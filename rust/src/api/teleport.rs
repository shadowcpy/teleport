use std::{path::PathBuf, sync::OnceLock};

use flutter_rust_bridge::frb;
use iroh::{EndpointAddr, EndpointId};
use tracing::Level;
use tracing_subscriber::{filter::Targets, layer::SubscriberExt, util::SubscriberInitExt};

use crate::{
    config::ConfigManager,
    frb_generated::StreamSink,
    service::{ActionRequest, ActionResponse, Service, ServiceHandle, UIRequest, UIResponse},
};

#[frb]
pub struct AppState {
    service: ServiceHandle,
}

#[frb]
impl AppState {
    pub async fn init(temp_dir: String, persistence_dir: String) -> anyhow::Result<Self> {
        let temp_dir = PathBuf::from(temp_dir);
        let persistence_dir = PathBuf::from(persistence_dir);
        let config = ConfigManager::get_or_init(persistence_dir).await?;

        let service = Service::spawn(config, temp_dir).await?;

        Ok(AppState { service })
    }

    pub async fn get_addr(&self) -> anyhow::Result<String> {
        let response = self.service.call(UIRequest::GetLocalAddr).await?;
        let UIResponse::GetLocalAddr(addr) = response.unwrap_ui_response() else {
            unreachable!()
        };
        let info = serde_json::to_string(&addr)?;
        Ok(info)
    }

    pub async fn peers(&self) -> anyhow::Result<Vec<(String, String)>> {
        let response = self.service.call(UIRequest::GetPeers).await?;
        let UIResponse::GetPeers(peers) = response.unwrap_ui_response() else {
            unreachable!()
        };
        Ok(peers
            .iter()
            .map(|p| (p.name.clone(), p.id.to_string()))
            .collect())
    }

    pub async fn pair_with(&self, info: String) -> anyhow::Result<()> {
        let addr: EndpointAddr = serde_json::from_str(&info)?;
        self.service.call(ActionRequest::PairWith(addr)).await?;
        Ok(())
    }

    pub async fn send_file(&self, peer: String, name: String, path: String) -> anyhow::Result<()> {
        let id: EndpointId = peer.parse()?;
        let path = PathBuf::from(path);
        let response = self
            .service
            .call(ActionRequest::SendFile { to: id, name, path })
            .await?;
        let ActionResponse::SendFile(result) = response.unwrap_action_response() else {
            unreachable!()
        };
        result
    }

    pub async fn get_target_dir(&self) -> anyhow::Result<Option<String>> {
        let response = self.service.call(UIRequest::GetTargetDir).await?;
        let UIResponse::GetTargetDir(dir) = response.unwrap_ui_response() else {
            unreachable!()
        };
        Ok(dir.map(|d| d.to_string_lossy().to_string()))
    }

    pub async fn set_target_dir(&self, dir: String) -> anyhow::Result<()> {
        let path = PathBuf::from(dir);
        self.service.call(UIRequest::SetTargetDir(path)).await?;
        Ok(())
    }

    pub async fn inbound_pairing_subscription(
        &self,
        stream: StreamSink<InboundPairingEvent>,
    ) -> anyhow::Result<()> {
        self.service
            .call(UIRequest::InPairingSubscription(stream))
            .await?;
        Ok(())
    }

    pub async fn outbound_pairing_subscription(
        &self,
        stream: StreamSink<OutboundPairingEvent>,
    ) -> anyhow::Result<()> {
        self.service
            .call(UIRequest::OutPairingSubscription(stream))
            .await?;
        Ok(())
    }

    pub async fn file_subscription(&self, stream: StreamSink<InboundFile>) -> anyhow::Result<()> {
        self.service
            .call(UIRequest::FileSubscription(stream))
            .await?;
        Ok(())
    }
}

#[frb]
pub struct InboundFile {
    pub peer: String,
    pub name: String,
    pub size: u64,
    pub path: String,
}

#[frb]
pub enum InboundPairingEvent {
    InboundPair(InboundPair),
    CompletedPair(CompletedPair),
    FailedPair(FailedPair),
}

#[frb]
pub struct InboundPair {
    pub peer: String,
    pub friendly_name: String,
    pub pairing_code: [u8; 6],
}

#[frb]
pub enum OutboundPairingEvent {
    Created([u8; 6]),
    CompletedPair(CompletedPair),
    FailedPair(FailedPair),
}

#[frb]
pub struct CompletedPair {
    pub peer: String,
    pub friendly_name: String,
}

#[frb]
pub struct FailedPair {
    pub peer: String,
    pub friendly_name: String,
    pub reason: String,
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
