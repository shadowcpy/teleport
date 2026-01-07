use iroh::EndpointAddr;
use serde::{Deserialize, Serialize};

pub mod config;
pub mod conn_quality;
pub mod pairing;
pub mod supervisor;
pub mod transfer;

pub use config::{ConfigManager, ConfigManagerArgs, ConfigReply, ConfigRequest, Peer};
pub use conn_quality::{
    ConnQualityActor, ConnQualityActorArgs, ConnQualityReply, ConnQualityRequest,
};
pub use pairing::{
    PairWithRequest, PairWithResponse, PairingActor, PairingActorArgs, PairingReply, PairingRequest,
};
pub use supervisor::{AppSupervisor, AppSupervisorArgs, UIRequest, UIResponse};
pub use transfer::{
    SendFileRequest, TransferActor, TransferActorArgs, TransferReply, TransferRequest,
};

#[derive(Serialize, Deserialize)]
pub struct PeerInfo {
    pub addr: EndpointAddr,
    pub secret: Vec<u8>,
}
