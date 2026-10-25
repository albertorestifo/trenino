//! Regenerates the checked-in UI TypeScript contracts:
//! `cargo run -p trenino-core --example export_ui_types`
use std::path::Path;

fn main() {
    let out = Path::new(env!("CARGO_MANIFEST_DIR")).join("../../tauri/ui/src/bridge/generated");
    trenino_core::ui::export_typescript_contracts(&out).expect("export typescript contracts");
    println!("wrote {}", out.display());
}
