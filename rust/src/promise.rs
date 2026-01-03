use std::fmt::Debug;
use std::future::Future;
use std::pin::Pin;
use std::task::{Context, Poll};
use tokio::sync::oneshot;

pub trait Link: Sized {
    type Sender;
    fn new() -> (Self, Self::Sender);
}

pub struct PromiseFinal<T> {
    rx: oneshot::Receiver<T>,
}

pub struct PromiseFinalSender<T> {
    tx: Option<oneshot::Sender<T>>,
}

impl<T> Future for PromiseFinal<T> {
    type Output = T;

    fn poll(mut self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<Self::Output> {
        match Pin::new(&mut self.rx).poll(cx) {
            Poll::Ready(v) => Poll::Ready(v.unwrap()),
            Poll::Pending => Poll::Pending,
        }
    }
}

impl<T: Debug> PromiseFinalSender<T> {
    pub fn send(mut self, value: T) {
        self.tx.take().unwrap().send(value).unwrap();
    }
}

impl<T> Link for PromiseFinal<T> {
    type Sender = PromiseFinalSender<T>;

    fn new() -> (Self, Self::Sender) {
        let (tx, rx) = oneshot::channel();
        (PromiseFinal { rx }, PromiseFinalSender { tx: Some(tx) })
    }
}

pub struct Promise<Y, Next: Link> {
    rx_yield_and_next_sender: oneshot::Receiver<(Y, oneshot::Sender<Next::Sender>)>,
}

pub struct PromiseSender<Y, Next: Link> {
    tx_yield_and_next_sender: Option<oneshot::Sender<(Y, oneshot::Sender<Next::Sender>)>>,
}

impl<Y, Next> Future for Promise<Y, Next>
where
    Next: Link,
    Next::Sender: Debug,
{
    type Output = (Y, Next);

    fn poll(mut self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<Self::Output> {
        match Pin::new(&mut self.rx_yield_and_next_sender).poll(cx) {
            Poll::Ready(v) => {
                let (y, tx_next_sender) = v.unwrap();
                let (next_promise, next_sender) = Next::new();
                tx_next_sender.send(next_sender).unwrap();
                Poll::Ready((y, next_promise))
            }
            Poll::Pending => Poll::Pending,
        }
    }
}

impl<Y, Next> PromiseSender<Y, Next>
where
    Y: Debug,
    Next: Link,
    Next::Sender: Debug,
{
    /// Send this stage’s value and wait until the consumer
    /// installs the next stage.
    pub async fn send(mut self, y: Y) -> Next::Sender {
        let (tx_next_sender, rx_next_sender) = oneshot::channel::<Next::Sender>();

        self.tx_yield_and_next_sender
            .take()
            .unwrap()
            .send((y, tx_next_sender))
            .unwrap();

        rx_next_sender.await.unwrap()
    }
}

impl<Y, Next: Link> Link for Promise<Y, Next> {
    type Sender = PromiseSender<Y, Next>;

    fn new() -> (Self, Self::Sender) {
        let (tx, rx) = oneshot::channel::<(Y, oneshot::Sender<Next::Sender>)>();
        (
            Promise {
                rx_yield_and_next_sender: rx,
            },
            PromiseSender {
                tx_yield_and_next_sender: Some(tx),
            },
        )
    }
}

/// Build a nested generator type.
///
/// `promise!(A, B, C)`
/// expands to:
/// `Promise<A, Promise<B, PromiseFinal<C>>>`
#[macro_export]
macro_rules! promise {
    ($final:ty) => {
        $crate::promise::PromiseFinal<$final>
    };
    ($head:ty, $($tail:ty),+ $(,)?) => {
        $crate::promise::Promise<$head, $crate::generator!($($tail),+)>
    };
}

pub use promise;

pub fn init_promise<G: Link>() -> (G, G::Sender) {
    G::new()
}
