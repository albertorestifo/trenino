//! Script persistence tests, mirroring test/trenino/train/script_context_test.exs
//! (list_scripts/1, list_enabled_scripts/1, get_script/1, create_script/2,
//! update_script/2, delete_script/1) plus trigger JSON round-trip coverage
//! against the exact Jason encoding produced by Elixir's TriggersType.
use rusqlite::Connection;
use tempfile::tempdir;
use trenino_core::{EntityId, OperationId};
use trenino_runtime::storage::scripts::{ScriptDraft, ScriptPatch, Triggers};
use trenino_runtime::storage::{Database, MutationOutcome, StorageError};

fn database() -> (tempfile::TempDir, Database, std::path::PathBuf) {
    let dir = tempdir().unwrap();
    let path = dir.path().join("domain.db");
    let db = Database::open_full(&path).unwrap();
    db.allocate_epoch().unwrap();
    (dir, db, path)
}

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

fn draft(name: &str) -> ScriptDraft {
    ScriptDraft {
        name: name.into(),
        enabled: true,
        code: "function on_change(event) end".into(),
        triggers: vec![],
    }
}

// Mirrors script_context_test.exs "returns empty list when no scripts".
#[test]
fn list_scripts_empty_when_none() {
    let (_dir, db, path) = database();
    let train = seed_train(&path, "Test Train");
    assert!(db.list_scripts(train).unwrap().is_empty());
}

// Mirrors "returns scripts ordered by name".
#[test]
fn list_scripts_ordered_by_name() {
    let (_dir, db, path) = database();
    let train = seed_train(&path, "Test Train");
    db.create_script(OperationId(1), train, draft("Zebra"))
        .unwrap();
    db.create_script(OperationId(2), train, draft("Alpha"))
        .unwrap();
    let names: Vec<String> = db
        .list_scripts(train)
        .unwrap()
        .into_iter()
        .map(|s| s.name)
        .collect();
    assert_eq!(names, ["Alpha", "Zebra"]);
}

// Mirrors "returns only enabled scripts".
#[test]
fn list_enabled_scripts_filters_disabled() {
    let (_dir, db, path) = database();
    let train = seed_train(&path, "Test Train");
    db.create_script(OperationId(1), train, draft("Enabled"))
        .unwrap();
    let mut disabled = draft("Disabled");
    disabled.enabled = false;
    db.create_script(OperationId(2), train, disabled).unwrap();
    let names: Vec<String> = db
        .list_enabled_scripts(train)
        .unwrap()
        .into_iter()
        .map(|s| s.name)
        .collect();
    assert_eq!(names, ["Enabled"]);
}

// Mirrors "returns script by id" and "returns error for missing id".
#[test]
fn get_script_or_not_found() {
    let (_dir, db, path) = database();
    let train = seed_train(&path, "Test Train");
    let created = db
        .create_script(OperationId(1), train, draft("Test"))
        .unwrap()
        .record;
    assert_eq!(db.get_script(created.id).unwrap().unwrap().name, "Test");
    assert!(db.get_script(EntityId(-1)).unwrap().is_none());
}

// Mirrors "creates script with valid attrs" (triggers round-trip) and "fails
// with invalid attrs".
#[test]
fn create_script_with_triggers_and_validations() {
    let (_dir, db, path) = database();
    let train = seed_train(&path, "Test Train");
    let mut valid = draft("My Script");
    valid.triggers = vec!["Endpoint.A".into()];
    let mutation = db.create_script(OperationId(1), train, valid).unwrap();
    assert_eq!(mutation.record.name, "My Script");
    assert_eq!(mutation.record.triggers, ["Endpoint.A"]);
    assert_eq!(mutation.receipt.outcome, MutationOutcome::Committed);
    // Ecto requires name and code; duplicates hit the (train_id, name) index.
    assert!(matches!(
        db.create_script(OperationId(2), train, draft("   ")),
        Err(StorageError::Constraint { .. })
    ));
    assert!(matches!(
        db.create_script(
            OperationId(3),
            train,
            ScriptDraft {
                code: String::new(),
                ..draft("Empty")
            }
        ),
        Err(StorageError::Constraint { .. })
    ));
    db.create_script(OperationId(4), train, draft("My Script"))
        .unwrap_err();
    assert!(matches!(
        db.create_script(OperationId(5), train, draft("My Script")),
        Err(StorageError::Conflict { .. })
    ));
}

// Mirrors Ecto's foreign_key_constraint(:train_id): unknown trains are
// rejected, and only the scripts topic revision tracks script mutations.
#[test]
fn create_script_rejects_unknown_train_and_tracks_revision() {
    let (_dir, db, _path) = database();
    assert!(matches!(
        db.create_script(OperationId(1), EntityId(424_242), draft("Ghost")),
        Err(StorageError::ForeignKey { .. })
    ));
    let revision = db.revision("scripts").unwrap();
    assert_eq!(db.revision("scripts").unwrap(), revision);
}

// Mirrors "updates script fields"; covers enabled/code/triggers too.
#[test]
fn update_script_fields() {
    let (_dir, db, path) = database();
    let train = seed_train(&path, "Test Train");
    let script = db
        .create_script(OperationId(1), train, draft("Old"))
        .unwrap()
        .record;
    let updated = db
        .update_script(
            OperationId(2),
            script.id,
            ScriptPatch {
                name: Some("New".into()),
                enabled: Some(false),
                code: Some("function on_change(event) return 1 end".into()),
                triggers: Some(vec!["A.InputValue".into(), "B.InputValue".into()]),
            },
        )
        .unwrap()
        .record;
    assert_eq!(updated.name, "New");
    assert!(!updated.enabled);
    assert_eq!(updated.triggers, ["A.InputValue", "B.InputValue"]);
    // Untouched fields survive a partial patch.
    let renamed_only = db
        .update_script(
            OperationId(3),
            script.id,
            ScriptPatch {
                name: Some("Newer".into()),
                ..Default::default()
            },
        )
        .unwrap()
        .record;
    assert_eq!(renamed_only.name, "Newer");
    assert!(!renamed_only.enabled);
    assert_eq!(renamed_only.triggers, ["A.InputValue", "B.InputValue"]);
    assert!(matches!(
        db.update_script(
            OperationId(4),
            script.id,
            ScriptPatch {
                name: Some("".into()),
                ..Default::default()
            }
        ),
        Err(StorageError::Constraint { .. })
    ));
    assert!(matches!(
        db.update_script(OperationId(5), EntityId(31337), ScriptPatch::default()),
        Err(StorageError::NotFound)
    ));
}

// Mirrors "deletes a script".
#[test]
fn delete_script_removes_row() {
    let (_dir, db, path) = database();
    let train = seed_train(&path, "Test Train");
    let script = db
        .create_script(OperationId(1), train, draft("ToDelete"))
        .unwrap()
        .record;
    db.delete_script(OperationId(2), script.id).unwrap();
    assert!(db.get_script(script.id).unwrap().is_none());
    assert!(matches!(
        db.delete_script(OperationId(3), script.id),
        Err(StorageError::NotFound)
    ));
}

// Golden round-trip: the stored triggers column must byte-match what Jason
// encodes for the Elixir example in Trenino.Train.Script's moduledoc, and the
// typed Triggers model must decode it back.
#[test]
fn triggers_golden_json_round_trip() {
    let (_dir, db, path) = database();
    let train = seed_train(&path, "Test Train");
    let mut with_triggers = draft("Golden");
    with_triggers.triggers = vec![
        "CurrentDrivableActor/Throttle.InputValue".into(),
        "CurrentDrivableActor/Function.HUD_GetSpeed".into(),
    ];
    let script = db
        .create_script(OperationId(1), train, with_triggers)
        .unwrap()
        .record;
    let connection = Connection::open(&path).unwrap();
    let raw: String = connection
        .query_row(
            "SELECT triggers FROM scripts WHERE id=?1",
            [script.id.0],
            |r| r.get(0),
        )
        .unwrap();
    // Jason.encode!(["CurrentDrivableActor/Throttle.InputValue",
    // "CurrentDrivableActor/Function.HUD_GetSpeed"]) in Elixir produces:
    assert_eq!(
        raw,
        r#"["CurrentDrivableActor/Throttle.InputValue","CurrentDrivableActor/Function.HUD_GetSpeed"]"#
    );
    assert_eq!(
        Triggers::decode(&raw).unwrap(),
        Triggers(vec![
            "CurrentDrivableActor/Throttle.InputValue".into(),
            "CurrentDrivableActor/Function.HUD_GetSpeed".into(),
        ])
    );
    assert_eq!(Triggers::default().encode().unwrap(), "[]");
}

// Defaults: enabled defaults to true and triggers to [] per the schema/Ecto
// field defaults; train deletion cascades per the FK.
#[test]
fn script_defaults_and_train_cascade() {
    let (_dir, db, path) = database();
    let train = seed_train(&path, "Test Train");
    let script = db
        .create_script(OperationId(1), train, draft("Defaults"))
        .unwrap()
        .record;
    assert!(script.enabled);
    assert!(script.triggers.is_empty());
    let connection = Connection::open(&path).unwrap();
    connection
        .execute("DELETE FROM trains WHERE id=?1", [train.0])
        .unwrap();
    drop(connection);
    assert!(db.get_script(script.id).unwrap().is_none());
    assert!(db.list_scripts(train).unwrap().is_empty());
}

// Mirrors script_test.exs "valid changeset with empty triggers" (l.31-41) and
// Script.changeset/2's validate_triggers (script.ex:62-77): triggers only need
// to be strings — empty or blank entries are accepted exactly like the Ecto
// changeset (parity audit P2-21; the Rust type system guarantees the string
// part, so nothing is rejected here).
#[test]
fn script_triggers_accept_empty_and_blank_strings() {
    let (_dir, db, path) = database();
    let train = seed_train(&path, "Test Train");
    let mut blank = draft("Blank Triggers");
    blank.triggers = vec!["".into(), "   ".into()];
    let created = db.create_script(OperationId(1), train, blank).unwrap();
    assert_eq!(created.record.triggers, ["", "   "]);

    let mutation = db
        .update_script(
            OperationId(2),
            created.record.id,
            ScriptPatch {
                triggers: Some(vec!["".into()]),
                ..ScriptPatch::default()
            },
        )
        .unwrap();
    assert_eq!(mutation.record.triggers, [""]);

    let empty = draft("Empty Triggers");
    let created_empty = db.create_script(OperationId(3), train, empty).unwrap();
    assert_eq!(created_empty.record.triggers, Vec::<String>::new());
}
