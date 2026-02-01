use std::{collections::HashMap, time::Duration};

use anyhow::Result;
use flutter_rust_bridge::JoinHandle;
use futures_util::StreamExt;
use iroh::{EndpointId, Watcher, endpoint::ConnectionInfo};
use kameo::prelude::*;
use tokio::spawn;

use crate::{
    api::teleport::{UIConnectionQuality, UIConnectionQualityUpdate},
    frb_generated::StreamSink,
};

pub struct ConnQualityActor {
    this: ActorRef<ConnQualityActor>,
    subscription: Option<StreamSink<UIConnectionQualityUpdate>>,
    tasks: HashMap<EndpointId, JoinHandle<()>>,
}

impl Actor for ConnQualityActor {
    type Args = ();
    type Error = anyhow::Error;

    async fn on_start(_args: Self::Args, actor_ref: ActorRef<Self>) -> Result<Self, Self::Error> {
        Ok(Self {
            this: actor_ref,
            subscription: None,
            tasks: HashMap::new(),
        })
    }
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum ConnQuality {
    Direct(Duration),
    Relay(Duration),
    None,
}

pub enum ConnQualityRequest {
    Subscription(StreamSink<UIConnectionQualityUpdate>),
    StartTracking {
        peer: EndpointId,
        conn_info: ConnectionInfo,
    },
    ConnectionQualityUpdate {
        peer: EndpointId,
        update: ConnQuality,
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
            ConnQualityRequest::StartTracking { peer, conn_info } => {
                if self.tasks.contains_key(&peer) {
                    return ConnQualityReply::Ack;
                }
                let watcher = conn_info.paths();
                let this = self.this.clone();
                let handle = spawn(async move {
                    let mut stream = watcher.stream();
                    while let Some(update) = stream.next().await {
                        let selected = update.iter().find(|p| p.is_selected());
                        let update = match selected {
                            Some(path) => match path.is_ip() {
                                true => ConnQuality::Direct(path.rtt()),
                                false => ConnQuality::Relay(path.rtt()),
                            },
                            None => ConnQuality::None,
                        };
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
                        ConnQuality::Direct(latency) => UIConnectionQuality::Direct {
                            latency: latency.as_millis(),
                        },
                        ConnQuality::Relay(latency) => UIConnectionQuality::Relay {
                            latency: latency.as_millis(),
                        },
                        ConnQuality::None => UIConnectionQuality::None,
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
