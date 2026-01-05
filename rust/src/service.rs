use std::{collections::HashMap, os::unix::io::FromRawFd, path::PathBuf, sync::Arc};

use anyhow::{Result, bail};
use flutter_rust_bridge::JoinHandle;
use futures_util::{SinkExt, StreamExt};
use iroh::{
    EndpointAddr, EndpointId, Watcher,
    endpoint::{Builder, ConnectionType, presets},
    protocol::Router,
};

use iroh_quinn_proto::TransportConfig;
use kameo::prelude::*;
use serde::{Deserialize, Serialize};
use tokio::{
    fs::File,
    io::{AsyncReadExt, BufReader},
    spawn,
};
use tokio_util::bytes::BytesMut;
use tracing::{info, warn};

use crate::{
    api::teleport::{
        InboundFileEvent, InboundFileStatus, InboundPair, OutboundFileStatus, PairingResponse,
        SendFileSource, UIConnectionQuality, UIConnectionQualityUpdate, UIPairReaction, UIPromise,
        UIResolver,
    },
    config::{ConfigManager, Peer},
    frb_generated::{RustAutoOpaque, StreamSink},
    promise::{Promise, init_promise},
    protocol::{
        framed::FramedBiStream,
        pair::{self, MAX_SIZE, Pair, PairAcceptor},
        send::{
            self, CHUNK_SIZE, ChunkHeader, DownloadStatus, FileStatus, Offer, SendAcceptor,
            SendRequest, SendResponse,
        },
    },
};

pub struct Dispatcher {
    this: ActorRef<Dispatcher>,
    manager: ConfigManager,
    router: Arc<Router>,
    temp_dir: PathBuf,
    file_subscription: Option<Arc<StreamSink<InboundFileEvent>>>,
    pairing_subscription: Option<StreamSink<InboundPair>>,
    conn_quality_subscription: Option<StreamSink<UIConnectionQualityUpdate>>,
    conn_quality_tasks: HashMap<EndpointId, JoinHandle<()>>,
    active_secret: Vec<u8>,
}

pub struct DispatcherArgs {
    pub manager: ConfigManager,
    pub temp_dir: PathBuf,
}

impl Actor for Dispatcher {
    type Args = DispatcherArgs;
    type Error = anyhow::Error;

    async fn on_start(args: Self::Args, actor_ref: ActorRef<Self>) -> Result<Self, Self::Error> {
        let DispatcherArgs { manager, temp_dir } = args;

        let mut transport_config = TransportConfig::default();
        if cfg!(target_os = "android") {
            transport_config.enable_segmentation_offload(false);
        }

        let endpoint = Builder::new(presets::N0)
            .secret_key(manager.key.clone())
            .transport_config(transport_config)
            .bind()
            .await?;

        let router = Router::builder(endpoint)
            .accept(
                pair::ALPN.to_vec(),
                Arc::new(PairAcceptor {
                    dispatcher: actor_ref.clone(),
                }),
            )
            .accept(
                send::ALPN.to_vec(),
                Arc::new(SendAcceptor {
                    dispatcher: actor_ref.clone(),
                }),
            )
            .spawn();

        let router = Arc::new(router);

        info!("EndpointID: {}", router.endpoint().id());
        info!("Router started");

        Ok(Self {
            this: actor_ref,
            manager,
            router,
            temp_dir,
            file_subscription: None,
            pairing_subscription: None,
            conn_quality_subscription: None,
            conn_quality_tasks: HashMap::new(),
            active_secret: generate_secret(),
        })
    }
}

impl Message<ActionRequest> for Dispatcher {
    type Reply = ActionResponse;

    async fn handle(
        &mut self,
        msg: ActionRequest,
        _ctx: &mut Context<Self, Self::Reply>,
    ) -> Self::Reply {
        match msg {
            ActionRequest::PairWith {
                peer,
                secret,
                pairing_code,
            } => {
                let result = self.pair_with(peer, secret, pairing_code);
                ActionResponse::PairWith(result)
            }
            ActionRequest::SendFile {
                to,
                name,
                source,
                progress,
            } => {
                self.send_file_with_source(to, name, source, progress).await;
                ActionResponse::Ack
            }
        }
    }
}

impl Message<BGRequest> for Dispatcher {
    type Reply = BGResponse;

    async fn handle(
        &mut self,
        msg: BGRequest,
        _ctx: &mut Context<Self, Self::Reply>,
    ) -> Self::Reply {
        match msg {
            BGRequest::IncomingPairStarted {
                from,
                name,
                code,
                outcome,
            } => {
                let reaction = self.incoming_pair_started(from, name, code, outcome).await;
                self.active_secret = generate_secret(); // Rotate secret
                let our_name = self.manager.name.clone();
                BGResponse::IncomingPair { reaction, our_name }
            }
            BGRequest::RegisterPeer(peer) => {
                self.register_peer(peer).await;
                BGResponse::Ack
            }
            BGRequest::IncomingOffer { from, offer } => {
                let response = self.incoming_offer(offer, from).unwrap();
                BGResponse::IncomingOffer { download: response }
            }
            BGRequest::DownloadStatus(file_event) => {
                self.download_status(file_event).await;
                BGResponse::Ack
            }
            BGRequest::ValidateSecret(secret) => {
                let valid = secret == self.active_secret;
                if !valid {
                    warn!("Invalid secret received for pairing");
                }
                BGResponse::ValidationResult(valid)
            }
            BGRequest::GetSecret => BGResponse::Secret(self.active_secret.clone()),
            BGRequest::StartConnectionQualityTask(peer) => {
                let this = self.this.clone();
                let router = self.router.clone();
                if self.conn_quality_tasks.contains_key(&peer) {
                    return BGResponse::Ack;
                }
                let Some(watcher) = router.endpoint().conn_type(peer) else {
                    return BGResponse::Ack;
                };
                let handle = spawn(async move {
                    let mut stream = watcher.stream();
                    while let Some(update) = stream.next().await {
                        this.tell(BGRequest::ConnectionQualityUpdate { peer, update })
                            .await
                            .unwrap();
                    }
                });
                self.conn_quality_tasks.insert(peer, handle);
                BGResponse::Ack
            }
            BGRequest::ConnectionQualityUpdate { peer, update } => {
                if let Some(ref ui) = self.conn_quality_subscription {
                    let quality = match update {
                        ConnectionType::Direct(_) => UIConnectionQuality::Direct,
                        ConnectionType::Relay(_) => UIConnectionQuality::Relay,
                        ConnectionType::Mixed(_, _) => UIConnectionQuality::Mixed,
                        ConnectionType::None => UIConnectionQuality::None,
                    };
                    ui.add(UIConnectionQualityUpdate {
                        peer: peer.to_string(),
                        quality,
                    })
                    .unwrap();
                }
                BGResponse::Ack
            }
        }
    }
}

impl Message<UIRequest> for Dispatcher {
    type Reply = UIResponse;

    async fn handle(
        &mut self,
        msg: UIRequest,
        _ctx: &mut Context<Self, Self::Reply>,
    ) -> Self::Reply {
        match msg {
            UIRequest::PairingSubscription(sub) => {
                self.pairing_subscription = Some(sub);
                UIResponse::Ack
            }
            UIRequest::FileSubscription(sub) => {
                self.file_subscription = Some(Arc::new(sub));
                UIResponse::Ack
            }
            UIRequest::ConnQualitySubscription(sub) => {
                self.conn_quality_subscription = Some(sub);
                UIResponse::Ack
            }
            UIRequest::SetTargetDir(path_buf) => {
                self.manager.target_dir = Some(path_buf);
                self.manager.save().await.unwrap();
                UIResponse::Ack
            }
            UIRequest::SetDeviceName(name) => {
                self.manager.name = name;
                self.manager.save().await.unwrap();
                UIResponse::Ack
            }
            UIRequest::GetTargetDir => {
                let dir = self.manager.target_dir.clone();
                UIResponse::GetTargetDir(dir)
            }
            UIRequest::GetLocalAddr => {
                let addr = self.router.endpoint().addr();
                UIResponse::GetLocalAddr(addr)
            }
            UIRequest::GetPeers => {
                let peers = self.manager.peers.clone();
                UIResponse::GetPeers(peers)
            }
            UIRequest::GetDeviceName => {
                let name = self.manager.name.clone();
                UIResponse::GetDeviceName(name)
            }
        }
    }
}

impl Dispatcher {
    pub async fn send_file_with_source(
        &self,
        peer: EndpointId,
        name: String,
        source: SendFileSource,
        ui: StreamSink<OutboundFileStatus>,
    ) {
        let router = self.router.clone();
        let this = self.this.clone();

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

                this.tell(BGRequest::StartConnectionQualityTask(peer))
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

    pub async fn download_status(&self, file_event: DownloadStatus) {
        let Some(ref ui) = self.file_subscription else {
            return;
        };
        let remote_peer = self
            .manager
            .peers
            .iter()
            .find(|p| p.id == file_event.peer)
            .unwrap();
        let file_name = if file_event.file_name.is_empty() {
            "Unknown file".to_string()
        } else {
            file_event.file_name.clone()
        };
        match file_event.status {
            FileStatus::Progress { offset, size } => {
                ui.add(InboundFileEvent {
                    peer: file_event.peer.to_string(),
                    peer_name: remote_peer.name.clone(),
                    file_name,
                    event: InboundFileStatus::Progress { offset, size },
                })
                .unwrap();
            }
            FileStatus::Done { offer, path } => {
                ui.add(InboundFileEvent {
                    peer: file_event.peer.to_string(),
                    peer_name: remote_peer.name.clone(),
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
                    peer: file_event.peer.to_string(),
                    peer_name: remote_peer.name.clone(),
                    file_name,
                    event: InboundFileStatus::Error(e),
                })
                .unwrap();
            }
        }
    }

    pub async fn incoming_pair_started(
        &mut self,
        from: EndpointId,
        friendly_name: String,
        pairing_code: [u8; 6],
        outcome: Promise<Result<(), String>>,
    ) -> Promise<UIPairReaction> {
        let (reaction_promise, reaction_resolver) = init_promise::<UIPairReaction>();

        if let Some(ref ui) = self.pairing_subscription {
            if self.manager.peers.iter().any(|p| p.id == from) {
                warn!("Already paired to {from}, ignoring");
                reaction_resolver.emit(UIPairReaction::Reject);
                return reaction_promise;
            }

            let pair = InboundPair {
                peer: from.to_string(),
                friendly_name: friendly_name.clone(),
                pairing_code,
                reaction: RustAutoOpaque::new(UIResolver::new(reaction_resolver)),
                outcome: RustAutoOpaque::new(UIPromise::new(outcome)),
            };

            ui.add(pair).unwrap();
        }
        reaction_promise
    }

    pub async fn register_peer(&mut self, peer: Peer) {
        self.manager.peers.push(peer);
        self.manager.save().await.unwrap();
    }

    pub fn incoming_offer(&self, _offer: Offer, from: EndpointId) -> Result<Option<PathBuf>> {
        // Peer Verification
        let is_known = self.manager.peers.iter().any(|p| p.id == from);
        if !is_known {
            warn!("Rejecting offer from unknown peer: {from}");
            return Ok(None);
        }

        let random = blake3::hash(&rand::random::<u128>().to_be_bytes()).to_hex();

        let path = self
            .temp_dir
            .join(format!("recv_{}_{}", from, random))
            .with_extension("tmp");

        Ok(Some(path))
    }

    pub fn pair_with(
        &self,
        addr: EndpointAddr,
        secret: Vec<u8>,
        code: [u8; 6],
    ) -> Promise<PairingResponse> {
        let id = addr.id;
        let name = self.manager.name.clone();
        let router = self.router.clone();
        let dispatcher = self.this.clone();
        let already_paired = self.manager.peers.iter().any(|p| p.id == addr.id);

        let (promise, resolver) = init_promise::<PairingResponse>();

        spawn(async move {
            if already_paired {
                warn!("Already paired to {id}, ignoring");
                resolver.emit(PairingResponse::Success);
                return;
            }

            info!("Pairing with {id}...");

            enum InternalPairingResult {
                Success(String),
                WrongCode,
                WrongSecret,
                Rejected,
            }

            let action = async {
                let conn = router.endpoint().connect(addr, pair::ALPN).await?;
                let (send, recv) = conn.open_bi().await?;
                let mut framed = FramedBiStream::new((send, recv), MAX_SIZE);

                Pair::Helo {
                    friendly_name: name,
                    pairing_code: code,
                    secret,
                }
                .send(&mut framed)
                .await?;

                info!("Sent HELO to {id}...");

                let response = Pair::recv(&mut framed).await?;

                info!("Got {response:?} from {id}");

                match response {
                    Pair::FuckOff => Ok(InternalPairingResult::Rejected),
                    Pair::NiceToMeetYou { friendly_name } => {
                        Ok(InternalPairingResult::Success(friendly_name))
                    }
                    Pair::WrongPairingCode => Ok(InternalPairingResult::WrongCode),
                    Pair::WrongSecret => Ok(InternalPairingResult::WrongSecret),
                    _ => bail!("Invalid msg type"),
                }
            };

            match action.await {
                Ok(InternalPairingResult::Success(peer_name)) => {
                    info!("Paired with {peer_name} ({id})");
                    dispatcher
                        .tell(BGRequest::RegisterPeer(Peer {
                            id,
                            name: peer_name,
                        }))
                        .await
                        .unwrap();
                    resolver.emit(PairingResponse::Success);
                }
                Ok(InternalPairingResult::WrongCode) => {
                    resolver.emit(PairingResponse::WrongCode);
                }
                Ok(InternalPairingResult::WrongSecret) => {
                    resolver.emit(PairingResponse::WrongSecret);
                }
                Ok(InternalPairingResult::Rejected) => {
                    resolver.emit(PairingResponse::Error("Peer rejected pairing".to_string()));
                }
                Err(e) => {
                    warn!("Failed to pair with {id}: {}", e);
                    resolver.emit(PairingResponse::Error(e.to_string()));
                }
            }
        });

        promise
    }
}

fn generate_secret() -> Vec<u8> {
    (0..128).map(|_| rand::random()).collect()
}

#[derive(Serialize, Deserialize)]
pub struct PeerInfo {
    pub addr: EndpointAddr,
    pub secret: Vec<u8>,
}

// Temporary internal enum to help with the match logic, or I can just change the async block return type.
// Actually, `action` returns `Result<PairingResponseInternal>` or similar.
// Let's redefine `action` return type slightly.

pub enum ActionRequest {
    PairWith {
        peer: EndpointAddr,
        secret: Vec<u8>,
        pairing_code: [u8; 6],
    },
    SendFile {
        to: EndpointId,
        name: String,
        source: SendFileSource,
        progress: StreamSink<OutboundFileStatus>,
    },
}

pub enum BGRequest {
    IncomingPairStarted {
        from: EndpointId,
        name: String,
        code: [u8; 6],
        outcome: Promise<Result<(), String>>,
    },
    RegisterPeer(Peer),
    IncomingOffer {
        offer: Offer,
        from: EndpointId,
    },
    DownloadStatus(DownloadStatus),
    ValidateSecret(Vec<u8>),
    GetSecret,
    StartConnectionQualityTask(EndpointId),
    ConnectionQualityUpdate {
        peer: EndpointId,
        update: ConnectionType,
    },
}

pub enum UIRequest {
    PairingSubscription(StreamSink<InboundPair>),
    FileSubscription(StreamSink<InboundFileEvent>),
    ConnQualitySubscription(StreamSink<UIConnectionQualityUpdate>),
    GetTargetDir,
    SetTargetDir(PathBuf),
    GetLocalAddr,
    GetPeers,
    SetDeviceName(String),
    GetDeviceName,
}

#[derive(Reply)]
pub enum UIResponse {
    GetLocalAddr(EndpointAddr),
    GetPeers(Vec<Peer>),
    GetTargetDir(Option<PathBuf>),
    GetDeviceName(String),
    Ack,
}

#[derive(Reply)]
pub enum BGResponse {
    IncomingPair {
        reaction: Promise<UIPairReaction>,
        our_name: String,
    },
    IncomingOffer {
        download: Option<PathBuf>,
    },
    ValidationResult(bool),
    Secret(Vec<u8>),
    Ack,
}

#[derive(Reply)]
pub enum ActionResponse {
    PairWith(Promise<PairingResponse>),
    Ack,
}
