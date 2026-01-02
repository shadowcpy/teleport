use std::{path::PathBuf, sync::Arc};

use anyhow::Result;
use iroh::{
    discovery::mdns::MdnsDiscoveryBuilder,
    endpoint::{presets, Builder},
    protocol::Router,
    EndpointAddr, EndpointId, PublicKey,
};
use iroh_blobs::{
    api::downloader::Downloader, store::mem::MemStore, ticket::BlobTicket, BlobsProtocol,
};
use tokio::{
    spawn,
    sync::{
        mpsc::{self, Receiver},
        oneshot,
    },
};
use tracing::{info, warn};

use crate::{
    api::teleport::InboundFile,
    config::{ConfigManager, Peer},
    frb_generated::StreamSink,
    protocol::{
        pair::{self, Pair},
        send::{self, Offer, Send},
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
                Arc::new(Pair {
                    handle: handle.clone(),
                }),
            )
            .accept(
                send::ALPN.to_vec(),
                Arc::new(Send {
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
        let mut pairing_subscription: Option<StreamSink<String>> = None;
        let mut file_subscription: Option<StreamSink<InboundFile>> = None;

        while let Some(msg) = channel.recv().await {
            let response = match msg.payload {
                ServiceRequest::IncomingPair(public_key) => {
                    self.incoming_pair(public_key, pairing_subscription.as_ref())
                        .await;
                    ServiceResponse::Ack
                }
                ServiceRequest::PairingSubscription(sub) => {
                    pairing_subscription = Some(sub);
                    ServiceResponse::Ack
                }
                ServiceRequest::FileSubscription(sub) => {
                    file_subscription = Some(sub);
                    ServiceResponse::Ack
                }
                ServiceRequest::PairWith(addr) => {
                    let result = self.pair_with(addr).await;
                    ServiceResponse::PairWith(result)
                }
                ServiceRequest::GetLocalAddr => {
                    let addr = self.router.endpoint().addr();
                    ServiceResponse::GetLocalAddr(addr)
                }
                ServiceRequest::GetPeers => {
                    let peers = self.manager.peers.clone();
                    ServiceResponse::GetPeers(peers)
                }
                ServiceRequest::IncomingOffer(offer) => {
                    self.incoming_offer(offer, file_subscription.as_ref())
                        .await
                        .unwrap();
                    ServiceResponse::Ack
                }
                ServiceRequest::SendFile((peer, name, path)) => {
                    let result = self.send_file(peer, name, path).await;
                    ServiceResponse::SendFile(result)
                }
                ServiceRequest::SetTargetDir(path_buf) => {
                    self.manager.target_dir = Some(path_buf);
                    self.manager.save().await.unwrap();
                    ServiceResponse::Ack
                }
                ServiceRequest::GetTargetDir => {
                    let dir = self.manager.target_dir.clone();
                    ServiceResponse::GetTargetDir(dir)
                }
            };
            msg.response.send(response).ok();
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

    pub async fn incoming_pair(&mut self, id: PublicKey, sub: Option<&StreamSink<String>>) {
        if self.manager.peers.iter().any(|p| p.id == id) {
            warn!("Already paired to {id}, ignoring");
            return;
        }
        self.manager.peers.push(Peer {
            name: "Jürgen".into(),
            id,
        });

        self.manager.save().await.unwrap();

        if let Some(notify) = sub {
            notify.add(id.to_string()).unwrap();
        }
    }

    pub async fn pair_with(&mut self, addr: EndpointAddr) -> Result<()> {
        let id = addr.id;

        if self.manager.peers.iter().any(|p| p.id == id) {
            warn!("Already paired to {id}, ignoring");
            return Ok(());
        }

        let conn = self.router.endpoint().connect(addr, pair::ALPN).await?;
        // Open a bidirectional QUIC stream
        let (mut send, mut recv) = conn.open_bi().await?;
        // Send some data to be echoed
        send.write_all(b"Hello, world!").await?;
        send.finish()?;

        // Receive the echo
        let response = recv.read_to_end(1000).await?;
        assert_eq!(&response, b"Hello, world!");

        // As the side receiving the last application data - say goodbye
        conn.close(0u32.into(), b"bye!");

        info!("Paired to {}", id);

        self.manager.peers.push(Peer {
            name: "Jürgen".into(),
            id,
        });

        self.manager.save().await?;

        Ok(())
    }
}

pub enum ServiceRequest {
    PairWith(EndpointAddr),
    IncomingPair(EndpointId),
    PairingSubscription(StreamSink<String>),
    FileSubscription(StreamSink<InboundFile>),
    IncomingOffer(Offer),
    SendFile((EndpointId, String, PathBuf)),
    GetTargetDir,
    SetTargetDir(PathBuf),
    GetLocalAddr,
    GetPeers,
}

pub enum ServiceResponse {
    PairWith(Result<()>),
    GetLocalAddr(EndpointAddr),
    GetPeers(Vec<Peer>),
    SendFile(Result<()>),
    GetTargetDir(Option<PathBuf>),
    Ack,
}

pub struct RequestContainer {
    payload: ServiceRequest,
    response: oneshot::Sender<ServiceResponse>,
}

#[derive(Debug, Clone)]
pub struct ServiceHandle {
    sender: mpsc::Sender<RequestContainer>,
}

impl ServiceHandle {
    pub async fn call(&self, payload: ServiceRequest) -> Result<ServiceResponse> {
        let (snd, rcv) = oneshot::channel();
        self.sender
            .send(RequestContainer {
                payload,
                response: snd,
            })
            .await?;
        Ok(rcv.await?)
    }
}
