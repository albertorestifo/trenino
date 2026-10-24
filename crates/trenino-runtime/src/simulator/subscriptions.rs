use super::client::{SimulatorClient, SimulatorError};
use std::{
    collections::{HashMap, HashSet},
    sync::{
        atomic::{AtomicBool, Ordering},
        Arc,
    },
    time::Duration,
};
use tokio::sync::{mpsc, oneshot, Mutex};

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct SubscriptionLease {
    pub token: u64,
    pub owner: String,
    pub generation: u64,
    pub endpoints: HashMap<String, i64>,
}
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum SubscriptionError {
    IdExhausted,
    UnknownLease,
}
#[derive(Default)]
pub struct SubscriptionRegistry {
    next_token: u64,
    next_id: i64,
    leases: HashMap<u64, SubscriptionLease>,
    refs: HashMap<(u64, String), (i64, HashSet<u64>)>,
}
impl SubscriptionRegistry {
    pub fn new(first_id: i64) -> Self {
        Self {
            next_id: first_id,
            ..Self::default()
        }
    }
    pub fn acquire(
        &mut self,
        owner: impl Into<String>,
        generation: u64,
        endpoints: impl IntoIterator<Item = String>,
    ) -> Result<SubscriptionLease, SubscriptionError> {
        self.acquire_with_new(owner, generation, endpoints)
            .map(|(lease, _)| lease)
    }
    pub fn acquire_with_new(
        &mut self,
        owner: impl Into<String>,
        generation: u64,
        endpoints: impl IntoIterator<Item = String>,
    ) -> Result<(SubscriptionLease, Vec<(String, i64)>), SubscriptionError> {
        let token = self
            .next_token
            .checked_add(1)
            .ok_or(SubscriptionError::IdExhausted)?;
        let owner = owner.into();
        let mut map = HashMap::new();
        let mut new = Vec::new();
        let mut seen = HashSet::new();
        for endpoint in endpoints {
            if !seen.insert(endpoint.clone()) {
                continue;
            }
            let key = (generation, endpoint.clone());
            let (id, was_new) = if let Some((id, owners)) = self.refs.get_mut(&key) {
                owners.insert(token);
                (*id, false)
            } else {
                let id = self
                    .next_id
                    .checked_add(1)
                    .ok_or(SubscriptionError::IdExhausted)?;
                self.next_id = id;
                self.refs.insert(key, (id, HashSet::from([token])));
                (id, true)
            };
            if was_new {
                new.push((endpoint.clone(), id))
            }
            map.insert(endpoint, id);
        }
        self.next_token = token;
        let lease = SubscriptionLease {
            token,
            owner,
            generation,
            endpoints: map,
        };
        self.leases.insert(token, lease.clone());
        Ok((lease, new))
    }
    /// IDs are returned only when no lease still owns the simulator subscription.
    pub fn release(&mut self, lease: SubscriptionLease) -> Result<Vec<i64>, SubscriptionError> {
        let stored = self
            .leases
            .remove(&lease.token)
            .ok_or(SubscriptionError::UnknownLease)?;
        let mut remove = Vec::new();
        for endpoint in stored.endpoints.keys() {
            let key = (stored.generation, endpoint.clone());
            if let Some((id, owners)) = self.refs.get_mut(&key) {
                owners.remove(&stored.token);
                if owners.is_empty() {
                    remove.push(*id);
                    self.refs.remove(&key);
                }
            }
        }
        remove.sort_unstable();
        Ok(remove)
    }
    pub fn lease_count(&self) -> usize {
        self.leases.len()
    }

    fn release_all(&mut self) -> Vec<i64> {
        let mut ids: Vec<_> = self.refs.values().map(|(id, _)| *id).collect();
        ids.sort_unstable();
        self.leases.clear();
        self.refs.clear();
        ids
    }
}

#[derive(Debug)]
pub enum SubscriptionServiceError {
    Registry(SubscriptionError),
    Simulator(SimulatorError),
    Closed,
    QueueTimeout,
    PendingCleanup(Vec<i64>),
}
impl From<SubscriptionError> for SubscriptionServiceError {
    fn from(e: SubscriptionError) -> Self {
        Self::Registry(e)
    }
}
impl From<SimulatorError> for SubscriptionServiceError {
    fn from(e: SimulatorError) -> Self {
        Self::Simulator(e)
    }
}
enum Command {
    Acquire(
        String,
        u64,
        Vec<String>,
        oneshot::Sender<Result<(SubscriptionLease, oneshot::Sender<()>), SubscriptionServiceError>>,
    ),
    Release(
        SubscriptionLease,
        oneshot::Sender<Result<Vec<i64>, SubscriptionServiceError>>,
    ),
    RetryCleanup(oneshot::Sender<Result<(), SubscriptionServiceError>>),
    Counts(oneshot::Sender<(usize, usize)>),
    Shutdown(oneshot::Sender<Result<(), SubscriptionServiceError>>),
}
pub struct SubscriptionService {
    sender: mpsc::Sender<Command>,
    admission: Mutex<()>,
    closing: AtomicBool,
    queue_wait: Duration,
    worker: Arc<Mutex<Option<tokio::task::JoinHandle<()>>>>,
}
impl SubscriptionService {
    pub fn new(client: Arc<SimulatorClient>, first_id: i64) -> Self {
        let (sender, receiver) = mpsc::channel(64);
        let worker = tokio::spawn(run_service(
            client.clone(),
            SubscriptionRegistry::new(first_id),
            receiver,
        ));
        Self {
            sender,
            admission: Mutex::new(()),
            closing: AtomicBool::new(false),
            queue_wait: client.queue_wait_budget(),
            worker: Arc::new(Mutex::new(Some(worker))),
        }
    }
    pub async fn acquire(
        &self,
        owner: impl Into<String>,
        generation: u64,
        endpoints: Vec<String>,
    ) -> Result<SubscriptionLease, SubscriptionServiceError> {
        let (reply, receive) = oneshot::channel();
        self.send(Command::Acquire(owner.into(), generation, endpoints, reply))
            .await?;
        let (lease, confirmation) = receive
            .await
            .map_err(|_| SubscriptionServiceError::Closed)??;
        confirmation
            .send(())
            .map_err(|_| SubscriptionServiceError::Closed)?;
        Ok(lease)
    }
    pub async fn release(
        &self,
        lease: SubscriptionLease,
    ) -> Result<Vec<i64>, SubscriptionServiceError> {
        let (reply, receive) = oneshot::channel();
        self.send(Command::Release(lease, reply)).await?;
        receive
            .await
            .map_err(|_| SubscriptionServiceError::Closed)?
    }
    pub async fn lease_count(&self) -> usize {
        self.counts().await.0
    }
    pub async fn pending_cleanup_count(&self) -> usize {
        self.counts().await.1
    }

    pub async fn retry_cleanup(&self) -> Result<(), SubscriptionServiceError> {
        let (reply, receive) = oneshot::channel();
        self.send_even_if_closing(Command::RetryCleanup(reply))
            .await?;
        receive
            .await
            .map_err(|_| SubscriptionServiceError::Closed)?
    }

    /// Close admission and drain leases. If the bounded inbox is full, `QueueTimeout`
    /// is retryable: the actor remains alive and a later shutdown call can be admitted.
    pub async fn shutdown(&self) -> Result<(), SubscriptionServiceError> {
        self.closing.store(true, Ordering::Release);
        let (reply, receive) = oneshot::channel();
        let send_result = self.send_even_if_closing(Command::Shutdown(reply)).await;
        if let Err(error) = send_result {
            if matches!(error, SubscriptionServiceError::QueueTimeout) {
                // The command was not admitted, so the actor has not been asked to exit.
                // Keep its handle intact and let the caller retry shutdown after the inbox drains.
                return Err(error);
            }
            if matches!(error, SubscriptionServiceError::Closed) {
                let mut worker = self.worker.lock().await;
                if let Some(handle) = worker.as_mut() {
                    handle.await.map_err(|_| SubscriptionServiceError::Closed)?;
                    worker.take();
                    return Ok(());
                }
            }
            return Err(error);
        }
        let result = receive
            .await
            .map_err(|_| SubscriptionServiceError::Closed)?;
        if result.is_ok() {
            let mut worker = self.worker.lock().await;
            if let Some(handle) = worker.as_mut() {
                handle.await.map_err(|_| SubscriptionServiceError::Closed)?;
                worker.take();
            }
        }
        result
    }

    async fn counts(&self) -> (usize, usize) {
        let (reply, receive) = oneshot::channel();
        if self
            .send_even_if_closing(Command::Counts(reply))
            .await
            .is_err()
        {
            return (0, 0);
        }
        receive.await.unwrap_or((0, 0))
    }

    async fn send(&self, command: Command) -> Result<(), SubscriptionServiceError> {
        self.send_with_closing_check(command, false).await
    }

    async fn send_even_if_closing(&self, command: Command) -> Result<(), SubscriptionServiceError> {
        self.send_with_closing_check(command, true).await
    }

    async fn send_with_closing_check(
        &self,
        command: Command,
        allow_closing: bool,
    ) -> Result<(), SubscriptionServiceError> {
        let deadline = tokio::time::Instant::now() + self.queue_wait;
        let admission = tokio::time::timeout_at(deadline, self.admission.lock())
            .await
            .map_err(|_| SubscriptionServiceError::QueueTimeout)?;
        if !allow_closing && self.closing.load(Ordering::Acquire) {
            return Err(SubscriptionServiceError::Closed);
        }
        tokio::time::timeout_at(deadline, self.sender.send(command))
            .await
            .map_err(|_| SubscriptionServiceError::QueueTimeout)?
            .map_err(|_| SubscriptionServiceError::Closed)?;
        drop(admission);
        Ok(())
    }
}

async fn run_service(
    client: Arc<SimulatorClient>,
    mut registry: SubscriptionRegistry,
    mut receiver: mpsc::Receiver<Command>,
) {
    let mut pending_cleanup = Vec::new();
    while let Some(command) = receiver.recv().await {
        match command {
            Command::Acquire(owner, generation, endpoints, reply) => {
                let result = acquire(
                    &client,
                    &mut registry,
                    &mut pending_cleanup,
                    owner,
                    generation,
                    endpoints,
                )
                .await;
                match result {
                    Ok(lease) => {
                        let (confirmation, confirm_receive) = oneshot::channel();
                        let confirmed = if reply.send(Ok((lease.clone(), confirmation))).is_ok() {
                            confirm_receive.await.is_ok()
                        } else {
                            false
                        };
                        if !confirmed {
                            rollback_lease(&client, &mut registry, &mut pending_cleanup, lease)
                                .await;
                        }
                    }
                    Err(error) => {
                        let _ = reply.send(Err(error));
                    }
                }
            }
            Command::Release(lease, reply) => {
                let result = match registry.release(lease) {
                    Ok(ids) => {
                        add_pending(&mut pending_cleanup, ids.clone());
                        retry_pending(&client, &mut pending_cleanup)
                            .await
                            .map(|()| ids)
                    }
                    Err(error) => Err(error.into()),
                };
                let _ = reply.send(result);
            }
            Command::RetryCleanup(reply) => {
                let _ = reply.send(retry_pending(&client, &mut pending_cleanup).await);
            }
            Command::Counts(reply) => {
                let _ = reply.send((registry.lease_count(), pending_cleanup.len()));
            }
            Command::Shutdown(reply) => {
                add_pending(&mut pending_cleanup, registry.release_all());
                let result = retry_pending(&client, &mut pending_cleanup).await;
                if pending_cleanup.is_empty() {
                    let _ = reply.send(Ok(()));
                    return;
                }
                let _ = reply.send(Err(SubscriptionServiceError::PendingCleanup(
                    pending_cleanup.clone(),
                )));
                let _ = result;
            }
        }
    }
    add_pending(&mut pending_cleanup, registry.release_all());
    let _ = retry_pending(&client, &mut pending_cleanup).await;
}

async fn acquire(
    client: &SimulatorClient,
    registry: &mut SubscriptionRegistry,
    pending_cleanup: &mut Vec<i64>,
    owner: String,
    generation: u64,
    endpoints: Vec<String>,
) -> Result<SubscriptionLease, SubscriptionServiceError> {
    let (lease, new) = registry.acquire_with_new(owner, generation, endpoints)?;
    for (endpoint, id) in new {
        if let Err(error) = client.subscribe(&endpoint, id).await {
            if let Ok(ids) = registry.release(lease.clone()) {
                add_pending(pending_cleanup, ids);
            }
            let _ = retry_pending(client, pending_cleanup).await;
            return Err(error.into());
        }
    }
    Ok(lease)
}

async fn rollback_lease(
    client: &SimulatorClient,
    registry: &mut SubscriptionRegistry,
    pending_cleanup: &mut Vec<i64>,
    lease: SubscriptionLease,
) {
    if let Ok(ids) = registry.release(lease) {
        add_pending(pending_cleanup, ids);
    }
    let _ = retry_pending(client, pending_cleanup).await;
}

fn add_pending(pending: &mut Vec<i64>, ids: impl IntoIterator<Item = i64>) {
    for id in ids {
        if !pending.contains(&id) {
            pending.push(id);
        }
    }
}

async fn retry_pending(
    client: &SimulatorClient,
    pending: &mut Vec<i64>,
) -> Result<(), SubscriptionServiceError> {
    let mut failures = Vec::new();
    let mut first_error = None;
    for id in pending.iter().copied() {
        if let Err(error) = client.unsubscribe(id).await {
            if first_error.is_none() {
                first_error = Some(error);
            }
            failures.push(id);
        }
    }
    *pending = failures;
    if let Some(error) = first_error {
        Err(error.into())
    } else {
        Ok(())
    }
}
