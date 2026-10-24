# Packaging sync scoped re-review

Date: 2026-10-24. **Verdict: ACCEPTED for local baseline integration and plan/manifest alignment. No blocking findings.** This does not accept the still-unimplemented Rust runtime updater adapter or certify an installed update/release.

Reviewed merge `914fc8118024fa0e5e046af624f26bb956616ecd` and follow-up `f9cb3e201f3c7bee752565646ed6c8a86f347cc8`, plus `packaging-sync-report.md`, `packaging-sync-review.diff`, current plans and ledger. No source edits, child reviews, key access, driver operation, installer staging or publishing were performed. This review report is the only authored file.

## Verified source evidence

- Merge parents are the clean rewrite checkpoint `f7c1c4c` and requested upstream `b324439`; final upstream was integrated, not intermediate MSIX intent.
- Enumerated every path changed in `a1ec201..b324439`. `git diff --exit-code b324439 HEAD -- <all those paths except .gitignore>` returned 0: upstream updater implementation/configuration/locks, signing tools, workflow changes, resources, helper lookup, installer warnings and firmware test isolation are retained unchanged.
- `.gitignore` retains the complete upstream resource ignore list and adds only the rewrite's root/crate target ignores. Existing `.superpowers/` ignore remains. No conflict markers or discarded upstream ignore entries were found.
- Root `Cargo.toml` now excludes `scripts/updater-signature-verifier`. Its manifest and standalone lockfile remain identical to upstream. This is the intended compatibility fix for the new root workspace.
- Updated overview/platform/UI/joystick plans carry the exact upstream SHA and stable native Help updater policy. Searches found no remaining instruction in these plans to implement MSIX or show both legacy application and firmware banners unconditionally in stable desktop builds. MSIX references explicitly reject that route; direct/server legacy app notices remain distribution-dependent. Firmware notification behavior stays independent.
- Platform/runtime steering preserves confirmation, verified download, explicit Rust quiescence acknowledgement, then installation; active firmware flash must block shutdown/installation. It retains output release, worker/serial settlement and SQLite flush/close requirements. The legacy localhost/`BackendExited` handshake is explicitly marked for replacement at runtime integration.
- Installed resource trust, `vJoyInstall.dll` adjacency, selected IDs 1..16, ownership isolation, public-key continuity, signing tests, NSIS/MSI separation and build-time libclang provisioning are carried forward. No architecture regression to all-device acquisition or fixed device 1 was introduced.
- Tracked working tree was clean at review time.

## Validation scope

The implementer/root report root and standalone verifier `cargo metadata --locked --no-deps` checks passing. The full Tauri test invocation remains blocked in `tauri-build` by the absent legacy backend binary; this is accurately recorded and was not bypassed with placeholder resources.

Root subsequently compiled the actual `tauri/src-tauri/src/update_flow.rs` directly with `rustc --edition=2021 --test` and reported all five sequencing tests passing. This supersedes the earlier report's narrower statement that those unit tests remained unverified. It verifies the generic source sequencing tests only; it does not prove the Tauri plugin integration, packaged resources or Rust quiescence implementation. No redundant test build was run during this scoped source re-review.

## Remaining gates

Continue normal controls/storage/UI review work against its existing scoped commits. Before desktop cutover, implement and verify the Rust updater lifecycle adapter, distribution-aware frontend behavior, clean CI libclang provisioning and extracted resource probes. Before release, complete the previously documented signed-artifact/metadata and disposable-Windows update/data/driver-preservation evidence. The local packaging integration itself is complete and accepted.
