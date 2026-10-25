//! Typed, ordered script side effects.
//!
//! Mirrors `Trenino.Train.ScriptEngine`'s `@type side_effect` tuples: the
//! engine only COLLECTS intents during execution; the caller applies them
//! after the Lua run completes (`lib/trenino/train/script_engine.ex`
//! moduledoc: "The engine collects side effects during execution rather than
//! performing them inline").

use super::event::ScriptValue;

/// One script intent, recorded in chronological call order (mirrors the
/// Elixir process-dictionary collector with a final `Enum.reverse`).
#[derive(Clone, Debug, PartialEq)]
pub enum ScriptEffect {
    /// `{:api_get, path}` — read intent; never fulfilled synchronously.
    ApiGet { path: String },
    /// `{:api_set, path, value}` — write intent.
    ApiSet { path: String, value: ScriptValue },
    /// `{:output_set, output_id, on}` — hardware output; ID truncated via
    /// `trunc/1`, `on` uses Lua truthiness.
    OutputSet { output_id: i64, on: bool },
    /// `{:display_set, i2c_address, text}` — I2C display write.
    DisplaySet { i2c_address: i64, text: String },
    /// `{:schedule, ms}` — re-invocation request (`trunc/1` of a positive
    /// number; the runner replaces any prior timer).
    Schedule { ms: u64 },
    /// `{:log, message}` — `print` output, args tab-joined.
    Log { message: String },
}
