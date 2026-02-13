<p align="center">
  <img src="icon.png" alt="trenino" width="128" height="128">
</p>

<h1 align="center">Trenino</h1>
<p align="center"><em>Train Sim World + Arduino • "Model train" in Italian</em></p>

<p align="center">
  <strong>Bridge your custom hardware to Train Sim World</strong>
</p>

<p align="center">
  <a href="#what-you-can-do">What You Can Do</a> •
  <a href="#getting-started">Getting Started</a> •
  <a href="#roadmap">Roadmap</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Train_Sim_World-6-blue" alt="TSW6">
  <img src="https://img.shields.io/badge/License-CC%20BY--NC-green" alt="License">
</p>

---

## What You Can Do

**[See Trenino in action!](https://www.youtube.com/watch?v=FcnUJaJU0Wo)**

Trenino bridges the gap between physical hardware and Train Sim World.
Build your own train controls with real throttle levers, brake handles, switches, and gauges—then connect them to the game through a simple desktop app.
No programming required. Just wire up your Arduino, flash the firmware with one click, and start driving.

- **Flash Arduino boards** directly from the app with pre-built firmware
- **Calibrate your controls** with a guided step-by-step process
- **Auto-detect trains** and load saved configurations automatically
- **Map any control** to simulator inputs using the built-in API explorer
- **BLDC haptic levers** with programmable force feedback and virtual detents
- **Set up trains with Claude AI** — describe what you want in plain language and let Claude configure buttons, LEDs, and sequences for you via [MCP integration](docs/mcp-setup.md)

---

## Getting Started

### Requirements

- Train Sim World 6 with External Interface API enabled. See [How to Enable the TSW API](#how-to-enable-the-tsw-api).
- An Arduino-compatible micro-controller. See [Supported Hardware](#supported-hardware).

### Installation

Download the latest release for Windows from the [Releases page](https://github.com/albertorestifo/trenino/releases).

### Setup and usage

See the video tutorial (WIP).

---

## Development

```bash
# Clone and setup
git clone https://github.com/albertorestifo/trenino.git
cd trenino
mix deps.get
mix ecto.setup

# Run the server
mix phx.server
```

Visit [http://localhost:4000](http://localhost:4000)

See the [docs](docs/) folder for architecture and development guides.

---

## How to Enable the TSW API

Train Sim World 6 includes an External Interface API that allows third-party applications to communicate with the simulator. To enable it:

### 1. Add the Launch Flag

1. Right-click Train Sim World 6 in Steam
2. Select **Properties**
3. In the **General** tab, find **Launch Options**
4. Add `-HTTPAPI`

### 2. Launch the game

The game must be launched to generate the API key for the first time.
Trenino will automatically detect the API key when started.

---

## Supported Hardware

Trenino supports the following Arduino-compatible boards:

| Board                         | MCU        | Analog Inputs | Digital I/O | BLDC Support |
| ----------------------------- | ---------- | ------------- | ----------- | ------------ |
| Arduino Uno                   | ATmega328P | 6             | 14          | No           |
| Arduino Nano                  | ATmega328P | 8             | 14          | No           |
| Arduino Nano (Old Bootloader) | ATmega328P | 8             | 14          | No           |
| Arduino Leonardo              | ATmega32U4 | 12            | 20          | No           |
| Arduino Micro                 | ATmega32U4 | 12            | 20          | No           |
| Arduino Mega 2560             | ATmega2560 | 16            | 54          | Yes          |
| SparkFun Pro Micro            | ATmega32U4 | 12            | 18          | No           |

**Recommended boards:**

- **Arduino Nano** - Compact and affordable, great for simple setups with a few levers
- **Arduino Mega 2560** - Best for complex builds with many inputs or BLDC haptic levers
- **SparkFun Pro Micro** - Small form factor with native USB

All boards can be flashed directly from Trenino without any additional software.

### BLDC Haptic Lever Requirements

For advanced haptic feedback with programmable force feedback:

- **Arduino Mega 2560** - Required for BLDC motor control
- **SimpleFOCShield v2** - Motor driver board
- **BLDC Motor** - 7 pole pairs typical
- **AS5047D Encoder** - 14-bit magnetic encoder

See [BLDC Lever Documentation](docs/features/bldc-levers.md) for setup instructions.

---

## License

[CC BY-NC 4.0](https://creativecommons.org/licenses/by-nc/4.0/) - Free to use and modify for non-commercial purposes.

For commercial licensing, contact [alberto@restifo.dev](mailto:alberto@restifo.dev).

---

## Acknowledgment

This project was inspired by [MobiFlight](https://www.mobiflight.com/en/index.html).
