use std::{fmt::Debug, path::PathBuf, sync::OnceLock};

use flutter_rust_bridge::frb;
use iroh::EndpointId;
use kameo::actor::{ActorRef, Spawn};
use tracing::Level;
use tracing_subscriber::{filter::Targets, layer::SubscriberExt, util::SubscriberInitExt};

use crate::{
    config::ConfigManager,
    frb_generated::{RustAutoOpaque, StreamSink},
    promise::{self, Promise, PromiseResolver},
    service::{
        ActionRequest, ActionResponse, BGRequest, BGResponse, Dispatcher, DispatcherArgs, PeerInfo,
        UIRequest, UIResponse,
    },
};

#[frb]
pub struct AppState {
    dispatcher: ActorRef<Dispatcher>,
}

#[frb]
impl AppState {
    pub async fn init(temp_dir: String, persistence_dir: String) -> anyhow::Result<Self> {
        let temp_dir = PathBuf::from(temp_dir);
        let persistence_dir = PathBuf::from(persistence_dir);
        let manager = ConfigManager::get_or_init(persistence_dir).await?;

        let args = DispatcherArgs { manager, temp_dir };
        let dispatcher = Dispatcher::spawn(args);

        Ok(AppState { dispatcher })
    }

    pub async fn get_addr(&self) -> anyhow::Result<String> {
        let response = self.dispatcher.ask(UIRequest::GetLocalAddr).await?;
        let UIResponse::GetLocalAddr(addr) = response else {
            unreachable!()
        };

        let response = self.dispatcher.ask(BGRequest::GetSecret).await?;
        let BGResponse::Secret(secret) = response else {
            unreachable!()
        };

        let info = PeerInfo { addr, secret };

        Ok(serde_json::to_string(&info)?)
    }

    pub async fn peers(&self) -> anyhow::Result<Vec<(String, String)>> {
        let response = self.dispatcher.ask(UIRequest::GetPeers).await?;
        let UIResponse::GetPeers(peers) = response else {
            unreachable!()
        };
        Ok(peers
            .iter()
            .map(|p| (p.name.clone(), p.id.to_string()))
            .collect())
    }

    pub async fn pair_with(
        &self,
        info: String,
        pairing_code: [u8; 6],
    ) -> anyhow::Result<PairingResponse> {
        let peer_info: PeerInfo = serde_json::from_str(&info)?;
        let response = self
            .dispatcher
            .ask(ActionRequest::PairWith {
                peer: peer_info.addr,
                secret: peer_info.secret,
                pairing_code,
            })
            .await?;
        let ActionResponse::PairWith(result) = response else {
            unreachable!()
        };
        Ok(result.await)
    }

    pub async fn send_file(
        &self,
        peer: String,
        name: String,
        path: String,
        progress: StreamSink<OutboundFileStatus>,
    ) -> anyhow::Result<()> {
        let id: EndpointId = peer.parse()?;
        let path = PathBuf::from(path);
        self.dispatcher
            .tell(ActionRequest::SendFile {
                to: id,
                name,
                path,
                progress,
            })
            .await?;
        Ok(())
    }

    pub async fn get_target_dir(&self) -> anyhow::Result<Option<String>> {
        let response = self.dispatcher.ask(UIRequest::GetTargetDir).await?;
        let UIResponse::GetTargetDir(dir) = response else {
            unreachable!()
        };
        Ok(dir.map(|d| d.to_string_lossy().to_string()))
    }

    pub async fn set_target_dir(&self, dir: String) -> anyhow::Result<()> {
        let path = PathBuf::from(dir);
        self.dispatcher.tell(UIRequest::SetTargetDir(path)).await?;
        Ok(())
    }

    pub async fn get_device_name(&self) -> anyhow::Result<String> {
        let response = self.dispatcher.ask(UIRequest::GetDeviceName).await?;
        let UIResponse::GetDeviceName(name) = response else {
            unreachable!()
        };
        Ok(name)
    }

    pub async fn set_device_name(&self, name: String) -> anyhow::Result<()> {
        self.dispatcher.tell(UIRequest::SetDeviceName(name)).await?;
        Ok(())
    }

    pub async fn pairing_subscription(
        &self,
        stream: StreamSink<InboundPair>,
    ) -> anyhow::Result<()> {
        self.dispatcher
            .tell(UIRequest::PairingSubscription(stream))
            .await?;
        Ok(())
    }

    pub async fn file_subscription(
        &self,
        stream: StreamSink<InboundFileEvent>,
    ) -> anyhow::Result<()> {
        self.dispatcher
            .tell(UIRequest::FileSubscription(stream))
            .await?;
        Ok(())
    }
}

#[frb]
pub enum OutboundFileStatus {
    Progress { offset: u64, size: u64 },
    Done,
    Error(String),
}

#[frb]
pub struct InboundFileEvent {
    pub peer: String,
    pub name: String,
    pub event: InboundFileStatus,
}

#[frb]
pub enum InboundFileStatus {
    Progress { offset: u64, size: u64 },
    Done { path: String, name: String },
    Error(String),
}

#[frb]
pub struct InboundPair {
    pub peer: String,
    pub friendly_name: String,
    pub pairing_code: [u8; 6],
    pub reaction: RustAutoOpaque<UIResolver<UIPairReaction>>,
    pub outcome: RustAutoOpaque<UIPromise<Result<(), String>>>,
}

impl InboundPair {
    pub async fn react(&self, reaction: UIPairReaction) {
        self.reaction.write().await.resolve(reaction);
    }
    pub async fn result(&self) -> Result<(), String> {
        self.outcome.write().await.result().await
    }
}

#[frb(opaque)]
pub struct UIPromise<T>(Option<Promise<T>>);

impl<T: Debug> UIPromise<T> {
    pub fn new(promise: promise::Promise<T>) -> Self {
        Self(Some(promise))
    }
    pub async fn result(&mut self) -> T {
        self.0.take().unwrap().await
    }
}

#[frb(opaque)]
pub struct UIResolver<T>(Option<PromiseResolver<T>>);

impl<T: Debug> UIResolver<T> {
    pub fn new(sender: PromiseResolver<T>) -> Self {
        Self(Some(sender))
    }
    pub fn resolve(&mut self, value: T) {
        self.0.take().unwrap().emit(value);
    }
}

#[frb]
#[derive(Debug)]
pub enum UIPairReaction {
    Accept,
    Reject,
    WrongPairingCode,
}

#[frb]
#[derive(Debug)]
pub enum PairingResponse {
    Success,
    WrongCode,
    WrongSecret,
    Error(String),
}

#[frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
    init_logging();
}

static TRACING_INIT: OnceLock<()> = OnceLock::new();

pub fn init_logging() {
    TRACING_INIT.get_or_init(|| {
        let filter = Targets::new()
            .with_default(Level::INFO)
            .with_target("netlink_packet_route::link::buffer_tool", Level::ERROR);

        let builder = tracing_subscriber::registry();

        #[cfg(target_os = "android")]
        let builder = builder.with(tracing_android::layer("my-rust-lib").unwrap());
        #[cfg(not(target_os = "android"))]
        let builder = builder.with(tracing_subscriber::fmt::layer());

        builder.with(filter).init();
    });
}
