//! Integration tests for the Rust MCP server, mirroring the Elixir oracle
//! suites: `test/trenino/mcp/server_test.exs`, `tool_registry_test.exs`,
//! `test/trenino/mcp/tools/*_test.exs` and
//! `test/trenino_web/controllers/mcp/mcp_controller_test.exs`.
//!
//! Every tool port is exercised through an in-memory fake; HTTP tests run
//! against a real loopback listener.

use std::collections::{HashMap, VecDeque};
use std::io::{Read, Write};
use std::net::{SocketAddr, TcpStream};
use std::sync::atomic::{AtomicBool, AtomicI64, Ordering};
use std::sync::{Arc, Mutex};
use std::time::Duration;

use serde_json::{json, Value};
use trenino_runtime::lifecycle::ShutdownCoordinator;
use trenino_runtime::mcp::ports::*;
use trenino_runtime::mcp::server::{
    handle_message, ApiKeySource, McpServer, McpServerStatus, McpStartError, MessageOutcome,
    PROTOCOL_VERSION,
};
use trenino_runtime::mcp::tools;

// ---------------------------------------------------------------------------
// In-memory port fakes
// ---------------------------------------------------------------------------

struct FakeTrains {
    detail: Mutex<Option<TrainDetail>>,
    elements: Mutex<Vec<ElementRecord>>,
    next_id: AtomicI64,
    create_error: Mutex<Option<PortError>>,
}

impl FakeTrains {
    fn new() -> Self {
        Self {
            detail: Mutex::new(None),
            elements: Mutex::new(vec![]),
            next_id: AtomicI64::new(1),
            create_error: Mutex::new(None),
        }
    }
}

impl TrainsPort for FakeTrains {
    fn list_trains(&self) -> Result<Vec<TrainSummary>, PortError> {
        Ok(self
            .detail
            .lock()
            .unwrap()
            .as_ref()
            .map(|detail| vec![detail.train.clone()])
            .unwrap_or_default())
    }

    fn get_train(&self, id: i64) -> Result<TrainDetail, PortError> {
        self.detail
            .lock()
            .unwrap()
            .clone()
            .filter(|detail| detail.train.id == id)
            .ok_or(PortError::NotFound)
    }

    fn list_elements(&self, _train_id: i64) -> Result<Vec<ElementRecord>, PortError> {
        Ok(self.all_elements())
    }

    fn create_element(
        &self,
        _train_id: i64,
        name: Option<String>,
        element_type: ElementType,
    ) -> Result<ElementRecord, PortError> {
        if let Some(error) = self.create_error.lock().unwrap().take() {
            return Err(error);
        }
        if name.as_deref().unwrap_or("").is_empty() {
            return Err(PortError::Validation(vec![(
                "name".to_string(),
                vec!["can't be blank".to_string()],
            )]));
        }
        let element = ElementRecord {
            id: self.next_id.fetch_add(1, Ordering::SeqCst),
            name: name.unwrap(),
            element_type,
        };
        self.elements.lock().unwrap().push(element.clone());
        Ok(element)
    }

    fn get_element(&self, id: i64) -> Result<ElementRecord, PortError> {
        self.all_elements()
            .into_iter()
            .find(|element| element.id == id)
            .ok_or(PortError::NotFound)
    }

    fn delete_element(&self, element: &ElementRecord) -> Result<(), PortError> {
        self.elements
            .lock()
            .unwrap()
            .retain(|candidate| candidate.id != element.id);
        if let Ok(mut detail) = self.detail.lock() {
            if let Some(detail) = detail.as_mut() {
                detail
                    .elements
                    .retain(|candidate| candidate.id != element.id);
            }
        }
        Ok(())
    }
}

impl FakeTrains {
    fn all_elements(&self) -> Vec<ElementRecord> {
        let mut elements = self
            .detail
            .lock()
            .map(|detail| {
                detail
                    .as_ref()
                    .map(|detail| detail.elements.clone())
                    .unwrap_or_default()
            })
            .unwrap_or_default();
        elements.extend(self.elements.lock().unwrap().iter().cloned());
        elements
    }
}

struct FakeHardware {
    devices: Mutex<Vec<DeviceSummary>>,
    inputs: Mutex<Vec<InputRecord>>,
    outputs: Mutex<Vec<HardwareOutputRecord>>,
    modules: Mutex<Vec<I2cModuleRecord>>,
    next_id: AtomicI64,
    create_error: Mutex<Option<PortError>>,
}

impl FakeHardware {
    fn new() -> Self {
        Self {
            devices: Mutex::new(vec![]),
            inputs: Mutex::new(vec![]),
            outputs: Mutex::new(vec![]),
            modules: Mutex::new(vec![]),
            next_id: AtomicI64::new(1),
            create_error: Mutex::new(None),
        }
    }
}

fn default_params() -> I2cModuleParams {
    I2cModuleParams {
        brightness: 8,
        num_digits: 4,
        display_type: "fourteen_segment".to_string(),
        has_dot: false,
        align_right: true,
        min_value: 0.0,
    }
}

impl HardwarePort for FakeHardware {
    fn list_devices(&self) -> Vec<DeviceSummary> {
        self.devices.lock().unwrap().clone()
    }

    fn list_inputs(&self, _device_id: i64) -> Result<Vec<InputRecord>, PortError> {
        Ok(self.inputs.lock().unwrap().clone())
    }

    fn list_outputs(&self) -> Vec<HardwareOutputRecord> {
        self.outputs.lock().unwrap().clone()
    }

    fn list_i2c_modules(&self) -> Vec<I2cModuleRecord> {
        self.modules.lock().unwrap().clone()
    }

    fn create_i2c_module(
        &self,
        device_id: i64,
        i2c_address: i64,
        attrs: I2cModuleAttrs,
    ) -> Result<I2cModuleRecord, PortError> {
        if let Some(error) = self.create_error.lock().unwrap().take() {
            return Err(error);
        }
        let chip = attrs.module_chip.unwrap_or_default();
        if chip != "ht16k33" {
            return Err(PortError::Validation(vec![(
                "module_chip".to_string(),
                vec!["is invalid".to_string()],
            )]));
        }
        let id = self.next_id.fetch_add(1, Ordering::SeqCst);
        let record = I2cModuleRecord {
            id,
            device_id,
            device_name: "Main device".to_string(),
            name: attrs.name,
            module_chip: chip,
            i2c_address,
            params: I2cModuleParams {
                brightness: attrs.brightness.unwrap_or(8),
                num_digits: attrs.num_digits.unwrap_or(4),
                ..default_params()
            },
        };
        self.modules.lock().unwrap().push(record.clone());
        Ok(record)
    }

    fn get_i2c_module(&self, id: i64) -> Result<I2cModuleRecord, PortError> {
        self.modules
            .lock()
            .unwrap()
            .iter()
            .find(|module| module.id == id)
            .cloned()
            .ok_or(PortError::NotFound)
    }

    fn update_i2c_module(
        &self,
        module: &I2cModuleRecord,
        changes: I2cModuleChanges,
    ) -> Result<I2cModuleRecord, PortError> {
        let mut modules = self.modules.lock().unwrap();
        let record = modules
            .iter_mut()
            .find(|candidate| candidate.id == module.id)
            .unwrap();
        if let Some(name) = changes.name {
            record.name = Some(name);
        }
        if let Some(brightness) = changes.brightness {
            if !(0..=15).contains(&brightness) {
                return Err(PortError::Validation(vec![(
                    "brightness".to_string(),
                    vec!["must be greater than or equal to 0".to_string()],
                )]));
            }
            record.params.brightness = brightness;
        }
        if let Some(num_digits) = changes.num_digits {
            record.params.num_digits = num_digits;
        }
        Ok(record.clone())
    }

    fn delete_i2c_module(&self, module: &I2cModuleRecord) -> Result<(), PortError> {
        self.modules
            .lock()
            .unwrap()
            .retain(|candidate| candidate.id != module.id);
        Ok(())
    }
}

struct FakeSequences {
    sequences: Mutex<Vec<SequenceRecord>>,
    next_id: AtomicI64,
    name_error: Mutex<Option<PortError>>,
    commands_error: Mutex<Option<PortError>>,
}

impl FakeSequences {
    fn new() -> Self {
        Self {
            sequences: Mutex::new(vec![]),
            next_id: AtomicI64::new(1),
            name_error: Mutex::new(None),
            commands_error: Mutex::new(None),
        }
    }
}

impl SequencesPort for FakeSequences {
    fn list_sequences(&self, train_id: i64) -> Vec<SequenceRecord> {
        self.sequences
            .lock()
            .unwrap()
            .iter()
            .filter(|sequence| sequence.train_id == train_id)
            .cloned()
            .collect()
    }

    fn create_sequence(
        &self,
        train_id: i64,
        name: Option<String>,
    ) -> Result<SequenceRecord, PortError> {
        let name = name.unwrap_or_default();
        if name.is_empty() {
            return Err(PortError::Validation(vec![(
                "name".to_string(),
                vec!["can't be blank".to_string()],
            )]));
        }
        let sequence = SequenceRecord {
            id: self.next_id.fetch_add(1, Ordering::SeqCst),
            train_id,
            name,
            commands: vec![],
        };
        self.sequences.lock().unwrap().push(sequence.clone());
        Ok(sequence)
    }

    fn get_sequence(&self, id: i64) -> Result<SequenceRecord, PortError> {
        self.sequences
            .lock()
            .unwrap()
            .iter()
            .find(|sequence| sequence.id == id)
            .cloned()
            .ok_or(PortError::NotFound)
    }

    fn update_sequence_name(
        &self,
        sequence: &SequenceRecord,
        name: Option<String>,
    ) -> Result<(), PortError> {
        if let Some(error) = self.name_error.lock().unwrap().take() {
            return Err(error);
        }
        self.sequences
            .lock()
            .unwrap()
            .iter_mut()
            .find(|candidate| candidate.id == sequence.id)
            .unwrap()
            .name = name.unwrap_or_default();
        Ok(())
    }

    fn set_sequence_commands(
        &self,
        sequence: &SequenceRecord,
        commands: Vec<SequenceCommandDraft>,
    ) -> Result<(), PortError> {
        if let Some(error) = self.commands_error.lock().unwrap().take() {
            return Err(error);
        }
        let mut next_command_id = 100;
        let commands = commands
            .into_iter()
            .map(|draft| {
                next_command_id += 1;
                SequenceCommandRecord {
                    id: next_command_id,
                    position: draft.position,
                    endpoint: draft.endpoint.unwrap_or_default(),
                    value: draft.value.unwrap_or(0.0),
                    delay_ms: draft.delay_ms,
                }
            })
            .collect();
        self.sequences
            .lock()
            .unwrap()
            .iter_mut()
            .find(|candidate| candidate.id == sequence.id)
            .unwrap()
            .commands = commands;
        Ok(())
    }

    fn delete_sequence(&self, sequence: &SequenceRecord) -> Result<(), PortError> {
        self.sequences
            .lock()
            .unwrap()
            .retain(|candidate| candidate.id != sequence.id);
        Ok(())
    }
}

struct FakeScripts {
    scripts: Mutex<Vec<ScriptRecord>>,
    next_id: AtomicI64,
    create_error: Mutex<Option<PortError>>,
}

impl FakeScripts {
    fn new() -> Self {
        Self {
            scripts: Mutex::new(vec![]),
            next_id: AtomicI64::new(1),
            create_error: Mutex::new(None),
        }
    }
}

impl ScriptsPort for FakeScripts {
    fn list_scripts(&self, train_id: i64) -> Vec<ScriptRecord> {
        self.scripts
            .lock()
            .unwrap()
            .iter()
            .filter(|script| script.train_id == train_id)
            .cloned()
            .collect()
    }

    fn get_script(&self, id: i64) -> Result<ScriptRecord, PortError> {
        self.scripts
            .lock()
            .unwrap()
            .iter()
            .find(|script| script.id == id)
            .cloned()
            .ok_or(PortError::NotFound)
    }

    fn create_script(&self, train_id: i64, attrs: ScriptAttrs) -> Result<ScriptRecord, PortError> {
        if let Some(error) = self.create_error.lock().unwrap().take() {
            return Err(error);
        }
        let script = ScriptRecord {
            id: self.next_id.fetch_add(1, Ordering::SeqCst),
            train_id,
            name: attrs.name.unwrap_or_default(),
            enabled: attrs.enabled.unwrap_or(true),
            code: attrs.code.unwrap_or_default(),
            triggers: attrs.triggers.unwrap_or_default(),
        };
        self.scripts.lock().unwrap().push(script.clone());
        Ok(script)
    }

    fn update_script(
        &self,
        script: &ScriptRecord,
        changes: ScriptAttrs,
    ) -> Result<ScriptRecord, PortError> {
        let mut scripts = self.scripts.lock().unwrap();
        let record = scripts
            .iter_mut()
            .find(|candidate| candidate.id == script.id)
            .unwrap();
        if let Some(name) = changes.name {
            record.name = name;
        }
        if let Some(code) = changes.code {
            record.code = code;
        }
        if let Some(triggers) = changes.triggers {
            record.triggers = triggers;
        }
        if let Some(enabled) = changes.enabled {
            record.enabled = enabled;
        }
        Ok(record.clone())
    }

    fn delete_script(&self, script: &ScriptRecord) -> Result<(), PortError> {
        self.scripts
            .lock()
            .unwrap()
            .retain(|candidate| candidate.id != script.id);
        Ok(())
    }
}

struct FakeBindings {
    outputs: Mutex<Vec<OutputBindingRecord>>,
    buttons: Mutex<Vec<ButtonBindingRecord>>,
    displays: Mutex<Vec<DisplayBindingRecord>>,
    next_id: AtomicI64,
    conflict: AtomicBool,
    create_error: Mutex<Option<PortError>>,
}

impl FakeBindings {
    fn new() -> Self {
        Self {
            outputs: Mutex::new(vec![]),
            buttons: Mutex::new(vec![]),
            displays: Mutex::new(vec![]),
            next_id: AtomicI64::new(1),
            conflict: AtomicBool::new(false),
            create_error: Mutex::new(None),
        }
    }
}

impl BindingsPort for FakeBindings {
    fn list_output_bindings(&self, train_id: i64) -> Vec<OutputBindingRecord> {
        self.outputs
            .lock()
            .unwrap()
            .iter()
            .filter(|binding| binding.train_id == train_id)
            .cloned()
            .collect()
    }

    fn create_output_binding(
        &self,
        train_id: i64,
        attrs: OutputBindingAttrs,
    ) -> Result<OutputBindingRecord, PortError> {
        if attrs.name.as_deref().unwrap_or("").is_empty() {
            return Err(PortError::Validation(vec![(
                "name".to_string(),
                vec!["can't be blank".to_string()],
            )]));
        }
        let binding = OutputBindingRecord {
            id: self.next_id.fetch_add(1, Ordering::SeqCst),
            train_id,
            name: attrs.name.unwrap(),
            output_id: attrs.output_id.unwrap_or(1),
            endpoint: attrs.endpoint.unwrap_or_default(),
            operator: attrs.operator.unwrap_or(BindingOperator::Gt),
            value_a: attrs.value_a,
            value_b: attrs.value_b,
            enabled: attrs.enabled.unwrap_or(true),
        };
        self.outputs.lock().unwrap().push(binding.clone());
        Ok(binding)
    }

    fn get_output_binding(&self, id: i64) -> Result<OutputBindingRecord, PortError> {
        self.outputs
            .lock()
            .unwrap()
            .iter()
            .find(|binding| binding.id == id)
            .cloned()
            .ok_or(PortError::NotFound)
    }

    fn update_output_binding(
        &self,
        binding: &OutputBindingRecord,
        changes: OutputBindingAttrs,
    ) -> Result<OutputBindingRecord, PortError> {
        let mut bindings = self.outputs.lock().unwrap();
        let record = bindings
            .iter_mut()
            .find(|candidate| candidate.id == binding.id)
            .unwrap();
        if let Some(name) = changes.name {
            if name.is_empty() {
                return Err(PortError::Validation(vec![(
                    "name".to_string(),
                    vec!["can't be blank".to_string()],
                )]));
            }
            record.name = name;
        }
        if let Some(output_id) = changes.output_id {
            record.output_id = output_id;
        }
        if let Some(endpoint) = changes.endpoint {
            record.endpoint = endpoint;
        }
        if let Some(operator) = changes.operator {
            record.operator = operator;
        }
        if changes.value_a.is_some() {
            record.value_a = changes.value_a;
        }
        if changes.value_b.is_some() {
            record.value_b = changes.value_b;
        }
        if let Some(enabled) = changes.enabled {
            record.enabled = enabled;
        }
        Ok(record.clone())
    }

    fn delete_output_binding(&self, binding: &OutputBindingRecord) -> Result<(), PortError> {
        self.outputs
            .lock()
            .unwrap()
            .retain(|candidate| candidate.id != binding.id);
        Ok(())
    }

    fn get_button_binding(&self, element_id: i64) -> Result<ButtonBindingRecord, PortError> {
        self.buttons
            .lock()
            .unwrap()
            .iter()
            .find(|binding| binding.element_id == element_id)
            .cloned()
            .ok_or(PortError::NotFound)
    }

    fn create_button_binding(
        &self,
        element_id: i64,
        input_id: i64,
        attrs: ButtonBindingAttrs,
    ) -> Result<ButtonBindingRecord, PortError> {
        if self.conflict.load(Ordering::SeqCst) {
            return Err(PortError::DestinationConflict);
        }
        if let Some(error) = self.create_error.lock().unwrap().take() {
            return Err(error);
        }
        let binding = ButtonBindingRecord {
            id: self.next_id.fetch_add(1, Ordering::SeqCst),
            element_id,
            input_id,
            mode: attrs.mode.unwrap_or(ButtonMode::Simple),
            endpoint: attrs.endpoint,
            on_value: attrs.on_value.unwrap_or(1.0),
            off_value: attrs.off_value.unwrap_or(0.0),
            enabled: attrs.enabled.unwrap_or(true),
            hardware_type: attrs.hardware_type.unwrap_or(HardwareType::Momentary),
            keystroke: attrs.keystroke,
            repeat_interval_ms: attrs.repeat_interval_ms.unwrap_or(100),
            on_sequence_id: attrs.on_sequence_id,
            off_sequence_id: attrs.off_sequence_id,
        };
        self.buttons.lock().unwrap().push(binding.clone());
        Ok(binding)
    }

    fn update_button_binding(
        &self,
        binding: &ButtonBindingRecord,
        changes: ButtonBindingAttrs,
    ) -> Result<ButtonBindingRecord, PortError> {
        if self.conflict.load(Ordering::SeqCst) {
            return Err(PortError::DestinationConflict);
        }
        let mut bindings = self.buttons.lock().unwrap();
        let record = bindings
            .iter_mut()
            .find(|candidate| candidate.id == binding.id)
            .unwrap();
        if let Some(mode) = changes.mode {
            record.mode = mode;
        }
        if changes.endpoint.is_some() {
            record.endpoint = changes.endpoint.clone();
        }
        if let Some(on_value) = changes.on_value {
            record.on_value = on_value;
        }
        if let Some(off_value) = changes.off_value {
            record.off_value = off_value;
        }
        if changes.keystroke.is_some() {
            record.keystroke = changes.keystroke.clone();
        }
        if changes.on_sequence_id.is_some() {
            record.on_sequence_id = changes.on_sequence_id;
        }
        if changes.off_sequence_id.is_some() {
            record.off_sequence_id = changes.off_sequence_id;
        }
        if let Some(repeat) = changes.repeat_interval_ms {
            record.repeat_interval_ms = repeat;
        }
        if let Some(hardware_type) = changes.hardware_type {
            record.hardware_type = hardware_type;
        }
        if let Some(enabled) = changes.enabled {
            record.enabled = enabled;
        }
        Ok(record.clone())
    }

    fn delete_button_binding(&self, element_id: i64) -> Result<(), PortError> {
        let retained = self
            .buttons
            .lock()
            .unwrap()
            .iter()
            .filter(|binding| binding.element_id != element_id)
            .count();
        let total = self.buttons.lock().unwrap().len();
        if retained == total {
            return Err(PortError::NotFound);
        }
        self.buttons
            .lock()
            .unwrap()
            .retain(|binding| binding.element_id != element_id);
        Ok(())
    }

    fn list_display_bindings(&self, train_id: i64) -> Vec<DisplayBindingRecord> {
        self.displays
            .lock()
            .unwrap()
            .iter()
            .filter(|binding| binding.train_id == train_id)
            .cloned()
            .collect()
    }

    fn create_display_binding(
        &self,
        train_id: i64,
        attrs: DisplayBindingAttrs,
    ) -> Result<DisplayBindingRecord, PortError> {
        let binding = DisplayBindingRecord {
            id: self.next_id.fetch_add(1, Ordering::SeqCst),
            train_id,
            i2c_module_id: attrs.i2c_module_id.unwrap_or(1),
            name: attrs.name,
            endpoint: attrs.endpoint.unwrap_or_default(),
            format_string: attrs.format_string.unwrap_or_else(|| "{value}".to_string()),
            enabled: attrs.enabled.unwrap_or(true),
        };
        self.displays.lock().unwrap().push(binding.clone());
        Ok(binding)
    }

    fn get_display_binding(&self, id: i64) -> Result<DisplayBindingRecord, PortError> {
        self.displays
            .lock()
            .unwrap()
            .iter()
            .find(|binding| binding.id == id)
            .cloned()
            .ok_or(PortError::NotFound)
    }

    fn update_display_binding(
        &self,
        binding: &DisplayBindingRecord,
        changes: DisplayBindingAttrs,
    ) -> Result<DisplayBindingRecord, PortError> {
        let mut bindings = self.displays.lock().unwrap();
        let record = bindings
            .iter_mut()
            .find(|candidate| candidate.id == binding.id)
            .unwrap();
        if let Some(name) = changes.name {
            record.name = Some(name);
        }
        if let Some(module) = changes.i2c_module_id {
            record.i2c_module_id = module;
        }
        if let Some(endpoint) = changes.endpoint {
            record.endpoint = endpoint;
        }
        if let Some(format_string) = changes.format_string {
            record.format_string = format_string;
        }
        if let Some(enabled) = changes.enabled {
            record.enabled = enabled;
        }
        Ok(record.clone())
    }

    fn delete_display_binding(&self, binding: &DisplayBindingRecord) -> Result<(), PortError> {
        self.displays
            .lock()
            .unwrap()
            .retain(|candidate| candidate.id != binding.id);
        Ok(())
    }
}

struct FakeSimulator {
    connected: AtomicBool,
    list_result: Mutex<Result<Value, String>>,
    get_result: Mutex<Result<Value, String>>,
    set_result: Mutex<Result<Value, String>>,
    calls: Mutex<Vec<(&'static str, String)>>,
}

impl FakeSimulator {
    fn new() -> Self {
        Self {
            connected: AtomicBool::new(false),
            list_result: Mutex::new(Ok(json!({"Nodes": [], "Endpoints": []}))),
            get_result: Mutex::new(Ok(json!(1.0))),
            set_result: Mutex::new(Ok(json!({"status": "ok"}))),
            calls: Mutex::new(vec![]),
        }
    }
}

impl SimulatorPort for FakeSimulator {
    fn is_connected(&self) -> bool {
        self.connected.load(Ordering::SeqCst)
    }

    fn list_endpoints(&self, path: Option<&str>) -> Result<Value, String> {
        self.calls
            .lock()
            .unwrap()
            .push(("list", path.unwrap_or("<root>").to_string()));
        self.list_result.lock().unwrap().clone()
    }

    fn get_value(&self, path: &str) -> Result<Value, String> {
        self.calls.lock().unwrap().push(("get", path.to_string()));
        self.get_result.lock().unwrap().clone()
    }

    fn set_value(&self, path: &str, value: &Value) -> Result<Value, String> {
        self.calls
            .lock()
            .unwrap()
            .push(("set", format!("{path}={value}")));
        self.set_result.lock().unwrap().clone()
    }
}

struct FakeDetection {
    scripted: Mutex<VecDeque<DetectionOutcome>>,
    requests: Mutex<Vec<DetectionRequest>>,
}

impl FakeDetection {
    fn new() -> Self {
        Self {
            scripted: Mutex::new(VecDeque::new()),
            requests: Mutex::new(vec![]),
        }
    }
}

impl DetectionPort for FakeDetection {
    fn detect_input(&self, request: &DetectionRequest) -> DetectionOutcome {
        self.requests.lock().unwrap().push(request.clone());
        match self.scripted.lock().unwrap().pop_front() {
            Some(outcome) => outcome,
            None => {
                let wait = request.timeout_ms.clamp(1, 2000) as u64;
                std::thread::sleep(Duration::from_millis(wait));
                DetectionOutcome::Timeout
            }
        }
    }
}

struct FakeVjoy {
    mappings: Mutex<Vec<VjoyMappingRecord>>,
    status: Mutex<VjoyStatusDetails>,
    put_error: Mutex<Option<VjoyPutError>>,
    lifecycle_results: Mutex<VecDeque<Result<(), VjoyReason>>>,
    reloads: AtomicI64,
    last_put: Mutex<Option<(i64, VjoyMappingDraft, bool)>>,
    next_id: AtomicI64,
}

impl FakeVjoy {
    fn new() -> Self {
        Self {
            mappings: Mutex::new(vec![]),
            status: Mutex::new(VjoyStatusDetails {
                status: VjoyStatus::Unsupported,
                reason: None,
            }),
            put_error: Mutex::new(None),
            lifecycle_results: Mutex::new(VecDeque::new()),
            reloads: AtomicI64::new(0),
            last_put: Mutex::new(None),
            next_id: AtomicI64::new(1),
        }
    }
}

impl VjoyPort for FakeVjoy {
    fn status_details(&self) -> VjoyStatusDetails {
        self.status.lock().unwrap().clone()
    }

    fn list_mappings(&self) -> Vec<VjoyMappingRecord> {
        self.mappings.lock().unwrap().clone()
    }

    fn put_mapping(
        &self,
        input_id: i64,
        draft: VjoyMappingDraft,
        replace: bool,
    ) -> Result<VjoyMappingRecord, VjoyPutError> {
        if let Some(error) = self.put_error.lock().unwrap().take() {
            return Err(error);
        }
        *self.last_put.lock().unwrap() = Some((input_id, draft.clone(), replace));
        let existing = self
            .mappings
            .lock()
            .unwrap()
            .iter()
            .find(|mapping| mapping.input_id == input_id)
            .map(|mapping| mapping.id);
        let id = existing.unwrap_or_else(|| self.next_id.fetch_add(1, Ordering::SeqCst));
        let record = VjoyMappingRecord {
            id,
            input_id,
            device_index: draft.device_index,
            target_type: draft.target_type,
            axis: draft.axis,
            button: draft.button,
            inverted: draft.inverted,
        };
        self.mappings
            .lock()
            .unwrap()
            .retain(|mapping| mapping.id != id);
        self.mappings.lock().unwrap().push(record.clone());
        Ok(record)
    }

    fn delete_mapping(&self, id: i64) -> Result<VjoyMappingRecord, PortError> {
        let mut mappings = self.mappings.lock().unwrap();
        let position = mappings
            .iter()
            .position(|mapping| mapping.id == id)
            .ok_or(PortError::NotFound)?;
        Ok(mappings.remove(position))
    }

    fn lifecycle(&self, _command: VjoyCommand) -> Result<(), VjoyReason> {
        self.lifecycle_results
            .lock()
            .unwrap()
            .pop_front()
            .unwrap_or(Ok(()))
    }

    fn reload_mappings(&self) {
        self.reloads.fetch_add(1, Ordering::SeqCst);
    }
}

struct FakeKey(String);
impl ApiKeySource for FakeKey {
    fn api_key(&self) -> Option<String> {
        Some(self.0.clone())
    }
}

#[allow(clippy::type_complexity)]
struct Fixture {
    ports: Ports,
    trains: Arc<FakeTrains>,
    hardware: Arc<FakeHardware>,
    sequences: Arc<FakeSequences>,
    scripts: Arc<FakeScripts>,
    bindings: Arc<FakeBindings>,
    simulator: Arc<FakeSimulator>,
    detection: Arc<FakeDetection>,
    vjoy: Arc<FakeVjoy>,
}

fn fixture() -> Fixture {
    let trains = Arc::new(FakeTrains::new());
    let hardware = Arc::new(FakeHardware::new());
    let sequences = Arc::new(FakeSequences::new());
    let scripts = Arc::new(FakeScripts::new());
    let bindings = Arc::new(FakeBindings::new());
    let simulator = Arc::new(FakeSimulator::new());
    let detection = Arc::new(FakeDetection::new());
    let vjoy = Arc::new(FakeVjoy::new());
    let ports = Ports {
        trains: trains.clone(),
        hardware: hardware.clone(),
        sequences: sequences.clone(),
        scripts: scripts.clone(),
        bindings: bindings.clone(),
        simulator: simulator.clone(),
        detection: detection.clone(),
        vjoy: vjoy.clone(),
    };
    Fixture {
        ports,
        trains,
        hardware,
        sequences,
        scripts,
        bindings,
        simulator,
        detection,
        vjoy,
    }
}

fn call(fixture: &Fixture, name: &str, arguments: Value) -> Result<Value, String> {
    tools::call_tool(&fixture.ports, name, &arguments)
}

fn rpc(fixture: &Fixture, method: &str, params: Value) -> Value {
    handle_message(
        &json!({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}),
        &fixture.ports,
    )
    .into_value()
}

/// Decode the single text content block of a tools/call result.
fn content_text(response: &Value) -> String {
    response["result"]["content"][0]["text"]
        .as_str()
        .expect("text content")
        .to_string()
}

fn content_json(response: &Value) -> Value {
    serde_json::from_str(&content_text(response)).expect("content is JSON")
}

// ---------------------------------------------------------------------------
// Minimal loopback HTTP client
// ---------------------------------------------------------------------------

struct HttpResponse {
    status: u16,
    body: String,
}

fn http_request(
    port: u16,
    request_line: &str,
    extra_headers: &[(&str, &str)],
    body: &str,
    close: bool,
) -> HttpResponse {
    let mut stream = TcpStream::connect(("127.0.0.1", port)).expect("connect");
    stream
        .set_read_timeout(Some(Duration::from_secs(5)))
        .unwrap();
    let mut request = format!(
        "{request_line} HTTP/1.1\r\nHost: 127.0.0.1:{port}\r\nContent-Length: {}\r\n",
        body.len()
    );
    if close {
        request.push_str("Connection: close\r\n");
    }
    for (key, value) in extra_headers {
        request.push_str(&format!("{key}: {value}\r\n"));
    }
    request.push_str("\r\n");
    request.push_str(body);
    stream.write_all(request.as_bytes()).expect("write");
    let mut raw = Vec::new();
    stream.read_to_end(&mut raw).expect("read to end");
    let text = String::from_utf8_lossy(&raw).to_string();
    let (head, body) = text.split_once("\r\n\r\n").expect("response split");
    let status = head
        .lines()
        .next()
        .and_then(|line| line.split_whitespace().nth(1))
        .and_then(|code| code.parse().ok())
        .expect("status code");
    HttpResponse {
        status,
        body: body.to_string(),
    }
}

fn post_json(port: u16, path: &str, body: &str) -> HttpResponse {
    http_request(
        port,
        &format!("POST {path}"),
        &[("Content-Type", "application/json")],
        body,
        true,
    )
}

struct SseClient {
    stream: TcpStream,
    buffer: String,
}

impl SseClient {
    fn connect(port: u16) -> (Self, u16, HashMap<String, String>) {
        let mut client = Self::connect_socket(port);
        client.write("GET /mcp/sse", &[("Accept", "text/event-stream")]);
        client.read_response_head()
    }

    fn connect_authenticated(port: u16, bearer: &str) -> (Self, u16, HashMap<String, String>) {
        let mut client = Self::connect_socket(port);
        client.write(
            "GET /mcp/sse",
            &[("Accept", "text/event-stream"), ("Authorization", bearer)],
        );
        client.read_response_head()
    }

    fn connect_socket(port: u16) -> Self {
        let stream = TcpStream::connect(("127.0.0.1", port)).expect("connect");
        stream
            .set_read_timeout(Some(Duration::from_secs(5)))
            .expect("read timeout");
        Self {
            stream,
            buffer: String::new(),
        }
    }

    fn read_response_head(mut self) -> (Self, u16, HashMap<String, String>) {
        let head = self.read_until("\r\n\r\n");
        let headers = head
            .lines()
            .filter_map(|line| {
                line.split_once(": ")
                    .map(|(key, value)| (key.to_ascii_lowercase(), value.trim().to_string()))
            })
            .collect::<HashMap<_, _>>();
        let status = head
            .lines()
            .next()
            .and_then(|line| line.split_whitespace().nth(1))
            .and_then(|code| code.parse().ok())
            .expect("status");
        (self, status, headers)
    }

    fn write(&mut self, request_line: &str, extra_headers: &[(&str, &str)]) {
        let port = self.stream.peer_addr().unwrap().port();
        let mut request = format!("{request_line} HTTP/1.1\r\nHost: 127.0.0.1:{port}\r\n");
        for (key, value) in extra_headers {
            request.push_str(&format!("{key}: {value}\r\n"));
        }
        request.push_str("\r\n");
        self.stream.write_all(request.as_bytes()).expect("write");
    }

    fn read_more(&mut self) {
        let mut chunk = [0_u8; 4096];
        let read = self.stream.read(&mut chunk).expect("read");
        if read == 0 {
            panic!("SSE stream ended unexpectedly");
        }
        self.buffer
            .push_str(&String::from_utf8_lossy(&chunk[..read]));
    }

    fn read_until(&mut self, marker: &str) -> String {
        while !self.buffer.contains(marker) {
            self.read_more();
        }
        let (head, _) = self.buffer.split_once(marker).expect("marker");
        let consumed = head.len() + marker.len();
        let head = head.to_string();
        self.buffer.drain(..consumed);
        head
    }

    /// Reads one `event:`/`data:` frame.
    fn next_event(&mut self) -> (String, String) {
        let frame = self.read_until("\n\n");
        let mut event = String::new();
        let mut data = String::new();
        for line in frame.lines() {
            if let Some(value) = line.strip_prefix("event: ") {
                event = value.to_string();
            } else if let Some(value) = line.strip_prefix("data: ") {
                data = value.to_string();
            }
        }
        (event, data)
    }
}

fn loopback(port: u16) -> SocketAddr {
    SocketAddr::from(([127, 0, 0, 1], port))
}

fn start_server(fixture: &Fixture) -> (Arc<McpServer>, u16) {
    let server = Arc::new(McpServer::new(Arc::new(fixture.ports.clone()), None));
    match server.start(loopback(0)).expect("start") {
        McpServerStatus::Running { address } => (server, address.port()),
        other => panic!("expected running server, got {other:?}"),
    }
}

// ---------------------------------------------------------------------------
// Protocol tests — mirror test/trenino/mcp/server_test.exs
// ---------------------------------------------------------------------------

#[test]
fn initialize_returns_server_info_and_capabilities() {
    // Mirrors: server_test.exs "initialize returns server info and capabilities"
    let fixture = fixture();
    let response = rpc(&fixture, "initialize", json!({}));
    assert_eq!(response["jsonrpc"], "2.0");
    assert_eq!(response["id"], 1);
    assert_eq!(response["result"]["serverInfo"]["name"], "Trenino");
    assert_eq!(response["result"]["capabilities"]["tools"], json!({}));
    assert_eq!(response["result"]["protocolVersion"], PROTOCOL_VERSION);
    assert!(response["result"]["serverInfo"]["version"].is_string());
}

#[test]
fn notifications_initialized_returns_null_result() {
    // Mirrors: server_test.exs "notifications/initialized returns ok"
    let fixture = fixture();
    let response = handle_message(
        &json!({"jsonrpc": "2.0", "method": "notifications/initialized", "params": {}}),
        &fixture.ports,
    );
    match response {
        MessageOutcome::Reply(value) => assert!(value["result"].is_null()),
        other => panic!("expected reply, got {other:?}"),
    }
}

#[test]
fn tools_list_returns_exact_tool_set_and_count() {
    // Mirrors: tool_registry_test.exs "returns all 47 tools",
    // server_test.exs "tools/list returns tool definitions"
    let fixture = fixture();
    let response = rpc(&fixture, "tools/list", json!({}));
    let tools = response["result"]["tools"].as_array().expect("tools");
    assert_eq!(tools.len(), 47);
    let names: Vec<&str> = tools
        .iter()
        .map(|tool| tool["name"].as_str().unwrap())
        .collect();
    assert_eq!(
        names,
        vec![
            // SimulatorTools
            "list_simulator_endpoints",
            "get_simulator_value",
            "set_simulator_value",
            // TrainTools
            "list_trains",
            "get_train",
            // ElementTools
            "list_elements",
            "create_element",
            "delete_element",
            // DeviceTools
            "list_devices",
            "list_device_inputs",
            "list_hardware_outputs",
            "list_i2c_modules",
            "create_i2c_module",
            "update_i2c_module",
            "delete_i2c_module",
            // OutputBindingTools
            "list_output_bindings",
            "create_output_binding",
            "update_output_binding",
            "delete_output_binding",
            // ButtonBindingTools
            "get_button_binding",
            "create_button_binding",
            "update_button_binding",
            "delete_button_binding",
            // SequenceTools
            "list_sequences",
            "create_sequence",
            "update_sequence",
            "delete_sequence",
            // ScriptTools
            "list_scripts",
            "get_script",
            "create_script",
            "update_script",
            "delete_script",
            // DetectionTools
            "detect_hardware_input",
            // DisplayBindingTools
            "list_display_bindings",
            "create_display_binding",
            "update_display_binding",
            "delete_display_binding",
            // VirtualJoystickTools
            "get_virtual_joystick_status",
            "list_virtual_joystick_mappings",
            "map_virtual_joystick_axis",
            "map_virtual_joystick_button",
            "delete_virtual_joystick_mapping",
            "enable_virtual_joystick",
            "disable_virtual_joystick",
            "retry_virtual_joystick",
            "cleanup_virtual_joystick",
            "check_virtual_joystick_installation",
        ]
    );
    // Uniqueness — mirrors tool_registry_test.exs "tool names are unique"
    let mut unique = names.clone();
    unique.sort_unstable();
    unique.dedup();
    assert_eq!(unique.len(), 47);
}

#[test]
fn tools_list_definitions_have_required_fields() {
    // Mirrors: server_test.exs "tools/list tool definitions have required fields"
    let fixture = fixture();
    let response = rpc(&fixture, "tools/list", json!({}));
    for tool in response["result"]["tools"].as_array().unwrap() {
        assert!(tool["name"].is_string(), "name missing in {tool}");
        assert!(
            tool["description"].is_string(),
            "description missing in {tool}"
        );
        assert!(
            tool["inputSchema"].is_object(),
            "inputSchema missing in {tool}"
        );
    }
}

#[test]
fn vjoy_schemas_are_strict() {
    // Mirrors: virtual_joystick_tools_test.exs
    // "publishes strict schemas without command or path parameters"
    let fixture = fixture();
    let response = rpc(&fixture, "tools/list", json!({}));
    let tools: HashMap<&str, &Value> = response["result"]["tools"]
        .as_array()
        .unwrap()
        .iter()
        .map(|tool| (tool["name"].as_str().unwrap(), tool))
        .collect();
    let axis = &tools["map_virtual_joystick_axis"]["inputSchema"];
    assert_eq!(
        axis["properties"]["axis"]["enum"],
        json!(["x", "y", "z", "rx", "ry", "rz", "slider_1", "slider_2"])
    );
    assert_eq!(axis["properties"]["device_index"]["enum"], json!([1]));
    assert_eq!(axis["required"], json!(["input_id", "axis"]));
    assert_eq!(axis["additionalProperties"], false);
    let button = &tools["map_virtual_joystick_button"]["inputSchema"];
    assert_eq!(
        button["properties"]["button"],
        json!({"type": "integer", "minimum": 1, "maximum": 32})
    );
    assert_eq!(button["additionalProperties"], false);
    let vjoy_names = [
        "get_virtual_joystick_status",
        "list_virtual_joystick_mappings",
        "map_virtual_joystick_axis",
        "map_virtual_joystick_button",
        "delete_virtual_joystick_mapping",
        "enable_virtual_joystick",
        "disable_virtual_joystick",
        "retry_virtual_joystick",
        "cleanup_virtual_joystick",
        "check_virtual_joystick_installation",
    ];
    assert!(!tools.contains_key("repair_virtual_joystick"));
    for name in vjoy_names {
        let tool = &tools[name];
        let properties = &tool["inputSchema"]["properties"];
        assert!(properties.get("path").is_none(), "{name} has path");
        assert!(properties.get("command").is_none(), "{name} has command");
    }
}

#[test]
fn ping_returns_empty_result() {
    // Mirrors: server_test.exs "ping returns empty result"
    let fixture = fixture();
    let response = rpc(&fixture, "ping", json!({}));
    assert_eq!(response["result"], json!({}));
}

#[test]
fn unknown_method_returns_method_not_found() {
    // Mirrors: server_test.exs "unknown method returns error"
    let fixture = fixture();
    let response = handle_message(
        &json!({"jsonrpc": "2.0", "id": 4, "method": "unknown/method", "params": {}}),
        &fixture.ports,
    );
    match response {
        MessageOutcome::Error(value) => {
            assert_eq!(value["error"]["code"], -32601);
            assert!(value["error"]["message"]
                .as_str()
                .unwrap()
                .contains("Method not found"));
        }
        other => panic!("expected error, got {other:?}"),
    }
}

#[test]
fn invalid_request_returns_error() {
    // Mirrors: server_test.exs "invalid request returns error"
    let fixture = fixture();
    let response = handle_message(&json!({"invalid": true}), &fixture.ports);
    match response {
        MessageOutcome::Error(value) => assert_eq!(value["error"]["code"], -32600),
        other => panic!("expected error, got {other:?}"),
    }
}

#[test]
fn tools_call_with_missing_params_returns_invalid_params() {
    // Mirrors: server_test.exs "tools/call with missing params returns error"
    let fixture = fixture();
    let response = handle_message(
        &json!({"jsonrpc": "2.0", "id": 5, "method": "tools/call", "params": {}}),
        &fixture.ports,
    );
    match response {
        MessageOutcome::Error(value) => assert_eq!(value["error"]["code"], -32602),
        other => panic!("expected error, got {other:?}"),
    }
}

#[test]
fn tools_call_dispatches_and_returns_content() {
    // Mirrors: server_test.exs "tools/call dispatches to tool and returns content"
    let fixture = fixture();
    let response = rpc(
        &fixture,
        "tools/call",
        json!({"name": "list_trains", "arguments": {}}),
    );
    assert_eq!(response["result"]["content"][0]["type"], "text");
    assert_eq!(content_json(&response), json!({"trains": []}));
}

#[test]
fn tools_call_with_unknown_tool_returns_error_content() {
    // Mirrors: server_test.exs "tools/call with unknown tool returns error content"
    let fixture = fixture();
    let response = rpc(
        &fixture,
        "tools/call",
        json!({"name": "nonexistent_tool", "arguments": {}}),
    );
    assert_eq!(response["result"]["isError"], true);
    assert!(
        content_text(&response).contains("Unknown tool"),
        "unexpected content: {}",
        content_text(&response)
    );
}

// ---------------------------------------------------------------------------
// Trains + elements — mirror train_tools_test.exs and element_tools_test.exs
// ---------------------------------------------------------------------------

fn seeded_train() -> TrainDetail {
    TrainDetail {
        train: TrainSummary {
            id: 3,
            name: "MCP Train".to_string(),
            identifiers: vec!["Class 350".to_string(), "DT".to_string()],
            description: Some("Test train".to_string()),
        },
        elements: vec![ElementRecord {
            id: 11,
            name: "Horn".to_string(),
            element_type: ElementType::Button,
        }],
        output_bindings: vec![OutputBindingRecord {
            id: 21,
            train_id: 3,
            name: "Brake warning".to_string(),
            output_id: 5,
            endpoint: "AWS.Function.IsWarningSound".to_string(),
            operator: BindingOperator::EqTrue,
            value_a: None,
            value_b: None,
            enabled: true,
        }],
        button_bindings: vec![ButtonBindingRecord {
            id: 31,
            element_id: 11,
            input_id: 7,
            mode: ButtonMode::Simple,
            endpoint: Some("Horn.InputValue".to_string()),
            on_value: 1.0,
            off_value: 0.0,
            enabled: true,
            hardware_type: HardwareType::Momentary,
            keystroke: None,
            repeat_interval_ms: 100,
            on_sequence_id: None,
            off_sequence_id: None,
        }],
        sequences: vec![SequenceRecord {
            id: 41,
            train_id: 3,
            name: "Startup".to_string(),
            commands: vec![SequenceCommandRecord {
                id: 51,
                position: 0,
                endpoint: "Battery.InputValue".to_string(),
                value: 1.0,
                delay_ms: 0,
            }],
        }],
    }
}

#[test]
fn trains_port_tools_list_and_get_payloads() {
    // Mirrors: train_tools_test.exs list/get assertions
    let fixture = fixture();
    *fixture.trains.detail.lock().unwrap() = Some(seeded_train());

    let listed = call(&fixture, "list_trains", json!({})).unwrap();
    assert_eq!(
        listed,
        json!({
            "trains": [{
                "id": 3,
                "name": "MCP Train",
                "identifiers": ["Class 350", "DT"],
                "description": "Test train",
            }]
        })
    );

    let detail = call(&fixture, "get_train", json!({"train_id": 3})).unwrap();
    let train = &detail["train"];
    assert_eq!(train["id"], 3);
    assert_eq!(train["identifiers"], json!(["Class 350", "DT"]));
    assert_eq!(
        train["elements"],
        json!([{"id": 11, "name": "Horn", "type": "button"}])
    );
    // Train view serializers omit train_id (mirror of TrainTools serializers).
    assert_eq!(
        train["output_bindings"],
        json!([{
            "id": 21,
            "name": "Brake warning",
            "endpoint": "AWS.Function.IsWarningSound",
            "operator": "eq_true",
            "output_id": 5,
            "value_a": null,
            "value_b": null,
            "enabled": true,
        }])
    );
    assert_eq!(
        train["button_bindings"][0],
        json!({
            "id": 31,
            "element_id": 11,
            "input_id": 7,
            "mode": "simple",
            "endpoint": "Horn.InputValue",
            "on_value": 1.0,
            "off_value": 0.0,
            "enabled": true,
            "hardware_type": "momentary",
            "keystroke": null,
            "repeat_interval_ms": 100,
            "on_sequence_id": null,
            "off_sequence_id": null,
        })
    );
    let sequence = &train["sequences"][0];
    assert_eq!(sequence["name"], "Startup");
    assert!(sequence.get("train_id").is_none());
    assert_eq!(
        sequence["commands"],
        json!([{
            "id": 51, "position": 0,
            "endpoint": "Battery.InputValue", "value": 1.0, "delay_ms": 0
        }])
    );
}

#[test]
fn trains_port_get_train_not_found() {
    // Mirrors: train_tools_test.exs get_train with missing id
    let fixture = fixture();
    let error = call(&fixture, "get_train", json!({"train_id": 99})).unwrap_err();
    assert_eq!(error, "Train not found with id 99");
}

#[test]
fn element_tools_crud_and_errors() {
    // Mirrors: element_tools_test.exs
    let fixture = fixture();
    *fixture.trains.detail.lock().unwrap() = Some(seeded_train());

    let created = call(
        &fixture,
        "create_element",
        json!({"train_id": 3, "name": "Throttle", "type": "lever"}),
    )
    .unwrap();
    assert_eq!(
        created,
        json!({"element": {"id": 1, "name": "Throttle", "type": "lever"}})
    );

    let listed = call(&fixture, "list_elements", json!({"train_id": 3})).unwrap();
    assert_eq!(listed["elements"].as_array().unwrap().len(), 2);

    let deleted = call(&fixture, "delete_element", json!({"id": 11})).unwrap();
    assert_eq!(deleted, json!({"deleted": true, "id": 11}));

    let error = call(&fixture, "delete_element", json!({"id": 404})).unwrap_err();
    assert_eq!(error, "Element not found with id 404");

    // Validation failure text — mirrors format_changeset_errors.
    *fixture.trains.create_error.lock().unwrap() = Some(PortError::Validation(vec![(
        "name".to_string(),
        vec!["can't be blank".to_string()],
    )]));
    let error = call(
        &fixture,
        "create_element",
        json!({"train_id": 3, "name": "", "type": "button"}),
    )
    .unwrap_err();
    assert_eq!(error, "Validation failed: name can't be blank");

    // Missing required argument (Elixir raises FunctionClauseError → 500;
    // Rust returns a tool error — documented deviation).
    let error = call(
        &fixture,
        "create_element",
        json!({"train_id": 3, "name": "x"}),
    )
    .unwrap_err();
    assert!(error.contains("Missing required argument: type"), "{error}");

    let error = call(
        &fixture,
        "create_element",
        json!({"train_id": 3, "name": "x", "type": "dial"}),
    )
    .unwrap_err();
    assert!(error.contains("must be 'button' or 'lever'"), "{error}");
}

// ---------------------------------------------------------------------------
// Hardware — mirror device_tools_test.exs
// ---------------------------------------------------------------------------

#[test]
fn hardware_tools_list_payloads() {
    // Mirrors: device_tools_test.exs list assertions
    let fixture = fixture();
    *fixture.hardware.devices.lock().unwrap() = vec![DeviceSummary {
        id: 1,
        name: "Arduino".to_string(),
    }];
    *fixture.hardware.inputs.lock().unwrap() = vec![InputRecord {
        id: 4,
        name: "Horn button".to_string(),
        pin: 2,
        input_type: InputType::Button,
    }];
    *fixture.hardware.outputs.lock().unwrap() = vec![HardwareOutputRecord {
        id: 9,
        name: "Brake LED".to_string(),
        pin: 5,
        device_id: 1,
        device_name: "Arduino".to_string(),
    }];

    assert_eq!(
        call(&fixture, "list_devices", json!({})).unwrap(),
        json!({"devices": [{"id": 1, "name": "Arduino"}]})
    );
    assert_eq!(
        call(&fixture, "list_device_inputs", json!({"device_id": 1})).unwrap(),
        json!({"inputs": [{"id": 4, "name": "Horn button", "pin": 2, "input_type": "button"}]})
    );
    assert_eq!(
        call(&fixture, "list_hardware_outputs", json!({})).unwrap(),
        json!({"outputs": [{
            "id": 9, "name": "Brake LED", "pin": 5,
            "device_name": "Arduino", "device_id": 1
        }]})
    );
}

#[test]
fn i2c_module_tools_crud_and_address_parsing() {
    // Mirrors: device_tools_test.exs i2c assertions (address parsing and
    // display formatting).
    let fixture = fixture();

    let created = call(
        &fixture,
        "create_i2c_module",
        json!({"device_id": 1, "module_chip": "ht16k33", "i2c_address": "0x70", "name": "Speed"}),
    )
    .unwrap();
    assert_eq!(created["i2c_module"]["i2c_address"], 112);
    assert_eq!(created["i2c_module"]["i2c_address_display"], "112 (0x70)");
    assert_eq!(created["i2c_module"]["device_name"], "Main device");
    assert_eq!(created["i2c_module"]["brightness"], 8);
    assert_eq!(created["i2c_module"]["num_digits"], 4);
    assert_eq!(created["i2c_module"]["display_type"], "fourteen_segment");
    assert_eq!(created["i2c_module"]["has_dot"], false);
    assert_eq!(created["i2c_module"]["align_right"], true);
    assert_eq!(created["i2c_module"]["min_value"], 0.0);

    // Decimal addresses and update/delete flows.
    let created = call(
        &fixture,
        "create_i2c_module",
        json!({"device_id": 1, "module_chip": "ht16k33", "i2c_address": "112"}),
    )
    .unwrap();
    let id = created["i2c_module"]["id"].as_i64().unwrap();

    let updated = call(
        &fixture,
        "update_i2c_module",
        json!({"id": id, "brightness": 15, "num_digits": 8}),
    )
    .unwrap();
    assert_eq!(updated["i2c_module"]["brightness"], 15);
    assert_eq!(updated["i2c_module"]["num_digits"], 8);

    let deleted = call(&fixture, "delete_i2c_module", json!({"id": id})).unwrap();
    assert_eq!(deleted, json!({"deleted": true, "id": id}));
    let error = call(&fixture, "delete_i2c_module", json!({"id": id})).unwrap_err();
    assert_eq!(error, format!("I2C module not found with id {id}"));

    let listed = call(&fixture, "list_i2c_modules", json!({})).unwrap();
    assert_eq!(listed["i2c_modules"].as_array().unwrap().len(), 1);
}

#[test]
fn i2c_address_rejection_cases() {
    // Mirrors: I2cModule.parse_i2c_address oracle semantics (decimal/hex,
    // full-string parse, 0..=255).
    let fixture = fixture();
    for bad in ["abc", "300", "0x100", "0x", "70.0", " 70", "-1"] {
        let error = call(
            &fixture,
            "create_i2c_module",
            json!({"device_id": 1, "module_chip": "ht16k33", "i2c_address": bad}),
        )
        .unwrap_err();
        assert_eq!(
            error,
            "Invalid i2c_address: use decimal (112) or hex (0x70)"
        );
    }

    // Validation passthrough ("Validation failed: ...").
    *fixture.hardware.create_error.lock().unwrap() = Some(PortError::Validation(vec![(
        "module_chip".to_string(),
        vec!["is invalid".to_string()],
    )]));
    let error = call(
        &fixture,
        "create_i2c_module",
        json!({"device_id": 1, "module_chip": "hd44780", "i2c_address": "112"}),
    )
    .unwrap_err();
    assert_eq!(error, "Validation failed: module_chip is invalid");
}

// ---------------------------------------------------------------------------
// Bindings — mirror output_binding_tools_test.exs, button_binding_tools_test.exs
// and display_binding_tools_test.exs
// ---------------------------------------------------------------------------

#[test]
fn output_binding_tools_crud() {
    // Mirrors: output_binding_tools_test.exs
    let fixture = fixture();

    let created = call(
        &fixture,
        "create_output_binding",
        json!({
            "train_id": 3,
            "name": "Brake warning LED",
            "output_id": 9,
            "endpoint": "AWS.Function.IsWarningSound",
            "operator": "eq_true"
        }),
    )
    .unwrap();
    assert_eq!(
        created["output_binding"],
        json!({
            "id": 1,
            "train_id": 3,
            "name": "Brake warning LED",
            "output_id": 9,
            "endpoint": "AWS.Function.IsWarningSound",
            "operator": "eq_true",
            "value_a": null,
            "value_b": null,
            "enabled": true,
        })
    );

    let listed = call(&fixture, "list_output_bindings", json!({"train_id": 3})).unwrap();
    assert_eq!(listed["output_bindings"].as_array().unwrap().len(), 1);

    let updated = call(
        &fixture,
        "update_output_binding",
        json!({"id": 1, "name": "Renamed", "value_a": 0.5, "enabled": false}),
    )
    .unwrap();
    assert_eq!(updated["output_binding"]["name"], "Renamed");
    assert_eq!(updated["output_binding"]["value_a"], 0.5);
    assert_eq!(updated["output_binding"]["enabled"], false);

    let deleted = call(&fixture, "delete_output_binding", json!({"id": 1})).unwrap();
    assert_eq!(deleted, json!({"deleted": true, "id": 1}));
    let error = call(&fixture, "delete_output_binding", json!({"id": 1})).unwrap_err();
    assert_eq!(error, "Output binding not found with id 1");

    let error = call(
        &fixture,
        "create_output_binding",
        json!({"train_id": 3, "output_id": 9, "endpoint": "x", "operator": "gt"}),
    )
    .unwrap_err();
    assert_eq!(error, "Validation failed: name can't be blank");

    let error = call(
        &fixture,
        "create_output_binding",
        json!({"train_id": 3, "name": "x", "output_id": 9, "endpoint": "e", "operator": "near"}),
    )
    .unwrap_err();
    assert!(error.contains("operator"), "{error}");
}

#[test]
fn button_binding_tools_crud_and_conflict() {
    // Mirrors: button_binding_tools_test.exs
    let fixture = fixture();

    let created = call(
        &fixture,
        "create_button_binding",
        json!({"element_id": 11, "input_id": 7, "mode": "keystroke", "keystroke": "CTRL+S"}),
    )
    .unwrap();
    assert_eq!(created["button_binding"]["mode"], "keystroke");
    assert_eq!(created["button_binding"]["keystroke"], "CTRL+S");
    assert_eq!(created["button_binding"]["on_value"], 1.0);

    let fetched = call(&fixture, "get_button_binding", json!({"element_id": 11})).unwrap();
    assert_eq!(
        fetched["button_binding"]["id"],
        created["button_binding"]["id"]
    );

    let updated = call(
        &fixture,
        "update_button_binding",
        json!({"element_id": 11, "mode": "momentary", "repeat_interval_ms": 250}),
    )
    .unwrap();
    assert_eq!(updated["button_binding"]["mode"], "momentary");
    assert_eq!(updated["button_binding"]["repeat_interval_ms"], 250);

    let deleted = call(&fixture, "delete_button_binding", json!({"element_id": 11})).unwrap();
    assert_eq!(deleted, json!({"deleted": true, "element_id": 11}));
    let error = call(&fixture, "delete_button_binding", json!({"element_id": 11})).unwrap_err();
    assert_eq!(error, "No button binding found for element 11");
    let error = call(&fixture, "get_button_binding", json!({"element_id": 12})).unwrap_err();
    assert_eq!(error, "No button binding found for element 12");

    // destination_conflict phrasing — mirrors button_binding_tools.ex
    // `{:error, :destination_conflict}` clause.
    fixture.bindings.conflict.store(true, Ordering::SeqCst);
    let error = call(
        &fixture,
        "create_button_binding",
        json!({"element_id": 11, "input_id": 7, "mode": "simple", "endpoint": "Horn.InputValue"}),
    )
    .unwrap_err();
    assert_eq!(
        error,
        "This input is assigned to the virtual joystick. Remove that mapping before enabling this binding."
    );

    // Changeset validation.
    *fixture.bindings.create_error.lock().unwrap() = Some(PortError::Validation(vec![(
        "mode".to_string(),
        vec!["is invalid".to_string()],
    )]));
    let error = call(
        &fixture,
        "create_button_binding",
        json!({"element_id": 11, "input_id": 7, "mode": "warp"}),
    )
    .unwrap_err();
    assert!(error.starts_with("Invalid argument: mode"), "{error}");
}

#[test]
fn display_binding_tools_crud() {
    // Mirrors: display_binding_tools_test.exs
    let fixture = fixture();

    let created = call(
        &fixture,
        "create_display_binding",
        json!({
            "train_id": 3,
            "name": "Train speed",
            "i2c_module_id": 1,
            "endpoint": "Speed.InputValue",
            "format_string": "{value:.0f}"
        }),
    )
    .unwrap();
    assert_eq!(
        created["display_binding"],
        json!({
            "id": 1,
            "train_id": 3,
            "i2c_module_id": 1,
            "name": "Train speed",
            "endpoint": "Speed.InputValue",
            "format_string": "{value:.0f}",
            "enabled": true,
        })
    );

    let listed = call(&fixture, "list_display_bindings", json!({"train_id": 3})).unwrap();
    assert_eq!(listed["display_bindings"].as_array().unwrap().len(), 1);

    let updated = call(
        &fixture,
        "update_display_binding",
        json!({"id": 1, "format_string": "{value:.1f}"}),
    )
    .unwrap();
    assert_eq!(updated["display_binding"]["format_string"], "{value:.1f}");

    let deleted = call(&fixture, "delete_display_binding", json!({"id": 1})).unwrap();
    assert_eq!(deleted, json!({"deleted": true, "id": 1}));
    let error = call(&fixture, "delete_display_binding", json!({"id": 1})).unwrap_err();
    assert_eq!(error, "Display binding not found with id 1");
}

// ---------------------------------------------------------------------------
// Sequences — mirror sequence_tools_test.exs
// ---------------------------------------------------------------------------

#[test]
fn sequence_tools_list_and_create_with_commands() {
    // Mirrors: sequence_tools_test.exs create assertions (positions, delay
    // default, values).
    let fixture = fixture();

    assert_eq!(
        call(&fixture, "list_sequences", json!({"train_id": 3})).unwrap(),
        json!({"sequences": []})
    );

    let created = call(
        &fixture,
        "create_sequence",
        json!({
            "train_id": 3,
            "name": "Startup",
            "commands": [
                {"endpoint": "Battery.InputValue", "value": 1.0, "delay_ms": 500},
                {"endpoint": "Lights.InputValue", "value": 0.0},
                {"endpoint": "Pantograph.InputValue", "value": 1.0, "delay_ms": 250}
            ]
        }),
    )
    .unwrap();
    let sequence = &created["sequence"];
    assert_eq!(sequence["name"], "Startup");
    assert_eq!(sequence["train_id"], 3);
    let commands = sequence["commands"].as_array().unwrap();
    assert_eq!(commands.len(), 3);
    assert_eq!(commands[0]["position"], 0);
    assert_eq!(commands[0]["delay_ms"], 500);
    assert_eq!(commands[1]["delay_ms"], 0);
    assert_eq!(commands[2]["position"], 2);

    assert_eq!(
        call(&fixture, "list_sequences", json!({"train_id": 3})).unwrap()["sequences"]
            .as_array()
            .unwrap()
            .len(),
        1
    );
}

#[test]
fn sequence_create_accepts_json_string_commands_and_empty_commands() {
    // Mirrors: commit 11a050d "handle commands parameter arriving as JSON
    // string in sequence tools" and the empty-commands test.
    let fixture = fixture();

    let created = call(
        &fixture,
        "create_sequence",
        json!({
            "train_id": 3,
            "name": "FromString",
            "commands": "[{\"endpoint\": \"A.InputValue\", \"value\": 2.0}]"
        }),
    )
    .unwrap();
    assert_eq!(created["sequence"]["commands"].as_array().unwrap().len(), 1);
    assert_eq!(
        created["sequence"]["commands"][0]["endpoint"],
        "A.InputValue"
    );

    let created = call(
        &fixture,
        "create_sequence",
        json!({"train_id": 3, "name": "Empty Sequence", "commands": []}),
    )
    .unwrap();
    assert_eq!(created["sequence"]["commands"], json!([]));

    let created = call(
        &fixture,
        "create_sequence",
        json!({"train_id": 3, "name": "No commands key"}),
    )
    .unwrap();
    assert_eq!(created["sequence"]["commands"], json!([]));
}

#[test]
fn sequence_tools_update_delete_and_errors() {
    // Mirrors: sequence_tools_test.exs update/delete/not-found/validation.
    let fixture = fixture();
    let created = call(
        &fixture,
        "create_sequence",
        json!({"train_id": 3, "name": "Startup", "commands": [
            {"endpoint": "A.InputValue", "value": 1.0},
            {"endpoint": "B.InputValue", "value": 1.0}
        ]}),
    )
    .unwrap();
    let id = created["sequence"]["id"].as_i64().unwrap();

    let updated = call(
        &fixture,
        "update_sequence",
        json!({"id": id, "name": "New Name"}),
    )
    .unwrap();
    assert_eq!(updated["sequence"]["name"], "New Name");
    assert_eq!(updated["sequence"]["commands"].as_array().unwrap().len(), 2);

    let updated = call(
        &fixture,
        "update_sequence",
        json!({"id": id, "commands": [{"endpoint": "New.Value", "value": 2.0}]}),
    )
    .unwrap();
    assert_eq!(updated["sequence"]["commands"].as_array().unwrap().len(), 1);
    assert_eq!(updated["sequence"]["commands"][0]["endpoint"], "New.Value");

    let deleted = call(&fixture, "delete_sequence", json!({"id": id})).unwrap();
    assert_eq!(deleted, json!({"deleted": true, "id": id}));
    let error = call(&fixture, "delete_sequence", json!({"id": id})).unwrap_err();
    assert_eq!(error, format!("Sequence not found with id {id}"));
    let error = call(&fixture, "update_sequence", json!({"id": 999})).unwrap_err();
    assert_eq!(error, "Sequence not found with id 999");

    let error = call(
        &fixture,
        "create_sequence",
        json!({"train_id": 3, "name": ""}),
    )
    .unwrap_err();
    assert_eq!(error, "Validation failed: name can't be blank");
}

#[test]
fn sequence_set_commands_failure_phrase() {
    // Mirrors: sequence_tools.ex `{:error, reason}` fallback
    // "Failed to set commands: ...".
    let fixture = fixture();
    let created = call(
        &fixture,
        "create_sequence",
        json!({"train_id": 3, "name": "Startup", "commands": []}),
    )
    .unwrap();
    let id = created["sequence"]["id"].as_i64().unwrap();
    *fixture.sequences.commands_error.lock().unwrap() = Some(PortError::Failed("boom".into()));
    let error = call(
        &fixture,
        "update_sequence",
        json!({"id": id, "commands": [{"endpoint": "A", "value": 1.0}]}),
    )
    .unwrap_err();
    assert_eq!(error, "Failed to set commands: boom");
}

// ---------------------------------------------------------------------------
// Scripts — mirror script_tools_test.exs
// ---------------------------------------------------------------------------

#[test]
fn script_tools_crud() {
    // Mirrors: script_tools_test.exs
    let fixture = fixture();

    assert_eq!(
        call(&fixture, "list_scripts", json!({"train_id": 3})).unwrap(),
        json!({"scripts": []})
    );

    let created = call(
        &fixture,
        "create_script",
        json!({
            "train_id": 3,
            "name": "Speed Warning",
            "code": "function on_change(event) end",
            "triggers": ["CurrentDrivableActor.Function.HUD_GetSpeed"],
            "enabled": false
        }),
    )
    .unwrap();
    assert_eq!(created["script"]["name"], "Speed Warning");
    assert_eq!(created["script"]["enabled"], false);
    assert_eq!(
        created["script"]["triggers"],
        json!(["CurrentDrivableActor.Function.HUD_GetSpeed"])
    );

    // Defaults: enabled true, triggers [] when omitted.
    let created = call(
        &fixture,
        "create_script",
        json!({"train_id": 3, "name": "Plain", "code": "return 1"}),
    )
    .unwrap();
    assert_eq!(created["script"]["enabled"], true);
    assert_eq!(created["script"]["triggers"], json!([]));
    let id = created["script"]["id"].as_i64().unwrap();

    // List summaries omit the code.
    let listed = call(&fixture, "list_scripts", json!({"train_id": 3})).unwrap();
    let summary = &listed["scripts"][0];
    assert!(summary.get("code").is_none());
    assert_eq!(summary["name"], "Speed Warning");

    let fetched = call(&fixture, "get_script", json!({"id": id})).unwrap();
    assert_eq!(fetched["script"]["code"], "return 1");

    let updated = call(
        &fixture,
        "update_script",
        json!({"id": id, "name": "New Name"}),
    )
    .unwrap();
    assert_eq!(updated["script"]["name"], "New Name");
    assert_eq!(updated["script"]["code"], "return 1");
    let updated = call(
        &fixture,
        "update_script",
        json!({"id": id, "triggers": ["NewEndpoint.Value"], "enabled": false}),
    )
    .unwrap();
    assert_eq!(updated["script"]["triggers"], json!(["NewEndpoint.Value"]));
    assert_eq!(updated["script"]["enabled"], false);

    let deleted = call(&fixture, "delete_script", json!({"id": id})).unwrap();
    assert_eq!(deleted, json!({"deleted": true, "id": id}));
    let error = call(&fixture, "get_script", json!({"id": id})).unwrap_err();
    assert_eq!(error, format!("Script not found with id {id}"));

    *fixture.scripts.create_error.lock().unwrap() = Some(PortError::Validation(vec![(
        "name".to_string(),
        vec!["can't be blank".to_string()],
    )]));
    let error = call(
        &fixture,
        "create_script",
        json!({"train_id": 3, "name": "", "code": "x"}),
    )
    .unwrap_err();
    assert_eq!(error, "Validation failed: name can't be blank");
}

// ---------------------------------------------------------------------------
// Simulator — mirror simulator_tools_test.exs
// ---------------------------------------------------------------------------

#[test]
fn simulator_tools_report_not_connected_and_pass_through() {
    // Mirrors: simulator_tools_test.exs
    let fixture = fixture();

    let not_connected = "Simulator not connected. Ensure Train Sim World is running with External Interface enabled.";
    assert_eq!(
        call(&fixture, "list_simulator_endpoints", json!({})).unwrap_err(),
        not_connected
    );
    assert_eq!(
        call(&fixture, "get_simulator_value", json!({"path": "A.B"})).unwrap_err(),
        not_connected
    );
    assert_eq!(
        call(
            &fixture,
            "set_simulator_value",
            json!({"path": "A.InputValue", "value": 1.0})
        )
        .unwrap_err(),
        not_connected
    );

    fixture.simulator.connected.store(true, Ordering::SeqCst);
    let listed = call(&fixture, "list_simulator_endpoints", json!({})).unwrap();
    assert_eq!(listed["Endpoints"], json!([]));
    // Omitted path means the root, empty string stays a path.
    call(&fixture, "list_simulator_endpoints", json!({"path": "AWS"})).unwrap();
    {
        let calls = fixture.simulator.calls.lock().unwrap();
        assert_eq!(calls[0].0, "list");
        assert_eq!(calls[0].1, "<root>");
        assert_eq!(calls[1].1, "AWS");
    }

    let value = call(&fixture, "get_simulator_value", json!({"path": "A.B"})).unwrap();
    assert_eq!(value, json!(1.0));

    *fixture.simulator.set_result.lock().unwrap() = Err("timeout".to_string());
    let error = call(
        &fixture,
        "set_simulator_value",
        json!({"path": "A.InputValue", "value": false}),
    )
    .unwrap_err();
    assert_eq!(error, "Simulator error: timeout");

    *fixture.simulator.get_result.lock().unwrap() = Err("not_found".to_string());
    let error = call(&fixture, "get_simulator_value", json!({"path": "X.Y"})).unwrap_err();
    assert_eq!(error, "Simulator error: not_found");
}

// ---------------------------------------------------------------------------
// Detection — mirror detection_tools_test.exs
// ---------------------------------------------------------------------------

#[test]
fn detection_tool_detected_and_timeout_payloads() {
    // Mirrors: detection_tools_test.exs
    let fixture = fixture();
    fixture
        .detection
        .scripted
        .lock()
        .unwrap()
        .push_back(DetectionOutcome::Detected(DetectedInput {
            input_id: 7,
            pin: 3,
            input_type: InputType::Analog,
            name: "Brake lever".to_string(),
            device_id: 1,
            device_name: "Arduino".to_string(),
            value: 128,
        }));

    let detected = call(
        &fixture,
        "detect_hardware_input",
        json!({"prompt": "Move the brake lever", "input_type": "analog", "timeout_ms": 1000}),
    )
    .unwrap();
    assert_eq!(
        detected,
        json!({
            "detected": true,
            "input": {
                "input_id": 7,
                "pin": 3,
                "input_type": "analog",
                "name": "Brake lever",
                "device_id": 1,
                "device_name": "Arduino",
                "value": 128,
            }
        })
    );

    let requests = fixture.detection.requests.lock().unwrap();
    assert_eq!(requests.len(), 1);
    assert_eq!(requests[0].prompt, "Move the brake lever");
    assert_eq!(requests[0].kind, DetectionKind::Analog);
    assert_eq!(requests[0].timeout_ms, 1000);
    drop(requests);

    // Unknown input_type falls back to Any; default timeout is 60s.
    fixture
        .detection
        .scripted
        .lock()
        .unwrap()
        .push_back(DetectionOutcome::Detected(DetectedInput {
            input_id: 8,
            pin: 4,
            input_type: InputType::Button,
            name: "Horn".to_string(),
            device_id: 1,
            device_name: "Arduino".to_string(),
            value: 1,
        }));
    call(
        &fixture,
        "detect_hardware_input",
        json!({"prompt": "Press a button"}),
    )
    .unwrap();
    {
        let requests = fixture.detection.requests.lock().unwrap();
        assert_eq!(requests[1].kind, DetectionKind::Any);
        assert_eq!(requests[1].timeout_ms, 60_000);
    }

    // Timeout path (short timeout so the fake actually waits).
    let timed_out = call(
        &fixture,
        "detect_hardware_input",
        json!({"prompt": "Press something", "timeout_ms": 20}),
    )
    .unwrap();
    assert_eq!(timed_out, json!({"detected": false, "reason": "timeout"}));

    let error = call(&fixture, "detect_hardware_input", json!({})).unwrap_err();
    assert!(
        error.contains("Missing required argument: prompt"),
        "{error}"
    );
}

// ---------------------------------------------------------------------------
// vJoy — mirror virtual_joystick_tools_test.exs
// ---------------------------------------------------------------------------

#[test]
fn vjoy_status_and_reason_shapes() {
    // Mirrors: virtual_joystick_tools_test.exs "reports unsupported status
    // and lifecycle commands structurally" + reason/1 clauses.
    let fixture = fixture();
    *fixture.vjoy.status.lock().unwrap() = VjoyStatusDetails {
        status: VjoyStatus::Unsupported,
        reason: None,
    };
    let status = call(&fixture, "get_virtual_joystick_status", json!({})).unwrap();
    assert_eq!(status, json!({"status": "unsupported", "reason": null}));

    *fixture.vjoy.status.lock().unwrap() = VjoyStatusDetails {
        status: VjoyStatus::RuntimeUnavailable,
        reason: Some(VjoyReason::Code("manager_unavailable".into())),
    };
    let status = call(&fixture, "get_virtual_joystick_status", json!({})).unwrap();
    assert_eq!(
        status,
        json!({"status": "runtime_unavailable", "reason": {"code": "manager_unavailable"}})
    );

    *fixture.vjoy.status.lock().unwrap() = VjoyStatusDetails {
        status: VjoyStatus::Degraded,
        reason: Some(VjoyReason::CodeWithDetails(
            "acquire_failed".into(),
            "%{} bridge".into(),
        )),
    };
    let status = call(&fixture, "get_virtual_joystick_status", json!({})).unwrap();
    assert_eq!(
        status["reason"],
        json!({"code": "acquire_failed", "details": "%{} bridge"})
    );
}

#[test]
fn vjoy_mapping_tools_and_structural_errors() {
    // Mirrors: virtual_joystick_tools_test.exs "mapping tools" describe block.
    let fixture = fixture();

    let mapped = call(
        &fixture,
        "map_virtual_joystick_axis",
        json!({"input_id": 1, "axis": "rx", "device_index": 1, "inverted": true}),
    )
    .unwrap();
    assert_eq!(mapped["status"], "ok");
    assert_eq!(mapped["reason"], Value::Null);
    assert_eq!(
        mapped["mapping"],
        json!({
            "id": 1, "input_id": 1, "device_index": 1, "target_type": "axis",
            "axis": "rx", "button": null, "inverted": true
        })
    );
    assert_eq!(fixture.vjoy.reloads.load(Ordering::SeqCst), 1);

    // Re-mapping the same input updates in place.
    let mapped = call(
        &fixture,
        "map_virtual_joystick_axis",
        json!({"input_id": 1, "axis": "slider_1"}),
    )
    .unwrap();
    assert_eq!(mapped["mapping"]["id"], 1);
    assert_eq!(mapped["mapping"]["axis"], "slider_1");
    assert_eq!(mapped["mapping"]["inverted"], false);
    assert_eq!(mapped["mapping"]["device_index"], 1);

    let mapped = call(
        &fixture,
        "map_virtual_joystick_button",
        json!({"input_id": 2, "button": 32}),
    )
    .unwrap();
    assert_eq!(mapped["mapping"]["target_type"], "button");
    assert_eq!(mapped["mapping"]["button"], 32);

    let listed = call(&fixture, "list_virtual_joystick_mappings", json!({})).unwrap();
    assert_eq!(listed["status"], "ok");
    assert!(listed.get("reason").is_none(), "no reason key in list");
    assert_eq!(listed["mappings"].as_array().unwrap().len(), 2);

    // destination_conflict / not_found are structural, never tool errors.
    *fixture.vjoy.put_error.lock().unwrap() = Some(VjoyPutError::DestinationConflict);
    let conflict = call(
        &fixture,
        "map_virtual_joystick_axis",
        json!({"input_id": 1, "axis": "x"}),
    )
    .unwrap();
    assert_eq!(
        conflict,
        json!({"status": "error", "reason": {"code": "destination_conflict"}})
    );

    let deleted = call(
        &fixture,
        "delete_virtual_joystick_mapping",
        json!({"id": 1}),
    )
    .unwrap();
    assert_eq!(
        deleted,
        json!({"status": "ok", "reason": null, "deleted": true, "id": 1})
    );
    let missing = call(
        &fixture,
        "delete_virtual_joystick_mapping",
        json!({"id": 1}),
    )
    .unwrap();
    assert_eq!(
        missing,
        json!({"status": "error", "reason": {"code": "not_found"}})
    );

    fixture
        .vjoy
        .put_error
        .lock()
        .unwrap()
        .replace(VjoyPutError::Validation(vec![(
            "target_type".to_string(),
            vec!["must target an axis".to_string()],
        )]));
    let validation = call(
        &fixture,
        "map_virtual_joystick_button",
        json!({"input_id": 9, "button": 1}),
    )
    .unwrap();
    assert_eq!(
        validation["reason"],
        json!({
            "code": "validation_failed",
            "errors": {"target_type": ["must target an axis"]}
        })
    );
}

#[test]
fn vjoy_lifecycle_tools() {
    // Mirrors: virtual_joystick_tools_test.exs "runtime tools" describe block.
    let fixture = fixture();

    let accepted = call(&fixture, "disable_virtual_joystick", json!({})).unwrap();
    assert_eq!(accepted, json!({"status": "accepted", "reason": null}));
    fixture
        .vjoy
        .lifecycle_results
        .lock()
        .unwrap()
        .push_back(Err(VjoyReason::Code("unsupported".into())));
    let rejected = call(&fixture, "enable_virtual_joystick", json!({})).unwrap();
    assert_eq!(
        rejected,
        json!({"status": "error", "reason": {"code": "unsupported"}})
    );
    fixture
        .vjoy
        .lifecycle_results
        .lock()
        .unwrap()
        .push_back(Err(VjoyReason::CodeWithDetails(
            "transition_in_progress".into(),
            "enable".into(),
        )));
    let rejected = call(&fixture, "retry_virtual_joystick", json!({})).unwrap();
    assert_eq!(
        rejected["reason"],
        json!({"code": "transition_in_progress", "details": "enable"})
    );

    for tool in [
        "cleanup_virtual_joystick",
        "check_virtual_joystick_installation",
    ] {
        let outcome = call(&fixture, tool, json!({})).unwrap();
        assert_eq!(outcome["status"], "accepted");
    }
}

#[test]
fn vjoy_argument_validation_rejects_without_raising() {
    // Mirrors: virtual_joystick_tools_test.exs "rejects missing, mistyped,
    // out-of-range, and extra mapping arguments without raising".
    let fixture = fixture();
    let cases = [
        (
            "map_virtual_joystick_axis",
            json!({"axis": "x"}),
            "input_id",
            "is required",
        ),
        (
            "map_virtual_joystick_axis",
            json!({"input_id": "1", "axis": "x"}),
            "input_id",
            "must be an integer",
        ),
        (
            "map_virtual_joystick_axis",
            json!({"input_id": 1, "axis": "pov"}),
            "axis",
            "must be a supported axis",
        ),
        (
            "map_virtual_joystick_axis",
            json!({"input_id": 1, "axis": "x", "device_index": 2}),
            "device_index",
            "must be the integer 1",
        ),
        (
            "map_virtual_joystick_axis",
            json!({"input_id": 1, "axis": "x", "device_index": 1.0}),
            "device_index",
            "must be the integer 1",
        ),
        (
            "map_virtual_joystick_axis",
            json!({"input_id": 1, "axis": "x", "inverted": 1}),
            "inverted",
            "must be a boolean",
        ),
        (
            "map_virtual_joystick_axis",
            json!({"input_id": 1, "axis": "x", "replace": "true"}),
            "replace",
            "must be a boolean",
        ),
        (
            "map_virtual_joystick_axis",
            json!({"input_id": 1, "axis": "x", "command": "cmd"}),
            "command",
            "is not allowed",
        ),
        (
            "map_virtual_joystick_button",
            json!({"button": 1}),
            "input_id",
            "is required",
        ),
        (
            "map_virtual_joystick_button",
            json!({"input_id": 1, "button": 0}),
            "button",
            "must be an integer from 1 to 32",
        ),
        (
            "map_virtual_joystick_button",
            json!({"input_id": 1, "button": 33}),
            "button",
            "must be an integer from 1 to 32",
        ),
        (
            "map_virtual_joystick_button",
            json!({"input_id": 1, "button": 1.0}),
            "button",
            "must be an integer from 1 to 32",
        ),
        (
            "map_virtual_joystick_button",
            json!({"input_id": 1, "button": 1, "device_index": 1.0}),
            "device_index",
            "must be the integer 1",
        ),
        (
            "map_virtual_joystick_button",
            json!({"input_id": 1, "button": 1, "replace": "false"}),
            "replace",
            "must be a boolean",
        ),
        (
            "map_virtual_joystick_button",
            json!({"input_id": 1, "button": 1, "extra": true}),
            "extra",
            "is not allowed",
        ),
        (
            "delete_virtual_joystick_mapping",
            json!({}),
            "id",
            "is required",
        ),
        (
            "delete_virtual_joystick_mapping",
            json!({"id": "1"}),
            "id",
            "must be an integer",
        ),
        (
            "delete_virtual_joystick_mapping",
            json!({"id": 1, "extra": true}),
            "extra",
            "is not allowed",
        ),
    ];
    for (tool, arguments, field, message) in cases {
        let outcome = call(&fixture, tool, arguments.clone()).unwrap();
        assert_eq!(outcome["status"], "error", "{tool} {arguments}");
        assert_eq!(
            outcome["reason"]["code"], "validation_failed",
            "{tool} {arguments}"
        );
        let errors = outcome["reason"]["errors"].as_array().unwrap();
        assert!(
            errors
                .iter()
                .any(|error| error["field"] == field && error["message"] == message),
            "{tool} {arguments} → {outcome}"
        );
    }

    // Non-object arguments.
    let outcome = call(&fixture, "map_virtual_joystick_axis", json!([1, "x"])).unwrap();
    assert_eq!(
        outcome["reason"]["errors"],
        json!([{"field": "arguments", "message": "must be an object"}])
    );
}

#[test]
fn vjoy_parameterless_tools_reject_any_arguments() {
    // Mirrors: virtual_joystick_tools_test.exs "rejects arguments for every
    // parameterless tool".
    let fixture = fixture();
    for tool in [
        "get_virtual_joystick_status",
        "list_virtual_joystick_mappings",
        "enable_virtual_joystick",
        "disable_virtual_joystick",
        "retry_virtual_joystick",
        "cleanup_virtual_joystick",
        "check_virtual_joystick_installation",
    ] {
        let outcome = call(&fixture, tool, json!({"extra": true})).unwrap();
        assert_eq!(outcome["reason"]["code"], "validation_failed", "{tool}");
        assert_eq!(
            outcome["reason"]["errors"],
            json!([{"field": "extra", "message": "is not allowed"}])
        );
    }
}

// ---------------------------------------------------------------------------
// HTTP transport — mirror mcp_controller_test.exs
// ---------------------------------------------------------------------------

#[test]
fn sse_sends_endpoint_event_and_delivers_messages() {
    // Mirrors: mcp_controller_test.exs "processes message and returns 202 for
    // valid session" plus the SSE handshake contract.
    let fixture = fixture();
    let (_server, port) = start_server(&fixture);

    let (mut client, status, headers) = SseClient::connect(port);
    assert_eq!(status, 200);
    assert_eq!(
        headers.get("content-type").map(String::as_str),
        Some("text/event-stream")
    );
    assert_eq!(
        headers.get("cache-control").map(String::as_str),
        Some("no-cache")
    );
    assert_eq!(
        headers
            .get("access-control-allow-origin")
            .map(String::as_str),
        Some("*")
    );

    let (event, data) = client.next_event();
    assert_eq!(event, "endpoint");
    assert!(data.starts_with(&format!("http://127.0.0.1:{port}/mcp/messages?session_id=")));
    let session_id = data
        .split("session_id=")
        .nth(1)
        .expect("session id")
        .to_string();

    let response = post_json(
        port,
        &format!("/mcp/messages?session_id={session_id}"),
        r#"{"jsonrpc": "2.0", "method": "ping", "id": 1}"#,
    );
    assert_eq!(response.status, 202);
    assert_eq!(response.body, "accepted");

    let (event, data) = client.next_event();
    assert_eq!(event, "message");
    let message: Value = serde_json::from_str(&data).expect("message JSON");
    assert_eq!(message["jsonrpc"], "2.0");
    assert_eq!(message["id"], 1);
    assert_eq!(message["result"], json!({}));
}

#[test]
fn messages_endpoint_status_errors() {
    // Mirrors: mcp_controller_test.exs "returns 400 when session_id is
    // missing" and "returns 404 when session is not found".
    let fixture = fixture();
    let (_server, port) = start_server(&fixture);

    let response = post_json(
        port,
        "/mcp/messages",
        r#"{"jsonrpc": "2.0", "method": "ping", "id": 1}"#,
    );
    assert_eq!(response.status, 400);
    assert!(response.body.contains("session_id"), "{}", response.body);

    let response = post_json(
        port,
        "/mcp/messages?session_id=nonexistent",
        r#"{"jsonrpc": "2.0", "method": "ping", "id": 1}"#,
    );
    assert_eq!(response.status, 404);
    assert!(
        response.body.contains("Session not found"),
        "{}",
        response.body
    );
}

#[test]
fn messages_endpoint_rejects_malformed_json() {
    // Phoenix parses the body before the controller; malformed JSON is a 400.
    let fixture = fixture();
    let (_server, port) = start_server(&fixture);
    let response = post_json(port, "/mcp/messages?session_id=x", "{not json");
    assert_eq!(response.status, 400);
}

#[test]
fn tools_list_and_call_flow_over_http() {
    // Mirrors: mcp_controller_test.exs "handles tools/list via POST" and
    // "handles tools/call via POST".
    let fixture = fixture();
    let (_server, port) = start_server(&fixture);
    let (mut client, _, _) = SseClient::connect(port);
    let (_, endpoint) = client.next_event();
    let session_id = endpoint.split("session_id=").nth(1).unwrap().to_string();

    let response = post_json(
        port,
        &format!("/mcp/messages?session_id={session_id}"),
        r#"{"jsonrpc": "2.0", "method": "tools/list", "id": 2, "params": {}}"#,
    );
    assert_eq!(response.status, 202);
    let (_, data) = client.next_event();
    let message: Value = serde_json::from_str(&data).unwrap();
    assert_eq!(message["result"]["tools"].as_array().unwrap().len(), 47);

    let response = post_json(
        port,
        &format!("/mcp/messages?session_id={session_id}"),
        r#"{"jsonrpc": "2.0", "method": "tools/call", "id": 3,
            "params": {"name": "list_trains", "arguments": {}}}"#,
    );
    assert_eq!(response.status, 202);
    let (_, data) = client.next_event();
    let message: Value = serde_json::from_str(&data).unwrap();
    let text = message["result"]["content"][0]["text"].as_str().unwrap();
    assert_eq!(
        serde_json::from_str::<Value>(text).unwrap(),
        json!({"trains": []})
    );
}

#[test]
fn error_responses_travel_over_sse() {
    // Mirrors: mcp_controller_test.exs "handles error responses via POST".
    let fixture = fixture();
    let (_server, port) = start_server(&fixture);
    let (mut client, _, _) = SseClient::connect(port);
    let (_, endpoint) = client.next_event();
    let session_id = endpoint.split("session_id=").nth(1).unwrap().to_string();

    let response = post_json(
        port,
        &format!("/mcp/messages?session_id={session_id}"),
        r#"{"jsonrpc": "2.0", "method": "unknown/method", "id": 4, "params": {}}"#,
    );
    assert_eq!(response.status, 202);
    let (_, data) = client.next_event();
    let message: Value = serde_json::from_str(&data).unwrap();
    assert_eq!(message["error"]["code"], -32601);
}

#[test]
fn concurrent_sessions_are_independent() {
    // Two SSE clients get their own sessions and only their own messages.
    let fixture = fixture();
    let (_server, port) = start_server(&fixture);
    let (mut first, _, _) = SseClient::connect(port);
    let (mut second, _, _) = SseClient::connect(port);
    let (_, first_endpoint) = first.next_event();
    let (_, second_endpoint) = second.next_event();
    let first_id = first_endpoint
        .split("session_id=")
        .nth(1)
        .unwrap()
        .to_string();
    let second_id = second_endpoint
        .split("session_id=")
        .nth(1)
        .unwrap()
        .to_string();
    assert_ne!(first_id, second_id);

    post_json(
        port,
        &format!("/mcp/messages?session_id={second_id}"),
        r#"{"jsonrpc": "2.0", "method": "ping", "id": 9}"#,
    );
    let (_, data) = second.next_event();
    let message: Value = serde_json::from_str(&data).unwrap();
    assert_eq!(message["id"], 9);
    // The first session stays silent: reading would block, so instead verify
    // a second message to the second session arrives promptly.
    post_json(
        port,
        &format!("/mcp/messages?session_id={second_id}"),
        r#"{"jsonrpc": "2.0", "method": "ping", "id": 10}"#,
    );
    let (_, data) = second.next_event();
    let message: Value = serde_json::from_str(&data).unwrap();
    assert_eq!(message["id"], 10);
    drop(first);
}

// ---------------------------------------------------------------------------
// Auth
// ---------------------------------------------------------------------------

#[test]
fn auth_is_open_without_a_configured_key() {
    // Default parity with the Elixir transport (local, unauthenticated).
    let fixture = fixture();
    let (_server, port) = start_server(&fixture);
    let (mut client, status, _) = SseClient::connect(port);
    assert_eq!(status, 200);
    let (_, endpoint) = client.next_event();
    let session_id = endpoint.split("session_id=").nth(1).unwrap().to_string();
    let response = post_json(
        port,
        &format!("/mcp/messages?session_id={session_id}"),
        r#"{"jsonrpc": "2.0", "method": "ping", "id": 1}"#,
    );
    assert_eq!(response.status, 202);
}

#[test]
fn auth_rejects_missing_or_wrong_bearer_tokens() {
    // Settings API-key gate: only a matching Bearer token is accepted.
    let fixture = fixture();
    let server = Arc::new(McpServer::new(
        Arc::new(fixture.ports.clone()),
        Some(Arc::new(FakeKey("s3cret".to_string()))),
    ));
    let port = match server.start(loopback(0)).unwrap() {
        McpServerStatus::Running { address } => address.port(),
        other => panic!("{other:?}"),
    };

    let sse = http_request(
        port,
        "GET /mcp/sse",
        &[("Accept", "text/event-stream")],
        "",
        true,
    );
    assert_eq!(sse.status, 401);

    let response = post_json(port, "/mcp/messages?session_id=x", "{}");
    assert_eq!(response.status, 401);

    let response = http_request(
        port,
        "POST /mcp/messages?session_id=x",
        &[
            ("Content-Type", "application/json"),
            ("Authorization", "Bearer wrong"),
        ],
        "{}",
        true,
    );
    assert_eq!(response.status, 401);

    // A matching token reaches the endpoints.
    let (mut client, status, _) = SseClient::connect_authenticated(port, "Bearer s3cret");
    assert_eq!(status, 200);
    let (_, endpoint) = client.next_event();
    let session_id = endpoint.split("session_id=").nth(1).unwrap().to_string();
    let response = http_request(
        port,
        &format!("POST /mcp/messages?session_id={session_id}"),
        &[
            ("Content-Type", "application/json"),
            ("Authorization", "Bearer s3cret"),
        ],
        r#"{"jsonrpc": "2.0", "method": "ping", "id": 1}"#,
        true,
    );
    assert_eq!(response.status, 202);
    let (_, data) = client.next_event();
    let message: Value = serde_json::from_str(&data).unwrap();
    assert_eq!(message["result"], json!({}));
}

// ---------------------------------------------------------------------------
// Lifecycle
// ---------------------------------------------------------------------------

#[test]
fn busy_port_is_degraded_not_fatal_and_retryable() {
    // Mirrors: remaining-work.md requirement "occupied external port should
    // not prevent startup" — degraded, retryable, never an app error.
    let fixture_a = fixture();
    let (server, port) = start_server(&fixture_a);
    let _ = server; // keep the port busy

    let fixture_b = fixture();
    let server_b = Arc::new(McpServer::new(Arc::new(fixture_b.ports.clone()), None));
    match server_b.start(loopback(port)).unwrap() {
        McpServerStatus::Degraded { reason } => {
            assert!(reason.contains("bind"), "{reason}");
        }
        other => panic!("expected degraded, got {other:?}"),
    }
    assert!(matches!(
        server_b.status(),
        McpServerStatus::Degraded { .. }
    ));

    // Double start while already attempting is rejected as a programming
    // error only after a successful bind — a degraded server may retry.
    server.stop().unwrap();
    match server_b.start(loopback(port)).unwrap() {
        McpServerStatus::Running { address } => assert_eq!(address.port(), port),
        other => panic!("expected running after retry, got {other:?}"),
    }
    let (mut client, status, _) = SseClient::connect(port);
    assert_eq!(status, 200);
    let (_, endpoint) = client.next_event();
    assert!(endpoint.contains(&format!("127.0.0.1:{port}")));
}

#[test]
fn start_while_running_is_rejected_and_stop_is_idempotent() {
    let fixture = fixture();
    let (server, port) = start_server(&fixture);
    let error = server.start(loopback(port)).unwrap_err();
    assert!(matches!(error, McpStartError::AlreadyRunning));
    server.stop().unwrap();
    server.stop().unwrap();
    assert_eq!(server.status(), McpServerStatus::Stopped);

    // Restart on the same port after stop.
    match server.start(loopback(port)).unwrap() {
        McpServerStatus::Running { address } => assert_eq!(address.port(), port),
        other => panic!("{other:?}"),
    }
    server.stop().unwrap();
}

#[test]
fn stop_ends_sse_streams_and_releases_the_port() {
    let fixture_a = fixture();
    let (server, port) = start_server(&fixture_a);
    let mut client = {
        let (client, _, _) = SseClient::connect(port);
        client
    };
    let (_, endpoint) = client.next_event();
    let session_id = endpoint.split("session_id=").nth(1).unwrap().to_string();

    // Session is live.
    let response = post_json(
        port,
        &format!("/mcp/messages?session_id={session_id}"),
        r#"{"jsonrpc": "2.0", "method": "ping", "id": 1}"#,
    );
    assert_eq!(response.status, 202);
    let _ = client.next_event();

    server.stop().unwrap();
    // The SSE stream terminates (EOF, not timeout).
    client
        .stream
        .set_read_timeout(Some(Duration::from_secs(5)))
        .unwrap();
    let mut sink = Vec::new();
    let ended = client.stream.read_to_end(&mut sink);
    assert!(ended.is_ok(), "SSE stream should close cleanly");

    // The port is released for another server.
    let fixture_b = fixture();
    let server_b = Arc::new(McpServer::new(Arc::new(fixture_b.ports.clone()), None));
    match server_b.start(loopback(port)).unwrap() {
        McpServerStatus::Running { address } => assert_eq!(address.port(), port),
        other => panic!("{other:?}"),
    }
    server_b.stop().unwrap();
}

#[test]
fn server_participates_in_ordered_shutdown() {
    // The server registers as a ShutdownParticipant; the coordinator closes
    // its network in the final phase.
    let fixture_a = fixture();
    let (server, port) = start_server(&fixture_a);
    let coordinator = ShutdownCoordinator::default();
    coordinator.register(server.clone()).unwrap();
    coordinator.shutdown(|| Ok(())).unwrap();

    assert_eq!(server.status(), McpServerStatus::Stopped);
    // After shutdown the port is free again.
    let fixture_b = fixture();
    let replacement = Arc::new(McpServer::new(Arc::new(fixture_b.ports.clone()), None));
    assert!(matches!(
        replacement.start(loopback(port)).unwrap(),
        McpServerStatus::Running { .. }
    ));
    replacement.stop().unwrap();
}

#[test]
fn http_initialize_uses_the_desktop_supplied_application_version() {
    let fixture = fixture();
    let server = McpServer::new(Arc::new(fixture.ports.clone()), None).with_server_version("9.8.7");
    let port = match server.start(loopback(0)).unwrap() {
        McpServerStatus::Running { address } => address.port(),
        other => panic!("{other:?}"),
    };
    let (mut client, _, _) = SseClient::connect(port);
    let (_, endpoint) = client.next_event();
    let session = endpoint.split("session_id=").nth(1).unwrap();
    assert_eq!(
        post_json(
            port,
            &format!("/mcp/messages?session_id={session}"),
            r#"{"jsonrpc":"2.0","method":"initialize","id":1}"#
        )
        .status,
        202
    );
    let (_, data) = client.next_event();
    let message: Value = serde_json::from_str(&data).unwrap();
    assert_eq!(message["result"]["serverInfo"]["version"], "9.8.7");
    drop(client);
    server.stop().unwrap();
}
