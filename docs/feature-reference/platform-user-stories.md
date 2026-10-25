# Platform and virtual joystick user stories

These stories describe the reviewed implementation at `188f35e4108733358730e92ebd98f1912af5173a`. Acceptance criteria are source-derived contracts, not a claim that manual acceptance testing was performed. Read [desktop and operations](desktop-and-operations.md) and [virtual joystick](virtual-joystick.md) for exact fields, events, algorithms and limitations. Other story collections: [hardware/firmware](hardware-user-stories.md), [train/simulator](train-user-stories.md), [UI/API](interface-user-stories.md).

<a id="plat-001"></a>

## PLAT-001 — Launch a self-contained desktop app

As a maker, I want to launch Trenino without installing Elixir or opening a terminal, so I can configure my rig.

- Preconditions: platform package installed; bundled backend available; local port 4000 usable.
- Flow: open launcher; view splash; backend starts with no-halt, production config and data migrations; readiness probe succeeds; main window opens.
- Acceptance: splash precedes main window; main window opens at localhost:4000 only after a successful health response; minimum dimensions 800×600; saved data uses the platform data directory.
- Failure: process-spawn error aborts setup; readiness exhaustion displays restart instruction and exits; port ownership and backend restart are not verified features.
- Evidence: [launcher](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/tauri/src-tauri/src/lib.rs), [health](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino_web/controllers/health_controller.ex), [health tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino_web/controllers/health_controller_test.exs).

<a id="plat-002"></a>

## PLAT-002 — Choose error-reporting consent

As a maker, I want to choose whether to send errors, so my preference persists without blocking normal use.

- Preconditions: app_settings has no error_reporting value.
- Flow: default LiveView redirects to consent; choose enabled or disabled; persist choice; return to app; later change in settings.
- Acceptance: either explicit choice enables normal UI access; absent/disabled preference drops Sentry events; enabled allows them only when DSN configured; changing one setting does not overwrite the simulator URL/key.
- Failure: handlers pattern-match successful persistence rather than rendering a save-error branch, so a failed save can crash; malformed stored consent is not enabled, although a raw row can bypass first-use prompting. The gate is a UI flow, not API authorization.
- Evidence: [settings](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/settings.ex), [consent gate](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino_web/live/consent_gate_hook.ex), [tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/settings_test.exs).

<a id="plat-003"></a>

## PLAT-003 — Use discovered or manual simulator credentials

As a simulator user, I want an automatically found key with manual override, so different installations can connect.

- Preconditions: supported game key file, or a supplied URL/key.
- Flow: use saved override if present; otherwise inspect TSW7 then TSW6 file on Windows; edit settings and reconnect when required.
- Acceptance: newer file takes precedence; file text trimmed; manual key stored unchanged by the context; missing file permits older-game fallback; default URL localhost:31270.
- Failure: missing USERPROFILE/non-Windows/read error are distinguishable; non-missing error stops fallback; settings persistence does not itself prove successful authentication.
- Evidence: [key lookup](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/settings/simulator.ex), [file tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/settings/simulator_test.exs), [connection behavior](simulator.md).

<a id="plat-004"></a>

## PLAT-004 — Retain configuration across restarts and upgrades

As a maker, I want hardware, train and automation settings to persist, so installation updates preserve my work.

- Preconditions: writable data directory/database or DATABASE_PATH override.
- Flow: save configuration; close; reopen; migrations upgrade existing data before normal startup.
- Acceptance: SQLite is durable storage; transient caches/status/sessions are reconstructed; train identifiers migrate to child rows with trimming; invalid legacy collisions fail instead of silently merging profiles.
- Failure: missing permissions or failed migration prevents readiness; irreversible migrations cannot promise downgrade; no app backup/export UI exists.
- Evidence: [runtime config](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/config/runtime.exs), [migrations](data-model.md), [identifier migration tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/repo/migrations/create_train_identifiers_test.exs).

<a id="plat-005"></a>

## PLAT-005 — Install a stable update without replacing a running backend

As an installed stable user, I want a verified update to install after the backend stops, so the executable is not replaced while running.

- Preconditions: updater-enabled build; backend not already known exited; stable feed reachable.
- Flow: Help → Check for Updates; confirm; download and verify; request backend shutdown; confirm sidecar exit; install; restart.
- Acceptance: duplicate menu checks suppressed; Later causes no download/shutdown/install; bad signature leaves backend running; failed shutdown prevents install; install failure is an error, not success.
- Failure: backend exit timeout 15 seconds after shutdown request; errors offer retry/reopen; there is no automatic flashing/control interlock.
- Evidence: [updater](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/tauri/src-tauri/src/updater.rs), [ordering unit tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/tauri/src-tauri/src/update_flow.rs).

<a id="plat-006"></a>

## PLAT-006 — Discover new versions in a browser/direct build

As a direct-distribution user, I want a newer-version notice, so I know when to obtain an installer.

- Preconditions: version checker enabled; GitHub release available.
- Flow: startup/periodic/manual check; compare latest semver; show notice; open release page or dismiss.
- Acceptance: startup delay 5 seconds; default period 24 hours; concurrent check ignored; dismissal clears in-memory notice; native-updater distribution disables duplicate notice service.
- Failure: failed check retains previous available-version state and clears checking; dismissal is not persistent suppression.
- Evidence: [checker](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/app_version/update_checker.ex), [distribution tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/ci/desktop_distribution_test.exs).

<a id="plat-007"></a>

## PLAT-007 — Close the app and release runtime resources

As a maker, I want closing the app to stop background control processes, so they do not remain orphaned.

- Preconditions: desktop backend is running.
- Flow: exit launcher; POST shutdown; server responds before System.stop; supervised workers terminate; joystick resets and feeder shuts down.
- Acceptance: failed HTTP shutdown falls back to child kill; normal joystick termination does not delete persistent vJoy device; ordinary exit and updater-confirmed exit use distinct waits.
- Failure: success of normal shutdown request is not followed by a complete process-exit confirmation; force termination cannot guarantee every cleanup callback runs.
- Evidence: [launcher exit](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/tauri/src-tauri/src/lib.rs), [manager termination test](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/virtual_joystick/manager_test.exs).

<a id="plat-008"></a>

## PLAT-008 — Install/uninstall alongside shared vJoy consumers

As a Windows user, I want Trenino to preserve shared driver state, so other applications keep their devices.

- Preconditions: use NSIS installer for lifecycle hooks.
- Flow: installer probes existing driver; installs pinned signed runtime only under eligible missing/owned cases; records ownership; uninstall checks marker and descriptor before removing its device; offers shared driver removal only when eligible.
- Acceptance: incompatible unowned drivers retained with warning; marker recorded only after successful install/create; silent uninstall retains shared driver; interactive removal defaults No; remaining devices block driver removal.
- Failure: unverified probe/version/signature retains state or aborts the appropriate install path; MSI does not provide these hooks.
- Evidence: [hooks](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/tauri/src-tauri/windows/installer-hooks.nsh), [hook tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/ci/installer_hooks_test.exs).

<a id="vj-001"></a>

## VJ-001 — Enable one joystick without running the game

As a maker, I want my hardware exposed as a Windows joystick, so I can bind it in any compatible game.

- Preconditions: Windows; compatible installed driver; device 1 missing or compatible.
- Flow: enable; approve UAC if creation needed; wait for fixed descriptor; launch feeder; hello returns valid range; persist enabled and show active.
- Acceptance: eight axes/32 buttons only; independent of simulator connection/active train; saved enabled remains false until ready; concurrent transitions rejected.
- Failure: cancel leaves mode off; incompatible/busy driver refused; post-create bridge start/error offers cleanup; silent hello and pre-ready exit/removal during first enable can remain pending indefinitely.
- Evidence: [manager](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/virtual_joystick/manager.ex), [manager tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/virtual_joystick/manager_test.exs).

<a id="vj-002"></a>

## VJ-002 — Map a calibrated lever to an axis

As a maker, I want calibrated endpoints and optional inversion to drive a chosen axis, so its full physical travel works in the game.

- Preconditions: analog input saved, calibrated with positive travel; free axis target.
- Flow: choose one of eight axes; save mapping; reload manager; move lever while active.
- Acceptance: target unique; correct hardware-to-driver scaling using actual hello bounds; clamp/direction/rollover from hardware calibration; optional extra inversion; other controls preserved by complete native report.
- Failure: invalid target/range rejected; uncalibrated values skipped; deleting/moving mapping currently does not explicitly reset old native target.
- Evidence: [mapper tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/virtual_joystick/mapper_test.exs), [context tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/virtual_joystick_test.exs), [Rust report tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/tauri/virtual_joystick/tests/protocol_test.rs).

<a id="vj-003"></a>

## VJ-003 — Map a button or matrix cell to a joystick button

As a maker, I want a physical button represented as a joystick button, so applications can bind it without TSW APIs.

- Preconditions: saved button input, including matrix-backed button; target 1–32 free.
- Flow: select target, save/reload, press and release.
- Acceptance: nonzero raw is pressed; zero released; input and target uniqueness enforced; runtime resolves virtual matrix pins through normal input path.
- Failure: analog-to-button/type mismatch rejected; mapping inversion is not applied to buttons.
- Evidence: [mapping schema](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/virtual_joystick/mapping.ex), [manager button tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/virtual_joystick/manager_test.exs).

<a id="vj-004"></a>

## VJ-004 — Switch an input destination with explicit replacement

As a maker, I want to replace simulator bindings with a joystick destination (or vice versa), so an input does not drive both paths accidentally.

- Preconditions: input has an enabled binding in the other destination system.
- Flow: first save reports destination conflict; choose replacement; validate new mapping; atomically delete conflicting enabled destinations; save; reload affected runtime controllers.
- Acceptance: invalid replacement retains prior settings; unrelated and disabled bindings retained; all enabled simulator bindings for that input removed on successful joystick replacement; reverse operation removes joystick mapping.
- Failure: duplicate target still fails and rolls back; disabling joystick does not delete mappings or restore old simulator bindings.
- Evidence: [transaction tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/virtual_joystick_test.exs), [train context](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/train.ex).

<a id="vj-005"></a>

## VJ-005 — Disconnect and reconnect hardware while driving

As a maker, I want disconnected controls to return to safe values, so pressed buttons do not remain held.

- Preconditions: mode active, mappings resolve to connected board ports.
- Flow: disconnect one board; manager compares connected port sets; center its mapped axes/release its buttons; retain other board controls; reconnect and resume input updates.
- Acceptance: safe writes only for disconnected port; initial cached state sent after feeder ready; raw values cached while off for later activation.
- Failure: mappings use config_id identity and duplicate IDs collapse; retained raw cache can outlive connection; disconnect does not remove persisted mappings.
- Evidence: [disconnect test](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/virtual_joystick/manager_test.exs), [serial identity](serial-protocol.md).

<a id="vj-006"></a>

## VJ-006 — Recover a failed feeder without unbounded retries

As a maker, I want visible recovery state and retry actions, so a process failure is understandable.

- Preconditions: previously confirmed enabled.
- Flow: feeder exit/removal → degraded; compatible device gets bounded backoff; hello succeeds → active; exhaustion → error; user retries or repairs.
- Acceptance: retry delays 250/500/1000/2000/4000 ms; saved enabled preserved; disable cancels retry; stale configuration replies ignored; repair only rechecks state.
- Failure: incompatible/busy/missing driver becomes error; individual command errors do not currently change manager status; device_busy hello event is not fully handled by Elixir.
- Evidence: [recovery tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/virtual_joystick/manager_test.exs), [bridge behavior](virtual-joystick.md).

<a id="vj-007"></a>

## VJ-007 — Disable or clean up a leftover joystick

As a maker, I want to remove the configured joystick, so applications stop seeing it when unused.

- Preconditions: mode active/error, or off preference plus compatible leftover device.
- Flow: disable resets/shuts down feeder before elevated deletion; confirm device missing; persist false. Leftover state offers remove_leftover; missing enabled device offers explicit setup retry.
- Acceptance: cancellation does not claim disabled; compatible device can resume feeder after cancelled disable; cleanup is available only in needs_cleanup; preferences change only after confirmation.
- Failure: deletion/ownership-marker error leaves cleanup state; a descriptor mismatch is not overwritten.
- Evidence: [configurator tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/virtual_joystick/configurator_test.exs), [lifecycle tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/virtual_joystick/manager_test.exs).

<a id="vj-008"></a>

## VJ-008 — Return a useful unsupported state on other platforms

As a non-Windows user, I want the application to explain joystick availability, so the rest of Trenino remains usable.

- Preconditions: Linux/macOS/other non-Windows OS.
- Flow: startup loads normal app; joystick manager marks unsupported; UI disables relevant operations.
- Acceptance: no driver configuration/elevation; enable/disable return unsupported; train/simulator features remain separate; native Rust adapter returns structured unsupported if directly exercised with valid CLI arguments.
- Failure: a compiled stub is not a native joystick implementation for that OS.
- Evidence: [platform](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/virtual_joystick/platform.ex), [startup reconciliation tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/virtual_joystick/manager_test.exs), [native stub](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/tauri/virtual_joystick/src/vjoy.rs).
