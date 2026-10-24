//! Typed train persistence (trains, identifiers, elements, lever configs,
//! notches) on the database's existing bounded worker. Ports the semantics of
//! `Trenino.Train` (train.ex) and the schemas in `lib/trenino/train/`:
//! validations, defaults, ordering, cascades, and unique constraints are
//! preserved; only the shape is Rust.
//!
//! Every mutation commits exactly one "trains" topic revision; invalid
//! mutations change neither content nor revision (`storage::domain::domain_tx`).
use rusqlite::{params, Connection, OptionalExtension};
use trenino_core::{EntityId, OperationId};

use crate::storage::{
    metadata_key, read_u64, validate_runtime_metadata, Database, DbResult, Mutation, Request,
    RuntimeMetadata, SchemaMode, StorageError,
};

use super::domain_tx;

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ElementKind {
    Lever,
    Button,
}

impl ElementKind {
    pub fn as_db(self) -> &'static str {
        match self {
            Self::Lever => "lever",
            Self::Button => "button",
        }
    }
    fn parse(value: &str) -> DbResult<Self> {
        match value {
            "lever" => Ok(Self::Lever),
            "button" => Ok(Self::Button),
            other => Err(invalid(format!("unknown element type {other:?}"))),
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum LeverType {
    Discrete,
    Continuous,
    Hybrid,
}

impl LeverType {
    pub fn as_db(self) -> &'static str {
        match self {
            Self::Discrete => "discrete",
            Self::Continuous => "continuous",
            Self::Hybrid => "hybrid",
        }
    }
    fn parse(value: &str) -> DbResult<Self> {
        match value {
            "discrete" => Ok(Self::Discrete),
            "continuous" => Ok(Self::Continuous),
            "hybrid" => Ok(Self::Hybrid),
            other => Err(invalid(format!("unknown lever_type {other:?}"))),
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum NotchKind {
    Gate,
    Linear,
}

impl NotchKind {
    pub fn as_db(self) -> &'static str {
        match self {
            Self::Gate => "gate",
            Self::Linear => "linear",
        }
    }
    fn parse(value: &str) -> DbResult<Self> {
        match value {
            "gate" => Ok(Self::Gate),
            "linear" => Ok(Self::Linear),
            other => Err(invalid(format!("unknown notch type {other:?}"))),
        }
    }
}

/// Outcome of `get_train_by_identifier` — mirrors
/// `Trenino.Train.get_train_by_identifier/1`'s `{:ok, ..} | {:error, :not_found}
/// | {:error, {:multiple_matches, trains}}`.
#[derive(Clone, Debug, PartialEq)]
pub enum IdentifierMatch {
    Unique(TrainRecord),
    NotFound,
    Ambiguous(Vec<TrainRecord>),
}

/// Outcome of `validate_notch_ranges` — mirrors `:ok | {:error, :gaps_detected, gaps}`.
#[derive(Clone, Debug, PartialEq)]
pub enum RangesValidation {
    Valid,
    Gaps(Vec<(f64, f64)>),
}

#[derive(Clone, Debug, PartialEq)]
pub struct NotchRecord {
    pub id: EntityId,
    pub lever_config_id: EntityId,
    pub index: i64,
    pub kind: NotchKind,
    pub value: Option<f64>,
    pub min_value: Option<f64>,
    pub max_value: Option<f64>,
    pub input_min: Option<f64>,
    pub input_max: Option<f64>,
    pub sim_input_min: Option<f64>,
    pub sim_input_max: Option<f64>,
    pub description: Option<String>,
}

/// Notch payload. `index` is honored by `create_notch`; the bulk saves
/// (`save_calibration`/`save_notches`) assign positions, exactly like the
/// Elixir context which overrides "index" with the list position.
#[derive(Clone, Debug, PartialEq)]
pub struct NotchDraft {
    pub index: i64,
    pub kind: NotchKind,
    pub value: Option<f64>,
    pub min_value: Option<f64>,
    pub max_value: Option<f64>,
    pub input_min: Option<f64>,
    pub input_max: Option<f64>,
    pub sim_input_min: Option<f64>,
    pub sim_input_max: Option<f64>,
    pub description: Option<String>,
}

/// Partial notch update; fields merge over the stored record before
/// revalidation (like an Ecto changeset over existing data).
#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct NotchPatch {
    pub index: Option<i64>,
    pub kind: Option<NotchKind>,
    pub value: Option<Option<f64>>,
    pub min_value: Option<Option<f64>>,
    pub max_value: Option<Option<f64>>,
    pub input_min: Option<Option<f64>>,
    pub input_max: Option<Option<f64>>,
    pub sim_input_min: Option<Option<f64>>,
    pub sim_input_max: Option<Option<f64>>,
}

#[derive(Clone, Debug, PartialEq)]
pub struct LeverConfigRecord {
    pub id: EntityId,
    pub element_id: EntityId,
    pub min_endpoint: String,
    pub max_endpoint: String,
    pub value_endpoint: String,
    pub notch_count_endpoint: Option<String>,
    pub notch_index_endpoint: Option<String>,
    pub lever_type: Option<LeverType>,
    pub inverted: bool,
    pub calibrated_at: Option<String>,
    pub notches: Vec<NotchRecord>,
}

#[derive(Clone, Debug, Default, PartialEq)]
pub struct LeverConfigDraft {
    pub min_endpoint: String,
    pub max_endpoint: String,
    pub value_endpoint: String,
    pub notch_count_endpoint: Option<String>,
    pub notch_index_endpoint: Option<String>,
    pub lever_type: Option<LeverType>,
    pub inverted: bool,
}

/// Partial lever-config update; `None` keeps the stored value. The nested
/// `Option<Option<T>>` shape (from `DevicePatch`) distinguishes "leave alone"
/// from "clear".
#[derive(Clone, Debug, Default, PartialEq)]
pub struct LeverConfigPatch {
    pub min_endpoint: Option<String>,
    pub max_endpoint: Option<String>,
    pub value_endpoint: Option<String>,
    pub notch_count_endpoint: Option<Option<String>>,
    pub notch_index_endpoint: Option<Option<String>>,
    pub lever_type: Option<Option<LeverType>>,
    pub inverted: Option<bool>,
    pub calibrated_at: Option<Option<String>>,
}

/// One entry of a `LeverAnalyzer` result, as consumed by
/// `create/update_lever_config_with_analysis`. `input_min`/`input_max` are the
/// simulator InputValue range and land in `sim_input_min/max`.
#[derive(Clone, Debug, PartialEq)]
pub struct SuggestedNotch {
    pub index: Option<i64>,
    pub kind: NotchKind,
    pub value: Option<f64>,
    pub min_value: Option<f64>,
    pub max_value: Option<f64>,
    pub description: Option<String>,
    pub input_min: Option<f64>,
    pub input_max: Option<f64>,
}

#[derive(Clone, Debug, PartialEq)]
pub struct LeverAnalysis {
    pub lever_type: LeverType,
    pub suggested_notches: Vec<SuggestedNotch>,
}

#[derive(Clone, Debug, PartialEq)]
pub struct ElementRecord {
    pub id: EntityId,
    pub train_id: EntityId,
    pub kind: ElementKind,
    pub name: String,
    pub lever_config: Option<LeverConfigRecord>,
}

#[derive(Clone, Debug, PartialEq)]
pub struct ElementDraft {
    pub kind: ElementKind,
    pub name: String,
}

#[derive(Clone, Debug, PartialEq)]
pub struct TrainRecord {
    pub id: EntityId,
    pub name: String,
    pub description: Option<String>,
    pub identifiers: Vec<String>,
    pub elements: Vec<ElementRecord>,
}

#[derive(Clone, Debug, PartialEq)]
pub struct TrainDraft {
    pub name: String,
    pub description: Option<String>,
    pub identifiers: Vec<String>,
}

#[derive(Clone, Debug, Default, PartialEq)]
pub struct TrainPatch {
    pub name: Option<String>,
    pub description: Option<Option<String>>,
    /// Full replacement of the identifier collection (Ecto `cast_assoc` with
    /// `on_replace: :delete`).
    pub identifiers: Option<Vec<String>>,
}

/// One entry of `update_notch_input_ranges`' batch.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct NotchInputRange {
    pub notch_id: EntityId,
    pub input_min: f64,
    pub input_max: f64,
}

// ---------------------------------------------------------------------------
// Errors / helpers
// ---------------------------------------------------------------------------

fn invalid(detail: impl Into<String>) -> StorageError {
    StorageError::Constraint {
        detail: detail.into(),
    }
}

fn taken(detail: impl Into<String>) -> StorageError {
    StorageError::Conflict {
        detail: detail.into(),
    }
}

/// Round to 2 decimal places like the Elixir schemas' `round_float_fields/2`.
fn round2(value: f64) -> f64 {
    trenino_core::rounding::round_elixir(value, 2).unwrap_or(value)
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


// ---------------------------------------------------------------------------
// Row readers
// ---------------------------------------------------------------------------

fn notch_row(row: &rusqlite::Row<'_>) -> rusqlite::Result<NotchRecord> {
    Ok(NotchRecord {
        id: EntityId(row.get(0)?),
        lever_config_id: EntityId(row.get(1)?),
        index: row.get(2)?,
        kind: NotchKind::parse(&row.get::<_, String>(3)?)
            .map_err(|_| rusqlite::Error::FromSqlConversionFailure(3, rusqlite::types::Type::Text, "unknown notch type".into()))?,
        value: row.get(4)?,
        min_value: row.get(5)?,
        max_value: row.get(6)?,
        input_min: row.get(7)?,
        input_max: row.get(8)?,
        sim_input_min: row.get(9)?,
        sim_input_max: row.get(10)?,
        description: row.get(11)?,
    })
}

const NOTCH_COLUMNS: &str =
    "id,lever_config_id,\"index\",type,value,min_value,max_value,input_min,input_max,sim_input_min,sim_input_max,description";

fn notches_for_config(c: &Connection, config: EntityId) -> DbResult<Vec<NotchRecord>> {
    let sql = format!(
        "SELECT {NOTCH_COLUMNS} FROM train_lever_notches WHERE lever_config_id=?1 ORDER BY id"
    );
    let mut q = c.prepare(&sql)?;
    let rows = q.query_map([config.0], notch_row)?;
    rows.collect::<Result<Vec<_>, _>>()
        .map_err(StorageError::from)
}

fn get_notch(c: &Connection, id: EntityId) -> DbResult<Option<NotchRecord>> {
    let sql = format!("SELECT {NOTCH_COLUMNS} FROM train_lever_notches WHERE id=?1");
    c.query_row(&sql, [id.0], notch_row)
        .optional()
        .map_err(StorageError::from)
}

fn lever_config_row(c: &Connection, row: &rusqlite::Row<'_>) -> rusqlite::Result<LeverConfigRecord> {
    let id = EntityId(row.get(0)?);
    let lever_type = row
        .get::<_, Option<String>>(7)?
        .map(|value| {
            LeverType::parse(&value).map_err(|_| {
                rusqlite::Error::FromSqlConversionFailure(
                    7,
                    rusqlite::types::Type::Text,
                    "unknown lever_type".into(),
                )
            })
        })
        .transpose()?;
    Ok(LeverConfigRecord {
        id,
        element_id: EntityId(row.get(1)?),
        min_endpoint: row.get(2)?,
        max_endpoint: row.get(3)?,
        value_endpoint: row.get(4)?,
        notch_count_endpoint: row.get(5)?,
        notch_index_endpoint: row.get(6)?,
        lever_type,
        inverted: row.get::<_, i64>(8)? != 0,
        calibrated_at: row.get(9)?,
        notches: notches_for_config(c, id).map_err(|e| {
            rusqlite::Error::FromSqlConversionFailure(9, rusqlite::types::Type::Null, format!("notches: {e:?}").into())
        })?,
    })
}

const LEVER_CONFIG_COLUMNS: &str = "id,element_id,min_endpoint,max_endpoint,value_endpoint,notch_count_endpoint,notch_index_endpoint,lever_type,inverted,calibrated_at";

fn get_lever_config_by_id(c: &Connection, id: EntityId) -> DbResult<Option<LeverConfigRecord>> {
    let sql = format!(
        "SELECT {LEVER_CONFIG_COLUMNS} FROM train_lever_configs WHERE id=?1"
    );
    c.query_row(&sql, [id.0], |row| lever_config_row(c, row))
        .optional()
        .map_err(StorageError::from)
}

/// Mirrors `Trenino.Train.get_lever_config/1`: looks the config up by element.
fn get_lever_config_for_element(
    c: &Connection,
    element: EntityId,
) -> DbResult<Option<LeverConfigRecord>> {
    let sql = format!(
        "SELECT {LEVER_CONFIG_COLUMNS} FROM train_lever_configs WHERE element_id=?1"
    );
    c.query_row(&sql, [element.0], |row| lever_config_row(c, row))
        .optional()
        .map_err(StorageError::from)
}

fn element_row(c: &Connection, row: &rusqlite::Row<'_>) -> rusqlite::Result<ElementRecord> {
    let id = EntityId(row.get(0)?);
    let kind = ElementKind::parse(&row.get::<_, String>(2)?).map_err(|_| {
        rusqlite::Error::FromSqlConversionFailure(2, rusqlite::types::Type::Text, "unknown element type".into())
    })?;
    let lever_config = get_lever_config_for_element(c, id)
        .map_err(|_| rusqlite::Error::FromSqlConversionFailure(2, rusqlite::types::Type::Null, "lever_config".into()))?;
    Ok(ElementRecord {
        id,
        train_id: EntityId(row.get(1)?),
        kind,
        name: row.get(3)?,
        lever_config,
    })
}

fn elements_for_train(c: &Connection, train: EntityId) -> DbResult<Vec<ElementRecord>> {
    let mut q = c.prepare(
        "SELECT id,train_id,type,name FROM train_elements WHERE train_id=?1 ORDER BY name,id",
    )?;
    let rows = q.query_map([train.0], |row| element_row(c, row))?;
    rows.collect::<Result<Vec<_>, _>>()
        .map_err(StorageError::from)
}

fn get_element_row(c: &Connection, id: EntityId) -> DbResult<Option<ElementRecord>> {
    c.query_row(
        "SELECT id,train_id,type,name FROM train_elements WHERE id=?1",
        [id.0],
        |row| element_row(c, row),
    )
    .optional()
    .map_err(StorageError::from)
}

fn identifiers_for_train(c: &Connection, train: EntityId) -> DbResult<Vec<String>> {
    let mut q = c.prepare(
        "SELECT identifier FROM train_identifiers WHERE train_id=?1 ORDER BY id",
    )?;
    let rows = q.query_map([train.0], |r| r.get(0))?;
    rows.collect::<Result<Vec<_>, _>>()
        .map_err(StorageError::from)
}

fn train_row(c: &Connection, row: &rusqlite::Row<'_>) -> rusqlite::Result<TrainRecord> {
    let id = EntityId(row.get(0)?);
    Ok(TrainRecord {
        id,
        name: row.get(1)?,
        description: row.get(2)?,
        identifiers: identifiers_for_train(c, id).map_err(|_| {
            rusqlite::Error::FromSqlConversionFailure(2, rusqlite::types::Type::Null, "identifiers".into())
        })?,
        elements: elements_for_train(c, id).map_err(|_| {
            rusqlite::Error::FromSqlConversionFailure(2, rusqlite::types::Type::Null, "elements".into())
        })?,
    })
}

fn get_train_row(c: &Connection, id: EntityId) -> DbResult<Option<TrainRecord>> {
    c.query_row(
        "SELECT id,name,description FROM trains WHERE id=?1",
        [id.0],
        |row| train_row(c, row),
    )
    .optional()
    .map_err(StorageError::from)
}

fn all_trains(c: &Connection) -> DbResult<Vec<TrainRecord>> {
    let mut q = c.prepare("SELECT id,name,description FROM trains ORDER BY name,id")?;
    let rows = q.query_map([], |row| train_row(c, row))?;
    rows.collect::<Result<Vec<_>, _>>()
        .map_err(StorageError::from)
}

fn train_exists(c: &Connection, id: EntityId) -> DbResult<bool> {
    c.query_row(
        "SELECT EXISTS(SELECT 1 FROM trains WHERE id=?1)",
        [id.0],
        |r| r.get(0),
    )
    .map_err(StorageError::from)
}

fn identifier_taken(
    c: &Connection,
    identifier: &str,
    exclude_train: Option<EntityId>,
) -> DbResult<bool> {
    c.query_row(
        "SELECT EXISTS(SELECT 1 FROM train_identifiers WHERE identifier=?1 AND train_id IS NOT ?2)",
        params![identifier, exclude_train.map(|id| id.0)],
        |r| r.get(0),
    )
    .map_err(StorageError::from)
}

// ---------------------------------------------------------------------------
// Validation (ports of the Ecto changesets)
// ---------------------------------------------------------------------------

fn validate_identifier_collection(
    c: &Connection,
    identifiers: &[String],
    exclude_train: Option<EntityId>,
) -> DbResult<()> {
    if identifiers.is_empty() {
        return Err(invalid(
            "identifiers must have at least one identifier",
        ));
    }
    let mut seen = std::collections::HashSet::new();
    for identifier in identifiers {
        if !seen.insert(identifier.as_str()) {
            return Err(invalid(
                "identifiers must be unique within a train profile",
            ));
        }
        if identifier_taken(c, identifier, exclude_train)? {
            return Err(taken(format!(
                "identifier {identifier:?} has already been taken"
            )));
        }
    }
    Ok(())
}

/// Ports `TrainIdentifier.changeset/2`: required + trimmed identifiers.
fn normalize_identifiers(raw: Vec<String>) -> Vec<String> {
    raw.into_iter()
        .map(|value| value.trim().to_string())
        .collect()
}

fn validate_lever_config_fields(
    min_endpoint: &str,
    max_endpoint: &str,
    value_endpoint: &str,
    notch_count: Option<&str>,
    notch_index: Option<&str>,
) -> DbResult<()> {
    if min_endpoint.is_empty() {
        return Err(invalid("min_endpoint can't be blank"));
    }
    if max_endpoint.is_empty() {
        return Err(invalid("max_endpoint can't be blank"));
    }
    if value_endpoint.is_empty() {
        return Err(invalid("value_endpoint can't be blank"));
    }
    // LeverConfig.validate_notch_endpoints/1
    if notch_count.is_some() && notch_index.is_none() {
        return Err(invalid(
            "notch_index_endpoint is required when notch_count_endpoint is set",
        ));
    }
    if notch_count.is_none() && notch_index.is_some() {
        return Err(invalid(
            "notch_count_endpoint is required when notch_index_endpoint is set",
        ));
    }
    Ok(())
}

/// Ports `Notch.changeset/2`'s validations over the merged field values.
fn validate_notch_fields(
    _index: i64,
    kind: NotchKind,
    value: Option<f64>,
    min_value: Option<f64>,
    max_value: Option<f64>,
    input_min: Option<f64>,
    input_max: Option<f64>,
    sim_input_min: Option<f64>,
    sim_input_max: Option<f64>,
) -> DbResult<()> {
    match kind {
        NotchKind::Gate => {
            if value.is_none() {
                return Err(invalid("value is required for gate notches"));
            }
        }
        NotchKind::Linear => {
            if min_value.is_none() || max_value.is_none() {
                return Err(invalid(
                    "min_value and max_value are required for linear notches",
                ));
            }
        }
    }
    validate_range_pair("input_min", "input_max", input_min, input_max, true)?;
    validate_range_pair(
        "sim_input_min",
        "sim_input_max",
        sim_input_min,
        sim_input_max,
        false,
    )?;
    Ok(())
}

/// Ports validate_both_set/validate_min_lte_max/validate_in_range. The 0.0-1.0
/// bound applies only to hardware input ranges, not sim input ranges.
fn validate_range_pair(
    min_field: &'static str,
    max_field: &'static str,
    min_value: Option<f64>,
    max_value: Option<f64>,
    normalized: bool,
) -> DbResult<()> {
    match (min_value, max_value) {
        (None, None) => {}
        (None, Some(_)) | (Some(_), None) => {
            return Err(invalid(format!(
                "both {min_field} and {max_field} must be set together"
            )));
        }
        (Some(min), Some(max)) => {
            if min > max {
                return Err(invalid(format!(
                    "{min_field} must be less than or equal to {max_field}"
                )));
            }
            if normalized && (min < 0.0 || max < 0.0 || min > 1.0 || max > 1.0) {
                return Err(invalid(format!(
                    "{min_field}/{max_field} must be between 0.0 and 1.0"
                )));
            }
        }
    }
    Ok(())
}

fn round_notch_draft(mut draft: NotchDraft) -> NotchDraft {
    draft.value = draft.value.map(round2);
    draft.min_value = draft.min_value.map(round2);
    draft.max_value = draft.max_value.map(round2);
    draft.input_min = draft.input_min.map(round2);
    draft.input_max = draft.input_max.map(round2);
    draft.sim_input_min = draft.sim_input_min.map(round2);
    draft.sim_input_max = draft.sim_input_max.map(round2);
    draft
}

fn validate_notch_draft(draft: &NotchDraft) -> DbResult<()> {
    validate_notch_fields(
        draft.index,
        draft.kind,
        draft.value,
        draft.min_value,
        draft.max_value,
        draft.input_min,
        draft.input_max,
        draft.sim_input_min,
        draft.sim_input_max,
    )
}

fn insert_notch(
    c: &Connection,
    config: EntityId,
    index: i64,
    draft: &NotchDraft,
) -> DbResult<NotchRecord> {
    validate_notch_draft(draft)?;
    let duplicate: bool = c.query_row(
        "SELECT EXISTS(SELECT 1 FROM train_lever_notches WHERE lever_config_id=?1 AND \"index\"=?2)",
        params![config.0, index],
        |r| r.get(0),
    )?;
    if duplicate {
        return Err(taken("notch index has already been taken"));
    }
    let now = timestamp();
    c.execute(
        "INSERT INTO train_lever_notches(lever_config_id,\"index\",type,value,min_value,max_value,description,input_min,input_max,sim_input_min,sim_input_max,inserted_at,updated_at) VALUES(?1,?2,?3,?4,?5,?6,?7,?8,?9,?10,?11,?12,?12)",
        params![config.0, index, draft.kind.as_db(), draft.value, draft.min_value, draft.max_value, draft.description, draft.input_min, draft.input_max, draft.sim_input_min, draft.sim_input_max, now],
    )?;
    get_notch(c, EntityId(c.last_insert_rowid()))?
        .ok_or(StorageError::NotFound)
}

fn notch_index_taken(
    c: &Connection,
    config: EntityId,
    index: i64,
    exclude: EntityId,
) -> DbResult<bool> {
    c.query_row(
        "SELECT EXISTS(SELECT 1 FROM train_lever_notches WHERE lever_config_id=?1 AND \"index\"=?2 AND id<>?3)",
        params![config.0, index, exclude.0],
        |r| r.get(0),
    )
    .map_err(StorageError::from)
}

// ---------------------------------------------------------------------------
// Train operations
// ---------------------------------------------------------------------------

fn list_trains(c: &mut Connection) -> DbResult<Vec<TrainRecord>> {
    all_trains(c)
}

fn get_train(c: &Connection, id: EntityId) -> DbResult<Option<TrainRecord>> {
    get_train_row(c, id)
}

/// Ports `Trenino.Train.get_train_by_identifier/1`: every stored identifier is
/// a prefix matcher over the detected ObjectClass; one matching profile wins,
/// several are ambiguous.
fn get_train_by_identifier(c: &Connection, detected: &str) -> DbResult<IdentifierMatch> {
    let mut matching = Vec::new();
    for train in all_trains(c)? {
        if train
            .identifiers
            .iter()
            .any(|identifier| detected.starts_with(identifier.as_str()))
        {
            matching.push(train);
        }
    }
    Ok(match matching.len() {
        0 => IdentifierMatch::NotFound,
        1 => IdentifierMatch::Unique(matching.remove(0)),
        _ => IdentifierMatch::Ambiguous(matching),
    })
}

fn create_train(
    c: &mut Connection,
    op: trenino_core::OperationId,
    draft: TrainDraft,
) -> DbResult<Mutation<TrainRecord>> {
    let identifiers = normalize_identifiers(draft.identifiers);
    if draft.name.is_empty() {
        return Err(invalid("name can't be blank"));
    }
    domain_tx(c, "trains", op, move |tx| {
        validate_identifier_collection(tx, &identifiers, None)?;
        let now = timestamp();
        tx.execute(
            "INSERT INTO trains(name,description,inserted_at,updated_at) VALUES(?1,?2,?3,?3)",
            params![draft.name, draft.description, now],
        )?;
        let train_id = EntityId(tx.last_insert_rowid());
        for identifier in &identifiers {
            tx.execute(
                "INSERT INTO train_identifiers(train_id,identifier,inserted_at,updated_at) VALUES(?1,?2,?3,?3)",
                params![train_id.0, identifier, now],
            )?;
        }
        get_train_row(tx, train_id)?.ok_or(StorageError::NotFound)
    })
}

fn update_train(
    c: &mut Connection,
    op: trenino_core::OperationId,
    id: EntityId,
    patch: TrainPatch,
) -> DbResult<Mutation<TrainRecord>> {
    domain_tx(c, "trains", op, move |tx| {
        let current = get_train_row(tx, id)?.ok_or(StorageError::NotFound)?;
        let name = patch.name.unwrap_or(current.name);
        if name.is_empty() {
            return Err(invalid("name can't be blank"));
        }
        let description = patch.description.unwrap_or(current.description);
        let now = timestamp();
        if let Some(raw) = patch.identifiers {
            let identifiers = normalize_identifiers(raw);
            // Ecto `on_replace: :delete` — the collection is fully replaced.
            validate_identifier_collection(tx, &identifiers, Some(id))?;
            tx.execute(
                "DELETE FROM train_identifiers WHERE train_id=?1",
                [id.0],
            )?;
            for identifier in &identifiers {
                tx.execute(
                    "INSERT INTO train_identifiers(train_id,identifier,inserted_at,updated_at) VALUES(?1,?2,?3,?3)",
                    params![id.0, identifier, now],
                )?;
            }
        } else if current.identifiers.is_empty() {
            // validate_identifier_collection/1 on an update that touches no
            // identifiers still rejects a profile left without any.
            return Err(invalid("identifiers must have at least one identifier"));
        }
        tx.execute(
            "UPDATE trains SET name=?1,description=?2,updated_at=?3 WHERE id=?4",
            params![name, description, now, id.0],
        )?;
        get_train_row(tx, id)?.ok_or(StorageError::NotFound)
    })
}

fn delete_train(
    c: &mut Connection,
    op: trenino_core::OperationId,
    id: EntityId,
) -> DbResult<Mutation<TrainRecord>> {
    domain_tx(c, "trains", op, move |tx| {
        let record = get_train_row(tx, id)?.ok_or(StorageError::NotFound)?;
        // identifiers/elements/lever configs/notches (and sequences/scripts)
        // cascade through the frozen schema's ON DELETE CASCADE foreign keys.
        tx.execute("DELETE FROM trains WHERE id=?1", [id.0])?;
        Ok(record)
    })
}

// ---------------------------------------------------------------------------
// Element operations
// ---------------------------------------------------------------------------

fn list_elements(c: &Connection, train: EntityId) -> DbResult<Vec<ElementRecord>> {
    elements_for_train(c, train)
}

fn get_element(c: &Connection, id: EntityId) -> DbResult<Option<ElementRecord>> {
    get_element_row(c, id)
}

fn create_element(
    c: &mut Connection,
    op: trenino_core::OperationId,
    train: EntityId,
    draft: ElementDraft,
) -> DbResult<Mutation<ElementRecord>> {
    if draft.name.is_empty() {
        return Err(invalid("name can't be blank"));
    }
    domain_tx(c, "trains", op, move |tx| {
        if !train_exists(tx, train)? {
            return Err(StorageError::ForeignKey {
                detail: "train does not exist".into(),
            });
        }
        let now = timestamp();
        tx.execute(
            "INSERT INTO train_elements(train_id,type,name,inserted_at,updated_at) VALUES(?1,?2,?3,?4,?4)",
            params![train.0, draft.kind.as_db(), draft.name, now],
        )?;
        get_element_row(tx, EntityId(tx.last_insert_rowid()))?.ok_or(StorageError::NotFound)
    })
}

fn delete_element(
    c: &mut Connection,
    op: trenino_core::OperationId,
    id: EntityId,
) -> DbResult<Mutation<ElementRecord>> {
    domain_tx(c, "trains", op, move |tx| {
        let record = get_element_row(tx, id)?.ok_or(StorageError::NotFound)?;
        // lever configs and notches cascade via ON DELETE CASCADE.
        tx.execute("DELETE FROM train_elements WHERE id=?1", [id.0])?;
        Ok(record)
    })
}

// ---------------------------------------------------------------------------
// Lever config operations
// ---------------------------------------------------------------------------

fn create_lever_config(
    c: &mut Connection,
    op: trenino_core::OperationId,
    element: EntityId,
    draft: LeverConfigDraft,
) -> DbResult<Mutation<LeverConfigRecord>> {
    validate_lever_config_fields(
        &draft.min_endpoint,
        &draft.max_endpoint,
        &draft.value_endpoint,
        draft.notch_count_endpoint.as_deref(),
        draft.notch_index_endpoint.as_deref(),
    )?;
    domain_tx(c, "trains", op, move |tx| {
        if get_element_row(tx, element)?.is_none() {
            return Err(StorageError::ForeignKey {
                detail: "element does not exist".into(),
            });
        }
        // LeverConfig's unique_constraint(:element_id)
        if get_lever_config_for_element(tx, element)?.is_some() {
            return Err(taken("element_id has already been taken"));
        }
        let now = timestamp();
        tx.execute(
            "INSERT INTO train_lever_configs(element_id,min_endpoint,max_endpoint,value_endpoint,notch_count_endpoint,notch_index_endpoint,lever_type,inverted,inserted_at,updated_at) VALUES(?1,?2,?3,?4,?5,?6,?7,?8,?9,?9)",
            params![element.0, draft.min_endpoint, draft.max_endpoint, draft.value_endpoint, draft.notch_count_endpoint, draft.notch_index_endpoint, draft.lever_type.map(LeverType::as_db), draft.inverted as i64, now],
        )?;
        get_lever_config_by_id(tx, EntityId(tx.last_insert_rowid()))?
            .ok_or(StorageError::NotFound)
    })
}

fn update_lever_config(
    c: &mut Connection,
    op: trenino_core::OperationId,
    id: EntityId,
    patch: LeverConfigPatch,
) -> DbResult<Mutation<LeverConfigRecord>> {
    domain_tx(c, "trains", op, move |tx| {
        let current = get_lever_config_by_id(tx, id)?.ok_or(StorageError::NotFound)?;
        let min_endpoint = patch.min_endpoint.unwrap_or(current.min_endpoint);
        let max_endpoint = patch.max_endpoint.unwrap_or(current.max_endpoint);
        let value_endpoint = patch.value_endpoint.unwrap_or(current.value_endpoint);
        let notch_count_endpoint =
            patch.notch_count_endpoint.unwrap_or(current.notch_count_endpoint);
        let notch_index_endpoint =
            patch.notch_index_endpoint.unwrap_or(current.notch_index_endpoint);
        let lever_type = patch.lever_type.unwrap_or(current.lever_type);
        let inverted = patch.inverted.unwrap_or(current.inverted);
        let calibrated_at = patch.calibrated_at.unwrap_or(current.calibrated_at);
        validate_lever_config_fields(
            &min_endpoint,
            &max_endpoint,
            &value_endpoint,
            notch_count_endpoint.as_deref(),
            notch_index_endpoint.as_deref(),
        )?;
        tx.execute(
            "UPDATE train_lever_configs SET min_endpoint=?1,max_endpoint=?2,value_endpoint=?3,notch_count_endpoint=?4,notch_index_endpoint=?5,lever_type=?6,inverted=?7,calibrated_at=?8,updated_at=?9 WHERE id=?10",
            params![min_endpoint, max_endpoint, value_endpoint, notch_count_endpoint, notch_index_endpoint, lever_type.map(LeverType::as_db), inverted as i64, calibrated_at, timestamp(), id.0],
        )?;
        get_lever_config_by_id(tx, id)?.ok_or(StorageError::NotFound)
    })
}

/// Ports `create_lever_config_with_analysis/3`: config + analyzer-suggested
/// notches in one commit; the analyzer's input range lands in sim_input_*.
fn create_lever_config_with_analysis(
    c: &mut Connection,
    op: trenino_core::OperationId,
    element: EntityId,
    draft: LeverConfigDraft,
    analysis: &LeverAnalysis,
) -> DbResult<Mutation<LeverConfigRecord>> {
    let mut draft = draft;
    draft.lever_type = Some(analysis.lever_type);
    validate_lever_config_fields(
        &draft.min_endpoint,
        &draft.max_endpoint,
        &draft.value_endpoint,
        draft.notch_count_endpoint.as_deref(),
        draft.notch_index_endpoint.as_deref(),
    )?;
    let suggestions = analysis.suggested_notches.clone();
    domain_tx(c, "trains", op, move |tx| {
        if get_element_row(tx, element)?.is_none() {
            return Err(StorageError::ForeignKey {
                detail: "element does not exist".into(),
            });
        }
        if get_lever_config_for_element(tx, element)?.is_some() {
            return Err(taken("element_id has already been taken"));
        }
        let now = timestamp();
        tx.execute(
            "INSERT INTO train_lever_configs(element_id,min_endpoint,max_endpoint,value_endpoint,notch_count_endpoint,notch_index_endpoint,lever_type,inverted,inserted_at,updated_at) VALUES(?1,?2,?3,?4,?5,?6,?7,?8,?9,?9)",
            params![element.0, draft.min_endpoint, draft.max_endpoint, draft.value_endpoint, draft.notch_count_endpoint, draft.notch_index_endpoint, draft.lever_type.map(LeverType::as_db), draft.inverted as i64, now],
        )?;
        let config_id = EntityId(tx.last_insert_rowid());
        insert_suggested_notches(tx, config_id, &suggestions)?;
        get_lever_config_by_id(tx, config_id)?.ok_or(StorageError::NotFound)
    })
}

/// Ports `update_lever_config_with_analysis/3`: rewrites the config and
/// replaces its notches with the new suggestions in one commit.
fn update_lever_config_with_analysis(
    c: &mut Connection,
    op: trenino_core::OperationId,
    id: EntityId,
    patch: LeverConfigPatch,
    analysis: &LeverAnalysis,
) -> DbResult<Mutation<LeverConfigRecord>> {
    let mut patch = patch;
    patch.lever_type = Some(Some(analysis.lever_type));
    let suggestions = analysis.suggested_notches.clone();
    domain_tx(c, "trains", op, move |tx| {
        let current = get_lever_config_by_id(tx, id)?.ok_or(StorageError::NotFound)?;
        let min_endpoint = patch.min_endpoint.unwrap_or(current.min_endpoint);
        let max_endpoint = patch.max_endpoint.unwrap_or(current.max_endpoint);
        let value_endpoint = patch.value_endpoint.unwrap_or(current.value_endpoint);
        let notch_count_endpoint =
            patch.notch_count_endpoint.unwrap_or(current.notch_count_endpoint);
        let notch_index_endpoint =
            patch.notch_index_endpoint.unwrap_or(current.notch_index_endpoint);
        let inverted = patch.inverted.unwrap_or(current.inverted);
        let calibrated_at = patch.calibrated_at.unwrap_or(current.calibrated_at);
        validate_lever_config_fields(
            &min_endpoint,
            &max_endpoint,
            &value_endpoint,
            notch_count_endpoint.as_deref(),
            notch_index_endpoint.as_deref(),
        )?;
        tx.execute(
            "UPDATE train_lever_configs SET min_endpoint=?1,max_endpoint=?2,value_endpoint=?3,notch_count_endpoint=?4,notch_index_endpoint=?5,lever_type=?6,inverted=?7,calibrated_at=?8,updated_at=?9 WHERE id=?10",
            params![min_endpoint, max_endpoint, value_endpoint, notch_count_endpoint, notch_index_endpoint, analysis.lever_type.as_db(), inverted as i64, calibrated_at, timestamp(), id.0],
        )?;
        tx.execute(
            "DELETE FROM train_lever_notches WHERE lever_config_id=?1",
            [id.0],
        )?;
        insert_suggested_notches(tx, id, &suggestions)?;
        get_lever_config_by_id(tx, id)?.ok_or(StorageError::NotFound)
    })
}

/// Ports `create_notches_from_suggestions/2`.
fn insert_suggested_notches(
    tx: &rusqlite::Transaction<'_>,
    config: EntityId,
    suggestions: &[SuggestedNotch],
) -> DbResult<()> {
    for suggestion in suggestions {
        let draft = NotchDraft {
            index: suggestion.index.unwrap_or(0),
            kind: suggestion.kind,
            value: suggestion.value,
            min_value: suggestion.min_value,
            max_value: suggestion.max_value,
            input_min: None,
            input_max: None,
            sim_input_min: suggestion.input_min,
            sim_input_max: suggestion.input_max,
            description: suggestion.description.clone(),
        };
        insert_notch(tx, config, draft.index, &round_notch_draft(draft))?;
    }
    Ok(())
}

// ---------------------------------------------------------------------------
// Notch operations
// ---------------------------------------------------------------------------

fn create_notch(
    c: &mut Connection,
    op: trenino_core::OperationId,
    config: EntityId,
    draft: NotchDraft,
) -> DbResult<Mutation<NotchRecord>> {
    let draft = round_notch_draft(draft);
    domain_tx(c, "trains", op, move |tx| {
        if get_lever_config_by_id(tx, config)?.is_none() {
            return Err(StorageError::ForeignKey {
                detail: "lever config does not exist".into(),
            });
        }
        insert_notch(tx, config, draft.index, &draft)
    })
}

fn update_notch(
    c: &mut Connection,
    op: trenino_core::OperationId,
    id: EntityId,
    patch: NotchPatch,
) -> DbResult<Mutation<NotchRecord>> {
    domain_tx(c, "trains", op, move |tx| {
        let current = get_notch(tx, id)?.ok_or(StorageError::NotFound)?;
        let index = patch.index.unwrap_or(current.index);
        let kind = patch.kind.unwrap_or(current.kind);
        let value = patch.value.unwrap_or(current.value).map(round2);
        let min_value = patch.min_value.unwrap_or(current.min_value).map(round2);
        let max_value = patch.max_value.unwrap_or(current.max_value).map(round2);
        let input_min = patch.input_min.unwrap_or(current.input_min).map(round2);
        let input_max = patch.input_max.unwrap_or(current.input_max).map(round2);
        let sim_input_min = patch.sim_input_min.unwrap_or(current.sim_input_min).map(round2);
        let sim_input_max = patch.sim_input_max.unwrap_or(current.sim_input_max).map(round2);
        validate_notch_fields(
            index, kind, value, min_value, max_value, input_min, input_max, sim_input_min,
            sim_input_max,
        )?;
        if notch_index_taken(tx, current.lever_config_id, index, id)? {
            return Err(taken("notch index has already been taken"));
        }
        tx.execute(
            "UPDATE train_lever_notches SET \"index\"=?1,type=?2,value=?3,min_value=?4,max_value=?5,input_min=?6,input_max=?7,sim_input_min=?8,sim_input_max=?9,updated_at=?10 WHERE id=?11",
            params![index, kind.as_db(), value, min_value, max_value, input_min, input_max, sim_input_min, sim_input_max, timestamp(), id.0],
        )?;
        get_notch(tx, id)?.ok_or(StorageError::NotFound)
    })
}

fn update_notch_description(
    c: &mut Connection,
    op: trenino_core::OperationId,
    id: EntityId,
    description: Option<String>,
) -> DbResult<Mutation<NotchRecord>> {
    domain_tx(c, "trains", op, move |tx| {
        if get_notch(tx, id)?.is_none() {
            return Err(StorageError::NotFound);
        }
        tx.execute(
            "UPDATE train_lever_notches SET description=?1,updated_at=?2 WHERE id=?3",
            params![description, timestamp(), id.0],
        )?;
        get_notch(tx, id)?.ok_or(StorageError::NotFound)
    })
}

fn delete_notch(
    c: &mut Connection,
    op: trenino_core::OperationId,
    id: EntityId,
) -> DbResult<Mutation<NotchRecord>> {
    domain_tx(c, "trains", op, move |tx| {
        let record = get_notch(tx, id)?.ok_or(StorageError::NotFound)?;
        tx.execute("DELETE FROM train_lever_notches WHERE id=?1", [id.0])?;
        Ok(record)
    })
}

/// Shared body of `save_calibration/2` and `save_notches/2`: replace all
/// notches in one commit, assigning index by list position. Any invalid notch
/// rolls the whole replacement back.
fn replace_notches_tx(
    tx: &rusqlite::Transaction<'_>,
    config: EntityId,
    notches: &[NotchDraft],
) -> DbResult<()> {
    tx.execute(
        "DELETE FROM train_lever_notches WHERE lever_config_id=?1",
        [config.0],
    )?;
    for (position, draft) in notches.iter().enumerate() {
        let draft = round_notch_draft(draft.clone());
        insert_notch(tx, config, position as i64, &draft)?;
    }
    Ok(())
}

fn save_lever_calibration(
    c: &mut Connection,
    op: trenino_core::OperationId,
    config: EntityId,
    notches: Vec<NotchDraft>,
) -> DbResult<Mutation<LeverConfigRecord>> {
    domain_tx(c, "trains", op, move |tx| {
        if get_lever_config_by_id(tx, config)?.is_none() {
            return Err(StorageError::NotFound);
        }
        replace_notches_tx(tx, config, &notches)?;
        tx.execute(
            "UPDATE train_lever_configs SET calibrated_at=?1,updated_at=?1 WHERE id=?2",
            params![timestamp(), config.0],
        )?;
        get_lever_config_by_id(tx, config)?.ok_or(StorageError::NotFound)
    })
}

fn save_notches(
    c: &mut Connection,
    op: trenino_core::OperationId,
    config: EntityId,
    notches: Vec<NotchDraft>,
) -> DbResult<Mutation<LeverConfigRecord>> {
    domain_tx(c, "trains", op, move |tx| {
        if get_lever_config_by_id(tx, config)?.is_none() {
            return Err(StorageError::NotFound);
        }
        replace_notches_tx(tx, config, &notches)?;
        get_lever_config_by_id(tx, config)?.ok_or(StorageError::NotFound)
    })
}

/// Ports `update_notch_input_ranges/3`: batch-updates notch input ranges (and
/// optionally the lever's inverted flag) in one commit; an unknown notch id
/// rolls everything back.
fn update_notch_input_ranges(
    c: &mut Connection,
    op: trenino_core::OperationId,
    config: EntityId,
    updates: Vec<NotchInputRange>,
    inverted: Option<bool>,
) -> DbResult<Mutation<LeverConfigRecord>> {
    domain_tx(c, "trains", op, move |tx| {
        get_lever_config_by_id(tx, config)?.ok_or(StorageError::NotFound)?;
        for update in &updates {
            get_notch(tx, update.notch_id)?
                .ok_or_else(|| invalid(format!("notch {} not found", update.notch_id.0)))?;
            let input_min = round2(update.input_min);
            let input_max = round2(update.input_max);
            validate_range_pair("input_min", "input_max", Some(input_min), Some(input_max), true)?;
            tx.execute(
                "UPDATE train_lever_notches SET input_min=?1,input_max=?2,updated_at=?3 WHERE id=?4",
                params![input_min, input_max, timestamp(), update.notch_id.0],
            )?;
        }
        if let Some(inverted) = inverted {
            tx.execute(
                "UPDATE train_lever_configs SET inverted=?1,updated_at=?2 WHERE id=?3",
                params![inverted as i64, timestamp(), config.0],
            )?;
        }
        get_lever_config_by_id(tx, config)?.ok_or(StorageError::NotFound)
    })
}

/// Ports `auto_distribute_input_ranges/1`: divides 0.0-1.0 evenly across the
/// notches (sorted by index). An empty notch list is a read-only success — no
/// revision is consumed, matching the Elixir path that skips the transaction.
fn auto_distribute_input_ranges(
    c: &mut Connection,
    op: trenino_core::OperationId,
    config: EntityId,
) -> DbResult<Mutation<LeverConfigRecord>> {
    // NOTE: the oracle passes lever_config_id into a lookup keyed by
    // element_id (a latent quirk); we resolve by primary key, which is what
    // the documented behavior describes.
    let current = {
        let tx = c.transaction()?;
        if validate_runtime_metadata(&tx)?.is_none() {
            return Err(StorageError::InvalidLegacyData {
                detail: "runtime metadata has not been initialized".into(),
            });
        }
        let record = get_lever_config_by_id(&tx, config)?.ok_or(StorageError::NotFound)?;
        tx.commit()?;
        record
    };
    if current.notches.is_empty() {
        let epoch = read_u64(c, "__runtime.epoch", 0)?;
        let revision = read_u64(c, &metadata_key("trains")?, 0)?;
        return Ok(Mutation {
            record: current,
            receipt: super::MutationReceipt {
                operation_id: op,
                outcome: super::MutationOutcome::Committed,
                metadata: RuntimeMetadata { epoch, revision },
            },
        });
    }
    let mut sorted: Vec<(i64, EntityId)> = current
        .notches
        .iter()
        .map(|notch| (notch.index, notch.id))
        .collect();
    sorted.sort_by_key(|(index, _)| *index);
    let count = sorted.len() as f64;
    let step = 1.0 / count;
    domain_tx(c, "trains", op, move |tx| {
        for &(index, notch_id) in &sorted {
            let input_min = round2(index as f64 * step);
            let input_max = round2((index + 1) as f64 * step);
            tx.execute(
                "UPDATE train_lever_notches SET input_min=?1,input_max=?2,updated_at=?3 WHERE id=?4",
                params![input_min, input_max, timestamp(), notch_id.0],
            )?;
        }
        get_lever_config_by_id(tx, config)?.ok_or(StorageError::NotFound)
    })
}

/// Ports `validate_notch_ranges/1` (read-only): checks the notch input ranges
/// cover 0.0-1.0 with no gaps larger than the 0.001 epsilon.
fn validate_notch_ranges(
    c: &Connection,
    config: EntityId,
) -> DbResult<Option<RangesValidation>> {
    let Some(record) = get_lever_config_by_id(c, config)? else {
        return Ok(None);
    };
    let mut notches = record.notches;
    notches.sort_by_key(|notch| notch.index);
    let mut ranges: Vec<(f64, f64)> = notches
        .iter()
        .filter(|notch| notch.input_min.is_some() && notch.input_max.is_some())
        .map(|notch| (notch.input_min.unwrap(), notch.input_max.unwrap()))
        .collect();
    ranges.sort_by(|a, b| a.0.partial_cmp(&b.0).unwrap());
    Ok(Some(match find_gaps(&ranges, 0.0, 1.0) {
        gaps if gaps.is_empty() => RangesValidation::Valid,
        gaps => RangesValidation::Gaps(gaps),
    }))
}

/// Ports `find_gaps/3` including the 0.001 epsilon.
fn find_gaps(ranges: &[(f64, f64)], mut current: f64, end: f64) -> Vec<(f64, f64)> {
    let mut gaps = Vec::new();
    for &(range_start, range_end) in ranges {
        if range_start > current + 0.001 {
            gaps.push((current, range_start));
        }
        current = current.max(range_end);
    }
    if current < end {
        gaps.push((current, end));
    }
    gaps
}

// ---------------------------------------------------------------------------
// Database wrappers (bounded worker dispatch, mirroring hardware_call)
// ---------------------------------------------------------------------------

impl Database {
    fn trains_call<T: Send + 'static>(
        &self,
        operation: &'static str,
        f: impl FnOnce(&mut Connection) -> DbResult<T> + Send + 'static,
    ) -> DbResult<T> {
        let (reply_tx, reply_rx) = std::sync::mpsc::channel();
        let job = Box::new(move |connection: &mut Connection, mode: SchemaMode| {
            let result = if mode == SchemaMode::Full {
                f(connection)
            } else {
                Err(StorageError::UnsupportedOperation { operation })
            };
            let _ = reply_tx.send(result);
        });
        self.worker
            .tx
            .lock()
            .map_err(|_| StorageError::WorkerStopped)?
            .as_ref()
            .ok_or(StorageError::WorkerStopped)?
            .send(Request::Hardware(job))
            .map_err(|_| StorageError::WorkerStopped)?;
        reply_rx.recv().map_err(|_| StorageError::WorkerStopped)?
    }

    pub fn list_trains(&self) -> DbResult<Vec<TrainRecord>> {
        self.trains_call("list_trains", list_trains)
    }

    pub fn get_train(&self, id: EntityId) -> DbResult<Option<TrainRecord>> {
        self.trains_call("get_train", move |c| get_train(c, id))
    }

    pub fn get_train_by_identifier(&self, detected: String) -> DbResult<IdentifierMatch> {
        self.trains_call("get_train_by_identifier", move |c| {
            get_train_by_identifier(c, &detected)
        })
    }

    pub fn create_train(
        &self,
        operation_id: OperationId,
        draft: TrainDraft,
    ) -> DbResult<Mutation<TrainRecord>> {
        self.trains_call("create_train", move |c| {
            create_train(c, operation_id, draft)
        })
    }

    pub fn update_train(
        &self,
        operation_id: OperationId,
        id: EntityId,
        patch: TrainPatch,
    ) -> DbResult<Mutation<TrainRecord>> {
        self.trains_call("update_train", move |c| {
            update_train(c, operation_id, id, patch)
        })
    }

    pub fn delete_train(
        &self,
        operation_id: OperationId,
        id: EntityId,
    ) -> DbResult<Mutation<TrainRecord>> {
        self.trains_call("delete_train", move |c| delete_train(c, operation_id, id))
    }

    pub fn list_train_elements(&self, train_id: EntityId) -> DbResult<Vec<ElementRecord>> {
        self.trains_call("list_train_elements", move |c| list_elements(c, train_id))
    }

    pub fn get_train_element(&self, id: EntityId) -> DbResult<Option<ElementRecord>> {
        self.trains_call("get_train_element", move |c| get_element(c, id))
    }

    pub fn create_train_element(
        &self,
        operation_id: OperationId,
        train_id: EntityId,
        draft: ElementDraft,
    ) -> DbResult<Mutation<ElementRecord>> {
        self.trains_call("create_train_element", move |c| {
            create_element(c, operation_id, train_id, draft)
        })
    }

    pub fn delete_train_element(
        &self,
        operation_id: OperationId,
        id: EntityId,
    ) -> DbResult<Mutation<ElementRecord>> {
        self.trains_call("delete_train_element", move |c| {
            delete_element(c, operation_id, id)
        })
    }

    /// By element id, like `Trenino.Train.get_lever_config/1`.
    pub fn get_lever_config_for_element(
        &self,
        element_id: EntityId,
    ) -> DbResult<Option<LeverConfigRecord>> {
        self.trains_call("get_lever_config", move |c| {
            get_lever_config_for_element(c, element_id)
        })
    }

    pub fn create_lever_config(
        &self,
        operation_id: OperationId,
        element_id: EntityId,
        draft: LeverConfigDraft,
    ) -> DbResult<Mutation<LeverConfigRecord>> {
        self.trains_call("create_lever_config", move |c| {
            create_lever_config(c, operation_id, element_id, draft)
        })
    }

    pub fn update_lever_config(
        &self,
        operation_id: OperationId,
        id: EntityId,
        patch: LeverConfigPatch,
    ) -> DbResult<Mutation<LeverConfigRecord>> {
        self.trains_call("update_lever_config", move |c| {
            update_lever_config(c, operation_id, id, patch)
        })
    }

    pub fn create_lever_config_with_analysis(
        &self,
        operation_id: OperationId,
        element_id: EntityId,
        draft: LeverConfigDraft,
        analysis: LeverAnalysis,
    ) -> DbResult<Mutation<LeverConfigRecord>> {
        self.trains_call("create_lever_config_with_analysis", move |c| {
            create_lever_config_with_analysis(c, operation_id, element_id, draft, &analysis)
        })
    }

    pub fn update_lever_config_with_analysis(
        &self,
        operation_id: OperationId,
        id: EntityId,
        patch: LeverConfigPatch,
        analysis: LeverAnalysis,
    ) -> DbResult<Mutation<LeverConfigRecord>> {
        self.trains_call("update_lever_config_with_analysis", move |c| {
            update_lever_config_with_analysis(c, operation_id, id, patch, &analysis)
        })
    }

    pub fn create_notch(
        &self,
        operation_id: OperationId,
        lever_config_id: EntityId,
        draft: NotchDraft,
    ) -> DbResult<Mutation<NotchRecord>> {
        self.trains_call("create_notch", move |c| {
            create_notch(c, operation_id, lever_config_id, draft)
        })
    }

    pub fn update_notch(
        &self,
        operation_id: OperationId,
        id: EntityId,
        patch: NotchPatch,
    ) -> DbResult<Mutation<NotchRecord>> {
        self.trains_call("update_notch", move |c| {
            update_notch(c, operation_id, id, patch)
        })
    }

    pub fn update_notch_description(
        &self,
        operation_id: OperationId,
        id: EntityId,
        description: Option<String>,
    ) -> DbResult<Mutation<NotchRecord>> {
        self.trains_call("update_notch_description", move |c| {
            update_notch_description(c, operation_id, id, description)
        })
    }

    pub fn delete_notch(
        &self,
        operation_id: OperationId,
        id: EntityId,
    ) -> DbResult<Mutation<NotchRecord>> {
        self.trains_call("delete_notch", move |c| delete_notch(c, operation_id, id))
    }

    pub fn save_lever_calibration(
        &self,
        operation_id: OperationId,
        lever_config_id: EntityId,
        notches: Vec<NotchDraft>,
    ) -> DbResult<Mutation<LeverConfigRecord>> {
        self.trains_call("save_calibration", move |c| {
            save_lever_calibration(c, operation_id, lever_config_id, notches)
        })
    }

    pub fn save_notches(
        &self,
        operation_id: OperationId,
        lever_config_id: EntityId,
        notches: Vec<NotchDraft>,
    ) -> DbResult<Mutation<LeverConfigRecord>> {
        self.trains_call("save_notches", move |c| {
            save_notches(c, operation_id, lever_config_id, notches)
        })
    }

    pub fn update_notch_input_ranges(
        &self,
        operation_id: OperationId,
        lever_config_id: EntityId,
        updates: Vec<NotchInputRange>,
        inverted: Option<bool>,
    ) -> DbResult<Mutation<LeverConfigRecord>> {
        self.trains_call("update_notch_input_ranges", move |c| {
            update_notch_input_ranges(c, operation_id, lever_config_id, updates, inverted)
        })
    }

    pub fn auto_distribute_input_ranges(
        &self,
        operation_id: OperationId,
        lever_config_id: EntityId,
    ) -> DbResult<Mutation<LeverConfigRecord>> {
        self.trains_call("auto_distribute_input_ranges", move |c| {
            auto_distribute_input_ranges(c, operation_id, lever_config_id)
        })
    }

    /// `Ok(None)` mirrors `{:error, :not_found}`.
    pub fn validate_notch_ranges(
        &self,
        lever_config_id: EntityId,
    ) -> DbResult<Option<RangesValidation>> {
        self.trains_call("validate_notch_ranges", move |c| {
            validate_notch_ranges(c, lever_config_id)
        })
    }
}
