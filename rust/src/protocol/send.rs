use anyhow::{Result, bail};
use futures_util::{SinkExt, StreamExt, TryStreamExt};
use iroh::{
    EndpointId,
    endpoint::Connection,
    protocol::{AcceptError, ProtocolHandler},
};
use iroh_blobs::{api::downloader::DownloadProgressItem, ticket::BlobTicket};
use kameo::actor::ActorRef;
use serde::{Deserialize, Serialize};
use tokio::spawn;
use tokio_util::bytes::BytesMut;
use tracing::{error, info};

use crate::{
    protocol::framed::FramedBiStream,
    service::{BGRequest, BGResponse, Dispatcher},
};

pub const ALPN: &[u8] = b"teleport/send/0";
pub const MAX_SIZE: usize = 4096;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Offer {
    pub name: String,
    pub size: u64,
    pub blob_ticket: BlobTicket,
}

#[derive(Debug, Serialize, Deserialize)]
pub enum SendRequest {
    Offer(Offer),
}

#[derive(Debug, Serialize, Deserialize)]
pub enum SendResponse {
    Accept,
    Reject,
    Progress { val: u64 },
    Done,
    Error(String),
}

impl SendRequest {
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

impl SendResponse {
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

// The protocol definition:
#[derive(Debug, Clone)]
pub struct SendAcceptor {
    pub dispatcher: ActorRef<Dispatcher>,
}

impl ProtocolHandler for SendAcceptor {
    async fn accept(&self, connection: Connection) -> Result<(), AcceptError> {
        let (send, recv) = connection.accept_bi().await?;
        let mut framed = FramedBiStream::new((send, recv), MAX_SIZE);
        let dispatcher = self.dispatcher.clone();
        let peer_id = connection.remote_id();

        spawn(async move {
            let req = match SendRequest::recv(&mut framed).await {
                Ok(req) => req,
                Err(e) => {
                    error!("Failed to receive request: {e}");
                    return;
                }
            };

            let SendRequest::Offer(offer) = req;

            info!("Got an offer: {offer:?}, from {peer_id}");

            let response = dispatcher
                .ask(BGRequest::IncomingOffer {
                    ticket: offer.blob_ticket.clone(),
                    from: peer_id,
                })
                .await
                .unwrap();

            let BGResponse::IncomingOffer { download } = response else {
                unreachable!()
            };

            if let Some(download) = download {
                if let Err(e) = SendResponse::Accept.send(&mut framed).await {
                    error!("Failed to send accept response: {e}");
                    connection.close(1u32.into(), b"ACCEPT_ERR");
                    dispatcher
                        .tell(BGRequest::DownloadStatus(DownloadStatus {
                            peer: peer_id,
                            status: FileStatus::Error(e.to_string()),
                        }))
                        .await
                        .unwrap();
                    return;
                }

                dispatcher
                    .tell(BGRequest::DownloadStatus(DownloadStatus {
                        peer: peer_id,
                        status: FileStatus::Progress {
                            offset: 0,
                            size: offer.size,
                        },
                    }))
                    .await
                    .unwrap();

                let mut progress = match download.stream().await {
                    Ok(progress) => progress,
                    Err(e) => {
                        error!("Failed to get download stream for offer from {peer_id}: {e}");
                        connection.close(1u32.into(), b"DL_ERR");
                        dispatcher
                            .tell(BGRequest::DownloadStatus(DownloadStatus {
                                peer: peer_id,
                                status: FileStatus::Error(e.to_string()),
                            }))
                            .await
                            .unwrap();
                        return;
                    }
                };

                while let Some(status) = progress.next().await {
                    let (internal, external) = match status {
                        DownloadProgressItem::Progress(val) if val % 100 == 0 => (
                            FileStatus::Progress {
                                offset: val,
                                size: offer.size,
                            },
                            SendResponse::Progress { val },
                        ),
                        DownloadProgressItem::DownloadError => {
                            let err_msg = format!("Download error");
                            (
                                FileStatus::Error(err_msg.clone()),
                                SendResponse::Error(err_msg),
                            )
                        }
                        DownloadProgressItem::PartComplete { .. } => {
                            (FileStatus::Done(offer.clone()), SendResponse::Done)
                        }
                        DownloadProgressItem::Error(e) => {
                            let err_msg = format!("Download error: {e}");
                            (
                                FileStatus::Error(e.to_string()),
                                SendResponse::Error(err_msg),
                            )
                        }
                        _ => continue,
                    };
                    dispatcher
                        .tell(BGRequest::DownloadStatus(DownloadStatus {
                            peer: peer_id,
                            status: internal.clone(),
                        }))
                        .await
                        .unwrap();

                    let result = external.send(&mut framed).await;
                    if let Err(e) = result {
                        error!("Failed to send progress response: {e}");
                        connection.close(1u32.into(), b"CLOSED");
                        dispatcher
                            .tell(BGRequest::DownloadStatus(DownloadStatus {
                                peer: peer_id,
                                status: FileStatus::Error(e.to_string()),
                            }))
                            .await
                            .unwrap();
                        break;
                    }
                    if matches!(internal, FileStatus::Done(_)) {
                        info!("Download from {peer_id} completed successfully");
                        break;
                    }
                }
            } else {
                if let Err(e) = SendResponse::Reject.send(&mut framed).await {
                    error!("Failed to send reject response: {e}");
                }
                info!("Offer from unknown peer {peer_id} rejected");
            }

            let _ = connection.closed().await;
        });

        Ok(())
    }
}

pub struct DownloadStatus {
    pub peer: EndpointId,
    pub status: FileStatus,
}

#[derive(Debug, Clone)]
pub enum FileStatus {
    Progress { offset: u64, size: u64 },
    Done(Offer),
    Error(String),
}
