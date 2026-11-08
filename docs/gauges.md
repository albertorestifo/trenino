# Physical gauges (beta)

Trenino drives real needle gauges built on **X27.168** gauge steppers (and Switec X25/X27
clones) and moves them from live simulator data, such as speed. Gauges are a beta
feature: turn on **Enable beta features** in Settings.

The controller does the stepping itself. It needs **controller firmware 3.3.0 or newer**;
older firmware rejects a configuration that contains a gauge. Firmware 3.1.0 to 3.2.1 had a
different, now removed, motor-shield gauge system: gauges set up for it were deleted when
Trenino was updated, so set them up again as described here.

## Wiring

Each gauge is wired one of two ways. The firmware's
[gauge wiring guide](https://github.com/albertorestifo/trenino_firmware/blob/master/docs/GAUGE_WIRING.md)
has a diagram for every board.

| Wiring | Use it for | Pins | Steps for 315° |
|---|---|---|---|
| **VID6606 driver chip** | Anything you keep. One chip drives four gauges. | STEP, DIR, and the chip's RESET_N (optional, shared by its four gauges) | 3780 |
| **Direct to board pins** | Bench prototypes. No chip. | The four board pins wired to X27 contacts 1-4 | 945 |

- At most **four gauges** per controller, and at most eight inputs, button matrices,
  displays and gauges together (outputs don't count).
- Direct drive works only on AVR boards (Pro Micro, Leonardo, Micro, Uno, Nano, Mega).
  Due and ESP32 need a VID6606. Keep to two direct gauges per board: four would draw close
  to the chip's current limit.
- No pin may be shared between gauges, except the RESET_N of one VID6606 chip. Trenino also
  refuses a gauge pin that an input, button matrix or output on the same configuration uses.
- On a VID6606, configure all four channels of the chip, even unused ones, so every input
  sits at a defined level.

### train-lever gauge board

The class 323 gauge driver board (revision 3) is a Pro Micro over one VID6606. Pick its
channel from **Fill pins from a board** in the gauge form:

| Channel | Connector | STEP | DIR | RESET_N |
|---|---|---|---|---|
| A | J1 | 8 | 7 | 6 |
| B | J2 | 14 | 16 | 6 |
| C | J3 | 21 (A3) | 20 (A2) | 6 |
| D | J4 | 5 | 4 | 6 |

## Add a gauge

1. Open the hardware configuration and find **Gauges**. Click **Add gauge**.
2. Name it, choose the wiring and enter the pins (or pick a board channel).
3. **Motion settings** start from values that suit an X27: 3780 steps of travel, 5000
   steps/s and 50000 steps/s² for a VID6606; 945 steps, 1800 steps/s and 1500 steps/s² for
   direct drive. Lower the speed if the needle loses its place. Turn on
   **Reverse direction** if the needle turns the wrong way.
4. Click **Add gauge**, then **Apply** the configuration. When the controller stores it,
   every gauge sweeps into its end stop and calls that position zero. It does the same each
   time it starts up and after every Apply.

Changing the wiring, the pins or the direction deletes the gauge's dial, because a stored
position no longer means the same needle angle. So does shortening the travel below a dial
point.

## Calibrate the dial

The dial belongs to the hardware, so it is calibrated once per gauge and shared by every
train that uses it.

1. On the gauge card, click **Calibrate**. The controller must be connected, on firmware
   3.3.0 or newer, and running the saved configuration (Apply first). The needle moves to
   0, and moves there again if the gauge re-zeros while the panel is open (after an Apply,
   or when the controller reconnects).
2. Move the needle with the slider or the -10/-1/+1/+10 buttons onto a printed mark.
3. Type the value the mark shows under **The dial shows** and click **Add point**. Add at
   least two points (2 to 32), for example the lowest and the highest mark; add more where
   the scale is not even.
4. Pick the **Dial unit** (raw, m/s, km/h or mph).
5. Click **Save, dial checked** once the points match the real dial. **Save draft** keeps
   them without enabling any train binding.
6. Click **Done** to hand the gauge back to the train.

While the panel moves a gauge, the active train's data for that gauge is paused. The
firmware does not report the needle's position, so your eyes are the measurement. If a
needle was knocked or lost steps, click **Re-zero**: it sweeps to its stop and comes back.

## Bind a gauge to a train

In the train editor, open **Gauge bindings** and click **Add gauge binding**:

1. Choose the hardware gauge. It shows whether its dial is calibrated.
2. Choose the simulator endpoint (through the API explorer) and the unit the simulator
   reports. Raw only fits a raw dial.
3. Save, and enable it once the gauge's dial is calibrated and reviewed.

Multiplier, offset, absolute value, out-of-range handling and the stale time are under
**Advanced**. The mapping is: unit conversion, optional absolute value, multiplier,
offset, then piecewise-linear interpolation over the dial points.

When the simulator value stops arriving, the needle holds its last position. After the
controller restarts or a configuration is applied, it rests at zero until a fresh value
arrives. An enabled binding that cannot move says why: simulator not connected, dial not
calibrated, controller not connected, firmware too old, configuration not applied, or the
gauge being calibrated.

### Class 323 starter

**Fill with Class 323 speedometer starter** in the binding form fills the name and the m/s input
unit. Choose the endpoint yourself; it is never guessed.

## MCP

With beta features on, an AI assistant can set gauges up through these tools:

- `list_gauges`, `create_gauge`, `update_gauge`, `delete_gauge`: the gauge settings.
- `apply_device_configuration`: send the configuration to the controller.
- `move_gauge`: move a needle to a step position to measure dial points. It pauses the
  train's data for that gauge for 60 seconds (renewed by every move); `release: true` hands
  it back. `zero_gauge` re-zeros it.
- `get_dial_calibration`, `update_dial_calibration`: the dial points.
- `list_gauge_bindings`, `create_gauge_binding`, `update_gauge_binding`,
  `delete_gauge_binding`, `preview_gauge_binding`, `get_gauge_runtime`: train bindings.

## Not yet verified on hardware

Firmware 3.3.0's gauge support has not yet been run on real gauges. Safe speeds and
accelerations for a given needle and dial are found by testing: raise them until the needle
loses steps, then back off.
