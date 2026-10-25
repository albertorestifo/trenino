use trenino_core::OperationId;
use trenino_runtime::{
    preview::CapturedRange,
    storage::{trains::*, *},
};

#[test]
fn mapping_commit_recomputes_ranges_and_rolls_back_every_write_on_late_failure() {
    let dir = tempfile::tempdir().unwrap();
    let path = dir.path().join("mapping.sqlite");
    let db = Database::open_full(&path).unwrap();
    db.allocate_epoch().unwrap();
    let device = db
        .create_device(
            OperationId(1),
            DeviceDraft {
                name: "Panel".into(),
                description: None,
                config_id: None,
            },
        )
        .unwrap()
        .record;
    let input = db
        .create_input(
            OperationId(2),
            device.id,
            InputDraft {
                pin: 1,
                kind: InputKind::Analog,
                sensitivity: Some(5),
                debounce: None,
                name: None,
                matrix_id: None,
            },
        )
        .unwrap()
        .record;
    db.save_calibration(
        OperationId(3),
        input.id,
        CalibrationRecord {
            max_hardware_value: Some(1023),
            min_value: Some(0),
            max_value: Some(1000),
            has_rollover: false,
            is_inverted: false,
        },
    )
    .unwrap();
    let train = db
        .create_train(
            OperationId(4),
            TrainDraft {
                name: "Train".into(),
                description: None,
                identifiers: vec!["Train".into()],
            },
        )
        .unwrap()
        .record;
    let element = db
        .create_train_element(
            OperationId(5),
            train.id,
            ElementDraft {
                kind: ElementKind::Lever,
                name: "Throttle".into(),
            },
        )
        .unwrap()
        .record;
    let mut draft = LeverMappingDraft {
        element_id: element.id,
        lever_config_id: None,
        input_id: input.id,
        replace_binding: false,
        endpoints: LeverConfigDraft {
            min_endpoint: "Throttle.Min".into(),
            max_endpoint: "Throttle.Max".into(),
            value_endpoint: "Throttle.Value".into(),
            notch_count_endpoint: None,
            notch_index_endpoint: None,
            lever_type: None,
            inverted: false,
        },
        notches: vec![NotchDraft {
            index: 0,
            kind: NotchKind::Linear,
            value: None,
            min_value: Some(0.0),
            max_value: Some(1.0),
            input_min: Some(999.0),
            input_max: Some(999.0),
            sim_input_min: Some(0.0),
            sim_input_max: Some(1.0),
            description: None,
        }],
        captured_ranges: vec![CapturedRange {
            min: 0,
            max: 1000,
            sample_count: 10,
        }],
        auto_distribute: false,
        calibration_completed: false,
    };
    let before = (
        db.revision("trains").unwrap(),
        db.revision("bindings").unwrap(),
    );
    let fixture = rusqlite::Connection::open(&path).unwrap();
    fixture.execute_batch("CREATE TRIGGER reject_notch BEFORE INSERT ON train_lever_notches BEGIN SELECT RAISE(ABORT,'injected final write failure'); END;").unwrap();
    assert!(db
        .commit_lever_mapping(OperationId(6), draft.clone())
        .is_err());
    assert!(db
        .get_train_element(element.id)
        .unwrap()
        .unwrap()
        .lever_config
        .is_none());
    assert!(db
        .list_lever_bindings_for_train(train.id)
        .unwrap()
        .is_empty());
    assert_eq!(
        before,
        (
            db.revision("trains").unwrap(),
            db.revision("bindings").unwrap()
        )
    );
    fixture.execute_batch("DROP TRIGGER reject_notch").unwrap();
    let saved = db
        .commit_lever_mapping(OperationId(7), draft.clone())
        .unwrap()
        .record;
    assert!(
        saved.calibrated_at.is_none(),
        "manual notch save preserves legacy metadata"
    );
    assert_eq!(saved.notches[0].input_min, Some(0.0));
    assert_eq!(saved.notches[0].input_max, Some(1.0));
    assert_eq!(
        db.get_lever_binding(saved.id).unwrap().unwrap().input_id,
        input.id
    );
    assert_eq!(db.revision("trains").unwrap(), before.0 + 1);
    assert_eq!(db.revision("bindings").unwrap(), before.1 + 1);
    draft.lever_config_id = Some(saved.id);
    draft.endpoints.value_endpoint = "Throttle.NewValue".into();
    fixture.execute_batch("CREATE TRIGGER reject_notch BEFORE INSERT ON train_lever_notches BEGIN SELECT RAISE(ABORT,'injected edit failure'); END;").unwrap();
    assert!(db.commit_lever_mapping(OperationId(8), draft).is_err());
    assert_eq!(
        db.get_train_element(element.id)
            .unwrap()
            .unwrap()
            .lever_config
            .unwrap(),
        saved
    );
    fixture.execute_batch("DROP TRIGGER reject_notch").unwrap();
    let mut automatic = LeverMappingDraft {
        element_id: element.id,
        lever_config_id: Some(saved.id),
        input_id: input.id,
        replace_binding: false,
        endpoints: LeverConfigDraft {
            min_endpoint: saved.min_endpoint.clone(),
            max_endpoint: saved.max_endpoint.clone(),
            value_endpoint: saved.value_endpoint.clone(),
            notch_count_endpoint: None,
            notch_index_endpoint: None,
            lever_type: None,
            inverted: false,
        },
        notches: vec![NotchDraft {
            index: 0,
            kind: NotchKind::Linear,
            value: None,
            min_value: Some(0.0),
            max_value: Some(1.0),
            input_min: None,
            input_max: None,
            sim_input_min: Some(0.0),
            sim_input_max: Some(1.0),
            description: None,
        }],
        captured_ranges: vec![],
        auto_distribute: true,
        calibration_completed: true,
    };
    let calibrated = db
        .commit_lever_mapping(OperationId(9), automatic.clone())
        .unwrap()
        .record;
    assert!(calibrated.calibrated_at.is_some());
    automatic.calibration_completed = false;
    let manual = db
        .commit_lever_mapping(OperationId(10), automatic)
        .unwrap()
        .record;
    assert_eq!(manual.calibrated_at, calibrated.calibrated_at);
}
