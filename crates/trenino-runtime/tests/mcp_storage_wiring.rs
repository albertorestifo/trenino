//! End-to-end wiring tests for the storage-backed MCP ports: every tool
//! family is exercised over the real HTTP transport (initialize → SSE session
//! → tools/call) against `StoragePorts` over a seeded disposable database.
//!
//! Mirrors the Elixir oracle suites `test/trenino/mcp/tools/*_test.exs` plus
//! `test/trenino_web/controllers/mcp/mcp_controller_test.exs`; DB side effects
//! (rows and topic revision bumps) are asserted through the typed repositories
//! exactly like `tests/domain_*.rs`.

use std::io::{Read, Write};
use std::net::{SocketAddr, TcpStream};
use std::sync::Arc;
use std::time::Duration;

use serde_json::{json, Value};
use tempfile::tempdir;
use trenino_core::{EntityId, OperationId};
use trenino_runtime::mcp::ports::Ports;
use trenino_runtime::mcp::server::{McpServer, McpServerStatus};
use trenino_runtime::mcp::storage_ports::StoragePorts;
use trenino_runtime::storage::bindings::{OutputBindingDraft, OutputBindingOperator};
use trenino_runtime::storage::trains::{ElementDraft, ElementKind, TrainDraft};
use trenino_runtime::storage::{Database, DeviceDraft, I2cModuleDraft, InputDraft, InputKind, OutputDraft};

// ---------------------------------------------------------------------------
// Seeded fixture
// ---------------------------------------------------------------------------

struct Fixture {
    _dir: tempfile::TempDir,
    db: Arc<Database>,
    _server: Arc<McpServer>,
    port: u16,
    train_id: i64,
    button_element_id: i64,
    analog_input_id: i64,
    button_input_id: i64,
    output_id: i64,
    i2c_module_id: i64,
}

fn seed() -> Fixture {
    let dir = tempdir().unwrap();
    let db = Arc::new(Database::open_full(dir.path().join("mcp.db")).unwrap());
    db.allocate_epoch().unwrap();

    let device = db
        .create_device(
            OperationId(1),
            DeviceDraft {
                name: "Deck".into(),
                description: None,
                config_id: None,
            },
        )
        .unwrap()
        .record;
    let analog_input = db
        .create_input(
            OperationId(2),
            device.id,
            InputDraft {
                pin: 2,
                kind: InputKind::Analog,
                sensitivity: Some(10),
                debounce: None,
                name: Some("Regulator".into()),
                matrix_id: None,
            },
        )
        .unwrap()
        .record;
    let button_input = db
        .create_input(
            OperationId(3),
            device.id,
            InputDraft {
                pin: 3,
                kind: InputKind::Button,
                sensitivity: None,
                debounce: Some(50),
                name: Some("Horn".into()),
                matrix_id: None,
            },
        )
        .unwrap()
        .record;
    let output = db
        .create_output(
            OperationId(4),
            device.id,
            OutputDraft {
                pin: 5,
                name: Some("LED".into()),
            },
        )
        .unwrap()
        .record;
    let train = db
        .create_train(
            OperationId(5),
            TrainDraft {
                name: "Freight".into(),
                description: None,
                identifiers: vec!["DB_CARGO".into(), "AAA".into()],
            },
        )
        .unwrap()
        .record;
    let element = db
        .create_train_element(
            OperationId(6),
            train.id,
            ElementDraft {
                kind: ElementKind::Button,
                name: "Horn Hi".into(),
            },
        )
        .unwrap()
        .record;
    let i2c_module = db
        .create_i2c_module(
            OperationId(7),
            device.id,
            I2cModuleDraft {
                name: Some("Speed".into()),
                module_chip: "ht16k33".into(),
                i2c_address: 0x70,
                params: Some(trenino_runtime::storage::Ht16k33Params {
                    brightness: 8,
                    num_digits: 4,
                    display_type: trenino_runtime::storage::DisplayType::FourteenSegment,
                    has_dot: false,
                    align_right: true,
                    min_value: Some(0.0),
                }),
            },
        )
        .unwrap()
        .record;

    let ports: Ports = StoragePorts::new(db.clone()).into_ports();
    let server = Arc::new(McpServer::new(Arc::new(ports), None));
    let address = match server.start(SocketAddr::from(([127, 0, 0, 1], 0))).unwrap() {
        McpServerStatus::Running { address } => address,
        other => panic!("expected running server, got {other:?}"),
    };

    Fixture {
        _dir: dir,
        db,
        _server: server,
        port: address.port(),
        train_id: train.id.0,
        button_element_id: element.id.0,
        analog_input_id: analog_input.id.0,
        button_input_id: button_input.id.0,
        output_id: output.id.0,
        i2c_module_id: i2c_module.id.0,
    }
}

// ---------------------------------------------------------------------------
// Loopback HTTP + SSE client (same approach as tests/mcp_server.rs)
// ---------------------------------------------------------------------------

struct Session {
    port: u16,
    stream: TcpStream,
    buffer: String,
    session_id: String,
}

fn connect(port: u16) -> Session {
    let mut stream = TcpStream::connect(("127.0.0.1", port)).unwrap();
    stream.set_read_timeout(Some(Duration::from_secs(5))).unwrap();
    let request = "GET /mcp/sse HTTP/1.1\r\nAccept: text/event-stream\r\n\r\n";
    stream.write_all(request.as_bytes()).unwrap();
    let mut session = Session {
        port,
        stream,
        buffer: String::new(),
        session_id: String::new(),
    };
    let head = session.read_until("\r\n\r\n");
    assert!(head.starts_with("HTTP/1.1 200"));
    let (event, data) = session.next_event();
    assert_eq!(event, "endpoint");
    session.session_id = data
        .split("session_id=")
        .nth(1)
        .unwrap()
        .trim()
        .to_string();
    session
}

impl Session {
    fn read_more(&mut self) {
        let mut chunk = [0_u8; 4096];
        let read = self.stream.read(&mut chunk).unwrap();
        assert!(read > 0, "SSE stream ended unexpectedly");
        self.buffer.push_str(&String::from_utf8_lossy(&chunk[..read]));
    }

    fn read_until(&mut self, marker: &str) -> String {
        while !self.buffer.contains(marker) {
            self.read_more();
        }
        let (head, _) = self.buffer.split_once(marker).unwrap();
        let head = head.to_string();
        self.buffer.drain(..head.len() + marker.len());
        head
    }

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

    /// initialize + one tools/call; returns (isError, decoded payload).
    fn call(&mut self, id: i64, name: &str, arguments: Value) -> (bool, Value) {
        if id == 1 {
            let init = json!({"jsonrpc": "2.0", "method": "initialize", "id": 0,
                "params": {"protocolVersion": "2024-11-05", "capabilities": {}, "clientInfo": {"name": "test", "version": "0"}}});
            self.post(&init);
            let (_, data) = self.next_event();
            let message: Value = serde_json::from_str(&data).unwrap();
            assert_eq!(message["result"]["serverInfo"]["name"], "Trenino");
        }
        let request = json!({"jsonrpc": "2.0", "method": "tools/call", "id": id,
            "params": {"name": name, "arguments": arguments}});
        self.post(&request);
        let (_, data) = self.next_event();
        let message: Value = serde_json::from_str(&data).unwrap();
        let result = &message["result"];
        let is_error = result.get("isError").and_then(Value::as_bool).unwrap_or(false);
        let text = result["content"][0]["text"].as_str().unwrap();
        let payload = serde_json::from_str::<Value>(text)
            .unwrap_or_else(|_| Value::String(text.to_string()));
        (is_error, payload)
    }

    fn post(&mut self, request: &Value) {
        let body = request.to_string();
        let mut stream = TcpStream::connect(("127.0.0.1", self.port)).unwrap();
        let http = format!(
            "POST /mcp/messages?session_id={} HTTP/1.1\r\nHost: 127.0.0.1\r\nContent-Type: application/json\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{}",
            self.session_id,
            body.len(),
            body
        );
        stream.write_all(http.as_bytes()).unwrap();
        let mut raw = Vec::new();
        stream.read_to_end(&mut raw).unwrap();
        let text = String::from_utf8_lossy(&raw).to_string();
        assert!(text.starts_with("HTTP/1.1 202"), "post failed: {text}");
    }
}

// ---------------------------------------------------------------------------
// Trains
// ---------------------------------------------------------------------------

#[test]
fn trains_list_and_get_over_http() {
    let fixture = seed();
    let mut session = connect(fixture.port);
    let (error, payload) = session.call(1, "list_trains", json!({}));
    assert!(!error);
    // identifier_values/1 sorts the prefixes.
    assert_eq!(
        payload,
        json!({"trains": [{"id": fixture.train_id, "name": "Freight",
            "identifiers": ["AAA", "DB_CARGO"], "description": null}]})
    );

    let (error, payload) = session.call(
        2,
        "get_train",
        json!({"train_id": 9999}),
    );
    assert!(error);
    assert_eq!(payload, json!("Train not found with id 9999"));
}

// ---------------------------------------------------------------------------
// Elements
// ---------------------------------------------------------------------------

#[test]
fn elements_crud_and_errors_over_http() {
    let fixture = seed();
    let mut session = connect(fixture.port);

    let (error, payload) = session.call(
        1,
        "create_element",
        json!({"train_id": fixture.train_id, "name": "Sander", "type": "lever"}),
    );
    assert!(!error);
    let element_id = payload["element"]["id"].as_i64().unwrap();
    assert_eq!(payload["element"]["type"], "lever");

    let (error, payload) = session.call(2, "list_elements", json!({"train_id": fixture.train_id}));
    assert!(!error);
    let names: Vec<&str> = payload["elements"]
        .as_array()
        .unwrap()
        .iter()
        .map(|e| e["name"].as_str().unwrap())
        .collect();
    assert_eq!(names, ["Horn Hi", "Sander"]); // ordered by name

    // Row visible through the repository (DB side effect).
    let stored = fixture
        .db
        .get_train_element(EntityId(element_id))
        .unwrap()
        .unwrap();
    assert_eq!(stored.name, "Sander");
    assert_eq!(stored.kind, ElementKind::Lever);

    let (error, payload) = session.call(3, "delete_element", json!({"id": 9999}));
    assert!(error);
    assert_eq!(payload, json!("Element not found with id 9999"));

    let (error, payload) = session.call(4, "delete_element", json!({"id": element_id}));
    assert!(!error);
    assert_eq!(payload, json!({"deleted": true, "id": element_id}));
    assert!(fixture.db.get_train_element(EntityId(element_id)).unwrap().is_none());
}

// ---------------------------------------------------------------------------
// Hardware catalog + i2c modules
// ---------------------------------------------------------------------------

#[test]
fn hardware_catalog_over_http() {
    let fixture = seed();
    let mut session = connect(fixture.port);

    let (_, payload) = session.call(1, "list_devices", json!({}));
    assert_eq!(payload, json!({"devices": [{"id": 1, "name": "Deck"}]}));

    let (error, payload) = session.call(2, "list_device_inputs", json!({"device_id": 1}));
    assert!(!error);
    assert_eq!(
        payload,
        json!({"inputs": [
            {"id": fixture.analog_input_id, "name": "Regulator", "pin": 2, "input_type": "analog"},
            {"id": fixture.button_input_id, "name": "Horn", "pin": 3, "input_type": "button"},
        ]})
    );

    let (_, payload) = session.call(3, "list_hardware_outputs", json!({}));
    assert_eq!(
        payload,
        json!({"outputs": [
            {"id": fixture.output_id, "name": "LED", "pin": 5, "device_id": 1, "device_name": "Deck"},
        ]})
    );

    let (_, payload) = session.call(4, "list_i2c_modules", json!({}));
    let module = &payload["i2c_modules"][0];
    assert_eq!(module["device_name"], "Deck");
    assert_eq!(module["module_chip"], "ht16k33");
    assert_eq!(module["i2c_address"], 0x70);
    assert_eq!(module["brightness"], 8);
}

#[test]
fn i2c_module_crud_and_errors_over_http() {
    let fixture = seed();
    let mut session = connect(fixture.port);

    let (error, payload) = session.call(
        1,
        "create_i2c_module",
        json!({"device_id": 1, "module_chip": "ht16k33", "i2c_address": "0x71", "brightness": 7}),
    );
    assert!(!error);
    let module_id = payload["i2c_module"]["id"].as_i64().unwrap();
    assert_eq!(payload["i2c_module"]["i2c_address"], 113);
    assert_eq!(payload["i2c_module"]["brightness"], 7);
    assert_eq!(payload["i2c_module"]["num_digits"], 4);
    assert_eq!(payload["i2c_module"]["display_type"], "fourteen_segment");

    // Duplicate (device, address) mirrors the Ecto unique constraint.
    let (error, payload) = session.call(
        2,
        "create_i2c_module",
        json!({"device_id": 1, "module_chip": "ht16k33", "i2c_address": "0x71"}),
    );
    assert!(error);
    assert_eq!(payload, json!("Validation failed: i2c_address has already been taken"));

    // Brightness bounds mirror validate_number messages.
    let (error, payload) = session.call(
        3,
        "create_i2c_module",
        json!({"device_id": 1, "module_chip": "ht16k33", "i2c_address": "0x72", "brightness": 16}),
    );
    assert!(error);
    assert_eq!(
        payload,
        json!("Validation failed: brightness must be less than or equal to 15")
    );

    let (error, payload) = session.call(
        4,
        "update_i2c_module",
        json!({"id": module_id, "brightness": 9, "name": "Ampere"}),
    );
    assert!(!error);
    assert_eq!(payload["i2c_module"]["brightness"], 9);
    assert_eq!(payload["i2c_module"]["name"], "Ampere");

    let (error, payload) = session.call(5, "update_i2c_module", json!({"id": 9999}));
    assert!(error);
    assert_eq!(payload, json!("I2C module not found with id 9999"));

    let (error, payload) = session.call(6, "delete_i2c_module", json!({"id": module_id}));
    assert!(!error);
    assert_eq!(payload, json!({"deleted": true, "id": module_id}));
}

// ---------------------------------------------------------------------------
// Output bindings
// ---------------------------------------------------------------------------

#[test]
fn output_bindings_crud_over_http() {
    let fixture = seed();
    let mut session = connect(fixture.port);

    let (error, payload) = session.call(
        1,
        "create_output_binding",
        json!({"train_id": fixture.train_id, "name": "Headlights",
            "output_id": fixture.output_id, "endpoint": "CurrentDrivableActor/Lights.Headlights",
            "operator": "eq_true"}),
    );
    assert!(!error);
    let binding_id = payload["output_binding"]["id"].as_i64().unwrap();
    assert_eq!(payload["output_binding"]["enabled"], true);

    // The mutation committed exactly one bindings-topic revision: the next
    // repository mutation observes revision 2.
    let second_output = fixture
        .db
        .create_output(
            OperationId(49),
            EntityId(1),
            OutputDraft {
                pin: 6,
                name: Some("Second".into()),
            },
        )
        .unwrap()
        .record;
    let follow = fixture
        .db
        .create_output_binding(
            OperationId(50),
            EntityId(fixture.train_id),
            OutputBindingDraft {
                name: "Other".into(),
                output_type: None,
                output_id: second_output.id,
                endpoint: "a.b".into(),
                operator: OutputBindingOperator::EqTrue,
                value_a: None,
                value_b: None,
                enabled: None,
            },
        )
        .unwrap();
    assert_eq!(follow.receipt.metadata.revision, 2);

    let (error, payload) = session.call(2, "list_output_bindings", json!({"train_id": fixture.train_id}));
    assert!(!error);
    assert_eq!(payload["output_bindings"].as_array().unwrap().len(), 2);
    assert_eq!(payload["output_bindings"][0]["name"], "Headlights"); // ordered by name

    // Missing name is the Ecto required error.
    let (error, payload) = session.call(
        3,
        "create_output_binding",
        json!({"train_id": fixture.train_id, "output_id": fixture.output_id,
            "endpoint": "x.y", "operator": "eq_true"}),
    );
    assert!(error);
    assert_eq!(payload, json!("Validation failed: name can't be blank"));

    // Between requires value_b (changeset validation via the repository).
    let (error, payload) = session.call(
        4,
        "create_output_binding",
        json!({"train_id": fixture.train_id, "name": "B", "output_id": fixture.output_id,
            "endpoint": "x.y", "operator": "between", "value_a": 0.1}),
    );
    assert!(error);
    assert_eq!(payload, json!("Validation failed: value_b can't be blank"));

    let (error, payload) = session.call(
        5,
        "update_output_binding",
        json!({"id": binding_id, "enabled": false}),
    );
    assert!(!error);
    assert_eq!(payload["output_binding"]["enabled"], false);

    let (error, payload) = session.call(6, "delete_output_binding", json!({"id": 9999}));
    assert!(error);
    assert_eq!(payload, json!("Output binding not found with id 9999"));

    let (error, payload) = session.call(7, "delete_output_binding", json!({"id": binding_id}));
    assert!(!error);
    assert_eq!(payload, json!({"deleted": true, "id": binding_id}));
}

// ---------------------------------------------------------------------------
// Button bindings + vJoy destination exclusivity
// ---------------------------------------------------------------------------

#[test]
fn button_bindings_and_destination_conflict_over_http() {
    let fixture = seed();
    let mut session = connect(fixture.port);

    let (error, payload) = session.call(
        1,
        "create_button_binding",
        json!({"element_id": fixture.button_element_id, "input_id": fixture.button_input_id,
            "mode": "simple", "endpoint": "CurrentDrivableActor/Horn.Hi"}),
    );
    assert!(!error);
    assert_eq!(payload["button_binding"]["mode"], "simple");
    assert_eq!(payload["button_binding"]["on_value"], 1.0);
    assert_eq!(payload["button_binding"]["repeat_interval_ms"], 100);

    // The bound input can no longer be mapped to vJoy without replace.
    let (error, payload) = session.call(
        2,
        "map_virtual_joystick_button",
        json!({"input_id": fixture.button_input_id, "button": 4}),
    );
    assert!(!error);
    assert_eq!(
        payload,
        json!({"status": "error", "reason": {"code": "destination_conflict"}})
    );

    // replace: true deletes the enabled binding in the same transaction.
    let (error, payload) = session.call(
        3,
        "map_virtual_joystick_button",
        json!({"input_id": fixture.button_input_id, "button": 4, "replace": true}),
    );
    assert!(!error);
    assert_eq!(payload["status"], "ok");
    assert_eq!(payload["mapping"]["button"], 4);

    let (error, payload) = session.call(
        4,
        "get_button_binding",
        json!({"element_id": fixture.button_element_id}),
    );
    assert!(error);
    assert_eq!(
        payload,
        json!(format!("No button binding found for element {}", fixture.button_element_id))
    );

    // Simple mode requires an endpoint.
    let element2 = fixture
        .db
        .create_train_element(
            OperationId(60),
            EntityId(fixture.train_id),
            ElementDraft {
                kind: ElementKind::Button,
                name: "Horn Lo".into(),
            },
        )
        .unwrap()
        .record;
    let (error, payload) = session.call(
        5,
        "create_button_binding",
        json!({"element_id": element2.id.0, "input_id": fixture.button_input_id, "mode": "simple"}),
    );
    assert!(error);
    assert_eq!(payload, json!("Validation failed: endpoint can't be blank"));

    let _ = session.call(6, "enable_virtual_joystick", json!({})); // lifecycle error covered below
}

#[test]
fn vjoy_mappings_and_lifecycle_over_http() {
    let fixture = seed();
    let mut session = connect(fixture.port);

    // Manager absent on a non-Windows host: unsupported, no reason.
    let (error, payload) = session.call(1, "get_virtual_joystick_status", json!({}));
    assert!(!error);
    assert_eq!(payload, json!({"status": "unsupported", "reason": null}));

    let (error, payload) = session.call(2, "enable_virtual_joystick", json!({}));
    assert!(!error);
    assert_eq!(
        payload,
        json!({"status": "error", "reason": {"code": "unsupported"}})
    );

    let (error, payload) = session.call(
        3,
        "map_virtual_joystick_axis",
        json!({"input_id": fixture.analog_input_id, "axis": "x"}),
    );
    assert!(!error);
    assert_eq!(payload["status"], "ok");
    assert_eq!(payload["mapping"]["axis"], "x");
    assert_eq!(payload["mapping"]["device_index"], 1);
    assert_eq!(payload["mapping"]["inverted"], false);

    // The mapping committed one vjoy-topic revision.
    let metadata = fixture.db.vjoy_topic_metadata().unwrap();
    assert_eq!(metadata.revision, 1);

    let (_, payload) = session.call(4, "list_virtual_joystick_mappings", json!({}));
    assert_eq!(payload["mappings"].as_array().unwrap().len(), 1);

    // Unknown input mirrors {:error, :not_found}.
    let (error, payload) = session.call(5, "map_virtual_joystick_axis", json!({"input_id": 9999, "axis": "y"}));
    assert!(!error);
    assert_eq!(payload, json!({"status": "error", "reason": {"code": "not_found"}}));

    // Structural argument validation rejects a bad axis.
    let (error, payload) = session.call(6, "map_virtual_joystick_axis", json!({"input_id": fixture.analog_input_id, "axis": "wobble"}));
    assert!(!error);
    assert_eq!(payload["reason"]["code"], "validation_failed");

    let mapping_id = stored_mapping_id(&mut session);
    let (error, payload) = session.call(8, "delete_virtual_joystick_mapping", json!({"id": mapping_id}));
    assert!(!error);
    assert_eq!(payload, json!({"status": "ok", "reason": null, "deleted": true, "id": mapping_id}));
}

fn stored_mapping_id(session: &mut Session) -> i64 {
    let (_, payload) = session.call(7, "list_virtual_joystick_mappings", json!({}));
    payload["mappings"][0]["id"].as_i64().unwrap()
}

// ---------------------------------------------------------------------------
// Display bindings
// ---------------------------------------------------------------------------

#[test]
fn display_bindings_crud_over_http() {
    let fixture = seed();
    let mut session = connect(fixture.port);

    let (error, payload) = session.call(
        1,
        "create_display_binding",
        json!({"train_id": fixture.train_id, "i2c_module_id": fixture.i2c_module_id,
            "name": "Speed", "endpoint": "CurrentDrivableActor/Speed", "format_string": "{value:.0f}"}),
    );
    assert!(!error);
    let binding_id = payload["display_binding"]["id"].as_i64().unwrap();
    assert_eq!(payload["display_binding"]["enabled"], true);

    let (error, payload) = session.call(2, "list_display_bindings", json!({"train_id": fixture.train_id}));
    assert!(!error);
    assert_eq!(payload["display_bindings"].as_array().unwrap().len(), 1);

    // Malformed format string repeats the DisplayFormatter message.
    let (error, payload) = session.call(
        3,
        "create_display_binding",
        json!({"train_id": fixture.train_id, "i2c_module_id": fixture.i2c_module_id,
            "endpoint": "a.b", "format_string": "{value:.42f}"}),
    );
    assert!(error);
    assert_eq!(
        payload,
        json!("Validation failed: format_string Use {value} or {value:.Nf}, with precision from 0 to 10")
    );

    let (error, payload) = session.call(
        4,
        "update_display_binding",
        json!({"id": binding_id, "format_string": "{value}"}),
    );
    assert!(!error);
    assert_eq!(payload["display_binding"]["format_string"], "{value}");

    let (error, payload) = session.call(5, "delete_display_binding", json!({"id": 9999}));
    assert!(error);
    assert_eq!(payload, json!("Display binding not found with id 9999"));

    let (error, payload) = session.call(6, "delete_display_binding", json!({"id": binding_id}));
    assert!(!error);
    assert_eq!(payload, json!({"deleted": true, "id": binding_id}));
}

// ---------------------------------------------------------------------------
// Sequences
// ---------------------------------------------------------------------------

#[test]
fn sequences_crud_over_http() {
    let fixture = seed();
    let mut session = connect(fixture.port);

    let (error, payload) = session.call(
        1,
        "create_sequence",
        json!({"train_id": fixture.train_id, "name": "Startup", "commands": [
            {"endpoint": "a.b", "value": 1.0, "delay_ms": 100},
            {"endpoint": "c.d", "value": 0.5},
        ]}),
    );
    assert!(!error);
    let sequence_id = payload["sequence"]["id"].as_i64().unwrap();
    let commands = payload["sequence"]["commands"].as_array().unwrap();
    assert_eq!(commands.len(), 2);
    assert_eq!(commands[0]["position"], 0); // reindexed from zero
    assert_eq!(commands[0]["delay_ms"], 100);
    assert_eq!(commands[1]["delay_ms"], 0);

    // Rows + ordering visible through the repository.
    let stored = fixture.db.sequence_commands(EntityId(sequence_id)).unwrap();
    assert_eq!(stored.len(), 2);
    assert_eq!(stored[0].endpoint, "a.b");

    let (error, payload) = session.call(2, "list_sequences", json!({"train_id": fixture.train_id}));
    assert!(!error);
    assert_eq!(payload["sequences"].as_array().unwrap().len(), 1);

    // set_sequence_commands failures keep the Elixir phrase.
    let (error, payload) = session.call(
        3,
        "update_sequence",
        json!({"id": sequence_id, "commands": [{"endpoint": "   ", "value": 1.0}]}),
    );
    assert!(error);
    assert_eq!(
        payload,
        json!("Failed to set commands: sequence command endpoint is required")
    );

    let (error, payload) = session.call(
        4,
        "update_sequence",
        json!({"id": sequence_id, "name": "Shutdown"}),
    );
    assert!(!error);
    assert_eq!(payload["sequence"]["name"], "Shutdown");

    let (error, payload) = session.call(5, "delete_sequence", json!({"id": 9999}));
    assert!(error);
    assert_eq!(payload, json!("Sequence not found with id 9999"));

    let (error, payload) = session.call(6, "delete_sequence", json!({"id": sequence_id}));
    assert!(!error);
    assert_eq!(payload, json!({"deleted": true, "id": sequence_id}));
    assert!(fixture.db.sequence_commands(EntityId(sequence_id)).unwrap().is_empty());
}

// ---------------------------------------------------------------------------
// Scripts
// ---------------------------------------------------------------------------

#[test]
fn scripts_crud_over_http() {
    let fixture = seed();
    let mut session = connect(fixture.port);

    let (error, payload) = session.call(
        1,
        "create_script",
        json!({"train_id": fixture.train_id, "name": "Greaser", "code": "return 1",
            "triggers": ["CurrentDrivableActor/Speed"]}),
    );
    assert!(!error);
    let script_id = payload["script"]["id"].as_i64().unwrap();
    assert_eq!(payload["script"]["enabled"], true);
    assert_eq!(payload["script"]["triggers"], json!(["CurrentDrivableActor/Speed"]));

    let (error, payload) = session.call(2, "list_scripts", json!({"train_id": fixture.train_id}));
    assert!(!error);
    assert_eq!(payload["scripts"][0]["name"], "Greaser");

    let (error, payload) = session.call(
        3,
        "create_script",
        json!({"train_id": fixture.train_id, "name": "  ", "code": "return 1"}),
    );
    assert!(error);
    assert_eq!(payload, json!("Validation failed: name can't be blank"));

    let (error, payload) = session.call(
        4,
        "update_script",
        json!({"id": script_id, "enabled": false}),
    );
    assert!(!error);
    assert_eq!(payload["script"]["enabled"], false);

    let (error, payload) = session.call(5, "delete_script", json!({"id": 9999}));
    assert!(error);
    assert_eq!(payload, json!("Script not found with id 9999"));

    let (error, payload) = session.call(6, "delete_script", json!({"id": script_id}));
    assert!(!error);
    assert_eq!(payload, json!({"deleted": true, "id": script_id}));
}

// ---------------------------------------------------------------------------
// Simulator + detection (live-service defaults)
// ---------------------------------------------------------------------------

#[test]
fn simulator_reports_not_connected_over_http() {
    let fixture = seed();
    let mut session = connect(fixture.port);
    let (error, payload) = session.call(1, "get_simulator_value", json!({"path": "a.b"}));
    assert!(error);
    assert_eq!(
        payload,
        json!("Simulator not connected. Ensure Train Sim World is running with External Interface enabled.")
    );
}

#[test]
fn detection_reports_timeout_over_http() {
    let fixture = seed();
    let mut session = connect(fixture.port);
    let (error, payload) = session.call(
        1,
        "detect_hardware_input",
        json!({"prompt": "Press a button", "timeout_ms": 5}),
    );
    assert!(!error);
    assert_eq!(payload, json!({"detected": false, "reason": "timeout"}));
}
