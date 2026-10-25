# Architecture Overview

Trenino is built with Rust: a Tokio-based runtime (`crates/trenino-core`,
`crates/trenino-runtime`) behind a Tauri/Svelte desktop UI (`tauri/`),
providing real-time hardware-to-simulator communication.

## System Components

```
┌─────────────────────────────────────────────────────────────────────────┐
│                             Trenino                                     │
│                                                                         │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────────────────┐  │
│  │   Hardware   │    │  Tauri/Svelte│    │     Train Sim World      │  │
│  │   Devices    │◄──►│  Desktop UI  │◄──►│    External Interface    │  │
│  │  (USB/UART)  │    │  (IPC bridge)│    │         API              │  │
│  └──────────────┘    └──────┬───────┘    └──────────────────────────┘  │
│         │                  │                        │                   │
│         ▼                  ▼                        ▼                   │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────────────────┐  │
│  │    Serial    │    │  AppServices │    │       Simulator          │  │
│  │  transport + │    │  + UI change │    │  connection owner +      │  │
│  │   protocol   │    │   events     │    │    HTTP client           │  │
│  └──────┬───────┘    └──────┬───────┘    └────────────┬─────────────┘  │
│         └────────────┬─────┴──────────────────────────┘                │
│                      ▼                                                 │
│              ┌──────────────┐                                          │
│              │    SQLite    │                                          │
│              │   Database   │                                          │
│              └──────────────┘                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

## Core Domains

### Hardware Domain (`crates/trenino-core/src/hardware/`, `crates/trenino-runtime/src/hardware/`)

Manages physical device connections, input calibration, and I2C peripherals.

- **protocol** — Binary message codec (`Message` enum, `encode_message`/
  `decode_message`) shared by runtime and tests
- **calibration** — Raw-value normalization (`normalize`, `total_travel`) and
  notch analysis
- **ht16k33** - Segment encoder and display driver for HT16K33 LED displays
- **runtime hardware service** - Serial transport, device discovery,
  configuration plans, calibration sessions, and input value broadcasting

### Firmware Domain (`crates/trenino-runtime/src/firmware/`)

Manages firmware releases, device definitions, and firmware uploads.

- **repository / catalog** - Cache of available devices
  - Loads device list from firmware release manifests (release.json)
  - Merges dynamic device data with static hardware configurations
  - Provides fast lookups for device configuration (MCU, programmer, baud rate)
  - Falls back to hardcoded devices if no manifest available
- **http / downloads** - Fetches releases and triggers catalog reload
- **owner** - Owns uploads: flashes firmware to devices using avrdude with an
  exclusive serial-port lease and retryable cleanup
- **updates** - Automatic firmware checks with persisted notices

### Train Domain (`crates/trenino-core/src/train/`, `crates/trenino-runtime/src/train/`)

Handles train configurations and input-to-lever mappings.

- **identifier** - Train configurations with one or more equivalent identifier
  prefixes; each globally unique prefix is owned by exactly one train profile
- **lever** - `LeverConfig`, `Notch` (gate/linear) and `map_input`
- **buttons / output / display** - Button bindings, LED/output bindings, and
  display bindings (a simulator endpoint mapped to an I2C module with a format
  string such as `{value}` or `{value:.Nf}`)
- **service** - Train repository operations
- **detection** - Polls the simulator for the active train with two-layer
  defense (ObjectClass + ProviderName fallback)
- **lever_controller / button_controller / output_controller /
  display_controller** - Map hardware values to simulator values, drive
  outputs, and poll simulator subscriptions to write formatted values to I2C
  displays
- **script** - Sandboxed Lua execution environment with Trenino API bindings
  (`api`, `output`, `display`, `schedule`, `state`) and a runner managing
  script lifecycle and triggers (manual, on_train_active, on_input_change)
- **sequence** - Command sequences with per-step values and delays

### Simulator Domain (`crates/trenino-runtime/src/simulator/`)

Communicates with Train Sim World's External Interface API.

- **client** - HTTP client for the TSW API (default `http://localhost:31270`)
- **connection / connection_owner** - Connection health and client handout
- **subscriptions / writer** - Endpoint subscriptions and coalesced writes
- **services** - Train detection, interactive control detection, lever
  analysis, guided calibration, endpoint explorer/suggestions

### Virtual Joystick Domain (`crates/trenino-runtime/src/vjoy/`, `tauri/virtual_joystick/`)

Provides a standalone Windows DirectInput destination backed by vJoy device 1.

- **manager** owns lifecycle reconciliation, mappings, cached hardware state,
  safe defaults, bridge restart/backoff, and the public runtime state machine.
- The **bridge** owns a persistent sidecar child process, enforces bounded
  JSON Lines framing, correlates acknowledgements, and coalesces newer
  updates for an in-flight control.
- **configurator** performs fixed elevated create/delete commands, waits for
  Windows enumeration, validates the exact eight-axis/32-button descriptor, and
  records device ownership only after confirmed creation.
- **mapper** converts existing calibrated analog values to the axis range
  reported by vJoy, with clamping and optional inversion.

Every physical input is routed to exactly one destination. Storage-layer
transactions perform explicit replacement between simulator/API and virtual
joystick mappings so UI and MCP callers cannot bypass exclusivity.

### MCP Domain (`crates/trenino-runtime/src/mcp/`)

Model Context Protocol server for AI-powered configuration.

- **server** - JSON-RPC 2.0 dispatch with an SSE/POST HTTP transport
  (`GET /mcp/sse`, `POST /mcp/messages?session_id=...`) bound to `127.0.0.1:4000`
  by default (`TRENINO_MCP_PORT` override), with a degraded-not-fatal lifecycle
- **tools** - 47 tools across 11 categories:
  - **simulator** - Browse endpoints, read/write simulator values
  - **train** - List trains and get configurations
  - **element** - Manage train buttons and levers
  - **device** - List devices, inputs, outputs, and I2C modules; CRUD for I2C modules
  - **output_binding** - CRUD operations for output bindings
  - **button_binding** - CRUD operations for button bindings
  - **sequence** - CRUD operations for command sequences
  - **script** - CRUD operations for Lua scripts
  - **detection** - Interactive hardware input detection (prompts the user via a UI modal)
  - **display_binding** - CRUD operations for display bindings
  - **vjoy** - status, mapping, lifecycle, cleanup, and installation-check
    operations for the standalone joystick destination
- **ports / storage_ports** - The storage-backed trait ports every tool talks to
- A legacy JSON HTTP API (`http_api.rs`) shares the same ports and database owner

### Serial Domain (`crates/trenino-core/src/hardware/protocol/`)

Low-level USB/UART communication with hardware devices.

- **codec** - Binary message encoding/decoding (`Message` enum)
- Runtime **hardware::transport** - Device connections and framing
- Runtime **hardware::discovery** - Auto-discovers connected devices

## Data Flow

### Hardware Input to Simulator

```
┌────────────┐     ┌────────────┐     ┌────────────┐     ┌────────────┐
│  Physical  │     │   Serial   │     │   Lever    │     │ Simulator  │
│   Input    │────►│  Protocol  │────►│ Controller │────►│    API     │
│ (0-1023)   │     │ InputValue │     │  Mapping   │     │  (0.0-1.0) │
└────────────┘     └────────────┘     └────────────┘     └────────────┘
                         │                  │
                         ▼                  ▼
                   ┌────────────┐     ┌────────────┐
                   │Calibration │     │   Notch    │
                   │   Data     │     │   Config   │
                   └────────────┘     └────────────┘
```

1. **Raw Input** - Hardware sends 16-bit ADC value (0-1023)
2. **Normalization** - Calibration data converts to 0.0-1.0
3. **Notch Mapping** - `map_input` finds the notch and interpolates
4. **API Call** - The lever controller sends the latest value to the simulator

### Hardware Input to Virtual Joystick

```text
hardware service input event
  -> exclusive destination lookup
  -> vjoy::Manager
  -> bridge (persistent sidecar process)
  -> virtual_joystick.exe
  -> trusted absolute vJoyInterface.dll
  -> vJoy device 1 complete report
```

The native protocol is versioned UTF-8 JSON Lines over stdin/stdout. Commands
include `hello`, `set_axis`, `set_button`, `reset`, and `shutdown`; mutations
carry monotonically increasing request IDs. Diagnostics use stderr. The Rust
sidecar owns one complete eight-axis/32-button report, so changing one control
cannot reset another, and it acquires/releases an existing compatible device
without creating, deleting, or stealing it.

### Train Detection Flow

```
┌────────────┐     ┌────────────┐     ┌────────────┐
│ Simulator  │     │ Detection  │     │   Train    │
│    API     │────►│  Service   │────►│  Lookup    │
│ /Formation │     │ (5s poll)  │     │            │
└────────────┘     └─────┬──────┘     └────────────┘
                         │
                         ▼
                   ┌────────────┐
                   │  trains    │
                   │  snapshot  │
                   └────────────┘
```

## Runtime Services

Services are Tokio tasks composed in
`crates/trenino-runtime/src/composition/` and exposed through `app.rs`
(`AppServices`) repositories:

- Simulator connection owner (API health)
- Train detection (train polling with two-layer defense)
- Lever controller (hardware value → simulator mapping)
- Button controller (button input to simulator/keyboard/sequences)
- Output controller (LED/output bindings)
- Display controller (I2C display bindings, 200ms poll)
- Script runner (Lua script execution)
- Hardware service (device management and input broadcasts)
- vJoy manager (Windows vJoy lifecycle and routing)
- Firmware owner (catalog, downloads, uploads)
- Hardware and train calibration sessions (generation-fenced)
- MCP server and legacy JSON HTTP API

A `ResourceArbiter` (`resource.rs`) grants exclusive leases — serial ports,
detection sessions, calibration — so UI, MCP and HTTP callers cannot double-own
hardware. `lifecycle.rs` coordinates shutdown with the database closed last.

## Database Schema

The full schema lives in
`crates/trenino-runtime/src/storage/schema/rust-full-v2.sql`; databases from
older releases are migrated by `storage/migration.rs`.

```
devices                    trains
├── id                     ├── id
├── config_id (unique)     ├── identifiers[]
├── name                   ├── name
├── inputs[]               ├── elements[]
│   ├── pin                │   ├── name
│   ├── type               │   ├── type
│   ├── sensitivity        │   └── lever_config
│   └── calibration        │       ├── endpoints
│       ├── min_value      │       ├── notches[]
│       └── max_value      │       │   ├── kind (gate/linear)
└── i2c_modules[]          │       │   ├── sim_input_min/max
    ├── module_chip        │       │   └── input_min/max
    ├── i2c_address        │       └── input_binding
    ├── name               │           └── input_id
    └── params (JSON)      ├── scripts[]
        ├── brightness     │   ├── name
        ├── num_digits     │   ├── content (Lua code)
        ├── display_type   │   ├── triggers
        ├── has_dot        │   └── enabled
        ├── align_right    └── display_bindings[]
        └── min_value          ├── i2c_module_id (FK)
                               ├── endpoint
                               ├── format_string
                               └── enabled

firmware_releases          firmware_files
├── id                     ├── id
├── version                ├── release_id (FK)
├── tag_name (unique)      ├── filename
├── release_url            ├── download_url
├── release_notes          ├── file_size
├── published_at           ├── environment (PlatformIO env)
└── manifest_json          └── downloaded_at
```

Train identifiers are stored in the normalized `train_identifiers` table. Each row
belongs to one train, and a global unique index prevents the same exact prefix from
being assigned to multiple profiles.

## Communication Protocols

### Serial Protocol (Device ↔ Trenino)

Binary protocol with message types (`Message` in
`crates/trenino-core/src/hardware/protocol/codec.rs`):

| Type | Name | Direction | Description |
|------|------|-----------|-------------|
| 0x00 | IdentityRequest | App → Device | Request device info |
| 0x01 | IdentityResponse | Device → App | Device signature (version, config id) |
| 0x02 | Configure* | App → Device | Send input/output/I2C config in parts (subtype: analog, button, matrix, HT16K33) |
| 0x03 | ConfigurationStored | Device → App | Config acknowledged |
| 0x04 | ConfigurationError | Device → App | Config rejected |
| 0x05 | InputValue | Device → App | Real-time input data |
| 0x06 | Heartbeat | Both | Keep-alive |
| 0x07 | SetOutput | App → Device | Set digital output pin on/off |
| 0x08 | RetryCalibration | App → Device | Ask device to retry calibration for a pin |
| 0x0D | WriteSegments | App → Device | Write segment bytes to an I2C display |
| 0x0E | SetModuleBrightness | App → Device | Set I2C display brightness (0–15) |
| 0x0F | ModuleError | Device → App | I2C module error report |

### Simulator API (Trenino ↔ Train Sim World)

HTTP/JSON REST API on port 31270:

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/get/<path>.<endpoint>` | Read a value |
| PATCH | `/set/<path>.<endpoint>?Value=X` | Write a value |
| GET | `/list/<path>` | List controls under a path |
| POST | `/subscription/<path>?Subscription=ID` | Subscribe to endpoint |
| GET | `/subscription?Subscription=ID` | Read subscription values |

Example paths:
- `/get/CurrentDrivableActor/Throttle(Lever).InputValue`
- `/set/CurrentDrivableActor/Throttle(Lever).InputValue?Value=0.5`

See [TSW API Guide](TSW_API_GUIDE.md) for the full reference.

### MCP Protocol (AI Tools ↔ Trenino)

SSE (Server-Sent Events) transport implementing Model Context Protocol:

| Endpoint | Description |
|----------|-------------|
| `GET /mcp/sse` | SSE endpoint for MCP server |
| `POST /mcp/messages?session_id=...` | JSON-RPC 2.0 messages |

Bound to `127.0.0.1:4000` by default (`TRENINO_MCP_PORT` override). Supports
47 tools across 11 categories for AI-powered train configuration. See [MCP
Setup Guide](mcp-setup.md) for details.

## UI Change Events

The Svelte UI subscribes to committed snapshots through the typed IPC bridge
(`tauri/ui/src/bridge/`). The Tauri shell (`tauri/src-tauri/src/rust_ui.rs`)
publishes changes as Tauri events:

| Event | Payload | Description |
|-------|---------|-------------|
| `ui://change/settings` | Settings snapshot | Simulator URL/key, consent |
| `ui://change/hardware` | Hardware snapshot | Device plugged/unplugged, configuration |
| `ui://change/trains` | Trains snapshot | Active train changed, train edits |
| `ui://change/bindings` | Bindings snapshot | Lever/button/output/display bindings |
| `ui://change/scripts` | Scripts snapshot | Lua script edits and run state |
| `ui://change/firmware` | Firmware snapshot | Catalog, downloads, notices |
| `ui://change/vjoy` | vJoy snapshot | Joystick mappings and lifecycle |
| `ui://hardware/input` | Input value view | Per-port hardware input stream |
| `ui://hardware/detection` | Detection events | Coordinates MCP detection tools with the UI modal overlay |
