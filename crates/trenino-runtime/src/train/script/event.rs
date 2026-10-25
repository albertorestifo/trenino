//! Script event values.
//!
//! Mirrors the event map built by `Trenino.Train.ScriptRunner`:
//! `%{"source" => ..., "value" => ..., "data" => ...}` where `source` is an
//! endpoint path or the reserved `"manual"`/`"scheduled"` strings, `value` is
//! the decoded subscription value (may be nil) and `data` is the full
//! subscription `"Values"` map (may be nil). `Lua.encode!/2` in the Elixir
//! oracle turns that map into a Lua table; nil-valued keys encode to absent
//! keys.

use std::collections::BTreeMap;

/// A Lua-representable value crossing the engine boundary. Integer and float
/// stay distinct, mirroring both Lua 5.3 number subtypes and the Elixir
/// oracle's distinct integer/float terms.
#[derive(Clone, Debug, PartialEq)]
pub enum ScriptValue {
    Nil,
    Boolean(bool),
    Integer(i64),
    Float(f64),
    String(String),
    /// A non-transmissible Lua value (table/function) recorded by
    /// `api.set`. The Elixir oracle records the raw term and only fails
    /// later, in the runner, when encoding it for the simulator; the typed
    /// Rust effect cannot embed Lua objects, so this marker preserves the
    /// "recorded, not rejected" behavior. See script-corpus.md.
    Opaque,
}

/// The `on_change(event)` payload.
#[derive(Clone, Debug, PartialEq)]
pub struct ScriptEvent {
    /// Trigger endpoint path, `"manual"` or `"scheduled"`.
    pub source: String,
    /// Current value of the trigger endpoint (nil for manual/scheduled runs).
    pub value: ScriptValue,
    /// Full subscription response values, when present.
    pub data: Option<BTreeMap<String, ScriptValue>>,
}
