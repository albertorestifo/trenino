# vJoy configurator fix 2 scoped re-review — 2026-10-25

Reviewed the actual configurator, Windows adapter/broker/worker, manager rollback, portable tests, and desktop main feature guard against all four Important findings in `tmp/vjoy-configurator-fix1-review.md`. No source edits, subagents, registry changes, driver access, or elevation.

## Verdict

**All four scoped findings are addressed. No additional concrete Important/Critical defect was established in this round.** This is source/portable-test acceptance, not native Windows installer or driver acceptance. Named-job access across elevation, nested-job behavior, alternate credentials, and GUI-subsystem worker pipes still require the recorded Windows smoke test.

## Finding dispositions

1. **Pending intent falsely grants ownership — closed.** `configurator.rs:249-260` now accepts an existing compatible device only through the owned marker or the separate confirmed-creation marker; pending intent has no authority. The confirmed stage is written only after successful helper completion and compatible-state confirmation (`:271-291`), before writing the ordinary ownership marker. Deletion likewise requires owned or confirmed provenance, while stale pending-only Compatible state returns `ForeignDevice`. Error reconciliation no longer turns launch failure/timeout plus compatibility into ownership. Manager startup, acquisition, and cleanup use confirmed rather than pending as the recovery authority. The two original actual-source RED reproductions now pass: stale prelaunch intent cannot delete a later foreign device, and definite launch failure cannot adopt it.

2. **Helper executes before containment — closed in the implemented control flow.** `windows_configurator.rs:209-329` elevates the installed same-executable broker, passing only a validated operation, selected ID, and a newly generated 128-bit random named job. The parent creates the kill-on-close job before launch and rejects an existing-name collision. The broker validates the name grammar and waits for `IsProcessInJob` against that exact named parent job (`:575-607`) before accessing the helper. It then revalidates the installed resource trio, constructs the fixed selected-ID arguments, starts the helper with `CREATE_SUSPENDED`, assigns the helper to its own kill-on-close job, and only then resumes the actual primary thread (`:608-704`). The helper already inherits the verified parent job; the nested broker job supplies cleanup on broker death. Both levels check process exit and job drain. Assignment/termination/reap failures cannot produce success; parent cleanup retains incomplete handles. The earlier ShellExecute-before-job race now covers only a controlled broker that performs no helper mutation until exact-job membership is established. No unsafe helper execution window was found.

   Native Windows execution was not available. In particular, a failure to establish job access/assignment intentionally remains `CleanupIncomplete`; source inspection does not prove that the real elevated path succeeds under every supported account policy.

3. **Production preflight bypasses bounded worker — closed for the reported path.** `WindowsVjoyAdapter::driver_available` and `device_status` (`windows.rs:163-168`) delegate to `probe_driver`/`probe_device`, which run same-executable children under their deadline. Worker modes call distinct `raw_driver_available`/`raw_device_status`, avoiding recursive spawn. Thus manager startup/enable/cleanup calls to those adapter APIs no longer execute those probes in the owner process. Configurator status/descriptor probing also remains in the bounded status worker. `tauri/src-tauri/src/main.rs:5-8` dispatches worker/broker modes before Tauri, with `cfg(all(windows, feature = "rust-ui"))`, matching the optional runtime dependency in Cargo.toml and preserving the legacy feature's compilation boundary.

   The retained descriptor/acquisition/live-report SDK path still initializes and uses native state in-process (`windows.rs:171` onward). This review does not claim those calls are fault-isolated or impose a new all-runtime-worker requirement; it closes the original pre-configuration `driver_available`/`device_status` bypass specifically.

4. **Marker-read error skips earlier acquisition rollback — closed.** Both ownership and confirmed-marker read errors now call `rollback_with_error` (`manager.rs:1094-1102`), which invokes `release_all` and surfaces its cleanup error preferentially. Earlier selected acquisitions are neutralized/released before the marker-read failure is returned. The checked-in regression injects the second selected ID's read failure and asserts release of ID 1 plus unchanged persisted enabled=false; it passed in this re-review. The confirmed-marker error branch uses the same rollback helper.

## Executed evidence

Only focused reproductions were run; the 76-test suite was not repeated.

```text
rustc --edition 2021 --test -Awarnings /tmp/trenino-vjoy-fix1-review-probes.rs -o /tmp/trenino-vjoy-fix1-review-probes
/tmp/trenino-vjoy-fix1-review-probes review_ --nocapture
2 passed: the two original foreign-ownership safety assertions

CARGO_TARGET_DIR=/tmp/trenino-vjoy-target cargo test -p trenino-runtime --test vjoy_manager --no-default-features second_selected_marker_read_failure_rolls_back_first_acquisition --quiet
1 passed
```

The standalone reproductions import the current production `configurator.rs`; they do not duplicate its implementation. The new broker grammar regression, confirmed-marker recovery test, and reported isolated actual-source Windows type-check/Clippy were inspected as supporting evidence, not falsely represented as rerun or native execution. Root-to-file symlink/reparse checks, fixed ID 1–16 grammar, legacy ID 1 owned marker, UAC cancellation mapping, and non-persisting runtime release remain present.
