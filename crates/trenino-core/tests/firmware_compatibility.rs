use trenino_core::firmware::{FirmwareRequirement, FirmwareVersion};

#[test]
fn manifest_validates_release_json_and_normalizes_mcu() {
    use trenino_core::firmware::{FirmwareManifest, Programmer};
    let manifest = FirmwareManifest::parse_json(r#"{"version":"v2.2.1","project":"trenino","devices":[{"environment":"uno","displayName":"Arduino Uno","firmwareFile":"uno.hex","uploadConfig":{"protocol":"arduino","mcu":"atmega328p","speed":115200,"requires1200bpsTouch":false}}]}"#).unwrap();
    assert_eq!(manifest.devices[0].upload_config.normalized_mcu(), "m328p");
    assert!(matches!(
        manifest.devices[0].upload_config.protocol,
        Programmer::Arduino
    ));
    assert!(FirmwareManifest::parse_json(r#"{"version":"1.0.0","project":"trenino","devices":[{"environment":"../escape","displayName":"x","firmwareFile":"x.hex","uploadConfig":{"protocol":"arduino","mcu":"m328p","speed":57600}}]}"#).is_err());
    let unsupported = FirmwareManifest::parse_json(r#"{"version":"1.0.0","project":"trenino","devices":[{"environment":"due","displayName":"Arduino Due","firmwareFile":"due.bin","uploadConfig":{"protocol":"sam-ba","mcu":"at91sam3x8e","speed":115200}}]}"#).unwrap();
    assert!(!unsupported.devices[0].upload_config.protocol.is_supported());
}

#[test]
fn nil_requirement_accepts_any_parseable_version_including_prereleases() {
    let requirement = FirmwareRequirement::parse(None).unwrap();
    assert!(requirement.matches("v1.2.3-rc.1"));
    assert!(!requirement.matches("1.2"));
}

#[test]
fn configured_requirement_excludes_prereleases_and_supports_elixir_ranges() {
    let requirement = FirmwareRequirement::parse(Some(">= 1.0.0 and < 2.0.0")).unwrap();
    assert!(requirement.matches("v1.5.0"));
    assert!(!requirement.matches("1.5.0-rc.1"));
    assert!(!requirement.matches("2.0.0"));

    let pessimistic = FirmwareRequirement::parse(Some("~> 1.2")).unwrap();
    assert!(pessimistic.matches("1.9.9"));
    assert!(!pessimistic.matches("2.0.0"));
    let patch_range = FirmwareRequirement::parse(Some("~> 1.2.3")).unwrap();
    assert!(patch_range.matches("1.2.3"));
    assert!(!patch_range.matches("1.3.0"));
    let disjunction = FirmwareRequirement::parse(Some(">= 1.0.0 or < 0.5.0")).unwrap();
    assert!(disjunction.matches("0.4.0"));
    assert!(disjunction.matches("2.0.0"));
}

#[test]
fn unsupported_or_invalid_versions_fail_closed() {
    assert!(FirmwareRequirement::parse(Some("~> 1.x")).is_err());
    assert!(!FirmwareRequirement::parse(None)
        .unwrap()
        .matches("not-a-version"));
    assert!(FirmwareVersion::parse("1.2").is_err());
    assert!(FirmwareVersion::parse("1.2.3+").is_err());
    assert!(FirmwareRequirement::parse(Some("~> v1.2")).is_err());
}

#[test]
fn configured_prerelease_matching_follows_elixir_operator_semantics() {
    let candidate = "1.2.3-rc.1";
    for requirement in ["== 1.2.3-rc.1", ">= 1.2.3-rc.1", "~> 1.2.3-rc.1", "< 1.2.3"] {
        assert!(
            FirmwareRequirement::parse(Some(requirement))
                .unwrap()
                .matches(candidate),
            "{requirement}"
        );
    }
    assert!(!FirmwareRequirement::parse(Some(">= 1.0.0 and < 2.0.0"))
        .unwrap()
        .matches(candidate));
    assert!(
        FirmwareRequirement::parse(Some(">= 1.0.0 and < 2.0.0 or == 1.2.3-rc.1"))
            .unwrap()
            .matches(candidate)
    );
}

#[test]
fn requirement_grammar_accepts_elixir_forms_and_rejects_reinterpretation() {
    assert!(FirmwareRequirement::parse(Some("1.2.3"))
        .unwrap()
        .matches("1.2.3"));
    assert!(FirmwareRequirement::parse(Some("~> 1.2.3+build.1")).is_ok());
    assert!(FirmwareRequirement::parse(Some("== 1.2.3+build.1")).is_ok());
    assert!(FirmwareRequirement::parse(Some("~>1.2.3")).is_ok());
    assert!(FirmwareRequirement::parse(Some(">=1.2.3")).is_ok());
    for invalid in ["= 1.2.3", "=1.2.3", ">= 1.2", ">= 1.0.0, < 2.0.0"] {
        assert!(
            FirmwareRequirement::parse(Some(invalid)).is_err(),
            "{invalid}"
        );
    }
}

#[test]
fn pessimistic_upper_bound_overflow_returns_an_error() {
    assert!(FirmwareRequirement::parse(Some("~> 18446744073709551615.0")).is_err());
    assert!(FirmwareRequirement::parse(Some("~> 1.18446744073709551615.0")).is_err());
}

#[test]
fn prerelease_admission_matches_the_executed_elixir_oracle_matrix() {
    // Every row was executed against the installed Elixir 1.20 oracle as
    // `Version.match?(version, requirement, allow_pre: false)`.
    let oracle = [
        // `>`/`>=`/`~>` admit a prerelease candidate only when the
        // requirement operand is itself a prerelease; `<`/`<=`/`==` are
        // plain comparisons a below-bound prerelease can satisfy.
        ("1.2.3-rc.1", "== 1.2.3-rc.1", true),
        ("1.2.3-rc.1", ">= 1.2.3-rc.1", true),
        ("1.2.3-rc.1", "~> 1.2.3-rc.1", true),
        ("1.2.3-rc.1", "< 1.2.3", true),
        ("1.2.3-rc.1", "<= 1.2.3", true),
        ("1.2.3-rc.1", "< 1.2.4", true),
        ("1.2.3-rc.1", "< 1.3.0", true),
        ("1.2.3-rc.1", "< 1.2.2", false),
        ("1.2.3-rc.1", "> 1.2.3", false),
        ("1.2.3-rc.1", ">= 1.2.3", false),
        ("1.2.3-rc.1", "> 1.2.2", false),
        ("1.2.3-rc.1", ">= 1.0.0", false),
        ("1.2.3-rc.1", "> 1.0.0", false),
        ("1.2.3-rc.1", "== 1.2.3", false),
        ("1.2.3-rc.1", "1.2.3", false),
        ("1.2.3-rc.1", "~> 1.2", false),
        ("1.2.3-rc.1", "~> 1.2.3", false),
        ("1.2.3-rc.1", "<= 1.2.3-rc.1", true),
        ("1.2.3-rc.1", "<= 1.2.3-rc.2", true),
        ("1.2.3-rc.1", "> 1.2.3-rc.2", false),
        ("1.2.3-rc.1", "> 1.2.3-rc.0", true),
        ("1.2.3-rc.1", "~> 1.2.0-rc.1", true),
        // Conjunctions apply the policy per bound: a stable lower bound
        // rejects the prerelease even though an upper bound with the same
        // core compares as satisfied (the round-2 R3 counterexamples).
        ("1.2.3-rc.1", ">= 1.0.0 and < 2.0.0", false),
        ("1.2.3-rc.1", ">= 1.0.0 and < 1.2.3", false),
        ("1.2.3-rc.2", ">= 1.0.0 and < 1.2.3", false),
        ("1.2.3-rc.2", ">= 1.0.0 and <= 1.2.3", false),
        ("1.2.3-rc.2", "> 1.0.0 and < 1.2.3", false),
        ("1.2.3-rc.2", ">= 1.2.3-rc.1 and < 2.0.0", true),
        ("1.2.3-rc.1", "== 1.2.3-rc.1 and >= 1.0.0", false),
        // Boolean alternatives evaluate the policy per alternative.
        ("1.2.3-rc.1", ">= 1.0.0 and < 2.0.0 or == 1.2.3-rc.1", true),
        ("1.2.3-rc.1", ">= 1.0.0 or < 1.2.3", true),
        ("1.2.3-rc.1", "< 1.2.3 or >= 2.0.0", true),
        // Stable candidates never hit the prerelease policy.
        ("1.5.0", ">= 1.0.0 and < 2.0.0", true),
        ("1.9.0", "~> 1.2", true),
        ("1.2.3", "~> 1.2.3", true),
    ];
    for (version, requirement, expected) in oracle {
        assert_eq!(
            FirmwareRequirement::parse(Some(requirement))
                .unwrap()
                .matches(version),
            expected,
            "{requirement} vs {version}"
        );
    }
}

#[test]
fn two_component_pessimistic_requirements_with_suffixes_match_the_elixir_oracle() {
    // `~> 1.2+build.1` translates to `>= 1.2.0+build.1 and < 2.0.0-0`: the
    // missing patch is inserted into the core, before the build suffix.
    let build = FirmwareRequirement::parse(Some("~> 1.2+build.1")).unwrap();
    assert!(build.matches("1.2.3"));
    assert!(!build.matches("1.2.3-rc.2"));
    assert!(!build.matches("1.1.9"));
    assert!(!build.matches("2.0.0"));
    // `~> 1.2-rc.1` translates to `>= 1.2.0-rc.1 and < 2.0.0-0`: the
    // prerelease suffix stays on the (admitting) lower bound.
    let pre = FirmwareRequirement::parse(Some("~> 1.2-rc.1")).unwrap();
    assert!(pre.matches("1.2.3-rc.2"));
    assert!(pre.matches("1.2.0"));
    assert!(pre.matches("1.2.0-rc.1"));
    assert!(pre.matches("1.9.0"));
    assert!(!pre.matches("1.2.0-rc.0"));
    assert!(!pre.matches("1.1.9"));
    assert!(!pre.matches("2.0.0"));
}
