use trenino_core::hardware::calibration::{analyze_sweep, normalize, Calibration};

#[test]
fn detects_inversion_and_rollover_and_integer_median() {
    assert_eq!(analyze_sweep(&[10, 30, 50, 70], 1023), (false, false));
    assert_eq!(analyze_sweep(&[70, 50, 30, 10], 1023), (true, false));
    assert_eq!(
        analyze_sweep(&[1010, 1015, 1020, 1023, 0, 5, 10], 1023),
        (false, true)
    );
    assert_eq!(
        analyze_sweep(&[15, 10, 5, 0, 1023, 1020, 1015], 1023),
        (true, true)
    );
}

#[test]
fn normalize_all_four_directions_with_clamping_and_dead_zone_ties() {
    let c = Calibration {
        min_value: 100,
        max_value: 900,
        max_hardware_value: 1023,
        inverted: false,
        rollover: false,
    };
    assert_eq!(normalize(500, &c), 400);
    assert_eq!(normalize(0, &c), 0);
    assert_eq!(normalize(999, &c), 800);
    let c = Calibration {
        min_value: 900,
        max_value: 100,
        max_hardware_value: 1023,
        inverted: true,
        rollover: false,
    };
    assert_eq!(normalize(500, &c), 400);
    let c = Calibration {
        min_value: 900,
        max_value: 100,
        max_hardware_value: 1023,
        inverted: false,
        rollover: true,
    };
    assert_eq!(normalize(0, &c), 124);
    assert_eq!(normalize(500, &c), 0); // midpoint tie rounds toward min
    let c = Calibration {
        min_value: 550,
        max_value: 735,
        max_hardware_value: 1023,
        inverted: true,
        rollover: true,
    };
    assert_eq!(normalize(1023, &c), 551);
    assert_eq!(normalize(735, &c), 839);
    assert_eq!(normalize(700, &c), 839);
}
#[test]
fn invalid_extreme_calibration_data_clamps_safely_and_analyzer_endpoints_match() {
    use trenino_core::hardware::calibration::{
        analyze, calculate_max, calculate_min, normalize, Calibration,
    };
    let invalid = Calibration {
        min_value: i32::MAX,
        max_value: i32::MIN,
        max_hardware_value: i32::MAX,
        inverted: false,
        rollover: false,
    };
    assert_eq!(normalize(i32::MAX, &invalid), 0);
    let analysis = analyze(&[90, 70, 50, 30], 1023);
    assert!(analysis.inverted);
    assert_eq!(calculate_min(&[90, 92, 91], analysis), Some(92));
    assert_eq!(calculate_max(&[10, 8, 9], analysis), Some(8));
    assert_eq!(calculate_min(&[], analysis), None);
}
