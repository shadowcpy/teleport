use anyhow::{bail, Result};
use futures_util::{SinkExt, TryStreamExt};
use iroh::{
    endpoint::Connection,
    protocol::{AcceptError, ProtocolHandler},
};
use serde::{Deserialize, Serialize};
use tokio::spawn;
use tokio_util::bytes::BytesMut;

use crate::{
    protocol::framed::FramedBiStream,
    service::{BGRequest, BGResponse, ServiceHandle, UIDoPair},
};

pub const ALPN: &[u8] = b"teleport/pair/0";

pub const MAX_SIZE: usize = 4096;

#[derive(Debug, Serialize, Deserialize)]
pub enum Pair {
    Helo {
        friendly_name: String,
        pairing_code: [u8; 6],
    },
    FuckOff,
    NiceToMeetYou {
        friendly_name: String,
    },
    WrongPairingCode,
}

impl Pair {
    pub async fn send(&self, stream: &mut FramedBiStream) -> Result<()> {
        let encoded_pair = postcard::to_extend(self, BytesMut::new())?.freeze();
        stream.write.send(encoded_pair).await?;
        Ok(())
    }

    pub async fn recv(stream: &mut FramedBiStream) -> Result<Pair> {
        let Some(encoded_move) = stream.read.try_next().await? else {
            bail!("unexpected end of stream");
        };
        let mv = postcard::from_bytes(&encoded_move)?;
        Ok(mv)
    }
}

#[derive(Debug, Clone)]
pub struct PairAcceptor {
    pub handle: ServiceHandle,
}

impl ProtocolHandler for PairAcceptor {
    async fn accept(&self, connection: Connection) -> Result<(), AcceptError> {
        let (send, recv) = connection.accept_bi().await?;
        let mut framed = FramedBiStream::new((send, recv), MAX_SIZE);
        let handle = self.handle.clone();

        spawn(async move {
            let Ok(helo) = Pair::recv(&mut framed).await else {
                connection.close(1u32.into(), b"INV_HELO");
                return;
            };

            let Pair::Helo {
                friendly_name: peer_name,
                pairing_code,
            } = helo
            else {
                connection.close(1u32.into(), b"INV_HELO");
                return;
            };

            let response = handle
                .call(BGRequest::IncomingPair {
                    from: connection.remote_id(),
                    friendly_name: peer_name.clone(),
                    pairing_code,
                })
                .await
                .unwrap();

            let BGResponse::IncomingPair(delayed) = response.unwrap_bg_response();

            let response = delayed.await.unwrap();

            if let UIDoPair::Accept { our_name } = response {
                let result = Pair::NiceToMeetYou {
                    friendly_name: our_name,
                }
                .send(&mut framed)
                .await;

                handle
                    .call(BGRequest::FinalizePair {
                        with: connection.remote_id(),
                        friendly_name: peer_name,
                        outcome: result,
                    })
                    .await
                    .unwrap();
            } else if let UIDoPair::WrongPairingCode = response {
                Pair::WrongPairingCode.send(&mut framed).await.ok();
            } else {
                Pair::FuckOff.send(&mut framed).await.ok();
            }
        });

        Ok(())
    }
}
