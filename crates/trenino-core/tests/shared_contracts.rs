use trenino_core::hardware::{self, DeviceConfiguration};
use trenino_core::ConfigId;

#[test]
fn root_config_id_is_the_hardware_configuration_id_type() {
    let configuration = DeviceConfiguration {
        inputs: vec![],
        matrices: vec![],
        modules: vec![hardware::Module::Ht16k33 {
            address: 0x70,
            brightness: 5,
            num_digits: 4,
        }],
    };
    let id: ConfigId = serde_json::from_str("2147483647").unwrap();
    let messages = hardware::build_configuration(&configuration, id).unwrap();
    assert!(matches!(
        messages[0],
        hardware::protocol::Message::ConfigureHt16k33 {
            config_id: 2147483647,
            ..
        }
    ));
}
