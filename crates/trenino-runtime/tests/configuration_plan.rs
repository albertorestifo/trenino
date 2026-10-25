use trenino_core::hardware::protocol::Message;
use trenino_core::{ConfigId, OperationId};
use trenino_runtime::{
    hardware::plan::configuration_request,
    storage::{Database, DeviceDraft, InputDraft, InputKind, MatrixDraft},
};
#[test]
fn stored_plan_uses_only_physical_packets_but_resolves_virtual_matrix_inputs() {
    let dir = tempfile::tempdir().unwrap();
    let db = Database::open_full(dir.path().join("plan.db")).unwrap();
    db.allocate_epoch().unwrap();
    let device = db
        .create_device(
            OperationId(1),
            DeviceDraft {
                name: "Desk".into(),
                description: None,
                config_id: Some(ConfigId::new(123).unwrap()),
            },
        )
        .unwrap()
        .record;
    assert!(configuration_request(&db, device.id, "PORT", 9).is_err());
    let button = db
        .create_input(
            OperationId(2),
            device.id,
            InputDraft {
                pin: 4,
                kind: InputKind::Button,
                sensitivity: None,
                debounce: Some(7),
                name: None,
                matrix_id: None,
            },
        )
        .unwrap()
        .record;
    let matrix = db
        .create_matrix(
            OperationId(3),
            device.id,
            MatrixDraft {
                name: "Keys".into(),
                row_pins: vec![5],
                col_pins: vec![6, 7],
            },
        )
        .unwrap()
        .record;
    let request = configuration_request(&db, device.id, "PORT", 9).unwrap();
    assert_eq!(request.config_id.get(), 123);
    assert_eq!(request.generation, 9);
    assert_eq!(request.port_name, "PORT");
    assert_eq!(request.messages.len(), 2);
    assert!(matches!(
        request.messages[0],
        Message::ConfigureButton {
            pin: 4,
            total_parts: 2,
            part_number: 0,
            debounce: 7,
            ..
        }
    ));
    assert!(
        matches!(&request.messages[1],Message::ConfigureMatrix{row_pins,col_pins,total_parts:2,part_number:1,..} if row_pins==&vec![5] && col_pins==&vec![6,7])
    );
    assert_eq!(request.mappings.len(), 3);
    assert!(request
        .mappings
        .iter()
        .any(|(pin, id)| *pin == 4 && id.input_id == button.id));
    for input in matrix.buttons {
        assert!(request
            .mappings
            .iter()
            .any(|(pin, id)| Some(*pin as i32) == input.pin && id.input_id == input.id));
    }
}
