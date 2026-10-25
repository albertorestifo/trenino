//! Train detection wiring for the runtime train service.
//!
//! Wraps [`TrainDetectionMonitor`] — the wave-1 port of
//! `Trenino.Train.Detection` (5s poll / 30s grace with 200ms fast probes) —
//! behind the train service's configuration source so the polling semantics
//! stay single-sourced while activation moves into
//! [`crate::train::service::TrainService`].
//!
//! The snapshot type carries the full routing-relevant configuration of one
//! train (elements, lever configs + notches, enabled bindings, sequences,
//! scripts, input calibrations) tagged with the committed DB revision it was
//! read at, mirroring the Elixir controllers' `load_bindings_for_train/2`
//! reads (`lever_controller.ex:282-298`, `button_controller.ex:284-306`).

use std::sync::Arc;

use trenino_core::hardware::calibration::Calibration;
use trenino_core::train::identifier::TrainProfile;
use trenino_core::{EntityId, Revision};

use crate::simulator::client::SimulatorClient;
use crate::simulator::services::clock::Clock;
use crate::simulator::services::train_detection::{
    MonitorError, ProfileSource, TrainDetectionEvent, TrainDetectionMonitor,
};
use crate::storage::bindings::{ButtonHardwareType, ButtonMode};
use crate::storage::scripts::ScriptRecord;
use crate::storage::sequences::SequenceCommandRecord;
use crate::storage::trains::TrainRecord;
use crate::storage::Database;

/// One ordered command of a button sequence, as loaded for a binding.
#[derive(Clone, Debug, PartialEq)]
pub struct SequenceCommand {
    pub endpoint: String,
    pub value: f64,
    pub delay_ms: u64,
}

/// Enabled button binding with its sequences resolved to commands, matching
/// the `binding_info` map of `Trenino.Train.ButtonController`
/// (button_controller.ex:53-80, 308-338).
#[derive(Clone, Debug, PartialEq)]
pub struct ButtonBindingInfo {
    pub binding_id: EntityId,
    pub element_id: EntityId,
    pub input_id: EntityId,
    /// Device owning the input, for routing identities.
    pub input_device: Option<EntityId>,
    pub endpoint: Option<String>,
    pub on_value: f64,
    pub off_value: f64,
    pub mode: ButtonMode,
    pub hardware_type: ButtonHardwareType,
    pub repeat_interval_ms: i64,
    pub keystroke: Option<String>,
    pub on_sequence: Option<Vec<SequenceCommand>>,
    pub off_sequence: Option<Vec<SequenceCommand>>,
}

/// Enabled lever binding with its mapped lever config and input calibration,
/// matching `Trenino.Train.LeverController`'s binding lookup
/// (lever_controller.ex:59-64, 282-298).
#[derive(Clone, Debug, PartialEq)]
pub struct LeverBindingInfo {
    pub binding_id: EntityId,
    pub input_id: EntityId,
    /// Device owning the input, for routing identities.
    pub input_device: Option<EntityId>,
    pub lever_config_id: EntityId,
    pub value_endpoint: String,
    pub inverted: bool,
    /// Notch mapping table in the core `LeverMapper` shape.
    pub notches: Vec<trenino_core::train::lever::Notch>,
    pub calibration: Option<Calibration>,
}

/// Full routing-relevant configuration of one train at one committed DB
/// revision. Frozen once per activation; controllers never re-read the DB.
#[derive(Clone, Debug, PartialEq)]
pub struct TrainConfigSnapshot {
    pub revision: Revision,
    pub train_id: EntityId,
    pub train_name: String,
    pub elements: Vec<TrainRecordElement>,
    pub lever_bindings: Vec<LeverBindingInfo>,
    pub button_bindings: Vec<ButtonBindingInfo>,
    pub scripts: Vec<ScriptRecord>,
}

/// Element kind (`train_elements.type`).
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ElementKind {
    Lever,
    Button,
}

/// One element of the snapshot, with its lever config + notches.
#[derive(Clone, Debug, PartialEq)]
pub struct TrainRecordElement {
    pub id: EntityId,
    pub kind: ElementKind,
    pub name: String,
    pub lever_config: Option<TrainLeverConfig>,
}

#[derive(Clone, Debug, PartialEq)]
pub struct TrainLeverConfig {
    pub id: EntityId,
    pub value_endpoint: String,
    pub inverted: bool,
    pub notches: Vec<trenino_core::train::lever::Notch>,
}

/// Errors surfaced by configuration reads.
#[derive(Clone, Debug, PartialEq)]
pub enum TrainConfigError {
    NotFound(EntityId),
    Storage(String),
}

impl std::fmt::Display for TrainConfigError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::NotFound(id) => write!(f, "train {id:?} not found"),
            Self::Storage(detail) => write!(f, "train configuration read failed: {detail}"),
        }
    }
}

/// Read-only access to the committed train configuration. The database-backed
/// implementation lives below; tests install an in-memory fake.
pub trait TrainConfigSource: Send + Sync + 'static {
    /// Every stored train profile with its identifiers (prefix matchers).
    fn profiles(&self) -> Vec<TrainProfile>;
    /// The full snapshot of one train at its current committed revision.
    fn snapshot(&self, train_id: EntityId) -> Result<TrainConfigSnapshot, TrainConfigError>;
}

/// Adapter turning a [`TrainConfigSource`] into the monitor's profile source.
struct SourceProfiles(Arc<dyn TrainConfigSource>);

impl ProfileSource for SourceProfiles {
    fn profiles(&self) -> Vec<TrainProfile> {
        self.0.profiles()
    }
}

/// Owned handle around the wave-1 train detection monitor: the 5s/30s/200ms
/// semantics stay implemented once, in `simulator::services::train_detection`.
pub struct TrainDetection {
    monitor: TrainDetectionMonitor,
}

impl TrainDetection {
    pub fn start(
        clock: Arc<dyn Clock>,
        source: Arc<dyn TrainConfigSource>,
    ) -> (Self, tokio::sync::mpsc::Receiver<TrainDetectionEvent>) {
        let (monitor, events) = TrainDetectionMonitor::start(clock, Arc::new(SourceProfiles(source)));
        (Self { monitor }, events)
    }

    pub async fn connected(&self, client: Arc<SimulatorClient>) -> Result<(), MonitorError> {
        self.monitor.connected(client).await
    }

    pub async fn disconnected(&self) -> Result<(), MonitorError> {
        self.monitor.disconnected().await
    }

    /// Manual re-detection with a cleared identifier (detection.ex:137-147):
    /// forces the full database lookup path. The train service calls this
    /// after CRUD so renamed identifiers and edited bindings take effect.
    pub async fn sync(&self) -> Result<(), MonitorError> {
        self.monitor.sync().await
    }

    pub async fn shutdown(self) -> Result<(), MonitorError> {
        self.monitor.shutdown().await
    }
}

/// Database-backed configuration source over the typed storage domain.
pub struct DbTrainConfigSource {
    db: Database,
}

impl DbTrainConfigSource {
    pub fn new(db: Database) -> Self {
        Self { db }
    }

    /// Combined committed revision of every topic the snapshot reads. Each
    /// mutation bumps exactly one topic by one, so the sum strictly increases
    /// across every edit — the monotonic revision contract the routing
    /// service requires of desired revisions.
    fn combined_revision(&self) -> Revision {
        let sum = ["trains", "bindings", "sequences", "scripts"]
            .iter()
            .filter_map(|topic| self.db.revision(topic).ok())
            .sum::<u64>();
        Revision(sum)
    }
}

impl TrainConfigSource for DbTrainConfigSource {
    fn profiles(&self) -> Vec<TrainProfile> {
        self.db
            .list_trains()
            .map(|trains| {
                trains
                    .into_iter()
                    .map(|train| TrainProfile {
                        id: train.id.0,
                        name: train.name,
                        identifiers: train.identifiers,
                    })
                    .collect()
            })
            .unwrap_or_default()
    }

    fn snapshot(&self, train_id: EntityId) -> Result<TrainConfigSnapshot, TrainConfigError> {
        let storage = |error: crate::storage::StorageError| TrainConfigError::Storage(error.to_string());
        let train: TrainRecord = self
            .db
            .get_train(train_id)
            .map_err(storage)?
            .ok_or(TrainConfigError::NotFound(train_id))?;

        let lever_bindings = self
            .db
            .list_lever_bindings_for_train(train_id)
            .map_err(storage)?
            .into_iter()
            .filter(|binding| binding.enabled)
            .map(|binding| {
                let config = train
                    .elements
                    .iter()
                    .find_map(|element| element.lever_config.as_ref().filter(|config| config.id == binding.lever_config_id))
                    .ok_or(TrainConfigError::NotFound(binding.lever_config_id))?;
                let input = self.db.get_input(binding.input_id).map_err(storage)?;
                let calibration = input
                    .as_ref()
                    .and_then(|input| input.calibration.clone())
                    .map(|row| Calibration {
                        min_value: row.value.min_value.unwrap_or(0),
                        max_value: row.value.max_value.unwrap_or(0),
                        max_hardware_value: row.value.max_hardware_value.unwrap_or(0),
                        inverted: row.value.is_inverted,
                        rollover: row.value.has_rollover,
                    });
                Ok(LeverBindingInfo {
                    binding_id: binding.id,
                    input_id: binding.input_id,
                    input_device: input.and_then(|input| input.device_id),
                    lever_config_id: binding.lever_config_id,
                    value_endpoint: config.value_endpoint.clone(),
                    inverted: config.inverted,
                    notches: core_notches(config),
                    calibration,
                })
            })
            .collect::<Result<Vec<_>, TrainConfigError>>()?;

        let button_bindings = self
            .db
            .list_button_bindings_for_train(train_id)
            .map_err(storage)?
            .into_iter()
            .filter(|binding| binding.enabled)
            .map(|binding| {
                let on_sequence = load_sequence(&self.db, binding.on_sequence_id)?;
                let off_sequence = load_sequence(&self.db, binding.off_sequence_id)?;
                let input_device = self
                    .db
                    .get_input(binding.input_id)
                    .map_err(storage)?
                    .and_then(|input| input.device_id);
                Ok(ButtonBindingInfo {
                    binding_id: binding.id,
                    element_id: binding.element_id,
                    input_id: binding.input_id,
                    input_device,
                    endpoint: binding.endpoint.clone(),
                    on_value: binding.on_value,
                    off_value: binding.off_value,
                    mode: binding.mode,
                    hardware_type: binding.hardware_type,
                    repeat_interval_ms: binding.repeat_interval_ms,
                    keystroke: binding.keystroke.clone(),
                    on_sequence,
                    off_sequence,
                })
            })
            .collect::<Result<Vec<_>, TrainConfigError>>()?;

        let scripts = self
            .db
            .list_scripts(train_id)
            .map_err(storage)?
            .into_iter()
            .filter(|script| script.enabled)
            .collect();

        Ok(TrainConfigSnapshot {
            revision: self.combined_revision(),
            train_id,
            train_name: train.name,
            elements: train
                .elements
                .into_iter()
                .map(|element| TrainRecordElement {
                    id: element.id,
                    kind: match element.kind {
                        crate::storage::trains::ElementKind::Lever => ElementKind::Lever,
                        crate::storage::trains::ElementKind::Button => ElementKind::Button,
                    },
                    name: element.name,
                    lever_config: element.lever_config.map(|config| {
                        let notches = core_notches(&config);
                        TrainLeverConfig {
                            id: config.id,
                            value_endpoint: config.value_endpoint,
                            inverted: config.inverted,
                            notches,
                        }
                    }),
                })
                .collect(),
            lever_bindings,
            button_bindings,
            scripts,
        })
    }
}

fn core_notches(config: &crate::storage::trains::LeverConfigRecord) -> Vec<trenino_core::train::lever::Notch> {
    config
        .notches
        .iter()
        .map(|notch| trenino_core::train::lever::Notch {
            kind: match notch.kind {
                crate::storage::trains::NotchKind::Gate => trenino_core::train::lever::NotchType::Gate,
                crate::storage::trains::NotchKind::Linear => trenino_core::train::lever::NotchType::Linear,
            },
            input_min: notch.input_min,
            input_max: notch.input_max,
            sim_input_min: notch.sim_input_min,
            sim_input_max: notch.sim_input_max,
        })
        .collect()
}

fn load_sequence(
    db: &Database,
    id: Option<EntityId>,
) -> Result<Option<Vec<SequenceCommand>>, TrainConfigError> {
    let Some(id) = id else {
        return Ok(None);
    };
    let commands: Vec<SequenceCommandRecord> = db.sequence_commands(id).map_err(|error| {
        TrainConfigError::Storage(error.to_string())
    })?;
    Ok(Some(
        commands
            .into_iter()
            .map(|command| SequenceCommand {
                endpoint: command.endpoint,
                value: command.value,
                delay_ms: command.delay_ms.max(0) as u64,
            })
            .collect(),
    ))
}
