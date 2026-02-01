# Native MCP Server for Train Configuration

## Overview

Expose Trenino as a native MCP (Model Context Protocol) server over SSE, allowing Claude to directly configure trains through structured tools. This replaces the current fetch-based MCP proxy with a first-class integration where Claude can set up output bindings, button bindings, sequences, and explore the simulator API — all through natural conversation.

The primary use case: a user tells Claude "set up a brake warning LED that turns on when speed exceeds 50" and Claude handles the rest — browsing simulator endpoints, finding the right hardware output, and creating the binding.

## Transport

SSE (Server-Sent Events) over the existing Phoenix web server. Two new routes:

- `GET /mcp/sse` — Opens an SSE stream. Server sends an `endpoint` event with the POST URL and a generated session ID.
- `POST /mcp/messages?session_id=<id>` — Client sends JSON-RPC 2.0 requests. Server processes them and pushes responses through the corresponding SSE stream.

No authentication — Trenino is a local desktop app. No new dependencies — Phoenix handles SSE and JSON natively.

## Module Structure

```
lib/trenino_web/
  controllers/
    mcp/
      mcp_controller.ex           # SSE endpoint + POST message handler

lib/trenino/
  mcp/
    server.ex                     # JSON-RPC 2.0 parsing, dispatch, response formatting
    tool_registry.ex              # Collects tool modules, handles tools/list and tools/call
    tools/
      simulator_tools.ex          # list_simulator_endpoints, get_simulator_value, set_simulator_value
      train_tools.ex              # list_trains, get_train
      device_tools.ex             # list_devices, list_device_inputs, list_hardware_outputs
      output_binding_tools.ex     # CRUD for output bindings
      button_binding_tools.ex     # CRUD for button bindings
      sequence_tools.ex           # CRUD for sequences
```

## Tool Inventory (20 tools)

### Simulator (read + write)

| Tool | Description |
|------|-------------|
| `list_simulator_endpoints` | Browse simulator API tree at a given path. Returns child endpoints with types and current values. |
| `get_simulator_value` | Read a single simulator endpoint value. |
| `set_simulator_value` | Write a value to a simulator endpoint (for experimentation). |

### Trains & Elements (read-only)

| Tool | Description |
|------|-------------|
| `list_trains` | List all trains with id, name, identifier, description. |
| `get_train` | Get a train with its elements and output bindings. |

### Devices & Hardware (read-only)

| Tool | Description |
|------|-------------|
| `list_devices` | List all connected devices with id, name, type. |
| `list_device_inputs` | List inputs for a device (id, name, pin, input_type). |
| `list_hardware_outputs` | List all available hardware outputs (id, name, pin, device). |

### Output Bindings (full CRUD)

| Tool | Description |
|------|-------------|
| `list_output_bindings` | List all output bindings for a train. |
| `create_output_binding` | Create a binding: monitor a simulator endpoint, control a hardware output based on a condition. |
| `update_output_binding` | Update an existing output binding. |
| `delete_output_binding` | Delete an output binding. |

### Button Bindings (full CRUD)

| Tool | Description |
|------|-------------|
| `get_button_binding` | Get the binding for a button element. |
| `create_button_binding` | Bind a hardware input to a button element with mode config (simple, momentary, sequence, keystroke). |
| `update_button_binding` | Update a button binding's mode, endpoint, values, etc. |
| `delete_button_binding` | Remove a button binding. |

### Sequences (full CRUD)

| Tool | Description |
|------|-------------|
| `list_sequences` | List all sequences for a train. |
| `create_sequence` | Create a named sequence with ordered commands (endpoint, value, delay). |
| `update_sequence` | Update a sequence's name or replace its commands. |
| `delete_sequence` | Delete a sequence. |

## Tool Schema Examples

### create_output_binding

```json
{
  "name": "create_output_binding",
  "description": "Create an output binding that controls a hardware output (LED) based on a simulator endpoint value. Use list_simulator_endpoints to find endpoints and list_hardware_outputs to find available outputs.",
  "inputSchema": {
    "type": "object",
    "properties": {
      "train_id": { "type": "integer", "description": "Train ID" },
      "name": { "type": "string", "description": "Human-readable name, e.g. 'Brake warning LED'" },
      "output_id": { "type": "integer", "description": "Hardware output ID from list_hardware_outputs" },
      "endpoint": { "type": "string", "description": "Simulator endpoint path to monitor" },
      "operator": { "type": "string", "enum": ["gt", "gte", "lt", "lte", "between", "eq_true", "eq_false"] },
      "value_a": { "type": "number", "description": "Threshold value (not needed for eq_true/eq_false)" },
      "value_b": { "type": "number", "description": "Upper threshold (only for 'between' operator)" }
    },
    "required": ["train_id", "name", "output_id", "endpoint", "operator"]
  }
}
```

### create_button_binding

```json
{
  "name": "create_button_binding",
  "description": "Bind a hardware input to a button element. Mode determines behavior: 'simple' sends a value once, 'momentary' repeats while held, 'sequence' runs a command sequence, 'keystroke' simulates a key press.",
  "inputSchema": {
    "type": "object",
    "properties": {
      "element_id": { "type": "integer", "description": "Button element ID from get_train" },
      "input_id": { "type": "integer", "description": "Hardware input ID from list_device_inputs" },
      "mode": { "type": "string", "enum": ["simple", "momentary", "sequence", "keystroke"] },
      "endpoint": { "type": "string", "description": "Simulator endpoint (for simple/momentary modes)" },
      "on_value": { "type": "number", "default": 1.0 },
      "off_value": { "type": "number", "default": 0.0 },
      "keystroke": { "type": "string", "description": "Key combo for keystroke mode, e.g. 'W' or 'CTRL+S'" },
      "on_sequence_id": { "type": "integer", "description": "Sequence ID for sequence mode (on press)" },
      "off_sequence_id": { "type": "integer", "description": "Sequence ID for sequence mode (on release)" },
      "repeat_interval_ms": { "type": "integer", "description": "Repeat interval for momentary mode (100-5000)" },
      "hardware_type": { "type": "string", "enum": ["momentary", "latching"], "default": "momentary" }
    },
    "required": ["element_id", "input_id", "mode"]
  }
}
```

### create_sequence

```json
{
  "name": "create_sequence",
  "description": "Create a named command sequence for a train. Commands are executed in order, each sending a value to a simulator endpoint with an optional delay before the next command.",
  "inputSchema": {
    "type": "object",
    "properties": {
      "train_id": { "type": "integer", "description": "Train ID" },
      "name": { "type": "string", "description": "Human-readable name, e.g. 'Startup sequence'" },
      "commands": {
        "type": "array",
        "items": {
          "type": "object",
          "properties": {
            "endpoint": { "type": "string", "description": "Simulator API path" },
            "value": { "type": "number", "description": "Value to send" },
            "delay_ms": { "type": "integer", "description": "Wait after this command (0-60000ms)", "default": 0 }
          },
          "required": ["endpoint", "value"]
        }
      }
    },
    "required": ["train_id", "name", "commands"]
  }
}
```

## Error Handling

Tool responses use MCP's standard content format.

Success:
```json
{
  "content": [{ "type": "text", "text": "{\"id\": 5, \"name\": \"Brake warning LED\", ...}" }]
}
```

Error (with `isError` flag):
```json
{
  "content": [{ "type": "text", "text": "Validation failed: endpoint is required" }],
  "isError": true
}
```

Mapping from context function returns:
- `{:ok, record}` -> success with serialized record
- `{:error, %Ecto.Changeset{}}` -> validation error with formatted changeset messages
- `{:error, :not_found}` -> "not found" error
- `{:error, :simulator_not_connected}` -> "simulator not connected, ensure Train Sim World is running"

## MCP Client Configuration

Replace the current `.mcp.json`:

```json
{
  "mcpServers": {
    "trenino": {
      "type": "sse",
      "url": "http://localhost:4000/mcp/sse"
    }
  }
}
```

The old `trenino-api` fetch server entry is removed.

## Protocol Details

JSON-RPC 2.0 methods handled:
- `initialize` — Returns server name ("Trenino"), version, and capabilities (`tools`).
- `tools/list` — Returns all 20 tool definitions with JSON schemas.
- `tools/call` — Dispatches to the matching tool module's execute function.

Session management:
- Each SSE connection gets a unique session ID (UUID).
- The controller process holds the SSE connection and a reference map for session lookup.
- Cleanup happens automatically when the SSE stream disconnects.

## Out of Scope

- Lever calibration (requires physical hardware interaction)
- Lever configuration CRUD (future addition)
- Script CRUD via MCP (already has REST API; can be added later)
- Authentication (local-only app)
- Streamable HTTP transport (can migrate later if needed)

## Follow-up: End-User Documentation

Write user-facing documentation covering:
- What the MCP integration is and why it is useful (pitch: "let Claude set up your train controls through conversation")
- Step-by-step setup instructions for Claude Desktop and Claude Code
- Example workflows (setting up output bindings, configuring buttons)
- Add a section to the main README highlighting the MCP feature
