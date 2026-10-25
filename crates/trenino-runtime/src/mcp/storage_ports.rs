//! Storage-backed implementations of every MCP domain port.
//!
//! Each port trait in [`crate::mcp::ports`] is implemented over an
//! `Arc<Database>` (the typed domain repositories from wave 1), reproducing the
//! semantics of the Elixir `Trenino.MCP.Tools.*` modules' context calls:
//! ordering (`order_by` clauses), changeset validation phrasing and the
//! `destination_conflict` exclusivity rule.
//!
//! Backing map (tool family → port → backing):
//! - trains/elements → [`StorageTrains`] — DB only
//! - devices/inputs/outputs/i2c modules → [`StorageHardware`] — DB only
//! - sequences → [`StorageSequences`] — DB only
//! - scripts → [`StorageScripts`] — DB only
//! - output/button/display bindings → [`StorageBindings`] — DB only
//!   (the Elixir `*Controller.reload_bindings/0` calls remain live-state and
//!   are a controllers-wave gap; nothing observable changes in the DB layer)
//! - vjoy mappings CRUD → [`StorageVjoy`] — DB only; status/lifecycle go
//!   through the injectable [`VjoyRuntime`] (default: manager-absent
//!   non-Windows behavior — `unsupported`)
//! - simulator → injectable [`SimulatorPort`] delegate, default
//!   [`DisconnectedSimulator`] (`is_connected == false`, so the tool layer
//!   returns the Elixir "Simulator not connected…" error verbatim)
//! - detection → injectable [`DetectionPort`] delegate, default
//!   [`NoDetection`] which reports a timeout immediately (the interactive
//!   `InputDetectionSession` needs the hardware runtime from the controllers
//!   wave; the response payload shape is identical, only the wait is skipped)
//!
//! The Rust `VjoyManager` does not yet port `remove_leftover`/`repair`; a
//! manager-backed [`VjoyRuntime`] reports those two commands as
//! `runtime_unavailable`.

use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::Arc;

use serde_json::Value;

use trenino_core::{EntityId, OperationId};

use crate::mcp::ports::{
    BindingOperator, ButtonBindingAttrs, ButtonBindingRecord, ButtonMode, DetectionOutcome,
    DetectionPort, DetectionRequest, DeviceSummary, DisplayBindingAttrs, DisplayBindingRecord,
    ElementRecord, ElementType, HardwareOutputRecord, HardwarePort, HardwareType, I2cModuleAttrs,
    I2cModuleChanges, I2cModuleParams, I2cModuleRecord, InputRecord, InputType, OutputBindingAttrs,
    OutputBindingRecord, PortError, Ports, ScriptAttrs, ScriptRecord, ScriptsPort,
    SequenceCommandDraft, SequenceCommandRecord, SequenceRecord, SequencesPort, SimulatorPort,
    TrainDetail, TrainSummary, TrainsPort, VjoyCommand, VjoyMappingDraft, VjoyMappingRecord,
    VjoyPort, VjoyPutError, VjoyReason, VjoyStatus, VjoyStatusDetails, VjoyTarget,
};
use crate::storage::Database;
use crate::storage::StorageError;
use crate::vjoy::VjoyManager;

/// Qualified namespace for the storage record/draft types used below.
mod st {
    pub use crate::storage::bindings::*;
    pub use crate::storage::scripts::*;
    pub use crate::storage::sequences::*;
    pub use crate::storage::trains::*;
    pub use crate::storage::*;
    pub use crate::vjoy::{MappingDraft, MappingRecord, Target, VjoyAxis};
}

/// Fresh operation id per mutation (single-purpose adapters; ids only need to
/// be unique within one database worker lifetime).
fn next_operation(counter: &AtomicU64) -> OperationId {
    OperationId(u128::from(counter.fetch_add(1, Ordering::Relaxed) + 1))
}

/// Maps a storage failure to the port error the tool layer phrases. Constraint
/// details are written `"<field> <ecto message>"` by the repositories, so they
/// translate into single-entry changeset validations.
fn port_error(error: StorageError) -> PortError {
    match error {
        StorageError::NotFound => PortError::NotFound,
        // A UNIQUE violation on a table is an Ecto changeset error
        // ("has already been taken"), never a destination conflict; only the
        // destination-exclusivity rule produces plain `Conflict` details.
        StorageError::Conflict { detail } if detail.contains("UNIQUE constraint failed") => {
            let field = detail.rsplit('.').next().unwrap_or("id").to_string();
            PortError::Validation(vec![(field, vec!["has already been taken".to_string()])])
        }
        StorageError::Conflict { .. } => PortError::DestinationConflict,
        StorageError::Constraint { detail } | StorageError::InvalidHardware { detail } => {
            match detail.split_once(' ') {
                Some((field, message))
                    if !field.is_empty()
                        && field
                            .chars()
                            .all(|c| c.is_ascii_lowercase() || c.is_ascii_digit() || c == '_') =>
                {
                    PortError::Validation(vec![(field.to_string(), vec![message.to_string()])])
                }
                _ => PortError::Failed(detail),
            }
        }
        other => PortError::Failed(other.to_string()),
    }
}

/// `value_a`/`endpoint`-style blank-required changeset error.
fn cant_be_blank(field: &str) -> PortError {
    PortError::Validation(vec![(
        field.to_string(),
        vec!["can't be blank".to_string()],
    )])
}

// ---------------------------------------------------------------------------
// Trains + elements
// ---------------------------------------------------------------------------

/// Trains/elements port over the `trains` domain repository.
pub struct StorageTrains {
    db: Arc<Database>,
    operations: AtomicU64,
}

impl StorageTrains {
    fn op(&self) -> OperationId {
        next_operation(&self.operations)
    }

    fn sequence_view(&self, record: st::SequenceRecord) -> Result<SequenceRecord, PortError> {
        let commands = self
            .db
            .sequence_commands(record.id)
            .map_err(port_error)?
            .into_iter()
            .map(|command| SequenceCommandRecord {
                id: command.id.0,
                position: command.position,
                endpoint: command.endpoint,
                value: command.value,
                delay_ms: command.delay_ms,
            })
            .collect();
        Ok(SequenceRecord {
            id: record.id.0,
            train_id: record.train_id.0,
            name: record.name,
            commands,
        })
    }
}

impl TrainsPort for StorageTrains {
    fn list_trains(&self) -> Result<Vec<TrainSummary>, PortError> {
        Ok(self
            .db
            .list_trains()
            .map_err(port_error)?
            .into_iter()
            .map(|train| {
                let mut identifiers = train.identifiers;
                identifiers.sort();
                TrainSummary {
                    id: train.id.0,
                    name: train.name,
                    identifiers,
                    description: train.description,
                }
            })
            .collect())
    }

    fn get_train(&self, id: i64) -> Result<TrainDetail, PortError> {
        let record = self
            .db
            .get_train(EntityId(id))
            .map_err(port_error)?
            .ok_or(PortError::NotFound)?;
        let elements = record
            .elements
            .iter()
            .map(|element| ElementRecord {
                id: element.id.0,
                name: element.name.clone(),
                element_type: match element.kind {
                    st::ElementKind::Lever => ElementType::Lever,
                    st::ElementKind::Button => ElementType::Button,
                },
            })
            .collect();
        let output_bindings = self
            .db
            .list_output_bindings(record.id)
            .map_err(port_error)?
            .into_iter()
            .map(output_binding_view)
            .collect();
        let button_bindings = self
            .db
            .list_button_bindings_for_train(record.id)
            .map_err(port_error)?
            .into_iter()
            .map(button_binding_view)
            .collect();
        let sequences = self
            .db
            .list_sequences(record.id)
            .map_err(port_error)?
            .into_iter()
            .map(|sequence| self.sequence_view(sequence))
            .collect::<Result<Vec<_>, _>>()?;
        let mut identifiers = record.identifiers;
        identifiers.sort();
        Ok(TrainDetail {
            train: TrainSummary {
                id: record.id.0,
                name: record.name,
                identifiers,
                description: record.description,
            },
            elements,
            output_bindings,
            button_bindings,
            sequences,
        })
    }

    fn list_elements(&self, train_id: i64) -> Result<Vec<ElementRecord>, PortError> {
        Ok(self
            .db
            .list_train_elements(EntityId(train_id))
            .map_err(port_error)?
            .into_iter()
            .map(|element| ElementRecord {
                id: element.id.0,
                name: element.name,
                element_type: match element.kind {
                    st::ElementKind::Lever => ElementType::Lever,
                    st::ElementKind::Button => ElementType::Button,
                },
            })
            .collect())
    }

    fn create_element(
        &self,
        train_id: i64,
        name: Option<String>,
        element_type: ElementType,
    ) -> Result<ElementRecord, PortError> {
        let record = self
            .db
            .create_train_element(
                self.op(),
                EntityId(train_id),
                st::ElementDraft {
                    kind: match element_type {
                        ElementType::Lever => st::ElementKind::Lever,
                        ElementType::Button => st::ElementKind::Button,
                    },
                    name: name.unwrap_or_default(),
                },
            )
            .map_err(port_error)?
            .record;
        Ok(ElementRecord {
            id: record.id.0,
            name: record.name,
            element_type,
        })
    }

    fn get_element(&self, id: i64) -> Result<ElementRecord, PortError> {
        let record = self
            .db
            .get_train_element(EntityId(id))
            .map_err(port_error)?
            .ok_or(PortError::NotFound)?;
        Ok(ElementRecord {
            id: record.id.0,
            name: record.name,
            element_type: match record.kind {
                st::ElementKind::Lever => ElementType::Lever,
                st::ElementKind::Button => ElementType::Button,
            },
        })
    }

    fn delete_element(&self, element: &ElementRecord) -> Result<(), PortError> {
        self.db
            .delete_train_element(self.op(), EntityId(element.id))
            .map_err(port_error)?;
        Ok(())
    }
}

// ---------------------------------------------------------------------------
// Hardware catalog
// ---------------------------------------------------------------------------

/// Hardware catalog port over the `hardware` storage repository.
pub struct StorageHardware {
    db: Arc<Database>,
    operations: AtomicU64,
}

impl StorageHardware {
    fn op(&self) -> OperationId {
        next_operation(&self.operations)
    }

    fn validate_i2c_attrs(&self, attrs: &I2cModuleAttrs, address: i64) -> Result<(), PortError> {
        if let Some(chip) = attrs.module_chip.as_deref() {
            if chip != "ht16k33" {
                return Err(PortError::Validation(vec![(
                    "module_chip".to_string(),
                    vec!["is invalid".to_string()],
                )]));
            }
        }
        if let Some(name) = attrs.name.as_deref() {
            if name.chars().count() > 100 {
                return Err(PortError::Validation(vec![(
                    "name".to_string(),
                    vec!["should be at most 100 characters".to_string()],
                )]));
            }
        }
        if let Some(brightness) = attrs.brightness {
            let mut errors = Vec::new();
            if brightness < 0 {
                errors.push("must be greater than or equal to 0".to_string());
            }
            if brightness > 15 {
                errors.push("must be less than or equal to 15".to_string());
            }
            if !errors.is_empty() {
                return Err(PortError::Validation(vec![(
                    "brightness".to_string(),
                    errors,
                )]));
            }
        }
        if let Some(num_digits) = attrs.num_digits {
            if ![4, 8].contains(&num_digits) {
                return Err(PortError::Validation(vec![(
                    "num_digits".to_string(),
                    vec!["is invalid".to_string()],
                )]));
            }
        }
        if !(0..=255).contains(&address) {
            return Err(PortError::Validation(vec![(
                "i2c_address".to_string(),
                vec![
                    "must be greater than or equal to 0 and less than or equal to 255".to_string(),
                ],
            )]));
        }
        Ok(())
    }

    fn i2c_params(&self, params: Option<&st::Ht16k33Params>) -> I2cModuleParams {
        match params {
            Some(params) => I2cModuleParams {
                brightness: i64::from(params.brightness),
                num_digits: i64::from(params.num_digits),
                display_type: match params.display_type {
                    st::DisplayType::SevenSegment => "seven_segment".to_string(),
                    st::DisplayType::FourteenSegment => "fourteen_segment".to_string(),
                },
                has_dot: params.has_dot,
                align_right: params.align_right,
                min_value: params.min_value.unwrap_or(0.0),
            },
            None => I2cModuleParams {
                brightness: 8,
                num_digits: 4,
                display_type: "fourteen_segment".to_string(),
                has_dot: false,
                align_right: true,
                min_value: 0.0,
            },
        }
    }

    fn i2c_view(&self, record: &st::I2cModuleRecord, device_name: &str) -> I2cModuleRecord {
        I2cModuleRecord {
            id: record.id.0,
            device_id: record.device_id.0,
            device_name: device_name.to_string(),
            name: record.name.clone(),
            module_chip: record.module_chip.clone(),
            i2c_address: i64::from(record.i2c_address),
            params: self.i2c_params(record.params.as_ref()),
        }
    }

    fn device_name(&self, id: EntityId) -> Result<String, PortError> {
        Ok(self
            .db
            .get_device(id)
            .map_err(port_error)?
            .map(|device| device.name.unwrap_or_default())
            .unwrap_or_default())
    }
}

impl HardwarePort for StorageHardware {
    fn list_devices(&self) -> Vec<DeviceSummary> {
        let Ok((snapshot, _)) = self.db.hardware_snapshot() else {
            return Vec::new();
        };
        let mut devices: Vec<(Option<String>, i64)> = snapshot
            .devices
            .iter()
            .map(|device| (device.name.clone(), device.id.0))
            .collect();
        devices.sort_by(|a, b| a.0.cmp(&b.0).then(a.1.cmp(&b.1)));
        devices
            .into_iter()
            .map(|(name, id)| DeviceSummary {
                id,
                name: name.unwrap_or_default(),
            })
            .collect()
    }

    fn list_inputs(&self, device_id: i64) -> Result<Vec<InputRecord>, PortError> {
        Ok(self
            .db
            .inputs_for_device(EntityId(device_id), false)
            .map_err(port_error)?
            .into_iter()
            .filter_map(|input| {
                let kind = input.kind?;
                let pin = input.pin?;
                Some(InputRecord {
                    id: input.id.0,
                    name: input.name.unwrap_or_default(),
                    pin: i64::from(pin),
                    input_type: match kind {
                        st::InputKind::Analog => InputType::Analog,
                        st::InputKind::Button => InputType::Button,
                    },
                })
            })
            .collect())
    }

    fn list_outputs(&self) -> Vec<HardwareOutputRecord> {
        let Ok((snapshot, _)) = self.db.hardware_snapshot() else {
            return Vec::new();
        };
        let mut devices = snapshot.devices.clone();
        devices.sort_by(|a, b| a.name.cmp(&b.name).then(a.id.cmp(&b.id)));
        devices
            .iter()
            .flat_map(|device| {
                snapshot
                    .outputs
                    .iter()
                    .filter(|output| output.device_id == device.id)
                    .map(|output| HardwareOutputRecord {
                        id: output.id.0,
                        name: output.name.clone().unwrap_or_default(),
                        pin: i64::from(output.pin),
                        device_id: device.id.0,
                        device_name: device.name.clone().unwrap_or_default(),
                    })
                    .collect::<Vec<_>>()
            })
            .collect()
    }

    fn list_i2c_modules(&self) -> Vec<I2cModuleRecord> {
        let Ok((snapshot, _)) = self.db.hardware_snapshot() else {
            return Vec::new();
        };
        let mut modules = snapshot.i2c_modules.clone();
        modules.sort_by(|a, b| a.i2c_address.cmp(&b.i2c_address).then(a.id.cmp(&b.id)));
        modules
            .iter()
            .map(|record| {
                let device_name = snapshot
                    .devices
                    .iter()
                    .find(|device| device.id == record.device_id)
                    .and_then(|device| device.name.clone())
                    .unwrap_or_default();
                self.i2c_view(record, &device_name)
            })
            .collect()
    }

    fn create_i2c_module(
        &self,
        device_id: i64,
        i2c_address: i64,
        attrs: I2cModuleAttrs,
    ) -> Result<I2cModuleRecord, PortError> {
        self.validate_i2c_attrs(&attrs, i2c_address)?;
        let record = self
            .db
            .create_i2c_module(
                self.op(),
                EntityId(device_id),
                st::I2cModuleDraft {
                    name: attrs.name.clone(),
                    module_chip: attrs
                        .module_chip
                        .clone()
                        .unwrap_or_else(|| "ht16k33".to_string()),
                    i2c_address: i2c_address as i32,
                    params: Some(st::Ht16k33Params {
                        brightness: attrs.brightness.unwrap_or(8) as i32,
                        num_digits: attrs.num_digits.unwrap_or(4) as i32,
                        display_type: st::DisplayType::FourteenSegment,
                        has_dot: false,
                        align_right: true,
                        min_value: Some(0.0),
                    }),
                },
            )
            .map_err(|error| {
                let duplicate = matches!(
                    &error,
                    StorageError::Sqlite(sqlite)
                        if sqlite.to_string().contains("device_i2c_modules")
                ) || matches!(
                    &error,
                    StorageError::Conflict { detail }
                        if detail.contains("UNIQUE constraint failed: device_i2c_modules")
                );
                if duplicate {
                    PortError::Validation(vec![(
                        "i2c_address".to_string(),
                        vec!["has already been taken".to_string()],
                    )])
                } else {
                    port_error(error)
                }
            })?
            .record;
        let device_name = self.device_name(record.device_id)?;
        Ok(self.i2c_view(&record, &device_name))
    }

    fn get_i2c_module(&self, id: i64) -> Result<I2cModuleRecord, PortError> {
        let (snapshot, _) = self.db.hardware_snapshot().map_err(port_error)?;
        let record = snapshot
            .i2c_modules
            .iter()
            .find(|module| module.id.0 == id)
            .ok_or(PortError::NotFound)?;
        let device_name = snapshot
            .devices
            .iter()
            .find(|device| device.id == record.device_id)
            .and_then(|device| device.name.clone())
            .unwrap_or_default();
        Ok(self.i2c_view(record, &device_name))
    }

    fn update_i2c_module(
        &self,
        module: &I2cModuleRecord,
        changes: I2cModuleChanges,
    ) -> Result<I2cModuleRecord, PortError> {
        let attrs = I2cModuleAttrs {
            name: changes.name.clone(),
            module_chip: Some("ht16k33".to_string()),
            brightness: changes.brightness,
            num_digits: changes.num_digits,
        };
        self.validate_i2c_attrs(&attrs, module.i2c_address)?;
        let (snapshot, _) = self.db.hardware_snapshot().map_err(port_error)?;
        let current = snapshot
            .i2c_modules
            .iter()
            .find(|candidate| candidate.id.0 == module.id)
            .cloned()
            .ok_or(PortError::NotFound)?;
        let current_params = self.i2c_params(current.params.as_ref());
        let record = self
            .db
            .update_i2c_module(
                self.op(),
                EntityId(module.id),
                st::I2cModuleDraft {
                    name: changes.name.or(current.name),
                    module_chip: current.module_chip,
                    i2c_address: current.i2c_address,
                    params: Some(st::Ht16k33Params {
                        brightness: changes.brightness.unwrap_or(current_params.brightness) as i32,
                        num_digits: changes.num_digits.unwrap_or(current_params.num_digits) as i32,
                        display_type: match current_params.display_type.as_str() {
                            "seven_segment" => st::DisplayType::SevenSegment,
                            _ => st::DisplayType::FourteenSegment,
                        },
                        has_dot: current_params.has_dot,
                        align_right: current_params.align_right,
                        min_value: Some(current_params.min_value),
                    }),
                },
            )
            .map_err(port_error)?
            .record;
        let device_name = self.device_name(record.device_id)?;
        Ok(self.i2c_view(&record, &device_name))
    }

    fn delete_i2c_module(&self, module: &I2cModuleRecord) -> Result<(), PortError> {
        self.db
            .delete_i2c_module(self.op(), EntityId(module.id))
            .map_err(port_error)?;
        Ok(())
    }
}

// ---------------------------------------------------------------------------
// Sequences
// ---------------------------------------------------------------------------

/// Sequences port over the `sequences` domain repository.
pub struct StorageSequences {
    db: Arc<Database>,
    operations: AtomicU64,
}

impl StorageSequences {
    fn op(&self) -> OperationId {
        next_operation(&self.operations)
    }

    fn view(&self, record: st::SequenceRecord) -> Result<SequenceRecord, PortError> {
        let commands = self
            .db
            .sequence_commands(record.id)
            .map_err(port_error)?
            .into_iter()
            .map(|command| SequenceCommandRecord {
                id: command.id.0,
                position: command.position,
                endpoint: command.endpoint,
                value: command.value,
                delay_ms: command.delay_ms,
            })
            .collect();
        Ok(SequenceRecord {
            id: record.id.0,
            train_id: record.train_id.0,
            name: record.name,
            commands,
        })
    }
}

impl SequencesPort for StorageSequences {
    fn list_sequences(&self, train_id: i64) -> Vec<SequenceRecord> {
        let Ok(records) = self.db.list_sequences(EntityId(train_id)) else {
            return Vec::new();
        };
        records
            .into_iter()
            .filter_map(|record| self.view(record).ok())
            .collect()
    }

    fn create_sequence(
        &self,
        train_id: i64,
        name: Option<String>,
    ) -> Result<SequenceRecord, PortError> {
        let name = name.unwrap_or_default();
        let trimmed = name.trim();
        if trimmed.is_empty() {
            return Err(cant_be_blank("name"));
        }
        if name.chars().count() > 100 {
            return Err(PortError::Validation(vec![(
                "name".to_string(),
                vec!["should be at most 100 characters".to_string()],
            )]));
        }
        let record = self
            .db
            .create_sequence(self.op(), EntityId(train_id), st::SequenceDraft { name })
            .map_err(port_error)?
            .record;
        self.view(record)
    }

    fn get_sequence(&self, id: i64) -> Result<SequenceRecord, PortError> {
        let record = self
            .db
            .get_sequence(EntityId(id))
            .map_err(port_error)?
            .ok_or(PortError::NotFound)?;
        self.view(record)
    }

    fn update_sequence_name(
        &self,
        sequence: &SequenceRecord,
        name: Option<String>,
    ) -> Result<(), PortError> {
        let Some(name) = name else {
            return Ok(());
        };
        let trimmed = name.trim();
        if trimmed.is_empty() {
            return Err(cant_be_blank("name"));
        }
        if name.chars().count() > 100 {
            return Err(PortError::Validation(vec![(
                "name".to_string(),
                vec!["should be at most 100 characters".to_string()],
            )]));
        }
        self.db
            .update_sequence(
                self.op(),
                EntityId(sequence.id),
                st::SequencePatch { name: Some(name) },
            )
            .map_err(port_error)?;
        Ok(())
    }

    fn set_sequence_commands(
        &self,
        sequence: &SequenceRecord,
        commands: Vec<SequenceCommandDraft>,
    ) -> Result<(), PortError> {
        let drafts: Vec<st::SequenceCommandDraft> = commands
            .into_iter()
            .map(|command| st::SequenceCommandDraft {
                endpoint: command.endpoint.unwrap_or_default(),
                value: command.value.unwrap_or(0.0),
                delay_ms: command.delay_ms,
            })
            .collect();
        // Elixir surfaces `set_sequence_commands` failures as
        // `{:error, reason}`, phrased "Failed to set commands: …" by the tool.
        self.db
            .set_sequence_commands(self.op(), EntityId(sequence.id), drafts)
            .map_err(|error| match error {
                StorageError::Constraint { detail } | StorageError::InvalidHardware { detail } => {
                    PortError::Failed(detail)
                }
                other => port_error(other),
            })?;
        Ok(())
    }

    fn delete_sequence(&self, sequence: &SequenceRecord) -> Result<(), PortError> {
        self.db
            .delete_sequence(self.op(), EntityId(sequence.id))
            .map_err(port_error)?;
        Ok(())
    }
}

// ---------------------------------------------------------------------------
// Scripts
// ---------------------------------------------------------------------------

/// Scripts port over the `scripts` domain repository.
pub struct StorageScripts {
    db: Arc<Database>,
    operations: AtomicU64,
}

impl StorageScripts {
    fn op(&self) -> OperationId {
        next_operation(&self.operations)
    }

    fn validate_attrs(&self, attrs: &ScriptAttrs) -> Result<(), PortError> {
        if let Some(name) = attrs.name.as_deref() {
            let trimmed = name.trim();
            if trimmed.is_empty() {
                return Err(cant_be_blank("name"));
            }
            if name.chars().count() > 100 {
                return Err(PortError::Validation(vec![(
                    "name".to_string(),
                    vec!["should be at most 100 characters".to_string()],
                )]));
            }
        }
        if let Some(code) = attrs.code.as_deref() {
            if code.trim().is_empty() {
                return Err(cant_be_blank("code"));
            }
        }
        Ok(())
    }
}

fn script_view(record: st::ScriptRecord) -> ScriptRecord {
    ScriptRecord {
        id: record.id.0,
        train_id: record.train_id.0,
        name: record.name,
        enabled: record.enabled,
        code: record.code,
        triggers: record.triggers,
    }
}

impl ScriptsPort for StorageScripts {
    fn list_scripts(&self, train_id: i64) -> Vec<ScriptRecord> {
        self.db
            .list_scripts(EntityId(train_id))
            .map(|scripts| scripts.into_iter().map(script_view).collect())
            .unwrap_or_default()
    }

    fn get_script(&self, id: i64) -> Result<ScriptRecord, PortError> {
        self.db
            .get_script(EntityId(id))
            .map_err(port_error)?
            .map(script_view)
            .ok_or(PortError::NotFound)
    }

    fn create_script(&self, train_id: i64, attrs: ScriptAttrs) -> Result<ScriptRecord, PortError> {
        self.validate_attrs(&attrs)?;
        let record = self
            .db
            .create_script(
                self.op(),
                EntityId(train_id),
                st::ScriptDraft {
                    name: attrs.name.unwrap_or_default(),
                    enabled: attrs.enabled.unwrap_or(true),
                    code: attrs.code.unwrap_or_default(),
                    triggers: attrs.triggers.unwrap_or_default(),
                },
            )
            .map_err(port_error)?
            .record;
        Ok(script_view(record))
    }

    fn update_script(
        &self,
        script: &ScriptRecord,
        changes: ScriptAttrs,
    ) -> Result<ScriptRecord, PortError> {
        self.validate_attrs(&changes)?;
        let record = self
            .db
            .update_script(
                self.op(),
                EntityId(script.id),
                st::ScriptPatch {
                    name: changes.name,
                    enabled: changes.enabled,
                    code: changes.code,
                    triggers: changes.triggers,
                },
            )
            .map_err(port_error)?
            .record;
        Ok(script_view(record))
    }

    fn delete_script(&self, script: &ScriptRecord) -> Result<(), PortError> {
        self.db
            .delete_script(self.op(), EntityId(script.id))
            .map_err(port_error)?;
        Ok(())
    }
}

// ---------------------------------------------------------------------------
// Bindings
// ---------------------------------------------------------------------------

fn output_binding_view(record: st::OutputBindingRecord) -> OutputBindingRecord {
    OutputBindingRecord {
        id: record.id.0,
        train_id: record.train_id.0,
        name: record.name,
        output_id: record.output_id.0,
        endpoint: record.endpoint,
        operator: match record.operator {
            st::OutputBindingOperator::Gt => BindingOperator::Gt,
            st::OutputBindingOperator::Gte => BindingOperator::Gte,
            st::OutputBindingOperator::Lt => BindingOperator::Lt,
            st::OutputBindingOperator::Lte => BindingOperator::Lte,
            st::OutputBindingOperator::Between => BindingOperator::Between,
            st::OutputBindingOperator::EqTrue => BindingOperator::EqTrue,
            st::OutputBindingOperator::EqFalse => BindingOperator::EqFalse,
        },
        value_a: record.value_a,
        value_b: record.value_b,
        enabled: record.enabled,
    }
}

fn output_operator_db(operator: BindingOperator) -> st::OutputBindingOperator {
    match operator {
        BindingOperator::Gt => st::OutputBindingOperator::Gt,
        BindingOperator::Gte => st::OutputBindingOperator::Gte,
        BindingOperator::Lt => st::OutputBindingOperator::Lt,
        BindingOperator::Lte => st::OutputBindingOperator::Lte,
        BindingOperator::Between => st::OutputBindingOperator::Between,
        BindingOperator::EqTrue => st::OutputBindingOperator::EqTrue,
        BindingOperator::EqFalse => st::OutputBindingOperator::EqFalse,
    }
}

fn button_binding_view(record: st::ButtonBindingRecord) -> ButtonBindingRecord {
    ButtonBindingRecord {
        id: record.id.0,
        element_id: record.element_id.0,
        input_id: record.input_id.0,
        mode: match record.mode {
            st::ButtonMode::Simple => ButtonMode::Simple,
            st::ButtonMode::Momentary => ButtonMode::Momentary,
            st::ButtonMode::Sequence => ButtonMode::Sequence,
            st::ButtonMode::Keystroke => ButtonMode::Keystroke,
        },
        endpoint: record.endpoint,
        on_value: record.on_value,
        off_value: record.off_value,
        enabled: record.enabled,
        hardware_type: match record.hardware_type {
            st::ButtonHardwareType::Momentary => HardwareType::Momentary,
            st::ButtonHardwareType::Latching => HardwareType::Latching,
        },
        keystroke: record.keystroke,
        repeat_interval_ms: record.repeat_interval_ms,
        on_sequence_id: record.on_sequence_id.map(|id| id.0),
        off_sequence_id: record.off_sequence_id.map(|id| id.0),
    }
}

fn display_binding_view(record: st::DisplayBindingRecord) -> DisplayBindingRecord {
    DisplayBindingRecord {
        id: record.id.0,
        train_id: record.train_id.0,
        i2c_module_id: record.i2c_module_id.0,
        name: record.name,
        endpoint: record.endpoint,
        format_string: record.format_string,
        enabled: record.enabled,
    }
}

/// Bindings port over the `bindings` domain repository. The destination
/// exclusivity rule (vJoy-mapped inputs) surfaces as
/// [`PortError::DestinationConflict`] exactly like the Elixir context's
/// `{:error, :destination_conflict}`.
pub struct StorageBindings {
    db: Arc<Database>,
    operations: AtomicU64,
}

impl StorageBindings {
    fn op(&self) -> OperationId {
        next_operation(&self.operations)
    }
}

impl crate::mcp::ports::BindingsPort for StorageBindings {
    fn list_output_bindings(&self, train_id: i64) -> Vec<OutputBindingRecord> {
        self.db
            .list_output_bindings(EntityId(train_id))
            .map(|bindings| bindings.into_iter().map(output_binding_view).collect())
            .unwrap_or_default()
    }

    fn create_output_binding(
        &self,
        train_id: i64,
        attrs: OutputBindingAttrs,
    ) -> Result<OutputBindingRecord, PortError> {
        let (name, output_id, endpoint) =
            (attrs.name.clone(), attrs.output_id, attrs.endpoint.clone());
        if name.as_deref().map(str::trim).unwrap_or("").is_empty() {
            return Err(cant_be_blank("name"));
        }
        let Some(output_id) = output_id else {
            return Err(cant_be_blank("output_id"));
        };
        if endpoint.as_deref().map(str::trim).unwrap_or("").is_empty() {
            return Err(cant_be_blank("endpoint"));
        }
        let Some(operator) = attrs.operator else {
            return Err(cant_be_blank("operator"));
        };
        let record = self
            .db
            .create_output_binding(
                self.op(),
                EntityId(train_id),
                st::OutputBindingDraft {
                    name: name.unwrap_or_default(),
                    output_type: None,
                    output_id: EntityId(output_id),
                    endpoint: endpoint.unwrap_or_default(),
                    operator: output_operator_db(operator),
                    value_a: attrs.value_a,
                    value_b: attrs.value_b,
                    enabled: attrs.enabled,
                },
            )
            .map_err(port_error)?
            .record;
        Ok(output_binding_view(record))
    }

    fn get_output_binding(&self, id: i64) -> Result<OutputBindingRecord, PortError> {
        self.db
            .get_output_binding(EntityId(id))
            .map_err(port_error)?
            .map(output_binding_view)
            .ok_or(PortError::NotFound)
    }

    fn update_output_binding(
        &self,
        binding: &OutputBindingRecord,
        changes: OutputBindingAttrs,
    ) -> Result<OutputBindingRecord, PortError> {
        let record = self
            .db
            .update_output_binding(
                self.op(),
                EntityId(binding.id),
                st::OutputBindingPatch {
                    name: changes.name,
                    output_type: None,
                    output_id: changes.output_id.map(EntityId),
                    endpoint: changes.endpoint,
                    operator: changes.operator.map(output_operator_db),
                    value_a: changes.value_a.map(Some),
                    value_b: changes.value_b.map(Some),
                    enabled: changes.enabled,
                },
            )
            .map_err(port_error)?
            .record;
        Ok(output_binding_view(record))
    }

    fn delete_output_binding(&self, binding: &OutputBindingRecord) -> Result<(), PortError> {
        self.db
            .delete_output_binding(self.op(), EntityId(binding.id))
            .map_err(port_error)?;
        Ok(())
    }

    fn get_button_binding(&self, element_id: i64) -> Result<ButtonBindingRecord, PortError> {
        self.db
            .get_button_binding(EntityId(element_id))
            .map_err(port_error)?
            .map(button_binding_view)
            .ok_or(PortError::NotFound)
    }

    fn create_button_binding(
        &self,
        element_id: i64,
        input_id: i64,
        attrs: ButtonBindingAttrs,
    ) -> Result<ButtonBindingRecord, PortError> {
        let record = self
            .db
            .create_button_binding(
                self.op(),
                EntityId(element_id),
                EntityId(input_id),
                st::ButtonBindingDraft {
                    endpoint: attrs.endpoint.clone(),
                    on_value: attrs.on_value,
                    off_value: attrs.off_value,
                    enabled: attrs.enabled,
                    mode: attrs.mode.map(|mode| match mode {
                        ButtonMode::Simple => st::ButtonMode::Simple,
                        ButtonMode::Momentary => st::ButtonMode::Momentary,
                        ButtonMode::Sequence => st::ButtonMode::Sequence,
                        ButtonMode::Keystroke => st::ButtonMode::Keystroke,
                    }),
                    hardware_type: attrs.hardware_type.map(|hardware| match hardware {
                        HardwareType::Momentary => st::ButtonHardwareType::Momentary,
                        HardwareType::Latching => st::ButtonHardwareType::Latching,
                    }),
                    repeat_interval_ms: attrs.repeat_interval_ms,
                    keystroke: attrs.keystroke,
                    on_sequence_id: attrs.on_sequence_id.map(EntityId),
                    off_sequence_id: attrs.off_sequence_id.map(EntityId),
                },
            )
            .map_err(port_error)?
            .record;
        Ok(button_binding_view(record))
    }

    fn update_button_binding(
        &self,
        binding: &ButtonBindingRecord,
        changes: ButtonBindingAttrs,
    ) -> Result<ButtonBindingRecord, PortError> {
        let record = self
            .db
            .update_button_binding(
                self.op(),
                EntityId(binding.id),
                st::ButtonBindingPatch {
                    input_id: None,
                    endpoint: changes.endpoint.map(Some),
                    on_value: changes.on_value,
                    off_value: changes.off_value,
                    enabled: changes.enabled,
                    mode: changes.mode.map(|mode| match mode {
                        ButtonMode::Simple => st::ButtonMode::Simple,
                        ButtonMode::Momentary => st::ButtonMode::Momentary,
                        ButtonMode::Sequence => st::ButtonMode::Sequence,
                        ButtonMode::Keystroke => st::ButtonMode::Keystroke,
                    }),
                    hardware_type: changes.hardware_type.map(|hardware| match hardware {
                        HardwareType::Momentary => st::ButtonHardwareType::Momentary,
                        HardwareType::Latching => st::ButtonHardwareType::Latching,
                    }),
                    repeat_interval_ms: changes.repeat_interval_ms,
                    keystroke: changes.keystroke.map(Some),
                    on_sequence_id: changes.on_sequence_id.map(|id| Some(EntityId(id))),
                    off_sequence_id: changes.off_sequence_id.map(|id| Some(EntityId(id))),
                },
            )
            .map_err(port_error)?
            .record;
        Ok(button_binding_view(record))
    }

    fn delete_button_binding(&self, element_id: i64) -> Result<(), PortError> {
        self.db
            .delete_button_binding(self.op(), EntityId(element_id))
            .map_err(port_error)?;
        Ok(())
    }

    fn list_display_bindings(&self, train_id: i64) -> Vec<DisplayBindingRecord> {
        self.db
            .list_display_bindings(EntityId(train_id))
            .map(|bindings| bindings.into_iter().map(display_binding_view).collect())
            .unwrap_or_default()
    }

    fn create_display_binding(
        &self,
        train_id: i64,
        attrs: DisplayBindingAttrs,
    ) -> Result<DisplayBindingRecord, PortError> {
        if attrs
            .endpoint
            .as_deref()
            .map(str::trim)
            .unwrap_or("")
            .is_empty()
        {
            return Err(cant_be_blank("endpoint"));
        }
        let Some(i2c_module_id) = attrs.i2c_module_id else {
            return Err(cant_be_blank("i2c_module_id"));
        };
        let record = self
            .db
            .create_display_binding(
                self.op(),
                EntityId(train_id),
                st::DisplayBindingDraft {
                    i2c_module_id: EntityId(i2c_module_id),
                    name: attrs.name.clone(),
                    endpoint: attrs.endpoint.unwrap_or_default(),
                    format_string: attrs.format_string.clone(),
                    enabled: attrs.enabled,
                },
            )
            .map_err(port_error)?
            .record;
        Ok(display_binding_view(record))
    }

    fn get_display_binding(&self, id: i64) -> Result<DisplayBindingRecord, PortError> {
        self.db
            .get_display_binding(EntityId(id))
            .map_err(port_error)?
            .map(display_binding_view)
            .ok_or(PortError::NotFound)
    }

    fn update_display_binding(
        &self,
        binding: &DisplayBindingRecord,
        changes: DisplayBindingAttrs,
    ) -> Result<DisplayBindingRecord, PortError> {
        let record = self
            .db
            .update_display_binding(
                self.op(),
                EntityId(binding.id),
                st::DisplayBindingPatch {
                    i2c_module_id: changes.i2c_module_id.map(EntityId),
                    name: changes.name.map(Some),
                    endpoint: changes.endpoint,
                    format_string: changes.format_string,
                    enabled: changes.enabled,
                },
            )
            .map_err(port_error)?
            .record;
        Ok(display_binding_view(record))
    }

    fn delete_display_binding(&self, binding: &DisplayBindingRecord) -> Result<(), PortError> {
        self.db
            .delete_display_binding(self.op(), EntityId(binding.id))
            .map_err(port_error)?;
        Ok(())
    }
}

// ---------------------------------------------------------------------------
// Simulator / detection defaults
// ---------------------------------------------------------------------------

/// Default simulator backing: no live session. The tool layer checks
/// `is_connected` first and answers with the Elixir not-connected error, so
/// the raw methods are unreachable through MCP.
pub struct DisconnectedSimulator;

impl SimulatorPort for DisconnectedSimulator {
    fn is_connected(&self) -> bool {
        false
    }
    fn list_endpoints(&self, _path: Option<&str>) -> Result<Value, String> {
        Err("not connected".to_string())
    }
    fn get_value(&self, _path: &str) -> Result<Value, String> {
        Err("not connected".to_string())
    }
    fn set_value(&self, _path: &str, _value: &Value) -> Result<Value, String> {
        Err("not connected".to_string())
    }
}

/// Default detection backing: no interactive hardware runtime yet, so every
/// request resolves as a timeout immediately (same payload the Elixir tool
/// produces on timeout; only the wait is skipped). Inject a real
/// [`DetectionPort`] once the controllers wave owns the input detection
/// session.
pub struct NoDetection;

impl DetectionPort for NoDetection {
    fn detect_input(&self, _request: &DetectionRequest) -> DetectionOutcome {
        DetectionOutcome::Timeout
    }
}

// ---------------------------------------------------------------------------
// vJoy
// ---------------------------------------------------------------------------

/// Live vJoy runtime surface used for status/lifecycle/reload. Implemented by
/// the real manager in the app wiring; the storage-backed default reproduces
/// the Elixir manager-absent behavior on non-Windows platforms
/// (`unsupported`).
pub trait VjoyRuntime: Send + Sync {
    fn status_details(&self) -> VjoyStatusDetails;
    fn lifecycle(&self, command: VjoyCommand) -> Result<(), VjoyReason>;
    fn reload_mappings(&self);
}

fn manager_status_view(status: crate::vjoy::manager::VjoyStatus) -> VjoyStatus {
    match status {
        crate::vjoy::manager::VjoyStatus::Unsupported => VjoyStatus::Unsupported,
        crate::vjoy::manager::VjoyStatus::Off => VjoyStatus::Off,
        crate::vjoy::manager::VjoyStatus::Enabling => VjoyStatus::Enabling,
        crate::vjoy::manager::VjoyStatus::Active => VjoyStatus::Active,
        crate::vjoy::manager::VjoyStatus::Disabling => VjoyStatus::Disabling,
        crate::vjoy::manager::VjoyStatus::NeedsSetup => VjoyStatus::NeedsSetup,
        crate::vjoy::manager::VjoyStatus::NeedsCleanup => VjoyStatus::NeedsCleanup,
        crate::vjoy::manager::VjoyStatus::Degraded => VjoyStatus::Degraded,
        crate::vjoy::manager::VjoyStatus::Error => VjoyStatus::Error,
    }
}

fn vjoy_error_reason(error: crate::vjoy::VjoyError) -> VjoyReason {
    use crate::vjoy::VjoyError as E;
    match error {
        E::Unsupported => VjoyReason::Code("unsupported".to_string()),
        E::DriverUnavailable(detail) => {
            VjoyReason::CodeWithDetails("driver_unavailable".to_string(), detail)
        }
        E::DeviceMissing(device) => {
            VjoyReason::CodeWithDetails("device_missing".to_string(), device.to_string())
        }
        E::DeviceBusy(device) => {
            VjoyReason::CodeWithDetails("device_busy".to_string(), device.to_string())
        }
        E::IncompatibleDevice(device, detail) => VjoyReason::CodeWithDetails(
            "incompatible_device".to_string(),
            format!("{device}: {detail}"),
        ),
        E::AcquireFailed(device, detail) => {
            VjoyReason::CodeWithDetails("acquire_failed".to_string(), format!("{device}: {detail}"))
        }
        E::NeutralizeFailed(device, detail) => VjoyReason::CodeWithDetails(
            "neutralize_failed".to_string(),
            format!("{device}: {detail}"),
        ),
        E::ReportFailed(device, detail) => {
            VjoyReason::CodeWithDetails("report_failed".to_string(), format!("{device}: {detail}"))
        }
        E::Configurator(error) => {
            VjoyReason::CodeWithDetails("configurator".to_string(), error.to_string())
        }
        E::InvalidState(detail) => {
            VjoyReason::CodeWithDetails("invalid_state".to_string(), detail.to_string())
        }
        E::Quarantined(device, detail) => {
            VjoyReason::CodeWithDetails("quarantined".to_string(), format!("{device}: {detail}"))
        }
        E::ArbiterBusy => VjoyReason::Code("arbiter_busy".to_string()),
        E::Storage(detail) => VjoyReason::CodeWithDetails("storage".to_string(), detail),
    }
}

impl<A: crate::vjoy::VjoyAdapter> VjoyRuntime for crate::vjoy::VjoyManager<A> {
    fn status_details(&self) -> VjoyStatusDetails {
        let (status, reason) = VjoyManager::status_details(self);
        VjoyStatusDetails {
            status: manager_status_view(status),
            reason: reason.map(vjoy_error_reason),
        }
    }

    fn lifecycle(&self, command: VjoyCommand) -> Result<(), VjoyReason> {
        let result = match command {
            VjoyCommand::Enable => VjoyManager::enable(self),
            VjoyCommand::Disable => VjoyManager::disable(self),
            VjoyCommand::Retry => VjoyManager::retry(self),
            // The manager wave has not ported the leftover-removal and
            // installation-recheck transitions yet.
            VjoyCommand::RemoveLeftover | VjoyCommand::Repair => {
                return Err(VjoyReason::Code("runtime_unavailable".to_string()))
            }
        };
        result.map_err(vjoy_error_reason)
    }

    fn reload_mappings(&self) {
        // Mapping reload is consumed by the mapper component (controllers
        // wave); the store read the manager would trigger is re-evaluated on
        // every list call, so there is nothing to invalidate here yet.
    }
}

/// vJoy port: mapping CRUD over the `vjoy` store; status/lifecycle delegated
/// to the injected [`VjoyRuntime`] (default: unsupported).
pub struct StorageVjoy {
    db: Arc<Database>,
    runtime: Option<Arc<dyn VjoyRuntime>>,
    operations: AtomicU64,
}

fn vjoy_mapping_view(record: &st::MappingRecord) -> VjoyMappingRecord {
    VjoyMappingRecord {
        id: record.id.0,
        input_id: record.input_id.0,
        device_index: i64::from(record.device_index),
        target_type: match record.target {
            st::Target::Axis(_) => VjoyTarget::Axis,
            st::Target::Button(_) => VjoyTarget::Button,
        },
        axis: match record.target {
            st::Target::Axis(axis) => Some(axis.as_db().to_string()),
            st::Target::Button(_) => None,
        },
        button: match record.target {
            st::Target::Axis(_) => None,
            st::Target::Button(button) => Some(i64::from(button)),
        },
        inverted: record.inverted,
    }
}

impl VjoyPort for StorageVjoy {
    fn status_details(&self) -> VjoyStatusDetails {
        match &self.runtime {
            Some(runtime) => runtime.status_details(),
            None => VjoyStatusDetails {
                status: VjoyStatus::Unsupported,
                reason: None,
            },
        }
    }

    fn list_mappings(&self) -> Vec<VjoyMappingRecord> {
        self.db
            .vjoy_list_mappings()
            .map(|mappings| mappings.iter().map(vjoy_mapping_view).collect())
            .unwrap_or_default()
    }

    fn put_mapping(
        &self,
        input_id: i64,
        draft: VjoyMappingDraft,
        replace: bool,
    ) -> Result<VjoyMappingRecord, VjoyPutError> {
        let device_index = u8::try_from(draft.device_index).map_err(|_| {
            VjoyPutError::Validation(vec![(
                "device_index".to_string(),
                vec!["is invalid".to_string()],
            )])
        })?;
        let target = match draft.target_type {
            VjoyTarget::Axis => {
                let axis = draft
                    .axis
                    .as_deref()
                    .and_then(st::VjoyAxis::parse)
                    .ok_or_else(|| {
                        VjoyPutError::Validation(vec![(
                            "axis".to_string(),
                            vec!["is invalid".to_string()],
                        )])
                    })?;
                st::Target::Axis(axis)
            }
            VjoyTarget::Button => {
                let button = u8::try_from(draft.button.unwrap_or(0))
                    .ok()
                    .filter(|b| (1..=32).contains(b))
                    .ok_or_else(|| {
                        VjoyPutError::Validation(vec![(
                            "button".to_string(),
                            vec!["must be an integer from 1 to 32".to_string()],
                        )])
                    })?;
                st::Target::Button(button)
            }
        };
        let record = self
            .db
            .vjoy_put_mapping(
                next_operation(&self.operations),
                EntityId(input_id),
                st::MappingDraft {
                    device_index,
                    target,
                    inverted: draft.inverted,
                },
                replace,
            )
            .map_err(|error| match error {
                StorageError::NotFound => VjoyPutError::NotFound,
                StorageError::Conflict { detail } if detail.contains("already been taken") => {
                    let field = detail.split_whitespace().next().unwrap_or("axis");
                    VjoyPutError::Validation(vec![(
                        field.to_string(),
                        vec!["has already been taken".to_string()],
                    )])
                }
                StorageError::Conflict { .. } => VjoyPutError::DestinationConflict,
                StorageError::Constraint { detail } => {
                    match detail.split_once(' ') {
                        Some((field, message)) if !field.is_empty() => VjoyPutError::Validation(
                            vec![(field.to_string(), vec![message.to_string()])],
                        ),
                        _ => VjoyPutError::Validation(vec![(String::new(), vec![detail])]),
                    }
                }
                other => VjoyPutError::Validation(vec![(String::new(), vec![other.to_string()])]),
            })?
            .record;
        Ok(vjoy_mapping_view(&record))
    }

    fn delete_mapping(&self, id: i64) -> Result<VjoyMappingRecord, PortError> {
        let record = self
            .db
            .vjoy_delete_mapping(next_operation(&self.operations), EntityId(id))
            .map_err(port_error)?
            .record;
        Ok(vjoy_mapping_view(&record))
    }

    fn lifecycle(&self, command: VjoyCommand) -> Result<(), VjoyReason> {
        match &self.runtime {
            Some(runtime) => runtime.lifecycle(command),
            // Elixir without a running manager on a non-Windows platform.
            None => Err(VjoyReason::Code("unsupported".to_string())),
        }
    }

    fn reload_mappings(&self) {
        if let Some(runtime) = &self.runtime {
            runtime.reload_mappings();
        }
    }
}

// ---------------------------------------------------------------------------
// Bundle
// ---------------------------------------------------------------------------

/// Storage-backed [`Ports`] bundle over one database plus optional live
/// services. The defaults match the Elixir application when the simulator
/// client, hardware detection session and vJoy manager are not running.
pub struct StoragePorts {
    db: Arc<Database>,
    simulator: Option<Arc<dyn SimulatorPort>>,
    detection: Option<Arc<dyn DetectionPort>>,
    vjoy_runtime: Option<Arc<dyn VjoyRuntime>>,
}

impl StoragePorts {
    pub fn new(db: Arc<Database>) -> Self {
        Self {
            db,
            simulator: None,
            detection: None,
            vjoy_runtime: None,
        }
    }

    /// Live simulator session backing (default: [`DisconnectedSimulator`]).
    pub fn with_simulator(mut self, simulator: Arc<dyn SimulatorPort>) -> Self {
        self.simulator = Some(simulator);
        self
    }

    /// Live hardware detection backing (default: [`NoDetection`]).
    pub fn with_detection(mut self, detection: Arc<dyn DetectionPort>) -> Self {
        self.detection = Some(detection);
        self
    }

    /// Live vJoy manager backing (default: unsupported).
    pub fn with_vjoy_runtime(mut self, runtime: Arc<dyn VjoyRuntime>) -> Self {
        self.vjoy_runtime = Some(runtime);
        self
    }

    /// Builds the port bundle consumed by [`crate::mcp::server::McpServer`].
    pub fn into_ports(self) -> Ports {
        Ports {
            trains: Arc::new(StorageTrains {
                db: self.db.clone(),
                operations: AtomicU64::new(0),
            }),
            hardware: Arc::new(StorageHardware {
                db: self.db.clone(),
                operations: AtomicU64::new(0),
            }),
            sequences: Arc::new(StorageSequences {
                db: self.db.clone(),
                operations: AtomicU64::new(0),
            }),
            scripts: Arc::new(StorageScripts {
                db: self.db.clone(),
                operations: AtomicU64::new(0),
            }),
            bindings: Arc::new(StorageBindings {
                db: self.db.clone(),
                operations: AtomicU64::new(0),
            }),
            simulator: self
                .simulator
                .unwrap_or_else(|| Arc::new(DisconnectedSimulator)),
            detection: self.detection.unwrap_or_else(|| Arc::new(NoDetection)),
            vjoy: Arc::new(StorageVjoy {
                db: self.db,
                runtime: self.vjoy_runtime,
                operations: AtomicU64::new(0),
            }),
        }
    }
}
