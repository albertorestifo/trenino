# Train Setup Guide

Skill for configuring trains in Trenino via MCP. Follow this workflow when helping users set up a new train or modify an existing configuration.

## Prerequisites

- Trenino must be running (MCP server at localhost:4000)
- For simulator tools: Train Sim World must be running with External Interface enabled
- For hardware tools: at least one hardware controller must be connected

Check prerequisites by calling `list_devices` (hardware) and `list_simulator_endpoints` with path "" (simulator).

## Train Setup Workflow

### 1. Identify the Train

Ask the user which train they want to configure. If the simulator is running:
- Use `list_simulator_endpoints` with path "" then navigate to find `CurrentDrivableActor`
- Read the `ObjectClass` endpoint to get the train identifier
- The identifier is a prefix (e.g., "RVM_LIRREX_M9" matches "RVM_LIRREX_M9-A", "RVM_LIRREX_M9-B")

Check if the train already exists with `list_trains`. If not, use the REST API or ask the user to create it in the UI.

### 2. Discover Available Controls

Explore the simulator API to find what controls the train has:
- Use `list_simulator_endpoints` starting at "CurrentDrivableActor"
- Look for nodes with `InputValue` endpoints (writable = true) — these are controllable
- Common controls: Throttle, Brake, TrainBrake, DynamicBrake, Reverser, Horn, Bell, Wipers, Headlights, DoorLeft, DoorRight

### 3. Create Elements

For each control the user wants to bind:
- Use `create_element` with `type: "lever"` for analog controls (throttle, brake, reverser)
- Use `create_element` with `type: "button"` for digital controls (horn, bell, doors, wipers)

### 4. Bind Hardware Inputs

For each element, bind it to a physical hardware input:
- **Always prefer `detect_hardware_input`** over asking for input IDs
- Call `detect_hardware_input` with a clear prompt: "Press the button you want to use for the horn"
- Use `input_type: "button"` for buttons, `input_type: "analog"` for levers
- The tool returns the input_id needed for binding

For **buttons**: Use `create_button_binding` with the detected input_id and the simulator endpoint.
For **levers**: Lever binding requires calibration through the UI (not yet available via MCP). Guide the user to use the Lever Setup Wizard in the UI.

### 5. Configure Button Binding Mode

Each button binding has a mode:
- **simple** (default): Sends `on_value` when pressed, `off_value` when released. Good for: horn, bell, wipers toggle.
- **momentary**: Repeats `on_value` at an interval while held. Good for: continuous horn, repeated actions.
- **sequence**: Executes a command sequence on press/release. Good for: startup procedures, multi-step operations.
- **keystroke**: Simulates a keyboard key. Good for: controls that TSW only accepts via keyboard.

Also set `hardware_type`:
- **momentary** (default): Spring-loaded buttons that return to off
- **latching**: Toggle switches that stay in position

### 6. Set Up Output Bindings (LEDs)

Bind hardware outputs (LEDs) to simulator state:
- Use `list_hardware_outputs` to find available LEDs
- Use `create_output_binding` with a simulator endpoint and condition

Operators:
- `gt`, `gte`, `lt`, `lte`: Compare endpoint value to `value_a`
- `between`: True when value is between `value_a` and `value_b`
- `eq_true`, `eq_false`: For boolean endpoints

Example: "Red LED on when speed > 100" → operator: "gt", value_a: 100

### 7. Create Sequences (Optional)

For complex multi-step operations:
- Use `create_sequence` with a name and ordered commands
- Each command has: endpoint, value, delay_ms (delay before next command)
- Bind sequences to buttons using `sequence` mode

### 8. Test

Guide the user through testing:
- Press each bound button and verify the simulator responds
- Move levers and check values
- Verify LED output bindings react correctly

## Common TSW Endpoint Patterns

| Control | Endpoint Pattern | Type |
|---------|-----------------|------|
| Throttle | `CurrentDrivableActor/Throttle.InputValue` | Lever (0.0-1.0) |
| Train Brake | `CurrentDrivableActor/TrainBrake.InputValue` | Lever (0.0-1.0) |
| Dynamic Brake | `CurrentDrivableActor/DynamicBrake.InputValue` | Lever (0.0-1.0) |
| Reverser | `CurrentDrivableActor/Reverser.InputValue` | Lever (-1.0 to 1.0) |
| Horn | `CurrentDrivableActor/Horn.InputValue` | Button (0/1) |
| Bell | `CurrentDrivableActor/Bell.InputValue` | Button (0/1) |
| Wipers | `CurrentDrivableActor/Wipers.InputValue` | Button (0/1) |
| Headlights | `CurrentDrivableActor/Headlights.InputValue` | Button or Lever |
| Door Left | `CurrentDrivableActor/DoorLeft.InputValue` | Button (0/1) |
| Door Right | `CurrentDrivableActor/DoorRight.InputValue` | Button (0/1) |
| Emergency Brake | `CurrentDrivableActor/EmergencyBrake.InputValue` | Button (0/1) |

**Note:** Endpoint names vary by train. Always discover using `list_simulator_endpoints` rather than assuming names.

## Interaction Style

- Be conversational and guide the user step by step
- When binding inputs, do them one at a time with `detect_hardware_input`
- Explain what each binding does in plain language
- After each binding, offer to test it immediately
- If something doesn't work, suggest using `get_simulator_value`/`set_simulator_value` to debug
