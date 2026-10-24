# Independent firmware catalog correctness review

Reviewed the committed firmware slice `8723455..f79f41e` on `codex/rust-rewrite`. Firmware sources were clean in the working tree. This review covers the core/runtime firmware modules only. The shared storage adapter, startup/UI wiring, and flashing are separate gates.

## Findings

### P1 — Explicit prerelease requirements reject valid releases

- **Source:** `crates/trenino-core/src/firmware/compatibility.rs:229-231`.
- **Evidence:** `FirmwareRequirement::matches` returns `false` for every prerelease whenever a requirement is configured, before evaluating any comparator. With Elixir 1.20.4, `Version.match?("1.2.3-rc.1", Version.parse_requirement!(">= 1.2.3-rc.1"), allow_pre: false)` returns `true`; so do `== 1.2.3-rc.1` for the exact version and `~> 1.2.3-rc.1` for the range start. Rust returns `false` for all three. The legacy `Trenino.Firmware.Compatibility` delegates directly to this Elixir call.
- **Impact:** A configured policy that explicitly admits a prerelease makes it unavailable for selection and latest-compatible lookup.
- **Required fix:** Match Elixir's comparator-specific prerelease behavior rather than applying a global prerelease veto. Add oracle-backed cases for explicit prerelease bounds and ordinary ranges that continue to exclude prereleases.

### P1 — Requirement parser silently changes policy meaning

- **Source:** `crates/trenino-core/src/firmware/compatibility.rs:166-175, 201-209, 247-260`.
- **Evidence:** Elixir `Version.parse_requirement/1` accepts bare `"1.2.3"` as exact equality, while Rust rejects it because no operator prefix exists. Conversely Elixir rejects `"= 1.2.3"`, `">= 1.2"`, and `">= 1.0.0, < 2.0.0"`; Rust accepts them, translating `=` to equality, extending a two-part comparison with `.0`, and treating comma as `and`. The oracle also accepts `!= 1.2.3` (deprecated), which Rust rejects. These inputs were checked with installed Elixir 1.20.4 / OTP 29.
- **Impact:** Valid configuration can fail startup, while invalid configuration is silently reinterpreted instead of being rejected. The latter can change which firmware is selectable.
- **Required fix:** Support valid Elixir syntax needed by the application, including bare exact versions. Reject syntax outside the implemented subset explicitly; remove the `=`/comma/two-part comparison reinterpretations. If `!=` is intentionally unsupported, return `UnsupportedSyntax` as an explicit policy limitation.

### P1 — A damaged expected cache entry cannot be repaired

- **Source:** `crates/trenino-runtime/src/firmware/downloads.rs:118-119, 168-171`.
- **Evidence/reproduction:** For a known four-byte asset, place a two-byte regular file at `cache_path(selection)`. `valid_cache` correctly refuses it, and the downloader can retrieve and fully validate a fresh four-byte partial. It then sees `destination.exists()` and returns `LengthMismatch`, deleting the good partial and retaining the bad file. Every retry follows the same path. The delivery report acknowledges this limitation.
- **Impact:** One interrupted, damaged, or stale cache file permanently prevents use of that release/environment until a user manually removes it.
- **Required fix:** Atomically replace only the expected cache entry after the new file is complete and validated, or quarantine the invalid entry and publish the valid one with safe rollback. Preserve unrelated files and cancellation cleanup.

### P2 — Cache names diverge from existing production cache

- **Source:** `crates/trenino-runtime/src/firmware/downloads.rs:85-100`.
- **Evidence:** Legacy `lib/trenino/firmware/file_path.ex` writes `"v#{version}_#{identifier}.hex"`; the Rust path writes `"{version}_{identifier}.hex"`. The catalog strips `v` from the release tag at `catalog.rs:229-230`, so a legacy `v2.2.1_uno.hex` is looked up as `2.2.1_uno.hex`.
- **Impact:** Previously downloaded firmware is not reusable offline after migration, despite the required production cache convention and offline-cache behavior.
- **Required fix:** Use the legacy `v` prefix for the canonical cache path, and test reuse of a pre-existing legacy cache entry without network access.

### P2 — Dismissing an already dismissed notice makes it reappear

- **Source:** `crates/trenino-runtime/src/firmware/updates.rs:162-176`.
- **Evidence/reproduction:** With an outdated connected device, `dismiss(&devices)` stores its key and `notice(&devices)` becomes `None`. Calling `dismiss(&devices)` again computes its key via `notice`, now gets `None`, persists `None`, and clears `dismissed_key`. The next `notice(&devices)` returns the same alert again. This can occur with a repeated or delayed UI dismissal command.
- **Required fix:** Make dismissal idempotent. Compute the current candidate key from connected devices independently of whether it has already been dismissed, or leave the saved key intact when no active notice is returned. Add a repeated-dismissal test, including repository restart.

### P2 — One missing manifest response aborts the entire catalog refresh

- **Source:** `crates/trenino-runtime/src/firmware/catalog.rs:138-147, 244-256`.
- **Evidence/reproduction:** A GitHub release advertising `release.json` whose asset request returns HTTP 404 causes `parse_release` to return `CatalogError::Http`; `refresh` propagates it and never persists valid releases later in the list. A release with no manifest asset is skipped. Legacy `Downloader.fetch_and_parse_manifest` skips a release when the manifest download returns a non-200 response. The delivery contract also says missing/invalid manifests are skipped while transport failures are returned.
- **Required fix:** Treat a missing manifest response such as 404/410 as a per-release skip, while retaining a catalog-wide error for network failures or server failures according to the chosen failure policy. Add a two-release fake-HTTP case with one missing manifest and one valid release.

## Verification performed

- Inspected all committed firmware core/runtime source, the dedicated tests, the delivery diff and report, and the relevant legacy Elixir implementation and manifest integration fixture. Did not read other reviewer findings.
- Ran a disposable local Elixir oracle script with Elixir 1.20.4 / OTP 29 for prerelease comparator behavior and accepted/rejected requirement grammar. Deleted the script afterward. No network, firmware, hardware, database, or installer access.
- Ran `git diff 8723455..f79f41e --check -- crates/trenino-core/src/firmware crates/trenino-runtime/src/firmware` (passed) and confirmed those firmware paths were clean in the working tree.
- Did not repeat the already-passed broad Rust test runs. The cache, dismissal, and 404 findings are direct code-path reproductions; targeted regression tests remain for the fixes.

## Verdict

- **Scoped specification:** Does not pass yet. The policy matcher diverges from actual Elixir semantics, a bad cache entry is unrecoverable, and existing cached firmware is missed after migration.
- **Quality:** The core boundaries, bounded transfer, selected-release pinning, and explicit repository port are useful foundations, but the listed edge cases need fixes and focused regression coverage before this slice is ready for integration. No finding here is based on the separately gated repository adapter, startup/UI wiring, or flashing.
