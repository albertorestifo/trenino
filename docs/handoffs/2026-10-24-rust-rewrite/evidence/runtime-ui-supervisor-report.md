# Runtime/UI integration supervisor report

Reviewed `f79f41e..4ee4052`, plus assertion-only formatting in `e9ef8d9`, against the integration and supervisor briefs. Later sibling hardware changes are outside this audit. The supervisor performed an independent source audit and disposable probes, then commissioned two fresh, independent `gpt-6-sol`/high reviews sequentially without sharing findings. Their original reports are retained as `runtime-ui-correctness-review.md` and `runtime-ui-adversarial-review.md`.

**Spec verdict: changes required for this bounded integration slice. Quality verdict: substantial working integration and useful automated coverage, but the ownership and mutation boundaries do not yet enforce the stated invariants.** No full-rewrite, packaged WebView, hardware-cleanup, or release-readiness approval is implied.

## Accepted findings

### R1 — P1: enforce one owner at every writable database admission, including file aliases

References: `crates/trenino-runtime/src/app.rs:46`, `:220-251`; `crates/trenino-runtime/src/storage/mod.rs:200-235`, `:257-258`, `:285-293`.

The adjacent `.runtime.lock` belongs only to AppServices and is derived from the canonical path string. Two reproducible routes bypass it:

1. Keep `AppServices::open_full(path, None)` alive, call `set_consent(true)`, then open `Database::open_full(path)` directly. The second worker is admitted and `allocate_epoch()` returns 2. The original service subsequently reports epoch 1/revision 0 because its cached epoch and the shared database metadata disagree. The generic `Database::open` also admits full schemas, so changing only `open_full` visibility is insufficient.
2. With the first service alive, create a hard link from `primary.db` to `alias.db`, then call `AppServices::open_full(alias, None)`. Canonicalization retains the distinct hard-link names and hence distinct lock files. The second AppServices instance starts at epoch 2; the first again reports epoch 1/revision 0 after previously committing revision 1.

Both routes were executed against disposable files on Windows. Output was respectively `direct worker admitted: new epoch=2; original service snapshot: epoch=1, revision=0`, and `second admitted: first epoch=1, second epoch=2; first snapshot after second startup: epoch=1, revision=0`.

Fix requirement: put exclusive ownership at the shared writable storage admission boundary and hold it until the worker closes. Cover both constructors and identify the underlying file, or explicitly reject unsupported multiply linked database files; a pathname-only sidecar cannot establish file identity. Preserve legacy query-only inspection. Test same-path direct opens and alias opens, ensuring rejected attempts do not advance epochs or reset revisions. This is an exposed Rust API/explicit-path ownership defect; no current WebView command opens a second database itself.

### R2 — P2: reject partial initialized runtime metadata before allocating an epoch

References: `crates/trenino-runtime/src/storage/mod.rs:649-662`, `:676-700`.

`read_u64` treats a missing epoch as zero, and `allocate_epoch` overwrites every topic revision without first distinguishing an uninitialized database from partial initialized metadata. Disposable reproduction: initialize a full database, commit consent, close it, delete only `__runtime.epoch` while retaining its topic revision rows, and reopen. Startup succeeds with epoch 1/revision 0, reusing the prior epoch. This is separate from the correctly strict schema-migration ledger admission.

Fix requirement: recognize the valid all-absent runtime metadata state for fresh/migrated databases, but refuse partial or malformed initialized metadata without writes. Validate the complete known metadata set before advancing the durable checked counter. Add partial-epoch, partial-revision, and malformed-counter preservation tests alongside the existing overflow case.

### R3 — P2: prevent legacy settings APIs from bypassing full-schema validation and revisions

References: `crates/trenino-runtime/src/settings.rs:59-75`, `:97-98`; `crates/trenino-runtime/src/storage/mod.rs:246-249`, `:492-508`; compare `crates/trenino-runtime/src/app.rs:74-135`.

On one full-v2 worker, `Settings::new(db.clone())` still uses unrestricted `Database::set`. A disposable probe called `set_error_reporting_consent(true)` and `set_simulator_url("file:///etc/passwd")` after allocating an epoch. The stored snapshot reported `consent=enabled, url=file:///etc/passwd, revision=0`. The invalid URL is accepted and user-visible settings change without any revision. This remains possible with a single worker, so the R1 ownership fix alone does not establish the mutation invariant.

Fix requirement: route every supported full-v2 settings mutation through the validated setting-plus-revision transaction, or restrict the old raw setters to bootstrap/explicit maintenance use. Guard the generic setter as well as named setters so reserved runtime metadata and known user settings cannot bypass the boundary. Add focused full-v2 API tests. Present Tauri commands already use AppServices correctly; this is not a demonstrated WebView command bypass.

### R4 — P2: merge the trial build override with caller-supplied Tauri configuration

References: `tauri/src-tauri/build.rs:5-9`.

The Rust feature replaces `TAURI_CONFIG` wholesale. This silently discards caller/CLI configuration such as an isolated identifier, version, updater endpoint, or updater artifact option. The installed Tauri build and code-generation sources both read this environment variable as a merge overlay. A disposable harness included the exact project build script and stubbed only `tauri_build::build`; supplying identifier/updater/artifact overrides produced an effective configuration containing only `frontendDist`, `externalBin`, and `resources`.

Fix requirement: parse and preserve the incoming overlay, then override only the three required trial fields. Emit the same merged configuration for both build processing and `generate_context!`. Add a small merge test preserving identifier, updater endpoint, and unrelated bundle keys. Do not test this by contacting an updater or installing anything.

### R5 — P2: show actionable schema refusal before the release GUI exits

References: `tauri/src-tauri/src/rust_ui.rs:406-421`; `tauri/src-tauri/src/main.rs:1-5`.

The storage layer returns actionable legacy/bootstrap refusal, but setup converts it to an I/O error and the outer builder calls `expect` before creating a window. The release Windows executable suppresses its console. Selecting a preserved legacy/bootstrap database therefore normally exits without showing the refusal or explicit upgrade requirement. This is established by the startup/error path; no GUI was launched to reproduce it.

Fix requirement: surface a sanitized startup failure through a dialog or error window, including actionable guidance for the known schema refusal variants, then exit cleanly. Keep legacy upgrade explicit and backup protected; do not turn the error handler into automatic migration. Verify the error presentation path with controlled initialization failures.

### R6 — P2: use platform-native absolute paths in the trial override test

Reference: `tauri/src-tauri/src/rust_ui.rs:491-504`.

The unconditionally compiled test passes `C:/isolated/trial.db` and unwraps successful absolute-path validation. That path is relative under Unix path semantics, so the test fails on Linux/macOS even though the production selector is platform-neutral. This is a deterministic source-level portability defect, not a claim that a non-Windows suite was run.

Fix requirement: obtain an absolute path from `tempfile::tempdir` and construct the selected/default paths under it; retain the separate relative-path rejection case. Run the focused test on Windows now and include it in later Linux/macOS verification.

## Independent findings adjudicated separately

- **Correctness: unsupported topic subscriptions.** Not promoted to an acceptance blocker. The command acknowledges observer registration, while the snapshot explicitly returns typed `unavailable`; this does not fabricate a supported domain result. Current screens do not subscribe to those unavailable topics. A capability query or rejection during registration could improve behavior, but the brief does not establish that registration itself promises an implemented publisher.
- **Adversarial: installer failure after quiescence.** The stopped application cannot resume commands, but the existing native failure dialog at `updater.rs:28` already tells the user to close and reopen it. Closing then reopening is a working recovery path, and preserving a quiesced process after a potentially partial installation is consistent with the upstream flow. Clearer unconditional wording after successful quiescence would help; this is not a new blocking defect or a reason to restore services automatically.
- **Adversarial: event selected before unsubscribe arrives afterward.** Not promoted to a defect without a stronger contract. Publication selects registered windows under the registry lock; an already selected/in-flight event can complete after teardown. The frontend explicitly disposes its listener and guards late delivery. Window/observer ownership and domain-operation independence remain intact. Documenting/testing the in-flight-delivery guarantee would improve clarity.

The original independent reports remain unchanged, including their priorities and judgments. This aggregate records the supervisor's acceptance decisions rather than silently rewriting those reviews.

## What the reviewed slice does establish

- Fresh full-v2 creation/reopen has explicit canonical baseline metadata; the fresh ledger extension requires an empty Ecto ledger, while migrated full-v2 requires the recognized Ecto ledger. Unknown/incomplete schema ledgers are refused. Legacy/bootstrap path selection does not migrate or discard their contents.
- Main-window command names, snake-case observer arguments, DTO shapes, decimal-string counters, and numeric checked ConfigId agree with the frontend. Database work is dispatched off the WebView thread. Core event capability is present; native updater calls do not require frontend updater command permissions.
- The normal AppServices command path serializes operations; consent commits its value/revision together, publishes afterward, and snapshots query current state. Public UI settings/errors do not expose API-key contents. Manual-key precedence, TSW7/TSW6 file ordering, and URL validation are implemented on that path.
- The native updater retains verified download before acknowledged shutdown before installation. No Rust trial command exposes flashing/controller work in this slice, so the absence of a hardware shutdown participant is a future integration gate, not fabricated successful cleanup. The coordinator explicitly runs registered participant phases and closes the database last.
- The explicit trial feature selects static frontend assets and isolated `rust-trial/trenino.db`, or an absolute explicit override, without starting BEAM. The legacy default configuration remains present.

## Evidence and limits

Accepted existing evidence: root's integrated `cargo test --workspace` passed 152 tests (core 53/runtime 99), superseding earlier report counts; workspace all-target strict Clippy and formatting passed. The implementation report records the desktop `rust-ui desktop-updater` 11-test suite, strict Clippy, Windows build, UI check/build, and 35 frontend tests. Root additionally confirmed `cargo check` for `rust-ui` alone. These broad suites were not repeated during this review.

Supervisor disposable probes used compiled local runtime code and fresh temporary databases only. Source/probe artifacts are under `C:/Users/Alberto/AppData/Local/Temp/trenino-runtime-review-3e6cfc7da6fe4ea38f9198c10187988f` (`main.rs`, `partial.rs`, `direct_worker.rs`, `legacy_setter.rs`, and `build_overlay.rs`). Initial standalone linker attempts needed the existing Windows import-library path; one retry waited for a sibling rebuild to release the rlib. The successful observations above are the basis of the findings. No production source edits, commits, live user databases, app/updater launches, hardware, installers, or signing actions were performed by this review team.

Remaining verification/release gates: actual Tauri invoke/WebView smoke coverage with a disposable trial database; Linux/macOS builds and tests; packaged static asset/IPC verification; installed updater behavior; real hardware/simulator lifecycle registration and cleanup; editor/workflow parity; preservation-aware bootstrap mapping and explicit backed-up migration exercises. The unchanged legacy build remains blocked in this checkout by the missing genuine backend executable; no placeholder binary or installed-resource modification is acceptable. These limits must stay separate from fixing the six concrete findings above.

## Scoped fix-round-1 re-review — `807420e`

Reviewed only `6b20a81..807420e` (`runtime-ui-fix1-review.diff`) against original R1–R6 and the appended implementation evidence. No fresh whole-slice review, new subagents, production edits, broad test reruns, real database access, app/updater launches, or hardware actions were performed. Concurrent firmware and hardware changes are excluded.

| Original finding | Verdict | Scoped assessment |
|---|---|---|
| R1 — single writable database owner | **NOT ADDRESSED** | Both public constructors now enter the ownership boundary and file aliases resolve to the same identity, but the lock namespace depends on each process's temporary-directory environment. The original second-worker/epoch-reset failure remains reproducible across two processes. See below. |
| R2 — partial runtime metadata | **ADDRESSED** | `allocate_epoch` validates the complete metadata set before writes, accepts only the all-absent initial state or a complete canonical nonzero epoch plus six revisions, and refuses partial/malformed/unknown rows. Reported preservation tests cover the original missing epoch and missing/malformed revision cases. |
| R3 — full-v2 setting mutation boundary | **ADDRESSED** | Full-schema raw `Database::set` is refused. Named `Settings` setters use the validated settings-plus-revision path; generic `set_value`, reserved keys, wrong topics, invalid consent, invalid URLs and empty keys cannot bypass it. Bootstrap behavior remains separate. |
| R4 — caller Tauri overlay | **ADDRESSED** | `trial_overlay` preserves caller fields and changes only the required frontend/bundle trial fields; build processing and code generation receive the same merged string. The focused merge test and reported incoming-overlay build cover the original loss. |
| R5 — visible release startup refusal | **ADDRESSED** | Known schema refusals now reach sanitized native dialogs before main-window creation. Dialog registration is present in both Rust feature combinations; asynchronous `show` avoids blocking setup; the pending flag prevents premature exit and is cleared before callback-requested exit. The ordinary empty-service shutdown path is valid. Native dialog appearance itself remains an unexecuted GUI smoke gate. |
| R6 — portable absolute-path fixture | **ADDRESSED** | Default and override fixture paths now derive from `tempfile::tempdir`; relative-path rejection remains. The Windows focused result is supplied; Linux/macOS execution is still a declared platform gate. |

### Remaining R1 — P1: temporary-directory-dependent identity lock namespace

Reference at this commit: `crates/trenino-runtime/src/storage/mod.rs:392-410`, specifically `std::env::temp_dir().join("trenino-runtime-db-locks")` at line 401.

The file identity is stable, but its lock file is resolved under a process-dependent root. Two instances launched with different `TMP`/`TEMP` settings (or `TMPDIR` on Unix) therefore acquire different lock files for the same underlying database. This is still a failure of the original R1 ownership boundary, not an unrelated new feature request.

Executed a disposable two-process Windows probe against the current compiled runtime:

1. Parent opens `AppServices::open_full(path, None)` and commits consent at epoch 1/revision 1.
2. Parent launches a small child probe with `TMP`, `TEMP`, and `TMPDIR` pointing to a separate disposable directory.
3. Child calls the public `Database::open_full` on the identical database path and then `allocate_epoch`.
4. Child succeeds with epoch 2. The still-open parent reports epoch 1/revision 0.

Observed output: `second worker admitted; epoch=2` followed by `first snapshot after child: epoch=1, revision=0`. Probe source and disposable files are retained at `C:/Users/Alberto/AppData/Local/Temp/trenino-runtime-fix1-review-cc9f8cf7695e4673b17244b3dc4f0d03/main.rs`. The parent's environment was not changed; only the child environment was overridden.

Fix requirement: make the ownership namespace independent of per-process environment and preserve identity/alias handling until the SQLite connection closes. An OS ownership primitive keyed to file identity is an appropriate direction; another environment-derived directory is not sufficient. Test rejection across processes with different temporary-directory environments and verify the original epoch/revision remain unchanged. Retain the existing direct-open and hard-link regressions.

### Evidence and scoped verdict

Accepted the writer's supplied results rather than repeating them: 17 AppServices tests, 11 foundation tests, 121 runtime tests; both Tauri Rust feature combinations' 14 library tests plus build-overlay test; both Windows feature builds and strict Clippy; formatting; and the build using incoming `TAURI_CONFIG`. Reviewed the corresponding test additions and production wiring. The only new executable supervisor check was the targeted two-process ownership probe above.

**Spec/quality verdict for this fix round: five findings addressed, R1 remains open at P1.** No additional important breakage was identified in this bounded diff. Release, hardware, WebView, platform, and installer gates remain as previously documented.

## Scoped fix-round-2 re-review — `535b58b`

Reviewed only `807420e..535b58b` (`runtime-ui-fix2-review.diff`) for the remaining R1 and new important breakage. Concurrent uncommitted hardware/firmware work, including their storage/Cargo additions, was excluded. No new subagents, production edits, broad test reruns, live databases, GUI/updater, or hardware actions were used.

**R1: ADDRESSED. R2–R6 remain ADDRESSED. No additional important breakage was identified in this diff.**

The temporary-directory namespace is removed. On Windows, the `Global\\TreninoRuntimeDb-{volume-serial}-{file-index}` mutex uses the opened file's identity and does not depend on the process environment. The database worker both acquires and releases the mutex, satisfying Windows mutex thread ownership. The file identity handle remains alive with the guard; timeout refuses admission, unexpected failures close the handle, and `WAIT_ABANDONED` is accepted as an acquired mutex so ordinary SQLite recovery can proceed. Failed schema/connection admission drops the guard on that same worker. Normal teardown explicitly drops the SQLite connection before releasing ownership.

On Unix, the guard holds an exclusive `fs2` file lock on the opened database descriptor itself, so hard-link aliases share the lock without a lock-directory lookup. The descriptor remains alive until connection teardown. Both platform implementations release ownership after legacy query-only recognition, preserving the intended inspection behavior. The Unix branch was inspected but not executed in this Windows environment; its platform test gate remains open.

The added subprocess regression directly covers the prior failing scenario: the child verifies its distinct temporary directory, attempts both the same database path and a cross-directory hard link, and must receive `AlreadyRunning`. The parent checks that its snapshot and stored epoch/revision remain unchanged, then closes the owner and confirms a successor advances to epoch 2. Existing direct-opener and alias regressions remain. This is adequate focused coverage of the original R1 failure and normal release/reacquisition.

Accepted the appended implementation evidence: the targeted subprocess regression failed before the ownership change and passed afterward; the complete AppServices suite passed 19 tests; foundation passed 11; runtime all-target strict Clippy and scoped rustfmt passed. Independently ran `git diff 807420e..535b58b --check`, which passed. The writer's broader formatting attempt encountered concurrent firmware-owned changes; those do not alter this scoped acceptance. No claim is made that owner-crash recovery or cross-user mutex ACL behavior was exercised—the code paths were inspected, and the executed subprocess case uses the same desktop account.

**Final scoped spec/quality verdict: all six accepted runtime/UI findings are closed; this fix series is accepted for the bounded integration slice.** Previously declared WebView, platform, packaging, updater-install, hardware lifecycle, migration, and application-parity gates remain unchanged. This is not full rewrite or release approval.
