use std::{path::PathBuf, sync::OnceLock};

use flutter_rust_bridge::frb;
use iroh::EndpointAddr;
use tracing::Level;
use tracing_subscriber::{filter::Targets, layer::SubscriberExt, util::SubscriberInitExt};

use crate::{
    config::ConfigManager,
    frb_generated::StreamSink,
    service::{Service, ServiceHandle, ServiceRequest, ServiceResponse},
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
        let response = self.service.call(ServiceRequest::GetLocalAddr).await?;
        let ServiceResponse::GetLocalAddr(addr) = response else {
            unreachable!()
        };
        let info = serde_json::to_string(&addr)?;
        Ok(info)
    }

    pub async fn peers(&self) -> anyhow::Result<Vec<(String, String)>> {
        let response = self.service.call(ServiceRequest::GetPeers).await?;
        let ServiceResponse::GetPeers(peers) = response else {
            unreachable!()
        };
        Ok(peers
            .iter()
            .map(|p| (p.name.clone(), p.id.to_string()))
            .collect())
    }

    pub async fn pair_with(&self, info: String) -> anyhow::Result<()> {
        let addr: EndpointAddr = serde_json::from_str(&info)?;
        let response = self.service.call(ServiceRequest::PairWith(addr)).await?;
        let ServiceResponse::PairWith(result) = response else {
            unreachable!()
        };
        result
    }

    pub async fn pairing_subscription(&self, stream: StreamSink<String>) -> anyhow::Result<()> {
        self.service
            .call(ServiceRequest::PairingSubscription(stream))
            .await?;
        Ok(())
    }
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
