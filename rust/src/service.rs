use std::{collections::HashMap, path::PathBuf, sync::Arc};

use anyhow::{bail, Result};
use derive_more::{From, Unwrap};
use iroh::{
    discovery::mdns::MdnsDiscoveryBuilder,
    endpoint::{presets, Builder},
    protocol::Router,
    EndpointAddr, EndpointId,
};
use iroh_blobs::{
    api::downloader::Downloader, store::mem::MemStore, ticket::BlobTicket, BlobsProtocol,
};
use rand::Rng;
use tokio::{
    spawn,
    sync::{
        mpsc::{self, Receiver},
        oneshot,
    },
};
use tracing::{info, warn};

use crate::{
    api::teleport::{
        CompletedPair, FailedPair, InboundFile, InboundPair, InboundPairingEvent,
        OutboundPairingEvent,
    },
    config::{ConfigManager, Peer},
    frb_generated::StreamSink,
    protocol::{
        framed::FramedBiStream,
        pair::{self, Pair, PairAcceptor, MAX_SIZE},
        send::{self, Offer, SendAcceptor},
    },
};

pub struct Service {
    manager: ConfigManager,
    router: Router,
    store: MemStore,
    temp_dir: PathBuf,
    downloader: Downloader,
}

impl Service {
    pub async fn spawn(manager: ConfigManager, temp_dir: PathBuf) -> Result<ServiceHandle> {
        let endpoint = Builder::new(presets::N0)
            .discovery(MdnsDiscoveryBuilder::default())
            .secret_key(manager.key.clone())
            .bind()
            .await?;

        let (sender, receiver) = mpsc::channel(16);
        let handle = ServiceHandle { sender };

        info!("EndpointID: {}", endpoint.id());

        let store = MemStore::new();

        let blobs = BlobsProtocol::new(&store, None);

        let downloader = store.downloader(&endpoint);

        let router = Router::builder(endpoint)
            .accept(iroh_blobs::ALPN, blobs)
            .accept(
                pair::ALPN.to_vec(),
                Arc::new(PairAcceptor {
                    handle: handle.clone(),
                }),
            )
            .accept(
                send::ALPN.to_vec(),
                Arc::new(SendAcceptor {
                    handle: handle.clone(),
                }),
            )
            .spawn();

        info!("Router started");

        let this = Self {
            manager,
            router,
            store,
            temp_dir,
            downloader,
        };

        spawn(this.main(receiver));

        Ok(handle)
    }

    async fn main(mut self, mut channel: Receiver<RequestContainer>) {
        let mut in_pairing_subscription: Option<StreamSink<InboundPairingEvent>> = None;
        let mut out_pairing_subscription: Option<StreamSink<OutboundPairingEvent>> = None;
        let mut file_subscription: Option<StreamSink<InboundFile>> = None;

        let mut pending_incoming_pairings = HashMap::new();

        while let Some(msg) = channel.recv().await {
            let response = match msg.payload {
                Request::ActionRequest(action) => match action {
                    ActionRequest::PairWith(addr) => {
                        self.pair_with(addr, out_pairing_subscription.as_ref())
                            .await
                            .unwrap();
                        Response::Ack
                    }
                    ActionRequest::SendFile { to, name, path } => {
                        let result = self.send_file(to, name, path).await;
                        ActionResponse::SendFile(result).into()
                    }
                },
                Request::BGRequest(bg) => match bg {
                    BGRequest::IncomingPair {
                        from,
                        friendly_name,
                        pairing_code,
                    } => {
                        let (respond, later) = delayed_response();
                        if let Some(ref notify) = in_pairing_subscription {
                            let pair = InboundPair {
                                peer: from.to_string(),
                                friendly_name,
                                pairing_code,
                            };
                            notify.add(InboundPairingEvent::InboundPair(pair)).unwrap();
                            if let Some(stale) = pending_incoming_pairings.insert(from, respond) {
                                stale.send(UIDoPair::Reject).unwrap();
                            }
                        }
                        BGResponse::IncomingPair(later).into()
                    }
                    BGRequest::FinalizePair {
                        with,
                        friendly_name,
                        outcome,
                    } => {
                        if let Err(e) = outcome {
                            if let Some(ref notify) = in_pairing_subscription {
                                notify
                                    .add(InboundPairingEvent::FailedPair(FailedPair {
                                        peer: with.to_string(),
                                        friendly_name,
                                        reason: e.to_string(),
                                    }))
                                    .unwrap();
                            }
                        } else {
                            self.manager.peers.push(Peer {
                                name: friendly_name.clone(),
                                id: with,
                            });
                            self.manager.save().await.unwrap();
                            if let Some(ref notify) = in_pairing_subscription {
                                notify
                                    .add(InboundPairingEvent::CompletedPair(CompletedPair {
                                        peer: with.to_string(),
                                        friendly_name,
                                    }))
                                    .unwrap();
                            }
                        }
                        Response::Ack
                    }
                    BGRequest::IncomingOffer(offer) => {
                        self.incoming_offer(offer, file_subscription.as_ref())
                            .await
                            .unwrap();
                        Response::Ack
                    }
                },
                Request::UIRequest(ui) => match ui {
                    UIRequest::InPairingSubscription(sub) => {
                        in_pairing_subscription = Some(sub);
                        Response::Ack
                    }
                    UIRequest::OutPairingSubscription(sub) => {
                        out_pairing_subscription = Some(sub);
                        Response::Ack
                    }
                    UIRequest::FileSubscription(sub) => {
                        file_subscription = Some(sub);
                        Response::Ack
                    }
                    UIRequest::SetTargetDir(path_buf) => {
                        self.manager.target_dir = Some(path_buf);
                        self.manager.save().await.unwrap();
                        Response::Ack
                    }
                    UIRequest::GetTargetDir => {
                        let dir = self.manager.target_dir.clone();
                        UIResponse::GetTargetDir(dir).into()
                    }
                    UIRequest::GetLocalAddr => {
                        let addr = self.router.endpoint().addr();
                        UIResponse::GetLocalAddr(addr).into()
                    }
                    UIRequest::GetPeers => {
                        let peers = self.manager.peers.clone();
                        UIResponse::GetPeers(peers).into()
                    }
                },
            };
            msg.response.send(response.into()).ok();
        }
    }

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
        if let Some(notify) = sub {
            notify
                .add(InboundFile {
                    peer: ticket.addr().id.to_string(),
                    name: offer.name,
                    size: offer.size,
                    path: path.to_string_lossy().to_string(),
                })
                .unwrap();
        }
        Ok(())
    }

    pub async fn pair_with(
        &mut self,
        addr: EndpointAddr,
        sub: Option<&StreamSink<OutboundPairingEvent>>,
    ) -> Result<()> {
        let id = addr.id;

        if self.manager.peers.iter().any(|p| p.id == id) {
            warn!("Already paired to {id}, ignoring");
            return Ok(());
        }

        let Some(sub) = sub else {
            bail!("Cannot pair without subscription");
        };

        let conn = self.router.endpoint().connect(addr, pair::ALPN).await?;
        let (send, recv) = conn.open_bi().await?;
        let mut framed = FramedBiStream::new((send, recv), MAX_SIZE);

        let rand: [u8; 6] = rand::rng().random();

        sub.add(OutboundPairingEvent::Created(rand)).unwrap();

        Pair::Helo {
            friendly_name: self.manager.name.clone(),
            pairing_code: rand,
        }
        .send(&mut framed)
        .await?;

        let response = Pair::recv(&mut framed).await?;

        let name = match response {
            Pair::FuckOff => {
                sub.add(OutboundPairingEvent::FailedPair(FailedPair {
                    peer: id.to_string(),
                    friendly_name: String::new(),
                    reason: "Fucked off".into(),
                }))
                .unwrap();
                return Ok(());
            }
            Pair::NiceToMeetYou { friendly_name } => friendly_name,
            Pair::WrongPairingCode => {
                sub.add(OutboundPairingEvent::FailedPair(FailedPair {
                    peer: id.to_string(),
                    friendly_name: String::new(),
                    reason: "Wrong Pairing Code".into(),
                }))
                .unwrap();
                return Ok(());
            }
            _ => bail!("Invalid msg type"),
        };

        self.manager.peers.push(Peer {
            name: name.clone(),
            id,
        });
        self.manager.save().await?;

        sub.add(OutboundPairingEvent::CompletedPair(CompletedPair {
            peer: id.to_string(),
            friendly_name: name,
        }))
        .unwrap();

        Ok(())
    }
}

#[derive(From)]
pub enum Request {
    UIRequest(UIRequest),
    ActionRequest(ActionRequest),
    BGRequest(BGRequest),
}

pub enum ActionRequest {
    PairWith(EndpointAddr),
    SendFile {
        to: EndpointId,
        name: String,
        path: PathBuf,
    },
}

pub enum BGRequest {
    IncomingPair {
        from: EndpointId,
        friendly_name: String,
        pairing_code: [u8; 6],
    },
    FinalizePair {
        with: EndpointId,
        friendly_name: String,
        outcome: Result<()>,
    },
    IncomingOffer(Offer),
}

pub enum UIRequest {
    InPairingSubscription(StreamSink<InboundPairingEvent>),
    OutPairingSubscription(StreamSink<OutboundPairingEvent>),
    FileSubscription(StreamSink<InboundFile>),
    GetTargetDir,
    SetTargetDir(PathBuf),
    GetLocalAddr,
    GetPeers,
}

pub struct RequestContainer {
    payload: Request,
    response: oneshot::Sender<Response>,
}

#[derive(From, Unwrap)]
pub enum Response {
    UIResponse(UIResponse),
    BGResponse(BGResponse),
    ActionResponse(ActionResponse),
    Ack,
}

pub enum UIResponse {
    GetLocalAddr(EndpointAddr),
    GetPeers(Vec<Peer>),
    GetTargetDir(Option<PathBuf>),
}

pub enum BGResponse {
    IncomingPair(DelayedResponse<UIDoPair>),
}

pub enum ActionResponse {
    PairWith(Result<()>),
    SendFile(Result<()>),
}

pub type DelayedResponse<T> = oneshot::Receiver<T>;

pub fn delayed_response<T>() -> (oneshot::Sender<T>, oneshot::Receiver<T>) {
    oneshot::channel()
}

#[derive(Debug)]
pub enum UIDoPair {
    Accept { our_name: String },
    Reject,
    WrongPairingCode,
}

#[derive(Debug, Clone)]
pub struct ServiceHandle {
    sender: mpsc::Sender<RequestContainer>,
}

impl ServiceHandle {
    pub async fn call(&self, payload: impl Into<Request>) -> Result<Response> {
        let (snd, rcv) = oneshot::channel();
        self.sender
            .send(RequestContainer {
                payload: payload.into(),
                response: snd,
            })
            .await?;
        Ok(rcv.await?)
    }
}
