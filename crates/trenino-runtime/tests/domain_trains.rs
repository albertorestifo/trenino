//! Integration tests for the "trains" domain topic. Each test mirrors the
//! corresponding coverage in the Elixir oracle `test/trenino/train_test.exs`
//! (plus boundary cases for rollback, ordering, and constraint semantics).
//!
//! Oracle sections not covered here (button bindings, sequences, scripts,
//! output/display bindings, lever input bindings) belong to other tracks.
use tempfile::tempdir;
use trenino_core::{EntityId, OperationId};
use trenino_runtime::storage::trains::*;
use trenino_runtime::storage::{Database, StorageError};

fn database() -> (tempfile::TempDir, Database) {
    let dir = tempdir().unwrap();
    let db = Database::open_full(dir.path().join("trains.db")).unwrap();
    db.allocate_epoch().unwrap();
    (dir, db)
}

fn train(db: &Database, name: &str, identifier: &str) -> TrainRecord {
    db.create_train(
        OperationId(1),
        TrainDraft {
            name: name.into(),
            description: None,
            identifiers: vec![identifier.into()],
        },
    )
    .unwrap()
    .record
}

fn lever_element(db: &Database, train_id: EntityId, name: &str) -> ElementRecord {
    db.create_train_element(
        OperationId(2),
        train_id,
        ElementDraft {
            kind: ElementKind::Lever,
            name: name.into(),
        },
    )
    .unwrap()
    .record
}

fn config_draft() -> LeverConfigDraft {
    LeverConfigDraft {
        min_endpoint: "CurrentDrivableActor/Throttle.MinValue".into(),
        max_endpoint: "CurrentDrivableActor/Throttle.MaxValue".into(),
        value_endpoint: "CurrentDrivableActor/Throttle.InputValue".into(),
        notch_count_endpoint: None,
        notch_index_endpoint: None,
        lever_type: None,
        inverted: false,
    }
}

fn gate(value: f64) -> NotchDraft {
    NotchDraft {
        index: 0,
        kind: NotchKind::Gate,
        value: Some(value),
        min_value: None,
        max_value: None,
        input_min: None,
        input_max: None,
        sim_input_min: None,
        sim_input_max: None,
        description: None,
    }
}

// --- create_train (mirrors "create_train/1" describe block) ----------------

#[test]
fn create_train_with_valid_attributes() {
    let (_dir, db) = database();
    let created = db
        .create_train(
            OperationId(1),
            TrainDraft {
                name: "Class 66".into(),
                description: Some("Freight locomotive".into()),
                identifiers: vec!["BR_Class_66".into()],
            },
        )
        .unwrap();
    // Mirrors: "creates a train with valid attributes"
    assert_eq!(created.record.name, "Class 66");
    assert_eq!(created.record.identifiers, ["BR_Class_66"]);
    assert_eq!(
        created.record.description.as_deref(),
        Some("Freight locomotive")
    );
    assert_eq!(created.receipt.metadata.revision, 1);
}

#[test]
fn create_train_without_description() {
    // Mirrors: "creates a train without description"
    let (_dir, db) = database();
    let record = train(&db, "Class 66", "BR_Class_66");
    assert_eq!(record.description, None);
}

#[test]
fn create_train_rejects_missing_name() {
    // Mirrors: "returns error changeset with missing name"
    let (_dir, db) = database();
    let err = db
        .create_train(
            OperationId(1),
            TrainDraft {
                name: String::new(),
                description: None,
                identifiers: vec!["BR_Class_66".into()],
            },
        )
        .unwrap_err();
    assert!(matches!(err, StorageError::Constraint { .. }));
    assert!(db.list_trains().unwrap().is_empty());
}

#[test]
fn create_train_rejects_missing_identifiers() {
    // Mirrors: "returns error changeset with missing identifier"
    let (_dir, db) = database();
    let err = db
        .create_train(
            OperationId(1),
            TrainDraft {
                name: "Class 66".into(),
                description: None,
                identifiers: vec![],
            },
        )
        .unwrap_err();
    assert!(matches!(err, StorageError::Constraint { .. }));
}

#[test]
fn create_train_enforces_unique_identifier_globally() {
    // Mirrors: "enforces unique identifier"
    let (_dir, db) = database();
    train(&db, "Class 66", "BR_Class_66");
    let err = db
        .create_train(
            OperationId(2),
            TrainDraft {
                name: "Other".into(),
                description: None,
                identifiers: vec!["BR_Class_66".into()],
            },
        )
        .unwrap_err();
    assert!(matches!(err, StorageError::Conflict { .. }));
}

#[test]
fn create_train_rejects_duplicate_identifiers_within_profile() {
    // Mirrors Train.changeset's "must be unique within a train profile".
    let (_dir, db) = database();
    let err = db
        .create_train(
            OperationId(1),
            TrainDraft {
                name: "Class 66".into(),
                description: None,
                identifiers: vec!["BR_Class_66".into(), "BR_Class_66".into()],
            },
        )
        .unwrap_err();
    assert!(matches!(err, StorageError::Constraint { .. }));
}

#[test]
fn create_train_trims_identifiers() {
    // Mirrors TrainIdentifier.changeset's update_change trim.
    let (_dir, db) = database();
    let record = db
        .create_train(
            OperationId(1),
            TrainDraft {
                name: "Class 66".into(),
                description: None,
                identifiers: vec!["  BR_Class_66  ".into()],
            },
        )
        .unwrap()
        .record;
    assert_eq!(record.identifiers, ["BR_Class_66"]);
}

// --- get_train / get_train_by_identifier -----------------------------------

#[test]
fn get_train_returns_train_by_id() {
    // Mirrors: "returns train by id" + "preloads associations when requested"
    let (_dir, db) = database();
    let record = train(&db, "Class 66", "BR_Class_66");
    lever_element(&db, record.id, "Throttle");
    let found = db.get_train(record.id).unwrap().unwrap();
    assert_eq!(found.id, record.id);
    assert_eq!(found.name, "Class 66");
    assert_eq!(found.elements.len(), 1);
}

#[test]
fn get_train_not_found() {
    // Mirrors: "returns error when train not found"
    let (_dir, db) = database();
    assert_eq!(db.get_train(EntityId(999_999)).unwrap(), None);
}

#[test]
fn get_train_by_identifier_matches_prefix() {
    // Mirrors: "returns train with matching identifier" and the prefix
    // matching semantics documented on get_train_by_identifier/1
    // ("RVM_FSN_DB_BR423-A" matches stored "RVM_FSN_DB_BR423").
    let (_dir, db) = database();
    let record = train(&db, "Class 66", "RVM_FSN_DB_BR423");
    match db
        .get_train_by_identifier("RVM_FSN_DB_BR423-A".into())
        .unwrap()
    {
        IdentifierMatch::Unique(found) => assert_eq!(found.id, record.id),
        other => panic!("expected unique match, got {other:?}"),
    }
    // Multiple identifiers on one profile behave as equivalent matchers.
    db.update_train(
        OperationId(2),
        record.id,
        TrainPatch {
            name: None,
            description: None,
            identifiers: Some(vec!["RVM_FSN_DB_BR423".into(), "RVM_OTHER_DB_BR423".into()]),
        },
    )
    .unwrap();
    assert!(matches!(
        db.get_train_by_identifier("RVM_OTHER_DB_BR423-B".into())
            .unwrap(),
        IdentifierMatch::Unique(_)
    ));
}

#[test]
fn get_train_by_identifier_not_found() {
    // Mirrors: "returns error when no train matches identifier"
    let (_dir, db) = database();
    assert!(matches!(
        db.get_train_by_identifier("NonExistent".into()).unwrap(),
        IdentifierMatch::NotFound
    ));
}

#[test]
fn get_train_by_identifier_ambiguous() {
    // Mirrors the {:error, {:multiple_matches, trains}} branch.
    let (_dir, db) = database();
    train(&db, "A", "RVM_FSN_DB_BR423");
    train(&db, "B", "RVM_FSN_DB_BR42");
    assert!(matches!(
        db.get_train_by_identifier("RVM_FSN_DB_BR423-A".into()).unwrap(),
        IdentifierMatch::Ambiguous(matches) if matches.len() == 2
    ));
}

#[test]
fn get_train_by_identifier_preloads_elements_with_lever_config() {
    // Mirrors: "preloads elements with lever_config"
    let (_dir, db) = database();
    let record = train(&db, "Class 66", "BR_Class_66");
    let element = lever_element(&db, record.id, "Throttle");
    db.create_lever_config(OperationId(3), element.id, config_draft())
        .unwrap();
    match db.get_train_by_identifier("BR_Class_66".into()).unwrap() {
        IdentifierMatch::Unique(found) => {
            assert_eq!(found.elements.len(), 1);
            assert!(found.elements[0].lever_config.is_some());
        }
        other => panic!("expected unique match, got {other:?}"),
    }
}

// --- update_train / delete_train / list_trains ------------------------------

#[test]
fn update_train_name_and_description() {
    // Mirrors: "updates train with valid attributes" + "updates description"
    let (_dir, db) = database();
    let record = train(&db, "Original", "BR_Class_66");
    let updated = db
        .update_train(
            OperationId(2),
            record.id,
            TrainPatch {
                name: Some("Updated".into()),
                description: Some(Some("New description".into())),
                identifiers: None,
            },
        )
        .unwrap()
        .record;
    assert_eq!(updated.name, "Updated");
    assert_eq!(updated.description.as_deref(), Some("New description"));
}

#[test]
fn update_train_replaces_identifiers() {
    // Mirrors cast_assoc(on_replace: :delete) replacement semantics.
    let (_dir, db) = database();
    let record = train(&db, "Original", "BR_Class_66");
    let updated = db
        .update_train(
            OperationId(2),
            record.id,
            TrainPatch {
                name: None,
                description: None,
                identifiers: Some(vec!["BR_Class_43".into()]),
            },
        )
        .unwrap()
        .record;
    assert_eq!(updated.identifiers, ["BR_Class_43"]);
    assert!(matches!(
        db.get_train_by_identifier("BR_Class_66".into()).unwrap(),
        IdentifierMatch::NotFound
    ));
}

#[test]
fn update_train_rejects_empty_identifiers_and_name() {
    let (_dir, db) = database();
    let record = train(&db, "Original", "BR_Class_66");
    for patch in [
        TrainPatch {
            name: Some(String::new()),
            description: None,
            identifiers: None,
        },
        TrainPatch {
            name: None,
            description: None,
            identifiers: Some(vec![]),
        },
    ] {
        assert!(db.update_train(OperationId(2), record.id, patch).is_err());
    }
    assert_eq!(
        db.get_train(record.id).unwrap().unwrap().identifiers,
        ["BR_Class_66"]
    );
}

#[test]
fn delete_train_cascades() {
    // Mirrors: "deletes train" + "cascade deletes associated elements"
    let (_dir, db) = database();
    let record = train(&db, "Class 66", "BR_Class_66");
    let element = lever_element(&db, record.id, "Throttle");
    let config = db
        .create_lever_config(OperationId(3), element.id, config_draft())
        .unwrap()
        .record;
    db.save_lever_calibration(OperationId(4), config.id, vec![gate(0.0), gate(1.0)])
        .unwrap();

    db.delete_train(OperationId(5), record.id).unwrap();
    assert_eq!(db.get_train(record.id).unwrap(), None);
    assert!(db.list_train_elements(record.id).unwrap().is_empty());
    assert_eq!(db.get_lever_config_for_element(element.id).unwrap(), None);
}

#[test]
fn list_trains_ordered_by_name() {
    // Mirrors: "returns empty list when no trains exist" + "returns trains ordered by name"
    let (_dir, db) = database();
    assert!(db.list_trains().unwrap().is_empty());
    train(&db, "Zebra", "id1");
    train(&db, "Alpha", "id2");
    train(&db, "Beta", "id3");
    let names: Vec<_> = db
        .list_trains()
        .unwrap()
        .into_iter()
        .map(|t| t.name)
        .collect();
    assert_eq!(names, ["Alpha", "Beta", "Zebra"]);
}

// --- elements (mirrors create_element/list_elements/get_element/delete_element) ---

#[test]
fn create_element_lever_and_button() {
    // Mirrors: "creates element with valid attributes" and button variants
    let (_dir, db) = database();
    let record = train(&db, "Class 66", "BR_Class_66");
    let lever = lever_element(&db, record.id, "Throttle");
    assert_eq!(lever.train_id, record.id);
    assert_eq!(lever.kind, ElementKind::Lever);
    let button = db
        .create_train_element(
            OperationId(3),
            record.id,
            ElementDraft {
                kind: ElementKind::Button,
                name: "Horn".into(),
            },
        )
        .unwrap()
        .record;
    assert_eq!(button.kind, ElementKind::Button);
}

#[test]
fn create_element_rejects_missing_name_and_unknown_train() {
    // Mirrors: "returns error changeset with missing name" and the
    // foreign_key_constraint(:train_id) on a missing train.
    let (_dir, db) = database();
    let record = train(&db, "Class 66", "BR_Class_66");
    let err = db
        .create_train_element(
            OperationId(2),
            record.id,
            ElementDraft {
                kind: ElementKind::Lever,
                name: String::new(),
            },
        )
        .unwrap_err();
    assert!(matches!(err, StorageError::Constraint { .. }));
    let err = db
        .create_train_element(
            OperationId(3),
            EntityId(999_999),
            ElementDraft {
                kind: ElementKind::Lever,
                name: "Throttle".into(),
            },
        )
        .unwrap_err();
    assert!(matches!(err, StorageError::ForeignKey { .. }));
}

#[test]
fn list_elements_ordered_by_name() {
    // Mirrors: "returns elements ordered by name" + "preloads lever_config with notches"
    let (_dir, db) = database();
    let record = train(&db, "Class 66", "BR_Class_66");
    for name in ["Throttle", "Brake", "Reverser"] {
        lever_element(&db, record.id, name);
    }
    let names: Vec<_> = db
        .list_train_elements(record.id)
        .unwrap()
        .into_iter()
        .map(|e| e.name)
        .collect();
    assert_eq!(names, ["Brake", "Reverser", "Throttle"]);

    let element = db
        .list_train_elements(record.id)
        .unwrap()
        .into_iter()
        .find(|e| e.name == "Throttle")
        .unwrap();
    let config = db
        .create_lever_config(OperationId(4), element.id, config_draft())
        .unwrap()
        .record;
    db.save_lever_calibration(OperationId(5), config.id, vec![gate(0.0), gate(1.0)])
        .unwrap();
    let reloaded = db
        .list_train_elements(record.id)
        .unwrap()
        .into_iter()
        .find(|e| e.name == "Throttle")
        .unwrap();
    let config = reloaded.lever_config.unwrap();
    assert_eq!(config.notches.len(), 2);
}

#[test]
fn get_element_and_delete_element_cascades() {
    // Mirrors: "returns element by id", "returns error when element not found",
    // "deletes element" — plus lever config/notch cascade via schema FKs.
    let (_dir, db) = database();
    let record = train(&db, "Class 66", "BR_Class_66");
    let element = lever_element(&db, record.id, "Throttle");
    assert_eq!(
        db.get_train_element(element.id).unwrap().unwrap().id,
        element.id
    );
    assert_eq!(db.get_train_element(EntityId(999_999)).unwrap(), None);

    let config = db
        .create_lever_config(OperationId(3), element.id, config_draft())
        .unwrap()
        .record;
    let notch = db
        .create_notch(OperationId(4), config.id, gate(0.0))
        .unwrap()
        .record;
    db.delete_train_element(OperationId(5), element.id).unwrap();
    assert_eq!(db.get_train_element(element.id).unwrap(), None);
    assert_eq!(db.get_lever_config_for_element(element.id).unwrap(), None);
    assert_eq!(db.get_train_element(element.id).unwrap(), None);
    // notch cascade is not directly observable through the public API
    // (its config is gone), so verify through the config reload:
    let _ = notch;
}

// --- lever configs -----------------------------------------------------------

#[test]
fn create_lever_config_valid_and_missing_fields() {
    // Mirrors: "creates lever config with valid attributes" +
    // "returns error changeset with missing required fields"
    let (_dir, db) = database();
    let record = train(&db, "Class 66", "BR_Class_66");
    let element = lever_element(&db, record.id, "Throttle");
    let created = db
        .create_lever_config(OperationId(3), element.id, config_draft())
        .unwrap()
        .record;
    assert_eq!(created.element_id, element.id);
    assert_eq!(
        created.min_endpoint,
        "CurrentDrivableActor/Throttle.MinValue"
    );
    assert_eq!(created.calibrated_at, None);

    let empty = LeverConfigDraft::default();
    let err = db
        .create_lever_config(OperationId(4), element.id, empty)
        .unwrap_err();
    assert!(matches!(err, StorageError::Constraint { .. }));
}

#[test]
fn lever_config_notch_endpoints_must_be_paired() {
    // Mirrors LeverConfig.validate_notch_endpoints/1.
    let (_dir, db) = database();
    let record = train(&db, "Class 66", "BR_Class_66");
    let element = lever_element(&db, record.id, "Throttle");
    for (count, index) in [
        (Some("Count".to_string()), None),
        (None, Some("Index".to_string())),
    ] {
        let mut draft = config_draft();
        draft.notch_count_endpoint = count;
        draft.notch_index_endpoint = index;
        assert!(db
            .create_lever_config(OperationId(3), element.id, draft)
            .is_err());
    }
    let mut draft = config_draft();
    draft.notch_count_endpoint = Some("Count".into());
    draft.notch_index_endpoint = Some("Index".into());
    assert!(db
        .create_lever_config(OperationId(4), element.id, draft)
        .is_ok());
}

#[test]
fn lever_config_unique_per_element() {
    // Mirrors LeverConfig's unique_constraint(:element_id).
    let (_dir, db) = database();
    let record = train(&db, "Class 66", "BR_Class_66");
    let element = lever_element(&db, record.id, "Throttle");
    db.create_lever_config(OperationId(3), element.id, config_draft())
        .unwrap();
    let err = db
        .create_lever_config(OperationId(4), element.id, config_draft())
        .unwrap_err();
    assert!(matches!(err, StorageError::Conflict { .. }));
}

#[test]
fn get_lever_config_by_element() {
    // Mirrors: "returns lever config by element id", "returns error when no
    // config exists", "preloads notches"
    let (_dir, db) = database();
    let record = train(&db, "Class 66", "BR_Class_66");
    let element = lever_element(&db, record.id, "Throttle");
    assert_eq!(db.get_lever_config_for_element(element.id).unwrap(), None);
    let config = db
        .create_lever_config(OperationId(3), element.id, config_draft())
        .unwrap()
        .record;
    db.save_lever_calibration(OperationId(4), config.id, vec![gate(0.0), gate(1.0)])
        .unwrap();
    let found = db
        .get_lever_config_for_element(element.id)
        .unwrap()
        .unwrap();
    assert_eq!(found.id, config.id);
    assert_eq!(found.notches.len(), 2);
}

#[test]
fn update_lever_config_merges_and_validates() {
    let (_dir, db) = database();
    let record = train(&db, "Class 66", "BR_Class_66");
    let element = lever_element(&db, record.id, "Throttle");
    let config = db
        .create_lever_config(OperationId(3), element.id, config_draft())
        .unwrap()
        .record;

    let updated = db
        .update_lever_config(
            OperationId(4),
            config.id,
            LeverConfigPatch {
                min_endpoint: Some("Other/Min".into()),
                inverted: Some(true),
                ..LeverConfigPatch::default()
            },
        )
        .unwrap()
        .record;
    assert_eq!(updated.min_endpoint, "Other/Min");
    assert!(updated.inverted);
    assert_eq!(
        updated.value_endpoint,
        "CurrentDrivableActor/Throttle.InputValue"
    );

    // Unbalanced notch endpoints on update are rejected and change nothing.
    let err = db
        .update_lever_config(
            OperationId(5),
            config.id,
            LeverConfigPatch {
                notch_count_endpoint: Some(Some("Count".into())),
                ..LeverConfigPatch::default()
            },
        )
        .unwrap_err();
    assert!(matches!(err, StorageError::Constraint { .. }));
    assert_eq!(
        db.get_lever_config_for_element(element.id)
            .unwrap()
            .unwrap()
            .notch_count_endpoint,
        None
    );
}

// --- save_calibration / save_notches (atomic bulk replace) -------------------

#[test]
fn save_calibration_sets_calibrated_at_and_indexes() {
    // Mirrors: "saves notches and sets calibrated_at"
    let (_dir, db) = database();
    let record = train(&db, "Class 66", "BR_Class_66");
    let element = lever_element(&db, record.id, "Throttle");
    let config = db
        .create_lever_config(OperationId(3), element.id, config_draft())
        .unwrap()
        .record;

    let updated = db
        .save_lever_calibration(
            OperationId(4),
            config.id,
            vec![
                NotchDraft {
                    description: Some("Off".into()),
                    ..gate(0.0)
                },
                NotchDraft {
                    kind: NotchKind::Linear,
                    value: Some(0.5),
                    min_value: Some(0.0),
                    max_value: Some(1.0),
                    ..gate(9.9)
                },
                NotchDraft {
                    description: Some("Full".into()),
                    ..gate(1.0)
                },
            ],
        )
        .unwrap()
        .record;
    assert!(updated.calibrated_at.is_some());
    let mut notches = updated.notches;
    notches.sort_by_key(|n| n.index);
    assert_eq!(notches.len(), 3);
    assert_eq!(notches[0].kind, NotchKind::Gate);
    assert_eq!(notches[0].value, Some(0.0));
    assert_eq!(notches[0].description.as_deref(), Some("Off"));
    assert_eq!(notches[0].index, 0);
    assert_eq!(notches[1].kind, NotchKind::Linear);
    assert_eq!(notches[1].value, Some(0.5));
    assert_eq!(notches[1].min_value, Some(0.0));
    assert_eq!(notches[1].max_value, Some(1.0));
    assert_eq!(notches[2].description.as_deref(), Some("Full"));
    assert_eq!(notches[2].index, 2);
}

#[test]
fn save_calibration_replaces_existing_notches() {
    // Mirrors: "replaces existing notches"
    let (_dir, db) = database();
    let record = train(&db, "Class 66", "BR_Class_66");
    let element = lever_element(&db, record.id, "Throttle");
    let config = db
        .create_lever_config(OperationId(3), element.id, config_draft())
        .unwrap()
        .record;
    db.save_lever_calibration(OperationId(4), config.id, vec![gate(0.0), gate(1.0)])
        .unwrap();
    let updated = db
        .save_lever_calibration(
            OperationId(5),
            config.id,
            vec![gate(0.0), gate(0.5), gate(1.0)],
        )
        .unwrap()
        .record;
    assert_eq!(updated.notches.len(), 3);
}

#[test]
fn save_calibration_rolls_back_atomically_on_invalid_notch() {
    // Boundary case: one invalid notch aborts the whole replacement — the
    // prior notches survive and no trains revision is consumed.
    let (_dir, db) = database();
    let record = train(&db, "Class 66", "BR_Class_66");
    let element = lever_element(&db, record.id, "Throttle");
    let config = db
        .create_lever_config(OperationId(3), element.id, config_draft())
        .unwrap()
        .record;
    let before = db
        .save_lever_calibration(OperationId(4), config.id, vec![gate(0.0), gate(1.0)])
        .unwrap();
    // Linear notch missing max_value fails Notch validations.
    let bad = NotchDraft {
        kind: NotchKind::Linear,
        min_value: Some(0.0),
        max_value: None,
        ..gate(0.5)
    };
    let err = db
        .save_lever_calibration(OperationId(5), config.id, vec![gate(0.0), bad])
        .unwrap_err();
    assert!(matches!(err, StorageError::Constraint { .. }));
    let after = db
        .get_lever_config_for_element(element.id)
        .unwrap()
        .unwrap();
    assert_eq!(after.notches.len(), 2);
    assert_eq!(after.calibrated_at, before.record.calibrated_at);
    assert_eq!(
        db.trains_snapshot().unwrap().1.revision,
        before.receipt.metadata.revision
    );
}

#[test]
fn save_notches_replaces_without_calibrated_at() {
    // Mirrors save_notches/2: same bulk replace, no calibrated_at timestamp.
    let (_dir, db) = database();
    let record = train(&db, "Class 66", "BR_Class_66");
    let element = lever_element(&db, record.id, "Throttle");
    let config = db
        .create_lever_config(OperationId(3), element.id, config_draft())
        .unwrap()
        .record;
    let saved = db
        .save_notches(OperationId(4), config.id, vec![gate(0.0), gate(1.0)])
        .unwrap()
        .record;
    assert_eq!(saved.calibrated_at, None);
    assert_eq!(saved.notches.len(), 2);
    // Replace with a single notch.
    let saved = db
        .save_notches(OperationId(5), config.id, vec![gate(0.25)])
        .unwrap()
        .record;
    assert_eq!(saved.notches.len(), 1);
    assert_eq!(saved.notches[0].index, 0);
    assert_eq!(saved.calibrated_at, None);
}

// --- individual notch operations ---------------------------------------------

#[test]
fn create_notch_validates_and_rounds() {
    // Mirrors Notch.changeset validations + round_float_fields/2.
    let (_dir, db) = database();
    let record = train(&db, "Class 66", "BR_Class_66");
    let element = lever_element(&db, record.id, "Throttle");
    let config = db
        .create_lever_config(OperationId(3), element.id, config_draft())
        .unwrap()
        .record;

    // Gate without value.
    let bad = NotchDraft {
        value: None,
        ..gate(0.0)
    };
    assert!(db.create_notch(OperationId(4), config.id, bad).is_err());
    // Input range outside 0.0-1.0.
    let bad = NotchDraft {
        input_min: Some(-0.1),
        input_max: Some(0.5),
        ..gate(0.0)
    };
    assert!(db.create_notch(OperationId(5), config.id, bad).is_err());
    // Half-set pair.
    let bad = NotchDraft {
        input_min: Some(0.1),
        ..gate(0.0)
    };
    assert!(db.create_notch(OperationId(6), config.id, bad).is_err());
    // Sim range min > max.
    let bad = NotchDraft {
        sim_input_min: Some(0.8),
        sim_input_max: Some(0.2),
        ..gate(0.0)
    };
    assert!(db.create_notch(OperationId(7), config.id, bad).is_err());
    // Sim ranges may exceed 1.0 (ThrottleAndBrake levers go -1.0..1.0).
    let ok = NotchDraft {
        sim_input_min: Some(-0.86),
        sim_input_max: Some(1.2),
        value: Some(0.126), // rounded to 0.13
        ..gate(0.0)
    };
    let created = db
        .create_notch(OperationId(8), config.id, ok)
        .unwrap()
        .record;
    assert_eq!(created.value, Some(0.13));
    assert_eq!(created.sim_input_min, Some(-0.86));
    assert_eq!(created.sim_input_max, Some(1.2));
    // Duplicate (lever_config_id, index).
    let dup = NotchDraft {
        index: 0,
        ..gate(1.0)
    };
    let err = db.create_notch(OperationId(9), config.id, dup).unwrap_err();
    assert!(matches!(err, StorageError::Conflict { .. }));
    // Unknown lever config.
    let err = db
        .create_notch(OperationId(10), EntityId(999_999), gate(0.0))
        .unwrap_err();
    assert!(matches!(err, StorageError::ForeignKey { .. }));
}

#[test]
fn update_notch_and_description() {
    // Mirrors: "updates notch description" + "clears notch description with nil"
    let (_dir, db) = database();
    let record = train(&db, "Class 66", "BR_Class_66");
    let element = lever_element(&db, record.id, "Throttle");
    let config = db
        .create_lever_config(OperationId(3), element.id, config_draft())
        .unwrap()
        .record;
    let notch = db
        .save_lever_calibration(OperationId(4), config.id, vec![gate(0.0)])
        .unwrap()
        .record
        .notches
        .remove(0);

    let updated = db
        .update_notch_description(OperationId(5), notch.id, Some("Idle Position".into()))
        .unwrap()
        .record;
    assert_eq!(updated.description.as_deref(), Some("Idle Position"));
    let cleared = db
        .update_notch_description(OperationId(6), notch.id, None)
        .unwrap()
        .record;
    assert_eq!(cleared.description, None);

    // Field update merged with stored values.
    let updated = db
        .update_notch(
            OperationId(7),
            notch.id,
            NotchPatch {
                input_min: Some(Some(0.0)),
                input_max: Some(Some(0.5)),
                ..NotchPatch::default()
            },
        )
        .unwrap()
        .record;
    assert_eq!(updated.input_min, Some(0.0));
    assert_eq!(updated.input_max, Some(0.5));
    assert_eq!(updated.value, Some(0.0));
    // Invalid merged result (input_min > stored input_max) rolls back.
    let err = db
        .update_notch(
            OperationId(8),
            notch.id,
            NotchPatch {
                input_min: Some(Some(0.8)),
                ..NotchPatch::default()
            },
        )
        .unwrap_err();
    assert!(matches!(err, StorageError::Constraint { .. }));
}

#[test]
fn delete_notch() {
    // Mirrors delete_notch/1.
    let (_dir, db) = database();
    let record = train(&db, "Class 66", "BR_Class_66");
    let element = lever_element(&db, record.id, "Throttle");
    let config = db
        .create_lever_config(OperationId(3), element.id, config_draft())
        .unwrap()
        .record;
    let notch = db
        .save_lever_calibration(OperationId(4), config.id, vec![gate(0.0), gate(1.0)])
        .unwrap()
        .record
        .notches
        .remove(0);
    db.delete_notch(OperationId(5), notch.id).unwrap();
    let config = db
        .get_lever_config_for_element(element.id)
        .unwrap()
        .unwrap();
    assert_eq!(config.notches.len(), 1);
    assert!(db.delete_notch(OperationId(6), notch.id).is_err());
}

// --- update_notch_input_ranges ------------------------------------------------

#[test]
fn update_notch_input_ranges_batch_and_inverted() {
    // Mirrors update_notch_input_ranges/3 incl. the :inverted option.
    let (_dir, db) = database();
    let record = train(&db, "Class 66", "BR_Class_66");
    let element = lever_element(&db, record.id, "Throttle");
    let config = db
        .create_lever_config(OperationId(3), element.id, config_draft())
        .unwrap()
        .record;
    let saved = db
        .save_lever_calibration(
            OperationId(4),
            config.id,
            vec![gate(0.0), gate(0.5), gate(1.0)],
        )
        .unwrap()
        .record;
    let mut notches = saved.notches;
    notches.sort_by_key(|n| n.index);
    let updated = db
        .update_notch_input_ranges(
            OperationId(5),
            config.id,
            vec![
                NotchInputRange {
                    notch_id: notches[0].id,
                    input_min: 0.0,
                    input_max: 0.33,
                },
                NotchInputRange {
                    notch_id: notches[1].id,
                    input_min: 0.334,
                    input_max: 0.67,
                },
            ],
            Some(true),
        )
        .unwrap()
        .record;
    assert!(updated.inverted);
    let mut reloaded = updated.notches;
    reloaded.sort_by_key(|n| n.index);
    assert_eq!(reloaded[0].input_min, Some(0.0));
    assert_eq!(reloaded[0].input_max, Some(0.33));
    // 0.334 rounds to 0.33 on write.
    assert_eq!(reloaded[1].input_min, Some(0.33));
    assert_eq!(reloaded[1].input_max, Some(0.67));
}

#[test]
fn update_notch_input_ranges_unknown_notch_rolls_back() {
    // Mirrors the {:not_found, notch_id} branch: the whole batch rolls back.
    let (_dir, db) = database();
    let record = train(&db, "Class 66", "BR_Class_66");
    let element = lever_element(&db, record.id, "Throttle");
    let config = db
        .create_lever_config(OperationId(3), element.id, config_draft())
        .unwrap()
        .record;
    let saved = db
        .save_lever_calibration(OperationId(4), config.id, vec![gate(0.0)])
        .unwrap();
    let notch = &saved.record.notches[0];
    let err = db
        .update_notch_input_ranges(
            OperationId(5),
            config.id,
            vec![
                NotchInputRange {
                    notch_id: notch.id,
                    input_min: 0.0,
                    input_max: 0.5,
                },
                NotchInputRange {
                    notch_id: EntityId(999_999),
                    input_min: 0.5,
                    input_max: 1.0,
                },
            ],
            None,
        )
        .unwrap_err();
    assert!(matches!(err, StorageError::Constraint { .. }));
    let config = db
        .get_lever_config_for_element(element.id)
        .unwrap()
        .unwrap();
    assert_eq!(config.notches[0].input_min, None);
    assert_eq!(
        db.trains_snapshot().unwrap().1.revision,
        saved.receipt.metadata.revision
    );
}

// --- auto_distribute_input_ranges / validate_notch_ranges ----------------------

#[test]
fn auto_distribute_evenly_divides_input_range() {
    // Mirrors auto_distribute_input_ranges/1 (step = 1/count, 2dp rounding).
    let (_dir, db) = database();
    let record = train(&db, "Class 66", "BR_Class_66");
    let element = lever_element(&db, record.id, "Throttle");
    let config = db
        .create_lever_config(OperationId(3), element.id, config_draft())
        .unwrap()
        .record;
    let saved = db
        .save_lever_calibration(
            OperationId(4),
            config.id,
            vec![gate(0.0), gate(0.25), gate(0.5), gate(1.0)],
        )
        .unwrap();
    let distributed = db
        .auto_distribute_input_ranges(OperationId(5), config.id)
        .unwrap()
        .record;
    let mut notches = distributed.notches;
    notches.sort_by_key(|n| n.index);
    let mins: Vec<_> = notches.iter().map(|n| n.input_min).collect();
    let maxs: Vec<_> = notches.iter().map(|n| n.input_max).collect();
    assert_eq!(mins, [Some(0.0), Some(0.25), Some(0.5), Some(0.75)]);
    assert_eq!(maxs, [Some(0.25), Some(0.5), Some(0.75), Some(1.0)]);
    // Full coverage validates.
    assert_eq!(
        db.validate_notch_ranges(config.id).unwrap(),
        Some(RangesValidation::Valid)
    );
    let _ = saved;
}

#[test]
fn auto_distribute_with_no_notches_is_read_only() {
    // Mirrors do_auto_distribute's empty-notches clause: no writes occur.
    let (_dir, db) = database();
    let record = train(&db, "Class 66", "BR_Class_66");
    let element = lever_element(&db, record.id, "Throttle");
    let config = db
        .create_lever_config(OperationId(3), element.id, config_draft())
        .unwrap();
    let revision_before = db.trains_snapshot().unwrap().1.revision;
    let result = db
        .auto_distribute_input_ranges(OperationId(4), config.record.id)
        .unwrap();
    assert!(result.record.notches.is_empty());
    assert_eq!(result.receipt.metadata.revision, revision_before);
    assert!(db
        .auto_distribute_input_ranges(OperationId(5), EntityId(999_999))
        .is_err());
}

#[test]
fn validate_notch_ranges_detects_gaps() {
    // Mirrors validate_notch_ranges/1's {:error, :gaps_detected, gaps}.
    let (_dir, db) = database();
    let record = train(&db, "Class 66", "BR_Class_66");
    let element = lever_element(&db, record.id, "Throttle");
    let config = db
        .create_lever_config(OperationId(3), element.id, config_draft())
        .unwrap()
        .record;
    // No ranges at all: the whole 0.0-1.0 span is a gap.
    db.save_lever_calibration(OperationId(4), config.id, vec![gate(0.0)])
        .unwrap();
    assert_eq!(
        db.validate_notch_ranges(config.id).unwrap(),
        Some(RangesValidation::Gaps(vec![(0.0, 1.0)]))
    );
    // Partial coverage leaves a trailing gap.
    db.update_notch_input_ranges(
        OperationId(5),
        config.id,
        vec![NotchInputRange {
            notch_id: db
                .get_lever_config_for_element(element.id)
                .unwrap()
                .unwrap()
                .notches[0]
                .id,
            input_min: 0.0,
            input_max: 0.5,
        }],
        None,
    )
    .unwrap();
    assert_eq!(
        db.validate_notch_ranges(config.id).unwrap(),
        Some(RangesValidation::Gaps(vec![(0.5, 1.0)]))
    );
    // Overlap tolerance: adjacent ranges within the 0.001 epsilon are fine.
    db.save_lever_calibration(OperationId(6), config.id, vec![gate(0.0), gate(1.0)])
        .unwrap();
    let reloaded = db
        .get_lever_config_for_element(element.id)
        .unwrap()
        .unwrap();
    let mut notches = reloaded.notches;
    notches.sort_by_key(|n| n.index);
    db.update_notch_input_ranges(
        OperationId(7),
        config.id,
        vec![
            NotchInputRange {
                notch_id: notches[0].id,
                input_min: 0.0,
                input_max: 0.5,
            },
            NotchInputRange {
                notch_id: notches[1].id,
                input_min: 0.501,
                input_max: 1.0,
            },
        ],
        None,
    )
    .unwrap();
    assert_eq!(
        db.validate_notch_ranges(config.id).unwrap(),
        Some(RangesValidation::Valid)
    );
    // Unknown config.
    assert_eq!(db.validate_notch_ranges(EntityId(999_999)).unwrap(), None);
}

// --- create/update_lever_config_with_analysis ----------------------------------

#[test]
fn lever_config_with_analysis_creates_config_and_notches() {
    // Mirrors create_lever_config_with_analysis/3: analyzer input ranges land
    // in sim_input_min/max, lever_type comes from the analysis.
    let (_dir, db) = database();
    let record = train(&db, "Class 66", "BR_Class_66");
    let element = lever_element(&db, record.id, "Throttle");
    let analysis = LeverAnalysis {
        lever_type: LeverType::Discrete,
        suggested_notches: vec![
            SuggestedNotch {
                index: Some(0),
                kind: NotchKind::Gate,
                value: Some(0.0),
                min_value: None,
                max_value: None,
                description: Some("N".into()),
                input_min: Some(0.0),
                input_max: Some(0.25),
            },
            SuggestedNotch {
                index: Some(1),
                kind: NotchKind::Gate,
                value: Some(1.0),
                min_value: None,
                max_value: None,
                description: None,
                input_min: Some(0.75),
                input_max: Some(1.0),
            },
        ],
    };
    let created = db
        .create_lever_config_with_analysis(
            OperationId(3),
            element.id,
            config_draft(),
            analysis.clone(),
        )
        .unwrap()
        .record;
    assert_eq!(created.lever_type, Some(LeverType::Discrete));
    assert_eq!(created.notches.len(), 2);
    assert_eq!(created.notches[0].sim_input_min, Some(0.0));
    assert_eq!(created.notches[0].sim_input_max, Some(0.25));
    assert_eq!(created.notches[1].sim_input_max, Some(1.0));
    // Hardware input ranges stay unset until notch mapping.
    assert_eq!(created.notches[0].input_min, None);

    // Update path replaces notches and rewrites the lever type in one commit.
    let analysis = LeverAnalysis {
        lever_type: LeverType::Hybrid,
        suggested_notches: vec![SuggestedNotch {
            index: Some(0),
            kind: NotchKind::Gate,
            value: Some(0.5),
            min_value: None,
            max_value: None,
            description: None,
            input_min: Some(0.4),
            input_max: Some(0.6),
        }],
    };
    let updated = db
        .update_lever_config_with_analysis(
            OperationId(4),
            created.id,
            LeverConfigPatch::default(),
            analysis,
        )
        .unwrap()
        .record;
    assert_eq!(updated.lever_type, Some(LeverType::Hybrid));
    assert_eq!(updated.notches.len(), 1);
    assert_eq!(updated.notches[0].value, Some(0.5));
}

#[test]
fn lever_config_with_analysis_rolls_back_on_bad_suggestion() {
    // Boundary: an invalid suggested notch aborts config creation entirely.
    let (_dir, db) = database();
    let record = train(&db, "Class 66", "BR_Class_66");
    let element = lever_element(&db, record.id, "Throttle");
    let analysis = LeverAnalysis {
        lever_type: LeverType::Continuous,
        suggested_notches: vec![
            SuggestedNotch {
                index: Some(0),
                kind: NotchKind::Gate,
                value: Some(0.0),
                min_value: None,
                max_value: None,
                description: None,
                input_min: None,
                input_max: None,
            },
            SuggestedNotch {
                index: Some(1),
                kind: NotchKind::Linear,
                value: None,
                min_value: None, // missing required linear bounds
                max_value: None,
                description: None,
                input_min: None,
                input_max: None,
            },
        ],
    };
    let err = db
        .create_lever_config_with_analysis(OperationId(3), element.id, config_draft(), analysis)
        .unwrap_err();
    assert!(matches!(err, StorageError::Constraint { .. }));
    assert_eq!(db.get_lever_config_for_element(element.id).unwrap(), None);
}

// --- revision discipline --------------------------------------------------------

#[test]
fn every_mutation_bumps_the_trains_topic_once() {
    let (_dir, db) = database();
    let created = db
        .create_train(
            OperationId(1),
            TrainDraft {
                name: "Class 66".into(),
                description: None,
                identifiers: vec!["BR_Class_66".into()],
            },
        )
        .unwrap();
    assert_eq!(created.receipt.metadata.revision, 1);
    let element = db
        .create_train_element(
            OperationId(2),
            created.record.id,
            ElementDraft {
                kind: ElementKind::Lever,
                name: "Throttle".into(),
            },
        )
        .unwrap();
    assert_eq!(element.receipt.metadata.revision, 2);
    let config = db
        .create_lever_config(OperationId(3), element.record.id, config_draft())
        .unwrap();
    assert_eq!(config.receipt.metadata.revision, 3);
    let saved = db
        .save_lever_calibration(OperationId(4), config.record.id, vec![gate(0.0), gate(1.0)])
        .unwrap();
    assert_eq!(saved.receipt.metadata.revision, 4);
    // Failed mutations consume no revision.
    assert!(db
        .create_train(
            OperationId(5),
            TrainDraft {
                name: String::new(),
                description: None,
                identifiers: vec!["X".into()],
            },
        )
        .is_err());
    assert_eq!(db.trains_snapshot().unwrap().1.revision, 4);
}

// Mirrors train_test.exs "list_button_elements/1" describe (3 tests):
// only button elements, ordered by name, empty when none exist.
fn button_element(db: &Database, op: u128, train_id: EntityId, name: &str) -> ElementRecord {
    db.create_train_element(
        OperationId(op),
        train_id,
        ElementDraft {
            kind: ElementKind::Button,
            name: name.into(),
        },
    )
    .unwrap()
    .record
}

#[test]
fn list_button_elements_returns_only_button_elements() {
    // Oracle: train_test.exs "returns only button elements".
    let (_dir, db) = database();
    let train = train(&db, "Class 66", "BR_Class_66");
    lever_element(&db, train.id, "Throttle");
    button_element(&db, 3, train.id, "Horn");
    button_element(&db, 4, train.id, "Bell");

    let elements = db.list_button_elements(train.id).unwrap();
    assert_eq!(elements.len(), 2);
    assert!(elements.iter().all(|e| e.kind == ElementKind::Button));
}

#[test]
fn list_button_elements_returns_elements_ordered_by_name() {
    // Oracle: train_test.exs "returns elements ordered by name".
    let (_dir, db) = database();
    let train = train(&db, "Class 66", "BR_Class_66");
    button_element(&db, 2, train.id, "Horn");
    button_element(&db, 3, train.id, "Bell");
    button_element(&db, 4, train.id, "Wiper");

    let names = db
        .list_button_elements(train.id)
        .unwrap()
        .into_iter()
        .map(|e| e.name)
        .collect::<Vec<_>>();
    assert_eq!(names, ["Bell", "Horn", "Wiper"]);
}

#[test]
fn list_button_elements_returns_empty_list_when_no_buttons() {
    // Oracle: train_test.exs "returns empty list when no button elements exist".
    let (_dir, db) = database();
    let train = train(&db, "Class 66", "BR_Class_66");
    lever_element(&db, train.id, "Throttle");
    assert!(db.list_button_elements(train.id).unwrap().is_empty());
}

// Ecto validate_required treats whitespace-only names as missing (verified
// against the live oracle: Train/Element changesets with name " " are invalid
// with "can't be blank") — parity audit P2-20.
#[test]
fn train_and_element_names_must_not_be_whitespace_only() {
    let (_dir, db) = database();
    assert!(matches!(
        db.create_train(
            OperationId(1),
            TrainDraft {
                name: "   ".into(),
                description: None,
                identifiers: vec!["BR_Class_66".into()],
            },
        ),
        Err(StorageError::Constraint { .. })
    ));
    let train = train(&db, "Class 66", "BR_Class_66");
    assert!(matches!(
        db.update_train(
            OperationId(2),
            train.id,
            TrainPatch {
                name: Some(" ".into()),
                ..TrainPatch::default()
            },
        ),
        Err(StorageError::Constraint { .. })
    ));
    assert!(matches!(
        db.create_train_element(
            OperationId(3),
            train.id,
            ElementDraft {
                kind: ElementKind::Button,
                name: "\t".into(),
            },
        ),
        Err(StorageError::Constraint { .. })
    ));
}
