//! ScriptRunner lifecycle parity with lib/trenino/train/script_runner.ex.

use std::collections::HashMap;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};
use std::time::Duration;

use serde_json::{json, Value};
use trenino_core::train::identifier::TrainProfile;
use trenino_runtime::simulator::services::clock::FakeClock;
use trenino_runtime::train::output_controller::{SimulatorConnectionView, SimulatorSubscriptions};
use trenino_runtime::train::script::{
    DisplayPort, HardwareOutputPort, ScriptDefinition, ScriptLimits, ScriptRunner, ScriptSource,
    ScriptValue, SimulatorSetPort,
};

#[derive(Default)]
struct Source(Mutex<HashMap<i64, Vec<ScriptDefinition>>>);
impl ScriptSource for Source {
    fn enabled_scripts(&self, train_id: i64) -> Vec<ScriptDefinition> {
        self.0
            .lock()
            .unwrap()
            .get(&train_id)
            .cloned()
            .unwrap_or_default()
    }
}

#[derive(Default)]
struct Simulator {
    ids: Mutex<HashMap<String, i64>>,
    values: Mutex<HashMap<i64, Value>>,
    unsubscribed: Mutex<Vec<i64>>,
}
impl SimulatorSubscriptions for Simulator {
    fn subscribe(&self, endpoint: &str, id: i64) -> Result<(), String> {
        self.ids.lock().unwrap().insert(endpoint.into(), id);
        Ok(())
    }
    fn get_subscription(&self, id: i64) -> Result<Value, String> {
        self.values
            .lock()
            .unwrap()
            .get(&id)
            .cloned()
            .ok_or("absent".into())
    }
    fn unsubscribe(&self, id: i64) -> Result<(), String> {
        self.unsubscribed.lock().unwrap().push(id);
        Ok(())
    }
}
struct Connection(Arc<Simulator>);
impl SimulatorConnectionView for Connection {
    fn connected_client(&self) -> Option<Arc<dyn SimulatorSubscriptions>> {
        Some(self.0.clone())
    }
}

#[derive(Default)]
struct Effects(Mutex<Vec<String>>);
impl SimulatorSetPort for Effects {
    fn set(&self, path: &str, value: &ScriptValue) -> Result<(), String> {
        self.0.lock().unwrap().push(format!("api:{path}:{value:?}"));
        Ok(())
    }
}
impl HardwareOutputPort for Effects {
    fn set_output(&self, id: i64, on: bool) {
        self.0.lock().unwrap().push(format!("output:{id}:{on}"));
    }
}
impl DisplayPort for Effects {
    fn write_display(&self, address: i64, text: &str) {
        self.0
            .lock()
            .unwrap()
            .push(format!("display:{address}:{text}"));
    }
}

struct Harness {
    source: Arc<Source>,
    simulator: Arc<Simulator>,
    effects: Arc<Effects>,
    clock: FakeClock,
    runner: ScriptRunner,
}
impl Harness {
    fn new() -> Self {
        let source = Arc::new(Source::default());
        let simulator = Arc::new(Simulator::default());
        let effects = Arc::new(Effects::default());
        let clock = FakeClock::new();
        let runner = ScriptRunner::start(
            source.clone(),
            Arc::new(Connection(simulator.clone())),
            effects.clone(),
            effects.clone(),
            effects.clone(),
            Arc::new(clock.clone()),
            ScriptLimits::default(),
        );
        Self {
            source,
            simulator,
            effects,
            clock,
            runner,
        }
    }
    fn script(&self, train_id: i64, code: &str, triggers: &[&str]) {
        self.source.0.lock().unwrap().insert(
            train_id,
            vec![ScriptDefinition {
                id: 7,
                name: "Test".into(),
                code: code.into(),
                triggers: triggers.iter().map(|s| (*s).into()).collect(),
            }],
        );
    }
    async fn activate(&self, id: i64) {
        self.runner
            .train_changed(Some(TrainProfile {
                id,
                name: format!("Train {id}"),
                identifiers: vec![],
            }))
            .await;
        self.runner.get_script_log(7).await.unwrap(); // mailbox barrier
    }
    fn reading(&self, endpoint: &str, value: Value) {
        let id = *self.simulator.ids.lock().unwrap().get(endpoint).unwrap();
        self.simulator.values.lock().unwrap().insert(
            id,
            json!({
                "Entries": [{"Values": {"Value": value, "ZExtra": 42}}]
            }),
        );
    }
    async fn tick(&self) {
        self.clock.advance(Duration::from_millis(200));
        // The host is on its own thread; wait until it has observed the clock.
        tokio::time::sleep(Duration::from_millis(20)).await;
        self.runner.get_script_log(7).await.unwrap();
    }
}

#[tokio::test]
async fn polls_only_changed_values_and_passes_full_event_data() {
    let h = Harness::new();
    h.script(
        1,
        "function on_change(e) print(e.source, e.value, e.data.ZExtra) end",
        &["Brake"],
    );
    h.activate(1).await;
    assert_eq!(h.simulator.ids.lock().unwrap().len(), 1);
    h.reading("Brake", json!(1));
    h.tick().await;
    assert_eq!(h.runner.get_script_log(7).await.unwrap(), ["Brake\t1\t42"]);
    h.tick().await;
    assert_eq!(h.runner.get_script_log(7).await.unwrap().len(), 1);
    h.reading("Brake", json!(2));
    h.tick().await;
    assert_eq!(h.runner.get_script_log(7).await.unwrap().len(), 2);
    h.runner.shutdown().await.unwrap();
}

#[tokio::test]
async fn manual_run_acknowledges_only_a_resident_compiled_script() {
    let h = Harness::new();
    assert_eq!(h.runner.run_script(7).await, Ok(false));
    h.script(1, "function on_change(", &[]);
    h.activate(1).await;
    assert_eq!(h.runner.run_script(7).await, Ok(false));
    h.script(1, "function on_change(e) print('manual') end", &[]);
    h.runner.reload_scripts().await;
    assert_eq!(h.runner.run_script(99).await, Ok(false));
    assert_eq!(h.runner.run_script(7).await, Ok(true));
    assert_eq!(h.runner.get_script_log(7).await.unwrap(), ["manual"]);
    h.runner.shutdown().await.unwrap();
    assert!(h.runner.run_script(7).await.is_err());
}

#[tokio::test]
async fn reload_cancels_old_schedule_and_replaces_vm_before_timer_fires() {
    let h = Harness::new();
    h.script(
        1,
        "function on_change(e) print(e.source); schedule(500) end",
        &[],
    );
    h.activate(1).await;
    h.runner.run_script(7).await.unwrap();
    assert_eq!(h.runner.get_script_log(7).await.unwrap(), ["manual"]);
    h.script(1, "function on_change(e) print('new', e.source) end", &[]);
    h.runner.reload_scripts().await;
    assert!(h.runner.get_script_log(7).await.unwrap().is_empty());
    h.clock.advance(Duration::from_millis(600));
    tokio::time::sleep(Duration::from_millis(20)).await;
    assert!(h.runner.get_script_log(7).await.unwrap().is_empty());
    h.runner.run_script(7).await.unwrap();
    assert_eq!(h.runner.get_script_log(7).await.unwrap(), ["new\tmanual"]);
    h.runner.shutdown().await.unwrap();
}

#[tokio::test]
async fn failing_run_discards_effects_and_keeps_the_script_usable() {
    let h = Harness::new();
    h.script(1, "function on_change(e) if e.source == 'manual' then api.set('Bad', 1); error('boom') else api.set('Good', 2) end end", &[]);
    h.activate(1).await;
    h.runner.run_script(7).await.unwrap();
    assert!(h.runner.get_script_log(7).await.unwrap()[0].starts_with("[error]"));
    assert!(h.effects.0.lock().unwrap().is_empty());
    h.runner.shutdown().await.unwrap();
}

#[tokio::test]
async fn applies_successful_effects_in_lua_call_order() {
    let h = Harness::new();
    h.script(
        1,
        "function on_change(e) api.set('A', 1); output.set(3, true); display.set(112, 'Hi'); api.set('B', false) end",
        &[],
    );
    h.activate(1).await;
    h.runner.run_script(7).await.unwrap();
    h.runner.get_script_log(7).await.unwrap();
    assert_eq!(
        *h.effects.0.lock().unwrap(),
        [
            "api:A:Integer(1)",
            "output:3:true",
            "display:112:Hi",
            "api:B:Boolean(false)",
        ]
    );
    h.runner.shutdown().await.unwrap();
}

#[tokio::test]
async fn train_switch_releases_subscriptions_and_old_schedules() {
    let h = Harness::new();
    h.script(
        1,
        "function on_change(e) print(e.source); schedule(500) end",
        &["Brake"],
    );
    h.activate(1).await;
    h.runner.run_script(7).await.unwrap();
    assert_eq!(h.runner.get_script_log(7).await.unwrap(), ["manual"]);
    h.activate(2).await;
    assert_eq!(h.simulator.unsubscribed.lock().unwrap().as_slice(), &[2000]);
    h.clock.advance(Duration::from_millis(600));
    tokio::time::sleep(Duration::from_millis(20)).await;
    assert!(h.runner.get_script_log(7).await.unwrap().is_empty());
    h.runner.shutdown().await.unwrap();
}

#[tokio::test]
async fn keeps_only_the_newest_hundred_log_entries() {
    let h = Harness::new();
    h.script(
        1,
        "function on_change(e) state.n = (state.n or 0) + 1; print(state.n) end",
        &[],
    );
    h.activate(1).await;
    for _ in 0..101 {
        h.runner.run_script(7).await.unwrap();
    }
    let log = h.runner.get_script_log(7).await.unwrap();
    assert_eq!(log.len(), 100);
    assert_eq!(log.first().unwrap(), "101");
    assert_eq!(log.last().unwrap(), "2");
    h.runner.shutdown().await.unwrap();
}

#[tokio::test]
async fn poll_replaces_a_due_schedule_without_running_the_old_callback() {
    let h = Harness::new();
    h.script(1, "function on_change(e) if e.source == 'manual' then schedule(200) elseif e.source == 'Brake' then schedule(500) else print(e.source) end end", &["Brake"]);
    h.activate(1).await;
    h.runner.run_script(7).await.unwrap();
    h.runner.get_script_log(7).await.unwrap();
    h.reading("Brake", json!(1));
    h.tick().await;
    assert!(h.runner.get_script_log(7).await.unwrap().is_empty());
    h.clock.advance(Duration::from_millis(499));
    tokio::time::sleep(Duration::from_millis(10)).await;
    assert!(h.runner.get_script_log(7).await.unwrap().is_empty());
    h.clock.advance(Duration::from_millis(1));
    tokio::time::sleep(Duration::from_millis(10)).await;
    assert_eq!(h.runner.get_script_log(7).await.unwrap(), ["scheduled"]);
    h.runner.shutdown().await.unwrap();
}

#[tokio::test]
async fn submillisecond_schedule_waits_for_clock_instead_of_spinning() {
    let h = Harness::new();
    h.script(
        1,
        "function on_change(e) print(e.source); schedule(0.5) end",
        &[],
    );
    h.activate(1).await;
    h.runner.run_script(7).await.unwrap();
    let log = tokio::time::timeout(Duration::from_secs(2), h.runner.get_script_log(7))
        .await
        .expect("runner starved its mailbox")
        .unwrap();
    assert_eq!(log.len(), 2);
    assert!(log[0].contains("schedule delay"));
    assert_eq!(log[1], "manual");
    h.clock.advance(Duration::from_secs(1));
    tokio::time::sleep(Duration::from_millis(10)).await;
    assert_eq!(h.runner.get_script_log(7).await.unwrap(), log);
    h.runner.shutdown().await.unwrap();
}

#[tokio::test]
async fn subscription_range_overflow_is_rejected_before_any_subscribe() {
    let h = Harness::new();
    let triggers: Vec<String> = (0..1001).map(|n| format!("Endpoint.{n:04}")).collect();
    h.source.0.lock().unwrap().insert(
        1,
        vec![ScriptDefinition {
            id: 7,
            name: "Too many".into(),
            code: "function on_change(e) end".into(),
            triggers,
        }],
    );
    h.activate(1).await;
    assert!(h.simulator.ids.lock().unwrap().is_empty());
    assert!(h.runner.get_script_log(7).await.unwrap()[0].contains("subscription"));
    h.runner.shutdown().await.unwrap();
}

#[derive(Default)]
struct BlockingSimulator {
    entered: AtomicBool,
    release: AtomicBool,
}
impl SimulatorSubscriptions for BlockingSimulator {
    fn subscribe(&self, _endpoint: &str, _id: i64) -> Result<(), String> {
        Ok(())
    }
    fn get_subscription(&self, _id: i64) -> Result<Value, String> {
        self.entered.store(true, Ordering::SeqCst);
        while !self.release.load(Ordering::SeqCst) {
            std::thread::sleep(Duration::from_millis(1));
        }
        Err("released".into())
    }
    fn unsubscribe(&self, _id: i64) -> Result<(), String> {
        Ok(())
    }
}
struct BlockingConnection(Arc<BlockingSimulator>);
impl SimulatorConnectionView for BlockingConnection {
    fn connected_client(&self) -> Option<Arc<dyn SimulatorSubscriptions>> {
        Some(self.0.clone())
    }
}

#[tokio::test]
async fn stalled_port_makes_shutdown_retryable_and_keeps_host_owned() {
    let source = Arc::new(Source::default());
    source.0.lock().unwrap().insert(
        1,
        vec![ScriptDefinition {
            id: 7,
            name: "Blocking".into(),
            code: "function on_change(e) end".into(),
            triggers: vec!["Brake".into()],
        }],
    );
    let simulator = Arc::new(BlockingSimulator::default());
    let clock = FakeClock::new();
    let effects = Arc::new(Effects::default());
    let runner = ScriptRunner::start(
        source,
        Arc::new(BlockingConnection(simulator.clone())),
        effects.clone(),
        effects.clone(),
        effects,
        Arc::new(clock.clone()),
        ScriptLimits::default(),
    );
    runner
        .train_changed(Some(TrainProfile {
            id: 1,
            name: "Train".into(),
            identifiers: vec![],
        }))
        .await;
    runner.get_script_log(7).await.unwrap();
    clock.advance(Duration::from_millis(200));
    tokio::time::timeout(Duration::from_secs(2), async {
        while !simulator.entered.load(Ordering::SeqCst) {
            tokio::time::sleep(Duration::from_millis(1)).await;
        }
    })
    .await
    .unwrap();
    assert!(
        tokio::time::timeout(Duration::from_millis(1500), runner.get_script_log(7))
            .await
            .expect("log request waited forever behind a blocked port")
            .is_none()
    );
    let first = tokio::time::timeout(Duration::from_secs(2), runner.shutdown())
        .await
        .expect("shutdown waited forever");
    assert!(first.is_err(), "blocked host must not be reported stopped");
    simulator.release.store(true, Ordering::SeqCst);
    runner
        .shutdown()
        .await
        .expect("retry joins the retained host");
}

#[tokio::test]
async fn abandoned_queued_manual_run_never_enters_the_vm_or_effect_port() {
    let source = Arc::new(Source::default());
    source.0.lock().unwrap().insert(
        1,
        vec![ScriptDefinition {
            id: 7,
            name: "Queued".into(),
            code: "function on_change(e) output.set(4, true); schedule(500) end".into(),
            triggers: vec!["Brake".into()],
        }],
    );
    let simulator = Arc::new(BlockingSimulator::default());
    let clock = FakeClock::new();
    let effects = Arc::new(Effects::default());
    let runner = ScriptRunner::start(
        source,
        Arc::new(BlockingConnection(simulator.clone())),
        effects.clone(),
        effects.clone(),
        effects.clone(),
        Arc::new(clock.clone()),
        ScriptLimits::default(),
    );
    runner
        .train_changed(Some(TrainProfile {
            id: 1,
            name: "Train".into(),
            identifiers: vec![],
        }))
        .await;
    runner.get_script_log(7).await.unwrap();
    clock.advance(Duration::from_millis(200));
    tokio::time::timeout(Duration::from_secs(2), async {
        while !simulator.entered.load(Ordering::SeqCst) {
            tokio::time::sleep(Duration::from_millis(1)).await;
        }
    })
    .await
    .unwrap();
    let mut request = Box::pin(runner.run_script(7));
    std::future::poll_fn(|cx| {
        assert!(std::future::Future::poll(request.as_mut(), cx).is_pending());
        std::task::Poll::Ready(())
    })
    .await;
    drop(request); // Same receiver loss as an ACK deadline.
    simulator.release.store(true, Ordering::SeqCst);
    runner.get_script_log(7).await.unwrap(); // host mailbox barrier
    clock.advance(Duration::from_millis(500));
    tokio::time::sleep(Duration::from_millis(20)).await;
    runner.get_script_log(7).await.unwrap();
    assert!(effects.0.lock().unwrap().is_empty());
    runner.shutdown().await.unwrap();
}

#[derive(Default)]
struct GatedOutput {
    entered: AtomicBool,
    release: AtomicBool,
    calls: Mutex<Vec<i64>>,
}
impl HardwareOutputPort for GatedOutput {
    fn set_output(&self, output_id: i64, _on: bool) {
        self.calls.lock().unwrap().push(output_id);
        if output_id == 4 {
            self.entered.store(true, Ordering::SeqCst);
            while !self.release.load(Ordering::SeqCst) {
                std::thread::sleep(Duration::from_millis(1));
            }
        }
    }
}

#[tokio::test]
async fn abandoned_active_manual_run_stops_later_effects_and_its_schedule() {
    let source = Arc::new(Source::default());
    source.0.lock().unwrap().insert(
        1,
        vec![ScriptDefinition {
            id: 7,
            name: "Gated".into(),
            code: "function on_change(e) if e.source == 'manual' then schedule(500); output.set(4, true); output.set(5, true) else output.set(6, true) end end".into(),
            triggers: vec![],
        }],
    );
    let simulator = Arc::new(Simulator::default());
    let clock = FakeClock::new();
    let effects = Arc::new(Effects::default());
    let outputs = Arc::new(GatedOutput::default());
    let runner = ScriptRunner::start(
        source,
        Arc::new(Connection(simulator)),
        effects.clone(),
        outputs.clone(),
        effects,
        Arc::new(clock.clone()),
        ScriptLimits::default(),
    );
    runner
        .train_changed(Some(TrainProfile {
            id: 1,
            name: "Train".into(),
            identifiers: vec![],
        }))
        .await;
    runner.get_script_log(7).await.unwrap();
    let running = tokio::spawn({
        let runner = runner.clone();
        async move { runner.run_script(7).await }
    });
    tokio::time::timeout(Duration::from_secs(2), async {
        while !outputs.entered.load(Ordering::SeqCst) {
            tokio::time::sleep(Duration::from_millis(1)).await;
        }
    })
    .await
    .unwrap();
    running.abort();
    let _ = running.await;
    outputs.release.store(true, Ordering::SeqCst);
    runner.get_script_log(7).await.unwrap();
    assert_eq!(*outputs.calls.lock().unwrap(), [4]);
    clock.advance(Duration::from_millis(500));
    tokio::time::sleep(Duration::from_millis(20)).await;
    runner.get_script_log(7).await.unwrap();
    assert_eq!(*outputs.calls.lock().unwrap(), [4], "orphan timer fired");

    // A later acknowledged manual run retains its scheduled callback.
    assert_eq!(runner.run_script(7).await, Ok(true));
    clock.advance(Duration::from_millis(500));
    tokio::time::sleep(Duration::from_millis(20)).await;
    runner.get_script_log(7).await.unwrap();
    assert_eq!(*outputs.calls.lock().unwrap(), [4, 4, 5, 6]);
    runner.shutdown().await.unwrap();
}
