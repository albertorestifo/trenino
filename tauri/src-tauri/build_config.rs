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
