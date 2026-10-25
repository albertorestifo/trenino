//! Script runner: the runtime half of `Trenino.Train.ScriptRunner`
//! (lib/trenino/train/script_runner.ex).
//!
//! Owns one [`ScriptVm`] per enabled script of the active train and drives
//! the full oracle lifecycle:
//!
//! - **load** — on train activation and on every `reload_scripts` (the cast
//!   the LiveViews send after script CRUD), compile each enabled script and
//!   create one simulator subscription per unique trigger endpoint from the
//!   ID range 2000-2999 (`load_scripts_for_train/2`, `compile_scripts/1`,
//!   `setup_subscriptions/1`);
//! - **poll** — every 200 ms fetch each subscription and fire `on_change`
//!   only for scripts whose endpoint value CHANGED since their last
//!   observation (`poll_and_execute/1`, `maybe_fire_script/5` with
//!   `last_values`);
//! - **execute** — per-script effects applied in chronological order:
//!   `print` → the script log ring, `schedule` → a per-script timer that
//!   replaces any prior one and re-runs with source `"scheduled"`,
//!   `api.set` → [`SimulatorSetPort`], `output.set` →
//!   [`HardwareOutputPort`], `display.set` → [`DisplayPort`]; `api.get` is
//!   an unfulfilled intent, exactly like the oracle (`process_effects/4`);
//! - **manual** — `run_script/1` executes with source `"manual"` and nil
//!   value/value-data; `get_script_log/1` returns the bounded log
//!   (newest first, 100 entries — `append_log/2`);
//! - **containment** — compile errors park a script (it never fires, keeps
//!   an empty log); runtime errors and timeouts append a `[error] …` entry
//!   and leave the VM rolled back; every failure is scoped to its own
//!   script (`execute_script/4`);
//! - **cleanup** — train change, reload and shutdown cancel the poll timer
//!   and every schedule timer, unsubscribe, and drop the VMs
//!   (`cleanup/1`).
//!
//! ## Structural notes
//!
//! - The mailbox follows the [`crate::train::output_controller`] pattern
//!   (commands + oneshot replies); the oracle's `Train.subscribe()` events
//!   arrive as [`ScriptRunnerCommand::TrainChanged`] and the LiveViews'
//!   `ScriptRunner.reload_scripts()` as [`ScriptRunnerCommand::ReloadScripts`].
//! - `ScriptVm` holds `Rc`-based interpreter state and is therefore not
//!   `Send`, so the state machine runs as a `spawn_local` task on a
//!   dedicated host thread with its own current-thread runtime (same shape
//!   as the MCP SSE host in `crate::mcp::server::serve`). Every command
//!   payload is `Send`; the handle is freely cloneable and runtime-agnostic.
//! - Subscription polling reuses the output controller's
//!   [`SimulatorConnectionView`]/[`SimulatorSubscriptions`] seams;
//!   [`SimulatorSetPort`] is the separate `api.set` effect sink the oracle
//!   resolves per effect through `get_simulator_client/0`.

use std::collections::{BTreeMap, HashMap};
use std::sync::{
    atomic::{AtomicBool, Ordering},
    Arc,
};
use std::thread::JoinHandle;
use std::time::{Duration, Instant};

use serde_json::Value;
use tokio::sync::{mpsc, oneshot, Mutex};
use trenino_core::train::identifier::TrainProfile;

use crate::simulator::services::clock::Clock;
use crate::train::output_controller::{SimulatorConnectionView, SimulatorSubscriptions};

use super::effect::ScriptEffect;
use super::engine::{ScriptError, ScriptLimits, ScriptVm};
use super::event::{ScriptEvent, ScriptValue};
use super::triggers::{SOURCE_MANUAL, SOURCE_SCHEDULED};

/// `@poll_interval_ms` (script_runner.ex:29).
pub const POLL_INTERVAL: Duration = Duration::from_millis(200);
/// `@subscription_id_base` (script_runner.ex:30): 2000-2999, disjoint from
/// the output controller's 1000-1999.
pub const SUBSCRIPTION_ID_BASE: i64 = 2000;
pub const MAX_SUBSCRIPTIONS: usize = 1000;
/// `append_log/2` ring size: "Keep last 100 log entries"
/// (script_runner.ex:500-504).
pub const LOG_RING: usize = 100;

const COMMAND_QUEUE: usize = 256;
const HOST_THREAD_NAME: &str = "trenino-script-runner";
/// Maximum wait for one shutdown attempt. A stalled synchronous port remains
/// owned for a later retry; the host is never detached and declared stopped.
pub const SHUTDOWN_TIMEOUT: Duration = Duration::from_secs(1);
pub const RUN_ACK_TIMEOUT: Duration = Duration::from_secs(30);

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ScriptShutdownError {
    Timeout,
    HostClosed,
    HostPanicked,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ScriptRunError {
    Timeout,
    HostClosed,
}

/// The trigger-relevant projection of one enabled script row
/// (`Train.list_enabled_scripts/1`, train.ex:1275-1281 — enabled rows only,
/// unspecified order; the source provides a stable order).
#[derive(Clone, Debug, PartialEq)]
pub struct ScriptDefinition {
    pub id: i64,
    pub name: String,
    pub code: String,
    /// Endpoint paths; empty means the script only runs manually or via
    /// `schedule()` (lib/trenino/train/script.ex moduledoc).
    pub triggers: Vec<String>,
}

/// Storage seam for the enabled scripts of a train.
pub trait ScriptSource: Send + Sync + 'static {
    fn enabled_scripts(&self, train_id: i64) -> Vec<ScriptDefinition>;
}

/// Effect sink for `api.set(path, value)` — the oracle's
/// `process_effect {:api_set, path, value}` → `SimulatorClient.set/3`
/// (script_runner.ex:445-458). The implementer owns connection liveness: a
/// missing client is the oracle's "Simulator not connected for api.set"
/// warning path. `ScriptValue::Opaque` (a Lua table/function) fails here,
/// standing in for the oracle's JSON-encode failure warning.
pub trait SimulatorSetPort: Send + Sync + 'static {
    fn set(&self, path: &str, value: &ScriptValue) -> Result<(), String>;
}

/// Effect sink for `output.set(id, on)` — the oracle's
/// `apply_output_set/2`: `Train.get_output_by_id/1` →
/// `ConfigurationManager.config_id_to_port/1` → `Hardware.set_output/3`
/// (script_runner.ex:420-428, 460-477). Unknown output IDs and missing
/// ports are the implementer's warnings; they never reach the script log.
pub trait HardwareOutputPort: Send + Sync + 'static {
    fn set_output(&self, output_id: i64, on: bool);
}

/// Effect sink for `display.set(addr, text)` — the oracle's
/// `apply_display_set/2`: module lookup by I2C address →
/// `HT16K33.encode_string/2` → `Hardware.write_segments/3`
/// (script_runner.ex:430-438, 479-496). A missing module is the
/// implementer's warning.
pub trait DisplayPort: Send + Sync + 'static {
    fn write_display(&self, i2c_address: i64, text: &str);
}

/// Mailbox entries (`handle_cast`/`handle_call`/`handle_info`).
pub enum ScriptRunnerCommand {
    /// `{:train_changed, train | nil}` (script_runner.ex:153-164).
    TrainChanged(Option<TrainProfile>),
    /// `:reload_scripts` (script_runner.ex:121-128) — the cast the UI sends
    /// after script CRUD (train_edit_live.ex:518,534; script_edit_live.ex).
    ReloadScripts,
    /// `{:run_script, script_id}` (script_runner.ex:130-140).
    RunScript(i64, oneshot::Sender<bool>),
    /// `{:get_script_log, script_id}` call (script_runner.ex:143-151).
    GetScriptLog(i64, oneshot::Sender<Vec<String>>),
    Shutdown(oneshot::Sender<()>),
}

/// One script's runtime state — the `ScriptState` struct
/// (script_runner.ex:33-51).
struct ScriptState {
    /// `script.name`, retained like the oracle's `script_state.script`
    /// reference (it only feeds log warnings there).
    #[allow(dead_code)]
    name: String,
    /// `lua`: `None` mirrors a `compile_error` script (never fires).
    vm: Option<ScriptVm>,
    /// `last_values`: change-only firing gate per endpoint.
    last_values: HashMap<String, ScriptValue>,
    /// `scheduled_timer`: `Process.send_after({:scheduled_run, id}, ms)`.
    scheduled_deadline: Option<Instant>,
    #[allow(dead_code)]
    compile_error: Option<String>,
    /// `log`: newest first, bounded by [`LOG_RING`].
    log: Vec<String>,
}

/// The `State` struct (script_runner.ex:53-69).
#[derive(Default)]
struct State {
    active_train: Option<TrainProfile>,
    scripts: BTreeMap<i64, ScriptState>,
    subscriptions: BTreeMap<String, i64>,
    endpoint_to_scripts: BTreeMap<String, Vec<i64>>,
    poll_deadline: Option<Instant>,
}

/// Injected collaborators bundled for the state-machine functions.
struct RunnerDeps {
    source: Arc<dyn ScriptSource>,
    connection: Arc<dyn SimulatorConnectionView>,
    set_port: Arc<dyn SimulatorSetPort>,
    output_port: Arc<dyn HardwareOutputPort>,
    display_port: Arc<dyn DisplayPort>,
    clock: Arc<dyn Clock>,
    limits: ScriptLimits,
}

/// Handle to the script runner host.
#[derive(Clone)]
pub struct ScriptRunner {
    sender: mpsc::Sender<ScriptRunnerCommand>,
    host: Arc<Mutex<Option<JoinHandle<()>>>>,
    shutdown_gate: Arc<Mutex<()>>,
    shutdown_requested: Arc<AtomicBool>,
}

impl ScriptRunner {
    /// Starts the host thread. Mirrors `start_link` + `init/1`: no train is
    /// active until the first [`ScriptRunnerCommand::TrainChanged`] (the
    /// Rust activation flow pushes the profile, like the output controller;
    /// the oracle pulls `Train.get_active_train/0` in `init/1`).
    pub fn start(
        source: Arc<dyn ScriptSource>,
        connection: Arc<dyn SimulatorConnectionView>,
        set_port: Arc<dyn SimulatorSetPort>,
        output_port: Arc<dyn HardwareOutputPort>,
        display_port: Arc<dyn DisplayPort>,
        clock: Arc<dyn Clock>,
        limits: ScriptLimits,
    ) -> Self {
        let (sender, receiver) = mpsc::channel(COMMAND_QUEUE);
        let host = std::thread::Builder::new()
            .name(HOST_THREAD_NAME.to_string())
            .spawn(move || {
                host(
                    receiver,
                    RunnerDeps {
                        source,
                        connection,
                        set_port,
                        output_port,
                        display_port,
                        clock,
                        limits,
                    },
                )
            })
            .expect("failed to spawn script runner host thread");
        Self {
            sender,
            host: Arc::new(Mutex::new(Some(host))),
            shutdown_gate: Arc::new(Mutex::new(())),
            shutdown_requested: Arc::new(AtomicBool::new(false)),
        }
    }

    /// `{:train_changed, train | nil}`.
    pub async fn train_changed(&self, train: Option<TrainProfile>) {
        let _ = self
            .sender
            .send(ScriptRunnerCommand::TrainChanged(train))
            .await;
    }

    /// `reload_scripts/0`.
    pub async fn reload_scripts(&self) {
        let _ = self.sender.send(ScriptRunnerCommand::ReloadScripts).await;
    }

    /// `run_script/1` (manual source).
    pub async fn run_script(&self, script_id: i64) -> Result<bool, ScriptRunError> {
        if self.shutdown_requested.load(Ordering::Acquire) {
            return Err(ScriptRunError::HostClosed);
        }
        let (reply, done) = oneshot::channel();
        let deadline = tokio::time::Instant::now() + RUN_ACK_TIMEOUT;
        tokio::time::timeout_at(
            deadline,
            self.sender
                .send(ScriptRunnerCommand::RunScript(script_id, reply)),
        )
        .await
        .map_err(|_| ScriptRunError::Timeout)?
        .map_err(|_| ScriptRunError::HostClosed)?;
        tokio::time::timeout_at(deadline, done)
            .await
            .map_err(|_| ScriptRunError::Timeout)?
            .map_err(|_| ScriptRunError::HostClosed)
    }

    /// `get_script_log/1`; `None` only when the runner host is gone (the
    /// oracle would crash on a dead server).
    pub async fn get_script_log(&self, script_id: i64) -> Option<Vec<String>> {
        tokio::time::timeout(std::time::Duration::from_secs(1), async {
            let (reply, done) = oneshot::channel();
            self.sender
                .send(ScriptRunnerCommand::GetScriptLog(script_id, reply))
                .await
                .ok()?;
            done.await.ok()
        })
        .await
        .ok()
        .flatten()
    }

    /// Cleanup and join the host. A synchronous port that ignores its own IO
    /// deadline can stall the host; this call then returns `Timeout` and keeps
    /// the join handle for a later retry. Production ports must enforce their
    /// own deadlines for cleanup to finish.
    pub async fn shutdown(&self) -> Result<(), ScriptShutdownError> {
        let _gate = self.shutdown_gate.lock().await;
        let deadline = tokio::time::Instant::now() + SHUTDOWN_TIMEOUT;
        if !self.shutdown_requested.load(Ordering::Acquire) {
            let (reply, done) = oneshot::channel();
            tokio::time::timeout_at(
                deadline,
                self.sender.send(ScriptRunnerCommand::Shutdown(reply)),
            )
            .await
            .map_err(|_| ScriptShutdownError::Timeout)?
            .map_err(|_| ScriptShutdownError::HostClosed)?;
            self.shutdown_requested.store(true, Ordering::Release);
            tokio::time::timeout_at(deadline, done)
                .await
                .map_err(|_| ScriptShutdownError::Timeout)?
                .map_err(|_| ScriptShutdownError::HostClosed)?;
        }
        loop {
            let finished = self
                .host
                .lock()
                .await
                .as_ref()
                .is_none_or(JoinHandle::is_finished);
            if finished {
                break;
            }
            if tokio::time::Instant::now() >= deadline {
                return Err(ScriptShutdownError::Timeout);
            }
            tokio::time::sleep(Duration::from_millis(5)).await;
        }
        if let Some(handle) = self.host.lock().await.take() {
            handle
                .join()
                .map_err(|_| ScriptShutdownError::HostPanicked)?;
        }
        Ok(())
    }
}

/// Dedicated host thread: `ScriptVm` is not `Send` (mlua `Rc` state), so the
/// state machine runs as a `spawn_local` task on a private current-thread
/// runtime, mirroring the oracle's one-process-per-runner isolation.
fn host(receiver: mpsc::Receiver<ScriptRunnerCommand>, deps: RunnerDeps) {
    let Ok(runtime) = tokio::runtime::Builder::new_current_thread()
        .enable_all()
        .thread_name(HOST_THREAD_NAME)
        .build()
    else {
        return;
    };
    let local = tokio::task::LocalSet::new();
    local.spawn_local(run(receiver, deps));
    runtime.block_on(local);
}

async fn run(mut receiver: mpsc::Receiver<ScriptRunnerCommand>, deps: RunnerDeps) {
    let mut state = State::default();
    loop {
        // One shared timer await: the poll timer and every per-script
        // schedule timer are all `Process.send_after` messages in the
        // oracle; here the earliest deadline drives the wake.
        let deadline = next_deadline(&state);
        let command = match deadline {
            Some(deadline) => {
                let remaining = deadline.saturating_duration_since(deps.clock.now());
                let sleep = deps.clock.sleep(remaining);
                tokio::select! {
                    command = receiver.recv() => command,
                    () = sleep => {
                        fire_due_timers(&mut state, &deps);
                        continue;
                    }
                }
            }
            None => receiver.recv().await,
        };
        let Some(command) = command else { break };
        match command {
            ScriptRunnerCommand::TrainChanged(None) => {
                // "Train deactivated, cleaning up" (script_runner.ex:153-158)
                cleanup(&mut state, &*deps.connection);
                state.active_train = None;
            }
            ScriptRunnerCommand::TrainChanged(Some(train)) => {
                // "Train activated" (script_runner.ex:160-164)
                cleanup(&mut state, &*deps.connection);
                load_scripts_for_train(&mut state, &deps, train);
            }
            ScriptRunnerCommand::ReloadScripts => match state.active_train.clone() {
                // No active train: nothing to reload (script_runner.ex:121-123)
                None => {}
                Some(train) => {
                    cleanup(&mut state, &*deps.connection);
                    load_scripts_for_train(&mut state, &deps, train);
                }
            },
            ScriptRunnerCommand::RunScript(script_id, reply) => {
                // The caller may have timed out or gone away while this
                // command waited behind a poll or another synchronous port.
                if reply.is_closed() {
                    continue;
                }
                // (script_runner.ex:130-140): unknown id is a no-op; a
                // compile-error script reaches execute_script and no-ops.
                let executable = state
                    .scripts
                    .get(&script_id)
                    .is_some_and(|script| script.vm.is_some());
                let prior_schedule = state
                    .scripts
                    .get(&script_id)
                    .and_then(|script| script.scheduled_deadline);
                if executable {
                    let event = ScriptEvent {
                        source: SOURCE_MANUAL.to_string(),
                        value: ScriptValue::Nil,
                        data: None,
                    };
                    execute_script_guarded(&mut state, &deps, script_id, &event, Some(&reply));
                }
                if reply.is_closed() {
                    restore_manual_schedule(&mut state, script_id, prior_schedule);
                    continue;
                }
                if reply.send(executable).is_err() {
                    restore_manual_schedule(&mut state, script_id, prior_schedule);
                }
            }
            ScriptRunnerCommand::GetScriptLog(script_id, reply) => {
                // (script_runner.ex:143-151): [] for an unknown script.
                let log = state
                    .scripts
                    .get(&script_id)
                    .map(|script| script.log.clone())
                    .unwrap_or_default();
                let _ = reply.send(log);
            }
            ScriptRunnerCommand::Shutdown(reply) => {
                cleanup(&mut state, &*deps.connection);
                let _ = reply.send(());
                break;
            }
        }
    }
}

/// Earliest of the poll timer and every script's schedule timer.
fn next_deadline(state: &State) -> Option<Instant> {
    let scheduled = state
        .scripts
        .values()
        .filter_map(|script| script.scheduled_deadline);
    state.poll_deadline.into_iter().chain(scheduled).min()
}

enum Due {
    Scheduled(i64),
    Poll,
}

/// Fires every due timer in deadline order (the oracle receives the
/// `Process.send_after` messages in send-time order): each scheduled run
/// clears its timer BEFORE executing (script_runner.ex:174-186), the poll
/// tick always re-arms itself (script_runner.ex:169-172, 506-510).
fn fire_due_timers(state: &mut State, deps: &RunnerDeps) {
    let now = deps.clock.now();
    let mut due: Vec<(Instant, Due)> = Vec::new();
    if state.poll_deadline.is_some_and(|deadline| deadline <= now) {
        due.push((state.poll_deadline.expect("checked above"), Due::Poll));
    }
    for (id, script) in &state.scripts {
        if let Some(deadline) = script.scheduled_deadline {
            if deadline <= now {
                due.push((deadline, Due::Scheduled(*id)));
            }
        }
    }
    due.sort_by_key(|(deadline, _)| *deadline);
    for (deadline, item) in due {
        match item {
            Due::Scheduled(script_id) => {
                // A preceding poll can run the same script and replace this
                // timer. Do not execute the stale item from the snapshot.
                let Some(script) = state.scripts.get_mut(&script_id) else {
                    continue;
                };
                if script.scheduled_deadline != Some(deadline) {
                    continue;
                }
                script.scheduled_deadline = None;
                let event = ScriptEvent {
                    source: SOURCE_SCHEDULED.to_string(),
                    value: ScriptValue::Nil,
                    data: None,
                };
                execute_script(state, deps, script_id, &event);
            }
            Due::Poll => {
                poll_and_execute(state, deps);
                state.poll_deadline = Some(deps.clock.now() + POLL_INTERVAL);
            }
        }
    }
}

/// `load_scripts_for_train/2` (script_runner.ex:192-216).
fn load_scripts_for_train(state: &mut State, deps: &RunnerDeps, train: TrainProfile) {
    let scripts = deps.source.enabled_scripts(train.id);
    state.active_train = Some(train);
    if scripts.is_empty() {
        // "No scripts for train …" — maps cleared, poll timer NOT armed.
        state.scripts.clear();
        state.subscriptions.clear();
        state.endpoint_to_scripts.clear();
        return;
    }
    state.scripts = compile_scripts(scripts.as_slice(), &deps.limits);
    match setup_subscriptions(deps, &scripts) {
        Ok((subscriptions, endpoint_to_scripts)) => {
            state.subscriptions = subscriptions;
            state.endpoint_to_scripts = endpoint_to_scripts;
        }
        Err(error) => {
            for script in state.scripts.values_mut() {
                append_log(script, &error);
            }
            state.subscriptions.clear();
            state.endpoint_to_scripts.clear();
        }
    }
    schedule_poll(state, &*deps.clock);
}

/// `compile_scripts/1` (script_runner.ex:218-232): one VM per script; a
/// compile failure parks the script (`compile_error` set, `lua` nil).
fn compile_scripts(
    scripts: &[ScriptDefinition],
    limits: &ScriptLimits,
) -> BTreeMap<i64, ScriptState> {
    scripts
        .iter()
        .map(|definition| {
            let (vm, compile_error) = match ScriptVm::compile(&definition.code, limits.clone()) {
                Ok(vm) => (Some(vm), None),
                Err(reason) => (None, Some(reason.to_string())),
            };
            (
                definition.id,
                ScriptState {
                    name: definition.name.clone(),
                    vm,
                    last_values: HashMap::new(),
                    scheduled_deadline: None,
                    compile_error,
                    log: Vec::new(),
                },
            )
        })
        .collect()
}

/// `setup_subscriptions/1` (script_runner.ex:234-275): group scripts by
/// trigger endpoint (script-list order preserved within each group), then
/// subscribe once per unique endpoint with IDs 2000+index. The oracle
/// iterates `Map.keys/1` — lexicographic for its small maps — so the IDs
/// follow lexicographic endpoint order here too; a failed subscribe is
/// logged only, and the (endpoint, id) entry is kept exactly like
/// `subscribe_to_endpoints/2` does (its polls then no-op).
type SubscriptionMaps = (BTreeMap<String, i64>, BTreeMap<String, Vec<i64>>);
fn setup_subscriptions(
    deps: &RunnerDeps,
    scripts: &[ScriptDefinition],
) -> Result<SubscriptionMaps, String> {
    let mut endpoint_to_scripts: BTreeMap<String, Vec<i64>> = BTreeMap::new();
    for script in scripts {
        for trigger in &script.triggers {
            endpoint_to_scripts
                .entry(trigger.clone())
                .or_default()
                .push(script.id);
        }
    }
    if endpoint_to_scripts.len() > MAX_SUBSCRIPTIONS {
        return Err(format!(
            "[error] Script subscription limit exceeded ({MAX_SUBSCRIPTIONS})"
        ));
    }
    let mut subscriptions = BTreeMap::new();
    if let Some(client) = deps.connection.connected_client() {
        for (index, endpoint) in endpoint_to_scripts.keys().enumerate() {
            let subscription_id = SUBSCRIPTION_ID_BASE + index as i64;
            let _ = client.subscribe(endpoint, subscription_id);
            subscriptions.insert(endpoint.clone(), subscription_id);
        }
    }
    // No connected client: "cannot set up subscriptions" — empty map, but
    // the scripts (and their schedule/manual paths) stay live.
    Ok((subscriptions, endpoint_to_scripts))
}

/// `schedule_poll/1` (script_runner.ex:506-510): cancel-and-rearm.
fn schedule_poll(state: &mut State, clock: &dyn Clock) {
    state.poll_deadline = Some(clock.now() + POLL_INTERVAL);
}

/// `cleanup/1` (script_runner.ex:512-533): cancel the poll timer, cancel
/// every schedule timer (dropping the script states drops their VMs),
/// unsubscribe every subscription, clear the maps.
fn cleanup(state: &mut State, connection: &dyn SimulatorConnectionView) {
    state.poll_deadline = None;
    state.scripts.clear();
    if let Some(client) = connection.connected_client() {
        for subscription_id in state.subscriptions.values() {
            let _ = client.unsubscribe(*subscription_id);
        }
    }
    state.subscriptions.clear();
    state.endpoint_to_scripts.clear();
}

/// `poll_and_execute/1` (script_runner.ex:277-289): nothing to do with no
/// subscriptions or no connected client.
fn poll_and_execute(state: &mut State, deps: &RunnerDeps) {
    if state.subscriptions.is_empty() {
        return;
    }
    let Some(client) = deps.connection.connected_client() else {
        return;
    };
    let endpoints: Vec<(String, i64)> = state
        .subscriptions
        .iter()
        .map(|(endpoint, id)| (endpoint.clone(), *id))
        .collect();
    for (endpoint, subscription_id) in endpoints {
        poll_endpoint(&*client, state, deps, &endpoint, subscription_id);
    }
}

/// `poll_endpoint/4` (script_runner.ex:291-300): fetch errors and unusable
/// envelopes leave state untouched.
fn poll_endpoint(
    client: &dyn SimulatorSubscriptions,
    state: &mut State,
    deps: &RunnerDeps,
    endpoint: &str,
    subscription_id: i64,
) {
    let Ok(body) = client.get_subscription(subscription_id) else {
        return;
    };
    let Some(entries) = body.get("Entries").and_then(Value::as_array) else {
        return;
    };
    if entries.is_empty() {
        return;
    }
    let value = extract_subscription_value(entries);
    check_and_fire(state, deps, endpoint, &value, entries);
}

/// `extract_subscription_value/1` (script_runner.ex:302-313): first entry's
/// `"Values"` map, first value; nil when absent or empty. Small Elixir maps
/// iterate in key term order, so "first" is the lexicographically smallest
/// key — the same entry `serde_json`'s (BTree-)ordered objects yield.
fn extract_subscription_value(entries: &[Value]) -> ScriptValue {
    match entries
        .first()
        .and_then(|entry| entry.get("Values"))
        .and_then(Value::as_object)
    {
        Some(values) => values
            .values()
            .next()
            .map(json_to_script_value)
            .unwrap_or(ScriptValue::Nil),
        None => ScriptValue::Nil,
    }
}

/// `build_data/1` (script_runner.ex:366-371): the whole first-entry
/// `"Values"` map, or nil.
fn build_data(entries: &[Value]) -> Option<BTreeMap<String, ScriptValue>> {
    entries
        .first()
        .and_then(|entry| entry.get("Values"))
        .and_then(Value::as_object)
        .map(|values| {
            values
                .iter()
                .map(|(key, value)| (key.clone(), json_to_script_value(value)))
                .collect()
        })
}

/// JSON term → Lua-representable value. JSON `null` (and containers, which
/// TSW subscriptions never carry) encode as nil, like `Lua.encode!/2`
/// dropping nil-valued keys.
fn json_to_script_value(value: &Value) -> ScriptValue {
    match value {
        Value::Bool(bit) => ScriptValue::Boolean(*bit),
        Value::Number(number) => {
            if let Some(int) = number.as_i64() {
                ScriptValue::Integer(int)
            } else {
                number
                    .as_f64()
                    .map(ScriptValue::Float)
                    .unwrap_or(ScriptValue::Nil)
            }
        }
        Value::String(text) => ScriptValue::String(text.clone()),
        _ => ScriptValue::Nil,
    }
}

/// `check_and_fire/4` (script_runner.ex:315-321): fire every script mapped
/// to the endpoint, in script-list order.
fn check_and_fire(
    state: &mut State,
    deps: &RunnerDeps,
    endpoint: &str,
    value: &ScriptValue,
    entries: &[Value],
) {
    let script_ids = state
        .endpoint_to_scripts
        .get(endpoint)
        .cloned()
        .unwrap_or_default();
    for script_id in script_ids {
        maybe_fire_script(state, deps, script_id, endpoint, value, entries);
    }
}

/// `maybe_fire_script/5` (script_runner.ex:323-340): compile-error scripts
/// never fire; an unchanged value (nil compared to nil included) does not
/// fire.
fn maybe_fire_script(
    state: &mut State,
    deps: &RunnerDeps,
    script_id: i64,
    endpoint: &str,
    value: &ScriptValue,
    entries: &[Value],
) {
    let Some(script) = state.scripts.get(&script_id) else {
        return;
    };
    if script.vm.is_none() {
        return;
    }
    let last = script
        .last_values
        .get(endpoint)
        .cloned()
        .unwrap_or(ScriptValue::Nil);
    if last == *value {
        return;
    }
    // `fire_script/6` (script_runner.ex:342-364): record the observation,
    // then execute with source = endpoint, value and full data.
    let script = state.scripts.get_mut(&script_id).expect("present above");
    script
        .last_values
        .insert(endpoint.to_string(), value.clone());
    let event = ScriptEvent {
        source: endpoint.to_string(),
        value: value.clone(),
        data: build_data(entries),
    };
    execute_script(state, deps, script_id, &event);
}

/// `execute_script/4` (script_runner.ex:373-398).
fn execute_script(state: &mut State, deps: &RunnerDeps, script_id: i64, event: &ScriptEvent) {
    execute_script_guarded(state, deps, script_id, event, None);
}

fn restore_manual_schedule(state: &mut State, script_id: i64, previous: Option<Instant>) {
    if let Some(script) = state.scripts.get_mut(&script_id) {
        script.scheduled_deadline = previous;
    }
}

fn execute_script_guarded(
    state: &mut State,
    deps: &RunnerDeps,
    script_id: i64,
    event: &ScriptEvent,
    manual_reply: Option<&oneshot::Sender<bool>>,
) {
    {
        let Some(script) = state.scripts.get_mut(&script_id) else {
            return;
        };
        let Some(vm) = script.vm.as_mut() else {
            // lua nil (compile error): no-op (script_runner.ex:373-375).
            return;
        };
        match vm.execute(event) {
            Ok(effects) => {
                // `process_effects/4`: chronological order, state threaded.
                for effect in effects {
                    if manual_reply.is_some_and(oneshot::Sender::is_closed) {
                        break;
                    }
                    process_effect(state, deps, script_id, effect);
                }
            }
            Err(reason) => {
                if manual_reply.is_some_and(oneshot::Sender::is_closed) {
                    return;
                }
                // `{:ok, {:error, reason}}` / timeout: log entry, VM state
                // rolled back (script_runner.ex:386-396).
                let entry = error_log_entry(&reason, &deps.limits);
                if let Some(script) = state.scripts.get_mut(&script_id) {
                    append_log(script, &entry);
                }
            }
        }
    }
}

/// `process_effect/4` (script_runner.ex:406-458).
fn process_effect(state: &mut State, deps: &RunnerDeps, script_id: i64, effect: ScriptEffect) {
    match effect {
        ScriptEffect::Log { message } => {
            if let Some(script) = state.scripts.get_mut(&script_id) {
                append_log(script, &message);
            }
        }
        ScriptEffect::Schedule { ms } => {
            // Cancel any prior timer by replacement (script_runner.ex:410-418).
            if let Some(script) = state.scripts.get_mut(&script_id) {
                // Lua accepts positive fractional delays but truncates them
                // to zero. Reject that intent rather than arm an immediate
                // self-rescheduling loop. This is an explicit safety bound.
                if ms == 0 {
                    script.scheduled_deadline = None;
                    append_log(script, "[error] schedule delay must be at least 1ms");
                } else {
                    script.scheduled_deadline = Some(deps.clock.now() + Duration::from_millis(ms));
                }
            }
        }
        ScriptEffect::OutputSet { output_id, on } => {
            deps.output_port.set_output(output_id, on);
        }
        ScriptEffect::DisplaySet { i2c_address, text } => {
            deps.display_port.write_display(i2c_address, &text);
        }
        // `{:api_get, _path}`: intent only (script_runner.ex:440-443).
        ScriptEffect::ApiGet { .. } => {}
        ScriptEffect::ApiSet { path, value } => {
            // Failures are the port's warning path (script_runner.ex:445-458).
            let _ = deps.set_port.set(&path, &value);
        }
    }
}

/// `append_log/2` (script_runner.ex:500-504): newest first,
/// `Enum.take([message | log], 100)`.
fn append_log(script: &mut ScriptState, message: &str) {
    script.log.insert(0, message.to_string());
    let excess = script.log.len().saturating_sub(LOG_RING);
    if excess > 0 {
        let keep = script.log.len() - excess;
        script.log.truncate(keep);
    }
}

/// The oracle's two failure log lines (script_runner.ex:387, 393): the
/// timeout line interpolates `@execution_timeout_ms`; here the same value
/// arrives as the engine's `execution_wall` limit.
fn error_log_entry(error: &ScriptError, limits: &ScriptLimits) -> String {
    match error {
        ScriptError::Timeout => format!(
            "[error] Script execution timed out ({}ms)",
            limits.execution_wall.as_millis()
        ),
        other => format!("[error] {other}"),
    }
}
