use super::client::{SimulatorClient, SimulatorError};
use std::{
    collections::{HashMap, HashSet},
    sync::Arc,
};
use tokio::sync::Mutex;

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
}

#[derive(Debug)]
pub enum SubscriptionServiceError {
    Registry(SubscriptionError),
    Simulator(SimulatorError),
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
#[derive(Default)]
struct ServiceState {
    registry: SubscriptionRegistry,
    pending_cleanup: Vec<i64>,
}
pub struct SubscriptionService {
    client: Arc<SimulatorClient>,
    state: Mutex<ServiceState>,
}
impl SubscriptionService {
    pub fn new(client: Arc<SimulatorClient>, first_id: i64) -> Self {
        Self {
            client,
            state: Mutex::new(ServiceState {
                registry: SubscriptionRegistry::new(first_id),
                pending_cleanup: Vec::new(),
            }),
        }
    }
    pub async fn acquire(
        &self,
        owner: impl Into<String>,
        generation: u64,
        endpoints: Vec<String>,
    ) -> Result<SubscriptionLease, SubscriptionServiceError> {
        let mut state = self.state.lock().await;
        let (lease, new) = state
            .registry
            .acquire_with_new(owner, generation, endpoints)?;
        for (endpoint, id) in new {
            if let Err(error) = self.client.subscribe(&endpoint, id).await {
                if let Ok(cleanup) = state.registry.release(lease.clone()) {
                    state.pending_cleanup.extend(cleanup)
                }
                let _ = cleanup_pending(&self.client, &mut state.pending_cleanup).await;
                return Err(SubscriptionServiceError::Simulator(error));
            }
        }
        Ok(lease)
    }
    pub async fn release(
        &self,
        lease: SubscriptionLease,
    ) -> Result<Vec<i64>, SubscriptionServiceError> {
        let mut state = self.state.lock().await;
        let ids = state.registry.release(lease)?;
        state.pending_cleanup.extend(ids.iter().copied());
        cleanup_pending(&self.client, &mut state.pending_cleanup).await?;
        Ok(ids)
    }
    pub async fn lease_count(&self) -> usize {
        self.state.lock().await.registry.lease_count()
    }
}
async fn cleanup_pending(
    client: &SimulatorClient,
    pending: &mut Vec<i64>,
) -> Result<(), SubscriptionServiceError> {
    let mut still_pending = Vec::new();
    let mut first_error = None;
    for id in pending.drain(..) {
        if let Err(error) = client.unsubscribe(id).await {
            if first_error.is_none() {
                first_error = Some(error)
            }
            still_pending.push(id)
        }
    }
    *pending = still_pending;
    if let Some(error) = first_error {
        Err(SubscriptionServiceError::Simulator(error))
    } else {
        Ok(())
    }
}
