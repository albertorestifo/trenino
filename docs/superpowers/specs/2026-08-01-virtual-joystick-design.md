# Windows Virtual Joystick Design

## Summary

Trenino will expose selected hardware levers and buttons as one generic Windows DirectInput joystick. The first release uses vJoy device 1 with eight conventional axes and 32 buttons. The mappings are standalone: they do not depend on Train Sim World detection or a train profile.

Each physical input has one exclusive destination. It can drive either an existing simulator/API behavior (including keystrokes and sequences) or a virtual joystick control, never both. Moving an input between destinations requires explicit confirmation and removes the old binding.

The user controls virtual joystick availability with a global UI toggle. When the mode is disabled, vJoy device 1 does not exist in Windows. Enabling creates it through an elevated operation; disabling safely releases its state and deletes it through another elevated operation. The vJoy driver remains installed until Trenino is uninstalled.

## Goals

- Present custom Trenino hardware to Windows games as a generic DirectInput joystick.
- Support one virtual device with eight axes and 32 buttons.
- Reuse existing hardware calibration for analog inputs.
- Mirror button pressed and released state directly.
- Keep mappings independent from train detection and train profiles.
- Make simulator/API and virtual joystick destinations mutually exclusive per physical input.
- Bundle the signed vJoy driver and required runtime files in the Windows installer.
- Create or delete the virtual device when the user enables or disables the mode.
- Preserve a clean path to multiple virtual devices without exposing that feature in the first release.

## Non-goals

- Xbox/XInput or PlayStation controller emulation.
- Linux or macOS virtual input support.
- Multiple simultaneous virtual devices in the UI or runtime.
- POV hats, force feedback, output reports, toggle buttons, or button pulses.
- Automatic activation based on a running game or detected train.
- A privileged Windows service to avoid UAC prompts.

## Technology choice

The initial backend is the signed Windows 10/11 build from the [BrunnerInnovation vJoy fork](https://github.com/BrunnerInnovation/vJoy). It provides generic DirectInput axes and buttons and retains vJoy's feeder SDK. The exact release artifact and SHA-256 checksum will be pinned in the Windows build configuration rather than downloading an unversioned latest release.

Alternatives were rejected for the initial release:

- ViGEmBus exposes fixed Xbox 360 or DualShock 4 devices rather than a generic joystick, and the project is retired.
- A custom Microsoft Virtual HID Framework driver would give full control but requires Trenino to develop, sign, distribute, and maintain a kernel-mode driver.
- A native Elixir NIF would reduce call overhead but place native vJoy faults inside the BEAM process.
- Owning vJoy in Tauri would introduce a reverse IPC channel and make the backend dependent on the UI shell.

## Architecture

The existing hardware and calibration pipelines remain authoritative. A new input-routing decision sends each incoming hardware event to exactly one output controller.

```text
Physical input
    |
    v
Serial protocol and ConfigurationManager
    |
    v
Exclusive destination lookup
    |-------------------------------|
    v                               v
Existing simulator/API route        VirtualJoystick.Manager
                                    |
                                    v
                              persistent bridge process
                                    |
                                    v
                            vJoy device 1 / DirectInput
```

The new `Trenino.VirtualJoystick` boundary contains three responsibilities:

- `Manager` owns the state machine, input subscriptions, current mappings, cached hardware state, bridge lifecycle, and create/start or stop/delete transitions.
- `Bridge` owns a persistent OS process and translates validated domain updates into protocol messages.
- `Configurator` detects the driver and device, performs fixed elevated create/delete operations, and verifies Windows device arrival or removal.

The Windows-only native executable is a separate Rust sidecar, following the repository's existing helper-binary packaging pattern. A process boundary contains SDK or driver failures and makes a future backend replaceable. The bridge interface includes a device index even though the first release validates that it is always 1.

The Manager is supervised with the other runtime controllers. On non-Windows platforms its public status is `unsupported`, it does not start a native process, and the UI hides or disables the feature with a clear platform explanation.

## Persistence and constraints

### Virtual joystick configuration

A singleton configuration stores:

- `enabled`: the user's requested persistent mode state.
- `device_index`: required to be 1 in the first release.

The runtime state is not inferred from this row alone. The Manager also verifies Windows enumeration and the bridge state before reporting the mode as active.

### Input mappings

Each standalone mapping references one existing hardware input and device index 1. It has one of these shapes:

- Axis: a target from `x`, `y`, `z`, `rx`, `ry`, `rz`, `slider_1`, or `slider_2`, plus an `inverted` flag.
- Button: a target number from 1 through 32.

Database constraints ensure that a physical input has at most one virtual joystick mapping and that a virtual axis or button has at most one source. Changesets additionally enforce that calibrated analog inputs map only to axes and button inputs map only to buttons.

Existing simulator destinations are stored in other tables, so cross-destination exclusivity cannot be expressed as one database constraint. All create/update entry points go through one domain operation that runs in a transaction. When moving an input to a different destination, the operation requires an explicit replacement flag, removes the old destination, and creates the new one atomically. LiveView and MCP entry points must call this operation rather than writing destination tables directly.

Mappings can be created and edited while virtual joystick mode is disabled.

## Axis and button behavior

Analog values pass through the existing hardware calibration, producing a normalized value from 0.0 to 1.0. Optional inversion transforms it to `1.0 - value`. Elixir clamps the result and scales it to the axis range reported by the installed vJoy device. The native bridge accepts only a validated integer within that discovered range.

On activation, the Manager publishes the most recently observed state of every mapped, connected input. An axis without a known current value is centered until its first hardware update. A button without a known current value is released.

Button inputs mirror physical state directly:

- Physical press sends button down.
- Physical release sends button up.
- A maintained switch remains down while the hardware reports it active.

Input updates are coalesced by control: if newer values arrive while a report is awaiting acknowledgement, only the newest pending value for that control needs to be sent. Values identical to the last applied value are skipped.

## Native bridge protocol

`virtual_joystick.exe` runs persistently and communicates using UTF-8 JSON Lines over stdin and stdout. Diagnostic logs go to stderr so they cannot corrupt protocol framing. Every message includes a protocol version established during the initial handshake.

Representative commands are:

```json
{"command":"hello","protocol":1}
{"command":"set_axis","device":1,"axis":"x","value":16384}
{"command":"set_button","device":1,"button":4,"pressed":true}
{"command":"reset","device":1}
{"command":"shutdown"}
```

The bridge returns structured responses and events such as `ready`, `applied`, `device_busy`, `device_removed`, `invalid_command`, and `error`. Commands that mutate state carry a monotonically increasing request identifier so acknowledgements can be correlated and stale replies ignored.

The bridge acquires device 1 and maintains one complete in-memory report containing all eight axes and 32 buttons. A control update changes that report and submits the complete report to vJoy, preventing an update to one control from resetting another. It never creates, deletes, or steals a device owned by another feeder.

The Elixir bridge wrapper owns the OS process through an Erlang Port, monitors termination, enforces maximum line length, rejects malformed or unexpected messages, and closes the port on shutdown.

## Enable and disable lifecycle

The driver is installed with Trenino, but the DirectInput device follows the UI toggle literally.

### Enable

1. The user turns on Virtual joystick mode.
2. Trenino explains that Windows will request administrator permission.
3. The Configurator runs a fixed elevated command that creates vJoy device 1 with exactly eight axes, 32 buttons, no POV hats, and no force feedback.
4. Trenino waits with a finite timeout for device arrival and validates its capabilities.
5. The Bridge starts, performs its protocol handshake, and acquires device 1.
6. The Manager sends current mapped hardware state, using safe defaults for unknown values.
7. Only after every step succeeds does it persist `enabled: true` and report `active`.

If creation succeeds but later startup fails, the UI reports the partial failure and offers an elevated rollback that deletes the device. It does not claim the mode is off until Windows confirms removal.

### Disable

1. The user turns off Virtual joystick mode.
2. The Manager releases all buttons, centers all axes, and requests a final complete report.
3. The Bridge relinquishes device 1 and exits.
4. Trenino requests elevation and deletes device 1, then refreshes vJoy.
5. Trenino waits with a finite timeout for device removal.
6. Only after removal is confirmed does it persist `enabled: false` and report `off`.

Declining UAC or any failed transition preserves the last confirmed persistent state. During a transition, the toggle is disabled to prevent concurrent operations.

Closing Trenino does not implicitly disable the mode. On graceful application shutdown, the Manager sends the safe state, relinquishes device 1, and stops the bridge, but leaves the device enumerated because the persisted request remains enabled. The next launch reacquires it. The user must turn the mode off to delete the device.

### Crash and startup reconciliation

A process or application crash can leave device 1 enumerated. At startup, the Manager compares the persisted requested state with the actual driver/device state:

- Requested on and compatible device present: start the bridge and restore current state.
- Requested on and device absent: show `needs_setup` and let the user retry the elevated enable flow; do not raise UAC automatically at startup.
- Requested off and device absent: remain off.
- Requested off and device present: show `needs_cleanup` and offer **Remove leftover device**; do not raise UAC automatically.
- Device present with incompatible capabilities or owned by another feeder: report the exact conflict and do not alter it automatically.

## Runtime states and failure handling

The public state is one of:

- `unsupported`
- `off`
- `enabling`
- `active`
- `disabling`
- `needs_setup`
- `needs_cleanup`
- `degraded`
- `error`

The UI derives labels and permitted actions from this state rather than maintaining an independent Boolean.

Failure rules are:

- UAC cancellation leaves the previous state in effect and explains that no change was made.
- Another feeder's ownership is never overridden; the UI offers Retry after the user closes it.
- Hardware disconnection releases buttons and centers axes sourced from that hardware while leaving other mappings active.
- Unexpected bridge termination changes the state to `degraded`. The Manager uses bounded exponential backoff to restart only when the device still exists and remains compatible.
- API-bound and keystroke-bound inputs remain operational during every virtual joystick failure.
- Device create/delete commands contain no user-controlled executable paths, command names, or shell fragments.

## User interface

The standalone Virtual joystick screen contains:

- A status card and global enable/disable toggle.
- A concise explanation of the UAC prompt before each transition.
- Driver/device diagnostics and context-specific Repair, Retry, or Remove leftover device actions.
- One mapping list grouped into axes and buttons.
- An add/edit flow that selects a hardware input, chooses its joystick control, and previews live input movement.
- Clear conflict messages for an already-used physical input or target control.
- A replacement confirmation when an input currently has a simulator/API destination.

The initial screen presents the conventional labels X, Y, Z, Rx, Ry, Rz, Slider 1, Slider 2 and Button 1 through Button 32. It does not expose device selection, descriptors, POV configuration, force feedback, or raw vJoy ranges.

The UI follows Trenino's established progressive-disclosure approach: users see readiness and mappings first; driver details appear only for setup or recovery.

## Packaging and distribution

The Windows build pipeline downloads a pinned signed vJoy release, verifies a committed SHA-256 checksum, and stages the installer and required SDK runtime DLLs. The Rust bridge is built for `x86_64-pc-windows-msvc` and bundled as a Tauri external binary.

The NSIS installer:

1. Detects the exact compatible vJoy driver version.
2. Installs or upgrades the bundled driver silently when necessary.
3. Removes any default device configuration created by installation so Trenino initially exposes no DirectInput device.
4. Leaves driver repair available to the installed application.

The uninstaller first removes the Trenino-managed device if present and then removes the bundled driver. If another vJoy device or dependent installation is detected, it does not remove shared driver state without an explicit user choice.

Installation records whether Trenino installed the driver. Uninstallation removes the driver automatically only when Trenino installed it and no non-Trenino vJoy devices remain; a compatible pre-existing installation is treated as shared system state.

The repository records the source URL, version, checksum, and license text. The installed application's third-party notices include vJoy attribution. Release automation fails if the downloaded checksum differs.

## Testing

### Pure and database tests

- Calibration, clamping, inversion, and axis-range scaling.
- Direct button state mapping.
- Input-type validation and all target bounds.
- Duplicate source and duplicate target rejection.
- Atomic replacement between simulator/API and virtual joystick destinations.
- Device index 1 validation.

### Manager tests

- Every valid state transition and invalid concurrent transition.
- UAC cancellation, enumeration timeout, incompatible capabilities, and busy device.
- Partial creation followed by rollback.
- Disable failure that leaves the device present.
- Startup reconciliation for every persisted/actual state combination.
- Hardware disconnect safe state.
- Bridge crash, bounded restart, and retry exhaustion.

### Bridge protocol tests

- Handshake and protocol-version mismatch.
- Complete report preservation across individual control updates.
- Request correlation, coalescing, and stale acknowledgements.
- Malformed JSON, oversized lines, unknown events, stderr output, and process termination.
- Reset and graceful shutdown ordering.

### UI and integration tests

- LiveView rendering and actions for every public state.
- Mapping creation, editing, replacement confirmation, and conflict errors.
- Toggle progress, UAC cancellation, cleanup, repair, and retry behavior.
- Windows integration on a dedicated vJoy-capable runner: install, create, enumerate, feed axes/buttons, reset, delete, and uninstall.
- Manual release verification in Windows Game Controllers and at least one DirectInput simulator.

Non-Windows CI uses fake Configurator and Bridge implementations. Tests must never invoke elevation or mutate real driver state unless explicitly tagged as Windows integration tests.

## Research references

- [BrunnerInnovation vJoy fork](https://github.com/BrunnerInnovation/vJoy) — signed Windows 10/11 binaries and vJoy SDK source.
- [njz3 vJoy fork](https://github.com/njz3/vJoy) — maintained build lineage and vJoy configuration documentation.
- [Microsoft Virtual HID Framework](https://learn.microsoft.com/en-us/windows-hardware/drivers/hid/virtual-hid-framework--vhf-) — evaluated custom-driver alternative.
- [ViGEmBus](https://github.com/nefarius/ViGEmBus) — evaluated and rejected fixed-controller alternative; repository retired in 2023.
- [Linux input userspace API](https://kernel.org/doc/html/latest/input/input_uapi.html) and [Apple DriverKit](https://developer.apple.com/documentation/DriverKit) — future platform research only.
