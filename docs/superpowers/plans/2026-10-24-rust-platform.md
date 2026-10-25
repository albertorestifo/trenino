# Rust storage, integrations, and desktop platform plan

**Status:** Proposed migration work packages for review, not authorization to implement.
**Goal:** Replace Elixir/Phoenix infrastructure with Rust services while retaining Tauri and a small TypeScript UI. All application rules stay in Rust.
**Architecture:** Pure types and rules in `crates/trenino-core`; service ownership, persistence and integrations in `crates/trenino-runtime`; thin desktop adapters in `tauri/src-tauri`. Frontend transport DTOs may be generated from Rust; persistence entities are never exposed directly.
**Related plans:** [overview](2026-10-24-rust-rewrite.md), hardware, controls, joystick and UI plans in this directory.

## Scope and current sources

| Functionality | Existing source | Proposed owner |
|---|---|---|
| SQLite, validation, transactions | `lib/trenino/repo.ex`, `lib/trenino/{hardware,train,settings}.ex`, schemas, `priv/repo/migrations` | runtime `storage/`, domain validation in core |
| Data/resource paths | `lib/trenino/paths.ex`, `config/runtime.exs`, firmware paths | runtime `paths.rs` |
| Supervision, startup, shutdown | `lib/trenino/application.ex`, `tauri/src-tauri/src/lib.rs` | runtime `app.rs`, desktop `lifecycle.rs` |
| MCP tool definitions/dispatch | `lib/trenino/mcp/`, controller and tests | runtime `integrations/mcp/` |
| HTTP API compatibility | `lib/trenino_web/router.ex`, `controllers/api/` | runtime `integrations/http/` |
| Consent, settings, API key discovery | settings modules, consent LiveViews/hooks | runtime `settings.rs`, core settings DTOs |
| App updates and diagnostics | `lib/trenino/app_version/`, Sentry configuration | runtime `updates.rs`, `diagnostics.rs` |
| Packaging and CI | workflows, scripts, Tauri configuration/capabilities | existing locations, rewritten after cutover |

Keep Windows and Linux releases; preserve macOS source-build support unless explicitly dropped. No native-widget redesign. No firmware rewrite. WebView runtime remains a Tauri dependency.

## Shared contracts and ownership

Proposed common vocabulary to finalize before implementation:

- `EntityId(i64)` preserves existing SQLite IDs; transport uses decimal strings to avoid JavaScript integer precision loss. Existing HTTP/MCP numeric shapes stay behind compatibility serializers.
- `AppError { code, message, field_errors, retryable }` separates validation, conflicts, not-found, unavailable, cancellation and internal failure. No raw secret-bearing error chains go to UI.
- `OperationId`, `SessionId`, and topic-scoped monotonic `Revision` identify long-running actions and state changes; stale completion cannot mutate a newer session. Include a runtime `Epoch` in subscription envelopes so a process restart cannot make old revisions look newer than fresh state.
- `AppServices` exposes typed domain handles; Tauri, HTTP and MCP use the same service entry points. None writes directly to tables or serial ports.
- `Snapshot<T> { epoch, topic, revision, value }` plus `Change<T> { epoch, topic, revision, value }` support consistent subscriptions. Subscribe/buffer before snapshot, discard older revisions and refresh on gaps or epoch change. Hardware events are not replayed as commands during UI recovery. Unsubscribe stops delivery; cancelling a session is a separate explicit command. Flash operations survive screen unmount/reload.
- `ConfigId` is the firmware/public hardware-route identity, distinct from database `EntityId`/`DeviceId` and transient `ConnectionId`. Preserve existing route tokens and wire values; never reinterpret a configuration route token as a SQLite primary key.
- Persisted mutations publish state changes after commit. Routing replacement across simulator and joystick bindings is one immediate SQLite transaction, with explicit conflict policy and runtime reconciliation after commit.
- Worker tasks have cancellation tokens, join handles, error reporting and bounded restart policies. Failed workers cannot disappear silently. Blocking device/DB work runs outside the UI and async executor threads.
- Shutdown stops admission/pollers, invalidates generations and cancels every effect producer (scripts, scheduled effects, sequences, repeats and calibration sessions) before releasing keyboard/joystick state. Keep adapters alive until bounded cleanup acknowledgements; then terminate/reap flashing children as required by the explicit close policy, close serial ports, stop network adapters and close DB last. An active flash requires an explicit close policy; never silently kill it through ordinary window navigation.
- A shared `InputRouter` resolves wire `(ConfigId, pin, ConnectionGeneration)` to persisted `(DeviceId, InputId)` once. It publishes `SourceEvent { device_id, input_id, connection_generation, sequence, raw_value }` plus explicit source-loss events; unresolved inputs remain diagnostic-only. Configuration replacement/removal invalidates the resolution and old generation before fanout.
- A runtime resource arbiter grants exclusive calibration/flash leases. Hardware and simulator calibration suspend ordinary TSW/vJoy actuation for their leased input/endpoint; flashing cancels affected calibration, announces source loss and neutralizes affected routes before closing the serial worker. Firmware operations retain their lease across bootloader port changes. Resumption requires fresh source samples, never stale cached button state.
- Routing has `desired_revision` (committed DB intent) and `active_revision` (acknowledged runtime routing). Commit precedes a release barrier; if old-output release fails, the input remains suspended/degraded, new routing stays inactive and the UI reports saved-but-not-active. Bounded reconciliation retries the release and activation using fresh generations; it must not undo a newer DB commit or claim the requested revision is active. Test commit-success/release-failure/reconnect explicitly.

## 1. Storage and data migration

**Proposed files:** `crates/trenino-runtime/src/storage/{mod,worker,migrations,hardware,trains,bindings,scripts,settings,firmware}.rs`, `src/paths.rs`, integration tests under `crates/trenino-runtime/tests/storage/`.

**Library choice:** `rusqlite`, with a dedicated owning DB thread and bounded request queue. This fits a local SQLite app and makes transaction boundaries explicit. Do not also introduce SQLx. Enable required backup support and use a pinned supported SQLite build. [rusqlite documentation](https://docs.rs/rusqlite/latest/rusqlite/).

- [ ] Capture schema, indexes, foreign keys, CHECK constraints, enum strings, UTC timestamp formats and JSON representations from migration-produced fixture databases. Export schema fixtures from disposable test databases, never copy an open production DB with raw file-copy alone.
- [ ] Preserve `%APPDATA%/Trenino/trenino.db`, Linux XDG paths and macOS Application Support path, including the existing `DATABASE_PATH` override. Tauri identifier-derived directories are not a drop-in replacement. `POOL_SIZE` is an Ecto implementation detail and is retired with the dedicated Rust DB worker; document this development/deployment change.
- [ ] Define a migration ledger separate from Ecto's `schema_migrations`; never pretend Ecto versions are Rust migration checksums. Recognize the last supported Elixir schema, validate its fingerprint, and baseline the Rust ledger transactionally.
- [ ] Provide fresh database creation and direct migration of supported legacy schemas. Proposed support floor: v0.7.4, matching current release upgrade checks, through current v0.8.0 schema; confirm fixture availability before freezing the floor. Port each required data-transform migration, including train identifier trimming/collision failures, not only final CREATE TABLE statements.
- [ ] Refuse unknown/newer schemas without mutation. Use SQLite backup API for consistent pre-upgrade backups, including WAL content, with free-space/error handling and a recoverable original. Prevent concurrent old/new application writers during migration.
- [ ] Port changeset rules into typed validators, retaining field-level errors, null-versus-empty behavior, cascading deletes, uniqueness and polymorphic I2C/script JSON semantics. Service-level transactions enforce cross-table rules even when requests come through MCP.
- [ ] Publish domain repositories returning owned values; no DB connection or transaction crosses an await boundary. Queue cancellation before execution is safe; cancellation after a transaction begins must not imply it was rolled back. Results carry operation identity and callers reconcile outcome before retrying.

**Acceptance:** fresh DB; v0.7.4/current fixtures; whitespace-colliding train identifiers; missing last identifier; malformed JSON; foreign-key deletes; unavailable path; interrupted migration; full disk; concurrent routing replacement; newer-schema refusal; rollback using backup with original app. Existing database tests remain executable in the legacy build during migration.

## 2. MCP and HTTP compatibility

**Proposed files:** `crates/trenino-runtime/src/integrations/{mod.rs,http/mod.rs,http/serializers.rs,mcp/mod.rs,mcp/legacy_sse.rs,mcp/tools.rs}`, contract fixtures in `tests/fixtures/api/` and `tests/fixtures/mcp/`.

Use Axum as a small loopback integration host, not a UI web server. Preserve the current endpoint/port defaults needed by existing MCP clients; a listener failure must leave the desktop UI usable and show integration status. No automatic second backend instance when the port is occupied.

- [ ] Snapshot the actual registered tool list and schemas from `tool_registry.ex` and all eleven tool modules; do not rely on a hardcoded count in prose. Preserve tool names, input schemas, result text/JSON formatting and failure envelopes.
- [ ] Preserve `GET /mcp/sse`, `POST /mcp/messages?session_id=...`, initial endpoint event, HTTP 202 replies, session errors and protocol negotiation required by existing clients. Clean up disconnected sessions and pending detections; bound queues/request sizes.
- [ ] Port train/script/output/simulator HTTP endpoints, status codes, identifier arrays, JSON timestamps and validation errors using captured fixtures. Tauri invokes Rust directly and does not need this listener for normal screens.
- [ ] Share service authorization/validation and transaction paths between Tauri/MCP/HTTP. User-facing detection prompts are session events plus durable current-state snapshots; cancelling a client/session closes only its own detection operation.
- [ ] Bind loopback only and define accepted Host/Origin behavior for supported local clients. Do not copy unrestricted browser CORS by accident. Document any intentionally tightened access policy as a compatibility change and test configured clients.
- [ ] Keep legacy compatibility adapters separate from a future current MCP transport. The current official `rmcp` README explicitly excludes the old two-endpoint 2024-11-05 transport; adopting it alone would break existing clients. First port the small legacy adapter and tool contracts; add modern transport later if requested.

**Acceptance:** tool-list/schema snapshots; each tool success/validation/not-found/conflict case; multiple SSE sessions; client disconnect during detection; occupied port; malformed JSON/unknown tools; HTTP status/payload golden cases; simultaneous UI/MCP edits produce the same invariants.

Source: [official MCP Rust SDK](https://github.com/modelcontextprotocol/rust-sdk). Its latest transport behavior must be verified against a pinned version at implementation time.

## 3. Settings, consent, diagnostics and updates

**Proposed files:** runtime `settings.rs`, `updates.rs`, `diagnostics.rs`; core settings/update types; tests with local HTTP server and environment/path injection.

- [ ] Retain the three consent states: unset, enabled, disabled. Persist the explicit choice and gate error reporting at send time, including after live revocation. No telemetry before the consent value is known.
- [ ] Preserve simulator URL defaults, manually stored API key precedence, TSW7 discovery with TSW6 fallback, and non-Windows behavior. Never expose API keys in logs or unrestricted snapshots.
- [ ] Port app version checking (5-second initial delay, 24-hour default interval, manual check, dismiss) separately from firmware update behavior. Preserve release tag parsing and notification semantics; this is a release checker, not an instruction to add automatic installation.
- [ ] Use structured Rust tracing and optional consent-gated error reporting. Redact credentials, user paths where appropriate and user script contents from remote diagnostics. Preserve local actionable errors when remote reporting is disabled.

**Acceptance:** unset/disabled/enabled/revoked consent; persisted choice after restart; missing/malformed key file; manual override; malformed release response; offline/retry; dismissed notification; no key/script leakage in captured logs/events.

## 4. Tauri lifecycle and distribution

**Proposed modifications:** `tauri/src-tauri/src/{main,lib}.rs`, new `commands/`, `lifecycle.rs`, capabilities and config; existing `scripts/build-desktop.sh`, Windows packaging scripts, CI/release/nightly workflows.

- [ ] Open the bundled frontend immediately with loading/error status. Initialize DB then services in Rust; remove backend health polling and backend-only splash/server shutdown protocol after parity.
- [ ] Expose narrowly scoped async commands and operation subscriptions. Keep blocking work off the WebView thread. Register only trusted bundled frontend origins; remove backend-spawn permission and review remaining capabilities individually.
- [ ] Prefer one application instance owning hardware/DB with focus-forwarding for a second launch; verify worker-mode dispatch precedes desktop initialization so a joystick worker does not start another UI/runtime.
- [ ] Keep avrdude external and preserve required DLL/config resources. Retain signed vJoy installation, ownership and elevation behavior. Keep WebView2/Linux WebKit prerequisites. A same-executable joystick worker reduces artifacts, not processes.
- [ ] During development keep the legacy app buildable and isolate Rust trial profiles/data/ports; only one implementation owns a physical port or joystick. Do not share a live profile between both implementations.
- [ ] CI builds Rust core/runtime tests, TypeScript checks/UI tests and Tauri packages on Windows/Linux, with macOS compile validation for source support. Keep hardware/driver-mutating tests separate and explicit.
- [ ] Release cutover removes Elixir/OTP, Burrito/Zig requirements attributable to Burrito, Mix assets/release stages and obsolete backend/keyboard artifacts only after all functionality gates pass. Retain Node/frontend build tooling because the user chose TypeScript. Establish one release version source with derived package metadata.
- [ ] Test NSIS and MSI semantics separately, upgrade/uninstall paths, non-ASCII install paths, offline launch, missing dependencies and rollback. Do not advertise MSI driver management unless it is actually implemented.

**Verification commands to implement with these files:** `cargo fmt --all -- --check`; `cargo clippy --workspace --all-targets -- -D warnings`; `cargo test --workspace`; frontend `npm ci`, `npm run check`, `npm test`, `npm run build`; `cargo tauri build` for supported package targets. These are future acceptance commands, not checks executed for this planning-only change.

## Ordering and gates

1. Freeze DTOs, fixtures and migration support floor; establish DB/runtime skeleton.
2. Deliver settings/consent and a read-only profile screen through Tauri.
3. Hardware/controls agents deliver real service slices against the shared repositories.
4. Restore MCP/HTTP alongside the same services, including UI detection prompts.
5. Integrate complete UI, safe shutdown, diagnostics and packaging.
6. Run hardware plus clean-machine upgrade gates, then retire the Elixir distribution.

Open design choices are framework selection for the small TS frontend, legacy DB support floor beyond v0.7.4, and whether a browser-only deployment must remain available. The default proposal preserves desktop Windows/Linux, existing external HTTP/MCP integrations and current UI workflows; it does not add a separately hosted browser application.

## References checked 2026-10-24

- [Tauri IPC](https://v2.tauri.app/concept/inter-process-communication/): commands and lifecycle events.
- [Tauri frontend channels](https://v2.tauri.app/develop/calling-frontend/): ordered progress streams and listener cleanup; channels still require app-level session/revision design.
- [Tauri frontend configuration](https://v2.tauri.app/start/frontend/): bundled static frontend, no Phoenix server requirement.
- [rusqlite](https://docs.rs/rusqlite/latest/rusqlite/): SQLite connections, transaction behavior and feature-selected backup facilities.
- [MCP Rust SDK](https://github.com/modelcontextprotocol/rust-sdk): distinguish modern Streamable HTTP from Trenino's legacy SSE transport.
