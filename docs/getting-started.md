# Getting Started

Get Trenino up and running in minutes.

## Prerequisites

- **Train Sim World** (with External Interface API enabled — see [Enabling the TSW API](#enabling-the-tsw-api) below)
- **An Arduino board** — see [Supported Hardware](hardware-setup.md#compatible-microcontrollers) for the full list

That's it. The desktop app includes everything else: the Trenino backend, avrdude for firmware flashing, and all required runtimes.

Virtual joystick mode is optional and currently available only on Windows
10/11. It needs the [vJoy 2.2.2.0 driver](https://github.com/BrunnerInnovation/vJoy/releases/tag/v2.2.2.0), which Trenino does not
install for you.

## Installation

Download the latest installer for your platform from the [Releases page](https://github.com/albertorestifo/trenino/releases):

- **Windows**: Run the NSIS installer (`.exe`) or the MSI — the Visual C++ Redistributable is bundled, no separate install needed. Prefer the NSIS `.exe`: its uninstaller also removes the virtual joystick device Trenino created, which the MSI does not.
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

On Windows, Trenino detects the API key automatically from `Documents\My Games\TrainSimWorld7\Saved\Config\CommAPIKey.txt`, falling back to the equivalent `TrainSimWorld6` folder. On other platforms, enter the key manually in **Settings** → Simulator Connection.

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

## Set Up a Physical Gauge (Speedometer)

If your panel has a stepper motor driving a needle, Trenino can walk you through the
whole setup, including the dial marks, without knowing any of the settings in advance.
For wiring and background see [Physical stepper gauges](stepper-gauges.md).

1. Open your configuration, find **Stepper axes**, click **Add gauge**, give it a name
   and pick the shield port. Click **Add and set up**: the guided setup opens right away.
   (Later, **Set up gauge** on the card or **Run gauge setup again** in its menu opens it.)
2. If Trenino later loses track of the needle (after a reconnect or a fault), the card
   says **Needs re-zero**: click **Re-zero** and it hands the gauge back to the train.
3. **Check**: the wizard confirms the controller is connected, the settings are on it
   and the motor is wired. It sends the settings if they are not. If you have a display
   at address 0x70, it repeats the warning about registering the shield first.
4. **Direction**: turn the needle by hand onto the 0 mark and press *The needle is on 0*.
   Trenino nudges it up a little. If it did not go up the dial, say so: Trenino flips the
   direction and sends it to the controller, and you line the needle up on 0 again.
5. **Dial**: enter the lowest and highest dial value and its unit (for example 0 to 100
   mph). Trenino moves the needle to evenly spaced marks; nudge it until it sits exactly
   on the mark and capture what the dial reads. Later marks start closer to the right
   place because Trenino learns the dial's scale from the first one.
6. **Verify**: the needle returns to 0 and you confirm it is exactly on the mark (this
   catches skipped steps), then it goes to a mark in between.
7. **Automatic zeroing** (optional, recommended): the needle sweeps into its end stop to
   find zero by itself. Trenino lengthens the sweep if needed, you nudge the needle onto
   0 once, and Trenino remembers the distance.
8. **Finish**: confirm the gauge works, give it a name, and the wizard shows the trains
   that already use it. Add the gauge to a train from **Trains > Gauges > Add gauge**.

A **Stop** button is visible whenever the needle moves. Closing the wizard at any point
stops the gauge and gives control back; steps that were already saved stay saved.

## Windows Virtual Joystick Mode

Virtual joystick mode lets Windows games see selected Trenino controls as one
generic DirectInput joystick. The first release exposes device 1 with these
fixed controls:

- Axes: X, Y, Z, Rx, Ry, Rz, Slider 1, and Slider 2
- Buttons: 1 through 32

Before using this mode, install the [vJoy 2.2.2.0 driver](https://github.com/BrunnerInnovation/vJoy/releases/tag/v2.2.2.0) (download
`vJoySetup_v2.2.2.0_Win10_Win11.exe` from that release and run it). Trenino
bundles the vJoy helper files it needs, but not the driver. If the driver is
missing, the Virtual joystick page says so and links to the same release.

It is Windows-only and does not require Train Sim World or an active train
configuration. Each physical input has one exclusive destination: it can be a
simulator/API or keystroke binding, or a virtual joystick control, but never
both. Trenino asks for confirmation before replacing an existing destination.

### Map and enable controls

1. Connect your hardware and calibrate every analog input you want to use.
2. Open **Virtual joystick** in the sidebar.
3. Add a mapping, select a hardware input, and choose an unused axis or button.
   Use **Invert** when an axis should move in the opposite direction.
4. If the input already controls a simulator action, review and confirm the
   replacement. Cancelling leaves the old binding unchanged.
5. Turn on **Virtual joystick mode**, read the administrator-permission notice,
   and accept the Windows UAC prompt.

Windows requests administrator permission whenever Trenino creates or removes
the virtual device, so both enabling and disabling can show UAC. A transition is
complete only after Trenino confirms that Windows added or removed the device.

### Verify it in Windows

Press `Win+R`, run `joy.cpl`, select the vJoy device, and open **Properties**.
Move each mapped lever and press each mapped button. The test page should show
the corresponding axis or button. Disable the mode and refresh Game Controllers;
device 1 should disappear completely.

Closing Trenino while the mode is enabled safely centers the axes, releases the
buttons, and relinquishes the feeder, but it deliberately leaves the device
enumerated. Reopen Trenino to reacquire it, or explicitly disable the mode to
remove it from Windows.

### Recovery

- **UAC was cancelled:** no confirmed setting is changed. Retry Enable/Disable
  and accept the prompt when ready.
- **Device is busy:** another feeder owns vJoy device 1. Close that application,
  then choose **Retry**. Trenino never steals the device.
- **Needs setup:** the saved request is enabled but the device is absent. Choose
  **Retry** after checking the driver installation.
- **Leftover device / Needs cleanup:** the saved mode is off but device 1 still
  exists. Choose **Remove leftover device** and accept UAC. Trenino refuses to
  delete a device with incompatible capabilities.
- **Driver is missing:** install the [vJoy 2.2.2.0 driver](https://github.com/BrunnerInnovation/vJoy/releases/tag/v2.2.2.0), then
  choose **Check installation**. If another vJoy version is installed and the
  mode still does not work, install 2.2.2.0 over it.
- **Device configuration is incompatible:** inspect or remove the conflicting
  vJoy device configuration, then choose **Check configuration**. Trenino does
  not silently replace unknown shared driver or device state.

## Next Steps

- [Hardware Setup Guide](hardware-setup.md) — detailed device and input configuration
- [Train Configuration](train-configuration.md) — advanced lever and button setup
- [Lua Scripting](lua-scripting.md) — automate lighting, sequences, and more
- [MCP Setup](mcp-setup.md) — use Claude AI to configure your trains by conversation

## Troubleshooting

### Simulator Won't Connect

- Ensure Train Sim World is running with `-HTTPAPI` in launch options
- Check that no firewall is blocking port 31270
- On Windows, verify `CommAPIKey.txt` exists under `Documents\My Games\TrainSimWorld7\Saved\Config` or `Documents\My Games\TrainSimWorld6\Saved\Config`; Trenino reads it automatically
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

If you want to contribute to Trenino or run it from source, see the [Development Guide](development.md). You'll need Elixir 1.20, Erlang/OTP 29, and Node.js.
