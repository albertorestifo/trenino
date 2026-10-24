# Runtime/UI integration correctness review

Range reviewed: `f79f41e..4ee4052`, with the `e9ef8d9` assertion-only follow-up. I reviewed the integration brief and appended contracts, implementation report, review diff, and the relevant source and UI bridge. This is a source review; I did not launch the app, updater, installer, or a user database. The reported workspace, desktop-feature, UI, Clippy, and formatting results are accepted as existing evidence rather than repeated here.

## Actionable findings

### P1 — The database path is not exclusively owned at the storage boundary

`AppServices::open_full` takes the adjacent `.runtime.lock` in `crates/trenino-runtime/src/app.rs:46`, but `Database::open_full` is public and opens the same file directly in `crates/trenino-runtime/src/storage/mod.rs:200-235`. SQLite's ordinary connection does not honor the adjacent lock. A second caller can therefore construct another live full-schema worker for the same path while `AppServices` owns it, and `Database::set_with_revision` can write through that second worker (`storage/mod.rs:285-293`). Repro on a disposable full-v2 file: keep an `AppServices::open_full(path, None)` alive, call `Database::open_full(path)` and then `set_with_revision("error_reporting", "disabled", "settings")`; both opens and the second write are admitted. This bypasses the service operation mutex and the single-owner guarantee, so the service cannot guarantee its snapshots and revisions are serialized with every admitted Rust writer.

Fix requirement: enforce ownership in the storage open path or make the full-schema constructor inaccessible outside the single owned service; ensure every runtime writer shares the same worker and lock. Add a focused two-opener refusal test using a disposable DB.

### P2 — Unsupported topics acknowledge subscriptions

`RustAppState::register` accepts every `Topic` in `tauri/src-tauri/src/rust_ui.rs:68-89`, and `ui_subscribe` returns that success at `rust_ui.rs:340-348`. Yet `AppServices::snapshot_json` returns `Unavailable` for bindings, scripts, and firmware at `crates/trenino-runtime/src/app.rs:168-184`. Repro: invoke `ui_subscribe` with `{topic:"firmware", subscription_id:"observer-1"}` from the main window; it returns success, while the immediately following `ui_get_snapshot` fails. The bridge then retains a registered observer and retries snapshots (`tauri/ui/src/bridge/client.ts:187-207`, `:125-157`). This is a success-shaped capability claim for an unavailable operation.

Fix requirement: reject unsupported topics with the same typed `unavailable` failure before registration, or provide a supported capability route that the bridge can check before subscribing.

### P2 — Trial startup refusal is not actionable in a release GUI

The service correctly returns explicit `BootstrapUpgradeRequired` and `LegacyUpgradeRequired` (`crates/trenino-runtime/src/storage/mod.rs:84-89`, `:383-398`), but the Tauri setup only converts them into an I/O error (`tauri/src-tauri/src/rust_ui.rs:406-411`) and `build(...).expect(...)` panics at `:420-421`. The release executable suppresses the Windows console (`tauri/src-tauri/src/main.rs:1-5`). Repro: select a disposable bootstrap-v1 or recognized Ecto DB through the absolute trial override and launch a release trial build; startup exits before a window or user-facing error is shown. The selected database is preserved, but the user cannot see why it was rejected or what explicit upgrade is needed.

Fix requirement: show a startup error dialog or error window containing the sanitized, actionable schema refusal and selected-path context before exiting. Keep upgrade manual and backup protected.

## Verdict

**Spec: not yet fully met. Quality: integration is substantially implemented but needs the three fixes above before this slice is accepted.** Full-v2 fresh creation and strict migration-ledger admission, checked numeric `ConfigId`, decimal-string counters, settings secret redaction, observed-window ownership, and download/verification before quiescence are supported by the reviewed source and reported tests. The path-lock bypass prevents a complete single-owner claim; unsupported subscriptions and invisible startup refusal miss the stated availability and actionable-error contracts.

Future release gates remain separate: a packaged WebView IPC smoke test, Linux/macOS builds, actual signed updater installation, real hardware/simulator shutdown participation, explicit preservation-aware bootstrap mapping, and non-disposable migration exercises. None was run in this review.
