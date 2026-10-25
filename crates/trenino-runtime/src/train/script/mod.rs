//! Lua scripting engine and trigger evaluation.
//!
//! Rust port of `lib/trenino/train/script_engine.ex` (+ the trigger
//! matching from `lib/trenino/train/script_runner.ex`), bounded per
//! Task 7 of `docs/superpowers/plans/2026-10-24-rust-controls.md`.
//! Behavior is pinned by the corpus in
//! `crates/trenino-runtime/tests/script_engine_corpus.rs`; intentional
//! divergences are recorded in
//! `docs/handoffs/2026-10-24-rust-rewrite/evidence/script-corpus.md`.

pub mod effect;
pub mod engine;
pub mod event;
pub mod runner;
pub mod triggers;

pub use effect::ScriptEffect;
pub use engine::{ScriptError, ScriptLimits, ScriptVm};
pub use event::{ScriptEvent, ScriptValue};
pub use runner::{
    DisplayPort, HardwareOutputPort, ScriptDefinition, ScriptRunError, ScriptRunner,
    ScriptRunnerCommand, ScriptShutdownError, ScriptSource, SimulatorSetPort, LOG_RING,
    MAX_SUBSCRIPTIONS, POLL_INTERVAL, RUN_ACK_TIMEOUT, SHUTDOWN_TIMEOUT, SUBSCRIPTION_ID_BASE,
};
pub use triggers::{matching_scripts, ScriptTriggerEntry, SOURCE_MANUAL, SOURCE_SCHEDULED};
