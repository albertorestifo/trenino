# Independent adversarial review: runtime/UI integration

Reviewed `f79f41e..4ee4052` with the assertion-only `e9ef8d9` follow-up, against `runtime-ui-integration-brief.md`, `runtime-ui-integration-report.md`, and `runtime-ui-integration-review.diff`. This review covers the Rust trial's AppServices, full-v2 admission, repositories, Tauri bridge, shutdown, and updater. No production files, user database, hardware, app, or installer were exercised. The reported workspace and desktop test/build results were accepted as existing evidence; I did not repeat those broad suites.

## Findings

### [P2] Failed native installation strands the running trial after acknowledged shutdown

**References:** `tauri/src-tauri/src/update_flow.rs:19-22`, `tauri/src-tauri/src/updater.rs:25-31,68-83,42-47`, `tauri/src-tauri/src/rust_ui.rs:150-184`.

**Trigger:** A signed package downloads and verifies, `RustAppState::shutdown()` succeeds, then `update.install(bytes)` returns an error (for example, the installer cannot be launched or written). `apply_update` necessarily invokes the installer after shutdown. The error handler keeps the current process/window open and advises retrying from Help, but `shutdown()` has removed AppServices and set `stopping`; the next check is rejected by `accepts_work()`. All UI commands are also unavailable. The native installer may fail after verification, so this is a real post-quiescence failure path, not a signature-bypass concern.

**Fix requirement:** Give the user a working recovery after an installer error following successful quiescence, such as an explicit app restart/reopen path, and make the dialog match what can actually be retried. Add a focused failure-path test around the state transition.

### [P2] Public settings setters can mutate full-v2 state without validation or a topic revision

**References:** `crates/trenino-runtime/src/settings.rs:59-75,96-98`, `crates/trenino-runtime/src/storage/mod.rs:246-249,269-292,492-508`, `crates/trenino-runtime/src/app.rs:74-135,317-333`.

**Trigger:** On a disposable full-v2 database, construct `Settings::new(Database::open_full(path)?)` and call `set_simulator_url("file:///etc/passwd")` or `set_error_reporting_consent(true)`. These public methods call `Database::set`, which is allowed in `SchemaMode::Full` and never bumps `__runtime.revision.settings`. The URL setter also accepts a value that `AppServices::set_simulator_url` rejects. A subsequent settings snapshot can therefore carry a changed value with an unchanged revision; an invalid URL is silently replaced by the default in `AppServices::get_settings`. The present Tauri commands use AppServices, so this is an exposed Rust API invariant breach rather than a demonstrated UI command bypass today.

**Fix requirement:** Make full-v2 settings mutations pass through the same validated setting-plus-revision transaction, or restrict these legacy setters to bootstrap-only use so full-v2 callers cannot bypass AppServices. Verify the revision and rejected URL with a focused full-v2 test.

### [P3] Unsubscribe can return before a previously selected event is emitted

**References:** `tauri/src-tauri/src/rust_ui.rs:92-109,117-128,360-374`.

**Trigger:** A consent write commits. `publish_change` obtains the list of window labels in `windows_for`, releases the registry lock, then a same-window `ui_unsubscribe` removes the last observer and returns. `publish_change` can still call `window.emit` using its copied label. Thus the backend can deliver a change to a window with no registered observer after unsubscribe has completed. The frontend's own listener disposal usually discards it, limiting present impact, but the backend's stated publication ownership contract is not met.

**Fix requirement:** Make publication and registry teardown ordered so a completed unsubscribe excludes later emission to that window, or explicitly weaken and test the contract to permit in-flight delivery. A controlled race test should cover the ordering.

## Verdict and limits

The canonical fresh full-v2 creation, exact baseline/ledger admission, legacy/bootstrap refusal, positive signed-32-bit `ConfigId` conversion, decimal-string counters, and one-worker AppServices command path appear consistent with the brief on code inspection. The settings and list repositories use serialized worker requests, and consent writes pair the setting and revision transactionally through AppServices. No additional concrete blocker was found in those paths.

**Spec verdict:** Partial pass. The updater recovery and full-v2 settings API issues should be resolved before claiming this integration contract complete; the observer race needs an explicit ownership decision and test. **Code quality verdict:** The narrow trial is coherent and has substantial existing automated coverage, but its post-shutdown failure behavior and public mutation boundary are not yet robust.

Separate later release gates remain as documented in the integration report: no packaged WebView IPC smoke test, no actual hardware/simulator lifecycle, no complete editors or firmware workflows, and no Linux/macOS package or real native update install. Those are not findings against this scoped diff.
