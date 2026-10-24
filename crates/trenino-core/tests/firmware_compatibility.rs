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
