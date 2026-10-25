# Rust distribution profile and installed upload tooling

Root found the Rust trial build overlay always deleted externalBin/resources, and production avrdude_tooling still used the old ad hoc resource-dir/avrdude path without Windows .exe or bundled avrdude.conf. That left recovered discovery code unused by the desktop upload path.

Changes:
- Installed avrdude discovery now uses shared ExecutableProbe: explicit trusted path, executable sibling with correct platform filename, development-only fallback. A rejected configured path never silently switches to another binary. Bundled resource binaries/avrdude.conf is passed explicitly when present.
- `TRENINO_RUST_BUNDLE=1` selects the required Rust distribution helpers/resources during build.rs context generation. Ordinary trial debug/test builds can still run without staged native payloads.
- Explicit CLI overlays tauri.rust.conf.json / tauri.rust.windows.conf.json include frontend, avrdude/keystroke, configuration, and Windows vJoy/VC/license resources. This is necessary because mutating TAURI_CONFIG inside build.rs cannot rewrite the parent Tauri CLI's bundle configuration. Overlay consistency is tested against build_config.rs.
- `scripts/build-rust-desktop.sh` reuses verified native staging from build-desktop.sh via TRENINO_BUILD_RUST=1, builds Svelte, skips BEAM and legacy virtual_joystick sidecar, and selects Rust+updater features and the CLI overlay. Default legacy script/release path remains unchanged pending native acceptance.

Verification: bash -n both scripts; desktop rust-ui library20 tests; build_config3 tests including actual CLI overlay consistency. No installer/bundler, signing, download staging, native driver or avrdude execution performed. Non-Windows packaging requires a genuine compatible avrdude and config staged in binaries; the existing downloader supplies Windows only. Do not claim those artifacts were built here.
