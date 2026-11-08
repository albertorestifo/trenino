# X27 gauge module: follow firmware 3.3.0

Status: reviewed (Fable, 2026-11-08), revised. Target: Trenino with firmware >= 3.3.0.

## Why

Firmware 3.3.0 (`trenino_firmware` 980b9e5) removed the stepper axis extension that
Trenino's gauges are built on: message types 16/17 (StepperCommand / StepperStatus), the
PCA9685/TB6612 shield, shield address registration, host lease, homing and status
feedback. Types 16/17 are now ignored. It replaced them with an ordinary module:

- `Configure` module type **7**, exact 12-byte payload
  `driver u8, pins u8[4], travel u16 LE, max_speed u16 LE, acceleration u16 LE, flags u8`.
  - driver 0 = VID6606 channel, `pins = [STEP, DIR, RESET_N | 0xff, 0xff]`, max_speed 1..5000.
  - driver 1 = direct X27 contacts 1..4 (AVR only; Due/ESP32 answer `ConfigurationError`),
    max_speed 1..1800.
  - travel 1..4000, acceleration 1..60000, flags bit0 = reverse, other bits 0.
  - At most 4 gauges per configuration; no shared STEP/DIR/coil pins (shared RESET_N ok).
- `SetGaugePosition` (18): `pin u8 (= pins[0]), position u16 LE`, clamped to travel,
  fire-and-forget, latest wins, non-gauge pin ignored.
- `ZeroGauge` (19): `pin u8`. Sweeps to the stop, then back to the latest position.
- Every gauge sweeps to zero when it starts (boot, and **every completed Configure**,
  which recreates all modules and so forgets the last position). No feedback of any kind.
- A gauge pin the board lacks is reported as `ModuleError` with `i2c_address` 0.

Trenino's ~7k lines of stepper/gauge code (StepperManager, StepperSession, lease, wizard,
commissioning UI, 7 MCP tools) target the removed contract and cannot work with 3.3.0.

## Decisions (user, 2026-11-08)

1. Rename the hardware concept to **Gauge** (`Trenino.Hardware.Gauge`, table
   `hardware_gauges`). Code, UI, MCP and docs say "gauge".
2. **The migration deletes all old gauge data**: stepper axes, dial calibrations and
   gauge bindings. Users set gauges up again on 3.3.0.
3. Replace the guided wizard with a **plain gauge form + live calibration panel**.
4. A stale/inactive binding **holds** the needle (nothing is sent).
5. **Everything stays beta** behind the existing `:gauges` flag: the Gauges section, the
   calibration panel, the train binding section, nav entries and all gauge MCP tools.
   Contexts, schemas, GenServers and supervision children are not gated (CLAUDE.md).

## Target design

### Protocol (`lib/trenino/serial/protocol/`)

- `configure.ex`: add `input_type: :gauge` (wire 0x07) with struct fields `driver`
  (`:vid6606 | :direct`), `pins` (4 integers, 255 = unused), `travel`, `max_speed`,
  `acceleration`, `reverse` (boolean -> flags bit0). Encode + decode clauses (decode with an
  exact 12-byte body). Update moduledoc/type.
- New `set_gauge_position.ex` (0x12: `pin`, `position` u16 LE) and `zero_gauge.ex`
  (0x13: `pin`), modelled on `set_output.ex`. Register both in `message.ex` dispatch.
- Delete `stepper_command.ex`, `stepper_status.ex`, `stepper_configuration.ex` and their
  dispatch lines in `message.ex`. 0x10/0x11 then decode as unknown, matching the firmware.

### Data (`lib/trenino/hardware/`)

`Gauge` schema, table `hardware_gauges`:

| field | type | notes |
|---|---|---|
| device_id | FK devices, on_delete delete_all | |
| name | string, <= 100 | required |
| driver | Ecto.Enum `[:vid6606, :direct]` | default `:vid6606` |
| pins | `{:array, :integer}` length 4 | VID6606 `[step, dir, reset or 255, 255]`; direct `[c1, c2, c3, c4]` |
| travel | integer 1..4000 | default 3780 (VID6606) / 945 (direct) |
| max_speed | integer, 1..5000 VID6606, 1..1800 direct | default 5000 / 1800 |
| acceleration | integer 1..60000 | default 50000 / 1500 |
| reverse | boolean | default false |

Changeset validations mirror the firmware so a bad config is caught before Configure:
pins in 0..254 when used, used pins distinct, VID6606 `pins[3] == 255`, `pins[2]` may be
255, per-driver speed range. Context-level checks (in `Hardware`, inside the save
transaction): at most 4 gauges per device; no STEP/DIR/coil pin shared with another gauge
on the device (a shared RESET_N is fine and expected: the train-lever board puts D6 in
every channel); `pins[0]` unique per device (it is the wire identity).

`DialCalibration` keeps its table but its FK becomes `gauge_id`; `validate_bounds` checks
positions against `0..gauge.travel`. `GaugeBinding.stepper_axis_id` becomes `gauge_id`.

`@dial_meaning_fields` becomes `[:driver, :pins, :reverse]`; a travel change only
invalidates when a stored point falls outside `0..travel` (the existing limits rule).

Migration `2026110812xxxx_replace_stepper_axes_with_gauges.exs` (user: delete all old
gauge data; it is beta and the old hardware cannot run on 3.3.0):

1. Drop `train_gauge_bindings`, `hardware_stepper_dial_calibrations`,
   `hardware_stepper_axes` (in FK order).
2. Create `hardware_gauges`; recreate `hardware_dial_calibrations` (`gauge_id` unique FK,
   delete_all) and `train_gauge_bindings` (`gauge_id` FK, no `inactive_behavior`,
   unique `[train_id, gauge_id]`).
3. `down` recreates the old tables empty (data is not restorable; documented).
4. `pins` is `{:array, :integer}` (ecto_sqlite3 stores JSON); exactly 4 entries.

### Applying a configuration (`configuration_manager.ex`, `hardware.ex`)

- `build_config_parts` = inputs ++ matrices ++ i2c ++ **gauges** (`{:gauge, gauge}` ->
  `%Configure{input_type: :gauge, ...}`).
- `validate_configuration`: gauges are their own element of the match tuple (not folded
  into `parts`), so the **3.3.0** floor applies whenever `gauges != []`, including a
  gauges-only device; 3.1.0 stays for the empty deployment only. Error stays `:firmware_update_required` with text naming the version.
- Remove `StepperManager.begin_deployment/finish_deployment` and the `stepper_token`.
- `Hardware.config_fingerprint/4` hashes `{pins, driver, travel, max_speed, acceleration,
  reverse}` per gauge (sorted by pins) instead of stepper axes.
- Host-side checks catch most `ConfigurationError` causes first (cap of 4, shared pins,
  ranges). The host cannot know the board type (Device has no board, Connection only the
  version), so direct drive on Due/ESP32 is caught by the firmware: when a configuration
  with gauges fails, the flash names the likely causes ("direct drive needs an AVR board:
  Pro Micro, Leonardo, Micro, Uno, Nano, Mega").
- Pin clashes: the gauge changeset (context-level) rejects a gauge pin used by an input,
  a matrix row/column or an output on the same device, since the firmware ignores
  `SetOutput` on gauge pins. RESET_N shared between gauges stays allowed.
- `Firmware.Compatibility` is a config-driven requirement, not a pinned version; nothing
  to change there. The "firmware update required" message points at the existing
  firmware update screen.
- `ModuleError` with `i2c_address 0` is logged and broadcast so the gauge section can say
  "a gauge pin can't drive an output on this board" (today ModuleError is only logged).
- Delete `update_stepper_shield_address`, `allcall_*`, `validate_stepper_display_conflict`,
  `commission_stepper_axis`, the `dial_valid` option and `StepperManager` calls.

### Runtime (`lib/trenino/hardware/gauge_driver.ex`, new, stateless)

```elixir
@spec set_position(Gauge.t(), non_neg_integer()) :: :ok | {:error, reason}
@spec zero(Gauge.t()) :: :ok | {:error, reason}
```

Each call resolves the device's live port (`Connection.list_devices`, connected, matching
`config_id`), checks firmware >= 3.3.0 and that the saved fingerprint equals
`device.applied_fingerprint` (else `:needs_apply`), clamps to `0..travel`, then sends
`SetGaugePosition` / `ZeroGauge` with `pin = hd(pins)`. Failure atoms:
`:device_not_connected`, `:firmware_update_required`, `:needs_apply`. The
fingerprint check reads the DB; to keep the 200 ms hot path cheap, `GaugeController`
caches the gauge and its "applied" verdict and refreshes on `"hardware:configuration"`
and `{:gauge_bindings_changed, _}` (it already caches hardware lookups, 65bf317).

Delete `StepperManager`, `StepperSession` (+ state), `StepperLease`,
`StepperSupervisor`, `GaugeWizard` (+ runner, observation) and their supervision
children / `:start_stepper_manager` config.

### Train side (`lib/trenino/train/`)

- `GaugeController.send_target` calls `GaugeDriver.set_position`. Keep the 2 s resend
  backstop: it also restores the needle after a Configure or a device reboot re-zeroes it.
  Additionally clear `sent` on `{:configuration_applied, ...}` and on device reconnect so
  the needle returns immediately after the zero sweep (the firmware queues a position sent
  during the sweep).
- Remove `subscribe_steppers`, `forget_unheld_targets`, `holds_target?`, and the
  `inactive` calls (stale = hold: only mark the status stale, send nothing).
- **Manual hold**: while the calibration panel or the MCP `move_gauge` tool drives a gauge,
  the controller must not overwrite it. `GaugeController.hold_manual(gauge_id, ttl_ms)`
  records `manual_until`; `send_target` skips gauges under manual hold (status
  `failure: :manual_control`). Each manual move renews it (60 s); "Done" in the panel or
  `release_manual` ends it, and the panel's LiveView pid is monitored so closing the page
  releases it. Ending a hold clears `sent` for that gauge so the train value is resent.
- `GaugeMapper.map/3` takes `%Gauge{}`; bounds are `0..travel`.
- `GaugeBinding`: `belongs_to :gauge`; drop `inactive_behavior`; `enableable?/1` =
  dial valid and reviewed (no `commissioned`).
- `Train` context preloads `gauge: [:device, :dial_calibration]`.
- `GaugePresets.class323_speedometer/0` unchanged.

### UI (`lib/trenino_web/`)

Configuration edit page, Gauges section (still `:if={@beta_gauges}`), built with
`section_group` / `config_section` / `row_actions` / `section_empty`:

- **Gauge form** (`GaugeFormComponent`, replaces `StepperAxisFormComponent`): name,
  driver radio (VID6606 / Direct), labelled pin inputs per driver (STEP, DIR, RESET_N
  optional | Contact 1-4), travel, max speed, acceleration, reverse. A "train-lever gauge
  board" pin preset select fills channel A-D (`[8,7,6]`, `[14,16,6]`, `[21,20,6]`,
  `[5,4,6]`) and VID6606 defaults. Hint text: direct drive is AVR only, VID6606 boards
  should configure all four channels, max four gauges.
- **Gauge row**: name, driver and pins summary, "Calibrate" and edit/delete row actions,
  "Apply needed" when the fingerprint differs (existing pattern), firmware note when the
  connected device is < 3.3.0.
- **Calibration panel** (`GaugeCalibrationComponent`, replaces wizard + commissioning
  components): enabled only when the device is connected, on >= 3.3.0 and applied.
  - step slider + number input (0..travel) and nudge buttons (-10, -1, +1, +10) that send
    `SetGaugePosition` (throttled ~20 Hz) under a manual hold;
  - "Zero" button (`ZeroGauge`);
  - dial points table: unit select, "Add point at this position" (value input), edit,
    delete, "Go to" (moves the needle to a point), "Save" and "Save as reviewed".
  - On close: release the manual hold.
- Train edit page `GaugeBindingWizard`: pick a gauge (`Hardware.list_all_gauges/0`); drop
  `StepperManager.snapshot` blockers; blockers become "dial not calibrated", "needs apply",
  "device not connected / firmware". Rename stepper wording.
- Delete `GaugeGuidance.axis_status` lifecycle logic, `GaugeFeedback` lease/reference
  vocabulary (keep value/unit helpers), `StepperCommissioningComponent`,
  `GaugeWizardComponent`, `new_gauges_section` firmware 3.1.0 placeholder text (3.3.0).

### MCP (`lib/trenino/mcp/tools/`)

Replace `StepperTools` (7 tools) with `GaugeTools` (7 tools, beta `:gauges`):
`list_gauges`, `create_gauge`, `update_gauge`, `delete_gauge`,
`apply_gauge_configuration`, `move_gauge` (gauge_id, position; takes the manual hold),
`zero_gauge`. `move_gauge` with `release: true` (no position) hands the gauge back to the
train; there is no separate release tool. Tool count stays 72 (beta off 43); update
`beta_test.exs` (`list_stepper_axes` -> `list_gauges`) and `tool_registry.ex`. Rewrite
descriptions in `GaugeBindingTools`, `DialCalibrationTools` ("measure points with
move_gauge and read the dial"), `GaugeSerialization` (drop lease/status; add firmware
3.3.0 message). Arg names `stepper_axis_id` -> `gauge_id`.

### Tests

- Delete: `stepper_command_test`, `stepper_status_test`, `stepper_manager_test`,
  `stepper_session_test`, `stepper_fault_sequences_test`, `stepper_axis_test`,
  `gauge_wizard_test`, `gauge_wizard_runner_test`, `stepper_tools_test`,
  `stepper_setup_test`, `stepper_axis_card_test`, `gauge_wizard_test` (live),
  `move_gauge_calibration_migration_test`, `test/support/stepper_firmware.ex`.
- Beta: off-state tests in `beta_features_test.exs` for the calibration panel and Gauges
  nav; `beta_test.exs` asserts `list_gauges` is hidden with beta off.
- New/rewritten: `configure_test` gauge clause (round trip, exact bytes against the two
  hex examples in firmware `GAUGE_WIRING.md`), `set_gauge_position_test`,
  `zero_gauge_test`, `gauge_test` (changeset), `gauges_test` (context: 4-gauge cap,
  shared RESET_N allowed, pin clash rejected, dial invalidation), `gauge_driver_test`,
  `configuration_manager_test` (gauge parts, 3.3.0 floor), `gauge_controller_test`
  (send via driver, resend after configuration_applied, manual hold, stale holds),
  `gauge_tools_test`, LiveView `gauge_setup_test` (form, presets, calibration panel
  sends messages), `dial_calibration_test` (bounds = travel), migration test.
  Use Mimic per the mimic-testing skill for `Connection.send_message`.

### Docs

Rewrite `docs/stepper-gauges.md` as `docs/gauges.md` (wiring summary linking firmware
`GAUGE_WIRING.md`, train-lever board presets, calibration panel, MCP flow). Update
`getting-started.md`, `train-configuration.md` (3.3.0), README "(beta)" line, settings
toggle description, CHANGELOG entry (breaking: requires firmware 3.3.0; old stepper axes,
dials removed).

## Build order

1. Protocol codecs + tests.
2. Migration, `Gauge` schema, context CRUD, dial/binding FK rename + tests.
3. ConfigurationManager / fingerprint / firmware floor + tests.
4. `GaugeDriver` + `GaugeController` changes (manual hold) + tests; delete stepper
   runtime and supervision children.
5. MCP `GaugeTools` + description rewrites + count tests.
6. UI: form, row, calibration panel, binding wizard + LiveView tests; delete old
   components.
7. Docs, CHANGELOG, `mix precommit`.

## Review outcome (Fable, 2026-11-08) — these override the sections above

1. **Pin rule** (firmware `gaugePinsConflict`): a gauge's own pins (STEP/DIR, or the four
   coils) must differ from every other gauge's own pins **and** from every other gauge's
   RESET_N. Only RESET_N may equal another gauge's RESET_N. No separate `pins[0]` check.
2. **Gauges-only device**: thread gauges through both `validate_configuration` and
   `send_configuration_messages`; the empty Configure is sent only when inputs, matrices,
   i2c modules *and* gauges are all empty. Otherwise a gauges-only device would get
   `02 id 00 00 ff` and lose its gauges. `validate_firmware_floor(port, version)`.
3. **ModuleError** carries no pin, so the message is device-level: "A gauge on this
   device failed to start: check its pins exist on this board." Broadcast after an
   apply only (boot-time errors are logged; out of scope).
4. **No `GaugeDriver` module**: `Hardware.set_gauge_position(port, gauge, position)` and
   `Hardware.zero_gauge(port, gauge)` like `set_output/3`, plus
   `Hardware.gauge_link(gauge)` -> `{:ok, port}` | `{:error, :device_not_connected |
   :firmware_update_required | :needs_apply}` for the panel/MCP. `applied_fingerprint ==
   nil` counts as `:needs_apply`. Whole-device fingerprint is accepted: an unapplied edit
   to an input also pauses that device's gauges until Apply (stated in the UI).
5. **GaugeController** caches `%{device_id => port | error}` and refreshes it on
   `Connection.subscribe/0` `{:devices_updated, _}` and
   `ConfigurationManager.subscribe_configuration/0` `{:configuration_applied, ...}`;
   both also clear `sent` so the needle is resent after the zero sweep. No resend hook on
   IdentityResponse (the 2 s backstop and devices_updated cover it).
6. **Manual hold** lives in `GaugeController` (works with `train: nil`). The panel takes it
   with a monitored pid (LeverController `sweep_started` precedent, `call_if_running`);
   MCP `move_gauge` takes it with a 60 s TTL renewed per move; `release: true` ends it.
   Status copy: stale = "holding last value; after a reboot the needle rests at zero".
7. **Migration**: `down` raises (irreversible). Old migrations untouched.
8. **MCP**: apply tool is `apply_device_configuration` (applies everything). Tools:
   `list_gauges, create_gauge, update_gauge, delete_gauge, apply_device_configuration,
   move_gauge, zero_gauge` (7, count stays 72 / 43). `GaugeRuntimeTools` stays beta;
   its serialization drops `inactive`/lease fields.
9. **Also touch**: `device.ex:40` has_many, `test_helper.exs` Mimic copies,
   `application.ex` stepper children + `config/test.exs :start_stepper_manager`,
   `sections.ex` `new_gauges_section` (DOM id `stepper-axes` -> `gauges`, update
   `beta_features_test`), `settings_live.ex`, `beta.ex` comment; tests
   `stepper_axes_test`, `stepper_gauge_integration_test`, `gauge_runtime_tools_test`,
   `gauge_bindings_test`, `gauge_mapper_test`, `section_structure_test`,
   `configuration_edit_live_test`, `train_edit_live_test`.

## Verification limits

Neither the firmware gauge module nor this host side has run on hardware yet (firmware
980b9e5 says so). Verification here is codec byte tests against the firmware's documented
hex examples, Mimic-based tests, and `mix precommit`.

## Open questions (resolved)

Hold owner: GaugeController. Resend on IdentityResponse: no. `pins`: `{:array, :integer}`
with `length == 4`, named inputs in the form.
