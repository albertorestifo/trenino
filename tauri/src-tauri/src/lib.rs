mod rust_ui;
mod telemetry;
#[cfg(any(feature = "desktop-updater", test))]
mod update_flow;
#[cfg(feature = "desktop-updater")]
mod updater;

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    rust_ui::run()
}
