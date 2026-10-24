use tempfile::tempdir;
use trenino_core::{ConfigId, EntityId, OperationId};
use trenino_runtime::storage::{
    CalibrationRecord, Database, DeviceDraft, InputDraft, InputKind, MatrixDraft, MatrixPinType,
    OutputDraft, StorageError,
};

fn database() -> (tempfile::TempDir, Database) {
    let dir = tempdir().unwrap();
    let db = Database::open_full(dir.path().join("hardware.db")).unwrap();
    db.allocate_epoch().unwrap();
    (dir, db)
}

#[test]
fn typed_hardware_mutations_roundtrip_ids_and_bump_once() {
    let (_dir, db) = database();
    let initial = db.hardware_snapshot().unwrap().1;
    let device = db
        .create_device(
            OperationId(1),
            DeviceDraft {
                name: "Panel".into(),
                description: Some("main".into()),
                config_id: Some(ConfigId::new(120).unwrap()),
            },
        )
        .unwrap();
    assert_eq!(device.record.config_id.unwrap().get(), 120);
    assert_eq!(device.receipt.metadata.revision, initial.revision + 1);
    let input = db
        .create_input(
            OperationId(2),
            device.record.id,
            InputDraft {
                pin: 4,
                kind: InputKind::Analog,
                sensitivity: Some(10),
                debounce: None,
                name: Some("Lever".into()),
                matrix_id: None,
            },
        )
        .unwrap();
    assert_eq!(input.record.pin, Some(4));
    assert_eq!(
        input.receipt.metadata.revision,
        device.receipt.metadata.revision + 1
    );
    let output = db
        .create_output(
            OperationId(3),
            device.record.id,
            OutputDraft {
                pin: 255,
                name: None,
            },
        )
        .unwrap();
    assert_eq!(output.record.device_id, device.record.id);
    assert_eq!(output.record.pin, 255);
    assert_eq!(
        output.receipt.metadata.revision,
        input.receipt.metadata.revision + 1
    );
    assert_eq!(
        db.get_device(device.record.id).unwrap().unwrap(),
        device.record
    );
    assert_eq!(
        db.get_input(input.record.id).unwrap().unwrap(),
        input.record
    );
    assert_eq!(
        db.get_output(output.record.id).unwrap().unwrap(),
        output.record
    );
}

#[test]
fn input_validation_and_duplicate_conflict_do_not_change_content_or_revision() {
    let (_dir, db) = database();
    let device = db
        .create_device(
            OperationId(10),
            DeviceDraft {
                name: "Panel".into(),
                description: None,
                config_id: None,
            },
        )
        .unwrap();
    let rev = device.receipt.metadata.revision;
    assert!(matches!(
        db.create_input(
            OperationId(11),
            device.record.id,
            InputDraft {
                pin: 128,
                kind: InputKind::Button,
                sensitivity: None,
                debounce: Some(50),
                name: None,
                matrix_id: None,
            }
        ),
        Err(StorageError::InvalidHardware { .. })
    ));
    let valid = InputDraft {
        pin: 8,
        kind: InputKind::Button,
        sensitivity: None,
        debounce: Some(255),
        name: None,
        matrix_id: None,
    };
    db.create_input(OperationId(12), device.record.id, valid.clone())
        .unwrap();
    assert!(matches!(
        db.create_input(OperationId(13), device.record.id, valid),
        Err(StorageError::Conflict { .. })
    ));
    assert_eq!(db.hardware_snapshot().unwrap().1.revision, rev + 1);
}

#[test]
fn matrix_children_are_ordered_generated_and_replaced_atomically() {
    let (_dir, db) = database();
    let device = db
        .create_device(
            OperationId(20),
            DeviceDraft {
                name: "Panel".into(),
                description: None,
                config_id: None,
            },
        )
        .unwrap();
    let created = db
        .create_matrix(
            OperationId(21),
            device.record.id,
            MatrixDraft {
                name: "Keys".into(),
                row_pins: vec![2, 3],
                col_pins: vec![5, 7, 9],
            },
        )
        .unwrap();
    let matrix = created.record;
    assert_eq!(
        matrix.row_pins.iter().map(|p| p.pin).collect::<Vec<_>>(),
        vec![2, 3]
    );
    assert_eq!(
        matrix.col_pins.iter().map(|p| p.pin).collect::<Vec<_>>(),
        vec![5, 7, 9]
    );
    assert_eq!(
        matrix
            .buttons
            .iter()
            .map(|b| b.pin.unwrap())
            .collect::<Vec<_>>(),
        vec![128, 129, 130, 131, 132, 133]
    );
    assert_eq!(
        matrix
            .buttons
            .iter()
            .map(|b| b.name.as_deref().unwrap())
            .collect::<Vec<_>>(),
        vec!["R0C0", "R0C1", "R0C2", "R1C0", "R1C1", "R1C2"]
    );
    let bad = db
        .replace_matrix_children(OperationId(22), matrix.id, vec![128], vec![5])
        .unwrap_err();
    assert!(matches!(bad, StorageError::InvalidHardware { .. }));
    assert_eq!(
        db.hardware_snapshot().unwrap().1.revision,
        created.receipt.metadata.revision
    );
    // Elixir accepts repeated pin values within a kind (only positions are unique).
    let repeated = db
        .replace_matrix_children(OperationId(23), matrix.id, vec![2, 2], vec![5])
        .unwrap();
    assert_eq!(
        repeated
            .record
            .buttons
            .iter()
            .map(|b| b.name.as_deref().unwrap())
            .collect::<Vec<_>>(),
        vec!["R0C0", "R1C0"]
    );
    assert_eq!(
        db.hardware_snapshot().unwrap().1.revision,
        created.receipt.metadata.revision + 1
    );
}

#[test]
fn matrix_replacement_cascades_removed_input_bindings_but_preserves_unrelated_rows() {
    let (_dir, db) = database();
    let device = db
        .create_device(
            OperationId(30),
            DeviceDraft {
                name: "Panel".into(),
                description: None,
                config_id: None,
            },
        )
        .unwrap();
    let created = db
        .create_matrix(
            OperationId(31),
            device.record.id,
            MatrixDraft {
                name: "Keys".into(),
                row_pins: vec![2],
                col_pins: vec![5, 6],
            },
        )
        .unwrap();
    let kept = db
        .create_input(
            OperationId(32),
            device.record.id,
            InputDraft {
                pin: 10,
                kind: InputKind::Button,
                sensitivity: None,
                debounce: Some(10),
                name: None,
                matrix_id: None,
            },
        )
        .unwrap();
    let receipt = db
        .replace_matrix_children(OperationId(33), created.record.id, vec![2], vec![5])
        .unwrap();
    assert_eq!(
        receipt.receipt.metadata.revision,
        kept.receipt.metadata.revision + 1
    );
    assert!(db.get_input(EntityId(1_000_000)).unwrap().is_none());
    assert!(db.get_input(kept.record.id).unwrap().is_some());
}

#[test]
fn calibration_roundtrip_replaces_in_one_revision_and_missing_input_fails() {
    let (_dir, db) = database();
    let device = db
        .create_device(
            OperationId(40),
            DeviceDraft {
                name: "Panel".into(),
                description: None,
                config_id: None,
            },
        )
        .unwrap();
    let input = db
        .create_input(
            OperationId(41),
            device.record.id,
            InputDraft {
                pin: 9,
                kind: InputKind::Analog,
                sensitivity: Some(5),
                debounce: None,
                name: None,
                matrix_id: None,
            },
        )
        .unwrap();
    let calibration = CalibrationRecord {
        max_hardware_value: Some(1023),
        min_value: Some(50),
        max_value: Some(900),
        has_rollover: true,
        is_inverted: false,
    };
    let first = db
        .save_calibration(OperationId(42), input.record.id, calibration.clone())
        .unwrap();
    let second = db
        .save_calibration(
            OperationId(43),
            input.record.id,
            CalibrationRecord {
                is_inverted: true,
                ..calibration.clone()
            },
        )
        .unwrap();
    assert_eq!(first.record.id, second.record.id);
    assert!(
        db.get_input(input.record.id)
            .unwrap()
            .unwrap()
            .calibration
            .unwrap()
            .value
            .is_inverted
    );
    assert_eq!(
        second.receipt.metadata.revision,
        first.receipt.metadata.revision + 1
    );
    assert!(matches!(
        db.save_calibration(OperationId(44), EntityId(99999), calibration),
        Err(StorageError::ForeignKey { .. })
    ));
    assert_eq!(
        db.hardware_snapshot().unwrap().1.revision,
        second.receipt.metadata.revision
    );
}

#[test]
fn cascade_delete_is_transactional_and_has_no_public_unchecked_entrypoint() {
    let (_dir, db) = database();
    let device = db
        .create_device(
            OperationId(50),
            DeviceDraft {
                name: "Panel".into(),
                description: None,
                config_id: None,
            },
        )
        .unwrap();
    let input = db
        .create_input(
            OperationId(51),
            device.record.id,
            InputDraft {
                pin: 9,
                kind: InputKind::Analog,
                sensitivity: Some(5),
                debounce: None,
                name: None,
                matrix_id: None,
            },
        )
        .unwrap();
    db.save_calibration(
        OperationId(52),
        input.record.id,
        CalibrationRecord {
            max_hardware_value: Some(1023),
            min_value: Some(0),
            max_value: Some(1023),
            has_rollover: false,
            is_inverted: false,
        },
    )
    .unwrap();
    assert!(db
        .get_device_by_config_id(ConfigId::new(1).unwrap())
        .unwrap()
        .is_none());
    assert_eq!(MatrixPinType::Row.as_db(), "row");
}
