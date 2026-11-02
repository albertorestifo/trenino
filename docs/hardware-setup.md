# Hardware Setup Guide

This guide covers connecting and configuring physical hardware devices with trenino.

## Firmware

The easiest way to install firmware is directly from the Trenino app — no separate tools needed:

1. Plug in your Arduino via USB
2. In Trenino, go to **Firmware** in the sidebar
3. Select your board type and click **Flash Firmware**

The app downloads the latest firmware release and flashes it in one step.

If you prefer to flash manually, see the [trenino_firmware repository](https://github.com/albertorestifo/trenino_firmware).

## Supported Hardware

trenino communicates with microcontroller-based devices via USB serial running the trenino_firmware firmware.

### Compatible Microcontrollers

The following Arduino boards are tested and supported with one-click firmware flashing from the app:

| Board | MCU | Analog Inputs | Digital I/O |
|---|---|---|---|
| Arduino Nano | ATmega328P | 8 | 14 |
| Arduino Nano (New Bootloader) | ATmega328P | 8 | 14 |
| SparkFun Pro Micro | ATmega32U4 | 12 | 18 |
| Arduino Uno | ATmega328P | 6 | 14 |
| Arduino Leonardo | ATmega32U4 | 12 | 20 |
| Arduino Micro | ATmega32U4 | 12 | 20 |
| Arduino Mega 2560 | ATmega2560 | 16 | 54 |

Other microcontrollers with USB serial and ADC inputs may work if you flash the firmware manually, but are not officially supported.

### Input Types

| Type | Description | Use Case |
|------|-------------|----------|
| Analog | 10-bit ADC (0-1023) | Potentiometers, throttle levers |
| Digital | On/Off state | Buttons, momentary switches, toggle switches |
| Matrix | Grid of digital inputs via row/column GPIO pins | Button matrices, arcade panels |

## Creating a Device Configuration

1. Navigate to **Configurations** in the sidebar
2. Click **New Configuration**
3. Enter a descriptive name (e.g., "Throttle Panel", "Reverser Controller")
4. Save the configuration

Each configuration receives a unique `config_id` that links it to physical hardware.

## Adding Input Pins

For each physical input on your device:

1. Open your configuration
2. Click **Add Input**
3. Configure:
   - **Name** - A friendly label shown in train configuration selectors (e.g., "Throttle Lever", "Horn Button")
   - **Pin Number** - The ADC pin on your microcontroller
   - **Input Type** - Analog or Digital
   - **Sensitivity** - Value change threshold (1-255, default 5)
4. Save the input

### Sensitivity Setting

The sensitivity value determines how much the input must change before sending an update. Lower values = more responsive but more network traffic.

| Value | Use Case |
|-------|----------|
| 1-3 | High precision requirements |
| 5 | Default, good balance |
| 10-20 | Noisy inputs, reduce chatter |

## Connecting Your Device

### Automatic Discovery

trenino automatically scans for devices every 60 seconds. Connected devices appear in the sidebar navigation.

### Manual Scan

Click the **Scan Devices** button to immediately discover connected devices.

### Device Status

| Status | Meaning |
|--------|---------|
| Connected | Device online and communicating |
| Disconnected | Device not responding |
| Unconfigured | No configuration applied |

## Applying Configuration to Device

Once your device is connected and configuration is ready:

1. Open the configuration
2. Click **Apply to Device**
3. Select the target device from the dropdown
4. The configuration is sent to the device

The device stores the `config_id` and begins streaming input values.

## I2C Display Modules

I2C display modules let you show live simulator data — speed, brake pressure, gear position — on physical LED displays attached to your Arduino. Trenino supports **HT16K33**-based displays, which are common on 7-segment and 14-segment Adafruit backpacks.

### Wiring

Connect the display to your Arduino via I2C:

| Display Pin | Arduino Nano/Uno | Arduino Mega |
|-------------|-----------------|--------------|
| SDA | A4 | 20 (SDA) |
| SCL | A5 | 21 (SCL) |
| VCC | 5V | 5V |
| GND | GND | GND |

Most HT16K33 boards have solder jumpers to set the I2C address (default `0x70`; jumpers change the lower bits to give addresses `0x70`–`0x77`).

### Adding an I2C Module to a Configuration

1. Open your device configuration (**Configurations** → select your config)
2. Open the **Displays** section and click **Add display**
3. Configure:
   - **Name** — optional friendly label (e.g., "Speed Display")
   - **I2C Address** — enter as decimal (`112`) or hex (`0x70`)
   - **Display Type** — `14-segment` (alphanumeric, default) or `7-segment` (numeric only)
   - **Advanced display settings: Brightness** — 0–100% slider (maps to hardware levels 0–15)
   - **Digits** — number of digits on the display: `4` or `8`
   - **Orientation** — re-orients the output for physically rotated or mirrored mounts: `Normal`, `Rotated 180°`, `Flipped horizontal`, or `Flipped vertical`. Applied in software, so it works with every binding and Lua `display.set`
   - **Minimum value** — clamp values below this number to the chosen minimum before display (default `0`). Leave it blank to allow negative values without a lower limit. Useful when the simulator endpoint can return negative values — for example, a reverser reads -1.0 to 1.0, so setting minimum value to `0` prevents negative numbers appearing on the display
   - **Right-align** — align text to the right of the display (useful for numbers; enabled by default)
   - **Decimal point** — enable if your display has a dot segment between digits
4. Click **Add display** (or **Save** when editing)

Each device can have multiple I2C modules as long as each uses a distinct address.
A configuration can contain only displays; adding a dummy input is unnecessary.

### Testing a Display

After saving, click **Test** next to the module in the I2C Modules table. This runs a brief display test sequence to confirm the wiring is correct.

### Binding Simulator Data to a Display

Once a module is configured, set up a **display binding** in your train configuration to show live values. See [Train Configuration — Display Bindings](train-configuration.md#display-bindings) for details.

## I2C Input Chips

Two I2C chips add inputs to a device, for when the board runs out of pins. They need firmware **3.2.0** or later. Trenino refuses to apply a configuration with an input chip to older firmware.

| Chip | Provides | Addresses |
|------|----------|-----------|
| **MCP23017** | Up to 14 digital inputs, or a switch matrix of up to 8x8, or a mix | `0x20`-`0x27` |
| **ADS1115** | Up to 4 analog inputs (3 if you use a supply reference) | `0x48`-`0x4B` |

Chip inputs behave like board-pin inputs: you can name, calibrate and bind them, and use them with detection and the virtual joystick. Each chip gets a block of virtual pins, handled by Trenino. They appear in the input lists as, for example, `MCP 0x20 GPA3`, `MCP 0x20 R0C1` or `ADS 0x48 AIN2`. A device has 128 virtual pins in total.

### Wiring

Wire SDA, SCL, VCC and GND as for a display (see above), and set the address with the chip's address pins (A0-A2 on the MCP23017; ADDR on the ADS1115). Every module on a device needs its own address. The I2C bus runs at 100 kHz, so a device with many chips, a large matrix, steppers and displays on one bus can get slow. If inputs feel sluggish, reduce the load on the bus.

On an Arduino Uno or Nano there is room for one chip with a matrix.

### MCP23017

- Choose which pins are **direct inputs** (buttons wired between the pin and GND, using the chip's pull-ups) and, optionally, which pins are matrix **rows** and **columns**.
- **GPA7 and GPB7 are output-only.** They cannot be direct inputs or matrix columns, because using them as inputs can corrupt SDA. A chip therefore has at most 14 direct inputs. They can be matrix rows. An 8x8 matrix needs GPA7 and GPB7 as rows.
- **Every matrix switch needs a diode.** There is no ghost key detection.
- Default debounce is 3 samples with no matrix and 2 with one; you can change it.

### ADS1115

- Choose which channels (AIN0-AIN3) are inputs, and the gain: `+-6.144 V` (default) or `+-4.096 V`. A 5 V supply needs gain 0, because inputs reach the rail.
- Inputs must stay within the chip's supply rails.
- **Without a supply reference**, readings depend on the supply voltage. On 5 V a lever at full travel reads about 80% of the range. Power potentiometers from a clean rail, away from stepper and LED current paths.
- **With a supply reference**, wire one channel to the same supply as the sensors and select it as the reference channel. Readings become a ratio of it and are 0-100% on any supply. **All sensors on that chip must be powered from that same supply.** If the reference reads too low, the chip reports an error and sends no values until it recovers.
- **Rollover (wrapping) sensors** only work on a chip with a supply reference, and only if the sensor spans the full supply voltage. Sensors with outputs of, for example, 10-90% of supply cannot wrap.
- ADS1115 inputs used as levers need calibrating, as with board pins (see [Calibrating Inputs](#calibrating-inputs)). Calibration will tell you if a sweep looks like rollover but the chip has no reference.

### Adding a Chip

Open your device configuration and add the chip from the I2C modules section. Choose the chip, address and pins or channels, and optionally name each input. When you edit a chip, only the channels you add or remove change: kept inputs keep their calibration and bindings. Removing a channel, or deleting the chip, deletes the affected inputs and their bindings; Trenino shows what will be lost first.

### Chip Failures

If a chip does not answer when the configuration is applied, loses power, or resets, Trenino marks its inputs as failed and shows a notice. The chip recovers by itself once it responds again. Check wiring, address and power first.

## Calibrating Inputs

Calibration maps raw ADC values to normalized 0.0-1.0 range.

### Starting Calibration

1. Find the input in your configuration
2. Click **Calibrate**
3. The calibration wizard opens

### Calibration Steps

**Step 1: Minimum Position**
- Move your input to its minimum position (e.g., throttle fully closed)
- Hold steady while samples are collected
- Click **Next** when complete

**Step 2: Full Sweep**
- Slowly move input through its entire range
- Move from minimum to maximum and back
- The system detects the full travel range
- Click **Next** when complete

**Step 3: Maximum Position**
- Move your input to its maximum position (e.g., throttle fully open)
- Hold steady while samples are collected
- Click **Finish** to save calibration

### Calibration Results

After calibration, you'll see:
- **Min Value** - Lowest detected ADC reading
- **Max Value** - Highest detected ADC reading
- **Detected Notches** - If your input has detents, they're automatically found

## Mapping Inputs to the Windows Virtual Joystick

On Windows 10/11, a calibrated analog input can drive one of eight conventional
axes: X, Y, Z, Rx, Ry, Rz, Slider 1, or Slider 2. A digital input can drive one
of 32 buttons. Analog values reuse the saved calibration and may be inverted;
buttons mirror their physical pressed/released state, including maintained
switches.

Open **Virtual joystick**, add a mapping, select the source input, and select an
unused target. A source and a target can each appear only once. An input cannot
simultaneously drive a simulator/API or keystroke binding and the virtual
joystick. If it already has a destination, Trenino shows the conflict and
requires explicit replacement confirmation.

Mappings can be prepared offline, including on other operating systems. Joystick
activation requires Windows 10 or 11. The page shows assigned mappings and capacity;
expand the available targets to inspect unused axes and buttons. Connect the source
hardware before using live preview.

Mappings can be prepared while the mode is off. Enabling or disabling the
device itself requires a Windows UAC prompt. If hardware disconnects while the
mode is active, Trenino releases mapped buttons and centers axes from that
hardware without disturbing controls sourced from other connected hardware.

For Windows verification and recovery steps, see
[Windows Virtual Joystick Mode](getting-started.md#windows-virtual-joystick-mode).

## Troubleshooting

### Device Not Appearing

1. Check USB cable connection
2. Verify device has correct firmware
3. Check device is not claimed by another application
4. Try a different USB port

### Erratic Input Values

1. Increase sensitivity setting to filter noise
2. Check for loose connections
3. Add hardware filtering (capacitor) if needed
4. Re-run calibration

### Configuration Won't Apply

1. Ensure device is connected
2. Check device isn't locked by another configuration
3. Verify firmware supports the protocol version

## Hardware Protocol Reference

For firmware developers implementing the trenino protocol:

### Message Format

Messages are framed using COBS encoding over UART.

### Message Types

| Type | Name | Direction | Description |
|------|------|-----------|-------------|
| 0x00 | IdentityRequest | App → Device | Request device identity |
| 0x01 | IdentityResponse | Device → App | Device signature (config_id) |
| 0x02 | Configure | App → Device | Send input config and I2C module definitions |
| 0x03 | ConfigurationStored | Device → App | Configuration acknowledged |
| 0x04 | ConfigurationError | Device → App | Configuration rejected |
| 0x05 | InputValue | Device → App | Real-time input reading |
| 0x06 | Heartbeat | Both | Keep-alive ping/pong |
| 0x07 | SetOutput | App → Device | Set a digital output pin on/off |
| 0x0D | WriteSegments | App → Device | Write segment bytes to an I2C display |
| 0x0E | SetModuleBrightness | App → Device | Set I2C display brightness (0–15) |
| 0x0F | ModuleError | Device → App | I2C module error report |

### Input Value Message (0x05)

```
Byte 0: Message type (0x05)
Bytes 1-4: config_id (int32, little-endian)
Byte 5: Pin number
Bytes 6-7: Value (int16, little-endian, 0-1023 for analog)
```
