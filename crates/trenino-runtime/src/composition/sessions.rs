//! Owned simulator guidance sessions. The single active slot serializes the
//! detection subscription and lever writes without inventing a hardware port.
use crate::simulator::{
    client::SimulatorClient,
    connection::SimulatorStatus,
    connection_owner::StatusSnapshot,
    services::{
        calibration::{
            self, CalibrationEvent, CalibrationProgress, CompletedCalibration, LeverEndpointSet,
        },
        clock::Clock,
        control_detection::{self, DetectedChange, DetectionEvent, DetectionOutcome},
        lever_analysis::{self, AnalysisOptions, AnalysisProgress},
    },
};
use serde::Serialize;
use std::{
    collections::BTreeMap,
    future::Future,
    sync::{
        atomic::{AtomicBool, Ordering},
        Arc,
    },
    time::Duration,
};
use tokio::{
    sync::{mpsc, oneshot, watch},
    task::JoinHandle,
};
use trenino_core::{
    calibration::analysis::AnalysisResult,
    train::buttons::{ordered_sequence, SequenceCommand},
};

const COMMAND_CAPACITY: usize = 16;
const TERMINAL_CAPACITY: usize = 32;
const CLEANUP_DEADLINE: Duration = Duration::from_secs(3);
const COMMAND_DEADLINE: Duration = Duration::from_secs(7);

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum SessionState {
    Listening,
    Running,
    Cancelling,
    Detected,
    TimedOut,
    Complete,
    Failed,
    Cancelled,
}
impl SessionState {
    fn terminal(self) -> bool {
        matches!(
            self,
            Self::Detected | Self::TimedOut | Self::Complete | Self::Failed | Self::Cancelled
        )
    }
}

#[derive(Clone, Debug, Serialize)]
pub struct SessionSnapshot {
    pub session_id: String,
    pub state: SessionState,
    pub changes: Vec<DetectedChange>,
    pub ambiguous: bool,
    pub remaining_ms: Option<u64>,
    pub analysis: Option<AnalysisResult>,
    pub analysis_progress: Option<AnalysisProgress>,
    pub calibration: Option<CompletedCalibration>,
    pub progress: Option<CalibrationProgress>,
    pub message: Option<String>,
    pub cleanup_pending: bool,
}
impl SessionSnapshot {
    fn new(id: u64, state: SessionState) -> Self {
        Self {
            session_id: id.to_string(),
            state,
            changes: vec![],
            ambiguous: false,
            remaining_ms: None,
            analysis: None,
            analysis_progress: None,
            calibration: None,
            progress: None,
            message: None,
            cleanup_pending: false,
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum SessionError {
    Offline,
    Busy,
    InvalidInput(String),
    NotFound,
    Closed,
    Deadline,
    CleanupFailed(String),
    Cancelled,
    Simulator(String),
}
impl std::fmt::Display for SessionError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{self:?}")
    }
}

enum Kind {
    Detection,
    Analysis { path: String, restore: Option<f64> },
    Calibration(LeverEndpointSet),
    Sequence(Vec<SequenceCommand>),
}
impl Kind {
    fn detection(&self) -> bool {
        matches!(self, Self::Detection)
    }
}
enum Command {
    Start(Kind, oneshot::Sender<Result<u64, SessionError>>),
    Status(u64, oneshot::Sender<Result<SessionSnapshot, SessionError>>),
    Cancel(u64, oneshot::Sender<Result<bool, SessionError>>),
    RunSequence(
        Vec<SequenceCommand>,
        oneshot::Sender<Result<bool, SessionError>>,
    ),
    Shutdown(oneshot::Sender<Result<(), SessionError>>),
}
enum Outcome {
    Detection(DetectionEvent),
    Analysis(Result<AnalysisResult, String>),
    Calibration(CalibrationEvent),
    Sequence(Result<(), SessionError>),
}
enum Event {
    Progress(u64, CalibrationProgress),
    AnalysisProgress(u64, AnalysisProgress),
    Done(u64, Outcome),
}
struct Active {
    id: u64,
    detection: bool,
    client: Arc<SimulatorClient>,
    worker: JoinHandle<()>,
    worker_joined: bool,
    deadline: Option<std::time::Instant>,
    sequence_reply: Option<SequenceReply>,
}
type SequenceReply = Arc<tokio::sync::Mutex<Option<oneshot::Sender<Result<bool, SessionError>>>>>;

#[derive(Clone)]
pub struct SimulatorSessionHost {
    commands: mpsc::Sender<Command>,
    finished: Arc<AtomicBool>,
}
impl SimulatorSessionHost {
    pub fn start(status: watch::Receiver<StatusSnapshot>, clock: Arc<dyn Clock>) -> Self {
        let (commands, receiver) = mpsc::channel(COMMAND_CAPACITY);
        let finished = Arc::new(AtomicBool::new(false));
        tokio::spawn(run(receiver, status, clock, finished.clone()));
        Self { commands, finished }
    }
    async fn request<T>(
        &self,
        build: impl FnOnce(oneshot::Sender<Result<T, SessionError>>) -> Command,
    ) -> Result<T, SessionError> {
        if self.finished.load(Ordering::Acquire) {
            return Err(SessionError::Closed);
        }
        let (reply, done) = oneshot::channel();
        self.commands
            .try_send(build(reply))
            .map_err(|_| SessionError::Busy)?;
        tokio::time::timeout(COMMAND_DEADLINE, done)
            .await
            .map_err(|_| SessionError::Deadline)?
            .map_err(|_| SessionError::Closed)?
    }
    pub async fn start_control_detection(&self) -> Result<u64, SessionError> {
        self.request(|r| Command::Start(Kind::Detection, r)).await
    }
    pub async fn start_lever_analysis(
        &self,
        path: String,
        restore: Option<f64>,
    ) -> Result<u64, SessionError> {
        if !valid_path(&path) || restore.is_some_and(|v| !v.is_finite()) {
            return Err(SessionError::InvalidInput(
                "invalid lever path or restore position".into(),
            ));
        }
        self.request(|r| Command::Start(Kind::Analysis { path, restore }, r))
            .await
    }
    pub async fn start_lever_calibration(
        &self,
        endpoints: LeverEndpointSet,
    ) -> Result<u64, SessionError> {
        if [
            &endpoints.min_endpoint,
            &endpoints.max_endpoint,
            &endpoints.value_endpoint,
            &endpoints.notch_count_endpoint,
            &endpoints.notch_index_endpoint,
        ]
        .iter()
        .any(|p| !valid_path(p))
        {
            return Err(SessionError::InvalidInput(
                "invalid calibration endpoint".into(),
            ));
        }
        self.request(|r| Command::Start(Kind::Calibration(endpoints), r))
            .await
    }
    pub async fn status(&self, id: u64) -> Result<SessionSnapshot, SessionError> {
        self.request(|r| Command::Status(id, r)).await
    }
    pub async fn cancel(&self, id: u64) -> Result<bool, SessionError> {
        self.request(|r| Command::Cancel(id, r)).await
    }
    pub async fn run_manual_sequence(
        &self,
        commands: Vec<SequenceCommand>,
    ) -> Result<bool, SessionError> {
        if commands
            .iter()
            .any(|c| c.endpoint.trim().is_empty() || !c.value.is_finite() || c.delay_ms > 60_000)
        {
            return Err(SessionError::InvalidInput(
                "invalid sequence commands or duration".into(),
            ));
        }
        let (reply, done) = oneshot::channel();
        self.commands
            .try_send(Command::RunSequence(commands, reply))
            .map_err(|_| SessionError::Busy)?;
        done.await.map_err(|_| SessionError::Closed)?
    }
    pub async fn shutdown(&self) -> Result<(), SessionError> {
        if self.finished.load(Ordering::Acquire) {
            return Ok(());
        }
        self.request(Command::Shutdown).await
    }
}
fn valid_path(path: &str) -> bool {
    !path.is_empty() && path.len() <= 1024 && !path.chars().any(char::is_control)
}

async fn run(
    mut commands: mpsc::Receiver<Command>,
    mut status: watch::Receiver<StatusSnapshot>,
    clock: Arc<dyn Clock>,
    finished: Arc<AtomicBool>,
) {
    let (events, mut incoming) = mpsc::channel::<Event>(COMMAND_CAPACITY);
    let mut entries = BTreeMap::<u64, SessionSnapshot>::new();
    let mut active: Option<Active> = None;
    let mut next_id = 0u64;
    let mut closing = false;
    let mut status_open = true;
    let mut commands_open = true;
    let mut cleanup_retry = tokio::time::interval_at(
        tokio::time::Instant::now() + Duration::from_secs(1),
        Duration::from_secs(1),
    );
    cleanup_retry.set_missed_tick_behavior(tokio::time::MissedTickBehavior::Skip);
    loop {
        tokio::select! {
            biased;
            changed=status.changed(),if status_open=>{
                if changed.is_err(){
                    status_open=false;
                    closing=true;
                    let _=cancel_active(&mut active,&mut entries,SessionError::Closed).await;
                } else if let Some(current)=active.as_ref(){let accepted=accepted_client(&status);if !accepted.as_ref().is_some_and(|c|Arc::ptr_eq(c,&current.client)){
                    let _=cancel_active(&mut active,&mut entries,SessionError::Cancelled).await;
                }}
            },
            command=commands.recv(),if commands_open=>{
                let Some(command)=command else {
                    commands_open=false;
                    closing=true;
                    match cancel_active(&mut active,&mut entries,SessionError::Closed).await{
                        Ok(())=>break,
                        Err(error)=>eprintln!("simulator session cleanup remains pending: {error}"),
                    }
                    continue;
                };
                match command {
                    Command::Start(kind,reply)=>{if reply.is_closed(){continue;}let result=if closing{Err(SessionError::Closed)}else if active.is_some(){Err(SessionError::Busy)}else if let Some(client)=accepted_client(&status){
                        next_id=next_id.wrapping_add(1).max(1);let id=next_id;let state=if kind.detection(){SessionState::Listening}else{SessionState::Running};entries.insert(id,SessionSnapshot::new(id,state));prune(&mut entries);
                        active=Some(spawn(id,kind,client,clock.clone(),events.clone(),None));Ok(id)
                    }else{Err(SessionError::Offline)};let started=result.as_ref().ok().copied();if reply.send(result).is_err()&&active.as_ref().is_some_and(|a|Some(a.id)==started){let _=cancel_active(&mut active,&mut entries,SessionError::Cancelled).await;}},
                    Command::Status(id,reply)=>{let result=entries.get(&id).cloned().map(|mut snapshot|{if let Some(a)=active.as_ref().filter(|a|a.id==id){snapshot.remaining_ms=a.deadline.map(|d|d.saturating_duration_since(clock.now()).as_millis() as u64);}snapshot}).ok_or(SessionError::NotFound);let _=reply.send(result);},
                    Command::Cancel(id,reply)=>{let result=if active.as_ref().is_some_and(|a|a.id==id){cancel_active(&mut active,&mut entries,SessionError::Cancelled).await.map(|()|true)}else if entries.contains_key(&id){Ok(false)}else{Err(SessionError::NotFound)};let _=reply.send(result);},
                    Command::RunSequence(sequence,reply)=>{
                        if reply.is_closed(){continue;}
                        if closing {let _=reply.send(Err(SessionError::Closed));}else if active.is_some(){let _=reply.send(Err(SessionError::Busy));}else if let Some(client)=accepted_client(&status){next_id=next_id.wrapping_add(1).max(1);let id=next_id;entries.insert(id,SessionSnapshot::new(id,SessionState::Running));prune(&mut entries);active=Some(spawn(id,Kind::Sequence(sequence),client,clock.clone(),events.clone(),Some(reply)));}else{let _=reply.send(Err(SessionError::Offline));}
                    },
                    Command::Shutdown(reply)=>{closing=true;let result=cancel_active(&mut active,&mut entries,SessionError::Cancelled).await;if result.is_ok(){finished.store(true,Ordering::Release);}let complete=result.is_ok();let _=reply.send(result);if complete{break;}},
                }
            },
            event=incoming.recv()=>{let Some(event)=event else{break};match event {
                Event::Progress(id,progress)=>{if active.as_ref().is_some_and(|a|a.id==id){if let Some(s)=entries.get_mut(&id){s.progress=Some(progress);}}},
                Event::AnalysisProgress(id,progress)=>{if active.as_ref().is_some_and(|a|a.id==id){if let Some(s)=entries.get_mut(&id){s.analysis_progress=Some(progress);}}},
                Event::Done(id,outcome)=>{if active.as_ref().is_some_and(|a|a.id==id){let result=finish_active(&mut active,&mut entries,outcome).await;if result.is_err(){/* keep the detection slot for cleanup retry */}}},
            }},
            _=cleanup_retry.tick(),if active.as_ref().is_some_and(|a|entries.get(&a.id).is_some_and(|s|s.cleanup_pending))=>{
                let cause = if commands_open {SessionError::Cancelled} else {SessionError::Closed};
                match cancel_active(&mut active,&mut entries,cause).await{
                    Ok(()) if !commands_open=>break,
                    Ok(())=>{},
                    Err(error)=>eprintln!("simulator session cleanup remains pending: {error}"),
                }
            },
        }
    }
    finished.store(true, Ordering::Release);
}
fn accepted_client(status: &watch::Receiver<StatusSnapshot>) -> Option<Arc<SimulatorClient>> {
    let s = status.borrow();
    (s.status == SimulatorStatus::Connected)
        .then(|| s.client.clone())
        .flatten()
}
fn prune(entries: &mut BTreeMap<u64, SessionSnapshot>) {
    while entries.len() > TERMINAL_CAPACITY {
        let Some(id) = entries
            .iter()
            .find(|(_, s)| s.state.terminal())
            .map(|(id, _)| *id)
        else {
            break;
        };
        entries.remove(&id);
    }
}

fn spawn(
    id: u64,
    kind: Kind,
    client: Arc<SimulatorClient>,
    clock: Arc<dyn Clock>,
    events: mpsc::Sender<Event>,
    sequence_reply: Option<oneshot::Sender<Result<bool, SessionError>>>,
) -> Active {
    let detection = kind.detection();
    let deadline = detection.then(|| clock.now() + control_detection::TIMEOUT);
    let task_client = client.clone();
    let sequence_reply = sequence_reply.map(|reply| Arc::new(tokio::sync::Mutex::new(Some(reply))));
    let worker_reply = sequence_reply.clone();
    let worker = tokio::spawn(async move {
        let outcome = match kind {
            Kind::Detection => {
                Outcome::Detection(match control_detection::detect(task_client, clock).await {
                    Ok(v) => DetectionEvent::Completed(v),
                    Err(e) => DetectionEvent::Failed(e),
                })
            }
            Kind::Analysis { path, restore } => {
                let (tx, mut rx) = mpsc::channel(16);
                let options = AnalysisOptions {
                    restore_position: restore,
                    ..Default::default()
                };
                let result = lever_analysis::analyze_with_progress(
                    &task_client,
                    &clock,
                    &path,
                    &options,
                    Some(&tx),
                );
                tokio::pin!(result);
                loop {
                    tokio::select! {biased;
                        done=&mut result=>{
                            while let Ok(progress)=rx.try_recv(){let _=events.send(Event::AnalysisProgress(id,progress)).await;}
                            break Outcome::Analysis(done.map_err(|e|format!("{e:?}")));
                        },
                        event=rx.recv()=>{if let Some(progress)=event{let _=events.send(Event::AnalysisProgress(id,progress)).await;}}
                    }
                }
            }
            Kind::Calibration(endpoints) => {
                let (tx, mut rx) = mpsc::channel(16);
                let result = calibration::calibrate_draft(&task_client, &clock, &endpoints, &tx);
                tokio::pin!(result);
                loop {
                    tokio::select! {biased;
                        done=&mut result=>{
                            while let Ok(CalibrationEvent::Progress(progress))=rx.try_recv(){let _=events.send(Event::Progress(id,progress)).await;}
                            let event=done.unwrap_or_else(||CalibrationEvent::Result(Err(calibration::CalibrationFailure::Store(calibration::CalibrationStoreError("calibration ended without result".into())))));
                            break Outcome::Calibration(event);
                        },
                        event=rx.recv()=>{if let Some(CalibrationEvent::Progress(progress))=event{let _=events.send(Event::Progress(id,progress)).await;}}
                    }
                }
            }
            Kind::Sequence(commands) => Outcome::Sequence(
                run_sequence(
                    &task_client,
                    &clock,
                    commands,
                    worker_reply.as_ref().expect("sequence caller"),
                )
                .await,
            ),
        };
        let _ = events.send(Event::Done(id, outcome)).await;
    });
    Active {
        id,
        detection,
        client,
        worker,
        worker_joined: false,
        deadline,
        sequence_reply,
    }
}
async fn run_sequence(
    client: &SimulatorClient,
    clock: &Arc<dyn Clock>,
    commands: Vec<SequenceCommand>,
    reply: &SequenceReply,
) -> Result<(), SessionError> {
    for c in ordered_sequence(&commands) {
        sequence_while_caller_alive(
            reply,
            client.set(&c.endpoint, &serde_json::Value::from(c.value)),
        )
        .await?
        .map_err(|e| SessionError::Simulator(e.to_string()))?;
        if c.delay_ms > 0 {
            sequence_while_caller_alive(reply, clock.sleep(Duration::from_millis(c.delay_ms)))
                .await?;
        }
    }
    Ok(())
}
async fn sequence_while_caller_alive<T>(
    reply: &SequenceReply,
    work: impl Future<Output = T>,
) -> Result<T, SessionError> {
    let mut guard = reply.lock().await;
    let caller = guard.as_mut().ok_or(SessionError::Cancelled)?;
    tokio::select! {biased;
        _=caller.closed()=>Err(SessionError::Cancelled),
        value=work=>Ok(value),
    }
}
async fn join_worker(active: &mut Active) -> Result<(), SessionError> {
    if active.worker_joined {
        return Ok(());
    }
    match tokio::time::timeout(CLEANUP_DEADLINE, &mut active.worker)
        .await
        .map_err(|_| SessionError::Deadline)?
    {
        Ok(()) => {
            active.worker_joined = true;
            Ok(())
        }
        Err(e) if e.is_cancelled() => {
            active.worker_joined = true;
            Ok(())
        }
        Err(e) => Err(SessionError::CleanupFailed(format!("session worker: {e}"))),
    }
}
async fn cleanup_detection(active: &Active) -> Result<(), SessionError> {
    if !active.detection {
        return Ok(());
    }
    tokio::time::timeout(
        CLEANUP_DEADLINE,
        active
            .client
            .unsubscribe(control_detection::SUBSCRIPTION_ID),
    )
    .await
    .map_err(|_| SessionError::Deadline)?
    .map(|_| ())
    .map_err(|e| SessionError::CleanupFailed(e.to_string()))
}
async fn cancel_active(
    active: &mut Option<Active>,
    entries: &mut BTreeMap<u64, SessionSnapshot>,
    cause: SessionError,
) -> Result<(), SessionError> {
    let Some(current) = active.as_mut() else {
        return Ok(());
    };
    if let Some(s) = entries.get_mut(&current.id) {
        s.state = SessionState::Cancelling;
        s.cleanup_pending = false;
    }
    current.worker.abort();
    let result = join_worker(current).await;
    let result = match result {
        Ok(()) => cleanup_detection(current).await,
        Err(e) => Err(e),
    };
    if let Err(e) = &result {
        if let Some(s) = entries.get_mut(&current.id) {
            s.state = SessionState::Failed;
            s.message = Some(e.to_string());
            s.cleanup_pending = true;
        }
        return result;
    }
    if let Some(s) = entries.get_mut(&current.id) {
        s.state = SessionState::Cancelled;
        s.message = Some(cause.to_string());
        s.cleanup_pending = false;
    }
    if let Some(reply) = current.sequence_reply.take() {
        if let Some(sender) = reply.lock().await.take() {
            let _ = sender.send(Err(cause));
        }
    }
    *active = None;
    Ok(())
}
async fn finish_active(
    active: &mut Option<Active>,
    entries: &mut BTreeMap<u64, SessionSnapshot>,
    outcome: Outcome,
) -> Result<(), SessionError> {
    let Some(current) = active.as_mut() else {
        return Ok(());
    };
    join_worker(current).await?;
    if let Err(e) = cleanup_detection(current).await {
        if let Some(s) = entries.get_mut(&current.id) {
            s.state = SessionState::Failed;
            s.message = Some(e.to_string());
            s.cleanup_pending = true;
        }
        return Err(e);
    }
    let s = entries
        .get_mut(&current.id)
        .expect("active session snapshot");
    s.cleanup_pending = false;
    match outcome {
        Outcome::Detection(DetectionEvent::Completed(DetectionOutcome::Detected {
            changes,
            ambiguous,
        })) => {
            s.state = SessionState::Detected;
            s.changes = changes;
            s.ambiguous = ambiguous;
        }
        Outcome::Detection(DetectionEvent::Completed(DetectionOutcome::TimedOut)) => {
            s.state = SessionState::TimedOut
        }
        Outcome::Detection(DetectionEvent::Failed(e)) => {
            s.state = SessionState::Failed;
            s.message = Some(format!("{e:?}"));
        }
        Outcome::Analysis(Ok(result)) => {
            s.state = SessionState::Complete;
            s.analysis = Some(result);
        }
        Outcome::Analysis(Err(e)) => {
            s.state = SessionState::Failed;
            s.message = Some(e);
        }
        Outcome::Calibration(CalibrationEvent::Result(Ok(result))) => {
            s.state = SessionState::Complete;
            s.calibration = Some(result);
        }
        Outcome::Calibration(CalibrationEvent::Result(Err(e))) => {
            s.state = SessionState::Failed;
            s.message = Some(format!("{e:?}"));
        }
        Outcome::Calibration(CalibrationEvent::Progress(progress)) => {
            s.state = SessionState::Failed;
            s.progress = Some(progress);
            s.message = Some("calibration ended without result".into());
        }
        Outcome::Sequence(result) => {
            let ok = result.is_ok();
            s.state = if ok {
                SessionState::Complete
            } else {
                SessionState::Failed
            };
            if let Err(e) = &result {
                s.message = Some(e.to_string());
            }
            if let Some(reply) = current.sequence_reply.take() {
                if let Some(sender) = reply.lock().await.take() {
                    let _ = sender.send(result.map(|()| true));
                }
            }
        }
    }
    *active = None;
    Ok(())
}
