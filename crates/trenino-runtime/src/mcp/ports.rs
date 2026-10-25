//! Domain ports consumed by MCP tools.
//!
//! Each trait mirrors the Elixir context functions the corresponding
//! `Trenino.MCP.Tools.*` module calls, so the tool layer ports orchestration
//! (lookups, cascades, error phrasing) while wave 2 wires these traits to the
//! real repositories. Ordering guarantees (Elixir `order_by` clauses) are noted
//! per method and belong to the implementation, not the caller.

use serde::Serialize;
use serde_json::Value;
use std::sync::Arc;

/// Errors a domain port can surface. Tool modules translate these into the
/// exact MCP error strings produced by the Elixir tools.
#[derive(Debug, Clone, PartialEq)]
pub enum PortError {
    /// The addressed record does not exist (`{:error, :not_found}`).
    NotFound,
    /// Changeset-style field errors (`{:error, %Ecto.Changeset{}}`).
    Validation(Vec<(String, Vec<String>)>),
    /// The input is already routed to the virtual joystick
    /// (`{:error, :destination_conflict}`).
    DestinationConflict,
    /// Free-form failure reason (`{:error, reason}`).
    Failed(String),
}

/// Train element kind (`train_elements.type`).
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum ElementType {
    Lever,
    Button,
}

/// Hardware input kind (`inputs.input_type`).
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum InputType {
    Analog,
    Button,
}

/// Output binding comparison operator (`output_bindings.operator`).
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum BindingOperator {
    Gt,
    Gte,
    Lt,
    Lte,
    Between,
    EqTrue,
    EqFalse,
}

/// Button binding behavior mode (`button_input_bindings.mode`).
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum ButtonMode {
    Simple,
    Momentary,
    Sequence,
    Keystroke,
}

/// Physical button type (`button_input_bindings.hardware_type`).
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum HardwareType {
    Momentary,
    Latching,
}

#[derive(Clone, Debug, PartialEq)]
pub struct TrainSummary {
    pub id: i64,
    pub name: String,
    /// Identifier prefixes, sorted (`Train.identifier_values/1`).
    pub identifiers: Vec<String>,
    pub description: Option<String>,
}

#[derive(Clone, Debug, PartialEq)]
pub struct ElementRecord {
    pub id: i64,
    pub name: String,
    pub element_type: ElementType,
}

#[derive(Clone, Debug, PartialEq)]
pub struct OutputBindingRecord {
    pub id: i64,
    pub train_id: i64,
    pub name: String,
    pub output_id: i64,
    pub endpoint: String,
    pub operator: BindingOperator,
    pub value_a: Option<f64>,
    pub value_b: Option<f64>,
    pub enabled: bool,
}

/// Fields present in the request; `create_output_binding` applies changeset
/// requiredness and defaults, updates change only provided fields.
#[derive(Clone, Debug, Default, PartialEq)]
pub struct OutputBindingAttrs {
    pub name: Option<String>,
    pub output_id: Option<i64>,
    pub endpoint: Option<String>,
    pub operator: Option<BindingOperator>,
    pub value_a: Option<f64>,
    pub value_b: Option<f64>,
    pub enabled: Option<bool>,
}

#[derive(Clone, Debug, PartialEq)]
pub struct ButtonBindingRecord {
    pub id: i64,
    pub element_id: i64,
    pub input_id: i64,
    pub mode: ButtonMode,
    pub endpoint: Option<String>,
    pub on_value: f64,
    pub off_value: f64,
    pub enabled: bool,
    pub hardware_type: HardwareType,
    pub keystroke: Option<String>,
    pub repeat_interval_ms: i64,
    pub on_sequence_id: Option<i64>,
    pub off_sequence_id: Option<i64>,
}

/// Fields present in the request; `create_button_binding` applies changeset
/// requiredness and defaults, updates change only provided fields.
#[derive(Clone, Debug, Default, PartialEq)]
pub struct ButtonBindingAttrs {
    pub mode: Option<ButtonMode>,
    pub endpoint: Option<String>,
    pub on_value: Option<f64>,
    pub off_value: Option<f64>,
    pub keystroke: Option<String>,
    pub on_sequence_id: Option<i64>,
    pub off_sequence_id: Option<i64>,
    pub repeat_interval_ms: Option<i64>,
    pub hardware_type: Option<HardwareType>,
    pub enabled: Option<bool>,
}

#[derive(Clone, Debug, PartialEq)]
pub struct DisplayBindingRecord {
    pub id: i64,
    pub train_id: i64,
    pub i2c_module_id: i64,
    pub name: Option<String>,
    pub endpoint: String,
    pub format_string: String,
    pub enabled: bool,
}

#[derive(Clone, Debug, Default, PartialEq)]
pub struct DisplayBindingAttrs {
    pub name: Option<String>,
    pub i2c_module_id: Option<i64>,
    pub endpoint: Option<String>,
    pub format_string: Option<String>,
    pub enabled: Option<bool>,
}

#[derive(Clone, Debug, PartialEq)]
pub struct SequenceCommandRecord {
    pub id: i64,
    pub position: i64,
    pub endpoint: String,
    pub value: f64,
    pub delay_ms: i64,
}

#[derive(Clone, Debug, PartialEq)]
pub struct SequenceRecord {
    pub id: i64,
    pub train_id: i64,
    pub name: String,
    /// Ordered by position.
    pub commands: Vec<SequenceCommandRecord>,
}

/// One command draft positioned by the caller (`build_command_attrs/1`).
#[derive(Clone, Debug, PartialEq)]
pub struct SequenceCommandDraft {
    pub position: i64,
    pub endpoint: Option<String>,
    pub value: Option<f64>,
    pub delay_ms: i64,
}

#[derive(Clone, Debug, PartialEq)]
pub struct ScriptRecord {
    pub id: i64,
    pub train_id: i64,
    pub name: String,
    pub enabled: bool,
    pub code: String,
    pub triggers: Vec<String>,
}

#[derive(Clone, Debug, Default, PartialEq)]
pub struct ScriptAttrs {
    pub name: Option<String>,
    pub code: Option<String>,
    pub triggers: Option<Vec<String>>,
    pub enabled: Option<bool>,
}

/// Everything `get_train` needs in one view.
#[derive(Clone, Debug, PartialEq)]
pub struct TrainDetail {
    pub train: TrainSummary,
    /// Ordered by name (`list_elements` ordering inside `get_train` uses the
    /// element association order; repositories return them ordered by name).
    pub elements: Vec<ElementRecord>,
    /// Ordered by name.
    pub output_bindings: Vec<OutputBindingRecord>,
    pub button_bindings: Vec<ButtonBindingRecord>,
    /// Ordered by name.
    pub sequences: Vec<SequenceRecord>,
}

/// Trains and train elements (`Trenino.Train` train/element functions used by
/// `TrainTools` and `ElementTools`).
pub trait TrainsPort: Send + Sync {
    /// Ordered by name.
    fn list_trains(&self) -> Result<Vec<TrainSummary>, PortError>;
    fn get_train(&self, id: i64) -> Result<TrainDetail, PortError>;
    /// Ordered by name.
    fn list_elements(&self, train_id: i64) -> Result<Vec<ElementRecord>, PortError>;
    fn create_element(
        &self,
        train_id: i64,
        name: Option<String>,
        element_type: ElementType,
    ) -> Result<ElementRecord, PortError>;
    fn get_element(&self, id: i64) -> Result<ElementRecord, PortError>;
    /// Deleting an element cascades to its button binding / lever config.
    fn delete_element(&self, element: &ElementRecord) -> Result<(), PortError>;
}

#[derive(Clone, Debug, PartialEq)]
pub struct DeviceSummary {
    pub id: i64,
    pub name: String,
}

#[derive(Clone, Debug, PartialEq)]
pub struct InputRecord {
    pub id: i64,
    pub name: String,
    pub pin: i64,
    pub input_type: InputType,
}

#[derive(Clone, Debug, PartialEq)]
pub struct HardwareOutputRecord {
    pub id: i64,
    pub name: String,
    pub pin: i64,
    pub device_id: i64,
    pub device_name: String,
}

/// HT16K33 module parameters with schema defaults already applied.
#[derive(Clone, Debug, PartialEq)]
pub struct I2cModuleParams {
    pub brightness: i64,
    pub num_digits: i64,
    pub display_type: String,
    pub has_dot: bool,
    pub align_right: bool,
    pub min_value: f64,
}

#[derive(Clone, Debug, PartialEq)]
pub struct I2cModuleRecord {
    pub id: i64,
    pub device_id: i64,
    pub device_name: String,
    pub name: Option<String>,
    pub module_chip: String,
    pub i2c_address: i64,
    pub params: I2cModuleParams,
}

#[derive(Clone, Debug, Default, PartialEq)]
pub struct I2cModuleAttrs {
    pub name: Option<String>,
    pub module_chip: Option<String>,
    pub brightness: Option<i64>,
    pub num_digits: Option<i64>,
}

#[derive(Clone, Debug, Default, PartialEq)]
pub struct I2cModuleChanges {
    pub name: Option<String>,
    pub brightness: Option<i64>,
    pub num_digits: Option<i64>,
}

/// Hardware catalog (`Trenino.Hardware` functions used by `DeviceTools`).
pub trait HardwarePort: Send + Sync {
    fn list_devices(&self) -> Vec<DeviceSummary>;
    fn list_inputs(&self, device_id: i64) -> Result<Vec<InputRecord>, PortError>;
    fn list_outputs(&self) -> Vec<HardwareOutputRecord>;
    fn list_i2c_modules(&self) -> Vec<I2cModuleRecord>;
    fn create_i2c_module(
        &self,
        device_id: i64,
        i2c_address: i64,
        attrs: I2cModuleAttrs,
    ) -> Result<I2cModuleRecord, PortError>;
    fn get_i2c_module(&self, id: i64) -> Result<I2cModuleRecord, PortError>;
    fn update_i2c_module(
        &self,
        module: &I2cModuleRecord,
        changes: I2cModuleChanges,
    ) -> Result<I2cModuleRecord, PortError>;
    fn delete_i2c_module(&self, module: &I2cModuleRecord) -> Result<(), PortError>;
}

/// Command sequences (`SequenceTools`).
pub trait SequencesPort: Send + Sync {
    /// Ordered by name, commands preloaded.
    fn list_sequences(&self, train_id: i64) -> Vec<SequenceRecord>;
    fn create_sequence(
        &self,
        train_id: i64,
        name: Option<String>,
    ) -> Result<SequenceRecord, PortError>;
    fn get_sequence(&self, id: i64) -> Result<SequenceRecord, PortError>;
    fn update_sequence_name(
        &self,
        sequence: &SequenceRecord,
        name: Option<String>,
    ) -> Result<(), PortError>;
    /// Replaces all commands; `Validation` mirrors changeset errors,
    /// `Failed` mirrors `{:error, reason}` from `set_sequence_commands`.
    fn set_sequence_commands(
        &self,
        sequence: &SequenceRecord,
        commands: Vec<SequenceCommandDraft>,
    ) -> Result<(), PortError>;
    fn delete_sequence(&self, sequence: &SequenceRecord) -> Result<(), PortError>;
}

/// Lua scripts (`ScriptTools`).
pub trait ScriptsPort: Send + Sync {
    fn list_scripts(&self, train_id: i64) -> Vec<ScriptRecord>;
    fn get_script(&self, id: i64) -> Result<ScriptRecord, PortError>;
    fn create_script(&self, train_id: i64, attrs: ScriptAttrs) -> Result<ScriptRecord, PortError>;
    fn update_script(
        &self,
        script: &ScriptRecord,
        changes: ScriptAttrs,
    ) -> Result<ScriptRecord, PortError>;
    fn delete_script(&self, script: &ScriptRecord) -> Result<(), PortError>;
}

/// Output, button and display bindings (`OutputBindingTools`,
/// `ButtonBindingTools`, `DisplayBindingTools`). Mutating implementations also
/// reload the corresponding controller bindings after commit, exactly like the
/// Elixir tools call `OutputController.reload_bindings/0` etc.
pub trait BindingsPort: Send + Sync {
    /// Ordered by name.
    fn list_output_bindings(&self, train_id: i64) -> Vec<OutputBindingRecord>;
    fn create_output_binding(
        &self,
        train_id: i64,
        attrs: OutputBindingAttrs,
    ) -> Result<OutputBindingRecord, PortError>;
    fn get_output_binding(&self, id: i64) -> Result<OutputBindingRecord, PortError>;
    fn update_output_binding(
        &self,
        binding: &OutputBindingRecord,
        changes: OutputBindingAttrs,
    ) -> Result<OutputBindingRecord, PortError>;
    fn delete_output_binding(&self, binding: &OutputBindingRecord) -> Result<(), PortError>;

    fn get_button_binding(&self, element_id: i64) -> Result<ButtonBindingRecord, PortError>;
    fn create_button_binding(
        &self,
        element_id: i64,
        input_id: i64,
        attrs: ButtonBindingAttrs,
    ) -> Result<ButtonBindingRecord, PortError>;
    fn update_button_binding(
        &self,
        binding: &ButtonBindingRecord,
        changes: ButtonBindingAttrs,
    ) -> Result<ButtonBindingRecord, PortError>;
    fn delete_button_binding(&self, element_id: i64) -> Result<(), PortError>;

    fn list_display_bindings(&self, train_id: i64) -> Vec<DisplayBindingRecord>;
    fn create_display_binding(
        &self,
        train_id: i64,
        attrs: DisplayBindingAttrs,
    ) -> Result<DisplayBindingRecord, PortError>;
    fn get_display_binding(&self, id: i64) -> Result<DisplayBindingRecord, PortError>;
    fn update_display_binding(
        &self,
        binding: &DisplayBindingRecord,
        changes: DisplayBindingAttrs,
    ) -> Result<DisplayBindingRecord, PortError>;
    fn delete_display_binding(&self, binding: &DisplayBindingRecord) -> Result<(), PortError>;
}

/// Train Sim World API access (`SimulatorTools` via `SimulatorConnection`).
/// Error strings are the raw reasons the tools prefix with
/// `"Simulator error: "`.
pub trait SimulatorPort: Send + Sync {
    /// `SimulatorConnection.get_status()` returning `:connected` with a client.
    fn is_connected(&self) -> bool;
    fn list_endpoints(&self, path: Option<&str>) -> Result<Value, String>;
    fn get_value(&self, path: &str) -> Result<Value, String>;
    fn set_value(&self, path: &str, value: &Value) -> Result<Value, String>;
}

/// Kind of hardware input the detection session accepts.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum DetectionKind {
    Button,
    Analog,
    Any,
}

#[derive(Clone, Debug, PartialEq)]
pub struct DetectionRequest {
    pub prompt: String,
    pub kind: DetectionKind,
    pub timeout_ms: i64,
}

/// One detected hardware input (`InputDetectionSession` detection payload).
#[derive(Clone, Debug, PartialEq)]
pub struct DetectedInput {
    pub input_id: i64,
    pub pin: i64,
    pub input_type: InputType,
    pub name: String,
    pub device_id: i64,
    pub device_name: String,
    pub value: i64,
}

#[derive(Clone, Debug, PartialEq)]
pub enum DetectionOutcome {
    Detected(DetectedInput),
    Timeout,
}

/// Interactive hardware input detection (`DetectionTools`). Implementations
/// surface the prompt to the UI, block until an event or timeout, and clear
/// the prompt afterwards.
pub trait DetectionPort: Send + Sync {
    fn detect_input(&self, request: &DetectionRequest) -> DetectionOutcome;
}

/// vJoy manager state (`VirtualJoystickTools`).
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum VjoyStatus {
    Unsupported,
    Off,
    Enabling,
    Active,
    Disabling,
    NeedsSetup,
    NeedsCleanup,
    Degraded,
    Error,
    RuntimeUnavailable,
}

/// Failure reason in the `reason` field: a bare code or a code with details
/// (`reason/1` in `VirtualJoystickTools`).
#[derive(Clone, Debug, PartialEq)]
pub enum VjoyReason {
    Code(String),
    CodeWithDetails(String, String),
}

#[derive(Clone, Debug, PartialEq)]
pub struct VjoyStatusDetails {
    pub status: VjoyStatus,
    pub reason: Option<VjoyReason>,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum VjoyTarget {
    Axis,
    Button,
}

/// vJoy axes (`@axes` in `VirtualJoystickTools`), in schema order.
pub const VJOY_AXES: [&str; 8] = ["x", "y", "z", "rx", "ry", "rz", "slider_1", "slider_2"];

#[derive(Clone, Debug, PartialEq)]
pub struct VjoyMappingRecord {
    pub id: i64,
    pub input_id: i64,
    pub device_index: i64,
    pub target_type: VjoyTarget,
    pub axis: Option<String>,
    pub button: Option<i64>,
    pub inverted: bool,
}

/// Mapping target with defaults already applied by the tool layer
/// (`device_index` 1, `inverted` false).
#[derive(Clone, Debug, PartialEq)]
pub struct VjoyMappingDraft {
    pub target_type: VjoyTarget,
    pub axis: Option<String>,
    pub button: Option<i64>,
    pub device_index: i64,
    pub inverted: bool,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum VjoyCommand {
    Enable,
    Disable,
    Retry,
    RemoveLeftover,
    Repair,
}

#[derive(Debug, Clone, PartialEq)]
pub enum VjoyPutError {
    /// Input already drives a simulator/lever destination.
    DestinationConflict,
    NotFound,
    /// Changeset field errors.
    Validation(Vec<(String, Vec<String>)>),
}

pub trait VjoyPort: Send + Sync {
    fn status_details(&self) -> VjoyStatusDetails;
    fn list_mappings(&self) -> Vec<VjoyMappingRecord>;
    /// Create or update the mapping for an input (`put_mapping` with
    /// `replace:`).
    fn put_mapping(
        &self,
        input_id: i64,
        draft: VjoyMappingDraft,
        replace: bool,
    ) -> Result<VjoyMappingRecord, VjoyPutError>;
    fn delete_mapping(&self, id: i64) -> Result<VjoyMappingRecord, PortError>;
    /// Lifecycle commands; `Err` carries the reason reported structurally.
    fn lifecycle(&self, command: VjoyCommand) -> Result<(), VjoyReason>;
    fn reload_mappings(&self);
}

/// All domain ports the MCP tool registry dispatches against.
#[derive(Clone)]
pub struct Ports {
    pub trains: Arc<dyn TrainsPort>,
    pub hardware: Arc<dyn HardwarePort>,
    pub sequences: Arc<dyn SequencesPort>,
    pub scripts: Arc<dyn ScriptsPort>,
    pub bindings: Arc<dyn BindingsPort>,
    pub simulator: Arc<dyn SimulatorPort>,
    pub detection: Arc<dyn DetectionPort>,
    pub vjoy: Arc<dyn VjoyPort>,
}
