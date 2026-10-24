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
#[test]
fn builder_rejects_duplicate_physical_pins_i2c_addresses_and_matrix_virtual_ranges() {
    use trenino_core::hardware::{
        build_configuration, AnalogInput, ButtonInput, ConfigId, DeviceConfiguration, Matrix,
        Module,
    };
    let id = ConfigId::new(9).unwrap();
    let base = DeviceConfiguration {
        inputs: vec![
            AnalogInput {
                pin: 1,
                sensitivity: 1,
            }
            .into(),
            ButtonInput {
                pin: 1,
                debounce: 0,
            }
            .into(),
        ],
        matrices: vec![],
        modules: vec![],
    };
    assert!(build_configuration(&base, id).is_err());
    let duplicate_modules = DeviceConfiguration {
        inputs: vec![ButtonInput {
            pin: 1,
            debounce: 0,
        }
        .into()],
        matrices: vec![],
        modules: vec![
            Module::Ht16k33 {
                address: 112,
                brightness: 8,
                num_digits: 4,
            },
            Module::Ht16k33 {
                address: 112,
                brightness: 8,
                num_digits: 8,
            },
        ],
    };
    assert!(build_configuration(&duplicate_modules, id).is_err());
    let duplicate_virtual_ranges = DeviceConfiguration {
        inputs: vec![],
        matrices: vec![
            Matrix {
                row_pins: vec![1],
                col_pins: vec![2],
            },
            Matrix {
                row_pins: vec![3, 4],
                col_pins: vec![5],
            },
        ],
        modules: vec![],
    };
    assert!(build_configuration(&duplicate_virtual_ranges, id).is_err());
}

#[test]
fn matrix_axes_must_be_nonempty() {
    assert!(Matrix {
        row_pins: vec![],
        col_pins: vec![2]
    }
    .validate()
    .is_err());
    assert!(Matrix {
        row_pins: vec![1],
        col_pins: vec![]
    }
    .validate()
    .is_err());
}
#[test]
fn display_alignment_matches_legacy_for_dots_and_combining_graphemes() {
    use trenino_core::hardware::ht16k33::encode_string;
    assert_eq!(
        encode_string("1.2", 4, false, true, true),
        vec![0, 0, 0, 0, 6, 0, 0, 64]
    );
    assert_eq!(
        encode_string("e\u{301}1", 4, false, true, true),
        vec![0, 0, 0, 0, 251, 0, 0, 0]
    );
}
#[test]
fn detection_supports_button_press_and_release_and_type_filtering() {
    use trenino_core::hardware::{InputDetection, InputKind};
    let mut button = InputDetection::new(InputKind::Button);
    assert!(!button.observe(10, 0, InputKind::Button));
    assert!(button.observe(10, 1, InputKind::Button));
    let mut release = InputDetection::new(InputKind::Button);
    assert!(!release.observe(11, 1, InputKind::Button));
    assert!(release.observe(11, 0, InputKind::Button));
    let mut analog = InputDetection::new(InputKind::Analog);
    assert!(!analog.observe(20, 40, InputKind::Button));
    assert!(!analog.observe(20, 1, InputKind::Analog)); // filtered input type retains the first baseline
    assert!(analog.observe(20, 91, InputKind::Analog));
}
