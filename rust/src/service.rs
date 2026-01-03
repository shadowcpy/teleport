use std::{collections::HashMap, path::PathBuf, sync::Arc};

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
use tracing::{info, warn};

use crate::{
    api::teleport::{
        CompletedPair, FailedPair, InboundFile, InboundPair, InboundPairingEvent, UIPairReaction,
    },
    config::{ConfigManager, Peer},
    frb_generated::StreamSink,
    promise::{PromiseFinal, PromiseFinalSender, init_promise, promise},
    protocol::{
        framed::FramedBiStream,
        pair::{self, MAX_SIZE, Pair, PairAcceptor},
        send::{self, Offer, SendAcceptor},
    },
};

pub struct Dispatcher {
    manager: ConfigManager,
    router: Router,
    store: MemStore,
    temp_dir: PathBuf,
    downloader: Downloader,
    inbound_pairings: InboundPairingState,
    file_subscription: Option<StreamSink<InboundFile>>,
}

pub struct InboundPairingState {
    subscription: Option<StreamSink<InboundPairingEvent>>,
    pending_reaction: HashMap<EndpointId, PromiseFinalSender<UIPairReaction>>,
    friendly_names: HashMap<EndpointId, String>,
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

        info!("EndpointID: {}", router.endpoint().id());
        info!("Router started");

        let inbound_pairing_state = InboundPairingState {
            subscription: None,
            pending_reaction: HashMap::new(),
            friendly_names: HashMap::new(),
        };

        Ok(Self {
            manager,
            router,
            store,
            temp_dir,
            downloader,
            file_subscription: None,
            inbound_pairings: inbound_pairing_state,
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
                let result = self.pair_with(peer, pairing_code).await;
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
            BGRequest::IncomingPairStarted { from, name, code } => {
                let promise = self.incoming_pair_started(from, name, code).await;
                BGResponse::IncomingPair(promise)
            }
            BGRequest::IncomingPairFinished { peer, outcome } => {
                self.incoming_pair_finished(peer, outcome).await;
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
                self.inbound_pairings.subscription = Some(sub);
                UIResponse::Ack
            }
            UIRequest::FileSubscription(sub) => {
                self.file_subscription = Some(sub);
                UIResponse::Ack
            }
            UIRequest::ReactToPairing { peer, reaction } => {
                if let Some(sender) = self.inbound_pairings.pending_reaction.remove(&peer) {
                    match reaction {
                        UIPairReaction::Accept { .. } => {
                            sender.send(UIPairReaction::Accept {
                                our_name: self.manager.name.clone(),
                            });
                        }
                        UIPairReaction::Reject => {
                            sender.send(UIPairReaction::Reject);
                        }
                        UIPairReaction::WrongPairingCode => {
                            sender.send(UIPairReaction::WrongPairingCode);
                        }
                    }
                } else {
                    warn!("No pending pairing for {peer}, ignoring reaction");
                }
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
    ) -> PromiseFinal<UIPairReaction> {
        let (promise, reaction_sender): (
            PromiseFinal<UIPairReaction>,
            PromiseFinalSender<UIPairReaction>,
        ) = init_promise();

        if let Some(ref ui) = self.inbound_pairings.subscription {
            if self.manager.peers.iter().any(|p| p.id == from) {
                warn!("Already paired to {from}, ignoring");
                reaction_sender.send(UIPairReaction::Reject);
                return promise;
            }

            let pair = InboundPair {
                peer: from.to_string(),
                friendly_name: friendly_name.clone(),
                pairing_code,
            };

            ui.add(InboundPairingEvent::InboundPair(pair)).unwrap();

            self.inbound_pairings
                .friendly_names
                .insert(from, friendly_name);

            if let Some(stale) = self
                .inbound_pairings
                .pending_reaction
                .insert(from, reaction_sender)
            {
                stale.send(UIPairReaction::Reject);
            }
        }
        promise
    }

    pub async fn incoming_pair_finished(&mut self, peer: EndpointId, outcome: Result<()>) {
        let ui = self.inbound_pairings.subscription.as_ref().unwrap();
        let name = self.inbound_pairings.friendly_names.remove(&peer).unwrap();
        match outcome {
            Ok(_) => {
                self.manager.peers.push(Peer {
                    name: name.clone(),
                    id: peer,
                });
                self.manager.save().await.unwrap();

                ui.add(InboundPairingEvent::CompletedPair(CompletedPair {
                    peer: peer.to_string(),
                    friendly_name: name,
                }))
                .unwrap();
            }
            Err(error) => {
                ui.add(InboundPairingEvent::FailedPair(FailedPair {
                    peer: peer.to_string(),
                    friendly_name: name,
                    reason: error.to_string(),
                }))
                .unwrap();
            }
        }
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

    pub async fn pair_with(&mut self, addr: EndpointAddr, code: [u8; 6]) -> Result<()> {
        let id = addr.id;

        if self.manager.peers.iter().any(|p| p.id == id) {
            warn!("Already paired to {id}, ignoring");
            return Ok(());
        }

        let conn = self.router.endpoint().connect(addr, pair::ALPN).await?;
        let (send, recv) = conn.open_bi().await?;
        let mut framed = FramedBiStream::new((send, recv), MAX_SIZE);

        Pair::Helo {
            friendly_name: self.manager.name.clone(),
            pairing_code: code,
        }
        .send(&mut framed)
        .await?;

        let response = Pair::recv(&mut framed).await?;

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

        self.manager.peers.push(Peer {
            name: name.clone(),
            id,
        });
        self.manager.save().await?;

        Ok(())
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
    },
    IncomingPairFinished {
        peer: EndpointId,
        outcome: Result<()>,
    },
    IncomingOffer(Offer),
}

pub enum UIRequest {
    PairingSubscription(StreamSink<InboundPairingEvent>),
    FileSubscription(StreamSink<InboundFile>),
    ReactToPairing {
        peer: EndpointId,
        reaction: UIPairReaction,
    },
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
    IncomingPair(promise!(UIPairReaction)),
    Ack,
}

#[derive(Reply)]
pub enum ActionResponse {
    PairWith(Result<()>),
    SendFile(Result<()>),
    Ack,
}
