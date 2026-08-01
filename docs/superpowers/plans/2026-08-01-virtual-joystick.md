# Windows Virtual Joystick Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Expose selected Trenino lever and button inputs as one removable Windows DirectInput joystick backed by vJoy device 1.

**Architecture:** Elixir owns persistence, exclusive input routing, calibration, and a lifecycle state machine. A persistent Windows-only Rust sidecar owns the vJoy feeder SDK through a JSON Lines Erlang Port, while a separate configurator performs fixed elevated create/delete operations. The Windows installer bundles a pinned signed vJoy release but leaves no device configured until the user enables the mode.

**Tech Stack:** Elixir/OTP, Ecto/SQLite, Phoenix LiveView, Rust, vJoy feeder SDK, Tauri 2, NSIS, ExUnit/Mimic.

## Global Constraints

- Windows 10/11 x86-64 only for runtime virtual joystick support; other platforms report `unsupported` and never invoke native tooling.
- The first release supports only vJoy device index `1`, eight axes (`x`, `y`, `z`, `rx`, `ry`, `rz`, `slider_1`, `slider_2`), and buttons `1..32`.
- No POV hats, force feedback, output reports, toggle buttons, pulses, XInput, automatic game activation, or multiple-device UI.
- A physical input has exactly one destination: simulator/API behavior or virtual joystick.
- Axis values reuse hardware calibration, clamp to `0.0..1.0`, apply optional inversion, and follow the project rule of rounding user-facing floats to two decimals.
- Button values mirror physical pressed/released state directly.
- Disabling the UI mode deletes device 1; enabling creates it. Both operations may show UAC.
- The vJoy driver remains installed while toggling and is removed only by safe Trenino uninstall behavior.
- Native logs use stderr; stdout is reserved for versioned UTF-8 JSON Lines protocol messages.
- Driver/device operations never interpolate user-controlled shell fragments.

---

## File Map

New domain files live in `lib/trenino/virtual_joystick/`: `configuration.ex` and `mapping.ex` are schemas, `mapper.ex` performs pure axis conversion, `bridge.ex` owns the native Port, `configurator.ex` owns elevated device configuration, `manager.ex` owns runtime state, and `platform.ex` detects supported Windows execution. `lib/trenino/virtual_joystick.ex` is the sole public context for persistence and commands.

The native helper lives in `tauri/virtual_joystick/`, separate from the existing one-shot keystroke executable. UI code lives in a dedicated `VirtualJoystickLive` rather than enlarging `SettingsLive`. Packaging changes stay under `scripts/` and `tauri/src-tauri/`.

---

### Task 1: Persist Virtual Joystick Configuration and Mappings

**Files:**
- Create: `priv/repo/migrations/20260801000000_create_virtual_joystick_tables.exs`
- Create: `lib/trenino/virtual_joystick/configuration.ex`
- Create: `lib/trenino/virtual_joystick/mapping.ex`
- Create: `lib/trenino/virtual_joystick.ex`
- Modify: `lib/trenino/hardware/input.ex`
- Create: `test/trenino/virtual_joystick_test.exs`
- Create: `test/support/virtual_joystick_fixtures.ex`
- Modify: `test/support/data_case.ex`

**Interfaces:**
- Produces: `Trenino.VirtualJoystick.get_configuration/0`, `list_mappings/0`, `get_mapping/1`, `put_mapping/3`, `delete_mapping/1`, and schema types used by all later tasks.
- `put_mapping(input_id, attrs, replace?: boolean)` returns `{:ok, %Mapping{}}`, `{:error, :destination_conflict}`, or `{:error, %Ecto.Changeset{}}`.

- [ ] **Step 1: Write failing schema and context tests**

Cover singleton default creation, device index 1 validation, analog-to-axis and button-to-button validation, eight allowed axes, buttons 1–32, unique input, unique `{device_index, target_type, target}`, preloads, deletion, and mapping replacement flag behavior. Use concrete assertions such as:

```elixir
assert {:error, changeset} =
         VirtualJoystick.put_mapping(analog.id, %{target_type: :button, button: 1})

assert "must target an axis" in errors_on(changeset).target_type
```

- [ ] **Step 2: Run the new tests and verify the missing modules fail**

Run: `mix test test/trenino/virtual_joystick_test.exs`

Expected: compilation failure because `Trenino.VirtualJoystick.Mapping` and context functions do not exist.

- [ ] **Step 3: Add the migration and focused schemas**

Create `virtual_joystick_configurations` with a singleton primary key, `enabled` default false, and `device_index` default 1. Create `virtual_joystick_mappings` with `input_id`, `device_index`, `target_type`, nullable `axis`, nullable `button`, and `inverted`. Add check constraints for device 1, target shape, axis names, and button range, plus unique indexes on `input_id`, `{device_index, axis}`, and `{device_index, button}` using partial indexes for SQLite.

Implement the mapping changeset shape explicitly:

```elixir
field :target_type, Ecto.Enum, values: [:axis, :button]
field :axis, Ecto.Enum, values: [:x, :y, :z, :rx, :ry, :rz, :slider_1, :slider_2]
field :button, :integer
field :device_index, :integer, default: 1
field :inverted, :boolean, default: false
belongs_to :input, Trenino.Hardware.Input
```

- [ ] **Step 4: Implement the public persistence context**

Use `Repo.transaction/1` in `put_mapping/3`, load the input with calibration/device, validate its input type, and insert/update the mapping. Return `:destination_conflict` when replacement was not authorized. Add `has_one :virtual_joystick_mapping` to `Hardware.Input`. Put reusable device/input/calibration creation helpers in `Trenino.VirtualJoystickFixtures` and import that module from `Trenino.DataCase`.

- [ ] **Step 5: Run migration and tests**

Run: `mix ecto.migrate && mix test test/trenino/virtual_joystick_test.exs`

Expected: all tests pass.

- [ ] **Step 6: Commit**

```bash
git add priv/repo/migrations/20260801000000_create_virtual_joystick_tables.exs lib/trenino/virtual_joystick.ex lib/trenino/virtual_joystick lib/trenino/hardware/input.ex test/trenino/virtual_joystick_test.exs test/support/virtual_joystick_fixtures.ex test/support/data_case.ex
git commit -m "feat: persist virtual joystick mappings"
```

### Task 2: Enforce Exclusive Destinations and Map Axis Values

**Files:**
- Create: `lib/trenino/virtual_joystick/mapper.ex`
- Modify: `lib/trenino/virtual_joystick.ex`
- Modify: `lib/trenino/train.ex`
- Modify: `lib/trenino/train/lever_controller.ex`
- Modify: `lib/trenino/train/button_controller.ex`
- Create: `test/trenino/virtual_joystick/mapper_test.exs`
- Modify: `test/trenino/virtual_joystick_test.exs`
- Modify: `test/trenino/train/button_controller_test.exs`

**Interfaces:**
- Consumes: mapping schemas and persistence context from Task 1.
- Produces: `Mapper.axis_value/4 :: {:ok, integer()} | {:error, :invalid_range | :uncalibrated}` and destination-safe simulator binding operations.

- [ ] **Step 1: Write failing mapper tests**

Test calibrated minimum/maximum, midpoint, clamping beyond calibration, inversion, reversed calibration bounds, absent calibration, and a discovered vJoy range other than the common default.

```elixir
assert {:ok, 24_576} = Mapper.axis_value(768, calibration, false, {0, 32_768})
assert {:ok, 8_192} = Mapper.axis_value(768, calibration, true, {0, 32_768})
```

- [ ] **Step 2: Run mapper tests and verify failure**

Run: `mix test test/trenino/virtual_joystick/mapper_test.exs`

Expected: failure because `Mapper.axis_value/4` is undefined.

- [ ] **Step 3: Implement pure axis conversion**

Reuse `Trenino.Hardware.Calibration.Calculator` rather than duplicate normalization. Clamp, invert when requested, and scale with `round(min + normalized * (max - min))`. Return `:invalid_range` when `max <= min`.

- [ ] **Step 4: Write failing exclusivity tests**

Test both directions:

- Creating a vJoy mapping for an API-bound input returns `:destination_conflict` unless `replace?: true`, then deletes every enabled lever/button binding using that input across trains before inserting the mapping.
- Creating or updating a lever/button binding for a vJoy-mapped input returns `:destination_conflict` unless `replace?: true`, then deletes the vJoy mapping in the same transaction.
- Existing bindings on unrelated inputs remain unchanged.

- [ ] **Step 5: Centralize destination replacement in transactions**

Add private helpers in the two public contexts rather than querying from controllers. Extend `Train.bind_input/3`, `Train.create_button_binding/4`, and `Train.update_button_binding/3` with an options argument that defaults to `replace?: false`; retain their current arities as wrappers so existing call sites compile unchanged. On successful replacement, call the relevant controller reload function and `VirtualJoystick.Manager.reload_mappings/0` only when those processes are running.

- [ ] **Step 6: Run focused tests**

Run: `mix test test/trenino/virtual_joystick/mapper_test.exs test/trenino/virtual_joystick_test.exs test/trenino/train/button_controller_test.exs`

Expected: all pass and existing API behavior is unchanged for non-vJoy inputs.

- [ ] **Step 7: Commit**

```bash
git add lib/trenino/virtual_joystick/mapper.ex lib/trenino/virtual_joystick.ex lib/trenino/train.ex lib/trenino/train/lever_controller.ex lib/trenino/train/button_controller.ex test/trenino/virtual_joystick test/trenino/virtual_joystick_test.exs test/trenino/train/button_controller_test.exs
git commit -m "feat: route inputs to one exclusive destination"
```

### Task 3: Build the Native vJoy Feeder Sidecar

**Files:**
- Create: `tauri/virtual_joystick/Cargo.toml`
- Create: `tauri/virtual_joystick/src/main.rs`
- Create: `tauri/virtual_joystick/src/protocol.rs`
- Create: `tauri/virtual_joystick/src/vjoy.rs`
- Create: `tauri/virtual_joystick/tests/protocol_test.rs`
- Create: `lib/mix/tasks/virtual_joystick.ex`

**Interfaces:**
- Consumes: vJoy SDK `vJoyInterface.dll` at runtime on Windows.
- Produces: `virtual_joystick.exe serve` with protocol version 1 and fixed device index 1.

- [ ] **Step 1: Write failing Rust protocol tests**

Deserialize `hello`, `set_axis`, `set_button`, `reset`, and `shutdown`; reject device indexes other than 1, unknown axes, button 0/33, values outside the negotiated axis range, oversized input, and protocol versions other than 1. Assert serialized responses include `request_id` when the command supplies one.

- [ ] **Step 2: Run tests and verify failure**

Run: `cargo test --manifest-path tauri/virtual_joystick/Cargo.toml`

Expected: compilation failure because protocol types are absent.

- [ ] **Step 3: Implement protocol types and line framing**

Use tagged Serde enums:

```rust
#[serde(tag = "command", rename_all = "snake_case")]
enum Command {
    Hello { protocol: u16 },
    SetAxis { request_id: u64, device: u8, axis: Axis, value: i32 },
    SetButton { request_id: u64, device: u8, button: u8, pressed: bool },
    Reset { request_id: u64, device: u8 },
    Shutdown,
}
```

Limit stdin lines to 16 KiB. Write only one JSON response per stdout line and flush after every response. Route diagnostics through `eprintln!`.

- [ ] **Step 4: Implement a vJoy adapter boundary**

Define a `VJoy` trait for protocol tests and a Windows implementation that dynamically loads the bundled SDK DLL. Bind `vJoyEnabled`, `GetVJDStatus`, `AcquireVJD`, `RelinquishVJD`, `GetVJDAxisMin`, `GetVJDAxisMax`, and `UpdateVJD`. Maintain one complete report initialized with centered axes and released buttons. Reject `VJD_STAT_BUSY` and never call acquisition for a busy device.

On non-Windows targets, compile a stub that returns the structured `unsupported_platform` error so ordinary macOS/Linux development can still run protocol tests.

- [ ] **Step 5: Test complete-report preservation**

Use a fake `VJoy` implementation to set X, set button 4, then set Y; assert the third submitted report retains X and button 4. Test reset, graceful shutdown, device removal, malformed JSON recovery, and SDK error translation.

- [ ] **Step 6: Add the Mix build task**

Follow `lib/mix/tasks/keystroke.ex`: build release/debug, choose `.exe` on Windows, print the exact output path, and fail on a nonzero Cargo exit.

- [ ] **Step 7: Run Rust tests and formatting**

Run: `cargo fmt --manifest-path tauri/virtual_joystick/Cargo.toml --check && cargo test --manifest-path tauri/virtual_joystick/Cargo.toml`

Expected: all protocol tests pass on the development platform using the fake/stub adapter.

- [ ] **Step 8: Commit**

```bash
git add tauri/virtual_joystick lib/mix/tasks/virtual_joystick.ex
git commit -m "feat: add persistent vJoy feeder sidecar"
```

### Task 4: Add the Elixir Port Bridge

**Files:**
- Create: `lib/trenino/virtual_joystick/bridge.ex`
- Create: `lib/trenino/virtual_joystick/bridge/port_adapter.ex`
- Create: `test/support/fake_virtual_joystick.exs`
- Create: `test/trenino/virtual_joystick/bridge_test.exs`
- Modify: `test/test_helper.exs`
- Modify: `config/test.exs`

**Interfaces:**
- Consumes: protocol version 1 from Task 3.
- Produces: `Bridge.start_link/1`, `set_axis/3`, `set_button/3`, `reset/1`, `shutdown/1`, `status/1`, and bridge events sent to the owning Manager.

- [ ] **Step 1: Write failing bridge tests with an injected adapter**

Test executable discovery, handshake success/mismatch, command request IDs, acknowledgement correlation, one pending newest value per control, stderr isolation, malformed/oversized stdout, unexpected exit, reset, and shutdown. Configure a 100 ms test timeout and assert callers receive tagged errors rather than exiting.

- [ ] **Step 2: Run bridge tests and verify failure**

Run: `mix test test/trenino/virtual_joystick/bridge_test.exs`

Expected: compilation failure because `Bridge` is absent.

- [ ] **Step 3: Implement executable discovery and Port ownership**

Search `APP_PATH`, `priv/bin`, and both Cargo build directories, matching the `Keyboard` helper conventions. Open an Erlang Port in binary stream mode and implement newline extraction with an explicit 16 KiB accumulator, preserving JSON Lines exactly as the external contract. Monitor `:exit_status`.

Public calls return `:ok | {:error, reason}`; the GenServer never exposes the raw Port. Emit `{:virtual_joystick_bridge, event}` to the Manager for `ready`, `device_removed`, and process exit.

- [ ] **Step 4: Implement coalescing and timeout cleanup**

Track `next_request_id`, outstanding calls, and `pending_by_control`. When an update is outstanding for `{:axis, axis}` or `{:button, number}`, replace its pending successor. On acknowledgement, reply to the original caller and send the newest successor. Remove timed-out request entries so late acknowledgements are ignored.

- [ ] **Step 5: Run bridge tests**

Run: `mix test test/trenino/virtual_joystick/bridge_test.exs`

Expected: all pass without launching a real executable.

- [ ] **Step 6: Commit**

```bash
git add lib/trenino/virtual_joystick/bridge.ex lib/trenino/virtual_joystick/bridge test/support/fake_virtual_joystick.exs test/trenino/virtual_joystick/bridge_test.exs test/test_helper.exs config/test.exs
git commit -m "feat: manage vJoy feeder through an Erlang Port"
```

### Task 5: Implement Elevated Device Configuration

**Files:**
- Create: `lib/trenino/virtual_joystick/platform.ex`
- Create: `lib/trenino/virtual_joystick/configurator.ex`
- Create: `lib/trenino/virtual_joystick/configurator/system_adapter.ex`
- Create: `test/trenino/virtual_joystick/configurator_test.exs`
- Modify: `test/test_helper.exs`

**Interfaces:**
- Produces: `Platform.windows?/0`; `Configurator.status/0`; `create/0`; `delete/0`; `wait_for/2`.
- Status values: `:driver_missing`, `:device_missing`, `:compatible`, `:incompatible`, and `:busy`.

- [ ] **Step 1: Write failing configurator tests**

Test non-Windows short-circuiting, driver missing, fixed create arguments, fixed delete arguments, UAC cancellation mapping, nonzero process exits, arrival/removal polling, timeout, incompatible descriptor, and busy device. Assert hostile text in environment variables never appears in an executable argument.

- [ ] **Step 2: Run tests and verify failure**

Run: `mix test test/trenino/virtual_joystick/configurator_test.exs`

Expected: compilation failure because the Configurator is absent.

- [ ] **Step 3: Implement fixed elevated operations**

Resolve bundled `vJoyConfig.exe` from trusted application locations. Invoke PowerShell directly with an argument list and `Start-Process -FilePath <resolved path> -ArgumentList <fixed quoted arguments> -Verb RunAs -Wait -PassThru`. The only create descriptor is device 1, axes `x y z rx ry rz sl0 sl1`, 32 buttons, zero POVs, and no FFB. The only delete target is device 1.

Map Windows cancellation code `1223` to `{:error, :uac_cancelled}`. Validate the executable is a regular file inside the expected app/resource directory before elevation.

- [ ] **Step 4: Implement bounded enumeration verification**

Poll the injected system adapter every 100 ms for up to 10 seconds. `create/0` succeeds only after `:compatible`; `delete/0` succeeds only after `:device_missing`. Return `{:error, :timeout}` otherwise.

- [ ] **Step 5: Run configurator tests**

Run: `mix test test/trenino/virtual_joystick/configurator_test.exs`

Expected: all pass with no elevation or real driver access.

- [ ] **Step 6: Commit**

```bash
git add lib/trenino/virtual_joystick/platform.ex lib/trenino/virtual_joystick/configurator.ex lib/trenino/virtual_joystick/configurator test/trenino/virtual_joystick/configurator_test.exs test/test_helper.exs
git commit -m "feat: configure vJoy device with explicit elevation"
```

### Task 6: Build the Runtime Manager State Machine

**Files:**
- Create: `lib/trenino/virtual_joystick/manager.ex`
- Modify: `lib/trenino/virtual_joystick.ex`
- Modify: `lib/trenino/application.ex`
- Modify: `config/test.exs`
- Create: `test/trenino/virtual_joystick/manager_test.exs`

**Interfaces:**
- Consumes: context, Mapper, Bridge, Configurator, serial device events, and `ConfigurationManager` input broadcasts.
- Produces: `VirtualJoystick.status/0`, `subscribe/0`, `enable/0`, `disable/0`, `retry/0`, `remove_leftover/0`, and `reload_mappings/0`.

- [ ] **Step 1: Write the state-machine tests**

Cover `unsupported`, `off`, `enabling`, `active`, `disabling`, `needs_setup`, `needs_cleanup`, `degraded`, and `error`. Exercise every startup reconciliation pair from the spec, enable/disable success, concurrent command rejection, UAC cancellation, partial-create rollback offer, incompatible/busy device, and persisted state only after confirmed transitions.

- [ ] **Step 2: Run tests and verify failure**

Run: `mix test test/trenino/virtual_joystick/manager_test.exs`

Expected: compilation failure because `Manager` is absent.

- [ ] **Step 3: Implement startup and public state transitions**

Use a typed `%State{}` struct containing requested state, public status, mappings by `{port, pin}`, subscribed ports, last raw values, bridge pid, retry attempt, and timer reference. Publish `{:virtual_joystick_status_changed, status}` on `virtual_joystick` PubSub only when status changes.

Run create/delete work under `Trenino.TaskSupervisor` so the GenServer remains responsive. Tag task replies with a transition reference and ignore stale results.

- [ ] **Step 4: Implement input subscriptions and safe states**

Build the same `{port, pin}` lookup used by the existing controllers, preload calibration, and subscribe once per connected port. For axis updates call `Mapper.axis_value/4` using the range learned at bridge handshake. For buttons convert nonzero raw values to `true`. Cache last raw values even while off so activation can publish current state.

On hardware disconnect, send center/released values only for mappings sourced from that device. On graceful app shutdown while enabled, reset and stop the bridge without deleting device 1.

- [ ] **Step 5: Implement degraded recovery**

Retry bridge startup after 250 ms, 500 ms, 1 s, 2 s, and 4 s, then remain in `error`. Retry only while the requested state is enabled and Configurator still reports `:compatible`. Cancel retry timers on disable or successful startup.

- [ ] **Step 6: Add supervised startup with a test gate**

Add `virtual_joystick_manager_child/0` to `Application`, controlled by `config :trenino, :start_virtual_joystick_manager, false` in tests. Start it after `ConfigurationManager` and before the endpoint.

- [ ] **Step 7: Run manager and regression tests**

Run: `mix test test/trenino/virtual_joystick/manager_test.exs test/trenino/train/button_controller_test.exs test/trenino/hardware/configuration_manager_test.exs`

Expected: all pass.

- [ ] **Step 8: Commit**

```bash
git add lib/trenino/virtual_joystick/manager.ex lib/trenino/virtual_joystick.ex lib/trenino/application.ex config/test.exs test/trenino/virtual_joystick/manager_test.exs
git commit -m "feat: manage virtual joystick runtime lifecycle"
```

### Task 7: Add the Standalone Virtual Joystick UI

**Files:**
- Create: `lib/trenino_web/live/virtual_joystick_live.ex`
- Create: `lib/trenino_web/live/components/virtual_joystick_mapping_form.ex`
- Modify: `lib/trenino_web/router.ex`
- Modify: `lib/trenino_web/components/nav_components.ex`
- Create: `test/trenino_web/live/virtual_joystick_live_test.exs`

**Interfaces:**
- Consumes: public `Trenino.VirtualJoystick` APIs and status PubSub from Task 6.
- Produces: `/virtual-joystick` setup, mapping, toggle, retry, repair, and cleanup experience.

- [ ] **Step 1: Write failing LiveView tests**

Test navigation and page rendering; non-Windows unsupported state; all status labels/actions; grouped eight-axis and 32-button lists; create/edit/delete mapping; live input preview; duplicate target errors; API destination replacement confirmation; toggle disabled during transitions; UAC explanation; cancellation; Retry; and Remove leftover device.

Use stable selectors such as:

```elixir
assert has_element?(view, "[data-testid='virtual-joystick-status']", "Off")
assert has_element?(view, "button[data-testid='virtual-joystick-toggle']")
```

- [ ] **Step 2: Run UI tests and verify failure**

Run: `mix test test/trenino_web/live/virtual_joystick_live_test.exs`

Expected: route/module failure.

- [ ] **Step 3: Implement the route, navigation, and status card**

Add the LiveView under the default consent/nav hooks. Subscribe on connected mount. Derive copy and permitted buttons entirely from Manager status. Confirm enable/disable in a modal that states Windows will request administrator permission.

- [ ] **Step 4: Implement mapping management**

List all configured hardware inputs with device and input names. Filter analog inputs for axes and button inputs for buttons. Show live normalized input movement without exposing raw vJoy ranges. When `put_mapping/3` returns `:destination_conflict`, show the existing destination and require a second submit carrying `replace=true`.

- [ ] **Step 5: Implement accessible transition and error behavior**

Disable controls during transitions, expose `aria-live="polite"` status text, never rely on color alone, and keep focus in confirmation/error dialogs. Use the exact plain-language states from the design.

- [ ] **Step 6: Run UI and router tests**

Run: `mix test test/trenino_web/live/virtual_joystick_live_test.exs`

Expected: all pass.

- [ ] **Step 7: Commit**

```bash
git add lib/trenino_web/live/virtual_joystick_live.ex lib/trenino_web/live/components/virtual_joystick_mapping_form.ex lib/trenino_web/router.ex lib/trenino_web/components/nav_components.ex test/trenino_web/live/virtual_joystick_live_test.exs
git commit -m "feat: add virtual joystick setup UI"
```

### Task 8: Expose Mapping Management Through MCP

**Files:**
- Create: `lib/trenino/mcp/tools/virtual_joystick_tools.ex`
- Modify: `lib/trenino/mcp/tool_registry.ex`
- Create: `test/trenino/mcp/tools/virtual_joystick_tools_test.exs`
- Modify: `test/trenino/mcp/tool_registry_test.exs`
- Modify: `test/trenino/mcp/server_test.exs`
- Modify: `test/trenino_web/controllers/mcp/mcp_controller_test.exs`

**Interfaces:**
- Consumes: the same context operations used by LiveView.
- Produces: list/status, create/update mapping, delete mapping, enable, disable, retry, and cleanup tools without bypassing destination exclusivity.

- [ ] **Step 1: Write failing MCP tool tests**

Test schemas and responses for status/list, axis mapping, button mapping, validation errors, destination conflict, explicit replacement, delete, and unsupported platform. Test that enable/disable reports transition acceptance and does not block an MCP request for UAC completion.

- [ ] **Step 2: Run tests and verify failure**

Run: `mix test test/trenino/mcp/tools/virtual_joystick_tools_test.exs`

Expected: module/tool registration failure.

- [ ] **Step 3: Implement tools using only the public context**

Use explicit JSON schemas: axis enum, integer button bounds 1–32, device index enum `[1]`, Boolean replacement flag, and integer input ID. Return structured `{status, reason}` data; do not expose executable paths or accept arbitrary commands.

- [ ] **Step 4: Register tools and update all three count assertions**

Add the module to `@tool_modules`. Update exact expected tool counts in the registry, server, and MCP controller tests as required by `CLAUDE.md`.

- [ ] **Step 5: Run MCP tests**

Run: `mix test test/trenino/mcp/tools/virtual_joystick_tools_test.exs test/trenino/mcp/tool_registry_test.exs test/trenino/mcp/server_test.exs test/trenino_web/controllers/mcp/mcp_controller_test.exs`

Expected: all pass.

- [ ] **Step 6: Commit**

```bash
git add lib/trenino/mcp/tools/virtual_joystick_tools.ex lib/trenino/mcp/tool_registry.ex test/trenino/mcp/tools/virtual_joystick_tools_test.exs test/trenino/mcp/tool_registry_test.exs test/trenino/mcp/server_test.exs test/trenino_web/controllers/mcp/mcp_controller_test.exs
git commit -m "feat: expose virtual joystick MCP tools"
```

### Task 9: Bundle vJoy and the Sidecar in Windows Builds

**Files:**
- Create: `scripts/download-vjoy.ps1`
- Create: `tauri/src-tauri/resources/vjoy.sha256`
- Create: `tauri/src-tauri/resources/THIRD_PARTY_NOTICES.md`
- Modify: `scripts/build-desktop.sh`
- Modify: `tauri/src-tauri/tauri.conf.json`
- Modify: `tauri/src-tauri/windows/installer-hooks.nsh`
- Modify: `.github/workflows/ci.yml`
- Modify: `tauri/src-tauri/Cargo.toml`

**Interfaces:**
- Consumes: a reviewed BrunnerInnovation signed release URL and its independently calculated SHA-256.
- Produces: Windows installer resources `vJoySetup.exe`, `vJoyConfig.exe`, `vJoyInterface.dll`, license text, and `virtual_joystick-x86_64-pc-windows-msvc.exe`.

- [ ] **Step 1: Add a checksum-verifying download script test mode**

Implement PowerShell parameters `-Version`, `-Url`, `-ExpectedSha256`, and `-Destination`. Download to a temporary file, calculate `Get-FileHash -Algorithm SHA256`, compare case-insensitively, and move into resources only on success. A `-VerifyOnly` path validates an existing artifact for CI. Any mismatch exits nonzero without replacing an existing verified file.

- [ ] **Step 2: Run checksum negative and positive checks**

Run on Windows CI with a small fixture artifact first. Expected: incorrect checksum fails; correct checksum succeeds. Then record the reviewed vJoy release URL/version/checksum in the script invocation and `vjoy.sha256`.

- [ ] **Step 3: Extend the Windows build**

Build `tauri/virtual_joystick` in release mode, copy its target-suffixed external binary, stage the verified SDK DLL/configurator/installer, and include them in Tauri `externalBin`/`resources`. Do not change macOS or Linux artifacts beyond compiling the unsupported stub when their existing build scripts require every external binary.

- [ ] **Step 4: Extend NSIS install/uninstall hooks**

Detect the compatible driver before installing. Install the pinned signed driver silently, record `VJoyInstalledByTrenino=1` in Trenino's registry key only when this installer added it, and delete the installer payload afterward. Clear the installer-created default device so first launch exposes no joystick.

On uninstall, remove device 1 if it matches Trenino's descriptor. Remove the driver automatically only when the ownership marker is 1 and no other vJoy devices exist; otherwise leave shared state and explain it in the uninstall log.

- [ ] **Step 5: Add Windows packaging CI**

Add a Windows job that verifies the checksum, builds both Rust crates, builds the Burrito/Tauri package, lists the expected resources, and runs the native protocol tests. Keep real driver installation in a separately tagged integration job because ordinary hosted runners must not mutate drivers.

- [ ] **Step 6: Verify the package on a Windows VM**

Install Trenino, confirm no controller exists while mode is off, enable and accept UAC, confirm one 8-axis/32-button controller, disable and confirm removal, then uninstall and confirm ownership-aware driver cleanup. Record the commands and observed versions in the release checklist or CI job log.

- [ ] **Step 7: Commit**

```bash
git add scripts/download-vjoy.ps1 scripts/build-desktop.sh tauri/src-tauri/resources tauri/src-tauri/tauri.conf.json tauri/src-tauri/windows/installer-hooks.nsh tauri/src-tauri/Cargo.toml .github/workflows/ci.yml
git commit -m "build: bundle signed vJoy runtime on Windows"
```

### Task 10: Documentation and Full Verification

**Files:**
- Modify: `README.md`
- Modify: `docs/getting-started.md`
- Modify: `docs/hardware-setup.md`
- Modify: `docs/architecture.md`
- Modify: `docs/development.md`
- Modify: `CHANGELOG.md`

**Interfaces:**
- Consumes: all shipped behavior from Tasks 1–9.
- Produces: user setup/recovery guidance, contributor architecture notes, and final verification evidence.

- [ ] **Step 1: Write user documentation**

Document Windows-only support, bundled-driver installation, the UAC prompt on each toggle, the eight axes/32 buttons, exclusive destinations, mapping steps, Windows Game Controllers verification, busy-device recovery, UAC cancellation, and leftover-device cleanup. State clearly that closing Trenino while enabled leaves the device enumerated but safely released.

- [ ] **Step 2: Update developer documentation**

Add the Manager/Bridge/Configurator boundaries, JSON Lines protocol, sidecar build command, vJoy checksum update procedure, Windows integration-test tag, and safe shared-driver uninstall rules.

- [ ] **Step 3: Run formatting and focused native checks**

Run:

```bash
mix format --check-formatted
cargo fmt --manifest-path tauri/virtual_joystick/Cargo.toml --check
cargo test --manifest-path tauri/virtual_joystick/Cargo.toml
```

Expected: all commands exit 0.

- [ ] **Step 4: Run the full project verification**

Run: `mix precommit`

Expected: compilation with warnings as errors, strict Credo, and the full ExUnit suite all pass.

- [ ] **Step 5: Perform Windows end-to-end verification**

On the dedicated Windows VM, verify create/enumerate/feed/reset/delete; physical lever extremes and midpoint; inversion; maintained and momentary buttons; hardware disconnect safe state; bridge termination/restart; app restart while enabled; UAC cancellation; another feeder owning device 1; and uninstall with both Trenino-owned and pre-existing vJoy installations.

- [ ] **Step 6: Commit documentation**

```bash
git add README.md docs/getting-started.md docs/hardware-setup.md docs/architecture.md docs/development.md CHANGELOG.md
git commit -m "docs: document Windows virtual joystick mode"
```

- [ ] **Step 7: Record final evidence**

Run `git status --short`, `git log --oneline -10`, and retain the successful `mix precommit`, Cargo, packaging, and Windows integration outputs for review. The work is complete only when the worktree contains no unintended changes and every required verification has current passing evidence.
