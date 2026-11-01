---
name: mimic-testing
description: Use when writing or fixing Elixir tests in this project that mock, stub, or expect calls on modules, or that touch serial, avrdude, or other hardware paths.
---

# Mimic in Trenino

`Trenino.DataCase`, `TreninoWeb.ConnCase` and `Trenino.SerialSafetyCase` already provide `use Mimic` and private mode. Use one of them; tests without a database that touch serial paths use `SerialSafetyCase`.

## Adding a Mock

- Add `Mimic.copy(Module)` to `test/test_helper.exs`, above `ExUnit.start`.
- Mock project modules and third-party dependencies, not stdlib or OTP modules.
- Mimic does not intercept calls made inside the mocked module itself.

## Hardware Guards

`DataCase.setup_forbidden_serial_stubs/0` stubs `Circuits.UART`, `Avrdude`, `AvrdudeRunner` and `Serial.Discovery` with raising modules from `test/support/forbidden_serial.ex`. To simulate one, override it with `stub/3` or `expect/3`. A new hardware-facing module needs its own forbidden stub.

## Processes

| Situation | Approach |
|---|---|
| `Task.async` from the test process | Inherits mocks |
| A single spawned process | `allow/3` |
| Controllers or GenServers you do not start | `set_mimic_global` in a test module without `async: true` |

## Database Isolation

Async `DataCase` tests get a per-test copy of the SQLite database. `@tag :isolated_repo` gives the same copy without `async: true`.
