//! Presence-aware top-level IPC patches. Unlike serde Option<Option<T>>,
//! this extractor preserves omitted, explicit null and a supplied value.
use serde::de::DeserializeOwned;
use tauri::ipc::{CommandArg, CommandItem, InvokeBody, InvokeError};

pub(super) struct NullableArg<T>(pub Option<Option<T>>);
impl<'de, R: tauri::Runtime, T: DeserializeOwned> CommandArg<'de, R> for NullableArg<T> {
    fn from_command(command: CommandItem<'de, R>) -> Result<Self, InvokeError> {
        match command.message.payload() {
            InvokeBody::Json(body) => match body.get(command.key) {
                None => Ok(Self(None)),
                Some(serde_json::Value::Null) => Ok(Self(Some(None))),
                Some(value) => serde_json::from_value(value.clone())
                    .map(|value| Self(Some(Some(value))))
                    .map_err(|error| {
                        tauri::Error::InvalidArgs(command.name, command.key, error).into()
                    }),
            },
            InvokeBody::Raw(_) => Err(InvokeError::from(
                "Expected a JSON object for patch arguments.",
            )),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::super::*;
    use serde_json::{json, Value};
    use tauri::test::MockRuntime;

    fn invoke(
        webview: &tauri::WebviewWindow<MockRuntime>,
        command: &str,
        body: Value,
    ) -> Result<Value, Value> {
        tauri::test::get_ipc_response(
            webview,
            tauri::webview::InvokeRequest {
                cmd: command.into(),
                callback: tauri::ipc::CallbackFn(0),
                error: tauri::ipc::CallbackFn(1),
                url: if cfg!(windows) {
                    "http://tauri.localhost"
                } else {
                    "tauri://localhost"
                }
                .parse()
                .unwrap(),
                body: tauri::ipc::InvokeBody::Json(body),
                headers: Default::default(),
                invoke_key: tauri::test::INVOKE_KEY.into(),
            },
        )
        .map(|body| body.deserialize::<Value>().unwrap())
    }
    #[test]
    fn real_configuration_and_train_commands_distinguish_missing_and_null() {
        let dir = tempfile::tempdir().unwrap();
        let state = RustAppState::empty();
        state
            .install(AppServices::open_full(dir.path().join("patch.db"), None).unwrap())
            .unwrap();
        let services = state.services().unwrap();
        let device = services
            .create_configuration_detail("Panel", Some("original".into()))
            .unwrap()
            .value
            .id;
        let train = services
            .create_train_entry("Train", Some("original".into()), vec!["unit".into()])
            .unwrap()
            .value
            .id;
        let app = tauri::test::mock_builder()
            .manage(state)
            .invoke_handler(tauri::generate_handler![
                ui_update_configuration,
                ui_update_train,
            ])
            .build(tauri::test::mock_context(tauri::test::noop_assets()))
            .unwrap();
        let webview = tauri::WebviewWindowBuilder::new(&app, "main", Default::default())
            .build()
            .unwrap();
        for (cmd, id) in [
            ("ui_update_configuration", device),
            ("ui_update_train", train),
        ] {
            invoke(
                &webview,
                cmd,
                json!({"id":id.0.to_string(),"name":"renamed"}),
            )
            .unwrap();
            let description = if cmd == "ui_update_configuration" {
                services.get_hardware_detail(id).unwrap().value.description
            } else {
                services.get_train_detail(id).unwrap().value.description
            };
            assert_eq!(
                description.as_deref(),
                Some("original"),
                "missing must preserve"
            );
            invoke(
                &webview,
                cmd,
                json!({"id":id.0.to_string(),"description":null}),
            )
            .unwrap();
            let description = if cmd == "ui_update_configuration" {
                services.get_hardware_detail(id).unwrap().value.description
            } else {
                services.get_train_detail(id).unwrap().value.description
            };
            assert_eq!(description, None, "{cmd}: explicit null must clear");
        }
    }

    #[test]
    fn real_button_command_clears_release_sequence_but_omission_preserves_it() {
        use trenino_runtime::storage::bindings::{
            ButtonBindingDraft, ButtonHardwareType, ButtonMode,
        };
        let dir = tempfile::tempdir().unwrap();
        let state = RustAppState::empty();
        state
            .install(AppServices::open_full(dir.path().join("button.db"), None).unwrap())
            .unwrap();
        let services = state.services().unwrap();
        let device = services
            .create_configuration_detail("Panel", None)
            .unwrap()
            .value
            .id;
        let input = services
            .create_input(trenino_runtime::app::CreateInputParams {
                device_id: device,
                pin: 4,
                kind: "button".into(),
                sensitivity: None,
                debounce: Some(20),
                name: None,
                matrix_id: None,
            })
            .unwrap()
            .value
            .inputs[0]
            .id;
        let train = services
            .create_train_entry("Train", None, vec!["unit".into()])
            .unwrap()
            .value
            .id;
        let element = services
            .create_element(train, "button", "Horn")
            .unwrap()
            .value
            .elements[0]
            .id;
        let sequence = services
            .create_sequence_entry(train, "Off")
            .unwrap()
            .value
            .sequences[0]
            .id;
        services
            .put_button_binding(
                element,
                input,
                ButtonBindingDraft {
                    mode: Some(ButtonMode::Sequence),
                    hardware_type: Some(ButtonHardwareType::Latching),
                    on_sequence_id: Some(sequence),
                    off_sequence_id: Some(sequence),
                    ..Default::default()
                },
                false,
            )
            .unwrap();
        let app = tauri::test::mock_builder()
            .manage(state)
            .invoke_handler(tauri::generate_handler![ui_put_button_binding])
            .build(tauri::test::mock_context(tauri::test::noop_assets()))
            .unwrap();
        let webview = tauri::WebviewWindowBuilder::new(&app, "main", Default::default())
            .build()
            .unwrap();
        invoke(&webview,"ui_put_button_binding",json!({"element_id":element.0.to_string(),"input_id":input.0.to_string(),"replace":false,"enabled":true})).unwrap();
        assert_eq!(
            services
                .database()
                .get_button_binding(element)
                .unwrap()
                .unwrap()
                .off_sequence_id,
            Some(sequence)
        );
        invoke(&webview,"ui_put_button_binding",json!({"element_id":element.0.to_string(),"input_id":input.0.to_string(),"replace":false,"off_sequence_id":null})).unwrap();
        assert_eq!(
            services
                .database()
                .get_button_binding(element)
                .unwrap()
                .unwrap()
                .off_sequence_id,
            None
        );
        let changed = invoke(&webview,"ui_put_button_binding",json!({"element_id":element.0.to_string(),"input_id":input.0.to_string(),"replace":false,"mode":"keystroke","keystroke":"CTRL+W","on_sequence_id":null,"off_sequence_id":null})).unwrap();
        assert!(changed["value"]["button"][0]["on_sequence_id"].is_null());
        assert_eq!(changed["value"]["button"][0]["keystroke"], "CTRL+W");
        let changed=invoke(&webview,"ui_put_button_binding",json!({"element_id":element.0.to_string(),"input_id":input.0.to_string(),"replace":false,"mode":"simple","endpoint":"Horn.InputValue","keystroke":null})).unwrap();
        assert!(changed["value"]["button"][0]["keystroke"].is_null());
        let changed=invoke(&webview,"ui_put_button_binding",json!({"element_id":element.0.to_string(),"input_id":input.0.to_string(),"replace":false,"mode":"sequence","on_sequence_id":sequence.0.to_string(),"endpoint":null})).unwrap();
        assert!(changed["value"]["button"][0]["endpoint"].is_null());
    }
    #[test]
    fn real_i2c_metadata_edit_preserves_params_and_explicit_params_replace_them() {
        use trenino_runtime::storage::{DisplayType, Ht16k33Params};
        let dir = tempfile::tempdir().unwrap();
        let state = RustAppState::empty();
        state
            .install(AppServices::open_full(dir.path().join("display.db"), None).unwrap())
            .unwrap();
        let services = state.services().unwrap();
        let device = services
            .create_configuration_detail("Panel", None)
            .unwrap()
            .value
            .id;
        let original = Ht16k33Params {
            brightness: 2,
            num_digits: 8,
            display_type: DisplayType::FourteenSegment,
            has_dot: true,
            align_right: true,
            min_value: Some(-5.),
        };
        let module = services
            .create_i2c_module(
                device,
                Some("display".into()),
                "ht16k33",
                0x70,
                Some(original.clone()),
            )
            .unwrap()
            .value
            .i2c_modules[0]
            .id;
        let app = tauri::test::mock_builder()
            .manage(state)
            .invoke_handler(tauri::generate_handler![
                ui_update_i2c_module,
                ui_create_i2c_module
            ])
            .build(tauri::test::mock_context(tauri::test::noop_assets()))
            .unwrap();
        let webview = tauri::WebviewWindowBuilder::new(&app, "main", Default::default())
            .build()
            .unwrap();
        let edited=invoke(&webview,"ui_update_i2c_module",json!({"id":module.0.to_string(),"name":"renamed","module_chip":"ht16k33","i2c_address":113})).unwrap();
        assert_eq!(
            edited["value"]["i2c_modules"][0]["params"],
            json!({"brightness":2,"num_digits":8,"display_type":"fourteen_segment","has_dot":true,"align_right":true,"min_value":-5.})
        );
        let changed=invoke(&webview,"ui_update_i2c_module",json!({"id":module.0.to_string(),"name":"renamed","module_chip":"ht16k33","i2c_address":113,"params":{"brightness":5,"num_digits":4,"display_type":"seven_segment","has_dot":false,"align_right":false,"min_value":null}})).unwrap();
        assert_eq!(
            changed["value"]["i2c_modules"][0]["params"]["min_value"],
            Value::Null
        );
        assert_eq!(
            changed["value"]["i2c_modules"][0]["params"]["brightness"],
            5
        );
        let error=invoke(&webview,"ui_update_i2c_module",json!({"id":module.0.to_string(),"name":"bad","module_chip":"ht16k33","i2c_address":113,"params":{"brightness":16,"num_digits":4,"display_type":"seven_segment","has_dot":false,"align_right":false,"min_value":null}})).unwrap_err();
        assert_eq!(error["code"], "validation");
        let preserved=invoke(&webview,"ui_update_i2c_module",json!({"id":module.0.to_string(),"name":"metadata","module_chip":"ht16k33","i2c_address":113,"params":null})).unwrap();
        assert_eq!(
            preserved["value"]["i2c_modules"][0]["params"]["brightness"],
            5
        );
        assert!(preserved["value"]["i2c_modules"][0]["params"]["min_value"].is_null());
        let created=invoke(&webview,"ui_create_i2c_module",json!({"device_id":device.0.to_string(),"module_chip":"ht16k33","i2c_address":114,"params":{"brightness":3,"num_digits":8,"display_type":"fourteen_segment","has_dot":true,"align_right":false,"min_value":null}})).unwrap();
        assert_eq!(
            created["value"]["i2c_modules"][1]["params"]["num_digits"],
            8
        );
        assert!(created["value"]["i2c_modules"][1]["params"]["min_value"].is_null());
        let error=invoke(&webview,"ui_update_i2c_module",json!({"id":module.0.to_string(),"module_chip":"ht16k33","i2c_address":113,"params":{"brightness":5,"num_digits":4,"display_type":"unknown","has_dot":false,"align_right":false,"min_value":null}})).unwrap_err();
        assert_eq!(
            error["field_errors"]["params.display_type"],
            "Select seven_segment or fourteen_segment."
        );
    }

    #[test]
    fn real_lever_notch_and_binding_commands_preserve_omission_and_clear_nulls() {
        use trenino_runtime::storage::{
            bindings::{DisplayBindingDraft, OutputBindingDraft, OutputBindingOperator},
            DisplayType, Ht16k33Params,
        };
        let dir = tempfile::tempdir().unwrap();
        let state = RustAppState::empty();
        state
            .install(AppServices::open_full(dir.path().join("fields.db"), None).unwrap())
            .unwrap();
        let services = state.services().unwrap();
        let device = services
            .create_configuration_detail("Panel", None)
            .unwrap()
            .value
            .id;
        let output = services
            .create_output(device, 4, None)
            .unwrap()
            .value
            .outputs[0]
            .id;
        let train = services
            .create_train_entry("Train", None, vec!["unit".into()])
            .unwrap()
            .value
            .id;
        let element = services
            .create_element(train, "lever", "Throttle")
            .unwrap()
            .value
            .elements[0]
            .id;
        let lever = services
            .create_lever(trenino_runtime::app::CreateLeverParams {
                element_id: element,
                min_endpoint: "Min".into(),
                max_endpoint: "Max".into(),
                value_endpoint: "Value".into(),
                notch_count_endpoint: Some("Count".into()),
                notch_index_endpoint: Some("Index".into()),
                lever_type: Some("discrete".into()),
                inverted: false,
            })
            .unwrap()
            .value
            .elements[0]
            .lever_config
            .as_ref()
            .unwrap()
            .id;
        let output_binding = services
            .create_output_binding_entry(
                train,
                OutputBindingDraft {
                    name: "LED".into(),
                    output_type: None,
                    output_id: output,
                    endpoint: "Value".into(),
                    operator: OutputBindingOperator::Between,
                    value_a: Some(10.),
                    value_b: Some(20.),
                    enabled: None,
                },
            )
            .unwrap()
            .value
            .output[0]
            .id;
        let module = services
            .create_i2c_module(
                device,
                None,
                "ht16k33",
                0x70,
                Some(Ht16k33Params {
                    brightness: 8,
                    num_digits: 4,
                    display_type: DisplayType::SevenSegment,
                    has_dot: false,
                    align_right: false,
                    min_value: None,
                }),
            )
            .unwrap()
            .value
            .i2c_modules[0]
            .id;
        let display_binding = services
            .create_display_binding_entry(
                train,
                DisplayBindingDraft {
                    i2c_module_id: module,
                    name: Some("Display".into()),
                    endpoint: "Value".into(),
                    format_string: None,
                    enabled: None,
                },
            )
            .unwrap()
            .value
            .display[0]
            .id;
        let app = tauri::test::mock_builder()
            .manage(state)
            .invoke_handler(tauri::generate_handler![
                ui_update_lever,
                ui_create_notch,
                ui_update_notch,
                ui_update_output_binding,
                ui_update_display_binding
            ])
            .build(tauri::test::mock_context(tauri::test::noop_assets()))
            .unwrap();
        let webview = tauri::WebviewWindowBuilder::new(&app, "main", Default::default())
            .build()
            .unwrap();
        let unchanged = invoke(
            &webview,
            "ui_update_lever",
            json!({"id":lever.0.to_string(),"inverted":true}),
        )
        .unwrap();
        assert_eq!(
            unchanged["value"]["elements"][0]["lever_config"]["notch_count_endpoint"],
            "Count"
        );
        let cleared=invoke(&webview,"ui_update_lever",json!({"id":lever.0.to_string(),"notch_count_endpoint":null,"notch_index_endpoint":null,"lever_type":null})).unwrap();
        for field in ["notch_count_endpoint", "notch_index_endpoint", "lever_type"] {
            assert!(cleared["value"]["elements"][0]["lever_config"][field].is_null());
        }
        assert_eq!(
            cleared["value"]["elements"][0]["lever_config"]["value_endpoint"],
            "Value"
        );
        let created=invoke(&webview,"ui_create_notch",json!({"lever_config_id":lever.0.to_string(),"notch":{"index":0,"kind":"gate","value":1.,"min_value":0.,"max_value":1.,"input_min":0.,"input_max":1.,"sim_input_min":0.,"sim_input_max":1.}})).unwrap();
        let notch = created["value"]["elements"][0]["lever_config"]["notches"][0]["id"].clone();
        let cleared=invoke(&webview,"ui_update_notch",json!({"id":notch,"min_value":null,"max_value":null,"input_min":null,"input_max":null,"sim_input_min":null,"sim_input_max":null})).unwrap();
        let row = &cleared["value"]["elements"][0]["lever_config"]["notches"][0];
        assert_eq!(row["value"], 1.);
        for field in [
            "min_value",
            "max_value",
            "input_min",
            "input_max",
            "sim_input_min",
            "sim_input_max",
        ] {
            assert!(row[field].is_null(), "{field}");
        }
        let linear = invoke(
            &webview,
            "ui_update_notch",
            json!({"id":notch,"kind":"linear","value":null,"min_value":0.,"max_value":1.}),
        )
        .unwrap();
        assert!(linear["value"]["elements"][0]["lever_config"]["notches"][0]["value"].is_null());
        let unchanged = invoke(
            &webview,
            "ui_update_output_binding",
            json!({"id":output_binding.0.to_string(),"name":"renamed"}),
        )
        .unwrap();
        assert_eq!(unchanged["value"]["output"][0]["value_a"], 10.);
        let cleared=invoke(&webview,"ui_update_output_binding",json!({"id":output_binding.0.to_string(),"operator":"eq_true","value_a":null,"value_b":null})).unwrap();
        assert!(cleared["value"]["output"][0]["value_a"].is_null());
        assert!(cleared["value"]["output"][0]["value_b"].is_null());
        let unchanged = invoke(
            &webview,
            "ui_update_display_binding",
            json!({"id":display_binding.0.to_string(),"enabled":false}),
        )
        .unwrap();
        assert_eq!(unchanged["value"]["display"][0]["name"], "Display");
        let cleared = invoke(
            &webview,
            "ui_update_display_binding",
            json!({"id":display_binding.0.to_string(),"name":null}),
        )
        .unwrap();
        assert!(cleared["value"]["display"][0]["name"].is_null());
    }

    #[test]
    fn create_i2c_without_params_uses_legacy_defaults() {
        let dir = tempfile::tempdir().unwrap();
        let state = RustAppState::empty();
        state
            .install(AppServices::open_full(dir.path().join("defaults.db"), None).unwrap())
            .unwrap();
        let services = state.services().unwrap();
        let device = services
            .create_configuration_detail("Panel", None)
            .unwrap()
            .value
            .id;
        let app = tauri::test::mock_builder()
            .manage(state)
            .invoke_handler(tauri::generate_handler![ui_create_i2c_module])
            .build(tauri::test::mock_context(tauri::test::noop_assets()))
            .unwrap();
        let webview = tauri::WebviewWindowBuilder::new(&app, "main", Default::default())
            .build()
            .unwrap();
        let response = invoke(
            &webview,
            "ui_create_i2c_module",
            json!({"device_id":device.0.to_string(),"module_chip":"ht16k33","i2c_address":112}),
        )
        .unwrap();
        assert_eq!(
            response["value"]["i2c_modules"][0]["params"],
            json!({"brightness":8,"num_digits":4,"display_type":"fourteen_segment","has_dot":false,"align_right":true,"min_value":0.})
        );
    }
    #[test]
    fn train_delete_requires_live_runtime_status_before_mutation() {
        let dir = tempfile::tempdir().unwrap();
        let state = RustAppState::empty();
        state
            .install(AppServices::open_full(dir.path().join("delete.db"), None).unwrap())
            .unwrap();
        let services = state.services().unwrap();
        let train = services
            .create_train_entry("Train", None, vec!["unit".into()])
            .unwrap()
            .value
            .id;
        let app = tauri::test::mock_builder()
            .manage(state)
            .invoke_handler(tauri::generate_handler![ui_delete_train])
            .build(tauri::test::mock_context(tauri::test::noop_assets()))
            .unwrap();
        let webview = tauri::WebviewWindowBuilder::new(&app, "main", Default::default())
            .build()
            .unwrap();
        let error = invoke(
            &webview,
            "ui_delete_train",
            json!({"id":train.0.to_string()}),
        )
        .unwrap_err();
        assert_eq!(error["code"], "unavailable");
        assert!(services.get_train_detail(train).is_ok());
    }

    #[test]
    fn deletion_guard_rejects_the_live_active_id_and_allows_other_profiles() {
        let active = trenino_core::EntityId(7);
        let error = validate_train_deletion(active, Some(active)).unwrap_err();
        assert_eq!(error.code, trenino_core::ErrorCode::Conflict);
        validate_train_deletion(trenino_core::EntityId(8), Some(active)).unwrap();
        validate_train_deletion(active, None).unwrap();
    }
}
