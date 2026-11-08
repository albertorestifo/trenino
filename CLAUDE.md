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

## Beta Features

Unfinished features are gated by `Trenino.Beta` (`lib/trenino/beta.ex`). They are always on in dev and test (`config :trenino, :beta_features, :all`), and in releases they follow the "Enable beta features" toggle on the Settings page. The current flags are `:gauges` (stepper-motor gauges) and `:selectors`.

When asked to put a feature behind beta:

1. Add the flag to `@features` and to `@type feature` in `lib/trenino/beta.ex`, with a one-line comment saying what it covers.
2. Add a `beta_<feature>` assign in `TreninoWeb.NavHook.on_mount/4`, and gate LiveView entry points with it: `:if={@beta_<feature>}` on sections, `++ if(@beta_<feature>, do: [...], else: [])` on nav items and option lists. Outside LiveViews, call `Beta.enabled?(:<feature>)`.
3. Gate the feature's MCP tool modules by adding them to `@beta_tool_modules` in `lib/trenino/mcp/tool_registry.ex`. The hard-coded tool counts stay the same, because tests run with every flag on. Update the off-state count in `test/trenino/beta_test.exs` instead.
4. Gate entry points only: UI sections, menu options and MCP tools. Never gate contexts, schemas, GenServers or supervision children, and never call `Beta.enabled?/1` from `Application.start` or `init`, since it reads the database. Data that is already saved keeps working while the flag is off, and the screens for existing records stay reachable.
5. Add off-state tests to `test/trenino_web/live/beta_features_test.exs` or `test/trenino/beta_test.exs`. These tests switch the global mode with `Application.put_env(:trenino, :beta_features, :setting)`, so they are `async: false` and restore the previous value in `on_exit`.
6. Mention the feature in the Settings toggle's description, mark it "(beta)" in the README, and add a CHANGELOG entry.

When asked to take a feature out of beta, remove it from `@features`, delete every `beta_<feature>` and `Beta.enabled?(:<feature>)` match plus its `@beta_tool_modules` entries and off-state tests, then update the Settings description, README and CHANGELOG.

## Elixir Guidelines

- Pattern match struct types in function arguments: `def process(%MyStruct{} = struct)`.
- Prefer structs over untyped maps. When a map is necessary, document its shape with a typespec.
- Round simulator inputs and outputs, calibration values, notch values and user-facing floats to 2 places: `Float.round(value, 2)`.
- Keep protocol structs atom-based and convert to integers only on the wire. Each message module implements `encode` and `decode_body` with binary pattern matching; dispatch lives in `lib/trenino/serial/protocol/message.ex`.
- GenServers keep their state in a nested `State` struct.
- Define macros only when explicitly requested.
- Edit-page sections (hardware configuration and train pages) use `section_group`, `config_section`, `section_action`, `row_actions` and `section_empty` from `TreninoWeb.SharedComponents`; see the "Edit-page sections" block in the phoenix-liveview skill.

## Tests

- Use `Trenino.DataCase`, `TreninoWeb.ConnCase` or `Trenino.SerialSafetyCase`. Never use bare `ExUnit.Case` for serial or avrdude paths.
- Synchronize with `Trenino.PubSubHelpers.wait_for_subscriber/2`, not sleeps.
