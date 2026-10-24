use std::time::{Duration, Instant};

use crate::routing::{InputIdentity, InputResolver, InputValueCache};
use trenino_core::hardware::protocol::Message;
use trenino_core::{ConfigId, EntityId};

pub trait ConfigurationPort {
    fn generation(&self) -> u64;
    fn send(&mut self, message: &Message) -> Result<(), String>;
    fn receive(&mut self, timeout: Duration) -> Result<Option<Message>, String>;
}

/// Implemented by the single runtime repository adapter; this module owns no database.
pub trait ConfigurationRepository {
    fn confirm_configuration(
        &mut self,
        device_id: EntityId,
        config_id: ConfigId,
    ) -> Result<(), String>;
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub enum ApplyError {
    StaleGeneration,
    InvalidMessage,
    Send(String),
    Receive(String),
    DeviceRejected,
    Timeout,
    Persist(String),
    Commit(String),
}

pub struct ConfigurationApply<I> {
    pub port_name: String,
    pub generation: u64,
    pub device_id: EntityId,
    pub config_id: ConfigId,
    pub messages: Vec<Message>,
    pub mappings: I,
    pub timeout: Duration,
}

/// Invalidates routing first, sends every multipart packet, waits for a matching
/// current-generation acknowledgement, persists confirmation, then publishes.
pub fn apply_configuration<P, R, I, F>(
    port: &mut P,
    repository: &mut R,
    resolver: &InputResolver,
    cache: &InputValueCache,
    request: ConfigurationApply<I>,
    publish_success: F,
) -> Result<(), ApplyError>
where
    P: ConfigurationPort,
    R: ConfigurationRepository,
    I: IntoIterator<Item = (u8, InputIdentity)>,
    F: FnOnce() -> Result<(), ApplyError>,
{
    apply_configuration_with(
        port,
        resolver,
        cache,
        request,
        |device_id, config_id| repository.confirm_configuration(device_id, config_id),
        publish_success,
    )
}

/// Configuration sequence with a short repository confirmation callback. The callback
/// is invoked only after ACK and never while waiting on the serial port.
pub fn apply_configuration_with<P, I, C, F>(
    port: &mut P,
    resolver: &InputResolver,
    cache: &InputValueCache,
    request: ConfigurationApply<I>,
    mut confirm: C,
    publish_success: F,
) -> Result<(), ApplyError>
where
    P: ConfigurationPort,
    I: IntoIterator<Item = (u8, InputIdentity)>,
    C: FnMut(EntityId, ConfigId) -> Result<(), String>,
    F: FnOnce() -> Result<(), ApplyError>,
{
    let ConfigurationApply { port_name, generation, device_id, config_id, messages, mappings, timeout } = request;
    let port_name = port_name.as_str();
    if !resolver.begin_reconfiguration(port_name, generation)
        || !cache.begin_reconfiguration(port_name, generation)
    {
        return Err(ApplyError::StaleGeneration);
    }
    if port.generation() != generation {
        return Err(ApplyError::StaleGeneration);
    }
    let mappings = mappings.into_iter().collect::<Vec<_>>();
    if mappings
        .iter()
        .any(|(_, identity)| identity.device_id != device_id)
    {
        return Err(ApplyError::InvalidMessage);
    }
    if messages.is_empty()
        || messages.iter().any(|message| {
            !matches!(message,
        Message::ConfigureAnalog { config_id: id, .. }
        | Message::ConfigureButton { config_id: id, .. }
        | Message::ConfigureMatrix { config_id: id, .. }
        | Message::ConfigureHt16k33 { config_id: id, .. } if *id == config_id.get())
        })
    {
        return Err(ApplyError::InvalidMessage);
    }
    for message in &messages {
        port.send(message).map_err(ApplyError::Send)?;
    }

    let deadline = Instant::now() + timeout;
    loop {
        if port.generation() != generation {
            return Err(ApplyError::StaleGeneration);
        }
        let remaining = deadline.saturating_duration_since(Instant::now());
        if remaining.is_zero() {
            return Err(ApplyError::Timeout);
        }
        match port.receive(remaining).map_err(ApplyError::Receive)? {
            Some(Message::ConfigurationStored { config_id: ack }) if ack == config_id.get() => {
                break
            }
            Some(Message::ConfigurationError { config_id: ack }) if ack == config_id.get() => {
                return Err(ApplyError::DeviceRejected)
            }
            Some(_) | None => {}
        }
    }

    if port.generation() != generation {
        return Err(ApplyError::StaleGeneration);
    }
    confirm(device_id, config_id).map_err(ApplyError::Persist)?;
    if port.generation() != generation {
        return Err(ApplyError::StaleGeneration);
    }
    if !resolver.replace_port(port_name, generation, config_id, mappings) {
        return Err(ApplyError::StaleGeneration);
    }
    if !cache.activate(port_name, generation) {
        resolver.invalidate_port(port_name, generation);
        return Err(ApplyError::StaleGeneration);
    }
    if let Err(error) = publish_success() {
        resolver.invalidate_port(port_name, generation);
        cache.invalidate(port_name, generation);
        return Err(error);
    }
    Ok(())
}
