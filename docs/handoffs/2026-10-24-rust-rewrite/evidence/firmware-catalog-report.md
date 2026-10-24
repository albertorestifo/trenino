# Firmware catalog, downloads, and updates report

## Delivered

- Core domain API in `crates/trenino-core/src/firmware/{mod,compatibility,manifest}.rs`: validated release manifests, supported and unsupported programmer values, MCU normalization, SemVer parsing, and Elixir-style requirement matching.
- Runtime API in `crates/trenino-runtime/src/firmware/{mod,catalog,downloads,repository,updates}.rs`: injectable GitHub release catalog client, repository port, immutable selected release/environment configuration, bounded streaming downloader, cache path resolution, and cancellable scheduler owner.
- Tests in `crates/trenino-core/tests/firmware_compatibility.rs` and `crates/trenino-runtime/tests/firmware_catalog.rs`.
- `serde_json` was promoted to a normal `trenino-core` dependency because manifest decoding is production code. No new crate or lockfile resolution was needed.
- `pub mod firmware;` registrations in both crate roots were made by the shared manifest owner.

## Public interfaces

- `FirmwareManifest::parse_json` validates required `version`, `project`, `devices`, device fields, upload configuration, safe environment/file components, and version syntax. Unsupported programmer strings parse and remain in catalog records; only `arduino`, `avr109`, `wiring`, `avrisp`, and `usbasp` appear in `FirmwareCatalog::available_devices` or can be selected. `UploadConfig::normalized_mcu` ports `atmega328p` → `m328p`, `atmega32u4` → `m32u4`, and `atmega2560` → `m2560`.
- `FirmwareRequirement::parse(Option<&str>)` supports nil, bare exact versions, `==`, comparison operators, `and`, `or`, and `~>` ranges. `matches` fails closed for malformed versions and follows the oracle-backed operator-sensitive configured-prerelease behavior. Unsupported syntax returns an error.
- `FirmwareCatalog<R: FirmwareRepository>` exposes async `refresh`, persisted `list`, compatible latest release lookup, manifest-backed `available_devices`, and pinned `select`. It fetches the fixed `albertorestifo/trenino_firmware` release API, requires each persisted release to have a valid `release.json`, and associates assets only by exact manifest filename. Releases with unsupported upload protocol or missing assets are retained as catalog metadata but are not selectable. Invalid/missing manifests are skipped; transport failures are returned.
- `FirmwareRepository` is an injected synchronous port. `upsert_catalog` must atomically persist release/file relationships and return stable local IDs; the API carries those as shared `EntityId`s and retains GitHub asset IDs separately. `record_check` and dismissal writes must return only after commit. No SQLite connection, firmware schema adapter, or default fake-success implementation was added.
- `FirmwareDownloader` streams into an exclusively created partial file, limits transfer bytes and concurrency, uses request timeouts, serializes requests by final destination, checks status/length and transfer completion, rejects empty content, removes owned partials on errors/cancellation, and atomically publishes the cache file and provenance receipt. It reuses receipt-matched files offline; explicit legacy reuse is typed as unverified and opt-in. HTTPS is required except for loopback HTTP used by local tests. `cache_directory` preserves production `~/.trenino/firmware_cache` and development `app_dir/priv/firmware_cache`; the filename preserves the legacy `v{version}_{environment-or-board}.hex` convention.
- `FirmwareUpdateScheduler` loads persisted check/dismissal state, applies the 5-second startup, 24-hour cadence, and 1-hour minimum settings, compares connected device versions, and returns a notice keyed by version and outdated shared device IDs. It mutates in-memory status only after repository persistence. `SchedulerTask` owns a cancellable startup/periodic async task.

## Legacy evidence and compatibility oracle

Behavior was read from `lib/trenino/firmware/{downloader,device_registry,compatibility,file_path,update_checker,update_check,firmware_release,firmware_file}.ex` and tests in `test/trenino/firmware/{release_manifest_integration_test,compatibility_test,downloader_test,device_registry_test,update_checker_test}.exs`. The real v2.2.1 manifest fixture includes `sam-ba` and `esptool` devices alongside supported AVR devices; unsupported protocols therefore must not invalidate the whole manifest. Missing `release.json` releases are not catalogued. The device registry must have no static board fallback.

An Elixir oracle script was saved temporarily and run with the installed Elixir 1.20.4 / OTP 29, then removed. Oracle results confirmed `~> 1.2` means `>= 1.2.0` and `< 2.0.0`; `~> 1.2.3` means `>= 1.2.3` and `< 1.3.0`; conjunction and disjunction behave as expected; configured prereleases do not match with `allow_pre: false`; and a leading `v` in a requirement is invalid. The Rust tests cover these boundaries.

## Verification

- `cargo test -p trenino-core --test firmware_compatibility` — 4 passed, 0 failed.
- `cargo test -p trenino-runtime --test firmware_catalog` — 13 passed, 0 failed.
- `cargo clippy -p trenino-runtime --all-targets -- -D warnings` — passed with no warnings.
- `git diff --check` on the firmware-owned paths — passed.
- Both focused runs compiled the registered core/runtime modules without warnings. HTTP tests used only loopback fake servers and temporary directories.

The tests cover required/malformed manifests, unsupported programmers, MCU normalization, leading `v`, nil/configured/pessimistic/disjunctive compatibility, manifest-only device selection, unsupported/missing assets, per-selection upload configuration pinning across refresh, HTTP status, timeout, length truncation, size bounds, cache path validation and environment fallback, offline cache reuse, same-asset concurrent requests, cancellation cleanup, update cadence/rate limiting, persisted dismissal, new-device re-notification, and failed persistence.

## Integration boundaries

- The shared app/storage owner explicitly excluded firmware tables and worker operations from this milestone. Implement a `FirmwareRepository` adapter on the existing single storage worker before enabling production catalog or scheduler writes; keep release and asset row writes transactional, and retain persisted update checks and dismissal across restart.
- Tauri/UI notification/event wiring and app startup registration remain separate integration work. The scheduler API has no implicit persistence fallback or external event publisher.
- Flashing, avrdude, COM ports, real firmware traffic, and hardware behavior were not invoked or tested.
- If a corrupted cache already occupies the expected final filename, the downloader preserves it and returns an error instead of replacing it. Fresh downloads publish via rename after complete transfer.
- Verification was scoped to the two firmware test targets; the full workspace suite was not run.

## Supervisor round 1 fixes (F1–F10)

This section supersedes earlier API and verification statements where the firmware slice changed during the supervisor fix round. The ten adjudicated findings are implemented in the firmware-owned modules and covered by focused regressions.

- **F1/F2 — cache provenance and legacy path:** cache files use the legacy `v{version}_{environment-or-board}.hex` name. A sibling `.trenino-meta.json` receipt binds reuse to the local release identity, GitHub asset ID when present, remote URL, filename, and declared size. Same-destination requests are serialized. The default policy is `LegacyCachePolicy::RejectUnverified`; callers may explicitly opt into `AllowUnverifiedMatchingPath`, which returns `CacheProvenance::LegacyUnverified` only for a valid nonempty file at the exact legacy path with unambiguous selection metadata. Receipts establish metadata association, not cryptographic authenticity; the manifest provides no trusted digest. Same asset reuse remains offline-capable when its receipt matches. Changed remote identity causes a fetch, including for pinned selections.
- **F3/F4/F5 — compatibility:** the Elixir-compatible requirement parser now supports bare exact requirements, `==`, comparisons, `~>` with two or three version components, `and`/`or`, build metadata, and no-space comparison operators. It rejects single `=`, incomplete comparison versions, comma conjunction and unsupported syntax instead of silently changing their meaning. Configured prereleases follow the tested operator and boolean-alternative semantics, including `< 1.2.3` matching `1.2.3-rc.1` and a stable range excluding it. Pessimistic upper-bound addition uses checked arithmetic and returns `RequirementError::RangeOverflow`.
- **F6/F7 — publication safety:** partial files use `create_new`, retry name collisions, and install cleanup ownership only after exclusive creation succeeds. Empty transfers return `DownloadError::EmptyAsset` before publishing either data or receipt. The focused collision test verifies an unowned candidate survives while an owned partial is cleaned.
- **F8 — redirect enforcement:** `FirmwareHttpClient::new(timeout)` builds a reqwest client with automatic redirects constrained at the redirect-policy boundary (maximum five hops; each destination is checked before follow). `get` validates the initial URL. Catalog list, manifest, and firmware requests all require this wrapper. HTTPS and loopback HTTP are allowed; userinfo is rejected. Local regressions cover blocked-hop non-contact, an allowed redirect, bounded loops, and no leftover partial files.
- **F9 — dismissal:** `FirmwareUpdateScheduler::dismiss` is a no-op when no applicable active notice exists; persisted state is written before in-memory state changes. Repeated and disconnected dismissals do not erase a previous dismissal; injected persistence failure leaves the notice available.
- **F10 — missing manifests:** a manifest response of 404 or 410 becomes the per-release `MissingManifest` outcome and is skipped. A valid later release is still upserted. Other non-success status and transport errors still abort refresh, with a 5xx regression proving the repository is not reported as updated.

### Round 1 verification evidence

- `cargo test -p trenino-core --test firmware_compatibility` — 7 passed, 0 failed.
- `cargo test -p trenino-runtime --test firmware_catalog` — 21 passed, 0 failed.
- `cargo clippy -p trenino-core --test firmware_compatibility -- -D warnings` — passed.
- `cargo clippy -p trenino-runtime --test firmware_catalog -- -D warnings` — passed.
- `rustfmt --edition 2021 --check` over the owned core/runtime firmware source and test files — passed.
- The initially stale concurrent-download assertion expected one cache file; after provenance receipts were introduced it was corrected to expect the firmware and its receipt. The focused runtime suite then passed all 21 tests.
- Elixir 1.20.4 / OTP29 oracle checks confirmed the prerelease results and grammar listed above, including `= 1.2.3`, `>= 1.2`, and comma conjunction rejection; both `~> 18446744073709551615.0` and `~> 1.18446744073709551615.0` return errors. These actual oracle outcomes are authoritative; no blanket configured-prerelease ban is applied.

### Persistence and integration contract

`FirmwareRepository` remains an injected synchronous port; no firmware tables or storage adapter were added. Its catalog upsert must commit release rows and their asset associations transactionally and return stable local release/asset entity identities. `FirmwareSelection.release_id` plus the immutable selected asset fields identify the selection. The cache receipt stores the local `release_id` and remote asset ID/URL/name/size; receipt matching is exact. Check records and dismissal writes must return only after commit. UI/startup integration must dispatch synchronous repository work away from the UI thread. Database adapter, scheduler/UI wiring, and flashing remain unintegrated. Verification used local loopback fixtures and temporary directories only.

Root follow-up verification after hardware compile checkpoint: `cargo test -p trenino-runtime --lib partial_file_tests` passed1/1 (create_new collision preserves unowned file). This removes the transient compile blocker noted by the writer; no firmware source edits were made by root.

## Supervisor round 2 fixes (R1–R4 + redirect fixture)

Closes the four findings from the appended 'Scoped fix1 re-review — commit 5eb754c' section and the F8 test-fixture caveat. Semantics were verified against the installed Elixir 1.20.2/OTP29 oracle (`Version.match?/3` with `allow_pre: false`) and the oracle implementation in the installed stdlib `version.ex` (`Requirement.match?/match_op?`).

- **R1 — immutable asset-bound cache paths (P1):** `FirmwareDownloader::cache_path` now returns `v{version}_{environment-or-board}.{key}.hex`, where `key` is a 16-hex FNV-1a-64 digest of the exact provenance a receipt certifies (`asset_key`/`fnv1a64` in `crates/trenino-runtime/src/firmware/downloads.rs`). Distinct remote assets for one version/environment resolve distinct destinations, so publishing a replacement never mutates bytes a consumer already received; the per-destination lock still serializes same-asset requests. Test: `downloading_a_replacement_asset_never_mutates_a_previously_returned_path` (retained A result still reads `OLD!` after B downloads; offline reuse of A stays `ReceiptMatched` at A's path).
- **R2 — failure-safe publication (P1):** data and receipt both live at the asset-bound destination, and a receipt is a pure function of the selection, so the only reachable receipt-replacement failure leaves the previous receipt of that same identity beside freshly fetched bytes of the same identity — never another asset's receipt over those bytes and never a receipt over absent bytes. The legacy `v{version}_{environment-or-board}.hex` name (`legacy_cache_path`) is now a read-only lookup/migration input: exact receipt matches there (pre-asset-bound caches) are reused immutably, and the opt-in `LegacyUnverified` policy/typing is unchanged. Publication order rationale is documented at the rename site. Test: `failed_receipt_publication_never_falsely_certifies_cache_bytes` (a directory squatting the receipt name fails the replacement deterministically on every platform, like the supervisor's held Windows share-mode handle; retries never report a receipt hit, a different asset publishes independently, no partials remain).
- **R3 — per-operator prerelease semantics (P2):** `FirmwareRequirement::matches` in `crates/trenino-core/src/firmware/compatibility.rs` ports the oracle's `match_op?` clauses: `>`/`>=` admit a prerelease candidate only when the requirement operand is itself a prerelease (`admits_prerelease`), while `<`, `<=` and `==` are plain comparisons; the group-wide `same_core` heuristic is deleted. `~>` is kept as a distinct `Bound::Pessimistic` whose upper bound is the Elixir translation `{major+1 | minor+1, 0, 0, pre: [0]}`. Tests: `prerelease_admission_matches_the_executed_elixir_oracle_matrix` (38 executed oracle rows, including the R3 counterexamples `>= 1.0.0 and < 1.2.3` vs `1.2.3-rc.2` → false and `>= 1.2.3-rc.1 and < 2.0.0` → true) plus the preserved `configured_prerelease_matching_follows_elixir_operator_semantics`.
- **R4 — two-component pessimistic suffixes (P2):** `parse_requirement_version` inserts the missing patch into the core before reattaching prerelease/build suffixes (`1.2-rc.1` → `1.2.0-rc.1`), so `~> 1.2+build.1` and `~> 1.2-rc.1` parse and match. Test: `two_component_pessimistic_requirements_with_suffixes_match_the_elixir_oracle`.
- **F8 fixture caveat:** the rejected-redirect fixtures in `crates/trenino-runtime/tests/firmware_catalog.rs` now build the disallowed target by cloning the counting listener's full URL and adding userinfo (`disallowed_with_userinfo`), preserving the ephemeral host-and-port authority, so zero-hit assertions prove non-contact with the real listener. `counted_http` was also hardened to drain the request and close cleanly; true-parallel downloads (distinct destinations no longer share a lock) exposed a reset/close race in the fixture itself (`received unexpected message from connection`, hits=1), which is a fixture defect, not a client defect.

### Round 2 verification evidence

- `cargo test -p trenino-core --test firmware_compatibility` — 9 passed, 0 failed.
- `cargo test -p trenino-runtime --test firmware_catalog` — 22 passed, 0 failed, stable across 8 consecutive runs.
- `cargo test -p trenino-runtime` — fully green (144 tests across all targets: 4+19+22+11+26+6+3+6+24+4+6+13).
- `cargo test -p trenino-core` — fully green (58 tests).
- Elixir 1.20.2/OTP29 oracle matrix executed locally (42 cases incl. all supervisor counterexamples); `version.ex` `Requirement.match?` source read from the installed stdlib. No network beyond loopback fakes, no real firmware, no user data; oracle script removed after use.
