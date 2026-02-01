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
use tracing::warn;

use crate::{
    protocol::framed::FramedBiStream,
    service::{AppSupervisor, ConnQualityRequest},
};

pub const ALPN: &[u8] = b"teleport/keepalive/1";
pub const MAX_MSG_SIZE: usize = 64;

#[derive(Debug, Serialize, Deserialize)]
pub enum KeepAlive {
    Ping { seq: u64 },
    Pong { seq: u64 },
}

impl KeepAlive {
    pub async fn send(&self, stream: &mut FramedBiStream) -> Result<()> {
        let encoded = postcard::to_extend(self, BytesMut::new())?.freeze();
        stream.write.send(encoded).await?;
        Ok(())
    }

    pub async fn recv(stream: &mut FramedBiStream) -> Result<Self> {
        let Some(encoded) = stream.read.try_next().await? else {
            bail!("unexpected end of stream");
        };
        let msg = postcard::from_bytes(&encoded)?;
        Ok(msg)
    }
}

#[derive(Debug, Clone)]
pub struct KeepAliveAcceptor {
    pub app: ActorRef<AppSupervisor>,
}

impl ProtocolHandler for KeepAliveAcceptor {
    async fn accept(&self, connection: Connection) -> Result<(), AcceptError> {
        let (send, recv) = connection.accept_bi().await?;
        let mut framed = FramedBiStream::new((send, recv), MAX_MSG_SIZE);
        let app = self.app.clone();
        let peer_id = connection.remote_id();

        app.tell(ConnQualityRequest::StartTracking {
            peer: peer_id,
            conn_info: connection.to_info(),
        })
        .await
        .ok();

        spawn(async move {
            loop {
                let msg = match KeepAlive::recv(&mut framed).await {
                    Ok(msg) => msg,
                    Err(e) => {
                        warn!("Keepalive stream from {peer_id} ended: {e}");
                        break;
                    }
                };

                match msg {
                    KeepAlive::Ping { seq } => {
                        if let Err(e) = (KeepAlive::Pong { seq }).send(&mut framed).await {
                            warn!("Failed to send keepalive pong to {peer_id}: {e}");
                            break;
                        }
                    }
                    KeepAlive::Pong { .. } => {
                        // Ignore unsolicited pongs.
                    }
                }
            }
        });

        Ok(())
    }
}
