//! Sequence persistence tests, mirroring the "Sequence tests" describes in
//! test/trenino/train_test.exs (create_sequence/2, get_sequence/1,
//! list_sequences/1, set_sequence_commands/2, add_sequence_command/2,
//! delete_sequence/1). Trains are seeded directly over SQLite because train
//! CRUD belongs to a separate module; the schema's foreign keys still apply.
use rusqlite::Connection;
use tempfile::tempdir;
use trenino_core::{EntityId, OperationId};
use trenino_runtime::storage::sequences::{SequenceCommandDraft, SequenceDraft, SequencePatch};
use trenino_runtime::storage::{Database, MutationOutcome, StorageError};

fn database() -> (tempfile::TempDir, Database, std::path::PathBuf) {
    let dir = tempdir().unwrap();
    let path = dir.path().join("domain.db");
    let db = Database::open_full(&path).unwrap();
    db.allocate_epoch().unwrap();
    (dir, db, path)
}

/// Inserts a train row the way the trains domain module would, returning its
/// id. Mirrors the `create_train` calls that open every Elixir sequence test.
fn seed_train(path: &std::path::Path, name: &str) -> EntityId {
    let connection = Connection::open(path).unwrap();
    connection
        .execute(
            "INSERT INTO trains(name,description,inserted_at,updated_at) VALUES(?1,NULL,'2026-01-01T00:00:00Z','2026-01-01T00:00:00Z')",
            [name],
        )
        .unwrap();
    EntityId(connection.last_insert_rowid())
}

fn command(endpoint: &str, value: f64, delay_ms: i64) -> SequenceCommandDraft {
    SequenceCommandDraft {
        endpoint: endpoint.into(),
        value,
        delay_ms,
    }
}

// Mirrors train_test.exs "creates a sequence with valid attributes".
#[test]
fn create_sequence_with_valid_attributes() {
    let (_dir, db, path) = database();
    let train = seed_train(&path, "Class 66");
    let mutation = db
        .create_sequence(
            OperationId(1),
            train,
            SequenceDraft {
                name: "Door Open".into(),
            },
        )
        .unwrap();
    assert_eq!(mutation.record.name, "Door Open");
    assert_eq!(mutation.record.train_id, train);
    assert_eq!(mutation.receipt.outcome, MutationOutcome::Committed);
}

// Mirrors "requires name" and "enforces unique name per train".
#[test]
fn create_sequence_validates_name_and_uniqueness() {
    let (_dir, db, path) = database();
    let train = seed_train(&path, "Class 66");
    assert!(matches!(
        db.create_sequence(OperationId(1), train, SequenceDraft { name: "   ".into() }),
        Err(StorageError::Constraint { .. })
    ));
    assert!(matches!(
        db.create_sequence(
            OperationId(2),
            train,
            SequenceDraft {
                name: "x".repeat(101)
            }
        ),
        Err(StorageError::Constraint { .. })
    ));
    db.create_sequence(
        OperationId(3),
        train,
        SequenceDraft {
            name: "Door Open".into(),
        },
    )
    .unwrap();
    // Ecto surfaces "has already been taken" via the (train_id, name) unique index.
    assert!(matches!(
        db.create_sequence(
            OperationId(4),
            train,
            SequenceDraft {
                name: "Door Open".into()
            }
        ),
        Err(StorageError::Conflict { .. })
    ));
    // Invalid mutations must not change content or revision.
    let revision = db.revision("trains").unwrap();
    assert!(matches!(
        db.create_sequence(
            OperationId(5),
            train,
            SequenceDraft {
                name: "Door Open".into()
            }
        ),
        Err(StorageError::Conflict { .. })
    ));
    assert_eq!(db.revision("trains").unwrap(), revision);
}

// Mirrors "create_sequence" foreign_key_constraint on an unknown train.
#[test]
fn create_sequence_rejects_unknown_train() {
    let (_dir, db, _path) = database();
    assert!(matches!(
        db.create_sequence(
            OperationId(1),
            EntityId(999_999),
            SequenceDraft {
                name: "Ghost".into()
            }
        ),
        Err(StorageError::ForeignKey { .. })
    ));
}

// Mirrors "returns sequence with commands preloaded" and "returns error for
// non-existent sequence".
#[test]
fn get_sequence_returns_commands_or_not_found() {
    let (_dir, db, path) = database();
    let train = seed_train(&path, "Class 66");
    let sequence = db
        .create_sequence(
            OperationId(1),
            train,
            SequenceDraft {
                name: "Door Open".into(),
            },
        )
        .unwrap()
        .record;
    db.add_sequence_command(
        OperationId(2),
        sequence.id,
        command("Horn.InputValue", 1.0, 0),
    )
    .unwrap();
    let fetched = db.get_sequence(sequence.id).unwrap().unwrap();
    assert_eq!(fetched.name, "Door Open");
    assert_eq!(db.sequence_commands(sequence.id).unwrap().len(), 1);
    assert!(db.get_sequence(EntityId(999_999)).unwrap().is_none());
}

// Mirrors "returns all sequences for a train", "returns sequences ordered by
// name", and "does not return sequences from other trains".
#[test]
fn list_sequences_scoped_and_ordered_by_name() {
    let (_dir, db, path) = database();
    let train1 = seed_train(&path, "Class 66");
    let train2 = seed_train(&path, "Class 43");
    db.create_sequence(
        OperationId(1),
        train1,
        SequenceDraft {
            name: "Zebra".into(),
        },
    )
    .unwrap();
    db.create_sequence(
        OperationId(2),
        train1,
        SequenceDraft {
            name: "Alpha".into(),
        },
    )
    .unwrap();
    db.create_sequence(
        OperationId(3),
        train2,
        SequenceDraft {
            name: "Bell".into(),
        },
    )
    .unwrap();
    let names: Vec<String> = db
        .list_sequences(train1)
        .unwrap()
        .into_iter()
        .map(|s| s.name)
        .collect();
    assert_eq!(names, ["Alpha", "Zebra"]);
}

// Mirrors "sets commands with auto-assigned positions".
#[test]
fn set_sequence_commands_assigns_positions() {
    let (_dir, db, path) = database();
    let train = seed_train(&path, "Class 66");
    let sequence = db
        .create_sequence(
            OperationId(1),
            train,
            SequenceDraft {
                name: "Door Open".into(),
            },
        )
        .unwrap()
        .record;
    let created = db
        .set_sequence_commands(
            OperationId(2),
            sequence.id,
            vec![
                command("Key.InputValue", 1.0, 500),
                command("Rotary.InputValue", 0.5, 250),
                command("Open.InputValue", 1.0, 0),
            ],
        )
        .unwrap()
        .record;
    assert_eq!(
        created.iter().map(|c| c.position).collect::<Vec<_>>(),
        [0, 1, 2]
    );
    assert_eq!(created[0].delay_ms, 500);
    assert_eq!(created[1].delay_ms, 250);
    assert_eq!(created[2].delay_ms, 0);
}

// Mirrors "replaces existing commands".
#[test]
fn set_sequence_commands_replaces_existing() {
    let (_dir, db, path) = database();
    let train = seed_train(&path, "Class 66");
    let sequence = db
        .create_sequence(
            OperationId(1),
            train,
            SequenceDraft {
                name: "Door Open".into(),
            },
        )
        .unwrap()
        .record;
    db.set_sequence_commands(
        OperationId(2),
        sequence.id,
        vec![command("Old.InputValue", 1.0, 0)],
    )
    .unwrap();
    db.set_sequence_commands(
        OperationId(3),
        sequence.id,
        vec![command("New.InputValue", 2.0, 0)],
    )
    .unwrap();
    let commands = db.sequence_commands(sequence.id).unwrap();
    assert_eq!(commands.len(), 1);
    assert_eq!(commands[0].endpoint, "New.InputValue");
}

// Mirrors "rounds float values to 2 decimal places".
#[test]
fn set_sequence_commands_rounds_values() {
    let (_dir, db, path) = database();
    let train = seed_train(&path, "Class 66");
    let sequence = db
        .create_sequence(
            OperationId(1),
            train,
            SequenceDraft {
                name: "Test".into(),
            },
        )
        .unwrap()
        .record;
    let created = db
        .set_sequence_commands(
            OperationId(2),
            sequence.id,
            vec![command("Test.InputValue", 0.123456, 0), command("Test.Other", 0.015, 0)],
        )
        .unwrap()
        .record;
    assert_eq!(created[0].value, 0.12);
    // Float.round/2 tie behavior: 0.015 rounds to 0.01 (naive half-up gives 0.02).
    assert_eq!(created[1].value, 0.01);
}

// Extra coverage for the Ecto delay_ms bounds in SequenceCommand.changeset/1:
// an invalid draft must leave existing commands untouched (Repo.transaction
// rollback semantics of set_sequence_commands/2).
#[test]
fn set_sequence_commands_is_atomic_on_invalid_draft() {
    let (_dir, db, path) = database();
    let train = seed_train(&path, "Class 66");
    let sequence = db
        .create_sequence(
            OperationId(1),
            train,
            SequenceDraft {
                name: "Test".into(),
            },
        )
        .unwrap()
        .record;
    db.set_sequence_commands(
        OperationId(2),
        sequence.id,
        vec![command("Keep.InputValue", 1.0, 0)],
    )
    .unwrap();
    let revision = db.revision("trains").unwrap();
    assert!(matches!(
        db.set_sequence_commands(
            OperationId(3),
            sequence.id,
            vec![
                command("Good.InputValue", 1.0, 0),
                command("Bad.InputValue", 1.0, 60_001),
            ],
        ),
        Err(StorageError::Constraint { .. })
    ));
    let commands = db.sequence_commands(sequence.id).unwrap();
    assert_eq!(commands.len(), 1);
    assert_eq!(commands[0].endpoint, "Keep.InputValue");
    assert_eq!(db.revision("trains").unwrap(), revision);
    assert!(matches!(
        db.set_sequence_commands(OperationId(4), sequence.id, vec![command("  ", 1.0, 0)],),
        Err(StorageError::Constraint { .. })
    ));
}

// Mirrors "adds command at the end".
#[test]
fn add_sequence_command_appends_at_max_position_plus_one() {
    let (_dir, db, path) = database();
    let train = seed_train(&path, "Class 66");
    let sequence = db
        .create_sequence(
            OperationId(1),
            train,
            SequenceDraft {
                name: "Test".into(),
            },
        )
        .unwrap()
        .record;
    let first = db
        .add_sequence_command(
            OperationId(2),
            sequence.id,
            command("First.InputValue", 1.0, 0),
        )
        .unwrap()
        .record;
    let second = db
        .add_sequence_command(
            OperationId(3),
            sequence.id,
            command("Second.InputValue", 2.0, 0),
        )
        .unwrap()
        .record;
    assert_eq!(first.position, 0);
    assert_eq!(second.position, 1);
}

// Mirrors "deletes sequence and its commands": commands cascade.
#[test]
fn delete_sequence_cascades_commands() {
    let (_dir, db, path) = database();
    let train = seed_train(&path, "Class 66");
    let sequence = db
        .create_sequence(
            OperationId(1),
            train,
            SequenceDraft {
                name: "Test".into(),
            },
        )
        .unwrap()
        .record;
    db.set_sequence_commands(
        OperationId(2),
        sequence.id,
        vec![command("Test.InputValue", 1.0, 0)],
    )
    .unwrap();
    db.delete_sequence(OperationId(3), sequence.id).unwrap();
    assert!(db.get_sequence(sequence.id).unwrap().is_none());
    assert!(db.sequence_commands(sequence.id).unwrap().is_empty());
    assert!(matches!(
        db.delete_sequence(OperationId(4), sequence.id),
        Err(StorageError::NotFound)
    ));
}

// Train deletion cascades to sequences and their commands per the schema's
// ON DELETE CASCADE foreign keys (mirrors Ecto's FK cascades).
#[test]
fn deleting_train_cascades_sequences_and_commands() {
    let (_dir, db, path) = database();
    let train = seed_train(&path, "Class 66");
    let sequence = db
        .create_sequence(
            OperationId(1),
            train,
            SequenceDraft {
                name: "Test".into(),
            },
        )
        .unwrap()
        .record;
    db.set_sequence_commands(
        OperationId(2),
        sequence.id,
        vec![command("Test.InputValue", 1.0, 0)],
    )
    .unwrap();
    let connection = Connection::open(&path).unwrap();
    connection
        .execute("DELETE FROM trains WHERE id=?1", [train.0])
        .unwrap();
    drop(connection);
    assert!(db.get_sequence(sequence.id).unwrap().is_none());
    assert!(db.list_sequences(train).unwrap().is_empty());
}

// Mirrors update_sequence/2 through Sequence.changeset/1: rename keeps the
// same row and bumps exactly one revision.
#[test]
fn update_sequence_renames() {
    let (_dir, db, path) = database();
    let train = seed_train(&path, "Class 66");
    let sequence = db
        .create_sequence(OperationId(1), train, SequenceDraft { name: "Old".into() })
        .unwrap()
        .record;
    let updated = db
        .update_sequence(
            OperationId(2),
            sequence.id,
            SequencePatch {
                name: Some("New".into()),
            },
        )
        .unwrap()
        .record;
    assert_eq!(updated.name, "New");
    assert_eq!(db.get_sequence(sequence.id).unwrap().unwrap().name, "New");
    assert!(matches!(
        db.update_sequence(
            OperationId(3),
            sequence.id,
            SequencePatch {
                name: Some("".into())
            },
        ),
        Err(StorageError::Constraint { .. })
    ));
}

// Mirrors delete_sequence_command/1.
#[test]
fn delete_sequence_command_removes_only_that_command() {
    let (_dir, db, path) = database();
    let train = seed_train(&path, "Class 66");
    let sequence = db
        .create_sequence(
            OperationId(1),
            train,
            SequenceDraft {
                name: "Test".into(),
            },
        )
        .unwrap()
        .record;
    db.set_sequence_commands(
        OperationId(2),
        sequence.id,
        vec![command("A", 1.0, 0), command("B", 2.0, 0)],
    )
    .unwrap();
    let commands = db.sequence_commands(sequence.id).unwrap();
    db.delete_sequence_command(OperationId(3), commands[0].id)
        .unwrap();
    let remaining = db.sequence_commands(sequence.id).unwrap();
    assert_eq!(remaining.len(), 1);
    assert_eq!(remaining[0].endpoint, "B");
    assert!(matches!(
        db.delete_sequence_command(OperationId(4), commands[0].id),
        Err(StorageError::NotFound)
    ));
}
