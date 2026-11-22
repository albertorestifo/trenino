# SimRail connector

Add SimRail as a second simulator next to Train Sim World, behind the `:simrail` beta flag.

## Background

- SimRail has no external API. The TreninoBridge MelonLoader mod (`integrations/simrail/`)
  exposes the player train over HTTP + WebSocket on `http://127.0.0.1:31275`.
  **Read `integrations/simrail/README.md` (the API) and `integrations/simrail/FINDINGS.md`
  (how SimRail trains behave) before writing code.** Per-train data for tests:
  `integrations/simrail/profiles/*.json` (`GET /api/v1/dump`), `sweeps/`, `recordings/`.
- Trenino was TSW-only: callers reached into `Simulator.Connection` and called
  `Simulator.Client` with TSW paths directly. Phase 0 (done, on `feat/simrail-bridge`)
  added the boundary every session builds against:
  - `Trenino.Simulator.Backend` — the behaviour a simulator implements: `id/0`,
    `capabilities/0` (`:push_values`, `:control_catalog`, `:vehicle_events`), `connect/1`,
    `check/1`, `disconnect/1`, `get/2`, `read/2`, `set/3`, `vehicle_id/1`, and optional
    `controls/1` and `watch/3`.
  - `Trenino.Simulator.Backend.TSW` — the TSW adapter (handle = `%Simulator.Client{}`).
  - `Trenino.Simulator` facade — `connected/0`, `current/0`, `supports?/1`, `get/1`,
    `read/1`, `set/2`, `vehicle_id/0`, `controls/0`. **All app code goes through it.**
  - `Trenino.Simulator.Control` / `Control.Position` — a cab control and its notch table
    (`value`, `label`, `stable` = spring-back target, `lower`/`upper` band for smooth levers).
  - `ConnectionState` has `backend` (default `Backend.TSW`); the handle stays in `client`.
    `mark_connecting/3` takes the backend.
  - Watch messages: `{:simulator_values, %{path => value}}` and
    `{:simulator_vehicle, vehicle_id | nil}`.
  - Beta flag `:simrail` in `Trenino.Beta`, `@beta_simrail` assign in `NavHook`.

## Rules for every session

- Branch from `origin/feat/simrail-bridge`, not `master`. Open the PR against
  `feat/simrail-bridge`.
- Stay inside your files (table below). If you need a change in another session's files,
  don't make it: note it in your PR description.
- Don't change the `Backend` behaviour or the facade's existing functions. Adding a
  facade function your work needs is fine; say so in the PR.
- Gate only entry points behind `:simrail` (UI sections, menu options, MCP tools) — see
  `.claude/skills/beta-features`. Never gate contexts, schemas, GenServers or supervisors.
- TSW behaviour must not change. Existing tests must keep passing; adapt stubs from
  `Client.*` to the facade/backend where you migrate a caller.
- Follow `CLAUDE.md`: typed structs, `Float.round(v, 2)` for user-facing floats, nested
  `State` structs in GenServers, Mimic for mocks (`Mimic.copy` in `test/test_helper.exs`).
- Run `mix precommit` before finishing.

## Sessions

| | Session | Owns | Done when |
|---|---|---|---|
| A | **SimRail backend** | new `lib/trenino/simulator/backend/sim_rail.ex` (+ `sim_rail/*` helpers), its tests, `Mimic.copy` lines | `Backend.SimRail` implements every callback incl. `controls/1` (schema → `%Control{}`) and `watch/3` (WebSocket `/api/v1/stream`, reconnects, vehicle events); tested against `integrations/simrail/profiles` fixtures |
| B | **Settings & connection** | `lib/trenino/settings.ex`, `settings/simulator.ex`, `simulator/connection.ex`, `settings_live.ex` | Simulator choice (`:tsw`/`:simrail`), SimRail URL (default `http://127.0.0.1:31275`) and optional token are stored; Connection connects/health-checks through `backend.connect/1` + `check/1` for the chosen backend; SimRail choice gated by `@beta_simrail` |
| C | **Write path** | `train/action_executor.ex`, `train/lever_controller.ex`, `train/button_controller.ex`, `live/.../sequence_manager_component.ex`, `mcp/tools/simulator_tools.ex` | Every write goes through `Simulator.set/2`; TSW-only conventions (`.InputValue` → `.Interacting` for momentary buttons, `control_path` stripping) only apply when `Simulator.current() == :tsw` |
| D | **Read path / watching** | new `lib/trenino/simulator/watcher.ex`, `train/output_controller.ex`, `train/display_controller.ex`, `train/gauge_controller.ex`, `train/script_runner.ex`, `train_edit_live.ex` value detection | One watcher service owns value watching: backends with `:push_values` use `watch/3`, others are polled via `read/2` (replacing the per-controller TSW subscription id ranges); controllers receive `{:simulator_values, ...}` |
| E | **Train identity & lever setup** | `train/detection.ex`, `train/identifier.ex`, `train.ex` (identifier lookup only), a migration, `train/lever_setup.ex`, `mcp/tools/lever_tools.ex`, new `simulator/sim_rail_levers.ex` | Trains/identifiers record their simulator; detection uses `Simulator.vehicle_id/0` (and vehicle events when supported); for `:control_catalog` backends lever setup builds `suggested_notches` from `Simulator.controls/0` notch tables instead of sweeping, handling spring-back (`stable`) and smooth bands |

Merge order: A and B first (they make SimRail connectable), then C, D, E in any order.

## Later (not in these sessions)

- SimRail control picker in the UI (schema-driven instead of TSW's tree browser).
- How hardware maps onto spring-back positions and pulse switches (see FINDINGS.md).
- Bridge packaging/installation for end users; multiplayer testing.
