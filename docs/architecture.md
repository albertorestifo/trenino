# Architecture Overview

Trenino is built with Elixir and Phoenix LiveView, providing real-time hardware-to-simulator communication with a responsive web interface.

## System Components

```
┌─────────────────────────────────────────────────────────────────────────┐
│                             Trenino                                     │
│                                                                         │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────────────────┐  │
│  │   Hardware   │    │   Phoenix    │    │     Train Sim World      │  │
│  │   Devices    │◄──►│   LiveView   │◄──►│    External Interface    │  │
│  │  (USB/UART)  │    │     UI       │    │         API              │  │
│  └──────────────┘    └──────────────┘    └──────────────────────────┘  │
│         │                   │                        │                  │
│         ▼                   ▼                        ▼                  │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────────────────┐  │
│  │    Serial    │    │    Ecto      │    │       Simulator          │  │
│  │  Connection  │    │   SQLite     │    │       Connection         │  │
│  │   GenServer  │    │  Database    │    │        GenServer         │  │
│  └──────────────┘    └──────────────┘    └──────────────────────────┘  │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

## Core Domains

### Hardware Domain (`lib/trenino/hardware/`)

Manages physical device connections, input calibration, and I2C peripherals.

- **Device** - Configuration schema with unique `config_id`
- **Input** - Pin definitions (analog/digital) with sensitivity
- **I2cModule** - Schema for I2C-attached display modules (HT16K33 chip) with polymorphic params
- **HT16K33** - Segment encoder and display driver for HT16K33 LED displays
- **ConfigurationManager** - GenServer broadcasting input value changes

### Firmware Domain (`lib/trenino/firmware/`)

Manages firmware releases, device definitions, and firmware uploads.

- **DeviceRegistry** - GenServer maintaining ETS cache of available devices
  - Loads device list from firmware release manifests (release.json)
  - Merges dynamic device data with static hardware configurations
  - Provides fast lookups for device configuration (MCU, programmer, baud rate)
  - Falls back to hardcoded devices if no manifest available
- **FirmwareRelease** - GitHub release metadata with optional manifest
- **FirmwareFile** - Individual firmware binaries per device environment
- **Downloader** - Fetches releases and triggers registry reload
- **Uploader** - Flashes firmware to devices using avrdude

### Train Domain (`lib/trenino/train/`)

Handles train configurations and input-to-lever mappings.

- **Train** - Train configuration with unique identifier
- **Element** - Cab elements (levers, buttons)
- **LeverConfig** - API endpoints and notch definitions
- **LeverInputBinding** - Maps hardware inputs to levers
- **LeverMapper** - Converts hardware values to simulator values
- **LeverController** - GenServer that sends values to simulator
- **Detection** - GenServer polling simulator for active train with two-layer defense (ObjectClass + ProviderName fallback)
- **Script** - Lua scripts for train automation with configurable triggers
- **ScriptEngine** - Sandboxed Lua execution environment with Trenino API bindings (`api`, `output`, `display`, `schedule`, `state`)
- **ScriptRunner** - GenServer managing script lifecycle and execution
- **DisplayBinding** - Maps a simulator endpoint to an I2C display module with a format string
- **DisplayFormatter** - Evaluates format strings (`{value}`, `{value:.Nf}`) against runtime values
- **DisplayController** - GenServer that polls simulator subscriptions and writes formatted values to I2C displays

### Simulator Domain (`lib/trenino/simulator/`)

Communicates with Train Sim World's External Interface API.

- **Client** - HTTP client for TSW API
- **Connection** - GenServer managing connection health
- **AutoConfig** - Windows auto-detection of API key from `CommAPIKey.txt`

### MCP Domain (`lib/trenino/mcp/`)

Model Context Protocol server for AI-powered configuration.

- **Server** - MCP server implementation with SSE transport at `/mcp/sse`
- **ToolRegistry** - Registry of available MCP tools organized by category
- **Tools** - 37 tools across 10 categories:
  - **SimulatorTools** - Browse endpoints, read/write simulator values
  - **TrainTools** - List trains and get configurations
  - **ElementTools** - Manage train buttons and levers
  - **DeviceTools** - List devices, inputs, outputs, and I2C modules; CRUD for I2C modules
  - **DetectionTools** - Interactive hardware input detection (prompts the user via a UI modal)
  - **OutputBindingTools** - CRUD operations for output bindings
  - **ButtonBindingTools** - CRUD operations for button bindings
  - **SequenceTools** - CRUD operations for command sequences
  - **ScriptTools** - CRUD operations for Lua scripts
  - **DisplayBindingTools** - CRUD operations for display bindings

### Serial Domain (`lib/trenino/serial/`)

Low-level USB/UART communication with hardware devices.

- **Connection** - GenServer managing device connections
- **Discovery** - Auto-discovers connected devices
- **Protocol** - Binary message encoding/decoding

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
3. **Notch Mapping** - LeverMapper finds notch and interpolates
4. **API Call** - LeverController sends value to simulator

### Train Detection Flow

```
┌────────────┐     ┌────────────┐     ┌────────────┐
│ Simulator  │     │ Detection  │     │   Train    │
│    API     │────►│  GenServer │────►│  Context   │
│ /Formation │     │ (15s poll) │     │  Lookup    │
└────────────┘     └────────────┘     └────────────┘
                         │
                         ▼
                   ┌────────────┐
                   │  PubSub    │
                   │ Broadcast  │
                   └────────────┘
```

## GenServer Supervision Tree

```
Application
├── Trenino.Repo (Ecto)
├── TreninoWeb.Endpoint (Phoenix)
├── Trenino.Firmware.DeviceRegistry (device definitions cache)
├── Trenino.Serial.Connection (device management)
├── Trenino.Simulator.Connection (API health)
├── Trenino.Train.Detection (train polling with two-layer defense)
├── Trenino.Train.LeverController (hardware value → simulator mapping)
├── Trenino.Train.ButtonController (button input to simulator)
├── Trenino.Train.OutputController (LED/output bindings)
├── Trenino.Train.DisplayController (I2C display bindings, 200ms poll)
├── Trenino.Train.ScriptRunner (Lua script execution)
├── Trenino.Hardware.ConfigurationManager (input broadcasts)
└── Calibration Supervisors
    ├── Trenino.Hardware.Calibration.SessionSupervisor
    └── Trenino.Train.Calibration.SessionSupervisor
```

## Database Schema

```
devices                    trains
├── id                     ├── id
├── config_id (unique)     ├── identifier (unique)
├── name                   ├── name
├── inputs[]               ├── elements[]
│   ├── pin                │   ├── name
│   ├── type               │   ├── type
│   ├── sensitivity        │   └── lever_config
│   └── calibration        │       ├── endpoints
│       ├── min_value      │       ├── notches[]
│       └── max_value      │       │   ├── value
└── i2c_modules[]          │       │   ├── type
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

## Communication Protocols

### Serial Protocol (Device ↔ Trenino)

Binary protocol with message types:

| Type | Name | Direction | Description |
|------|------|-----------|-------------|
| 0x00 | IdentityRequest | App → Device | Request device info |
| 0x01 | IdentityResponse | Device → App | Device signature |
| 0x02 | Configure | App → Device | Send input config and I2C module definitions |
| 0x03 | ConfigurationStored | Device → App | Config acknowledged |
| 0x04 | ConfigurationError | Device → App | Config rejected |
| 0x05 | InputValue | Device → App | Real-time input data |
| 0x06 | Heartbeat | Both | Keep-alive |
| 0x07 | SetOutput | App → Device | Set digital output pin on/off |
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
| `/mcp/sse` | SSE endpoint for MCP server |

Supports 37 tools across 10 categories for AI-powered train configuration. See [MCP Setup Guide](../docs/mcp-setup.md) for details.

## Event Broadcasting (PubSub)

| Topic | Events | Description |
|-------|--------|-------------|
| `device_updates` | Connection changes | Device plugged/unplugged |
| `train:detection` | Train detected | Active train changed |
| `simulator:connection` | Status changes | API connection health |
| `serial:messages:{port}` | Input values | Per-port message stream |
| `hardware:input_values:{port}` | Input value updates | Per-port hardware input stream (used by InputDetectionSession) |
| `mcp:detection` | Detection requests/completions | Coordinates MCP detection tools with the UI modal overlay |
