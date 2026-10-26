# Doc-parity completion handoff

> Branch: `codex/rust-rewrite`. Date: 2026-10-26. Orchestrated OMP session.
> Goal: full feature parity of the Rust implementation with the user-facing
> documentation (`docs/`, `DESIGN.md`, `README.md`, `.claude/skills/`).

## Method

1. Baseline green: `cargo test --workspace` 840 passed / 0 failed; svelte-check 0
   errors; `npm --prefix tauri/ui test` 165/165.
2. Eleven read-only verification subagents, one per documentation area, traced
   every documented claim end-to-end (UI → bridge → IPC → runtime → storage) and
   cited file:line evidence. Verdicts: MATCH / DIFF / MISSING / UNVERIFIABLE.
3. Findings triaged; each divergence got a direction decision (fix Rust vs fix doc).
   Direction rule: implement in Rust when the doc promises a feature (goal is
   parity as documented) or when the removed Elixir oracle had it; fix the doc when
   the doc described fiction or the implementation is deliberately equivalent.

## Oracle checks (done by orchestrator)

- `ProviderName` fallback (docs train-configuration.md:154, architecture.md:73):
  never existed in code (git history clean). Actual layers: `CurrentFormation.DrivableIndex`
  → ObjectClass, fallback `CurrentFormation/0.ObjectClass`. → doc fix.
- Button ON/OFF auto-detect (train-configuration.md:273): Elixir DID implement it
  (`configuration_wizard_component.ex:97-137` at commit 046f7b2: on=current_value,
  off=previous_value, 2dp). → Rust feature gap, implement.
- Manual "Set Active" (train-configuration.md:158): no Elixir precedent; doc-promised.
  → implement in Rust.
- Name-based suggestion (`suggest_lever`/`suggest_button`): library-only in both
  Elixir and Rust; docs promise UI wiring (control_auto_suggestion.md User Flow,
  getting-started.md:94). → implement in Rust.

## Difference inventory (all being worked)

### Rust code fixes
- MCP `list_simulator_endpoints` empty path errors instead of root (tools.rs:373-376).
- MCP vJoy `RemoveLeftover`/`Repair` stubbed `runtime_unavailable` while manager
  implements them (storage_ports.rs:1338-1350 + stale comments :28-29).
- Subscriptions: no pre-DELETE before subscribe (subscriptions.rs:373-392);
  stale-Entries risk after restart (TSW_API_GUIDE.md best practice).
- Manual train activation API missing (service + AppServices + reconcile path).
- `suggest_lever`/`suggest_button` no production callers (explorer.rs:173,193);
  need service handlers + IPC.
- Control-detection result must carry current/previous values for button wizard.
- IPC shell: `ui_activate_train`, `ui_suggest_lever`, `ui_suggest_button`,
  `ui_vjoy_status`, `ui_vjoy_remove_leftover`, `ui_vjoy_repair` (rust_ui.rs).
- NSIS uninstall cleans only vJoy device 1; loop markers 1..16 (installer-hooks.nsh).
- UI: Firmware sidebar tab missing (Navigation.svelte); detection modal has no
  listener; Set Active button; wizard suggestion prefill; button on/off suggest;
  nav dot semantics; TrainEdit danger-zone bg.
- UI/a11y: WCAG AA contrast failures in light theme (copper primary 2.7:1, badges),
  dark error text 2.9:1, dark primary 4.1:1; no prefers-reduced-motion; Inter-first
  font stack; EmptyState panel; Firmware card shadow; mono versions; theme switcher.
- Nightly/dev build script included `desktop-updater` feature (nightly.yml uses it);
  FIXED inline: scripts/build-rust-desktop.sh:137 now builds with `--features "rust-ui"`.
  release.yml:208 passes its own features — stable unaffected.

### Doc fixes (docs were wrong; code verified correct)
- train-configuration.md:149 poll 15s → 5s; :154 ProviderName → real two layers.
- architecture.md:73 ProviderName wording; :221 ResourceArbiter detection wording.
- getting-started.md:20 VC++ NSIS-only (MSI passive resource); :110 device 1 → IDs 1–16;
  :65 nav shows "Simulator connected".
- windows-distribution.md:52-53 remove Elixir-era second helper anchor.
- lua-scripting.md:218 actual sandbox set (os partially available, coroutine removed);
  schedule() <1ms rejection note.
- skills/lua-scripting.md:32 api.set returns true (not ok,err).
- control_auto_suggestion.md:85 word-match rung formula + lowercasing note.
- skills/trenino-mcp.md:23 delete_element(id) (was element_id);
  train-setup.md:22 no REST train creation.
- mcp-setup.md tools table: add Scripts row (47 tools, 11 categories); note MCP has
  no interactive control-detection tool.
- TSW_API_GUIDE.md:470-483 nonexistent detect_control_type symbol.
- lever_input_mapping_architecture.md: -0.23 (was -0.22), 0.51 (was 0.515), half-open
  notch ranges, inverted-lever subsection, emergent dead zones, range-capture sketch.
- DESIGN.md aligned to implementation (alerts inline, modal widths, dropdown, type
  scale, breadcrumbs, tokens updated with the AA fixes).

## Wave status (see git diff / agent transcripts)

- Wave 1 dispatched: `FixBackendRuntime` (runtime fixes + tests),
  `FixFrontendDesign` (CSS/a11y + vJoy recovery UI + theme + DESIGN.md),
  `FixDocs` (all doc corrections). Inline build-script fix DONE.
- Wave 2 dispatched: `FixFrontendFeatures` (bridge + nav + modal + Set Active +
  wizard prefill). `FixIpcShell` (rust_ui.rs commands + NSIS loop) pending
  `FixBackendRuntime` completion (compiles against new runtime APIs).
- Gate after waves: `cargo fmt --all --check` (fix), `cargo clippy --workspace
  --all-targets -- -D warnings`, `cargo test --workspace`,
  `npm --prefix tauri/ui run check`, `npm test`, `npm run build`,
  `cargo test --manifest-path tauri/src-tauri/Cargo.toml --features rust-ui` and
  `cargo build ... --features "rust-ui desktop-updater"`.
- Re-verification: spawn fresh read-only agents to re-check each fixed claim against
  its doc line.

## IPC contract fixed for wave 2 (already consumed by FixFrontendFeatures)

- `ui_activate_train` { trainId: string } → { ok: boolean; error?: string }
- `ui_suggest_lever` { elementName: string } → { match: { controlPath, endpoints:
  {value,min,max,notchCount,notchIndex}, confidence } | null; error? }
- `ui_suggest_button` { elementName: string } → { match: { controlPath, endpoint,
  confidence } | null; error? }
- `ui_vjoy_status` {} → { state: on|off|needs_setup|needs_cleanup|error, reason|null }
- `ui_vjoy_remove_leftover` {} → { ok, error? }; `ui_vjoy_repair` {} → { ok, error? }
- Event `ui://hardware/detection` payload `{ prompt: string|null }` (emitted today,
  rust_ui.rs:3592-3610); UI modal consumes it.

## Notes for resuming

- Nothing committed; all work is on-disk in this checkout. `git status` shows the
  changes; commit in focused messages if desired.
- Handoff convention: docs/handoffs/<date>-<topic>/README.md + evidence/.
- Agents used were default `task` workers; the harness rejects `model` overrides for
  non-seance agents, so cheap-model dispatch was unavailable.
- Remaining UNVERIFIABLE items (physical hardware / Windows / live TSW) are listed in
  each verification report; they are release gates, not code gaps.

## Final state (session close)

All fixes landed and re-verified. Gates: `cargo fmt --all --check` and
src-tauri fmt clean; `cargo clippy --workspace --all-targets -- -D warnings`
and src-tauri `--features rust-ui` clippy clean; `cargo test --workspace`
848/0; src-tauri `--features rust-ui` 40/0; `--features "rust-ui
desktop-updater"` compiles; svelte-check 411 files 0 errors; vitest 166/166;
frontend production build ok.

Re-verification (fresh read-only agents): 5/5 PASS trains/suggestion/modal;
5/5 PASS vJoy recovery + packaging; 9/9 PASS docs/MCP; design PASS after two
residuals fixed: `::root` → `:root` (font stack was never applied) and the
muted-text sweep — all 181 `text-base-content/{50,60,70}` utilities across 21
svelte files replaced with a theme-aware `.text-muted` token (light solid
oklch(42% 0.012 260) = #494d54, computed 7.99:1 on base-100 / 7.53:1 on
base-200; dark keeps the 70% base-content blend). DESIGN.md label spec updated.
`docs/development.md:243` stale ProviderName line also corrected.

Nothing is committed; all work is on-disk on `codex/rust-rewrite`.
One non-reproducing flake was observed once while two cargo suites ran
concurrently; three sequential full suites after it were green.

Remaining acceptance beyond software parity (unchanged, needs equipment/OS):
live TSW, physical boards/serial, Windows UAC/driver/installer/updater,
real vJoy hardware, NSIS compile of the new 1..16 uninstall loop.

## Feature-reference corpus verification (follow-up, same day)

A remote commit added `docs/feature-reference/` — a 25-file source-grounded
reference of the original Elixir app (the behavioral oracle for the rewrite).
Eight read-only scouts verified the Rust implementation against it:
hardware/serial, firmware, simulator/API/MCP, train controls, scripting,
vJoy, platform/data-model, and all 15 rewrite contracts + journeys J-01..J-05.

Verdict: no Critical regressions; journeys complete; every corpus-documented
Elixir gap either fixed (input-disconnect neutralization, generation-fenced
late completions, held-key release on train switch, output write suppression,
updater interlock, script reload parity, wizard dead-ends, crash-safe firmware
cache) or deliberately preserved with a code comment (momentary repeat
interval, duplicate config_id ambiguity, matrix destructive resize).

Fixed for oracle parity (tests added): apply-ACK deadline 10 s; discovery
accepts stale-request-id IdentityResponse; matrix rename preserves children
(name-only path, `ui_update_matrix` gained optional `name`); empty-dimension
matrices rejected at storage; HT16K33 Configure decode symmetry; manual
disconnect retains last_error; get_device_by_config_id deterministic
(ORDER BY id); firmware check errors carry 'GitHub API error: {status}';
list_devices MCP description accurate; ScriptValue integer/float equivalence
at the trigger change-gate; vJoy enable-failure classification per corpus
table (UAC-cancel → off/needs_setup; creation failure → needs_cleanup only
for Trenino-OWNED compatible devices — foreign devices stay error, guarded by
the pre-existing foreign-selection test); API key file read-error stops TSW6
fallback.

Accepted divergences (deliberate hardening, documented): stricter firmware
manifest acceptance; MCP -32603 on join failure; stricter script POST
validation; health-reason collapse (Ecto-specific distinctions); schedule(<1ms)
rejection; unwired firmware check-interval override; missing unfiltered
update_available helper (no caller).

OPEN PRODUCT DECISION: the error-reporting consent toggle stores consent but
no telemetry transport exists in the Rust app (Elixir wired Sentry). Opting in
sends nothing — privacy-safe, but the settings copy promises crash reports.
Decide: wire a reporter (new dependency + network egress) or keep the
consent-gated no-op with honest copy.

Gates after corpus fixes: workspace 857/0, src-tauri 40/0, both clippy
-D warnings clean, svelte-check 0 errors, vitest 166/166.
