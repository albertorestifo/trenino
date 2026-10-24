use trenino_core::train::identifier::{match_identifier, IdentifierMatch, TrainProfile};
use trenino_core::train::lever::{map_input, LeverConfig, MappingError, Notch, NotchType};
use trenino_core::train::output::{evaluate_output, OutputBinding, OutputOperator, SimValue};

fn notch(
    kind: NotchType,
    input: (Option<f64>, Option<f64>),
    sim: (Option<f64>, Option<f64>),
) -> Notch {
    Notch {
        kind,
        input_min: input.0,
        input_max: input.1,
        sim_input_min: sim.0,
        sim_input_max: sim.1,
    }
}

#[test]
fn lever_mapping_preserves_half_open_ranges_and_the_exact_one_boundary() {
    let config = LeverConfig {
        inverted: false,
        notches: vec![
            notch(
                NotchType::Gate,
                (Some(0.0), Some(0.33)),
                (Some(0.0), Some(0.1)),
            ),
            notch(
                NotchType::Gate,
                (Some(0.33), Some(0.67)),
                (Some(0.45), Some(0.55)),
            ),
            notch(
                NotchType::Linear,
                (Some(0.67), Some(1.0)),
                (Some(0.9), Some(1.0)),
            ),
        ],
    };
    assert_eq!(map_input(&config, 0.32), Ok(0.05));
    assert_eq!(map_input(&config, 0.33), Ok(0.5));
    assert_eq!(map_input(&config, 1.0), Ok(1.0));
    assert_eq!(map_input(&config, 1.01), Err(MappingError::NoNotch));
}

#[test]
fn reversed_layout_inverts_linear_position_after_hardware_inversion() {
    let config = LeverConfig {
        inverted: true,
        notches: vec![
            notch(
                NotchType::Linear,
                (Some(0.0), Some(0.45)),
                (Some(0.56), Some(1.0)),
            ),
            notch(
                NotchType::Gate,
                (Some(0.99), Some(1.0)),
                (Some(0.0), Some(0.04)),
            ),
        ],
    };
    // Elixir rounds (1-input) to two decimal places, then reverses position in a reversed layout.
    assert_eq!(map_input(&config, 0.75), Ok(0.76));
    assert_eq!(map_input(&config, 0.0), Ok(0.02));
}

#[test]
fn lever_mapping_reports_missing_coverage_and_simulator_ranges() {
    let no_coverage = LeverConfig {
        inverted: false,
        notches: vec![notch(
            NotchType::Linear,
            (None, None),
            (Some(0.0), Some(1.0)),
        )],
    };
    assert_eq!(map_input(&no_coverage, 0.5), Err(MappingError::NoNotch));
    let no_sim_range = LeverConfig {
        inverted: false,
        notches: vec![notch(
            NotchType::Linear,
            (Some(0.0), Some(1.0)),
            (None, None),
        )],
    };
    assert_eq!(
        map_input(&no_sim_range, 0.5),
        Err(MappingError::NoSimulatorRange)
    );
}

#[test]
fn output_predicates_keep_boolean_and_numeric_types_separate_and_between_inclusive() {
    let between = OutputBinding {
        operator: OutputOperator::Between,
        value_a: Some(30.0),
        value_b: Some(60.0),
    };
    assert!(evaluate_output(&between, &SimValue::Number(30.0)));
    assert!(evaluate_output(&between, &SimValue::Number(60.0)));
    assert!(!evaluate_output(&between, &SimValue::Bool(true)));
    let eq_true = OutputBinding {
        operator: OutputOperator::EqTrue,
        value_a: None,
        value_b: None,
    };
    assert!(evaluate_output(&eq_true, &SimValue::Bool(true)));
    assert!(!evaluate_output(&eq_true, &SimValue::Number(1.0)));
}

#[test]
fn identifier_matching_is_case_sensitive_deduplicated_per_profile_and_ambiguous_across_profiles() {
    let profiles = vec![
        TrainProfile {
            id: 1,
            name: "BR 423".into(),
            identifiers: vec!["RVM_DB_BR423".into(), "RVM_DB_BR423_RED".into()],
        },
        TrainProfile {
            id: 2,
            name: "Other".into(),
            identifiers: vec!["RVM_DB_BR423_RED".into()],
        },
    ];
    assert_eq!(
        match_identifier(&profiles, "RVM_DB_BR423_RED_VARIANT"),
        IdentifierMatch::Ambiguous(vec![1, 2])
    );
    assert_eq!(
        match_identifier(&profiles[..1], "RVM_DB_BR423_RED_VARIANT"),
        IdentifierMatch::Unique(1)
    );
    assert_eq!(
        match_identifier(&profiles, "rvm_db_br423_red_variant"),
        IdentifierMatch::NotFound
    );
}
use trenino_core::train::display::{format_display, validate_format};

#[test]
fn display_format_matches_legacy_tokens_and_safe_invalid_precision() {
    assert_eq!(
        format_display("V:{value:.1f}", &SimValue::Number(42.5)),
        "V:42.5"
    );
    assert_eq!(format_display("{value:.0f}", &SimValue::Number(42.5)), "43");
    assert_eq!(
        format_display("{value:.2f}", &SimValue::Number(42.0)),
        "42.00"
    );
    assert_eq!(format_display("{value}", &SimValue::Bool(true)), "true");
    assert_eq!(
        format_display("{value:.11f}", &SimValue::Number(42.5)),
        "42.5"
    );
    assert_eq!(validate_format("{value:.10f}"), Ok(()));
    assert!(validate_format("{value:.2g}").is_err());
}
use trenino_core::calibration::analysis::{analyze_samples, LeverType, Sample, ZoneType};

#[test]
fn analyzer_merges_no_snap_notches_and_preserves_gate_linear_hybrid_classification() {
    let samples: Vec<_> = (0..=50)
        .map(|i| {
            let input = i as f64 * 0.02;
            let (actual, output, notch) = if input < 0.1 {
                (0.0, -11.0, 0)
            } else if input < 0.9 {
                (input, -10.0 + input * 20.0, 1)
            } else {
                (1.0, 10.0, 2)
            };
            Sample {
                set_input: input,
                actual_input: actual,
                output: (output * 100.0).round() / 100.0,
                notch_index: notch,
                snapped: (actual - input).abs() > 0.03,
            }
        })
        .collect();
    let result = analyze_samples(&samples).unwrap();
    assert_eq!(result.lever_type, LeverType::Hybrid);
    assert!(result.zones.iter().any(|zone| zone.kind == ZoneType::Gate));
    assert!(result
        .zones
        .iter()
        .any(|zone| zone.kind == ZoneType::Linear));
    assert_eq!(result.suggested_notches.len(), 3);
    assert!(result
        .suggested_notches
        .iter()
        .any(|notch| notch.description == "Gate at output -11.0"));
}

#[test]
fn analyzer_detects_continuous_and_discrete_sources_by_output_thresholds() {
    let continuous: Vec<_> = (0..=50)
        .map(|i| {
            let x = i as f64 * 0.02;
            Sample {
                set_input: x,
                actual_input: x,
                output: x,
                notch_index: 0,
                snapped: false,
            }
        })
        .collect();
    assert_eq!(
        analyze_samples(&continuous).unwrap().lever_type,
        LeverType::Continuous
    );
    let discrete: Vec<_> = (0..=50)
        .map(|i| {
            let x = i as f64 * 0.02;
            let out = if x < 0.33 {
                -1.0
            } else if x < 0.66 {
                0.0
            } else {
                1.0
            };
            let actual = if x < 0.33 {
                0.0
            } else if x < 0.66 {
                0.5
            } else {
                1.0
            };
            Sample {
                set_input: x,
                actual_input: actual,
                output: out,
                notch_index: if x < 0.33 {
                    0
                } else if x < 0.66 {
                    1
                } else {
                    2
                },
                snapped: (actual - x).abs() > 0.03,
            }
        })
        .collect();
    assert_eq!(
        analyze_samples(&discrete).unwrap().lever_type,
        LeverType::Discrete
    );
}
use trenino_core::train::buttons::{
    transition, ButtonAction, ButtonBinding, ButtonMode, ButtonState, HardwareType, SequenceCommand,
};

#[test]
fn momentary_button_orders_interacting_and_value_and_release_cancels_before_off() {
    let binding = ButtonBinding {
        element_id: 7,
        endpoint: Some("Path/Horn.InputValue".into()),
        on_value: 1.0,
        off_value: 0.0,
        mode: ButtonMode::Momentary,
        hardware_type: HardwareType::Momentary,
        on_sequence: vec![],
        off_sequence: vec![],
    };
    let (state, press) = transition(&binding, ButtonState::default(), true);
    assert_eq!(
        press,
        vec![
            ButtonAction::SetInteracting {
                endpoint: "Path/Horn.Interacting".into(),
                value: true
            },
            ButtonAction::Set {
                endpoint: "Path/Horn.InputValue".into(),
                value: 1.0
            },
            ButtonAction::StartMomentaryRepeat { element_id: 7 }
        ]
    );
    let (_, release) = transition(&binding, state, false);
    assert_eq!(
        release,
        vec![
            ButtonAction::CancelActive { element_id: 7 },
            ButtonAction::Set {
                endpoint: "Path/Horn.InputValue".into(),
                value: 0.0
            },
            ButtonAction::SetInteracting {
                endpoint: "Path/Horn.Interacting".into(),
                value: false
            }
        ]
    );
}

#[test]
fn sequence_button_cancels_momentary_on_release_and_starts_latching_off_sequence() {
    let command = SequenceCommand {
        endpoint: "A.InputValue".into(),
        value: 0.5,
        delay_ms: 25,
        position: 0,
    };
    let binding = ButtonBinding {
        element_id: 9,
        endpoint: None,
        on_value: 1.0,
        off_value: 0.0,
        mode: ButtonMode::Sequence,
        hardware_type: HardwareType::Momentary,
        on_sequence: vec![command.clone()],
        off_sequence: vec![],
    };
    let (state, press) = transition(&binding, ButtonState::default(), true);
    assert_eq!(
        press,
        vec![ButtonAction::StartSequence {
            element_id: 9,
            commands: vec![command.clone()]
        }]
    );
    let (_, release) = transition(&binding, state, false);
    assert_eq!(release, vec![ButtonAction::CancelActive { element_id: 9 }]);
    let latching = ButtonBinding {
        hardware_type: HardwareType::Latching,
        off_sequence: vec![command.clone()],
        ..binding
    };
    let (_, release) = transition(
        &latching,
        ButtonState {
            active: true,
            last_sent_value: Some(1.0),
        },
        false,
    );
    assert_eq!(
        release,
        vec![ButtonAction::StartSequence {
            element_id: 9,
            commands: vec![command]
        }]
    );
}

#[test]
fn simple_button_deduplicates_edges_and_sequence_commands_keep_position_and_post_delays() {
    let binding = ButtonBinding {
        element_id: 1,
        endpoint: Some("Bell.InputValue".into()),
        on_value: 1.0,
        off_value: 0.0,
        mode: ButtonMode::Simple,
        hardware_type: HardwareType::Momentary,
        on_sequence: vec![],
        off_sequence: vec![],
    };
    let (state, press) = transition(&binding, ButtonState::default(), true);
    assert_eq!(
        press,
        vec![ButtonAction::Set {
            endpoint: "Bell.InputValue".into(),
            value: 1.0
        }]
    );
    let (state, repeated) = transition(&binding, state, true);
    assert!(repeated.is_empty());
    let (_, release) = transition(&binding, state, false);
    assert_eq!(
        release,
        vec![ButtonAction::Set {
            endpoint: "Bell.InputValue".into(),
            value: 0.0
        }]
    );
    let commands = vec![
        SequenceCommand {
            endpoint: "B".into(),
            value: 2.0,
            delay_ms: 40,
            position: 1,
        },
        SequenceCommand {
            endpoint: "A".into(),
            value: 1.0,
            delay_ms: 0,
            position: 0,
        },
    ];
    assert_eq!(
        trenino_core::train::buttons::ordered_commands(commands),
        vec!["A", "B"]
    );
}
use trenino_core::train::buttons::{sequence_steps, SequenceStep};
#[test]
fn sequence_plan_sends_in_position_order_and_waits_after_each_delayed_command() {
    let commands = vec![
        SequenceCommand {
            endpoint: "second".into(),
            value: 2.0,
            delay_ms: 40,
            position: 1,
        },
        SequenceCommand {
            endpoint: "first".into(),
            value: 1.0,
            delay_ms: 0,
            position: 0,
        },
    ];
    assert_eq!(
        sequence_steps(&commands),
        vec![
            SequenceStep::Send(commands[1].clone()),
            SequenceStep::Send(commands[0].clone()),
            SequenceStep::Wait(40)
        ]
    );
}
#[test]
fn display_formatter_preserves_legacy_lexical_precision_rules() {
    assert_eq!(
        format_display("{value:.01f}", &SimValue::Number(42.56)),
        "42.56"
    );
    assert!(validate_format("{value:.01f}").is_err());
    assert_eq!(format_display("{value}", &SimValue::Number(42.0)), "42.0");
}
use trenino_core::simulator::Endpoint;

#[test]
fn simulator_dtos_preserve_endpoint_text_and_reject_blank_or_non_finite_values() {
    assert_eq!(
        Endpoint::new("Current/Control(Lever).InputValue")
            .unwrap()
            .as_str(),
        "Current/Control(Lever).InputValue"
    );
    assert!(Endpoint::new("  \t ").is_err());
    assert!(SimValue::number(f64::NAN).is_err());
    assert_eq!(
        serde_json::to_string(&SimValue::Bool(true)).unwrap(),
        "true"
    );
    assert_eq!(
        serde_json::to_string(&SimValue::String("café".into())).unwrap(),
        "\"café\""
    );
    assert!(serde_json::from_str::<Endpoint>("\"  \t\"").is_err());
    assert!(serde_json::to_string(&SimValue::Number(f64::INFINITY)).is_err());
}
