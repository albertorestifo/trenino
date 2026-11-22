# SimRail research findings

Living notes from probing SimRail through the TreninoBridge mod. Read this before
building the Trenino SimRail connector. Raw data lives next to this file:

- `profiles/<vehicle>.json` — `GET /api/v1/dump` per train: schema (groups, controls,
  notch tables), all values at capture time, and raw control properties.
- `sweeps/<vehicle>-<label>.json` — `sweep-controls.mjs` output: every bound control
  stepped through its positions and which other values reacted.
- `recordings/<vehicle>-<time>.jsonl` — `record-session.mjs` output: every value change
  while driving (first line: schema, second: full initial state).

## How SimRail exposes a train

- No external API. The mod reads `RailStock.PlayerVehicle` → `IOStorageList.storages`.
- Each storage is an **IO group**: a float array plus a parallel names array. We address
  values as `Group.field`, e.g. `Physics_Input_EN57.maincontroller_a`. Booleans are 0/1.
- Groups are `Physics_Input_*` (what the driver commands) and `Physics_Output_*` (what
  the simulation reports). Every vehicle has `Physics_Input_General` /
  `Physics_Output_General` plus vehicle-specific groups (`Physics_Input_EN57`,
  `Physics_Output_TRAXX_E186`, `Physics_Output_SOD`, ...).
- **Which group a train uses for its main controls varies**: the EN57 drives through
  `Physics_Input_EN57.maincontroller_a` and ignores `Physics_Input_General.drive_handle`;
  the Traxx drives through `Physics_Input_General.drive_handle`. Never assume — use the
  control list.
- Cab controls (`PhysicsInteraction*` components) are bound to one IO field
  (`ioFieldName = "Group@field"`) and keep their own position. Writing IO directly
  without syncing them desyncs keyboard/mouse input; the bridge calls the game's
  `SetStateFromPhysics` after every write.

## Controls

- Kinds seen: stepped levers, smooth levers, stepped switches, toggle buttons,
  continuous (push) buttons, flaps, plus unbound decor (windows...).
- **Notch tables are per control, not per path.** The Traxx `activation_handle` is
  `0,1,2` in cab A and `0,1,3` in cab B — the value also encodes which cab is active.
- Notch values are often non-uniform or reversed:
  - EN57 `mainbrake_a`: `0, 1, 2, 4, 5, 5.6, 6, 7`
  - EN57 `directioncontroller_a`: index 0 = value 4 = forward, index 4 = value 0 = backward
  - Traxx `main_brake`: index 0 = value 5 … index 5 = value 0
- **Spring-return positions** (`StablePosition` in the schema as `stable`): the Traxx
  traction lever `drive_handle` has 8 positions; only 1, 3, 5, 7 hold. 0/2 spring to 1,
  4/6 spring to 5 (a set-point controller: nudge to raise/lower traction force). A
  hardware notched lever cannot map 1:1 onto such controls.
- **Push buttons** write `pressedPhysicsValue` while held and `nonPressedPhysicsValue`
  otherwise (schema: `button.pressed` / `button.released`). Traxx direction is three
  buttons on one field: forward = 1, neutral = 2, backward = −1. Spring brake: release
  = −1, apply = 1.
- Spring-return switches (pantograph, main switch on the Traxx): −1 / 0 (rest) / +1.
  Commanding them means writing ±1 briefly, then 0.
- Controls carry game input-action names (`actions`), e.g. "Increase Throttle",
  "Driving direction forward" — the same actions SimRail's keybindings use.

## Train-specific notes

### EN57 (`en57/en57-047`, ElectricMultipleUnit)
- 5 groups, 419 values, 176 controls (113 bound).
- Throttle `Physics_Input_EN57.maincontroller_a` 0–6; brake `mainbrake_a` (see above).
- Notch 1 → `supply_current_a` ~172 A, `resistors_lamp_a` 1; notch 2 → ~210 A.
- Vigilance `securitysystembutton_a` pulses 1 / −1.
- Recording `en57_en57-047-*.jsonl`: driver operated throttle/brake/vigilance on an
  already-live train; the first "values" line duplicates the initial state (pre-fix build).

### Traxx E186 (`traxx/e186-134`, Locomotive)
- 4 groups, 389 values, 280 controls (272 bound, 200 buttons incl. two display keypads).
- Start-up (all via the API): `Physics_Input_TRAXX_E186.activation_handle` → 1 (battery,
  LV) → 2 (cab active); `pantograph_set_rq` +1 then 0 (`supply_voltage` 3500, 3 kV DC);
  `main_switch` +1 then 0 (`main_circuit_breaker_status` 1, `traction_voltage` 3500).
- `emergency_brake_button_flag` rests at **−255**; writing 1 trips the emergency brake,
  opens the main breaker and stops the motors.
- `assimilation_button` opened the breaker and lowered the pantographs in the live sweep.
- `speed_ctrl` (cruise) positions drive `speed_ctrl_value` (0 → 140 km/h at position 4).
- `light_pos` 12-position light switch mirrored by `actual_light_switch_pos`.
- Drive test did not get the train moving: `pipe_pressure` stayed 0 (brake pipe not
  charged after the sweep's emergency brake) and the spring-loaded `drive_handle`
  returned to neutral. The driver also operated the cab during this test, so treat
  `traxx-drive-test-*.jsonl` and `traxx_e186-133-*.jsonl` as mixed human/API input.
- Sweeps: `traxx_e186-134-cold.json` (unpowered), `traxx_e186-134-live.json` (powered
  until step 1 tripped the emergency brake — later steps ran on a dead loco).

## Open questions
- How to charge the brake pipe / reset after an emergency brake via IO (Traxx).
- Units: `velocity` (km/h?), pressures (bar), `traction_force_*` (kN?).
- Do writes behave the same in multiplayer (physics may run server-side)?
- Smooth levers (`PhysicsInteractionLeverSmooth`) — none on EN57/Traxx main controls yet.
