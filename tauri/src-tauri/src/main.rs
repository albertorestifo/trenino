// Prevents additional console window on Windows in release
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

fn main() {
    #[cfg(all(windows, feature = "rust-ui"))]
    if let Some(code) = trenino_runtime::vjoy::windows::status_worker_entry() {
        std::process::exit(code);
    }
    trenino_lib::run()
}
