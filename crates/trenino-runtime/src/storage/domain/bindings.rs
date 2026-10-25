//! Typed persistence for the four train binding families on the `bindings`
//! topic. Ports the binding functions of `Trenino.Train` (lib/trenino/train.ex)
//! together with the changeset rules of
//! `Trenino.Train.{LeverInputBinding,ButtonInputBinding,OutputBinding,DisplayBinding}`:
//!
//! | Rust API                                     | Elixir function                          |
//! |----------------------------------------------|------------------------------------------|
//! | `get_lever_binding`                          | `get_binding/1`                          |
//! | `bind_lever_input(_with)`                    | `bind_input/2,3`                         |
//! | `unbind_lever_input`                         | `unbind_input/1`                         |
//! | `set_lever_binding_enabled(_with)`           | `set_binding_enabled/2,3`                |
//! | `list_lever_bindings_for_train`              | `list_bindings_for_train/1`              |
//! | `get_button_binding`                         | `get_button_binding/1`                   |
//! | `create_button_binding(_with)`               | `create_button_binding/3,4`              |
//! | `update_button_binding(_with)`               | `update_button_binding/2,3`              |
//! | `delete_button_binding`                      | `delete_button_binding/1`                |
//! | `set_button_binding_enabled(_with)`          | `set_button_binding_enabled/2,3`         |
//! | `list_button_bindings_for_train`             | `list_button_bindings_for_train/1`       |
//! | `list_output_bindings`                       | `list_output_bindings/1`                 |
//! | `list_enabled_output_bindings`               | `list_enabled_output_bindings/1`         |
//! | `get_output_binding`                         | `get_output_binding/1`                   |
//! | `create_output_binding`                      | `create_output_binding/2`                |
//! | `update_output_binding`                      | `update_output_binding/2`                |
//! | `delete_output_binding`                      | `delete_output_binding/1`                |
//! | `list_display_bindings`                      | `list_display_bindings/1`                |
//! | `list_enabled_display_bindings`              | `list_enabled_display_bindings/1`        |
//! | `get_display_binding`                        | `get_display_binding/1`                  |
//! | `create_display_binding`                     | `create_display_binding/2`               |
//! | `update_display_binding`                     | `update_display_binding/2`               |
//! | `delete_display_binding`                     | `delete_display_binding/1`               |
//!
//! Error categories mirror the Elixir outcomes: changeset validation failures
//! surface as `StorageError::Constraint` carrying the Ecto error text, unique
//! index violations as `StorageError::Conflict`, foreign-key violations as
//! `StorageError::ForeignKey`, and missing records on mutations as
//! `StorageError::NotFound` (reads return `Option`). The `replace?` option of
//! the Elixir `save_binding` transaction ports to [`BindOptions`]; enabling an
//! input binding whose input is claimed by a `virtual_joystick_mappings` row
//! conflicts unless `replace` deletes that mapping first, and a failed write
//! rolls the deletion back with the rest of the transaction. Replacing a
//! mapping commits only a `bindings` topic revision (the Elixir code has one
//! notification channel; per-topic revision accounting here is the Rust
//! structuring of that behavior). The database worker is the single writer, so
//! Ecto's `mode: :immediate` serialization is structural here.
use super::super::{Connection, Database, DbResult, Mutation, Request, SchemaMode, StorageError};
use super::domain_tx;
use rusqlite::{params, OptionalExtension, Transaction};
use std::sync::mpsc;
use trenino_core::{EntityId, OperationId};
use unicode_segmentation::UnicodeSegmentation;

/// Revision topic shared by every binding mutation in this module.
const TOPIC: &str = "bindings";

/// Mirrors the Elixir `opts` keyword list of the binding functions:
/// `replace: true` ports `replace?: true`, stealing an input already claimed
/// by a virtual joystick mapping instead of failing with a conflict.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct BindOptions {
    pub replace: bool,
}

/// Button binding mode (`Trenino.Train.ButtonInputBinding` `:mode`).
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ButtonMode {
    Simple,
    Momentary,
    Sequence,
    Keystroke,
}

impl ButtonMode {
    pub fn as_db(self) -> &'static str {
        match self {
            Self::Simple => "simple",
            Self::Momentary => "momentary",
            Self::Sequence => "sequence",
            Self::Keystroke => "keystroke",
        }
    }

    fn parse(value: &str) -> DbResult<Self> {
        match value {
            "simple" => Ok(Self::Simple),
            "momentary" => Ok(Self::Momentary),
            "sequence" => Ok(Self::Sequence),
            "keystroke" => Ok(Self::Keystroke),
            other => Err(corrupt(format!("unknown button binding mode {other:?}"))),
        }
    }
}

/// Physical button hardware type (`:momentum` spring-loaded, `:latching`
/// toggle); `off_sequence_id` is only valid for latching hardware.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ButtonHardwareType {
    Momentary,
    Latching,
}

impl ButtonHardwareType {
    pub fn as_db(self) -> &'static str {
        match self {
            Self::Momentary => "momentary",
            Self::Latching => "latching",
        }
    }

    fn parse(value: &str) -> DbResult<Self> {
        match value {
            "momentary" => Ok(Self::Momentary),
            "latching" => Ok(Self::Latching),
            other => Err(corrupt(format!(
                "unknown button binding hardware_type {other:?}"
            ))),
        }
    }
}

/// Condition operator of an output binding (`Trenino.Train.OutputBinding`).
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum OutputBindingOperator {
    Gt,
    Gte,
    Lt,
    Lte,
    Between,
    EqTrue,
    EqFalse,
}

impl OutputBindingOperator {
    pub fn as_db(self) -> &'static str {
        match self {
            Self::Gt => "gt",
            Self::Gte => "gte",
            Self::Lt => "lt",
            Self::Lte => "lte",
            Self::Between => "between",
            Self::EqTrue => "eq_true",
            Self::EqFalse => "eq_false",
        }
    }

    fn parse(value: &str) -> DbResult<Self> {
        match value {
            "gt" => Ok(Self::Gt),
            "gte" => Ok(Self::Gte),
            "lt" => Ok(Self::Lt),
            "lte" => Ok(Self::Lte),
            "between" => Ok(Self::Between),
            "eq_true" => Ok(Self::EqTrue),
            "eq_false" => Ok(Self::EqFalse),
            other => Err(corrupt(format!(
                "unknown output binding operator {other:?}"
            ))),
        }
    }
}

/// Output binding actuator type; only `led` exists today.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum OutputType {
    Led,
}

impl OutputType {
    pub fn as_db(self) -> &'static str {
        match self {
            Self::Led => "led",
        }
    }

    fn parse(value: &str) -> DbResult<Self> {
        match value {
            "led" => Ok(Self::Led),
            other => Err(corrupt(format!(
                "unknown output binding output_type {other:?}"
            ))),
        }
    }
}

/// A `lever_input_bindings` row (`Trenino.Train.LeverInputBinding`).
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct LeverBindingRecord {
    pub id: EntityId,
    pub lever_config_id: EntityId,
    pub input_id: EntityId,
    pub enabled: bool,
}

/// A `button_input_bindings` row (`Trenino.Train.ButtonInputBinding`).
#[derive(Clone, Debug, PartialEq)]
pub struct ButtonBindingRecord {
    pub id: EntityId,
    pub element_id: EntityId,
    pub input_id: EntityId,
    pub endpoint: Option<String>,
    pub on_value: f64,
    pub off_value: f64,
    pub enabled: bool,
    pub mode: ButtonMode,
    pub hardware_type: ButtonHardwareType,
    pub repeat_interval_ms: i64,
    pub keystroke: Option<String>,
    pub on_sequence_id: Option<EntityId>,
    pub off_sequence_id: Option<EntityId>,
}

/// Attributes for `create_button_binding`; `None` fields take the schema
/// defaults (endpoint `nil`, on/off 1.0/0.0, enabled, simple mode, momentary
/// hardware, 100ms repeat).
#[derive(Clone, Debug, Default, PartialEq)]
pub struct ButtonBindingDraft {
    pub endpoint: Option<String>,
    pub on_value: Option<f64>,
    pub off_value: Option<f64>,
    pub enabled: Option<bool>,
    pub mode: Option<ButtonMode>,
    pub hardware_type: Option<ButtonHardwareType>,
    pub repeat_interval_ms: Option<i64>,
    pub keystroke: Option<String>,
    pub on_sequence_id: Option<EntityId>,
    pub off_sequence_id: Option<EntityId>,
}

/// Partial update for `update_button_binding`; `None` keeps the stored value.
/// `Some(None)` clears the nullable endpoint/keystroke/sequence references,
/// mirroring `Ecto.Changeset.cast/3` of `nil` attributes.
#[derive(Clone, Debug, Default, PartialEq)]
pub struct ButtonBindingPatch {
    pub input_id: Option<EntityId>,
    pub endpoint: Option<Option<String>>,
    pub on_value: Option<f64>,
    pub off_value: Option<f64>,
    pub enabled: Option<bool>,
    pub mode: Option<ButtonMode>,
    pub hardware_type: Option<ButtonHardwareType>,
    pub repeat_interval_ms: Option<i64>,
    pub keystroke: Option<Option<String>>,
    pub on_sequence_id: Option<Option<EntityId>>,
    pub off_sequence_id: Option<Option<EntityId>>,
}

/// A `train_output_bindings` row (`Trenino.Train.OutputBinding`).
#[derive(Clone, Debug, PartialEq)]
pub struct OutputBindingRecord {
    pub id: EntityId,
    pub train_id: EntityId,
    pub name: String,
    pub output_type: OutputType,
    pub output_id: EntityId,
    pub endpoint: String,
    pub operator: OutputBindingOperator,
    pub value_a: Option<f64>,
    pub value_b: Option<f64>,
    pub enabled: bool,
}

/// Attributes for `create_output_binding`; `None` fields take the schema
/// defaults (`led` output type, enabled).
#[derive(Clone, Debug, PartialEq)]
pub struct OutputBindingDraft {
    pub name: String,
    pub output_type: Option<OutputType>,
    pub output_id: EntityId,
    pub endpoint: String,
    pub operator: OutputBindingOperator,
    pub value_a: Option<f64>,
    pub value_b: Option<f64>,
    pub enabled: Option<bool>,
}

/// Partial update for `update_output_binding`; `None` keeps the stored value
/// (`train_id` is immutable, mirroring the context functions).
#[derive(Clone, Debug, Default, PartialEq)]
pub struct OutputBindingPatch {
    pub name: Option<String>,
    pub output_type: Option<OutputType>,
    pub output_id: Option<EntityId>,
    pub endpoint: Option<String>,
    pub operator: Option<OutputBindingOperator>,
    pub value_a: Option<Option<f64>>,
    pub value_b: Option<Option<f64>>,
    pub enabled: Option<bool>,
}

/// A `train_display_bindings` row (`Trenino.Train.DisplayBinding`).
/// `script_id` is a reserved nullable FK (`ON DELETE SET NULL`) that the
/// Elixir changeset never casts; it is read-only here as well.
#[derive(Clone, Debug, PartialEq)]
pub struct DisplayBindingRecord {
    pub id: EntityId,
    pub train_id: EntityId,
    pub i2c_module_id: EntityId,
    pub name: Option<String>,
    pub endpoint: String,
    pub format_string: String,
    pub enabled: bool,
    pub script_id: Option<EntityId>,
}

/// Attributes for `create_display_binding`; a `None` format string takes the
/// `{value}` default and `None` enabled means enabled.
#[derive(Clone, Debug, PartialEq)]
pub struct DisplayBindingDraft {
    pub i2c_module_id: EntityId,
    pub name: Option<String>,
    pub endpoint: String,
    pub format_string: Option<String>,
    pub enabled: Option<bool>,
}

/// Partial update for `update_display_binding`; `None` keeps the stored value
/// (`train_id` and `script_id` are immutable).
#[derive(Clone, Debug, Default, PartialEq)]
pub struct DisplayBindingPatch {
    pub i2c_module_id: Option<EntityId>,
    pub name: Option<Option<String>>,
    pub endpoint: Option<String>,
    pub format_string: Option<String>,
    pub enabled: Option<bool>,
}

impl Database {
    /// Dispatch helper mirroring `hardware_call`: binding operations run on
    /// the shared bounded worker and require the full schema.
    fn bindings_call<T: Send + 'static>(
        &self,
        operation: &'static str,
        f: impl FnOnce(&mut Connection) -> DbResult<T> + Send + 'static,
    ) -> DbResult<T> {
        let (reply_tx, reply_rx) = mpsc::channel();
        let job = Box::new(move |connection: &mut Connection, mode: SchemaMode| {
            let result = if mode == SchemaMode::Full {
                f(connection)
            } else {
                Err(StorageError::UnsupportedOperation { operation })
            };
            let _ = reply_tx.send(result);
        });
        self.worker
            .tx
            .lock()
            .map_err(|_| StorageError::WorkerStopped)?
            .as_ref()
            .ok_or(StorageError::WorkerStopped)?
            .send(Request::Hardware(job))
            .map_err(|_| StorageError::WorkerStopped)?;
        reply_rx.recv().map_err(|_| StorageError::WorkerStopped)?
    }

    /// `Trenino.Train.get_binding/1`: the one binding of a lever config.
    pub fn get_lever_binding(
        &self,
        lever_config_id: EntityId,
    ) -> DbResult<Option<LeverBindingRecord>> {
        self.bindings_call("get_lever_binding", move |c| {
            lever_binding_row(c, lever_config_id)
        })
    }

    /// `Trenino.Train.bind_input/2`.
    pub fn bind_lever_input(
        &self,
        operation_id: OperationId,
        lever_config_id: EntityId,
        input_id: EntityId,
    ) -> DbResult<Mutation<LeverBindingRecord>> {
        self.bind_lever_input_with(
            operation_id,
            lever_config_id,
            input_id,
            BindOptions::default(),
        )
    }

    /// `Trenino.Train.bind_input/3`: creates the binding or rebinds the lever
    /// config to a new input (enabled state is preserved).
    pub fn bind_lever_input_with(
        &self,
        operation_id: OperationId,
        lever_config_id: EntityId,
        input_id: EntityId,
        opts: BindOptions,
    ) -> DbResult<Mutation<LeverBindingRecord>> {
        self.bindings_call("bind_lever_input", move |c| {
            domain_tx(c, TOPIC, operation_id, move |tx| {
                bind_lever_input_tx(tx, lever_config_id, input_id, opts)
            })
        })
    }

    /// `Trenino.Train.unbind_input/1`: deletes the binding (`:not_found` when
    /// the lever config has none).
    pub fn unbind_lever_input(
        &self,
        operation_id: OperationId,
        lever_config_id: EntityId,
    ) -> DbResult<Mutation<LeverBindingRecord>> {
        self.bindings_call("unbind_lever_input", move |c| {
            domain_tx(c, TOPIC, operation_id, move |tx| {
                let record =
                    lever_binding_row(tx, lever_config_id)?.ok_or(StorageError::NotFound)?;
                tx.execute(
                    "DELETE FROM lever_input_bindings WHERE id=?1",
                    [record.id.0],
                )?;
                Ok(record)
            })
        })
    }

    /// `Trenino.Train.set_binding_enabled/2`.
    pub fn set_lever_binding_enabled(
        &self,
        operation_id: OperationId,
        lever_config_id: EntityId,
        enabled: bool,
    ) -> DbResult<Mutation<LeverBindingRecord>> {
        self.set_lever_binding_enabled_with(
            operation_id,
            lever_config_id,
            enabled,
            BindOptions::default(),
        )
    }

    /// `Trenino.Train.set_binding_enabled/3`: enabling a binding whose input
    /// is claimed by vJoy requires `replace`.
    pub fn set_lever_binding_enabled_with(
        &self,
        operation_id: OperationId,
        lever_config_id: EntityId,
        enabled: bool,
        opts: BindOptions,
    ) -> DbResult<Mutation<LeverBindingRecord>> {
        self.bindings_call("set_lever_binding_enabled", move |c| {
            domain_tx(c, TOPIC, operation_id, move |tx| {
                let current =
                    lever_binding_row(tx, lever_config_id)?.ok_or(StorageError::NotFound)?;
                apply_destination_exclusivity(tx, current.input_id, enabled, opts.replace)?;
                tx.execute(
                    "UPDATE lever_input_bindings SET enabled=?1,updated_at=?2 WHERE id=?3",
                    params![enabled as i64, timestamp(), current.id.0],
                )?;
                lever_binding_row(tx, lever_config_id)?.ok_or(StorageError::NotFound)
            })
        })
    }

    /// `Trenino.Train.list_bindings_for_train/1`: bindings whose lever config
    /// belongs to an element of the train.
    pub fn list_lever_bindings_for_train(
        &self,
        train_id: EntityId,
    ) -> DbResult<Vec<LeverBindingRecord>> {
        self.bindings_call("list_lever_bindings_for_train", move |c| {
            let mut statement = c.prepare(
                "SELECT b.id,b.lever_config_id,b.input_id,b.enabled
                 FROM lever_input_bindings b
                 JOIN train_lever_configs lc ON b.lever_config_id=lc.id
                 JOIN train_elements e ON lc.element_id=e.id
                 WHERE e.train_id=?1",
            )?;
            let rows = statement
                .query_map([train_id.0], |r| {
                    Ok(LeverBindingRecord {
                        id: EntityId(r.get(0)?),
                        lever_config_id: EntityId(r.get(1)?),
                        input_id: EntityId(r.get(2)?),
                        enabled: r.get::<_, i64>(3)? != 0,
                    })
                })?
                .collect::<Result<Vec<_>, _>>()?;
            Ok(rows)
        })
    }

    /// `Trenino.Train.get_button_binding/1`: the one binding of an element.
    pub fn get_button_binding(
        &self,
        element_id: EntityId,
    ) -> DbResult<Option<ButtonBindingRecord>> {
        self.bindings_call("get_button_binding", move |c| {
            button_binding_row_by_element(c, element_id)
        })
    }

    /// `Trenino.Train.create_button_binding/3`.
    pub fn create_button_binding(
        &self,
        operation_id: OperationId,
        element_id: EntityId,
        input_id: EntityId,
        draft: ButtonBindingDraft,
    ) -> DbResult<Mutation<ButtonBindingRecord>> {
        self.create_button_binding_with(
            operation_id,
            element_id,
            input_id,
            draft,
            BindOptions::default(),
        )
    }

    /// `Trenino.Train.create_button_binding/4`: creating an enabled binding
    /// for a vJoy-mapped input requires `replace`.
    pub fn create_button_binding_with(
        &self,
        operation_id: OperationId,
        element_id: EntityId,
        input_id: EntityId,
        draft: ButtonBindingDraft,
        opts: BindOptions,
    ) -> DbResult<Mutation<ButtonBindingRecord>> {
        self.bindings_call("create_button_binding", move |c| {
            domain_tx(c, TOPIC, operation_id, move |tx| {
                let record = button_record_from_draft(element_id, input_id, &draft)?;
                validate_button_binding(&record)?;
                apply_destination_exclusivity(tx, record.input_id, record.enabled, opts.replace)?;
                insert_button_binding(tx, &record)?;
                let binding_id = EntityId(tx.last_insert_rowid());
                button_binding_row_by_id(tx, binding_id)?.ok_or(StorageError::NotFound)
            })
        })
    }

    /// `Trenino.Train.update_button_binding/2`.
    pub fn update_button_binding(
        &self,
        operation_id: OperationId,
        binding_id: EntityId,
        patch: ButtonBindingPatch,
    ) -> DbResult<Mutation<ButtonBindingRecord>> {
        self.update_button_binding_with(operation_id, binding_id, patch, BindOptions::default())
    }

    /// `Trenino.Train.update_button_binding/3`: rebinding to a vJoy-mapped
    /// input requires `replace`.
    pub fn update_button_binding_with(
        &self,
        operation_id: OperationId,
        binding_id: EntityId,
        patch: ButtonBindingPatch,
        opts: BindOptions,
    ) -> DbResult<Mutation<ButtonBindingRecord>> {
        self.bindings_call("update_button_binding", move |c| {
            domain_tx(c, TOPIC, operation_id, move |tx| {
                let current =
                    button_binding_row_by_id(tx, binding_id)?.ok_or(StorageError::NotFound)?;
                let record = merge_button_patch(current, &patch)?;
                validate_button_binding(&record)?;
                apply_destination_exclusivity(tx, record.input_id, record.enabled, opts.replace)?;
                update_button_binding_row(tx, &record)?;
                button_binding_row_by_id(tx, binding_id)?.ok_or(StorageError::NotFound)
            })
        })
    }

    /// `Trenino.Train.delete_button_binding/1`: deletes by element ID.
    pub fn delete_button_binding(
        &self,
        operation_id: OperationId,
        element_id: EntityId,
    ) -> DbResult<Mutation<ButtonBindingRecord>> {
        self.bindings_call("delete_button_binding", move |c| {
            domain_tx(c, TOPIC, operation_id, move |tx| {
                let record =
                    button_binding_row_by_element(tx, element_id)?.ok_or(StorageError::NotFound)?;
                tx.execute(
                    "DELETE FROM button_input_bindings WHERE id=?1",
                    [record.id.0],
                )?;
                Ok(record)
            })
        })
    }

    /// `Trenino.Train.set_button_binding_enabled/2`.
    pub fn set_button_binding_enabled(
        &self,
        operation_id: OperationId,
        element_id: EntityId,
        enabled: bool,
    ) -> DbResult<Mutation<ButtonBindingRecord>> {
        self.set_button_binding_enabled_with(
            operation_id,
            element_id,
            enabled,
            BindOptions::default(),
        )
    }

    /// `Trenino.Train.set_button_binding_enabled/3`: enabling a binding whose
    /// input is claimed by vJoy requires `replace`.
    pub fn set_button_binding_enabled_with(
        &self,
        operation_id: OperationId,
        element_id: EntityId,
        enabled: bool,
        opts: BindOptions,
    ) -> DbResult<Mutation<ButtonBindingRecord>> {
        self.bindings_call("set_button_binding_enabled", move |c| {
            domain_tx(c, TOPIC, operation_id, move |tx| {
                let current =
                    button_binding_row_by_element(tx, element_id)?.ok_or(StorageError::NotFound)?;
                let mut record = current;
                record.enabled = enabled;
                validate_button_binding(&record)?;
                apply_destination_exclusivity(tx, record.input_id, record.enabled, opts.replace)?;
                update_button_binding_row(tx, &record)?;
                button_binding_row_by_element(tx, element_id)?.ok_or(StorageError::NotFound)
            })
        })
    }

    /// `Trenino.Train.list_button_bindings_for_train/1`.
    pub fn list_button_bindings_for_train(
        &self,
        train_id: EntityId,
    ) -> DbResult<Vec<ButtonBindingRecord>> {
        self.bindings_call("list_button_bindings_for_train", move |c| {
            let mut statement = c.prepare(
                "SELECT b.id,b.element_id,b.input_id,b.endpoint,b.on_value,b.off_value,b.enabled,b.mode,b.hardware_type,b.repeat_interval_ms,b.keystroke,b.on_sequence_id,b.off_sequence_id
                 FROM button_input_bindings b
                 JOIN train_elements e ON b.element_id=e.id
                 WHERE e.train_id=?1",
            )?;
            let raw = statement
                .query_map([train_id.0], button_binding_raw_row)?
                .collect::<Result<Vec<_>, _>>()?;
            raw.into_iter().map(button_binding_parse).collect()
        })
    }

    /// `Trenino.Train.list_output_bindings/1`, ordered by name.
    pub fn list_output_bindings(&self, train_id: EntityId) -> DbResult<Vec<OutputBindingRecord>> {
        self.output_bindings_where(train_id, "ORDER BY name", false)
    }

    /// `Trenino.Train.list_enabled_output_bindings/1` (no ordering, mirroring
    /// the Elixir query).
    pub fn list_enabled_output_bindings(
        &self,
        train_id: EntityId,
    ) -> DbResult<Vec<OutputBindingRecord>> {
        self.output_bindings_where(train_id, "", true)
    }

    fn output_bindings_where(
        &self,
        train_id: EntityId,
        order: &'static str,
        enabled_only: bool,
    ) -> DbResult<Vec<OutputBindingRecord>> {
        self.bindings_call("list_output_bindings", move |c| {
            let sql = format!(
                "SELECT id,train_id,name,output_type,output_id,endpoint,operator,value_a,value_b,enabled
                 FROM train_output_bindings WHERE train_id=?1{} {order}",
                if enabled_only { " AND enabled=1" } else { "" }
            );
            let mut statement = c.prepare(&sql)?;
            let raw = statement
                .query_map([train_id.0], output_binding_raw_row)?
                .collect::<Result<Vec<_>, _>>()?;
            raw.into_iter().map(output_binding_parse).collect()
        })
    }

    /// `Trenino.Train.get_output_binding/1`.
    pub fn get_output_binding(
        &self,
        binding_id: EntityId,
    ) -> DbResult<Option<OutputBindingRecord>> {
        self.bindings_call("get_output_binding", move |c| {
            output_binding_row(c, binding_id)
        })
    }

    /// `Trenino.Train.create_output_binding/2`.
    pub fn create_output_binding(
        &self,
        operation_id: OperationId,
        train_id: EntityId,
        draft: OutputBindingDraft,
    ) -> DbResult<Mutation<OutputBindingRecord>> {
        self.bindings_call("create_output_binding", move |c| {
            domain_tx(c, TOPIC, operation_id, move |tx| {
                let record = OutputBindingRecord {
                    id: EntityId(0),
                    train_id,
                    name: draft.name,
                    output_type: draft.output_type.unwrap_or(OutputType::Led),
                    output_id: draft.output_id,
                    endpoint: draft.endpoint,
                    operator: draft.operator,
                    value_a: match draft.value_a {
                        Some(value) => Some(round2(value)?),
                        None => None,
                    },
                    value_b: match draft.value_b {
                        Some(value) => Some(round2(value)?),
                        None => None,
                    },
                    enabled: draft.enabled.unwrap_or(true),
                };
                validate_output_binding(&record)?;
                insert_output_binding(tx, &record)?;
                let binding_id = EntityId(tx.last_insert_rowid());
                output_binding_row(tx, binding_id)?.ok_or(StorageError::NotFound)
            })
        })
    }

    /// `Trenino.Train.update_output_binding/2`.
    pub fn update_output_binding(
        &self,
        operation_id: OperationId,
        binding_id: EntityId,
        patch: OutputBindingPatch,
    ) -> DbResult<Mutation<OutputBindingRecord>> {
        self.bindings_call("update_output_binding", move |c| {
            domain_tx(c, TOPIC, operation_id, move |tx| {
                let current = output_binding_row(tx, binding_id)?.ok_or(StorageError::NotFound)?;
                let record = OutputBindingRecord {
                    id: current.id,
                    train_id: current.train_id,
                    name: patch.name.unwrap_or(current.name),
                    output_type: patch.output_type.unwrap_or(current.output_type),
                    output_id: patch.output_id.unwrap_or(current.output_id),
                    endpoint: patch.endpoint.unwrap_or(current.endpoint),
                    operator: patch.operator.unwrap_or(current.operator),
                    value_a: match patch.value_a {
                        Some(Some(value)) => Some(round2(value)?),
                        Some(None) => None,
                        None => current.value_a,
                    },
                    value_b: match patch.value_b {
                        Some(Some(value)) => Some(round2(value)?),
                        Some(None) => None,
                        None => current.value_b,
                    },
                    enabled: patch.enabled.unwrap_or(current.enabled),
                };
                validate_output_binding(&record)?;
                update_output_binding_row(tx, &record)?;
                output_binding_row(tx, binding_id)?.ok_or(StorageError::NotFound)
            })
        })
    }

    /// `Trenino.Train.delete_output_binding/1`.
    pub fn delete_output_binding(
        &self,
        operation_id: OperationId,
        binding_id: EntityId,
    ) -> DbResult<Mutation<OutputBindingRecord>> {
        self.bindings_call("delete_output_binding", move |c| {
            domain_tx(c, TOPIC, operation_id, move |tx| {
                let record = output_binding_row(tx, binding_id)?.ok_or(StorageError::NotFound)?;
                tx.execute(
                    "DELETE FROM train_output_bindings WHERE id=?1",
                    [record.id.0],
                )?;
                Ok(record)
            })
        })
    }

    /// `Trenino.Train.list_display_bindings/1`, ordered by name.
    pub fn list_display_bindings(&self, train_id: EntityId) -> DbResult<Vec<DisplayBindingRecord>> {
        self.display_bindings_where(train_id, "ORDER BY name", false)
    }

    /// `Trenino.Train.list_enabled_display_bindings/1`, ordered by name.
    pub fn list_enabled_display_bindings(
        &self,
        train_id: EntityId,
    ) -> DbResult<Vec<DisplayBindingRecord>> {
        self.display_bindings_where(train_id, "ORDER BY name", true)
    }

    fn display_bindings_where(
        &self,
        train_id: EntityId,
        order: &'static str,
        enabled_only: bool,
    ) -> DbResult<Vec<DisplayBindingRecord>> {
        self.bindings_call("list_display_bindings", move |c| {
            let sql = format!(
                "SELECT id,train_id,i2c_module_id,name,endpoint,format_string,enabled,script_id
                 FROM train_display_bindings WHERE train_id=?1{} {order}",
                if enabled_only { " AND enabled=1" } else { "" }
            );
            let mut statement = c.prepare(&sql)?;
            let raw = statement
                .query_map([train_id.0], display_binding_raw_row)?
                .collect::<Result<Vec<_>, _>>()?;
            raw.into_iter().map(display_binding_parse).collect()
        })
    }

    /// `Trenino.Train.get_display_binding/1`.
    pub fn get_display_binding(
        &self,
        binding_id: EntityId,
    ) -> DbResult<Option<DisplayBindingRecord>> {
        self.bindings_call("get_display_binding", move |c| {
            display_binding_row(c, binding_id)
        })
    }

    /// `Trenino.Train.create_display_binding/2`.
    pub fn create_display_binding(
        &self,
        operation_id: OperationId,
        train_id: EntityId,
        draft: DisplayBindingDraft,
    ) -> DbResult<Mutation<DisplayBindingRecord>> {
        self.bindings_call("create_display_binding", move |c| {
            domain_tx(c, TOPIC, operation_id, move |tx| {
                let record = DisplayBindingRecord {
                    id: EntityId(0),
                    train_id,
                    i2c_module_id: draft.i2c_module_id,
                    name: draft.name,
                    endpoint: draft.endpoint,
                    format_string: draft.format_string.unwrap_or_else(|| "{value}".into()),
                    enabled: draft.enabled.unwrap_or(true),
                    script_id: None,
                };
                validate_display_binding(&record)?;
                insert_display_binding(tx, &record)?;
                let binding_id = EntityId(tx.last_insert_rowid());
                display_binding_row(tx, binding_id)?.ok_or(StorageError::NotFound)
            })
        })
    }

    /// `Trenino.Train.update_display_binding/2`.
    pub fn update_display_binding(
        &self,
        operation_id: OperationId,
        binding_id: EntityId,
        patch: DisplayBindingPatch,
    ) -> DbResult<Mutation<DisplayBindingRecord>> {
        self.bindings_call("update_display_binding", move |c| {
            domain_tx(c, TOPIC, operation_id, move |tx| {
                let current = display_binding_row(tx, binding_id)?.ok_or(StorageError::NotFound)?;
                let record = DisplayBindingRecord {
                    id: current.id,
                    train_id: current.train_id,
                    i2c_module_id: patch.i2c_module_id.unwrap_or(current.i2c_module_id),
                    name: patch.name.unwrap_or(current.name),
                    endpoint: patch.endpoint.unwrap_or(current.endpoint),
                    format_string: patch.format_string.unwrap_or(current.format_string),
                    enabled: patch.enabled.unwrap_or(current.enabled),
                    script_id: current.script_id,
                };
                validate_display_binding(&record)?;
                update_display_binding_row(tx, &record)?;
                display_binding_row(tx, binding_id)?.ok_or(StorageError::NotFound)
            })
        })
    }

    /// `Trenino.Train.delete_display_binding/1`.
    pub fn delete_display_binding(
        &self,
        operation_id: OperationId,
        binding_id: EntityId,
    ) -> DbResult<Mutation<DisplayBindingRecord>> {
        self.bindings_call("delete_display_binding", move |c| {
            domain_tx(c, TOPIC, operation_id, move |tx| {
                let record = display_binding_row(tx, binding_id)?.ok_or(StorageError::NotFound)?;
                tx.execute(
                    "DELETE FROM train_display_bindings WHERE id=?1",
                    [record.id.0],
                )?;
                Ok(record)
            })
        })
    }
}

// =====================
// Destination exclusivity (vJoy cross-family rule)
// =====================

/// Ports the `save_binding`/`persist_binding` transaction core: when the
/// resulting binding is enabled, an input claimed by a `virtual_joystick_mappings`
/// row conflicts unless `replace` deletes the mapping first. The deletion
/// rolls back with the transaction when the subsequent write fails, mirroring
/// `Repo.rollback` in `maybe_replace_virtual_joystick_mapping/2`.
fn apply_destination_exclusivity(
    tx: &Transaction<'_>,
    input_id: EntityId,
    enabled: bool,
    replace: bool,
) -> DbResult<()> {
    if !enabled {
        return Ok(());
    }
    let claimed: Option<i64> = tx
        .query_row(
            "SELECT id FROM virtual_joystick_mappings WHERE input_id=?1 LIMIT 1",
            [input_id.0],
            |row| row.get(0),
        )
        .optional()?;
    match claimed {
        Some(mapping_id) if replace => {
            tx.execute(
                "DELETE FROM virtual_joystick_mappings WHERE id=?1",
                [mapping_id],
            )?;
            Ok(())
        }
        Some(_) => Err(StorageError::Conflict {
            detail:
                "destination conflict: input is already mapped to a virtual joystick destination"
                    .into(),
        }),
        None => Ok(()),
    }
}

// =====================
// Button binding helpers
// =====================

fn button_record_from_draft(
    element_id: EntityId,
    input_id: EntityId,
    draft: &ButtonBindingDraft,
) -> DbResult<ButtonBindingRecord> {
    Ok(ButtonBindingRecord {
        id: EntityId(0),
        element_id,
        input_id,
        endpoint: draft.endpoint.clone(),
        on_value: match draft.on_value {
            Some(value) => round2(value)?,
            None => 1.0,
        },
        off_value: match draft.off_value {
            Some(value) => round2(value)?,
            None => 0.0,
        },
        enabled: draft.enabled.unwrap_or(true),
        mode: draft.mode.unwrap_or(ButtonMode::Simple),
        hardware_type: draft.hardware_type.unwrap_or(ButtonHardwareType::Momentary),
        repeat_interval_ms: draft.repeat_interval_ms.unwrap_or(100),
        keystroke: draft.keystroke.clone(),
        on_sequence_id: draft.on_sequence_id,
        off_sequence_id: draft.off_sequence_id,
    })
}

fn merge_button_patch(
    current: ButtonBindingRecord,
    patch: &ButtonBindingPatch,
) -> DbResult<ButtonBindingRecord> {
    Ok(ButtonBindingRecord {
        id: current.id,
        element_id: current.element_id,
        input_id: patch.input_id.unwrap_or(current.input_id),
        endpoint: patch.endpoint.clone().unwrap_or(current.endpoint),
        on_value: match patch.on_value {
            Some(value) => round2(value)?,
            None => current.on_value,
        },
        off_value: match patch.off_value {
            Some(value) => round2(value)?,
            None => current.off_value,
        },
        enabled: patch.enabled.unwrap_or(current.enabled),
        mode: patch.mode.unwrap_or(current.mode),
        hardware_type: patch.hardware_type.unwrap_or(current.hardware_type),
        repeat_interval_ms: patch
            .repeat_interval_ms
            .unwrap_or(current.repeat_interval_ms),
        keystroke: patch.keystroke.clone().unwrap_or(current.keystroke),
        on_sequence_id: patch.on_sequence_id.unwrap_or(current.on_sequence_id),
        off_sequence_id: patch.off_sequence_id.unwrap_or(current.off_sequence_id),
    })
}

/// Ports `ButtonInputBinding.changeset/2` validation (mode requirements,
/// sequence rules, repeat interval bounds) evaluated against the effective
/// record, exactly like `Ecto.Changeset.get_field/2` semantics.
fn validate_button_binding(record: &ButtonBindingRecord) -> DbResult<()> {
    match record.mode {
        ButtonMode::Simple | ButtonMode::Momentary => {
            if is_blank(record.endpoint.as_deref()) {
                return Err(invalid("endpoint can't be blank"));
            }
        }
        ButtonMode::Sequence => {
            if record.on_sequence_id.is_none() && record.off_sequence_id.is_none() {
                return Err(invalid("on_sequence_id at least one sequence is required"));
            }
        }
        ButtonMode::Keystroke => {
            if is_blank(record.keystroke.as_deref()) {
                return Err(invalid("keystroke can't be blank"));
            }
        }
    }
    if record.mode != ButtonMode::Sequence && record.off_sequence_id.is_some() {
        return Err(invalid("off_sequence_id is only valid in sequence mode"));
    }
    if record.mode == ButtonMode::Sequence
        && record.hardware_type == ButtonHardwareType::Momentary
        && record.off_sequence_id.is_some()
    {
        return Err(invalid(
            "off_sequence_id is only valid for latching hardware",
        ));
    }
    if record.repeat_interval_ms <= 0 {
        return Err(invalid("repeat_interval_ms must be greater than 0"));
    }
    if record.repeat_interval_ms > 5000 {
        return Err(invalid(
            "repeat_interval_ms must be less than or equal to 5000",
        ));
    }
    Ok(())
}

type ButtonBindingRaw = (
    i64,
    i64,
    i64,
    Option<String>,
    f64,
    f64,
    i64,
    String,
    String,
    i64,
    Option<String>,
    Option<i64>,
    Option<i64>,
);

fn button_binding_raw_row(r: &rusqlite::Row<'_>) -> rusqlite::Result<ButtonBindingRaw> {
    Ok((
        r.get(0)?,
        r.get(1)?,
        r.get(2)?,
        r.get(3)?,
        r.get(4)?,
        r.get(5)?,
        r.get(6)?,
        r.get(7)?,
        r.get(8)?,
        r.get(9)?,
        r.get(10)?,
        r.get(11)?,
        r.get(12)?,
    ))
}

fn button_binding_parse(raw: ButtonBindingRaw) -> DbResult<ButtonBindingRecord> {
    Ok(ButtonBindingRecord {
        id: EntityId(raw.0),
        element_id: EntityId(raw.1),
        input_id: EntityId(raw.2),
        endpoint: raw.3,
        on_value: raw.4,
        off_value: raw.5,
        enabled: raw.6 != 0,
        mode: ButtonMode::parse(&raw.7)?,
        hardware_type: ButtonHardwareType::parse(&raw.8)?,
        repeat_interval_ms: raw.9,
        keystroke: raw.10,
        on_sequence_id: raw.11.map(EntityId),
        off_sequence_id: raw.12.map(EntityId),
    })
}

const BUTTON_BINDING_COLUMNS: &str = "id,element_id,input_id,endpoint,on_value,off_value,enabled,mode,hardware_type,repeat_interval_ms,keystroke,on_sequence_id,off_sequence_id";

fn button_binding_row_by_id(c: &Connection, id: EntityId) -> DbResult<Option<ButtonBindingRecord>> {
    let sql = format!("SELECT {BUTTON_BINDING_COLUMNS} FROM button_input_bindings WHERE id=?1");
    let raw = c
        .query_row(&sql, [id.0], button_binding_raw_row)
        .optional()?;
    raw.map(button_binding_parse).transpose()
}

fn button_binding_row_by_element(
    c: &Connection,
    element_id: EntityId,
) -> DbResult<Option<ButtonBindingRecord>> {
    let sql =
        format!("SELECT {BUTTON_BINDING_COLUMNS} FROM button_input_bindings WHERE element_id=?1");
    let raw = c
        .query_row(&sql, [element_id.0], button_binding_raw_row)
        .optional()?;
    raw.map(button_binding_parse).transpose()
}

fn insert_button_binding(tx: &Transaction<'_>, record: &ButtonBindingRecord) -> DbResult<()> {
    let now = timestamp();
    tx.execute(
        "INSERT INTO button_input_bindings(input_id,element_id,endpoint,on_value,off_value,enabled,mode,hardware_type,repeat_interval_ms,keystroke,on_sequence_id,off_sequence_id,inserted_at,updated_at)
         VALUES(?1,?2,?3,?4,?5,?6,?7,?8,?9,?10,?11,?12,?13,?13)",
        params![
            record.input_id.0,
            record.element_id.0,
            record.endpoint,
            record.on_value,
            record.off_value,
            record.enabled as i64,
            record.mode.as_db(),
            record.hardware_type.as_db(),
            record.repeat_interval_ms,
            record.keystroke,
            record.on_sequence_id.map(|id| id.0),
            record.off_sequence_id.map(|id| id.0),
            now
        ],
    )?;
    Ok(())
}

fn update_button_binding_row(tx: &Transaction<'_>, record: &ButtonBindingRecord) -> DbResult<()> {
    tx.execute(
        "UPDATE button_input_bindings SET input_id=?1,endpoint=?2,on_value=?3,off_value=?4,enabled=?5,mode=?6,hardware_type=?7,repeat_interval_ms=?8,keystroke=?9,on_sequence_id=?10,off_sequence_id=?11,updated_at=?12 WHERE id=?13",
        params![
            record.input_id.0,
            record.endpoint,
            record.on_value,
            record.off_value,
            record.enabled as i64,
            record.mode.as_db(),
            record.hardware_type.as_db(),
            record.repeat_interval_ms,
            record.keystroke,
            record.on_sequence_id.map(|id| id.0),
            record.off_sequence_id.map(|id| id.0),
            timestamp(),
            record.id.0
        ],
    )?;
    Ok(())
}

// =====================
// Lever binding helpers
// =====================

fn lever_binding_row(
    c: &Connection,
    lever_config_id: EntityId,
) -> DbResult<Option<LeverBindingRecord>> {
    c.query_row(
        "SELECT id,lever_config_id,input_id,enabled FROM lever_input_bindings WHERE lever_config_id=?1",
        [lever_config_id.0],
        |r| {
            Ok(LeverBindingRecord {
                id: EntityId(r.get(0)?),
                lever_config_id: EntityId(r.get(1)?),
                input_id: EntityId(r.get(2)?),
                enabled: r.get::<_, i64>(3)? != 0,
            })
        },
    )
    .optional()
    .map_err(StorageError::from)
}

// =====================
// Output binding helpers
// =====================

/// Ports `OutputBinding.changeset/2` validation: required name/endpoint,
/// `value_a` for numeric operators, `value_b` for `between`.
fn validate_output_binding(record: &OutputBindingRecord) -> DbResult<()> {
    if record.name.trim().is_empty() {
        return Err(invalid("name can't be blank"));
    }
    if record.endpoint.trim().is_empty() {
        return Err(invalid("endpoint can't be blank"));
    }
    validate_output_condition(record.operator, record.value_a, record.value_b).map_err(invalid)
}

/// Shared numeric-condition check for committed bindings and read-only UI
/// previews. This is the same required-field rule as the Ecto changeset.
pub fn validate_output_condition(
    operator: OutputBindingOperator,
    value_a: Option<f64>,
    value_b: Option<f64>,
) -> Result<(), &'static str> {
    if value_a.is_some_and(|value| !value.is_finite())
        || value_b.is_some_and(|value| !value.is_finite())
    {
        return Err("value must be a finite number");
    }
    if !matches!(
        operator,
        OutputBindingOperator::EqTrue | OutputBindingOperator::EqFalse
    ) && value_a.is_none()
    {
        return Err("value_a can't be blank");
    }
    if operator == OutputBindingOperator::Between && value_b.is_none() {
        return Err("value_b can't be blank");
    }
    Ok(())
}

type OutputBindingRaw = (
    i64,
    i64,
    String,
    String,
    i64,
    String,
    String,
    Option<f64>,
    Option<f64>,
    i64,
);

fn output_binding_raw_row(r: &rusqlite::Row<'_>) -> rusqlite::Result<OutputBindingRaw> {
    Ok((
        r.get(0)?,
        r.get(1)?,
        r.get(2)?,
        r.get(3)?,
        r.get(4)?,
        r.get(5)?,
        r.get(6)?,
        r.get(7)?,
        r.get(8)?,
        r.get(9)?,
    ))
}

fn output_binding_parse(raw: OutputBindingRaw) -> DbResult<OutputBindingRecord> {
    Ok(OutputBindingRecord {
        id: EntityId(raw.0),
        train_id: EntityId(raw.1),
        name: raw.2,
        output_type: OutputType::parse(&raw.3)?,
        output_id: EntityId(raw.4),
        endpoint: raw.5,
        operator: OutputBindingOperator::parse(&raw.6)?,
        value_a: raw.7,
        value_b: raw.8,
        enabled: raw.9 != 0,
    })
}

fn output_binding_row(c: &Connection, id: EntityId) -> DbResult<Option<OutputBindingRecord>> {
    let raw = c
        .query_row(
            "SELECT id,train_id,name,output_type,output_id,endpoint,operator,value_a,value_b,enabled FROM train_output_bindings WHERE id=?1",
            [id.0],
            output_binding_raw_row,
        )
        .optional()?;
    raw.map(output_binding_parse).transpose()
}

fn insert_output_binding(tx: &Transaction<'_>, record: &OutputBindingRecord) -> DbResult<()> {
    let now = timestamp();
    tx.execute(
        "INSERT INTO train_output_bindings(train_id,name,output_type,output_id,endpoint,operator,value_a,value_b,enabled,inserted_at,updated_at)
         VALUES(?1,?2,?3,?4,?5,?6,?7,?8,?9,?10,?10)",
        params![
            record.train_id.0,
            record.name,
            record.output_type.as_db(),
            record.output_id.0,
            record.endpoint,
            record.operator.as_db(),
            record.value_a,
            record.value_b,
            record.enabled as i64,
            now
        ],
    )?;
    Ok(())
}

fn update_output_binding_row(tx: &Transaction<'_>, record: &OutputBindingRecord) -> DbResult<()> {
    tx.execute(
        "UPDATE train_output_bindings SET name=?1,output_type=?2,output_id=?3,endpoint=?4,operator=?5,value_a=?6,value_b=?7,enabled=?8,updated_at=?9 WHERE id=?10",
        params![
            record.name,
            record.output_type.as_db(),
            record.output_id.0,
            record.endpoint,
            record.operator.as_db(),
            record.value_a,
            record.value_b,
            record.enabled as i64,
            timestamp(),
            record.id.0
        ],
    )?;
    Ok(())
}

// =====================
// Display binding helpers
// =====================

/// Ports `DisplayBinding.changeset/2` validation: required endpoint and format
/// string, name ≤ 100 characters, format string ≤ 200 characters and only
/// `{value}` / `{value:.Nf}` tokens with precision 0–10.
fn validate_display_binding(record: &DisplayBindingRecord) -> DbResult<()> {
    if record.endpoint.trim().is_empty() {
        return Err(invalid("endpoint can't be blank"));
    }
    if record.format_string.trim().is_empty() {
        return Err(invalid("format_string can't be blank"));
    }
    // Ecto validate_length counts graphemes (String.length/1), like
    // core/train/display.rs — a combining-mark name of two codepoints is a
    // single character.
    if record
        .name
        .as_ref()
        .is_some_and(|n| n.graphemes(true).count() > 100)
    {
        return Err(invalid("name should be at most 100 characters"));
    }
    if record.format_string.graphemes(true).count() > 200 {
        return Err(invalid("format_string should be at most 200 characters"));
    }
    if let Err(message) = validate_display_format(&record.format_string) {
        return Err(invalid(format!("format_string {message}")));
    }
    Ok(())
}

/// Ports `Trenino.Train.DisplayFormatter.validate_format/1`: every `{value…}`
/// occurrence must be `{value}` or `{value:.Nf}` with N in 0–10.
fn validate_display_format(format: &str) -> Result<(), &'static str> {
    const MESSAGE: &str = "Use {value} or {value:.Nf}, with precision from 0 to 10";
    let mut rest = format;
    while let Some(position) = rest.find("{value") {
        let tail = &rest[position + "{value".len()..];
        rest = if let Some(stripped) = tail.strip_prefix('}') {
            stripped
        } else if let Some(digits) = tail.strip_prefix(":.") {
            let bytes = digits.as_bytes();
            let token_len = if bytes.first().is_some_and(u8::is_ascii_digit)
                && bytes.get(1) == Some(&b'f')
                && bytes.get(2) == Some(&b'}')
            {
                3
            } else if bytes.starts_with(b"10f}") {
                4
            } else {
                return Err(MESSAGE);
            };
            &digits[token_len..]
        } else {
            return Err(MESSAGE);
        };
    }
    Ok(())
}

type DisplayBindingRaw = (
    i64,
    i64,
    i64,
    Option<String>,
    String,
    String,
    i64,
    Option<i64>,
);

fn display_binding_raw_row(r: &rusqlite::Row<'_>) -> rusqlite::Result<DisplayBindingRaw> {
    Ok((
        r.get(0)?,
        r.get(1)?,
        r.get(2)?,
        r.get(3)?,
        r.get(4)?,
        r.get(5)?,
        r.get(6)?,
        r.get(7)?,
    ))
}

fn display_binding_parse(raw: DisplayBindingRaw) -> DbResult<DisplayBindingRecord> {
    Ok(DisplayBindingRecord {
        id: EntityId(raw.0),
        train_id: EntityId(raw.1),
        i2c_module_id: EntityId(raw.2),
        name: raw.3,
        endpoint: raw.4,
        format_string: raw.5,
        enabled: raw.6 != 0,
        script_id: raw.7.map(EntityId),
    })
}

fn display_binding_row(c: &Connection, id: EntityId) -> DbResult<Option<DisplayBindingRecord>> {
    let raw = c
        .query_row(
            "SELECT id,train_id,i2c_module_id,name,endpoint,format_string,enabled,script_id FROM train_display_bindings WHERE id=?1",
            [id.0],
            display_binding_raw_row,
        )
        .optional()?;
    raw.map(display_binding_parse).transpose()
}

fn insert_display_binding(tx: &Transaction<'_>, record: &DisplayBindingRecord) -> DbResult<()> {
    let now = timestamp();
    tx.execute(
        "INSERT INTO train_display_bindings(train_id,i2c_module_id,name,endpoint,format_string,enabled,inserted_at,updated_at)
         VALUES(?1,?2,?3,?4,?5,?6,?7,?7)",
        params![
            record.train_id.0,
            record.i2c_module_id.0,
            record.name,
            record.endpoint,
            record.format_string,
            record.enabled as i64,
            now
        ],
    )?;
    Ok(())
}

fn update_display_binding_row(tx: &Transaction<'_>, record: &DisplayBindingRecord) -> DbResult<()> {
    tx.execute(
        "UPDATE train_display_bindings SET i2c_module_id=?1,name=?2,endpoint=?3,format_string=?4,enabled=?5,updated_at=?6 WHERE id=?7",
        params![
            record.i2c_module_id.0,
            record.name,
            record.endpoint,
            record.format_string,
            record.enabled as i64,
            timestamp(),
            record.id.0
        ],
    )?;
    Ok(())
}

// =====================
// Shared helpers
// =====================

/// Ecto treats `nil` and whitespace-only strings as missing for
/// `validate_required/3`.
fn is_blank(value: Option<&str>) -> bool {
    value.is_none_or(|v| v.trim().is_empty())
}

/// Rounds user-supplied floats to two decimals with Elixir's `Float.round/2`
/// semantics (see `ButtonInputBinding.round_float_fields/2` and
/// `OutputBinding.round_float_fields/2`).
fn round2(value: f64) -> DbResult<f64> {
    trenino_core::rounding::round_elixir(value, 2)
        .ok_or_else(|| invalid("value must be a finite number"))
}

/// Changeset-style validation failure carrying the Ecto error text.
fn invalid(detail: impl Into<String>) -> StorageError {
    StorageError::Constraint {
        detail: detail.into(),
    }
}

/// Stored row could not be decoded into the typed record.
fn corrupt(detail: impl Into<String>) -> StorageError {
    StorageError::InvalidLegacyData {
        detail: detail.into(),
    }
}

/// UTC timestamp matching the `strftime('%Y-%m-%dT%H:%M:%SZ','now')` format
/// the Ecto schemas store (second precision).
fn timestamp() -> String {
    let seconds = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs() as i64;
    let days = seconds.div_euclid(86_400);
    let rem = seconds.rem_euclid(86_400);
    let z = days + 719_468;
    let era = if z >= 0 { z } else { z - 146_096 } / 146_097;
    let doe = z - era * 146_097;
    let yoe = (doe - doe / 1_460 + doe / 36_524 - doe / 146_096) / 365;
    let y = yoe + era * 400;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let d = doy - (153 * mp + 2) / 5 + 1;
    let m = mp + if mp < 10 { 3 } else { -9 };
    let year = y + if m <= 2 { 1 } else { 0 };
    format!(
        "{year:04}-{m:02}-{d:02}T{:02}:{:02}:{:02}Z",
        rem / 3_600,
        (rem % 3_600) / 60,
        rem % 60
    )
}

pub(super) fn bind_lever_input_tx(
    tx: &Transaction<'_>,
    lever_config_id: EntityId,
    input_id: EntityId,
    opts: BindOptions,
) -> DbResult<LeverBindingRecord> {
    let existing = lever_binding_row(tx, lever_config_id)?;
    let enabled = existing.as_ref().is_none_or(|row| row.enabled);
    apply_destination_exclusivity(tx, input_id, enabled, opts.replace)?;
    let now = timestamp();
    match existing {
        Some(row) => {
            tx.execute(
                "UPDATE lever_input_bindings SET input_id=?1,enabled=?2,updated_at=?3 WHERE id=?4",
                params![input_id.0, row.enabled as i64, now, row.id.0],
            )?;
        }
        None => {
            tx.execute(
                            "INSERT INTO lever_input_bindings(lever_config_id,input_id,enabled,inserted_at,updated_at) VALUES(?1,?2,1,?3,?3)",
                            params![lever_config_id.0, input_id.0, now],
                        )?;
        }
    }
    lever_binding_row(tx, lever_config_id)?.ok_or(StorageError::NotFound)
}
