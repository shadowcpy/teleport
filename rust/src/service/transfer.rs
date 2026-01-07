use std::{collections::HashMap, os::unix::io::FromRawFd, path::PathBuf, sync::Arc};

use anyhow::{Result, bail};
use futures_util::SinkExt;
use iroh::{EndpointId, protocol::Router};
use kameo::prelude::*;
use tokio::{
    fs::File,
    io::{AsyncReadExt, BufReader},
    spawn,
};
use tokio_util::bytes::BytesMut;
use tracing::{info, warn};

use crate::{
    api::teleport::{InboundFileEvent, InboundFileStatus, OutboundFileStatus, SendFileSource},
    frb_generated::StreamSink,
    protocol::{
        framed::FramedBiStream,
        send::{
            self, CHUNK_SIZE, ChunkHeader, DownloadStatus, FileStatus, Offer, SendRequest,
            SendResponse,
        },
    },
};

use super::{ConfigManager, ConfigReply, ConfigRequest, ConnQualityActor, ConnQualityRequest};

pub struct TransferActor {
    config: ActorRef<ConfigManager>,
    conn_quality: ActorRef<ConnQualityActor>,
    router: Arc<Router>,
    temp_dir: PathBuf,
    file_subscription: Option<Arc<StreamSink<InboundFileEvent>>>,
    peer_cache: HashMap<EndpointId, String>,
}

pub struct TransferActorArgs {
    pub config: ActorRef<ConfigManager>,
    pub conn_quality: ActorRef<ConnQualityActor>,
    pub router: Arc<Router>,
    pub temp_dir: PathBuf,
}

impl Actor for TransferActor {
    type Args = TransferActorArgs;
    type Error = anyhow::Error;

    async fn on_start(args: Self::Args, _actor_ref: ActorRef<Self>) -> Result<Self, Self::Error> {
        Ok(Self {
            config: args.config,
            conn_quality: args.conn_quality,
            router: args.router,
            temp_dir: args.temp_dir,
            file_subscription: None,
            peer_cache: HashMap::new(),
        })
    }
}

pub struct SendFileRequest {
    pub to: EndpointId,
    pub name: String,
    pub source: SendFileSource,
    pub progress: StreamSink<OutboundFileStatus>,
}

pub enum TransferRequest {
    IncomingOffer { offer: Offer, from: EndpointId },
    DownloadStatus(DownloadStatus),
    FileSubscription(StreamSink<InboundFileEvent>),
}

#[derive(Reply)]
pub enum TransferReply {
    IncomingOffer(Option<PathBuf>),
    Ack,
}

impl Message<SendFileRequest> for TransferActor {
    type Reply = ();

    async fn handle(
        &mut self,
        msg: SendFileRequest,
        _ctx: &mut Context<Self, Self::Reply>,
    ) -> Self::Reply {
        let router = self.router.clone();
        let conn_quality = self.conn_quality.clone();
        let SendFileRequest {
            to: peer,
            name,
            source,
            progress: ui,
        } = msg;

        spawn(async move {
            let action = async {
                let (file, size) = match source {
                    SendFileSource::Path(path) => {
                        let file = File::open(PathBuf::from(path)).await?;
                        let metadata = file.metadata().await?;
                        (file, metadata.len())
                    }
                    SendFileSource::Fd(fd) => {
                        let std_file = unsafe { std::fs::File::from_raw_fd(fd) };
                        let file = File::from_std(std_file);
                        let metadata = file.metadata().await?;
                        (file, metadata.len())
                    }
                };

                let mut reader = BufReader::new(file);

                let conn = router.endpoint().connect(peer, send::ALPN).await?;

                conn_quality
                    .tell(ConnQualityRequest::StartTracking(peer))
                    .await
                    .unwrap();

                let (send, recv) = conn.open_bi().await?;
                let mut framed = FramedBiStream::new((send, recv), send::MAX_MSG_SIZE);

                let offer = Offer { name, size };

                send::SendRequest::Offer(offer).send(&mut framed).await?;

                let response = send::SendResponse::recv(&mut framed).await?;

                match response {
                    send::SendResponse::Accept => {
                        info!("Offer accepted by {peer}");
                    }
                    send::SendResponse::Reject => {
                        bail!("Offer rejected by peer");
                    }
                    _ => bail!("Unexpected response: {response:?}"),
                }

                let mut offset = 0u64;
                let mut buffer = vec![0u8; CHUNK_SIZE];
                loop {
                    let n = reader.read(&mut buffer).await?;
                    if n == 0 {
                        SendRequest::Finish.send(&mut framed).await?;
                        break;
                    }

                    let chunk_data = &buffer[..n];

                    let header = ChunkHeader { size: n as u32 };

                    SendRequest::ChunkHeader(header).send(&mut framed).await?;
                    framed
                        .write
                        .send(BytesMut::from(chunk_data).freeze())
                        .await?;

                    offset += n as u64;

                    ui.add(OutboundFileStatus::Progress { offset, size })
                        .unwrap();
                }

                let response = SendResponse::recv(&mut framed).await?;

                match response {
                    SendResponse::Done => {
                        info!("File transfer to {peer} completed");
                    }
                    SendResponse::Error(e) => {
                        bail!("File transfer error from peer: {e}");
                    }
                    _ => bail!("Unexpected response: {response:?}"),
                }

                Ok(())
            };
            match action.await {
                Ok(_) => {
                    ui.add(OutboundFileStatus::Done).unwrap();
                }
                Err(e) => {
                    warn!("Failed to send file to {peer}: {}", e);
                    ui.add(OutboundFileStatus::Error(e.to_string())).unwrap();
                }
            }
        });
    }
}

impl Message<TransferRequest> for TransferActor {
    type Reply = TransferReply;

    async fn handle(
        &mut self,
        msg: TransferRequest,
        _ctx: &mut Context<Self, Self::Reply>,
    ) -> Self::Reply {
        match msg {
            TransferRequest::IncomingOffer { offer, from } => {
                let response = self.incoming_offer(offer, from).await.unwrap();
                TransferReply::IncomingOffer(response)
            }
            TransferRequest::DownloadStatus(file_event) => {
                self.download_status(file_event).await;
                TransferReply::Ack
            }
            TransferRequest::FileSubscription(sub) => {
                self.file_subscription = Some(Arc::new(sub));
                TransferReply::Ack
            }
        }
    }
}

impl TransferActor {
    pub async fn download_status(&mut self, file_event: DownloadStatus) {
        let Some(ref ui) = self.file_subscription else {
            return;
        };

        let peer_id = file_event.peer;
        let peer_name = if let Some(name) = self.peer_cache.get(&peer_id) {
            name.clone()
        } else {
            let response = self
                .config
                .ask(ConfigRequest::GetPeerName(peer_id))
                .await
                .unwrap();
            let ConfigReply::PeerName(name) = response else {
                unreachable!()
            };
            let name = name.unwrap_or_else(|| "Unknown peer".to_string());
            self.peer_cache.insert(peer_id, name.clone());
            name
        };

        let file_name = if file_event.file_name.is_empty() {
            "Unknown file".to_string()
        } else {
            file_event.file_name.clone()
        };
        match file_event.status {
            FileStatus::Progress { offset, size } => {
                ui.add(InboundFileEvent {
                    peer: peer_id.to_string(),
                    peer_name,
                    file_name,
                    event: InboundFileStatus::Progress { offset, size },
                })
                .unwrap();
            }
            FileStatus::Done { offer, path } => {
                ui.add(InboundFileEvent {
                    peer: peer_id.to_string(),
                    peer_name,
                    file_name: offer.name.clone(),
                    event: InboundFileStatus::Done {
                        path: path.to_string_lossy().to_string(),
                        name: offer.name.clone(),
                    },
                })
                .unwrap();
            }
            FileStatus::Error(e) => {
                ui.add(InboundFileEvent {
                    peer: peer_id.to_string(),
                    peer_name,
                    file_name,
                    event: InboundFileStatus::Error(e),
                })
                .unwrap();
            }
        }
    }

    pub async fn incoming_offer(&self, _offer: Offer, from: EndpointId) -> Result<Option<PathBuf>> {
        // Peer Verification
        let peer_id = from;
        let response = self.config.ask(ConfigRequest::IsPeerKnown(peer_id)).await?;
        let ConfigReply::IsPeerKnown(is_known) = response else {
            unreachable!()
        };
        if !is_known {
            warn!("Rejecting offer from unknown peer: {peer_id}");
            return Ok(None);
        }

        let random = blake3::hash(&rand::random::<u128>().to_be_bytes()).to_hex();

        let path = self
            .temp_dir
            .join(format!("recv_{}_{}", peer_id, random))
            .with_extension("tmp");

        Ok(Some(path))
    }
}
