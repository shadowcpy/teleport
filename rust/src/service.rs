use std::{path::PathBuf, sync::Arc};

use anyhow::Result;
use iroh::{
    discovery::mdns::MdnsDiscoveryBuilder,
    endpoint::{presets, Builder},
    protocol::Router,
    EndpointAddr, EndpointId, PublicKey,
};
use iroh_blobs::{api::downloader::Downloader, store::mem::MemStore, BlobsProtocol};
use tokio::{
    spawn,
    sync::{
        mpsc::{self, Receiver},
        oneshot,
    },
};
use tracing::{info, warn};

use crate::{
    config::{ConfigManager, Peer},
    frb_generated::StreamSink,
    protocol::{self, Pair},
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
        let service_handle = ServiceHandle { sender };

        info!("EndpointID: {}", endpoint.id());

        let store = MemStore::new();

        let blobs = BlobsProtocol::new(&store, None);

        let downloader = store.downloader(&endpoint);

        let handle = service_handle.clone();
        let router = Router::builder(endpoint)
            .accept(iroh_blobs::ALPN, blobs)
            .accept(protocol::ALPN.to_vec(), Arc::new(Pair { handle }))
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

        Ok(service_handle)
    }

    async fn main(mut self, mut channel: Receiver<RequestContainer>) {
        let mut pairing_subscription: Option<StreamSink<String>> = None;

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
            };

            msg.response.send(response).ok();
        }
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

        let conn = self.router.endpoint().connect(addr, protocol::ALPN).await?;
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
    GetLocalAddr,
    GetPeers,
}

pub enum ServiceResponse {
    PairWith(Result<()>),
    GetLocalAddr(EndpointAddr),
    GetPeers(Vec<Peer>),
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

// pub async fn provide_file(&self, path: String) -> anyhow::Result<String> {
//     let path = Path::new(&path);
//     let tag = self.store.blobs().add_path(path).await?;
//     let endpoint_id = self.router.endpoint().id();
//     let ticket = BlobTicket::new(endpoint_id.into(), tag.hash, tag.format);
//     Ok(ticket.to_string())
// }
// pub async fn download_file(&self, ticket: String) -> anyhow::Result<String> {
//     let ticket: BlobTicket = ticket.parse()?;
//     self.downloader
//         .download(ticket.hash(), Some(ticket.addr().id))
//         .await?;
//     let path = self.temp_dir.join(ticket.hash().to_string());
//     self.store.blobs().export(ticket.hash(), &path).await?;
//     Ok(path.to_string_lossy().to_string())
// }
