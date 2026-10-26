use serde_json::Value;
use std::time::Duration;

pub const HEALTH_INTERVAL: Duration = Duration::from_secs(30);
pub const FAST_HEALTH_INTERVAL: Duration = Duration::from_secs(2);
pub const MAX_HEALTH_FAILURES: u8 = 3;
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum SimulatorStatus {
    Disconnected,
    Connecting,
    Connected,
    Error,
    NeedsConfig,
}
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum ConnectionError {
    InvalidKey,
    ConnectionFailed,
    Timeout,
    Other(String),
}
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum HealthDecision {
    CheckAfter(Duration),
    RetryAfter(Duration),
}
#[derive(Clone, Debug, PartialEq)]
pub struct ConnectionState {
    pub status: SimulatorStatus,
    pub last_error: Option<ConnectionError>,
    pub info: Option<Value>,
    pub health_failures: u8,
}
impl Default for ConnectionState {
    fn default() -> Self {
        Self {
            status: SimulatorStatus::NeedsConfig,
            last_error: None,
            info: None,
            health_failures: 0,
        }
    }
}
impl ConnectionState {
    pub fn connected(&mut self, info: Value) {
        self.status = SimulatorStatus::Connected;
        self.info = Some(info);
        self.last_error = None;
        self.health_failures = 0;
    }
    pub fn disconnected(&mut self) {
        self.status = SimulatorStatus::Disconnected;
        self.info = None;
        self.health_failures = 0;
    }
    pub fn needs_config(&mut self) {
        self.status = SimulatorStatus::NeedsConfig;
        self.info = None;
        self.last_error = None;
        self.health_failures = 0;
    }
    pub fn failed_to_connect(&mut self, error: ConnectionError) {
        self.status = SimulatorStatus::Error;
        self.last_error = Some(error);
        self.health_failures = 0;
    }
    pub fn after_health_check(&mut self, result: Result<(), ConnectionError>) -> HealthDecision {
        if self.status != SimulatorStatus::Connected {
            return HealthDecision::CheckAfter(HEALTH_INTERVAL);
        }
        match result {
            Ok(()) => {
                self.health_failures = 0;
                self.last_error = None;
                HealthDecision::CheckAfter(HEALTH_INTERVAL)
            }
            Err(ConnectionError::InvalidKey) => {
                self.status = SimulatorStatus::Error;
                self.health_failures = 0;
                self.last_error = Some(ConnectionError::InvalidKey);
                HealthDecision::RetryAfter(HEALTH_INTERVAL)
            }
            Err(error) => {
                self.health_failures = self.health_failures.saturating_add(1);
                self.last_error = Some(error);
                if self.health_failures < MAX_HEALTH_FAILURES {
                    HealthDecision::CheckAfter(FAST_HEALTH_INTERVAL)
                } else {
                    let error = self.last_error.take().unwrap();
                    self.status = SimulatorStatus::Error;
                    self.health_failures = 0;
                    self.last_error = Some(error);
                    HealthDecision::RetryAfter(HEALTH_INTERVAL)
                }
            }
        }
    }
}
