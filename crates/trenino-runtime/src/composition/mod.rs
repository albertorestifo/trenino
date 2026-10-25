//! Production service composition and adapters shared by desktop and MCP.
pub mod hardware;
pub mod input;
pub mod io;
pub mod keyboard;
pub mod sessions;
pub mod storage;
use self::{
    io::{IoBridge, LiveSimulator},
    keyboard::NativeKeyboard,
    storage::{DbSources, ScriptHardware},
};
use crate::{
    lifecycle::ShutdownParticipant,
    resource::ResourceArbiter,
    routing::{reconcile::RoutingService, InputResolver},
    simulator::{
        connection_owner::{ConnectionConfig, SimulatorConnectionOwner},
        services::clock::{Clock, SystemClock},
    },
    storage::Database,
    train::{
        detection::{DbTrainConfigSource, TrainConfigSource},
        display_controller::DisplayController,
        output_controller::{HardwareDispatch, OutputController},
        script::{ScriptLimits, ScriptRunner},
        service::{TrainEvent, TrainServiceHandle},
    },
};
use std::{
    sync::{mpsc, Arc, Mutex},
    time::Duration,
};
/// Owns all simulator/train producers on a dedicated host. It does not hold
/// AppServices, so SQLite can close after acknowledged producer shutdown.
pub struct ControlRuntime {
    pub train: TrainServiceHandle,
    output: OutputController,
    display: DisplayController,
    stopped: std::sync::atomic::AtomicBool,
    pub scripts: ScriptRunner,
    pub simulator: Arc<LiveSimulator>,
    pub connection: SimulatorConnectionOwner,
    pub sessions: sessions::SimulatorSessionHost,
    stop: tokio::sync::mpsc::Sender<mpsc::SyncSender<Result<(), String>>>,
    host: Mutex<Option<std::thread::JoinHandle<()>>>,
}
impl ControlRuntime {
    pub fn is_running(&self) -> bool {
        !self.stopped.load(std::sync::atomic::Ordering::Acquire)
    }
    pub fn hardware_resumed(&self) -> Result<(), String> {
        self.output.devices_updated()?;
        self.display.invalidate_hardware()
    }

    pub fn start(
        db: Arc<Database>,
        config: Arc<dyn ConnectionConfig>,
        resolver: Arc<InputResolver>,
        arbiter: Arc<ResourceArbiter>,
        hardware: Arc<dyn HardwareDispatch>,
        keys: Arc<NativeKeyboard>,
    ) -> Result<Self, String> {
        let (ready, started) = mpsc::sync_channel(1);
        let host=std::thread::Builder::new().name("trenino-controls".into()).spawn(move||{
   let rt=tokio::runtime::Builder::new_multi_thread().worker_threads(2).enable_all().build().expect("controls runtime");
   rt.block_on(async move {
    let clock:Arc<dyn Clock>=Arc::new(SystemClock);
    let io=IoBridge::start();
    let (signals,_unused)=tokio::sync::mpsc::channel(1);
    let connection=SimulatorConnectionOwner::start(clock.clone(),config,signals);
    let sessions=sessions::SimulatorSessionHost::start(connection.latest(),clock.clone());
    let simulator=Arc::new(LiveSimulator{io:io.clone(),status:connection.latest()});
    let source=Arc::new(DbTrainConfigSource::new((*db).clone()));
    let routing=Arc::new(RoutingService::new(resolver.clone(),arbiter));
    let (train,mut events)=TrainServiceHandle::start(clock.clone(),source.clone(),routing,resolver,keys.clone());
    let sources=Arc::new(DbSources(db.clone()));
    let output=OutputController::start(sources.clone(),simulator.clone(),hardware.clone(),clock.clone());
    let display=DisplayController::start(sources.clone(),simulator.clone(),hardware.clone(),clock.clone());
    let effects=Arc::new(ScriptHardware{db:db.clone(),dispatch:hardware});
    let scripts=ScriptRunner::start(sources,simulator.clone(),simulator.clone(),effects.clone(),effects,clock,ScriptLimits::default());
    let (stop,mut stopping)=tokio::sync::mpsc::channel::<mpsc::SyncSender<Result<(),String>>>(1);
    let mut status=connection_updates(connection.latest());
    let mut revisions=read_revisions(&db);
    let _=ready.send((train.clone(),scripts.clone(),simulator.clone(),connection.clone(),sessions.clone(),output.clone(),display.clone(),stop));
    let mut ticker=tokio::time::interval(Duration::from_millis(250));
    let mut producers_stopped=false;
    let mut stopping_requested=false;
    let mut effective_client: Option<Arc<crate::simulator::client::SimulatorClient>> = None;
    loop {tokio::select!{
      biased;
      reply=stopping.recv()=>{let Some(reply)=reply else{break}; stopping_requested=true;
       // Keep the host alive on failure: shutdown coordinator can retry.
       let result=async {
        sessions.shutdown().await.map_err(|e|format!("sessions: {e:?}"))?;
        scripts.shutdown().await.map_err(|e|format!("scripts: {e:?}"))?;
        output.shutdown().await; display.shutdown().await;
        if !producers_stopped {train.clone().shutdown().await.map_err(|e|format!("train: {e:?}"))?;producers_stopped=true;}
        keys.shutdown()?;
        connection.shutdown().await.map_err(|e|format!("connection: {e:?}"))?;
        io.shutdown(); Ok::<(),String>(())
       }.await;
       let complete=result.is_ok();let _=reply.send(result);if complete{break;}
      },
      changed=status.changed(),if !stopping_requested=>{if changed.is_err(){continue}let snapshot=status.borrow_and_update().clone();
       let client = if snapshot.status == crate::simulator::connection::SimulatorStatus::Connected { snapshot.client } else { None };
       let same = match (&effective_client, &client) { (Some(a),Some(b)) => Arc::ptr_eq(a,b), (None,None) => true, _ => false };
       if same { continue; }
       effective_client = client.clone();
       if let Some(client)=client {if let Err(e)=train.simulator_connected(client).await{eprintln!("train connection: {e:?}");}
        let profile=train.snapshot().active_train_id.and_then(|id|source.profiles().into_iter().find(|p|p.id==id.0));
        output.train_changed(profile.clone()).await;display.train_changed(profile.clone()).await;scripts.train_changed(profile).await;
       } else {let _=train.simulator_disconnected().await;output.train_changed(None).await;display.train_changed(None).await;scripts.train_changed(None).await;}
      },
      event=events.recv(),if !stopping_requested=>{if let Some(TrainEvent::TrainChanged(id))=event {let profile=id.filter(|_| effective_client.is_some()).and_then(|id|source.profiles().into_iter().find(|p|p.id==id.0));output.train_changed(profile.clone()).await;display.train_changed(profile.clone()).await;scripts.train_changed(profile).await;}},
      _=ticker.tick(),if !stopping_requested=>{let next=read_revisions(&db);if next!=revisions {if next.last()!=revisions.last(){let _=connection.reconfigure().await;}let _=train.sync().await;output.reload_bindings().await;display.reload_bindings().await;scripts.reload_scripts().await;revisions=next;}}
    }}
   });
  }).map_err(|e|e.to_string())?;
        let (train, scripts, simulator, connection, sessions, output, display, stop) = started
            .recv()
            .map_err(|_| "controls startup failed".to_string())?;
        Ok(Self {
            train,
            scripts,
            simulator,
            connection,
            sessions,
            output,
            display,
            stopped: std::sync::atomic::AtomicBool::new(false),
            stop,
            host: Mutex::new(Some(host)),
        })
    }
}
fn read_revisions(db: &Database) -> Vec<u64> {
    ["trains", "bindings", "scripts", "hardware", "settings"]
        .iter()
        .map(|t| db.revision(t).unwrap_or(0))
        .collect()
}
impl ShutdownParticipant for ControlRuntime {
    fn stop_admission(&self) -> Result<(), String> {
        self.stopped
            .store(true, std::sync::atomic::Ordering::Release);
        Ok(())
    }
    fn cancel_and_join_producers(&self) -> Result<(), String> {
        self.stopped
            .store(true, std::sync::atomic::Ordering::Release);
        let mut host = self.host.lock().map_err(|_| "controls host poisoned")?;
        if host.is_none() {
            return Ok(());
        }
        if host.as_ref().is_some_and(|h| h.is_finished()) {
            let h = host.take().expect("finished host");
            h.join().map_err(|_| "controls host panicked")?;
            self.stopped
                .store(true, std::sync::atomic::Ordering::Release);
            return Ok(());
        }
        let (reply, done) = mpsc::sync_channel(1);
        self.stop
            .try_send(reply)
            .map_err(|_| "controls shutdown pending".to_string())?;
        done.recv_timeout(Duration::from_secs(20))
            .map_err(|_| "controls shutdown deadline".to_string())??;
        self.stopped
            .store(true, std::sync::atomic::Ordering::Release);
        if let Some(h) = host.take() {
            h.join().map_err(|_| "controls host panicked")?;
        }
        Ok(())
    }
    fn neutralize_and_release_outputs(&self) -> Result<(), String> {
        Ok(())
    }
    fn close_ports_and_network(&self) -> Result<(), String> {
        Ok(())
    }
}

fn connection_updates(
    mut receiver: tokio::sync::watch::Receiver<crate::simulator::connection_owner::StatusSnapshot>,
) -> tokio::sync::watch::Receiver<crate::simulator::connection_owner::StatusSnapshot> {
    // watch receivers begin with their current value marked seen. Force one
    // initial delivery so a connection completed during construction is applied.
    receiver.mark_changed();
    receiver
}
#[cfg(test)]
mod tests {
    #[tokio::test]
    async fn initial_connected_snapshot_is_processed_without_later_notification() {
        use crate::simulator::{connection::SimulatorStatus, connection_owner::StatusSnapshot};
        let (_owner, receiver) = tokio::sync::watch::channel(StatusSnapshot {
            status: SimulatorStatus::Connected,
            last_error: None,
            info: None,
            health_failures: 0,
            client: None,
        });
        let mut updates = super::connection_updates(receiver);
        tokio::time::timeout(std::time::Duration::from_millis(50), updates.changed())
            .await
            .expect("already-connected startup must not wait for health check")
            .unwrap();
        assert_eq!(
            updates.borrow_and_update().status,
            SimulatorStatus::Connected
        );
    }
}
