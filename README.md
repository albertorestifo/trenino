<p align="center">
  <img src="icon.png" alt="tsw_io" width="128" height="128">
</p>

<h1 align="center">tsw_io</h1>

<p align="center">
  <strong>Bridge your custom hardware to Train Sim World</strong>
</p>

<p align="center">
  <a href="#what-you-can-do">What You Can Do</a> •
  <a href="#getting-started">Getting Started</a> •
  <a href="#how-it-works">How It Works</a> •
  <a href="#roadmap">Roadmap</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Train_Sim_World-6-blue" alt="TSW6">
  <img src="https://img.shields.io/badge/License-CC%20BY--NC-green" alt="License">
</p>

---

## What You Can Do

tsw_io lets you connect real hardware controls to Train Sim World. Build your own train cab with actual throttle levers, brake handles, and switches.

### Connect Your Hardware

- **Plug in your device** and tsw_io automatically detects it
- **Use multiple controllers** at the same time
- **Calibrate analog inputs** with a guided wizard that finds min/max values and detent positions

### Configure Your Trains

- **Auto-detect the train** you're currently driving
- **Discover available controls** directly from the simulator
- **Map physical controls to train levers** with a step-by-step wizard
- **Save profiles per train** so switching trains is seamless

### Drive with Real Controls

- **Low-latency input** streaming to the simulator
- **Automatic reconnection** if the connection drops
- **Real-time feedback** showing input values as you move controls

---

## Getting Started

### Requirements

- Train Sim World 6 with External Interface API enabled
- Hardware device running [tsw_board firmware](https://github.com/albertorestifo/tsw_board)

### Installation

Download the latest release for your platform from the [Releases page](https://github.com/albertorestifo/tsw_io/releases).

### Setup

1. **Connect to Simulator** - Enter your API URL and key (auto-detected on Windows)
2. **Add Your Hardware** - Create a device config and define your input pins
3. **Calibrate Inputs** - Run the wizard for each analog input
4. **Configure a Train** - Create a profile and detect available levers
5. **Bind Controls** - Link your calibrated inputs to train levers
6. **Map Notches** - Set input ranges for each notch position

---

## How It Works

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   Hardware   │     │    tsw_io    │     │  Train Sim   │
│   Device     │────▶│    Server    │────▶│    World     │
│              │ USB │              │ API │              │
└──────────────┘     └──────────────┘     └──────────────┘
```

1. Your hardware sends input values over USB
2. tsw_io normalizes them using your calibration data
3. Notch mapping converts to simulator values
4. API calls update train controls in real-time

---

## Roadmap

**Output Support**
- LED indicators driven by simulator state
- Displays showing speed, pressure, and other values
- Haptic feedback for force effects

**More Input Types**
- Digital inputs for buttons and switches
- Rotary encoders for infinite-rotation knobs
- Matrix keyboards for button panels

**Platform & Features**
- Train Sim World 5 support
- Configuration import/export to share profiles
- Custom input response curves
- Macros for triggering action sequences

---

## Development

```bash
# Clone and setup
git clone https://github.com/albertorestifo/tsw_io.git
cd tsw_io
mix deps.get
mix ecto.setup

# Run the server
mix phx.server
```

Visit [http://localhost:4000](http://localhost:4000)

See the [docs](docs/) folder for architecture and development guides.

---

## License

[CC BY-NC 4.0](https://creativecommons.org/licenses/by-nc/4.0/) - Free to use and modify for non-commercial purposes.

For commercial licensing, contact [alberto@restifo.dev](mailto:alberto@restifo.dev).
