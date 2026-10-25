# Virtual joystick feature and native feeder contract

Baseline: `188f35e4108733358730e92ebd98f1912af5173a`, reviewed 2026-10-25. This describes code behavior, including limitations; it does not report a live driver test. See [UI](user-interface.md), [hardware calibration](hardware.md), [train destinations](train-profiles-and-controls.md), and [installation](desktop-and-operations.md).

## Purpose and boundaries

A Windows maker can expose saved hardware inputs as a single removable DirectInput joystick, without connecting to Train Sim World. The fixed descriptor is device **1**, eight axes (`x`, `y`, `z`, `rx`, `ry`, `rz`, `slider_1`, `slider_2`), 32 buttons, no POV and no force feedback. It is not one joystick per Arduino, a configurable descriptor, or a train profile. Mappings are application-wide and may combine several boards.

The cooperating pieces are:

| Piece | Responsibility |
|---|---|
| `VirtualJoystick` context | Singleton preferences, mapping transactions, exclusive destination replacement |
| `Manager` | Requested versus actual state; connected-port mapping; subscriptions; recovery |
| `Configurator` | Fixed create/delete operations and confirmation polling |
| `SystemAdapter` | Trusted helper lookup, native Windows status probe, elevation, ownership marker |
| `Mapper` | Hardware calibration to discovered integer axis range |
| `Bridge` | Persistent JSON-lines process, correlation, buffering, per-control coalescing |
| Rust `Session` | Validate commands, acquire vJoy, maintain complete report, acknowledge writes |
| Rust `NativeVJoy` | Dynamically load the selected DLL and call its ABI |

Sources: [context](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/virtual_joystick.ex), [manager](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/virtual_joystick/manager.ex), [bridge](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/virtual_joystick/bridge.ex), [Rust protocol](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/tauri/virtual_joystick/src/protocol.rs).

## Persistent configuration and mapping rules

`virtual_joystick_configurations` contains only row ID `1`. Reading configuration creates it if missing, with `enabled=false`, `device_index=1`. The database and changeset enforce index 1. `enabled` is **last confirmed mode**, not the pending UI toggle. There is no persisted runtime status or retry counter.

Each `virtual_joystick_mappings` row has an input FK, index 1, target type `axis|button`, axis or button number, and `inverted=false`. Exactly one target field must be populated. Buttons range 1–32; axes use the fixed enum. Analog inputs must target an axis; button inputs must target a button. Mapping creation itself does not require calibration; an uncalibrated axis is skipped at runtime. The UI can impose additional readiness requirements.

Database uniqueness enforces one mapping per hardware input and one input per axis/button destination. The context updates an existing input's mapping rather than inserting a second row. Caller-supplied `input_id` attributes are discarded in favor of the explicit function argument. Listing orders by device, target type, axis, button and preloads input, device, and calibration.

An enabled simulator lever or button binding conflicts with a virtual joystick mapping, across **all** train profiles. With `replace?=false`, return `:destination_conflict`. With `replace?=true`, delete all enabled conflicting simulator bindings, leave disabled/unrelated bindings alone, and insert/update the new destination in a SQLite `mode: :immediate` transaction. An invalid replacement rolls back deletions. Reverse replacement occurs in the Train context. Reload notifications are explicit and conditional on running controllers; plain context CRUD does not universally refresh the manager, so UI/MCP callers also invoke reloads.

Sources: [mapping schema](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/virtual_joystick/mapping.ex), [configuration schema](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/virtual_joystick/configuration.ex), [database checks](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/priv/repo/migrations/20260801000000_create_virtual_joystick_tables.exs), [destination tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/virtual_joystick_test.exs).

## State and lifecycle

All platforms load saved mappings and subscribe to serial updates. Non-Windows then reports `unsupported` and rejects enable/disable; no device configuration is attempted.

Windows startup reconciles confirmed preference against the native probe:

| Saved enabled | Probe | Result |
|---|---|---|
| false | device_missing | off |
| false | compatible | needs_cleanup, reason leftover_device |
| true | device_missing | needs_setup |
| true | compatible | degraded while feeder starts, then active on ready |
| either | incompatible, busy, driver_missing | error with probe reason |

`enable` returns `:ok` after starting an asynchronous configuration task, enters `enabling`, and rejects enable/disable/retry/cleanup during a transition. A reference/action pair makes stale configuration task replies harmless. A successful create starts the bridge. Only a valid ready event for device 1 with integer increasing bounds publishes current input values and saves `enabled=true`. `enable` while already active is idempotent.

UAC cancellation during enable returns to `off` when previously off, or `needs_setup` when the saved preference was enabled. Other creation failure becomes `needs_cleanup` if a compatible device exists, otherwise `needs_setup`. A bridge start failure or explicit bridge error during enable becomes `needs_cleanup` and does not persist activation. A pre-ready exit/device_removed event during first enable only clears the bridge fields when requested? is still false; it can leave `enabling` pending indefinitely instead of taking that error path.

`disable` cancels retries, asks the bridge to reset and shut down, enters `disabling`, then deletes the device asynchronously. Only confirmed deletion changes persisted `enabled` to false. If deletion fails, `needs_cleanup` remains. If UAC is cancelled and a compatible device still exists with a true saved preference, the feeder restarts. Cleanup operates only from `needs_cleanup`; it does not invent a changed confirmed preference. `retry` handles `needs_setup`, `degraded`, and `error`; `repair` from error merely probes/reconciles, rather than reinstalling a driver.

On feeder exit or device removal, a saved enabled preference causes `degraded` and bounded retries at 250, 500, 1,000, 2,000 and 4,000 ms. Each retry requires a compatible probe; exhaustion or an incompatible probe becomes `error`. A successful ready event resets the retry counter. Disabling cancels pending retries. On application termination the bridge resets/shuts down, but the configured vJoy device and enabled preference remain for the next launch.

`virtual_joystick` PubSub emits `{:virtual_joystick_status_changed, status}` when the status changes, and `{:virtual_joystick_status_details_changed, %{status: status, reason: reason}}` when status or reason changes. A repeated identical pair emits neither. Status details are also available synchronously.

Evidence: [manager implementation](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/virtual_joystick/manager.ex), [lifecycle tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/virtual_joystick/manager_test.exs).

## Routing raw hardware values

The manager lists connected serial devices with a non-null device configuration ID, builds `config_id -> port`, then resolves each mapping through its input's saved device. Runtime keys are `{port, input.pin}`. Duplicate connected config IDs collapse in this map. It subscribes once per seen port to configuration input values, primes values from `get_input_values(port)`, and retains a cache even while mode is off. Old subscriptions/cache entries are not explicitly removed.

While active, new analog values use hardware `Calculator.normalize(raw, calibration) / Calculator.total_travel(calibration)`. Apply mapping inversion as `1-normalized`, then `round(axis_min + normalized*(axis_max-axis_min))`. Hardware normalization already handles calibration direction, rollover and clamping; joystick inversion is an additional layer. Missing/zero-travel calibration or a non-increasing range returns an error and does not write an axis. Example range 0–32,768 and normalized 0.75 produces 24,576, or 8,192 when inverted. Actual bounds come from hello; 0–32,768 is only a test example.

Buttons write `pressed = raw != 0`; the mapping inversion field has no effect on this branch. On ready, cached mapped values are applied; missing values use a centered axis or released button. A disconnected port sends safe values using the **old** mapping set for that port, leaving other ports' controls alone. Elixir safe center uses rounding; Rust reset uses integer division, so an odd sum can differ by one unit.

Reload rebuilds maps/subscriptions but does not explicitly clear the old native destination for a mapping that was deleted or moved, nor publish every cached value immediately. The manager ignores per-write bridge errors, so an acknowledged command failure does not itself move mode out of `active`. These are current implementation boundaries relevant to a rewrite.

Sources: [mapper](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/virtual_joystick/mapper.ex), [mapping examples](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/virtual_joystick/mapper_test.exs), [manager input tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/virtual_joystick/manager_test.exs).

## Configuration and Windows helper selection

Create invokes only `vJoyConfig.exe 1 -a x y z rx ry rz sl0 sl1 -b 32 -p 0`; delete invokes `-d 1`. A compatible create is already satisfied; a missing delete clears the ownership marker idempotently. Busy, incompatible and missing-driver states are refused. Create/delete run elevated through fixed native PowerShell. Exit 1223 is `uac_cancelled`; other nonzero exits remain `{:process_exit, code}`. After the command exits successfully, poll every at most 100 ms against a 10,000 ms monotonic deadline. Probe time counts toward that deadline. Ownership is recorded/removed only after confirmation; marker failures remain visible errors even if the device operation succeeded.

The adapter uses `C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe` and `C:\Windows\System32\reg.exe`. Status loads `vJoyInterface.dll` through a C# P/Invoke probe and validates all eight required HID usages, no extra listed axes, exactly 32 buttons, zero discrete/continuous POV, no FFB, and device availability. A malformed/failed/late probe is classified `driver_missing`; this state does not prove physical absence.

Lookup tries absolute `APP_PATH/resources` then application-bundled `priv/bin`, `priv/resources`, and `resources`. Helpers must be regular files contained below their declared root; every component from trusted anchor is checked for symlink/reparse escapes. No PATH/current-directory lookup is allowed for elevated helpers. Runtime ownership is HKCU `Software\Trenino\VJoyDevice1CreatedByTrenino` DWORD 1, separate from the installer's HKLM driver-ownership marker.

Sources: [configurator](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/virtual_joystick/configurator.ex), [system adapter](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/virtual_joystick/configurator/system_adapter.ex), [trust and deadline tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/virtual_joystick/configurator_test.exs), [installed helper tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/virtual_joystick/installed_helpers_test.exs).

## JSON-lines bridge protocol, version 1

UTF-8 JSON objects separated by LF over stdin/stdout; Rust accepts a trailing CR. Diagnostics go to stderr. Maximum line content is 16 KiB, with oversized input drained through its newline before processing the next command. A response is flushed after each input command.

| Command | Fields | Success |
|---|---|---|
| hello | `protocol:1` | `ready`, protocol, device 1, axis_min, axis_max |
| set_axis | request_id u64, device 1, axis enum, value i32 within discovered bounds | `applied`, request_id |
| set_button | request_id u64, device 1, button 1–32, pressed boolean | `applied`, request_id |
| reset | request_id u64, device 1 | `applied`, request_id |
| shutdown | no other required fields | `stopped`, then loop exits |

```json
{"command":"hello","protocol":1}
{"event":"ready","protocol":1,"device":1,"axis_min":0,"axis_max":32767}
{"command":"set_axis","request_id":1,"device":1,"axis":"slider_2","value":1234}
{"event":"applied","request_id":1}
```

Hello checks vJoy enabled/status, rejects busy without acquisition, acquires free/owned device, reads the X axis range, initializes a complete centered report in memory, and replies ready. If range lookup fails after acquisition, relinquish. Repeat hello on an acquired session returns its range without reacquiring. Hello alone does not submit the initial report. Each mutation modifies the retained report and submits the complete eight-axis/32-button state, preserving other controls. A failed update does not undo the in-memory mutation. Shutdown relinquishes once; no explicit Drop/EOF reset is implemented.

Responses also include `device_busy` (device), `device_removed` (device and optional request_id), `invalid_command` (code, message, optional request_id), or `error` (code, message, optional request_id). Codes include `invalid_command`, `input_too_large`, `not_ready`, `vjoy_disabled`, `unsupported_platform`, `sdk_error`. Invalid JSON/UTF-8/type/device/axis/button/range/protocol becomes a structured failure. Reset/button before hello returns not_ready; axis before hello is rejected during parsing. Invalid JSON can only retain request_id if that field can be parsed independently.

Elixir sends hello on process open; only protocol 1 ready is accepted. It gives each mutation a monotonically increasing request ID and device from handshake. One request is in flight per axis/button key; one latest pending write replaces earlier pending writes, whose callers receive `:superseded`. Acknowledgement or timeout clears that key and dispatches its pending write. Reset has no coalescing key. Default request timeout is 5,000 ms; safe call timeout adds 1,000 ms. Process exit fails all outstanding/pending callers. Stderr is ignored by the bridge.

**Known gaps:** no handshake timer is scheduled, so a silent feeder can leave enabling pending; pre-ready exit/removal on initial enable can also leave that transition pending as described above. Elixir ignores an uncorrelated `device_busy` event and only forwards certain startup errors; the Rust event exists but is not a complete manager recovery path. Generic bridge `protocol_error` notifications are not handled specially by the manager. Non-Windows Elixir feeder arguments are just `serve`, but the Rust CLI always requires `serve --vjoy-interface <absolute DLL>`; normal mode short-circuits before using that path.

Evidence: [bridge](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/virtual_joystick/bridge.ex), [port adapter](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/virtual_joystick/bridge/port_adapter.ex), [Rust parser/session](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/tauri/virtual_joystick/src/protocol.rs), [CLI](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/tauri/virtual_joystick/src/lib.rs), [protocol tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/tauri/virtual_joystick/tests/protocol_test.rs), [bridge tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/virtual_joystick/bridge_test.exs).

## Native ABI and packaging

The CLI accepts exactly four argv entries including program name; DLL path must be absolute and end with `vJoyInterface.dll` case-insensitively. Invalid invocation exits 2; DLL initialization or IO failure exits 1. It dynamically loads that exact path with `libloading`, resolving `vJoyEnabled`, `GetVJDStatus`, `AcquireVJD`, `RelinquishVJD`, `GetVJDAxisMin`, `GetVJDAxisMax`, `UpdateVJD`. Device status integer 0 is owned, 1 free, 2 busy, other values missing.

The pinned SDK uses a 124-byte C `JOYSTICK_POSITION_V3` layout, with compile-time size/offset checks and Windows tests. The native report is zero-initialized; X/Y/Z and rotations use their matching fields, sliders use `w_slider` and `w_dial`; 32 buttons become bits 0–31 of the main button word. Unused fields are zero. Native `UpdateVJD` false produces `sdk_error`, not the trait's `DeviceRemoved` variant; removal tests use a fake adapter. Non-Windows native methods return unsupported-platform.

Only the Windows Tauri overlay bundles this feeder and vJoy resources. The generic build script still builds a non-Windows stub, but base Tauri configuration does not package it. See [desktop operations](desktop-and-operations.md).

Evidence: [native ABI](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/tauri/virtual_joystick/src/vjoy.rs), [entry point](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/tauri/virtual_joystick/src/main.rs), [Windows overlay](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/tauri/src-tauri/tauri.windows.conf.json).
