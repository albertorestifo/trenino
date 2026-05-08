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
2. Scroll to the **I2C Modules** section and click **Add Module**
3. Configure:
   - **Name** — optional friendly label (e.g., "Speed Display")
   - **Chip** — `HT16K33` (currently the only supported chip)
   - **I2C Address** — enter as decimal (`112`) or hex (`0x70`)
   - **Brightness** — 0–100% slider (maps to hardware levels 0–15)
   - **Digits** — number of digits on the display: `4` or `8`
4. Click **Save**

Each device can have multiple I2C modules as long as each uses a distinct address.

### Testing a Display

After saving, click **Test** next to the module in the I2C Modules table. This runs a brief display test sequence to confirm the wiring is correct.

### Binding Simulator Data to a Display

Once a module is configured, set up a **display binding** in your train configuration to show live values. See [Train Configuration — Display Bindings](train-configuration.md#display-bindings) for details.

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

```
[START_BYTE] [TYPE] [PAYLOAD...] [END_BYTE]
```

### Message Types

| Type | Direction | Payload |
|------|-----------|---------|
| 0x01 | Request | None |
| 0x01 | Response | Signature bytes |
| 0x02 | To Device | config_id (4 bytes) + pin + type + sensitivity |
| 0x03 | From Device | None (acknowledgment) |
| 0x04 | Both | None (heartbeat) |
| 0x05 | From Device | config_id (4 bytes) + pin + value (2 bytes signed) |

### Input Value Message

```
Byte 0: Message type (0x05)
Bytes 1-4: config_id (int32, little-endian)
Byte 5: Pin number
Bytes 6-7: Value (int16, little-endian, 0-1023 for analog)
```
