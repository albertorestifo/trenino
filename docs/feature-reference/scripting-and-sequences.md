# Lua scripting and reusable command sequences

Baseline `188f35e4108733358730e92ebd98f1912af5173a`; static source/test review, no simulator/hardware actions or tests executed here. This document treats implemented behavior as the rewrite reference and marks gaps where the existing guide or test names imply stronger guarantees.

## Lua records and lifecycle

A Script belongs to a train, with `id`, `train_id`, `name`, `enabled=true`, `code=""`, `triggers=[]`, UTC inserted_at/updated_at. Required train_id/name/code; name length 1..100; unique `(train_id,name)`; FK train. Empty code is the struct default but fails required validation when creating a usable record. Lua syntax and presence of `on_change` are **not** schema validation: arbitrary nonempty code can persist and fail compile/run later. Triggers must be a list of endpoint strings, but blank strings, duplicate paths, nonexistent paths, and an empty list are allowed. There is no code-length or trigger-count validation.

SQLite storage uses `Script.TriggersType`: DB type string containing JSON list. Cast accepts all-string lists or a JSON string decoding to a list; Script changeset separately rejects nonstrings in that decoded list. Dump JSON-encodes a list. Load invalid JSON/non-list as empty list; load nil as empty list; load other types errors. This is not normalized child-table trigger storage.

Train context `list_scripts(train_id)` sorts by name; `list_enabled_scripts` filters enabled (no explicit order); `get_script` returns ok/not_found; `get_script!` raises; create/update/delete use schema changeset. These context methods do **not** call runtime reload. `Train.get_output_by_id` delegates Hardware.get_output, and is used by script output actions. Source: [schema](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/train/script.ex), [trigger type](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/train/script/triggers_type.ex), [Train context](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/train.ex).

`ScriptRunner` is one named GenServer for all active-profile scripts, subscribes **Train detection only**, and on init loads the active train if one exists. Each enabled record gets its own independent Lua VM (`ScriptState.lua`) plus last_values, scheduled_timer, compile_error and log. Reload scripts discards/recompiles **all** enabled scripts for the active train, resets their state/logs, cancels scheduling, and replaces subscriptions. With no active train reload is a no-op. Train change cleans previous state then loads new; nil train cleans all. Disabling/deleting is effective in runner after a reload/profile change. No auto-start `on_change` event is sent merely for compilation/activation.

Runner API: `reload_scripts()` cast, `run_script(id)` cast, `get_script_log(id)` call. Manual run only searches currently loaded enabled scripts of the active train: an existing DB record belonging elsewhere/disabled/unloaded does nothing; a compiled-invalid record also does nothing. Get log for missing script -> []. Public methods assume the runner exists (no guard around GenServer calls/casts).

Sources: [runner](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/train/script_runner.ex), [engine](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/train/script_engine.ex), [guide](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/docs/lua-scripting.md).

## Lua VM and exact host API

`ScriptEngine.new(code)` creates `Lua.new()`, installs the host globals below, initializes `state={}`, then `Lua.eval!` executes the top-level code. It rescues exceptions to `{:error, Exception.message}`. Compilation is not merely parsing: top-level Lua executes in the runner during load. There is **no 200 ms timeout around this creation/eval path**. A top-level infinite loop could block profile loading; the per-callback execution deadline described below does not cover it.

`ScriptEngine.execute(lua,event_map)` initializes a process-dictionary side-effect collector, Lua-encodes event, calls `on_change(event)`, returns `{:ok,updated_lua,effects_in_call_order}` or error message, and clears collector in after. No effects occur inline within Lua; the engine captures intents, and runner performs them only after the callback succeeds. If callback errors or times out, accumulated effects and updated VM are discarded. Calls at Lua top level can collect effects during `new` but they are not returned/executed by that method; put operational actions in `on_change`.

| Lua API | Arguments, return values, and exact effect |
|---|---|
| `api.get(path)` | First argument converted to string; collects `{:api_get,path}`; always returns **nil, "not available"**. Runner ignores the intent: no HTTP read is performed. Use event.value/event.data for trigger data. |
| `api.set(path,value)` | Argument 0 stringified, argument 1 unvalidated term; collects `{:api_set,path,value}`; returns true immediately, before HTTP outcome. Documented numeric type is not enforced by the host callback. |
| `output.set(id,on)` | Exactly two arguments, ID any number -> trunc to integer; on uses Lua truthiness (only false/nil off; **0 is on**); effect output_set; returns true. Invalid shape -> nil and usage string. |
| `display.set(addr,text)` | Exactly two args, numeric address truncated, binary text required; effect display_set; returns true, else nil and usage string. Address is I2C bus address, **not** module DB ID. |
| `schedule(ms)` | Exactly one number >0 -> trunc to integer; collects schedule, returns true, else nil and usage string. Positive fraction <1 truncates to **0**, causing immediate timer scheduling; no maximum enforced. |
| `print(...)` | Stringify arguments, join with tabs; captures log; returns no values. Unsupported Elixir conversion can fail callback. |
| `state` | Mutable Lua table, independent per script VM, retained only through successful callback result; resets on recompilation/profile change/app restart. Other Lua global values/functions also live in that VM. |

The guide calls the VM sandboxed and states require/io/os/file/package are unavailable. Source relies on `Lua.new()` library defaults; it does not explicitly remove these names or implement a second capability/memory/instruction sandbox. A test confirms `io.write` fails. A rewrite should preserve only the intended host capabilities deliberately, with separate tests for forbidden capabilities, rather than claim a complete security boundary from this wrapper alone. There is no explicit memory quota in these modules.

## Trigger subscriptions and events

On profile load gather every enabled script's triggers, build `endpoint_to_scripts` (including duplicates), create one subscription per unique endpoint using IDs **2000 + index**, and retain every endpoint ID even if `Client.subscribe` fails (failure is logged). Compiled-invalid scripts still contribute endpoints. Endpoint map ordering does not define stable IDs. No hard limit prevents >1000 endpoints and overlapping another component's ID convention. ScriptRunner does not subscribe to simulator connection or hardware device events.

Every **200 ms after poll processing**, poll each retained subscription synchronously through Client if simulator globally connected. Nonempty `Entries` list: inspect only first entry's Values map, choose first `Map.values` item (or nil), and compare with per-script last_values[path] using Elixir `!=`. Values remain **raw** (no two-decimal rounding), unlike output/display controllers. NodeValid is **not checked**. Missing Values leads nil; initial nil equals missing cache so does not trigger. Initial false, numeric 0, or any other nonnil value triggers. Changes to other fields in the Values map do not trigger if the selected first value is unchanged. Numeric integer/float equivalents compare equal under `!=`. Poll failures/malformed/empty replies are ignored. Duplicate trigger entries can repeat IDs in endpoint_to_scripts, but after the first successful check updates last_value, the next identical comparison normally skips.

Automatic event is `{"source": "<endpoint>", "value": <first value>, "data": <first entry Values map>}` encoded into Lua. data is **not** the complete HTTP response or complete Entries list despite broad guide wording. Cache updates before executing callback; if the callback fails, the same unchanged trigger will not automatically retry. A future changed value/manual run/timer can execute again.

Manual event: `source="manual",value=nil,data=nil`. Scheduled event: `source="scheduled",value=nil,data=nil`. Neither refreshes all trigger values or supplies the last trigger value; scripts must store it in state if needed for a timer. No “initial”, “train activated”, “disconnect”, “hardware input”, or “button pressed” Lua events are generated here.

## Callback scheduling, errors, and side effects

Runner starts callback with linked `Task.async`, waits/yields **200 ms** and brutally shuts down if still running. Success retains new VM, then processes effects in call order in the GenServer. Runtime errors keep old VM, append `[error] <reason>`; timeout keeps old VM, appends `[error] Script execution timed out (200ms)`. No script auto-disable/backoff is implemented. Compile error stores compile_error string with nil lua; it is logged to application Logger but not added to ScriptState.log, and manual/automatic execution skips it. Compile errors do not stop other scripts loading.

The deadline applies only to `ScriptEngine.execute` in its task. **Side-effect HTTP writes, database lookup, encoding and serial calls run synchronously in runner after the deadline**, so slow operations can block all scripts/polls/timers. Runner executes one callback/effects batch at a time; multiple scripts are not independent workers. Unexpected task process exits are not comprehensively handled by the yield-result case (normal engine exceptions are rescued); this is not a general supervision boundary for all host failures.

| Effect processing | Result/failure semantics |
|---|---|
| log | Prepend message; retain newest **100 entries**; `get_script_log` returns newest first; no timestamps added |
| schedule | Cancel existing timer for this script; `Process.send_after(self(),{:scheduled_run,id},ms)`; last schedule in effect order wins; positive schedule can be triggered by manual/automatic/scheduled callback |
| api_set | If simulator connected, Client.set; failed response logs application warning; disconnected logs warning; no Lua result change, retry, log-console entry or compensation |
| api_get | Ignored; does not read, cache or schedule response |
| output_set | Load **hardware output database ID**, resolve its device config_id to live port, write high/low. Unknown ID warns; disconnected port skips silently. No verification output belongs to active train. |
| display_set | Query all I2C modules each call, choose **first matching numeric I2C address across all devices**, resolve port, encode via HT16K33 and write segments. Missing module warns; disconnected skips. No device argument resolves duplicate addresses. No brightness initialization/minimum clamp/last-text cache from DisplayController. |

Output/display effect return values are ignored by runner. Multiple scripts and binding controllers can write the same output/display; there is no ownership arbitration, merging, or guaranteed final order across processes. A script blink can be overwritten by OutputController, and direct script display text by a DisplayBinding next time it changes/replays. API effect path or type is not validated against discovered writable endpoints.

A script has at most one stored scheduled timer. On delivery runner clears timer pointer then invokes; a callback must schedule again for recurrence. Reload/deactivate cancels known timer. Already queued scheduled messages contain only script_id, **no generation token**; a stale message can run a newly reloaded script with the same ID. The same concern applies when cancel/replace races with timer delivery. There is no schedule cancellation Lua API other than host replacing/canceling timers on lifecycle events.

Cleanup cancels poll/scheduled timers, unsubscribes if a currently connected client is available, and clears VMs/scripts/subscription maps. It **does not** turn off hardware outputs, blank displays, or revert simulator writes performed by scripts. On simulator disconnect, runner has no direct event handler; polling skips while disconnected, timers still fire, logs/state can change, output/display effects can still run. If loaded while disconnected there are no subscriptions; reconnect alone does not create them. If the game lost subscriptions, polling them does not recreate them; caller must reload or change active profile. Contrast DisplayController's explicit simulator reconnect handling.

## Script patterns supported by these contracts

Speed conversion works through a trigger value, e.g. HUD_GetSpeed m/s -> `event.value * 3.6`; a computed display uses display.set. Blinking uses state.on plus schedule, started manually; no-trigger scripts do not auto-start. Debounce stores state.last_value and schedule(500), causing most recent timer intent to replace prior one. A state machine must handle manual/scheduled nil values before comparing numeric fields; guide example predicates that compare event.value > 0 can fail on nil.

The guide's `api.get` limitation is accurate; do not rewrite it as a functioning synchronous read without consciously changing the API. The API hosts return optimistic true, not confirmation of game/hardware delivery. Transaction-like deferred effects apply only up to successful Lua execution: once runner starts processing them, earlier writes remain applied if a later effect fails.

## Script test evidence and gaps

| File | Actual exercised scope in reviewed test body |
|---|---|
| [script_test](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/train/script_test.exs) | Required fields, valid/empty triggers, invalid trigger types, unique name per train |
| [script_context_test](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/train/script_context_test.exs) | CRUD, name ordering, enabled filter, missing ID |
| [script_engine_test](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/train/script_engine_test.exs) | Syntax success/error, event passing, captured api/output/display/schedule/log effects, state continuity, runtime exception, io access failure |
| [script_runner_test](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/train/script_runner_test.exs) | **Does not start ScriptRunner**; only creates/retrieves scripts and tests enabled filter through Train context |

There is no runner lifecycle/deadline/timer/reconnect/side-effect delivery proof in that last file, despite its name and comment referring to a proven OutputController pattern. Those details above are source-derived, not runtime verified. Tests are read here, not run during documentation work.

## Reusable sequences and commands

Sequence / table `sequences`: required train_id/name, name length 1..100, FK train, unique `(train_id,name)`, UTC timestamps. `commands` association preloads ascending position. SequenceCommand / `sequence_commands`: required sequence_id, position, endpoint, value; position integer >=0; float value rounded two decimals; `delay_ms` integer default 0, when present 0..60000 inclusive; FK sequence; unique `(sequence_id,position)`. Schema does not validate endpoint existence, writable capability, allowed value range, name/endpoint maximum beyond sequence name, or aggregate duration. Explicit nil delay passes `validate_number` if omitted/nil and is not required; consumers generally expect a number. No command type other than simulator endpoint write is modeled; no read, branching, loops, keyboard or Lua command step.

`Sequence.total_duration` sums command delays, treating nil as 0; unloaded/nonlist commands -> 0. Reported duration **excludes HTTP execution time and scheduling delays**, and includes final command delay. A sequence may be empty and persist successfully.

Context contract:

| Function | Behavior |
|---|---|
| create_sequence(train_id,attrs) | Put atom train_id then changeset insert; callers of this context should use consistent atom keys |
| get_sequence(id) | ok/not_found, commands preloaded sorted |
| get_sequence!(id) | Raises if absent, commands not preloaded |
| list_sequences(train_id) | Sorted name, commands preloaded |
| update_sequence / delete_sequence | Changeset update/Repo.delete; DB cascades remove commands (verified by context tests) |
| set_sequence_commands(sequence,list) | Transaction delete old commands, insert replacements assigning zero-based position from list order; first invalid changeset rolls entire transaction back |
| add_sequence_command(sequence,attrs) | Query max(position) or -1 and append at max+1; no surrounding transaction/serialization; concurrent append can conflict |
| delete_sequence_command(command) | Delete row; does not compact remaining positions |

`set_sequence_commands` and add overwrite atom sequence_id/position in attrs. Unlike button context, these do not normalize string-key attributes before adding atom keys; UI/tools must supply consistent key types or normalize before calling. Command reorder is represented by full list replacement, changing command IDs. Runtime ButtonController snapshots commands into maps at **binding load**; editing a sequence does not update already loaded command snapshots without reload. Multiple buttons can refer to same sequence; schemas only enforce FK, not same-train ownership.

Sources: [Sequence](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/train/sequence.ex), [SequenceCommand](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/train/sequence_command.ex), [context](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/train.ex), [context tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/train_test.exs). UI sequence Test/Run dispatch is described in the UI reference; there is no public Train.execute_sequence API here.

## Execution through button bindings

In sequence mode ButtonController loads on_sequence/off_sequence commands from Train.get_sequence. Press with nonempty on sequence creates an **unlinked spawned process** executing command list. It monitors the controller. The worker checks for controller DOWN before each command, obtains currently connected simulator client for each write, and calls Client.set. Disconnected game or failed command only logs warning and **continues to later commands**. It does not fail fast, retry, roll back previous writes or expose a per-step result/event.

Delay is **after** each command, including final command. Worker waits in a receive for controller DOWN with delay timeout, so ordinary controller death can interrupt waits; brutal exit kills it immediately. At empty list it demonitor/flushes and sends `{:sequence_complete,element_id}`. Controller drops active_buttons[element_id]. A successfully completed sequence does not auto-send off_value; binding on/off values are UI state markers in sequence mode.

Release **always cancels current tracked sequence worker first**, even for latching hardware. For momentary hardware, release only updates button UI/cache; off sequence is not valid. For latching hardware, optional nonempty off sequence spawns another worker; absent/empty off sequence just updates state. An off-only sequence is allowed by schema: press skips; release runs it. Train change/deactivation/reload kill tracked workers and stop future commands; applied commands remain applied. Serial disconnect does not automatically cancel a running sequence.

Duplicate press without intervening release can spawn another worker and overwrite stored PID, leaving the earlier worker untracked; no busy guard prevents it. `sequence_complete` is keyed only by element ID, **not task ID/generation**. Old worker completion can delete tracking for a newer worker, after which release/profile cleanup may not kill it. Tests cover press-release-press cancellation, but not this overlapping duplicate-press case. Completion for a completely absent element ID is harmless.

Runtime source: [ButtonController](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/train/button_controller.ex). [ButtonController tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/train/button_controller_test.exs) verify command snapshot loading, active PID lifecycle, completion, momentary release cancellation, long-delay cancellation, release/press replacement, train deactivation, and stale completion for a missing ID. They do not demonstrate successful game command delivery; much of the fixture environment is disconnected/no-op at transport boundary.

## Rewrite invariants versus open decisions

Implemented invariants: profile-scoped unique script/sequence names; ordered sequence commands; max 60s delay per command; Lua callback state committed only after success; effect order preserved within a callback; per-script one remembered timer; 100-entry newest-first log; fresh trigger data from polling rather than functioning api.get. Required boundaries: simulator connectivity, hardware device config_id->live port resolution, external keyboard helper for button keystrokes, HT16K33 encoder for display actions, and explicit runtime reload after edits.

Decisions exposed by gaps: compile timeout and VM memory limits; strong sandbox tests; late timer/sequence completion generations; reconnect subscription replay; same-profile ownership validation; button duplicate-press behavior; cancellation compensation; script hardware write arbitration; I2C address uniqueness across devices; side-effect delivery errors in console; async writes to avoid all scripts blocking. These are not silently treated as features already present.

See [train controls](train-profiles-and-controls.md), [simulator contract](simulator.md), and [user stories](train-user-stories.md) for connected scenarios.
