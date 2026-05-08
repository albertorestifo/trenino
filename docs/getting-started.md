# Getting Started

Get Trenino up and running in minutes.

## Prerequisites

- **Train Sim World** (with External Interface API enabled — see [Enabling the TSW API](#enabling-the-tsw-api) below)
- **An Arduino board** — see [Supported Hardware](hardware-setup.md#compatible-microcontrollers) for the full list

That's it. The desktop app includes everything else: the Trenino backend, avrdude for firmware flashing, and all required runtimes.

## Installation

Download the latest installer for your platform from the [Releases page](https://github.com/albertorestifo/trenino/releases):

- **Windows**: Run the NSIS installer (`.exe`) or the MSI — the Visual C++ Redistributable is bundled, no separate install needed
- **Linux**: Download the `.AppImage`, then mark it executable and run it:
  ```bash
  chmod +x Trenino_*.AppImage
  ./Trenino_*.AppImage
  ```

> **macOS**: Pre-built installers are not yet available for macOS. See the [Development Guide](development.md#building-the-desktop-app) to build from source.

## Enabling the TSW API

Train Sim World ships with an External Interface API that Trenino uses to read and control your train. It's disabled by default.

1. Right-click **Train Sim World** in Steam → **Properties**
2. In the **General** tab, add `-HTTPAPI` to **Launch Options**
3. Launch the game once — this generates the API key file

On Windows, Trenino detects the API key automatically from `Documents\My Games\TrainSimWorld6\Saved\Config\CommAPIKey.txt`. On other platforms, enter the key manually in **Settings** → Simulator Connection.

## Firmware

Your Arduino needs the Trenino firmware before Trenino can talk to it. The easiest way is to flash it directly from the app — no separate tools required:

1. Plug in your Arduino via USB
2. In Trenino, go to **Firmware** in the sidebar
3. Select your board type and click **Flash Firmware**

The app downloads the latest firmware release and flashes it in one step using the bundled avrdude.

> If you prefer to flash manually, see the [Trenino Firmware repository](https://github.com/albertorestifo/trenino_firmware).

## First Run

The first time you launch Trenino, you'll be directed to a consent screen at `/consent`. It asks whether you'd like to share anonymous crash reports to help improve the app. You can change this at any time from the **Settings** page.

## Quick Setup Guide

Once Trenino is running and your hardware is connected:

### Step 1: Configure Simulator Connection

1. Start Train Sim World
2. In Trenino, click the **Settings** gear icon (⚙) in the navigation bar
3. Under **Simulator Connection**, the default URL is `http://localhost:31270` — change it if your simulator is on a different machine
4. **Windows**: if the API key is found in your Train Simulator folder it's used automatically; otherwise enter it manually in the **API Key** field
5. Click **Save** and verify the connection status in the nav bar shows "Connected"

### Step 2: Create Hardware Configuration

1. Click **Configurations** in the sidebar
2. Click **New Configuration**
3. Name it (e.g., "My Throttle Controller")
4. Add inputs for each physical control:
   - Click **Add Input**
   - Set pin number and type (Analog for potentiometers, Digital for buttons)
5. Save your configuration

### Step 3: Connect and Calibrate Hardware

1. Plug in your hardware device via USB
2. Click **Scan Devices** or wait for auto-discovery
3. Click **Apply to Device** on your configuration
4. For each analog input, click **Calibrate**:
   - Hold at minimum → samples are collected automatically
   - Sweep the full range
   - Hold at maximum → click Finish

### Step 4: Create Train Configuration

1. Load a train in Train Sim World
2. In Trenino, click **Trains**
3. The detected train appears — click **Create Configuration**
4. Add elements:
   - Click **Add Element**, name it (e.g., "Throttle"), choose type: Lever
5. Click **Configure** → the app suggests the matching simulator endpoint automatically

### Step 5: Bind Input to Lever

1. On your lever element, click **Configure**
2. Select your calibrated hardware input
3. Follow the **Map Notches** wizard to set input ranges for each notch

### Step 6: Test It Out!

1. Move your physical control
2. Watch the lever respond in Train Sim World
3. Adjust calibration or notch mapping if needed

## Next Steps

- [Hardware Setup Guide](hardware-setup.md) — detailed device and input configuration
- [Train Configuration](train-configuration.md) — advanced lever and button setup
- [Lua Scripting](lua-scripting.md) — automate lighting, sequences, and more
- [MCP Setup](mcp-setup.md) — use Claude AI to configure your trains by conversation

## Troubleshooting

### Simulator Won't Connect

- Ensure Train Sim World is running with `-HTTPAPI` in launch options
- Check that no firewall is blocking port 31270
- On Windows, verify `Documents\My Games\TrainSimWorld6\Saved\Config\CommAPIKey.txt` exists; Trenino reads it automatically
- Open **Settings** and check that the simulator URL is correct (default `http://localhost:31270`)

### Device Not Found

- Check the USB cable and try a different port
- Verify the device has been flashed with Trenino firmware (see **Firmware** section above)
- Click **Scan Devices** to trigger a manual scan
- Check that no other application (e.g., the Arduino IDE) has the serial port open

### No Response from Train Controls

- Verify the train configuration is active (check the **Trains** page)
- Confirm the input binding is enabled
- Make sure calibration completed successfully (inputs show a normalized value)
- Use the API Explorer to test your simulator endpoint paths directly

---

## For Developers

If you want to contribute to Trenino or run it from source, see the [Development Guide](development.md). You'll need Elixir 1.15+, Erlang/OTP 26+, and Node.js.
