//! Injectable serial runtime. Construction is inert; [`HardwareRuntime::start`]
//! explicitly begins periodic discovery and owns all port workers until shutdown.
pub mod configuration;
pub mod discovery;
pub mod sessions;
pub mod transport;

use std::collections::HashMap;
use std::io;
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::{mpsc, Arc, Mutex};
use std::time::{Duration, Instant};

use discovery::DiscoveryTiming;
use transport::{eligible_ports, SerialTransport};
use trenino_core::hardware::protocol::{decode_message, encode_message, FrameDecoder, Message};

pub const DEFAULT_BAUD: u32 = 115_200;
pub const SCAN_INTERVAL: Duration = Duration::from_millis(60_000);
pub const FAILURE_RETRY: Duration = Duration::from_millis(30_000);
pub const DISCOVERY_TIMEOUT: Duration = Duration::from_millis(10_000);
pub const CLEANUP_DEADLINE: Duration = Duration::from_millis(5_000);

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

enum PortCommand {
    Send(Message, Arc<AtomicBool>, mpsc::Sender<Result<(), String>>),
    Close,
}

/// A port task exclusively owns its open serial handle, reader, decoder, and writes.
pub struct OwnedPortTask {
    port: String,
    generation: u64,
    cancelled: Arc<AtomicBool>,
    failed: Arc<AtomicBool>,
    commands: mpsc::Sender<PortCommand>,
    join: Option<std::thread::JoinHandle<()>>,
}

impl OwnedPortTask {
    fn spawn<T, F>(
        transport: Arc<T>,
        port: String,
        generation: u64,
        timing: DiscoveryTiming,
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
        let (commands, command_rx) = mpsc::channel();
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
                                reason: error.to_string(),
                            });
                            return;
                        }
                    };
                let identity =
                    match discovery::discover_with_cancel(serial.as_mut(), timing, || {
                        worker_cancelled.load(Ordering::Acquire)
                    }) {
                        Ok(identity) => identity,
                        Err(error) => {
                            if !worker_cancelled.load(Ordering::Acquire) {
                                worker_failed.store(true, Ordering::Release);
                                sink(PortEvent::Failed {
                                    port: thread_port,
                                    generation,
                                    reason: format!("{error:?}"),
                                });
                            }
                            return;
                        }
                    };
                sink(PortEvent::Discovered {
                    port: worker_port.clone(),
                    generation,
                    identity,
                });
                let mut decoder = FrameDecoder::default();
                let mut buffer = [0u8; 512];
                loop {
                    if worker_cancelled.load(Ordering::Acquire) {
                        break;
                    }
                    match command_rx.try_recv() {
                        Ok(PortCommand::Close) | Err(mpsc::TryRecvError::Disconnected) => break,
                        Ok(PortCommand::Send(message, cancelled, reply)) => {
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
                                        worker_failed.store(true, Ordering::Release);
                                        sink(PortEvent::Failed {
                                            port: worker_port.clone(),
                                            generation,
                                            reason: format!("invalid frame: {error:?}"),
                                        });
                                        break;
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

    pub fn send(&self, message: Message, timeout: Duration) -> Result<(), String> {
        let cancelled = Arc::new(AtomicBool::new(false));
        let _guard = CancelWrite(cancelled.clone());
        self.send_with_cancel(message, timeout, cancelled)
    }

    fn send_with_cancel(
        &self,
        message: Message,
        timeout: Duration,
        cancelled: Arc<AtomicBool>,
    ) -> Result<(), String> {
        let (reply, receive) = mpsc::channel();
        self.commands
            .send(PortCommand::Send(message, cancelled, reply))
            .map_err(|_| "port owner stopped".to_string())?;
        receive
            .recv_timeout(timeout)
            .map_err(|_| "serial write timed out".to_string())?
    }

    pub fn close(mut self, deadline: Duration) -> io::Result<()> {
        self.cancelled.store(true, Ordering::Release);
        let _ = self.commands.send(PortCommand::Close);
        let join = self.join.take().expect("port task already joined");
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
        join.join()
            .map_err(|_| io::Error::other("serial task panicked"))
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
    Shutdown,
    SendMessage(
        String,
        Message,
        Duration,
        Arc<AtomicBool>,
        mpsc::Sender<Result<(), String>>,
    ),
    HandoffPort(String, mpsc::Sender<Result<PortHandoff, String>>),
    ReleaseHandoff(PortHandoff, mpsc::Sender<Result<(), String>>),
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct PortHandoff {
    pub port: String,
    pub generation: u64,
}

pub struct DiscoveryHandle {
    commands: mpsc::Sender<RuntimeCommand>,
    join: Option<std::thread::JoinHandle<()>>,
}

impl DiscoveryHandle {
    pub fn scan_now(&self) -> Result<(), String> {
        self.commands
            .send(RuntimeCommand::Scan)
            .map_err(|_| "runtime stopped".into())
    }
    pub fn send_message(
        &self,
        port: &str,
        message: Message,
        timeout: Duration,
    ) -> Result<(), String> {
        let cancelled = Arc::new(AtomicBool::new(false));
        let _guard = CancelWrite(cancelled.clone());
        let (reply, receive) = mpsc::channel();
        self.commands
            .send(RuntimeCommand::SendMessage(
                port.to_owned(),
                message,
                timeout,
                cancelled,
                reply,
            ))
            .map_err(|_| "runtime stopped".to_string())?;
        receive
            .recv_timeout(timeout)
            .map_err(|_| "serial write timed out".to_string())?
    }
    /// Close and join the owned serial task before an external firmware tool opens the port.
    /// The reservation persists until `release_handoff` is explicitly called.
    pub fn handoff_port(&self, port: &str, timeout: Duration) -> Result<PortHandoff, String> {
        let (reply, receive) = mpsc::channel();
        self.commands
            .send(RuntimeCommand::HandoffPort(port.to_owned(), reply))
            .map_err(|_| "runtime stopped".to_string())?;
        receive
            .recv_timeout(timeout)
            .map_err(|_| "port handoff timed out".to_string())?
    }

    pub fn release_handoff(&self, handoff: PortHandoff, timeout: Duration) -> Result<(), String> {
        let (reply, receive) = mpsc::channel();
        self.commands
            .send(RuntimeCommand::ReleaseHandoff(handoff, reply))
            .map_err(|_| "runtime stopped".to_string())?;
        receive
            .recv_timeout(timeout)
            .map_err(|_| "handoff release timed out".to_string())?
    }
    pub fn shutdown(mut self) -> io::Result<()> {
        let _ = self.commands.send(RuntimeCommand::Shutdown);
        if let Some(join) = self.join.take() {
            join.join()
                .map_err(|_| io::Error::other("discovery worker panicked"))?;
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
}

impl<T: SerialTransport> HardwareRuntime<T> {
    pub fn new(transport: Arc<T>, discovery_timing: DiscoveryTiming) -> Self {
        Self {
            transport,
            discovery_timing,
            scan_interval: SCAN_INTERVAL,
            failure_retry: FAILURE_RETRY,
            cleanup_deadline: CLEANUP_DEADLINE,
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
        let (commands, command_rx) = mpsc::channel();
        let runtime_sink = Arc::new(sink);
        let join = std::thread::Builder::new()
            .name("hardware-discovery".into())
            .spawn(move || {
                let generation_counter = AtomicU64::new(0);
                let mut ports: HashMap<String, OwnedPortTask> = HashMap::new();
                let mut retry_after: HashMap<String, Instant> = HashMap::new();
                let mut reserved_ports: HashMap<String, u64> = HashMap::new();
                let active_generations = Arc::new(Mutex::new(HashMap::<String, u64>::new()));
                let mut next_scan = Instant::now() + Duration::from_secs(1);
                loop {
                    let wait = next_scan.saturating_duration_since(Instant::now()).min(
                        if ports.is_empty() {
                            self.scan_interval
                        } else {
                            Duration::from_millis(100)
                        },
                    );
                    match command_rx.recv_timeout(wait) {
                        Ok(RuntimeCommand::Shutdown)
                        | Err(mpsc::RecvTimeoutError::Disconnected) => break,
                        Ok(RuntimeCommand::Scan) => next_scan = Instant::now(),
                        Ok(RuntimeCommand::SendMessage(
                            port,
                            message,
                            timeout,
                            cancelled,
                            reply,
                        )) => {
                            let result = if cancelled.load(Ordering::Acquire) {
                                Err("serial write cancelled before dispatch".to_string())
                            } else if let Some(owner) = ports.get(&port) {
                                owner.send_with_cancel(message, timeout, cancelled)
                            } else {
                                Err("port is not connected".to_string())
                            };
                            let _ = reply.send(result);
                        }
                        Ok(RuntimeCommand::HandoffPort(port, reply)) => {
                            let result = if let Some(task) = ports.remove(&port) {
                                let handoff = PortHandoff {
                                    port: port.clone(),
                                    generation: task.generation(),
                                };
                                active_generations
                                    .lock()
                                    .expect("generation registry poisoned")
                                    .remove(&port);
                                match task.close(self.cleanup_deadline) {
                                    Ok(()) => {
                                        reserved_ports.insert(port.clone(), handoff.generation);
                                        runtime_sink(PortEvent::Closed {
                                            port,
                                            generation: handoff.generation,
                                        });
                                        Ok(handoff)
                                    }
                                    Err(error) => Err(error.to_string()),
                                }
                            } else {
                                let generation = 0;
                                reserved_ports.insert(port.clone(), generation);
                                Ok(PortHandoff { port, generation })
                            };
                            let _ = reply.send(result);
                            next_scan = Instant::now() + self.scan_interval;
                        }
                        Ok(RuntimeCommand::ReleaseHandoff(handoff, reply)) => {
                            let result = match reserved_ports.get(&handoff.port) {
                                Some(generation) if *generation == handoff.generation => {
                                    reserved_ports.remove(&handoff.port);
                                    next_scan = Instant::now();
                                    Ok(())
                                }
                                _ => Err("invalid port handoff token".to_string()),
                            };
                            let _ = reply.send(result);
                        }
                        Err(mpsc::RecvTimeoutError::Timeout) => {}
                    }
                    if ports.values().any(OwnedPortTask::has_failed) && Instant::now() < next_scan {
                        next_scan = Instant::now();
                    }
                    if Instant::now() < next_scan {
                        continue;
                    }
                    next_scan = Instant::now() + self.scan_interval;
                    let failed_ports = ports
                        .iter()
                        .filter(|(_, task)| task.has_failed())
                        .map(|(port, _)| port.clone())
                        .collect::<Vec<_>>();
                    for port in failed_ports {
                        if let Some(task) = ports.remove(&port) {
                            let generation = task.generation();
                            if let Err(error) = task.close(self.cleanup_deadline) {
                                runtime_sink(PortEvent::Failed {
                                    port: port.clone(),
                                    generation,
                                    reason: error.to_string(),
                                });
                            }
                            active_generations
                                .lock()
                                .expect("generation registry poisoned")
                                .remove(&port);
                            retry_after.insert(port, Instant::now() + self.failure_retry);
                            next_scan = Instant::now() + self.failure_retry;
                        }
                    }
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
                        if let Some(owner) = ports.remove(&port) {
                            let generation = owner.generation();
                            active_generations
                                .lock()
                                .expect("generation registry poisoned")
                                .remove(&port);
                            if let Err(error) = owner.close(self.cleanup_deadline) {
                                runtime_sink(PortEvent::Failed {
                                    port: port.clone(),
                                    generation,
                                    reason: error.to_string(),
                                });
                            }
                        }
                    }
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
                for (_, task) in ports {
                    let port = task.port().to_owned();
                    let generation = task.generation();
                    if let Err(error) = task.close(self.cleanup_deadline) {
                        runtime_sink(PortEvent::Failed {
                            port: port.clone(),
                            generation,
                            reason: error.to_string(),
                        });
                    }
                    active_generations
                        .lock()
                        .expect("generation registry poisoned")
                        .remove(&port);
                }
            })
            .expect("failed to spawn hardware discovery worker");
        DiscoveryHandle {
            commands,
            join: Some(join),
        }
    }
}

fn event_port(event: &PortEvent) -> &str {
    match event {
        PortEvent::Discovered { port, .. }
        | PortEvent::Message { port, .. }
        | PortEvent::Failed { port, .. }
        | PortEvent::Closed { port, .. } => port,
    }
}
