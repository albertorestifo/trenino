# Claude Code Instructions

Trenino is a Phoenix/LiveView app with a Tauri desktop wrapper. It bridges custom hardware controllers to Train Sim World and exposes a local MCP server.

## Commands

```bash
mix precommit   # compile (warnings-as-errors), deps.unlock --unused, format, credo --strict, tests. Rewrites files. Run before committing.
mix test        # run tests (auto-creates and migrates the test DB)
mix setup       # first-time setup: deps, DB, assets
```

## MCP Tools

Tool modules live in `lib/trenino/mcp/tools/`. Use `SequenceTools` as the CRUD pattern, and check `lib/trenino/train.ex` for existing context functions first.

When adding or removing a tool:

1. Update `@tool_modules` in `lib/trenino/mcp/tool_registry.ex` if the module is new or removed.
2. Update the hardcoded tool count in these tests, including the title in `tool_registry_test.exs`:
   - `test/trenino/mcp/tool_registry_test.exs`
   - `test/trenino/mcp/server_test.exs`
   - `test/trenino_web/controllers/mcp/mcp_controller_test.exs`

## Elixir Guidelines

- Pattern match struct types in function arguments: `def process(%MyStruct{} = struct)`.
- Prefer structs over untyped maps. When a map is necessary, document its shape with a typespec.
- Round simulator inputs and outputs, calibration values, notch values and user-facing floats to 2 places: `Float.round(value, 2)`.
- Keep protocol structs atom-based and convert to integers only on the wire. Each message module implements `encode` and `decode_body` with binary pattern matching; dispatch lives in `lib/trenino/serial/protocol/message.ex`.
- GenServers keep their state in a nested `State` struct.
- Define macros only when explicitly requested.

## Tests

- Use `Trenino.DataCase`, `TreninoWeb.ConnCase` or `Trenino.SerialSafetyCase`. Never use bare `ExUnit.Case` for serial or avrdude paths.
- Synchronize with `Trenino.PubSubHelpers.wait_for_subscriber/2`, not sleeps.
