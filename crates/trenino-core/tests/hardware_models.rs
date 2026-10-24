use trenino_core::hardware::{
    build_configuration, AnalogInput, ButtonInput, ConfigId, DeviceConfiguration, InputDetection,
    InputKind, Matrix, Module,
};

#[test]
fn configuration_orders_inputs_then_matrices_then_modules() {
    let c = DeviceConfiguration {
        inputs: vec![
            ButtonInput {
                pin: 2,
                debounce: 4,
            }
            .into(),
            AnalogInput {
                pin: 1,
                sensitivity: 10,
            }
            .into(),
        ],
        matrices: vec![Matrix {
            row_pins: vec![3],
            col_pins: vec![4],
        }],
        modules: vec![Module::Ht16k33 {
            address: 112,
            brightness: 8,
            num_digits: 4,
        }],
    };
    let messages = build_configuration(&c, ConfigId::new(77).unwrap()).unwrap();
    assert_eq!(messages.len(), 4);
    assert!(matches!(
        messages[0],
        trenino_core::hardware::protocol::Message::ConfigureAnalog { pin: 1, .. }
    ));
    assert!(matches!(
        messages[1],
        trenino_core::hardware::protocol::Message::ConfigureButton { pin: 2, .. }
    ));
    assert!(matches!(
        messages[2],
        trenino_core::hardware::protocol::Message::ConfigureMatrix { .. }
    ));
    assert!(matches!(
        messages[3],
        trenino_core::hardware::protocol::Message::ConfigureHt16k33 { .. }
    ));
}

#[test]
fn boundaries_and_detection_threshold_match_legacy() {
    assert!(AnalogInput {
        pin: 127,
        sensitivity: 1
    }
    .validate()
    .is_ok());
    assert!(AnalogInput {
        pin: 128,
        sensitivity: 1
    }
    .validate()
    .is_err());
    assert!(AnalogInput {
        pin: 1,
        sensitivity: 0
    }
    .validate()
    .is_err());
    assert!(AnalogInput {
        pin: 1,
        sensitivity: 10
    }
    .validate()
    .is_ok());
    assert!(ButtonInput {
        pin: 1,
        debounce: 255
    }
    .validate()
    .is_ok());
    assert!(ButtonInput {
        pin: 1,
        debounce: 256
    }
    .validate()
    .is_err());
    assert!(Matrix::virtual_pin(1, 0, 128).is_none());
    assert_eq!(Matrix::virtual_pin(0, 0, 1), Some(128));
    assert_eq!(Matrix::virtual_pin(0, 127, 128), Some(255));
    let mut detector = InputDetection::new(InputKind::Analog);
    assert!(!detector.observe(1, 10, InputKind::Analog));
    assert!(!detector.observe(1, 60, InputKind::Analog));
    assert!(detector.observe(1, 61, InputKind::Analog));
}

#[test]
fn i2c_and_display_parameters_keep_legacy_ranges() {
    assert_eq!(Module::parse_address("0x70"), Some(112));
    assert_eq!(Module::parse_address("0X70"), None);
    assert_eq!(Module::parse_address("255"), Some(255));
    assert_eq!(Module::parse_address("256"), None);
    assert!(Module::Ht16k33 {
        address: 255,
        brightness: 15,
        num_digits: 8
    }
    .validate()
    .is_ok());
    assert!(Module::Ht16k33 {
        address: 256,
        brightness: 8,
        num_digits: 4
    }
    .validate()
    .is_err());
    assert!(Module::Ht16k33 {
        address: 112,
        brightness: 16,
        num_digits: 4
    }
    .validate()
    .is_err());
}
#[test]
fn segment_encoding_keeps_digit_order_padding_dot_and_unknown_behavior() {
    use trenino_core::hardware::ht16k33::encode_string;
    assert_eq!(
        encode_string("1.2", 4, true, true, false),
        vec![0x86, 0x5b, 0, 0]
    );
    assert_eq!(
        encode_string("4", 4, true, false, true),
        vec![0, 0, 0, 0x66]
    );
    assert_eq!(
        encode_string("~", 4, false, false, false),
        vec![0, 0, 0, 0, 0, 0, 0, 0]
    );
}
