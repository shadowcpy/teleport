use std::{path::PathBuf, sync::Arc, time::Duration};

use anyhow::{Result, bail};
use iroh::{
    EndpointAddr, EndpointId,
    discovery::mdns::MdnsDiscoveryBuilder,
    endpoint::{Builder, TransportConfig, presets},
    protocol::Router,
};
use iroh_blobs::{
    BlobsProtocol,
    api::downloader::{DownloadProgress, Downloader},
    store::mem::MemStore,
    ticket::BlobTicket,
};
use iroh_quinn_proto::{IdleTimeout, VarInt};
use kameo::prelude::*;
use tokio::spawn;
use tracing::{error, info, warn};

use crate::{
    api::teleport::{
        InboundFileEvent, InboundFileStatus, InboundPair, OutboundFileStatus, PairingResponse,
        UIPairReaction, UIPromise, UIResolver,
    },
    config::{ConfigManager, Peer},
    frb_generated::{RustAutoOpaque, StreamSink},
    promise::{Promise, init_promise},
    protocol::{
        framed::FramedBiStream,
        pair::{self, MAX_SIZE, Pair, PairAcceptor},
        send::{self, DownloadStatus, FileStatus, Offer, SendAcceptor},
    },
};

pub struct Dispatcher {
    this: ActorRef<Dispatcher>,
    manager: ConfigManager,
    router: Arc<Router>,
    store: Arc<MemStore>,
    temp_dir: PathBuf,
    downloader: Downloader,
    file_subscription: Option<Arc<StreamSink<InboundFileEvent>>>,
    pairing_subscription: Option<StreamSink<InboundPair>>,
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
        transport_config.enable_segmentation_offload(false);
        transport_config.max_idle_timeout(Some(VarInt::from_u32(5_000).into()));

        let endpoint = Builder::new(presets::N0)
            .discovery(MdnsDiscoveryBuilder::default())
            .secret_key(manager.key.clone())
            .transport_config(transport_config)
            .bind()
            .await?;

        let store = MemStore::new();

        let blobs = BlobsProtocol::new(&store, None);

        let downloader = store.downloader(&endpoint);

        let router = Router::builder(endpoint)
            .accept(iroh_blobs::ALPN, blobs)
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
        let store = Arc::new(store);

        info!("EndpointID: {}", router.endpoint().id());
        info!("Router started");

        Ok(Self {
            this: actor_ref,
            manager,
            router,
            store,
            temp_dir,
            downloader,
            file_subscription: None,
            pairing_subscription: None,
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
            ActionRequest::PairWith { peer, pairing_code } => {
                let result = self.pair_with(peer, pairing_code);
                ActionResponse::PairWith(result)
            }
            ActionRequest::SendFile {
                to,
                name,
                path,
                progress,
            } => {
                self.send_file(to, name, path, progress).await;
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
                let our_name = self.manager.name.clone();
                BGResponse::IncomingPair { reaction, our_name }
            }
            BGRequest::RegisterPeer(peer) => {
                self.register_peer(peer).await;
                BGResponse::Ack
            }
            BGRequest::IncomingOffer { from, ticket } => {
                let response = self.incoming_offer(ticket, from).unwrap();
                BGResponse::IncomingOffer { download: response }
            }
            BGRequest::DownloadStatus(file_event) => {
                self.download_status(file_event).await;
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
    pub async fn send_file(
        &self,
        peer: EndpointId,
        name: String,
        path: PathBuf,
        ui: StreamSink<OutboundFileStatus>,
    ) {
        let store = self.store.clone();
        let router = self.router.clone();

        spawn(async move {
            let action = async {
                let tag = store.blobs().add_path(path).await?;
                let observer = store.blobs().observe(tag.hash).await?;
                let size = observer.size();
                let endpoint_addr = router.endpoint().addr();
                let ticket = BlobTicket::new(endpoint_addr, tag.hash, tag.format);

                let conn = router.endpoint().connect(peer, send::ALPN).await?;
                let (send, recv) = conn.open_bi().await?;
                let mut framed = FramedBiStream::new((send, recv), send::MAX_SIZE);

                let offer = Offer {
                    name,
                    size,
                    blob_ticket: ticket,
                };

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

                loop {
                    let response = send::SendResponse::recv(&mut framed).await?;
                    match response {
                        send::SendResponse::Progress { val } => {
                            ui.add(OutboundFileStatus::Progress {
                                offset: val,
                                size: observer.size(),
                            })
                            .unwrap();
                        }
                        send::SendResponse::Done => {
                            info!("Transfer complete!");
                            conn.close(0u32.into(), b"bye");
                            break;
                        }
                        send::SendResponse::Error(e) => {
                            bail!("Remote error: {e}");
                        }
                        _ => {}
                    }
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
        match file_event.status {
            FileStatus::Progress { offset, size } => {
                ui.add(InboundFileEvent {
                    peer: file_event.peer.to_string(),
                    name: remote_peer.name.clone(),
                    event: InboundFileStatus::Progress { offset, size },
                })
                .unwrap();
            }
            FileStatus::Done(offer) => {
                let ticket = &offer.blob_ticket;
                let path = self.temp_dir.join(ticket.hash().to_string());
                if let Err(e) = self.store.blobs().export(ticket.hash(), &path).await {
                    error!("Failed to export blob for offer {:?}: {}", offer, e);
                    ui.add(InboundFileEvent {
                        peer: file_event.peer.to_string(),
                        name: remote_peer.name.clone(),
                        event: InboundFileStatus::Error(e.to_string()),
                    })
                    .unwrap();
                } else {
                    ui.add(InboundFileEvent {
                        peer: file_event.peer.to_string(),
                        name: remote_peer.name.clone(),
                        event: InboundFileStatus::Done {
                            path: path.to_string_lossy().to_string(),
                            name: offer.name.clone(),
                        },
                    })
                    .unwrap();
                }
            }
            FileStatus::Error(e) => {
                ui.add(InboundFileEvent {
                    peer: file_event.peer.to_string(),
                    name: remote_peer.name.clone(),
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

    pub fn incoming_offer(
        &self,
        ticket: BlobTicket,
        from: EndpointId,
    ) -> Result<Option<DownloadProgress>> {
        // Peer Verification
        let is_known = self.manager.peers.iter().any(|p| p.id == from);
        if !is_known {
            warn!("Rejecting offer from unknown peer: {from}");
            return Ok(None);
        }

        let download_fut = self
            .downloader
            .download(ticket.hash(), Some(ticket.addr().id));

        Ok(Some(download_fut))
    }

    pub fn pair_with(&self, addr: EndpointAddr, code: [u8; 6]) -> Promise<PairingResponse> {
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

            let action = async {
                let conn = router.endpoint().connect(addr, pair::ALPN).await?;
                let (send, recv) = conn.open_bi().await?;
                let mut framed = FramedBiStream::new((send, recv), MAX_SIZE);

                Pair::Helo {
                    friendly_name: name,
                    pairing_code: code,
                }
                .send(&mut framed)
                .await?;

                info!("Sent HELO to {id}...");

                let response = Pair::recv(&mut framed).await?;

                info!("Got {response:?} from {id}");

                let name = match response {
                    Pair::FuckOff => {
                        bail!("Peer rejected pairing");
                    }
                    Pair::NiceToMeetYou { friendly_name } => friendly_name,
                    Pair::WrongPairingCode => {
                        return Ok(None);
                    }
                    _ => bail!("Invalid msg type"),
                };

                Ok(Some(name))
            };

            match action.await {
                Ok(Some(peer_name)) => {
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
                Ok(None) => {
                    resolver.emit(PairingResponse::WrongCode);
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

// Temporary internal enum to help with the match logic, or I can just change the async block return type.
// Actually, `action` returns `Result<PairingResponseInternal>` or similar.
// Let's redefine `action` return type slightly.

pub enum ActionRequest {
    PairWith {
        peer: EndpointAddr,
        pairing_code: [u8; 6],
    },
    SendFile {
        to: EndpointId,
        name: String,
        path: PathBuf,
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
        ticket: BlobTicket,
        from: EndpointId,
    },
    DownloadStatus(DownloadStatus),
}

pub enum UIRequest {
    PairingSubscription(StreamSink<InboundPair>),
    FileSubscription(StreamSink<InboundFileEvent>),
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
        download: Option<DownloadProgress>,
    },
    Ack,
}

#[derive(Reply)]
pub enum ActionResponse {
    PairWith(Promise<PairingResponse>),
    Ack,
}
