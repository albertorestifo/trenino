//! Storage-backed adapter implementing the hardware runtime repository
//! contracts over the single bounded [`Database`] owner. Every mutation is one
//! atomic database commit; none of them hold the worker across serial I/O.

use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::Arc;

use trenino_core::hardware::calibration::Calibration;
use trenino_core::hardware::protocol::Message;
use trenino_core::{ConfigId, EntityId, OperationId};

use crate::hardware::configuration::ConfigurationRepository;
use crate::hardware::service::{
    HardwareRepository, PersistedHardwareConfiguration, PersistedInputMapping,
};
use crate::hardware::sessions::{CalibrationRepository, InputKind as SessionInputKind};
use crate::routing::InputIdentity;
use crate::storage::{CalibrationRecord, Database, DevicePatch, InputKind as StorageInputKind};

pub struct DatabaseHardwareRepository {
    database: Arc<Database>,
    operations: AtomicU64,
}

impl DatabaseHardwareRepository {
    pub fn new(database: Arc<Database>) -> Self {
        Self {
            database,
            operations: AtomicU64::new(0),
        }
    }

    fn next_operation(&self) -> OperationId {
        let next = self.operations.fetch_add(1, Ordering::Relaxed) + 1;
        OperationId(u128::from(next))
    }
}

impl ConfigurationRepository for DatabaseHardwareRepository {
    fn confirm_configuration(
        &mut self,
        device_id: EntityId,
        config_id: ConfigId,
    ) -> Result<(), String> {
        self.database
            .update_device(
                self.next_operation(),
                device_id,
                DevicePatch {
                    name: None,
                    description: None,
                    config_id: Some(Some(config_id)),
                },
            )
            .map(|_| ())
            .map_err(|error| match error {
                crate::storage::StorageError::NotFound => {
                    format!("device {device_id:?} no longer exists; refusing stale confirmation")
                }
                other => other.to_string(),
            })
    }
}

impl CalibrationRepository for DatabaseHardwareRepository {
    fn persist_calibration(
        &mut self,
        input_id: EntityId,
        calibration: Calibration,
    ) -> Result<(), String> {
        let record = CalibrationRecord {
            max_hardware_value: Some(calibration.max_hardware_value),
            min_value: Some(calibration.min_value),
            max_value: Some(calibration.max_value),
            has_rollover: calibration.rollover,
            is_inverted: calibration.inverted,
        };
        self.database
            .save_calibration(self.next_operation(), input_id, record)
            .map(|_| ())
            .map_err(|error| error.to_string())
    }
}

impl HardwareRepository for DatabaseHardwareRepository {
    fn load_configuration(
        &mut self,
        _port: &str,
        identity: &Message,
    ) -> Result<Option<PersistedHardwareConfiguration>, String> {
        // Boards are resolved by their persisted configuration identity, not by
        // port name, so the same device is found after replugging.
        let Message::IdentityResponse { config_id, .. } = identity else {
            return Ok(None);
        };
        let Some(config_id) = ConfigId::new(*config_id).ok() else {
            return Ok(None);
        };
        let Some(device) = self
            .database
            .get_device_by_config_id(config_id)
            .map_err(|e| e.to_string())?
        else {
            return Ok(None);
        };
        let inputs = self
            .database
            .inputs_for_device(device.id, true)
            .map_err(|e| e.to_string())?;
        let mappings = inputs
            .into_iter()
            .map(|input| {
                let pin = input
                    .pin
                    .filter(|pin| (0..=u8::MAX as i32).contains(pin))
                    .ok_or_else(|| format!("stored input {:?} has no valid pin", input.id))?
                    as u8;
                let kind = match input.kind {
                    Some(StorageInputKind::Analog) => SessionInputKind::Analog,
                    Some(StorageInputKind::Button) => SessionInputKind::Button,
                    None => return Err(format!("stored input {:?} has no kind", input.id)),
                };
                Ok(PersistedInputMapping {
                    pin,
                    identity: InputIdentity {
                        device_id: device.id,
                        input_id: input.id,
                    },
                    kind,
                })
            })
            .collect::<Result<Vec<_>, String>>()?;
        Ok(Some(PersistedHardwareConfiguration {
            device_id: device.id,
            config_id,
            mappings,
        }))
    }

    fn delete_device_unchecked(&mut self, device_id: EntityId) -> Result<(), String> {
        self.database
            .delete_device_unchecked(self.next_operation(), device_id)
            .map(|_| ())
            .map_err(|error| match error {
                crate::storage::StorageError::NotFound => {
                    format!("device {device_id:?} no longer exists")
                }
                other => other.to_string(),
            })
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::storage::{Database, DeviceDraft, InputDraft};
    use trenino_core::OperationId;

    fn repository() -> (tempfile::TempDir, DatabaseHardwareRepository) {
        let dir = tempfile::tempdir().unwrap();
        let database = Arc::new(Database::open_full(dir.path().join("hardware.db")).unwrap());
        database.allocate_epoch().unwrap();
        (dir, DatabaseHardwareRepository::new(database))
    }

    fn identity(config_id: u32) -> Message {
        Message::IdentityResponse {
            request_id: 1,
            major: 1,
            minor: 0,
            patch: 0,
            config_id,
        }
    }

    #[test]
    fn resolves_persisted_configuration_by_identity_and_confirms_atomically() {
        let (_dir, mut repository) = repository();
        let device = repository
            .database
            .create_device(
                OperationId(1),
                DeviceDraft {
                    name: "Panel".into(),
                    description: None,
                    config_id: Some(ConfigId::new(77).unwrap()),
                },
            )
            .unwrap();
        let input = repository
            .database
            .create_input(
                OperationId(2),
                device.record.id,
                InputDraft {
                    pin: 9,
                    kind: StorageInputKind::Analog,
                    sensitivity: Some(5),
                    debounce: None,
                    name: None,
                    matrix_id: None,
                },
            )
            .unwrap();

        let loaded = repository
            .load_configuration("COM-any", &identity(77))
            .unwrap()
            .unwrap();
        assert_eq!(loaded.device_id, device.record.id);
        assert_eq!(loaded.config_id.get(), 77);
        assert_eq!(loaded.mappings.len(), 1);
        assert_eq!(loaded.mappings[0].pin, 9);
        assert_eq!(loaded.mappings[0].identity.input_id, input.record.id);
        assert_eq!(loaded.mappings[0].kind, SessionInputKind::Analog);

        assert!(repository
            .load_configuration("COM-any", &identity(999_999))
            .unwrap()
            .is_none());
        assert!(repository
            .load_configuration("COM-any", &Message::IdentityRequest { request_id: 2 })
            .unwrap()
            .is_none());

        repository
            .confirm_configuration(device.record.id, ConfigId::new(91).unwrap())
            .unwrap();
        assert_eq!(
            repository
                .database
                .get_device(device.record.id)
                .unwrap()
                .unwrap()
                .config_id
                .map(|id| id.get()),
            Some(91)
        );
        assert!(repository
            .confirm_configuration(EntityId(999_999), ConfigId::new(1).unwrap())
            .is_err());
    }

    #[test]
    fn persists_calibration_and_deletes_devices_atomically() {
        let (_dir, mut repository) = repository();
        let device = repository
            .database
            .create_device(
                OperationId(1),
                DeviceDraft {
                    name: "Panel".into(),
                    description: None,
                    config_id: None,
                },
            )
            .unwrap();
        let input = repository
            .database
            .create_input(
                OperationId(2),
                device.record.id,
                InputDraft {
                    pin: 3,
                    kind: StorageInputKind::Button,
                    sensitivity: None,
                    debounce: Some(20),
                    name: None,
                    matrix_id: None,
                },
            )
            .unwrap();

        repository
            .persist_calibration(
                input.record.id,
                Calibration {
                    min_value: 0,
                    max_value: 900,
                    max_hardware_value: 1023,
                    inverted: true,
                    rollover: false,
                },
            )
            .unwrap();
        let stored = repository
            .database
            .get_input(input.record.id)
            .unwrap()
            .unwrap()
            .calibration
            .unwrap();
        assert_eq!(stored.value.max_value, Some(900));
        assert!(stored.value.is_inverted);

        repository
            .delete_device_unchecked(device.record.id)
            .unwrap();
        assert!(repository
            .database
            .get_device(device.record.id)
            .unwrap()
            .is_none());
        assert!(repository
            .delete_device_unchecked(device.record.id)
            .is_err());
    }
}
