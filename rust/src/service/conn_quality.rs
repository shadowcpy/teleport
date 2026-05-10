use std::{collections::HashMap, time::Duration};

use anyhow::Result;
use flutter_rust_bridge::JoinHandle;
use futures_util::StreamExt;
use iroh::{
    EndpointId,
    endpoint::{Connection, PathEvent, WeakConnectionHandle},
};
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
        handle: WeakConnectionHandle,
    },
    ConnectionQualityUpdate {
        peer: EndpointId,
        update: ConnQuality,
    },
    TrackingEnded {
        peer: EndpointId,
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
            ConnQualityRequest::StartTracking { peer, handle } => {
                if self.tasks.contains_key(&peer) {
                    return ConnQualityReply::Ack;
                }
                let this = self.this.clone();
                let handle = spawn(async move {
                    let Some(conn) = handle.upgrade() else {
                        this.tell(ConnQualityRequest::ConnectionQualityUpdate {
                            peer,
                            update: ConnQuality::None,
                        })
                        .await
                        .ok();
                        this.tell(ConnQualityRequest::TrackingEnded { peer })
                            .await
                            .ok();
                        return;
                    };

                    let mut events = conn.path_events();
                    let update = selected_quality(&conn);
                    drop(conn);

                    this.tell(ConnQualityRequest::ConnectionQualityUpdate { peer, update })
                        .await
                        .ok();

                    while let Some(event) = events.next().await {
                        match event {
                            PathEvent::Opened { .. }
                            | PathEvent::Selected { .. }
                            | PathEvent::Closed { .. }
                            | PathEvent::Lagged { .. } => {
                                let update = handle
                                    .upgrade()
                                    .map(|conn| selected_quality(&conn))
                                    .unwrap_or(ConnQuality::None);

                                this.tell(ConnQualityRequest::ConnectionQualityUpdate {
                                    peer,
                                    update,
                                })
                                .await
                                .ok();
                            }
                            _ => {}
                        }
                    }

                    this.tell(ConnQualityRequest::ConnectionQualityUpdate {
                        peer,
                        update: ConnQuality::None,
                    })
                    .await
                    .ok();
                    this.tell(ConnQualityRequest::TrackingEnded { peer })
                        .await
                        .ok();
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
            ConnQualityRequest::TrackingEnded { peer } => {
                self.tasks.remove(&peer);
                ConnQualityReply::Ack
            }
        }
    }
}

fn selected_quality(conn: &Connection) -> ConnQuality {
    let paths = conn.paths();
    let Some(path) = paths.iter().find(|p| p.is_selected()) else {
        return ConnQuality::None;
    };

    if path.is_ip() {
        ConnQuality::Direct(path.rtt())
    } else if path.is_relay() {
        ConnQuality::Relay(path.rtt())
    } else {
        ConnQuality::None
    }
}
