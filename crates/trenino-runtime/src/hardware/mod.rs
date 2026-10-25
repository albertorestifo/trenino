//! Injectable serial runtime. Construction is inert; [`HardwareRuntime::start`]
//! explicitly begins periodic discovery and owns all port workers until shutdown.
pub mod configuration;
pub mod discovery;
pub mod plan;
pub mod repository;
pub mod service;
pub mod sessions;
pub mod transport;

use std::collections::HashMap;
use std::io;
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::{mpsc, Arc, Mutex};
use std::time::{Duration, Instant};

use crate::resource::{FirmwareHandoffPermit, FirmwareHandoffPin};
use discovery::DiscoveryTiming;
use transport::{eligible_ports, SerialTransport};
use trenino_core::hardware::protocol::{decode_message, encode_message, FrameDecoder, Message};

pub const DEFAULT_BAUD: u32 = 115_200;
pub const SCAN_INTERVAL: Duration = Duration::from_millis(60_000);
pub const FAILURE_RETRY: Duration = Duration::from_millis(30_000);
pub const DISCOVERY_TIMEOUT: Duration = Duration::from_millis(10_000);
pub const CLEANUP_DEADLINE: Duration = Duration::from_millis(5_000);
const RUNTIME_COMMAND_CAPACITY: usize = 64;
const PORT_COMMAND_CAPACITY: usize = 64;
const HANDOFF_RESULT_CAPACITY: usize = 1024;

#[derive(Clone, Debug, Eq, PartialEq)]
pub enum PortEvent {
    Discovered {
        port: String,
        generation: u64,
        identity: Message,
    },
    Message {
        port: String,
        generation: u64,
        message: Message,
    },
    ProtocolError {
        port: String,
        generation: u64,
        reason: String,
    },
    Failed {
        port: String,
        generation: u64,
        reason: String,
    },
    Closed {
        port: String,
        generation: u64,
    },
}

/// Human-readable port failure strings, porting
/// `DeviceConnection.format_error_reason/1`
/// (lib/trenino/serial/connection/device_connection.ex:124-145). Symbolic
/// reason tokens map to the oracle's exact strings; unknown tokens fall back
/// to the oracle's atom rendering (underscores to spaces, capitalized).
pub fn format_error_reason(reason: &str) -> String {
    match reason {
        "eacces" => "Permission denied".into(),
        "enoent" => "Port not found".into(),
        "ebusy" => "Port is busy (in use by another program)".into(),
        "eagain" => "Resource temporarily unavailable".into(),
        "eio" => "I/O error".into(),
        "einval" => "Invalid port configuration".into(),
        "enxio" => "Device not configured".into(),
        "eperm" => "Operation not permitted".into(),
        "no_valid_response" => "No Trenino firmware detected".into(),
        "timeout" => "Connection timed out".into(),
        "port_timed_out" => "Device not responding".into(),
        other if other.chars().any(char::is_whitespace) => other.to_string(),
        other => {
            let joined = other.replace('_', " ");
            match joined.chars().next() {
                Some(first) => {
                    let upper: String = first.to_uppercase().collect();
                    format!("{upper}{}", &joined[first.len_utf8()..])
                }
                None => joined,
            }
        }
    }
}

/// Maps an OS port-open error to the oracle's human-readable string via its
/// errno name (`:enoent`, `:ebusy`, ...), falling back to the io error's own
/// display text for anything unmapped.
pub fn format_io_error_reason(error: &io::Error) -> String {
    // Unix errno numbers are not Windows error codes; handle Darwin's
    // EAGAIN through ErrorKind rather than assuming Linux's value 11.
    #[cfg(unix)]
    {
        let token = match error.raw_os_error() {
            Some(13) => Some("eacces"),
            Some(2) => Some("enoent"),
            Some(16) => Some("ebusy"),
            Some(5) => Some("eio"),
            Some(22) => Some("einval"),
            Some(6) => Some("enxio"),
            Some(1) => Some("eperm"),
            _ => None,
        };
        if let Some(token) = token {
            return format_error_reason(token);
        }
    }
    match error.kind() {
        io::ErrorKind::PermissionDenied => format_error_reason("eacces"),
        io::ErrorKind::NotFound => format_error_reason("enoent"),
        io::ErrorKind::WouldBlock => format_error_reason("eagain"),
        io::ErrorKind::InvalidInput => format_error_reason("einval"),
        _ => error.to_string(),
    }
}

/// Discovery failures map to the oracle's reason atoms (`:no_valid_response`,
/// `:timeout`) or the errno mapping for I/O errors, then through
/// [`format_error_reason`] for the human-readable string.
fn discovery_failure_reason(error: &discovery::DiscoveryError) -> String {
    match error {
        discovery::DiscoveryError::Io(io) => format_io_error_reason(io),
        discovery::DiscoveryError::NoValidResponse => format_error_reason("no_valid_response"),
        discovery::DiscoveryError::DeadlineExceeded => format_error_reason("timeout"),
    }
}

enum PortCommand {
    Send(
        u64,
        Message,
        Arc<AtomicBool>,
        mpsc::Sender<Result<(), String>>,
    ),
    Close,
}

/// A port task exclusively owns its open serial handle, reader, decoder, and writes.
pub struct OwnedPortTask {
    port: String,
    generation: u64,
    cancelled: Arc<AtomicBool>,
    failed: Arc<AtomicBool>,
    commands: mpsc::SyncSender<PortCommand>,
    join: Option<std::thread::JoinHandle<()>>,
    close_requested: bool,
    joined: Option<Result<(), String>>,
    discovery_deadline: Instant,
    discovery_complete: Arc<AtomicBool>,
    discovery_timeout_reported: bool,
}

impl OwnedPortTask {
    fn spawn<T, F>(
        transport: Arc<T>,
        port: String,
        generation: u64,
        timing: DiscoveryTiming,
        discovery_timeout: Duration,
        sink: F,
    ) -> Self
    where
        T: SerialTransport,
        F: Fn(PortEvent) + Send + 'static,
    {
        let thread_port = port.clone();
        let worker_port = port.clone();
        let cancelled = Arc::new(AtomicBool::new(false));
        let worker_cancelled = cancelled.clone();
        let failed = Arc::new(AtomicBool::new(false));
        let worker_failed = failed.clone();
        let discovery_complete = Arc::new(AtomicBool::new(false));
        let worker_discovery_complete = discovery_complete.clone();
        let (commands, command_rx) = mpsc::sync_channel(PORT_COMMAND_CAPACITY);
        let join = std::thread::Builder::new()
            .name(format!("serial-{port}-{generation}"))
            .spawn(move || {
                let mut serial =
                    match transport.open(&thread_port, DEFAULT_BAUD, timing.read_timeout) {
                        Ok(serial) => serial,
                        Err(error) => {
                            worker_failed.store(true, Ordering::Release);
                            sink(PortEvent::Failed {
                                port: thread_port,
                                generation,
                                reason: format_io_error_reason(&error),
                            });
                            return;
                        }
                    };
                let discovery = match discovery::discover_owned(
                    serial.as_mut(),
                    timing,
                    discovery_timeout,
                    || worker_cancelled.load(Ordering::Acquire),
                ) {
                    Ok(discovery) => discovery,
                    Err(error) => {
                        if !worker_cancelled.load(Ordering::Acquire) {
                            worker_failed.store(true, Ordering::Release);
                            sink(PortEvent::Failed {
                                port: thread_port,
                                generation,
                                reason: discovery_failure_reason(&error),
                            });
                        }
                        return;
                    }
                };
                worker_discovery_complete.store(true, Ordering::Release);
                sink(PortEvent::Discovered {
                    port: worker_port.clone(),
                    generation,
                    identity: discovery.identity,
                });
                let mut decoder = discovery.decoder;
                for reason in discovery.protocol_errors {
                    sink(PortEvent::ProtocolError {
                        port: worker_port.clone(),
                        generation,
                        reason,
                    });
                }
                for message in discovery.trailing_messages {
                    sink(PortEvent::Message {
                        port: worker_port.clone(),
                        generation,
                        message,
                    });
                }
                let mut buffer = [0u8; 512];
                loop {
                    if worker_cancelled.load(Ordering::Acquire) {
                        break;
                    }
                    match command_rx.try_recv() {
                        Ok(PortCommand::Close) | Err(mpsc::TryRecvError::Disconnected) => break,
                        Ok(PortCommand::Send(expected_generation, message, cancelled, reply)) => {
                            if expected_generation != generation {
                                let _ = reply.send(Err("stale port generation".into()));
                                continue;
                            }
                            if cancelled.load(Ordering::Acquire) {
                                let _ = reply
                                    .send(Err("serial write cancelled before dispatch".into()));
                                continue;
                            }
                            let result = encode_message(&message)
                                .map(|payload| FrameDecoder::encode_frame(&payload))
                                .map_err(|error| format!("encode failed: {error:?}"))
                                .and_then(|frame| {
                                    serial.write_all(&frame).map_err(|error| error.to_string())
                                })
                                .and_then(|()| serial.flush().map_err(|error| error.to_string()));
                            let failed = result.as_ref().err().cloned();
                            let _ = reply.send(result);
                            if let Some(reason) = failed {
                                worker_failed.store(true, Ordering::Release);
                                sink(PortEvent::Failed {
                                    port: worker_port.clone(),
                                    generation,
                                    reason,
                                });
                                break;
                            }
                        }
                        Err(mpsc::TryRecvError::Empty) => {}
                    }
                    match serial.read(&mut buffer) {
                        Ok(0) => {}
                        Ok(count) => {
                            for packet in decoder.push(&buffer[..count]) {
                                match packet.and_then(|payload| decode_message(&payload)) {
                                    Ok(message) => sink(PortEvent::Message {
                                        port: worker_port.clone(),
                                        generation,
                                        message,
                                    }),
                                    Err(error) => {
                                        sink(PortEvent::ProtocolError {
                                            port: worker_port.clone(),
                                            generation,
                                            reason: format!("invalid frame: {error:?}"),
                                        });
                                    }
                                }
                            }
                        }
                        Err(error)
                            if matches!(
                                error.kind(),
                                io::ErrorKind::TimedOut | io::ErrorKind::WouldBlock
                            ) => {}
                        Err(error) => {
                            worker_failed.store(true, Ordering::Release);
                            sink(PortEvent::Failed {
                                port: worker_port.clone(),
                                generation,
                                reason: error.to_string(),
                            });
                            break;
                        }
                    }
                }
                sink(PortEvent::Closed {
                    port: worker_port,
                    generation,
                });
            })
            .expect("failed to spawn owned serial port task");
        Self {
            port,
            generation,
            cancelled,
            failed,
            commands,
            join: Some(join),
            close_requested: false,
            joined: None,
            discovery_deadline: Instant::now() + discovery_timeout,
            discovery_complete,
            discovery_timeout_reported: false,
        }
    }

    pub fn port(&self) -> &str {
        &self.port
    }
    pub fn generation(&self) -> u64 {
        self.generation
    }
    fn has_failed(&self) -> bool {
        self.failed.load(Ordering::Acquire)
    }
    fn is_closing(&self) -> bool {
        self.close_requested
    }

    pub fn send(&self, message: Message, timeout: Duration) -> Result<(), String> {
        let cancelled = Arc::new(AtomicBool::new(false));
        let _guard = CancelWrite(cancelled.clone());
        self.send_with_cancel(self.generation, message, timeout, cancelled)
    }

    fn send_with_cancel(
        &self,
        expected_generation: u64,
        message: Message,
        timeout: Duration,
        cancelled: Arc<AtomicBool>,
    ) -> Result<(), String> {
        let (reply, receive) = mpsc::channel();
        self.commands
            .try_send(PortCommand::Send(
                expected_generation,
                message,
                cancelled,
                reply,
            ))
            .map_err(|error| match error {
                mpsc::TrySendError::Full(_) => "serial command queue is full".to_string(),
                mpsc::TrySendError::Disconnected(_) => "port owner stopped".to_string(),
            })?;
        receive
            .recv_timeout(timeout)
            .map_err(|_| "serial write timed out".to_string())?
    }

    pub fn close(&mut self, deadline: Duration) -> io::Result<()> {
        if let Some(result) = &self.joined {
            return result.clone().map_err(io::Error::other);
        }
        self.cancelled.store(true, Ordering::Release);
        if !self.close_requested {
            let _ = self.commands.try_send(PortCommand::Close);
            self.close_requested = true;
        }
        let Some(join) = self.join.as_ref() else {
            return Err(io::Error::other(
                "serial task join outcome was not recorded",
            ));
        };
        let started = Instant::now();
        while !join.is_finished() {
            if started.elapsed() >= deadline {
                return Err(io::Error::new(
                    io::ErrorKind::TimedOut,
                    "serial cleanup deadline exceeded",
                ));
            }
            std::thread::sleep(Duration::from_millis(10));
        }
        let result = self
            .join
            .take()
            .expect("join exists after finished check")
            .join()
            .map_err(|_| "serial task panicked".to_string());
        self.joined = Some(result.clone());
        result.map_err(io::Error::other)
    }

    fn is_joined(&self) -> bool {
        self.join.is_none() && self.joined.is_some()
    }
    fn expire_discovery(&mut self, now: Instant) -> bool {
        if !self.discovery_timeout_reported
            && !self.discovery_complete.load(Ordering::Acquire)
            && now >= self.discovery_deadline
        {
            self.discovery_timeout_reported = true;
            self.cancelled.store(true, Ordering::Release);
            self.failed.store(true, Ordering::Release);
            true
        } else {
            false
        }
    }
}

struct CancelWrite(Arc<AtomicBool>);
impl Drop for CancelWrite {
    fn drop(&mut self) {
        self.0.store(true, Ordering::Release);
    }
}

enum RuntimeCommand {
    Scan,
    DisconnectPort(String, u64, mpsc::Sender<Result<(), String>>),
    Shutdown,
    SendMessage(
        String,
        u64,
        Message,
        Duration,
        Arc<AtomicBool>,
        mpsc::Sender<Result<(), String>>,
    ),
    HandoffPort(String, u64, HandoffOperationId, FirmwareHandoffPin),
    ReleaseHandoff(PortHandoff, HandoffOperationId, FirmwareHandoffPin),
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct PortHandoff {
    port: String,
    generation: u64,
    reservation_id: u64,
}

impl PortHandoff {
    fn new(port: String, generation: u64) -> Self {
        static NEXT_RESERVATION_ID: AtomicU64 = AtomicU64::new(1);
        Self {
            port,
            generation,
            reservation_id: NEXT_RESERVATION_ID.fetch_add(1, Ordering::Relaxed).max(1),
        }
    }

    pub fn port(&self) -> &str {
        &self.port
    }

    pub fn generation(&self) -> u64 {
        self.generation
    }

    pub fn reservation_id(&self) -> u64 {
        self.reservation_id
    }
}

#[derive(Clone, Copy, Debug, Eq, Hash, PartialEq)]
pub struct HandoffOperationId(u64);

impl HandoffOperationId {
    pub fn get(self) -> u64 {
        self.0
    }
}

pub struct DiscoveryHandle {
    commands: mpsc::SyncSender<RuntimeCommand>,
    active_generations: Arc<Mutex<HashMap<String, u64>>>,
    join: Option<std::thread::JoinHandle<()>>,
    shutdown_started: bool,
    shutdown_deadline: Duration,
    handoff_results: Arc<Mutex<HashMap<HandoffOperationId, Result<PortHandoff, String>>>>,
    release_results: Arc<Mutex<HashMap<HandoffOperationId, Result<(), String>>>>,
    shutdown_failures: Arc<Mutex<Vec<String>>>,
    next_handoff_operation: AtomicU64,
    next_release_operation: AtomicU64,
}

impl DiscoveryHandle {
    pub fn port_generations(&self) -> HashMap<String, u64> {
        self.active_generations
            .lock()
            .expect("generation registry poisoned")
            .clone()
    }

    pub fn disconnect_port(&self, port: &str, generation: u64) -> Result<(), String> {
        let (reply, receive) = mpsc::channel();
        self.commands
            .try_send(RuntimeCommand::DisconnectPort(
                port.into(),
                generation,
                reply,
            ))
            .map_err(|_| "hardware command queue unavailable".to_string())?;
        receive
            .recv_timeout(self.shutdown_deadline + Duration::from_secs(1))
            .map_err(|_| "disconnect cleanup is still pending".to_string())?
    }

    pub fn scan_now(&self) -> Result<(), String> {
        self.commands
            .try_send(RuntimeCommand::Scan)
            .map_err(|error| match error {
                mpsc::TrySendError::Full(_) => "runtime command queue is full".into(),
                mpsc::TrySendError::Disconnected(_) => "runtime stopped".into(),
            })
    }
    pub fn send_message(
        &self,
        port: &str,
        expected_generation: u64,
        message: Message,
        timeout: Duration,
    ) -> Result<(), String> {
        let cancelled = Arc::new(AtomicBool::new(false));
        let _guard = CancelWrite(cancelled.clone());
        let (reply, receive) = mpsc::channel();
        self.commands
            .try_send(RuntimeCommand::SendMessage(
                port.to_owned(),
                expected_generation,
                message,
                timeout,
                cancelled,
                reply,
            ))
            .map_err(|error| match error {
                mpsc::TrySendError::Full(_) => "runtime command queue is full".to_string(),
                mpsc::TrySendError::Disconnected(_) => "runtime stopped".to_string(),
            })?;
        receive
            .recv_timeout(timeout)
            .map_err(|_| "serial write timed out".to_string())?
    }
    /// Start an arbiter-authorized handoff. The operation ID remains valid for querying
    /// completion after a caller timeout or UI cancellation.
    pub fn begin_handoff(
        &self,
        port: &str,
        generation: u64,
        permit: &FirmwareHandoffPermit,
    ) -> Result<HandoffOperationId, String> {
        let pin = permit.pin(port, generation).map_err(|error| {
            format!("firmware lease does not authorize this port generation: {error:?}")
        })?;
        if self
            .handoff_results
            .lock()
            .expect("handoff operation registry poisoned")
            .len()
            >= HANDOFF_RESULT_CAPACITY
        {
            return Err("handoff result capacity reached".into());
        }
        let id = HandoffOperationId(
            self.next_handoff_operation
                .fetch_add(1, Ordering::Relaxed)
                .wrapping_add(1)
                .max(1),
        );
        self.commands
            .try_send(RuntimeCommand::HandoffPort(
                port.to_owned(),
                generation,
                id,
                pin,
            ))
            .map_err(|error| match error {
                mpsc::TrySendError::Full(_) => "runtime command queue is full".to_string(),
                mpsc::TrySendError::Disconnected(_) => "runtime stopped".to_string(),
            })?;
        Ok(id)
    }

    pub fn handoff_result(
        &self,
        operation: HandoffOperationId,
    ) -> Option<Result<PortHandoff, String>> {
        self.handoff_results
            .lock()
            .expect("handoff operation registry poisoned")
            .get(&operation)
            .cloned()
    }

    pub fn take_handoff_result(
        &self,
        operation: HandoffOperationId,
    ) -> Option<Result<PortHandoff, String>> {
        self.handoff_results
            .lock()
            .expect("handoff operation registry poisoned")
            .remove(&operation)
    }

    pub fn wait_handoff(
        &self,
        operation: HandoffOperationId,
        timeout: Duration,
    ) -> Option<Result<PortHandoff, String>> {
        let deadline = Instant::now() + timeout;
        loop {
            if let Some(result) = self.handoff_result(operation) {
                return Some(result);
            }
            if Instant::now() >= deadline {
                return None;
            }
            std::thread::sleep(Duration::from_millis(2));
        }
    }

    pub fn begin_release_handoff(
        &self,
        handoff: PortHandoff,
        permit: &FirmwareHandoffPermit,
    ) -> Result<HandoffOperationId, String> {
        let pin = permit
            .pin(&handoff.port, handoff.generation)
            .map_err(|error| {
                format!("firmware lease no longer authorizes this reservation: {error:?}")
            })?;
        if self
            .release_results
            .lock()
            .expect("handoff release result registry poisoned")
            .len()
            >= HANDOFF_RESULT_CAPACITY
        {
            return Err("handoff release result capacity reached".into());
        }
        let operation = HandoffOperationId(
            self.next_release_operation
                .fetch_add(1, Ordering::Relaxed)
                .wrapping_add(1)
                .max(1),
        );
        self.commands
            .try_send(RuntimeCommand::ReleaseHandoff(handoff, operation, pin))
            .map_err(|error| match error {
                mpsc::TrySendError::Full(_) => "runtime command queue is full".to_string(),
                mpsc::TrySendError::Disconnected(_) => "runtime stopped".to_string(),
            })?;
        Ok(operation)
    }

    pub fn release_result(&self, operation: HandoffOperationId) -> Option<Result<(), String>> {
        self.release_results
            .lock()
            .expect("handoff release result registry poisoned")
            .get(&operation)
            .cloned()
    }

    pub fn take_release_result(&self, operation: HandoffOperationId) -> Option<Result<(), String>> {
        self.release_results
            .lock()
            .expect("handoff release result registry poisoned")
            .remove(&operation)
    }
    pub fn shutdown(&mut self) -> io::Result<()> {
        if !self.shutdown_started {
            self.commands
                .try_send(RuntimeCommand::Shutdown)
                .map_err(|error| match error {
                    mpsc::TrySendError::Full(_) => io::Error::new(
                        io::ErrorKind::WouldBlock,
                        "runtime command queue is full; retry shutdown",
                    ),
                    mpsc::TrySendError::Disconnected(_) => {
                        io::Error::other("discovery worker stopped before shutdown")
                    }
                })?;
            self.shutdown_started = true;
        }
        let started = Instant::now();
        let wait_deadline = self.shutdown_deadline + Duration::from_millis(100);
        while self.join.as_ref().is_some_and(|join| !join.is_finished()) {
            if started.elapsed() >= wait_deadline {
                return Err(io::Error::new(
                    io::ErrorKind::TimedOut,
                    "hardware shutdown still owns open ports; retry shutdown to join",
                ));
            }
            std::thread::sleep(Duration::from_millis(10));
        }
        if let Some(join) = self.join.take() {
            join.join()
                .map_err(|_| io::Error::other("discovery worker panicked"))?;
        }
        if let Some(failure) = self
            .shutdown_failures
            .lock()
            .expect("shutdown diagnostics poisoned")
            .first()
            .cloned()
        {
            return Err(io::Error::other(failure));
        }
        Ok(())
    }
}

/// Runtime scan policy, deliberately separate from construction to prevent default scans.
pub struct HardwareRuntime<T: SerialTransport> {
    transport: Arc<T>,
    pub discovery_timing: DiscoveryTiming,
    scan_interval: Duration,
    failure_retry: Duration,
    cleanup_deadline: Duration,
    discovery_timeout: Duration,
}

impl<T: SerialTransport> HardwareRuntime<T> {
    pub fn new(transport: Arc<T>, discovery_timing: DiscoveryTiming) -> Self {
        Self {
            transport,
            discovery_timing,
            scan_interval: SCAN_INTERVAL,
            failure_retry: FAILURE_RETRY,
            cleanup_deadline: CLEANUP_DEADLINE,
            discovery_timeout: DISCOVERY_TIMEOUT,
        }
    }

    pub fn with_policy(
        mut self,
        scan_interval: Duration,
        failure_retry: Duration,
        cleanup_deadline: Duration,
    ) -> Self {
        self.scan_interval = scan_interval;
        self.failure_retry = failure_retry;
        self.cleanup_deadline = cleanup_deadline;
        self
    }

    pub fn with_discovery_timeout(mut self, timeout: Duration) -> Self {
        self.discovery_timeout = timeout;
        self
    }

    pub fn enumerate_ports(&self) -> io::Result<Vec<String>> {
        self.transport.enumerate().map(eligible_ports)
    }

    /// Starts the initial one-second delayed scan and recurring scans. All open port
    /// workers and their handles remain in this owner until failure or shutdown.
    pub fn start<F>(self: Arc<Self>, sink: F) -> DiscoveryHandle
    where
        F: Fn(PortEvent) + Send + Sync + 'static,
        T: 'static,
    {
        let (commands, command_rx) = mpsc::sync_channel(RUNTIME_COMMAND_CAPACITY);
        let runtime_sink = Arc::new(sink);
        let shutdown_deadline = self.cleanup_deadline;
        let discovery_timeout = self.discovery_timeout;
        let handoff_results = Arc::new(Mutex::new(HashMap::new()));
        let worker_handoff_results = handoff_results.clone();
        let release_results = Arc::new(Mutex::new(HashMap::new()));
        let worker_release_results = release_results.clone();
        let shutdown_failures = Arc::new(Mutex::new(Vec::new()));
        let worker_shutdown_failures = shutdown_failures.clone();
        let active_generations = Arc::new(Mutex::new(HashMap::<String, u64>::new()));
        let worker_generations = active_generations.clone();
        let join = std::thread::Builder::new()
            .name("hardware-discovery".into())
            .spawn(move || {
                let generation_counter = AtomicU64::new(0);
                let mut ports: HashMap<String, OwnedPortTask> = HashMap::new();
                let mut retry_after: HashMap<String, Instant> = HashMap::new();
                let mut reserved_ports: HashMap<String, (PortHandoff, FirmwareHandoffPin)> = HashMap::new();
                let active_generations = worker_generations;
                let mut next_scan = Instant::now() + Duration::from_secs(1);
                let mut shutting_down = false;
                loop {
                    let wait = if shutting_down {
                        Duration::from_millis(50)
                    } else {
                        next_scan.saturating_duration_since(Instant::now()).min(
                            if ports.is_empty() {
                                self.scan_interval
                            } else {
                                Duration::from_millis(100)
                            },
                        )
                    };
                    let mut manual_scan = false;
                    match command_rx.recv_timeout(wait) {
                        Ok(RuntimeCommand::Shutdown)
                        | Err(mpsc::RecvTimeoutError::Disconnected) => shutting_down = true,
                        // Manual scan bypasses the failure backoff
                        // (connection.ex:261-267 `clear_failed_ports`): the
                        // timer is accelerated and every pending retry-after
                        // entry is dropped so failed ports are retried now.
                        Ok(RuntimeCommand::Scan) => {
                            next_scan = Instant::now();
                            manual_scan = true;
                            retry_after.clear();
                        }
                        Ok(RuntimeCommand::DisconnectPort(port,generation,reply)) => {
                            let result = if reserved_ports.contains_key(&port) {
                                Err("port is reserved for firmware".to_string())
                            } else if let Some(owner)=ports.get_mut(&port) {
                                if owner.generation()!=generation { Err("stale port generation".to_string()) }
                                else {
                                    active_generations.lock().expect("generation registry poisoned").remove(&port);
                                    owner.close(self.cleanup_deadline).map_err(|e|e.to_string())
                                }
                            } else { Err("port is not connected".into()) };
                            if result.is_ok() {
                                ports.remove(&port);
                                retry_after.insert(port.clone(),Instant::now()+self.failure_retry);
                                runtime_sink(PortEvent::Closed{port,generation});
                            }
                            let _=reply.send(result);
                        }
                        Ok(RuntimeCommand::SendMessage(
                            port,
                            expected_generation,
                            message,
                            timeout,
                            cancelled,
                            reply,
                        )) => {
                            let result = if cancelled.load(Ordering::Acquire) {
                                Err("serial write cancelled before dispatch".to_string())
                            } else if let Some(owner) = ports.get(&port) {
                                if owner.generation() != expected_generation {
                                    Err("stale port generation".to_string())
                                } else {
                                    owner.send_with_cancel(
                                        expected_generation,
                                        message,
                                        timeout,
                                        cancelled,
                                    )
                                }
                            } else {
                                Err("port is not connected".to_string())
                            };
                            let _ = reply.send(result);
                        }
                        Ok(RuntimeCommand::HandoffPort(port, expected_generation, operation, pin)) => {
                            let result = if !pin.authorizes(&port, expected_generation) {
                                Err("firmware lease expired before port close".to_string())
                            } else if reserved_ports.contains_key(&port) {
                                Err("port is already reserved".to_string())
                            } else if let Some(mut task) = ports.remove(&port) {
                                if task.generation() != expected_generation {
                                    ports.insert(port.clone(), task);
                                    Err("stale port generation".to_string())
                                } else {
                                    let handoff =
                                        PortHandoff::new(port.clone(), expected_generation);
                                    active_generations
                                        .lock()
                                        .expect("generation registry poisoned")
                                        .remove(&port);
                                    match task.close(self.cleanup_deadline) {
                                        Ok(()) => {
                                            reserved_ports.insert(port.clone(), (handoff.clone(), pin));
                                            runtime_sink(PortEvent::Closed {
                                                port: port.clone(),
                                                generation: handoff.generation,
                                            });
                                            Ok(handoff)
                                        }
                                        Err(error) => {
                                            if task.is_joined() {
                                                let reason = error.to_string();
                                                runtime_sink(PortEvent::Failed { port: port.clone(), generation: expected_generation, reason: reason.clone() });
                                                worker_shutdown_failures.lock().expect("shutdown diagnostics poisoned").push(reason);
                                                retry_after.insert(port.clone(), Instant::now() + self.failure_retry);
                                            } else {
                                                ports.insert(port.clone(), task);
                                            }
                                            Err(error.to_string())
                                        }
                                    }
                                }
                            } else if expected_generation == 0 && self.enumerate_ports().is_ok_and(|available| available.contains(&port)) {
                                // A board without firmware cannot answer identity discovery.
                                // Zero denotes an explicitly selected available port with no
                                // current scanner owner. A newly opened owner would instead
                                // take the generation-mismatch branch above.
                                let handoff = PortHandoff::new(port.clone(),0);
                                reserved_ports.insert(port.clone(),(handoff.clone(),pin));
                                Ok(handoff)
                            } else {
                                Err("port is not connected or available".to_string())
                            };
                            worker_handoff_results
                                .lock()
                                .expect("handoff operation registry poisoned")
                                .insert(operation, result);
                            next_scan = Instant::now() + self.scan_interval;
                        }
                        Ok(RuntimeCommand::ReleaseHandoff(handoff, operation, pin)) => {
                            let result = match reserved_ports.get(&handoff.port) {
                                Some((current, _)) if current == &handoff && pin.authorizes(&handoff.port, handoff.generation) => {
                                    reserved_ports.remove(&handoff.port);
                                    next_scan = Instant::now();
                                    Ok(())
                                }
                                _ => Err("invalid port handoff token".to_string()),
                            };
                            worker_release_results
                                .lock()
                                .expect("handoff release result registry poisoned")
                                .insert(operation, result);
                        }
                        Err(mpsc::RecvTimeoutError::Timeout) => {}
                    }
                    if !shutting_down {
                        for (port, task) in &mut ports {
                            if task.expire_discovery(Instant::now()) {
                                active_generations.lock().expect("generation registry poisoned").remove(port);
                                runtime_sink(PortEvent::Failed {
                                    port: port.clone(),
                                    generation: task.generation(),
                                    reason: "discovery coordinator deadline exceeded; owner retained until join".into(),
                                });
                            }
                        }
                    }
                    if shutting_down {
                        let mut closed_ports = Vec::new();
                        for (port, task) in &mut ports {
                            active_generations
                                .lock()
                                .expect("generation registry poisoned")
                                .remove(port);
                            if let Err(error) = task.close(self.cleanup_deadline) {
                                runtime_sink(PortEvent::Failed {
                                    port: port.clone(),
                                    generation: task.generation(),
                                    reason: error.to_string(),
                                });
                                if task.is_joined() {
                                    worker_shutdown_failures.lock().expect("shutdown diagnostics poisoned").push(error.to_string());
                                    closed_ports.push((port.clone(), task.generation(), false));
                                }
                            } else {
                                closed_ports.push((port.clone(), task.generation(), true));
                            }
                        }
                        for (port, generation, clean) in closed_ports {
                            ports.remove(&port);
                            active_generations
                                .lock()
                                .expect("generation registry poisoned")
                                .remove(&port);
                            if clean { runtime_sink(PortEvent::Closed { port, generation }); }
                        }
                        if ports.is_empty() && reserved_ports.is_empty() {
                            break;
                        }
                        continue;
                    }
                    if ports
                        .values()
                        .any(|task| task.has_failed() || task.is_closing())
                        && Instant::now() < next_scan
                    {
                        next_scan = Instant::now();
                    }
                    if Instant::now() < next_scan {
                        continue;
                    }
                    next_scan = Instant::now() + self.scan_interval;
                    let failed_ports = ports
                        .iter()
                        .filter(|(_, task)| task.has_failed() || task.is_closing())
                        .map(|(port, _)| port.clone())
                        .collect::<Vec<_>>();
                    for port in failed_ports {
                        let mut closed = false;
                        let mut joined_failure = false;
                        if let Some(task) = ports.get_mut(&port) {
                            let generation = task.generation();
                            active_generations
                                .lock()
                                .expect("generation registry poisoned")
                                .remove(&port);
                            match task.close(self.cleanup_deadline) {
                                Err(error) => {
                                    runtime_sink(PortEvent::Failed { port: port.clone(), generation, reason: error.to_string() });
                                    if task.is_joined() {
                                        worker_shutdown_failures.lock().expect("shutdown diagnostics poisoned").push(error.to_string());
                                        closed = true;
                                        joined_failure = true;
                                    }
                                }
                                Ok(()) => closed = true,
                            }
                            if closed && !joined_failure {
                                runtime_sink(PortEvent::Closed {
                                    port: port.clone(),
                                    generation,
                                });
                            }
                        }
                        if closed {
                            ports.remove(&port);
                            active_generations
                                .lock()
                                .expect("generation registry poisoned")
                                .remove(&port);
                            retry_after.insert(port, Instant::now() + self.failure_retry);
                            next_scan = Instant::now() + self.failure_retry;
                        }
                    }
                    // Cleanup above can reinsert the failed owner's backoff
                    // after the Scan command was accepted. Bypass that new
                    // entry too, after joining the old owner and before open.
                    if manual_scan { retry_after.clear(); }
                    let available = match self.enumerate_ports() {
                        Ok(available) => available
                            .into_iter()
                            .collect::<std::collections::HashSet<_>>(),
                        Err(error) => {
                            runtime_sink(PortEvent::Failed {
                                port: String::new(),
                                generation: 0,
                                reason: error.to_string(),
                            });
                            continue;
                        }
                    };
                    let removed = ports
                        .keys()
                        .filter(|port| !available.contains(*port))
                        .cloned()
                        .collect::<Vec<_>>();
                    for port in removed {
                        let mut closed = false;
                        let mut joined_failure = false;
                        if let Some(owner) = ports.get_mut(&port) {
                            let generation = owner.generation();
                            active_generations
                                .lock()
                                .expect("generation registry poisoned")
                                .remove(&port);
                            match owner.close(self.cleanup_deadline) {
                                Err(error) => {
                                    runtime_sink(PortEvent::Failed {
                                        port: port.clone(),
                                        generation,
                                        reason: error.to_string(),
                                    });
                                    // A joined worker (for example a panicked reader) has no
                                    // handle left to retry; record the failure and remove only
                                    // this owner. An unfinished owner stays quarantined until
                                    // it can join, never dropping unrelated live owners.
                                    if owner.is_joined() {
                                        worker_shutdown_failures
                                            .lock()
                                            .expect("shutdown diagnostics poisoned")
                                            .push(error.to_string());
                                        closed = true;
                                        joined_failure = true;
                                    }
                                }
                                Ok(()) => closed = true,
                            }
                            if closed && !joined_failure {
                                runtime_sink(PortEvent::Closed {
                                    port: port.clone(),
                                    generation,
                                });
                            }
                        }
                        if closed {
                            ports.remove(&port);
                            active_generations
                                .lock()
                                .expect("generation registry poisoned")
                                .remove(&port);
                        }
                    }
                    // A bootloader can appear under a different port name.
                    // While firmware owns any reservation, retain existing
                    // unrelated connections but admit no new serial owners;
                    // the uploader alone probes the replacement port. Once
                    // the handoff is acknowledged released, scanning resumes.
                    if !reserved_ports.is_empty() { continue; }
                    for port in available {
                        if reserved_ports.contains_key(&port)
                            || ports.contains_key(&port)
                            || retry_after
                                .get(&port)
                                .is_some_and(|at| *at > Instant::now())
                        {
                            continue;
                        }
                        let generation = generation_counter
                            .fetch_add(1, Ordering::Relaxed)
                            .wrapping_add(1)
                            .max(1);
                        active_generations
                            .lock()
                            .expect("generation registry poisoned")
                            .insert(port.clone(), generation);
                        let sink = runtime_sink.clone();
                        let port_for_event = port.clone();
                        let event_generations = active_generations.clone();
                        let task = OwnedPortTask::spawn(
                            self.transport.clone(),
                            port.clone(),
                            generation,
                            self.discovery_timing,
                            discovery_timeout,
                            move |event| {
                                let current = event_generations
                                    .lock()
                                    .expect("generation registry poisoned")
                                    .get(&port_for_event)
                                    .copied();
                                if current == Some(generation)
                                    && event_port(&event) == port_for_event
                                {
                                    sink(event);
                                }
                            },
                        );
                        ports.insert(port, task);
                    }
                }
            })
            .expect("failed to spawn hardware discovery worker");
        DiscoveryHandle {
            commands,
            active_generations,
            join: Some(join),
            shutdown_started: false,
            shutdown_deadline,
            handoff_results,
            release_results,
            shutdown_failures,
            next_handoff_operation: AtomicU64::new(0),
            next_release_operation: AtomicU64::new(0),
        }
    }
}

fn event_port(event: &PortEvent) -> &str {
    match event {
        PortEvent::Discovered { port, .. }
        | PortEvent::Message { port, .. }
        | PortEvent::ProtocolError { port, .. }
        | PortEvent::Failed { port, .. }
        | PortEvent::Closed { port, .. } => port,
    }
}
