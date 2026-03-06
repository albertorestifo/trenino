# Trenino MCP Tools Guide

Operational guide for using Trenino's MCP tools. Use this when interacting with the Trenino MCP server to configure trains, explore the simulator API, or manage hardware.

## Connection

Trenino's MCP server runs at `http://localhost:4000/mcp/sse` using SSE transport. The server must be running before connecting.

## Tool Categories

### Simulator Tools
- `list_simulator_endpoints(path)` — Browse the simulator API tree. Start with path "" for root, then drill into children.
- `get_simulator_value(path)` — Read a value. Use for debugging and verification.
- `set_simulator_value(path, value)` — Write a value. Use for testing controls.

### Train Tools
- `list_trains` — List all configured trains.
- `get_train(train_id)` — Get full train config including elements, bindings, sequences.

### Element Tools
- `list_elements(train_id)` — List elements (levers and buttons) for a train.
- `create_element(train_id, name, type)` — Create a new element. Type: "lever" or "button".
- `delete_element(element_id)` — Delete an element and its bindings.

### Device Tools
- `list_devices` — List connected hardware devices.
- `list_device_inputs(device_id)` — List inputs for a device.
- `list_hardware_outputs` — List all hardware outputs (LEDs) across devices.

### Detection Tools (Interactive)
- `detect_hardware_input(prompt, input_type)` — Auto-detect hardware input. Blocks until user interacts with hardware. Shows modal in UI. **IMPORTANT: Only call one detection at a time. Do NOT run multiple detections in parallel. Wait for each to complete before starting the next.**

### Button Binding Tools
- `get_button_binding(element_id)` — Get binding for a button element.
- `create_button_binding(...)` — Bind hardware input to button element. Modes: simple, momentary, sequence, keystroke.
- `update_button_binding(...)` — Update existing binding.
- `delete_button_binding(element_id)` — Remove binding.

### Output Binding Tools
- `list_output_bindings(train_id)` — List output bindings.
- `create_output_binding(...)` — Create LED binding based on simulator state.
- `update_output_binding(...)` — Update binding.
- `delete_output_binding(id)` — Delete binding.

### Sequence Tools
- `list_sequences(train_id)` — List command sequences.
- `create_sequence(train_id, name, commands)` — Create sequence.
- `update_sequence(id, ...)` — Update sequence.
- `delete_sequence(id)` — Delete sequence.

### Script Tools
- `list_scripts(train_id)` — List Lua scripts (metadata only, no code).
- `get_script(id)` — Get a script with full code, triggers, and enabled status.
- `create_script(train_id, name, code, triggers?, enabled?)` — Create a Lua script.
- `update_script(id, name?, code?, triggers?, enabled?)` — Update script fields.
- `delete_script(id)` — Delete a script.

## Common Workflows

### Discover what a train can do
1. `list_simulator_endpoints("")` → find `CurrentDrivableActor`
2. `list_simulator_endpoints("CurrentDrivableActor")` → see all control groups
3. Drill into each group to find `InputValue` endpoints

### Bind a button to a control
1. `detect_hardware_input(prompt: "Press the horn button", input_type: "button")`
2. Use returned `input_id` in `create_button_binding`

### Check if something is working
1. `get_simulator_value("CurrentDrivableActor/Horn.InputValue")` → see current state
2. `set_simulator_value("CurrentDrivableActor/Horn.InputValue", 1)` → test manually

## Error Handling

- "Simulator not connected": Start Train Sim World and enable External Interface
- "Session not found": Trenino may have restarted, reconnect MCP
- Validation errors: Check required fields and valid enum values
- Empty device list: Connect hardware via USB, check serial connection

## Tips

- Always call `list_trains` first to understand current configuration state
- Use `get_train` to see the full picture before making changes
- Prefer `detect_hardware_input` over manually looking up input IDs
- When exploring endpoints, go breadth-first: list children, then drill into interesting ones
- Round float values to 2 decimal places when displaying to users
