//! Trigger evaluation: input event → matching scripts.
//!
//! Mirrors `Trenino.Train.ScriptRunner.setup_subscriptions/1` +
//! `check_and_fire/4`: scripts declare trigger endpoint paths; an endpoint
//! observation fires exactly the enabled scripts whose trigger list contains
//! that endpoint string (exact match), in script list order. Disabled
//! scripts are never registered (`Trenino.Train.list_enabled_scripts/1`),
//! and `"manual"`/`"scheduled"` invocations bypass trigger matching entirely
//! (they address a script by ID).

/// Reserved event source for editor-triggered runs
/// (`script_runner.ex` `handle_cast({:run_script, _})`).
pub const SOURCE_MANUAL: &str = "manual";
/// Reserved event source for `schedule()` re-invocations
/// (`script_runner.ex` `handle_info({:scheduled_run, _})`).
pub const SOURCE_SCHEDULED: &str = "scheduled";

/// The trigger-relevant projection of a stored script.
#[derive(Clone, Debug, PartialEq)]
pub struct ScriptTriggerEntry {
    pub id: i64,
    pub enabled: bool,
    /// Endpoint paths; empty means the script only runs manually or via
    /// `schedule()` (see `lib/trenino/train/script.ex` moduledoc).
    pub triggers: Vec<String>,
}

/// Returns the IDs of scripts that an observation of `source` must fire, in
/// input order.
///
/// Elixir semantics preserved:
/// - exact string match between trigger entry and endpoint;
/// - enabled scripts only;
/// - each script matches at most once even with duplicated trigger entries
///   (the oracle's second observation sees `last_values` already updated and
///   skips — `maybe_fire_script/5`);
/// - input order preserved (`Enum.flat_map` + `Enum.group_by` over the
///   script list; the oracle's underlying query order is unspecified, so
///   callers pass their own stable order).
pub fn matching_scripts<'a, I>(scripts: I, source: &str) -> Vec<i64>
where
    I: IntoIterator<Item = &'a ScriptTriggerEntry>,
{
    scripts
        .into_iter()
        .filter(|s| s.enabled && s.triggers.iter().any(|t| t == source))
        .map(|s| s.id)
        .collect()
}
