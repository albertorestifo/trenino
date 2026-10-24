#[path = "build_config.rs"]
mod build_config;

fn main() {
    // The default package keeps the existing Elixir distribution. The explicit
    // Rust trial feature selects the static Vite build and omits absent legacy
    // sidecar binaries from Tauri's bundle validation.
    if std::env::var_os("CARGO_FEATURE_RUST_UI").is_some() {
        println!("cargo:rerun-if-env-changed=TAURI_CONFIG");
        let incoming = std::env::var_os("TAURI_CONFIG")
            .map(|value| value.into_string().expect("TAURI_CONFIG must be valid UTF-8"));
        let overlay = build_config::trial_overlay(incoming.as_deref())
            .expect("TAURI_CONFIG must contain a valid JSON overlay");
        std::env::set_var("TAURI_CONFIG", &overlay);
        println!("cargo:rustc-env=TAURI_CONFIG={overlay}");
        println!("cargo:rerun-if-changed=../ui/dist/index.html");
    }
    tauri_build::build()
}
