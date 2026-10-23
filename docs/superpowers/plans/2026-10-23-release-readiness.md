# Release Readiness Implementation Plan

> **For agentic workers:** Use superpowers:subagent-driven-development. Work on the assigned task only; the coordinator owns integration and final verification.

**Goal:** Fix release review findings and make new setup flows usable.
**Architecture:** Targeted changes to existing contexts, GenServers and LiveViews.
**Tech Stack:** Elixir, Phoenix LiveView, Ecto/SQLite, Tailwind, Tauri.
**Spec:** docs/superpowers/specs/2026-10-23-release-readiness-design.md

## Global Constraints
- Preserve PRODUCT.md and DESIGN.md style. No publishing, tagging or remote push.
- User authorizes proceeding without confirmation. Work on release/0.8.0-readiness.
- Regression tests first for functional changes. Do not add tests for trivial copy/style edits.
- Do not commit other agents' changes or spawn further agents.
- All Mix test/build invocations use `python3 /tmp/trenino-release-fixes/run_mix.py ...` to serialize shared SQLite/build access.
- Agents run targeted tests; coordinator runs the full suite after integration.

## Review Focus
- Disconnect/crash/late completion must not spin or resurrect stale lever writes.
- Display delivery failure and reconnect must replay unchanged values safely.
- Validation must preserve every display field, including unchecked booleans.
- Offline/no-device/mapping conflicts must have recoverable user-facing behavior.
- Long IDs and narrow viewports must retain usable inputs and action controls.

### Task 1: Runtime reliability
**Files:** lib/trenino/train/lever_controller.ex, display_controller.ex, display_formatter.ex, display_binding.ex; lib/trenino/hardware/configuration_manager.ex; lib/trenino/mcp/tools/button_binding_tools.ex; corresponding tests.
- [x] Reproduce with failing tests: error/skip lever writes avoid hot retry; :DOWN releases pending writer; obsolete writes cannot affect a reloaded profile; display-only device deploys; failed/no-port display write is not cached and stable value replays on reconnect; invalid precision does not raise; MCP destination_conflict returns readable error.
- [x] Implement bounded retry/recovery using existing lifecycle events, preserve latest-value coalescing. Avoid leaked timers/tasks or infinite retries.
- [x] Bound display precision to 0..10; add `DisplayFormatter.validate_format/1` returning `:ok | {:error, String.t()}`; changeset rejects unsupported value-token formats; formatter remains safe for legacy invalid strings. UI task may call this function.
- [x] Correct display deployment and delivery bookkeeping; handle device reconnect and brightness as needed.
- [x] Run targeted tests, self-review, report exact commands/results and limitations.

### Task 2: Display and train setup UX
**Files:** lib/trenino_web/live/components/i2c_module_form_component.ex, display_binding_wizard.ex; lib/trenino_web/live/configuration_edit_live.ex, train_edit_live.ex; relevant LiveView tests. Do not edit runtime files from task 1 or shared nav/core components from task 3.
- [x] Add failing behavioral tests for display settings surviving validation, unchecked values, prerequisites and current-ID entry where supported.
- [x] Render changed embedded parameters correctly; use accessible labels, dialog semantics/focus entry/trap/return/Escape and named edit/delete actions, following existing joystick patterns.
- [x] Rename primary flow Add display; show name/type/address first; show fixed chip as supporting text, reveal brightness/alignment/minimum/dot options under Advanced. Preserve settings when collapsed.
- [x] Make display selection precede endpoint exploration; prerequisites give direct connection/hardware links. Use decimal places by default with advanced custom format and a meaningful live preview. Backend validator interface from task 1: validate_format/1 => :ok | {:error, message}, 0..10 decimals.
- [x] Widen/labell identifier rows; explain prefix matching and source, expose current train ID when connected, protect last required row. Add explicit new-train heading.
- [x] Compact empty sections and provide anchor navigation/grouping for Controls, Displays & lights, Automation; keep narrow-window display binding actions accessible. Avoid large rearchitecture.
- [x] Run focused LiveView tests; report files and verification.

### Task 3: Joystick, navigation and settings UX
**Files:** lib/trenino_web/live/virtual_joystick_live.ex, settings_live.ex; lib/trenino_web/components/nav_components.ex, shared_components.ex; relevant hooks/layouts only if needed; relevant tests. Do not edit task 2 files.
- [x] Add failing behavioral tests for mapping display, offline preview guidance, simulator-independent status and settings feedback.
- [x] Show assigned mappings/capacity with Add mapping action and Axis/Button choice; reveal unused target inventory on demand. No loss of editing or destination replacement behavior.
- [x] Clearly support offline configuration, distinguish unsupported Windows activation, show device-specific disconnected preview instructions and setup link for no eligible inputs.
- [x] Suppress unrelated simulator failure escalation on joystick route.
- [x] Restore narrow-window navigation; prevent update banner overflow; correct skipped shared card headings and layout animation where practical.
- [x] Give platform-specific TSW7/6 key guidance, accurate product name, Save and test connection feedback with existing connection APIs.
- [x] Run focused tests; report verification.

### Task 4: Release metadata, dependencies and integration
**Files:** mix.exs, mix.lock, tauri package/config/Cargo metadata and lockfiles, README.md, CHANGELOG.md, relevant documentation.
- [x] Align application versions to 0.8.0 without tagging/publishing; document new fixes and TSW7 support.
- [x] Inspect current advisory metadata and update compatible affected dependencies; report unresolved exposure without speculative claims.
- [x] Review all task diffs independently; resolve findings with owners.
- [x] Run mix precommit and applicable native tests, then browser screenshots/keyboard/narrow-screen tests. Do not claim Windows hardware tests ran.
