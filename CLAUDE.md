# Claude Code Instructions

## Project Overview

Trenino is a Phoenix/LiveView web app (+ Tauri desktop wrapper) that bridges custom hardware
controllers to Train Sim World via a local MCP server. Key subsystems:

- `lib/trenino/hardware/` — serial port + hardware I/O
- `lib/trenino/simulator/` — Train Sim World simulator client
- `lib/trenino/train/` — domain logic (scripts, sequences, bindings, calibration)
- `lib/trenino/mcp/` — MCP server + tool registry
- `lib/trenino_web/` — Phoenix LiveView UI

## Commands

```bash
mix precommit   # compile (warnings-as-errors) + credo strict + full test suite — run before committing
mix test        # run tests (auto-creates and migrates test DB)
mix setup       # first-time setup: deps + DB + assets
```

## Skills

Project skills live in `.claude/skills/`. Invoke them by name when relevant:

- `/phoenix-liveview` — Phoenix v1.8, LiveView, Ecto, HEEx, forms, streams, Tailwind v4
- `/elixir-patterns` — Elixir core idioms, OTP, GenServer, Mix
- `/mimic-testing` — Mimic mocking library setup and patterns
- `/trenino-mcp` — MCP server interaction and tool usage
- `/train-setup` — Train configuration workflow

## MCP Tools

Tool modules live in `lib/trenino/mcp/tools/`. When adding or removing a tool:

1. Add the module to `lib/trenino/mcp/tool_registry.ex` (`@tool_modules` list)
2. Update the hardcoded tool count in **all three** of these test files:
   - `test/trenino/mcp/tool_registry_test.exs`
   - `test/trenino/mcp/server_test.exs`
   - `test/trenino_web/controllers/mcp/mcp_controller_test.exs`

Use `SequenceTools` (`lib/trenino/mcp/tools/sequence_tools.ex`) as the canonical CRUD pattern.
Context functions live in `lib/trenino/train.ex` — check there before writing new tool logic.

## Elixir Coding Guidelines

### Type Safety

Always pattern match on struct type in function arguments:

```elixir
# Good
def process(%MyStruct{} = struct), do: ...

# Bad
def process(struct), do: ...
```

Prefer structs over untyped maps. When maps are necessary, document shape via typespecs:

```elixir
@type options :: %{port: integer(), timeout: integer()}
@spec connect(options()) :: :ok
```

### Float Value Precision

Round float values to 2 decimal places for simulator inputs/outputs, calibration values, notch values, and any user-facing float data:

```elixir
value = Float.round(raw_value, 2)
```

Apply in: simulator client reads, calibration recording, notch value storage, UI display.

### Protocol Messages

Handle atom-to-integer conversion in encode/decode functions using binary pattern matching — keep the struct API using atoms, the wire format using integers:

```elixir
def encode(%MyMessage{type: :analog}), do: {:ok, <<0x01, 0x00>>}
def encode(%MyMessage{type: :digital}), do: {:ok, <<0x01, 0x01>>}

def decode(<<0x01, 0x00>>), do: {:ok, %MyMessage{type: :analog}}
def decode(<<0x01, 0x01>>), do: {:ok, %MyMessage{type: :digital}}
```
