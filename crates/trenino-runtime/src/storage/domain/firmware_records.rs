//! Typed firmware persistence (release catalog, update-check history, upload
//! history) on the database's bounded worker, topic `firmware`.
//!
//! Ports the persistence behavior of the Elixir `Trenino.Firmware` context
//! (`lib/trenino/firmware.ex`) and its schemas: release/file refresh upserts
//! from `Downloader.store_release/1` + `store_firmware_file/2`, check recording
//! from `UpdateChecker.record_check/4` (including `cleanup_old_checks/0`
//! retention), and the `UploadHistory` start/complete/fail/cancel changesets.
//!
//! A catalog refresh commits as ONE transaction and bumps the firmware topic
//! revision exactly once, matching the durability contract of
//! `firmware::FirmwareRepository::upsert_catalog` ("commit each catalog
//! refresh as one transaction and return only after commit"). Elixir stored
//! each release independently; the atomic refresh is strictly stronger and is
//! what the Rust catalog port requires.
//!
//! The storage layer never computes or verifies checksums itself: refresh
//! upserts never touch `checksum_sha256` (exactly like
//! `Downloader.store_firmware_file/2`, which only replaces board_type,
//! environment, download_url and file_size). A checksum may only be recorded
//! by an explicit `update_firmware_file` patch from a caller that obtained it
//! from a trusted source.
use super::{domain_tx, topic_metadata};
use crate::storage::{
    Connection, Database, DbResult, Mutation, Request, RuntimeMetadata, SchemaMode, StorageError,
};
use rusqlite::{params, OptionalExtension, Transaction};
use std::sync::mpsc;
use trenino_core::{EntityId, OperationId};

const TOPIC: &str = "firmware";
/// Mirrors `UpdateChecker.cleanup_old_checks/0` ("keep last 100 checks").
const UPDATE_CHECK_RETENTION: i64 = 100;
/// Mirrors `Firmware.list_upload_history/1` (`limit` option default: 50).
const UPLOAD_HISTORY_DEFAULT_LIMIT: i64 = 50;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum UploadStatus {
    Started,
    Completed,
    Failed,
    Cancelled,
}

impl UploadStatus {
    fn as_db(self) -> &'static str {
        match self {
            Self::Started => "started",
            Self::Completed => "completed",
            Self::Failed => "failed",
            Self::Cancelled => "cancelled",
        }
    }
    fn parse(value: &str) -> DbResult<Self> {
        match value {
            "started" => Ok(Self::Started),
            "completed" => Ok(Self::Completed),
            "failed" => Ok(Self::Failed),
            "cancelled" => Ok(Self::Cancelled),
            _ => Err(StorageError::InvalidLegacyData {
                detail: format!("unknown firmware upload status {value:?}"),
            }),
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct FirmwareReleaseRecord {
    pub id: EntityId,
    pub version: String,
    pub tag_name: String,
    pub release_url: Option<String>,
    pub release_notes: Option<String>,
    pub published_at: Option<String>,
    pub manifest_json: Option<String>,
    pub inserted_at: String,
    pub updated_at: String,
}

/// Full replace payload for `Firmware.upsert_release/1`: on an existing
/// `tag_name` every field is replaced, exactly like the Ecto changeset update
/// fed with the complete attribute map from `Downloader.parse_release/1`.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct FirmwareReleaseDraft {
    pub version: String,
    pub tag_name: String,
    pub release_url: Option<String>,
    pub release_notes: Option<String>,
    pub published_at: Option<String>,
    pub manifest_json: Option<String>,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct FirmwareFileRecord {
    pub id: EntityId,
    pub release_id: EntityId,
    pub board_type: String,
    pub environment: Option<String>,
    pub download_url: String,
    pub file_size: Option<i64>,
    /// Never populated by refresh upserts; only an explicit patch may record
    /// a checksum asserted by a trusted source. Storage treats it as opaque.
    pub checksum_sha256: Option<String>,
    pub inserted_at: String,
    pub updated_at: String,
}

/// Refresh payload for one (release, board_type) file row. Deliberately has
/// no checksum field: `Downloader.store_firmware_file/2` neither inserts nor
/// replaces `checksum_sha256`.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct FirmwareFileDraft {
    pub board_type: String,
    pub environment: Option<String>,
    pub download_url: String,
    pub file_size: Option<i64>,
}

/// Ecto-cast semantics for `Firmware.update_firmware_file/2`: `None` leaves
/// the column unchanged, `Some(None)` stores NULL, `Some(Some(v))` stores `v`.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct FirmwareFilePatch {
    pub release_id: Option<EntityId>,
    pub board_type: Option<String>,
    pub environment: Option<Option<String>>,
    pub download_url: Option<String>,
    pub file_size: Option<Option<i64>>,
    pub checksum_sha256: Option<Option<String>>,
}

/// One release plus its per-board files in a catalog refresh.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct CatalogUpsert {
    pub release: FirmwareReleaseDraft,
    pub files: Vec<FirmwareFileDraft>,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct CatalogReleaseRow {
    pub release: FirmwareReleaseRecord,
    pub files: Vec<FirmwareFileRecord>,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct UpdateCheckDraft {
    /// Second-precision UTC timestamp (`YYYY-MM-DDTHH:MM:SSZ`); required by
    /// the `UpdateCheck` changeset (`validate_required([:checked_at])`).
    pub checked_at: String,
    pub found_updates: bool,
    pub latest_version: Option<String>,
    pub error_message: Option<String>,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct UpdateCheckRow {
    pub id: EntityId,
    pub checked_at: String,
    pub found_updates: bool,
    pub latest_version: Option<String>,
    pub error_message: Option<String>,
    pub inserted_at: String,
    pub updated_at: String,
}

/// Payload for `Firmware.create_upload_history/1` (`start_changeset`):
/// status and `started_at` are assigned by the mutation, never by the caller.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct UploadStart {
    pub upload_id: String,
    pub port: String,
    pub board_type: String,
    pub firmware_file_id: Option<EntityId>,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct UploadHistoryRecord {
    pub id: EntityId,
    pub upload_id: String,
    pub port: String,
    pub board_type: String,
    pub firmware_file_id: Option<EntityId>,
    pub status: UploadStatus,
    pub error_message: Option<String>,
    pub avrdude_output: Option<String>,
    pub duration_ms: Option<i64>,
    pub started_at: Option<String>,
    pub completed_at: Option<String>,
    pub inserted_at: String,
    pub updated_at: String,
}

impl Database {
    fn firmware_call<T: Send + 'static>(
        &self,
        operation: &'static str,
        f: impl FnOnce(&mut Connection) -> DbResult<T> + Send + 'static,
    ) -> DbResult<T> {
        let (reply_tx, reply_rx) = mpsc::channel();
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

    /// Current firmware topic revision pair without a transaction.
    pub fn firmware_metadata(&self) -> DbResult<RuntimeMetadata> {
        self.firmware_call("firmware_metadata", |c| topic_metadata(c, TOPIC))
    }

    /// `Firmware.list_releases/0`: all releases, newest `published_at` first.
    pub fn list_firmware_releases(&self) -> DbResult<Vec<FirmwareReleaseRecord>> {
        self.firmware_call("list_firmware_releases", list_releases)
    }

    /// `Firmware.get_latest_release/0`.
    pub fn get_latest_firmware_release(&self) -> DbResult<Option<FirmwareReleaseRecord>> {
        self.firmware_call("get_latest_firmware_release", |c| {
            c.query_row(
                "SELECT id,version,tag_name,release_url,release_notes,published_at,manifest_json,inserted_at,updated_at FROM firmware_releases ORDER BY published_at DESC LIMIT 1",
                [],
                release_row,
            )
            .optional()
            .map_err(StorageError::from)
        })
    }

    /// `Firmware.get_release/1`.
    pub fn get_firmware_release(&self, id: EntityId) -> DbResult<Option<FirmwareReleaseRecord>> {
        self.firmware_call("get_firmware_release", move |c| get_release(c, id))
    }

    /// `Firmware.get_release_by_tag/1`.
    pub fn get_firmware_release_by_tag(
        &self,
        tag_name: &str,
    ) -> DbResult<Option<FirmwareReleaseRecord>> {
        let tag_name = tag_name.to_owned();
        self.firmware_call("get_firmware_release_by_tag", move |c| {
            get_release_by_tag(c, &tag_name)
        })
    }

    /// `Firmware.get_firmware_file/1`.
    pub fn get_firmware_file(&self, id: EntityId) -> DbResult<Option<FirmwareFileRecord>> {
        self.firmware_call("get_firmware_file", move |c| get_file(c, id))
    }

    /// `Firmware.get_firmware_file_for_board/2`.
    pub fn get_firmware_file_for_board(
        &self,
        release_id: EntityId,
        board_type: &str,
    ) -> DbResult<Option<FirmwareFileRecord>> {
        let board_type = board_type.to_owned();
        self.firmware_call("get_firmware_file_for_board", move |c| {
            get_file_for_board(c, release_id, &board_type)
        })
    }

    /// Files belonging to a release (the `has_many :firmware_files` preload),
    /// in stable row order.
    pub fn firmware_files_for_release(
        &self,
        release_id: EntityId,
    ) -> DbResult<Vec<FirmwareFileRecord>> {
        self.firmware_call("firmware_files_for_release", move |c| {
            files_for_release(c, release_id)
        })
    }

    /// Most recent update check (`UpdateChecker.get_last_check_from_db/0`).
    pub fn latest_update_check(&self) -> DbResult<Option<UpdateCheckRow>> {
        self.firmware_call("latest_update_check", |c| {
            c.query_row(
                "SELECT id,checked_at,found_updates,latest_version,error_message,inserted_at,updated_at FROM firmware_update_checks ORDER BY checked_at DESC LIMIT 1",
                [],
                check_row,
            )
            .optional()
            .map_err(StorageError::from)
        })
    }

    /// Update-check history, newest `checked_at` first (mirrors the raw
    /// `order_by(desc: c.checked_at)` query used by the Elixir tests).
    pub fn list_update_checks(&self, limit: u32) -> DbResult<Vec<UpdateCheckRow>> {
        self.firmware_call("list_update_checks", move |c| {
            let mut q = c.prepare(
                "SELECT id,checked_at,found_updates,latest_version,error_message,inserted_at,updated_at FROM firmware_update_checks ORDER BY checked_at DESC LIMIT ?1",
            )?;
            let rows = q.query_map([i64::from(limit)], check_row)?;
            rows.collect::<Result<Vec<_>, _>>()
                .map_err(StorageError::from)
        })
    }

    /// `Firmware.get_upload_history/1` (lookup by `upload_id`).
    pub fn get_upload_history(
        &self,
        upload_id: &str,
    ) -> DbResult<Option<UploadHistoryRecord>> {
        let upload_id = upload_id.to_owned();
        let raw = self.firmware_call("get_upload_history", move |c| {
            c.query_row(
                "SELECT id,upload_id,port,board_type,firmware_file_id,status,error_message,avrdude_output,duration_ms,started_at,completed_at,inserted_at,updated_at FROM firmware_upload_history WHERE upload_id=?1",
                [&upload_id],
                upload_row,
            )
            .optional()
            .map_err(StorageError::from)
        })?;
        raw.map(decode_upload_row).transpose()
    }

    /// `Firmware.list_upload_history/1`: newest `started_at` first (ties by
    /// id), `None` limit falls back to the Elixir default of 50.
    pub fn list_upload_history(
        &self,
        limit: Option<u32>,
    ) -> DbResult<Vec<UploadHistoryRecord>> {
        let limit = i64::from(limit.unwrap_or(UPLOAD_HISTORY_DEFAULT_LIMIT as u32));
        self.firmware_call("list_upload_history", move |c| {
            let mut q = c.prepare(
                "SELECT id,upload_id,port,board_type,firmware_file_id,status,error_message,avrdude_output,duration_ms,started_at,completed_at,inserted_at,updated_at FROM firmware_upload_history ORDER BY started_at DESC, id DESC LIMIT ?1",
            )?;
            let rows = q.query_map([limit], upload_row)?;
            rows.collect::<Result<Vec<_>, _>>()
                .map_err(StorageError::from)?
                .into_iter()
                .map(decode_upload_row)
                .collect()
        })
    }

    /// `Firmware.create_release/1`: insert; `version`/`tag_name` required,
    /// `tag_name` unique (conflict on duplicate).
    pub fn create_firmware_release(
        &self,
        operation_id: OperationId,
        draft: FirmwareReleaseDraft,
    ) -> DbResult<Mutation<FirmwareReleaseRecord>> {
        self.firmware_call("create_firmware_release", move |c| {
            create_release(c, operation_id, draft)
        })
    }

    /// `Firmware.upsert_release/1`: full-field replace when `tag_name`
    /// already exists (same row id), plain insert otherwise.
    pub fn upsert_firmware_release(
        &self,
        operation_id: OperationId,
        draft: FirmwareReleaseDraft,
    ) -> DbResult<Mutation<FirmwareReleaseRecord>> {
        self.firmware_call("upsert_firmware_release", move |c| {
            domain_tx(c, TOPIC, operation_id, move |tx| {
                upsert_release_row(tx, &draft)
            })
        })
    }

    /// Delete a release. The schema cascades to its firmware files; upload
    /// history rows referencing those files keep their content with
    /// `firmware_file_id` set to NULL (`ON DELETE SET NULL`). Elixir exposes
    /// no context function for this; the primitive exercises the constraints
    /// the schema defines.
    pub fn delete_firmware_release(
        &self,
        operation_id: OperationId,
        id: EntityId,
    ) -> DbResult<Mutation<FirmwareReleaseRecord>> {
        self.firmware_call("delete_firmware_release", move |c| {
            domain_tx(c, TOPIC, operation_id, move |tx| {
                let record = get_release(tx, id)?.ok_or(StorageError::NotFound)?;
                tx.execute("DELETE FROM firmware_releases WHERE id=?1", [id.0])?;
                Ok(record)
            })
        })
    }

    /// `Firmware.create_firmware_file/2`.
    pub fn create_firmware_file(
        &self,
        operation_id: OperationId,
        release_id: EntityId,
        draft: FirmwareFileDraft,
    ) -> DbResult<Mutation<FirmwareFileRecord>> {
        self.firmware_call("create_firmware_file", move |c| {
            domain_tx(c, TOPIC, operation_id, move |tx| {
                insert_file_row(tx, release_id, &draft)
            })
        })
    }

    /// `Downloader.store_firmware_file/2`: upsert by
    /// `(firmware_release_id, board_type)` replacing board_type, environment,
    /// download_url and file_size only; `checksum_sha256` is preserved.
    pub fn upsert_firmware_file(
        &self,
        operation_id: OperationId,
        release_id: EntityId,
        draft: FirmwareFileDraft,
    ) -> DbResult<Mutation<FirmwareFileRecord>> {
        self.firmware_call("upsert_firmware_file", move |c| {
            domain_tx(c, TOPIC, operation_id, move |tx| {
                upsert_file_row(tx, release_id, &draft)
            })
        })
    }

    /// `Firmware.update_firmware_file/2` with Ecto-cast merge semantics.
    pub fn update_firmware_file(
        &self,
        operation_id: OperationId,
        id: EntityId,
        patch: FirmwareFilePatch,
    ) -> DbResult<Mutation<FirmwareFileRecord>> {
        self.firmware_call("update_firmware_file", move |c| {
            update_file(c, operation_id, id, patch)
        })
    }

    /// Delete a single firmware file; referencing upload history rows get
    /// `firmware_file_id` set to NULL. See `delete_firmware_release`.
    pub fn delete_firmware_file(
        &self,
        operation_id: OperationId,
        id: EntityId,
    ) -> DbResult<Mutation<FirmwareFileRecord>> {
        self.firmware_call("delete_firmware_file", move |c| {
            domain_tx(c, TOPIC, operation_id, move |tx| {
                let record = get_file(tx, id)?.ok_or(StorageError::NotFound)?;
                tx.execute("DELETE FROM firmware_files WHERE id=?1", [id.0])?;
                Ok(record)
            })
        })
    }

    /// Whole catalog refresh in one commit (one firmware topic revision):
    /// for each entry, the `Downloader.store_release/1` path — upsert the
    /// release by tag, then upsert every file by (release, board_type).
    /// Storage boundary for a thin `FirmwareRepository::upsert_catalog`
    /// adapter; the adapter maps rows to `CatalogRelease` and parses
    /// `manifest_json` itself.
    pub fn upsert_catalog(
        &self,
        operation_id: OperationId,
        entries: Vec<CatalogUpsert>,
    ) -> DbResult<Mutation<Vec<CatalogReleaseRow>>> {
        self.firmware_call("upsert_catalog", move |c| {
            domain_tx(c, TOPIC, operation_id, move |tx| {
                let mut rows = Vec::with_capacity(entries.len());
                for entry in &entries {
                    let release = upsert_release_row(tx, &entry.release)?;
                    let mut files = Vec::with_capacity(entry.files.len());
                    for draft in &entry.files {
                        files.push(upsert_file_row(tx, release.id, draft)?);
                    }
                    rows.push(CatalogReleaseRow { release, files });
                }
                Ok(rows)
            })
        })
    }

    /// `UpdateChecker.record_check/4`: append one check row and prune history
    /// to the newest 100 rows (`cleanup_old_checks/0`) in the same commit.
    pub fn record_update_check(
        &self,
        operation_id: OperationId,
        draft: UpdateCheckDraft,
    ) -> DbResult<Mutation<UpdateCheckRow>> {
        self.firmware_call("record_update_check", move |c| {
            if draft.checked_at.is_empty() {
                return Err(blank("update check checked_at"));
            }
            domain_tx(c, TOPIC, operation_id, move |tx| {
                let now = timestamp();
                tx.execute(
                    "INSERT INTO firmware_update_checks(checked_at,found_updates,latest_version,error_message,inserted_at,updated_at) VALUES(?1,?2,?3,?4,?5,?5)",
                    params![
                        draft.checked_at,
                        i64::from(draft.found_updates),
                        draft.latest_version,
                        draft.error_message,
                        now
                    ],
                )?;
                let id = tx.last_insert_rowid();
                tx.execute(
                    "DELETE FROM firmware_update_checks WHERE id NOT IN (SELECT id FROM firmware_update_checks ORDER BY checked_at DESC LIMIT ?1)",
                    [UPDATE_CHECK_RETENTION],
                )?;
                get_check(tx, EntityId(id))?.ok_or(StorageError::NotFound)
            })
        })
    }

    /// `Firmware.create_upload_history/1` (`UploadHistory.start_changeset/1`):
    /// inserts with status `started` and `started_at = now` (second
    /// precision). Storage boundary for the avrdude upload-lifecycle port.
    pub fn start_upload_history(
        &self,
        operation_id: OperationId,
        start: UploadStart,
    ) -> DbResult<Mutation<UploadHistoryRecord>> {
        self.firmware_call("start_upload_history", move |c| {
            if start.upload_id.is_empty() {
                return Err(blank("upload history upload_id"));
            }
            if start.port.is_empty() {
                return Err(blank("upload history port"));
            }
            if start.board_type.is_empty() {
                return Err(blank("upload history board_type"));
            }
            domain_tx(c, TOPIC, operation_id, move |tx| {
                let now = timestamp();
                tx.execute(
                    "INSERT INTO firmware_upload_history(upload_id,port,board_type,firmware_file_id,status,started_at,inserted_at,updated_at) VALUES(?1,?2,?3,?4,?5,?6,?7,?7)",
                    params![
                        start.upload_id,
                        start.port,
                        start.board_type,
                        start.firmware_file_id.map(|id| id.0),
                        UploadStatus::Started.as_db(),
                        now,
                        now
                    ],
                )?;
                let id = EntityId(tx.last_insert_rowid());
                get_upload(tx, id)?.ok_or(StorageError::NotFound)
            })
        })
    }

    /// `Firmware.complete_upload/2` (`complete_changeset`): status completed,
    /// `completed_at = now`, `duration_ms = completed_at - started_at`.
    pub fn complete_upload_history(
        &self,
        operation_id: OperationId,
        id: EntityId,
        avrdude_output: Option<String>,
    ) -> DbResult<Mutation<UploadHistoryRecord>> {
        self.firmware_call("complete_upload_history", move |c| {
            finish_upload(c, operation_id, id, Finish::Completed { avrdude_output })
        })
    }

    /// `Firmware.fail_upload/3` (`fail_changeset`): status failed with error
    /// message and optional avrdude output.
    pub fn fail_upload_history(
        &self,
        operation_id: OperationId,
        id: EntityId,
        error_message: String,
        avrdude_output: Option<String>,
    ) -> DbResult<Mutation<UploadHistoryRecord>> {
        self.firmware_call("fail_upload_history", move |c| {
            finish_upload(
                c,
                operation_id,
                id,
                Finish::Failed {
                    error_message,
                    avrdude_output,
                },
            )
        })
    }

    /// `Firmware.cancel_upload_history/1` (`cancel_changeset`): status
    /// cancelled; never sets `error_message`.
    pub fn cancel_upload_history(
        &self,
        operation_id: OperationId,
        id: EntityId,
    ) -> DbResult<Mutation<UploadHistoryRecord>> {
        self.firmware_call("cancel_upload_history", move |c| {
            finish_upload(c, operation_id, id, Finish::Cancelled)
        })
    }
}

enum Finish {
    Completed { avrdude_output: Option<String> },
    Failed { error_message: String, avrdude_output: Option<String> },
    Cancelled,
}

fn finish_upload(
    c: &mut Connection,
    operation_id: OperationId,
    id: EntityId,
    finish: Finish,
) -> DbResult<Mutation<UploadHistoryRecord>> {
    domain_tx(c, TOPIC, operation_id, move |tx| {
        let current = get_upload(tx, id)?.ok_or(StorageError::NotFound)?;
        let now = timestamp();
        let duration_ms = duration_ms(current.started_at.as_deref(), &now)?;
        match finish {
            Finish::Completed { avrdude_output } => tx.execute(
                "UPDATE firmware_upload_history SET status=?1,completed_at=?2,duration_ms=?3,avrdude_output=?4,updated_at=?2 WHERE id=?5",
                params![UploadStatus::Completed.as_db(), now, duration_ms, avrdude_output, id.0],
            )?,
            Finish::Failed { error_message, avrdude_output } => tx.execute(
                "UPDATE firmware_upload_history SET status=?1,error_message=?2,avrdude_output=?3,completed_at=?4,duration_ms=?5,updated_at=?4 WHERE id=?6",
                params![UploadStatus::Failed.as_db(), error_message, avrdude_output, now, duration_ms, id.0],
            )?,
            Finish::Cancelled => tx.execute(
                "UPDATE firmware_upload_history SET status=?1,completed_at=?2,duration_ms=?3,updated_at=?2 WHERE id=?4",
                params![UploadStatus::Cancelled.as_db(), now, duration_ms, id.0],
            )?,
        };
        get_upload(tx, id)?.ok_or(StorageError::NotFound)
    })
}

fn blank(field: &str) -> StorageError {
    // Mirrors Ecto `validate_required` ("can't be blank").
    StorageError::Constraint {
        detail: format!("firmware {field} can't be blank"),
    }
}

fn validate_release_draft(draft: &FirmwareReleaseDraft) -> DbResult<()> {
    if draft.version.is_empty() {
        return Err(blank("release version"));
    }
    if draft.tag_name.is_empty() {
        return Err(blank("release tag_name"));
    }
    Ok(())
}

fn validate_file_draft(draft: &FirmwareFileDraft) -> DbResult<()> {
    if draft.board_type.is_empty() {
        return Err(blank("file board_type"));
    }
    if draft.download_url.is_empty() {
        return Err(blank("file download_url"));
    }
    Ok(())
}

fn release_row(row: &rusqlite::Row<'_>) -> rusqlite::Result<FirmwareReleaseRecord> {
    Ok(FirmwareReleaseRecord {
        id: EntityId(row.get(0)?),
        version: row.get(1)?,
        tag_name: row.get(2)?,
        release_url: row.get(3)?,
        release_notes: row.get(4)?,
        published_at: row.get(5)?,
        manifest_json: row.get(6)?,
        inserted_at: row.get(7)?,
        updated_at: row.get(8)?,
    })
}

const RELEASE_COLUMNS: &str =
    "id,version,tag_name,release_url,release_notes,published_at,manifest_json,inserted_at,updated_at";

fn get_release(c: &Connection, id: EntityId) -> DbResult<Option<FirmwareReleaseRecord>> {
    c.query_row(
        &format!("SELECT {RELEASE_COLUMNS} FROM firmware_releases WHERE id=?1"),
        [id.0],
        release_row,
    )
    .optional()
    .map_err(StorageError::from)
}

fn get_release_by_tag(c: &Connection, tag: &str) -> DbResult<Option<FirmwareReleaseRecord>> {
    c.query_row(
        &format!("SELECT {RELEASE_COLUMNS} FROM firmware_releases WHERE tag_name=?1"),
        [tag],
        release_row,
    )
    .optional()
    .map_err(StorageError::from)
}

fn list_releases(c: &mut Connection) -> DbResult<Vec<FirmwareReleaseRecord>> {
    let mut q = c.prepare(&format!(
        "SELECT {RELEASE_COLUMNS} FROM firmware_releases ORDER BY published_at DESC"
    ))?;
    let rows = q.query_map([], release_row)?;
    rows.collect::<Result<Vec<_>, _>>()
        .map_err(StorageError::from)
}

fn insert_release_row(
    tx: &Transaction<'_>,
    draft: &FirmwareReleaseDraft,
) -> DbResult<FirmwareReleaseRecord> {
    validate_release_draft(draft)?;
    tx.execute(
        "INSERT INTO firmware_releases(version,tag_name,release_url,release_notes,published_at,manifest_json,inserted_at,updated_at) VALUES(?1,?2,?3,?4,?5,?6,?7,?7)",
        params![
            draft.version,
            draft.tag_name,
            draft.release_url,
            draft.release_notes,
            draft.published_at,
            draft.manifest_json,
            timestamp()
        ],
    )?;
    get_release(tx, EntityId(tx.last_insert_rowid()))?.ok_or(StorageError::NotFound)
}

fn upsert_release_row(
    tx: &Transaction<'_>,
    draft: &FirmwareReleaseDraft,
) -> DbResult<FirmwareReleaseRecord> {
    validate_release_draft(draft)?;
    match get_release_by_tag(tx, &draft.tag_name)? {
        Some(existing) => {
            tx.execute(
                "UPDATE firmware_releases SET version=?1,tag_name=?2,release_url=?3,release_notes=?4,published_at=?5,manifest_json=?6,updated_at=?7 WHERE id=?8",
                params![
                    draft.version,
                    draft.tag_name,
                    draft.release_url,
                    draft.release_notes,
                    draft.published_at,
                    draft.manifest_json,
                    timestamp(),
                    existing.id.0
                ],
            )?;
            get_release(tx, existing.id)?.ok_or(StorageError::NotFound)
        }
        None => insert_release_row(tx, draft),
    }
}

fn create_release(
    c: &mut Connection,
    operation_id: OperationId,
    draft: FirmwareReleaseDraft,
) -> DbResult<Mutation<FirmwareReleaseRecord>> {
    domain_tx(c, TOPIC, operation_id, move |tx| insert_release_row(tx, &draft))
}

fn file_row(row: &rusqlite::Row<'_>) -> rusqlite::Result<FirmwareFileRecord> {
    Ok(FirmwareFileRecord {
        id: EntityId(row.get(0)?),
        release_id: EntityId(row.get(1)?),
        board_type: row.get(2)?,
        environment: row.get(3)?,
        download_url: row.get(4)?,
        file_size: row.get(5)?,
        checksum_sha256: row.get(6)?,
        inserted_at: row.get(7)?,
        updated_at: row.get(8)?,
    })
}

const FILE_COLUMNS: &str =
    "id,firmware_release_id,board_type,environment,download_url,file_size,checksum_sha256,inserted_at,updated_at";

fn get_file(c: &Connection, id: EntityId) -> DbResult<Option<FirmwareFileRecord>> {
    c.query_row(
        &format!("SELECT {FILE_COLUMNS} FROM firmware_files WHERE id=?1"),
        [id.0],
        file_row,
    )
    .optional()
    .map_err(StorageError::from)
}

fn get_file_for_board(
    c: &Connection,
    release_id: EntityId,
    board_type: &str,
) -> DbResult<Option<FirmwareFileRecord>> {
    c.query_row(
        &format!(
            "SELECT {FILE_COLUMNS} FROM firmware_files WHERE firmware_release_id=?1 AND board_type=?2"
        ),
        params![release_id.0, board_type],
        file_row,
    )
    .optional()
    .map_err(StorageError::from)
}

fn files_for_release(c: &Connection, release_id: EntityId) -> DbResult<Vec<FirmwareFileRecord>> {
    let mut q = c.prepare(&format!(
        "SELECT {FILE_COLUMNS} FROM firmware_files WHERE firmware_release_id=?1 ORDER BY id"
    ))?;
    let rows = q.query_map([release_id.0], file_row)?;
    rows.collect::<Result<Vec<_>, _>>()
        .map_err(StorageError::from)
}

fn insert_file_row(
    tx: &Transaction<'_>,
    release_id: EntityId,
    draft: &FirmwareFileDraft,
) -> DbResult<FirmwareFileRecord> {
    validate_file_draft(draft)?;
    tx.execute(
        "INSERT INTO firmware_files(firmware_release_id,board_type,environment,download_url,file_size,inserted_at,updated_at) VALUES(?1,?2,?3,?4,?5,?6,?6)",
        params![
            release_id.0,
            draft.board_type,
            draft.environment,
            draft.download_url,
            draft.file_size,
            timestamp()
        ],
    )?;
    get_file(tx, EntityId(tx.last_insert_rowid()))?.ok_or(StorageError::NotFound)
}

fn upsert_file_row(
    tx: &Transaction<'_>,
    release_id: EntityId,
    draft: &FirmwareFileDraft,
) -> DbResult<FirmwareFileRecord> {
    validate_file_draft(draft)?;
    match get_file_for_board(tx, release_id, &draft.board_type)? {
        Some(existing) => {
            // store_firmware_file/2 replaces exactly these attributes;
            // checksum_sha256 is never touched by a refresh.
            tx.execute(
                "UPDATE firmware_files SET board_type=?1,environment=?2,download_url=?3,file_size=?4,updated_at=?5 WHERE id=?6",
                params![
                    draft.board_type,
                    draft.environment,
                    draft.download_url,
                    draft.file_size,
                    timestamp(),
                    existing.id.0
                ],
            )?;
            get_file(tx, existing.id)?.ok_or(StorageError::NotFound)
        }
        None => insert_file_row(tx, release_id, draft),
    }
}

fn update_file(
    c: &mut Connection,
    operation_id: OperationId,
    id: EntityId,
    patch: FirmwareFilePatch,
) -> DbResult<Mutation<FirmwareFileRecord>> {
    domain_tx(c, TOPIC, operation_id, move |tx| {
        let current = get_file(tx, id)?.ok_or(StorageError::NotFound)?;
        let release_id = patch.release_id.unwrap_or(current.release_id);
        let board_type = patch.board_type.unwrap_or(current.board_type);
        let environment = patch.environment.unwrap_or(current.environment);
        let download_url = patch.download_url.unwrap_or(current.download_url);
        let file_size = patch.file_size.unwrap_or(current.file_size);
        let checksum_sha256 = patch.checksum_sha256.unwrap_or(current.checksum_sha256);
        if board_type.is_empty() {
            return Err(blank("file board_type"));
        }
        if download_url.is_empty() {
            return Err(blank("file download_url"));
        }
        tx.execute(
            "UPDATE firmware_files SET firmware_release_id=?1,board_type=?2,environment=?3,download_url=?4,file_size=?5,checksum_sha256=?6,updated_at=?7 WHERE id=?8",
            params![
                release_id.0,
                board_type,
                environment,
                download_url,
                file_size,
                checksum_sha256,
                timestamp(),
                id.0
            ],
        )?;
        get_file(tx, id)?.ok_or(StorageError::NotFound)
    })
}

fn check_row(row: &rusqlite::Row<'_>) -> rusqlite::Result<UpdateCheckRow> {
    Ok(UpdateCheckRow {
        id: EntityId(row.get(0)?),
        checked_at: row.get(1)?,
        found_updates: row.get::<_, i64>(2)? != 0,
        latest_version: row.get(3)?,
        error_message: row.get(4)?,
        inserted_at: row.get(5)?,
        updated_at: row.get(6)?,
    })
}

fn get_check(c: &Connection, id: EntityId) -> DbResult<Option<UpdateCheckRow>> {
    c.query_row(
        "SELECT id,checked_at,found_updates,latest_version,error_message,inserted_at,updated_at FROM firmware_update_checks WHERE id=?1",
        [id.0],
        check_row,
    )
    .optional()
    .map_err(StorageError::from)
}

/// Raw upload-history row with the status string not yet decoded, so a
/// corrupt status surfaces as `InvalidLegacyData` instead of a mapping error.
type RawUploadRow = (
    i64,
    String,
    String,
    String,
    Option<i64>,
    String,
    Option<String>,
    Option<String>,
    Option<i64>,
    Option<String>,
    Option<String>,
    String,
    String,
);

fn upload_row(row: &rusqlite::Row<'_>) -> rusqlite::Result<RawUploadRow> {
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
        row.get(11)?,
        row.get(12)?,
    ))
}

fn decode_upload_row(row: RawUploadRow) -> DbResult<UploadHistoryRecord> {
    let (
        id,
        upload_id,
        port,
        board_type,
        firmware_file_id,
        status,
        error_message,
        avrdude_output,
        duration_ms,
        started_at,
        completed_at,
        inserted_at,
        updated_at,
    ) = row;
    Ok(UploadHistoryRecord {
        id: EntityId(id),
        upload_id,
        port,
        board_type,
        firmware_file_id: firmware_file_id.map(EntityId),
        status: UploadStatus::parse(&status)?,
        error_message,
        avrdude_output,
        duration_ms,
        started_at,
        completed_at,
        inserted_at,
        updated_at,
    })
}

fn get_upload(c: &Connection, id: EntityId) -> DbResult<Option<UploadHistoryRecord>> {
    c.query_row(
        "SELECT id,upload_id,port,board_type,firmware_file_id,status,error_message,avrdude_output,duration_ms,started_at,completed_at,inserted_at,updated_at FROM firmware_upload_history WHERE id=?1",
        [id.0],
        upload_row,
    )
    .optional()
    .map_err(StorageError::from)?
    .map(decode_upload_row)
    .transpose()
}

/// `DateTime.diff(now, started_at, :millisecond)` from the changesets:
/// `None` when `started_at` is NULL, otherwise second-precision difference
/// (both timestamps are truncated to seconds, so the result is a whole
/// number of seconds in milliseconds).
fn duration_ms(started_at: Option<&str>, now: &str) -> DbResult<Option<i64>> {
    match started_at {
        None => Ok(None),
        Some(started) => {
            let start = unix_seconds(started).ok_or_else(|| StorageError::InvalidLegacyData {
                detail: format!("unparseable firmware upload started_at {started:?}"),
            })?;
            let end = unix_seconds(now).ok_or_else(|| StorageError::InvalidLegacyData {
                detail: format!("unparseable generated timestamp {now:?}"),
            })?;
            Ok(Some((end - start) * 1000))
        }
    }
}

/// Second-precision UTC timestamp, matching the Ecto `:utc_datetime` format
/// written by the rest of the storage layer (`hardware.rs`).
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

/// Inverse of `timestamp()` for duration computation. Accepts both
/// `YYYY-MM-DDTHH:MM:SSZ` (written by this crate) and `YYYY-MM-DD HH:MM:SS`
/// (SQLite `CURRENT_TIMESTAMP`, used by legacy migration inserts).
fn unix_seconds(ts: &str) -> Option<i64> {
    let bytes = ts.as_bytes();
    if bytes.len() < 19
        || bytes[4] != b'-'
        || bytes[7] != b'-'
        || (bytes[10] != b'T' && bytes[10] != b' ')
        || bytes[13] != b':'
        || bytes[16] != b':'
    {
        return None;
    }
    let year: i64 = ts.get(0..4)?.parse().ok()?;
    let month: i64 = ts.get(5..7)?.parse().ok()?;
    let day: i64 = ts.get(8..10)?.parse().ok()?;
    let hour: i64 = ts.get(11..13)?.parse().ok()?;
    let minute: i64 = ts.get(14..16)?.parse().ok()?;
    let second: i64 = ts.get(17..19)?.parse().ok()?;
    if !(1..=12).contains(&month) || !(1..=31).contains(&day) {
        return None;
    }
    // days-from-civil (Howard Hinnant's algorithm).
    let y = if month <= 2 { year - 1 } else { year };
    let era = if y >= 0 { y } else { y - 399 } / 400;
    let yoe = y - era * 400;
    let mp = (month + 9) % 12;
    let doy = (153 * mp + 2) / 5 + day - 1;
    let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
    let days = era * 146_097 + doe - 719_468;
    Some(days * 86_400 + hour * 3_600 + minute * 60 + second)
}
