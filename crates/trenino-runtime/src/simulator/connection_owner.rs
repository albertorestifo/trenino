//! Owned simulator connection and health/retry loop.
//!
//! Preserves the legacy 1s initial delay, 30s normal/retry interval, 2s
//! transient probe and three-failure tolerance. Unlike the legacy GenServer,
//! explicit disconnect/reconfigure cancels old attempts and timers: a stale
//! result must never reactivate train controllers. All spawned probes are
//! cancelled and joined before shutdown acknowledgement. `latest()` is the
//! reliable current-state feed; broadcasts and the compatibility signal feed
//! are telemetry and may be coalesced for slow consumers.
use super::{
    client::{SimulatorClient, SimulatorError},
    connection::{ConnectionError, ConnectionState, HealthDecision, SimulatorStatus},
    services::clock::Clock,
};
use serde_json::Value;
use std::{
    sync::Arc,
    time::{Duration, Instant},
};
use tokio::sync::{broadcast, mpsc, oneshot, watch, Mutex};

pub const RETRY_INTERVAL: Duration = Duration::from_secs(30);
pub const INITIAL_DELAY: Duration = Duration::from_secs(1);
pub const RECONFIGURE_DELAY: Duration = Duration::from_millis(500);

pub trait ConnectionConfig: Send + Sync + 'static {
    fn simulator_url(&self) -> String;
    fn api_key(&self) -> Option<String>;
}
impl ConnectionConfig for crate::settings::Settings {
    fn simulator_url(&self) -> String {
        self.simulator_url()
            .unwrap_or_else(|_| "http://localhost:31270".into())
    }
    fn api_key(&self) -> Option<String> {
        self.api_key().ok().flatten()
    }
}
#[derive(Clone, Debug)]
pub struct StatusSnapshot {
    pub status: SimulatorStatus,
    pub last_error: Option<ConnectionError>,
    pub info: Option<Value>,
    pub health_failures: u8,
    pub client: Option<Arc<SimulatorClient>>,
}
impl StatusSnapshot {
    fn of(state: &ConnectionState, client: &Option<Arc<SimulatorClient>>) -> Self {
        Self {
            status: state.status,
            last_error: state.last_error.clone(),
            info: state.info.clone(),
            health_failures: state.health_failures,
            client: client.clone(),
        }
    }
}
#[derive(Clone, Debug)]
pub struct StatusChanged(pub StatusSnapshot);
#[derive(Clone, Debug)]
pub enum ConnectionSignal {
    Connected(Arc<SimulatorClient>),
    Disconnected,
}
#[derive(Debug, PartialEq, Eq)]
pub enum OwnerError {
    Closed,
}
enum Command {
    GetStatus(oneshot::Sender<StatusSnapshot>),
    Connect,
    Reconfigure(oneshot::Sender<()>),
    Disconnect(oneshot::Sender<()>),
    Shutdown(oneshot::Sender<()>),
}
#[derive(Clone)]
pub struct SimulatorConnectionOwner {
    commands: mpsc::Sender<Command>,
    events: broadcast::Sender<StatusChanged>,
    latest: watch::Receiver<StatusSnapshot>,
    worker: Arc<Mutex<Option<tokio::task::JoinHandle<()>>>>,
}
impl SimulatorConnectionOwner {
    pub fn start(
        clock: Arc<dyn Clock>,
        config: Arc<dyn ConnectionConfig>,
        signals: mpsc::Sender<ConnectionSignal>,
    ) -> Self {
        let (commands, receiver) = mpsc::channel(64);
        let (events, _) = broadcast::channel(128);
        let (latest_tx, latest) =
            watch::channel(StatusSnapshot::of(&ConnectionState::default(), &None));
        // Capture the deadline before spawning so fake-clock and startup
        // scheduling cannot shift the initial connection delay.
        let deadline = clock.now() + INITIAL_DELAY;
        let worker = tokio::spawn(run(
            clock,
            config,
            signals,
            events.clone(),
            latest_tx,
            receiver,
            deadline,
        ));
        Self {
            commands,
            events,
            latest,
            worker: Arc::new(Mutex::new(Some(worker))),
        }
    }
    pub fn subscribe(&self) -> broadcast::Receiver<StatusChanged> {
        self.events.subscribe()
    }
    pub fn latest(&self) -> watch::Receiver<StatusSnapshot> {
        self.latest.clone()
    }
    pub async fn status(&self) -> Result<StatusSnapshot, OwnerError> {
        let (reply, receiver) = oneshot::channel();
        self.commands
            .send(Command::GetStatus(reply))
            .await
            .map_err(|_| OwnerError::Closed)?;
        receiver.await.map_err(|_| OwnerError::Closed)
    }
    pub async fn retry_connection(&self) -> Result<(), OwnerError> {
        self.commands
            .send(Command::Connect)
            .await
            .map_err(|_| OwnerError::Closed)
    }
    pub async fn reconfigure(&self) -> Result<(), OwnerError> {
        let (reply, done) = oneshot::channel();
        self.commands
            .send(Command::Reconfigure(reply))
            .await
            .map_err(|_| OwnerError::Closed)?;
        done.await.map_err(|_| OwnerError::Closed)
    }
    pub async fn disconnect(&self) -> Result<(), OwnerError> {
        let (reply, done) = oneshot::channel();
        self.commands
            .send(Command::Disconnect(reply))
            .await
            .map_err(|_| OwnerError::Closed)?;
        done.await.map_err(|_| OwnerError::Closed)
    }
    pub async fn shutdown(&self) -> Result<(), OwnerError> {
        let mut slot = self.worker.lock().await;
        let Some(worker) = slot.as_mut() else {
            return Ok(());
        };
        if !worker.is_finished() {
            let (reply, done) = oneshot::channel();
            if self.commands.send(Command::Shutdown(reply)).await.is_ok() {
                let _ = done.await;
            }
        }
        worker.await.map_err(|_| OwnerError::Closed)?;
        slot.take();
        Ok(())
    }
}
#[derive(Clone, Copy)]
enum Timer {
    Connect,
    Health,
}
type Attempt = Option<tokio::task::JoinHandle<Result<Value, SimulatorError>>>;
async fn cancel(attempt: &mut Attempt) {
    if let Some(task) = attempt.take() {
        task.abort();
        let _ = task.await;
    }
}
async fn run(
    clock: Arc<dyn Clock>,
    config: Arc<dyn ConnectionConfig>,
    signals: mpsc::Sender<ConnectionSignal>,
    events: broadcast::Sender<StatusChanged>,
    latest: watch::Sender<StatusSnapshot>,
    mut commands: mpsc::Receiver<Command>,
    initial: Instant,
) {
    let mut state = ConnectionState::default();
    let mut client = None;
    let mut attempt: Attempt = None;
    let mut health_probe = false;
    let mut timer = Some((initial, Timer::Connect));
    loop {
        let sleep =
            timer.map(|(deadline, _)| clock.sleep(deadline.saturating_duration_since(clock.now())));
        tokio::select! {
            biased;
            command = commands.recv() => match command {
                None => break,
                Some(Command::GetStatus(reply)) => { let _ = reply.send(StatusSnapshot::of(&state, &client)); }
                Some(Command::Shutdown(reply)) => { cancel(&mut attempt).await; let _ = reply.send(()); break; }
                Some(command @ Command::Disconnect(_)) | Some(command @ Command::Reconfigure(_)) => {
                    let reconfigure = matches!(command, Command::Reconfigure(_));
                    let (Command::Disconnect(reply) | Command::Reconfigure(reply)) = command else { unreachable!() };
                    cancel(&mut attempt).await;
                    timer = reconfigure.then(|| (clock.now() + RECONFIGURE_DELAY, Timer::Connect));
                    state.disconnected(); client = None;
                    // Legacy reconfigure is silent on the event topic, but
                    // live consumers must stop using its old client now.
                    latest.send_replace(StatusSnapshot::of(&state, &client));
                    if !reconfigure { publish(&events, &signals, &latest, &state, &client); }
                    let _ = reply.send(());
                }
                Some(Command::Connect) => {
                    cancel(&mut attempt).await;
                    timer = None;
                    health_probe = false;
                    connect(&config, &mut state, &mut client, &mut attempt);
                    if state.status == SimulatorStatus::Error { timer = Some((clock.now()+RETRY_INTERVAL, Timer::Connect)); }
                    publish(&events, &signals, &latest, &state, &client);
                }
            },
            result = async { match attempt.as_mut() { Some(task) => task.await, None => std::future::pending().await } } => {
                attempt = None;
                if health_probe {
                    let result = result.unwrap_or(Err(SimulatorError::Transport("health worker stopped".into()))).map_err(classify);
                    match result {
                        Ok(info) => { state.connected(info); timer = Some((clock.now()+super::connection::HEALTH_INTERVAL, Timer::Health)); }
                        Err(error) => match state.after_health_check(Err(error)) {
                            HealthDecision::CheckAfter(delay) => timer = Some((clock.now()+delay, Timer::Health)),
                            HealthDecision::RetryAfter(delay) => { timer = Some((clock.now()+delay, Timer::Connect)); publish(&events, &signals, &latest, &state, &client); }
                        }
                    }
                    latest.send_replace(StatusSnapshot::of(&state, &client));
                } else {
                    match result {
                        Ok(Ok(info)) => { state.connected(info); timer = Some((clock.now()+super::connection::HEALTH_INTERVAL, Timer::Health)); }
                        Ok(Err(error)) => { state.failed_to_connect(classify(error)); timer = Some((clock.now()+RETRY_INTERVAL, Timer::Connect)); }
                        Err(_) => { state.failed_to_connect(ConnectionError::ConnectionFailed); timer = Some((clock.now()+RETRY_INTERVAL, Timer::Connect)); }
                    }
                    publish(&events, &signals, &latest, &state, &client);
                }
            },
            _ = async { match sleep { Some(sleep) => sleep.await, None => std::future::pending().await } } => {
                let (_, kind) = timer.take().expect("timer was armed");
                match kind {
                    Timer::Connect => {
                        cancel(&mut attempt).await;
                        health_probe = false;
                    connect(&config, &mut state, &mut client, &mut attempt);
                        if state.status == SimulatorStatus::Error { timer = Some((clock.now()+RETRY_INTERVAL, Timer::Connect)); }
                        publish(&events, &signals, &latest, &state, &client);
                    }
                    Timer::Health => {
                        if let Some(current) = client.as_ref().filter(|_| state.status == SimulatorStatus::Connected) {
                            let probe = current.with_fast_timeouts();
                            health_probe = true;
                            attempt = Some(tokio::spawn(async move {
                                match probe { Ok(fast) => fast.info().await, Err(error) => Err(error) }
                            }));
                        }
                    }
                }
            }
        }
    }
    cancel(&mut attempt).await;
}
fn connect(
    config: &Arc<dyn ConnectionConfig>,
    state: &mut ConnectionState,
    client: &mut Option<Arc<SimulatorClient>>,
    attempt: &mut Attempt,
) {
    let Some(key) = config.api_key() else {
        state.needs_config();
        *client = None;
        return;
    };
    match SimulatorClient::new(&config.simulator_url(), &key) {
        Ok(fresh) => {
            let fresh = Arc::new(fresh);
            state.status = SimulatorStatus::Connecting;
            state.last_error = None;
            *client = Some(fresh.clone());
            *attempt = Some(tokio::spawn(async move { fresh.info().await }));
        }
        Err(error) => {
            state.failed_to_connect(classify(error));
            *client = None;
        }
    }
}
fn publish(
    events: &broadcast::Sender<StatusChanged>,
    signals: &mpsc::Sender<ConnectionSignal>,
    latest: &watch::Sender<StatusSnapshot>,
    state: &ConnectionState,
    client: &Option<Arc<SimulatorClient>>,
) {
    let snapshot = StatusSnapshot::of(state, client);
    latest.send_replace(snapshot.clone());
    let _ = events.send(StatusChanged(snapshot.clone()));
    let signal = match (snapshot.status, snapshot.client) {
        (SimulatorStatus::Connected, Some(client)) => ConnectionSignal::Connected(client),
        _ => ConnectionSignal::Disconnected,
    };
    let _ = signals.try_send(signal);
}
fn classify(error: SimulatorError) -> ConnectionError {
    match error {
        SimulatorError::InvalidKey => ConnectionError::InvalidKey,
        _ => ConnectionError::ConnectionFailed,
    }
}
