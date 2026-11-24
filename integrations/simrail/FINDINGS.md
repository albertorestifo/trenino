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
- **Spring-back positions** (`StablePosition` in the schema as `stable`): the Traxx
  traction lever `drive_handle` has 8 positions; only 1, 3, 5, 7 hold. 0/2 spring to 1,
  4/6 spring to 5 (a set-point controller: nudge to raise/lower traction force).
  They are ordinary positions to Trenino: whether the physical lever springs back is up
  to the hardware (a spring, a detent valley, or none). Each notch records
  `springs_back_to` for the notch disk designer only.
  **A written value stays until the next write, spring-back positions included**
  (tested 2026-11-23, Traxx `drive_handle` 0 and `speed_ctrl` 1: value and cab lever
  position unchanged for 2 s+ with nothing re-applying them). The game springs a lever
  back only when its own keyboard/mouse interaction is released, so the value tracks
  the hardware lever: when the hardware springs back, Trenino writes the rest position.
  An earlier note here claimed the game springs written values back after ~0.15 s; that
  drift came from the driver operating the cab during the test. Bridge 0.3.0 briefly
  "held" such values; 0.3.1 removed it.
- **One handle can appear as several controls on the same path**: the same lever in
  each cab (identical tables, listed once by `SimRailLevers.distinct/1`) and, on some
  trains, a smooth and a stepped variant of one handle (the EU07 brakes: see below).
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

### EU07 (`4e/eu07-193`, Locomotive) — Łódź–Warsaw / base game
- 4 groups, 278 values, 159 controls (145 bound). Main controls use `Physics_Input_General`.
- **44-position resistor controller** `drive_handle` (0–43) plus a 7-position field-weakening
  lever `scnd_handle` (values 6…0, reversed).
- Direction is a **lever** here (`direction_rq` −1 backward / 2 neutral / 1 forward — same
  values as the Traxx's three buttons, so `direction_rq` semantics are consistent).
- **Each brake handle exists as a smooth and a stepped control on the same path**, in both
  cabs (an earlier note here said the cabs differed; they don't): `main_brake` is a smooth
  notch-based FV4a (`hamulec_zasadniczy`: positions with value + lower/upper band, e.g.
  value 6 covers 6.5…4.5) and an 11-step variant (`hamulec_zasadniczy_step`:
  `8,7,6,5.25,4.5,4,3.5,3,2,1,0`). `local_brake` is a continuous 1…0 smooth lever and a
  6-step variant. The setup picker labels them "Smooth" and "Stepped".
- While dragged with the mouse, smooth levers write **intermediate values** (0.546, 2.436,
  4.987…) and settle on the notch value — genuine analog input.
- Manual start-up recorded (`eu07-manual-startup-*.jsonl`, driver-operated, ends moving):
  `battery_rq` 1 (battery immediately: `battery_status` 1, 90 V) → `active_cab` 1 →
  `direction_rq` 1 → `unlockovldmotors_rq` 1/−1 (reset overload relays) →
  `pantograph_front_rq` / `pantograph_back_rq` 1 (`supply_voltage` 3500,
  `main_circuit_breaker_status` 0.8 = armed) → `main_switch` button 1 then 0 (breaker 1.0)
  → `converter_rq` 1 → `compressor_rq` 1 → release brakes, notch up.
  `unlockandrelease_rq` was used while starting off. `overload_motors_lamp` lit at notch ~9
  under load; line voltage sags (3500 → ~3430 V).
- Main switch = two push buttons on one path: close (`bt-zal_WS`, pressed 1) and open
  (`bt-wyl_WS`, pressed −1).
- **Lesson: a cold sweep left the EU07 in a state where the battery would not come on —
  neither via the bridge nor via the game's own `B` key (both write only
  `battery_rq` 0→1).** Reloading the train fixed it. Run sweeps only on freshly loaded
  trains, and never trust conclusions about "this input does nothing" from a train that has
  been swept.

### ED250 Pendolino (`pendolino/ed250-018 variant`, ElectricMultipleUnit)
- 4 groups, 371 values, 322 controls (280 bound, 172 buttons).
- **Analog throttle**: `drive_handle` is a smooth lever, continuous 0…1 (power fraction);
  `traction_force_handle` follows (0.2 → ~20 kN, 1 → 100). First train where a continuous
  hardware lever maps 1:1. Not a combined power/brake handle — the brake is separate.
- `main_brake`: smooth lever with bands in one cab (value 4 covers 6…3.8, 3.6 covers
  3.8…2.667) and an 11-step lever in the other (`7,6,5.33,4.67,4,3.6,3.23,2.667,2,1,0`).
  Brake valve: 0 → fill, 2 → running (pipe pressure climbs to 5 bar).
- `speed_ctrl` (cruise) is a spring-return lever: only position 2 holds; 0/1/3 spring back
  to 2 (nudge down/up). `speed_ctrl_value` reached 250.
- **Pulse switches**: `battery_rq` 1 then back to 0; `active_cab` rests at −2 and pulses to 1.
  A connector must send a pulse, not hold a level.
- Start-up (driver-operated, `ed250-manual-startup-*.jsonl`): `battery_rq` pulse
  (`battery_status` 1) → `active_cab` pulse (`cab` 1) → vigilance → pantograph(s) up →
  `force_compressors` → **`control_circuits` 1** → `main_switch` 1/0 (`supply_voltage` 3500;
  several main-switch presses did nothing until `control_circuits` was on) → `main_brake`
  0 then 2 (fill, pipe 5 bar) → spring brake release → direction 1 → throttle.
- **`main_circuit_breaker_status` means something else here**: 0→1 when the battery came on
  and 1→0 when the main switch closed, yet traction worked afterwards. Output semantics
  are per vehicle, even for identically named fields.
- ETCS is active: `etcs2023_service_brake` fired after the first throttle application.
- `test_dashboard_controls` is a lamp test: lights every indicator output at once (useful
  for testing hardware lamps).
- Live sweep (`pendolino_ed250-018_variant-live.json`, start-up/trip controls skipped):
  143 of 160 steps clean; 17 steps saw other **inputs** change at the same time
  (`drive_handle` ×8, direction, horn, vigilance…) — treat those attributions as unreliable.
  `sweep-controls.mjs` now records such changes separately as `concurrentInputs`.

## MelonLoader crash: Il2CppInterop hooks the wrong function (2026-11-22)

SimRail crashed twice mid-session (`APPCRASH`, `coreclr.dll+0x1d4089`, `0xc0000005`), each
time within a second of a trainset being handed to the train server. Both crash dumps
(`%LOCALAPPDATA%\CrashDumps`, read with `dotnet-dump`) show the same thread:

```
IL2CPP Threadpool worker
  GameAssembly+0x289440 -> call GameAssembly+0x289310        (generated game code)
  Il2CppInterop ... Class_GetFieldDefaultValue_Hook.Hook()   line 33: return Original(field, out type)
  System.ExecutionEngineException
```

No bridge code was on the stack. Il2CppInterop 1.5.1-ci.845 (MelonLoader 0.7.3) finds
`Class::GetDefaultFieldValue` by prologue signatures and takes the first hit. On Unity
2023.1.8 its "V Rising" signature `48 89 5C 24 08 48 89 74 24 10 57 48 83 EC 40 48 8B 41 10`
matches 9 functions. The first, `0x289310`, takes `(this, int, float, ushort, MethodInfo*)`,
so the 2-pointer hook clobbers its arguments every time the game calls it. The real function
is `0x54d580`: `Field::StaticGetValueInternal` (`0x53c820`) calls it with `lea rdx,[rsp+50h]`
(`&type`), and its body computes `(field - field->parent->fields) >> 5`. It is the only
signature hit reachable by direct calls from the `il2cpp_field_static_get_value` export.
It reproduces with a bare loader: upstream is
[BepInEx/Il2CppInterop#284](https://github.com/BepInEx/Il2CppInterop/issues/284).
`TreninoInteropGuard` (plugin) applies the reachability check before the hook is installed.

## Open questions

- The EN57 and Traxx profiles were captured before the bridge reported `stable` and
  button values; re-capture them to have spring-back data for those trains.
- Whether a written spring-back value also stays in multiplayer (tested single-player).
- How to charge the brake pipe / reset after an emergency brake via IO (Traxx).
- Units: `velocity` (km/h?), pressures (bar), `traction_force_*` (kN?).
- Do writes behave the same in multiplayer (physics may run server-side)?
- Which state the EU07 cold sweep latched (candidates: a fault_*/unlock input or a
  battery_rq −1 "off" position held during the sweep).
- No train with a combined power/brake handle profiled yet (EN76 Elf may have one).
- Whether the ED250 writes `drive_handle` itself (`reset_controller`, cruise control) or the
  concurrent changes in its sweep were the driver.
