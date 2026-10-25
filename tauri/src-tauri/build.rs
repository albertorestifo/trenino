#[path = "build_config.rs"]
mod build_config;

fn main() {
    // The default package keeps the existing Elixir distribution. The explicit
    // Rust trial feature selects the static Vite build and omits absent legacy
    // sidecar binaries from Tauri's bundle validation.
    if std::env::var_os("CARGO_FEATURE_RUST_UI").is_some() {
        println!("cargo:rerun-if-env-changed=TAURI_CONFIG");
        let incoming = std::env::var_os("TAURI_CONFIG").map(|value| {
            value
                .into_string()
                .expect("TAURI_CONFIG must be valid UTF-8")
        });
        println!("cargo:rerun-if-env-changed=TRENINO_RUST_BUNDLE");
        let overlay = if std::env::var_os("TRENINO_RUST_BUNDLE").as_deref()
            == Some(std::ffi::OsStr::new("1"))
        {
            build_config::rust_bundle_overlay(
                incoming.as_deref(),
                std::env::var("CARGO_CFG_TARGET_OS").as_deref() == Ok("windows"),
            )
        } else {
            build_config::trial_overlay(incoming.as_deref())
        }
        .expect("TAURI_CONFIG must contain a valid JSON overlay");
        std::env::set_var("TAURI_CONFIG", &overlay);
        println!("cargo:rustc-env=TAURI_CONFIG={overlay}");
        println!("cargo:rerun-if-changed=../ui/dist/index.html");
    }
    tauri_build::build()
}
