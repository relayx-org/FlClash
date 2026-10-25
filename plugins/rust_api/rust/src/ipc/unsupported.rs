use super::EventSink;
use std::io;

pub struct Server;

fn unsupported() -> io::Error {
    io::Error::new(
        io::ErrorKind::Unsupported,
        "IPC server is not available on this platform",
    )
}

impl Server {
    pub fn bind(_address: String) -> io::Result<Self> {
        Err(unsupported())
    }

    pub fn events(&self, _sink: EventSink) {}

    pub fn send(&self, _payload: &[u8]) -> io::Result<()> {
        Err(unsupported())
    }

    pub fn close(&self) {}
}
