//! Wave-2 app-services surface: topic snapshots, command-shaped mutations and
//! shutdown coordination. Mirrors the Elixir LiveView page contracts in
//! `lib/trenino_web/live/*.ex` and the storage tests in
//! `crates/trenino-runtime/tests/domain_*.rs`.
use std::sync::{Arc, Mutex};

use tempfile::tempdir;
use trenino_core::ui::UiFailure;
use trenino_core::{EntityId, Topic};
use trenino_runtime::app::AppServices;
use trenino_runtime::lifecycle::{ShutdownCoordinator, ShutdownParticipant};
use trenino_runtime::storage::bindings::OutputBindingOperator;
use trenino_runtime::storage::firmware_records::{
    CatalogUpsert, FirmwareFileDraft, FirmwareReleaseDraft, UpdateCheckDraft,
};
use trenino_runtime::storage::trains::{NotchDraft, NotchKind};
use trenino_runtime::storage::Database;
use trenino_runtime::vjoy::store::{MappingDraft, Target, VjoyAxis};

struct Fixture {
    _dir: tempfile::TempDir,
    services: AppServices,
}

fn seed() -> Fixture {
    let dir = tempdir().expect("tempdir");
    let services = AppServices::open_full(dir.path().join("app.db"), None).expect("open");
    Fixture { _dir: dir, services }
}

fn seed_device(services: &AppServices) -> EntityId {
    services
        .create_configuration("Main panel", Some("Desk controller".into()))
        .expect("create configuration");
    let (devices, _) = services
        .database()
        .hardware_snapshot()
        .expect("hardware snapshot");
    devices.devices[0].id
}

fn seed_analog_input(services: &AppServices, device_id: EntityId) -> EntityId {
    let snapshot = services
        .create_input(
            device_id,
            3,
            "analog",
            Some(5),
            None,
            Some("Throttle".into()),
            None,
        )
        .expect("create input");
    snapshot.value.inputs[0].id
}

fn seed_train(services: &AppServices) -> EntityId {
    let snapshot = services
        .create_train_entry(
            "BR 185.2",
            None,
            vec!["br185".into(), "185".into()],
        )
        .expect("create train");
    snapshot.value.id
}

fn seed_lever(services: &AppServices, train_id: EntityId) -> EntityId {
    let element = services
        .create_element(train_id, "lever", "Throttle")
        .expect("create element");
    let element_id = element.value.elements[0].id;
    let detail = services
        .create_lever(
            element_id,
            "TD:MainLoco:Throttle:0".into(),
            "TD:MainLoco:Throttle:1".into(),
            "TD:MainLoco:Throttle".into(),
            None,
            None,
            Some("discrete"),
            false,
        )
        .expect("create lever");
    detail.value.elements[0]
        .lever_config
        .as_ref()
        .expect("lever config")
        .id
}

#[test]
fn every_topic_returns_a_snapshot_from_a_seeded_database() {
    let fixture = seed();
    let services = &fixture.services;
    let device = seed_device(services);
    seed_analog_input(services, device);
    let train = seed_train(services);
    seed_lever(services, train);

    for topic in [
        Topic::Settings,
        Topic::Hardware,
        Topic::Trains,
        Topic::Bindings,
        Topic::Scripts,
        Topic::Firmware,
        Topic::Vjoy,
    ] {
        let json = services.snapshot_json(topic).expect("snapshot");
        assert_eq!(json["topic"], serde_json::to_value(topic).expect("topic serializes"));
        assert!(json["epoch"].as_str().is_some(), "{topic:?} epoch is a string");
        assert!(json["revision"].as_str().is_some());
    }

    let hardware = services.snapshot_json(Topic::Hardware).expect("hardware");
    assert_eq!(hardware["value"][0]["name"], "Main panel");
    let vjoy = services.snapshot_json(Topic::Vjoy).expect("vjoy");
    assert_eq!(vjoy["value"]["enabled"], false);
    assert_eq!(vjoy["value"]["selected_devices"][0], 1);
}

#[test]
fn hardware_detail_and_child_crud_round_trip() {
    let fixture = seed();
    let services = &fixture.services;
    let device = seed_device(services);

    let input = services
        .create_input(device, 5, "button", Some(12), Some(3), Some("Horn".into()), None)
        .expect("input");
    assert_eq!(input.value.inputs.len(), 1);
    assert_eq!(input.value.inputs[0].kind, "button");

    let updated = services
        .update_input(input.value.inputs[0].id, 5, "button", None, Some(3), Some("Horn 2".into()))
        .expect("update input");
    assert_eq!(updated.value.inputs[0].name.as_deref(), Some("Horn 2"));

    let matrix = services
        .create_matrix(device, "Button matrix", vec![2, 3], vec![4, 5])
        .expect("matrix");
    assert_eq!(matrix.value.matrices.len(), 1);
    let matrix_id = matrix.value.matrices[0].id;
    let rematrix = services
        .update_matrix(matrix_id, vec![2], vec![4, 5, 6])
        .expect("update matrix");
    assert_eq!(rematrix.value.matrices[0].row_pins.len(), 1);
    assert_eq!(rematrix.value.matrices[0].col_pins.len(), 3);

    let output = services
        .create_output(device, 7, Some("Speedo LED".into()))
        .expect("output");
    assert_eq!(output.value.outputs[0].pin, 7);

    let module = services
        .create_i2c_module(
            device,
            Some("Headcode".into()),
            "ht16k33",
            0x70,
            Some(trenino_runtime::storage::Ht16k33Params {
                brightness: 8,
                num_digits: 4,
                display_type: trenino_runtime::storage::DisplayType::SevenSegment,
                has_dot: false,
                align_right: true,
                min_value: None,
            }),
        )
        .expect("i2c module");
    assert_eq!(module.value.i2c_modules[0].module_chip, "ht16k33");
    assert_eq!(
        module.value.i2c_modules[0]
            .params
            .as_ref()
            .expect("params")
            .display_type,
        "seven_segment"
    );

    services.delete_input(input.value.inputs[0].id).expect("delete input");
    services.delete_matrix(matrix_id).expect("delete matrix");
    services
        .delete_output(output.value.outputs[0].id)
        .expect("delete output");
    services
        .delete_i2c_module(module.value.i2c_modules[0].id)
        .expect("delete i2c module");
    let detail = services.get_hardware_detail(device).expect("detail");
    assert!(detail.value.inputs.is_empty());
    assert!(detail.value.matrices.is_empty());
    assert!(detail.value.outputs.is_empty());
    assert!(detail.value.i2c_modules.is_empty());

    let listed = services
        .update_configuration(device, Some("Renamed".into()), None)
        .expect("update configuration");
    assert_eq!(listed.value[0].name, "Renamed");
    let listed = services.delete_configuration(device).expect("delete configuration");
    assert!(listed.value.is_empty());
}

#[test]
fn train_detail_crud_auto_distribute_and_validation() {
    let fixture = seed();
    let services = &fixture.services;
    let train = seed_train(services);
    let lever = seed_lever(services, train);

    let detail = services
        .save_notches(
            lever,
            vec![
                NotchDraft {
                    index: 0,
                    kind: NotchKind::Gate,
                    value: Some(0.0),
                    min_value: Some(0.0),
                    max_value: Some(0.25),
                    input_min: None,
                    input_max: None,
                    sim_input_min: None,
                    sim_input_max: None,
                    description: Some("N".into()),
                },
                NotchDraft {
                    index: 1,
                    kind: NotchKind::Gate,
                    value: Some(1.0),
                    min_value: Some(0.75),
                    max_value: Some(1.0),
                    input_min: None,
                    input_max: None,
                    sim_input_min: None,
                    sim_input_max: None,
                    description: Some("Full".into()),
                },
            ],
        )
        .expect("save notches");
    assert_eq!(detail.value.elements[0].lever_config.as_ref().expect("cfg").notches.len(), 2);

    // Stored notches carry no input ranges yet, so validation reports gaps.
    let validation = services.validate_notch_ranges(lever).expect("validate");
    assert!(!validation.value.valid, "unset input ranges report gaps");
    assert!(!validation.value.gaps.is_empty());

    let distributed = services.auto_distribute_notches(lever).expect("distribute");
    let validation = services.validate_notch_ranges(lever).expect("validate again");
    assert!(validation.value.valid, "auto-distributed ranges cover");
    assert!(distributed
        .value
        .elements[0]
        .lever_config
        .as_ref()
        .expect("cfg")
        .notches
        .iter()
        .all(|notch| notch.input_min.is_some() && notch.input_max.is_some()));
    assert_eq!(
        distributed
            .value
            .elements[0]
            .lever_config
            .as_ref()
            .expect("cfg")
            .notches
            .len(),
        2
    );

    // Identifiers replace wholesale via update.
    let updated = services
        .update_train_entry(train, None, None, Some(vec!["br185.2".into()]))
        .expect("update train");
    assert_eq!(updated.value.identifiers, vec!["br185.2".to_string()]);

    let listed = services.delete_train_entry(train).expect("delete train");
    assert!(listed.value.is_empty());
}

#[test]
fn binding_crud_publishes_the_bindings_topic() {
    let fixture = seed();
    let services = &fixture.services;
    let device = seed_device(services);
    let analog = seed_analog_input(services, device);
    let button = services
        .create_input(device, 9, "button", None, Some(20), Some("Pantograph".into()), None)
        .expect("button input")
        .value
        .inputs[0]
        .id;
    let output = services
        .create_output(device, 11, None)
        .expect("output")
        .value
        .outputs[0]
        .id;
    let train = seed_train(services);
    let lever = seed_lever(services, train);
    let element = services
        .create_element(train, "button", "Panto")
        .expect("button element");
    let button_element = element.value.elements[1].id;
    let module = services
        .create_i2c_module(
            device,
            None,
            "ht16k33",
            0x71,
            Some(trenino_runtime::storage::Ht16k33Params {
                brightness: 8,
                num_digits: 4,
                display_type: trenino_runtime::storage::DisplayType::SevenSegment,
                has_dot: false,
                align_right: false,
                min_value: None,
            }),
        )
        .expect("i2c for display");

    let before = services.get_bindings_snapshot().expect("bindings").revision;
    services
        .bind_lever(lever, analog, false)
        .expect("bind lever");
    services
        .put_button_binding(
            button_element,
            button,
            trenino_runtime::storage::bindings::ButtonBindingDraft {
                endpoint: Some("TD:MainLoco:Pantograph".into()),
                ..Default::default()
            },
            false,
        )
        .expect("put button binding");
    services
        .create_output_binding_entry(
            train,
            trenino_runtime::storage::bindings::OutputBindingDraft {
                name: "Brake lights".into(),
                output_type: None,
                output_id: output,
                endpoint: "TD:MainLoco:Brake".into(),
                operator: OutputBindingOperator::Gt,
                value_a: Some(0.1),
                value_b: None,
                enabled: None,
            },
        )
        .expect("output binding");
    services
        .create_display_binding_entry(
            train,
            trenino_runtime::storage::bindings::DisplayBindingDraft {
                i2c_module_id: module.value.i2c_modules[0].id,
                name: Some("Speed".into()),
                endpoint: "TD:MainLoco:Speed".into(),
                format_string: None,
                enabled: None,
            },
        )
        .expect("display binding");

    let bindings = services.get_bindings_snapshot().expect("bindings");
    assert!(bindings.revision.0 > before.0, "topic revision advanced");
    assert_eq!(bindings.value.lever.len(), 1);
    assert_eq!(bindings.value.button.len(), 1);
    assert_eq!(bindings.value.output.len(), 1);
    assert_eq!(bindings.value.display.len(), 1);
    assert_eq!(bindings.value.display[0].format_string, "{value}");

    services.unbind_lever(lever).expect("unbind");
    services
        .delete_button_binding_entry(button_element)
        .expect("delete button binding");
    let bindings = services.get_bindings_snapshot().expect("bindings");
    assert!(bindings.value.lever.is_empty());
    assert!(bindings.value.button.is_empty());
}


#[test]
fn sequences_commands_and_scripts_round_trip() {
    let fixture = seed();
    let services = &fixture.services;
    let train = seed_train(services);

    services
        .create_sequence_entry(train, "Start-up")
        .expect("create sequence");
    let detail = services.get_train_detail(train).expect("detail");
    let sequence = detail.value.sequences[0].id;

    let detail = services
        .set_sequence_commands_entry(
            sequence,
            vec![
                trenino_runtime::storage::sequences::SequenceCommandDraft {
                    endpoint: "TD:MainLoco:Panto".into(),
                    value: 1.0,
                    delay_ms: 250,
                },
                trenino_runtime::storage::sequences::SequenceCommandDraft {
                    endpoint: "TD:MainLoco:Throttle".into(),
                    value: 0.3,
                    delay_ms: 0,
                },
            ],
        )
        .expect("set commands");
    assert_eq!(detail.value.sequences[0].commands.len(), 2);
    assert_eq!(detail.value.sequences[0].commands[1].value, 0.3);

    services
        .update_sequence_entry(sequence, Some("Start-up 2".into()))
        .expect("rename");
    services.reload_scripts().expect("reload");
    services
        .delete_sequence_entry(sequence)
        .expect("delete sequence");
    let detail = services.get_train_detail(train).expect("detail");
    assert!(detail.value.sequences.is_empty());

    services
        .create_script_entry(train, "Adhesion", "return 1.0", vec!["TD:MainLoco:Speed".into()])
        .expect("create script");
    let scripts = services.get_scripts_snapshot().expect("scripts");
    assert_eq!(scripts.value.scripts.len(), 1);
    assert!(scripts.value.scripts[0].enabled);
    services
        .delete_script_entry(scripts.value.scripts[0].id)
        .expect("delete script");
    let scripts = services.reload_scripts().expect("reload");
    assert!(scripts.value.scripts.is_empty());
}

#[test]
fn vjoy_mapping_and_selection_snapshot() {
    let fixture = seed();
    let services = &fixture.services;
    let device = seed_device(services);
    let input = seed_analog_input(services, device);

    let view = services
        .put_vjoy_mapping_entry(
            input,
            MappingDraft {
                device_index: 2,
                target: Target::Axis(VjoyAxis::X),
                inverted: false,
            },
            false,
        )
        .expect("put mapping");
    assert_eq!(view.value.mappings.len(), 1);
    assert_eq!(view.value.mappings[0].target, "axis/x");

    let view = services
        .set_vjoy_selection(vec![2, 3])
        .expect("set selection");
    assert_eq!(view.value.selected_devices, vec![2, 3]);

    services
        .confirm_vjoy_enabled(true)
        .expect("confirm enabled");
    let view = services.get_vjoy_snapshot().expect("vjoy");
    assert!(view.value.enabled);

    let view = services
        .delete_vjoy_mapping_entry(view.value.mappings[0].id)
        .expect("delete mapping");
    assert!(view.value.mappings.is_empty());
}

#[test]
fn firmware_catalog_and_update_check_snapshot() {
    let fixture = seed();
    let services = &fixture.services;

    let view = services
        .refresh_firmware_catalog(vec![CatalogUpsert {
            release: FirmwareReleaseDraft {
                version: "1.4.0".into(),
                tag_name: "v1.4.0".into(),
                release_url: Some("https://example.test/v1.4.0".into()),
                release_notes: None,
                published_at: Some("2026-10-01T00:00:00Z".into()),
                manifest_json: None,
            },
            files: vec![FirmwareFileDraft {
                board_type: "uno".into(),
                environment: None,
                download_url: "https://example.test/fw.hex".into(),
                file_size: Some(2048),
            }],
        }])
        .expect("refresh catalog");
    assert_eq!(view.value.releases.len(), 1);
    assert_eq!(view.value.releases[0].files[0].board_type, "uno");

    let view = services
        .record_firmware_update_check(UpdateCheckDraft {
            checked_at: "2026-10-25T00:00:00Z".into(),
            found_updates: true,
            latest_version: Some("1.4.0".into()),
            error_message: None,
        })
        .expect("record check");
    assert_eq!(view.value.update_checks.len(), 1);
    assert!(view.value.update_checks[0].found_updates);
}

#[test]
fn invalid_input_maps_to_validation_field_errors() {
    let fixture = seed();
    let services = &fixture.services;
    let device = seed_device(services);
    let _train = seed_train(services);

    let failure = UiFailure::from(
        services
            .create_configuration("   ", None)
            .expect_err("blank name"),
    );
    assert_eq!(failure.code, "validation");
    assert!(failure.field_errors.contains_key("name"));

    let failure = UiFailure::from(
        services
            .create_input(device, 1, "rotary", None, None, None, None)
            .expect_err("bad kind"),
    );
    assert_eq!(failure.code, "validation");
    assert!(failure.field_errors.contains_key("kind"));

    let failure = UiFailure::from(
        services
            .create_train_entry("Valid", None, Vec::new())
            .expect_err("no identifiers"),
    );
    assert!(failure.field_errors.contains_key("identifiers"));

    let failure = UiFailure::from(
        services
            .update_train_entry(EntityId(9999), Some("x".into()), None, None)
            .expect_err("unknown train"),
    );
    assert_eq!(failure.code, "not_found");

    // Invalid mutations never advance the topic revision.
    let before = services.list_trains().expect("trains").revision;
    assert!(services.create_train_entry("", None, vec!["x".into()]).is_err());
    let after = services.list_trains().expect("trains").revision;
    assert_eq!(before, after);
}

#[test]
fn database_accessor_shares_the_worker_and_respects_quiesce() {
    let fixture = seed();
    let services = &fixture.services;
    seed_device(services);

    let database: Arc<Database> = services.database();
    let (devices, _) = database.hardware_snapshot().expect("direct read");
    assert_eq!(devices.devices.len(), 1);

    let count = services
        .database_op(|db| {
            db.configurations_snapshot()
                .map(|(records, _)| records.len())
                .map_err(|_| trenino_core::AppError::internal("read failed"))
        })
        .expect("database op");
    assert_eq!(count, 1);

    services.quiesce();
    let failure = UiFailure::from(
        services
            .create_configuration("Late", None)
            .expect_err("admission closed"),
    );
    assert_eq!(failure.code, "unavailable");
    assert!(failure.retryable);
}

/// Records the phase order for the shutdown-coordinator contract.
struct RecordingParticipant {
    name: &'static str,
    log: Arc<Mutex<Vec<String>>>,
}

impl ShutdownParticipant for RecordingParticipant {
    fn stop_admission(&self) -> Result<(), String> {
        self.log.lock().expect("log").push(format!("{}:admission", self.name));
        Ok(())
    }
    fn cancel_and_join_producers(&self) -> Result<(), String> {
        self.log
            .lock()
            .expect("log")
            .push(format!("{}:producers", self.name));
        Ok(())
    }
    fn neutralize_and_release_outputs(&self) -> Result<(), String> {
        self.log
            .lock()
            .expect("log")
            .push(format!("{}:outputs", self.name));
        Ok(())
    }
    fn close_ports_and_network(&self) -> Result<(), String> {
        self.log
            .lock()
            .expect("log")
            .push(format!("{}:ports", self.name));
        Ok(())
    }
}

#[test]
fn shutdown_participants_run_in_registration_order_without_hanging() {
    let coordinator = ShutdownCoordinator::default();
    let log = Arc::new(Mutex::new(Vec::new()));
    coordinator
        .register(Arc::new(RecordingParticipant { name: "mcp", log: log.clone() }))
        .expect("register mcp");
    coordinator
        .register(Arc::new(RecordingParticipant { name: "vjoy", log: log.clone() }))
        .expect("register vjoy");

    let result = std::thread::spawn(move || {
        coordinator.shutdown(|| Ok(())).expect("shutdown");
    });
    result.join().expect("shutdown thread must not hang");
    assert_eq!(
        *log.lock().expect("log"),
        vec![
            "mcp:admission", "vjoy:admission",
            "mcp:producers", "vjoy:producers",
            "mcp:outputs", "vjoy:outputs",
            "mcp:ports", "vjoy:ports",
        ]
    );
}

#[test]
fn registration_after_shutdown_begun_is_refused() {
    let coordinator = ShutdownCoordinator::default();
    coordinator.shutdown(|| Ok(())).expect("shutdown");
    let refused = coordinator
        .register(Arc::new(RecordingParticipant {
            name: "late",
            log: Arc::new(Mutex::new(Vec::new())),
        }))
        .expect_err("registration refused");
    assert_eq!(refused, "shutdown has already begun");
}

#[test]
fn epoch_is_shared_across_snapshots() {
    let fixture = seed();
    let services = &fixture.services;
    let epoch = services.epoch();
    let settings = services.get_settings().expect("settings");
    assert_eq!(settings.epoch, epoch);
    let detail_epoch = services.get_vjoy_snapshot().expect("vjoy").epoch;
    assert_eq!(detail_epoch, epoch);
}
// ----- MCP server shutdown participation --------------------------------------

mod mcp_fakes {
    use std::sync::Arc;
    use trenino_runtime::mcp::ports::*;
    use trenino_runtime::mcp::server::{McpServer, McpServerStatus};

    fn fail<T>(what: &str) -> Result<T, PortError> {
        Err(PortError::Failed(format!("fake port: {what}")))
    }

    struct FakeTrains;
    impl TrainsPort for FakeTrains {
        fn list_trains(&self) -> Result<Vec<TrainSummary>, PortError> {
            Ok(Vec::new())
        }
        fn get_train(&self, _id: i64) -> Result<TrainDetail, PortError> {
            fail("get_train")
        }
        fn list_elements(&self, _train_id: i64) -> Result<Vec<ElementRecord>, PortError> {
            Ok(Vec::new())
        }
        fn create_element(
            &self,
            _train_id: i64,
            _name: Option<String>,
            _element_type: ElementType,
        ) -> Result<ElementRecord, PortError> {
            fail("create_element")
        }
        fn get_element(&self, _id: i64) -> Result<ElementRecord, PortError> {
            fail("get_element")
        }
        fn delete_element(&self, _element: &ElementRecord) -> Result<(), PortError> {
            fail("delete_element")
        }
    }

    struct FakeHardware;
    impl HardwarePort for FakeHardware {
        fn list_devices(&self) -> Vec<DeviceSummary> {
            Vec::new()
        }
        fn list_inputs(&self, _device_id: i64) -> Result<Vec<InputRecord>, PortError> {
            Ok(Vec::new())
        }
        fn list_outputs(&self) -> Vec<HardwareOutputRecord> {
            Vec::new()
        }
        fn list_i2c_modules(&self) -> Vec<I2cModuleRecord> {
            Vec::new()
        }
        fn create_i2c_module(
            &self,
            _device_id: i64,
            _i2c_address: i64,
            _attrs: I2cModuleAttrs,
        ) -> Result<I2cModuleRecord, PortError> {
            fail("create_i2c_module")
        }
        fn get_i2c_module(&self, _id: i64) -> Result<I2cModuleRecord, PortError> {
            fail("get_i2c_module")
        }
        fn update_i2c_module(
            &self,
            _module: &I2cModuleRecord,
            _changes: I2cModuleChanges,
        ) -> Result<I2cModuleRecord, PortError> {
            fail("update_i2c_module")
        }
        fn delete_i2c_module(&self, _module: &I2cModuleRecord) -> Result<(), PortError> {
            fail("delete_i2c_module")
        }
    }

    struct FakeSequences;
    impl SequencesPort for FakeSequences {
        fn list_sequences(&self, _train_id: i64) -> Vec<SequenceRecord> {
            Vec::new()
        }
        fn create_sequence(
            &self,
            _train_id: i64,
            _name: Option<String>,
        ) -> Result<SequenceRecord, PortError> {
            fail("create_sequence")
        }
        fn get_sequence(&self, _id: i64) -> Result<SequenceRecord, PortError> {
            fail("get_sequence")
        }
        fn update_sequence_name(
            &self,
            _sequence: &SequenceRecord,
            _name: Option<String>,
        ) -> Result<(), PortError> {
            fail("update_sequence_name")
        }
        fn set_sequence_commands(
            &self,
            _sequence: &SequenceRecord,
            _commands: Vec<SequenceCommandDraft>,
        ) -> Result<(), PortError> {
            fail("set_sequence_commands")
        }
        fn delete_sequence(&self, _sequence: &SequenceRecord) -> Result<(), PortError> {
            fail("delete_sequence")
        }
    }

    struct FakeScripts;
    impl ScriptsPort for FakeScripts {
        fn list_scripts(&self, _train_id: i64) -> Vec<ScriptRecord> {
            Vec::new()
        }
        fn get_script(&self, _id: i64) -> Result<ScriptRecord, PortError> {
            fail("get_script")
        }
        fn create_script(&self, _train_id: i64, _attrs: ScriptAttrs) -> Result<ScriptRecord, PortError> {
            fail("create_script")
        }
        fn update_script(
            &self,
            _script: &ScriptRecord,
            _changes: ScriptAttrs,
        ) -> Result<ScriptRecord, PortError> {
            fail("update_script")
        }
        fn delete_script(&self, _script: &ScriptRecord) -> Result<(), PortError> {
            fail("delete_script")
        }
    }

    struct FakeBindings;
    impl BindingsPort for FakeBindings {
        fn list_output_bindings(&self, _train_id: i64) -> Vec<OutputBindingRecord> {
            Vec::new()
        }
        fn create_output_binding(
            &self,
            _train_id: i64,
            _attrs: OutputBindingAttrs,
        ) -> Result<OutputBindingRecord, PortError> {
            fail("create_output_binding")
        }
        fn get_output_binding(&self, _id: i64) -> Result<OutputBindingRecord, PortError> {
            fail("get_output_binding")
        }
        fn update_output_binding(
            &self,
            _binding: &OutputBindingRecord,
            _changes: OutputBindingAttrs,
        ) -> Result<OutputBindingRecord, PortError> {
            fail("update_output_binding")
        }
        fn delete_output_binding(&self, _binding: &OutputBindingRecord) -> Result<(), PortError> {
            fail("delete_output_binding")
        }
        fn get_button_binding(&self, _element_id: i64) -> Result<ButtonBindingRecord, PortError> {
            fail("get_button_binding")
        }
        fn create_button_binding(
            &self,
            _element_id: i64,
            _input_id: i64,
            _attrs: ButtonBindingAttrs,
        ) -> Result<ButtonBindingRecord, PortError> {
            fail("create_button_binding")
        }
        fn update_button_binding(
            &self,
            _binding: &ButtonBindingRecord,
            _changes: ButtonBindingAttrs,
        ) -> Result<ButtonBindingRecord, PortError> {
            fail("update_button_binding")
        }
        fn delete_button_binding(&self, _element_id: i64) -> Result<(), PortError> {
            fail("delete_button_binding")
        }
        fn list_display_bindings(&self, _train_id: i64) -> Vec<DisplayBindingRecord> {
            Vec::new()
        }
        fn create_display_binding(
            &self,
            _train_id: i64,
            _attrs: DisplayBindingAttrs,
        ) -> Result<DisplayBindingRecord, PortError> {
            fail("create_display_binding")
        }
        fn get_display_binding(&self, _id: i64) -> Result<DisplayBindingRecord, PortError> {
            fail("get_display_binding")
        }
        fn update_display_binding(
            &self,
            _binding: &DisplayBindingRecord,
            _changes: DisplayBindingAttrs,
        ) -> Result<DisplayBindingRecord, PortError> {
            fail("update_display_binding")
        }
        fn delete_display_binding(&self, _binding: &DisplayBindingRecord) -> Result<(), PortError> {
            fail("delete_display_binding")
        }
    }

    struct FakeSimulator;
    impl SimulatorPort for FakeSimulator {
        fn is_connected(&self) -> bool {
            false
        }
        fn list_endpoints(&self, _path: Option<&str>) -> Result<serde_json::Value, String> {
            Err("not connected".into())
        }
        fn get_value(&self, _path: &str) -> Result<serde_json::Value, String> {
            Err("not connected".into())
        }
        fn set_value(&self, _path: &str, _value: &serde_json::Value) -> Result<serde_json::Value, String> {
            Err("not connected".into())
        }
    }

    struct FakeDetection;
    impl DetectionPort for FakeDetection {
        fn detect_input(&self, _request: &DetectionRequest) -> DetectionOutcome {
            DetectionOutcome::Timeout
        }
    }

    struct FakeVjoy;
    impl VjoyPort for FakeVjoy {
        fn status_details(&self) -> VjoyStatusDetails {
            VjoyStatusDetails {
                status: VjoyStatus::Unsupported,
                reason: None,
            }
        }
        fn list_mappings(&self) -> Vec<VjoyMappingRecord> {
            Vec::new()
        }
        fn put_mapping(
            &self,
            _input_id: i64,
            _draft: VjoyMappingDraft,
            _replace: bool,
        ) -> Result<VjoyMappingRecord, VjoyPutError> {
            Err(VjoyPutError::NotFound)
        }
        fn delete_mapping(&self, _id: i64) -> Result<VjoyMappingRecord, PortError> {
            fail("delete_mapping")
        }
        fn lifecycle(&self, _command: VjoyCommand) -> Result<(), VjoyReason> {
            Err(VjoyReason::Code("unsupported".into()))
        }
        fn reload_mappings(&self) {}
    }

    /// Mirrors the integrator wiring:
    /// `StoragePorts::new(database).into_ports()` handed to `McpServer::new`,
    /// here built from in-memory fakes instead of the database.
    pub fn fake_ports() -> Ports {
        Ports {
            trains: Arc::new(FakeTrains),
            hardware: Arc::new(FakeHardware),
            sequences: Arc::new(FakeSequences),
            scripts: Arc::new(FakeScripts),
            bindings: Arc::new(FakeBindings),
            simulator: Arc::new(FakeSimulator),
            detection: Arc::new(FakeDetection),
            vjoy: Arc::new(FakeVjoy),
        }
    }

    pub fn start_fake_server() -> (Arc<McpServer>, u16) {
        let server = Arc::new(McpServer::new(Arc::new(fake_ports()), None));
        match server.start(([127, 0, 0, 1], 0).into()).expect("start") {
            McpServerStatus::Running { address } => (server, address.port()),
            McpServerStatus::Stopped => panic!("server reported stopped"),
            McpServerStatus::Degraded { reason } => panic!("ephemeral port degraded: {reason}"),
        }
    }


}

struct McpStopParticipant {
    server: Arc<trenino_runtime::mcp::server::McpServer>,
}

impl ShutdownParticipant for McpStopParticipant {
    fn stop_admission(&self) -> Result<(), String> {
        Ok(())
    }
    fn cancel_and_join_producers(&self) -> Result<(), String> {
        Ok(())
    }
    fn neutralize_and_release_outputs(&self) -> Result<(), String> {
        Ok(())
    }
    fn close_ports_and_network(&self) -> Result<(), String> {
        self.server.stop()
    }
}

#[test]
fn mcp_server_participates_in_shutdown_and_releases_its_port() {
    let (server, port) = mcp_fakes::start_fake_server();
    let coordinator = ShutdownCoordinator::default();
    coordinator
        .register(Arc::new(McpStopParticipant {
            server: server.clone(),
        }))
        .expect("register mcp");

    // The shutdown must release the listener without hanging.
    let thread = std::thread::spawn(move || coordinator.shutdown(|| Ok(())));
    let completed = std::thread::spawn(move || thread.join().expect("shutdown thread"));
    completed.join().expect("shutdown join").expect("shutdown");

    let rebound = mcp_fakes::start_fake_server();
    assert!(rebound.1 > 0, "a fresh server can bind after shutdown");
    rebound.0.stop().expect("stop rebound server");
    let _ = port;
}

#[test]
fn busy_mcp_port_is_a_degraded_start_error_not_a_crash() {
    let (_first, _port) = mcp_fakes::start_fake_server();
    // Binding an already-bound loopback port must report a bind error that the
    // caller treats as degraded (non-fatal), exactly like the wave-1 server
    // contract ("not prevent startup").
    let port = _port;
    let second = trenino_runtime::mcp::server::McpServer::new(
        Arc::new(mcp_fakes::fake_ports()),
        None,
    );
    match second.start(([127, 0, 0, 1], port).into()) {
        Ok(trenino_runtime::mcp::server::McpServerStatus::Degraded { .. }) => {}
        Ok(trenino_runtime::mcp::server::McpServerStatus::Running { .. }) => {
            panic!("second server must not take the busy port")
        }
        Ok(trenino_runtime::mcp::server::McpServerStatus::Stopped) => {
            panic!("busy port must report degraded, not stopped")
        }
        Err(error) => panic!("busy port must degrade, not fail: {error:?}"),
    }
    _first.stop().expect("stop first");
}
