use std::{collections::HashMap, sync::Arc};

use anyhow::Result;
use flutter_rust_bridge::JoinHandle;
use futures_util::StreamExt;
use iroh::{EndpointId, Watcher, endpoint::ConnectionType, protocol::Router};
use kameo::prelude::*;
use tokio::spawn;

use crate::{
    api::teleport::{UIConnectionQuality, UIConnectionQualityUpdate},
    frb_generated::StreamSink,
};

pub struct ConnQualityActor {
    this: ActorRef<ConnQualityActor>,
    router: Arc<Router>,
    subscription: Option<StreamSink<UIConnectionQualityUpdate>>,
    tasks: HashMap<EndpointId, JoinHandle<()>>,
}

pub struct ConnQualityActorArgs {
    pub router: Arc<Router>,
}

impl Actor for ConnQualityActor {
    type Args = ConnQualityActorArgs;
    type Error = anyhow::Error;

    async fn on_start(args: Self::Args, actor_ref: ActorRef<Self>) -> Result<Self, Self::Error> {
        Ok(Self {
            this: actor_ref,
            router: args.router,
            subscription: None,
            tasks: HashMap::new(),
        })
    }
}

pub enum ConnQualityRequest {
    Subscription(StreamSink<UIConnectionQualityUpdate>),
    StartTracking(EndpointId),
    ConnectionQualityUpdate {
        peer: EndpointId,
        update: ConnectionType,
    },
}

#[derive(Reply)]
pub enum ConnQualityReply {
    Ack,
}

impl Message<ConnQualityRequest> for ConnQualityActor {
    type Reply = ConnQualityReply;

    async fn handle(
        &mut self,
        msg: ConnQualityRequest,
        _ctx: &mut Context<Self, Self::Reply>,
    ) -> Self::Reply {
        match msg {
            ConnQualityRequest::Subscription(sub) => {
                self.subscription = Some(sub);
                ConnQualityReply::Ack
            }
            ConnQualityRequest::StartTracking(peer) => {
                if self.tasks.contains_key(&peer) {
                    return ConnQualityReply::Ack;
                }
                let Some(watcher) = self.router.endpoint().conn_type(peer) else {
                    return ConnQualityReply::Ack;
                };
                let this = self.this.clone();
                let handle = spawn(async move {
                    let mut stream = watcher.stream();
                    while let Some(update) = stream.next().await {
                        this.tell(ConnQualityRequest::ConnectionQualityUpdate { peer, update })
                            .await
                            .unwrap();
                    }
                });
                self.tasks.insert(peer, handle);
                ConnQualityReply::Ack
            }
            ConnQualityRequest::ConnectionQualityUpdate { peer, update } => {
                if let Some(ref ui) = self.subscription {
                    let quality = match update {
                        ConnectionType::Direct(_) => UIConnectionQuality::Direct,
                        ConnectionType::Relay(_) => UIConnectionQuality::Relay,
                        ConnectionType::Mixed(_, _) => UIConnectionQuality::Mixed,
                        ConnectionType::None => UIConnectionQuality::None,
                    };
                    ui.add(UIConnectionQualityUpdate {
                        peer: peer.to_string(),
                        quality,
                    })
                    .unwrap();
                }
                ConnQualityReply::Ack
            }
        }
    }
}
