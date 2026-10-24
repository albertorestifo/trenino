# Trenino Rust rewrite: coordinated migration proposal

**Status:** Implementation authorized and in progress on `codex/rust-rewrite`. Foundation, pure hardware, the vJoy adapter, supported legacy database migration, controls primitives, the UI shell/bridge, and the bounded AppServices/Tauri startup integration have passed their scoped reviews. Hardware runtime and firmware catalog fixes are under review; hardware domain repositories are being implemented. The merged Windows packaging/updater baseline is incorporated. The legacy application remains the default until runtime, UI, migration and packaging parity are verified. Unimplemented interfaces below remain design targets.

**Desktop checkpoint:** The opt-in `rust-ui` feature builds the static frontend without BEAM, with and without `desktop-updater`. It uses isolated trial data, validates full-schema admission, owns writable databases across process/path aliases, and preserves verified-download → acknowledged Rust shutdown → installation ordering. Settings and read-only configuration/train commands are present. This checkpoint does not establish running WebView IPC, complete editors/controllers, real hardware cleanup, native installer/update behavior, or Linux/macOS execution; those remain explicit integration gates.

**User decisions:** Retain Tauri and the existing UI experience. Use a small TypeScript frontend with all application logic in Rust. Have subagents examine and plan the functionality migrations, including whether vJoy can be replaced directly in Rust.

**Implementation authorization:** User approved branch-based implementation with cheap concurrent coders, Astra track supervisors and independent correctness/adversarial reviews. Use the `vjoy` crate; retain the driver. Fixed device 1 is not a requirement: select a device explicitly, preserve ownership isolation and migrate existing configurations.

**Distribution baseline:** PR 169 (`b32443901c5f63e5c7f6b6cb5224eb4ae1b0b91f`) is merged into this branch. Stable Windows desktop updates use signed Tauri updater artifacts and NSIS metadata, not MSIX; updater and Windows publisher signatures remain separate. Preserve native Help → Check for Updates, the updater overlay/configuration, public-key continuity, release signing checks, `vJoyInstall.dll` packaging, and absolute trusted resource discovery. The legacy application release checker is distribution-aware and must not create a duplicate stable desktop banner; firmware release notifications remain independent. See the platform, UI, and joystick contracts below.

## Recommendation

Keep Tauri as the desktop host, bundle a static TypeScript frontend, and replace the Phoenix/Elixir backend with in-process Rust services. Keep current screens, styling and workflows; port the HEEx/LiveView implementation rather than trying to run it without Elixir. Use the same domain services from desktop commands and the compatibility HTTP/MCP server.

Retain the signed vJoy driver initially, as the user explicitly accepted after asking about existing Rust replacements. Its feeder is already Rust: replace the Elixir manager and integration layer, reuse its native adapter, and consider running the feeder as a headless mode of the same executable to preserve fault isolation without another packaged executable. Rust wrappers such as `vjoy` still require an installed driver; other virtual HID products exist but are not verified drop-in Rust replacements for this descriptor. A new Rust virtual HID driver is a separate project with signing and driver lifecycle obligations; it is not needed for the application rewrite.

## Reading order and responsibility map

| Plan | Functionality covered | Planning owner |
|---|---|---|
| [Platform](2026-10-24-rust-platform.md) | Database migration, settings/consent, runtime ownership, MCP/HTTP, diagnostics, app updates, packaging/CI | Main coordinator |
| [Hardware](2026-10-24-rust-hardware.md) | Serial protocol/discovery, configuration, hardware calibration, matrices/I2C, firmware downloads/flashing/history | Hardware subagent |
| [Controls](2026-10-24-rust-controls.md) | Simulator API, train identification, lever mapping/calibration, buttons/sequences/keyboard, outputs/displays, Lua | Controls subagent |
| [Joystick](2026-10-24-rust-joystick.md) | Feeder/driver distinction, native integration, lifecycle/ownership, safe defaults, recovery | Joystick subagent |
| [UI](2026-10-24-rust-ui.md) | Every current screen and wizard, styling, form/session state, command/event adapters, parity validation | UI subagent |

## Target structure

```text
Cargo.toml                         shared Rust workspace
crates/trenino-core/src/            pure rules, protocols, typed values and transport DTOs
crates/trenino-runtime/src/         owned background services, SQLite, hardware and integrations
tauri/src-tauri/src/               Tauri commands, lifecycle, worker-mode entry point
tauri/ui/                          small TypeScript frontend; framework is a proposal
```

Do not split every subsystem into an independent crate. Module boundaries are enough until compile-time/platform isolation justifies another crate. The existing vJoy Rust library may stay separate as a Windows adapter. `trenino-core` must not depend on Tauri, database connections or live hardware.

The frontend owns transient presentation state: navigation, focus, open panels and draft text. Rust owns validation, persisted state, device sessions, calibration, simulator mapping, script execution, routing conflicts and all effects. UI display formatting may stay in TypeScript; numeric mapping/calibration rules cannot.

The UI uses typed commands for changes, snapshots for recovery and subscriptions for progress. Fast telemetry may be coalesced for display; physical button transitions and sequence actions must retain order. Refreshing or closing a screen does not implicitly restart hardware services.

## Alternatives considered

1. **Chosen direction:** Tauri plus TypeScript UI and Rust services. Removes BEAM/Phoenix/Burrito and local HTTP dependence for UI while retaining web styling and WebView prerequisites.
2. Rust/WASM frontend inside Tauri. Technically possible, but the user explicitly chose the smaller TypeScript frontend.
3. Native Windows widgets/full native UI. Discussed previously; superseded by retaining Tauri/UI.

## Cross-plan contracts that take precedence

- One Rust runtime owns physical devices and application state; one dedicated SQLite worker owns DB connections/transactions. `rusqlite` is the proposed storage choice. No independent agent introduces a second ORM/pool without review.
- Preserve database IDs internally as signed 64-bit integers. New Tauri DTOs serialize IDs as strings; compatibility HTTP/MCP retains existing payload shapes. Domain-specific ID wrappers may wrap the shared representation.
- Each long-running action has an operation/session identity; completion checks current generation before applying effects. Cancellation is explicit and observable. Unsubscribing a UI listener is not cancellation; persistence checkpoints already committed by a wizard survive closing it. Preserve the actual autosave/save points of each existing screen.
- Snapshot/event envelopes use a runtime epoch and topic-scoped revision. Epoch change or event gaps trigger a fresh snapshot. Firmware `ConfigId`, SQLite entity IDs and connection/session identities are separate types.
- UI/MCP/HTTP mutations share validation and domain transaction entry points. Input routing replacement across simulator and joystick destinations is atomic and requires explicit conflict replacement.
- Successful commits publish change notifications; services reconcile committed state. Handle a crash between commit and notification through startup/snapshot reconciliation, not speculative frontend state.
- Track desired routing revision separately from active routing revision. After a successful commit, failed release of the previous destination leaves the input suspended/degraded and the new route inactive. Reconcile with bounded retries/fresh generation; surface saved-but-not-active status rather than rolling back a newer edit or claiming success.
- One input router resolves firmware config/pin/generation to persisted device/input IDs, then fans out the same ordered source events to all consumers. Configuration replacement/removal invalidates that resolution before any further dispatch.
- One resource arbiter coordinates hardware/simulator calibration and flashing. Calibration suspends ordinary actuation for the leased resource; flashing cancels affected sessions and emits source loss/neutralization before closing serial. Routes resume only from fresh samples.
- Serial flashing owns an exclusive lease across serial bootloader port changes. UI navigation cannot accidentally release that lease.
- Keep the firmware/wire protocol stable. Capture the existing custom COBS behavior in byte-for-byte fixtures before replacing its implementation.
- Keep Lua API compatibility unless a documented correction is approved. Deadline enforcement must cover compilation/top-level execution and callbacks; dropping an async future is insufficient to terminate a blocking interpreter.
- Worker restart is bounded and visible. Startup/shutdown and device loss must release keyboard/button states and reset joystick outputs as specified by the joystick plan.
- Shutdown first stops admission and cancels all producers of effects, then neutralizes/releases outputs while adapters are alive, then closes hardware/network and finally DB. A cancelled producer cannot enqueue a fresh effect after release.
- Keep existing external MCP/HTTP compatibility. The UI does not require the listener, and an occupied integration port does not prevent app startup.
- Stable Tauri desktop uses the native signed updater; preserve its user-confirmed download → runtime quiescence acknowledgement → install ordering. Rust shutdown must stop admission, block installation during active firmware flashing, neutralize/release joystick and keyboard outputs, settle workers/serial ownership, and flush/close SQLite before acknowledging. Download or signature failure leaves services running; quiescence failure blocks installation. Firmware notifications stay separate from app updates. Nightly/development and direct/server distributions retain their own policy; do not duplicate the stable desktop app banner.
- Trust packaged configurator resources only through verified absolute installed paths. `vJoyConfig.exe` must load its packaged `vJoyInstall.dll` without PATH or CWD lookup. Continue explicit selected vJoy IDs 1..16 and ownership checks; upstream packaging does not restore fixed device 1.
- Keep supported Windows/Linux packages and macOS source-build portability. Do not interpret the Windows-only vJoy feature as authorization to drop Linux.

If subsystem signatures differ, the milestone-zero contract work reconciles them into one concrete API before implementation begins. Signatures in individual documents illustrate ownership and responsibilities; they are not independent competing public APIs.

## Delivery sequence

| Milestone | Deliverable | Exit evidence |
|---|---|---|
| 0. Characterization and contracts | Golden fixtures from current code/tests, shared DTOs, concurrency policy, DB support floor, frontend choice | Inventory covers all screens/services/tools; proposed interfaces reconciled |
| 1. Desktop foundation | Rust startup, SQLite upgrades, settings/consent, one read-only profile/device screen | Existing DB loads without data loss; app starts without BEAM |
| 2. Hardware and simulator slice | Connect device, display input, calibrate, map one lever, drive simulator, recover disconnect | Real hardware/TSW scenario plus protocol and retry tests |
| 3. Routing and controls | Train detection, buttons/sequences/keyboard, complete levers, vJoy integration | Ordered events, exclusive mappings and safe disconnect/shutdown verified |
| 4. Remaining feature parity | Firmware wizard, displays/outputs, Lua, MCP/API, remaining screens | Existing behavior fixtures plus end-to-end workflow coverage |
| 5. Distribution cutover | Windows/Linux packaging and upgrade path; remove obsolete stack | Clean-machine install/upgrade/rollback and hardware checks |

Parallel work is possible after milestone 0: hardware, controls, UI, integration adapters and joystick can proceed against fake implementations of the agreed interfaces. Do not run both old and new implementations against the same live hardware, joystick or writable profile.

## Highest-risk acceptance scenarios

1. **Existing data:** v0.7.4/current database upgrades preserve calibration, bindings, identifiers, scripts, consent and driver ownership. Newer schema and invalid legacy data fail without mutation; backups include WAL data.
2. **Device loss:** disconnect during lever motion, held button, display output or joystick use; safe output state and eventual recovery without stale replay.
3. **Flashing:** bootloader changes port, cancellation/UAC denial, avrdude failure and close during upload; exclusive port ownership remains correct and subprocesses are reaped.
4. **Concurrent callers:** UI and MCP replace mappings or edit a profile together; transaction rules remain consistent and stale completions do not override current state.
5. **Scripts and shutdown:** infinite loops/top-level code, effect limits, scheduled callbacks after profile change; no permanently hung interpreter or stuck key/joystick state.
6. **UI parity:** all current routes/wizards, validation retention, keyboard navigation, modal focus and both themes; slow or disconnected services cannot freeze the window.
7. **Distribution:** no Elixir/Burrito artifacts required, packaged resources resolve under non-ASCII paths, Windows driver ownership respected, Linux package has no Windows-only resources.

## Explicit limits and remaining decisions

- This is a substantial rewrite, not a thin backend substitution: LiveView rendering and event handling must also be ported.
- TypeScript, HTML/CSS and a frontend build remain by user choice. WebView2/WebKit, SQLite, firmware flashing utilities and vJoy still exist; “Rust rewrite” does not mean zero native dependencies.
- The default proposal preserves desktop behavior and external APIs, not a standalone hosted browser version. Confirm separately if browser-only use must remain a product feature.
- Library recommendations are based on current primary documentation; pin versions and validate OS compatibility in milestone 0. No implementation/test results are claimed by these planning documents.
- Behavior corrections discovered while reading current code must be labelled separately from parity. Do not silently reimplement a misleading comment or preserve unsafe behavior merely because it exists today.
- No elapsed-time estimate is credible until the first real hardware slice and database migration prototype establish the integration cost. Track acceptance milestones rather than predicted lines of rewritten code.

## Suggested first implementation slice

After review, implement one profile/device screen with consent and database loading, serial input display, hardware calibration, one lever mapping and simulator output. This tests the selected UI bridge, state ownership, persistence, serial protocol and simulator client together before the rest of the rewrite is committed to those interfaces.
