use std::path::PathBuf;

use anyhow::Result;
use iroh::{EndpointId, SecretKey};
use kameo::prelude::*;
use rand::rng;
use serde::{Deserialize, Serialize};
use tokio::fs;
use tracing::info;

const CONFIG_FILE: &str = "storage.toml";

#[derive(Serialize, Deserialize)]
pub struct Config {
    pub key: SecretKey,
    pub name: String,
    pub target_dir: Option<PathBuf>,
    pub peers: Vec<Peer>,
}

#[derive(Serialize, Deserialize, Clone)]
pub struct Peer {
    pub name: String,
    pub id: EndpointId,
}

impl Default for Config {
    fn default() -> Self {
        Self {
            key: SecretKey::generate(&mut rng()),
            target_dir: None,
            peers: vec![],
            name: "Unnamed".into(),
        }
    }
}

pub struct ConfigManager {
    path: PathBuf,
    config: Config,
}

pub struct ConfigManagerArgs {
    pub persistence_dir: PathBuf,
}

impl Actor for ConfigManager {
    type Args = ConfigManagerArgs;
    type Error = anyhow::Error;

    async fn on_start(args: Self::Args, _actor_ref: ActorRef<Self>) -> Result<Self, Self::Error> {
        let path = args.persistence_dir.join(CONFIG_FILE);

        let config = if !fs::try_exists(&path).await? {
            let default_config = Config::default();
            let default_config_str = toml_edit::ser::to_string_pretty(&default_config)?;
            fs::write(&path, &default_config_str).await?;
            default_config
        } else {
            let config = fs::read_to_string(&path).await?;
            let config: Config = toml_edit::de::from_str(&config)?;
            info!("Restored secret key from storage");
            config
        };

        Ok(Self { path, config })
    }
}

impl ConfigManager {
    async fn save(&self) -> anyhow::Result<()> {
        let config_str = toml_edit::ser::to_string_pretty(&self.config)?;
        fs::write(&self.path, &config_str).await?;
        Ok(())
    }
}

pub enum ConfigRequest {
    GetKey,
    GetPeers,
    GetPeerName(EndpointId),
    IsPeerKnown(EndpointId),
    RegisterPeer(Peer),
    GetTargetDir,
    SetTargetDir(PathBuf),
    GetDeviceName,
    SetDeviceName(String),
}

#[derive(Reply)]
pub enum ConfigReply {
    Key(SecretKey),
    Peers(Vec<Peer>),
    PeerName(Option<String>),
    IsPeerKnown(bool),
    TargetDir(Option<PathBuf>),
    DeviceName(String),
    Ack,
}

impl Message<ConfigRequest> for ConfigManager {
    type Reply = ConfigReply;

    async fn handle(
        &mut self,
        msg: ConfigRequest,
        _ctx: &mut Context<Self, Self::Reply>,
    ) -> Self::Reply {
        match msg {
            ConfigRequest::GetKey => ConfigReply::Key(self.config.key.clone()),
            ConfigRequest::GetPeers => ConfigReply::Peers(self.config.peers.clone()),
            ConfigRequest::GetPeerName(peer) => ConfigReply::PeerName(
                self.config
                    .peers
                    .iter()
                    .find(|p| p.id == peer)
                    .map(|p| p.name.clone()),
            ),
            ConfigRequest::IsPeerKnown(peer) => {
                ConfigReply::IsPeerKnown(self.config.peers.iter().any(|p| p.id == peer))
            }
            ConfigRequest::RegisterPeer(peer) => {
                if let Some(existing) = self.config.peers.iter_mut().find(|p| p.id == peer.id) {
                    existing.name = peer.name;
                } else {
                    self.config.peers.push(peer);
                }
                self.save().await.unwrap();
                ConfigReply::Ack
            }
            ConfigRequest::GetTargetDir => {
                let dir = self.config.target_dir.clone();
                ConfigReply::TargetDir(dir)
            }
            ConfigRequest::SetTargetDir(path_buf) => {
                self.config.target_dir = Some(path_buf);
                self.save().await.unwrap();
                ConfigReply::Ack
            }
            ConfigRequest::GetDeviceName => ConfigReply::DeviceName(self.config.name.clone()),
            ConfigRequest::SetDeviceName(name) => {
                self.config.name = name;
                self.save().await.unwrap();
                ConfigReply::Ack
            }
        }
    }
}
