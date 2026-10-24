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

/// The sole authoritative input resolver shared by all hardware consumers.
/// A complete replacement takes one write lock, so no reader observes a partial map.
#[derive(Default)]
pub struct InputResolver {
    ports: RwLock<HashMap<String, PortRoutes>>,
    latest_generation: RwLock<HashMap<String, u64>>,
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
        let mut latest = self
            .latest_generation
            .write()
            .expect("input generation registry poisoned");
        if latest
            .get(port)
            .is_some_and(|current| generation < *current)
        {
            return false;
        }
        latest.insert(port.to_owned(), generation);
        self.ports.write().expect("input resolver poisoned").insert(
            port.to_owned(),
            PortRoutes {
                generation,
                config_id,
                pins,
            },
        );
        true
    }

    /// Invalidate only the generation that is being reconfigured or disconnected.
    pub fn invalidate_port(&self, port: &str, generation: u64) -> bool {
        let mut ports = self.ports.write().expect("input resolver poisoned");
        if ports
            .get(port)
            .is_some_and(|routes| routes.generation == generation)
        {
            ports.remove(port);
            true
        } else {
            false
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
        let routes = ports.get(port)?;
        (routes.generation == generation && routes.config_id == config_id)
            .then(|| routes.pins.get(&pin).copied())
            .flatten()
    }
}

/// Current raw input values, kept separate from routed events and preview throttling.
#[derive(Default)]
pub struct InputValueCache {
    ports: RwLock<HashMap<String, CachedPortValues>>,
    latest_generation: RwLock<HashMap<String, u64>>,
    invalidated: RwLock<std::collections::HashSet<(String, u64)>>,
}

#[derive(Clone, Debug, Eq, PartialEq)]
struct CachedPortValues {
    generation: u64,
    values: HashMap<u8, i16>,
}

impl InputValueCache {
    pub fn update(&self, port: &str, generation: u64, pin: u8, value: i16) -> bool {
        let mut latest = self
            .latest_generation
            .write()
            .expect("input cache generation registry poisoned");
        if latest
            .get(port)
            .is_some_and(|current| generation < *current)
        {
            return false;
        }
        if self
            .invalidated
            .read()
            .expect("input cache invalidation registry poisoned")
            .contains(&(port.to_owned(), generation))
        {
            return false;
        }
        latest.insert(port.to_owned(), generation);
        let mut ports = self.ports.write().expect("input value cache poisoned");
        let entry = ports
            .entry(port.to_owned())
            .or_insert_with(|| CachedPortValues {
                generation,
                values: HashMap::new(),
            });
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
            .filter(|entry| entry.generation == generation)
            .map(|entry| entry.values.clone())
            .unwrap_or_default()
    }

    pub fn invalidate(&self, port: &str, generation: u64) -> bool {
        let mut latest = self
            .latest_generation
            .write()
            .expect("input cache generation registry poisoned");
        if latest
            .get(port)
            .is_some_and(|current| generation < *current)
        {
            return false;
        }
        latest.insert(port.to_owned(), generation);
        self.invalidated
            .write()
            .expect("input cache invalidation registry poisoned")
            .insert((port.to_owned(), generation));
        let mut ports = self.ports.write().expect("input value cache poisoned");
        if ports
            .get(port)
            .is_some_and(|entry| entry.generation == generation)
        {
            ports.remove(port);
            true
        } else {
            true
        }
    }

    /// Explicitly reactivate a generation after successful persisted configuration.
    pub fn activate(&self, port: &str, generation: u64) -> bool {
        let mut latest = self
            .latest_generation
            .write()
            .expect("input cache generation registry poisoned");
        if latest
            .get(port)
            .is_some_and(|current| generation < *current)
        {
            return false;
        }
        latest.insert(port.to_owned(), generation);
        self.invalidated
            .write()
            .expect("input cache invalidation registry poisoned")
            .remove(&(port.to_owned(), generation));
        self.ports
            .write()
            .expect("input value cache poisoned")
            .insert(
                port.to_owned(),
                CachedPortValues {
                    generation,
                    values: HashMap::new(),
                },
            );
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
