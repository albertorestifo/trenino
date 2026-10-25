use serde_json::{json, Map, Value};

pub fn trial_overlay(incoming: Option<&str>) -> Result<String, serde_json::Error> {
    let mut config = match incoming {
        Some(raw) if !raw.trim().is_empty() => serde_json::from_str::<Value>(raw)?,
        _ => Value::Object(Map::new()),
    };
    let root = config
        .as_object_mut()
        .expect("Tauri configuration overlay must be a JSON object");
    root.entry("build")
        .or_insert_with(|| Value::Object(Map::new()))
        .as_object_mut()
        .expect("Tauri build configuration must be an object")
        .insert("frontendDist".into(), json!("../ui/dist"));
    let bundle = root
        .entry("bundle")
        .or_insert_with(|| Value::Object(Map::new()))
        .as_object_mut()
        .expect("Tauri bundle configuration must be an object");
    bundle.insert("externalBin".into(), json!([]));
    bundle.insert("resources".into(), json!([]));
    serde_json::to_string(&config)
}

#[cfg(test)]
mod tests {
    use serde_json::{json, Value};

    #[test]
    fn trial_overlay_preserves_caller_configuration_and_overrides_only_trial_fields() {
        let incoming = json!({
            "identifier": "org.example.trenino-test",
            "plugins": { "updater": { "endpoints": ["https://updates.example.test/latest"] } },
            "bundle": { "targets": ["msi"], "category": "Utility", "externalBin": ["legacy"], "resources": ["old"] },
            "build": { "beforeBuildCommand": "npm run build", "frontendDist": "../old" }
        });

        let merged: Value =
            serde_json::from_str(&super::trial_overlay(Some(&incoming.to_string())).unwrap())
                .unwrap();

        assert_eq!(merged["identifier"], incoming["identifier"]);
        assert_eq!(merged["plugins"]["updater"], incoming["plugins"]["updater"]);
        assert_eq!(merged["bundle"]["targets"], json!(["msi"]));
        assert_eq!(merged["bundle"]["category"], json!("Utility"));
        assert_eq!(merged["bundle"]["externalBin"], json!([]));
        assert_eq!(merged["bundle"]["resources"], json!([]));
        assert_eq!(merged["build"]["frontendDist"], json!("../ui/dist"));
        assert_eq!(
            merged["build"]["beforeBuildCommand"],
            json!("npm run build")
        );
    }
}

/// Rust distribution retains native helpers/resources while omitting the BEAM
/// backend and the legacy vJoy sidecar (the Rust host uses the vendored SDK).
pub fn rust_bundle_overlay(
    incoming: Option<&str>,
    windows: bool,
) -> Result<String, serde_json::Error> {
    let mut config: Value = serde_json::from_str(&trial_overlay(incoming)?)?;
    let bundle = config["bundle"].as_object_mut().expect("bundle object");
    bundle.insert(
        "externalBin".into(),
        json!(["binaries/avrdude", "binaries/keystroke"]),
    );
    let resources = if windows {
        json!([
            "binaries/avrdude.conf",
            "resources/vc_redist.x64.exe",
            "resources/vJoySetup.exe",
            "resources/vJoyConfig.exe",
            "resources/vJoyInstall.dll",
            "resources/vJoyInterface.dll",
            "resources/vJoy-LICENSE.txt",
            "resources/THIRD_PARTY_NOTICES.md"
        ])
    } else {
        json!(["binaries/avrdude.conf"])
    };
    bundle.insert("resources".into(), resources);
    serde_json::to_string(&config)
}

#[cfg(test)]
mod rust_bundle_tests {
    use super::*;
    #[test]
    fn cli_distribution_overlays_match_the_rust_build_configuration() {
        for (windows, raw) in [
            (false, include_str!("tauri.rust.conf.json")),
            (true, include_str!("tauri.rust.windows.conf.json")),
        ] {
            let cli: Value = serde_json::from_str(raw).unwrap();
            let build: Value =
                serde_json::from_str(&rust_bundle_overlay(None, windows).unwrap()).unwrap();
            assert_eq!(cli["bundle"], build["bundle"]);
            assert_eq!(cli["build"], build["build"]);
        }
    }
    #[test]
    fn rust_distribution_keeps_required_helpers_and_trusted_windows_resource_layout() {
        let config: Value = serde_json::from_str(&rust_bundle_overlay(Some(r#"{"plugins":{"updater":{"pubkey":"preserved"}},"bundle":{"targets":["nsis"]}}"#), true).unwrap()).unwrap();
        assert_eq!(
            config["bundle"]["externalBin"],
            json!(["binaries/avrdude", "binaries/keystroke"])
        );
        for file in [
            "resources/vJoyConfig.exe",
            "resources/vJoyInstall.dll",
            "resources/vJoyInterface.dll",
            "resources/vJoy-LICENSE.txt",
            "binaries/avrdude.conf",
        ] {
            assert!(config["bundle"]["resources"]
                .as_array()
                .unwrap()
                .contains(&json!(file)));
        }
        assert_eq!(config["plugins"]["updater"]["pubkey"], "preserved");
        assert_eq!(config["bundle"]["targets"], json!(["nsis"]));
        let portable: Value =
            serde_json::from_str(&rust_bundle_overlay(None, false).unwrap()).unwrap();
        assert_eq!(
            portable["bundle"]["resources"],
            json!(["binaries/avrdude.conf"])
        );
    }
}
