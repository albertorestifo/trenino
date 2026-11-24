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
| Analog, MT6701 sensor | 14-bit magnetic angle over I2C (0-16383 per turn), firmware 3.4.0 | Levers with a magnet on the shaft |
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
   - **Sensitivity** - Value change threshold (1-10, default 5)
4. Save the input

### Sensitivity Setting

The sensitivity value determines how much the input must change before sending an update. Lower values = more responsive but more network traffic.

| Value | Use Case |
|-------|----------|
| 1-2 | Train levers, especially notches that cover a short part of the travel |
| 5 | Default, good balance |
| 8-10 | Noisy inputs, reduce chatter |

## Connecting Your Device

### Automatic Discovery

trenino checks for new devices every 2 seconds, so a board connects a few seconds after it is plugged in. Connected devices appear in the sidebar navigation.

If a port fails to connect, trenino tries it again after 5 seconds, then waits longer after each further failure, up to once a minute. This keeps it from repeatedly resetting a board that does not run Trenino firmware.

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

## Magnetic Angle Sensors (MT6701)

An analog input can be read by an MT6701 magnetic angle sensor over I2C instead of an
analog pin. It reports the magnet's angle at 14 bits (about 0.02° per count), and needs
controller firmware **3.4.0** or newer. The SimRail gate-lever sensor board in the
`train-lever` repository is built around it.

### Wiring and addresses

- Connect the sensor board's I2C connector to the controller's 5V, GND, SDA and SCL.
- Every MT6701 answers at **0x06** from the factory.
- Two sensors can share one cable. Before plugging the second board into the chain,
  set it to **0x46** with the MT6701 setup sketch (`addr46`, then `burn`). The chip has
  no address pin, so this is the only way to tell two of them apart.
- I2C displays (HT16K33, 0x70-0x77) can share the same bus.

### Adding the input

1. Click **Add input** and keep **Analog** as the type.
2. Pick **MT6701 magnetic sensor (I2C)** as the sensor.
3. Pick the address. The form picks the first one this configuration doesn't use yet.
   If the connected controller's firmware is too old, the form says so.
4. Apply the configuration.

The inputs list shows the sensor as `I2C 0x06` and its live angle. With two sensors,
move one lever and watch which angle changes.

If a sensor doesn't answer, its row shows **Not responding**: right after Apply when the
controller reports it missing, or when no reading has arrived for 5 seconds. The
controller keeps retrying, so the badge clears by itself once the cable or address is
fixed.

### Calibrating

Calibration works as for other levers, with two differences:

- The first step shows the live angle. Move the lever end to end before pressing Start:
  the angle should change smoothly. If it stays still or jumps, check the magnet and the
  gap.
- Holding a position needs one fresh reading, not a run of samples: a magnetic sensor
  at rest only sends every 2 seconds.

The sensor's 0°/360° point can be anywhere in the lever's travel: Trenino follows the
lever round the circle, so there is no need to align the magnet. A calibration fails if
the lever turned the magnet less than 5° (the magnet slips on the shaft) or more than
330° (the two ends can't be told apart). Changing an input's sensor or address clears
its calibration.

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

## Calibrating Inputs

Calibration maps raw values to the normalized 0.0-1.0 range. For magnetic angle sensors,
see [Calibrating](#calibrating) under Magnetic Angle Sensors.

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
3. Verify firmware supports the protocol version (3.3.0 for gauges, 3.4.0 for magnetic
   sensors)

### Magnetic Sensor Not Responding

1. Check the 4-wire cable (5V, GND, SDA, SCL) and that SDA and SCL aren't swapped
2. With two sensors, check that the second board was set to 0x46 with the setup sketch,
   and that the input uses that address
3. Run the setup sketch's live readout to check the sensor on its own

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
