---
name: train-setup
description: Use when configuring a train in Trenino through its MCP tools, including elements, button or output bindings, selectors (multi-position switches), display bindings, sequences, Lua scripts, or virtual joystick mappings.
---

# Train Setup

Tool schemas carry parameters, modes and operators. This skill covers the order of work and the limits of MCP.

## Before You Start

- Trenino must be running for MCP. `Session not found` means it restarted, so reconnect.
- Simulator tools need Train Sim World running with the External Interface enabled.
- Call `list_trains` and `get_train` first to see what already exists.

## Workflow

1. **Identify the train.** Read `CurrentFormation.DrivableIndex`, then `CurrentFormation/<index>.ObjectClass`, and strip any trailing `_C`. Identifiers are prefixes, and a train can have several.
2. **Create the train in the UI if it is missing.** Neither MCP nor the REST API can create trains.
3. **Discover controls.** Explore `list_simulator_endpoints` breadth-first from `CurrentDrivableActor`. Names vary by train (for example `Throttle(Lever)`), so never assume them.
4. **Create elements.** Use `lever` for analog controls, `button` for digital ones, and `selector` for a potentiometer that acts as a multi-position switch (for example a lights selector).
5. **Bind inputs.** Use `detect_hardware_input` rather than asking for IDs, one call at a time.
6. **Bind buttons** with `create_button_binding`. Set up levers with the lever tools (see Levers below).
7. **Configure selectors** with `configure_selector`. The input must be an analog input with `calibrated: true` in `list_device_inputs`; calibration is UI-only. List positions in the order the knob passes through them. Omit ranges for an even split, or ask the user to capture detents in the selector setup in the UI when the knob's detents are uneven. Each position has an enter and an exit action (`set_value`, `sequence`, `keystroke`, or the default `none`).
8. **Add optional behaviour:** output bindings, I2C modules with display bindings, sequences, Lua scripts, or virtual joystick mappings.
9. **Test with the user.** After each binding, debug with `get_simulator_value` and `set_simulator_value`.

## Levers

1. `list_simulator_levers` with `match` set to the element's name. Match by `role` (`Throttle`, `AutomaticBrake`, `IndependentBrake`, `DynamicBrake`, `Reverser`), not by node name. On twin-cab trains use the `_F` control unless the user says otherwise.
2. `set_lever_endpoint` with the chosen `control_path`.
3. `calibrate_lever` only after the user agrees: it moves the lever in the game and can move the train. Ask them to stop the train, apply the train brake, and set the train up as if to drive (reverser out of neutral), or power notches may be blocked. Tell the user every returned warning and the notch names it found.
4. `bind_lever_input` with an analog input from `detect_hardware_input`. The input must be calibrated (UI-only).
5. `open_lever_setup` to hand over. Mapping the physical notches needs the user; `get_lever.next_step` says what is left.

To print a physical notch disk that matches a calibrated lever, give the user `get_lever.notch_disk_url`. It opens the notch disk generator with the lever's notches filled in.

Recalibrating keeps the notch mapping when the notches did not change.

## Selectors

- Find the simulator value of each position first: move the control in the game and read it with `get_simulator_value`.
- Keystroke actions are tapped once. They are skipped when the selector syncs (train activation, simulator reconnect), because a second tap would toggle the state back. Prefer `set_value` when the control has an endpoint.
- While the simulator is disconnected the selector tracks its position but runs no actions.

## Lua Scripts

Write them per `docs/lua-scripting.md`. Get output IDs from `list_hardware_outputs`. Use `event.value`, because `api.get` returns `nil`. Each run is limited to 200ms.

## Working With the User

Go one step at a time and explain each binding in plain language.
