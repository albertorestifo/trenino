use std::io;
use std::sync::atomic::{AtomicU32, Ordering};
use std::thread;
use std::time::{Duration, Instant};

use trenino_core::hardware::protocol::{decode_message, encode_message, FrameDecoder, Message};

use super::transport::SerialIo;

static NEXT_REQUEST_ID: AtomicU32 = AtomicU32::new(1);

#[derive(Clone, Copy, Debug)]
pub struct DiscoveryTiming {
    pub settle: Duration,
    pub read_timeout: Duration,
    pub attempts: u8,
}

impl Default for DiscoveryTiming {
    fn default() -> Self {
        Self {
            settle: Duration::from_millis(3_000),
            read_timeout: Duration::from_millis(1_000),
            attempts: 5,
        }
    }
}

#[derive(Debug)]
pub enum DiscoveryError {
    Io(io::Error),
    NoValidResponse,
}

pub fn discover(io: &mut dyn SerialIo, timing: DiscoveryTiming) -> Result<Message, DiscoveryError> {
    discover_with_cancel(io, timing, || false)
}

pub fn discover_with_cancel<F>(
    io: &mut dyn SerialIo,
    timing: DiscoveryTiming,
    cancelled: F,
) -> Result<Message, DiscoveryError>
where
    F: Fn() -> bool,
{
    let settle_deadline = Instant::now() + timing.settle;
    while Instant::now() < settle_deadline {
        if cancelled() {
            return Err(DiscoveryError::NoValidResponse);
        }
        thread::sleep((settle_deadline - Instant::now()).min(Duration::from_millis(10)));
    }
    // Drain stale bootloader bytes until the port read timeout indicates empty.
    let mut garbage = [0u8; 512];
    loop {
        if cancelled() {
            return Err(DiscoveryError::NoValidResponse);
        }
        match io.read(&mut garbage) {
            Ok(0) => break,
            Ok(_) => continue,
            Err(error) if error.kind() == io::ErrorKind::TimedOut => break,
            Err(error) => return Err(DiscoveryError::Io(error)),
        }
    }
    let mut decoder = FrameDecoder::default();
    for _ in 0..timing.attempts {
        if cancelled() {
            return Err(DiscoveryError::NoValidResponse);
        }
        let request_id = NEXT_REQUEST_ID.fetch_add(1, Ordering::Relaxed);
        let request = Message::IdentityRequest { request_id };
        io.write_all(&FrameDecoder::encode_frame(
            &encode_message(&request).map_err(|_| DiscoveryError::NoValidResponse)?,
        ))
        .map_err(DiscoveryError::Io)?;
        io.flush().map_err(DiscoveryError::Io)?;
        let deadline = Instant::now() + timing.read_timeout;
        while Instant::now() < deadline {
            if cancelled() {
                return Err(DiscoveryError::NoValidResponse);
            }
            let mut buffer = [0u8; 512];
            match io.read(&mut buffer) {
                Ok(0) => continue,
                Ok(count) => {
                    for packet in decoder.push(&buffer[..count]).into_iter().flatten() {
                        if let Ok(Message::IdentityResponse {
                            request_id: response_id,
                            ..
                        }) = decode_message(&packet)
                        {
                            if response_id == request_id {
                                return Ok(
                                    decode_message(&packet).expect("validated identity packet")
                                );
                            }
                        }
                    }
                }
                Err(error) if error.kind() == io::ErrorKind::TimedOut => break,
                Err(error) => return Err(DiscoveryError::Io(error)),
            }
        }
    }
    Err(DiscoveryError::NoValidResponse)
}
