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
    DeadlineExceeded,
}

pub struct DiscoveryResult {
    pub identity: Message,
    pub decoder: FrameDecoder,
    pub trailing_messages: Vec<Message>,
    pub protocol_errors: Vec<String>,
}

pub fn discover(io: &mut dyn SerialIo, timing: DiscoveryTiming) -> Result<Message, DiscoveryError> {
    discover_owned(io, timing, Duration::from_secs(10), || false).map(|result| result.identity)
}

pub fn discover_with_cancel<F>(
    io: &mut dyn SerialIo,
    timing: DiscoveryTiming,
    cancelled: F,
) -> Result<Message, DiscoveryError>
where
    F: Fn() -> bool,
{
    discover_owned(io, timing, Duration::from_secs(10), cancelled).map(|result| result.identity)
}

/// Discover the identity while retaining complete messages and decoder state that
/// followed it in the same serial read. This is transferred to the persistent owner.
pub fn discover_owned<F>(
    io: &mut dyn SerialIo,
    timing: DiscoveryTiming,
    outer_timeout: Duration,
    cancelled: F,
) -> Result<DiscoveryResult, DiscoveryError>
where
    F: Fn() -> bool,
{
    let overall_deadline = Instant::now() + outer_timeout;
    let settle_deadline = (Instant::now() + timing.settle).min(overall_deadline);
    while Instant::now() < settle_deadline {
        if cancelled() {
            return Err(DiscoveryError::NoValidResponse);
        }
        if Instant::now() >= overall_deadline {
            return Err(DiscoveryError::DeadlineExceeded);
        }
        thread::sleep((settle_deadline - Instant::now()).min(Duration::from_millis(10)));
    }

    // Drain stale bytes only until the overall discovery deadline, even if a device
    // continuously sends noise instead of becoming quiet.
    let mut garbage = [0u8; 512];
    loop {
        if cancelled() {
            return Err(DiscoveryError::NoValidResponse);
        }
        let remaining = overall_deadline.saturating_duration_since(Instant::now());
        if remaining.is_zero() {
            return Err(DiscoveryError::DeadlineExceeded);
        }
        io.set_timeout(remaining.min(timing.read_timeout))
            .map_err(DiscoveryError::Io)?;
        match io.read(&mut garbage) {
            Ok(0) => break,
            Ok(_) => continue,
            Err(error)
                if matches!(
                    error.kind(),
                    io::ErrorKind::TimedOut | io::ErrorKind::WouldBlock
                ) =>
            {
                break
            }
            Err(error) => return Err(DiscoveryError::Io(error)),
        }
    }

    let mut decoder = FrameDecoder::default();
    for _ in 0..timing.attempts {
        if cancelled() {
            return Err(DiscoveryError::NoValidResponse);
        }
        let remaining = overall_deadline.saturating_duration_since(Instant::now());
        if remaining.is_zero() {
            return Err(DiscoveryError::DeadlineExceeded);
        }
        io.set_timeout(remaining.min(timing.read_timeout))
            .map_err(DiscoveryError::Io)?;
        let request_id = NEXT_REQUEST_ID.fetch_add(1, Ordering::Relaxed);
        let request = Message::IdentityRequest { request_id };
        io.write_all(&FrameDecoder::encode_frame(
            &encode_message(&request).map_err(|_| DiscoveryError::NoValidResponse)?,
        ))
        .map_err(DiscoveryError::Io)?;
        io.flush().map_err(DiscoveryError::Io)?;
        let deadline = (Instant::now() + timing.read_timeout).min(overall_deadline);
        while Instant::now() < deadline {
            if cancelled() {
                return Err(DiscoveryError::NoValidResponse);
            }
            let remaining = deadline.saturating_duration_since(Instant::now());
            if remaining.is_zero() {
                break;
            }
            io.set_timeout(remaining).map_err(DiscoveryError::Io)?;
            let mut buffer = [0u8; 512];
            match io.read(&mut buffer) {
                Ok(0) => continue,
                Ok(count) => {
                    let packets = decoder.push(&buffer[..count]);
                    let mut identity = None;
                    let mut stale_identity = None;
                    let mut after_identity = false;
                    let mut trailing_messages = Vec::new();
                    let mut protocol_errors = Vec::new();
                    for packet in packets {
                        let payload = match packet {
                            Ok(payload) => payload,
                            Err(error) => {
                                if after_identity {
                                    protocol_errors.push(format!("invalid frame: {error:?}"));
                                }
                                continue;
                            }
                        };
                        let message = match decode_message(&payload) {
                            Ok(message) => message,
                            Err(error) => {
                                if after_identity {
                                    protocol_errors.push(format!("invalid frame: {error:?}"));
                                }
                                continue;
                            }
                        };
                        if !after_identity {
                            if let Message::IdentityResponse {
                                request_id: response_id,
                                ..
                            } = &message
                            {
                                if *response_id == request_id {
                                    identity = Some(message);
                                    after_identity = true;
                                } else {
                                    // Firmware echoing a stale request id after a reset is
                                    // still a valid IdentityResponse (HW-003): accept it as a
                                    // fallback, preferring a matching id from the same batch.
                                    stale_identity.get_or_insert(message);
                                }
                            }
                        } else {
                            trailing_messages.push(message);
                        }
                    }
                    if identity.is_none() && stale_identity.is_some() {
                        identity = stale_identity;
                    }
                    if let Some(identity) = identity {
                        return Ok(DiscoveryResult {
                            identity,
                            decoder,
                            trailing_messages,
                            protocol_errors,
                        });
                    }
                }
                Err(error)
                    if matches!(
                        error.kind(),
                        io::ErrorKind::TimedOut | io::ErrorKind::WouldBlock
                    ) =>
                {
                    break
                }
                Err(error) => return Err(DiscoveryError::Io(error)),
            }
        }
    }
    if Instant::now() >= overall_deadline {
        return Err(DiscoveryError::DeadlineExceeded);
    }
    Err(DiscoveryError::NoValidResponse)
}
