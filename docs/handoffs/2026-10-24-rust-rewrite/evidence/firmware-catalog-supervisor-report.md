# Firmware catalog supervisor report

Reviewed delivery: `8723455..f79f41e`, branch `codex/rust-rewrite`, workspace `C:/Users/Alberto/.codex/worktrees/rust-rewrite/tsw_io`. Firmware source remained unchanged throughout review. This report aggregates the supervisor's independent audit and two fresh independent Sol/high reviews dispatched by root from unprimed briefs. Neither reviewer read the supervisor findings or the other review.

**Scoped specification: FAIL pending fixes. Quality: FAIL pending fixes.** Ten actionable findings remain: one P1 and nine P2. Cross-asset cache reuse can return the wrong bytes for a pinned selection. Compatibility, cache publication/continuity, redirect handling, missing manifests and dismissal also need targeted fixes before integration. This verdict is for the delivered firmware slice; it does not expand the milestone to separately gated adapters or flashing.

## Scope and positive evidence

The delivered code contains actual catalog HTTP logic, streamed cache downloads, a timer task, a scheduler state owner and an injected repository contract. It is not merely a collection of interface declarations. Manifest-backed selection, supported-programmer filtering while retaining unsupported metadata, distinct local/GitHub asset IDs, selected upload-config cloning, body limits and ordinary partial cleanup are present. Repository writes have no fake-success default. The explicit scheduler cancellation probe passes. The scheduler also stops when its owner is dropped, as adjudicated below.

Shared-worker firmware persistence, Tauri/startup/UI event wiring and flashing remain later gates. They are not findings here. Synchronous repository calls must still be placed off the UI thread when those integrations are implemented; no additional SQLite pool is authorized by this slice. Firmware notices remain separate from native application updates. No review action accessed real GitHub, downloaded actual firmware, opened user databases or COM ports, ran installers or flashed hardware.

## Actionable merged findings

### F1 — P1: Bind cache reuse to the selected asset

**Source:** `crates/trenino-runtime/src/firmware/downloads.rs:85-100`, `:110-119`, `:202-210`.

The final path contains only version/environment; cache validity checks only file type and size. Locks use the local asset row ID rather than the destination, so different assets sharing a path also use different locks.

**Executed reproduction:** download the four bytes `OLD!` for version `1.2.3`, environment `uno`. Clone the selection, change its GitHub asset ID and download URL, retain declared size four, and request it with an offline URL. The second request returns the first file and `OLD!` without contacting the selected asset. Thus refreshed metadata or another selected asset can receive another asset's firmware despite selection pinning.

**Required fix:** bind cached files/publication receipts to selected release and remote asset provenance, and serialize conflicting final destinations. A changed asset must not become a cache hit solely because size and version/environment match. Retain offline reuse for an unchanged, valid association. Do not claim cryptographic authenticity without a supplied trusted digest. Coordinate legacy migration with F2; missing historical provenance must be an explicit limitation/decision rather than silently treated as proof of identity.

**Regression checks:** same path/equal size/different asset identity; unchanged asset offline reuse; concurrent conflicting identities; refreshed selection versus already pinned selection.

### F2 — P2: Preserve the legacy cache filename convention

**Source:** `downloads.rs:98-100`; legacy authority `lib/trenino/firmware/file_path.ex:66-71`.

Legacy paths are `v{version}_{environment-or-board}.hex`; Rust writes `{version}_{environment-or-board}.hex`. Catalog versions have their tag's leading `v` removed at `catalog.rs:230`. An existing `v1.2.3_uno.hex` is therefore invisible to the Rust lookup and forces network access.

**Reproduction:** seed a known valid legacy file under `v1.2.3_uno.hex`, use version `1.2.3` and environment `uno`, and make the fake server offline. Current cache_path points to a different file. Both reviewers independently identified this, and the supervisor checked the exact legacy path function.

**Required fix:** preserve or explicitly recognize/migrate legacy names before attempting HTTP. Combine this with the identity policy in F1; a blanket size-only alias lookup must not reintroduce cross-asset reuse. Test a valid, unambiguous legacy cache association offline and ensure unrelated files are retained.

### F3 — P2: Match actual Elixir prerelease comparator behavior

**Source:** `crates/trenino-core/src/firmware/compatibility.rs:229-231`.

The unconditional configured-prerelease veto runs before all comparators. The legacy application calls `Version.match?(parsed, req, allow_pre: false)`, which has operator-sensitive behavior.

**Executed oracle evidence (Elixir 1.20.4 / OTP29):**

| Candidate | Requirement | Elixir result | Current Rust result |
| --- | --- | --- | --- |
| `1.2.3-rc.1` | `== 1.2.3-rc.1` | true | false |
| `1.2.3-rc.1` | `>= 1.2.3-rc.1` | true | false |
| `1.2.3-rc.1` | `~> 1.2.3-rc.1` | true | false |
| `1.2.3-rc.1` | `< 1.2.3` | true | false |
| `1.2.3-rc.1` | `>= 1.0.0 and < 2.0.0` | false | false |

The last two cases matter: even saying that every stable comparator excludes prereleases would be inaccurate. Root explicitly ruled the actual oracle/source behavior authoritative over the brief's earlier blanket shorthand.

**Required fix:** implement operator- and Boolean-combination semantics backed by an oracle matrix, including equality, strict/inclusive upper/lower bounds, pessimistic ranges and nil policy. Preserve malformed-version refusal. Do not simply allow all prereleases whenever any comparator mentions one.

**Priority adjudication:** both independent reviews rated this P1. The supervisor retains it as a blocking P2 because it is a configured-policy correctness edge, while the P1 cache issue can return wrong bytes. It must still be fixed before this slice passes.

### F4 — P2: Stop reinterpreting malformed requirement grammar

**Source:** `compatibility.rs:166-175`, `:201-209`, `:247-260`.

**Executed oracle/Rust evidence:** Elixir rejects `= 1.2.3`, `>= 1.2`, and `>= 1.0.0, < 2.0.0`; Rust accepts them by treating `=` as equality, appending `.0`, and treating comma as conjunction. Conversely Elixir accepts bare `1.2.3` as exact equality; Rust refuses it. Rust also rejects valid `~> 1.2.3+build.1` and `== 1.2.3+build.1` because its component count includes build-metadata dots.

**Required fix:** accurately parse the supported Elixir grammar. Require complete versions where that operator requires them, preserve two-component pessimistic ranges, support basic exact equality, and count version components separately from prerelease/build metadata. Reject unsupported syntax explicitly rather than normalize it into another meaning. The deprecated `!=` form may remain an explicitly reported UnsupportedSyntax limitation if outside the supported subset; no requirement here forces every deprecated syntax form to be implemented.

**Regression checks:** oracle-backed accepted/rejected grammar table and matching boundaries. The correctness review's P1 rating is normalized to blocking P2 for the same configured-policy reason as F3.

### F5 — P2: Refuse overflowing pessimistic upper bounds

**Source:** `compatibility.rs:181-194`.

**Executed reproduction:** `FirmwareRequirement::parse(Some("~> 18446744073709551615.0"))` panics at `major + 1` in debug; release arithmetic wraps. The minor increment has the corresponding defect. Installed Elixir rejects that policy.

**Required fix:** enforce representable policy/version limits and checked upper-bound arithmetic, returning a structured error. Cover both major and minor maximum values and ensure debug/release behavior is consistent. This is separate from grammar repair because unchecked arithmetic must not remain reachable even after tokenizer changes.

### F6 — P2: Arm partial-file cleanup only after acquiring ownership

**Source:** `crates/trenino-runtime/src/firmware/downloads.rs:127-149` and `:212-227`.

The cleanup guard is armed before HTTP and before create_new succeeds. A preexisting file at the generated PID/sequence name is removed when create_new fails or an earlier request step fails. PID reuse after a crash can collide with an old partial.

**Executed reproduction:** precreate `1.2.3_uno.hex.PID.0.partial` through `.19.partial` in a disposable directory. Run one fresh downloader request in the isolated harness. It errors on create_new and the file count falls from twenty to nineteen, despite never creating or owning the deleted file.

**Required fix:** retry unique names on collision, and install cleanup ownership only after successful exclusive creation. Never delete a path merely because it was the candidate name. Test collision plus HTTP failure/cancellation while preserving all preexisting files.

### F7 — P2: Reject empty firmware before publication

**Source:** `downloads.rs:151-173` versus `valid_cache` at `:202-210`.

**Executed reproduction:** a fake HTTP200 response with an empty body and declared asset size zero returns Ok and publishes a zero-byte final file. Unknown-size empty transfers follow the same branch. The next invocation rejects that very file as an invalid cache entry, so successful publication contradicts the downloader's own usability criterion.

**Required fix:** refuse zero-byte transfers before publication for both known-zero and unknown sizes, return an appropriate typed error, and leave no new partial/final cache file. Preserve unrelated existing files. No firmware-format parser or authenticity claim is required by this finding.

### F8 — P2: Apply URL policy before each redirected request

**Source:** `downloads.rs:129-136`; `crates/trenino-runtime/src/firmware/catalog.rs:118-127`, `:244-253`.

Default reqwest clients follow redirects before send returns. Checking response.url afterwards cannot prevent disallowed contact or a redirect chain that traverses a disallowed target and finishes at an allowed one.

**Executed local reproduction:** an allowed loopback fake endpoint returns a redirect to `http://user:pass@127.0.0.1:PORT/`. A second local listener records receipt of the request. Only afterwards does download return InvalidUrl. No remote target was contacted.

**Required fix:** enforce the initial URL and every redirect hop before following it for release-list, manifest and firmware requests. Use a transport/client boundary whose redirect policy is guaranteed, or resolve bounded redirects explicitly with automatic following disabled. Merely asking future callers to configure the injected client correctly leaves current public behavior unenforced. Preserve appropriate allowed GitHub redirects and existing byte/time bounds.

**Regression checks:** disallowed hop is never contacted; permitted chain succeeds; redirect count/time are bounded; failed redirects leave no owned partial files.

### F9 — P2: Make dismissal idempotent

**Source:** `crates/trenino-runtime/src/firmware/updates.rs:171-177`.

**Executed reproduction:** persist latest2.0.0 with a connected device at1.0.0. First dismiss stores the key and hides the notice. Second identical dismiss calls notice, gets None, persists None, and revives the same notice. A delayed dismissal while devices are disconnected similarly clears the saved key.

**Required fix:** make no-active-notice dismissal a no-op or derive its candidate identity independently of dismissal visibility. Clearing a saved dismissal should require a separate intentional operation. Preserve commit-before-state behavior.

**Regression checks:** repeated dismissal; disconnected dismissal followed by reconnect; scheduler recreation from the same repository; repository dismissal failure leaves the prior state intact; a genuinely new applicable notice remains visible.

### F10 — P2: Skip a missing manifest response without discarding other releases

**Source:** `crates/trenino-runtime/src/firmware/catalog.rs:138-147`, `:253-254`; legacy `lib/trenino/firmware/downloader.ex:129-163`.

A release advertising release.json whose asset returns404 becomes CatalogError::Http, aborting refresh before valid releases are persisted. Absence of the manifest asset itself is already a per-release skip. Legacy manifest-download errors skip that release, and the scoped report promises missing/invalid manifests are skipped while transport failures propagate.

**Code-path reproduction:** serve a release list containing A and B; A advertises a manifest returning404, B has a valid manifest/asset. Current parse_release returns Http for A, and refresh returns before upsert_catalog. This was source-verified, not executed as a Rust HTTP probe during review.

**Required fix:** classify a missing manifest resource (at least404/410) as a per-release missing-manifest outcome. Preserve an explicit failure policy for actual transport errors and server failures. Add the two-release local-server regression, proving B is persisted and A is skipped, plus a transport-error case proving failure remains truthful.

## Rejected or narrowed reviewer findings

**Adversarial finding7, scheduler task survives owner drop: rejected.** Dropping SchedulerTask drops its only watch::Sender. rx.changed then resolves with a closed-channel error, and every select treats that branch as return. Although dropping JoinHandle alone detaches a task, that is not this owner's entire lifecycle. A new focused probe started an indefinitely pending callback, dropped SchedulerTask, and verified the callback's drop guard ran and no second check began. An explicit Drop implementation may improve readability but is not required to fix an observed leak. This probe passed; no production edit was made.

**Correctness finding3, corrupt expected cache must automatically repair: not a blocker under this scope.** The downloader truthfully rejects a known-bad existing destination, preserves it, and removes the newly downloaded partial. The implementation report explicitly documents that refusal. The binding requirement asks truthful corrupt-cache outcomes and preservation of unrelated files; it does not mandate automatic replacement. Therefore no automatic-repair feature is imposed by this review. F1/F2 may naturally require a redesigned publication scheme, and the writer should preserve a deliberate corrupt-cache outcome with regression coverage. Returning an error must remain truthful; automatic quarantine/replacement is a permissible design choice if implemented safely, not an additional acceptance condition invented here.

**No automatic expansion to deferred adapters.** Neither a second persistence pool nor UI/startup/flashing integration is required to close these findings. Actual manifest-driven unsupported-device coexistence is intentional and not a defect. No checksum validation is asserted where actual metadata supplies none.

## Verification and review provenance

Retained independent reports:

- `firmware-catalog-correctness-review.md`
- `firmware-catalog-adversarial-review.md`

Retained own-audit checkpoint: `firmware-catalog-supervisor-checkpoint.md`. The two fresh reviewers used separate unprimed briefs and did not read prior findings. Their reports remain unchanged; this document records adjudication rather than rewriting their evidence.

Supervisor evidence comprises standalone rustc import of the actual compatibility module, installed Elixir oracle scripts, and seven focused local Cargo harness checks: five defect reproductions, explicit timer cancellation, and owner-drop cancellation. The first six were run during the own audit; only the disputed owner-drop check and a small Elixir adjudication matrix were added during aggregation. No broad suite was repeated.

The isolated harness is `C:/Users/Alberto/AppData/Local/Temp/firmware-supervisor-harness`, importing the actual firmware source and core crate while excluding concurrently edited hardware modules. Example command:

`cargo test --offline --manifest-path C:/Users/Alberto/AppData/Local/Temp/firmware-supervisor-harness/Cargo.toml --target-dir C:/Users/Alberto/.codex/worktrees/rust-rewrite/tsw_io/target supervisor_drop_cancels -- --nocapture`

The drop check passed1/1. Earlier four-defect batch passed4/4, redirect reproduction passed1/1, and explicit cancellation check passed1/1. Passing a test that asserts a defect is reproduction evidence, not a product correctness claim. Both independent reviews also ran scoped diff checks successfully. One initial supervisor workspace probe could not compile during unrelated hardware edits; it was removed and replaced by the isolated harness, and is not counted as a firmware failure.

## Required next gate

Implement F1–F10 in the owned firmware paths, add focused regressions reflecting these cases, and return the firmware slice for targeted re-review. Keep migration/asset identity and redirect-client construction decisions explicit. Once those pass, retain the separately documented shared-worker repository, startup/UI and flashing gates; this report does not authorize treating their eventual integration as already verified.

## Scoped fix1 re-review — commit 5eb754c

Reviewed only the original F1–F10 fixes and important regressions introduced by `535b58b..5eb754c` (`firmware-catalog-fix1-review.diff`). Read the writer's appended evidence and explicit legacy opt-in/provenance limitation. No new independent children, broad review or full-suite rerun was performed. Concurrent hardware edits are excluded.

**Verdict: NOT ACCEPTED.** Seven original findings are addressed; F1, F3 and F4 are not fully addressed. F1 additionally introduces a reproducible failed-publication identity mismatch. The remaining work is bounded to the cache and compatibility fixes below.

| Original finding | Fix1 status | Evidence / adjudication |
| --- | --- | --- |
| F1 — asset-bound cache | **NOT ADDRESSED** | Receipts prevent the original simple stale lookup, but replacement mutates a path already returned for a pinned asset. Separate data/receipt replacement can leave new bytes certified by the old receipt. Both reproduced below. |
| F2 — legacy filename | **ADDRESSED** | Canonical path restores `v{version}_{environment-or-board}.hex`. Explicit `AllowUnverifiedMatchingPath` enables offline legacy reuse and reports `LegacyUnverified`; strict default does not pretend a receipt-less legacy file proves asset identity. This is an acceptable explicit migration limitation under the original scope, subject to F1's stable-result fix. |
| F3 — Elixir prerelease semantics | **NOT ADDRESSED** | Individual cited examples now pass, but group-wide same-core admission changes conjunction meaning; local oracle counterexample below. |
| F4 — exact requirement grammar | **NOT ADDRESSED** | Bare equality, malformed `=`/comma/incomplete comparisons and three-component build-metadata cases are fixed. Valid two-component pessimistic requirements with suffixes remain rejected because `.0` is appended after the suffix. |
| F5 — upper-bound overflow | **ADDRESSED** | Both increments use checked_add and return RangeOverflow; focused writer tests cover major and minor overflow. |
| F6 — partial ownership | **ADDRESSED** | create_new succeeds before the guard is armed; collisions retry. Root independently ran the focused collision unit test1/1 after the unrelated compile checkpoint. |
| F7 — empty publication | **ADDRESSED** | Both known-zero and unknown-size empty bodies return EmptyAsset before data/receipt publication; writer regression covers both. |
| F8 — redirect boundary | **ADDRESSED** | A private-client FirmwareHttpClient wrapper enforces the initial URL and each redirect before following, with a fixed redirect limit. Catalog, manifest and download paths require it. Test fixture caveat below should be corrected. |
| F9 — dismissal idempotence | **ADDRESSED** | No active notice is a no-op; writes precede state mutation. Writer tests cover repeated/disconnected dismissal, restart and failed persistence. |
| F10 — missing manifest skip | **ADDRESSED** | 404/410 become MissingManifest; valid later release is retained. Other server errors remain failures; local writer fixtures cover404 and500 outcomes. |

### R1 — P1: Successful replacement changes an already returned selected-asset path

**Source:** `crates/trenino-runtime/src/firmware/downloads.rs:138`, `:233-240`.

The receipt now identifies the currently stored asset, but the returned path is still shared by all assets at the same version/environment. Downloading B atomically replaces the path previously returned for A. Serialization of the download calls does not protect consumers after the call returns.

**Executed local reproduction:** A and B are pinned selections for version1.2.3/uno with distinct GitHub IDs and URLs, both four bytes. Download A=`AAAA`, retain its DownloadResult, then download B=`BBBB`. Both results contain the same path, and reading A's retained result now returns `BBBB`. Concurrent downloads can cause the same mismatch between return and consumer open. The writer's new concurrent test checks only fetched counts and provenance, not that each returned result still names its selected bytes.

**Required fix:** return immutable asset-specific paths/content handles, or an explicit owned lease that prevents replacement until the consumer releases it. Keep legacy naming as a controlled lookup/migration input if needed; it must not force two pinned assets to share a mutable returned object. Add a regression that consumes A's returned result after B completes and still obtains A's bytes.

### R2 — P1: Failed receipt replacement falsely certifies new bytes as the old asset

**Source:** `downloads.rs:233-236`, `:159-165`, `:304-308`.

Data and receipt are replaced with two independent filesystem operations. After data replacement succeeds, receipt replacement can fail, preserving the old receipt beside the new same-sized bytes. A subsequent request for the old selected asset sees ReceiptMatched and returns the new asset's data. The writer report's claim of atomic publication of data and provenance together is therefore false.

**Executed Windows/local reproduction:** download A=`AAAA`; hold A's `.trenino-meta.json` open with `OpenOptionsExt::share_mode(FILE_SHARE_READ)` so it can be read but cannot be replaced. Download B=`BBBB` with another GitHub ID/URL and the same declared length. Its data replacement succeeds, receipt replacement returns CacheIo, and A's old receipt remains. Release the handle and request A again with its original server already gone: the downloader returns `CacheProvenance::ReceiptMatched`, but its file contains `BBBB`.

This can also occur at an interruption between the two replacements; the test uses an ordinary deterministic filesystem failure rather than process termination.

**Required fix:** make data/provenance association crash- and failure-safe. Prefer immutable identity-specific entries with an atomic commit record/pointer, or another protocol that cannot leave an old valid receipt over new bytes. Ensure a failed second publication never permits a false hit for either identity. Retain the original valid entry where possible and keep cleanup restricted to owned files. Add the deterministic receipt-replacement failure regression. A local digest could detect mismatched receipt/data but does not alone resolve R1's already returned mutable path.

### R3 — P2: Conjunctions incorrectly inherit prerelease permission from any same-core bound

**Source:** `crates/trenino-core/src/firmware/compatibility.rs:259-274`.

The new `group.iter().any(|bound| bound.version.same_core(&version))` admits a prerelease to the entire conjunction merely because an upper bound shares its core. It is not equivalent to Elixir's requirement evaluation.

**Executed oracle and Rust comparison:** candidate `1.2.3-rc.2`, requirement `>= 1.0.0 and < 1.2.3`: Elixir1.20.4 `Version.match?(..., allow_pre: false)` returns false; current Rust returns true. The same mismatch occurs for `>= 1.0.0 and <= 1.2.3` and `> 1.0.0 and < 1.2.3`. Explicit prerelease lower-bound requirement `>= 1.2.3-rc.1 and < 2.0.0` legitimately returns true in Elixir and must remain supported.

**Required fix:** use actual operator/conjunction semantics rather than group-wide same-core admission. Extend the oracle-backed tests with these mixed-bound conjunctions and preserve original individual `<`, `==`, `>=`, `~>` examples plus Boolean alternatives. Do not replace this heuristic with another unverified blanket rule.

### R4 — P2: Two-component pessimistic versions append patch after suffix

**Source:** `compatibility.rs:283-294`, particularly `format!("{value}.0")`.

Core component counting now correctly stops before `-` or `+`, but completion adds `.0` to the end of the entire input. `~> 1.2+build.1` becomes the invalid core string `1.2+build.1.0`; `~> 1.2-rc.1` becomes `1.2-rc.1.0`. Both fail FirmwareVersion::parse because their core still has only two components.

**Executed oracle/Rust comparison:** installed Elixir accepts both requirements; for candidate `1.2.3-rc.2`, `~> 1.2+build.1` returns false and `~> 1.2-rc.1` returns true. Current Rust returns an error for both requirements. These are combinations of the advertised supported pessimistic operator, two-component version and suffix syntax, not a request to implement an unrelated deprecated operator.

**Required fix:** insert the missing patch into the core before reattaching prerelease/build suffixes. Add accepted-parsing and matching-boundary tests against the oracle for both forms.

### Focused verification caveat for F8

`crates/trenino-runtime/tests/firmware_catalog.rs` constructs the disallowed target from `target.host_str()` / `download_target.host_str()` and drops the ephemeral listener's port. Consequently the zero-hit listener assertion would still pass if a broken client contacted loopback port80 instead of the counting listener. The production redirect policy is correct by source inspection, so F8 is marked addressed, but change this test to retain the full host-and-port authority and userinfo when constructing the rejected redirect. The original supervisor redirect probe retained the real target port and established non-contact meaningfully. This is a bounded test correction, not another full review gate.

### Fix1 evidence and limits

- Read the scoped fix diff, current touched firmware modules and focused tests, and the appended implementation evidence. Accepted writer/root evidence:7 core compatibility tests,21 runtime catalog tests, strict focused clippy, owned-file format/diff checks, and root's independent partial-file unit test1/1.
- Added only three targeted reproduction checks in disposable `C:/Users/Alberto/AppData/Local/Temp/firmware-fix1-harness`, importing current firmware source and core crate directly. Command: `cargo test --offline --manifest-path C:/Users/Alberto/AppData/Local/Temp/firmware-fix1-harness/Cargo.toml --target-dir C:/Users/Alberto/.codex/worktrees/rust-rewrite/tsw_io/target fix1_ -- --nocapture --test-threads=1`.
- Result:3/3 reproduction checks passed: mutable returned path, failed receipt publication identity mismatch, and compatibility mismatches. These assert the defects, so their pass is not correctness acceptance.
- Ran a small disposable Elixir oracle matrix for the exact conjunction/suffix counterexamples; removed the script. No full suite, real network, firmware, user database, hardware or installer access.
- No production/test source edits. Hardware/runtime concurrent edits are outside this verdict. Shared-worker persistence, UI/startup and flashing remain later gates.

**Next bounded gate:** fix R1–R4 (remaining original F1/F3/F4), correct the redirect fixture authority, and provide focused evidence for those cases. The seven addressed findings do not need a new broad independent review unless their implementation changes.
