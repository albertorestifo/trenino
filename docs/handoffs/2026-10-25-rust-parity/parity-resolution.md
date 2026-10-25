# Resolution of the prior parity audit

This maps the numbered findings in the [historical audit](../2026-10-24-rust-rewrite/evidence/parity-audit.md) to the delivered implementation. The archived audit remains unchanged apart from its superseding notice.

| Audit findings | Resolution |
| --- | --- |
| 1, 7, 11 | Live vJoy input mapping, cache/replay, per-port loss, recovery ladder, mapping reload and midpoint 16384; `vjoy_live`, `vjoy_manager` and configurator tests. Native DLL integration replaces the old bridge handshake; no second bridge process remains. |
| 2, 12 | Owned Lua runner and shared sequence executor, effects through production adapters; timer/poll/log/manual-call ownership and cancellation tests. |
| 3 | Owned simulator connection/health actor with accepted-client identity, retry/reconfigure/disconnect and watch snapshots; stale queued and in-flight IO fenced. |
| 4 | Sequence persistence uses the shared Elixir rounding implementation, pinned by tie regressions. |
| 5, 14, 22 | Manual scan bypasses failed-port backoff, platform-neutral readable serial errors, owned 500ms post-upload rescan. |
| 6 | Trusted root-to-file Windows helper checks, UAC cancellation, registry ownership, explicit selected IDs and bounded job-owned process trees. Portable tests and isolated Windows-source checks passed; actual native execution remains unverified. |
| 8 | Shared executable discovery for installed sibling/resources and explicit absolute overrides; development-only PATH/repository fallback. Failed configured paths do not silently fall back. |
| 9 | MCP returns structured missing-argument errors instead of reproducing an Elixir request crash. This is an intentional compatibility hardening; the legacy tool names/arguments remain available. |
| 10, 18 | Optional GitHub authorization, compatibility selection regressions, manifest-backed registry/filename helpers and real automatic firmware owner/UI notices. |
| 13 | AppServices is the authoritative settings path; the older standalone Settings test surface is not a second production owner. |
| 15–17 | Button-element listing, sequence total duration, ConfigId parsing and formatted I2C address helpers added. |
| 19 | Manifest metadata remains authoritative for upload tooling/board selection; the static legacy board table is intentionally not another mutable authority. |
| 20, 21, 25 | Schema-specific whitespace rules, blank trigger acceptance and grapheme-based display-name limits now match the retained schemas. |
| 23 | ConfigId generation remains bounded to 1024 attempts before returning an explicit error instead of looping forever. Random selection is not a persisted/observable compatibility contract; IDs retain the original valid range and uniqueness checks. |
| 24 | Hardware/scanner lifecycle tests exercise bounded admission, backoff/manual retry and source ownership. Bounded terminal operation history now evicts completed entries instead of exhausting the application after 1024 operations. |
| 26 | Desktop MCP version is explicitly sourced from the desktop package, with actual HTTP initialize coverage. Typed error and trigger representations remain Rust API details; 403 bodies are omitted. The old audit groups several untested edge representations here; these are not claimed as byte-identical error payloads. |
| 27 | Absence of legacy tests is recorded as a confidence limit; it does not excuse omitted runtime integration. New fake-service and actual IPC tests cover the corresponding Rust paths. |

Additional gaps found during implementation were also closed: the legacy JSON REST listener, actual domain-effect composition, atomic mapping save, truthful post-commit acknowledgement, omitted/null IPC patches, concurrent I2C parameter preservation, route-unmount cleanup, firmware automatic notices, and partially resumed controllers under a retained calibration lease. Follow the final reviews in `evidence/` for exact probes and fix verification.
