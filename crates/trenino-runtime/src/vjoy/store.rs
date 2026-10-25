//! vJoy persistence on the storage worker (topic `vjoy`): the singleton
//! requested-enable configuration, the persisted selected-device set, and
//! input→target mappings. Ported from the Elixir `Trenino.VirtualJoystick`
//! context and its `Configuration`/`Mapping` schemas.
//!
//! Semantics preserved from the oracle:
//! - the singleton configuration row is created on first read with defaults
//!   (`enabled = false`, `device_index = 1`);
//! - mappings validate input-kind/target agreement, axis/button domains and
//!   target shape before writing; one mapping per input updates in place;
//! - `(device, axis)` and `(device, button)` targets are unique per the schema
//!   partial indexes — surfaced as `StorageError::Conflict`;
//! - a mapping is rejected while an *enabled* simulator binding exists for the
//! input unless `replace` removes every enabled binding in the same
//! transaction (Elixir `:destination_conflict` / `replace?`);
//! - `list` orders by device, target type, axis, button.

use std::collections::BTreeSet;

use rusqlite::{params, Connection, OptionalExtension, Transaction};
use trenino_core::{EntityId, OperationId};

use crate::storage::{domain_tx, topic_metadata, Database, InputKind, Mutation, RuntimeMetadata, StorageError};

/// The one topic all vJoy mutations commit under; each committed mutation
/// bumps exactly one revision.
const VJOY_TOPIC: &str = "vjoy";

/// app_settings key holding the persisted selected-device set as a sorted,
/// de-duplicated decimal CSV (e.g. `1,3,16`).
const SELECTED_DEVICES_KEY: &str = "vjoy.selected_devices";

pub const MIN_DEVICE_INDEX: u8 = 1;
pub const MAX_DEVICE_INDEX: u8 = 16;
pub const MAX_BUTTON: u8 = 32;

/// The eight serialized axis names, in canonical order.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord)]
pub enum VjoyAxis {
    X,
    Y,
    Z,
    Rx,
    Ry,
    Rz,
    Slider1,
    Slider2,
}

impl VjoyAxis {
    pub const ALL: [Self; 8] = [
        Self::X,
        Self::Y,
        Self::Z,
        Self::Rx,
        Self::Ry,
        Self::Rz,
        Self::Slider1,
        Self::Slider2,
    ];

    pub fn as_db(self) -> &'static str {
        match self {
            Self::X => "x",
            Self::Y => "y",
            Self::Z => "z",
            Self::Rx => "rx",
            Self::Ry => "ry",
            Self::Rz => "rz",
            Self::Slider1 => "slider_1",
            Self::Slider2 => "slider_2",
        }
    }

    /// Mirrors the Ecto enum: unknown names are invalid, not defaulted.
    pub fn parse(value: &str) -> Option<Self> {
        Self::ALL.iter().copied().find(|axis| axis.as_db() == value)
    }
}

/// Where one mapped input sends its value.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Target {
    Axis(VjoyAxis),
    Button(u8),
}

impl Target {
    fn target_type(self) -> &'static str {
        match self {
            Self::Axis(_) => "axis",
            Self::Button(_) => "button",
        }
    }

    fn axis_name(self) -> Option<&'static str> {
        match self {
            Self::Axis(axis) => Some(axis.as_db()),
            Self::Button(_) => None,
        }
    }

    fn button_number(self) -> Option<u8> {
        match self {
            Self::Axis(_) => None,
            Self::Button(button) => Some(button),
        }
    }
}

/// Validated mapping values for [`Database::vjoy_put_mapping`]. The input is
/// identified by the call's `input_id` argument, never by caller attributes
/// (Elixir drops a caller-supplied `input_id` the same way).
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct MappingDraft {
    pub device_index: u8,
    pub target: Target,
    pub inverted: bool,
}

/// A persisted mapping joined with the input facts the Elixir context preloaded
/// (`input: [:device]` — pin/device/name here; calibration is consumed by the
/// shared mapper track, not this store).
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct MappingRecord {
    pub id: EntityId,
    pub input_id: EntityId,
    pub device_index: u8,
    pub target: Target,
    pub inverted: bool,
    pub input_kind: InputKind,
    pub input_pin: Option<i32>,
    pub input_device: Option<EntityId>,
    pub input_name: Option<String>,
}

/// The singleton requested-state row (`virtual_joystick_configurations`).
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct VjoyConfiguration {
    pub enabled: bool,
    pub device_index: u8,
}

impl Default for VjoyConfiguration {
    fn default() -> Self {
        Self {
            enabled: false,
            device_index: 1,
        }
    }
}

/// Mapping-level error categories surfaced by this store, mirroring the Elixir
/// context's `{:error, :not_found | :destination_conflict | changeset}` shape.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum VjoyStoreError {
    /// The input (or mapping) row does not exist.
    NotFound,
    /// An enabled simulator binding owns this input's destination.
    DestinationConflict,
    /// The (device, axis) or (device, button) target is already mapped.
    TargetTaken(&'static str),
    /// Draft validation failed; the detail repeats the Elixir changeset text.
    Invalid(&'static str),
}

impl VjoyStoreError {
    fn into_storage(self) -> StorageError {
        match self {
            Self::NotFound => StorageError::NotFound,
            Self::DestinationConflict => StorageError::Conflict {
                detail: "destination_conflict".into(),
            },
            Self::TargetTaken(field) => StorageError::Conflict {
                detail: format!("{field} has already been taken"),
            },
            Self::Invalid(detail) => StorageError::Constraint {
                detail: detail.into(),
            },
        }
    }
}

fn timestamp() -> String {
    let seconds = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs() as i64;
    let days = seconds.div_euclid(86_400);
    let rem = seconds.rem_euclid(86_400);
    let z = days + 719_468;
    let era = if z >= 0 { z } else { z - 146_096 } / 146_097;
    let doe = z - era * 146_097;
    let yoe = (doe - doe / 1_460 + doe / 36_524 - doe / 146_096) / 365;
    let y = yoe + era * 400;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let d = doy - (153 * mp + 2) / 5 + 1;
    let m = mp + if mp < 10 { 3 } else { -9 };
    let year = y + if m <= 2 { 1 } else { 0 };
    format!(
        "{year:04}-{m:02}-{d:02}T{:02}:{:02}:{:02}Z",
        rem / 3_600,
        (rem % 3_600) / 60,
        rem % 60
    )
}

fn parse_input_kind(value: &str) -> Result<InputKind, StorageError> {
    match value {
        "analog" => Ok(InputKind::Analog),
        "button" => Ok(InputKind::Button),
        other => Err(StorageError::InvalidLegacyData {
            detail: format!("unknown input_type {other:?}"),
        }),
    }
}

/// Creates the singleton row with defaults when absent (Elixir
/// `get_configuration/0` inserts on first read). No revision bump: the row
/// carries only defaults, exactly like the oracle's read path.
fn ensure_configuration(c: &Connection) -> Result<VjoyConfiguration, StorageError> {
    c.execute(
        "INSERT OR IGNORE INTO virtual_joystick_configurations(id,enabled,device_index,inserted_at,updated_at)\
         \n         VALUES(1,FALSE,1,?1,?1)",
        params![timestamp()],
    )?;
    configuration(c)
}

fn configuration(c: &Connection) -> Result<VjoyConfiguration, StorageError> {
    let (enabled, device_index): (bool, i64) = c
        .query_row(
            "SELECT enabled,device_index FROM virtual_joystick_configurations WHERE id=1",
            [],
            |row| Ok((row.get(0)?, row.get(1)?)),
        )
        .optional()?
        .ok_or(StorageError::NotFound)?;
    Ok(VjoyConfiguration {
        enabled,
        device_index: device_index as u8,
    })
}

fn parse_selection(value: &str) -> Result<Vec<u8>, StorageError> {
    let mut devices = BTreeSet::new();
    for part in value.split(',') {
        if part.is_empty() {
            continue;
        }
        let device: u32 = part
            .parse()
            .map_err(|_| StorageError::InvalidLegacyData {
                detail: format!("{SELECTED_DEVICES_KEY} holds a non-numeric device id"),
            })?;
        if !(MIN_DEVICE_INDEX as u32..=MAX_DEVICE_INDEX as u32).contains(&device) {
            return Err(StorageError::InvalidLegacyData {
                detail: format!("{SELECTED_DEVICES_KEY} holds device id {device} outside 1..=16"),
            });
        }
        devices.insert(device as u8);
    }
    Ok(devices.into_iter().collect())
}

fn stored_selection(c: &Connection) -> Result<Option<Vec<u8>>, StorageError> {
    let stored: Option<String> = c
        .query_row(
            "SELECT value FROM app_settings WHERE key=?1",
            [SELECTED_DEVICES_KEY],
            |row| row.get(0),
        )
        .optional()?;
    stored.map(|value| parse_selection(&value)).transpose()
}

fn write_selection(tx: &Transaction<'_>, devices: &[u8]) -> Result<(), StorageError> {
    let value = devices
        .iter()
        .map(u8::to_string)
        .collect::<Vec<_>>()
        .join(",");
    tx.execute(
        "INSERT INTO app_settings(key,value) VALUES(?1,?2)\
         \n         ON CONFLICT(key) DO UPDATE SET value=excluded.value",
        params![SELECTED_DEVICES_KEY, value],
    )?;
    Ok(())
}

fn validate_selection(devices: &[u8]) -> Result<Vec<u8>, VjoyStoreError> {
    let mut unique = BTreeSet::new();
    for device in devices {
        if !(MIN_DEVICE_INDEX..=MAX_DEVICE_INDEX).contains(device) {
            return Err(VjoyStoreError::Invalid(
                "device_index must be between 1 and 16",
            ));
        }
        unique.insert(*device);
    }
    if unique.is_empty() {
        return Err(VjoyStoreError::Invalid("selected device set must not be empty"));
    }
    Ok(unique.into_iter().collect())
}

/// Row shape of [`MAPPING_SELECT`].
type MappingTuple = (
    i64,
    i64,
    i64,
    String,
    Option<String>,
    Option<i64>,
    i64,
    String,
    Option<i32>,
    Option<i64>,
    Option<String>,
);

fn mapping_row(row: &rusqlite::Row<'_>) -> rusqlite::Result<MappingTuple> {
    Ok((
        row.get(0)?,
        row.get(1)?,
        row.get(2)?,
        row.get(3)?,
        row.get(4)?,
        row.get(5)?,
        row.get(6)?,
        row.get(7)?,
        row.get(8)?,
        row.get(9)?,
        row.get(10)?,
    ))
}

fn hydrate_mapping(
    (id, input_id, device_index, target_type, axis, button, inverted, input_type, pin, device, name): MappingTuple,
) -> Result<MappingRecord, StorageError> {
    let target = match (target_type.as_str(), axis.as_deref(), button) {
        ("axis", Some(name), None) => Target::Axis(
            VjoyAxis::parse(name).ok_or_else(|| StorageError::InvalidLegacyData {
                detail: format!("mapping {id} holds unknown axis {name:?}"),
            })?,
        ),
        ("button", None, Some(button)) => {
            if !(1..=MAX_BUTTON as i64).contains(&button) {
                return Err(StorageError::InvalidLegacyData {
                    detail: format!("mapping {id} holds button {button} outside 1..=32"),
                });
            }
            Target::Button(button as u8)
        }
        _ => {
            return Err(StorageError::InvalidLegacyData {
                detail: format!("mapping {id} has an invalid target shape"),
            })
        }
    };
    Ok(MappingRecord {
        id: EntityId(id),
        input_id: EntityId(input_id),
        device_index: device_index as u8,
        target,
        inverted: inverted != 0,
        input_kind: parse_input_kind(&input_type)?,
        input_pin: pin,
        input_device: device.map(EntityId),
        input_name: name,
    })
}

const MAPPING_SELECT: &str = "SELECT m.id,m.input_id,m.device_index,m.target_type,m.axis,m.button,m.inverted,i.input_type,i.pin,i.device_id,i.name\
     \n     FROM virtual_joystick_mappings m JOIN device_inputs i ON i.id=m.input_id";

fn get_mapping(c: &Connection, id: EntityId) -> Result<Option<MappingRecord>, StorageError> {
    let row = c
        .query_row(
            &format!("{MAPPING_SELECT} WHERE m.id=?1"),
            [id.0],
            mapping_row,
        )
        .optional()?;
    row.map(hydrate_mapping).transpose()
}

fn mapping_by_input(c: &Connection, input: EntityId) -> Result<Option<(i64, i64)>, StorageError> {
    c.query_row(
        "SELECT id,device_index FROM virtual_joystick_mappings WHERE input_id=?1",
        [input.0],
        |row| Ok((row.get(0)?, row.get(1)?)),
    )
    .optional()
    .map_err(StorageError::from)
}

fn target_taken(
    tx: &Transaction<'_>,
    device: u8,
    target: Target,
    exclude: Option<i64>,
) -> Result<bool, StorageError> {
    let (column, value): (&'static str, String) = match target {
        Target::Axis(axis) => ("axis", axis.as_db().to_owned()),
        Target::Button(button) => ("button", button.to_string()),
    };
    let sql = format!(
        "SELECT EXISTS(SELECT 1 FROM virtual_joystick_mappings\
         \n         WHERE device_index=?1 AND target_type=?2 AND {column}=?3 AND id!=?4)"
    );
    let taken: bool = tx.query_row(
        &sql,
        params![
            i64::from(device),
            target.target_type(),
            value,
            exclude.unwrap_or(-1)
        ],
        |row| row.get(0),
    )?;
    Ok(taken)
}

fn enabled_binding_exists(tx: &Transaction<'_>, input: EntityId) -> Result<bool, StorageError> {
    let lever: bool = tx.query_row(
        "SELECT EXISTS(SELECT 1 FROM lever_input_bindings WHERE input_id=?1 AND enabled=1)",
        [input.0],
        |row| row.get(0),
    )?;
    let button: bool = tx.query_row(
        "SELECT EXISTS(SELECT 1 FROM button_input_bindings WHERE input_id=?1 AND enabled=1)",
        [input.0],
        |row| row.get(0),
    )?;
    Ok(lever || button)
}

fn delete_enabled_bindings(tx: &Transaction<'_>, input: EntityId) -> Result<(), StorageError> {
    tx.execute(
        "DELETE FROM lever_input_bindings WHERE input_id=?1 AND enabled=1",
        [input.0],
    )?;
    tx.execute(
        "DELETE FROM button_input_bindings WHERE input_id=?1 AND enabled=1",
        [input.0],
    )?;
    Ok(())
}

fn validate_draft(draft: &MappingDraft, input_kind: InputKind) -> Result<(), VjoyStoreError> {
    if !(MIN_DEVICE_INDEX..=MAX_DEVICE_INDEX).contains(&draft.device_index) {
        return Err(VjoyStoreError::Invalid(
            "device_index must be between 1 and 16",
        ));
    }
    let kind_matches = match (input_kind, draft.target) {
        (InputKind::Analog, Target::Axis(_)) => true,
        (InputKind::Analog, Target::Button(_)) => false,
        (InputKind::Button, Target::Button(_)) => true,
        (InputKind::Button, Target::Axis(_)) => false,
    };
    if !kind_matches {
        return Err(VjoyStoreError::Invalid(match input_kind {
            InputKind::Analog => "target_type must target an axis",
            InputKind::Button => "target_type must target a button",
        }));
    }
    if let Target::Button(button) = draft.target {
        if !(1..=MAX_BUTTON).contains(&button) {
            return Err(VjoyStoreError::Invalid("button must be between 1 and 32"));
        }
    }
    Ok(())
}

impl Database {
    /// The singleton requested-state configuration, created with defaults on
    /// first read. Mirrors `Trenino.VirtualJoystick.get_configuration/0`.
    pub fn vjoy_configuration(&self) -> Result<VjoyConfiguration, StorageError> {
        self.domain_call("vjoy_configuration", |c| ensure_configuration(c))
    }

    /// Persist the requested-enable flag. Only called after the runtime
    /// confirmed the corresponding transition (acquire/release), matching the
    /// oracle's persist-after-confirmation rule.
    pub fn vjoy_confirm_enabled(
        &self,
        operation_id: OperationId,
        enabled: bool,
    ) -> Result<Mutation<VjoyConfiguration>, StorageError> {
        self.domain_call("vjoy_confirm_enabled", move |c| {
            domain_tx(c, VJOY_TOPIC, operation_id, |tx| {
                ensure_configuration(tx)?;
                tx.execute(
                    "UPDATE virtual_joystick_configurations SET enabled=?1,updated_at=?2 WHERE id=1",
                    params![enabled, timestamp()],
                )?;
                configuration(tx)
            })
        })
    }

    /// The persisted selected-device set, sorted ascending. When no selection
    /// has been stored yet it seeds from the singleton configuration's
    /// `device_index` — migrating existing device-1 rows without adopting any
    /// other device.
    pub fn vjoy_selected_devices(&self) -> Result<Vec<u8>, StorageError> {
        self.domain_call("vjoy_selected_devices", |c| {
            Ok(match stored_selection(c)? {
                Some(devices) => devices,
                None => vec![ensure_configuration(c)?.device_index],
            })
        })
    }

    /// Persist the selected-device set. Duplicates collapse and the set is
    /// stored sorted; every id must be in `1..=16` and the set non-empty.
    pub fn vjoy_set_selected_devices(
        &self,
        operation_id: OperationId,
        devices: &[u8],
    ) -> Result<Mutation<Vec<u8>>, StorageError> {
        let requested = devices.to_vec();
        self.domain_call("vjoy_set_selected_devices", move |c| {
            let normalized =
                validate_selection(&requested).map_err(VjoyStoreError::into_storage)?;
            domain_tx(c, VJOY_TOPIC, operation_id, |tx| {
                write_selection(tx, &normalized)?;
                Ok(normalized)
            })
        })
    }

    /// All mappings ordered by device index, target type, axis, button — the
    /// Elixir `list_mappings/0` order.
    pub fn vjoy_list_mappings(&self) -> Result<Vec<MappingRecord>, StorageError> {
        self.domain_call("vjoy_list_mappings", |c| {
            let mut statement = c.prepare(&format!(
                "{MAPPING_SELECT} ORDER BY m.device_index,m.target_type,m.axis,m.button"
            ))?;
            let rows = statement
                .query_map([], mapping_row)?
                .collect::<rusqlite::Result<Vec<_>>>()?;
            rows.into_iter().map(hydrate_mapping).collect()
        })
    }

    /// One mapping with its input facts. `None` mirrors `{:error, :not_found}`.
    pub fn vjoy_get_mapping(&self, id: EntityId) -> Result<Option<MappingRecord>, StorageError> {
        self.domain_call("vjoy_get_mapping", move |c| get_mapping(c, id))
    }

    /// Create or update the mapping for one input. Rejections:
    /// - missing input — [`StorageError::NotFound`];
    /// - analog/button disagreement and domain violations —
    ///   [`StorageError::Constraint`] with the Elixir changeset detail;
    /// - an enabled simulator binding holds the input's destination —
    ///   [`StorageError::Conflict`] `destination_conflict` unless `replace`
    ///   deletes every enabled binding in the same transaction;
    /// - the (device, axis)/(device, button) target is already used —
    ///   [`StorageError::Conflict`] `axis|button has already been taken`.
    pub fn vjoy_put_mapping(
        &self,
        operation_id: OperationId,
        input_id: EntityId,
        draft: MappingDraft,
        replace: bool,
    ) -> Result<Mutation<MappingRecord>, StorageError> {
        self.domain_call("vjoy_put_mapping", move |c| {
            domain_tx(c, VJOY_TOPIC, operation_id, |tx| {
                let (input_type, _pin, _device, _name): (String, Option<i32>, Option<i64>, Option<String>) = tx
                    .query_row(
                        "SELECT input_type,pin,device_id,name FROM device_inputs WHERE id=?1",
                        [input_id.0],
                        |row| Ok((row.get(0)?, row.get(1)?, row.get(2)?, row.get(3)?)),
                    )
                    .optional()?
                    .ok_or(VjoyStoreError::NotFound.into_storage())?;
                let input_kind = parse_input_kind(&input_type)?;
                validate_draft(&draft, input_kind).map_err(VjoyStoreError::into_storage)?;

                if replace {
                    delete_enabled_bindings(tx, input_id)?;
                } else if enabled_binding_exists(tx, input_id)? {
                    return Err(VjoyStoreError::DestinationConflict.into_storage());
                }

                let existing = mapping_by_input(tx, input_id)?;
                if target_taken(tx, draft.device_index, draft.target, existing.map(|(id, _)| id))? {
                    return Err(
                        VjoyStoreError::TargetTaken(match draft.target {
                            Target::Axis(_) => "axis",
                            Target::Button(_) => "button",
                        })
                        .into_storage(),
                    );
                }

                let now = timestamp();
                let (axis, button) = (
                    draft.target.axis_name(),
                    draft.target.button_number().map(i64::from),
                );
                let id = match existing {
                    Some((id, _)) => {
                        tx.execute(
                            "UPDATE virtual_joystick_mappings SET device_index=?1,target_type=?2,axis=?3,button=?4,inverted=?5,updated_at=?6 WHERE id=?7",
                            params![
                                i64::from(draft.device_index),
                                draft.target.target_type(),
                                axis,
                                button,
                                draft.inverted,
                                now,
                                id
                            ],
                        )?;
                        id
                    }
                    None => {
                        tx.execute(
                            "INSERT INTO virtual_joystick_mappings(input_id,device_index,target_type,axis,button,inverted,inserted_at,updated_at) VALUES(?1,?2,?3,?4,?5,?6,?7,?7)",
                            params![
                                input_id.0,
                                i64::from(draft.device_index),
                                draft.target.target_type(),
                                axis,
                                button,
                                draft.inverted,
                                now
                            ],
                        )?;
                        tx.last_insert_rowid()
                    }
                };
                get_mapping(tx, EntityId(id))?.ok_or(StorageError::NotFound)
            })
        })
    }

    /// Delete one mapping. Missing ids reject like the oracle's `:not_found`.
    pub fn vjoy_delete_mapping(
        &self,
        operation_id: OperationId,
        id: EntityId,
    ) -> Result<Mutation<MappingRecord>, StorageError> {
        self.domain_call("vjoy_delete_mapping", move |c| {
            domain_tx(c, VJOY_TOPIC, operation_id, |tx| {
                let record =
                    get_mapping(tx, id)?.ok_or(VjoyStoreError::NotFound.into_storage())?;
                tx.execute("DELETE FROM virtual_joystick_mappings WHERE id=?1", [id.0])?;
                Ok(record)
            })
        })
    }

    /// Current `vjoy` topic revision pair without mutating anything.
    pub fn vjoy_topic_metadata(&self) -> Result<RuntimeMetadata, StorageError> {
        self.domain_call("vjoy_topic_metadata", |c| topic_metadata(c, VJOY_TOPIC))
    }
}
