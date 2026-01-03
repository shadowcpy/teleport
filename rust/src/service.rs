use std::{path::PathBuf, sync::Arc};

use anyhow::{Result, bail};
use iroh::{
    EndpointAddr, EndpointId,
    discovery::mdns::MdnsDiscoveryBuilder,
    endpoint::{Builder, presets},
    protocol::Router,
};
use iroh_blobs::{
    BlobsProtocol, api::downloader::Downloader, store::mem::MemStore, ticket::BlobTicket,
};
use kameo::prelude::*;
use tokio::spawn;
use tracing::{info, warn};

use crate::{
    api::teleport::{InboundFile, InboundPair, UIPairReaction, UIPromise, UIResolver},
    config::{ConfigManager, Peer},
    frb_generated::{RustAutoOpaque, StreamSink},
    promise::{Promise, init_promise},
    protocol::{
        framed::FramedBiStream,
        pair::{self, MAX_SIZE, Pair, PairAcceptor},
        send::{self, Offer, SendAcceptor},
    },
};

pub struct Dispatcher {
    this: ActorRef<Dispatcher>,
    manager: ConfigManager,
    router: Arc<Router>,
    store: MemStore,
    temp_dir: PathBuf,
    downloader: Downloader,
    file_subscription: Option<StreamSink<InboundFile>>,
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

        let endpoint = Builder::new(presets::N0)
            .discovery(MdnsDiscoveryBuilder::default())
            .secret_key(manager.key.clone())
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
            ActionRequest::SendFile { to, name, path } => {
                let result = self.send_file(to, name, path).await;
                ActionResponse::SendFile(result)
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
            BGRequest::IncomingOffer(offer) => {
                self.incoming_offer(offer, self.file_subscription.as_ref())
                    .await
                    .unwrap();
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
                self.file_subscription = Some(sub);
                UIResponse::Ack
            }
            UIRequest::SetTargetDir(path_buf) => {
                self.manager.target_dir = Some(path_buf);
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
        }
    }
}

impl Dispatcher {
    pub async fn send_file(&self, peer: EndpointId, name: String, path: PathBuf) -> Result<()> {
        let tag = self.store.blobs().add_path(path).await?;
        let endpoint_id = self.router.endpoint().id();
        let ticket = BlobTicket::new(endpoint_id.into(), tag.hash, tag.format);

        let conn = self.router.endpoint().connect(peer, send::ALPN).await?;
        let (mut send, _) = conn.open_bi().await?;

        let offer = Offer {
            name,
            size: 10,
            blob_ticket: ticket,
        };

        let message = postcard::to_allocvec(&offer)?;

        send.write_all(&message).await?;
        send.finish()?;

        conn.closed().await;

        Ok(())
    }

    pub async fn incoming_pair_started(
        &mut self,
        from: EndpointId,
        friendly_name: String,
        pairing_code: [u8; 6],
        outcome: Promise<Result<(), String>>,
    ) -> Promise<UIPairReaction> {
        let (reaction_promise, reaction_resolver) = init_promise();

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

    pub async fn incoming_offer(
        &self,
        offer: Offer,
        sub: Option<&StreamSink<InboundFile>>,
    ) -> Result<()> {
        let ticket = offer.blob_ticket;
        self.downloader
            .download(ticket.hash(), Some(ticket.addr().id))
            .await?;
        let path = self.temp_dir.join(ticket.hash().to_string());
        self.store.blobs().export(ticket.hash(), &path).await?;
        if let Some(ui) = sub {
            ui.add(InboundFile {
                peer: ticket.addr().id.to_string(),
                name: offer.name,
                size: offer.size,
                path: path.to_string_lossy().to_string(),
            })
            .unwrap();
        }
        Ok(())
    }

    pub fn pair_with(&self, addr: EndpointAddr, code: [u8; 6]) -> Promise<Result<()>> {
        let id = addr.id;
        let name = self.manager.name.clone();
        let router = self.router.clone();
        let dispatcher = self.this.clone();
        let already_paired = self.manager.peers.iter().any(|p| p.id == addr.id);

        let (promise, resolver) = init_promise();

        spawn(async move {
            if already_paired {
                warn!("Already paired to {id}, ignoring");
                resolver.emit(Ok(()));
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
                        bail!("Wrong pairing code");
                    }
                    _ => bail!("Invalid msg type"),
                };

                Ok(name)
            };

            match action.await {
                Ok(peer_name) => {
                    info!("Paired with {peer_name} ({id})");
                    dispatcher
                        .tell(BGRequest::RegisterPeer(Peer {
                            id,
                            name: peer_name,
                        }))
                        .await
                        .unwrap();
                    resolver.emit(Ok(()));
                }
                Err(e) => {
                    warn!("Failed to pair with {id}: {}", e);
                    resolver.emit(Err(e));
                }
            }
        });

        promise
    }
}
pub enum ActionRequest {
    PairWith {
        peer: EndpointAddr,
        pairing_code: [u8; 6],
    },
    SendFile {
        to: EndpointId,
        name: String,
        path: PathBuf,
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
    IncomingOffer(Offer),
}

pub enum UIRequest {
    PairingSubscription(StreamSink<InboundPair>),
    FileSubscription(StreamSink<InboundFile>),
    GetTargetDir,
    SetTargetDir(PathBuf),
    GetLocalAddr,
    GetPeers,
}

#[derive(Reply)]
pub enum UIResponse {
    GetLocalAddr(EndpointAddr),
    GetPeers(Vec<Peer>),
    GetTargetDir(Option<PathBuf>),
    Ack,
}

#[derive(Reply)]
pub enum BGResponse {
    IncomingPair {
        reaction: Promise<UIPairReaction>,
        our_name: String,
    },
    Ack,
}

#[derive(Reply)]
pub enum ActionResponse {
    PairWith(Promise<Result<()>>),
    SendFile(Result<()>),
    Ack,
}
