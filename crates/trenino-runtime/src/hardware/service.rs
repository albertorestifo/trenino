//! Runtime-owned orchestration above the low-level serial scanner.
//!
//! The service is deliberately injected with the one repository adapter and shared
//! output consumer used by the application. It owns event routing, configuration
//! operations, sessions, leases, and the scanner lifetime; UI callers only receive
//! operation IDs and snapshots.
use std::collections::{HashMap, HashSet, VecDeque};
use std::io;
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::{mpsc, Arc, Condvar, Mutex};
use std::thread::JoinHandle;
use std::time::{Duration, Instant};

use trenino_core::hardware::protocol::Message;
use trenino_core::{ConfigId, EntityId, SessionId};

use crate::resource::{LeaseKind, LeaseToken, ResourceArbiter, ResourceConsumers, ResourceError};
use crate::routing::{InputEvent, InputIdentity, InputResolver, InputValueCache};

use super::configuration::{
    apply_configuration, ApplyError, ConfigurationApply, ConfigurationPort, ConfigurationRepository,
};
use super::discovery::DiscoveryTiming;
use super::sessions::{
    CalibrationRepository, CalibrationSession, DetectionOutcome, HardwareSessions,
    InputDetectionSession, InputKind, SessionError,
};
use super::transport::SerialTransport;
use super::{
    DiscoveryHandle, HandoffOperationId, HardwareRuntime, PortEvent, PortHandoff, CLEANUP_DEADLINE,
    FAILURE_RETRY, SCAN_INTERVAL,
};

const EVENT_CAPACITY: usize = 4096;
const ACK_CAPACITY: usize = 256;
const MAX_OPERATIONS: usize = 1024;
type DispatcherControl = (mpsc::SyncSender<Option<PortEvent>>, JoinHandle<()>);
type ConfigurationWorker = (Arc<AtomicBool>, JoinHandle<()>);
type ConfigurationResults =
    Arc<Mutex<HashMap<ConfigurationOperationId, Option<Result<(), ApplyError>>>>>;

#[derive(Clone, Debug)]
pub struct PersistedInputMapping {
    pub pin: u8,
    pub identity: InputIdentity,
    pub kind: InputKind,
}

#[derive(Clone, Debug)]
pub struct PersistedHardwareConfiguration {
    pub device_id: EntityId,
    pub config_id: ConfigId,
    pub mappings: Vec<PersistedInputMapping>,
}

/// Implemented by the application's one repository adapter. The lookup must resolve
/// the observed port/identity to the already-persisted board and input rows.
pub trait HardwareRepository:
    ConfigurationRepository + CalibrationRepository + Send + 'static
{
    fn load_configuration(
        &mut self,
        port: &str,
        identity: &Message,
    ) -> Result<Option<PersistedHardwareConfiguration>, String>;
}

pub trait HardwareConsumers: ResourceConsumers {
    /// Synchronously accepts one authoritative input edge/sample. Returning an error
    /// fails closed for this port generation; consumers must not silently discard it.
    fn dispatch_input(&self, identity: InputIdentity, event: InputEvent) -> Result<(), String>;
    fn protocol_error(&self, port: &str, generation: u64, reason: &str);
    fn configuration_applied(&self, port: &str, generation: u64, config_id: ConfigId);
    fn detection_outcome(&self, id: SessionId, outcome: DetectionOutcome);
    fn calibration_error(&self, id: SessionId, error: SessionError);
}

#[derive(Clone, Copy, Debug, Eq, Hash, PartialEq)]
pub struct ConfigurationOperationId(u64);

impl ConfigurationOperationId {
    pub fn get(self) -> u64 {
        self.0
    }
}

#[derive(Clone, Debug)]
struct CurrentPort {
    generation: u64,
    config_id: Option<ConfigId>,
    device_id: Option<EntityId>,
    kinds: HashMap<u8, InputKind>,
}

#[derive(Default)]
struct DispatcherState {
    ports: HashMap<String, CurrentPort>,
}

#[derive(Default)]
struct AckState {
    messages: VecDeque<(u64, Message)>,
    closed: bool,
}

#[derive(Default)]
struct AckInbox {
    state: Mutex<AckState>,
    changed: Condvar,
}

impl AckInbox {
    fn push(&self, generation: u64, message: Message) -> Result<(), String> {
        let mut state = self.state.lock().expect("configuration ACK inbox poisoned");
        if state.closed {
            return Err("configuration ACK inbox is closed".into());
        }
        if state.messages.len() >= ACK_CAPACITY {
            return Err("configuration ACK inbox is full".into());
        }
        state.messages.push_back((generation, message));
        self.changed.notify_all();
        Ok(())
    }

    fn receive(
        &self,
        generation: u64,
        timeout: Duration,
        cancelled: &AtomicBool,
    ) -> Result<Option<Message>, String> {
        let deadline = Instant::now() + timeout;
        let mut state = self.state.lock().expect("configuration ACK inbox poisoned");
        loop {
            if cancelled.load(Ordering::Acquire) || state.closed {
                return Err("configuration operation cancelled".into());
            }
            while let Some((message_generation, message)) = state.messages.pop_front() {
                if message_generation == generation {
                    return Ok(Some(message));
                }
            }
            let remaining = deadline.saturating_duration_since(Instant::now());
            if remaining.is_zero() {
                return Ok(None);
            }
            let (next, wait) = self
                .changed
                .wait_timeout(state, remaining.min(Duration::from_millis(20)))
                .expect("configuration ACK inbox poisoned");
            state = next;
            if wait.timed_out() && Instant::now() >= deadline {
                return Ok(None);
            }
        }
    }

    fn close(&self) {
        let mut state = self.state.lock().expect("configuration ACK inbox poisoned");
        state.closed = true;
        state.messages.clear();
        self.changed.notify_all();
    }
}

struct CoordinatedConsumers<C: HardwareConsumers> {
    inner: Arc<C>,
    sessions: Arc<HardwareSessions>,
    calibration_lease: Arc<Mutex<HashMap<String, (SessionId, LeaseToken)>>>,
    arbiter: Mutex<std::sync::Weak<ResourceArbiter>>,
}

impl<C: HardwareConsumers> ResourceConsumers for CoordinatedConsumers<C> {
    fn suspend_actuation(&self, port: &str) -> Result<(), String> {
        self.inner.suspend_actuation(port)
    }

    fn cancel_calibration(&self, port: &str) -> Result<(), String> {
        self.sessions.cancel_calibrations_on(port);
        if let Some((_, token)) = self
            .calibration_lease
            .lock()
            .expect("calibration lease registry poisoned")
            .remove(port)
        {
            if let Some(arbiter) = self
                .arbiter
                .lock()
                .expect("arbiter weak ref poisoned")
                .upgrade()
            {
                arbiter
                    .release(token)
                    .map_err(|error| format!("cancelled calibration did not release: {error:?}"))?;
            }
        }
        self.inner.cancel_calibration(port)
    }

    fn source_lost(&self, port: &str, generation: u64) -> Result<(), String> {
        self.sessions.source_lost(port, generation);
        self.inner.source_lost(port, generation)
    }

    fn resume_after_fresh_sample(&self, port: &str) -> Result<(), String> {
        self.inner.resume_after_fresh_sample(port)
    }
}

struct RuntimeConfigurationPort<C: HardwareConsumers> {
    port: String,
    generation: u64,
    scanner: Arc<Mutex<DiscoveryHandle>>,
    state: Arc<Mutex<DispatcherState>>,
    ack: Arc<AckInbox>,
    cancelled: Arc<AtomicBool>,
    _consumer: std::marker::PhantomData<C>,
}

impl<C: HardwareConsumers> ConfigurationPort for RuntimeConfigurationPort<C> {
    fn generation(&self) -> u64 {
        if self.cancelled.load(Ordering::Acquire) {
            return 0;
        }
        self.state
            .lock()
            .expect("hardware dispatcher state poisoned")
            .ports
            .get(&self.port)
            .map(|port| port.generation)
            .unwrap_or(0)
    }

    fn send(&mut self, message: &Message) -> Result<(), String> {
        if self.cancelled.load(Ordering::Acquire) {
            return Err("configuration operation cancelled".into());
        }
        self.scanner
            .lock()
            .expect("hardware scanner handle poisoned")
            .send_message(
                &self.port,
                self.generation,
                message.clone(),
                Duration::from_secs(2),
            )
    }

    fn receive(&mut self, timeout: Duration) -> Result<Option<Message>, String> {
        self.ack.receive(self.generation, timeout, &self.cancelled)
    }
}

pub struct HardwareService<T, R, C>
where
    T: SerialTransport,
    R: HardwareRepository,
    C: HardwareConsumers,
{
    transport: Arc<T>,
    timing: DiscoveryTiming,
    scan_interval: Duration,
    failure_retry: Duration,
    cleanup_deadline: Duration,
    repository: Arc<Mutex<R>>,
    consumer: Arc<C>,
    sessions: Arc<HardwareSessions>,
    resolver: Arc<InputResolver>,
    cache: Arc<InputValueCache>,
    coordinated_consumers: Arc<CoordinatedConsumers<C>>,
    arbiter: Arc<ResourceArbiter>,
    started: AtomicBool,
}

impl<T, R, C> HardwareService<T, R, C>
where
    T: SerialTransport,
    R: HardwareRepository,
    C: HardwareConsumers,
{
    pub fn new(
        transport: Arc<T>,
        timing: DiscoveryTiming,
        repository: R,
        consumer: Arc<C>,
    ) -> Self {
        let sessions = Arc::new(HardwareSessions::default());
        let resolver = Arc::new(InputResolver::default());
        let cache = Arc::new(InputValueCache::default());
        let calibration_lease = Arc::new(Mutex::new(HashMap::new()));
        let coordinated_consumers = Arc::new(CoordinatedConsumers {
            inner: consumer.clone(),
            sessions: sessions.clone(),
            calibration_lease,
            arbiter: Mutex::new(std::sync::Weak::new()),
        });
        let arbiter = Arc::new(ResourceArbiter::new(coordinated_consumers.clone()));
        *coordinated_consumers
            .arbiter
            .lock()
            .expect("arbiter weak ref poisoned") = Arc::downgrade(&arbiter);
        Self {
            transport,
            timing,
            scan_interval: SCAN_INTERVAL,
            failure_retry: FAILURE_RETRY,
            cleanup_deadline: CLEANUP_DEADLINE,
            repository: Arc::new(Mutex::new(repository)),
            consumer,
            sessions,
            resolver,
            cache,
            coordinated_consumers,
            arbiter,
            started: AtomicBool::new(false),
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

    /// Explicitly starts the scanner and the service-owned dispatcher. Construction is inert.
    pub fn start(self: Arc<Self>) -> io::Result<HardwareServiceHandle<T, R, C>> {
        if self.started.swap(true, Ordering::AcqRel) {
            return Err(io::Error::new(
                io::ErrorKind::AlreadyExists,
                "hardware service already started",
            ));
        }
        let (event_tx, event_rx) = mpsc::sync_channel::<Option<PortEvent>>(EVENT_CAPACITY);
        let dispatcher_tx = event_tx.clone();
        let state = Arc::new(Mutex::new(DispatcherState::default()));
        let ack = Arc::new(AckInbox::default());
        let dispatcher_service = self.clone();
        let dispatcher_state = state.clone();
        let dispatcher_ack = ack.clone();
        let dispatcher = match std::thread::Builder::new()
            .name("hardware-dispatcher".into())
            .spawn(move || {
                while let Ok(Some(event)) = event_rx.recv() {
                    dispatch_event(
                        &dispatcher_service,
                        &dispatcher_state,
                        &dispatcher_ack,
                        event,
                    );
                }
            }) {
            Ok(dispatcher) => dispatcher,
            Err(error) => {
                self.started.store(false, Ordering::Release);
                return Err(error);
            }
        };
        let runtime = Arc::new(
            HardwareRuntime::new(self.transport.clone(), self.timing).with_policy(
                self.scan_interval,
                self.failure_retry,
                self.cleanup_deadline,
            ),
        );
        let scanner = Arc::new(Mutex::new(runtime.start(move |event| {
            // Bounded backpressure preserves authoritative ordered events.
            let _ = event_tx.send(Some(event));
        })));
        Ok(HardwareServiceHandle {
            service: self,
            scanner,
            state,
            ack,
            dispatcher_shutdown: Mutex::new(Some((dispatcher_tx, dispatcher))),
            configuration_operations: Mutex::new(HashMap::new()),
            active_configuration_ports: Arc::new(Mutex::new(HashSet::new())),
            operation_results: Arc::new(Mutex::new(HashMap::new())),
            next_operation: AtomicU64::new(0),
            stopping: Arc::new(AtomicBool::new(false)),
        })
    }
}

pub struct HardwareServiceHandle<T, R, C>
where
    T: SerialTransport,
    R: HardwareRepository,
    C: HardwareConsumers,
{
    service: Arc<HardwareService<T, R, C>>,
    scanner: Arc<Mutex<DiscoveryHandle>>,
    state: Arc<Mutex<DispatcherState>>,
    ack: Arc<AckInbox>,
    dispatcher_shutdown: Mutex<Option<DispatcherControl>>,
    configuration_operations: Mutex<HashMap<ConfigurationOperationId, ConfigurationWorker>>,
    active_configuration_ports: Arc<Mutex<HashSet<String>>>,
    operation_results: ConfigurationResults,
    next_operation: AtomicU64,
    stopping: Arc<AtomicBool>,
}

impl<T, R, C> HardwareServiceHandle<T, R, C>
where
    T: SerialTransport,
    R: HardwareRepository,
    C: HardwareConsumers,
{
    pub fn resolver(&self) -> Arc<InputResolver> {
        self.service.resolver.clone()
    }

    pub fn input_cache(&self) -> Arc<InputValueCache> {
        self.service.cache.clone()
    }

    pub fn sessions(&self) -> Arc<HardwareSessions> {
        self.service.sessions.clone()
    }

    pub fn start_detection(
        &self,
        id: SessionId,
        session: InputDetectionSession,
    ) -> Result<Arc<Mutex<InputDetectionSession>>, SessionError> {
        let consumer = self.service.consumer.clone();
        self.service
            .sessions
            .insert_detection_with_callback(id, session, move |outcome| {
                consumer.detection_outcome(id, outcome);
            })
    }

    pub fn resource_arbiter(&self) -> Arc<ResourceArbiter> {
        self.service.arbiter.clone()
    }

    pub fn scan_now(&self) -> Result<(), String> {
        self.scanner
            .lock()
            .expect("hardware scanner handle poisoned")
            .scan_now()
    }

    pub fn send_message(
        &self,
        port: &str,
        generation: u64,
        message: Message,
        timeout: Duration,
    ) -> Result<(), String> {
        self.scanner
            .lock()
            .expect("hardware scanner handle poisoned")
            .send_message(port, generation, message, timeout)
    }

    pub fn acquire_firmware_lease(
        &self,
        port: impl Into<String>,
        generation: u64,
    ) -> Result<LeaseToken, ResourceError> {
        self.service.arbiter.acquire(LeaseKind::Firmware {
            port: port.into(),
            generation,
        })
    }

    pub fn begin_firmware_handoff(
        &self,
        lease: LeaseToken,
        port: &str,
        generation: u64,
    ) -> Result<HandoffOperationId, String> {
        let permit = self
            .service
            .arbiter
            .firmware_handoff_permit(lease)
            .map_err(|error| format!("firmware lease unavailable: {error:?}"))?;
        self.scanner
            .lock()
            .expect("hardware scanner handle poisoned")
            .begin_handoff(port, generation, &permit)
    }

    pub fn handoff_result(
        &self,
        operation: HandoffOperationId,
    ) -> Option<Result<PortHandoff, String>> {
        self.scanner
            .lock()
            .expect("hardware scanner handle poisoned")
            .handoff_result(operation)
    }

    pub fn take_handoff_result(
        &self,
        operation: HandoffOperationId,
    ) -> Option<Result<PortHandoff, String>> {
        self.scanner
            .lock()
            .expect("hardware scanner handle poisoned")
            .take_handoff_result(operation)
    }

    pub fn release_firmware_handoff(
        &self,
        lease: LeaseToken,
        handoff: PortHandoff,
    ) -> Result<HandoffOperationId, String> {
        let permit = self
            .service
            .arbiter
            .firmware_handoff_permit(lease)
            .map_err(|error| format!("firmware lease unavailable: {error:?}"))?;
        self.scanner
            .lock()
            .expect("hardware scanner handle poisoned")
            .begin_release_handoff(handoff, &permit)
    }

    pub fn handoff_release_result(
        &self,
        operation: HandoffOperationId,
    ) -> Option<Result<(), String>> {
        self.scanner
            .lock()
            .expect("hardware scanner handle poisoned")
            .release_result(operation)
    }

    pub fn take_handoff_release_result(
        &self,
        operation: HandoffOperationId,
    ) -> Option<Result<(), String>> {
        self.scanner
            .lock()
            .expect("hardware scanner handle poisoned")
            .take_release_result(operation)
    }

    pub fn release_firmware_lease(&self, lease: LeaseToken) -> Result<(), ResourceError> {
        self.service.arbiter.release(lease)
    }

    pub fn start_calibration(
        &self,
        session: CalibrationSession,
    ) -> Result<Arc<Mutex<CalibrationSession>>, SessionError> {
        let port = session.port.clone();
        let generation = session.generation;
        let id = session.id;
        let lease = self
            .service
            .arbiter
            .acquire(LeaseKind::Calibration {
                port: port.clone(),
                generation,
            })
            .map_err(|error| {
                SessionError::Persist(format!("calibration lease unavailable: {error:?}"))
            })?;
        let session = match self.service.sessions.insert_calibration(session) {
            Ok(session) => session,
            Err(error) => {
                let _ = self.service.arbiter.release(lease);
                return Err(error);
            }
        };
        self.service
            .coordinated_consumers
            .calibration_lease
            .lock()
            .expect("calibration lease registry poisoned")
            .insert(port, (id, lease));
        Ok(session)
    }

    pub fn cancel_calibration(&self, id: SessionId) -> Result<bool, ResourceError> {
        let Some(session) = self.service.sessions.calibration(id) else {
            return Ok(false);
        };
        session
            .lock()
            .expect("calibration session poisoned")
            .cancel();
        let lease = {
            let mut leases = self
                .service
                .coordinated_consumers
                .calibration_lease
                .lock()
                .expect("calibration lease registry poisoned");
            let port = leases
                .iter()
                .find_map(|(port, (session_id, _))| (*session_id == id).then(|| port.clone()));
            port.and_then(|port| leases.remove(&port).map(|(_, lease)| lease))
        };
        if let Some(lease) = lease {
            self.service.arbiter.release(lease)?;
        }
        Ok(true)
    }

    pub fn advance_calibration(
        &self,
        id: SessionId,
    ) -> Result<Option<trenino_core::hardware::calibration::Calibration>, SessionError> {
        let session = self
            .service
            .sessions
            .calibration(id)
            .ok_or(SessionError::InvalidStep)?;
        let result = {
            let mut repository = self
                .service
                .repository
                .lock()
                .expect("hardware repository poisoned");
            session
                .lock()
                .expect("calibration session poisoned")
                .advance_and_persist(&mut *repository)
        };
        if session
            .lock()
            .expect("calibration session poisoned")
            .terminal_result()
            .is_some()
        {
            let lease = {
                let mut leases = self
                    .service
                    .coordinated_consumers
                    .calibration_lease
                    .lock()
                    .expect("calibration lease registry poisoned");
                let port = leases
                    .iter()
                    .find_map(|(port, (session_id, _))| (*session_id == id).then(|| port.clone()));
                port.and_then(|port| leases.remove(&port).map(|(_, lease)| lease))
            };
            if let Some(lease) = lease {
                self.service.arbiter.release(lease).map_err(|error| {
                    SessionError::Persist(format!("calibration release failed: {error:?}"))
                })?;
            }
        }
        result
    }

    pub fn begin_configuration(
        &self,
        request: ConfigurationApply<Vec<(u8, InputIdentity)>>,
    ) -> Result<ConfigurationOperationId, String> {
        if self.stopping.load(Ordering::Acquire) {
            return Err("hardware service is shutting down".into());
        }
        let mut operations = self
            .configuration_operations
            .lock()
            .expect("configuration operation registry poisoned");
        if operations.len() >= MAX_OPERATIONS
            || self
                .operation_results
                .lock()
                .expect("configuration result registry poisoned")
                .len()
                >= MAX_OPERATIONS
        {
            return Err("configuration operation capacity reached".into());
        }
        let active_ports = self.active_configuration_ports.clone();
        {
            let mut active_ports_guard = active_ports
                .lock()
                .expect("active configuration port registry poisoned");
            if !active_ports_guard.insert(request.port_name.clone()) {
                return Err("configuration is already in progress for this port".into());
            }
        }
        let id = ConfigurationOperationId(
            self.next_operation
                .fetch_add(1, Ordering::Relaxed)
                .wrapping_add(1)
                .max(1),
        );
        let cancelled = Arc::new(AtomicBool::new(false));
        let result_map = self.operation_results.clone();
        result_map
            .lock()
            .expect("configuration result registry poisoned")
            .insert(id, None);
        let worker_result_map = result_map.clone();
        let scanner = self.scanner.clone();
        let state = self.state.clone();
        let ack = self.ack.clone();
        let resolver = self.service.resolver.clone();
        let cache = self.service.cache.clone();
        let repository = self.service.repository.clone();
        let consumer = self.service.consumer.clone();
        let worker_cancelled = cancelled.clone();
        let worker_request = request;
        let worker_active_ports = active_ports.clone();
        let port_name_for_cleanup = worker_request.port_name.clone();
        let worker = std::thread::Builder::new()
            .name(format!("hardware-config-{}", id.0))
            .spawn(move || {
                let port_name = worker_request.port_name.clone();
                let generation = worker_request.generation;
                let config_id = worker_request.config_id;
                let mut port = RuntimeConfigurationPort::<C> {
                    port: port_name.clone(),
                    generation,
                    scanner,
                    state,
                    ack,
                    cancelled: worker_cancelled,
                    _consumer: std::marker::PhantomData,
                };
                let result = {
                    let mut repository = repository.lock().expect("hardware repository poisoned");
                    apply_configuration(
                        &mut port,
                        &mut *repository,
                        &resolver,
                        &cache,
                        worker_request,
                        || consumer.configuration_applied(&port_name, generation, config_id),
                    )
                };
                worker_result_map
                    .lock()
                    .expect("configuration result registry poisoned")
                    .insert(id, Some(result));
                worker_active_ports
                    .lock()
                    .expect("active configuration port registry poisoned")
                    .remove(&port_name);
            })
            .map_err(|error| {
                result_map
                    .lock()
                    .expect("configuration result registry poisoned")
                    .remove(&id);
                active_ports
                    .lock()
                    .expect("active configuration port registry poisoned")
                    .remove(&port_name_for_cleanup);
                format!("failed to start configuration operation: {error}")
            })?;
        operations.insert(id, (cancelled, worker));
        Ok(id)
    }

    pub fn configuration_result(
        &self,
        id: ConfigurationOperationId,
    ) -> Option<Result<(), ApplyError>> {
        let result = self
            .operation_results
            .lock()
            .expect("configuration result registry poisoned")
            .get(&id)?
            .clone()?;
        if let Some((_, worker)) = self
            .configuration_operations
            .lock()
            .expect("configuration operation registry poisoned")
            .remove(&id)
        {
            let _ = worker.join();
        }
        Some(result)
    }

    pub fn take_configuration_result(
        &self,
        id: ConfigurationOperationId,
    ) -> Option<Result<(), ApplyError>> {
        let result = self.configuration_result(id)?;
        self.operation_results
            .lock()
            .expect("configuration result registry poisoned")
            .remove(&id);
        Some(result)
    }

    pub fn shutdown(&mut self) -> io::Result<()> {
        self.stopping.store(true, Ordering::Release);
        for (cancelled, _) in self
            .configuration_operations
            .lock()
            .expect("configuration operation registry poisoned")
            .values()
        {
            cancelled.store(true, Ordering::Release);
        }
        self.scanner
            .lock()
            .expect("hardware scanner handle poisoned")
            .shutdown()?;
        self.ack.close();
        if let Some((sender, dispatcher)) = self
            .dispatcher_shutdown
            .get_mut()
            .expect("dispatcher handle poisoned")
            .take()
        {
            let stop_result = sender.send(None);
            dispatcher
                .join()
                .map_err(|_| io::Error::other("hardware dispatcher panicked"))?;
            if stop_result.is_err() {
                return Err(io::Error::other(
                    "hardware dispatcher stopped before shutdown signal",
                ));
            }
        }
        let operations = std::mem::take(
            &mut *self
                .configuration_operations
                .lock()
                .expect("configuration operation registry poisoned"),
        );
        for (_, (cancelled, worker)) in operations {
            cancelled.store(true, Ordering::Release);
            if worker.join().is_err() {
                return Err(io::Error::other("configuration operation panicked"));
            }
        }
        self.service.sessions.shutdown();
        self.service
            .arbiter
            .shutdown()
            .map_err(|error| io::Error::other(format!("resource shutdown failed: {error:?}")))?;
        Ok(())
    }
}

fn dispatch_event<T, R, C>(
    service: &HardwareService<T, R, C>,
    state: &Arc<Mutex<DispatcherState>>,
    ack: &Arc<AckInbox>,
    event: PortEvent,
) where
    T: SerialTransport,
    R: HardwareRepository,
    C: HardwareConsumers,
{
    match event {
        PortEvent::Discovered {
            port,
            generation,
            identity,
        } => {
            let previous_generation = {
                let state = state.lock().expect("hardware dispatcher state poisoned");
                if state
                    .ports
                    .get(&port)
                    .is_some_and(|current| current.generation >= generation)
                {
                    return;
                }
                state.ports.get(&port).map(|current| current.generation)
            };
            if let Some(previous_generation) = previous_generation {
                mark_source_lost(service, state, &port, previous_generation);
            }
            {
                let mut state = state.lock().expect("hardware dispatcher state poisoned");
                state.ports.insert(
                    port.clone(),
                    CurrentPort {
                        generation,
                        config_id: None,
                        device_id: None,
                        kinds: HashMap::new(),
                    },
                );
            }
            let persisted = {
                let mut repository = service
                    .repository
                    .lock()
                    .expect("hardware repository poisoned");
                repository.load_configuration(&port, &identity)
            };
            let mut current = CurrentPort {
                generation,
                config_id: None,
                device_id: None,
                kinds: HashMap::new(),
            };
            match persisted {
                Ok(Some(configuration)) => {
                    let firmware_config = match &identity {
                        Message::IdentityResponse { config_id, .. } => {
                            ConfigId::new(*config_id).ok()
                        }
                        _ => None,
                    };
                    let mappings_valid = configuration
                        .mappings
                        .iter()
                        .all(|mapping| mapping.identity.device_id == configuration.device_id);
                    if firmware_config == Some(configuration.config_id) && mappings_valid {
                        let mappings = configuration
                            .mappings
                            .iter()
                            .map(|mapping| (mapping.pin, mapping.identity));
                        if service.resolver.replace_port(
                            &port,
                            generation,
                            configuration.config_id,
                            mappings,
                        ) {
                            current.config_id = Some(configuration.config_id);
                            current.device_id = Some(configuration.device_id);
                            current.kinds = configuration
                                .mappings
                                .into_iter()
                                .map(|mapping| (mapping.pin, mapping.kind))
                                .collect();
                        }
                    } else {
                        service.consumer.protocol_error(
                            &port,
                            generation,
                            "persisted configuration does not match board identity",
                        );
                    }
                }
                Ok(None) => {}
                Err(error) => service.consumer.protocol_error(
                    &port,
                    generation,
                    &format!("configuration lookup failed: {error}"),
                ),
            }
            service.cache.activate(&port, generation);
            state
                .lock()
                .expect("hardware dispatcher state poisoned")
                .ports
                .insert(port, current);
        }
        PortEvent::Message {
            port,
            generation,
            message: Message::InputValue { pin, value },
        } => {
            let current = state
                .lock()
                .expect("hardware dispatcher state poisoned")
                .ports
                .get(&port)
                .cloned();
            let Some(current) = current.filter(|current| current.generation == generation) else {
                return;
            };
            if !service.cache.update(&port, generation, pin, value) {
                return;
            }
            let identity = current
                .config_id
                .and_then(|config| service.resolver.resolve(&port, generation, config, pin));
            let kind = current.kinds.get(&pin).copied().unwrap_or(InputKind::Any);
            service
                .sessions
                .observe_input(&port, generation, pin, value, kind, identity);
            for (id, result) in service
                .sessions
                .observe_calibrations(&port, generation, pin, value)
            {
                if let Err(error) = result {
                    service.consumer.calibration_error(id, error);
                }
            }
            if let Some(identity) = identity {
                let event = InputEvent {
                    port_generation: generation,
                    config_id: current.config_id.unwrap(),
                    pin,
                    value,
                };
                if let Err(error) = service.consumer.dispatch_input(identity, event) {
                    mark_source_lost(service, state, &port, generation);
                    service.consumer.protocol_error(
                        &port,
                        generation,
                        &format!("input dispatch failed; port suspended: {error}"),
                    );
                } else {
                    release_lost_calibration_after_fresh_input(service, &port);
                }
            }
        }
        PortEvent::Message {
            port,
            generation,
            message:
                message @ (Message::ConfigurationStored { .. } | Message::ConfigurationError { .. }),
        } => {
            if let Err(error) = ack.push(generation, message) {
                service.consumer.protocol_error(&port, generation, &error);
            }
        }
        PortEvent::Message { .. } => {}
        PortEvent::ProtocolError {
            port,
            generation,
            reason,
        } => service.consumer.protocol_error(&port, generation, &reason),
        PortEvent::Failed {
            port,
            generation,
            reason,
        } => {
            if !port.is_empty() {
                mark_source_lost(service, state, &port, generation);
            }
            service.consumer.protocol_error(&port, generation, &reason);
        }
        PortEvent::Closed { port, generation } => {
            mark_source_lost(service, state, &port, generation)
        }
    }
}

fn release_lost_calibration_after_fresh_input<T, R, C>(
    service: &HardwareService<T, R, C>,
    port: &str,
) where
    T: SerialTransport,
    R: HardwareRepository,
    C: HardwareConsumers,
{
    let lease = {
        let leases = service
            .coordinated_consumers
            .calibration_lease
            .lock()
            .expect("calibration lease registry poisoned");
        leases.get(port).copied()
    };
    let Some((session_id, token)) = lease else {
        return;
    };
    let source_lost = service
        .sessions
        .calibration(session_id)
        .is_some_and(|session| {
            session.lock().expect("calibration session poisoned").step()
                == super::sessions::CalibrationStep::SourceLost
        });
    if !source_lost {
        return;
    }
    service
        .coordinated_consumers
        .calibration_lease
        .lock()
        .expect("calibration lease registry poisoned")
        .remove(port);
    if let Err(error) = service.arbiter.release(token) {
        service.consumer.protocol_error(
            port,
            0,
            &format!("calibration lease release stayed suspended: {error:?}"),
        );
    }
}

fn mark_source_lost<T, R, C>(
    service: &HardwareService<T, R, C>,
    state: &Arc<Mutex<DispatcherState>>,
    port: &str,
    generation: u64,
) where
    T: SerialTransport,
    R: HardwareRepository,
    C: HardwareConsumers,
{
    let removed = {
        let mut state = state.lock().expect("hardware dispatcher state poisoned");
        if state
            .ports
            .get(port)
            .is_some_and(|current| current.generation == generation)
        {
            state.ports.remove(port);
            true
        } else {
            false
        }
    };
    if removed {
        service.resolver.invalidate_port(port, generation);
        service.cache.invalidate(port, generation);
        service
            .coordinated_consumers
            .source_lost(port, generation)
            .ok();
    }
}
