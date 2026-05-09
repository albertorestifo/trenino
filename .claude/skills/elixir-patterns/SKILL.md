---
name: elixir-patterns
description: Use when writing Elixir modules, functions, GenServers, supervisors, or Mix tasks in this project. Also use when choosing data structures, error handling strategies, or OTP primitives.
---

# Elixir + OTP Patterns

## Core Language

- Lists do not support index-based access via `[]` — use `Enum.at/2`, pattern matching, or `List` functions
- Bind block expression results to a variable — rebinding inside `if`/`case` is lost:

```elixir
# INVALID
if connected?(socket) do
  socket = assign(socket, :val, val)
end

# VALID
socket = if connected?(socket), do: assign(socket, :val, val), else: socket
```

- **Never** nest multiple modules in the same file — causes cyclic dependencies
- **Never** use map access syntax (`struct[:field]`) on structs — use `struct.field` or the struct's API
- No `return` or early returns — last expression is always returned
- `if/else if` does not exist — use `cond` or `case`
- Process dictionary is unidiomatic

## Pattern Matching

- Prefer pattern matching over conditional logic
- Prefer matching in function heads over `if`/`case` in function bodies
- `%{}` matches ANY map — use `map_size(map) == 0` to check for truly empty maps

## Error Handling

- Use `{:ok, result}` / `{:error, reason}` tuples for fallible operations
- Use `with` to chain operations that return `{:ok, _}` / `{:error, _}`
- Avoid raising exceptions for control flow
- Avoid nested `case` — refactor to a single `case`, `with`, or separate functions

## Functions and Naming

- Guard clauses: `when is_binary(name) and byte_size(name) > 0`
- Predicate names end in `?`, never start with `is_` (reserve for guards)
- Descriptive names: `calculate_total_price/2` not `calc/2`
- Only use macros if explicitly requested

## Collections

- Prefer `Enum` functions over manual recursion
- Prepend to lists: `[new | list]` not `list ++ [new]`
- Use `Task.async_stream(collection, callback, timeout: :infinity)` for concurrent enumeration
- **Never** `String.to_atom/1` on user input — memory leak risk

## Data Structures

- Use structs over maps when the shape is known
- Keyword lists for options: `[timeout: 5000, retries: 3]`
- Maps for dynamic key-value data

## Mix Tasks

- Run `mix help task_name` before using any task
- `mix deps.clean --all` is almost never needed — avoid it

## Testing

- `mix test test/my_test.exs` for a file; `mix test path/test.exs:123` for a specific test
- `mix test --failed` to re-run only previously failed tests
- Use `@tag` + `mix test --only tag` for targeted runs
- Use `dbg/1` while debugging

## OTP / GenServer

- Keep state simple and serializable
- Handle all expected messages explicitly
- Use `handle_continue/2` for post-init work
- Prefer `GenServer.call/3` over `cast/2` for back-pressure
- OTP primitives need names in child spec: `{DynamicSupervisor, name: MyApp.MySup}`

## Fault Tolerance

- Design processes to handle crashes and supervisor restarts
- Use `:max_restarts` / `:max_seconds` to prevent restart loops
- Use `Task.Supervisor` for better fault tolerance
- Tasks automatically inherit parent process mocks (Mimic private mode)
