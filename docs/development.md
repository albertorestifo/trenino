# Development Guide

Guide for developers contributing to Trenino.

## Development Setup

### Prerequisites

- Rust toolchain 1.91.1 (rustup; includes clippy + rustfmt)
- Node.js 22 — Svelte desktop UI in `tauri/ui`

## Development Commands

```bash
# Format, lint and tests (same gates as .github/workflows/rust-parity.yml)
cargo fmt --all --check
cargo clippy --workspace --all-targets -- -D warnings
cargo test --workspace -- --test-threads=1

# Desktop UI
npm --prefix tauri/ui ci
npm --prefix tauri/ui run check
npm --prefix tauri/ui test
npm --prefix tauri/ui run build

# Desktop shell (Tauri commands + updater)
cargo fmt --manifest-path tauri/src-tauri/Cargo.toml --check
cargo test --manifest-path tauri/src-tauri/Cargo.toml --features "rust-ui desktop-updater" -- --test-threads=1
cargo check --manifest-path tauri/src-tauri/Cargo.toml --features "rust-ui desktop-updater"
```

Run the desktop app locally:

```bash
npm --prefix tauri/ui run build
cargo run --manifest-path tauri/src-tauri/Cargo.toml --features rust-ui
```

There is no hot-reload wiring (no `devUrl` in the Tauri configs): rebuild the
UI and relaunch to pick up frontend changes. `npm --prefix tauri/ui run dev`
serves the UI in a browser without Tauri IPC.

On Windows, vendored vJoy bindings require `LIBCLANG_PATH` (see
Windows Virtual Joystick Development below).

### Optional: Keystroke Simulation Support

The keystroke button binding mode uses a small Rust sidecar that simulates
keyboard input. On Windows it uses the `SendInput` API; on Linux it uses
`xdotool` (requires `libxdo-dev`). Build it with:

```bash
cargo build --manifest-path tauri/keystroke/Cargo.toml --release
```

Debug builds of the runtime discover the sidecar automatically at
`tauri/keystroke/target/{release,debug}` (or an avrdude/keystroke on `PATH`);
release builds only use trusted configured or bundled app-resource paths.

**Linux prerequisite:**
```bash
sudo apt-get install libxdo-dev
```

Verify it's working:

```bash
./tauri/keystroke/target/release/keystroke tap A
```

### Optional: Firmware Upload Support

To use the firmware upload feature during development, you need to install avrdude:

**macOS:**
```bash
brew install avrdude
```

**Linux (Debian/Ubuntu):**
```bash
sudo apt-get install avrdude
```

**Linux (Fedora):**
```bash
sudo dnf install avrdude
```

**Windows:**
Download from [avrdudes/avrdude releases](https://github.com/avrdudes/avrdude/releases) and add to your PATH.

The desktop app bundles avrdude automatically, so end users don't need to install it separately.

### Windows Virtual Joystick Development

The Windows build uses `vjoy-sys` to generate bindings and requires the LLVM
`libclang.dll` development library. Set `LIBCLANG_PATH` to the directory containing
that DLL before invoking Cargo if bindgen cannot locate it. This is a build-time
prerequisite; the packaged application does not require LLVM or libclang.

The native feeder is a standalone Rust crate:

```bash
cargo run --manifest-path tauri/virtual_joystick/Cargo.toml
cargo test --manifest-path tauri/virtual_joystick/Cargo.toml
```

On Windows the bridge passes an absolute, trusted packaged-resource path to the
sidecar, which requires `serve --vjoy-interface <absolute DLL path>`. Do not
restore bare-name DLL loading or accept executable/DLL paths from UI or MCP
input. Non-Windows builds compile the unsupported adapter but do not bundle the
Windows sidecar or vJoy resources.

Tests that install/remove the driver or create real Windows devices run only on
the disposable, elevated Windows VM. Ordinary hosted CI must remain
non-mutating: its Windows packaging job verifies downloads and Authenticode,
builds both native crates and the Tauri/NSIS package, inspects the packaged
layout, and performs a sidecar handshake without installing the driver.

## Project Structure

```
crates/
├── trenino-core/              # Shared domain types and wire contracts
│   └── src/
│       ├── hardware/          # Serial protocol codec, calibration, HT16K33
│       ├── train/             # Lever/notch model, buttons, display, outputs
│       ├── calibration/       # Notch analysis
│       ├── rounding.rs        # Exact decimal rounding helpers
│       └── simulator.rs       # Simulator client types
│
└── trenino-runtime/           # Tokio services
    └── src/
        ├── app.rs             # Application-facing repositories + UI snapshots
        ├── composition/       # Production service composition and adapters
        ├── hardware/          # Device service, discovery, transport, sessions
        ├── firmware/          # Catalog, downloads, upload, owner, updates
        ├── train/             # Detection, lever/button/output/display
        │                      # controllers, script runner, sequences
        ├── simulator/         # Client, connection owner, subscriptions,
        │                      # detection/analysis/explorer services
        ├── vjoy/              # Windows vJoy manager, configurator, mapper
        ├── storage/           # SQLite database, schema, domain stores
        ├── mcp/               # MCP server, 47-tool registry, ports
        ├── http_api.rs        # Legacy JSON HTTP API
        ├── keyboard.rs        # Keystroke sidecar backend
        ├── resource.rs        # Resource arbiter (exclusive leases)
        ├── routing/           # Input resolver and mapping reconciliation
        └── lifecycle.rs       # Coordinated shutdown

tauri/
├── src-tauri/                 # Tauri shell (rust-ui IPC commands, updater, sidecars)
├── ui/                        # Svelte/TypeScript desktop frontend
├── keystroke/                 # Keyboard input sidecar (Rust)
└── virtual_joystick/          # Windows vJoy feeder sidecar (Rust)
```

## Coding Guidelines

### Type Safety

Model domain data as strongly-typed structs and enums (`crates/trenino-core`),
not untyped maps. When JSON is unavoidable (MCP, HTTP API, IPC), derive
`Serialize`/`Deserialize` on dedicated wire types.

### Float Precision

Round float values to 2 decimal places for hardware/calibration values using the
exact-decimal helper in `crates/trenino-core/src/rounding.rs`:

```rust
// Good
use trenino_core::rounding::round_elixir;
let value = round_elixir(raw_value, 2).ok_or(MyError::NonFinite)?;

// Bad — rounds the intermediate product to another binary float and can
// move values such as 2.675 across the decimal midpoint
let value = (raw_value * 100.0).round() / 100.0;
```

### Protocol Messages

Keep the Rust API using enum variants and the wire format using integers;
convert in encode/decode with byte-pattern matching in
`crates/trenino-core/src/hardware/protocol/codec.rs`:

```rust
// Good — enum in the API, integer on the wire
pub enum Message {
    SetOutput { pin: u8, high: bool },
    // ...
}

pub fn encode_message(m: &Message) -> Result<Vec<u8>, ProtocolError> {
    let mut out = Vec::new();
    match m {
        Message::SetOutput { pin, high } => out.extend([0x07, *pin, u8::from(*high)]),
        // ...
    }
    Ok(out)
}
```

## Running Tests

```bash
# Whole workspace (integration suites live in crates/trenino-runtime/tests/)
cargo test --workspace -- --test-threads=1

# A single suite
cargo test -p trenino-runtime --test simulator_detection

# Desktop UI
npm --prefix tauri/ui test

# Windows vJoy feeder
cargo test --manifest-path tauri/virtual_joystick/Cargo.toml
```

Integration suites run against fake services (no real hardware, serial ports or
simulator); a `fixtures/` directory supplies canned databases and responses.
Real serial firmware flashing and Windows driver mutation are separate,
equipment-gated acceptance checks (see
`docs/handoffs/2026-10-25-rust-parity/README.md`).

## Database

Trenino stores everything in a single SQLite database owned by the runtime
(`crates/trenino-runtime/src/storage/`).

- The full Rust schema is `crates/trenino-runtime/src/storage/schema/rust-full-v2.sql`.
- Databases created by older releases are recognized read-only and upgraded
  explicitly via the `migrate_legacy` path, which validates the legacy schema,
  takes a backup, and applies the transformation in one transaction.

There are no runtime migrations to run by hand; schema changes ship as new
schema versions handled in `storage/migration.rs`.

## Code Quality

```bash
cargo fmt --all --check
cargo clippy --workspace --all-targets -- -D warnings
```

## Architecture

### Runtime services

Long-running work runs as Tokio tasks/services composed in
`crates/trenino-runtime/src/composition/`:

- Simulator connection owner — API health and client handout
- Train detection — active train polling with two-layer defense
  (ObjectClass + ProviderName fallback)
- Lever/button/output/display controllers — input-to-simulator mapping,
  LED/output bindings, I2C display polling
- Script runner — sandboxed Lua execution and lifecycle management
- Hardware service — serial transport, device discovery, input broadcasting
- Firmware owner — catalog, downloads, uploads, exclusive serial handoff
- vJoy manager — Windows virtual joystick lifecycle and routing

A `ResourceArbiter` grants exclusive leases (serial ports, detection sessions,
calibration) so UI, MCP and HTTP callers cannot double-own hardware.
`lifecycle.rs` coordinates shutdown with the database closed last.

### UI snapshots and change events

The Svelte UI never talks to services directly. `app.rs` exposes
repository methods that return committed `UiSnapshot` values, and the Tauri
shell (`tauri/src-tauri/src/rust_ui.rs`) publishes changes as
`ui://change/{topic}` events (`settings`, `hardware`, `trains`, `bindings`,
`scripts`, `firmware`, `vjoy`) plus `ui://hardware/input` and
`ui://hardware/detection` streams. The frontend subscribes through the typed
bridge in `tauri/ui/src/bridge/`.

## Adding New Features

### New Input Type

1. Add the variant to the configure message(s) in
   `crates/trenino-core/src/hardware/protocol/codec.rs`
2. Extend the hardware configuration plan/repository in
   `crates/trenino-runtime/src/hardware/`
3. Add UI support in the configuration editor (`tauri/ui/`)
4. Update calibration if needed

### New Element Type

1. Add the type to the element model in `crates/trenino-core/src/train/`
2. Create a config struct (like the lever `LeverConfig`)
3. Add UI components for configuration (`tauri/ui/`)
4. Implement value mapping logic in the runtime controllers

### New Protocol Message

1. Add the variant to `Message` in
   `crates/trenino-core/src/hardware/protocol/codec.rs`
2. Extend `encode_message`/`decode_message` with its integer type byte
3. Handle it in the runtime hardware transport
   (`crates/trenino-runtime/src/hardware/transport.rs`)

## Debugging

### API Explorer

Built-in API explorer in the train configuration UI for testing simulator
endpoints.

### IPC events

The desktop UI's live state (hardware inputs, detection requests, topic
changes) is visible on the `ui://…` Tauri events; instrument listeners in
`tauri/ui/src/bridge/` when debugging stale-UI issues.

### Focused tests

Each runtime subsystem has an integration suite in
`crates/trenino-runtime/tests/` (for example `simulator_detection.rs`,
`hardware_runtime.rs`, `vjoy_manager.rs`); run the relevant one directly while
iterating.

## Building the Desktop App

Build the desktop bundle with:

```bash
./scripts/build-rust-desktop.sh
```

The script wraps `scripts/build-desktop.sh` with `TRENINO_BUILD_RUST=1` and
refuses to package if the required avrdude binary/config is missing (no
placeholder helper is staged). It uses `tauri/src-tauri/tauri.rust.conf.json`
(Windows: `tauri.rust.windows.conf.json`) and the `rust-ui desktop-updater`
features.

Pre-built releases are provided for Windows and Linux; macOS packages can be
built from an Apple Silicon checkout with the same script. Build artifacts land
under `tauri/src-tauri/target/`.

### Bundled Components

The desktop app bundles:
- **avrdude** - AVR programmer for firmware uploads
- **avrdude.conf** - Configuration file for avrdude
- **keystroke** - Keyboard input simulator for keystroke button bindings
- **virtual_joystick** (Windows only) - persistent vJoy feeder sidecar
- **vJoy runtime** (Windows only) - pinned signed installer, configurator, x64
  feeder DLL, license, and third-party notices

### Updating the pinned vJoy release

Do not use an unversioned release URL. Review the BrunnerInnovation release,
license, signing identity, SDK ABI, and configurator command line first. Download
the installer, SDK, and tagged license independently; calculate SHA-256 for each;
then update all matching pins in:

- `scripts/build-desktop.sh`
- `tauri/src-tauri/resources/vjoy.sha256`
- `tauri/src-tauri/Cargo.toml` package metadata
- `.github/workflows/ci.yml`
- `tauri/src-tauri/resources/THIRD_PARTY_NOTICES.md`

Exercise `scripts/download-vjoy.ps1` with both a wrong and correct checksum. A
mismatch must not replace an existing verified artifact. Run the Windows package
job and retain its uploaded NSIS artifact before performing the elevated VM
checklist.

### Shared vJoy state during uninstall

Trenino removes device 1 only when its persistent ownership marker and exact
descriptor both match. It never removes a driver it did not install. Even when
Trenino owns the driver and a healthy API probe reports zero devices, interactive
uninstall asks the user and defaults to retaining the potentially shared driver;
silent uninstall always retains it. Missing, disabled, incompatible, or otherwise
ambiguous driver state is retained with an installer log entry.
