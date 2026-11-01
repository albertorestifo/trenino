---
name: train-setup
description: Use when configuring a train in Trenino through its MCP tools, including elements, button or output bindings, display bindings, sequences, Lua scripts, or virtual joystick mappings.
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
4. **Create elements.** Use `lever` for analog controls and `button` for digital ones.
5. **Bind inputs.** Use `detect_hardware_input` rather than asking for IDs, one call at a time.
6. **Bind buttons** with `create_button_binding`. Send levers to the Lever Setup Wizard in the UI, because lever binding and calibration are UI-only.
7. **Add optional behaviour:** output bindings, I2C modules with display bindings, sequences, Lua scripts, or virtual joystick mappings.
8. **Test with the user.** After each binding, debug with `get_simulator_value` and `set_simulator_value`.

## Lua Scripts

Write them per `docs/lua-scripting.md`. Get output IDs from `list_hardware_outputs`. Use `event.value`, because `api.get` returns `nil`. Each run is limited to 200ms.

## Working With the User

Go one step at a time and explain each binding in plain language.
