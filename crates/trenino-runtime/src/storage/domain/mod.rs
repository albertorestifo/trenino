//! Typed domain persistence (trains, sequences, scripts, bindings, firmware
//! records) on the database's existing bounded worker. Every mutation commits
//! exactly one topic revision; invalid mutations change neither content nor
//! revision. Modules follow the contracts established by `storage::hardware`.
pub mod bindings;
pub mod firmware_records;
pub mod scripts;
pub mod sequences;
pub mod trains;

use rusqlite::Transaction;
use trenino_core::OperationId;

use super::{
    metadata_key, read_u64, validate_runtime_metadata, Connection, DbResult, Mutation,
    MutationOutcome, MutationReceipt, RuntimeMetadata, StorageError,
};

/// Runs `f` in one transaction and, only if it succeeds, increments the topic
/// revision exactly once in the same commit. Mirrors `hardware_tx` for domain
/// topics; overflow rolls the whole mutation back.
pub(crate) fn domain_tx<T>(
    connection: &mut Connection,
    topic: &'static str,
    operation_id: OperationId,
    f: impl FnOnce(&Transaction<'_>) -> DbResult<T>,
) -> DbResult<Mutation<T>> {
    let tx = connection.transaction()?;
    if validate_runtime_metadata(&tx)?.is_none() {
        return Err(StorageError::InvalidLegacyData {
            detail: "runtime metadata has not been initialized".into(),
        });
    }
    let record = f(&tx)?;
    let key = metadata_key(topic)?;
    let current = read_u64(&tx, &key, 0)?;
    let revision = current.checked_add(1).ok_or_else(|| StorageError::InvalidLegacyData {
        detail: format!("{topic} topic revision counter is exhausted"),
    })?;
    tx.execute(
        "INSERT INTO app_settings(key,value) VALUES(?1,?2) ON CONFLICT(key) DO UPDATE SET value=excluded.value",
        (&key, revision.to_string()),
    )?;
    let epoch = read_u64(&tx, "__runtime.epoch", 0)?;
    tx.commit()?;
    Ok(Mutation {
        record,
        receipt: MutationReceipt {
            operation_id,
            outcome: MutationOutcome::Committed,
            metadata: RuntimeMetadata { epoch, revision },
        },
    })
}

/// Reads the current topic revision pair without a transaction.
pub(crate) fn topic_metadata(
    connection: &Connection,
    topic: &'static str,
) -> DbResult<RuntimeMetadata> {
    Ok(RuntimeMetadata {
        epoch: read_u64(connection, "__runtime.epoch", 0)?,
        revision: read_u64(connection, &metadata_key(topic)?, 0)?,
    })
}
