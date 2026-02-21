use std::fmt::Debug;
use std::future::Future;
use std::pin::Pin;
use std::task::{Context, Poll};
use tokio::sync::oneshot;

pub struct Promise<T> {
    rx: oneshot::Receiver<T>,
}

pub struct PromiseResolver<T> {
    tx: Option<oneshot::Sender<T>>,
}

impl<T> Future for Promise<T> {
    type Output = T;

    fn poll(mut self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<Self::Output> {
        match Pin::new(&mut self.rx).poll(cx) {
            Poll::Ready(v) => Poll::Ready(v.unwrap()),
            Poll::Pending => Poll::Pending,
        }
    }
}

impl<T: Debug> PromiseResolver<T> {
    pub fn emit(mut self, value: T) {
        self.tx.take().unwrap().send(value).unwrap();
    }
}

pub fn init_promise<T>() -> (Promise<T>, PromiseResolver<T>) {
    let (tx, rx) = oneshot::channel();
    (Promise { rx }, PromiseResolver { tx: Some(tx) })
}
