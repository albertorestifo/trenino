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
fn output_integer_comparisons_preserve_precision_against_float_thresholds() {
    let positive = SimValue::Integer(9_007_199_254_740_993);
    let negative = SimValue::Integer(-9_007_199_254_740_993);
    let binding = |operator, value_a, value_b| OutputBinding {
        operator,
        value_a: Some(value_a),
        value_b,
    };

    assert!(evaluate_output(
        &binding(OutputOperator::Gt, 9_007_199_254_740_992.0, None),
        &positive
    ));
    assert!(!evaluate_output(
        &binding(OutputOperator::Lte, 9_007_199_254_740_992.0, None),
        &positive
    ));
    assert!(evaluate_output(
        &binding(OutputOperator::Lt, -9_007_199_254_740_992.0, None),
        &negative
    ));
    assert!(!evaluate_output(
        &binding(OutputOperator::Gte, -9_007_199_254_740_992.0, None),
        &negative
    ));
    assert!(evaluate_output(
        &binding(
            OutputOperator::Between,
            9_007_199_254_740_992.0,
            Some(9_007_199_254_740_994.0)
        ),
        &positive
    ));
    assert!(evaluate_output(
        &binding(OutputOperator::Gt, 11.5, None),
        &SimValue::Integer(12)
    ));
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
use trenino_core::calibration::analysis::{
    analyze_samples, AnalysisError, LeverType, Sample, ZoneType,
};

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
    let (after_release, release) = transition(
        &latching,
        ButtonState {
            active: true,
            last_sent_value: Some(1.0),
        },
        false,
    );
    assert_eq!(
        release,
        vec![
            ButtonAction::CancelActive { element_id: 9 },
            ButtonAction::StartSequence {
                element_id: 9,
                commands: vec![command]
            }
        ]
    );
    assert!(after_release.active);

    let no_off_sequence = ButtonBinding {
        off_sequence: vec![],
        ..latching
    };
    let (after_release, release) = transition(
        &no_off_sequence,
        ButtonState {
            active: true,
            last_sent_value: Some(1.0),
        },
        false,
    );
    assert_eq!(release, vec![ButtonAction::CancelActive { element_id: 9 }]);
    assert!(!after_release.active);
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
use trenino_core::rounding::round_elixir;
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

#[test]
fn elixir_rounding_matches_binary_float_ties_and_large_values() {
    for (input, places, expected) in [
        (0.015, 2, 0.01),
        (-0.015, 2, -0.01),
        (2.675, 2, 2.67),
        (-2.675, 2, -2.67),
        (0.15, 1, 0.1),
        (-0.15, 1, -0.1),
        (1.235, 2, 1.24),
        (2.5, 0, 3.0),
        (-2.5, 0, -3.0),
        (1.0e20, 2, 1.0e20),
    ] {
        assert_eq!(
            round_elixir(input, places),
            Some(expected),
            "{input} to {places}"
        );
    }
    assert_eq!(round_elixir(f64::MAX, 2), Some(f64::MAX));
    assert_eq!(round_elixir(f64::INFINITY, 2), None);
}

#[test]
fn display_raw_token_preserves_json_integer_float_and_exponent_text() {
    for (json, expected) in [
        ("12", "12"),
        ("12.0", "12.0"),
        ("1.0e20", "1.0e20"),
        ("1.0e-8", "1.0e-8"),
    ] {
        let value: SimValue = serde_json::from_str(json).unwrap();
        assert_eq!(format_display("{value}", &value), expected);
    }
    assert_eq!(
        format_display("{value:.2f}", &SimValue::Number(2.675)),
        "2.67"
    );
}

#[test]
fn display_float_notation_matches_elixir_shortest_notation_boundaries() {
    for (value, expected) in [
        (0.001, "0.001"),
        (0.0009999999999999998, "9.999999999999998e-4"),
        (-0.0009999999999999998, "-9.999999999999998e-4"),
        (0.0001, "0.0001"),
        (100_000_000_000_000.0, "1.0e14"),
        (999_999_999_999_999.9, "999999999999999.9"),
        (1_000_000_000_000_000.0, "1.0e15"),
        (1_000_000_000_000_001.0, "1000000000000001.0"),
        (1_000_000_000_001_000.0, "1.000000000001e15"),
        (1.0e16, "1.0e16"),
        (-1_000_000_000_000_000.0, "-1.0e15"),
    ] {
        let value = SimValue::Number(value);
        assert_eq!(format_display("{value}", &value), expected);
    }
}

#[test]
fn elixir_rounding_controls_mapping_and_analyzer_gate_threshold() {
    let config = LeverConfig {
        inverted: false,
        notches: vec![Notch {
            kind: NotchType::Linear,
            input_min: Some(0.0),
            input_max: Some(1.0),
            sim_input_min: Some(0.0),
            sim_input_max: Some(1.0),
        }],
    };
    assert_eq!(map_input(&config, 0.015), Ok(0.01));

    let samples = [
        Sample {
            set_input: 0.0,
            actual_input: 0.0,
            output: 0.0,
            notch_index: 1,
            snapped: false,
        },
        Sample {
            set_input: 1.0,
            actual_input: 1.0,
            output: 0.15,
            notch_index: 1,
            snapped: false,
        },
    ];
    let result = analyze_samples(&samples).unwrap();
    assert_eq!(result.zones[0].kind, ZoneType::Gate);
    assert_eq!(result.zones[0].value, Some(0.07));
}

#[test]
fn analyzer_handles_equal_large_finite_gate_values_without_overflow() {
    let samples = [
        Sample {
            set_input: 0.0,
            actual_input: 0.0,
            output: f64::MAX,
            notch_index: 0,
            snapped: false,
        },
        Sample {
            set_input: 0.5,
            actual_input: 0.5,
            output: f64::MAX,
            notch_index: 0,
            snapped: false,
        },
    ];
    let result = analyze_samples(&samples).unwrap();
    assert_eq!(result.zones[0].value, Some(f64::MAX));
}

#[test]
fn analyzer_rejects_non_finite_derived_zone_width() {
    let samples = [
        Sample {
            set_input: 0.0,
            actual_input: 0.0,
            output: -f64::MAX,
            notch_index: 0,
            snapped: false,
        },
        Sample {
            set_input: 0.5,
            actual_input: 0.5,
            output: f64::MAX,
            notch_index: 0,
            snapped: false,
        },
    ];
    assert_eq!(
        analyze_samples(&samples),
        Err(AnalysisError::InvalidDerivedResult)
    );
}

// ---------------------------------------------------------------------------
// Train identifier parity (oracle: test/trenino/train/identifier_test.exs
// `common_prefix/1` suite and the `extract_train_name/1` doctests in
// lib/trenino/train/identifier.ex).
// ---------------------------------------------------------------------------

use trenino_core::train::identifier::{common_prefix, extract_train_name, normalize_object_class};

fn owned(items: &[&str]) -> Vec<String> {
    items.iter().map(|item| (*item).to_owned()).collect()
}

#[test]
fn common_prefix_matches_the_elixir_cases() {
    // empty list
    assert_eq!(common_prefix(&[]), "");
    // single string returned as-is
    assert_eq!(common_prefix(&owned(&["BR_Class_66"])), "BR_Class_66");
    // identical strings
    assert_eq!(
        common_prefix(&owned(&["BR_Class_66", "BR_Class_66"])),
        "BR_Class_66"
    );
    // same beginning
    assert_eq!(
        common_prefix(&owned(&["BR_Class_66_DB", "BR_Class_66_Freightliner"])),
        "BR_Class_66"
    );
    // across multiple strings
    assert_eq!(
        common_prefix(&owned(&[
            "BR_Class_66_DB_Cargo",
            "BR_Class_66_Freightliner",
            "BR_Class_66_GBRF"
        ])),
        "BR_Class_66"
    );
    // no common prefix
    assert_eq!(common_prefix(&owned(&["ABC", "XYZ"])), "");
    // different lengths
    assert_eq!(common_prefix(&owned(&["AB", "ABCD", "ABCDEF"])), "AB");
    // unicode graphemes
    assert_eq!(
        common_prefix(&owned(&["Zürich_Train_A", "Zürich_Train_B"])),
        "Zürich_Train"
    );
    // strips multiple trailing non-alphanumeric characters
    assert_eq!(common_prefix(&owned(&["Train__A", "Train__B"])), "Train");
    // entirely alphanumeric prefix keeps the digits
    assert_eq!(common_prefix(&owned(&["ABC123X", "ABC123Y"])), "ABC123");
}

#[test]
fn extract_train_name_matches_the_elixir_doctests() {
    assert_eq!(
        extract_train_name("RVM_PBO_Class142_DMSL_New_GMPTE_C"),
        "Class 142"
    );
    assert_eq!(extract_train_name("RVM_FSN_DB_BR430_ETW4_C"), "DB BR 430");
    assert_eq!(extract_train_name("RVM_LIRREX_M9-B_C"), "M9");
    assert_eq!(extract_train_name("RVM_CJP_BNSF_ES44C4_C"), "BNSF ES44C4");
    assert_eq!(extract_train_name("unknown_format"), "");
}

#[test]
fn extract_train_name_pattern_priority_and_fallback() {
    // DB+BR beats company+model and single-part patterns.
    assert_eq!(extract_train_name("RVM_FSN_DB_BR430_ETW4"), "DB BR 430");
    // Single-part Class pattern preserves the joined number.
    assert_eq!(extract_train_name("RVM_PBO_Class801_C"), "Class 801");
    // Model number without hyphen suffix.
    assert_eq!(extract_train_name("RVM_LIRREX_M9_C"), "M9");
    // Company + model for a known operator.
    assert_eq!(extract_train_name("RVM_NJT_AMTK_AcelaA21_C"), "AMTK AcelaA21");
    // Fallback: first part with letters AND digits, 2-10 chars.
    assert_eq!(extract_train_name("RVM_XYZ_XYZ1234_C"), "XYZ1234");
    // No candidate: pure route/part words without digits or patterns.
    assert_eq!(extract_train_name("RVM_CJP_Passing_C"), "");
    // RVM alone cannot yield a name.
    assert_eq!(extract_train_name("RVM"), "");
    assert_eq!(extract_train_name(""), "");
}

#[test]
fn normalize_object_class_strips_suffix_and_trailing_junk() {
    // derive_from_formation normalization (identifier.ex:41-46): `_C` suffix
    // plus trailing non-alphanumerics.
    assert_eq!(normalize_object_class("RVM_SBN_OBB_1116_C"), "RVM_SBN_OBB_1116");
    assert_eq!(
        normalize_object_class("RVM_PBO_Class142_DMSL_C"),
        "RVM_PBO_Class142_DMSL"
    );
    assert_eq!(normalize_object_class("RVM_Train_Class"), "RVM_Train_Class");
    assert_eq!(normalize_object_class("RVM_FSN_DB_BR430__"), "RVM_FSN_DB_BR430");
}

#[test]
fn identifier_matching_covers_prefix_ambiguity_and_case() {
    // Deduplicated per profile: both identifiers of profile 1 match.
    let profiles = vec![
        TrainProfile {
            id: 1,
            name: "BR 423".into(),
            identifiers: vec!["RVM_DB_BR423".into(), "RVM_DB_BR423_RED".into()],
        },
        TrainProfile {
            id: 2,
            name: "BR 423 Red".into(),
            identifiers: vec!["RVM_DB_BR423_RED".into()],
        },
    ];
    // Cross-profile overlap is ambiguous — never the longest prefix.
    assert_eq!(
        match_identifier(&profiles, "RVM_DB_BR423_RED_VARIANT"),
        IdentifierMatch::Ambiguous(vec![1, 2])
    );
    // Unrelated identifiers owned by one profile all match that profile.
    let single = vec![TrainProfile {
        id: 7,
        name: "BR 423".into(),
        identifiers: vec!["RVM_FSN_DB_BR423".into(), "RVM_OTHER_DB_BR423".into()],
    }];
    assert_eq!(
        match_identifier(&single, "RVM_OTHER_DB_BR423_VARIANT"),
        IdentifierMatch::Unique(7)
    );
    // Case-sensitive prefix matching.
    assert_eq!(
        match_identifier(&profiles, "rvm_db_br423_red_variant"),
        IdentifierMatch::NotFound
    );
    // Exact prefix (stored == detected) matches.
    assert_eq!(
        match_identifier(&single, "RVM_FSN_DB_BR423"),
        IdentifierMatch::Unique(7)
    );
}
