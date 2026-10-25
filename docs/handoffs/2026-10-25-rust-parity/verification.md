# Verification and native acceptance

Executed on macOS arm64, October 25, 2026. All databases and network services used for behavioral probes were disposable fixtures. Reports in `evidence/` preserve scoped regression tests, RED/GREEN probes and review dispositions. Raw build logs are ignored local artifacts under `tmp/`.

## Fresh aggregate checks

| Check | Result | Local log |
| --- | --- | --- |
| `cargo test --workspace -- --test-threads=1` | 840 passed, zero failures | `completion-workspace-tests.log` |
| `cargo clippy --workspace --all-targets -- -D warnings` | Passed | `completion-workspace-clippy.log` |
| `cargo fmt --all --check` | Passed | `completion-workspace-fmt.log` |
| `npm --prefix tauri/ui run check` | Zero errors and warnings | `final-ui-check.log` |
| `npm --prefix tauri/ui test` | 165 passed, 12 files | `final-ui-tests.log` |
| `npm --prefix tauri/ui run build` | Passed, 141 modules | `final-ui-build.log` |
| `cargo test --manifest-path tauri/src-tauri/Cargo.toml --features "rust-ui desktop-updater"` | 37 passed, zero failures | `completion-desktop-tests.log` |
| Desktop strict clippy, all targets, same features | Passed | `completion-desktop-clippy.log` |
| Desktop formatting check, same manifest | Passed | `completion-desktop-fmt.log` |
| Desktop build, same features | Passed | `completion-desktop-build.log` |
| `git diff --check` | Passed | Executed directly |

The separate scoped `rust-ui` desktop run passed 34 tests. Aggregate test totals include their respective library/integration/build-config suites; workspace and desktop are separate manifests.

## Closing adversarial verification

Both final calibration reviews accepted the dispatch repair. The independent closing reviewer executed 12 focused checks, including the original false-cleanup-ACK failure probe, actual controller/arbiter dispatch, retained-owner recovery and wizard cancellation. See [closing review](evidence/calibration-dispatch-fence-review.md) and [original reviewer fix review](evidence/calibration-dispatch-fence-fix-review.md). These checks supplement, rather than replace, the fresh aggregate runs above.

## Native smoke isolation

The macOS debug app is an ad-hoc bundle under `tmp/native-bundle-smoke.snp4139e`, with a disposable database, fake API key and loopback simulator on port 58328. A recent update-check fixture suppresses automatic upstream requests during the final smoke; it does not validate real GitHub access.

The first native run verified consent, train/script creation, accepted simulator connection, detected active train, manual Lua execution/logs and endpoint exploration/selection. It exposed real configuration-create and hash-navigation defects missed by bridge mocks; fixes have actual backend/IPC and frontend regression tests.

During shutdown verification, a CUA accessibility read after Quit unexpectedly relaunched the bundle without the trial override. This created a new empty default Rust trial database. The session verified zero user records, stopped that owned process through coordinated shutdown, and removed only those newly created empty artifacts. No existing user database was modified. Final shutdown verification uses process and SQLite checks without another CUA observation.

## Final rebuilt native WebView results

The final build was copied into the same isolated debug bundle and launched with an explicit trial database override and an ephemeral localhost listener. Actual UI actions verified:

- Configuration creation now returns its detail and navigates to `/configurations/2126339067`; the persisted name and ID were checked in the fixture afterward.
- The train page shows the actual detected simulator ID, marks the fixture train Active and disables Delete with the active-train explanation.
- Clicking Automation scrolls the editor while retaining `/trains/1`; it no longer changes the SPA route to an unavailable page.

Coordinated localhost `POST /api/shutdown` returned `shutting_down`; the owned process exited with code 0. Its disappearance and an exclusive SQLite reopen were verified from the shell. The owned loopback simulator was then stopped and its listener confirmed gone. No CUA observation was made after exit. The native keyboard Quit shortcut did not establish process exit, so it is not counted as shutdown evidence.

## Explicitly unperformed acceptance

- Actual Windows UAC consent, nested Job Object termination, driver/configurator/installer operations. Portable configurator tests and isolated actual Windows-source typecheck/clippy ran; full target compilation on macOS lacks Windows SDK headers.
- Clean-machine Linux/Windows builds/installations and CI execution. The added workflow is source configuration, not a completed CI run.
- Physical serial controls, calibration, output/display, flashing/bootloader changes, native key injection, real vJoy and real simulator operation.
- Signed release packaging, updater install/rollback and publication. Stable updater tests exercise cleanup ordering, not an actual installation.
- Non-Windows Rust packaging requires real avrdude and avrdude.conf staging. The wrapper's missing-prerequisite refusal was executed and verified; no fake sidecar was supplied.

Keep the legacy release default until these native acceptance gates pass. Software/fake-service coverage does not imply they have passed.
