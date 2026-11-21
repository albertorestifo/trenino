# Claude Code Instructions

Trenino is a Phoenix/LiveView app with a Tauri desktop wrapper. It bridges custom hardware controllers to Train Sim World and exposes a local MCP server.

## Commands

```bash
mix precommit   # compile (warnings-as-errors), deps.unlock --unused, format, credo --strict, tests. Rewrites files. Run before committing.
mix test        # run tests (auto-creates and migrates the test DB)
mix setup       # first-time setup: deps, DB, assets
```

## MCP Tools

Tool modules live in `lib/trenino/mcp/tools/`. When adding or removing a tool, follow `lib/trenino/mcp/CLAUDE.md`: several tests hardcode the tool count.

## Beta Features

Unfinished features are gated by `Trenino.Beta` (`lib/trenino/beta.ex`). To put a feature behind beta or take one out, use the beta-features skill. Gate entry points only (UI sections, menu options, MCP tools), never contexts, schemas, GenServers or supervision children. Never call `Beta.enabled?/1` from `Application.start` or `init`, since it reads the database.

## Elixir Guidelines

- Pattern match struct types in function arguments: `def process(%MyStruct{} = struct)`.
- Prefer structs over untyped maps. When a map is necessary, document its shape with a typespec.
- Round simulator inputs and outputs, calibration values, notch values and user-facing floats to 2 places: `Float.round(value, 2)`. Exception: the live lever position and the interpolated value for linear notches keep `LeverMapper.input_precision/0` (4) places, so short notches keep their resolution.
- Keep protocol structs atom-based and convert to integers only on the wire. Each message module implements `encode` and `decode_body` with binary pattern matching; dispatch lives in `lib/trenino/serial/protocol/message.ex`.
- GenServers keep their state in a nested `State` struct.
- Define macros only when explicitly requested.
- Edit-page sections (hardware configuration and train pages) use `section_group`, `config_section`, `section_action`, `row_actions` and `section_empty` from `TreninoWeb.SharedComponents`; see the "Edit-page sections" block in the phoenix-liveview skill.

## Tests

- Use `Trenino.DataCase`, `TreninoWeb.ConnCase` or `Trenino.SerialSafetyCase`. Never use bare `ExUnit.Case` for serial or avrdude paths.
- Synchronize with `Trenino.PubSubHelpers.wait_for_subscriber/2`, not sleeps.
