# Architecture Overview

TWS IO is built with Elixir and Phoenix LiveView, providing real-time hardware-to-simulator communication with a responsive web interface.

## System Components

```
┌─────────────────────────────────────────────────────────────────────────┐
│                              TWS IO                                     │
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

Manages physical device connections and input calibration.

- **Device** - Configuration schema with unique `config_id`
- **Input** - Pin definitions (analog/digital) with sensitivity
- **ConfigurationManager** - GenServer broadcasting input value changes
- **Calibration** - Multi-step wizard for input calibration

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
- **ScriptEngine** - Sandboxed Lua execution environment with Trenino API bindings
- **ScriptRunner** - GenServer managing script lifecycle and execution

### Simulator Domain (`lib/trenino/simulator/`)

Communicates with Train Sim World's External Interface API.

- **Client** - HTTP client for TSW API
- **Connection** - GenServer managing connection health
- **AutoConfig** - Windows auto-detection of API key

### MCP Domain (`lib/trenino/mcp/`)

Model Context Protocol server for AI-powered configuration.

- **Server** - MCP server implementation with SSE transport at `/mcp/sse`
- **ToolRegistry** - Registry of available MCP tools organized by category
- **Tools** - 20 tools across 6 categories:
  - **ElementTools** - Manage train buttons and levers
  - **TrainTools** - List trains and get configurations
  - **DeviceTools** - List devices, inputs, and outputs
  - **ButtonBindingTools** - CRUD operations for button bindings
  - **OutputBindingTools** - CRUD operations for output bindings
  - **SequenceTools** - CRUD operations for command sequences
  - **SimulatorTools** - Browse endpoints, read/write simulator values

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
├── Trenino.Train.LeverController (value mapping)
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
└── inputs[]               ├── elements[]
    ├── pin                │   ├── name
    ├── type               │   ├── type
    ├── sensitivity        │   └── lever_config
    └── calibration        │       ├── endpoints
        ├── min_value      │       ├── notches[]
        └── max_value      │       │   ├── value
                           │       │   ├── type
                           │       │   └── input_min/max
                           │       └── input_binding
                           │           └── input_id
                           └── scripts[]
                               ├── name
                               ├── content (Lua code)
                               ├── triggers (manual, on_train_active, on_input_change)
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

### Serial Protocol (Device ↔ TWS IO)

Binary protocol with message types:

| Type | Name | Direction | Description |
|------|------|-----------|-------------|
| 0x01 | IdentityRequest | App → Device | Request device info |
| 0x01 | IdentityResponse | Device → App | Device signature |
| 0x02 | Configure | App → Device | Send input config |
| 0x03 | ConfigurationStored | Device → App | Config acknowledged |
| 0x04 | Heartbeat | Both | Keep-alive |
| 0x05 | InputValue | Device → App | Real-time input data |

### Simulator API (TWS IO ↔ Train Sim World)

HTTP/JSON REST API:

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/Info` | List available commands |
| GET | `/Path/{path}` | Read cab element value |
| PUT | `/Path/{path}` | Set cab element value |

Example paths:
- `/CurrentDrivableActor/Throttle(Lever).InputValue`
- `/CurrentDrivableActor/Reverser(Lever).NotchesIndex`

### MCP Protocol (AI Tools ↔ Trenino)

SSE (Server-Sent Events) transport implementing Model Context Protocol:

| Endpoint | Description |
|----------|-------------|
| `/mcp/sse` | SSE endpoint for MCP server |

Supports 20 tools across 6 categories for AI-powered train configuration. See [MCP Setup Guide](../docs/mcp-setup.md) for details.

## Event Broadcasting (PubSub)

| Topic | Events | Description |
|-------|--------|-------------|
| `device_updates` | Connection changes | Device plugged/unplugged |
| `train:detection` | Train detected | Active train changed |
| `simulator:connection` | Status changes | API connection health |
| `serial:messages:{port}` | Input values | Per-port message stream |
