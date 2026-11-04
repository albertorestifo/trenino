<h1 align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="priv/static/images/trenino-lockup-dark.svg">
    <img src="priv/static/images/trenino-lockup-primary.svg" alt="Trenino" width="280">
  </picture>
</h1>
<p align="center"><em>Train Sim World + Arduino · "Model train" in Italian</em></p>

<p align="center">
  <strong>Bridge your custom hardware to Train Sim World</strong>
</p>

<p align="center">
  <a href="#features">Features</a> ·
  <a href="#getting-started">Getting Started</a> ·
  <a href="#supported-hardware">Supported Hardware</a> ·
  <a href="#development">Development</a> ·
  <a href="https://discord.gg/d75tmjwUav">Discord</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Train_Sim_World-6_%26_7-blue" alt="TSW6 and TSW7">
  <img src="https://img.shields.io/badge/License-CC%20BY--NC-green" alt="License">
</p>

<p align="center">
  <a href="https://discord.gg/d75tmjwUav">
    <img src="https://img.shields.io/badge/Join_the_Trenino_Discord-5865F2?style=for-the-badge&logo=discord&logoColor=white" alt="Join the Trenino Discord" height="40">
  </a>
  <br>
  <sub>Share your builds, get help with wiring and setup, and follow what's coming next.</sub>
</p>

## Features

**[See Trenino in action!](https://www.youtube.com/watch?v=FcnUJaJU0Wo)**

Build your own train controls with real throttle levers, brake handles, switches, and gauges — then connect them to Train Sim World through a simple desktop app. No programming required. Wire up your Arduino, flash the firmware with one click, and start driving.

- **One-click firmware flashing** — flash Arduino boards directly from the app, no extra software needed
- **Guided calibration** — step-by-step process to calibrate your levers and controls
- **Auto-detection** — automatically recognizes which train you're driving and loads the right configuration
- **Visual control mapping** — map any hardware input to simulator controls using the built-in API explorer
- **Windows virtual joystick** — expose selected calibrated levers and buttons as one removable DirectInput joystick with eight axes and 32 buttons, independently of Train Sim World
- **I2C display modules** — show live simulator data (speed, brake pressure, gear position) on HT16K33 7- or 14-segment LED displays wired to your Arduino
- **Physical stepper gauges** — drive real needle gauges with stepper motors and bind them to live simulator data such as speed or brake pressure ([stepper gauges guide](docs/stepper-gauges.md))
- **Lua scripting** — write custom logic to flash warning LEDs, react to speed changes, automate sequences, and more ([scripting guide](docs/lua-scripting.md))
- **AI-assisted setup** — describe what you want in plain language and let Claude configure your train via [MCP integration](docs/mcp-setup.md). With Trenino open, a coding agent such as Claude Code or Codex can set itself up when you ask it to "install the Trenino MCP" (setup guide for agents at `http://localhost:4000/llms.txt`, in releases newer than 0.8.2)

## Getting Started

### Requirements

- **Train Sim World 6 or 7** with the External Interface API enabled (see [below](#enabling-the-tsw-api))
- **An Arduino board** — see [Supported Hardware](#supported-hardware)

Virtual joystick mode is optional and additionally requires Windows 10 or 11
and the [vJoy 2.2.2.0 driver](https://github.com/BrunnerInnovation/vJoy/releases/tag/v2.2.2.0), which you install separately. See
[Getting Started](docs/getting-started.md#windows-virtual-joystick-mode).

### Installation

Download the latest installer for your platform from the [Releases page](https://github.com/albertorestifo/trenino/releases):

- **Windows 10/11**: use the NSIS installer (`.exe`), which installs the bundled Visual C++ Redistributable and removes Trenino's virtual joystick device on uninstall. The MSI does not run these hooks; its prerequisites must be installed separately.
- **Linux**: AppImage (`.AppImage`) — download, mark as executable, and run

macOS builds are not provided as pre-built releases. See the [Development Guide](docs/development.md#building-the-desktop-app) to build from source.

### Updating

Starting with the first updater-enabled stable release, choose **Help → Check for
Updates** to install a newer stable version. Existing users must install that
first release manually once. Finish firmware flashing and stop simulator controls
before accepting an update; Trenino closes during installation.

Nightly builds still require manual installation. Updater signatures verify update
authenticity, but are not Windows publisher certificates, so Windows may still
show an installation warning. See [distribution details](docs/windows-distribution.md).

### Enabling the TSW API

Train Sim World 6 and 7 ship with an External Interface API for third-party apps. To enable it:

1. Right-click **Train Sim World 6 or 7** in Steam → **Properties**
2. In the **General** tab, add `-HTTPAPI` to **Launch Options**
3. Launch the game once to generate the API key

Trenino detects the API key automatically on startup.

## Supported Hardware

| Board | MCU | Analog Inputs | Digital I/O | Status |
|---|---|---|---|---|
| Arduino Nano | ATmega328P | 8 | 14 | Fully tested |
| Arduino Nano (New Bootloader) | ATmega328P | 8 | 14 | Fully tested |
| SparkFun Pro Micro | ATmega32U4 | 12 | 18 | Fully tested |
| Arduino Uno | ATmega328P | 6 | 14 | Supported |
| Arduino Leonardo | ATmega32U4 | 12 | 20 | Supported |
| Arduino Micro | ATmega32U4 | 12 | 20 | Supported |
| Arduino Mega 2560 | ATmega2560 | 16 | 54 | Supported |

All boards can be flashed directly from Trenino.

## Development

```bash
git clone https://github.com/albertorestifo/trenino.git
cd trenino
mix setup
mix phx.server
```

Visit [localhost:4000](http://localhost:4000). See the [docs](docs/) folder for architecture and development guides.

## License

[CC BY-NC 4.0](https://creativecommons.org/licenses/by-nc/4.0/) — free to use and modify for non-commercial purposes.
For commercial licensing, contact [alberto@restifo.dev](mailto:alberto@restifo.dev).

## Acknowledgment

Inspired by [MobiFlight](https://www.mobiflight.com/en/index.html).
