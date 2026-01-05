use anyhow::{Result, bail};
use futures_util::{SinkExt, TryStreamExt};
use iroh::{
    endpoint::Connection,
    protocol::{AcceptError, ProtocolHandler},
};
use kameo::actor::ActorRef;
use serde::{Deserialize, Serialize};
use tokio::spawn;
use tokio_util::bytes::BytesMut;
use tracing::info;

use crate::{
    api::teleport::UIPairReaction,
    config::Peer,
    promise::init_promise,
    protocol::framed::FramedBiStream,
    service::{BGRequest, BGResponse, Dispatcher},
};

pub const ALPN: &[u8] = b"teleport/pair/0";

pub const MAX_SIZE: usize = 4096;

#[derive(Debug, Serialize, Deserialize)]
pub enum Pair {
    Helo {
        friendly_name: String,
        pairing_code: [u8; 6],
        secret: Vec<u8>,
    },
    FuckOff,
    NiceToMeetYou {
        friendly_name: String,
    },
    WrongPairingCode,
    WrongSecret,
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
    pub dispatcher: ActorRef<Dispatcher>,
}

impl ProtocolHandler for PairAcceptor {
    async fn accept(&self, connection: Connection) -> Result<(), AcceptError> {
        let (send, recv) = connection.accept_bi().await?;
        let mut framed = FramedBiStream::new((send, recv), MAX_SIZE);
        let dispatcher = self.dispatcher.clone();

        info!("New pairing request from {}", connection.remote_id());

        spawn(async move {
            let Ok(helo) = Pair::recv(&mut framed).await else {
                connection.close(1u32.into(), b"INV_HELO");
                return;
            };

            let Pair::Helo {
                friendly_name: peer_name,
                pairing_code,
                secret,
            } = helo
            else {
                connection.close(1u32.into(), b"INV_HELO");
                return;
            };

            let Ok(response) = dispatcher.ask(BGRequest::ValidateSecret(secret)).await else {
                connection.close(1u32.into(), b"INT_ERR");
                return;
            };

            let BGResponse::ValidationResult(valid_secret) = response else {
                unreachable!()
            };

            if !valid_secret {
                info!("Invalid secret from {}", connection.remote_id());
                Pair::WrongSecret.send(&mut framed).await.ok();
                connection.close(1u32.into(), b"INV_SEC");
                return;
            }

            info!("Got HELO from {}", connection.remote_id());

            let (promise, resolver) = init_promise();

            let response = dispatcher
                .ask(BGRequest::IncomingPairStarted {
                    from: connection.remote_id(),
                    name: peer_name.clone(),
                    code: pairing_code,
                    outcome: promise,
                })
                .await
                .unwrap();

            let BGResponse::IncomingPair { reaction, our_name } = response else {
                unreachable!()
            };

            let reaction = reaction.await;

            info!("Responding with {reaction:?} to {}", connection.remote_id());

            match reaction {
                UIPairReaction::Accept => {
                    let result = Pair::NiceToMeetYou {
                        friendly_name: our_name,
                    }
                    .send(&mut framed)
                    .await;

                    dispatcher
                        .tell(BGRequest::IncomingPairCompleted {
                            outcome: result.map(|_| Peer {
                                name: peer_name,
                                id: connection.remote_id(),
                            }),
                            resolver,
                        })
                        .await
                        .unwrap();
                    let _ = connection.closed().await;
                }
                UIPairReaction::WrongPairingCode => {
                    Pair::WrongPairingCode.send(&mut framed).await.ok();
                    let _ = connection.closed().await;
                }
                UIPairReaction::Reject => {
                    Pair::FuckOff.send(&mut framed).await.ok();
                    let _ = connection.closed().await;
                }
            }
        });

        Ok(())
    }
}
