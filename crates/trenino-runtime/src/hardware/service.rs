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
    apply_configuration_with, ApplyError, ConfigurationApply, ConfigurationPort,
    ConfigurationRepository,
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
type DispatcherControl = (mpsc::SyncSender<Option<DispatcherMessage>>, JoinHandle<()>);
type ConfigurationWorker = (Arc<AtomicBool>, JoinHandle<()>);
type ConfigurationResults =
    Arc<Mutex<HashMap<ConfigurationOperationId, Option<Result<(), ApplyError>>>>>;
type AckInboxes = Arc<Mutex<HashMap<String, Arc<AckInbox>>>>;

enum DispatcherMessage {
    Port(PortEvent),
    ConfigurationLoaded {
        port: String,
        generation: u64,
        identity: Message,
        result: Result<Option<PersistedHardwareConfiguration>, String>,
    },
}

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

    /// Commits the destructive device deletion as one atomic storage mutation.
    /// Only [`HardwareServiceHandle::delete_device`] may call this, and only while it
    /// holds the service's runtime exclusion fence across the connected-configuration
    /// check and this commit; adapters must fail stale or duplicate attempts and never
    /// re-check connectedness themselves.
    fn delete_device_unchecked(&mut self, device_id: EntityId) -> Result<(), String>;
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
    lookup_pending: bool,
    pending_inputs: VecDeque<(u8, i16)>,
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

/// Fail-closed runtime exclusion guarding device deletion. `pending` counts deletions
/// whose storage commit has not finished, blocking new persisted-configuration
/// activation for that device across the check and the commit. `tombstones` block
/// activation forever after a successful deletion so a repository lookup that started
/// before the commit can never publish routes for the removed device afterwards.
#[derive(Default)]
struct DeviceDeletionFence {
    pending: HashMap<EntityId, usize>,
    tombstones: HashSet<EntityId>,
}

impl DeviceDeletionFence {
    fn is_blocked(&self, device: EntityId) -> bool {
        self.pending.contains_key(&device) || self.tombstones.contains(&device)
    }

    fn begin(&mut self, device: EntityId) {
        *self.pending.entry(device).or_insert(0) += 1;
    }

    fn end(&mut self, device: EntityId) {
        if let Some(count) = self.pending.get_mut(&device) {
            *count -= 1;
            if *count == 0 {
                self.pending.remove(&device);
            }
        }
    }
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
    device_deletion_fence: Arc<Mutex<DeviceDeletionFence>>,
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
            device_deletion_fence: Arc::new(Mutex::new(DeviceDeletionFence::default())),
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
        let (event_tx, event_rx) = mpsc::sync_channel::<Option<DispatcherMessage>>(EVENT_CAPACITY);
        let dispatcher_tx = event_tx.clone();
        let dispatcher_worker_tx = dispatcher_tx.clone();
        let lookup_workers = Arc::new(Mutex::new(Vec::<JoinHandle<()>>::new()));
        let dispatcher_lookup_workers = lookup_workers.clone();
        let state = Arc::new(Mutex::new(DispatcherState::default()));
        let ack_inboxes = Arc::new(Mutex::new(HashMap::<String, Arc<AckInbox>>::new()));
        let dispatcher_service = self.clone();
        let dispatcher_state = state.clone();
        let dispatcher_ack = ack_inboxes.clone();
        let dispatcher = match std::thread::Builder::new()
            .name("hardware-dispatcher".into())
            .spawn(move || {
                while let Ok(Some(event)) = event_rx.recv() {
                    match event {
                        DispatcherMessage::Port(event) => dispatch_event(
                            &dispatcher_service,
                            &dispatcher_state,
                            &dispatcher_ack,
                            event,
                            &dispatcher_worker_tx,
                            &dispatcher_lookup_workers,
                        ),
                        DispatcherMessage::ConfigurationLoaded { port, generation, identity, result } => {
                            finish_discovery(&dispatcher_service, &dispatcher_state, port, generation, identity, result,
                                &dispatcher_ack, &dispatcher_worker_tx, &dispatcher_lookup_workers);
                        }
                    }
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
            let _ = event_tx.send(Some(DispatcherMessage::Port(event)));
        })));
        Ok(HardwareServiceHandle {
            service: self,
            scanner,
            state,
            ack_inboxes,
            dispatcher_shutdown: Mutex::new(Some((dispatcher_tx, dispatcher))),
            configuration_operations: Mutex::new(HashMap::new()),
            active_configuration_ports: Arc::new(Mutex::new(HashSet::new())),
            operation_results: Arc::new(Mutex::new(HashMap::new())),
            next_operation: AtomicU64::new(0),
            stopping: Arc::new(AtomicBool::new(false)),
            admission: Mutex::new(false),
            lookup_workers,
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
    ack_inboxes: AckInboxes,
    dispatcher_shutdown: Mutex<Option<DispatcherControl>>,
    configuration_operations: Mutex<HashMap<ConfigurationOperationId, ConfigurationWorker>>,
    active_configuration_ports: Arc<Mutex<HashSet<String>>>,
    operation_results: ConfigurationResults,
    next_operation: AtomicU64,
    stopping: Arc<AtomicBool>,
    admission: Mutex<bool>,
    lookup_workers: Arc<Mutex<Vec<JoinHandle<()>>>>,
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
        let admission = self.admission.lock().expect("hardware admission poisoned");
        if *admission { return Err(SessionError::AdmissionClosed); }
        let consumer = self.service.consumer.clone();
        let result = self.service
            .sessions
            .insert_detection_with_callback(id, session, move |outcome| {
                consumer.detection_outcome(id, outcome);
            });
        drop(admission);
        result
    }

    pub fn resource_arbiter(&self) -> Arc<ResourceArbiter> {
        self.service.arbiter.clone()
    }

    pub fn scan_now(&self) -> Result<(), String> {
        let admission = self.admission.lock().expect("hardware admission poisoned");
        if *admission { return Err("hardware service is shutting down".into()); }
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
        let admission = self.admission.lock().expect("hardware admission poisoned");
        if *admission { return Err("hardware service is shutting down".into()); }
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
        let admission = self.admission.lock().expect("hardware admission poisoned");
        if *admission { return Err(ResourceError::Busy); }
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
        let admission = self.admission.lock().expect("hardware admission poisoned");
        if *admission { return Err("hardware service is shutting down".into()); }
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
            .firmware_handoff_release_permit(lease)
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

    /// Deletes one device while holding the service's fail-closed runtime exclusion
    /// across both the connected-configuration check and the repository commit.
    /// Persisted-configuration activation for the device is refused from the moment
    /// the fence is taken (mirroring the Elixir `configuration_active?` refusal with
    /// an actionable error naming the connected port), and a successful commit
    /// tombstones the device so pre-deletion lookup results can never re-activate it.
    pub fn delete_device(&self, device_id: EntityId) -> Result<(), String> {
        let admission = self.admission.lock().expect("hardware admission poisoned");
        if *admission {
            return Err("hardware service is shutting down".into());
        }
        drop(admission);
        let fence = self.service.device_deletion_fence.clone();
        fence
            .lock()
            .expect("device deletion fence poisoned")
            .begin(device_id);
        let connected_port = {
            let state = self.state.lock().expect("hardware dispatcher state poisoned");
            state.ports.iter().find_map(|(port, current)| {
                (current.device_id == Some(device_id)).then(|| port.clone())
            })
        };
        if let Some(port) = connected_port {
            fence
                .lock()
                .expect("device deletion fence poisoned")
                .end(device_id);
            return Err(format!(
                "device {} is connected on port {port}; disconnect the board before deleting it",
                device_id.0
            ));
        }
        let committed = self
            .service
            .repository
            .lock()
            .expect("hardware repository poisoned")
            .delete_device_unchecked(device_id);
        let mut fence = fence.lock().expect("device deletion fence poisoned");
        fence.end(device_id);
        if committed.is_ok() {
            fence.tombstones.insert(device_id);
        }
        committed
    }

    pub fn start_calibration(
        &self,
        session: CalibrationSession,
    ) -> Result<Arc<Mutex<CalibrationSession>>, SessionError> {
        let admission = self.admission.lock().expect("hardware admission poisoned");
        if *admission { return Err(SessionError::AdmissionClosed); }
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
        let admission = self.admission.lock().expect("hardware admission poisoned");
        if *admission || self.stopping.load(Ordering::Acquire) {
            return Err("hardware service is shutting down".into());
        }
        if self
            .service
            .device_deletion_fence
            .lock()
            .expect("device deletion fence poisoned")
            .is_blocked(request.device_id)
        {
            return Err(format!(
                "device {} is being deleted or was deleted",
                request.device_id.0
            ));
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
        let ack = Arc::new(AckInbox::default());
        self.ack_inboxes.lock().expect("ack inbox registry poisoned")
            .insert(request.port_name.clone(), ack.clone());
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
        let resolver = self.service.resolver.clone();
        let cache = self.service.cache.clone();
        let repository = self.service.repository.clone();
        let consumer = self.service.consumer.clone();
        let worker_cancelled = cancelled.clone();
        let worker_request = request;
        let deletion_fence = self.service.device_deletion_fence.clone();
        let worker_active_ports = active_ports.clone();
        let worker_ack_inboxes = self.ack_inboxes.clone();
        let operation_ack = ack.clone();
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
                    ack: operation_ack.clone(),
                    cancelled: worker_cancelled,
                    _consumer: std::marker::PhantomData,
                };
                let device_id = worker_request.device_id;
                let kinds = configuration_kinds(&worker_request.messages, &worker_request.mappings);
                let commit_state = port.state.clone();
                let confirm_repository = repository.clone();
                let result = apply_configuration_with(
                    &mut port,
                    &resolver,
                    &cache,
                    worker_request,
                    move |device_id, config_id| {
                        confirm_repository
                            .lock()
                            .expect("hardware repository poisoned")
                            .confirm_configuration(device_id, config_id)
                    },
                    || {
                        let mut state = commit_state.lock().expect("hardware dispatcher state poisoned");
                        let Some(current) = state.ports.get_mut(&port_name) else {
                            return Err(ApplyError::StaleGeneration);
                        };
                        if current.generation != generation {
                            return Err(ApplyError::StaleGeneration);
                        }
                        // The deletion fence is checked atomically with dispatcher
                        // activation: a device being deleted or already deleted can
                        // never become the port's active configuration.
                        if deletion_fence
                            .lock()
                            .expect("device deletion fence poisoned")
                            .is_blocked(device_id)
                        {
                            return Err(ApplyError::Commit(
                                "device deletion is in progress; configuration commit refused".into(),
                            ));
                        }
                        current.config_id = Some(config_id);
                        current.device_id = Some(device_id);
                        current.kinds = kinds;
                        drop(state);
                        // A confirmed configuration proves the device still exists, so a
                        // stale deletion tombstone from a previous lifecycle is cleared.
                        deletion_fence
                            .lock()
                            .expect("device deletion fence poisoned")
                            .tombstones
                            .remove(&device_id);
                        consumer.configuration_applied(&port_name, generation, config_id);
                        Ok(())
                    },
                );
                worker_result_map
                    .lock()
                    .expect("configuration result registry poisoned")
                    .insert(id, Some(result));
                worker_active_ports
                    .lock()
                    .expect("active configuration port registry poisoned")
                    .remove(&port_name);
                let mut inboxes = worker_ack_inboxes.lock().expect("ack inbox registry poisoned");
                if inboxes.get(&port_name).is_some_and(|current| Arc::ptr_eq(current, &operation_ack)) {
                    inboxes.remove(&port_name);
                }
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
                self.ack_inboxes.lock().expect("ack inbox registry poisoned").remove(&port_name_for_cleanup);
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
        {
            let mut admission = self.admission.lock().expect("hardware admission poisoned");
            *admission = true;
        }
        self.stopping.store(true, Ordering::Release);
        self.service.sessions.close_admission();
        self.service.arbiter.close_admission();
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
        for inbox in self.ack_inboxes.lock().expect("ack inbox registry poisoned").values() {
            inbox.close();
        }
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
        let lookup_workers = std::mem::take(&mut *self.lookup_workers.lock().expect("lookup worker registry poisoned"));
        for worker in lookup_workers {
            if worker.join().is_err() { return Err(io::Error::other("hardware repository lookup panicked")); }
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
    ack_inboxes: &AckInboxes,
    event: PortEvent,
    dispatcher: &mpsc::SyncSender<Option<DispatcherMessage>>,
    lookup_workers: &Arc<Mutex<Vec<JoinHandle<()>>>>,
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
                mark_source_lost(service, state, ack_inboxes, &port, previous_generation);
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
                        lookup_pending: true,
                        pending_inputs: VecDeque::new(),
                    },
                );
            }
            let repository = service.repository.clone();
            let dispatcher = dispatcher.clone();
            let lookup_port = port.clone();
            let worker = std::thread::Builder::new()
                .name(format!("hardware-lookup-{port}-{generation}"))
                .spawn(move || {
                    let result = repository.lock().expect("hardware repository poisoned")
                        .load_configuration(&lookup_port, &identity);
                    let _ = dispatcher.send(Some(DispatcherMessage::ConfigurationLoaded {
                        port: lookup_port, generation, identity, result,
                    }));
                });
            match worker {
                Ok(worker) => {
                    // Finished handles are joined only at shutdown; prune them here so
                    // reconnect churn cannot grow the registry without bound.
                    let mut workers = lookup_workers.lock().expect("lookup worker registry poisoned");
                    workers.retain(|joined| !joined.is_finished());
                    workers.push(worker);
                }
                Err(error) => service.consumer.protocol_error(&port, generation, &format!("failed to start configuration lookup: {error}")),
            }
        }
        PortEvent::Message {
            port,
            generation,
            message: Message::InputValue { pin, value },
        } => {
            {
                let mut ports = state.lock().expect("hardware dispatcher state poisoned");
                let Some(current) = ports.ports.get_mut(&port) else { return; };
                if current.generation != generation { return; }
                if current.lookup_pending {
                    if current.pending_inputs.len() < EVENT_CAPACITY {
                        current.pending_inputs.push_back((pin, value));
                    } else {
                        service.consumer.protocol_error(&port, generation, "discovery input backlog overflow");
                    }
                    return;
                }
            }
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
            if let Some(identity) = identity.filter(|_| {
                !service.arbiter.port_neutralization_failed(&port)
            }) {
                let event = InputEvent {
                    port_generation: generation,
                    config_id: current.config_id.unwrap(),
                    pin,
                    value,
                };
                if let Err(error) = service.consumer.dispatch_input(identity, event) {
                    mark_source_lost(service, state, ack_inboxes, &port, generation);
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
            if let Some(ack) = ack_inboxes.lock().expect("ack inbox registry poisoned").get(&port).cloned() {
                if let Err(error) = ack.push(generation, message) {
                    service.consumer.protocol_error(&port, generation, &error);
                }
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
                mark_source_lost(service, state, ack_inboxes, &port, generation);
            }
            service.consumer.protocol_error(&port, generation, &reason);
        }
        PortEvent::Closed { port, generation } => {
            mark_source_lost(service, state, ack_inboxes, &port, generation)
        }
    }
}

fn finish_discovery<T, R, C>(
    service: &HardwareService<T, R, C>,
    state: &Arc<Mutex<DispatcherState>>,
    port: String,
    generation: u64,
    identity: Message,
    persisted: Result<Option<PersistedHardwareConfiguration>, String>,
    ack_inboxes: &AckInboxes,
    dispatcher: &mpsc::SyncSender<Option<DispatcherMessage>>,
    lookup_workers: &Arc<Mutex<Vec<JoinHandle<()>>>>,
) where
    T: SerialTransport,
    R: HardwareRepository,
    C: HardwareConsumers,
{
    if !state.lock().expect("hardware dispatcher state poisoned").ports
        .get(&port).is_some_and(|current| current.generation == generation) { return; }
    let mut current = CurrentPort { generation, config_id: None, device_id: None, kinds: HashMap::new(), lookup_pending: false, pending_inputs: VecDeque::new() };
    // Persisted configuration that matched the board identity; activation happens
    // below inside the dispatcher lock so the deletion fence is checked atomically.
    let mut validated: Option<PersistedHardwareConfiguration> = None;
    match persisted {
        Ok(Some(configuration)) => {
            let firmware_config = match &identity {
                Message::IdentityResponse { config_id, .. } => ConfigId::new(*config_id).ok(),
                _ => None,
            };
            let mappings_valid = configuration.mappings.iter()
                .all(|mapping| mapping.identity.device_id == configuration.device_id);
            if firmware_config == Some(configuration.config_id) && mappings_valid {
                validated = Some(configuration);
            } else {
                service.consumer.protocol_error(&port, generation, "persisted configuration does not match board identity");
            }
        }
        Ok(None) => {}
        Err(error) => service.consumer.protocol_error(&port, generation, &format!("configuration lookup failed: {error}")),
    }
    service.cache.activate(&port, generation);
    let mut dispatcher_state = state.lock().expect("hardware dispatcher state poisoned");
    if dispatcher_state.ports.get(&port).is_some_and(|current| current.generation == generation) {
        if let Some(configuration) = validated {
            // Checked atomically with dispatcher insertion: a device deleted before
            // this point never activates, and a deletion starting after this point
            // observes the connected device and refuses to commit.
            if service.device_deletion_fence
                .lock()
                .expect("device deletion fence poisoned")
                .is_blocked(configuration.device_id)
            {
                service.consumer.protocol_error(&port, generation, "device is being deleted or was deleted; persisted configuration not activated");
            } else {
                let device_id = configuration.device_id;
                let mappings = configuration.mappings.iter().map(|mapping| (mapping.pin, mapping.identity));
                if service.resolver.replace_port(&port, generation, configuration.config_id, mappings) {
                    current.config_id = Some(configuration.config_id);
                    current.device_id = Some(device_id);
                    current.kinds = configuration.mappings.into_iter().map(|mapping| (mapping.pin, mapping.kind)).collect();
                }
            }
        }
        if let Some(previous) = dispatcher_state.ports.get(&port) { current.pending_inputs = previous.pending_inputs.clone(); }
        dispatcher_state.ports.insert(port.clone(), current);
    }
    let pending = dispatcher_state.ports.get_mut(&port).map(|current| std::mem::take(&mut current.pending_inputs)).unwrap_or_default();
    drop(dispatcher_state);
    for (pin, value) in pending {
        dispatch_event(service, state, ack_inboxes,
            PortEvent::Message { port: port.clone(), generation, message: Message::InputValue { pin, value } },
            dispatcher, lookup_workers);
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
    let terminal = service
        .sessions
        .calibration(session_id)
        .is_some_and(|session| {
            matches!(session.lock().expect("calibration session poisoned").step(),
                super::sessions::CalibrationStep::SourceLost
                    | super::sessions::CalibrationStep::Overflowed
                    | super::sessions::CalibrationStep::Complete
                    | super::sessions::CalibrationStep::Cancelled)
        });
    if !terminal {
        return;
    }
    match service.arbiter.release(token) {
        Ok(()) => {
            let mut leases = service.coordinated_consumers.calibration_lease.lock()
                .expect("calibration lease registry poisoned");
            if leases.get(port).is_some_and(|(id, current)| *id == session_id && *current == token) {
                leases.remove(port);
            }
        }
        Err(error) => service.consumer.protocol_error(
            port, 0, &format!("terminal calibration lease release stayed suspended: {error:?}"),
        ),
    }
}

fn configuration_kinds(
    messages: &[Message],
    mappings: &[(u8, InputIdentity)],
) -> HashMap<u8, InputKind> {
    let mut kinds = HashMap::new();
    for message in messages {
        match message {
            Message::ConfigureAnalog { pin, .. } => { kinds.insert(*pin, InputKind::Analog); }
            Message::ConfigureButton { pin, .. } => { kinds.insert(*pin, InputKind::Button); }
            Message::ConfigureMatrix { row_pins, col_pins, .. } => {
                for pin in row_pins.iter().chain(col_pins) { kinds.insert(*pin, InputKind::Button); }
            }
            _ => {}
        }
    }
    for (pin, _) in mappings { kinds.entry(*pin).or_insert(InputKind::Any); }
    kinds
}

fn mark_source_lost<T, R, C>(
    service: &HardwareService<T, R, C>,
    state: &Arc<Mutex<DispatcherState>>,
    ack_inboxes: &AckInboxes,
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
        if let Some(ack) = ack_inboxes.lock().expect("ack inbox registry poisoned").get(port) { ack.close(); }
        service.resolver.invalidate_port(port, generation);
        service.cache.invalidate(port, generation);
        if let Err(error) = service.arbiter.neutralize_source(port, generation) {
            service.consumer.protocol_error(
                port,
                generation,
                &format!("source neutralization failed; resource remains suspended: {error:?}"),
            );
        }
    }
}
