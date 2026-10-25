# Rewrite acceptance contracts and known behavior decisions

This is a technology-neutral checklist derived from the reviewed application's behavior. It is not an implementation plan and does not evaluate the code on `codex/rust-rewrite`. Use the linked feature documents and [user stories](user-stories.md) for full detail and source evidence.

## Contracts that cross feature boundaries

| Contract | Observable scenario | Expected result and boundary |
|---|---|---|
| Durable identity | Move a panel to another serial port, then reopen a train | Saved configuration identity resolves resource bindings independently of OS port; duplicate config_id ambiguity remains an explicit limitation |
| Offline configuration | Edit a train/display/profile before game/hardware connect | Persistent definitions can be edited where current UI permits; runtime execution waits for required connection/selection |
| Configuration acknowledgment | Send full configuration, then receive matching stored/error | ConfigurationManager correlates pending apply with matching configuration acknowledgment. The configuration editor listens globally and does not filter all apply-result broadcasts by device/port, so an unrelated operation can affect its displayed status |
| Calibration layers | Use one physical lever for two trains and joystick mode | Hardware direction/rollover calibration is reused; train-specific notch/simulator ranges and joystick inversion remain separate |
| Active profile ownership | Change from train A to B while input moves | Train controllers replace active bindings/scripts/subscriptions; hardware configuration and global joystick mappings are not deleted |
| Ambiguous train identifiers | Two profiles have prefixes matching same class | No arbitrary winning train; report multiple matches and deactivate automatic profile selection |
| Destination exclusivity | Map an API-bound input to joystick | Conflict unless replacement requested; successful replacement deletes relevant enabled old bindings atomically; invalid new record retains old destinations |
| Matrix identity | Bind a matrix cell, resize the matrix | Virtual pin namespace is deterministic; destructive recreate/resize can delete old input rows and dependent bindings; document this before preserving it |
| Input disconnect | One of two boards disappears | vJoy centers/releases only missing-port controls. Train lever/button controllers rebuild lookups but do not universally cancel pending writes/repeats/sequences or release held keys; preserve or explicitly change that difference |
| Output write suppression | Repeated equal simulator value/format result | Controllers avoid unnecessary unchanged hardware writes; boolean comparison and segment encoding retain specified semantics |
| Script lifecycle | Edit/toggle/reload a script | VM state/timers/subscriptions reset according to runner reload path; HTTP/UI and MCP do not currently trigger reload identically |
| Firmware port ownership | Flash while serial service knows port | Pause/release connection with correlation token, prevent normal discovery racing upload, reacquire/rediscover after completion/failure/cancel |
| Joystick confirmation | Create device but feeder never becomes ready | Do not persist enabled merely because create command launched; current missing handshake deadline is a gap, not proof of success |
| Verified app update | Download fails signature check | Backend continues; shutdown/install only after verified download and user confirmation |
| Shared driver ownership | Uninstall with another vJoy device/user | Preserve unknown/shared state; marker + descriptor + version/probe + user choice govern removal |
| Consent boundary | Disable error reporting then produce error | Sentry callback drops event; basic app access remains; UI consent is not HTTP/MCP auth |

## Representative complete acceptance journeys

### J-01 — From unflashed board to a simulator throttle

Install desktop package; make consent choice; select supported firmware environment/release; flash with port handoff and history; discover board identity; create hardware configuration; add analog input; apply and await ack; calibrate physical travel; connect simulator; create profile with one or more class-prefix identifiers; create lever element; discover/analyze simulator control; map physical notch intervals; bind input; activate detected train; move lever; verify expected simulator InputValue and handling of disconnect/reconnect.

This crosses [firmware](firmware.md), [hardware](hardware.md), [serial protocol](serial-protocol.md), [simulator](simulator.md), [train controls](train-profiles-and-controls.md), [UI](user-interface.md), and [persistence](data-model.md). Do not collapse board calibration, game lever analysis and hardware-to-notch mapping into one unspecified calibration step.

### J-02 — A reusable physical panel across train variants

Create two aliases for equivalent simulator class prefixes on one train profile; create button, lever, LED and display bindings; drive either variant; switch to an unmatched train and then back; observe grace/clearing behavior; ensure restored controllers use the correct saved resources; create overlapping alias on another profile and verify ambiguity rather than undocumented precedence.

See [detection state machine](simulator.md), [binding runtime](train-profiles-and-controls.md), [train stories](train-user-stories.md).

### J-03 — Hardware inputs as a standalone joystick

With simulator stopped, map a calibrated analog input and matrix button; explicitly replace any enabled simulator bindings; enable fixed device 1 through UAC/configurator/feeder confirmation; verify axis scaling and button state; disconnect one board; retry a failed feeder; disable and confirm device removal. Restart with saved enabled but missing device, or saved disabled plus leftover device, and expose appropriate setup/cleanup paths.

See [joystick](virtual-joystick.md), [VJ stories](platform-user-stories.md), [UI](user-interface.md).

### J-04 — Automation with visible errors

Create a reusable command sequence and a Lua script; bind button press/release sequences; give the script simulator endpoint triggers and exercise manual/scheduled callbacks; drive values, schedule callbacks and observe logs; introduce a syntax/runtime error or execution timeout; reload; ensure one script failure does not silently claim hardware/simulator side effects were applied. Exercise HTTP/UI and MCP authoring separately because their reload/error paths differ.

See [Lua and sequences](scripting-and-sequences.md), [API/MCP](api-and-mcp.md), [editor](user-interface.md).

### J-05 — Update and reinstall while preserving configuration

Save profiles and mappings; check stable update, defer once, accept once; verify download/signature before shutdown; confirm sidecar exit before installation; restart and migrate; inspect saved configuration and re-created runtime state. Exercise cancelled UAC and failures separately. Uninstall under shared vJoy scenarios; check retention contracts rather than assuming ownership from device absence.

See [desktop lifecycle](desktop-and-operations.md), [migration behavior](data-model.md), [platform stories](platform-user-stories.md).

## Existing gaps requiring deliberate compatibility decisions

These are current source observations, not requested fixes. Preserve them only if compatibility requires it; improving them changes observable behavior and deserves an explicit acceptance decision.

| Area | Current observation | Consequence for a rewrite |
|---|---|---|
| Historical docs | Old tool counts, wire layouts, sensor ranges, schema fields and promised validation drift from source | Prefer this snapshot's code contracts over copied old prose |
| Serial Configure decoder | HT16K33 encoding exists without a matching decode clause | Decide whether host decode parity is required versus improving symmetric tooling |
| Hardware config locking | Pending operations key by config_id rather than a complete per-port operation lock | Concurrency and duplicate identity handling need explicit design |
| Calibration session supervision | Hardware Session and NotchMappingSession comments do not override default permanent GenServer child specs; legacy LeverSession explicitly uses temporary restart | Normal completion/cancel lifecycle needs explicit restart policy |
| Legacy calibration helpers | Some older lever paths do not populate modern simulator ranges; helper ID confusion exists | Do not assume all public calibration paths produce runtime-ready bindings |
| Momentary buttons | Validated repeat_interval_ms is not used by immediate repeat loop | Current timing is not a reliable configurable contract |
| Output runtime | No hysteresis and no simulator connection subscription | Avoid inventing smoothing/reconnect promises while specifying parity |
| Lua reads | api.get is a stub returning unavailable rather than a synchronous simulator read | Examples must use event values/other implemented APIs |
| Lua execution | The 200 ms callback limit does not cover top-level compile/eval or later host effects | Compilation, host-operation deadlines and resource limits require explicit choices |
| Late completion | Scheduled Lua events and sequence completion lack generation tokens | Stale notifications may affect a new runtime instance with the same record ID |
| UI wizard paths | Some manual-skip and auto-detect result branches do not complete the advertised setup | Acceptance must check persisted usable state, not only changed wizard step |
| API consistency | MCP schema advertisement, validation, controller reloads and errors vary by tool | Decide whether new API preserves quirks or standardizes with a versioned contract |
| Joystick feeder | No hello timeout; uncorrelated busy event not handled; some write errors ignored | Readiness/recovery cannot be inferred from mode labels alone |
| Joystick remap | Old destination not explicitly reset on mapping deletion/move | Decide how stale target state should be cleared |
| Desktop readiness | A queryable firmware_releases table is the readiness condition | A stronger service/migration ownership check would be a changed contract |
| App updates | User told to finish flashing/control, but updater does not enforce an interlock | Preserve guidance versus add a real quiescence protocol deliberately |
| Migration rollback | Several migrations refuse or cannot restore historical data | Upgrade/downgrade and import expectations must be defined explicitly |

The exact evidence, assumptions and edge cases are in each feature reference; these summaries must not be interpreted as a runtime bug reproduction report.

## Verification layers for a future implementation

Start with value/serialization contracts (wire layouts, calibration arithmetic, notch interpolation, comparator truth tables, display glyphs, request/response JSON). Then verify state machines using controlled adapters (timeouts, stale replies, concurrent transitions, disconnects, retries, cancellation). Next verify persisted migrations/transactions and every user-story journey. Finally exercise real boards, a running supported simulator and a disposable Windows environment for signed driver/installer/DirectInput behavior. Keep physical integration evidence separate from fake-adapter tests and documentation integrity checks.
