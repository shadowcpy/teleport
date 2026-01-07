use std::sync::Arc;

use anyhow::{Result, bail};
use iroh::{EndpointAddr, EndpointId, protocol::Router};
use kameo::prelude::*;
use tokio::spawn;
use tracing::{info, warn};

use crate::{
    api::teleport::{InboundPair, PairingResponse, UIPairReaction, UIPromise, UIResolver},
    frb_generated::{RustAutoOpaque, StreamSink},
    promise::{Promise, PromiseResolver, init_promise},
    protocol::{
        framed::FramedBiStream,
        pair::{self, MAX_SIZE, Pair},
    },
};

use super::{ConfigManager, ConfigReply, ConfigRequest, Peer};

pub struct PairingActor {
    config: ActorRef<ConfigManager>,
    router: Arc<Router>,
    pairing_subscription: Option<StreamSink<InboundPair>>,
    active_secret: Vec<u8>,
}

pub struct PairingActorArgs {
    pub config: ActorRef<ConfigManager>,
    pub router: Arc<Router>,
}

impl Actor for PairingActor {
    type Args = PairingActorArgs;
    type Error = anyhow::Error;

    async fn on_start(args: Self::Args, _actor_ref: ActorRef<Self>) -> Result<Self, Self::Error> {
        Ok(Self {
            config: args.config,
            router: args.router,
            pairing_subscription: None,
            active_secret: generate_secret(),
        })
    }
}

pub struct PairWithRequest {
    pub peer: EndpointAddr,
    pub secret: Vec<u8>,
    pub pairing_code: [u8; 6],
}

#[derive(Reply)]
pub struct PairWithResponse(pub Promise<PairingResponse>);

pub enum PairingRequest {
    PairingSubscription(StreamSink<InboundPair>),
    IncomingPairStarted {
        from: EndpointId,
        name: String,
        code: [u8; 6],
        outcome: Promise<Result<(), String>>,
    },
    IncomingPairCompleted {
        outcome: Result<Peer, anyhow::Error>,
        resolver: PromiseResolver<Result<(), String>>,
    },
    ValidateSecret(Vec<u8>),
    GetSecret,
}

#[derive(Reply)]
pub enum PairingReply {
    IncomingPair {
        reaction: Promise<UIPairReaction>,
        our_name: String,
    },
    ValidationResult(bool),
    Secret(Vec<u8>),
    Ack,
}

impl Message<PairWithRequest> for PairingActor {
    type Reply = PairWithResponse;

    async fn handle(
        &mut self,
        msg: PairWithRequest,
        _ctx: &mut Context<Self, Self::Reply>,
    ) -> Self::Reply {
        let addr = msg.peer;
        let secret = msg.secret;
        let code = msg.pairing_code;
        let id = addr.id;
        let config = self.config.clone();
        let router = self.router.clone();

        let (promise, resolver) = init_promise::<PairingResponse>();

        spawn(async move {
            let response = config.ask(ConfigRequest::IsPeerKnown(id)).await;
            let already_paired = matches!(response, Ok(ConfigReply::IsPeerKnown(true)));
            if already_paired {
                warn!("Already paired to {id}, ignoring");
                resolver.emit(PairingResponse::Success);
                return;
            }

            let response = config.ask(ConfigRequest::GetDeviceName).await;
            let name = match response {
                Ok(ConfigReply::DeviceName(name)) => name,
                _ => String::new(),
            };

            info!("Pairing with {id}...");

            enum InternalPairingResult {
                Success(String),
                WrongCode,
                WrongSecret,
                Rejected,
            }

            let action = async {
                let conn = router.endpoint().connect(addr, pair::ALPN).await?;
                let (send, recv) = conn.open_bi().await?;
                let mut framed = FramedBiStream::new((send, recv), MAX_SIZE);

                Pair::Helo {
                    friendly_name: name,
                    pairing_code: code,
                    secret,
                }
                .send(&mut framed)
                .await?;

                info!("Sent HELO to {id}...");

                let response = Pair::recv(&mut framed).await?;

                info!("Got {response:?} from {id}");

                match response {
                    Pair::FuckOff => Ok(InternalPairingResult::Rejected),
                    Pair::NiceToMeetYou { friendly_name } => {
                        Ok(InternalPairingResult::Success(friendly_name))
                    }
                    Pair::WrongPairingCode => Ok(InternalPairingResult::WrongCode),
                    Pair::WrongSecret => Ok(InternalPairingResult::WrongSecret),
                    _ => bail!("Invalid msg type"),
                }
            };

            match action.await {
                Ok(InternalPairingResult::Success(peer_name)) => {
                    info!("Paired with {peer_name} ({id})");
                    config
                        .tell(ConfigRequest::RegisterPeer(Peer {
                            id,
                            name: peer_name,
                        }))
                        .await
                        .unwrap();
                    resolver.emit(PairingResponse::Success);
                }
                Ok(InternalPairingResult::WrongCode) => {
                    resolver.emit(PairingResponse::WrongCode);
                }
                Ok(InternalPairingResult::WrongSecret) => {
                    resolver.emit(PairingResponse::WrongSecret);
                }
                Ok(InternalPairingResult::Rejected) => {
                    resolver.emit(PairingResponse::Error("Peer rejected pairing".to_string()));
                }
                Err(e) => {
                    warn!("Failed to pair with {id}: {}", e);
                    resolver.emit(PairingResponse::Error(e.to_string()));
                }
            }
        });

        PairWithResponse(promise)
    }
}

impl Message<PairingRequest> for PairingActor {
    type Reply = PairingReply;

    async fn handle(
        &mut self,
        msg: PairingRequest,
        _ctx: &mut Context<Self, Self::Reply>,
    ) -> Self::Reply {
        match msg {
            PairingRequest::PairingSubscription(sub) => {
                self.pairing_subscription = Some(sub);
                PairingReply::Ack
            }
            PairingRequest::IncomingPairStarted {
                from,
                name,
                code,
                outcome,
            } => {
                let reaction = self.incoming_pair_started(from, name, code, outcome).await;
                self.active_secret = generate_secret();
                let response = self.config.ask(ConfigRequest::GetDeviceName).await.unwrap();
                let ConfigReply::DeviceName(our_name) = response else {
                    unreachable!()
                };
                PairingReply::IncomingPair { reaction, our_name }
            }
            PairingRequest::IncomingPairCompleted { outcome, resolver } => {
                match outcome {
                    Ok(peer) => {
                        self.config
                            .tell(ConfigRequest::RegisterPeer(peer))
                            .await
                            .unwrap();
                        resolver.emit(Ok(()));
                    }
                    Err(e) => resolver.emit(Err(e.to_string())),
                }
                PairingReply::Ack
            }
            PairingRequest::ValidateSecret(secret) => {
                let valid = secret == self.active_secret;
                if !valid {
                    warn!("Invalid secret received for pairing");
                }
                PairingReply::ValidationResult(valid)
            }
            PairingRequest::GetSecret => PairingReply::Secret(self.active_secret.clone()),
        }
    }
}

impl PairingActor {
    pub async fn incoming_pair_started(
        &mut self,
        from: EndpointId,
        friendly_name: String,
        pairing_code: [u8; 6],
        outcome: Promise<Result<(), String>>,
    ) -> Promise<UIPairReaction> {
        let (reaction_promise, reaction_resolver) = init_promise::<UIPairReaction>();
        let peer_id = from;

        let response = self
            .config
            .ask(ConfigRequest::IsPeerKnown(peer_id))
            .await
            .unwrap();
        let ConfigReply::IsPeerKnown(is_known) = response else {
            unreachable!()
        };

        if let Some(ref ui) = self.pairing_subscription {
            if is_known {
                warn!("Already paired to {peer_id}, ignoring");
                reaction_resolver.emit(UIPairReaction::Reject);
                return reaction_promise;
            }

            let pair = InboundPair {
                peer: peer_id.to_string(),
                friendly_name: friendly_name.clone(),
                pairing_code,
                reaction: RustAutoOpaque::new(UIResolver::new(reaction_resolver)),
                outcome: RustAutoOpaque::new(UIPromise::new(outcome)),
            };

            ui.add(pair).unwrap();
        }
        reaction_promise
    }
}

fn generate_secret() -> Vec<u8> {
    (0..128).map(|_| rand::random()).collect()
}
