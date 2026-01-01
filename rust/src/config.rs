use std::{
    ops::{Deref, DerefMut},
    path::PathBuf,
};

use iroh::{EndpointId, SecretKey};
use rand::rng;
use serde::{Deserialize, Serialize};
use tokio::fs;
use tracing::info;

const CONFIG_FILE: &str = "storage.toml";

#[derive(Serialize, Deserialize)]
pub struct Config {
    pub key: SecretKey,
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
            peers: vec![],
        }
    }
}

pub struct ConfigManager {
    path: PathBuf,
    config: Config,
}

impl ConfigManager {
    pub async fn get_or_init(persistence_dir: PathBuf) -> anyhow::Result<Self> {
        let path = persistence_dir.join(CONFIG_FILE);

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

    pub async fn save(&self) -> anyhow::Result<()> {
        let config_str = toml_edit::ser::to_string_pretty(&self.config)?;
        fs::write(&self.path, &config_str).await?;
        Ok(())
    }
}

impl Deref for ConfigManager {
    type Target = Config;

    fn deref(&self) -> &Self::Target {
        &self.config
    }
}

impl DerefMut for ConfigManager {
    fn deref_mut(&mut self) -> &mut Self::Target {
        &mut self.config
    }
}
