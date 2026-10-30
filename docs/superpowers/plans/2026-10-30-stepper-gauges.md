# Stepper gauges Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. The user chose GPT 6.1 Sol implementation after Astra planning. Steps use checkbox syntax for tracking. Do not ask for a new approval gate; the user authorized autonomous execution.

**Goal:** Make configurable physical gauges usable from Trenino's hardware and train UI, including commissioning, calibration, simulator driving and safe recovery.

**Architecture:** Dedicated per-port stepper sessions own motion lifecycle through the existing Serial.Connection. Hardware and Train contexts persist axes and gauge bindings; a pure mapper converts simulator samples into bounded positions. A train controller handles subscriptions, while LiveView and MCP use the same contexts and runtime operations.

**Tech Stack:** Elixir 1.20/OTP29 locally (project minimum ~>1.16), Phoenix1.8/LiveView1.2, Ecto SQLite, Circuits.UART, ExUnit/Mimic, Tailwind/HEEx.

**Spec:** `docs/superpowers/specs/2026-10-30-stepper-gauges-design.md` (read in full).

## Global Constraints

- Firmware floor: stable version >=3.1.0; extension revision 1; inspect status capability bits before Configure.
- Two logical axes (0 and 1), one shared shield address 0x60–0x77, distinct ports 1 and 2.
- Positions -1000000..1000000; speed1..200 transitions/s; acceleration1..10000 transitions/s²; watchdog100..60000ms.
- Startup_reference manual is default. Explicit opt-in home_on_connect may Home once on a fresh connection only for commissioned internal-stop+hold axes after capability/Reset/Configure; never auto Reference, train-activation Home, or blind retry after uncertainty/reboot/fault/process restart.
- Continuous bindings require idle hold; firmware reference is volatile and completion of internal-stop Home is assumed, not sensed.
- Firmware generic; all train names, unit conversion, calibration and geometry live in Trenino.
- No physical commands on form mount/validation/save. Startup auto-Home is an explicit persisted commissioning preference, not a template default. No raw JSON/config-byte UI.
- Preserve original checkout's untracked mechanical/docs work. Work only in `C:\Users\Alberto\Documents\trenino-stepper` on `codex/stepper-gauges`, baseline333a8ea.
- Tests must never discover, upload to, or operate real hardware. Use existing DataCase/SerialSafetyCase forbidden UART stubs.
- Follow CLAUDE.md and `.claude/skills/{elixir-patterns,phoenix-liveview,mimic-testing}/SKILL.md`; structs/typespecs, no dynamic atoms, 2-decimal user values, explicit form IDs.

## Review Focus

- Same COM port with a new UART generation, or repeated devices_updated from unrelated hardware: new generation resets reference; duplicate updates do not reset a running gauge (Task4).
- Stale Home ACK/retry after Stop, legacy deployment, or reconnect: never execute Home again or restore a false known reference (Tasks3–4).
- Numeric strings, nil, ambiguous Values maps, stale HTTP completion and negative speeds: no arbitrary zero/movement or cross-train update (Tasks5–6).
- Editing mode/bounds while a binding is active or deleting an energized axis: invalidate incompatible mapping and stop ownership safely (Tasks2,4,6).
- UI refresh/browser closure during commissioning and display0x70 first registration: no automatic motion, clear manual ownership, explicit registration guidance (Tasks4,7–8).

## Recon and execution notes

Parent has prepared worktree, trusted its inspected mise.toml and built dependencies. Baseline `mix test` passed1569 tests,3 excluded,62seconds; log `%TEMP%\trenino-stepper-baseline.log`. `mix`, `elixir` available from mise (1.20.4-otp-29). `mix precommit` runs compile warnings-as-errors, deps.unlock --unused, format, credo strict, full tests; inspect dependency-lock changes before staging. Prefer `login:false` on PowerShell tool invocations if shell startup mise emits noise.

Read firmware final `docs/STEPPER_PROTOCOL.md`, `src/stepper.cpp`, `src/stepper_service.cpp`, plus empty configuration tests. Firmware v3.1.0 was published at ed24b0e with canonical8-byte empty config; parent verified eight board builds and159 native tests. Empty config removes legacy configured modules and resets axes; independent SetOutput pins retain existing semantics. It is not a global pin reset.

Existing integration points: `Hardware.ConfigurationManager` (`apply_configuration/2`, in_flight map), `Serial.Connection` (`send_message/2`, subscriptions, all-status device events), `DeviceConnection` (pid/version/config_id), `Train.DisplayController` (subscription lifecycle pattern), `DisplayBindingWizard`/`I2cModuleFormComponent` and corresponding editor sections, `MCP.Tools.SequenceTools` canonical CRUD. Current DisplayFormatter has unit conversion assuming m/s; new generic conversion belongs to GaugeMapper, without incidental display refactoring.

Use separate source files for Session.State/struct helpers; don't add more nested modules. The following names/interfaces are deliberate shared contracts. Implementation may split private helpers for maintainability without changing the public contracts.

### Task 1: Exact protocol codecs and empty configuration

**Files:** Create `lib/trenino/serial/protocol/stepper_command.ex`, `stepper_configuration.ex`, `stepper_status.ex`; modify `message.ex`, `configure.ex` in that directory. Tests `test/trenino/serial/protocol/stepper_command_test.exs`, `stepper_status_test.exs`, existing `configure_test.exs` and `message_test.exs`.

**Interfaces:** `%StepperCommand{operation, axis, request_id, configuration, position}`, `encode/1`, `decode_body/1`; configuration is `%Serial.Protocol.StepperConfiguration{}` with exactly the wire fields named as in StepperAxis schema (no id/device/name/timestamps/commissioning/startup fields). Task2 adds `StepperAxis.to_protocol_config(axis) :: StepperConfiguration.t` so protocol has no Ecto dependency. `%StepperStatus{operation, axis, request_id, result, state, configured, known, energized, reference_kind, fault, position, target, phase, max_axes, drivers, modes, homing}` with decode_body/1. Public operations/enums are atoms mapped explicitly. `StepperStatus.supports?(status, protocol_config) :: boolean`. `Configure{input_type: :empty}`.

- [ ] Write golden byte tests using signed minimum -1000, maximum720, direction-1, request0x1234, mode six-state, address0x60, port1, watchdog1000; assert Configure byte_size41 and exact offsets. Assert MoveTo(-1) payload `<<255,255,255,255>>`, Home6 bytes, Status23 bytes, reference-kind flags, all result/fault/state variants.
- [ ] Assert malformed/trailing bytes, revision2, unknown operation, invalid request0 mutation, axis255 on axis operations, invalid integer widths, speed201 and unknown enums return errors without raise/truncation. Assert valid extra capability bits don't hide supported bits.
- [ ] Assert empty config id0x12345678 encodes `<<2,0x78,0x56,0x34,0x12,0,0,255>>`; malformed empty discriminator/size/part rejected; old formats unchanged.
- [ ] Run `mix test test/trenino/serial/protocol`, verify new tests fail for missing codecs, implement exact layouts and Message dispatch0x10/0x11, rerun until passing. Commit `feat: add stepper protocol and empty configuration codecs` with explicit paths only.

### Task 2: Persist axes and central hardware validation

**Files:** Create `priv/repo/migrations/20261030120000_create_hardware_stepper_axes.exs`, `lib/trenino/hardware/stepper_axis.ex`; modify `hardware.ex`, `hardware/device.ex`; tests `test/trenino/hardware/stepper_axis_test.exs`, `stepper_axes_test.exs`.

**Interfaces:** Hardware `list_stepper_axes(device_id) :: [StepperAxis.t]`, `list_all_stepper_axes/0` preloaded device; `get_stepper_axis(id) :: {:ok, axis}|{:error,:not_found}`; create_stepper_axis(device_id, attrs), update_stepper_axis(axis,attrs), delete_stepper_axis(axis), all return usual Ecto tuples. `StepperAxis.changeset/2`, `motion_changed?/1`. Runtime reconciliation hooks are integrated in Task4, not hidden network I/O in a changeset.

- [ ] Write migration/schema/context tests for every firmware range, unique index and shared resource constraint; third axis/duplicate port/second shield rejected, different port same shield accepted. Home timeout insufficient for sweep+backoff+500ms margin rejected. Validate startup_reference enum and require commissioned+internal_stop+hold for effective home_on_connect; clearing commissioning disables automatic startup immediately (may retain selected preference visibly inactive). Name-only update preserves commissioned; mode/direction/limits/home changes clear it. Hex address parsing accepts0x60 and decimal96 consistently through context/UI.
- [ ] Test axis belongs to real device, device cascade, database round trip for every field and no stored runtime known/position state. Add validation for display-address conflict and known SDA/SCL pin conflict without assuming all boards use Nano pins.
- [ ] Run `mix test test/trenino/hardware/stepper_axis_test.exs test/trenino/hardware/stepper_axes_test.exs`, observe failure, implement schema/migration/context transactions and association, rerun passing. Commit `feat: persist configurable hardware stepper axes`.

### Task 3: Session state machine, request correlation and watchdog

**Files:** Create `lib/trenino/hardware/stepper_session.ex`, `stepper_session/state.ex`, `stepper_session/axis_state.ex`; tests `test/trenino/hardware/stepper_session_test.exs`; add mock registrations in `test/test_helper.exs` as needed with type_check:true.

**Interfaces:** `StepperSession.start_link(opts)` accepts port, generation, device_id, axes, send_fun (default Connection.send_message/2), optional timing overrides. `snapshot(pid) :: map`; `command(pid, axis_id, operation, params, owner_token) :: {:ok,request_id}|{:error,reason}` immediate admission result; `set_target(pid,axis_id,target,owner_token) :: :ok|{:error,reason}` coalescing; `begin_deployment(pid) :: {:ok,token}|{:error,reason}` replies after acknowledged Reset; `finish_deployment(pid,token,result) :: :ok`. Status updates published `{:stepper_updated, device_id, snapshot}` on `hardware:steppers:<device_id>`; snapshot structs/documented shapes contain lifecycle, per-axis status, pending operation/error, capabilities and manual pause.

- [ ] Build fake transport tests driving actual GenServer messages, recording commands and returning encoded/decoded firmware fixture status via PubSub. No real UART. Assert GetStatus axis0 → Reset255 → Configure0/1 ordering and awaiting_reference; version/capability failure sends no Configure.
- [ ] Test ACK only transitions accepted/pending, Home remains homing until known idle status; idle release never ready; async request0 not an ACK. Test250ms timeout retries same exact ID/content at most twice, then unknown outcome and status poll. Delayed ACK for superseded Home cannot complete a Stop or trigger new Home. Stop preempts pending Home and clears its retry.
- [ ] Assert watchdog tick occurs at250ms for1000ms and25ms for100ms, during homing and pending ACK, with two axes using minimum watchdog. Status polling250ms moving/1000ms idle. Cancelled old-generation timer ignored. Request65535 followed by Reset/reconfigure before request reuse and awaits reference.
- [ ] Test malformed/unknown status, I2C shared fault, host loss, unconfigured unexpected reboot, failed Reset (power unknown), failed serial write/exit, and failed reconfigure all prevent targets. Keep last target only on successful acceptance; coalesce three pending targets into latest; do not deduplicate across lost reference/generation. A late known async status after Reset in the same UART generation must not restore ready without explicit Home/Reference in the new reference epoch and a fresh correlated status poll.
- [ ] Run `mix test test/trenino/hardware/stepper_session_test.exs`, confirm failures then implement bounded asynchronous state machine and enum-safe status handling. Keep HTTP/database long work out of this process. Rerun pass and commit `feat: manage stepper command sessions and watchdogs`.

### Task 4: Manager, ownership and deployment arbitration

**Files:** Create `lib/trenino/hardware/stepper_manager.ex`, `stepper_supervisor.ex`; modify `hardware/configuration_manager.ex`, `hardware.ex`, `application.ex`, `config/test.exs`; tests `test/trenino/hardware/stepper_manager_test.exs`, `configuration_manager_test.exs`, `stepper_axes_test.exs`.

**Interfaces:** Manager `snapshot(device_id)`, `subscribe(device_id)`, `claim_manual(axis_id, owner_pid) :: {:ok,token}|error`, `release_manual(axis_id,token)`, `resume(axis_id)`, `command(axis_id,op,params,token)`, `set_target(axis_id,target,train_id)`, `begin_deployment(port)`, `finish_deployment(port,token,result)`, `reconcile_device(device_id)`, `recommission_address(device_id,new_address,acknowledged?)`. Hardware exposes delegated user-facing functions as appropriate. `begin_deployment` is the only configuration barrier; session never synchronously calls back ConfigurationManager. Inactive action also routed through Manager, not raw Serial writes.

- [ ] Write tests with two ports, startup already-connected snapshot, repeated identical updates, same port/new pid, disconnected/uploading state in nonempty devices list, duplicate config_id conflict, and process restart. New generation awaits reference by default; opted-in commissioned internal-stop axes Home exactly once after acknowledged setup; identical event never resends Reset or Home. Manager/session restart for already-connected board and configuration reload never auto-Home. Failure/uncertainty never allocates a fresh Home ID.
- [ ] Write integration race test: queue desired target, begin deployment, assert ACKed Reset before any legacy Configure and no target until fresh explicit reference. Cover initial no-session barrier, concurrent apply same port, ConfigurationStored with correct id wrong port, send failure, timeout, rejected config, DB confirm failure and disconnect; barrier is finalized exactly once and no stale event restores readiness.
- [ ] Enable axis-only Apply with canonical empty packet (no `:no_inputs`); gate old firmware; after real ConfigurationStored update tracked config_id and configure axes. Preserve previous nonempty device flows. Don't claim empty config clears independent SetOutput pins.
- [ ] Test manual take-control pauses Train targets; owner DOWN clears lease/stops, does not resume; forged token rejected; jog only from fresh stationary known status. Explicit Resume required. Test delete energized axis waits for Release and reconciliation, failure preserves row; offline deletion works. Address change requires explicit Reset→ForgetDriver→Configure; ordinary resource conflict never invokes ForgetDriver. Shared address updated transactionally and both axes lose reference.
- [ ] Wire supervisor order after Serial.Connection, manager before ConfigurationManager; add `:start_stepper_manager` config disabled in test. Manager must work for no-axis devices with no packets/extra failure. Run `mix test test/trenino/hardware/stepper_manager_test.exs test/trenino/hardware/configuration_manager_test.exs test/trenino/hardware/stepper_axes_test.exs`; implement until pass. Commit `feat: coordinate stepper ownership and device deployments`.

### Task 5: Gauge bindings and pure mapping

**Files:** Create `priv/repo/migrations/20261030121000_create_train_gauge_bindings.exs`, `lib/trenino/train/gauge_binding.ex`, `gauge_point.ex`, `gauge_mapper.ex`; modify `lib/trenino/train.ex`, `train/train.ex`, hardware update reconciliation; tests `test/trenino/train/gauge_binding_test.exs`, `gauge_mapper_test.exs`, `gauge_bindings_test.exs`.

**Interfaces:** `GaugeMapper.map(binding, raw_value, axis) :: {:ok,%{value:float,target:integer,clamped:boolean}}|{:error,reason}`; `GaugeMapper.convert(value,input_unit,output_unit) :: {:ok,float}|error`; Train list_gauge_bindings(train_id), list_enabled_gauge_bindings(train_id) preload stepper_axis: :device; get/create/update/delete_gauge_binding parallel existing display APIs. All mutations notify controller reload in context after success, so UI/MCP behave identically.

- [ ] Test points[{0,0},{50,350},{100,720}] yield25→175,75→535; descending positions supported; boundaries exact; -1 clamps0 or rejects by policy;101 clamps720;44.704mps converts100mph→720;36kmh converts10mps; raw→mph rejected. Test absolute input option separately from negative-value clamping and affine transform ordering.
- [ ] Test duplicate/sorted-after-rounding value, non-monotonic target, out-of-limit point,1/33points, invalid units, blank endpoint, invalid stale timeout, numeric string/nil/boolean/map inputs rejected. Enabled binding requires commissioned+hold axis, FK and train-axis unique constraints; device/axis delete cascades binding.
- [ ] Test axis mode update disables dependent bindings and invalidates calibration; bounds update prevents now-invalid binding use; offline save valid disabled binding allowed. Implement persistence/mapper/validation and context hooks. Run three new test files until pass, then commit `feat: add calibrated continuous gauge bindings`.

### Task 6: Simulator gauge controller and train lifecycle

**Files:** Create `lib/trenino/train/gauge_controller.ex`, `gauge_controller/state.ex`; modify `application.ex`, `config/test.exs`; tests `test/trenino/train/gauge_controller_test.exs`.

**Interfaces:** `GaugeController.start_link(opts)`, `reload_bindings/0`; consumes Train APIs and GaugeMapper plus StepperManager.set_target/3. Publishes `{:gauge_binding_updated, binding_id, runtime_status}` (status sample/transformed value/target/failure/stale/awaiting reference) on `train:gauges:<train_id>`; `subscribe(train_id)` and `snapshot(train_id)` support UI. Use4000–4999,200ms polling, per-binding stale_after_ms.

- [ ] Test endpoint dedup, chosen value_key, single numeric Values default, ambiguity and invalid NodeValid/Entries, unchanged target dedup, failed command not marked delivered. Confirm activation without reference/commissioning never moves; fresh sample after explicit reference/resume does.
- [ ] Test simulator disconnected, stale value after2000ms, hold/release policy once, train changed to nil and another train, old sample/task result late, restart and reconnect; unsubscribe old client's IDs, cancel timers, no previous train sample escapes. Slow HTTP polling cannot prevent serial loss/manual pause event handling or allow overlapping unbounded polls. Retry failed subscriptions with backoff while active.
- [ ] Test mode edit/deletion/reload during in-flight poll, manual ownership denial and explicit resume, two axes independent targets/shared fault; controller cannot Home/Reference automatically (optional startup Home belongs only to the hardware session). Add `:start_gauge_controller` false in tests and gated production supervision. Run `mix test test/trenino/train/gauge_controller_test.exs`, implement until pass; commit `feat: drive calibrated gauges from active train telemetry`.

### Task 7: Hardware axis forms and usable commissioning UI

**Files:** Create `lib/trenino_web/live/components/stepper_axis_form_component.ex`, `stepper_commissioning_component.ex`, `lib/trenino/hardware/stepper_presets.ex`; modify `lib/trenino_web/live/configuration_edit_live.ex`, `configuration_list_live.ex` only where Apply availability/counts require; tests `test/trenino_web/live/stepper_setup_test.exs`, existing configuration editor tests; preset test `test/trenino/hardware/stepper_presets_test.exs`.

**Interfaces:** `StepperPresets.class323_speedometer_axis/0 :: map` returns disabled/uncommissioned editable candidates from spec. Components send `{:stepper_axis_saved,axis}`, `:stepper_axis_cancelled`; editor forwards stepper status and manages manual lease with LiveView pid, no singleton component process assumption. Stable IDs: `stepper-axes`, `stepper-axis-form`, `stepper-commissioning`, `stepper-home`, `stepper-stop`, `stepper-release`, `stepper-reference`, `stepper-resume` (prefix axis id where multiple rendered).

- [ ] Write LiveView flow test create axis via labeled fields → save → select connected eligible device → Apply empty legacy config → show awaiting reference. All config fields editable; shared-port/address/form validation visible. Unsupported firmware renders update guidance and rejects forged submit/runtime events.
- [ ] Test manual claim/jog/home/reference/stop/release/enable/recover/complete commissioning/resume controls call manager with exact params; no calls on mount/change/save. Home ACK shows in progress, completion says “Assumed internal-stop reference”; unknown position shows unavailable. Idle release warning prevents continuous binding expectations.
- [ ] Test disconnected/error/busy status updates, forged foreign-axis IDs, malformed integer events, browser termination/owner DOWN, failed apply and retry; new config transition initializes axis assigns correctly. Show first-registration/address-change ALLCALL instructions and explicit acknowledgement flow, not automatic ForgetDriver.
- [ ] Implement forms with existing .input/to_form conventions, units and advanced fields, axis cards and commissioning panel. Include editable Class323 preset with conspicuous unverified physical calibration and host-reference/manual-startup default; after commissioning internal-stop mode offer clearly labeled opt-in automatic Home on new connection. Test selecting the preference never moves immediately and that uncommissioned axes cannot use it. Run `mix test test/trenino_web/live/stepper_setup_test.exs test/trenino_web/live/configuration_edit_live_test.exs test/trenino/hardware/stepper_presets_test.exs`; commit `feat: add stepper configuration and commissioning screens`.

### Task 8: Train gauge wizard, calibration capture and starter profile

**Files:** Create `lib/trenino_web/live/components/gauge_binding_wizard.ex`, `lib/trenino/train/gauge_presets.ex`; modify `lib/trenino_web/live/train_edit_live.ex`; tests `test/trenino_web/live/gauge_setup_test.exs`, `test/trenino/train/gauge_presets_test.exs`.

**Interfaces:** Wizard sends `{:gauge_binding_saved,binding}`/`:gauge_binding_cancelled`; accept explorer_event forwarding like DisplayBindingWizard, client optional for offline editing/manual endpoint entry. `GaugePresets.class323_speedometer/0` returns mps→mph points0→0/100→720, no endpoint, enabledfalse; selected hardware bounds validated before use. Stable IDs `gauge-bindings`, `gauge-binding-form`, `gauge-calibration-points`, `gauge-preview`, `gauge-test-value`, `gauge-capture-position`.

- [ ] Test complete flow select configured axis → select endpoint through existing API explorer → choose key/units/abs/transform → add/edit/remove/reorder measured points → preview → save disabled → commission/enable → live state. Deletion and enable toggle update controller without remount. Missing hardware guidance is actionable.
- [ ] Test offline binding edit, preview never moves, Test value requires manual lease, capture requires known stationary fresh status and records entered dial value; invalid/out-of-range/duplicate points visible. Cancel releases/preserves pause correctly; stale explorer event cannot update another wizard; foreign binding IDs rejected.
- [ ] Test starter shows0–100mph/240°/approximately720transitions as unverified estimate; no guessed simulator endpoint, no automatic Home/enable; all values editable and round-trip. Live card shows latest sample/converted value/estimated target, awaiting reference/stale/fault/manual pause and link to commissioning.
- [ ] Implement dedicated wizard with human fields, point table and simple SVG or textual mapping preview, forwarding editor hooks without expanding unrelated flows. Run `mix test test/trenino_web/live/gauge_setup_test.exs test/trenino/train/gauge_presets_test.exs test/trenino_web/live/display_setup_test.exs`; commit `feat: add train gauge setup and calibration workflow`.

### Task 9: MCP parity and documentation

**Files:** Create `lib/trenino/mcp/tools/stepper_tools.ex`, `gauge_binding_tools.ex`; modify `mcp/tool_registry.ex`, docs/train-configuration.md, README.md as appropriate; create `docs/stepper-gauges.md`; tests `test/trenino/mcp/tools/stepper_tools_test.exs`, `gauge_binding_tools_test.exs`, and registry/server/controller counts in all3 CLAUDE.md paths.

**Interfaces:** MCP names `list_stepper_axes`, `get_stepper_axis_status`, `create_stepper_axis`, `update_stepper_axis`, `delete_stepper_axis`, `control_stepper_axis`; `list_gauge_bindings`, `create_gauge_binding`, `update_gauge_binding`, `delete_gauge_binding`, `preview_gauge_binding`. Runtime control explicit op and params, uses ownership/session safety; Home/Reference never implied by CRUD. Add Manager `claim_mcp_manual(axis_id) :: {:ok,opaque_token}`, `renew_mcp_manual(axis_id,token)`, `command_once(axis_id,operation,params,lease_token,operation_token)` and explicit release operation. Manager owns MCP token leases for60000ms (HTTP request pid is ephemeral); explicit renew only, expiration Stops/leaves paused, reset/disconnect revokes. Deduplicate mutating operation_token with identical content for entire lease, maximum100 records then reject further new operations until new lease; changed-content reuse rejects. Tool response includes token expiry, command acceptance/pending and actual status. All commissioning operations remain available, with bounded manual ownership and retry safety.

- [ ] Test tool schemas/routing, malformed params, not-found, identical domain validation, serialization of units/points/reference-kind/pending/error; disabled creation, no raw serial bypass, no movement on CRUD or preview. Test runtime operation cannot retain a lease forever after request process exits and cannot restart Home on HTTP retry without same operation token.
- [ ] Implement tools following SequenceTools; update all3 count assertions using actual added count, no guessed numbers. Document all lifecycle/commissioning/ALLCALL/reference/mapping/failure behavior from spec plus Class323 walkthrough and physical verification checklist. Note version3.1.0 floor and empty config semantics.
- [ ] Run `mix test test/trenino/mcp/tools/stepper_tools_test.exs test/trenino/mcp/tools/gauge_binding_tools_test.exs test/trenino/mcp/tool_registry_test.exs test/trenino/mcp/server_test.exs test/trenino_web/controllers/mcp/mcp_controller_test.exs`; commit `feat: expose gauge configuration tools and commissioning guide`.

### Task 10: Whole feature verification and handoff

**Files:** Add `test/trenino/stepper_gauge_integration_test.exs` and adjust only feature-owned bugs found; update docs acceptance evidence.

- [ ] Integration test mocked transport+simulator drives persisted axis-only hardware → real empty Configure bytes → ConfigurationStored identity association → probe/Reset/Configure → user Reference → commissioned enable binding →44.704mps maps720 → manual takeover blocks telemetry → release/disconnect invalidates → reconnect configures without Home/Move → explicit reference/resume uses fresh telemetry. Test opted-in commissioned startup Home separately: once per actual new connection, no Home for duplicate status events/restarts/deployment, successful completion enables fresh telemetry and failure remains blocked. Second scenario existing input+display+two axes deployment cannot interleave targets, shared I2C fault invalidates both, stale samples cannot move after train switch.
- [ ] Run focused integration plus all new test files. Run `mix format --check-formatted`, `mix precommit`; inspect every failure against baseline and fix relevant issues, do not waive introduced regressions or delete meaningful tests. Final passing output is required before “complete”.
- [ ] Review diff for unsafe raw UART calls, arbitrary atoms, bypassed ownership, unconfigured/uncertain autoHome, truthfulness of homing labels, unverified preset enabled by default, partial UI routes, changed user work, migrations supported by SQLite, registered MCP count changes and added dependencies (should be none).
- [ ] Start app in controlled environment with UART discovery stubbed/disabled and inspect actual hardware/train forms visually if feasible; do not let a UI smoke test touch the user's physical controller. Tests remain the verified minimum if no browser runtime available. Record physical hardware test unperformed distinctly from software pass.
- [ ] Commit any final fixes with explicit paths. Report branch/worktree, tests and exact usable UI route/flow, plus human hardware checks still required. No push, merge, deployment or firmware flashing unless parent/user already authorized it separately.

## Self-review and acceptance coverage

Persistence/configuration: Tasks1–2,4; transport/lease/retries/faults:3–4; mapping/calibration/unit policies:5,8; simulator/train transitions:6; complete hardware UI:7; complete train UI:8; MCP/docs:9; full interaction evidence:10. Every Review Focus class has explicit tests above. Physical home direction, real travel/steps, winding order, stop contact, needle fit and endpoint units remain measured commissioning inputs—not software assumptions. The parent handles firmware publication; host implementation must verify final contract bytes before locking fixtures.

