use iroh::{
    endpoint::Connection,
    protocol::{AcceptError, ProtocolHandler},
};
use tracing::info;

use crate::service::{ServiceHandle, ServiceRequest};

pub const ALPN: &[u8] = b"teleport/pair/0";

// The protocol definition:
#[derive(Debug, Clone)]
pub struct Pair {
    pub handle: ServiceHandle,
}

impl ProtocolHandler for Pair {
    async fn accept(&self, connection: Connection) -> Result<(), AcceptError> {
        let (mut send, mut recv) = connection.accept_bi().await?;

        let bytes_sent = tokio::io::copy(&mut recv, &mut send).await?;

        info!(
            "Echoed {bytes_sent} bytes, paired to {}",
            connection.remote_id()
        );

        self.handle
            .call(ServiceRequest::IncomingPair(connection.remote_id()))
            .await
            .unwrap();

        send.finish()?;
        connection.closed().await;

        Ok(())
    }
}
