use iroh::endpoint::{RecvStream, SendStream};
use tokio_util::codec::{FramedRead, FramedWrite, LengthDelimitedCodec};

pub struct FramedBiStream {
    pub write: FramedWrite<SendStream, LengthDelimitedCodec>,
    pub read: FramedRead<RecvStream, LengthDelimitedCodec>,
}

impl FramedBiStream {
    pub fn new((send, recv): (SendStream, RecvStream), max_len: usize) -> Self {
        let mut codec = LengthDelimitedCodec::builder();
        codec.max_frame_length(max_len);
        Self {
            write: codec.new_write(send),
            read: codec.new_read(recv),
        }
    }
}
