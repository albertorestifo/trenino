//! Serial effects retain physical ownership independently from current DB rows.
use crate::{
    hardware::service::{ConnectedPort, HardwareCommandPort},
    storage::{Database, DisplayType},
    train::output_controller::{HardwareDispatch, OutputLevel},
};
use std::{
    collections::{BTreeMap, HashMap, HashSet},
    sync::{
        atomic::{AtomicBool, Ordering},
        Arc, Mutex,
    },
    time::{Duration, Instant},
};
use trenino_core::hardware::{ht16k33::encode_string, protocol::Message};
pub trait EffectTransport: Send + Sync + 'static {
    fn connected_ports(&self) -> Vec<ConnectedPort>;
    fn send_message(
        &self,
        port: &str,
        generation: u64,
        message: Message,
        timeout: Duration,
    ) -> Result<(), String>;
}
impl EffectTransport for HardwareCommandPort {
    fn connected_ports(&self) -> Vec<ConnectedPort> {
        self.connected_ports()
    }
    fn send_message(&self, p: &str, g: u64, m: Message, t: Duration) -> Result<(), String> {
        self.send_message(p, g, m, t)
    }
}
#[derive(Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
enum Target {
    Output(u8),
    Display(u8),
}
type Pending = HashMap<(String, u64), BTreeMap<Target, Message>>;
pub struct LiveHardwareEffects {
    pub command: Arc<dyn EffectTransport>,
    db: Arc<Database>,
    suspended: Arc<Mutex<HashSet<String>>>,
    // Potential energization survives uncertain acknowledgements and DB deletion/moves.
    pending: Mutex<Pending>,
    stopping: AtomicBool,
}
impl LiveHardwareEffects {
    pub fn new(
        command: Arc<dyn EffectTransport>,
        db: Arc<Database>,
        suspended: Arc<Mutex<HashSet<String>>>,
    ) -> Self {
        Self {
            command,
            db,
            suspended,
            pending: Mutex::new(HashMap::new()),
            stopping: AtomicBool::new(false),
        }
    }
    fn port(&self, port: &str) -> Result<ConnectedPort, String> {
        self.command
            .connected_ports()
            .into_iter()
            .find(|p| p.port == port)
            .ok_or_else(|| "Device disconnected.".into())
    }
    fn send_effect(&self, port: &str, message: Message) -> Result<(), String> {
        self.send_effect_at(port, None, message)
    }
    fn send_effect_at(
        &self,
        port: &str,
        expected_generation: Option<u64>,
        message: Message,
    ) -> Result<(), String> {
        let suspended = self
            .suspended
            .lock()
            .map_err(|_| "output admission poisoned")?;
        let cleanup = matches!(&message, Message::SetOutput { high: false, .. })
            || matches!(&message, Message::WriteSegments { data, .. } if data.iter().all(|byte| *byte == 0));
        if self.stopping.load(Ordering::Acquire) && !cleanup {
            return Err("Device output is shutting down.".into());
        }
        if suspended.contains(port) {
            return Err("Device output is suspended.".into());
        }
        let current = self.port(port)?;
        if expected_generation.is_some_and(|generation| generation != current.generation) {
            return Err("Device generation changed; select its current connection again.".into());
        }
        let mut pending = self
            .pending
            .lock()
            .map_err(|_| "output ownership poisoned")?;
        let tracked = pending
            .entry((port.to_owned(), current.generation))
            .or_default();
        // The transport can fail after bytes were written. Remember potential
        // physical effects before dispatch, and forget only acknowledged cleanup.
        match &message {
            Message::SetOutput { pin, high: true } => {
                tracked.insert(
                    Target::Output(*pin),
                    Message::SetOutput {
                        pin: *pin,
                        high: false,
                    },
                );
            }
            Message::WriteSegments { address, data } if data.iter().any(|v| *v != 0) => {
                track_display(tracked, *address, data.len());
            }
            _ => {}
        }
        self.command.send_message(
            port,
            current.generation,
            message.clone(),
            Duration::from_secs(2),
        )?;
        match message {
            Message::SetOutput { pin, high: false } => {
                tracked.remove(&Target::Output(pin));
            }
            Message::WriteSegments { address, data } if data.iter().all(|v| *v == 0) => {
                let previous = match tracked.get(&Target::Display(address)) {
                    Some(Message::WriteSegments { data, .. }) => data.len(),
                    _ => 0,
                };
                if data.len() >= previous {
                    tracked.remove(&Target::Display(address));
                }
            }
            _ => {}
        }
        Ok(())
    }
    pub fn set_output_at(
        &self,
        port: &str,
        generation: u64,
        pin: i32,
        level: OutputLevel,
    ) -> Result<(), String> {
        self.send_effect_at(
            port,
            Some(generation),
            Message::SetOutput {
                pin: pin.try_into().map_err(|_| "invalid output pin")?,
                high: level == OutputLevel::High,
            },
        )
    }
    pub fn set_module_brightness_at(
        &self,
        port: &str,
        generation: u64,
        address: i32,
        brightness: i32,
    ) -> Result<(), String> {
        self.send_effect_at(
            port,
            Some(generation),
            Message::SetModuleBrightness {
                address: address.try_into().map_err(|_| "invalid display address")?,
                brightness: brightness.try_into().map_err(|_| "invalid brightness")?,
            },
        )
    }
    pub fn write_segments_at(
        &self,
        port: &str,
        generation: u64,
        address: i32,
        data: Vec<u8>,
    ) -> Result<(), String> {
        self.send_effect_at(
            port,
            Some(generation),
            Message::WriteSegments {
                address: address.try_into().map_err(|_| "invalid display address")?,
                data,
            },
        )
    }
    pub fn stop_admission(&self) {
        self.stopping.store(true, Ordering::Release);
    }
    /// Acknowledged shutdown barrier for every physical target we may have
    /// energized, including scripts/manual effects absent from current DB rows.
    /// Successful entries are removed; uncertain failures remain for retry.
    pub fn neutralize_all(&self, timeout: Duration) -> Result<(), String> {
        self.stop_admission();
        let deadline = Instant::now() + timeout;
        // Serialize against all admitted writes and lease neutralization.
        let _gate = loop {
            match self.suspended.try_lock() {
                Ok(gate) => break gate,
                Err(std::sync::TryLockError::Poisoned(_)) => {
                    return Err("output admission poisoned".into())
                }
                Err(std::sync::TryLockError::WouldBlock) => {
                    if Instant::now() >= deadline {
                        return Err("hardware neutralization admission deadline exceeded".into());
                    }
                    std::thread::sleep(Duration::from_millis(2));
                }
            }
        };
        let mut pending = self
            .pending
            .lock()
            .map_err(|_| "output ownership poisoned")?;
        let mut failures = Vec::new();
        for ((port, generation), tracked) in pending.iter_mut() {
            tracked.retain(|_, message| {
                let remaining = deadline.saturating_duration_since(Instant::now());
                if remaining.is_zero() {
                    failures.push("hardware neutralization deadline exceeded".to_owned());
                    return true;
                }
                match self.command.send_message(
                    port,
                    *generation,
                    message.clone(),
                    remaining.min(Duration::from_secs(2)),
                ) {
                    Ok(()) => false,
                    Err(error) => {
                        failures.push(error);
                        true
                    }
                }
            });
        }
        pending.retain(|_, tracked| !tracked.is_empty());
        if failures.is_empty() {
            Ok(())
        } else {
            Err(failures.join("; "))
        }
    }
    pub fn suspend(&self, port: &str) -> Result<(), String> {
        let mut suspended = self
            .suspended
            .lock()
            .map_err(|_| "output admission poisoned")?;
        suspended.insert(port.to_owned());
        let current = self.port(port)?;
        let mut pending = self
            .pending
            .lock()
            .map_err(|_| "output ownership poisoned")?;
        let tracked = pending
            .entry((port.to_owned(), current.generation))
            .or_default();
        if let Some(device) = current.device_id {
            for output in self
                .db
                .outputs_for_device(device)
                .map_err(|e| e.to_string())?
            {
                let pin = output.pin.try_into().map_err(|_| "invalid output pin")?;
                tracked
                    .entry(Target::Output(pin))
                    .or_insert(Message::SetOutput { pin, high: false });
            }
            for module in self
                .db
                .i2c_modules_for_device(device)
                .map_err(|e| e.to_string())?
            {
                if let Some(p) = module.params {
                    let address = module
                        .i2c_address
                        .try_into()
                        .map_err(|_| "invalid display address")?;
                    let data = encode_string(
                        "",
                        p.num_digits as usize,
                        p.display_type == DisplayType::SevenSegment,
                        p.has_dot,
                        p.align_right,
                    );
                    track_display(tracked, address, data.len());
                }
            }
        }
        let mut failures = vec![];
        tracked.retain(|_, message| {
            match self.command.send_message(
                port,
                current.generation,
                message.clone(),
                Duration::from_secs(2),
            ) {
                Ok(()) => false,
                Err(e) => {
                    failures.push(e);
                    true
                }
            }
        });
        if failures.is_empty() {
            Ok(())
        } else {
            Err(failures.join("; "))
        }
    }
}
impl HardwareDispatch for LiveHardwareEffects {
    fn resolve_port(&self, config: i64) -> Option<String> {
        self.command
            .connected_ports()
            .into_iter()
            .find(|p| p.config_id.is_some_and(|id| id.get() as i64 == config))
            .map(|p| p.port)
    }
    fn set_output(&self, port: &str, pin: i32, level: OutputLevel) -> Result<(), String> {
        self.send_effect(
            port,
            Message::SetOutput {
                pin: pin.try_into().map_err(|_| "invalid output pin")?,
                high: level == OutputLevel::High,
            },
        )
    }
    fn set_module_brightness(
        &self,
        port: &str,
        address: i32,
        brightness: i32,
    ) -> Result<(), String> {
        self.send_effect(
            port,
            Message::SetModuleBrightness {
                address: address.try_into().map_err(|_| "invalid display address")?,
                brightness: brightness.try_into().map_err(|_| "invalid brightness")?,
            },
        )
    }
    fn write_segments(&self, port: &str, address: i32, data: Vec<u8>) -> Result<(), String> {
        self.send_effect(
            port,
            Message::WriteSegments {
                address: address.try_into().map_err(|_| "invalid display address")?,
                data,
            },
        )
    }
}

fn track_display(tracked: &mut BTreeMap<Target, Message>, address: u8, width: usize) {
    let previous = match tracked.get(&Target::Display(address)) {
        Some(Message::WriteSegments { data, .. }) => data.len(),
        _ => 0,
    };
    tracked.insert(
        Target::Display(address),
        Message::WriteSegments {
            address,
            data: vec![0; width.max(previous)],
        },
    );
}
