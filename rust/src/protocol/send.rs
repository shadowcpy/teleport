use std::path::PathBuf;

use anyhow::{Result, bail};
use futures_util::{SinkExt, TryStreamExt};
use iroh::{
    EndpointId,
    endpoint::Connection,
    protocol::{AcceptError, ProtocolHandler},
};
use iroh_quinn_proto::VarInt;
use kameo::actor::ActorRef;
use serde::{Deserialize, Serialize};
use tokio::{
    fs::File,
    io::{AsyncWriteExt, BufWriter},
    spawn,
};
use tokio_util::bytes::BytesMut;
use tracing::{error, info};

use crate::{
    protocol::framed::FramedBiStream,
    service::{AppSupervisor, TransferReply, TransferRequest},
};

pub const ALPN: &[u8] = b"teleport/send/1";

pub const CHUNK_SIZE: usize = 1024 * 256; // 256 KiB
pub const MAX_MSG_SIZE: usize = CHUNK_SIZE + 1024;

pub const MAX_FILE_SIZE: u64 = 1024 * 1024 * 1024 * 20; // 20 GiB

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Offer {
    pub name: String,
    pub size: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ChunkHeader {
    pub size: u32,
}

#[derive(Debug, Serialize, Deserialize)]
pub enum SendRequest {
    Offer(Offer),
    ChunkHeader(ChunkHeader),
    Finish,
}

#[derive(Debug, Serialize, Deserialize)]
pub enum SendResponse {
    Accept,
    Reject,
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

#[derive(Debug, thiserror::Error)]
enum SendError {
    #[error("Failed to receive request: {0}")]
    Recv(#[from] anyhow::Error),
    #[error("Expected offer request")]
    ExpectedOffer,
    #[error("Failed to send response: {0}")]
    Send(anyhow::Error),
    #[error("Failed to write to file: {0}")]
    WriteFile(std::io::Error),
    #[error("Received more data than expected")]
    Oversize,
    #[error("Invalid chunk")]
    InvalidChunk,
}

impl SendError {
    fn to_close_code(&self) -> (VarInt, &'static [u8]) {
        match self {
            SendError::Recv(_) => (1u32.into(), b"RECV_ERR"),
            SendError::ExpectedOffer => (1u32.into(), b"EXP_OFFER"),
            SendError::Send(_) => (1u32.into(), b"SEND_ERR"),
            SendError::WriteFile(_) => (1u32.into(), b"WRITE_ERR"),
            SendError::Oversize => (1u32.into(), b"OVERSIZE"),
            SendError::InvalidChunk => (1u32.into(), b"INV_CHUNK"),
        }
    }
}

#[derive(Debug, Clone)]
pub struct SendAcceptor {
    pub app: ActorRef<AppSupervisor>,
}

impl ProtocolHandler for SendAcceptor {
    async fn accept(&self, connection: Connection) -> Result<(), AcceptError> {
        let (send, recv) = connection.accept_bi().await?;
        let mut framed = FramedBiStream::new((send, recv), MAX_MSG_SIZE);
        let app = self.app.clone();
        let peer_id = connection.remote_id();

        spawn(async move {
            let action = async {
                let req = SendRequest::recv(&mut framed).await?;
                let SendRequest::Offer(offer) = req else {
                    return Err(SendError::ExpectedOffer);
                };

                info!("Got an offer: {offer:?}, from {peer_id}");
                let size = offer.size;

                if size > MAX_FILE_SIZE {
                    error!("File size too large: {size}");
                    return Err(SendError::Oversize);
                }

                let response = app
                    .ask(TransferRequest::IncomingOffer {
                        offer: offer.clone(),
                        from: peer_id,
                    })
                    .await
                    .unwrap();

                let TransferReply::IncomingOffer(download) = response else {
                    unreachable!()
                };

                let Some(path) = download else {
                    if let Err(e) = SendResponse::Reject.send(&mut framed).await {
                        error!("Failed to send reject response: {e}");
                    }
                    info!("Offer from unknown peer {peer_id} rejected");
                    return Ok(());
                };

                if let Err(e) = SendResponse::Accept.send(&mut framed).await {
                    return Err(SendError::Send(e));
                }

                let temp_file = File::create(&path).await.map_err(SendError::WriteFile)?;
                let mut writer = BufWriter::new(temp_file);

                app.tell(TransferRequest::DownloadStatus(DownloadStatus {
                    peer: peer_id,
                    file_name: offer.name.clone(),
                    status: FileStatus::Progress { offset: 0, size },
                }))
                .await
                .unwrap();

                let mut offset = 0u64;

                loop {
                    let req = SendRequest::recv(&mut framed).await?;

                    match req {
                        SendRequest::Offer(_) => return Err(SendError::InvalidChunk),
                        SendRequest::Finish => {
                            if offset != size {
                                error!(
                                    "Finish received but sizes do not match. Expected {size}, got {offset}"
                                );
                                return Err(SendError::InvalidChunk);
                            }
                            break;
                        }
                        SendRequest::ChunkHeader(header) => {
                            // Receive raw data
                            let Some(data) = framed
                                .read
                                .try_next()
                                .await
                                .map_err(|e| SendError::Recv(e.into()))?
                            else {
                                return Err(SendError::InvalidChunk);
                            };

                            if data.len() != header.size as usize {
                                return Err(SendError::InvalidChunk);
                            }

                            if let Err(e) = writer.write_all(&data).await {
                                return Err(SendError::WriteFile(e));
                            }

                            offset += data.len() as u64;

                            info!("Received chunk from {peer_id} ({offset}/{size})");

                            if offset > size {
                                return Err(SendError::Oversize);
                            }

                            app.tell(TransferRequest::DownloadStatus(DownloadStatus {
                                peer: peer_id,
                                file_name: offer.name.clone(),
                                status: FileStatus::Progress { offset, size },
                            }))
                            .await
                            .unwrap();
                        }
                    }
                }

                writer.flush().await.map_err(SendError::WriteFile)?;
                drop(writer);

                info!("Download from peer {peer_id} completed");
                app.tell(TransferRequest::DownloadStatus(DownloadStatus {
                    peer: peer_id,
                    file_name: offer.name.clone(),
                    status: FileStatus::Done { offer, path },
                }))
                .await
                .unwrap();

                SendResponse::Done
                    .send(&mut framed)
                    .await
                    .map_err(SendError::Send)?;

                Ok(())
            };

            if let Err(e) = action.await {
                error!("Connection failed: {e}");
                let (code, reason) = e.to_close_code();
                connection.close(code, reason);

                app.tell(TransferRequest::DownloadStatus(DownloadStatus {
                    peer: peer_id,
                    file_name: String::new(),
                    status: FileStatus::Error(e.to_string()),
                }))
                .await
                .ok();
            } else {
                let _ = connection.closed().await;
            }
        });

        Ok(())
    }
}

pub struct DownloadStatus {
    pub peer: EndpointId,
    pub file_name: String,
    pub status: FileStatus,
}

#[derive(Debug, Clone)]
pub enum FileStatus {
    Progress { offset: u64, size: u64 },
    Done { offer: Offer, path: PathBuf },
    Error(String),
}
