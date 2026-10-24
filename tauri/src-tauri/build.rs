fn main() {
    // The default package keeps the existing Elixir distribution. The explicit
    // Rust trial feature selects the static Vite build and omits absent legacy
    // sidecar binaries from Tauri's bundle validation.
    if std::env::var_os("CARGO_FEATURE_RUST_UI").is_some() {
        let overlay =
            r#"{"build":{"frontendDist":"../ui/dist"},"bundle":{"externalBin":[],"resources":[]}}"#;
        std::env::set_var("TAURI_CONFIG", overlay);
        println!("cargo:rustc-env=TAURI_CONFIG={overlay}");
        println!("cargo:rerun-if-changed=../ui/dist/index.html");
    }
    tauri_build::build()
}
