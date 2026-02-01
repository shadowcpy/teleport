use std::{path::PathBuf, sync::Arc};

use anyhow::Result;
use iroh::{
    EndpointAddr,
    endpoint::{Builder, QuicTransportConfig, presets},
    protocol::Router,
};
use kameo::prelude::*;
use tracing::info;

use crate::{
    api::teleport::{InboundFileEvent, InboundPair, UIConnectionQualityUpdate},
    frb_generated::StreamSink,
    protocol::{keepalive, pair, send},
    service::Peer,
};

use super::{
    ConfigManager, ConfigManagerArgs, ConfigReply, ConfigRequest, ConnQualityActor,
    ConnQualityReply, ConnQualityRequest, KeepAliveActor, KeepAliveActorArgs, PairWithRequest,
    PairWithResponse, PairingActor, PairingActorArgs, PairingReply, PairingRequest, SendFileRequest,
    TransferActor, TransferActorArgs, TransferReply, TransferRequest,
};

pub struct AppSupervisor {
    router: Arc<Router>,
    config: ActorRef<ConfigManager>,
    pairing: ActorRef<PairingActor>,
    transfer: ActorRef<TransferActor>,
    conn_quality: ActorRef<ConnQualityActor>,
    keepalive: ActorRef<KeepAliveActor>,
}

pub struct AppSupervisorArgs {
    pub persistence_dir: PathBuf,
}

impl Actor for AppSupervisor {
    type Args = AppSupervisorArgs;
    type Error = anyhow::Error;

    async fn on_start(args: Self::Args, actor_ref: ActorRef<Self>) -> Result<Self, Self::Error> {
        let AppSupervisorArgs { persistence_dir } = args;

        let config = ConfigManager::spawn(ConfigManagerArgs { persistence_dir });
        let response = config.ask(ConfigRequest::GetKey).await?;
        let ConfigReply::Key(key) = response else {
            unreachable!()
        };
        let mut transport_config = QuicTransportConfig::builder();
        if cfg!(target_os = "android") {
            transport_config = transport_config.enable_segmentation_offload(false);
        }

        let endpoint = Builder::new(presets::N0)
            .secret_key(key)
            .transport_config(transport_config.build())
            .bind()
            .await?;

        let router = Router::builder(endpoint)
            .accept(
                pair::ALPN.to_vec(),
                Arc::new(pair::PairAcceptor {
                    app: actor_ref.clone(),
                }),
            )
            .accept(
                send::ALPN.to_vec(),
                Arc::new(send::SendAcceptor {
                    app: actor_ref.clone(),
                }),
            )
            .accept(
                keepalive::ALPN.to_vec(),
                Arc::new(keepalive::KeepAliveAcceptor {
                    app: actor_ref.clone(),
                }),
            )
            .spawn();

        let router = Arc::new(router);

        info!("EndpointID: {}", router.endpoint().id());
        info!("Router started");

        let conn_quality = ConnQualityActor::spawn(());
        let pairing = PairingActor::spawn(PairingActorArgs {
            config: config.clone(),
            router: router.clone(),
        });
        let transfer = TransferActor::spawn(TransferActorArgs {
            config: config.clone(),
            conn_quality: conn_quality.clone(),
            router: router.clone(),
        });
        let keepalive = KeepAliveActor::spawn(KeepAliveActorArgs {
            config: config.clone(),
            conn_quality: conn_quality.clone(),
            router: router.clone(),
        });

        Ok(Self {
            router,
            config,
            pairing,
            transfer,
            conn_quality,
            keepalive,
        })
    }
}

impl Message<PairWithRequest> for AppSupervisor {
    type Reply = PairWithResponse;

    async fn handle(
        &mut self,
        msg: PairWithRequest,
        _ctx: &mut Context<Self, Self::Reply>,
    ) -> Self::Reply {
        self.pairing.ask(msg).await.unwrap()
    }
}

impl Message<SendFileRequest> for AppSupervisor {
    type Reply = ();

    async fn handle(
        &mut self,
        msg: SendFileRequest,
        _ctx: &mut Context<Self, Self::Reply>,
    ) -> Self::Reply {
        self.transfer.tell(msg).await.unwrap();
    }
}

impl Message<PairingRequest> for AppSupervisor {
    type Reply = PairingReply;

    async fn handle(
        &mut self,
        msg: PairingRequest,
        _ctx: &mut Context<Self, Self::Reply>,
    ) -> Self::Reply {
        self.pairing.ask(msg).await.unwrap()
    }
}

impl Message<TransferRequest> for AppSupervisor {
    type Reply = TransferReply;

    async fn handle(
        &mut self,
        msg: TransferRequest,
        _ctx: &mut Context<Self, Self::Reply>,
    ) -> Self::Reply {
        self.transfer.ask(msg).await.unwrap()
    }
}

impl Message<ConnQualityRequest> for AppSupervisor {
    type Reply = ConnQualityReply;

    async fn handle(
        &mut self,
        msg: ConnQualityRequest,
        _ctx: &mut Context<Self, Self::Reply>,
    ) -> Self::Reply {
        self.conn_quality.ask(msg).await.unwrap()
    }
}

impl Message<UIRequest> for AppSupervisor {
    type Reply = UIResponse;

    async fn handle(
        &mut self,
        msg: UIRequest,
        _ctx: &mut Context<Self, Self::Reply>,
    ) -> Self::Reply {
        match msg {
            UIRequest::PairingSubscription(sub) => {
                self.pairing
                    .tell(PairingRequest::PairingSubscription(sub))
                    .await
                    .unwrap();
                UIResponse::Ack
            }
            UIRequest::FileSubscription(sub) => {
                self.transfer
                    .tell(TransferRequest::FileSubscription(sub))
                    .await
                    .unwrap();
                UIResponse::Ack
            }
            UIRequest::ConnQualitySubscription(sub) => {
                self.conn_quality
                    .tell(ConnQualityRequest::Subscription(sub))
                    .await
                    .unwrap();
                UIResponse::Ack
            }
            UIRequest::SetTargetDir(path_buf) => {
                self.config
                    .tell(ConfigRequest::SetTargetDir(path_buf))
                    .await
                    .unwrap();
                UIResponse::Ack
            }
            UIRequest::SetDeviceName(name) => {
                self.config
                    .tell(ConfigRequest::SetDeviceName(name))
                    .await
                    .unwrap();
                UIResponse::Ack
            }
            UIRequest::GetTargetDir => {
                let response = self.config.ask(ConfigRequest::GetTargetDir).await.unwrap();
                let ConfigReply::TargetDir(dir) = response else {
                    unreachable!()
                };
                UIResponse::GetTargetDir(dir)
            }
            UIRequest::GetLocalAddr => {
                let addr = self.router.endpoint().addr();
                UIResponse::GetLocalAddr(addr)
            }
            UIRequest::GetPeers => {
                let response = self.config.ask(ConfigRequest::GetPeers).await.unwrap();
                let ConfigReply::Peers(peers) = response else {
                    unreachable!()
                };
                UIResponse::GetPeers(peers)
            }
            UIRequest::GetDeviceName => {
                let response = self.config.ask(ConfigRequest::GetDeviceName).await.unwrap();
                let ConfigReply::DeviceName(name) = response else {
                    unreachable!()
                };
                UIResponse::GetDeviceName(name)
            }
            UIRequest::GetSecret => {
                let response = self.pairing.ask(PairingRequest::GetSecret).await.unwrap();
                let PairingReply::Secret(secret) = response else {
                    unreachable!()
                };
                UIResponse::Secret(secret)
            }
        }
    }
}

pub enum UIRequest {
    PairingSubscription(StreamSink<InboundPair>),
    FileSubscription(StreamSink<InboundFileEvent>),
    ConnQualitySubscription(StreamSink<UIConnectionQualityUpdate>),
    GetTargetDir,
    SetTargetDir(PathBuf),
    GetLocalAddr,
    GetPeers,
    SetDeviceName(String),
    GetDeviceName,
    GetSecret,
}

#[derive(Reply)]
pub enum UIResponse {
    GetLocalAddr(EndpointAddr),
    GetPeers(Vec<Peer>),
    GetTargetDir(Option<PathBuf>),
    GetDeviceName(String),
    Secret(Vec<u8>),
    Ack,
}
