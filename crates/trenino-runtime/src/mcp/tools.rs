//! MCP tool definitions and dispatch, a port of `Trenino.MCP.ToolRegistry`
//! and the eleven `Trenino.MCP.Tools.*` modules.
//!
//! Tool names, descriptions, input schemas, result payload shapes and error
//! strings mirror the Elixir oracle exactly. Domain access goes through the
//! port traits in [`crate::mcp::ports`]; wave 2 wires them to real
//! repositories.
//!
//! One deliberate deviation: the Elixir tool modules pattern-match required
//! arguments, so calls missing them raise `FunctionClauseError` and the HTTP
//! layer dies with a 500. Here the same calls return a normal tool error
//! message instead (`Missing required argument: ...`), keeping the
//! JSON-RPC response valid for well-behaved clients.

use crate::mcp::ports::{
    BindingOperator, ButtonBindingAttrs, ButtonBindingRecord, ButtonMode, DetectionKind,
    DetectionOutcome, DetectionRequest, DisplayBindingAttrs, ElementType, HardwareType,
    I2cModuleAttrs, I2cModuleChanges, OutputBindingAttrs, PortError, Ports, ScriptAttrs,
    SequenceCommandDraft, SequenceRecord, VjoyCommand, VjoyMappingDraft, VjoyPutError, VjoyReason,
    VjoyStatusDetails, VjoyTarget, VJOY_AXES,
};
use serde_json::{json, Map, Value};

pub struct ToolDef {
    pub name: &'static str,
    pub description: &'static str,
    pub input_schema: Value,
}

/// Tool sections in `Trenino.MCP.ToolRegistry` order.
pub fn list_tools() -> Vec<ToolDef> {
    let mut tools = Vec::with_capacity(47);
    tools.extend(simulator::tools());
    tools.extend(train::tools());
    tools.extend(element::tools());
    tools.extend(device::tools());
    tools.extend(output_binding::tools());
    tools.extend(button_binding::tools());
    tools.extend(sequence::tools());
    tools.extend(script::tools());
    tools.extend(detection::tools());
    tools.extend(display_binding::tools());
    tools.extend(vjoy::tools());
    tools
}

type Handler = fn(&Ports, &str, &Value) -> Result<Value, String>;

/// Dispatch a tool call (`ToolRegistry.call_tool/2`).
pub fn call_tool(ports: &Ports, name: &str, arguments: &Value) -> Result<Value, String> {
    let handler = section_for(name).ok_or_else(|| format!("Unknown tool: {name}"))?;
    handler(ports, name, arguments)
}

fn section_for(name: &str) -> Option<Handler> {
    const SECTIONS: [(&[&str], Handler); 11] = [
        (&simulator::TOOL_NAMES, simulator::execute),
        (&train::TOOL_NAMES, train::execute),
        (&element::TOOL_NAMES, element::execute),
        (&device::TOOL_NAMES, device::execute),
        (&output_binding::TOOL_NAMES, output_binding::execute),
        (&button_binding::TOOL_NAMES, button_binding::execute),
        (&sequence::TOOL_NAMES, sequence::execute),
        (&script::TOOL_NAMES, script::execute),
        (&detection::TOOL_NAMES, detection::execute),
        (&display_binding::TOOL_NAMES, display_binding::execute),
        (&vjoy::TOOL_NAMES, vjoy::execute),
    ];
    SECTIONS
        .into_iter()
        .find(|(names, _)| names.contains(&name))
        .map(|(_, handler)| handler)
}

fn raw<'a>(arguments: &'a Value, key: &str) -> Option<&'a Value> {
    arguments.get(key).filter(|value| !value.is_null())
}

/// Ecto cast failure text used by the changeset tools.
fn invalid_type(field: &str) -> String {
    format_changeset_errors(&[(field.to_string(), vec!["is invalid".to_string()])])
}

fn req_i64(arguments: &Value, key: &str) -> Result<i64, String> {
    raw(arguments, key)
        .ok_or_else(|| format!("Missing required argument: {key}"))?
        .as_i64()
        .ok_or_else(|| invalid_type(key))
}

fn req_str<'a>(arguments: &'a Value, key: &str) -> Result<&'a str, String> {
    raw(arguments, key)
        .ok_or_else(|| format!("Missing required argument: {key}"))?
        .as_str()
        .ok_or_else(|| invalid_type(key))
}

fn opt_i64(arguments: &Value, key: &str) -> Result<Option<i64>, String> {
    raw(arguments, key)
        .map(|value| value.as_i64().ok_or_else(|| invalid_type(key)))
        .transpose()
}

fn opt_f64(arguments: &Value, key: &str) -> Result<Option<f64>, String> {
    raw(arguments, key)
        .map(|value| value.as_f64().ok_or_else(|| invalid_type(key)))
        .transpose()
}

fn opt_bool(arguments: &Value, key: &str) -> Result<Option<bool>, String> {
    raw(arguments, key)
        .map(|value| value.as_bool().ok_or_else(|| invalid_type(key)))
        .transpose()
}

fn opt_str(arguments: &Value, key: &str) -> Result<Option<String>, String> {
    raw(arguments, key)
        .map(|value| {
            value
                .as_str()
                .map(str::to_owned)
                .ok_or_else(|| invalid_type(key))
        })
        .transpose()
}

/// `format_changeset_errors/1` shared by the changeset-backed tools.
pub fn format_changeset_errors(errors: &[(String, Vec<String>)]) -> String {
    let fields = errors
        .iter()
        .map(|(field, messages)| format!("{field} {}", messages.join(", ")))
        .collect::<Vec<_>>()
        .join("; ");
    format!("Validation failed: {fields}")
}

/// Default mapping for port errors that tools do not phrase contextually.
fn port_error(error: PortError) -> String {
    match error {
        PortError::Validation(errors) => format_changeset_errors(&errors),
        PortError::DestinationConflict => destination_conflict_message().to_string(),
        // Call sites phrase `NotFound` contextually; a raw NotFound here means
        // a port used it where the Elixir context never can.
        PortError::NotFound => "Not found".to_string(),
        PortError::Failed(reason) => reason,
    }
}

fn not_found(error: PortError, message: impl FnOnce() -> String) -> String {
    match error {
        PortError::NotFound => message(),
        other => port_error(other),
    }
}

fn destination_conflict_message() -> &'static str {
    "This input is assigned to the virtual joystick. Remove that mapping before enabling this binding."
}

// ---------------------------------------------------------------------------
// Serializer helpers (Elixir `serialize_*` functions)
// ---------------------------------------------------------------------------

fn serialize_element(element: &crate::mcp::ports::ElementRecord) -> Value {
    json!({
        "id": element.id,
        "name": element.name,
        "type": element.element_type,
    })
}

/// `TrainTools.serialize_output_binding/1` (no train_id).
fn serialize_output_binding_train_view(binding: &crate::mcp::ports::OutputBindingRecord) -> Value {
    json!({
        "id": binding.id,
        "name": binding.name,
        "endpoint": binding.endpoint,
        "operator": binding.operator,
        "output_id": binding.output_id,
        "value_a": binding.value_a,
        "value_b": binding.value_b,
        "enabled": binding.enabled,
    })
}

/// `OutputBindingTools.serialize/1` (with train_id).
fn serialize_output_binding_full(binding: &crate::mcp::ports::OutputBindingRecord) -> Value {
    json!({
        "id": binding.id,
        "train_id": binding.train_id,
        "name": binding.name,
        "output_id": binding.output_id,
        "endpoint": binding.endpoint,
        "operator": binding.operator,
        "value_a": binding.value_a,
        "value_b": binding.value_b,
        "enabled": binding.enabled,
    })
}

fn serialize_button_binding(binding: &ButtonBindingRecord) -> Value {
    json!({
        "id": binding.id,
        "element_id": binding.element_id,
        "input_id": binding.input_id,
        "mode": binding.mode,
        "endpoint": binding.endpoint,
        "on_value": binding.on_value,
        "off_value": binding.off_value,
        "enabled": binding.enabled,
        "hardware_type": binding.hardware_type,
        "keystroke": binding.keystroke,
        "repeat_interval_ms": binding.repeat_interval_ms,
        "on_sequence_id": binding.on_sequence_id,
        "off_sequence_id": binding.off_sequence_id,
    })
}

fn serialize_sequence_command(command: &crate::mcp::ports::SequenceCommandRecord) -> Value {
    json!({
        "id": command.id,
        "position": command.position,
        "endpoint": command.endpoint,
        "value": command.value,
        "delay_ms": command.delay_ms,
    })
}

/// `TrainTools.serialize_sequence/1` (no train_id).
fn serialize_sequence_train_view(sequence: &SequenceRecord) -> Value {
    json!({
        "id": sequence.id,
        "name": sequence.name,
        "commands": sequence.commands.iter().map(serialize_sequence_command).collect::<Vec<_>>(),
    })
}

/// `SequenceTools.serialize/1` (with train_id).
fn serialize_sequence_full(sequence: &SequenceRecord) -> Value {
    json!({
        "id": sequence.id,
        "name": sequence.name,
        "train_id": sequence.train_id,
        "commands": sequence.commands.iter().map(serialize_sequence_command).collect::<Vec<_>>(),
    })
}

fn serialize_script_summary(script: &crate::mcp::ports::ScriptRecord) -> Value {
    json!({
        "id": script.id,
        "train_id": script.train_id,
        "name": script.name,
        "enabled": script.enabled,
        "triggers": script.triggers,
    })
}

fn serialize_script_full(script: &crate::mcp::ports::ScriptRecord) -> Value {
    json!({
        "id": script.id,
        "train_id": script.train_id,
        "name": script.name,
        "enabled": script.enabled,
        "code": script.code,
        "triggers": script.triggers,
    })
}

fn serialize_display_binding(binding: &crate::mcp::ports::DisplayBindingRecord) -> Value {
    json!({
        "id": binding.id,
        "train_id": binding.train_id,
        "i2c_module_id": binding.i2c_module_id,
        "name": binding.name,
        "endpoint": binding.endpoint,
        "format_string": binding.format_string,
        "enabled": binding.enabled,
    })
}

fn serialize_detected_input(input: &crate::mcp::ports::DetectedInput) -> Value {
    json!({
        "input_id": input.input_id,
        "pin": input.pin,
        "input_type": input.input_type,
        "name": input.name,
        "device_id": input.device_id,
        "device_name": input.device_name,
        "value": input.value,
    })
}

fn serialize_vjoy_mapping(mapping: &crate::mcp::ports::VjoyMappingRecord) -> Value {
    json!({
        "id": mapping.id,
        "input_id": mapping.input_id,
        "device_index": mapping.device_index,
        "target_type": mapping.target_type,
        "axis": mapping.axis,
        "button": mapping.button,
        "inverted": mapping.inverted,
    })
}

fn empty_schema() -> Value {
    json!({"type": "object", "properties": {}, "required": []})
}

// ---------------------------------------------------------------------------
// SimulatorTools
// ---------------------------------------------------------------------------

mod simulator {
    use super::*;

    pub const TOOL_NAMES: [&str; 3] = [
        "list_simulator_endpoints",
        "get_simulator_value",
        "set_simulator_value",
    ];

    pub fn tools() -> Vec<ToolDef> {
        vec![
            ToolDef {
                name: "list_simulator_endpoints",
                description: "Browse the simulator API tree at a given path. The response contains two key sections: 'Nodes' are child containers navigated with '/' (e.g. 'CurrentDrivableActor/AWS'), and 'Endpoints' are leaf values on the current node (e.g. 'Property.IsPlayer', 'Function.CanOperateDoors', 'InputValue'). To read an endpoint value, use get_simulator_value with the node path joined to the endpoint name using '.' (dot), e.g. 'CurrentDrivableActor.Function.CanOperateDoors' or 'CurrentDrivableActor/AWS.Function.IsWarningSound'. Use with no path to see the root, then drill into children.",
                input_schema: json!({
                    "type": "object",
                    "properties": {
                        "path": {
                            "type": "string",
                            "description": "Node path to browse, e.g. 'CurrentDrivableActor' or 'CurrentDrivableActor/AWS'. Omit or leave empty for root."
                        }
                    }
                }),
            },
            ToolDef {
                name: "get_simulator_value",
                description: "Read the current value of a simulator endpoint. Use list_simulator_endpoints first to discover available nodes and endpoints. Path format: 'NodePath.EndpointName' — use '/' to separate nodes, '.' to separate the final node from the endpoint. Examples: 'CurrentDrivableActor.Function.CanOperateDoors', 'CurrentDrivableActor/AWS.Function.IsWarningSound', 'CurrentDrivableActor/PassengerDoor_FL.Function.GetNormalisedOutputValue'.",
                input_schema: json!({
                    "type": "object",
                    "properties": {
                        "path": {
                            "type": "string",
                            "description": "Full path: node path + '.' + endpoint name, e.g. 'CurrentDrivableActor/AWS.Function.IsWarningSound'"
                        }
                    },
                    "required": ["path"]
                }),
            },
            ToolDef {
                name: "set_simulator_value",
                description: "Write a value to a writable simulator endpoint. Use list_simulator_endpoints to find writable endpoints (marked Writable: true, e.g. 'InputValue'). Path format is the same as get_simulator_value: 'NodePath.EndpointName'.",
                input_schema: json!({
                    "type": "object",
                    "properties": {
                        "path": {
                            "type": "string",
                            "description": "Full path: node path + '.' + endpoint name, e.g. 'CurrentDrivableActor/ThrottleAndBrake (Irregular Lever).InputValue'"
                        },
                        "value": {
                            "description": "Value to set (number, string, or boolean)"
                        }
                    },
                    "required": ["path", "value"]
                }),
            },
        ]
    }

    pub fn execute(ports: &Ports, name: &str, arguments: &Value) -> Result<Value, String> {
        match name {
            "list_simulator_endpoints" => {
                let path = opt_str(arguments, "path")?;
                let path = path.filter(|path| !path.is_empty());
                with_client(ports, |port| port.list_endpoints(path.as_deref()))
            }
            "get_simulator_value" => {
                let path = req_str(arguments, "path")?;
                with_client(ports, |port| port.get_value(path))
            }
            _ => {
                let path = req_str(arguments, "path")?;
                let value = raw(arguments, "value")
                    .ok_or_else(|| "Missing required argument: value".to_string())?
                    .clone();
                with_client(ports, |port| port.set_value(path, &value))
            }
        }
    }

    fn with_client(
        ports: &Ports,
        call: impl FnOnce(&dyn crate::mcp::ports::SimulatorPort) -> Result<Value, String>,
    ) -> Result<Value, String> {
        if !ports.simulator.is_connected() {
            return Err(
                "Simulator not connected. Ensure Train Sim World is running with External Interface enabled."
                    .to_string(),
            );
        }
        let simulator = ports.simulator.as_ref();
        call(simulator).map_err(|reason| format!("Simulator error: {reason}"))
    }
}

// ---------------------------------------------------------------------------
// TrainTools
// ---------------------------------------------------------------------------

mod train {
    use super::*;

    pub const TOOL_NAMES: [&str; 2] = ["list_trains", "get_train"];

    pub fn tools() -> Vec<ToolDef> {
        vec![
            ToolDef {
                name: "list_trains",
                description: "List all configured trains. Returns id, name, identifiers, and description for each train.",
                input_schema: empty_schema(),
            },
            ToolDef {
                name: "get_train",
                description: "Get a train's full configuration including its elements (levers and buttons) and output bindings. Use this to understand the train's current setup before making changes.",
                input_schema: json!({
                    "type": "object",
                    "properties": {
                        "train_id": {"type": "integer", "description": "Train ID from list_trains"}
                    },
                    "required": ["train_id"]
                }),
            },
        ]
    }

    pub fn execute(ports: &Ports, name: &str, arguments: &Value) -> Result<Value, String> {
        match name {
            "list_trains" => {
                let trains = ports.trains.list_trains().map_err(port_error)?;
                Ok(json!({
                    "trains": trains
                        .iter()
                        .map(|train| json!({
                            "id": train.id,
                            "name": train.name,
                            "identifiers": train.identifiers,
                            "description": train.description,
                        }))
                        .collect::<Vec<_>>()
                }))
            }
            _ => {
                let train_id = req_i64(arguments, "train_id")?;
                match ports.trains.get_train(train_id) {
                    Ok(detail) => Ok(json!({
                        "train": {
                            "id": detail.train.id,
                            "name": detail.train.name,
                            "identifiers": detail.train.identifiers,
                            "description": detail.train.description,
                            "elements": detail.elements.iter().map(serialize_element).collect::<Vec<_>>(),
                            "output_bindings": detail
                                .output_bindings
                                .iter()
                                .map(serialize_output_binding_train_view)
                                .collect::<Vec<_>>(),
                            "button_bindings": detail
                                .button_bindings
                                .iter()
                                .map(serialize_button_binding)
                                .collect::<Vec<_>>(),
                            "sequences": detail
                                .sequences
                                .iter()
                                .map(serialize_sequence_train_view)
                                .collect::<Vec<_>>(),
                        }
                    })),
                    Err(error) => Err(not_found(error, || {
                        format!("Train not found with id {train_id}")
                    })),
                }
            }
        }
    }
}

// ---------------------------------------------------------------------------
// ElementTools
// ---------------------------------------------------------------------------

mod element {
    use super::*;

    pub const TOOL_NAMES: [&str; 3] = ["list_elements", "create_element", "delete_element"];

    pub fn tools() -> Vec<ToolDef> {
        vec![
            ToolDef {
                name: "list_elements",
                description: "List all elements (buttons and levers) for a train. Returns id, name, and type for each element.",
                input_schema: json!({
                    "type": "object",
                    "properties": {
                        "train_id": {"type": "integer", "description": "Train ID"}
                    },
                    "required": ["train_id"]
                }),
            },
            ToolDef {
                name: "create_element",
                description: "Create a new element (button or lever) on a train. Elements represent controls that can be bound to hardware inputs. After creating a button element, use create_button_binding to bind it to a hardware input.",
                input_schema: json!({
                    "type": "object",
                    "properties": {
                        "train_id": {"type": "integer", "description": "Train ID"},
                        "name": {"type": "string", "description": "Human-readable name, e.g. 'Horn Hi'"},
                        "type": {
                            "type": "string",
                            "enum": ["button", "lever"],
                            "description": "Element type: 'button' for push buttons, 'lever' for analog controls"
                        }
                    },
                    "required": ["train_id", "name", "type"]
                }),
            },
            ToolDef {
                name: "delete_element",
                description: "Delete an element from a train. This will also delete any associated button binding or lever config.",
                input_schema: json!({
                    "type": "object",
                    "properties": {
                        "id": {"type": "integer", "description": "Element ID to delete"}
                    },
                    "required": ["id"]
                }),
            },
        ]
    }

    pub fn execute(ports: &Ports, name: &str, arguments: &Value) -> Result<Value, String> {
        match name {
            "list_elements" => {
                let train_id = req_i64(arguments, "train_id")?;
                let elements = ports.trains.list_elements(train_id).map_err(port_error)?;
                Ok(json!({
                    "elements": elements.iter().map(serialize_element).collect::<Vec<_>>()
                }))
            }
            "create_element" => {
                let train_id = req_i64(arguments, "train_id")?;
                let element_name = req_str(arguments, "name")?;
                let element_type = parse_element_type(req_str(arguments, "type")?)?;
                match ports.trains.create_element(
                    train_id,
                    Some(element_name.to_string()),
                    element_type,
                ) {
                    Ok(element) => Ok(json!({"element": serialize_element(&element)})),
                    Err(error) => Err(port_error(error)),
                }
            }
            _ => {
                let id = req_i64(arguments, "id")?;
                match ports.trains.get_element(id) {
                    Ok(element) => ports
                        .trains
                        .delete_element(&element)
                        .map_err(port_error)
                        .map(|_| json!({"deleted": true, "id": id})),
                    Err(error) => Err(not_found(error, || {
                        format!("Element not found with id {id}")
                    })),
                }
            }
        }
    }

    fn parse_element_type(value: &str) -> Result<ElementType, String> {
        match value {
            "button" => Ok(ElementType::Button),
            "lever" => Ok(ElementType::Lever),
            other => Err(format!(
                "Invalid argument: type '{other}' must be 'button' or 'lever'"
            )),
        }
    }
}

// ---------------------------------------------------------------------------
// DeviceTools
// ---------------------------------------------------------------------------

mod device {
    use super::*;
    use crate::mcp::ports::{I2cModuleParams, I2cModuleRecord};

    pub const TOOL_NAMES: [&str; 7] = [
        "list_devices",
        "list_device_inputs",
        "list_hardware_outputs",
        "list_i2c_modules",
        "create_i2c_module",
        "update_i2c_module",
        "delete_i2c_module",
    ];

    pub fn tools() -> Vec<ToolDef> {
        vec![
            ToolDef {
                name: "list_devices",
                description: "List all connected hardware devices. Returns id, name, and connection status for each device.",
                input_schema: empty_schema(),
            },
            ToolDef {
                name: "list_device_inputs",
                description: "List all inputs (buttons and analog sensors) for a specific device. Use this to find input IDs when creating button bindings.",
                input_schema: json!({
                    "type": "object",
                    "properties": {
                        "device_id": {"type": "integer", "description": "Device ID from list_devices"}
                    },
                    "required": ["device_id"]
                }),
            },
            ToolDef {
                name: "list_hardware_outputs",
                description: "List all available hardware outputs (LEDs, relays) across all devices. Use this to find output IDs when creating output bindings.",
                input_schema: empty_schema(),
            },
            ToolDef {
                name: "list_i2c_modules",
                description: "List all I2C modules configured on any device. Use this to find i2c_module_id when creating display bindings.",
                input_schema: empty_schema(),
            },
            ToolDef {
                name: "create_i2c_module",
                description: "Add an I2C module to a device. i2c_address accepts decimal (112) or hex (0x70). module_chip must be 'ht16k33'. brightness 0–15. num_digits 4 or 8.",
                input_schema: json!({
                    "type": "object",
                    "properties": {
                        "device_id": {"type": "integer", "description": "Device ID"},
                        "name": {"type": "string", "description": "Human-readable name, e.g. 'Speed display'"},
                        "module_chip": {"type": "string", "enum": ["ht16k33"]},
                        "i2c_address": {
                            "type": "string",
                            "description": "I2C address: decimal '112' or hex '0x70'"
                        },
                        "brightness": {"type": "integer", "description": "0–15"},
                        "num_digits": {"type": "integer", "enum": [4, 8]}
                    },
                    "required": ["device_id", "module_chip", "i2c_address"]
                }),
            },
            ToolDef {
                name: "update_i2c_module",
                description: "Update an I2C module's name, brightness, or num_digits.",
                input_schema: json!({
                    "type": "object",
                    "properties": {
                        "id": {"type": "integer"},
                        "name": {"type": "string"},
                        "brightness": {"type": "integer", "description": "0–15"},
                        "num_digits": {"type": "integer", "enum": [4, 8]}
                    },
                    "required": ["id"]
                }),
            },
            ToolDef {
                name: "delete_i2c_module",
                description: "Delete an I2C module from a device.",
                input_schema: json!({
                    "type": "object",
                    "properties": {"id": {"type": "integer"}},
                    "required": ["id"]
                }),
            },
        ]
    }

    pub fn execute(ports: &Ports, name: &str, arguments: &Value) -> Result<Value, String> {
        match name {
            "list_devices" => Ok(json!({
                "devices": ports
                    .hardware
                    .list_devices()
                    .iter()
                    .map(|device| json!({"id": device.id, "name": device.name}))
                    .collect::<Vec<_>>()
            })),
            "list_device_inputs" => {
                let device_id = req_i64(arguments, "device_id")?;
                let inputs = ports.hardware.list_inputs(device_id).map_err(port_error)?;
                Ok(json!({
                    "inputs": inputs
                        .iter()
                        .map(|input| json!({
                            "id": input.id,
                            "name": input.name,
                            "pin": input.pin,
                            "input_type": input.input_type,
                        }))
                        .collect::<Vec<_>>()
                }))
            }
            "list_hardware_outputs" => Ok(json!({
                "outputs": ports
                    .hardware
                    .list_outputs()
                    .iter()
                    .map(|output| json!({
                        "id": output.id,
                        "name": output.name,
                        "pin": output.pin,
                        "device_name": output.device_name,
                        "device_id": output.device_id,
                    }))
                    .collect::<Vec<_>>()
            })),
            "list_i2c_modules" => Ok(json!({
                "i2c_modules": ports
                    .hardware
                    .list_i2c_modules()
                    .iter()
                    .map(serialize_i2c_module)
                    .collect::<Vec<_>>()
            })),
            "create_i2c_module" => {
                let device_id = req_i64(arguments, "device_id")?;
                let address_text = arguments
                    .get("i2c_address")
                    .and_then(Value::as_str)
                    .unwrap_or("");
                let Some(address) = parse_i2c_address(address_text) else {
                    return Err("Invalid i2c_address: use decimal (112) or hex (0x70)".to_string());
                };
                let attrs = I2cModuleAttrs {
                    name: opt_str(arguments, "name")?,
                    module_chip: opt_str(arguments, "module_chip")?,
                    brightness: opt_i64(arguments, "brightness")?,
                    num_digits: opt_i64(arguments, "num_digits")?,
                };
                ports
                    .hardware
                    .create_i2c_module(device_id, address, attrs)
                    .map(|module| json!({"i2c_module": serialize_i2c_module(&module)}))
                    .map_err(port_error)
            }
            "update_i2c_module" => {
                let id = req_i64(arguments, "id")?;
                match ports.hardware.get_i2c_module(id) {
                    Ok(module) => {
                        let changes = I2cModuleChanges {
                            name: opt_str(arguments, "name")?,
                            brightness: opt_i64(arguments, "brightness")?,
                            num_digits: opt_i64(arguments, "num_digits")?,
                        };
                        ports
                            .hardware
                            .update_i2c_module(&module, changes)
                            .map(|updated| json!({"i2c_module": serialize_i2c_module(&updated)}))
                            .map_err(port_error)
                    }
                    Err(error) => Err(not_found(error, || {
                        format!("I2C module not found with id {id}")
                    })),
                }
            }
            _ => {
                let id = req_i64(arguments, "id")?;
                match ports.hardware.get_i2c_module(id) {
                    Ok(module) => ports
                        .hardware
                        .delete_i2c_module(&module)
                        .map_err(port_error)
                        .map(|_| json!({"deleted": true, "id": id})),
                    Err(error) => Err(not_found(error, || {
                        format!("I2C module not found with id {id}")
                    })),
                }
            }
        }
    }

    /// `I2cModule.parse_i2c_address/1`: decimal or lowercase `0x` hex,
    /// full-string parse, 0..=255.
    fn parse_i2c_address(text: &str) -> Option<i64> {
        let (digits, radix) = match text.strip_prefix("0x") {
            Some(hex) => (hex, 16),
            None => (text, 10),
        };
        if digits.is_empty() {
            return None;
        }
        i64::from_str_radix(digits, radix)
            .ok()
            .filter(|address| (0..=255).contains(address))
    }

    /// `I2cModule.format_i2c_address/1`.
    fn format_i2c_address(address: i64) -> String {
        format!("{address} (0x{:02X})", address)
    }

    fn serialize_i2c_module(module: &I2cModuleRecord) -> Value {
        let I2cModuleParams {
            brightness,
            num_digits,
            display_type,
            has_dot,
            align_right,
            min_value,
        } = &module.params;
        json!({
            "id": module.id,
            "device_id": module.device_id,
            "device_name": module.device_name,
            "name": module.name,
            "module_chip": module.module_chip,
            "i2c_address": module.i2c_address,
            "i2c_address_display": format_i2c_address(module.i2c_address),
            "brightness": brightness,
            "num_digits": num_digits,
            "display_type": display_type,
            "has_dot": has_dot,
            "align_right": align_right,
            "min_value": min_value,
        })
    }
}

// ---------------------------------------------------------------------------
// OutputBindingTools
// ---------------------------------------------------------------------------

mod output_binding {
    use super::*;

    pub const TOOL_NAMES: [&str; 4] = [
        "list_output_bindings",
        "create_output_binding",
        "update_output_binding",
        "delete_output_binding",
    ];

    const OPERATORS: [&str; 7] = ["gt", "gte", "lt", "lte", "between", "eq_true", "eq_false"];

    fn operator_schema() -> Value {
        json!({
            "type": "string",
            "enum": OPERATORS,
            "description": "Comparison operator"
        })
    }

    fn operator_schema_update() -> Value {
        json!({"type": "string", "enum": OPERATORS})
    }

    pub fn tools() -> Vec<ToolDef> {
        vec![
            ToolDef {
                name: "list_output_bindings",
                description: "List all output bindings for a train. Each binding monitors a simulator endpoint and controls a hardware output (LED) based on a condition.",
                input_schema: json!({
                    "type": "object",
                    "properties": {
                        "train_id": {"type": "integer", "description": "Train ID"}
                    },
                    "required": ["train_id"]
                }),
            },
            ToolDef {
                name: "create_output_binding",
                description: "Create an output binding that controls a hardware output (LED) based on a simulator endpoint value. Use list_simulator_endpoints to find endpoints and list_hardware_outputs to find available outputs. Operators: 'gt' (>), 'gte' (>=), 'lt' (<), 'lte' (<=), 'between' (range), 'eq_true' (boolean true), 'eq_false' (boolean false).",
                input_schema: json!({
                    "type": "object",
                    "properties": {
                        "train_id": {"type": "integer", "description": "Train ID"},
                        "name": {"type": "string", "description": "Human-readable name, e.g. 'Brake warning LED'"},
                        "output_id": {
                            "type": "integer",
                            "description": "Hardware output ID from list_hardware_outputs"
                        },
                        "endpoint": {
                            "type": "string",
                            "description": "Simulator endpoint path to monitor, using 'NodePath.EndpointName' format (e.g. 'CurrentDrivableActor/AWS.Function.IsWarningSound'). Use '/' between nodes and '.' to join the final node to the endpoint."
                        },
                        "operator": operator_schema(),
                        "value_a": {
                            "type": "number",
                            "description": "Threshold value for numeric operators (not needed for eq_true/eq_false)"
                        },
                        "value_b": {
                            "type": "number",
                            "description": "Upper threshold (only for 'between' operator)"
                        },
                        "enabled": {
                            "type": "boolean",
                            "description": "Whether the binding is active (default: true)"
                        }
                    },
                    "required": ["train_id", "name", "output_id", "endpoint", "operator"]
                }),
            },
            ToolDef {
                name: "update_output_binding",
                description: "Update an existing output binding. Only provide the fields you want to change.",
                input_schema: json!({
                    "type": "object",
                    "properties": {
                        "id": {"type": "integer", "description": "Output binding ID"},
                        "name": {"type": "string", "description": "Human-readable name"},
                        "output_id": {"type": "integer", "description": "Hardware output ID"},
                        "endpoint": {"type": "string", "description": "Simulator endpoint path"},
                        "operator": operator_schema_update(),
                        "value_a": {"type": "number", "description": "Threshold value"},
                        "value_b": {"type": "number", "description": "Upper threshold (for 'between')"},
                        "enabled": {"type": "boolean", "description": "Whether the binding is active"}
                    },
                    "required": ["id"]
                }),
            },
            ToolDef {
                name: "delete_output_binding",
                description: "Delete an output binding.",
                input_schema: json!({
                    "type": "object",
                    "properties": {
                        "id": {"type": "integer", "description": "Output binding ID to delete"}
                    },
                    "required": ["id"]
                }),
            },
        ]
    }

    fn parse_operator(value: &str) -> Result<BindingOperator, String> {
        match value {
            "gt" => Ok(BindingOperator::Gt),
            "gte" => Ok(BindingOperator::Gte),
            "lt" => Ok(BindingOperator::Lt),
            "lte" => Ok(BindingOperator::Lte),
            "between" => Ok(BindingOperator::Between),
            "eq_true" => Ok(BindingOperator::EqTrue),
            "eq_false" => Ok(BindingOperator::EqFalse),
            other => Err(format!(
                "Invalid argument: operator '{other}' must be one of {}",
                OPERATORS.join(", ")
            )),
        }
    }

    fn build_attrs(arguments: &Value) -> Result<OutputBindingAttrs, String> {
        let operator = match raw(arguments, "operator") {
            Some(value) => Some(parse_operator(
                value.as_str().ok_or_else(|| invalid_type("operator"))?,
            )?),
            None => None,
        };
        Ok(OutputBindingAttrs {
            name: opt_str(arguments, "name")?,
            output_id: opt_i64(arguments, "output_id")?,
            endpoint: opt_str(arguments, "endpoint")?,
            operator,
            value_a: opt_f64(arguments, "value_a")?,
            value_b: opt_f64(arguments, "value_b")?,
            enabled: opt_bool(arguments, "enabled")?,
        })
    }

    pub fn execute(ports: &Ports, name: &str, arguments: &Value) -> Result<Value, String> {
        match name {
            "list_output_bindings" => {
                let train_id = req_i64(arguments, "train_id")?;
                Ok(json!({
                    "output_bindings": ports
                        .bindings
                        .list_output_bindings(train_id)
                        .iter()
                        .map(serialize_output_binding_full)
                        .collect::<Vec<_>>()
                }))
            }
            "create_output_binding" => {
                let train_id = req_i64(arguments, "train_id")?;
                let attrs = build_attrs(arguments)?;
                ports
                    .bindings
                    .create_output_binding(train_id, attrs)
                    .map(|binding| json!({"output_binding": serialize_output_binding_full(&binding)}))
                    .map_err(port_error)
            }
            "update_output_binding" => {
                let id = req_i64(arguments, "id")?;
                match ports.bindings.get_output_binding(id) {
                    Ok(binding) => {
                        let attrs = build_attrs(arguments)?;
                        ports
                            .bindings
                            .update_output_binding(&binding, attrs)
                            .map(|updated| json!({"output_binding": serialize_output_binding_full(&updated)}))
                            .map_err(port_error)
                    }
                    Err(error) => Err(not_found(error, || {
                        format!("Output binding not found with id {id}")
                    })),
                }
            }
            _ => {
                let id = req_i64(arguments, "id")?;
                match ports.bindings.get_output_binding(id) {
                    Ok(binding) => ports
                        .bindings
                        .delete_output_binding(&binding)
                        .map_err(port_error)
                        .map(|_| json!({"deleted": true, "id": id})),
                    Err(error) => Err(not_found(error, || {
                        format!("Output binding not found with id {id}")
                    })),
                }
            }
        }
    }
}

// ---------------------------------------------------------------------------
// ButtonBindingTools
// ---------------------------------------------------------------------------

mod button_binding {
    use super::*;

    pub const TOOL_NAMES: [&str; 4] = [
        "get_button_binding",
        "create_button_binding",
        "update_button_binding",
        "delete_button_binding",
    ];

    pub fn tools() -> Vec<ToolDef> {
        vec![
            ToolDef {
                name: "get_button_binding",
                description: "Get the button binding for a specific button element. Returns the binding configuration including mode, endpoint, and values.",
                input_schema: json!({
                    "type": "object",
                    "properties": {
                        "element_id": {"type": "integer", "description": "Button element ID from get_train"}
                    },
                    "required": ["element_id"]
                }),
            },
            ToolDef {
                name: "create_button_binding",
                description: "Bind a hardware input to a button element. Modes:\n- 'simple': Send on_value when pressed, off_value when released (requires endpoint)\n- 'momentary': Repeat on_value at interval while held (requires endpoint, repeat_interval_ms)\n- 'sequence': Execute command sequences on press/release (requires on_sequence_id and/or off_sequence_id)\n- 'keystroke': Simulate a keyboard key press (requires keystroke, e.g. 'W' or 'CTRL+S')\n\nUse list_device_inputs to find input IDs and get_train to find button element IDs.",
                input_schema: json!({
                    "type": "object",
                    "properties": {
                        "element_id": {"type": "integer", "description": "Button element ID from get_train"},
                        "input_id": {"type": "integer", "description": "Hardware input ID from list_device_inputs"},
                        "mode": {
                            "type": "string",
                            "enum": ["simple", "momentary", "sequence", "keystroke"],
                            "description": "Button behavior mode"
                        },
                        "endpoint": {
                            "type": "string",
                            "description": "Simulator endpoint (required for simple/momentary modes)"
                        },
                        "on_value": {"type": "number", "description": "Value sent when pressed (default: 1.0)"},
                        "off_value": {"type": "number", "description": "Value sent when released (default: 0.0)"},
                        "keystroke": {
                            "type": "string",
                            "description": "Key combo for keystroke mode, e.g. 'W', 'CTRL+S'"
                        },
                        "on_sequence_id": {
                            "type": "integer",
                            "description": "Sequence ID to execute on press (for sequence mode)"
                        },
                        "off_sequence_id": {
                            "type": "integer",
                            "description": "Sequence ID to execute on release (for sequence mode, latching buttons only)"
                        },
                        "repeat_interval_ms": {
                            "type": "integer",
                            "description": "Repeat interval in ms for momentary mode (100-5000, default: 100)"
                        },
                        "hardware_type": {
                            "type": "string",
                            "enum": ["momentary", "latching"],
                            "description": "Physical button type (default: momentary)"
                        }
                    },
                    "required": ["element_id", "input_id", "mode"]
                }),
            },
            ToolDef {
                name: "update_button_binding",
                description: "Update an existing button binding. Only provide the fields you want to change.",
                input_schema: json!({
                    "type": "object",
                    "properties": {
                        "element_id": {"type": "integer", "description": "Button element ID"},
                        "mode": {"type": "string", "enum": ["simple", "momentary", "sequence", "keystroke"]},
                        "endpoint": {"type": "string", "description": "Simulator endpoint"},
                        "on_value": {"type": "number"},
                        "off_value": {"type": "number"},
                        "keystroke": {"type": "string"},
                        "on_sequence_id": {"type": "integer"},
                        "off_sequence_id": {"type": "integer"},
                        "repeat_interval_ms": {"type": "integer"},
                        "hardware_type": {"type": "string", "enum": ["momentary", "latching"]},
                        "enabled": {"type": "boolean", "description": "Whether the binding is active"}
                    },
                    "required": ["element_id"]
                }),
            },
            ToolDef {
                name: "delete_button_binding",
                description: "Remove a button binding from a button element.",
                input_schema: json!({
                    "type": "object",
                    "properties": {
                        "element_id": {"type": "integer", "description": "Button element ID"}
                    },
                    "required": ["element_id"]
                }),
            },
        ]
    }

    fn parse_mode(value: &str) -> Result<ButtonMode, String> {
        match value {
            "simple" => Ok(ButtonMode::Simple),
            "momentary" => Ok(ButtonMode::Momentary),
            "sequence" => Ok(ButtonMode::Sequence),
            "keystroke" => Ok(ButtonMode::Keystroke),
            other => Err(format!(
                "Invalid argument: mode '{other}' must be simple, momentary, sequence or keystroke"
            )),
        }
    }

    fn parse_hardware_type(value: &str) -> Result<HardwareType, String> {
        match value {
            "momentary" => Ok(HardwareType::Momentary),
            "latching" => Ok(HardwareType::Latching),
            other => Err(format!(
                "Invalid argument: hardware_type '{other}' must be momentary or latching"
            )),
        }
    }

    fn build_attrs(arguments: &Value) -> Result<ButtonBindingAttrs, String> {
        let mode = match raw(arguments, "mode") {
            Some(value) => Some(parse_mode(
                value.as_str().ok_or_else(|| invalid_type("mode"))?,
            )?),
            None => None,
        };
        let hardware_type = match raw(arguments, "hardware_type") {
            Some(value) => Some(parse_hardware_type(
                value
                    .as_str()
                    .ok_or_else(|| invalid_type("hardware_type"))?,
            )?),
            None => None,
        };
        Ok(ButtonBindingAttrs {
            mode,
            endpoint: opt_str(arguments, "endpoint")?,
            on_value: opt_f64(arguments, "on_value")?,
            off_value: opt_f64(arguments, "off_value")?,
            keystroke: opt_str(arguments, "keystroke")?,
            on_sequence_id: opt_i64(arguments, "on_sequence_id")?,
            off_sequence_id: opt_i64(arguments, "off_sequence_id")?,
            repeat_interval_ms: opt_i64(arguments, "repeat_interval_ms")?,
            hardware_type,
            enabled: opt_bool(arguments, "enabled")?,
        })
    }

    fn map_put_error(error: PortError) -> String {
        match error {
            PortError::DestinationConflict => destination_conflict_message().to_string(),
            other => port_error(other),
        }
    }

    pub fn execute(ports: &Ports, name: &str, arguments: &Value) -> Result<Value, String> {
        match name {
            "get_button_binding" => {
                let element_id = req_i64(arguments, "element_id")?;
                match ports.bindings.get_button_binding(element_id) {
                    Ok(binding) => {
                        Ok(json!({"button_binding": serialize_button_binding(&binding)}))
                    }
                    Err(error) => Err(not_found(error, || {
                        format!("No button binding found for element {element_id}")
                    })),
                }
            }
            "create_button_binding" => {
                let element_id = req_i64(arguments, "element_id")?;
                let input_id = req_i64(arguments, "input_id")?;
                let attrs = build_attrs(arguments)?;
                ports
                    .bindings
                    .create_button_binding(element_id, input_id, attrs)
                    .map(|binding| json!({"button_binding": serialize_button_binding(&binding)}))
                    .map_err(map_put_error)
            }
            "update_button_binding" => {
                let element_id = req_i64(arguments, "element_id")?;
                match ports.bindings.get_button_binding(element_id) {
                    Ok(binding) => {
                        let attrs = build_attrs(arguments)?;
                        ports
                            .bindings
                            .update_button_binding(&binding, attrs)
                            .map(|updated| json!({"button_binding": serialize_button_binding(&updated)}))
                            .map_err(map_put_error)
                    }
                    Err(error) => Err(not_found(error, || {
                        format!("No button binding found for element {element_id}")
                    })),
                }
            }
            _ => {
                let element_id = req_i64(arguments, "element_id")?;
                ports
                    .bindings
                    .delete_button_binding(element_id)
                    .map_err(|error| {
                        not_found(error, || {
                            format!("No button binding found for element {element_id}")
                        })
                    })
                    .map(|_| json!({"deleted": true, "element_id": element_id}))
            }
        }
    }
}

// ---------------------------------------------------------------------------
// SequenceTools
// ---------------------------------------------------------------------------

mod sequence {
    use super::*;

    pub const TOOL_NAMES: [&str; 4] = [
        "list_sequences",
        "create_sequence",
        "update_sequence",
        "delete_sequence",
    ];

    fn command_items_schema(description: &str, delay_description: &str) -> Value {
        json!({
            "type": "array",
            "description": description,
            "items": {
                "type": "object",
                "properties": {
                    "endpoint": {"type": "string", "description": "Simulator API endpoint path"},
                    "value": {"type": "number", "description": "Value to send"},
                    "delay_ms": {"type": "integer", "description": delay_description}
                },
                "required": ["endpoint", "value"]
            }
        })
    }

    pub fn tools() -> Vec<ToolDef> {
        vec![
            ToolDef {
                name: "list_sequences",
                description: "List all command sequences for a train. Sequences can be used with button bindings in 'sequence' mode to execute multiple simulator commands in order.",
                input_schema: json!({
                    "type": "object",
                    "properties": {
                        "train_id": {"type": "integer", "description": "Train ID"}
                    },
                    "required": ["train_id"]
                }),
            },
            ToolDef {
                name: "create_sequence",
                description: "Create a named command sequence for a train. Commands are executed in order, each sending a value to a simulator endpoint with an optional delay before the next command. Use list_simulator_endpoints to find valid endpoint paths.",
                input_schema: json!({
                    "type": "object",
                    "properties": {
                        "train_id": {"type": "integer", "description": "Train ID"},
                        "name": {"type": "string", "description": "Human-readable name, e.g. 'Startup sequence'"},
                        "commands": command_items_schema(
                            "Ordered list of commands to execute",
                            "Delay in ms after this command before next (0-60000, default: 0)"
                        )
                    },
                    "required": ["train_id", "name", "commands"]
                }),
            },
            ToolDef {
                name: "update_sequence",
                description: "Update a sequence's name or replace all its commands. When providing commands, all existing commands are replaced.",
                input_schema: json!({
                    "type": "object",
                    "properties": {
                        "id": {"type": "integer", "description": "Sequence ID"},
                        "name": {"type": "string", "description": "New name for the sequence"},
                        "commands": command_items_schema(
                            "New ordered list of commands (replaces all existing commands)",
                            "Delay in ms (0-60000, default: 0)"
                        )
                    },
                    "required": ["id"]
                }),
            },
            ToolDef {
                name: "delete_sequence",
                description: "Delete a command sequence. This will also remove any button binding references to it.",
                input_schema: json!({
                    "type": "object",
                    "properties": {
                        "id": {"type": "integer", "description": "Sequence ID to delete"}
                    },
                    "required": ["id"]
                }),
            },
        ]
    }

    /// `build_command_attrs/1`: accepts an array or a JSON-encoded string
    /// (the "commands arriving as JSON string" fix), indexes positions and
    /// defaults delay_ms to 0.
    fn build_command_attrs(commands: &Value) -> Result<Vec<SequenceCommandDraft>, String> {
        let commands = match commands {
            Value::String(text) => serde_json::from_str::<Value>(text)
                .map_err(|_| "Failed to set commands: invalid JSON commands string".to_string())?,
            other => other.clone(),
        };
        let Some(items) = commands.as_array() else {
            return Err("Failed to set commands: commands must be an array".to_string());
        };
        Ok(items
            .iter()
            .enumerate()
            .map(|(index, command)| SequenceCommandDraft {
                position: index as i64,
                endpoint: command
                    .get("endpoint")
                    .filter(|value| !value.is_null())
                    .and_then(Value::as_str)
                    .map(str::to_owned),
                value: command
                    .get("value")
                    .filter(|value| !value.is_null())
                    .and_then(Value::as_f64),
                delay_ms: command
                    .get("delay_ms")
                    .filter(|value| !value.is_null())
                    .and_then(Value::as_i64)
                    .unwrap_or(0),
            })
            .collect())
    }

    fn set_commands_error(error: PortError) -> String {
        match error {
            PortError::Validation(errors) => format_changeset_errors(&errors),
            PortError::Failed(reason) => format!("Failed to set commands: {reason}"),
            other => format!("Failed to set commands: {other:?}"),
        }
    }

    pub fn execute(ports: &Ports, name: &str, arguments: &Value) -> Result<Value, String> {
        match name {
            "list_sequences" => {
                let train_id = req_i64(arguments, "train_id")?;
                Ok(json!({
                    "sequences": ports
                        .sequences
                        .list_sequences(train_id)
                        .iter()
                        .map(serialize_sequence_full)
                        .collect::<Vec<_>>()
                }))
            }
            "create_sequence" => {
                let train_id = req_i64(arguments, "train_id")?;
                let sequence_name = req_str(arguments, "name")?;
                let sequence = match ports
                    .sequences
                    .create_sequence(train_id, Some(sequence_name.to_string()))
                {
                    Ok(sequence) => sequence,
                    Err(PortError::Validation(errors)) => {
                        return Err(format_changeset_errors(&errors))
                    }
                    Err(PortError::Failed(reason)) => {
                        return Err(format!("Failed to set commands: {reason}"))
                    }
                    Err(other) => return Err(port_error(other)),
                };
                let commands: Vec<SequenceCommandDraft> = match raw(arguments, "commands") {
                    Some(Value::Array(commands)) if !commands.is_empty() => {
                        build_command_attrs(&Value::Array(commands.clone()))?
                    }
                    Some(Value::String(text)) => {
                        let parsed = serde_json::from_str::<Value>(text).map_err(|_| {
                            "Failed to set commands: invalid JSON commands string".to_string()
                        })?;
                        let is_empty = parsed.as_array().is_some_and(Vec::is_empty);
                        if is_empty {
                            Vec::new()
                        } else {
                            build_command_attrs(&parsed)?
                        }
                    }
                    _ => Vec::new(),
                };
                if commands.is_empty() {
                    return Ok(json!({"sequence": serialize_sequence_full(&sequence)}));
                }
                match ports.sequences.set_sequence_commands(&sequence, commands) {
                    Ok(()) => match ports.sequences.get_sequence(sequence.id) {
                        Ok(updated) => Ok(json!({"sequence": serialize_sequence_full(&updated)})),
                        Err(error) => Err(port_error(error)),
                    },
                    Err(error) => Err(set_commands_error(error)),
                }
            }
            "update_sequence" => {
                let id = req_i64(arguments, "id")?;
                let sequence = match ports.sequences.get_sequence(id) {
                    Ok(sequence) => sequence,
                    Err(error) => {
                        return Err(not_found(error, || {
                            format!("Sequence not found with id {id}")
                        }))
                    }
                };
                if let Some(name) = raw(arguments, "name") {
                    let name = name.as_str().ok_or_else(|| invalid_type("name"))?;
                    if let Err(PortError::Validation(errors)) = ports
                        .sequences
                        .update_sequence_name(&sequence, Some(name.to_string()))
                    {
                        return Err(format_changeset_errors(&errors));
                    }
                }
                if let Some(commands) = raw(arguments, "commands") {
                    let drafts = build_command_attrs(commands)?;
                    if let Err(error) = ports.sequences.set_sequence_commands(&sequence, drafts) {
                        return Err(set_commands_error(error));
                    }
                }
                match ports.sequences.get_sequence(id) {
                    Ok(updated) => Ok(json!({"sequence": serialize_sequence_full(&updated)})),
                    Err(error) => Err(not_found(error, || {
                        format!("Sequence not found with id {id}")
                    })),
                }
            }
            _ => {
                let id = req_i64(arguments, "id")?;
                match ports.sequences.get_sequence(id) {
                    Ok(sequence) => ports
                        .sequences
                        .delete_sequence(&sequence)
                        .map_err(port_error)
                        .map(|_| json!({"deleted": true, "id": id})),
                    Err(error) => Err(not_found(error, || {
                        format!("Sequence not found with id {id}")
                    })),
                }
            }
        }
    }
}

// ---------------------------------------------------------------------------
// ScriptTools
// ---------------------------------------------------------------------------

mod script {
    use super::*;

    pub const TOOL_NAMES: [&str; 5] = [
        "list_scripts",
        "get_script",
        "create_script",
        "update_script",
        "delete_script",
    ];

    pub fn tools() -> Vec<ToolDef> {
        vec![
            ToolDef {
                name: "list_scripts",
                description: "List all Lua scripts for a train. Returns script metadata (id, name, enabled, triggers) without the full code. Use get_script to retrieve the code for a specific script.",
                input_schema: json!({
                    "type": "object",
                    "properties": {
                        "train_id": {"type": "integer", "description": "Train ID"}
                    },
                    "required": ["train_id"]
                }),
            },
            ToolDef {
                name: "get_script",
                description: "Get a Lua script by ID, including its full code, triggers, and enabled status.",
                input_schema: json!({
                    "type": "object",
                    "properties": {
                        "id": {"type": "integer", "description": "Script ID"}
                    },
                    "required": ["id"]
                }),
            },
            ToolDef {
                name: "create_script",
                description: "Create a new Lua script for a train. Scripts must define an on_change(event) callback. Triggers are simulator endpoint paths that fire the script when their values change. Use list_simulator_endpoints to find valid trigger paths.",
                input_schema: json!({
                    "type": "object",
                    "properties": {
                        "train_id": {"type": "integer", "description": "Train ID"},
                        "name": {"type": "string", "description": "Human-readable name, e.g. 'Speed Warning'"},
                        "code": {
                            "type": "string",
                            "description": "Lua source code. Must define function on_change(event)."
                        },
                        "triggers": {
                            "type": "array",
                            "description": "Simulator endpoint paths that trigger the script, e.g. [\"CurrentDrivableActor/Throttle.InputValue\"]",
                            "items": {"type": "string"}
                        },
                        "enabled": {
                            "type": "boolean",
                            "description": "Whether the script is active (default: true)"
                        }
                    },
                    "required": ["train_id", "name", "code"]
                }),
            },
            ToolDef {
                name: "update_script",
                description: "Update a Lua script's name, code, triggers, or enabled status. Only provided fields are changed.",
                input_schema: json!({
                    "type": "object",
                    "properties": {
                        "id": {"type": "integer", "description": "Script ID"},
                        "name": {"type": "string", "description": "New name"},
                        "code": {"type": "string", "description": "New Lua source code"},
                        "triggers": {
                            "type": "array",
                            "description": "New trigger endpoint paths",
                            "items": {"type": "string"}
                        },
                        "enabled": {"type": "boolean", "description": "Enable or disable the script"}
                    },
                    "required": ["id"]
                }),
            },
            ToolDef {
                name: "delete_script",
                description: "Delete a Lua script.",
                input_schema: json!({
                    "type": "object",
                    "properties": {
                        "id": {"type": "integer", "description": "Script ID to delete"}
                    },
                    "required": ["id"]
                }),
            },
        ]
    }

    fn extract_attrs(arguments: &Value) -> Result<ScriptAttrs, String> {
        Ok(ScriptAttrs {
            name: opt_str(arguments, "name")?,
            code: opt_str(arguments, "code")?,
            triggers: raw(arguments, "triggers")
                .map(|value| {
                    value.as_array().ok_or_else(|| invalid_type("triggers"))?;
                    value
                        .as_array()
                        .unwrap()
                        .iter()
                        .map(|trigger| {
                            trigger
                                .as_str()
                                .map(str::to_owned)
                                .ok_or_else(|| invalid_type("triggers"))
                        })
                        .collect::<Result<Vec<_>, _>>()
                })
                .transpose()?,
            enabled: opt_bool(arguments, "enabled")?,
        })
    }

    pub fn execute(ports: &Ports, name: &str, arguments: &Value) -> Result<Value, String> {
        match name {
            "list_scripts" => {
                let train_id = req_i64(arguments, "train_id")?;
                Ok(json!({
                    "scripts": ports
                        .scripts
                        .list_scripts(train_id)
                        .iter()
                        .map(serialize_script_summary)
                        .collect::<Vec<_>>()
                }))
            }
            "get_script" => {
                let id = req_i64(arguments, "id")?;
                match ports.scripts.get_script(id) {
                    Ok(script) => Ok(json!({"script": serialize_script_full(&script)})),
                    Err(error) => Err(not_found(error, || {
                        format!("Script not found with id {id}")
                    })),
                }
            }
            "create_script" => {
                let train_id = req_i64(arguments, "train_id")?;
                req_str(arguments, "name")?;
                req_str(arguments, "code")?;
                let attrs = extract_attrs(arguments)?;
                ports
                    .scripts
                    .create_script(train_id, attrs)
                    .map(|script| json!({"script": serialize_script_full(&script)}))
                    .map_err(port_error)
            }
            "update_script" => {
                let id = req_i64(arguments, "id")?;
                match ports.scripts.get_script(id) {
                    Ok(script) => {
                        let changes = extract_attrs(arguments)?;
                        ports
                            .scripts
                            .update_script(&script, changes)
                            .map(|updated| json!({"script": serialize_script_full(&updated)}))
                            .map_err(port_error)
                    }
                    Err(error) => Err(not_found(error, || {
                        format!("Script not found with id {id}")
                    })),
                }
            }
            _ => {
                let id = req_i64(arguments, "id")?;
                match ports.scripts.get_script(id) {
                    Ok(script) => ports
                        .scripts
                        .delete_script(&script)
                        .map_err(port_error)
                        .map(|_| json!({"deleted": true, "id": id})),
                    Err(error) => Err(not_found(error, || {
                        format!("Script not found with id {id}")
                    })),
                }
            }
        }
    }
}

// ---------------------------------------------------------------------------
// DetectionTools
// ---------------------------------------------------------------------------

mod detection {
    use super::*;

    pub const TOOL_NAMES: [&str; 1] = ["detect_hardware_input"];
    const DEFAULT_TIMEOUT_MS: i64 = 60_000;

    pub fn tools() -> Vec<ToolDef> {
        vec![ToolDef {
            name: "detect_hardware_input",
            description: "Prompt the user to interact with a hardware input (press a button, move a lever). Shows a modal in the Trenino UI and waits for the input event. Returns the detected input details including its database ID for use in bindings. Prefer this over asking the user for input IDs manually. IMPORTANT: Only call this tool one at a time. Do NOT call multiple detections in parallel. Wait for each detection to complete before starting the next one.",
            input_schema: json!({
                "type": "object",
                "properties": {
                    "prompt": {
                        "type": "string",
                        "description": "Message shown to the user"
                    },
                    "input_type": {
                        "type": "string",
                        "enum": ["button", "analog", "any"],
                        "description": "Type of input to detect"
                    }
                },
                "required": ["prompt"]
            }),
        }]
    }

    pub fn execute(ports: &Ports, _name: &str, arguments: &Value) -> Result<Value, String> {
        let prompt = req_str(arguments, "prompt")?;
        let kind = parse_input_type(raw(arguments, "input_type").and_then(Value::as_str));
        let timeout_ms = opt_i64(arguments, "timeout_ms")?.unwrap_or(DEFAULT_TIMEOUT_MS);
        let request = DetectionRequest {
            prompt: prompt.to_string(),
            kind,
            timeout_ms,
        };
        match ports.detection.detect_input(&request) {
            DetectionOutcome::Detected(input) => {
                Ok(json!({"detected": true, "input": serialize_detected_input(&input)}))
            }
            DetectionOutcome::Timeout => Ok(json!({"detected": false, "reason": "timeout"})),
        }
    }

    fn parse_input_type(value: Option<&str>) -> DetectionKind {
        match value {
            Some("button") => DetectionKind::Button,
            Some("analog") => DetectionKind::Analog,
            _ => DetectionKind::Any,
        }
    }
}

// ---------------------------------------------------------------------------
// DisplayBindingTools
// ---------------------------------------------------------------------------

mod display_binding {
    use super::*;

    pub const TOOL_NAMES: [&str; 4] = [
        "list_display_bindings",
        "create_display_binding",
        "update_display_binding",
        "delete_display_binding",
    ];

    pub fn tools() -> Vec<ToolDef> {
        vec![
            ToolDef {
                name: "list_display_bindings",
                description: "List all display bindings for a train.",
                input_schema: json!({
                    "type": "object",
                    "properties": {"train_id": {"type": "integer"}},
                    "required": ["train_id"]
                }),
            },
            ToolDef {
                name: "create_display_binding",
                description: "Create a display binding that shows a simulator endpoint value on an I2C display. Use list_i2c_modules to find i2c_module_id. format_string tokens: '{value}' (raw), '{value:.Nf}' (float with N decimals). Example: '{value:.0f}' shows speed as integer.",
                input_schema: json!({
                    "type": "object",
                    "properties": {
                        "train_id": {"type": "integer"},
                        "name": {"type": "string", "description": "e.g. 'Train speed'"},
                        "i2c_module_id": {"type": "integer"},
                        "endpoint": {"type": "string", "description": "Simulator endpoint path"},
                        "format_string": {"type": "string", "description": "e.g. '{value:.0f}' or '{value}'"},
                        "enabled": {"type": "boolean"}
                    },
                    "required": ["train_id", "i2c_module_id", "endpoint", "format_string"]
                }),
            },
            ToolDef {
                name: "update_display_binding",
                description: "Update an existing display binding.",
                input_schema: json!({
                    "type": "object",
                    "properties": {
                        "id": {"type": "integer"},
                        "name": {"type": "string"},
                        "i2c_module_id": {"type": "integer"},
                        "endpoint": {"type": "string"},
                        "format_string": {"type": "string"},
                        "enabled": {"type": "boolean"}
                    },
                    "required": ["id"]
                }),
            },
            ToolDef {
                name: "delete_display_binding",
                description: "Delete a display binding.",
                input_schema: json!({
                    "type": "object",
                    "properties": {"id": {"type": "integer"}},
                    "required": ["id"]
                }),
            },
        ]
    }

    fn build_attrs(arguments: &Value) -> Result<DisplayBindingAttrs, String> {
        Ok(DisplayBindingAttrs {
            name: opt_str(arguments, "name")?,
            i2c_module_id: opt_i64(arguments, "i2c_module_id")?,
            endpoint: opt_str(arguments, "endpoint")?,
            format_string: opt_str(arguments, "format_string")?,
            enabled: opt_bool(arguments, "enabled")?,
        })
    }

    pub fn execute(ports: &Ports, name: &str, arguments: &Value) -> Result<Value, String> {
        match name {
            "list_display_bindings" => {
                let train_id = req_i64(arguments, "train_id")?;
                Ok(json!({
                    "display_bindings": ports
                        .bindings
                        .list_display_bindings(train_id)
                        .iter()
                        .map(serialize_display_binding)
                        .collect::<Vec<_>>()
                }))
            }
            "create_display_binding" => {
                let train_id = req_i64(arguments, "train_id")?;
                let attrs = build_attrs(arguments)?;
                ports
                    .bindings
                    .create_display_binding(train_id, attrs)
                    .map(|binding| json!({"display_binding": serialize_display_binding(&binding)}))
                    .map_err(port_error)
            }
            "update_display_binding" => {
                let id = req_i64(arguments, "id")?;
                match ports.bindings.get_display_binding(id) {
                    Ok(binding) => {
                        let changes = build_attrs(arguments)?;
                        ports
                            .bindings
                            .update_display_binding(&binding, changes)
                            .map(|updated| json!({"display_binding": serialize_display_binding(&updated)}))
                            .map_err(port_error)
                    }
                    Err(error) => Err(not_found(error, || {
                        format!("Display binding not found with id {id}")
                    })),
                }
            }
            _ => {
                let id = req_i64(arguments, "id")?;
                match ports.bindings.get_display_binding(id) {
                    Ok(binding) => ports
                        .bindings
                        .delete_display_binding(&binding)
                        .map_err(port_error)
                        .map(|_| json!({"deleted": true, "id": id})),
                    Err(error) => Err(not_found(error, || {
                        format!("Display binding not found with id {id}")
                    })),
                }
            }
        }
    }
}

// ---------------------------------------------------------------------------
// VirtualJoystickTools
// ---------------------------------------------------------------------------

mod vjoy {
    use super::*;

    pub const TOOL_NAMES: [&str; 10] = [
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

    const EMPTY_TOOLS: [&str; 7] = [
        "get_virtual_joystick_status",
        "list_virtual_joystick_mappings",
        "enable_virtual_joystick",
        "disable_virtual_joystick",
        "retry_virtual_joystick",
        "cleanup_virtual_joystick",
        "check_virtual_joystick_installation",
    ];

    fn empty_schema() -> Value {
        json!({"type": "object", "properties": {}, "required": [], "additionalProperties": false})
    }

    fn id_schema() -> Value {
        json!({
            "type": "object",
            "properties": {"id": {"type": "integer", "description": "Virtual joystick mapping ID"}},
            "required": ["id"],
            "additionalProperties": false
        })
    }

    fn axis_schema() -> Value {
        json!({
            "type": "object",
            "properties": {
                "input_id": {"type": "integer", "description": "Hardware input ID"},
                "device_index": {"type": "integer", "enum": [1], "description": "Virtual device index"},
                "axis": {"type": "string", "enum": VJOY_AXES, "description": "Virtual joystick axis"},
                "inverted": {"type": "boolean", "description": "Invert the axis direction"},
                "replace": {
                    "type": "boolean",
                    "description": "Replace an existing simulator/API destination"
                }
            },
            "required": ["input_id", "axis"],
            "additionalProperties": false
        })
    }

    fn button_schema() -> Value {
        json!({
            "type": "object",
            "properties": {
                "input_id": {"type": "integer", "description": "Hardware input ID"},
                "device_index": {"type": "integer", "enum": [1], "description": "Virtual device index"},
                "button": {"type": "integer", "minimum": 1, "maximum": 32},
                "replace": {
                    "type": "boolean",
                    "description": "Replace an existing simulator/API destination"
                }
            },
            "required": ["input_id", "button"],
            "additionalProperties": false
        })
    }

    pub fn tools() -> Vec<ToolDef> {
        vec![
            ToolDef {
                name: "get_virtual_joystick_status",
                description: "Get virtual joystick runtime status.",
                input_schema: empty_schema(),
            },
            ToolDef {
                name: "list_virtual_joystick_mappings",
                description: "List all hardware inputs mapped to the virtual joystick.",
                input_schema: empty_schema(),
            },
            ToolDef {
                name: "map_virtual_joystick_axis",
                description: "Create or update an analog input mapping to a virtual joystick axis.",
                input_schema: axis_schema(),
            },
            ToolDef {
                name: "map_virtual_joystick_button",
                description:
                    "Create or update a button input mapping to a virtual joystick button.",
                input_schema: button_schema(),
            },
            ToolDef {
                name: "delete_virtual_joystick_mapping",
                description: "Delete a virtual joystick mapping.",
                input_schema: id_schema(),
            },
            ToolDef {
                name: "enable_virtual_joystick",
                description: "Begin enabling the virtual joystick.",
                input_schema: empty_schema(),
            },
            ToolDef {
                name: "disable_virtual_joystick",
                description: "Begin disabling the virtual joystick.",
                input_schema: empty_schema(),
            },
            ToolDef {
                name: "retry_virtual_joystick",
                description: "Retry virtual joystick setup or connection.",
                input_schema: empty_schema(),
            },
            ToolDef {
                name: "cleanup_virtual_joystick",
                description: "Begin removing a leftover virtual joystick device.",
                input_schema: empty_schema(),
            },
            ToolDef {
                name: "check_virtual_joystick_installation",
                description:
                    "Recheck the vJoy installation after the user completes driver repair.",
                input_schema: empty_schema(),
            },
        ]
    }

    /// Ordered argument errors from `validate_arguments/2`.
    type ValidationErrors = Vec<(String, String)>;

    fn validate_object(
        arguments: &Value,
        required: &[&str],
        optional: &[&str],
    ) -> Result<(), ValidationErrors> {
        let Some(map) = arguments.as_object() else {
            return Err(vec![(
                "arguments".to_string(),
                "must be an object".to_string(),
            )]);
        };
        let mut errors: ValidationErrors = vec![];
        for field in required {
            if !map.contains_key(*field) {
                errors.push(((*field).to_string(), "is required".to_string()));
            }
        }
        for key in map.keys() {
            if !required.contains(&key.as_str()) && !optional.contains(&key.as_str()) {
                errors.push((key.clone(), "is not allowed".to_string()));
            }
        }
        if errors.is_empty() {
            Ok(())
        } else {
            Err(errors)
        }
    }

    fn require_integer(
        errors: ValidationErrors,
        arguments: &Value,
        field: &str,
        predicate: impl Fn(i64) -> bool,
        message: &str,
    ) -> ValidationErrors {
        match raw(arguments, field) {
            Some(value) => match value.as_i64() {
                Some(number) if predicate(number) => errors,
                _ => push_error(errors, field, message),
            },
            None => errors,
        }
    }

    fn require_value(
        errors: ValidationErrors,
        arguments: &Value,
        field: &str,
        predicate: impl Fn(&Value) -> bool,
        message: &str,
    ) -> ValidationErrors {
        match raw(arguments, field) {
            Some(value) if predicate(value) => errors,
            Some(_) => push_error(errors, field, message),
            None => errors,
        }
    }

    fn push_error(mut errors: ValidationErrors, field: &str, message: &str) -> ValidationErrors {
        errors.push((field.to_string(), message.to_string()));
        errors
    }

    fn validation_failed_argument_errors(errors: ValidationErrors) -> Value {
        json!({
            "status": "error",
            "reason": {
                "code": "validation_failed",
                "errors": errors
                    .iter()
                    .map(|(field, message)| json!({"field": field, "message": message}))
                    .collect::<Vec<_>>()
            }
        })
    }

    fn validation_failed_changeset(errors: &[(String, Vec<String>)]) -> Value {
        let grouped = errors.iter().fold(
            Map::new(),
            |mut grouped: Map<String, Value>, (field, messages)| {
                let entry = grouped
                    .entry(field.clone())
                    .or_insert_with(|| Value::Array(vec![]));
                if let Value::Array(list) = entry {
                    list.extend(messages.iter().cloned().map(Value::String));
                }
                grouped
            },
        );
        json!({
            "status": "error",
            "reason": {"code": "validation_failed", "errors": grouped}
        })
    }

    fn error_result(reason: Option<VjoyReason>) -> Value {
        json!({"status": "error", "reason": reason_json(&reason)})
    }

    fn reason_json(reason: &Option<VjoyReason>) -> Value {
        match reason {
            None => Value::Null,
            Some(VjoyReason::Code(code)) => json!({"code": code}),
            Some(VjoyReason::CodeWithDetails(code, details)) => {
                json!({"code": code, "details": details})
            }
        }
    }

    pub fn execute(ports: &Ports, name: &str, arguments: &Value) -> Result<Value, String> {
        if let Err(errors) = validate_arguments(name, arguments) {
            return Ok(validation_failed_argument_errors(errors));
        }
        do_execute(ports, name, arguments)
    }

    fn validate_arguments(name: &str, arguments: &Value) -> Result<(), ValidationErrors> {
        if EMPTY_TOOLS.contains(&name) {
            return validate_object(arguments, &[], &[]);
        }
        match name {
            "map_virtual_joystick_axis" => {
                validate_object(
                    arguments,
                    &["input_id", "axis"],
                    &["device_index", "inverted", "replace"],
                )?;
                let errors = vec![];
                let errors = require_integer(
                    errors,
                    arguments,
                    "input_id",
                    |_| true,
                    "must be an integer",
                );
                let errors = require_value(
                    errors,
                    arguments,
                    "axis",
                    is_supported_axis,
                    "must be a supported axis",
                );
                let errors = require_integer(
                    errors,
                    arguments,
                    "device_index",
                    |n| n == 1,
                    "must be the integer 1",
                );
                let errors = require_value(
                    errors,
                    arguments,
                    "inverted",
                    Value::is_boolean,
                    "must be a boolean",
                );
                let errors = require_value(
                    errors,
                    arguments,
                    "replace",
                    Value::is_boolean,
                    "must be a boolean",
                );
                outcome(errors)
            }
            "map_virtual_joystick_button" => {
                validate_object(
                    arguments,
                    &["input_id", "button"],
                    &["device_index", "replace"],
                )?;
                let errors = vec![];
                let errors = require_integer(
                    errors,
                    arguments,
                    "input_id",
                    |_| true,
                    "must be an integer",
                );
                let errors = require_integer(
                    errors,
                    arguments,
                    "button",
                    |n| (1..=32).contains(&n),
                    "must be an integer from 1 to 32",
                );
                let errors = require_integer(
                    errors,
                    arguments,
                    "device_index",
                    |n| n == 1,
                    "must be the integer 1",
                );
                let errors = require_value(
                    errors,
                    arguments,
                    "replace",
                    Value::is_boolean,
                    "must be a boolean",
                );
                outcome(errors)
            }
            _ => {
                validate_object(arguments, &["id"], &[])?;
                let errors = vec![];
                let errors =
                    require_integer(errors, arguments, "id", |_| true, "must be an integer");
                outcome(errors)
            }
        }
    }

    fn is_supported_axis(value: &Value) -> bool {
        value.as_str().is_some_and(|axis| VJOY_AXES.contains(&axis))
    }

    fn outcome(errors: ValidationErrors) -> Result<(), ValidationErrors> {
        if errors.is_empty() {
            Ok(())
        } else {
            Err(errors)
        }
    }

    fn do_execute(ports: &Ports, name: &str, arguments: &Value) -> Result<Value, String> {
        match name {
            "get_virtual_joystick_status" => {
                let VjoyStatusDetails { status, reason } = ports.vjoy.status_details();
                Ok(json!({"status": status, "reason": reason_json(&reason)}))
            }
            "list_virtual_joystick_mappings" => Ok(json!({
                "status": "ok",
                "mappings": ports
                    .vjoy
                    .list_mappings()
                    .iter()
                    .map(serialize_vjoy_mapping)
                    .collect::<Vec<_>>()
            })),
            "map_virtual_joystick_axis" => {
                let input_id = arguments["input_id"].as_i64().unwrap_or_default();
                let axis = arguments["axis"].as_str().unwrap_or_default().to_string();
                let draft = VjoyMappingDraft {
                    target_type: VjoyTarget::Axis,
                    axis: Some(axis),
                    button: None,
                    device_index: arguments
                        .get("device_index")
                        .and_then(Value::as_i64)
                        .unwrap_or(1),
                    inverted: arguments
                        .get("inverted")
                        .and_then(Value::as_bool)
                        .unwrap_or(false),
                };
                put_mapping(ports, input_id, draft, replace_flag(arguments))
            }
            "map_virtual_joystick_button" => {
                let input_id = arguments["input_id"].as_i64().unwrap_or_default();
                let button = arguments["button"].as_i64().unwrap_or_default();
                let draft = VjoyMappingDraft {
                    target_type: VjoyTarget::Button,
                    axis: None,
                    button: Some(button),
                    device_index: arguments
                        .get("device_index")
                        .and_then(Value::as_i64)
                        .unwrap_or(1),
                    inverted: false,
                };
                put_mapping(ports, input_id, draft, replace_flag(arguments))
            }
            "delete_virtual_joystick_mapping" => {
                let id = arguments["id"].as_i64().unwrap_or_default();
                match ports.vjoy.delete_mapping(id) {
                    Ok(_) => Ok(json!({"status": "ok", "reason": null, "deleted": true, "id": id})),
                    Err(PortError::NotFound) => Ok(error_result(Some(VjoyReason::Code(
                        "not_found".to_string(),
                    )))),
                    Err(PortError::Validation(errors)) => Ok(validation_failed_changeset(&errors)),
                    Err(other) => Ok(error_result(Some(VjoyReason::Code(format!("{other:?}"))))),
                }
            }
            "enable_virtual_joystick" => lifecycle(ports, VjoyCommand::Enable),
            "disable_virtual_joystick" => lifecycle(ports, VjoyCommand::Disable),
            "retry_virtual_joystick" => lifecycle(ports, VjoyCommand::Retry),
            "cleanup_virtual_joystick" => lifecycle(ports, VjoyCommand::RemoveLeftover),
            _ => lifecycle(ports, VjoyCommand::Repair),
        }
    }

    fn replace_flag(arguments: &Value) -> bool {
        arguments
            .get("replace")
            .and_then(Value::as_bool)
            .unwrap_or(false)
    }

    fn put_mapping(
        ports: &Ports,
        input_id: i64,
        draft: VjoyMappingDraft,
        replace: bool,
    ) -> Result<Value, String> {
        match ports.vjoy.put_mapping(input_id, draft, replace) {
            Ok(mapping) => {
                ports.vjoy.reload_mappings();
                Ok(json!({
                    "status": "ok",
                    "reason": null,
                    "mapping": serialize_vjoy_mapping(&mapping)
                }))
            }
            Err(VjoyPutError::DestinationConflict) => Ok(error_result(Some(VjoyReason::Code(
                "destination_conflict".to_string(),
            )))),
            Err(VjoyPutError::NotFound) => Ok(error_result(Some(VjoyReason::Code(
                "not_found".to_string(),
            )))),
            Err(VjoyPutError::Validation(errors)) => Ok(validation_failed_changeset(&errors)),
        }
    }

    fn lifecycle(ports: &Ports, command: VjoyCommand) -> Result<Value, String> {
        match ports.vjoy.lifecycle(command) {
            Ok(()) => Ok(json!({"status": "accepted", "reason": null})),
            Err(reason) => Ok(error_result(Some(reason))),
        }
    }
}
