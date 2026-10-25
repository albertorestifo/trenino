//! Bounded Lua script engine.
//!
//! Ports `Trenino.Train.ScriptEngine` (Elixir, backed by the pure-Elixir
//! `lua` 1.0.2 Lua 5.3 VM) onto mlua 0.12 with the vendored Lua 5.3
//! interpreter, preserving the oracle's observable behavior:
//!
//! - one VM per script, `on_change(event)` invoked per trigger, effects
//!   collected as typed intents instead of performed inline;
//! - exact sandbox surface (see `sandbox_surface_matches_oracle` in the
//!   corpus): string/math/table/utf8/os(−exec/exit/getenv/remove/rename/
//!   tmpname)/debug(oracle stubs) libraries, no io/package/coroutine/load/
//!   loadfile/dofile/require;
//! - Elixir callback quirks: `to_string/1` conversions (nil → ""), arity
//!   checks in `output.set`/`display.set`/`schedule`, `trunc/1` on IDs,
//!   Lua truthiness (only `false`/`nil` falsy), `api.get` placeholder
//!   returns, `print` tab-joining, chronological effect order;
//! - per-call state rollback on failed/timed-out calls (the Elixir oracle
//!   gets this for free from immutability).
//!
//! Bounds (Task 7 of the Rust controls plan; the oracle has NONE of these —
//! they are intentional, documented safety additions):
//! - wall-clock deadlines for compile and execute, enforced by a global
//!   instruction hook (covers coroutine threads; no blocking native
//!   callback is exposed, so hook granularity bounds interruption latency);
//! - instruction-count backstop;
//! - per-VM memory limit via the interpreter allocator;
//! - per-run effect budget and per-message log byte cap.
//!
//! ## Rollback strategy
//!
//! mlua offers no faithful VM snapshot API, and a JSON copy of `state`
//! cannot restore globals/upvalues/closures (Task 7 explicitly rejects that
//! claim). Instead the engine exploits the fact that every host callback is
//! a pure function of its arguments: it keeps TWO state-identical VMs
//! (primary + mirror). `execute` runs the event on the primary; on success
//! the same event is replayed on the mirror so both advance to the new
//! committed state. On failure the mutated primary is discarded and the
//! untouched mirror is promoted — restoring globals, upvalues, closures and
//! tables exactly. A lost mirror (only possible through nondeterministic
//! host state such as `os.time`) is rebuilt by replaying the logged event
//! history on a fresh compile; if that fails the engine reports a
//! `ScriptError::Rollback` instead of silently diverging. Both VMs seed
//! their per-VM `math.random` replacement identically, so replay is
//! deterministic. See script-corpus.md for the full analysis.

use std::cell::{Cell, RefCell};
use std::fmt;
use std::rc::Rc;
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};

use mlua::{HookTriggers, Lua, LuaOptions, MultiValue, StdLib, Table, Value, VmState};

use super::effect::ScriptEffect;
use super::event::{ScriptEvent, ScriptValue};

/// Tunable bounds for one script VM.
#[derive(Clone, Debug)]
pub struct ScriptLimits {
    /// Wall-clock deadline for one `on_change` execution
    /// (default 200ms — `script_runner.ex` `@execution_timeout_ms`).
    pub execution_wall: Duration,
    /// Wall-clock deadline for compiling and running top-level code
    /// (Task 7 new bound; the Elixir oracle would hang forever).
    pub compile_wall: Duration,
    /// Per-VM allocator limit (Task 7: 16 MiB).
    pub memory_bytes: usize,
    /// Max recorded effects per execution (Task 7: 256).
    pub max_effects: usize,
    /// Max bytes of one `print` message (longer messages truncate —
    /// bounded payload).
    pub max_log_message_bytes: usize,
    /// Instruction-hook granularity (hook fires every N VM instructions).
    pub hook_instruction_interval: u32,
    /// Per-call instruction budget backstop behind the wall clock.
    pub max_instructions: u64,
}

impl Default for ScriptLimits {
    fn default() -> Self {
        Self {
            execution_wall: Duration::from_millis(200),
            compile_wall: Duration::from_millis(200),
            memory_bytes: 16 * 1024 * 1024,
            max_effects: 256,
            max_log_message_bytes: 8 * 1024,
            hook_instruction_interval: 512,
            max_instructions: 200_000_000,
        }
    }
}

/// Failure classification. The oracle distinguishes compile errors from
/// runtime errors (`ScriptEngine.new/1` vs `execute/2` rescue paths); the
/// limit categories are new, typed bounds.
#[derive(Clone, Debug, PartialEq)]
pub enum ScriptError {
    /// Lua syntax/load error (oracle: `{:error, reason}` from `new/1`).
    Compile(String),
    /// Runtime error in Lua code or a host callback conversion
    /// (oracle: `{:error, reason}` from `execute/2`).
    Runtime(String),
    Timeout,
    /// Instruction budget exceeded (new bound).
    InstructionLimit,
    /// VM memory limit exceeded (new bound).
    MemoryLimit,
    /// Effect budget exceeded (new bound).
    EffectLimit,
    /// A failed call could not be rolled back exactly (internal
    /// inconsistency; never silently diverges).
    Rollback(String),
}

impl fmt::Display for ScriptError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            ScriptError::Compile(m) => write!(f, "compile error: {m}"),
            ScriptError::Runtime(m) => write!(f, "{m}"),
            ScriptError::Timeout => write!(f, "script execution timed out"),
            ScriptError::InstructionLimit => write!(f, "script instruction limit exceeded"),
            ScriptError::MemoryLimit => write!(f, "script memory limit exceeded"),
            ScriptError::EffectLimit => write!(f, "script effect limit exceeded"),
            ScriptError::Rollback(m) => write!(f, "script rollback degraded: {m}"),
        }
    }
}

impl std::error::Error for ScriptError {}

// Internal failure marker set by the hook/callbacks before erroring, so the
// error mapper can classify precisely instead of parsing messages.
#[derive(Clone, Copy, Debug, PartialEq)]
enum Marker {
    Timeout,
    Instructions,
    Effects,
}

struct HookState {
    deadline: Cell<Option<Instant>>,
    instructions: Cell<u64>,
    max_instructions: Cell<u64>,
    marker: Rc<RefCell<Option<Marker>>>,
}

/// Shared per-VM context captured by the Trenino API callbacks.
#[derive(Clone)]
struct Ctx {
    effects: Rc<RefCell<Vec<ScriptEffect>>>,
    marker: Rc<RefCell<Option<Marker>>>,
    max_effects: usize,
    max_log_message_bytes: usize,
}

fn record(ctx: &Ctx, effect: ScriptEffect) -> mlua::Result<()> {
    let mut effects = ctx.effects.borrow_mut();
    if effects.len() >= ctx.max_effects {
        ctx.marker.replace(Some(Marker::Effects));
        return Err(mlua::Error::runtime("effect limit exceeded"));
    }
    effects.push(effect);
    Ok(())
}

/// One Lua VM instance with its hook/collector state.
struct Vm {
    lua: Lua,
    hook: Rc<HookState>,
    effects: Rc<RefCell<Vec<ScriptEffect>>>,
    marker: Rc<RefCell<Option<Marker>>>,
}

impl Vm {
    fn build(code: &str, limits: &ScriptLimits) -> Result<Vm, ScriptError> {
        // SAFETY: the only unsafe stdlib requested is `debug`. Its raw
        // global is replaced in `install_sandbox` by a trimmed table that
        // keeps just the oracle's introspection functions; registry and
        // userdata access (getregistry/getuservalue/setuservalue/
        // upvaluejoin/debug) are dropped, so no script-reachable sandbox
        // escape remains once setup completes.
        let lua = unsafe {
            Lua::unsafe_new_with(
                StdLib::COROUTINE
                    | StdLib::TABLE
                    | StdLib::OS
                    | StdLib::STRING
                    | StdLib::MATH
                    | StdLib::UTF8
                    | StdLib::DEBUG,
                LuaOptions::new(),
            )
        };

        let marker: Rc<RefCell<Option<Marker>>> = Rc::new(RefCell::new(None));
        let effects: Rc<RefCell<Vec<ScriptEffect>>> = Rc::new(RefCell::new(Vec::new()));
        let ctx = Ctx {
            effects: effects.clone(),
            marker: marker.clone(),
            max_effects: limits.max_effects,
            max_log_message_bytes: limits.max_log_message_bytes,
        };

        lua.set_memory_limit(limits.memory_bytes).map_err(setup_error)?;

        install_sandbox(&lua, &ctx)?;
        install_api(&lua, &ctx)?;

        // state = {} (script_engine.ex `setup_state/1`), before user code.
        let state = lua.create_table().map_err(setup_error)?;
        lua.globals().raw_set("state", state).map_err(setup_error)?;

        // Global instruction hook: wall-clock deadline + instruction backstop.
        let hook = Rc::new(HookState {
            deadline: Cell::new(None),
            instructions: Cell::new(0),
            max_instructions: Cell::new(limits.max_instructions),
            marker: marker.clone(),
        });
        let hook_cb = hook.clone();
        let interval = limits.hook_instruction_interval;
        lua.set_global_hook(
            HookTriggers {
                every_nth_instruction: Some(interval.max(1)),
                ..HookTriggers::default()
            },
            move |_lua, _debug| {
                let n = hook_cb.instructions.get().saturating_add(interval as u64);
                hook_cb.instructions.set(n);
                if let Some(deadline) = hook_cb.deadline.get() {
                    if Instant::now() >= deadline {
                        hook_cb.marker.replace(Some(Marker::Timeout));
                        return Err(mlua::Error::runtime("execution deadline exceeded"));
                    }
                }
                if n > hook_cb.max_instructions.get() {
                    hook_cb.marker.replace(Some(Marker::Instructions));
                    return Err(mlua::Error::runtime("instruction limit exceeded"));
                }
                Ok(VmState::Continue)
            },
        )
        .map_err(setup_error)?;

        // Compile and run top-level code under the compile deadline
        // (script_engine.ex `new/1` runs the chunk eagerly).
        hook.deadline.set(Some(Instant::now() + limits.compile_wall));
        hook.instructions.set(0);
        marker.replace(None);
        let loaded = lua.load(code).set_name("script").exec();
        hook.deadline.set(None);
        loaded.map_err(|e| map_error(e, &marker))?;

        Ok(Vm { lua, hook, effects, marker })
    }

    /// Run `on_change(event)` and return the chronological effects.
    fn run(&self, event: &ScriptEvent, wall: Duration) -> Result<Vec<ScriptEffect>, ScriptError> {
        self.hook.deadline.set(Some(Instant::now() + wall));
        self.hook.instructions.set(0);
        self.marker.replace(None);
        self.effects.borrow_mut().clear();

        let result = self.run_inner(event);

        self.hook.deadline.set(None);
        result
    }

    fn run_inner(&self, event: &ScriptEvent) -> Result<Vec<ScriptEffect>, ScriptError> {
        let on_change: Value = self
            .lua
            .globals()
            .raw_get("on_change")
            .map_err(|e| ScriptError::Runtime(e.to_string()))?;
        let function = match on_change {
            Value::Function(f) => f,
            _ => {
                return Err(ScriptError::Runtime(
                    "attempt to call a nil value (global 'on_change')".to_string(),
                ))
            }
        };
        let table = encode_event(&self.lua, event)?;
        function
            .call::<()>(table)
            .map_err(|e| map_error(e, &self.marker))?;
        Ok(self.effects.borrow().clone())
    }
}

/// A compiled script VM with rollback support.
pub struct ScriptVm {
    code: String,
    limits: ScriptLimits,
    primary: Vm,
    mirror: Option<Vm>,
    log: Vec<ScriptEvent>,
    degraded: bool,
}

impl ScriptVm {
    /// Compile `code` (top-level code executes immediately, as in
    /// `ScriptEngine.new/1`). Two state-identical VMs are built: the
    /// primary executes events; the mirror is the rollback image.
    pub fn compile(code: &str, limits: ScriptLimits) -> Result<ScriptVm, ScriptError> {
        let primary = Vm::build(code, &limits)?;
        let mirror = Vm::build(code, &limits)?;
        Ok(ScriptVm {
            code: code.to_string(),
            limits,
            primary,
            mirror: Some(mirror),
            log: Vec::new(),
            degraded: false,
        })
    }

    /// True when the rollback image could not be kept in sync (only possible
    /// through nondeterministic host state such as `os.time`); failures then
    /// report `ScriptError::Rollback` rather than diverging silently.
    pub fn rollback_degraded(&self) -> bool {
        self.degraded
    }

    /// Execute `on_change(event)`; on success the effects are the
    /// authoritative, chronologically ordered intents and the VM state
    /// advances. On failure nothing commits: state rolls back to the
    /// pre-call value (mirroring the oracle's immutable-state semantics).
    pub fn execute(&mut self, event: &ScriptEvent) -> Result<Vec<ScriptEffect>, ScriptError> {
        if self.mirror.is_none() {
            match self.rebuild() {
                Ok(vm) => {
                    self.mirror = Some(vm);
                    self.degraded = false;
                }
                Err(e) => {
                    self.degraded = true;
                    let _ = e; // proceed; the failure path rebuilds or reports
                }
            }
        }

        match self.primary.run(event, self.limits.execution_wall) {
            Ok(effects) => {
                self.log.push(event.clone());
                // Advance the mirror to the new committed state (deterministic
                // replay: pure callbacks, identically seeded RNG).
                let mirror_ok = match self.mirror.as_ref() {
                    Some(m) => m.run(event, self.limits.execution_wall).is_ok(),
                    None => false,
                };
                if !mirror_ok {
                    self.mirror = None;
                    self.degraded = true;
                }
                Ok(effects)
            }
            Err(err) => {
                match self.mirror.take() {
                    Some(m) => self.primary = m,
                    None => match self.rebuild() {
                        Ok(vm) => self.primary = vm,
                        Err(rb) => {
                            self.degraded = true;
                            return Err(ScriptError::Rollback(format!(
                                "{err}; rollback image rebuild failed: {rb}"
                            )));
                        }
                    },
                }
                Err(err)
            }
        }
    }

    /// Rebuild a state-identical VM: fresh compile + replay of the
    /// committed event history.
    fn rebuild(&self) -> Result<Vm, ScriptError> {
        let vm = Vm::build(&self.code, &self.limits)?;
        for event in &self.log {
            vm.run(event, self.limits.execution_wall)?;
        }
        Ok(vm)
    }
}

// -- error mapping -----------------------------------------------------------

fn setup_error(e: mlua::Error) -> ScriptError {
    ScriptError::Runtime(format!("vm setup failed: {e}"))
}

fn map_error(err: mlua::Error, marker: &RefCell<Option<Marker>>) -> ScriptError {
    if let Some(m) = marker.borrow_mut().take() {
        return match m {
            Marker::Timeout => ScriptError::Timeout,
            Marker::Instructions => ScriptError::InstructionLimit,
            Marker::Effects => ScriptError::EffectLimit,
        };
    }
    match err {
        mlua::Error::SyntaxError { message, .. } => ScriptError::Compile(message),
        mlua::Error::MemoryError(_) => ScriptError::MemoryLimit,
        e => ScriptError::Runtime(e.to_string()),
    }
}

// -- event encoding ----------------------------------------------------------

fn to_lua_value(lua: &Lua, value: &ScriptValue) -> Result<Value, ScriptError> {
    Ok(match value {
        ScriptValue::Nil => Value::Nil,
        ScriptValue::Boolean(b) => Value::Boolean(*b),
        ScriptValue::Integer(i) => Value::Integer(*i),
        ScriptValue::Float(f) => Value::Number(*f),
        ScriptValue::String(s) => Value::String(lua.create_string(s.as_bytes()).map_err(setup_error)?),
        ScriptValue::Opaque => Value::Nil,
    })
}

fn encode_event(lua: &Lua, event: &ScriptEvent) -> Result<Table, ScriptError> {
    let table = lua.create_table().map_err(setup_error)?;
    table
        .raw_set("source", event.source.clone())
        .map_err(setup_error)?;
    // Lua.encode!/2 maps nil-valued keys to absent keys.
    if !matches!(event.value, ScriptValue::Nil) {
        table
            .raw_set("value", to_lua_value(lua, &event.value)?)
            .map_err(setup_error)?;
    }
    if let Some(data) = &event.data {
        let data_table = lua.create_table().map_err(setup_error)?;
        for (k, v) in data {
            if !matches!(v, ScriptValue::Nil) {
                data_table
                    .raw_set(k.clone(), to_lua_value(lua, v)?)
                    .map_err(setup_error)?;
            }
        }
        table.raw_set("data", data_table).map_err(setup_error)?;
    }
    Ok(table)
}

// -- value conversions (Elixir semantics) ------------------------------------

/// Elixir `to_string/1` over Lua values: nil → "", booleans → "true"/"false",
/// integers decimal, floats via `Float.to_string/1` ("1.0", "0.5"),
/// strings verbatim. Tables/functions raise `Protocol.UndefinedError` in the
/// oracle, so they error here too.
fn elixir_to_string(value: &Value) -> mlua::Result<String> {
    match value {
        Value::Nil => Ok(String::new()),
        Value::Boolean(true) => Ok("true".to_string()),
        Value::Boolean(false) => Ok("false".to_string()),
        Value::Integer(i) => Ok(i.to_string()),
        Value::Number(f) => Ok(format!("{f:?}")),
        Value::String(s) => Ok(s.to_string_lossy().to_string()),
        _ => Err(mlua::Error::runtime(
            "to_string is not implement for this value (oracle: Protocol.UndefinedError)",
        )),
    }
}

fn to_script_value(value: &Value) -> ScriptValue {
    match value {
        Value::Nil => ScriptValue::Nil,
        Value::Boolean(b) => ScriptValue::Boolean(*b),
        Value::Integer(i) => ScriptValue::Integer(*i),
        Value::Number(f) => ScriptValue::Float(*f),
        Value::String(s) => ScriptValue::String(s.to_string_lossy().to_string()),
        _ => ScriptValue::Opaque,
    }
}

/// Lua truthiness (script_engine.ex `truthy?/1`): only `false` and `nil`
/// are falsy — zero, 0.0 and "" are truthy.
fn lua_truthy(value: &Value) -> bool {
    !matches!(value, Value::Nil | Value::Boolean(false))
}

/// Elixir `is_number/1` + `trunc/1` view of a Lua value: integers and
/// FINITE floats are numbers (the oracle represents NaN/infinity as
/// non-number atoms, so they fall to usage errors, not raises).
fn lua_number(value: &Value) -> Option<f64> {
    match value {
        Value::Integer(i) => Some(*i as f64),
        Value::Number(f) if f.is_finite() => Some(*f),
        _ => None,
    }
}

fn truncate_utf8(message: &mut String, max_bytes: usize) {
    if message.len() <= max_bytes {
        return;
    }
    let mut end = max_bytes;
    while end > 0 && !message.is_char_boundary(end) {
        end -= 1;
    }
    message.truncate(end);
}

// -- deterministic per-VM RNG (math.random replacement) ----------------------

const RNG_INITIAL_SEED: u64 = 0x9E37_79B9_7F4A_7C15;


impl fmt::Debug for ScriptVm {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("ScriptVm")
            .field("committed_events", &self.log.len())
            .field("rollback_degraded", &self.degraded)
            .finish_non_exhaustive()
    }
}
fn rng_next(cell: &Cell<u64>) -> u64 {
    let mut x = cell.get();
    if x == 0 {
        x = RNG_INITIAL_SEED;
    }
    // xorshift64*
    x ^= x >> 12;
    x ^= x << 25;
    x ^= x >> 27;
    cell.set(x);
    x.wrapping_mul(0x2545_F491_4F6C_DD1D)
}

// -- sandbox + API installation ----------------------------------------------

/// Strips the VM down to the oracle's library surface: lua.ex
/// `@default_sandbox` (io, file, package, load, loadfile, require, dofile,
/// os.execute/exit/getenv/remove/rename/tmpname removed) over the stdlib
/// install list (string, math, table, utf8, os, debug — no coroutine).
fn install_sandbox(lua: &Lua, ctx: &Ctx) -> Result<(), ScriptError> {
    let globals = lua.globals();
    for name in ["coroutine", "io", "file", "package", "load", "loadfile", "dofile", "require"] {
        globals.raw_set(name, Value::Nil).map_err(setup_error)?;
    }

    // os: keep clock/date/difftime/setlocale/time (the oracle surface),
    // add the oracle's time_ms/time_us extras, remove the rest.
    let os: Table = globals.raw_get("os").map_err(setup_error)?;
    for name in ["exit", "getenv", "tmpname", "execute", "remove", "rename"] {
        os.raw_set(name, Value::Nil).map_err(setup_error)?;
    }
    let time_ms = lua
        .create_function(|_, _: MultiValue| {
            Ok(SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .map(|d| d.as_millis() as i64)
                .unwrap_or(0))
        })
        .map_err(setup_error)?;
    let time_us = lua
        .create_function(|_, _: MultiValue| {
            Ok(SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .map(|d| d.as_micros() as i64)
                .unwrap_or(0))
        })
        .map_err(setup_error)?;
    os.raw_set("time_ms", time_ms).map_err(setup_error)?;
    os.raw_set("time_us", time_us).map_err(setup_error)?;

    // debug: keep the introspection functions the oracle implements; mirror
    // its stubs (sethook/gethook/upvalueid); drop registry/userdata access
    // that the oracle does not expose.
    let debug: Table = globals.raw_get("debug").map_err(setup_error)?;
    let trimmed = lua.create_table().map_err(setup_error)?;
    for name in [
        "getinfo",
        "traceback",
        "getmetatable",
        "setmetatable",
        "getlocal",
        "setlocal",
        "getupvalue",
        "setupvalue",
    ] {
        let f: Value = debug.raw_get(name).map_err(setup_error)?;
        trimmed.raw_set(name, f).map_err(setup_error)?;
    }
    let sethook = lua
        .create_function(|_, _: MultiValue| Ok(MultiValue::new()))
        .map_err(setup_error)?;
    let gethook = lua
        .create_function(|lua, _: MultiValue| {
            Ok(MultiValue::from_vec(vec![
                Value::Nil,
                Value::String(lua.create_string("")?),
                Value::Integer(0),
            ]))
        })
        .map_err(setup_error)?;
    let upvalueid = lua
        .create_function(|_, _: MultiValue| {
            Ok(MultiValue::from_vec(vec![Value::Nil]))
        })
        .map_err(setup_error)?;
    trimmed.raw_set("sethook", sethook).map_err(setup_error)?;
    trimmed.raw_set("gethook", gethook).map_err(setup_error)?;
    trimmed.raw_set("upvalueid", upvalueid).map_err(setup_error)?;
    globals.raw_set("debug", trimmed).map_err(setup_error)?;

    // math.random/randomseed: replaced with a per-VM deterministic PRNG.
    // Real Lua 5.3 uses process-global rand(), which would desynchronize the
    // rollback mirror; the oracle uses Erlang's :rand (per-process, itself
    // nondeterministic across runs), so no script can depend on a specific
    // sequence. Identical seeding across primary/mirror keeps replay exact.
    let math: Table = globals.raw_get("math").map_err(setup_error)?;
    let rng = Rc::new(Cell::new(RNG_INITIAL_SEED));
    let rng_for_random = rng.clone();
    let random = lua
        .create_function(move |_, args: MultiValue| {
            let arg = |i: usize| args.iter().nth(i).cloned();
            let as_integer = |v: &Value| -> Option<i64> {
                match v {
                    Value::Integer(i) => Some(*i),
                    Value::Number(f) if f.fract() == 0.0 && f.is_finite() => Some(*f as i64),
                    _ => None,
                }
            };
            let x = rng_next(&rng_for_random);
            let value = match (arg(0), arg(1)) {
                (None, _) => Value::Number((x >> 11) as f64 / (1u64 << 53) as f64),
                (Some(v), None) => {
                    let m = as_integer(&v).ok_or_else(|| {
                        mlua::Error::runtime("number has no integer representation")
                    })?;
                    if m < 1 {
                        return Err(mlua::Error::runtime("interval is empty"));
                    }
                    Value::Integer(1 + (x as i64 % m))
                }
                (Some(lo), Some(hi)) => {
                    let m = as_integer(&lo).ok_or_else(|| {
                        mlua::Error::runtime("number has no integer representation")
                    })?;
                    let n = as_integer(&hi).ok_or_else(|| {
                        mlua::Error::runtime("number has no integer representation")
                    })?;
                    if m > n {
                        return Err(mlua::Error::runtime("interval is empty"));
                    }
                    let span = (n - m + 1) as u64;
                    Value::Integer(m + (x % span) as i64)
                }
            };
            Ok(MultiValue::from_vec(vec![value]))
        })
        .map_err(setup_error)?;
    let rng_for_seed = rng.clone();
    let randomseed = lua
        .create_function(move |_, args: MultiValue| {
            if let Some(v) = args.iter().next() {
                let seed = match v {
                    Value::Integer(i) => *i as u64,
                    Value::Number(f) if f.is_finite() => *f as i64 as u64,
                    _ => 0,
                };
                rng_for_seed.set(if seed == 0 { RNG_INITIAL_SEED } else { seed });
            }
            Ok(MultiValue::new())
        })
        .map_err(setup_error)?;
    math.raw_set("random", random).map_err(setup_error)?;
    math.raw_set("randomseed", randomseed).map_err(setup_error)?;

    // print: collector override (script_engine.ex `setup_print/1`).
    let print_ctx = ctx.clone();
    let print = lua
        .create_function(move |_, args: MultiValue| {
            let mut parts = Vec::with_capacity(args.len());
            for value in args.iter() {
                parts.push(elixir_to_string(value)?);
            }
            let mut message = parts.join("\t");
            truncate_utf8(&mut message, print_ctx.max_log_message_bytes);
            record(&print_ctx, ScriptEffect::Log { message })?;
            Ok(MultiValue::new())
        })
        .map_err(setup_error)?;
    globals.raw_set("print", print).map_err(setup_error)?;

    Ok(())
}

/// Installs the Trenino API: api.get/api.set, output.set, display.set,
/// schedule — exact ports of script_engine.ex `setup_api/1`,
/// `setup_output/1`, `setup_display/1`, `setup_schedule/1` including usage
/// messages, arity checks, truncation and truthiness.
fn install_api(lua: &Lua, ctx: &Ctx) -> Result<(), ScriptError> {
    let globals = lua.globals();

    let api = lua.create_table().map_err(setup_error)?;
    let get_ctx = ctx.clone();
    let get = lua
        .create_function(move |lua, args: MultiValue| {
            let path = elixir_to_string(&args.iter().next().cloned().unwrap_or(Value::Nil))?;
            record(&get_ctx, ScriptEffect::ApiGet { path })?;
            // Placeholder returns: nil plus "not available" — the read
            // intent is recorded but never fulfilled synchronously.
            Ok(MultiValue::from_vec(vec![
                Value::Nil,
                Value::String(lua.create_string("not available")?),
            ]))
        })
        .map_err(setup_error)?;
    let set_ctx = ctx.clone();
    let set = lua
        .create_function(move |_, args: MultiValue| {
            let values: Vec<Value> = args.iter().cloned().collect();
            let path = elixir_to_string(values.first().unwrap_or(&Value::Nil))?;
            let value = to_script_value(values.get(1).unwrap_or(&Value::Nil));
            record(&set_ctx, ScriptEffect::ApiSet { path, value })?;
            Ok(MultiValue::from_vec(vec![Value::Boolean(true)]))
        })
        .map_err(setup_error)?;
    api.raw_set("get", get).map_err(setup_error)?;
    api.raw_set("set", set).map_err(setup_error)?;
    globals.raw_set("api", api).map_err(setup_error)?;

    let output = lua.create_table().map_err(setup_error)?;
    let output_ctx = ctx.clone();
    let output_set = lua
        .create_function(move |lua, args: MultiValue| {
            let values: Vec<Value> = args.iter().cloned().collect();
            // Oracle pattern match `[id, on]`: exactly two arguments.
            if values.len() == 2 {
                if let Some(id) = lua_number(&values[0]) {
                    let on = lua_truthy(&values[1]);
                    record(
                        &output_ctx,
                        ScriptEffect::OutputSet { output_id: id.trunc() as i64, on },
                    )?;
                    return Ok(MultiValue::from_vec(vec![Value::Boolean(true)]));
                }
            }
            Ok(MultiValue::from_vec(vec![
                Value::Nil,
                Value::String(lua.create_string("usage: output.set(id, true/false)")?),
            ]))
        })
        .map_err(setup_error)?;
    output.raw_set("set", output_set).map_err(setup_error)?;
    globals.raw_set("output", output).map_err(setup_error)?;

    let display = lua.create_table().map_err(setup_error)?;
    let display_ctx = ctx.clone();
    let display_set = lua
        .create_function(move |lua, args: MultiValue| {
            let values: Vec<Value> = args.iter().cloned().collect();
            // Oracle pattern match `[addr, text]`: exactly two arguments,
            // address numeric, text binary.
            if values.len() == 2 {
                if let Some(addr) = lua_number(&values[0]) {
                    if let Value::String(text) = &values[1] {
                        record(
                            &display_ctx,
                            ScriptEffect::DisplaySet {
                                i2c_address: addr.trunc() as i64,
                                text: text.to_string_lossy().to_string(),
                            },
                        )?;
                        return Ok(MultiValue::from_vec(vec![Value::Boolean(true)]));
                    }
                }
            }
            Ok(MultiValue::from_vec(vec![
                Value::Nil,
                Value::String(lua.create_string("usage: display.set(i2c_address, text)")?),
            ]))
        })
        .map_err(setup_error)?;
    display.raw_set("set", display_set).map_err(setup_error)?;
    globals.raw_set("display", display).map_err(setup_error)?;

    let schedule_ctx = ctx.clone();
    let schedule = lua
        .create_function(move |lua, args: MultiValue| {
            let values: Vec<Value> = args.iter().cloned().collect();
            // Oracle pattern match `[ms]` with `is_number(ms) and ms > 0`;
            // the recorded value is trunc(ms) — 0.5 records 0.
            if values.len() == 1 {
                if let Some(ms) = lua_number(&values[0]) {
                    if ms > 0.0 {
                        record(
                            &schedule_ctx,
                            ScriptEffect::Schedule { ms: (ms.trunc() as i64).max(0) as u64 },
                        )?;
                        return Ok(MultiValue::from_vec(vec![Value::Boolean(true)]));
                    }
                }
            }
            Ok(MultiValue::from_vec(vec![
                Value::Nil,
                Value::String(lua.create_string(
                    "usage: schedule(milliseconds) where milliseconds > 0",
                )?),
            ]))
        })
        .map_err(setup_error)?;
    globals.raw_set("schedule", schedule).map_err(setup_error)?;

    Ok(())
}
