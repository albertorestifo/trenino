# Firmware catalog supervisor checkpoint — own audit only

Status: own audit complete; both required fresh independent reviews remain pending. This is not an acceptance verdict. Root will dispatch the independent reviewers while the supervisor yields its slot, then resume this supervisor for aggregation and adjudication.

Scope reviewed: firmware catalog/core manifest and compatibility, immutable selection, downloader/cache, scheduler and injected repository contract at 8723455..f79f41e. Read firmware-catalog-supervisor-brief.md, firmware-catalog-brief.md, firmware-catalog-report.md, firmware-catalog-review.diff, actual source, focused tests and legacy Elixir source. Shared-worker repository implementation, startup/UI wiring and flashing are explicit later gates; their absence is not a finding against this slice.

## Confirmed own-audit findings, pending independent aggregation

1. **P1 — Cache reuse loses pinned remote asset identity.** `crates/trenino-runtime/src/firmware/downloads.rs:118` and `:202`: cache path is version/environment, and validity is only regular-file/nonempty/length. Download OLD! for version1.2.3/uno, then clone selection and change GitHub asset ID and URL while preserving size4. The second download returns OLD! from the first asset even when the new URL is offline. A refreshed/replaced asset can therefore receive the wrong firmware bytes despite a pinned selection. Bind publication/reuse to selected asset provenance (e.g. validated receipt or identity-addressed file), and coordinate locks at the actual destination identity. This is identity validation, not an unsupported checksum/authenticity claim.

2. **P2 — Cleanup deletes files it never created.** `downloads.rs:127-149`: guard is armed before HTTP and before `create_new`. Precreate the chosen `version_environment.hex.PID.SEQ.partial`; `create_new` fails, then guard deletes that existing file. Recycled PID/sequence after a crash can collide with a previous partial. Guard only files successfully created/owned by this attempt; retry unique names on collision. Local reproduction precreated sequences0..19 and observed count19 after a failed attempt.

3. **P2 — Empty transfer reports a successful usable firmware path.** `downloads.rs:163-173`: HTTP200 with empty body and expected size0 returns Ok with an empty final file. Unknown-size empty body follows the same route. `valid_cache` refuses that same file on the next attempt, so initial success and subsequent cache validity disagree. Reject zero-byte firmware before publication; test both known zero and unknown size.

4. **P2 — Redirect policy is checked only after forbidden contact.** `downloads.rs:129-136`, also `catalog.rs` request/response URL checks. Injected default reqwest client follows redirects before response URL validation. A loopback fake redirect to `http://user:pass@127.0.0.1:PORT/` contacts that forbidden credential-bearing target, then returns InvalidUrl. Validate each redirect before following it, including catalog/manifest requests, or require/enforce a transport policy with a checked redirect boundary. No external network was used for the probe.

5. **P2 — Requirement parser silently accepts invalid Elixir policies.** `crates/trenino-core/src/firmware/compatibility.rs:169-175`, `:247-260`: Rust accepts `>= 1.2`, `= 1.2.3`, and `>= 1.0.0, < 2.0.0`; installed Elixir `Version.parse_requirement` returns `:error` for each. This violates malformed policy refusal. Rust also returns InvalidRequirement for valid `~> 1.2.3+build.1` and `== 1.2.3+build.1` because it counts dots in build metadata. Implement the supported Elixir grammar accurately and reject unsupported syntax explicitly; do not normalize invalid grammar into a different policy.

6. **P2 — Explicit prerelease policies differ from actual Elixir semantics.** `compatibility.rs:229-230`: unconditional prerelease refusal returns false for `1.2.3-dev` against `== 1.2.3-dev` or `>= 1.2.3-dev`. Actual installed `Version.match?(..., allow_pre: false)` returns true in both cases. Plain stable ranges still exclude prereleases. Root expressly ruled actual source/oracle parity authoritative and corrected the broad prerelease shorthand in the brief/ledger. Implement comparator-aware prerelease behavior with oracle cases.

7. **P2 — Pessimistic upper bounds can panic.** `compatibility.rs:183,191`: `~> 18446744073709551615.0` parses into u64 then unchecked `major + 1` panics in debug and wraps in release. Equivalent minor overflow exists. Installed Elixir rejects that policy. Validate representable version/policy limits and use checked increments, returning a structured error rather than panic/wrap.

8. **P2 — Repeated dismiss reverses the dismissal.** `crates/trenino-runtime/src/firmware/updates.rs:171-177`: dismiss calls notice, which suppresses the already-dismissed notice. The second identical dismiss consequently persists None and makes the same notice visible again. Derive identity independently from visibility or leave existing dismissal unchanged when no notice exists; repeated UI events/retries must be idempotent.

## Verification evidence

- Standalone rustc harness importing real compatibility.rs demonstrated malformed-policy acceptance, valid build-metadata requirement rejection, explicit prerelease mismatch, and caught the overflow panic.
- Temporary Elixir scripts used installed Elixir1.20.4/OTP29 and direct `Version.parse_requirement` / `Version.match?` calls. No mix dependencies or application services were started.
- Isolated Cargo harness at `C:/Users/Alberto/AppData/Local/Temp/firmware-supervisor-harness` imports the real firmware module and core crate, excluding hardware/runtime integration. Its `src/lib.rs` retains exact reproductions.
- Run: `cargo test --offline --manifest-path C:/Users/Alberto/AppData/Local/Temp/firmware-supervisor-harness/Cargo.toml --target-dir C:/Users/Alberto/.codex/worktrees/rust-rewrite/tsw_io/target supervisor_ -- --nocapture --test-threads=1` (individual batches were run: first4, redirect1, task1). Six targeted checks passed. Five intentionally assert the observed defects; passing these is reproduction evidence, not product correctness. The sixth positively checks startup/cadence and explicit task cancellation using injected10ms timing.
- A first attempt to compile a temporary workspace test was blocked by hardware writer's transient HandoffPort/DiscoveryHandle edits. The temporary test was removed and the isolated harness used instead. That compile failure is not attributed to firmware.
- Firmware production source and tests were unchanged. No real GitHub/firmware downloads, user database, ports, installers or flashing were touched. No broad unchanged suite was rerun.

## Resume instructions

Read this checkpoint and both independent report files after they are complete. Verify/adjudicate all findings, deduplicate, and write firmware-catalog-supervisor-report.md with final spec/quality verdicts and precise fix requirements. Do not treat this checkpoint as an accepted result.
