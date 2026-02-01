use std::{collections::HashMap, sync::Arc, time::Duration};

use anyhow::Result;
use flutter_rust_bridge::JoinHandle;
use iroh::{EndpointId, protocol::Router};
use kameo::prelude::*;
use tokio::{spawn, time};
use tracing::warn;

use crate::{
    protocol::{framed::FramedBiStream, keepalive, keepalive::KeepAlive},
    service::{ConfigManager, ConfigReply, ConfigRequest, ConnQualityActor, ConnQualityRequest},
};

const KEEPALIVE_INTERVAL: Duration = Duration::from_secs(10);
const KEEPALIVE_TIMEOUT: Duration = Duration::from_secs(5);
const RECONNECT_DELAY: Duration = Duration::from_secs(5);
const PEER_SCAN_INTERVAL: Duration = Duration::from_secs(10);

pub struct KeepAliveActor {
    config: ActorRef<ConfigManager>,
    conn_quality: ActorRef<ConnQualityActor>,
    router: Arc<Router>,
    tasks: HashMap<EndpointId, JoinHandle<()>>,
}

pub struct KeepAliveActorArgs {
    pub config: ActorRef<ConfigManager>,
    pub conn_quality: ActorRef<ConnQualityActor>,
    pub router: Arc<Router>,
}

impl Actor for KeepAliveActor {
    type Args = KeepAliveActorArgs;
    type Error = anyhow::Error;

    async fn on_start(args: Self::Args, actor_ref: ActorRef<Self>) -> Result<Self, Self::Error> {
        let this = actor_ref.clone();
        spawn(async move {
            let mut interval = time::interval(PEER_SCAN_INTERVAL);
            loop {
                interval.tick().await;
                this.tell(KeepAliveRequest::Tick).await.ok();
            }
        });

        Ok(Self {
            config: args.config,
            conn_quality: args.conn_quality,
            router: args.router,
            tasks: HashMap::new(),
        })
    }
}

pub enum KeepAliveRequest {
    Tick,
}

#[derive(Reply)]
pub enum KeepAliveReply {
    Ack,
}

impl Message<KeepAliveRequest> for KeepAliveActor {
    type Reply = KeepAliveReply;

    async fn handle(
        &mut self,
        msg: KeepAliveRequest,
        _ctx: &mut Context<Self, Self::Reply>,
    ) -> Self::Reply {
        match msg {
            KeepAliveRequest::Tick => {
                let response = self.config.ask(ConfigRequest::GetPeers).await;
                let peers = match response {
                    Ok(ConfigReply::Peers(peers)) => peers,
                    _ => return KeepAliveReply::Ack,
                };

                for peer in peers {
                    if self.tasks.contains_key(&peer.id) {
                        continue;
                    }
                    let router = self.router.clone();
                    let conn_quality = self.conn_quality.clone();
                    let peer_id = peer.id;
                    let handle = spawn(async move {
                        run_keepalive(peer_id, router, conn_quality).await;
                    });
                    self.tasks.insert(peer.id, handle);
                }
                KeepAliveReply::Ack
            }
        }
    }
}

async fn run_keepalive(
    peer: EndpointId,
    router: Arc<Router>,
    conn_quality: ActorRef<ConnQualityActor>,
) {
    let mut seq: u64 = 0;

    loop {
        let conn = match router.endpoint().connect(peer, keepalive::ALPN).await {
            Ok(conn) => conn,
            Err(e) => {
                warn!("Keepalive connect to {peer} failed: {e}");
                time::sleep(RECONNECT_DELAY).await;
                continue;
            }
        };

        conn_quality
            .tell(ConnQualityRequest::StartTracking {
                peer,
                conn_info: conn.to_info(),
            })
            .await
            .ok();

        let (send, recv) = match conn.open_bi().await {
            Ok(streams) => streams,
            Err(e) => {
                warn!("Keepalive stream open to {peer} failed: {e}");
                time::sleep(RECONNECT_DELAY).await;
                continue;
            }
        };

        let mut framed = FramedBiStream::new((send, recv), keepalive::MAX_MSG_SIZE);
        let mut interval = time::interval(KEEPALIVE_INTERVAL);

        loop {
            interval.tick().await;
            seq = seq.wrapping_add(1);

            if let Err(e) = (KeepAlive::Ping { seq }).send(&mut framed).await {
                warn!("Keepalive ping to {peer} failed: {e}");
                break;
            }

            match time::timeout(KEEPALIVE_TIMEOUT, KeepAlive::recv(&mut framed)).await {
                Ok(Ok(KeepAlive::Pong { seq: pong_seq })) if pong_seq == seq => {}
                Ok(Ok(_)) => {
                    warn!("Keepalive pong mismatch from {peer}");
                    break;
                }
                Ok(Err(e)) => {
                    warn!("Keepalive recv from {peer} failed: {e}");
                    break;
                }
                Err(_) => {
                    warn!("Keepalive pong timeout from {peer}");
                    break;
                }
            }
        }

        conn.close(0u32.into(), b"PING");
        time::sleep(RECONNECT_DELAY).await;
    }
}
