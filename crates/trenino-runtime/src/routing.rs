//! Generation-fenced mapping from firmware input values to persisted input rows.
use std::collections::HashMap;
use std::sync::RwLock;

use trenino_core::{ConfigId, EntityId};

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct InputIdentity {
    pub device_id: EntityId,
    pub input_id: EntityId,
}

#[derive(Clone, Debug)]
struct PortRoutes {
    generation: u64,
    config_id: ConfigId,
    pins: HashMap<u8, InputIdentity>,
}

#[derive(Clone, Debug, Default)]
struct PortRouteState {
    generation: Option<u64>,
    revoked: bool,
    routes: Option<PortRoutes>,
}

/// The sole authoritative input resolver shared by all hardware consumers.
/// A complete replacement takes one write lock, so no reader observes a partial map.
#[derive(Default)]
pub struct InputResolver {
    ports: RwLock<HashMap<String, PortRouteState>>,
}

impl InputResolver {
    pub fn replace_port<I>(
        &self,
        port: &str,
        generation: u64,
        config_id: ConfigId,
        inputs: I,
    ) -> bool
    where
        I: IntoIterator<Item = (u8, InputIdentity)>,
    {
        let pins = inputs.into_iter().collect();
        let mut ports = self.ports.write().expect("input resolver poisoned");
        let state = ports.entry(port.to_owned()).or_default();
        if state.generation.is_some_and(|current| generation < current)
            || (state.generation == Some(generation) && state.revoked)
        {
            return false;
        }
        *state = PortRouteState {
            generation: Some(generation),
            revoked: false,
            routes: Some(PortRoutes {
                generation,
                config_id,
                pins,
            }),
        };
        true
    }

    /// Remove the current mapping while allowing a confirmed reconfiguration of the
    /// same live connection generation to install a replacement atomically.
    pub fn begin_reconfiguration(&self, port: &str, generation: u64) -> bool {
        let mut ports = self.ports.write().expect("input resolver poisoned");
        let state = ports.entry(port.to_owned()).or_default();
        if state.generation.is_some_and(|current| generation < current)
            || (state.generation == Some(generation) && state.revoked)
        {
            return false;
        }
        if state.generation != Some(generation) {
            state.revoked = false;
        }
        state.generation = Some(generation);
        state.routes = None;
        true
    }

    /// Invalidate only the generation that is being reconfigured or disconnected.
    pub fn invalidate_port(&self, port: &str, generation: u64) -> bool {
        let mut ports = self.ports.write().expect("input resolver poisoned");
        let state = ports.entry(port.to_owned()).or_default();
        if state.generation.is_some_and(|current| generation < current) {
            false
        } else {
            state.generation = Some(generation);
            state.revoked = true;
            state.routes = None;
            true
        }
    }

    pub fn resolve(
        &self,
        port: &str,
        generation: u64,
        config_id: ConfigId,
        pin: u8,
    ) -> Option<InputIdentity> {
        let ports = self.ports.read().expect("input resolver poisoned");
        let routes = ports.get(port)?.routes.as_ref()?;
        (routes.generation == generation && routes.config_id == config_id)
            .then(|| routes.pins.get(&pin).copied())
            .flatten()
    }
}

/// Current raw input values, kept separate from routed events and preview throttling.
#[derive(Default)]
pub struct InputValueCache {
    ports: RwLock<HashMap<String, CachePortState>>,
}

#[derive(Clone, Debug, Eq, PartialEq)]
struct CachedPortValues {
    generation: u64,
    values: HashMap<u8, i16>,
}

#[derive(Clone, Debug, Default)]
struct CachePortState {
    generation: Option<u64>,
    revoked: bool,
    values: Option<CachedPortValues>,
}

impl InputValueCache {
    pub fn update(&self, port: &str, generation: u64, pin: u8, value: i16) -> bool {
        let mut ports = self.ports.write().expect("input value cache poisoned");
        let state = ports.entry(port.to_owned()).or_default();
        if state.generation.is_some_and(|current| generation < current)
            || (state.generation == Some(generation) && state.revoked)
        {
            return false;
        }
        if state.generation != Some(generation) || state.values.is_none() {
            state.generation = Some(generation);
            state.revoked = false;
            state.values = Some(CachedPortValues {
                generation,
                values: HashMap::new(),
            });
        }
        let entry = state.values.as_mut().expect("cache entry was initialized");
        if entry.generation != generation {
            *entry = CachedPortValues {
                generation,
                values: HashMap::new(),
            };
        }
        entry.values.insert(pin, value);
        true
    }

    pub fn snapshot(&self, port: &str, generation: u64) -> HashMap<u8, i16> {
        self.ports
            .read()
            .expect("input value cache poisoned")
            .get(port)
            .filter(|state| !state.revoked && state.generation == Some(generation))
            .and_then(|state| state.values.as_ref())
            .filter(|entry| entry.generation == generation)
            .map(|entry| entry.values.clone())
            .unwrap_or_default()
    }

    pub fn invalidate(&self, port: &str, generation: u64) -> bool {
        let mut ports = self.ports.write().expect("input value cache poisoned");
        let state = ports.entry(port.to_owned()).or_default();
        if state.generation.is_some_and(|current| generation < current) {
            return false;
        }
        state.generation = Some(generation);
        state.revoked = true;
        state.values = None;
        true
    }

    /// Prepare the live generation for a new persisted configuration, clearing old
    /// samples while retaining permission to reactivate after confirmation.
    pub fn begin_reconfiguration(&self, port: &str, generation: u64) -> bool {
        let mut ports = self.ports.write().expect("input value cache poisoned");
        let state = ports.entry(port.to_owned()).or_default();
        if state.generation.is_some_and(|current| generation < current)
            || (state.generation == Some(generation) && state.revoked)
        {
            return false;
        }
        if state.generation != Some(generation) {
            state.revoked = false;
        }
        state.generation = Some(generation);
        state.values = None;
        true
    }

    /// Explicitly reactivate a generation after successful persisted configuration.
    pub fn activate(&self, port: &str, generation: u64) -> bool {
        let mut ports = self.ports.write().expect("input value cache poisoned");
        let state = ports.entry(port.to_owned()).or_default();
        if state.generation.is_some_and(|current| generation < current)
            || (state.generation == Some(generation) && state.revoked)
        {
            return false;
        }
        *state = CachePortState {
            generation: Some(generation),
            revoked: false,
            values: Some(CachedPortValues {
                generation,
                values: HashMap::new(),
            }),
        };
        true
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct InputEvent {
    pub port_generation: u64,
    pub config_id: ConfigId,
    pub pin: u8,
    pub value: i16,
}

/// Lossless bounded FIFO for authoritative edges and calibration samples.
/// Callers must propagate `Overflow`; no event is silently discarded.
pub struct EventQueue<T> {
    capacity: usize,
    queue: std::sync::Mutex<std::collections::VecDeque<T>>,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum QueueError {
    Overflow,
}

impl<T> EventQueue<T> {
    pub fn new(capacity: usize) -> Self {
        Self {
            capacity: capacity.max(1),
            queue: std::sync::Mutex::new(std::collections::VecDeque::new()),
        }
    }

    pub fn push(&self, event: T) -> Result<(), QueueError> {
        let mut queue = self.queue.lock().expect("input event queue poisoned");
        if queue.len() == self.capacity {
            return Err(QueueError::Overflow);
        }
        queue.push_back(event);
        Ok(())
    }

    pub fn pop(&self) -> Option<T> {
        self.queue
            .lock()
            .expect("input event queue poisoned")
            .pop_front()
    }

    pub fn len(&self) -> usize {
        self.queue.lock().expect("input event queue poisoned").len()
    }

    pub fn is_empty(&self) -> bool {
        self.len() == 0
    }
}
