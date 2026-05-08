# Train Configuration Guide

This guide covers setting up train configurations and binding hardware inputs to simulator controls.

## Understanding Train Configurations

Each train in Train Sim World has unique cab elements (throttle, reverser, brakes). Trenino stores configurations that map your hardware to these elements.

### Train Identifier

Trains are identified by a prefix derived from the simulator's formation data. For example:

```
Formation: ["Class_BR_DR4_08_A", "Class_BR_DR4_08_B", ...]
Identifier: "Class_BR_DR4"
```

When you drive this train in the simulator, Trenino automatically activates the matching configuration.

The identifier acts as a prefix — a single configuration for `RVM_LIRREX_M9` will match `RVM_LIRREX_M9-A`, `RVM_LIRREX_M9-B`, and other variants. This is useful for trains where different car variants form the same consist.

## Creating a Train Configuration

### From Auto-Detection

1. Start Train Sim World with your desired train loaded
2. Navigate to **Trains** in Trenino
3. The detected train appears with a **Create Configuration** option
4. Click to create a configuration pre-filled with the train identifier

### Manual Creation

1. Navigate to **Trains**
2. Click **New Train**
3. Enter:
   - **Name** - Friendly name (e.g., "BR Class 66")
   - **Identifier** - Must match simulator's ObjectClass prefix
4. Save the train

## Adding Cab Elements

### Element Types

| Type | Description | Examples |
|------|-------------|----------|
| Lever | Analog control with notches | Throttle, Reverser, Dynamic Brake |
| Button | Momentary or latching input | Horn, Bell, Headlights, Wipers, Sander |

### Creating a Lever Element

1. Open your train configuration
2. Click **Add Element**
3. Enter element name (e.g., "Throttle", "Reverser")
4. Select type: **Lever**
5. Save the element

## Configuring Lever Endpoints

Each lever needs API endpoints to communicate with the simulator.

### Auto-Detection

1. With the train loaded in simulator, click **Auto-Detect** on the lever
2. Trenino queries the simulator for available controls
3. Endpoints are automatically configured:
   - Value endpoint (read/write current position)
   - Notch count and index endpoints
   - Min/max value endpoints

### Manual Configuration

Click the **Settings** icon on the lever to manually configure:

| Field | Description | Example |
|-------|-------------|---------|
| Value Endpoint | Read/write lever position | `/CurrentDrivableActor/Throttle(Lever).InputValue` |
| Min Endpoint | Minimum value | `/CurrentDrivableActor/Throttle(Lever).Min` |
| Max Endpoint | Maximum value | `/CurrentDrivableActor/Throttle(Lever).Max` |
| Notch Count | Number of notches | `/CurrentDrivableActor/Throttle(Lever).Notches` |
| Notch Index | Current notch | `/CurrentDrivableActor/Throttle(Lever).NotchesIndex` |

## Notch Configuration

Many train controls have discrete positions (notches). Trenino supports both continuous and notched controls.

### Notch Types

| Type | Behavior | Use Case |
|------|----------|----------|
| Gate | Fixed value, snaps to position | Reverser (Forward/Neutral/Reverse) |
| Linear | Interpolates between boundaries | Throttle notches, dynamic brake |

### Auto-Detecting Notches

1. Click **Auto-Detect** on a configured lever
2. Trenino reads notch data from the simulator
3. Notch positions and types are automatically set

### Notch Mapping Wizard

Maps hardware input ranges to lever notches:

1. Click **Map Notches** on a lever with bound input
2. The wizard guides you through each notch boundary:
   - Move your physical input to the notch boundary position
   - Click **Record** to save the input value
   - Repeat for all notch boundaries
3. Save when complete

The wizard validates:
- No gaps between notches
- Full input range covered (0.0 to 1.0)
- Boundaries don't overlap

## Binding Hardware Inputs

Connect calibrated hardware inputs to lever elements.

### Prerequisites

Before binding:
1. Hardware device configured and connected
2. Input calibrated (has min/max values)
3. Lever element created with endpoints

### Binding Process

1. Find the lever element in your train configuration
2. Click **Bind Input**
3. Select from available calibrated inputs
4. The binding is created and enabled

### Binding Status

| Status | Meaning |
|--------|---------|
| Bound | Input connected to lever |
| Unbound | No input assigned |
| Disabled | Binding exists but inactive |

## Real-Time Operation

### Automatic Train Detection

When you load a train in the simulator:

1. Trenino polls the simulator every 15 seconds
2. Detects the current formation's identifier
3. Matches against stored train configurations
4. Activates bindings for the matched train

Detection uses a two-layer strategy: it first checks `ObjectClass` from `CurrentDrivableActor`, then falls back to `ProviderName`. This makes detection reliable even for freight trains where the locomotive and wagons have different class prefixes.

### Manual Train Activation

Click **Set Active** on any train to manually activate its bindings.

### Value Flow

When operating:

```
Hardware Input → Calibration → Notch Mapping → Simulator API
     ↓               ↓              ↓              ↓
  0-1023         0.0-1.0       Notch Value    Lever Moves
```

## Lua Scripts

Each train configuration can have Lua scripts that react to simulator events — speed changes, control movements, or timers — and control hardware outputs or write simulator values in response.

Common uses:
- Turn on a warning LED when speed exceeds a threshold
- Blink an LED at a configurable rate
- Synchronize output LEDs with simulator state (e.g., pantograph up indicator)
- Automate startup sequences

Scripts are managed in the **Scripts** section of the train configuration page. Each script has:
- A name
- Lua code with an `on_change(event)` function
- One or more triggers (simulator endpoint paths whose value changes will fire the script)

See the [Lua Scripting Guide](lua-scripting.md) for the full API reference and examples.

## Display Bindings

Display bindings connect simulator endpoint values to I2C display modules on your hardware — for example, showing current speed on a 7-segment LED display attached to your Arduino.

### Prerequisites

Before creating display bindings:
1. At least one I2C display module must be configured on your device — see [I2C Display Modules](hardware-setup.md#i2c-display-modules)
2. Your train configuration must exist and be open in the train edit page

### Adding a Display Binding

1. Open your train configuration
2. Scroll to the **Display Bindings** section and click **Add Binding**
3. Configure:
   - **Name** — optional label (e.g., "Speed", "Brake Pressure")
   - **I2C Module** — select the display to write to
   - **Endpoint** — the simulator API path whose value you want to show (use the API Explorer to find paths)
   - **Format** — how to render the value (see below)
4. Save the binding

### Format Strings

The format string controls how the numeric value is rendered before being sent to the display.

| Token | Output | Example value | Result |
|-------|--------|---------------|--------|
| `{value}` | Raw value as string | `42.5` | `42.5` |
| `{value:.0f}` | Float with 0 decimal places | `42.5` | `43` |
| `{value:.1f}` | Float with 1 decimal place | `42.5` | `42.5` |
| `{value:.2f}` | Float with 2 decimal places | `42.5` | `42.50` |

For speed in km/h, `{value:.0f}` is usually the most readable choice.

You can mix static text with the token: for example, `{value:.0f}` shows just the number, while a format like `{value}` shows whatever the simulator returns as-is.

### How Bindings Work

- Bindings activate automatically when their train's configuration becomes active
- The display is polled every 200 ms and updated only when the value changes
- When the train is deactivated, all bound displays are blanked
- A train can have one binding per I2C module

### Example: Speed Display

**Endpoint:** `CurrentDrivableActor.Function.HUD_GetSpeed`

The speed endpoint returns meters per second. To convert to km/h, you would need a Lua script (see [display.set()](lua-scripting.md#displayset)). If you just want raw m/s, `{value:.1f}` gives one decimal place.

## Configuring Buttons

Each button element needs a hardware input binding and a behavior mode.

### Button Hardware Types

Before configuring the binding, tell Trenino what kind of switch you're using:

| Type | Description | Examples |
|------|-------------|---------|
| **Momentary** | Spring-loaded, returns when released | Horn buttons, push buttons |
| **Latching** | Stays in position when toggled | Toggle switches, key switches |

### Binding a Hardware Input to a Button

1. Open your train configuration and find the button element
2. Click **Configure** on the button
3. Select your hardware input from the list
4. Choose the **hardware type** (Momentary or Latching)
5. Choose a **binding mode** (see below)

### Button Binding Modes

#### Simple Mode (default)

Sends a value to a simulator endpoint when pressed, and another value when released. Best for lights, sanding, and most switches.

- **Endpoint** — the simulator API path to write to
- **ON Value** — sent when the button is pressed (default: `1.0`)
- **OFF Value** — sent when the button is released (default: `0.0`)

**Auto-detecting ON/OFF values**: Instead of entering values manually, click **Auto-Detect** on the button configuration. Trenino will watch for changes when you interact with the matching control in the simulator and suggest the correct values.

#### Momentary Mode

Continuously repeats the ON value at a fixed interval while the button is held down. Use this for controls like the horn that need a stream of "pressed" signals, not a single toggle.

- **Endpoint** — the simulator API path
- **ON Value** — sent repeatedly while held
- **Repeat Interval** — how often to repeat (milliseconds, default: 100ms)

#### Keystroke Mode

Simulates a keyboard key while the button is held. The key is pressed when the button is pressed and released when the button is released. Useful for games that respond to keyboard input.

- **Key** — captured interactively; click **Capture Key** and press the key on your keyboard
- **Modifiers** — optionally combine with Ctrl, Shift, or Alt

> Note: Keystroke simulation requires the keystroke utility to be present. In the desktop app it's bundled automatically. See the [Development Guide](development.md#optional-keystroke-simulation-support) for setup in development.

#### Sequence Mode

Executes a pre-configured command sequence when the button is pressed (and optionally a different sequence when released). Use this for multi-step operations like startup procedures.

- **On Press Sequence** — sequence to run when button is pressed
- **On Release Sequence** — (latching hardware only) sequence to run when button is released/toggled off

At least one sequence must be assigned. See [Command Sequences](#command-sequences) below to create sequences first.

### Command Sequences

Sequences are reusable lists of simulator commands with configurable delays between steps. They're available to all buttons on a train and can also be triggered manually from the Sequences section.

**Creating a sequence:**

1. Open your train configuration
2. Scroll to the **Sequences** section and click **New Sequence**
3. Name the sequence (e.g., "Cold Start")
4. Add commands:
   - **Endpoint** — the simulator API path to write to
   - **Value** — the value to send
   - **Delay** — milliseconds to wait before the next command
5. Save the sequence
6. Click **Test** to execute it immediately from the Sequences table

**Example — Cold Start sequence:**

| Step | Endpoint | Value | Delay |
|------|----------|-------|-------|
| 1 | `CurrentDrivableActor/BatteryIsolator.InputValue` | `1.0` | `500` |
| 2 | `CurrentDrivableActor/Pantograph.InputValue` | `1.0` | `1000` |
| 3 | `CurrentDrivableActor/MainBreaker.InputValue` | `1.0` | `0` |

Assign this sequence to a button in Sequence mode to trigger the full startup with one button press.

## API Explorer

For debugging, use the built-in API Explorer:

1. Click the **API Explorer** icon on a lever
2. Enter an API path to query
3. View live values from the simulator

Common paths to explore:
- `/CurrentDrivableActor.Info` - List available controls
- `/CurrentDrivableActor/Throttle(Lever).InputValue` - Current throttle
- `/CurrentDrivableActor.Function.HUD_GetSpeed` - Current speed

## Troubleshooting

### Train Not Detected

1. Verify simulator is running with External Interface enabled
2. Check Trenino's simulator connection status
3. Ensure the train identifier matches the `ObjectClass` prefix for your locomotive

### Lever Not Responding

1. Confirm input is bound and enabled
2. Check calibration is complete
3. Verify endpoint paths are correct
4. Test with API Explorer

### Wrong Notch Selected

1. Re-run notch mapping wizard
2. Verify notch boundaries don't overlap
3. Check input calibration accuracy
