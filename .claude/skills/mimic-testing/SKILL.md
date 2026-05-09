---
name: mimic-testing
description: Use when writing Elixir tests that require mocking, stubbing, or expecting function calls on modules. Do not use for standard ExUnit tests that do not need mocking.
---

# Mimic Mocking Library

Do not mock Elixir standard library or OTP modules directly.

## Required Setup

In `test_helper.exs`, **before** `ExUnit.start()`:

```elixir
Mimic.copy(MyModule, type_check: true)  # type_check: true is required, never omit it
ExUnit.start()
```

In test modules:

```elixir
defmodule MyTest do
  use ExUnit.Case, async: true
  use Mimic
end
```

## Core Functions

| Function | Use when | Verified at end? |
|----------|----------|-----------------|
| `expect/4` | Function MUST be called | Yes |
| `stub/3` | Function MAY be called | No |
| `stub/1` | Stub all public functions | No |
| `reject/1` or `reject/3` | Function must NOT be called | Yes |

```elixir
# expect — FIFO queue for multiple calls
Calculator
|> expect(:add, fn x, y -> x + y end)
|> expect(:add, fn _, _ -> :second_call end)

# stub
Calculator |> stub(:add, fn x, y -> x + y end)

# reject
reject(&Calculator.dangerous_operation/1)
```

## Mode Selection

**Private (default — preferred):** Tests can use `async: true`. Each process sees its own mocks.

```elixir
setup :set_mimic_private
setup :verify_on_exit!
```

**Global (use sparingly):** Must use `async: false`. Only owner process can create stubs/expectations. Cannot use `allow/3`.

```elixir
setup :set_mimic_global
```

## Multi-Process

In private mode, use `allow/3` for spawned processes. `Task.async` tasks automatically inherit parent mocks — no `allow/3` needed.

```elixir
Calculator |> expect(:add, fn x, y -> x + y end)
parent = self()
spawn_link(fn ->
  Calculator |> allow(parent, self())
  assert Calculator.add(1, 2) == 3
end)
```

## DSL Mode

```elixir
use Mimic.DSL

test "example" do
  stub Calculator.add(_x, _y), do: :stubbed
  expect Calculator.mult(x, y), do: x * y
end
```

## Constraints

- Can only mock publicly exported functions — arity must match exactly
- Mocking does NOT intercept intra-module calls — use fully qualified `Module.function/n`
- `copy/2` must be called before `ExUnit.start()` for every module to mock

## Common Errors

| Error | Fix |
|-------|-----|
| `Module X has not been copied` | Add `Mimic.copy(X, type_check: true)` to `test_helper.exs` before `ExUnit.start()` |
| `Function not defined for Module` | Check function name and arity |
| `Only the global owner is allowed` | Wrong process in global mode |
| `Allow must not be called when mode is global` | Don't mix `allow/3` with global mode |
