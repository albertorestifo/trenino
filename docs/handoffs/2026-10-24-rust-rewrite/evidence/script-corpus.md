# Lua script engine corpus — evidence

Date: 2026-10-25. Track: `wt/d8-lua` (Lua script engine for the Rust rewrite).
Oracle: Elixir app at `lib/trenino/train/script_engine.ex`, `script_runner.ex`,
`test/trenino/train/script_engine_test.exs`, `test/trenino/train/script_context_test.exs`,
and the pinned Lua dependency's actual sources under `deps/lua/` (hex package
`lua` **1.0.2**, mix.lock `f349d1b8`).

Corpus: `crates/trenino-runtime/tests/script_engine_corpus.rs` — **47 tests,
all green** on the real engine (`cargo test -p trenino-runtime --test
script_engine_corpus`). Every test cites its Elixir source. Full crate:
`cargo test -p trenino-runtime` green (all 16 test binaries). macOS arm64
build green (`cargo build -p trenino-runtime`, rustc 1.91.1).

## 1. Engine choice evidence

- The Elixir dependency `lua` 1.0.2 is a **Lua 5.3 VM implemented in Elixir**
  (`deps/lua/README.md`: "Embed a sandboxed Lua 5.3 scripting runtime"; the
  VM sets `_VERSION = "Lua 5.3"`, `deps/lua/lib/lua/vm/stdlib.ex:68`). It is
  not 5.4/5.5/Luau, and the package name must not be trusted over the
  sources (spike-brief instruction).
- Chosen engine: **mlua 0.12.2, features `lua53` + `vendored`** (vendored
  `lua-src` 551.0.2 ⇒ Lua 5.3.6). This matches the oracle dialect exactly —
  integer/float subtype semantics (`math.type`, `3/2 == 1.5`, `7//2 == 3`),
  `_VERSION == "Lua 5.3"` (asserted in `sandbox_surface_matches_oracle`),
  number→string formatting. The task suggestion of "lua54 vendored default"
  was **not** followed: 5.4 would diverge on `_VERSION`, add
  `<close>`/`<const>`/`coroutine.close` the oracle lacks, and buys nothing
  for this port. The predecessor's `Cargo.toml` line (mlua 0.12, lua53,
  vendored) was verified correct and kept unchanged.
- mlua 0.12.2 API audit (from the vendored crate source):
  - `Lua::set_global_hook(HookTriggers::every_nth_instruction, cb)` —
    erroring from the hook propagates through the running Lua code; the
    **global** hook covers coroutine threads (Task 7 requirement).
  - `Lua::set_memory_limit(usize)` — allocator-enforced.
  - **No state snapshot/restore API exists** (grep over mlua-0.12.2/src) —
    this constrains the rollback strategy (§3).
  - `Lua::unsafe_new_with` is required to load the `debug` stdlib at all
    (safe `new_with` refuses it). Used once per VM; the raw debug table is
    immediately replaced by a trimmed table (see §4 sandbox), so no
    script-reachable registry/userdata access remains.

## 2. Corpus coverage ↔ Elixir sources

| Corpus group | Elixir source |
|---|---|
| compile ok / syntax error / top-level code runs, effects discarded | `script_engine_test.exs` "creates VM…", "returns error for invalid Lua syntax"; `script_engine.ex new/1` + `add_side_effect/1` process-dictionary discard |
| event shape (`source`/`value`/`data`, nil→absent keys, 1.0 vs 2) | `script_engine.ex execute/2` + `Lua.encode!/2`; `script_runner.ex fire_script/build_data` |
| output.set (effects, truthiness incl. zero/0.0/""/nil, `trunc`, usage fallback, exact-2-arity with explicit-nil) | `script_engine.ex setup_output/1`, `truthy?/1` |
| display.set (0x70, truncation, usage fallback) | `script_engine_test.exs` "collects display.set side effects"; `setup_display/1` |
| schedule (effect, 0.5→`{schedule, 0}` quirk, usage fallbacks) | `setup_schedule/1` (`is_number(ms) and ms > 0` then `trunc/1`) |
| api.get (placeholder `nil, "not available"` returns, ignored intent, no-arg→`""` path) | `setup_api/1`; Task 7 "api.get placeholder returns and ignored effect" |
| api.set (effect, `[true]`, missing value→nil, value kinds, numeric path→string, table→`Opaque`) | `setup_api/1` |
| print (tab join, nil→"", no-arg→"", table→error like `Protocol.UndefinedError`) | `setup_print/1` + Elixir `to_string/1` semantics |
| ordered effects | `add_side_effect/1` prepend + `Enum.reverse` ⇒ chronological |
| state persistence (counter, upvalues/closures/globals/tables) | `script_engine_test.exs` "state persists between invocations"; `setup_state/1`; spike brief |
| numbers / strings / Unicode / pcall | spike brief "numbers", "strings/Unicode"; `deps/lua` Lua 5.3 semantics; stdlib base globals |
| coroutines absent | `deps/lua/lib/lua/vm/stdlib.ex @libraries` — no coroutine library in the oracle; engine mirrors the absence |
| sandbox (io, coroutine, package, load/loadfile/dofile/require, os.exit…) | `script_engine_test.exs` "sandboxed - no io access"; `deps/lua/lib/lua.ex @default_sandbox` |
| failed-call rollback / timeout rollback | `script_runner.ex execute_script/4` (`{:ok, {:error, _}}` keeps old VM; `Task.yield`+`brutal_kill` @ 200ms); Task 7 state-retention characterization |
| instruction/memory/effect bounds | Task 7 proposed bounds (new, intentional) |
| trigger matching (exact endpoint, enabled-only, no-triggers, dedupe, order, manual/scheduled constants) | `script_runner.ex setup_subscriptions/check_and_fire/maybe_fire_script/handle_cast({:run_script,…})/handle_info({:scheduled_run,…})`; `script_context_test.exs` "returns only enabled scripts"; `train.ex list_enabled_scripts/1`; `script.ex` moduledoc |

## 3. Rollback strategy (Task 7 gate)

Requirement: a failed or timed-out call must leave the **pre-call** VM state
(globals, `state` table, upvalues, closures) — the Elixir engine gets this
for free from immutability (`{:error, _}` discards the new VM; `Task`
brutal-kill leaves the old one).

- mlua has **no faithful snapshot API**, and Task 7 forbids pretending a
  JSON copy of `state` restores closures/upvalues/globals. In-place `pcall`
  cannot roll back mutations either.
- Chosen strategy: **deterministic dual-VM mirror replay**. Every host
  callback in this engine is a pure function of its arguments (api.get
  returns constants; all others return `[true]`/usage tuples), so the VM is
  a deterministic function of (code, event history). The engine keeps two
  state-identical VMs built from the same code with the same RNG seed:
  - `execute` runs the event on the **primary**; its effects are the
    authoritative result.
  - On success the same event is replayed on the **mirror** so both VMs
    advance to the new committed state; the event is appended to a log.
  - On failure the mutated primary is **discarded and the mirror promoted**
    — an O(1) exact rollback of globals, upvalues, closures and tables.
    The lost mirror is rebuilt lazily (fresh compile + log replay) before
    the next call.
  - If a mirror replay or rebuild fails (possible only through
    nondeterministic host state, i.e. `os.time`-dependent scripts) the
    engine flags `rollback_degraded()` and later failures return
    `ScriptError::Rollback` — never a silent divergence.
- Determinism guarantees: per-VM `math.random` replacement (xorshift64*,
  fixed seed — Lua 5.3's C `rand()` is process-global and would desync the
  mirror); pure callbacks; identical build sequence. Remaining
  nondeterminism: `os.time/os.clock/os.date/os.time_ms/os.time_us` (kept for
  oracle library parity) — see gaps.
- Alternative considered and rejected: fork/worker subprocess with
  copy-on-write snapshot — Task 7 permits it, but forking a multithreaded
  host and shipping VM state back is strictly more complex than replay for
  no fidelity gain here, and no blocking native callback exists that an
  instruction hook cannot interrupt (§4).

## 4. Deadline mechanism

- **Global instruction hook** (`every_nth_instruction(512)`) checks a
  wall-clock deadline (`Instant`): 200ms execute (mirrors
  `@execution_timeout_ms`) and 200ms compile (new bound; the oracle hangs
  forever on top-level loops — corpus asserts the new Timeout error).
- Backstop: per-call instruction budget (200M default) behind the wall
  clock (corpus: `instruction_limit_bounds_execution`).
- The hook is the mlua *global* hook, so coroutine threads are covered even
  though the oracle exposes no coroutine library.
- No exposed native callback blocks (all Trenino callbacks return
  immediately; stdlib is vendored Lua), so hook granularity bounds
  interruption latency; per-VM allocator memory limit (16 MiB default)
  bounds runaway allocation (corpus: `memory_limit_bounds_allocation`).
- `debug.sethook`/`gethook` are **stubbed to the oracle's no-op returns**
  (the Elixir debug lib defines them as no-ops), which also prevents a
  script from disarming the deadline hook.
- Effect budget (256/run) and log-message byte cap (8 KiB) are Task 7
  bounds; exceeding the effect budget fails the call explicitly
  (`EffectLimit`) and rolls back.

## 5. Documented divergences (no silent divergence)

1. **New bounds (intentional, Task 7-sanctioned)**: compile wall clock, 16
   MiB memory, 256 effects/run, 8 KiB log messages, instruction backstop.
   The oracle hangs/OOMs/collects unbounded instead. Users see typed errors
   (`Timeout`, `MemoryLimit`, `EffectLimit`, `InstructionLimit`).
2. **Error message text differs** (categories preserved): oracle messages
   look like `Lua runtime error: at <eval>:2: …`; mine carry mlua's
   formatting with chunk name `script`. Corpus asserts category + content
   substrings, mirroring the oracle tests' `{:error, _reason}` assertions.
3. **Extreme float formatting in `print`/paths**: Rust `{:?}` gives
   `1e20`; Elixir `Float.to_string` gives `1.0e20`. Common range
   (`1.0`, `0.5`, `2.5`) is identical; corpus stays in the common range.
4. **`math.random`**: per-VM deterministic xorshift64* (fixed initial
   seed) instead of oracle `:rand` (per-process seeding ⇒ the oracle's own
   sequence is not reproducible run-to-run). Specific sequences were never
   portable; determinism is required for the rollback replay. `math.random`
   argument semantics (0/1/2 args, interval errors) follow Lua 5.3.
5. **`api.set(path, table)`**: oracle records the raw Lua term and fails
   later in the runner when encoding for the simulator; the typed effect
   records `ScriptValue::Opaque` (recorded, not rejected — same
   no-error-at-call-time behavior).
6. **Non-finite numbers**: the oracle represents NaN/±inf as non-number
   atoms, so `output.set(0/0, true)` is a *usage error* and
   `schedule(1/0)` would raise `ArithmeticError` in `trunc/1`; this engine
   treats non-finite floats as non-numbers (usage error) in all such
   checks — same observable behavior for output.set/display.set/schedule,
   and a usage-instead-of-runtime error for `schedule(1/0)`.
7. **`os.time`-dependent scripts**: replay (mirror sync / rebuild) re-runs
   callbacks at a later wall-clock time; time-derived state values inside a
   rolled-back/rebuilt VM can differ by the replay delay. Flagged via
   `rollback_degraded()`; worst case a failure returns `ScriptError::Rollback`
   instead of an exact rollback.
8. **`pairs()` order over string keys**: real Lua seeds string hashing per
   `lua_State`, so iteration order can differ between the primary and a
   rebuilt mirror, while the oracle (Elixir maps) is content-ordered.
   Scripts whose *state* depends on string-key iteration order may observe
   order differences after rollback; values from the primary execution
   remain authoritative. Integer-key/array iteration is unaffected.
9. **Invalid UTF-8 Lua strings** crossing the effect boundary are
   lossily converted (typed `String` effects); the oracle passes raw bytes
   through. Corpus uses UTF-8 only.
10. **`debug` details**: names and stubs match the oracle surface
    (`getinfo`, `traceback`, `get/setmetatable`, `get/setlocal`,
    `get/setupvalue` real; `sethook`/`gethook`/`upvalueid` stubbed); field
    details of `getinfo` tables differ where the oracle reimplemented them
    in Elixir. Registry/userdata access (`getregistry` etc.) is absent, as
    in the oracle.

## 6. Gaps / handoff to wave-2

- Runner concerns intentionally NOT built here (wave-2 per plan Task 7/8):
  200ms polling loop, subscription leases, `last_values` change-only firing
  (the trigger API `matching_scripts` provides the matching half; the
  change-detection half belongs to the runner), newest-first 100-entry log
  ring (`append_log`), schedule-timer replacement semantics, effect
  application to simulator/hardware.
- `ScriptVm` is `!Send` (Rc'd hook/collector state; mlua without the
  `send` feature). The wave-2 worker should own it on one thread.
- Subprocess isolation was not implemented: with pure, non-blocking host
  callbacks plus instruction-hook deadlines and allocator memory limits,
  in-process execution is bounded; revisit only if a future host callback
  can block (Task 7 allows internal worker processes if that changes).
- Storage-level script persistence (scripts table/domain records) is a
  separate track; `ScriptTriggerEntry` is the deliberate loose coupling.

## 7. Reproduction

```bash
cd /Users/alberto/repos/arestifo/trenino-d8-lua
cargo test -p trenino-runtime --test script_engine_corpus   # 47 passed
cargo test -p trenino-runtime                               # all green
cargo build -p trenino-runtime                              # macOS arm64, rustc 1.91.1
```

Dependencies: `mlua 0.12.2` (features `lua53`, `vendored`; brings
`lua-src 551.0.2` = Lua 5.3.6, `cc`, `pkg-config`). No other manifest
changes beyond the predecessor's mlua line (kept verbatim).
