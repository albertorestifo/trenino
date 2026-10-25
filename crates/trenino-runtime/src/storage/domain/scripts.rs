//! Typed script persistence on the database's existing bounded worker.
//! Mirrors `Trenino.Train`'s script functions: names are unique per train and
//! 1..=100 characters, `code` is required, `enabled` defaults to true, and
//! triggers are stored as a JSON-encoded array of endpoint path strings in the
//! `scripts.triggers` column (exactly what Jason produces for Elixir's
//! `TriggersType`). Every mutation commits exactly one "scripts" topic
//! revision.
use super::domain_tx;
use rusqlite::{params, Connection as SqliteConnection, OptionalExtension};
use serde::{Deserialize, Serialize};
use trenino_core::{EntityId, OperationId};

use crate::storage::{Database, DbResult, Mutation, StorageError};

/// A script row. `triggers` is the decoded list of simulator endpoint paths.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ScriptRecord {
    pub id: EntityId,
    pub train_id: EntityId,
    pub name: String,
    pub enabled: bool,
    pub code: String,
    pub triggers: Vec<String>,
}

/// Typed serde model for the `scripts.triggers` column: a JSON array of
/// endpoint path strings, wire-compatible with Elixir's
/// `Trenino.Train.Script.TriggersType` (Jason-encoded `["a","b"]`).
#[derive(Clone, Debug, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct Triggers(pub Vec<String>);

impl Triggers {
    /// Encodes exactly like Jason: a compact JSON array of strings.
    pub fn encode(&self) -> DbResult<String> {
        serde_json::to_string(&self).map_err(|error| StorageError::Constraint {
            detail: format!("failed to encode script triggers: {error}"),
        })
    }

    /// Decodes the stored JSON; anything but an array of strings is rejected
    /// (Elixir's `TriggersType.load/1` degrades to `[]`, but only well-formed
    /// rows written through this API can exist in the full-v2 schema).
    pub fn decode(raw: &str) -> DbResult<Self> {
        let decoded: Self =
            serde_json::from_str(raw).map_err(|error| StorageError::InvalidLegacyData {
                detail: format!("invalid script triggers JSON: {error}"),
            })?;
        Ok(decoded)
    }
}

/// Payload for [`Database::create_script`]. `enabled` defaults to `true`;
/// name and code are required, mirroring the Ecto changeset.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ScriptDraft {
    pub name: String,
    pub enabled: bool,
    pub code: String,
    pub triggers: Vec<String>,
}

/// Partial update for [`Database::update_script`]; `None` keeps the field.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct ScriptPatch {
    pub name: Option<String>,
    pub enabled: Option<bool>,
    pub code: Option<String>,
    pub triggers: Option<Vec<String>>,
}

impl Database {
    /// Original UTC timestamps for external JSON API compatibility.
    pub fn script_timestamps(&self, id: EntityId) -> DbResult<Option<(String, String)>> {
        self.domain_call("script_timestamps", move |c| {
            c.query_row(
                "SELECT inserted_at,updated_at FROM scripts WHERE id=?1",
                [id.0],
                |row| Ok((row.get(0)?, row.get(1)?)),
            )
            .optional()
            .map_err(StorageError::from)
        })
    }

    pub fn get_script(&self, id: EntityId) -> DbResult<Option<ScriptRecord>> {
        self.domain_call("get_script", move |c| get_script(c, id))
    }

    /// Lists a train's scripts ordered by name (Elixir `list_scripts/1`).
    pub fn list_scripts(&self, train_id: EntityId) -> DbResult<Vec<ScriptRecord>> {
        self.domain_call("list_scripts", move |c| list_scripts(c, train_id, None))
    }

    /// Lists only enabled scripts (Elixir `list_enabled_scripts/1`).
    pub fn list_enabled_scripts(&self, train_id: EntityId) -> DbResult<Vec<ScriptRecord>> {
        self.domain_call("list_enabled_scripts", move |c| {
            list_scripts(c, train_id, Some(true))
        })
    }

    pub fn create_script(
        &self,
        operation_id: OperationId,
        train_id: EntityId,
        draft: ScriptDraft,
    ) -> DbResult<Mutation<ScriptRecord>> {
        self.domain_call("create_script", move |c| {
            create_script(c, operation_id, train_id, draft)
        })
    }

    pub fn update_script(
        &self,
        operation_id: OperationId,
        id: EntityId,
        patch: ScriptPatch,
    ) -> DbResult<Mutation<ScriptRecord>> {
        self.domain_call("update_script", move |c| {
            update_script(c, operation_id, id, patch)
        })
    }

    pub fn delete_script(
        &self,
        operation_id: OperationId,
        id: EntityId,
    ) -> DbResult<Mutation<ScriptRecord>> {
        self.domain_call("delete_script", move |c| delete_script(c, operation_id, id))
    }
}

fn invalid(detail: String) -> StorageError {
    StorageError::Constraint { detail }
}

fn validate_name(name: &str) -> DbResult<()> {
    let trimmed = name.trim();
    if trimmed.is_empty() || name.chars().count() > 100 {
        return Err(invalid("script name must be 1 to 100 characters".into()));
    }
    Ok(())
}

fn validate_triggers(_triggers: &[String]) -> DbResult<()> {
    // `Script.changeset/2` only requires every trigger to be a binary
    // (script.ex:62-77) — empty or blank strings are accepted, and the Rust
    // type system already guarantees the string part. Kept as a hook so the
    // Ecto validation point stays explicit.
    Ok(())
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

fn script_row(row: &rusqlite::Row<'_>) -> rusqlite::Result<ScriptRecord> {
    let raw_triggers: String = row.get(5)?;
    let triggers = serde_json::from_str::<Triggers>(&raw_triggers)
        .map(|t| t.0)
        .unwrap_or_default();
    Ok(ScriptRecord {
        id: EntityId(row.get(0)?),
        train_id: EntityId(row.get(1)?),
        name: row.get(2)?,
        enabled: row.get::<_, i64>(3)? != 0,
        code: row.get(4)?,
        triggers,
    })
}

fn get_script(c: &SqliteConnection, id: EntityId) -> DbResult<Option<ScriptRecord>> {
    c.query_row(
        "SELECT id,train_id,name,enabled,code,triggers FROM scripts WHERE id=?1",
        [id.0],
        script_row,
    )
    .optional()
    .map_err(StorageError::from)
}

fn list_scripts(
    c: &SqliteConnection,
    train_id: EntityId,
    enabled: Option<bool>,
) -> DbResult<Vec<ScriptRecord>> {
    let mut statement = c.prepare(
        "SELECT id,train_id,name,enabled,code,triggers FROM scripts WHERE train_id=?1 AND (?2 IS NULL OR enabled=?2) ORDER BY name, id",
    )?;
    let rows = statement.query_map(params![train_id.0, enabled.map(|e| e as i64)], script_row)?;
    let mut records = Vec::new();
    for row in rows {
        records.push(row?);
    }
    Ok(records)
}

fn create_script(
    c: &mut crate::storage::Connection,
    op: OperationId,
    train_id: EntityId,
    draft: ScriptDraft,
) -> DbResult<Mutation<ScriptRecord>> {
    validate_name(&draft.name)?;
    if draft.code.trim().is_empty() {
        return Err(invalid("script code is required".into()));
    }
    validate_triggers(&draft.triggers)?;
    let triggers = Triggers(draft.triggers.clone()).encode()?;
    domain_tx(c, "scripts", op, move |tx| {
        tx.execute(
            "INSERT INTO scripts(train_id,name,enabled,code,triggers,inserted_at,updated_at) VALUES(?1,?2,?3,?4,?5,?6,?6)",
            params![
                train_id.0,
                draft.name,
                draft.enabled as i64,
                draft.code,
                triggers,
                timestamp()
            ],
        )?;
        get_script(tx, EntityId(tx.last_insert_rowid()))?.ok_or(StorageError::NotFound)
    })
}

fn update_script(
    c: &mut crate::storage::Connection,
    op: OperationId,
    id: EntityId,
    patch: ScriptPatch,
) -> DbResult<Mutation<ScriptRecord>> {
    if let Some(name) = patch.name.as_deref() {
        validate_name(name)?;
    }
    if let Some(code) = patch.code.as_deref() {
        if code.trim().is_empty() {
            return Err(invalid("script code is required".into()));
        }
    }
    if let Some(triggers) = patch.triggers.as_deref() {
        validate_triggers(triggers)?;
    }
    let triggers = match patch.triggers.as_ref() {
        Some(triggers) => Some(Triggers(triggers.clone()).encode()?),
        None => None,
    };
    domain_tx(c, "scripts", op, move |tx| {
        let current = get_script(tx, id)?.ok_or(StorageError::NotFound)?;
        let name = patch.name.unwrap_or(current.name);
        let enabled = patch.enabled.unwrap_or(current.enabled);
        let code = patch.code.unwrap_or(current.code);
        let triggers = match triggers {
            Some(encoded) => encoded,
            None => Triggers(current.triggers).encode()?,
        };
        tx.execute(
            "UPDATE scripts SET name=?1,enabled=?2,code=?3,triggers=?4,updated_at=?5 WHERE id=?6",
            params![name, enabled as i64, code, triggers, timestamp(), id.0],
        )?;
        get_script(tx, id)?.ok_or(StorageError::NotFound)
    })
}

fn delete_script(
    c: &mut crate::storage::Connection,
    op: OperationId,
    id: EntityId,
) -> DbResult<Mutation<ScriptRecord>> {
    domain_tx(c, "scripts", op, move |tx| {
        let record = get_script(tx, id)?.ok_or(StorageError::NotFound)?;
        // Display bindings referencing this script are set to NULL by the
        // schema's ON DELETE SET NULL; nothing else references scripts.
        tx.execute("DELETE FROM scripts WHERE id=?1", [id.0])?;
        Ok(record)
    })
}
