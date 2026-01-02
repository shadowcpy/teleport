use iroh::{
    endpoint::Connection,
    protocol::{AcceptError, ProtocolHandler},
};
use iroh_blobs::ticket::BlobTicket;
use serde::{Deserialize, Serialize};
use tracing::info;

use crate::service::{ServiceHandle, ServiceRequest};

pub const ALPN: &[u8] = b"teleport/send/0";

#[derive(Debug, Serialize, Deserialize)]
pub struct Offer {
    pub name: String,
    pub size: u64,
    pub blob_ticket: BlobTicket,
}

// The protocol definition:
#[derive(Debug, Clone)]
pub struct Send {
    pub handle: ServiceHandle,
}

impl ProtocolHandler for Send {
    async fn accept(&self, connection: Connection) -> Result<(), AcceptError> {
        let (mut send, mut recv) = connection.accept_bi().await?;

        let data = recv.read_to_end(size_of::<Offer>() * 2).await.unwrap();

        let offer: Offer = postcard::from_bytes(&data).unwrap();

        info!("Got an offer: {offer:?}, from {}", connection.remote_id());

        self.handle
            .call(ServiceRequest::IncomingOffer(offer))
            .await
            .unwrap();

        send.finish()?;

        connection.close(0u32.into(), b"bye!");

        Ok(())
    }
}
