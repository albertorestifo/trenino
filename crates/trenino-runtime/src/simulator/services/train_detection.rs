//! Train detection monitor.
//!
//! Port of `Trenino.Train.Detection` (lib/trenino/train/detection.ex): polls
//! formation data every 5s while connected, derives the train identifier from
//! the drivable vehicle's ObjectClass (index 0 fallback), matches stored
//! profiles with the shared prefix/dedup/ambiguity rules, and on simulator
//! disconnect keeps the active profile alive through an exact 30s grace period
//! probed every 200ms with the fast client. Successful probes extend grace and
//! never change the detected profile; expiry deactivates the train.

use crate::simulator::client::{SimulatorClient, SimulatorError};
use std::sync::Arc;
use std::time::{Duration, Instant};
use tokio::sync::{mpsc, oneshot, Mutex};
use trenino_core::train::identifier::{
    match_identifier, normalize_object_class, IdentifierMatch, TrainProfile,
};

use super::clock::Clock;

pub const POLL_INTERVAL: Duration = Duration::from_secs(5);
pub const GRACE_PERIOD: Duration = Duration::from_secs(30);
pub const GRACE_POLL_INTERVAL: Duration = Duration::from_millis(200);

/// Source of stored train profiles (fake in tests; wave 2 wires the trains
/// repository). Matching itself uses `trenino_core::train::identifier`.
pub trait ProfileSource: Send + Sync + 'static {
    fn profiles(&self) -> Vec<TrainProfile>;
}

#[derive(Clone, Debug, PartialEq)]
pub enum TrainDetectionEvent {
    TrainDetected {
        identifier: String,
        train: Option<TrainProfile>,
    },
    TrainChanged(Option<TrainProfile>),
    MultipleTrainsMatch {
        identifier: String,
        trains: Vec<TrainProfile>,
    },
    DetectionError(SimulatorError),
}

pub enum TrainDetectionCommand {
    Connected(Arc<SimulatorClient>),
    Disconnected,
    Sync,
    Shutdown(oneshot::Sender<()>),
}

struct DetectionState {
    active_train: Option<TrainProfile>,
    current_identifier: Option<String>,
    detection_error: Option<Vec<i64>>,
    last_successful_contact: Option<Instant>,
    connected_client: Option<Arc<SimulatorClient>>,
    last_client: Option<Arc<SimulatorClient>>,
    polling_enabled: bool,
    grace_client: Option<Arc<SimulatorClient>>,
}

impl DetectionState {
    fn in_grace(&self) -> bool {
        self.grace_client.is_some()
    }
    fn connected(&mut self, client: Arc<SimulatorClient>) {
        // A reconnect exits grace, re-enables polling and triggers detection.
        self.grace_client = None;
        self.polling_enabled = true;
        self.connected_client = Some(client.clone());
        self.last_client = Some(client);
    }
    fn deactivate(&mut self) -> TrainDetectionEvent {
        self.active_train = None;
        self.current_identifier = None;
        self.detection_error = None;
        self.last_successful_contact = None;
        TrainDetectionEvent::TrainChanged(None)
    }
}

#[derive(Debug)]
pub enum MonitorError {
    Closed,
}

pub struct TrainDetectionMonitor {
    commands: mpsc::Sender<TrainDetectionCommand>,
    worker: Arc<Mutex<Option<tokio::task::JoinHandle<()>>>>,
}

impl TrainDetectionMonitor {
    pub fn start(
        clock: Arc<dyn Clock>,
        profiles: Arc<dyn ProfileSource>,
    ) -> (Self, mpsc::Receiver<TrainDetectionEvent>) {
        let (commands, command_receiver) = mpsc::channel(64);
        let (events, event_receiver) = mpsc::channel(64);
        let worker = tokio::spawn(run(clock, profiles, command_receiver, events));
        (
            Self {
                commands,
                worker: Arc::new(Mutex::new(Some(worker))),
            },
            event_receiver,
        )
    }

    pub async fn connected(&self, client: Arc<SimulatorClient>) -> Result<(), MonitorError> {
        self.send(TrainDetectionCommand::Connected(client)).await
    }

    pub async fn disconnected(&self) -> Result<(), MonitorError> {
        self.send(TrainDetectionCommand::Disconnected).await
    }

    pub async fn sync(&self) -> Result<(), MonitorError> {
        self.send(TrainDetectionCommand::Sync).await
    }

    pub async fn shutdown(self) -> Result<(), MonitorError> {
        let (reply, reply_receiver) = oneshot::channel();
        self.commands
            .send(TrainDetectionCommand::Shutdown(reply))
            .await
            .map_err(|_| MonitorError::Closed)?;
        reply_receiver.await.map_err(|_| MonitorError::Closed)?;
        let mut slot = self.worker.lock().await;
        if let Some(handle) = slot.as_mut() {
            handle.await.map_err(|_| MonitorError::Closed)?;
            *slot = None;
        }
        Ok(())
    }

    async fn send(&self, command: TrainDetectionCommand) -> Result<(), MonitorError> {
        self.commands
            .send(command)
            .await
            .map_err(|_| MonitorError::Closed)
    }
}

/// Dropping the monitor closes the command channel, which stops the worker.
impl Drop for TrainDetectionMonitor {
    fn drop(&mut self) {}
}

async fn run(
    clock: Arc<dyn Clock>,
    profiles: Arc<dyn ProfileSource>,
    mut commands: mpsc::Receiver<TrainDetectionCommand>,
    events: mpsc::Sender<TrainDetectionEvent>,
) {
    let mut state = DetectionState {
        active_train: None,
        current_identifier: None,
        detection_error: None,
        last_successful_contact: None,
        connected_client: None,
        last_client: None,
        polling_enabled: false,
        grace_client: None,
    };
    let mut poll_timer = Box::pin(clock.sleep(POLL_INTERVAL));
    let mut grace_timer = Box::pin(clock.sleep(GRACE_POLL_INTERVAL));
    loop {
        tokio::select! {
            biased;
            command = commands.recv() => {
                let Some(command) = command else { break };
                match command {
                    TrainDetectionCommand::Connected(client) => {
                        state.connected(client);
                        poll_timer = Box::pin(clock.sleep(POLL_INTERVAL));
                        poll(&mut state, &profiles, &events, &clock).await;
                    }
                    TrainDetectionCommand::Disconnected => {
                        state.polling_enabled = false;
                        if !state.in_grace() {
                            if state.active_train.is_some()
                                && enter_grace_period(&mut state, &clock)
                            {
                                grace_timer = Box::pin(clock.sleep(GRACE_POLL_INTERVAL));
                            } else if state.active_train.is_some() {
                                let event = state.deactivate();
                                publish(&events, event);
                            } else {
                                // No active train: deactivate immediately, no grace.
                                let event = state.deactivate();
                                publish(&events, event);
                            }
                        }
                    }
                    TrainDetectionCommand::Sync => {
                        // Force a full re-detection with database lookup in
                        // both branches, mirroring detection.ex:137-147
                        // (`%{state | current_identifier: nil}` unconditionally).
                        state.current_identifier = None;
                        let client = if let Some(grace_client) = state.grace_client.clone() {
                            Some(grace_client)
                        } else {
                            state.connected_client.clone()
                        };
                        if let Some(client) = client {
                            detect(&mut state, &client, &profiles, &events, &clock).await;
                        }
                    }
                    TrainDetectionCommand::Shutdown(reply) => {
                        let _ = reply.send(());
                        break;
                    }
                }
            }
            _ = &mut poll_timer, if state.polling_enabled => {
                poll(&mut state, &profiles, &events, &clock).await;
                poll_timer = Box::pin(clock.sleep(POLL_INTERVAL));
            }
            _ = &mut grace_timer, if state.in_grace() => {
                grace_poll(&mut state, &events, &clock).await;
                if state.in_grace() {
                    grace_timer = Box::pin(clock.sleep(GRACE_POLL_INTERVAL));
                }
            }
        }
    }
}

fn publish(events: &mpsc::Sender<TrainDetectionEvent>, event: TrainDetectionEvent) {
    // PubSub-style: a full mailbox drops instead of stalling detection.
    let _ = events.try_send(event);
}

async fn poll(
    state: &mut DetectionState,
    profiles: &Arc<dyn ProfileSource>,
    events: &mpsc::Sender<TrainDetectionEvent>,
    clock: &Arc<dyn Clock>,
) {
    let Some(client) = state.connected_client.clone() else {
        return;
    };
    detect(state, &client, profiles, events, clock).await;
}

async fn detect(
    state: &mut DetectionState,
    client: &Arc<SimulatorClient>,
    profiles: &Arc<dyn ProfileSource>,
    events: &mpsc::Sender<TrainDetectionEvent>,
    clock: &Arc<dyn Clock>,
) {
    match derive_identifier(client).await {
        Ok(identifier) => {
            state.last_successful_contact = Some(clock.now());
            handle_identifier_detected(state, identifier, profiles, events);
        }
        Err(reason) => {
            publish(events, TrainDetectionEvent::DetectionError(reason));
        }
    }
}

fn handle_identifier_detected(
    state: &mut DetectionState,
    identifier: String,
    profiles: &Arc<dyn ProfileSource>,
    events: &mpsc::Sender<TrainDetectionEvent>,
) {
    if state.current_identifier.as_deref() == Some(identifier.as_str()) {
        // Same train: no events, just refresh the check time.
        return;
    }
    let stored = profiles.profiles();
    match match_identifier(&stored, &identifier) {
        IdentifierMatch::Unique(id) => {
            let train = stored.iter().find(|profile| profile.id == id).cloned();
            publish(
                events,
                TrainDetectionEvent::TrainDetected {
                    identifier: identifier.clone(),
                    train: train.clone(),
                },
            );
            if state.active_train.as_ref().map(|active| active.id) != train.as_ref().map(|t| t.id) {
                publish(events, TrainDetectionEvent::TrainChanged(train.clone()));
            }
            state.current_identifier = Some(identifier);
            state.active_train = train;
            state.detection_error = None;
        }
        IdentifierMatch::NotFound => {
            publish(
                events,
                TrainDetectionEvent::TrainDetected {
                    identifier: identifier.clone(),
                    train: None,
                },
            );
            if state.active_train.is_some() {
                publish(events, TrainDetectionEvent::TrainChanged(None));
            }
            state.current_identifier = Some(identifier);
            state.active_train = None;
            state.detection_error = None;
        }
        IdentifierMatch::Ambiguous(ids) => {
            let trains: Vec<TrainProfile> = stored
                .iter()
                .filter(|profile| ids.contains(&profile.id))
                .cloned()
                .collect();
            publish(
                events,
                TrainDetectionEvent::TrainDetected {
                    identifier: identifier.clone(),
                    train: None,
                },
            );
            publish(
                events,
                TrainDetectionEvent::MultipleTrainsMatch {
                    identifier: identifier.clone(),
                    trains: trains.clone(),
                },
            );
            if state.active_train.is_some() {
                publish(events, TrainDetectionEvent::TrainChanged(None));
            }
            state.current_identifier = Some(identifier);
            state.active_train = None;
            state.detection_error = Some(ids);
        }
    }
}

async fn grace_poll(
    state: &mut DetectionState,
    events: &mpsc::Sender<TrainDetectionEvent>,
    clock: &Arc<dyn Clock>,
) {
    let Some(grace_client) = state.grace_client.clone() else {
        // Grace period was exited; ignore the late timer, keep polling enabled.
        return;
    };
    match derive_identifier(&grace_client).await {
        Ok(_identifier) => {
            // Successful probes extend grace and preserve the current profile;
            // the derived identifier is deliberately discarded.
            state.last_successful_contact = Some(clock.now());
        }
        Err(_) => {
            let elapsed = state
                .last_successful_contact
                .map(|contact| clock.elapsed_since(contact))
                .unwrap_or(GRACE_PERIOD);
            if elapsed >= GRACE_PERIOD {
                state.grace_client = None;
                let event = state.deactivate();
                publish(events, event);
            }
        }
    }
}

fn enter_grace_period(state: &mut DetectionState, clock: &Arc<dyn Clock>) -> bool {
    // No client ever seen: the caller deactivates immediately instead.
    let Some(last_client) = state.last_client.clone() else {
        return false;
    };
    let Ok(fast) = last_client.with_fast_timeouts() else {
        return false;
    };
    state.grace_client = Some(Arc::new(fast));
    if state.last_successful_contact.is_none() {
        state.last_successful_contact = Some(clock.now());
    }
    true
}

/// Derives the train identifier from the current formation, mirroring
/// `Trenino.Train.Identifier.derive_from_formation/1`: the drivable index is
/// read first and index 0 is the fallback on any failure.
pub async fn derive_identifier(client: &SimulatorClient) -> Result<String, SimulatorError> {
    let object_class = match client.get_int("CurrentFormation.DrivableIndex").await {
        Ok(index) => {
            match client
                .get_string(&format!("CurrentFormation/{index}.ObjectClass"))
                .await
            {
                Ok(object_class) => object_class,
                Err(_) => client.get_string("CurrentFormation/0.ObjectClass").await?,
            }
        }
        Err(_) => client.get_string("CurrentFormation/0.ObjectClass").await?,
    };
    Ok(normalize_object_class(&object_class))
}
