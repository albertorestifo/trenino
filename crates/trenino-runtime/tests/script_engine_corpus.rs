//! Corpus of Lua script-engine behaviors encoded from the Elixir oracle.
//!
//! Every test cites the Elixir source that defines the behavior being
//! mirrored:
//!
//! - `lib/trenino/train/script_engine.ex` (engine semantics)
//! - `lib/trenino/train/script_runner.ex` (trigger/rollback semantics)
//! - `test/trenino/train/script_engine_test.exs` (behavioral oracle tests)
//! - `test/trenino/train/script_context_test.exs` (enabled-script filtering)
//! - the pinned Elixir Lua dependency `lua` 1.0.2 (a Lua 5.3 VM implemented
//!   in Elixir; see `deps/lua/lib/lua.ex` sandbox defaults and
//!   `deps/lua/lib/lua/vm/stdlib.ex` installed libraries)
//! - `docs/handoffs/2026-10-24-rust-rewrite/evidence/script-compatibility-spike-brief.md`
//!   (mandated corpus coverage: truthiness incl. zero, numbers,
//!   strings/Unicode, api.get placeholder + ignored intent, api.set /
//!   output.set / display.set / schedule / print conversions and error
//!   behavior, ordered effects, state persistence, globals/upvalues/
//!   closures/tables/coroutines, failed-call/timeout rollback, trigger
//!   evaluation)
//! - `docs/superpowers/plans/2026-10-24-rust-controls.md` Task 7 (intentional
//!   new bounds: compile deadline, memory limit, effect limit)
//!
//! Deviations from the oracle are asserted explicitly here and justified in
//! `docs/handoffs/2026-10-24-rust-rewrite/evidence/script-corpus.md`.

use std::collections::BTreeMap;
use std::time::Duration;

use trenino_runtime::train::script::{
    matching_scripts, ScriptEffect, ScriptError, ScriptEvent, ScriptLimits, ScriptTriggerEntry,
    ScriptValue, ScriptVm, SOURCE_MANUAL, SOURCE_SCHEDULED,
};

// -- helpers --------------------------------------------------------------

fn compile(code: &str) -> ScriptVm {
    ScriptVm::compile(code, ScriptLimits::default())
        .unwrap_or_else(|e| panic!("compile failed: {e}"))
}

fn ev(source: &str) -> ScriptEvent {
    ScriptEvent {
        source: source.to_string(),
        value: ScriptValue::Nil,
        data: None,
    }
}

fn run(vm: &mut ScriptVm, event: &ScriptEvent) -> Vec<ScriptEffect> {
    vm.execute(event)
        .unwrap_or_else(|e| panic!("execute failed: {e}"))
}

fn logs(effects: &[ScriptEffect]) -> Vec<String> {
    effects
        .iter()
        .filter_map(|e| match e {
            ScriptEffect::Log { message } => Some(message.clone()),
            _ => None,
        })
        .collect()
}

fn fast_limits() -> ScriptLimits {
    ScriptLimits {
        execution_wall: Duration::from_millis(2_000),
        compile_wall: Duration::from_millis(2_000),
        ..ScriptLimits::default()
    }
}

// -- new/compile ----------------------------------------------------------

// Mirrors test/trenino/train/script_engine_test.exs "creates VM with valid
// Lua code".
#[test]
fn compile_ok_for_valid_code() {
    let vm = compile("function on_change(event) end");
    let _ = vm;
}

// Mirrors script_engine_test.exs "returns error for invalid Lua syntax".
#[test]
fn compile_error_for_invalid_syntax() {
    let err = ScriptVm::compile("function on_change(event", ScriptLimits::default())
        .expect_err("syntax error expected");
    assert!(matches!(err, ScriptError::Compile(_)), "got: {err:?}");
}

// Mirrors script_engine.ex `new/1`: top-level code executes at load time
// (`Lua.eval!`), so top-level state mutations persist. Oracle: lua 1.0.2.
#[test]
fn top_level_code_runs_at_compile_and_mutates_state() {
    let mut vm = compile("state.booted = true\nfunction on_change(e) print(state.booted) end");
    let effects = run(&mut vm, &ev("test"));
    assert_eq!(logs(&effects), vec!["true".to_string()]);
}

// Oracle behavior: side effects emitted by TOP-LEVEL code are collected into
// the caller's process dictionary and then discarded — `execute/2` resets the
// collector before each run, so top-level effects never surface (see
// script_engine.ex `new/1` + `add_side_effect/1` vs `execute/2`).
#[test]
fn top_level_effects_are_discarded() {
    let mut vm =
        compile("output.set(3, true)\nprint(\"boot\")\nfunction on_change(e) print(\"go\") end");
    let effects = run(&mut vm, &ev("test"));
    assert_eq!(logs(&effects), vec!["go".to_string()]);
    assert!(!effects
        .iter()
        .any(|e| matches!(e, ScriptEffect::OutputSet { .. })));
}

// Intentional new bound (Task 7: "200ms compile deadline"): the Elixir oracle
// compiles with no instruction or wall-clock bound and would hang forever on
// a top-level infinite loop; the Rust engine errors instead. Documented in
// script-corpus.md.
#[test]
fn top_level_infinite_loop_hits_compile_deadline() {
    let limits = ScriptLimits {
        compile_wall: Duration::from_millis(100),
        ..fast_limits()
    };
    let err =
        ScriptVm::compile("while true do end", limits).expect_err("compile deadline expected");
    assert!(matches!(err, ScriptError::Timeout), "got: {err:?}");
}

// -- execute: event shape --------------------------------------------------

// Mirrors script_engine_test.exs "calls on_change with event".
#[test]
fn execute_calls_on_change_with_event_source() {
    let mut vm = compile("function on_change(event) print(event.source) end");
    let event = ScriptEvent {
        source: "test".to_string(),
        value: ScriptValue::Float(1.0),
        data: None,
    };
    let effects = run(&mut vm, &event);
    assert_eq!(logs(&effects), vec!["test".to_string()]);
}

// Mirrors script_engine.ex `execute/2`: `Lua.call_function!(lua,
// [:on_change], ...)` raises when `on_change` is nil, rescued to
// `{:error, reason}`.
#[test]
fn execute_errors_when_on_change_missing() {
    let mut vm = compile("x = 1");
    let err = vm.execute(&ev("test")).expect_err("error expected");
    assert!(
        matches!(&err, ScriptError::Runtime(m) if m.contains("on_change")),
        "got: {err:?}"
    );
}

// Mirrors script_engine.ex `execute/2` + lua.ex `encode!/2` + Lua 5.3 number
// formatting: event.value 1.0 encodes as a float ("1.0"), event.value 2 as an
// integer ("2"). script_engine_test.exs "state persists between
// invocations" accepts "1.0" or "1" because the oracle test is lenient; the
// Rust engine follows Lua 5.3 integer/float distinction exactly like the
// Elixir VM's Lua 5.3 semantics.
#[test]
fn event_value_number_formatting() {
    let mut vm = compile("function on_change(e) print(e.value) end");
    let effects = run(
        &mut vm,
        &ScriptEvent {
            source: "test".into(),
            value: ScriptValue::Float(1.0),
            data: None,
        },
    );
    assert_eq!(logs(&effects), vec!["1.0".to_string()]);

    let effects = run(
        &mut vm,
        &ScriptEvent {
            source: "test".into(),
            value: ScriptValue::Integer(2),
            data: None,
        },
    );
    assert_eq!(logs(&effects), vec!["2".to_string()]);
}

// Mirrors script_runner.ex `fire_script/5` + `build_data/1`: the event carries
// the full subscription "Values" map as `event.data`, or nil.
#[test]
fn event_data_table_and_nil() {
    let mut vm = compile(
        "function on_change(e)\n  if e.data == nil then print(\"nodata\", e.value) else print(e.data.A, e.data.B) end\nend",
    );
    let mut data = BTreeMap::new();
    data.insert("A".to_string(), ScriptValue::Float(0.5));
    data.insert("B".to_string(), ScriptValue::Boolean(true));
    let effects = run(
        &mut vm,
        &ScriptEvent {
            source: "EP".into(),
            value: ScriptValue::Float(0.5),
            data: Some(data),
        },
    );
    assert_eq!(logs(&effects), vec!["0.5\ttrue".to_string()]);

    let effects = run(&mut vm, &ev("EP"));

    // e.value is nil → to_string(nil) == "" (Elixir Kernel.to_string/1).
    assert_eq!(logs(&effects), vec!["nodata\t".to_string()]);
}

// -- output.set -------------------------------------------------------------

// Mirrors script_engine_test.exs "collects output.set side effects".
#[test]
fn output_set_effects() {
    let mut vm = compile("function on_change(e) output.set(3, true) output.set(7, false) end");
    let effects = run(&mut vm, &ev("test"));
    assert!(effects.contains(&ScriptEffect::OutputSet {
        output_id: 3,
        on: true
    }));
    assert!(effects.contains(&ScriptEffect::OutputSet {
        output_id: 7,
        on: false
    }));
}

// Mirrors script_engine.ex `truthy?/1`: only `false` and `nil` are falsy —
// zero, empty string and 0.0 are TRUTHY (Lua truthiness; spike brief
// "truthiness including zero").
#[test]
fn output_set_truthiness_including_zero() {
    let mut vm = compile(
        "function on_change(e)\n  output.set(1, 0)\n  output.set(2, 0.0)\n  output.set(3, \"\")\n  output.set(4, nil)\n  output.set(5, false)\nend",
    );
    let effects = run(&mut vm, &ev("test"));
    assert!(effects.contains(&ScriptEffect::OutputSet {
        output_id: 1,
        on: true
    }));
    assert!(effects.contains(&ScriptEffect::OutputSet {
        output_id: 2,
        on: true
    }));
    assert!(effects.contains(&ScriptEffect::OutputSet {
        output_id: 3,
        on: true
    }));
    assert!(effects.contains(&ScriptEffect::OutputSet {
        output_id: 4,
        on: false
    }));
    assert!(effects.contains(&ScriptEffect::OutputSet {
        output_id: 5,
        on: false
    }));
}

// Mirrors script_engine.ex `setup_output/1`: `trunc(id)` truncates toward
// zero. Task 7: "output.set truncates IDs".
#[test]
fn output_set_truncates_ids() {
    let mut vm = compile("function on_change(e) output.set(3.9, true) output.set(7.2, true) end");
    let effects = run(&mut vm, &ev("test"));
    assert!(effects.contains(&ScriptEffect::OutputSet {
        output_id: 3,
        on: true
    }));
    assert!(effects.contains(&ScriptEffect::OutputSet {
        output_id: 7,
        on: true
    }));
}

// Mirrors script_engine.ex `setup_output/1` fallback: wrong usage returns
// `[nil, "usage: ..."]` instead of raising, records no effect, and execution
// continues.
#[test]
fn output_set_usage_error_returns_nil_and_message() {
    let mut vm = compile(
        "function on_change(e)\n  local ok, err = output.set(\"nope\", true)\n  print(ok, err)\nend",
    );
    let effects = run(&mut vm, &ev("test"));
    assert_eq!(
        logs(&effects),
        vec!["\tusage: output.set(id, true/false)".to_string()]
    );
    assert!(!effects
        .iter()
        .any(|e| matches!(e, ScriptEffect::OutputSet { .. })));
}

// Mirrors script_engine.ex `setup_output/1` argument pattern `[id, on]`:
// exactly two arguments are required — one argument is a usage error, while
// an EXPLICIT trailing nil still counts as the second argument.
#[test]
fn output_set_arity_quirks() {
    let mut vm = compile(
        "function on_change(e)\n  local ok1 = output.set(3)\n  local ok2, e2 = output.set(4, nil)\n  print(ok1, ok2, e2)\nend",
    );
    let effects = run(&mut vm, &ev("test"));
    // ok1: usage error returns nil first (prints ""); output.set(4, nil) is a
    // valid two-argument call with on=nil → falsy, returns true.
    assert_eq!(logs(&effects), vec!["\ttrue\t".to_string()]);
    // output.set(4, nil) DID record an effect with on=false.
    assert!(effects.contains(&ScriptEffect::OutputSet {
        output_id: 4,
        on: false
    }));
}

// -- display.set -------------------------------------------------------------

// Mirrors script_engine_test.exs "collects display.set side effects"
// (0x70 == 112).
#[test]
fn display_set_effects() {
    let mut vm = compile("function on_change(e) display.set(0x70, \"1234\") end");
    let effects = run(&mut vm, &ev("test"));
    assert_eq!(
        effects,
        vec![ScriptEffect::DisplaySet {
            i2c_address: 112,
            text: "1234".to_string()
        }]
    );
}

// Mirrors script_engine.ex `setup_display/1` fallback: non-number address or
// non-string text → `[nil, "usage: ..."]`, no effect, no raise. Address also
// truncates (trunc/1).
#[test]
fn display_set_usage_and_truncation() {
    let mut vm = compile(
        "function on_change(e)\n  local ok, err = display.set(\"x\", \"t\")\n  print(ok, err)\n  display.set(99.9, \"txt\")\nend",
    );
    let effects = run(&mut vm, &ev("test"));
    assert_eq!(
        logs(&effects),
        vec!["\tusage: display.set(i2c_address, text)".to_string()]
    );
    assert!(effects.contains(&ScriptEffect::DisplaySet {
        i2c_address: 99,
        text: "txt".into()
    }));
}

// -- schedule ----------------------------------------------------------------

// Mirrors script_engine_test.exs "collects schedule side effects".
#[test]
fn schedule_effect() {
    let mut vm = compile("function on_change(e) schedule(500) end");
    let effects = run(&mut vm, &ev("test"));
    assert_eq!(effects, vec![ScriptEffect::Schedule { ms: 500 }]);
}

// Mirrors script_engine.ex `setup_schedule/1`: the guard is `is_number(ms)
// and ms > 0` (0.5 passes) but the recorded effect is `trunc(ms)` — so
// schedule(0.5) records {:schedule, 0}. Faithful port of the oracle quirk.
#[test]
fn schedule_sub_one_millisecond_truncates_to_zero() {
    let mut vm = compile("function on_change(e) schedule(0.5) end");
    let effects = run(&mut vm, &ev("test"));
    assert_eq!(effects, vec![ScriptEffect::Schedule { ms: 0 }]);
}

// Mirrors script_engine.ex `setup_schedule/1` fallback: non-number,
// non-positive, and wrong-arity calls return the usage message.
#[test]
fn schedule_usage_errors() {
    let mut vm = compile(
        "function on_change(e)\n  local a1, a2 = schedule(0)\n  local b1, b2 = schedule(\"x\")\n  local c1, c2 = schedule()\n  print(a1, a2, b1, b2, c1, c2)\nend",
    );
    let effects = run(&mut vm, &ev("test"));
    let usage = "usage: schedule(milliseconds) where milliseconds > 0";
    assert_eq!(
        logs(&effects),
        vec![format!("\t{usage}\t\t{usage}\t\t{usage}")]
    );
}

// -- api.get / api.set ---------------------------------------------------------

// Mirrors script_engine_test.exs "collects api.get side effects" plus Task 7:
// "Preserve api.get placeholder returns and ignored effect" — api.get returns
// nil plus the literal second value "not available", and the recorded read
// intent is never fulfilled synchronously.
#[test]
fn api_get_placeholder_returns_and_ignored_intent() {
    let mut vm = compile(
        "function on_change(e)\n  local v, err = api.get(\"SomeEndpoint\")\n  print(v, err)\nend",
    );
    let effects = run(&mut vm, &ev("test"));
    assert_eq!(effects.len(), 2);
    assert!(effects.contains(&ScriptEffect::ApiGet {
        path: "SomeEndpoint".to_string()
    }));
    // print(nil, err) — Elixir to_string(nil) == "", joined with a tab.
    assert_eq!(logs(&effects), vec!["\tnot available".to_string()]);
}

// Mirrors script_engine.ex `setup_api/1`: `args |> List.first() |> to_string()`
// — calling api.get() with no argument records {:api_get, ""} because
// List.first([]) is nil and to_string(nil) is "".
#[test]
fn api_get_no_argument_records_empty_path() {
    let mut vm = compile("function on_change(e) api.get() end");
    let effects = run(&mut vm, &ev("test"));
    assert_eq!(
        effects,
        vec![ScriptEffect::ApiGet {
            path: String::new()
        }]
    );
}

// Mirrors script_engine_test.exs "collects api.set side effects" and
// script_engine.ex `setup_api/1`: returns [true].
#[test]
fn api_set_effect_and_return_value() {
    let mut vm = compile(
        "function on_change(e)\n  local ok = api.set(\"SomeEndpoint\", 0.5)\n  print(ok)\nend",
    );
    let effects = run(&mut vm, &ev("test"));
    assert_eq!(
        effects[0],
        ScriptEffect::ApiSet {
            path: "SomeEndpoint".to_string(),
            value: ScriptValue::Float(0.5)
        }
    );
    assert_eq!(logs(&effects), vec!["true".to_string()]);
}

// Mirrors script_engine.ex `setup_api/1`: `value = Enum.at(args, 1)` — a
// missing second argument records nil rather than failing, and integer /
// boolean / string values are recorded as-is. api.set path goes through
// to_string/1, so a numeric path is stringified.
#[test]
fn api_set_value_conversion_and_quirks() {
    let mut vm = compile(
        "function on_change(e)\n  api.set(\"a\")\n  api.set(\"b\", 3)\n  api.set(\"c\", true)\n  api.set(\"d\", \"txt\")\n  api.set(42, 1)\nend",
    );
    let effects = run(&mut vm, &ev("test"));
    assert_eq!(
        effects,
        vec![
            ScriptEffect::ApiSet {
                path: "a".into(),
                value: ScriptValue::Nil
            },
            ScriptEffect::ApiSet {
                path: "b".into(),
                value: ScriptValue::Integer(3)
            },
            ScriptEffect::ApiSet {
                path: "c".into(),
                value: ScriptValue::Boolean(true)
            },
            ScriptEffect::ApiSet {
                path: "d".into(),
                value: ScriptValue::String("txt".into())
            },
            ScriptEffect::ApiSet {
                path: "42".into(),
                value: ScriptValue::Integer(1)
            },
        ]
    );
}

// Oracle: api.set records whatever Lua value was passed (the raw table term)
// and does not fail at record time — simulator encoding failure happens later
// in the runner (script_runner.ex `process_effect` logs a warning). The Rust
// engine cannot embed a Lua table in a typed effect, so non-transmissible
// values are recorded as `ScriptValue::Opaque`. Documented divergence.
#[test]
fn api_set_table_value_records_opaque() {
    let mut vm = compile("function on_change(e) api.set(\"x\", {}) end");
    let effects = run(&mut vm, &ev("test"));
    assert_eq!(
        effects,
        vec![ScriptEffect::ApiSet {
            path: "x".into(),
            value: ScriptValue::Opaque
        }]
    );
}

// -- print ---------------------------------------------------------------------

// Mirrors script_engine.ex `setup_print/1`: args joined with "\t" using
// Elixir to_string/1 semantics per arg (nil → "", integers without ".0",
// floats with ".0").
#[test]
fn print_joins_args_with_tab() {
    let mut vm = compile("function on_change(e) print(1, 1.0, \"x\", true, nil) end");
    let effects = run(&mut vm, &ev("test"));
    assert_eq!(logs(&effects), vec!["1\t1.0\tx\ttrue\t".to_string()]);
}

// Mirrors script_engine.ex `setup_print/1`: Enum.map_join([], ...) == "".
#[test]
fn print_with_no_args_logs_empty_string() {
    let mut vm = compile("function on_change(e) print() end");
    let effects = run(&mut vm, &ev("test"));
    assert_eq!(logs(&effects), vec![String::new()]);
}

// Mirrors Elixir Protocol.UndefinedError: print of a table cannot be
// stringified by to_string/1, so the whole call FAILS in the oracle. The Rust
// engine mirrors the failure (does not invent "table: 0x..." formatting).
#[test]
fn print_of_table_errors_like_oracle() {
    let mut vm = compile("function on_change(e) print({}) end");
    let err = vm.execute(&ev("test")).expect_err("table print must fail");
    assert!(matches!(err, ScriptError::Runtime(_)), "got: {err:?}");
}

// -- ordered effects --------------------------------------------------------------

// Mirrors script_engine.ex `add_side_effect/1` + `execute/2`
// (prepend-then-reverse ⇒ chronological order); spike brief "ordered
// effects".
#[test]
fn effects_are_ordered_chronologically() {
    let mut vm = compile(
        "function on_change(e)\n  api.set(\"A\", 1)\n  output.set(1, true)\n  print(\"mid\")\n  schedule(100)\n  display.set(0x70, \"txt\")\n  api.get(\"B\")\nend",
    );
    let effects = run(&mut vm, &ev("test"));
    assert_eq!(
        effects,
        vec![
            ScriptEffect::ApiSet {
                path: "A".into(),
                value: ScriptValue::Integer(1)
            },
            ScriptEffect::OutputSet {
                output_id: 1,
                on: true
            },
            ScriptEffect::Log {
                message: "mid".into()
            },
            ScriptEffect::Schedule { ms: 100 },
            ScriptEffect::DisplaySet {
                i2c_address: 0x70,
                text: "txt".into()
            },
            ScriptEffect::ApiGet { path: "B".into() },
        ]
    );
}

// -- state persistence --------------------------------------------------------------

// Mirrors script_engine_test.exs "state persists between invocations" (the
// oracle test accepts "1.0" or "1"; the Lua 5.3 integer path prints "1").
#[test]
fn state_persists_between_invocations() {
    let mut vm = compile(
        "function on_change(event)\n  if state.counter == nil then state.counter = 0 end\n  state.counter = state.counter + 1\n  print(state.counter)\nend",
    );
    let e1 = run(&mut vm, &ev("test"));
    assert_eq!(logs(&e1), vec!["1".to_string()]);
    let e2 = run(&mut vm, &ev("test"));
    assert_eq!(logs(&e2), vec!["2".to_string()]);
}

// Mirrors script_engine.ex `setup_state/1` ("state = {}" before user code)
// and spike brief "globals/upvalues/closures/tables": top-level locals
// (closures/upvalues), globals, and tables all persist across invocations.
#[test]
fn globals_upvalues_closures_and_tables_persist() {
    let mut vm = compile(
        "local count = 0\nlocal function inc() count = count + 1 return count end\nfunction on_change(e)\n  inc() inc()\n  global_counter = (global_counter or 0) + inc()\n  t = t or {}\n  t[#t + 1] = count\n  print(count, global_counter, #t)\nend",
    );
    assert_eq!(
        logs(&run(&mut vm, &ev("test"))),
        vec!["3\t3\t1".to_string()]
    );
    // then global_counter = 3 + inc() where inc() advances count to 6 and
    // returns 6 → 9. Identical to the oracle's pure-Lua semantics.
    assert_eq!(
        logs(&run(&mut vm, &ev("test"))),
        vec!["6\t9\t2".to_string()]
    );
}

// -- language surface -----------------------------------------------------------------

// Spike brief "numbers": Lua 5.3 integer/float semantics shared by the oracle
// (lua 1.0.2 is a Lua 5.3 VM — deps/lua/README.md) and this engine.
#[test]
fn lua53_number_semantics() {
    let mut vm = compile(
        "function on_change(e)\n  print(3 / 2, 7 // 2, 1 == 1.0, math.type(1), math.type(1.0), 10 % 3, 2^10)\nend",
    );
    assert_eq!(
        logs(&run(&mut vm, &ev("test"))),
        vec!["1.5\t3\ttrue\tinteger\tfloat\t1\t1024.0".to_string()]
    );
}

// Spike brief "strings/Unicode": Lua strings are byte strings; utf8.len
// counts codepoints (oracle installs the utf8 library —
// deps/lua/lib/lua/vm/stdlib.ex @libraries).
#[test]
fn strings_and_unicode() {
    let mut vm = compile(
        "function on_change(e)\n  local s = \"héllo\"\n  print(#s, utf8.len(s), s .. \" wörld\", string.rep(\"ab\", 2), s:upper())\nend",
    );
    assert_eq!(
        logs(&run(&mut vm, &ev("test"))),
        vec!["6\t5\théllo wörld\tabab\tHéLLO".to_string()]
    );
}

// Spike brief "coroutines": the oracle lua 1.0.2 dependency has NO coroutine
// library (deps/lua/lib/lua/vm/stdlib.ex @libraries installs string, math,
// table, utf8, os, debug only), so coroutine-using scripts FAIL in the
// oracle. The engine mirrors that absence.
#[test]
fn coroutines_are_absent_like_oracle() {
    let mut vm = compile("function on_change(e) local c = coroutine.create(function() end) end");
    let err = vm.execute(&ev("test")).expect_err("coroutine must be nil");
    assert!(
        matches!(&err, ScriptError::Runtime(m) if m.contains("coroutine")),
        "got: {err:?}"
    );
}

// Mirrors script_engine_test.exs "returns error for runtime exceptions";
// error categories (compile vs runtime) stay distinguishable
// (script_engine.ex rescues into {:error, reason}).
#[test]
fn runtime_error_returns_error_with_script_text() {
    let mut vm = compile("function on_change(event) error(\"intentional error\") end");
    let err = vm.execute(&ev("test")).expect_err("error expected");
    assert!(
        matches!(&err, ScriptError::Runtime(m) if m.contains("intentional error")),
        "got: {err:?}"
    );
}

// Mirrors deps/lua/lib/lua/vm/stdlib.ex base_globals: pcall is available and
// Lua-level errors are catchable inside scripts.
#[test]
fn pcall_catches_errors_inside_script() {
    let mut vm = compile(
        "function on_change(e)\n  local ok, err = pcall(function() error(\"boom\") end)\n  print(ok, err)\nend",
    );
    let effects = run(&mut vm, &ev("test"));
    assert_eq!(logs(&effects).len(), 1);
    assert!(
        logs(&effects)[0].starts_with("false\t"),
        "got: {}",
        logs(&effects)[0]
    );
}

// -- sandbox ------------------------------------------------------------------------

// Mirrors script_engine_test.exs "sandboxed - no io access" (io.write on the
// oracle errors because io functions are sandboxed away —
// deps/lua/lib/lua.ex @default_sandbox).
#[test]
fn sandbox_no_io_access() {
    let mut vm = compile("function on_change(event) io.write(\"should fail\") end");
    let err = vm.execute(&ev("test")).expect_err("io must not exist");
    assert!(matches!(err, ScriptError::Runtime(_)), "got: {err:?}");
}

// Mirrors the oracle's exact library surface after
// deps/lua/lib/lua.ex @default_sandbox (io, file, package, load, loadfile,
// require, dofile, os.execute/exit/getenv/remove/rename/tmpname removed) and
// deps/lua/lib/lua/vm/stdlib.ex installed libraries (string, math, table,
// utf8, os, debug — no coroutine). _VERSION is "Lua 5.3".
#[test]
fn sandbox_surface_matches_oracle() {
    let mut vm = compile(
        "function on_change(e)\n  print(type(io), type(coroutine), type(load), type(require), type(package), type(os.exit), type(os.time), _VERSION)\nend",
    );
    let effects = run(&mut vm, &ev("test"));
    assert_eq!(
        logs(&effects),
        vec!["nil\tnil\tnil\tnil\tnil\tnil\tfunction\tLua 5.3".to_string()]
    );
}

// -- failed-call / timeout rollback ----------------------------------------------------

// Mirrors script_runner.ex `execute_script/4` `{:ok, {:error, reason}}` branch:
// the Elixir engine is immutable, so a failed on_change leaves the PRE-CALL
// VM in place — state mutations from the failed run vanish. Task 7:
// "Characterize state retention on thrown error: Elixir returns no updated VM
// on failure".
#[test]
fn failed_call_rolls_back_state() {
    let mut vm = compile(
        "function on_change(event)\n  state.n = (state.n or 0) + 1\n  if event.value == 1 then error(\"boom\") end\n  print(state.n)\nend",
    );
    let failing = ScriptEvent {
        source: "test".into(),
        value: ScriptValue::Integer(1),
        data: None,
    };
    let err = vm.execute(&failing).expect_err("error expected");
    assert!(matches!(err, ScriptError::Runtime(_)));
    // The failed increment was rolled back: the next successful run sees 1.
    let effects = run(&mut vm, &ev("test"));
    assert_eq!(logs(&effects), vec!["1".to_string()]);
}

// Mirrors script_runner.ex @execution_timeout_ms (200) with
// Task.yield/Task.shutdown(:brutal_kill): a timed-out run leaves the pre-call
// VM state in place. The Rust engine enforces the wall-clock deadline with an
// instruction hook (granularity documented in script-corpus.md).
#[test]
fn timeout_rolls_back_state() {
    let limits = ScriptLimits {
        execution_wall: Duration::from_millis(100),
        ..fast_limits()
    };
    let mut vm = ScriptVm::compile(
        "function on_change(event)\n  state.n = (state.n or 0) + 1\n  if event.value == 1 then while true do end end\n  print(state.n)\nend",
        limits,
    )
    .unwrap();
    let hanging = ScriptEvent {
        source: "test".into(),
        value: ScriptValue::Integer(1),
        data: None,
    };
    let err = vm.execute(&hanging).expect_err("timeout expected");
    assert!(matches!(err, ScriptError::Timeout), "got: {err:?}");
    let effects = run(&mut vm, &ev("test"));
    assert_eq!(logs(&effects), vec!["1".to_string()]);
}

// Task 7 backstop: the instruction budget fires even when the wall clock
// would not (here: generous wall clock, tiny instruction budget).
#[test]
fn instruction_limit_bounds_execution() {
    let limits = ScriptLimits {
        hook_instruction_interval: 64,
        max_instructions: 1_000,
        ..fast_limits()
    };
    let mut vm = ScriptVm::compile("function on_change(e) while true do end end", limits).unwrap();
    let err = vm
        .execute(&ev("test"))
        .expect_err("instruction limit expected");
    assert!(matches!(err, ScriptError::InstructionLimit), "got: {err:?}");
}

// Task 7 new bound (intentional divergence: the oracle has no memory limit —
// BEAM GC): "16MiB VM budget" via the interpreter allocator.
#[test]
fn memory_limit_bounds_allocation() {
    let limits = ScriptLimits {
        memory_bytes: 512 * 1024,
        ..fast_limits()
    };
    let mut vm = ScriptVm::compile(
        "function on_change(e)\n  local t = {}\n  for i = 1, 1000000 do t[i] = string.rep(\"x\", 64) end\nend",
        limits,
    )
    .unwrap();
    let err = vm.execute(&ev("test")).expect_err("memory limit expected");
    assert!(matches!(err, ScriptError::MemoryLimit), "got: {err:?}");
}

// Task 7 new bound (intentional divergence: the oracle collects unbounded
// effects): "256 effects/run" — exceeding the budget fails the call
// explicitly and rolls back.
#[test]
fn effect_limit_bounds_effect_storms() {
    let limits = ScriptLimits {
        max_effects: 8,
        ..fast_limits()
    };
    let mut vm = ScriptVm::compile(
        "function on_change(e)\n  for i = 1, 100 do print(i) end\nend",
        limits,
    )
    .unwrap();
    let err = vm.execute(&ev("test")).expect_err("effect limit expected");
    assert!(matches!(err, ScriptError::EffectLimit), "got: {err:?}");
}

// -- trigger evaluation (wave-2 API) --------------------------------------------

// Mirrors script_runner.ex `setup_subscriptions/1` + `check_and_fire/4`:
// an endpoint event fires exactly the scripts whose trigger list contains
// that endpoint string (exact match), in script list order.
#[test]
fn matching_scripts_exact_endpoint() {
    let scripts = vec![
        ScriptTriggerEntry {
            id: 1,
            enabled: true,
            triggers: vec!["Endpoint.A".into()],
        },
        ScriptTriggerEntry {
            id: 2,
            enabled: true,
            triggers: vec!["Endpoint.B".into(), "Endpoint.A".into()],
        },
        ScriptTriggerEntry {
            id: 3,
            enabled: true,
            triggers: vec!["Endpoint.AB".into()],
        },
    ];
    assert_eq!(matching_scripts(&scripts, "Endpoint.A"), vec![1, 2]);
    assert_eq!(matching_scripts(&scripts, "Endpoint.AB"), vec![3]);
    assert_eq!(matching_scripts(&scripts, "Endpoint.C"), Vec::<i64>::new());
}

// Mirrors script_context_test.exs "returns only enabled scripts" +
// train.ex `list_enabled_scripts/1` (only enabled scripts are ever loaded
// into the runner).
#[test]
fn matching_scripts_enabled_only() {
    let scripts = vec![
        ScriptTriggerEntry {
            id: 1,
            enabled: false,
            triggers: vec!["Endpoint.A".into()],
        },
        ScriptTriggerEntry {
            id: 2,
            enabled: true,
            triggers: vec!["Endpoint.A".into()],
        },
    ];
    assert_eq!(matching_scripts(&scripts, "Endpoint.A"), vec![2]);
}

// Mirrors lib/trenino/train/script.ex moduledoc: "A script with no triggers
// will only run when you click Run or when a schedule() timer fires" — no
// endpoint ever matches an empty trigger list.
#[test]
fn matching_scripts_no_triggers_never_match() {
    let scripts = vec![ScriptTriggerEntry {
        id: 7,
        enabled: true,
        triggers: vec![],
    }];
    assert_eq!(matching_scripts(&scripts, "Endpoint.A"), Vec::<i64>::new());
}

// Mirrors script_runner.ex `maybe_fire_script/5`: a duplicated trigger
// entry cannot double-fire the script (the first fire updates last_values, so
// the second observation sees last == value and skips) — modeled as a single
// match per script.
#[test]
fn matching_scripts_deduplicates_within_a_script() {
    let scripts = vec![ScriptTriggerEntry {
        id: 9,
        enabled: true,
        triggers: vec!["Endpoint.A".into(), "Endpoint.A".into()],
    }];
    assert_eq!(matching_scripts(&scripts, "Endpoint.A"), vec![9]);
}

// Mirrors script_runner.ex `handle_cast({:run_script, ...})` (source
// "manual") and `handle_info({:scheduled_run, ...})` (source "scheduled") —
// reserved source strings used for non-endpoint invocations.
#[test]
fn reserved_source_constants() {
    assert_eq!(SOURCE_MANUAL, "manual");
    assert_eq!(SOURCE_SCHEDULED, "scheduled");
}

// -- ScriptValue numeric equivalence at the change-detection gate -----------

// Mirrors scripting-and-sequences.md: "Numeric integer/float equivalents
// compare equal under !=", so a 1 <-> 1.0 flip must not re-fire triggers.
#[test]
fn script_value_integer_and_float_equivalents_compare_equal() {
    assert_eq!(ScriptValue::Integer(1), ScriptValue::Float(1.0));
    assert_eq!(ScriptValue::Float(1.0), ScriptValue::Integer(1));
    assert_ne!(ScriptValue::Integer(1), ScriptValue::Float(1.5));
    assert_ne!(ScriptValue::Float(1.5), ScriptValue::Integer(1));
}

// Strings never compare equal to numbers, even when their text matches.
#[test]
fn script_value_string_never_equals_number() {
    assert_ne!(ScriptValue::String("1".into()), ScriptValue::Integer(1));
    assert_ne!(ScriptValue::String("1.0".into()), ScriptValue::Float(1.0));
    assert_ne!(ScriptValue::Integer(1), ScriptValue::String("1".into()));
}
