//! Typed sequence persistence (sequences + ordered sequence commands) on the
//! database's existing bounded worker. Mirrors `Trenino.Train`'s sequence
//! functions: names are unique per train and 1..=100 characters, command
//! values are rounded to two decimal places, `set_sequence_commands` is an
//! atomic full replace with 0-indexed auto-assigned positions, and deleting a
//! sequence (or a train) cascades to its commands via the schema's foreign
//! keys. Every mutation commits exactly one "trains" topic revision.
use super::domain_tx;
use rusqlite::{params, Connection as SqliteConnection, OptionalExtension};

use trenino_core::{EntityId, OperationId};

use crate::storage::{Database, DbResult, Mutation, StorageError};

/// A sequence row; commands are loaded separately via
/// [`Database::sequence_commands`].
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct SequenceRecord {
    pub id: EntityId,
    pub train_id: EntityId,
    pub name: String,
}

/// One ordered command within a sequence. `delay_ms` is the wait after this
/// command before the next one.
#[derive(Clone, Debug, PartialEq)]
pub struct SequenceCommandRecord {
    pub id: EntityId,
    pub sequence_id: EntityId,
    pub position: i64,
    pub endpoint: String,
    /// Rounded to two decimal places on write (project float precision rule).
    pub value: f64,
    pub delay_ms: i64,
}

/// Payload for creating or replacing sequence commands. Positions are always
/// assigned by the storage layer, never by callers.
#[derive(Clone, Debug, PartialEq)]
pub struct SequenceCommandDraft {
    pub endpoint: String,
    pub value: f64,
    pub delay_ms: i64,
}

/// Payload for [`Database::create_sequence`].
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct SequenceDraft {
    pub name: String,
}

/// Partial update for [`Database::update_sequence`]; `None` keeps the field.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct SequencePatch {
    pub name: Option<String>,
}

impl Database {
    pub fn get_sequence(&self, id: EntityId) -> DbResult<Option<SequenceRecord>> {
        self.domain_call("get_sequence", move |c| get_sequence(c, id))
    }

    /// Lists a train's sequences ordered by name (Elixir `list_sequences/1`).
    pub fn list_sequences(&self, train_id: EntityId) -> DbResult<Vec<SequenceRecord>> {
        self.domain_call("list_sequences", move |c| list_sequences(c, train_id))
    }

    /// Lists a sequence's commands ordered by position (the `preload_order`
    /// used by `get_sequence/1`).
    pub fn sequence_commands(&self, sequence_id: EntityId) -> DbResult<Vec<SequenceCommandRecord>> {
        self.domain_call("sequence_commands", move |c| {
            sequence_commands(c, sequence_id)
        })
    }

    pub fn create_sequence(
        &self,
        operation_id: OperationId,
        train_id: EntityId,
        draft: SequenceDraft,
    ) -> DbResult<Mutation<SequenceRecord>> {
        self.domain_call("create_sequence", move |c| {
            create_sequence(c, operation_id, train_id, draft)
        })
    }

    pub fn update_sequence(
        &self,
        operation_id: OperationId,
        id: EntityId,
        patch: SequencePatch,
    ) -> DbResult<Mutation<SequenceRecord>> {
        self.domain_call("update_sequence", move |c| {
            update_sequence(c, operation_id, id, patch)
        })
    }

    /// Deletes the sequence; commands cascade via the schema's foreign key.
    pub fn delete_sequence(
        &self,
        operation_id: OperationId,
        id: EntityId,
    ) -> DbResult<Mutation<SequenceRecord>> {
        self.domain_call("delete_sequence", move |c| {
            delete_sequence(c, operation_id, id)
        })
    }

    /// Atomic full replace of a sequence's commands with 0-indexed positions
    /// assigned in list order (Elixir `set_sequence_commands/2`).
    pub fn set_sequence_commands(
        &self,
        operation_id: OperationId,
        sequence_id: EntityId,
        drafts: Vec<SequenceCommandDraft>,
    ) -> DbResult<Mutation<Vec<SequenceCommandRecord>>> {
        self.domain_call("set_sequence_commands", move |c| {
            set_sequence_commands(c, operation_id, sequence_id, drafts)
        })
    }

    /// Appends one command after the current highest position (Elixir
    /// `add_sequence_command/2`).
    pub fn add_sequence_command(
        &self,
        operation_id: OperationId,
        sequence_id: EntityId,
        draft: SequenceCommandDraft,
    ) -> DbResult<Mutation<SequenceCommandRecord>> {
        self.domain_call("add_sequence_command", move |c| {
            add_sequence_command(c, operation_id, sequence_id, draft)
        })
    }

    /// Sum of the sequence's command delays in milliseconds — Elixir
    /// `Sequence.total_duration/1` (sequence.ex:60-65).
    pub fn sequence_total_duration(&self, sequence_id: EntityId) -> DbResult<i64> {
        self.domain_call("sequence_total_duration", move |c| {
            Ok(total_duration(&sequence_commands(c, sequence_id)?))
        })
    }

    pub fn delete_sequence_command(
        &self,
        operation_id: OperationId,
        command_id: EntityId,
    ) -> DbResult<Mutation<SequenceCommandRecord>> {
        self.domain_call("delete_sequence_command", move |c| {
            delete_sequence_command(c, operation_id, command_id)
        })
    }
}

/// Elixir `Sequence.total_duration/1` (sequence.ex:60-65): the sum of every
/// command's delay in milliseconds (execution time excluded).
pub fn total_duration(commands: &[SequenceCommandRecord]) -> i64 {
    commands.iter().map(|command| command.delay_ms).sum()
}

fn invalid(detail: String) -> StorageError {
    StorageError::Constraint { detail }
}

fn validate_name(name: &str) -> DbResult<()> {
    let trimmed = name.trim();
    if trimmed.is_empty() || name.chars().count() > 100 {
        return Err(invalid("sequence name must be 1 to 100 characters".into()));
    }
    Ok(())
}

fn validate_command(draft: &SequenceCommandDraft) -> DbResult<()> {
    if draft.endpoint.trim().is_empty() {
        return Err(invalid("sequence command endpoint is required".into()));
    }
    if draft.value.is_nan() || draft.value.is_infinite() {
        return Err(invalid(
            "sequence command value must be a finite number".into(),
        ));
    }
    if !(0..=60_000).contains(&draft.delay_ms) {
        return Err(invalid(
            "sequence command delay_ms must be between 0 and 60000".into(),
        ));
    }
    Ok(())
}

fn rounded(value: f64) -> f64 {
    // Float.round/2 semantics: ties cross toward even significant digits
    // (0.015 -> 0.01), unlike naive (v*100).round()/100 (0.02).
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

fn sequence_row(row: &rusqlite::Row<'_>) -> rusqlite::Result<SequenceRecord> {
    Ok(SequenceRecord {
        id: EntityId(row.get(0)?),
        train_id: EntityId(row.get(1)?),
        name: row.get(2)?,
    })
}

fn get_sequence(c: &SqliteConnection, id: EntityId) -> DbResult<Option<SequenceRecord>> {
    c.query_row(
        "SELECT id,train_id,name FROM sequences WHERE id=?1",
        [id.0],
        sequence_row,
    )
    .optional()
    .map_err(StorageError::from)
}

fn list_sequences(c: &SqliteConnection, train_id: EntityId) -> DbResult<Vec<SequenceRecord>> {
    let mut statement =
        c.prepare("SELECT id,train_id,name FROM sequences WHERE train_id=?1 ORDER BY name, id")?;
    let rows = statement.query_map([train_id.0], sequence_row)?;
    let mut records = Vec::new();
    for row in rows {
        records.push(row?);
    }
    Ok(records)
}

fn command_row(row: &rusqlite::Row<'_>) -> rusqlite::Result<SequenceCommandRecord> {
    Ok(SequenceCommandRecord {
        id: EntityId(row.get(0)?),
        sequence_id: EntityId(row.get(1)?),
        position: row.get(2)?,
        endpoint: row.get(3)?,
        value: row.get(4)?,
        delay_ms: row.get(5)?,
    })
}

fn sequence_commands(
    c: &SqliteConnection,
    sequence_id: EntityId,
) -> DbResult<Vec<SequenceCommandRecord>> {
    let mut statement = c.prepare(
        "SELECT id,sequence_id,position,endpoint,value,delay_ms FROM sequence_commands WHERE sequence_id=?1 ORDER BY position",
    )?;
    let rows = statement.query_map([sequence_id.0], command_row)?;
    let mut records = Vec::new();
    for row in rows {
        records.push(row?);
    }
    Ok(records)
}

fn get_command(c: &SqliteConnection, id: EntityId) -> DbResult<Option<SequenceCommandRecord>> {
    c.query_row(
        "SELECT id,sequence_id,position,endpoint,value,delay_ms FROM sequence_commands WHERE id=?1",
        [id.0],
        command_row,
    )
    .optional()
    .map_err(StorageError::from)
}

fn insert_command(
    tx: &rusqlite::Transaction<'_>,
    sequence_id: EntityId,
    position: i64,
    draft: &SequenceCommandDraft,
) -> DbResult<SequenceCommandRecord> {
    let now = timestamp();
    tx.execute(
        "INSERT INTO sequence_commands(sequence_id,position,endpoint,value,delay_ms,inserted_at,updated_at) VALUES(?1,?2,?3,?4,?5,?6,?6)",
        params![sequence_id.0, position, draft.endpoint, rounded(draft.value), draft.delay_ms, now],
    )?;
    get_command(tx, EntityId(tx.last_insert_rowid()))?.ok_or(StorageError::NotFound)
}

fn create_sequence(
    c: &mut crate::storage::Connection,
    op: OperationId,
    train_id: EntityId,
    draft: SequenceDraft,
) -> DbResult<Mutation<SequenceRecord>> {
    validate_name(&draft.name)?;
    domain_tx(c, "trains", op, move |tx| {
        tx.execute(
            "INSERT INTO sequences(name,train_id,inserted_at,updated_at) VALUES(?1,?2,?3,?3)",
            params![draft.name, train_id.0, timestamp()],
        )?;
        get_sequence(tx, EntityId(tx.last_insert_rowid()))?.ok_or(StorageError::NotFound)
    })
}

fn update_sequence(
    c: &mut crate::storage::Connection,
    op: OperationId,
    id: EntityId,
    patch: SequencePatch,
) -> DbResult<Mutation<SequenceRecord>> {
    if let Some(name) = patch.name.as_deref() {
        validate_name(name)?;
    }
    domain_tx(c, "trains", op, move |tx| {
        let current = get_sequence(tx, id)?.ok_or(StorageError::NotFound)?;
        let name = patch.name.unwrap_or(current.name);
        tx.execute(
            "UPDATE sequences SET name=?1,updated_at=?2 WHERE id=?3",
            params![name, timestamp(), id.0],
        )?;
        get_sequence(tx, id)?.ok_or(StorageError::NotFound)
    })
}

fn delete_sequence(
    c: &mut crate::storage::Connection,
    op: OperationId,
    id: EntityId,
) -> DbResult<Mutation<SequenceRecord>> {
    domain_tx(c, "trains", op, move |tx| {
        let record = get_sequence(tx, id)?.ok_or(StorageError::NotFound)?;
        // sequence_commands rows cascade via ON DELETE CASCADE.
        tx.execute("DELETE FROM sequences WHERE id=?1", [id.0])?;
        Ok(record)
    })
}

fn set_sequence_commands(
    c: &mut crate::storage::Connection,
    op: OperationId,
    sequence_id: EntityId,
    drafts: Vec<SequenceCommandDraft>,
) -> DbResult<Mutation<Vec<SequenceCommandRecord>>> {
    for draft in &drafts {
        validate_command(draft)?;
    }
    domain_tx(c, "trains", op, move |tx| {
        get_sequence(tx, sequence_id)?.ok_or(StorageError::NotFound)?;
        tx.execute(
            "DELETE FROM sequence_commands WHERE sequence_id=?1",
            [sequence_id.0],
        )?;
        let mut records = Vec::with_capacity(drafts.len());
        for (position, draft) in drafts.iter().enumerate() {
            records.push(insert_command(tx, sequence_id, position as i64, draft)?);
        }
        Ok(records)
    })
}

fn add_sequence_command(
    c: &mut crate::storage::Connection,
    op: OperationId,
    sequence_id: EntityId,
    draft: SequenceCommandDraft,
) -> DbResult<Mutation<SequenceCommandRecord>> {
    validate_command(&draft)?;
    domain_tx(c, "trains", op, move |tx| {
        let _ = get_sequence(tx, sequence_id)?.ok_or(StorageError::NotFound)?;
        let max_position: Option<i64> = tx.query_row(
            "SELECT MAX(position) FROM sequence_commands WHERE sequence_id=?1",
            [sequence_id.0],
            |row| row.get(0),
        )?;
        insert_command(tx, sequence_id, max_position.unwrap_or(-1) + 1, &draft)
    })
}

fn delete_sequence_command(
    c: &mut crate::storage::Connection,
    op: OperationId,
    command_id: EntityId,
) -> DbResult<Mutation<SequenceCommandRecord>> {
    domain_tx(c, "trains", op, move |tx| {
        let record = get_command(tx, command_id)?.ok_or(StorageError::NotFound)?;
        tx.execute("DELETE FROM sequence_commands WHERE id=?1", [command_id.0])?;
        Ok(record)
    })
}
