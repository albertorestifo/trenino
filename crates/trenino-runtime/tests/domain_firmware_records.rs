//! Integration tests for typed firmware persistence
//! (`storage/domain/firmware_records.rs`, topic `firmware`).
//!
//! Mirrors the Elixir suites:
//! - test/trenino/firmware_test.exs (`Trenino.FirmwareTest`)
//! - test/trenino/firmware/firmware_release_test.exs
//! - test/trenino/firmware/firmware_file_test.exs
//! - test/trenino/firmware/upload_history_test.exs
//! - test/trenino/firmware/update_checker_test.exs ("UpdateCheck persistence")
//!
//! plus the one-transaction-per-refresh durability contract of
//! `firmware::FirmwareRepository::upsert_catalog`.
use rusqlite::Connection;
use tempfile::tempdir;
use trenino_core::{EntityId, OperationId};
use trenino_runtime::storage::firmware_records::{
    CatalogUpsert, FirmwareFileDraft, FirmwareFilePatch, FirmwareReleaseDraft, UpdateCheckDraft,
    UploadStart, UploadStatus,
};
use trenino_runtime::storage::{Database, StorageError};

fn database() -> (tempfile::TempDir, Database) {
    let dir = tempdir().unwrap();
    let db = Database::open_full(dir.path().join("firmware.db")).unwrap();
    db.allocate_epoch().unwrap();
    (dir, db)
}

fn release_draft(version: &str, tag_name: &str, published_at: Option<&str>) -> FirmwareReleaseDraft {
    FirmwareReleaseDraft {
        version: version.into(),
        tag_name: tag_name.into(),
        release_url: Some(format!(
            "https://github.com/albertorestifo/trenino_firmware/releases/tag/{tag_name}"
        )),
        release_notes: None,
        published_at: published_at.map(str::to_owned),
        manifest_json: None,
    }
}

fn file_draft(board_type: &str, download_url: &str, file_size: i64) -> FirmwareFileDraft {
    FirmwareFileDraft {
        board_type: board_type.into(),
        environment: Some(board_type.into()),
        download_url: download_url.into(),
        file_size: Some(file_size),
    }
}

fn upload_start(upload_id: &str, port: &str, board_type: &str) -> UploadStart {
    UploadStart {
        upload_id: upload_id.into(),
        port: port.into(),
        board_type: board_type.into(),
        firmware_file_id: None,
    }
}

/// Mirrors "upsert_release/1" (firmware_test.exs): creates when the tag is
/// unknown and full-field replaces when it exists; plus the
/// `Downloader.store_firmware_file/2` refresh path (upsert by
/// (release_id, board_type) with the environment attribute).
#[test]
fn refresh_upsert_replaces_release_and_files_in_place() {
    let (_dir, db) = database();

    let first = db
        .upsert_firmware_release(
            OperationId(1),
            FirmwareReleaseDraft {
                release_notes: Some("Original".into()),
                ..release_draft("1.0.0", "v1.0.0", Some("2025-12-09T12:31:04Z"))
            },
        )
        .unwrap();
    let uno = db
        .upsert_firmware_file(
            OperationId(2),
            first.record.id,
            file_draft(
                "uno",
                "https://github.com/releases/download/v1.0.0/tws-io-arduino-uno.hex",
                17_113,
            ),
        )
        .unwrap();
    db.upsert_firmware_file(
        OperationId(3),
        first.record.id,
        file_draft(
            "leonardo",
            "https://github.com/releases/download/v1.0.0/tws-io-arduino-leonardo.hex",
            22_890,
        ),
    )
    .unwrap();

    // Second refresh of the same tag with changed metadata and assets.
    let second = db
        .upsert_firmware_release(
            OperationId(4),
            FirmwareReleaseDraft {
                release_notes: Some("Updated notes".into()),
                ..release_draft("1.0.0", "v1.0.0", Some("2025-12-09T12:31:04Z"))
            },
        )
        .unwrap();
    assert_eq!(second.record.id, first.record.id);
    assert_eq!(second.record.release_notes.as_deref(), Some("Updated notes"));

    let uno_after = db
        .upsert_firmware_file(
            OperationId(5),
            first.record.id,
            file_draft("uno", "https://cdn.example.com/uno-v2.hex", 18_000),
        )
        .unwrap();
    assert_eq!(uno_after.record.id, uno.record.id);
    assert_eq!(uno_after.record.download_url, "https://cdn.example.com/uno-v2.hex");
    assert_eq!(uno_after.record.file_size, Some(18_000));
    assert_eq!(uno_after.record.environment.as_deref(), Some("uno"));

    // Refresh never duplicates rows: still exactly one release and two files.
    assert_eq!(db.list_firmware_releases().unwrap().len(), 1);
    let files = db.firmware_files_for_release(first.record.id).unwrap();
    assert_eq!(files.len(), 2);
    assert!(files.iter().all(|f| f.release_id == first.record.id));
}

/// `FirmwareRepository::upsert_catalog` durability contract: the whole
/// refresh commits as one transaction (one firmware topic revision), and an
/// invalid entry rolls the refresh back entirely, leaving content and
/// revision untouched.
#[test]
fn catalog_upsert_commits_once_and_rolls_back_atomically() {
    let (_dir, db) = database();
    let before = db.firmware_metadata().unwrap();

    let refresh = db
        .upsert_catalog(
            OperationId(1),
            vec![
                CatalogUpsert {
                    release: release_draft("1.0.0", "v1.0.0", Some("2025-12-01T00:00:00Z")),
                    files: vec![file_draft("uno", "https://example.com/uno.hex", 17_113)],
                },
                CatalogUpsert {
                    release: release_draft("1.1.0", "v1.1.0", Some("2025-12-10T00:00:00Z")),
                    files: vec![
                        file_draft("uno", "https://example.com/uno-2.hex", 17_200),
                        file_draft("nano", "https://example.com/nano.hex", 17_200),
                    ],
                },
            ],
        )
        .unwrap();

    let after = db.firmware_metadata().unwrap();
    assert_eq!(after.revision, before.revision + 1);
    assert_eq!(refresh.record.len(), 2);
    assert_eq!(refresh.record[0].files.len(), 1);
    assert_eq!(refresh.record[1].files.len(), 2);
    // Row ids assigned by the refresh are stable and usable for selection.
    assert_ne!(refresh.record[0].release.id, refresh.record[1].release.id);

    // A failing entry (blank version, like Ecto validate_required) aborts the
    // whole refresh: no content change, no revision bump.
    let failure = db.upsert_catalog(
        OperationId(2),
        vec![
            CatalogUpsert {
                release: release_draft("2.0.0", "v2.0.0", None),
                files: vec![],
            },
            CatalogUpsert {
                release: release_draft("", "v3.0.0", None),
                files: vec![],
            },
        ],
    );
    assert!(matches!(failure, Err(StorageError::Constraint { .. })));
    assert_eq!(db.firmware_metadata().unwrap().revision, after.revision);
    assert_eq!(db.list_firmware_releases().unwrap().len(), 2);
    assert!(db.get_firmware_release_by_tag("v2.0.0").unwrap().is_none());
}

/// Mirrors "list_releases/1" and "get_latest_release/1" (firmware_test.exs):
/// empty database, `published_at` descending order, latest selection.
#[test]
fn releases_list_newest_first_and_latest_lookup() {
    let (_dir, db) = database();
    assert_eq!(db.list_firmware_releases().unwrap(), vec![]);
    assert_eq!(db.get_latest_firmware_release().unwrap(), None);

    db.create_firmware_release(
        OperationId(1),
        release_draft("0.9.0", "v0.9.0", Some("2025-11-01T12:00:00Z")),
    )
    .unwrap();
    let new_release = db
        .create_firmware_release(
            OperationId(2),
            release_draft("1.0.0", "v1.0.0", Some("2025-12-09T12:00:00Z")),
        )
        .unwrap();

    let releases = db.list_firmware_releases().unwrap();
    assert_eq!(releases.len(), 2);
    assert_eq!(releases[0].id, new_release.record.id);
    assert_eq!(releases[0].tag_name, "v1.0.0");
    assert_eq!(releases[1].tag_name, "v0.9.0");

    let latest = db.get_latest_firmware_release().unwrap().unwrap();
    assert_eq!(latest.id, new_release.record.id);
    assert_eq!(latest.version, "1.0.0");
}

/// Mirrors "get_release/2" and "get_release_by_tag/2" (firmware_test.exs).
#[test]
fn release_lookup_by_id_and_tag() {
    let (_dir, db) = database();
    let release = db
        .create_firmware_release(
            OperationId(1),
            release_draft("1.0.0", "v1.0.0", Some("2025-12-09T12:31:04Z")),
        )
        .unwrap();

    let by_id = db.get_firmware_release(release.record.id).unwrap().unwrap();
    assert_eq!(by_id.tag_name, "v1.0.0");
    let by_tag = db.get_firmware_release_by_tag("v1.0.0").unwrap().unwrap();
    assert_eq!(by_tag.id, release.record.id);

    assert_eq!(db.get_firmware_release(EntityId(999_999)).unwrap(), None);
    assert_eq!(db.get_firmware_release_by_tag("v99.0.0").unwrap(), None);
}

/// Mirrors "create_release/1 returns error with invalid attributes"
/// (firmware_test.exs) and "requires version" / "requires tag_name" /
/// "enforces unique tag_name constraint" (firmware_release_test.exs).
#[test]
fn create_release_validates_required_fields_and_unique_tag() {
    let (_dir, db) = database();

    let blank_version = db.create_firmware_release(OperationId(1), release_draft("", "v1.0.0", None));
    assert!(matches!(blank_version, Err(StorageError::Constraint { .. })));

    let blank_tag = db.create_firmware_release(OperationId(2), release_draft("1.0.0", "", None));
    assert!(matches!(blank_tag, Err(StorageError::Constraint { .. })));

    db.create_firmware_release(OperationId(3), release_draft("1.0.0", "v1.0.0", None))
        .unwrap();
    let duplicate = db.create_firmware_release(OperationId(4), release_draft("1.0.1", "v1.0.0", None));
    assert!(matches!(duplicate, Err(StorageError::Conflict { .. })));
}

/// Mirrors firmware_file_test.exs: "requires board_type" / "requires
/// download_url" / "enforces unique constraint on release_id + board_type" /
/// "enforces foreign key constraint on firmware_release_id", and
/// firmware_test.exs "get_firmware_file/2" + "get_firmware_file_for_board/2".
///
/// Note: the Elixir "validates board_type enum" test predates dynamic,
/// manifest-loaded device configurations (see the note at the bottom of
/// firmware_test.exs); board_type is free-form here as in the current
/// changeset.
#[test]
fn firmware_file_creation_constraints_and_lookups() {
    let (_dir, db) = database();
    let release = db
        .create_firmware_release(OperationId(1), release_draft("1.0.0", "v1.0.0", None))
        .unwrap();

    let file = db
        .create_firmware_file(
            OperationId(2),
            release.record.id,
            file_draft("micro", "https://example.com/micro.hex", 22_890),
        )
        .unwrap();
    assert_eq!(file.record.release_id, release.record.id);
    assert_eq!(file.record.board_type, "micro");
    assert_eq!(file.record.checksum_sha256, None);

    let found = db.get_firmware_file(file.record.id).unwrap().unwrap();
    assert_eq!(found.id, file.record.id);
    assert_eq!(db.get_firmware_file(EntityId(999_999)).unwrap(), None);

    let for_board = db
        .get_firmware_file_for_board(release.record.id, "micro")
        .unwrap()
        .unwrap();
    assert_eq!(for_board.id, file.record.id);
    assert_eq!(
        db.get_firmware_file_for_board(release.record.id, "mega2560")
            .unwrap(),
        None
    );

    // Unique (firmware_release_id, board_type).
    let duplicate = db.create_firmware_file(
        OperationId(3),
        release.record.id,
        file_draft("micro", "https://example.com/micro-2.hex", 1),
    );
    assert!(matches!(duplicate, Err(StorageError::Conflict { .. })));

    // FK to a missing release.
    let orphan = db.create_firmware_file(
        OperationId(4),
        EntityId(999_999),
        file_draft("uno", "https://example.com/uno.hex", 1),
    );
    assert!(matches!(orphan, Err(StorageError::ForeignKey { .. })));

    // Required fields.
    let blank_board = db.create_firmware_file(
        OperationId(5),
        release.record.id,
        file_draft("", "https://example.com/x.hex", 1),
    );
    assert!(matches!(blank_board, Err(StorageError::Constraint { .. })));
    let blank_url = db.create_firmware_file(
        OperationId(6),
        release.record.id,
        file_draft("uno", "", 1),
    );
    assert!(matches!(blank_url, Err(StorageError::Constraint { .. })));
}

/// Mirrors "update_firmware_file/2 updates firmware file attributes"
/// (firmware_test.exs): Ecto-cast merge semantics — only patched fields
/// change, NULL-able fields can be cleared, required fields stay validated.
#[test]
fn update_firmware_file_merges_patch_and_validates() {
    let (_dir, db) = database();
    let release = db
        .create_firmware_release(OperationId(1), release_draft("1.0.0", "v1.0.0", None))
        .unwrap();
    let file = db
        .create_firmware_file(
            OperationId(2),
            release.record.id,
            file_draft("uno", "https://example.com/uno.hex", 17_113),
        )
        .unwrap();

    let updated = db
        .update_firmware_file(
            OperationId(3),
            file.record.id,
            FirmwareFilePatch {
                file_size: Some(Some(12_345)),
                checksum_sha256: Some(Some("abc123".into())),
                ..FirmwareFilePatch::default()
            },
        )
        .unwrap();
    assert_eq!(updated.record.file_size, Some(12_345));
    assert_eq!(updated.record.checksum_sha256.as_deref(), Some("abc123"));
    // Untouched fields survive the merge.
    assert_eq!(updated.record.board_type, "uno");
    assert_eq!(updated.record.download_url, "https://example.com/uno.hex");
    assert_eq!(updated.record.environment.as_deref(), Some("uno"));

    // Present-but-NULL clears a nullable column.
    let cleared = db
        .update_firmware_file(
            OperationId(4),
            file.record.id,
            FirmwareFilePatch {
                checksum_sha256: Some(None),
                ..FirmwareFilePatch::default()
            },
        )
        .unwrap();
    assert_eq!(cleared.record.checksum_sha256, None);

    // validate_required still applies to merged values.
    let blank = db.update_firmware_file(
        OperationId(5),
        file.record.id,
        FirmwareFilePatch {
            download_url: Some(String::new()),
            ..FirmwareFilePatch::default()
        },
    );
    assert!(matches!(blank, Err(StorageError::Constraint { .. })));

    let missing = db.update_firmware_file(
        OperationId(6),
        EntityId(999_999),
        FirmwareFilePatch::default(),
    );
    assert!(matches!(missing, Err(StorageError::NotFound)));
}

/// `Downloader.store_firmware_file/2` never replaces `checksum_sha256`: a
/// checksum recorded out-of-band survives later refreshes, while the refresh
/// still replaces environment/download_url/file_size. Storage never derives
/// checksums itself.
#[test]
fn refresh_preserves_recorded_checksum() {
    let (_dir, db) = database();
    let release = db
        .create_firmware_release(OperationId(1), release_draft("1.0.0", "v1.0.0", None))
        .unwrap();
    let file = db
        .upsert_firmware_file(
            OperationId(2),
            release.record.id,
            file_draft("uno", "https://example.com/uno.hex", 17_113),
        )
        .unwrap();
    db.update_firmware_file(
        OperationId(3),
        file.record.id,
        FirmwareFilePatch {
            checksum_sha256: Some(Some("deadbeef".into())),
            ..FirmwareFilePatch::default()
        },
    )
    .unwrap();

    let refreshed = db
        .upsert_firmware_file(
            OperationId(4),
            release.record.id,
            FirmwareFileDraft {
                board_type: "uno".into(),
                environment: Some("uno_rev3".into()),
                download_url: "https://example.com/uno-new.hex".into(),
                file_size: Some(18_000),
            },
        )
        .unwrap();
    assert_eq!(refreshed.record.id, file.record.id);
    assert_eq!(refreshed.record.environment.as_deref(), Some("uno_rev3"));
    assert_eq!(refreshed.record.download_url, "https://example.com/uno-new.hex");
    assert_eq!(refreshed.record.file_size, Some(18_000));
    assert_eq!(refreshed.record.checksum_sha256.as_deref(), Some("deadbeef"));
}

/// Mirrors "UpdateCheck persistence" (update_checker_test.exs): insert and
/// retrieve, ordering by checked_at, error message round-trip, the
/// found_updates flag, and `UpdateChecker.cleanup_old_checks/0` retention of
/// the newest 100 rows. Also "requires checked_at".
#[test]
fn update_checks_append_order_and_prune_to_latest_hundred() {
    let (_dir, db) = database();

    let blank = db.record_update_check(
        OperationId(1),
        UpdateCheckDraft {
            checked_at: String::new(),
            found_updates: false,
            latest_version: None,
            error_message: None,
        },
    );
    assert!(matches!(blank, Err(StorageError::Constraint { .. })));

    let older = db
        .record_update_check(
            OperationId(2),
            UpdateCheckDraft {
                checked_at: "2025-12-01T10:00:00Z".into(),
                found_updates: false,
                latest_version: None,
                error_message: Some("GitHub API error: 403".into()),
            },
        )
        .unwrap();
    assert!(!older.record.found_updates);
    assert_eq!(older.record.error_message.as_deref(), Some("GitHub API error: 403"));
    assert!(!older.record.inserted_at.is_empty());

    let newer = db
        .record_update_check(
            OperationId(3),
            UpdateCheckDraft {
                checked_at: "2025-12-09T10:00:00Z".into(),
                found_updates: true,
                latest_version: Some("1.2.0".into()),
                error_message: None,
            },
        )
        .unwrap();
    assert!(newer.record.found_updates);

    let latest = db.latest_update_check().unwrap().unwrap();
    assert_eq!(latest.id, newer.record.id);
    assert_eq!(latest.latest_version.as_deref(), Some("1.2.0"));

    let checks = db.list_update_checks(10).unwrap();
    assert_eq!(checks.len(), 2);
    assert_eq!(checks[0].id, newer.record.id);
    assert_eq!(checks[1].id, older.record.id);

    // Retention: only the newest 100 checks survive each append.
    for i in 0..105u32 {
        db.record_update_check(
            OperationId(100 + u128::from(i)),
            UpdateCheckDraft {
                checked_at: format!("2026-01-01T00:{:02}:{:02}Z", i / 60, i % 60),
                found_updates: false,
                latest_version: None,
                error_message: None,
            },
        )
        .unwrap();
    }
    let kept = db.list_update_checks(200).unwrap();
    assert_eq!(kept.len(), 100);
    assert_eq!(kept[0].checked_at, "2026-01-01T00:01:44Z");
    // The two pre-retention rows from 2025 are evicted.
    assert!(kept.iter().all(|c| c.checked_at.starts_with("2026-01-01")));
}

/// Mirrors "create_upload_history/1" and "get_upload_history/1"
/// (firmware_test.exs) and the start_changeset required-field tests
/// (upload_history_test.exs), including the firmware_file FK.
#[test]
fn upload_history_start_and_lookup() {
    let (_dir, db) = database();
    let release = db
        .create_firmware_release(OperationId(1), release_draft("1.0.0", "v1.0.0", None))
        .unwrap();
    let file = db
        .create_firmware_file(
            OperationId(2),
            release.record.id,
            file_draft("uno", "https://example.com/uno.hex", 17_113),
        )
        .unwrap();

    let started = db
        .start_upload_history(
            OperationId(3),
            UploadStart {
                firmware_file_id: Some(file.record.id),
                ..upload_start("upload_123", "/dev/ttyUSB0", "leonardo")
            },
        )
        .unwrap();
    assert_eq!(started.record.status, UploadStatus::Started);
    assert!(started.record.started_at.is_some());
    assert_eq!(started.record.firmware_file_id, Some(file.record.id));
    assert_eq!(started.record.completed_at, None);
    assert_eq!(started.record.duration_ms, None);

    let found = db.get_upload_history("upload_123").unwrap().unwrap();
    assert_eq!(found.id, started.record.id);
    assert_eq!(db.get_upload_history("nonexistent").unwrap(), None);

    // validate_required([:upload_id, :port, :board_type]).
    for (op, start) in [
        (4, upload_start("", "/dev/ttyUSB0", "uno")),
        (5, upload_start("x", "", "uno")),
        (6, upload_start("y", "/dev/ttyUSB0", "")),
    ] {
        let result = db.start_upload_history(OperationId(op), start);
        assert!(matches!(result, Err(StorageError::Constraint { .. })));
    }

    // foreign_key_constraint(:firmware_file_id).
    let orphan = db.start_upload_history(
        OperationId(7),
        UploadStart {
            firmware_file_id: Some(EntityId(999_999)),
            ..upload_start("orphan", "/dev/ttyUSB0", "uno")
        },
    );
    assert!(matches!(orphan, Err(StorageError::ForeignKey { .. })));
}

/// Mirrors "complete_upload/2", "fail_upload/3" and "cancel_upload_history/1"
/// (firmware_test.exs) and the matching changeset tests
/// (upload_history_test.exs), including "does not set error_message" on
/// cancel. Durations are whole seconds in milliseconds because timestamps are
/// truncated to seconds, as in Elixir's `:utc_datetime`.
#[test]
fn upload_history_complete_fail_cancel_lifecycle() {
    let (_dir, db) = database();

    let started = db
        .start_upload_history(OperationId(1), upload_start("complete_test", "/dev/ttyUSB0", "uno"))
        .unwrap();
    let completed = db
        .complete_upload_history(OperationId(2), started.record.id, Some("success".into()))
        .unwrap();
    assert_eq!(completed.record.status, UploadStatus::Completed);
    assert!(completed.record.completed_at.is_some());
    let duration = completed.record.duration_ms.unwrap();
    assert!(duration >= 0);
    assert_eq!(duration % 1000, 0);
    assert_eq!(completed.record.avrdude_output.as_deref(), Some("success"));

    let started = db
        .start_upload_history(OperationId(3), upload_start("fail_test", "/dev/ttyUSB0", "leonardo"))
        .unwrap();
    let failed = db
        .fail_upload_history(
            OperationId(4),
            started.record.id,
            "Device not responding".into(),
            Some("avrdude: error".into()),
        )
        .unwrap();
    assert_eq!(failed.record.status, UploadStatus::Failed);
    assert_eq!(failed.record.error_message.as_deref(), Some("Device not responding"));
    assert_eq!(failed.record.avrdude_output.as_deref(), Some("avrdude: error"));
    assert!(failed.record.completed_at.is_some());
    assert!(failed.record.duration_ms.is_some());

    let started = db
        .start_upload_history(OperationId(5), upload_start("cancel_test", "/dev/ttyUSB0", "micro"))
        .unwrap();
    let cancelled = db.cancel_upload_history(OperationId(6), started.record.id).unwrap();
    assert_eq!(cancelled.record.status, UploadStatus::Cancelled);
    assert!(cancelled.record.completed_at.is_some());
    assert_eq!(cancelled.record.error_message, None);

    // Missing rows surface as NotFound for every lifecycle mutation.
    for result in [
        db.complete_upload_history(OperationId(7), EntityId(999_999), None),
        db.fail_upload_history(OperationId(8), EntityId(999_999), "boom".into(), None),
        db.cancel_upload_history(OperationId(9), EntityId(999_999)),
    ] {
        assert!(matches!(result, Err(StorageError::NotFound)));
    }
}

/// Mirrors "handles nil started_at" (upload_history_test.exs): completing an
/// upload whose `started_at` is NULL (legacy/seeded row) sets no duration.
/// The NULL-started row is seeded with a raw connection because the start
/// mutation always assigns `started_at`, exactly like `start_changeset`.
#[test]
fn upload_history_completion_without_started_at_has_no_duration() {
    let dir = tempdir().unwrap();
    let path = dir.path().join("firmware.db");
    let db = Database::open_full(&path).unwrap();
    db.allocate_epoch().unwrap();
    drop(db);

    let raw = Connection::open(&path).unwrap();
    raw.execute(
        "INSERT INTO firmware_upload_history(upload_id,port,board_type,status,inserted_at,updated_at) VALUES('legacy_upload','/dev/ttyUSB0','uno','started','2025-01-01 00:00:00','2025-01-01 00:00:00')",
        [],
    )
    .unwrap();
    let legacy_id = raw.last_insert_rowid();
    raw.close().unwrap();

    let db = Database::open_full(&path).unwrap();
    let completed = db
        .complete_upload_history(OperationId(1), EntityId(legacy_id), None)
        .unwrap();
    assert_eq!(completed.record.status, UploadStatus::Completed);
    assert!(completed.record.completed_at.is_some());
    assert_eq!(completed.record.duration_ms, None);
}

/// Mirrors "list_upload_history/1" (firmware_test.exs): empty list, ordering
/// by started_at descending with id tiebreak, and the limit option with the
/// Elixir default of 50.
#[test]
fn upload_history_listing_order_and_limit() {
    let (_dir, db) = database();
    assert_eq!(db.list_upload_history(None).unwrap(), vec![]);

    for i in 1..=5u128 {
        db.start_upload_history(
            OperationId(i),
            upload_start(&format!("upload_{i}"), "/dev/ttyUSB0", "uno"),
        )
        .unwrap();
    }

    let all = db.list_upload_history(None).unwrap();
    assert_eq!(all.len(), 5);
    assert_eq!(all[0].upload_id, "upload_5");
    assert_eq!(all[4].upload_id, "upload_1");

    let limited = db.list_upload_history(Some(3)).unwrap();
    assert_eq!(limited.len(), 3);
    assert_eq!(limited[0].upload_id, "upload_5");

    // The default limit is 50: 51 rows list as 50 unless a larger limit is given.
    for i in 6..=51u128 {
        db.start_upload_history(
            OperationId(i),
            upload_start(&format!("upload_{i}"), "/dev/ttyUSB0", "uno"),
        )
        .unwrap();
    }
    assert_eq!(db.list_upload_history(None).unwrap().len(), 50);
    assert_eq!(db.list_upload_history(Some(60)).unwrap().len(), 51);
}

/// Mirrors the schema constraints behind firmware_file_test.exs and
/// upload_history_test.exs associations: deleting a release cascades to its
/// files (`ON DELETE CASCADE`), and upload history rows referencing those
/// files survive with `firmware_file_id` set to NULL (`ON DELETE SET NULL`).
/// Elixir exposes no context delete; these exercise the frozen schema's
/// declared behavior through the storage primitives.
#[test]
fn release_delete_cascades_files_and_detaches_upload_history() {
    let (_dir, db) = database();
    let release = db
        .create_firmware_release(OperationId(1), release_draft("1.0.0", "v1.0.0", None))
        .unwrap();
    let file = db
        .create_firmware_file(
            OperationId(2),
            release.record.id,
            file_draft("uno", "https://example.com/uno.hex", 17_113),
        )
        .unwrap();
    let history = db
        .start_upload_history(
            OperationId(3),
            UploadStart {
                firmware_file_id: Some(file.record.id),
                ..upload_start("upload_detach", "/dev/ttyUSB0", "uno")
            },
        )
        .unwrap();
    let failed = db
        .fail_upload_history(OperationId(4), history.record.id, "boom".into(), None)
        .unwrap();

    let deleted = db.delete_firmware_release(OperationId(5), release.record.id).unwrap();
    assert_eq!(deleted.record.id, release.record.id);
    assert_eq!(db.get_firmware_release(release.record.id).unwrap(), None);
    assert_eq!(db.firmware_files_for_release(release.record.id).unwrap(), vec![]);
    assert_eq!(db.get_firmware_file(file.record.id).unwrap(), None);

    let detached = db.get_upload_history("upload_detach").unwrap().unwrap();
    assert_eq!(detached.firmware_file_id, None);
    // The history row and its recorded outcome survive the cascade.
    assert_eq!(detached.status, UploadStatus::Failed);
    assert_eq!(detached.error_message.as_deref(), Some("boom"));
    assert_eq!(detached.duration_ms, failed.record.duration_ms);

    let missing = db.delete_firmware_release(OperationId(6), EntityId(999_999));
    assert!(matches!(missing, Err(StorageError::NotFound)));
}

/// `ON DELETE SET NULL` for a single file delete: the history row keeps its
/// audit content and drops only the file reference.
#[test]
fn file_delete_detaches_upload_history() {
    let (_dir, db) = database();
    let release = db
        .create_firmware_release(OperationId(1), release_draft("1.0.0", "v1.0.0", None))
        .unwrap();
    let file = db
        .create_firmware_file(
            OperationId(2),
            release.record.id,
            file_draft("uno", "https://example.com/uno.hex", 17_113),
        )
        .unwrap();
    db.start_upload_history(
        OperationId(3),
        UploadStart {
            firmware_file_id: Some(file.record.id),
            ..upload_start("upload_file_detach", "/dev/ttyUSB0", "uno")
        },
    )
    .unwrap();

    let deleted = db.delete_firmware_file(OperationId(4), file.record.id).unwrap();
    assert_eq!(deleted.record.id, file.record.id);
    // The release itself is untouched by a file delete.
    assert!(db.get_firmware_release(release.record.id).unwrap().is_some());

    let detached = db.get_upload_history("upload_file_detach").unwrap().unwrap();
    assert_eq!(detached.firmware_file_id, None);
    assert_eq!(detached.status, UploadStatus::Started);

    let missing = db.delete_firmware_file(OperationId(5), EntityId(999_999));
    assert!(matches!(missing, Err(StorageError::NotFound)));
}

/// Receipt/metadata association (storage::hardware contract): every
/// committed firmware mutation echoes its operation id and advances the
/// firmware topic revision by exactly one; rejected mutations change neither
/// content nor revision.
#[test]
fn mutation_receipts_track_operation_and_revision() {
    let (_dir, db) = database();
    let initial = db.firmware_metadata().unwrap();

    let release = db
        .create_firmware_release(OperationId(11), release_draft("1.0.0", "v1.0.0", None))
        .unwrap();
    assert_eq!(release.receipt.operation_id, OperationId(11));
    assert_eq!(release.receipt.metadata.epoch, initial.epoch);
    assert_eq!(release.receipt.metadata.revision, initial.revision + 1);

    let check = db
        .record_update_check(
            OperationId(12),
            UpdateCheckDraft {
                checked_at: "2025-12-09T12:00:00Z".into(),
                found_updates: false,
                latest_version: None,
                error_message: None,
            },
        )
        .unwrap();
    assert_eq!(check.receipt.metadata.revision, initial.revision + 2);

    let upload = db
        .start_upload_history(OperationId(13), upload_start("op_test", "/dev/ttyUSB0", "uno"))
        .unwrap();
    assert_eq!(upload.receipt.metadata.revision, initial.revision + 3);

    // Rejected mutation: no revision bump, no content change.
    let duplicate = db.create_firmware_release(OperationId(14), release_draft("1.0.1", "v1.0.0", None));
    assert!(matches!(duplicate, Err(StorageError::Conflict { .. })));
    assert_eq!(db.firmware_metadata().unwrap().revision, initial.revision + 3);
    assert_eq!(db.list_firmware_releases().unwrap().len(), 1);
}
