# Physical stepper gauges

Trenino stores generic electrical axes separately from train units and calibration.
Use firmware **3.1.0 or newer**, extension revision 1. Capability checks precede
configuration. Two logical axes (0/1) share one Adafruit Motor Shield V2/V3
compatible shield at 0x60–0x77, on separate motor ports 1/2.

## Wiring and registration

For the white X27.168 LHY1109, select X27 six-state mode. Coordinates and speeds
are **commutation transitions in that mode**, not degrees or generic full steps.
Verify the actual winding pairs and their polarity against the motor datasheet
before connecting each winding to a shield bridge. Check actual motor/shield
electrical ratings, power and wiring.

An unregistered PCA9685 responds to ALLCALL 0x70. When the panel has a stepper axis
and a configured module at 0x70, Trenino shows a non-blocking warning (Stepper axes
and the Apply dialog); Apply is never blocked and needs no confirmation. **To be
safe, unplug the 0x70 display, apply with the shield alone, reconnect the display and
apply again.**
Repeat after EEPROM erase, address change or shield replacement. Software cannot
safely discover an unknown responder by probing writes. Ordinary resource
conflicts never automatically ForgetDriver.

## Guided gauge setup

The quickest route to a working speedometer is **Guided gauge setup** on the axis card
(**Stepper axes** on the configuration page). It chains the manual steps below into one
flow and needs no knowledge of the parameters. It uses the same operations as the manual
controls (`StepperManager` claim/command/release, `Hardware.save_dial_calibration`,
`complete_commissioning`) and adds no protocol or firmware changes. Every safety rule
still holds: nothing moves on open or save, motion only follows a button that says it will
move, and commissioning is recorded only through `complete_commissioning`.

1. **Check.** Device connected, firmware supported, saved settings applied (a **Send
   settings** button applies them), idle hold on, and a wiring confirmation. The 0x70
   display warning is repeated. Continue takes manual control behind the scenes; the
   wizard never uses the word lease. A UI hold has no timer (it is tied to the open page),
   so there is nothing to renew; if the manager revokes it (for example after Apply) the
   wizard takes it again by itself.
2. **Direction.** Align the needle on 0 by hand, **The needle is on 0** (assigns the
   reference), jog +20, and ask whether it moved up the dial. If not, `reverse` is
   flipped, the settings are applied and the user realigns (Apply drops the reference),
   then the check repeats.
3. **Dial.** Lowest/highest value, unit and mark count (default 5). The first mark is
   estimated from the axis travel spread over the dial, later marks from the slope of the
   last two points (estimates land within about 2 percent). Each mark is a move to the
   estimate, optional nudges (kept inside the soft limits) and a capture of the reading
   against a fresh stationary position. The marks stay in memory; nothing is saved until the
   verification passes, so an earlier reviewed dial and its gauges are untouched if the
   wizard is closed first. If a mark cannot be reached, `max_position` is extended (with
   Apply and realignment).
4. **Verify.** The needle returns to 0 and the user confirms it is exactly on the mark
   (a lost-step check; a miss offers realigning or measuring again), then a mark between
   two measured points is checked and only then the dial is saved reviewed.
5. **Automatic zeroing (optional).** Switches to internal stop, keeps home speed 50, and
   sets the sweep to cover the top of the dial (or the soft limit) plus the backoff and a
   margin, and a timeout above `ceil(1000 * (steps + backoff) / speed) + 500`. A sweep that
   was too short is called out and lengthened. After Apply and Home the user nudges the
   needle up onto 0; the first sweep always uses `home_backoff` 0, so the needle can only
   land at or below 0, and the new `home_backoff` is the nudge distance (for example 253).
   After a second Apply and Home the user confirms it lands on 0 (otherwise the tuning
   starts over from backoff 0). The tuning can be cancelled, which restores the previous
   homing settings. The startup-homing checkbox is always written, ticked or not.
6. **Finish.** `complete_commissioning`, optional `home_on_connect`, a name field, the
   trains with a gauge binding on the axis (with a link to add one), then closing the
   wizard releases manual control and resumes train control for a commissioned axis.

Waits follow real status, never sleeps: a move finishes when the device reports the
axis stationary at the target, a Home when it was seen homing and is stationary and
referenced again. A **Stop** button shows during any motion. A fault, or a device that
disconnects, pauses the wizard with a plain next action (Recover, or plug it back in);
after recovery the user realigns the needle and the wizard resumes at the same step
with measured marks kept. Closing midway stops the axis, hands control back and keeps
only clearly saved steps (axis settings, the dial). The state machine lives in
`Trenino.Hardware.GaugeWizard` (pure, tested without hardware); effects are run by
`Trenino.Hardware.GaugeWizard.Runner` and the page is `TreninoWeb.GaugeWizardComponent`.
Closing the browser tab or navigating away drops manual control: the manager stops the
axis and, when it is still commissioned, returns it to train control, exactly as Close
does. A move in progress when that happens can lose the reference. An uncommissioned
axis stays paused.

## Configure and commission

1. In Hardware configurations, select a panel and open **Stepper axes**. Click
   **Quick setup: X27.168 motor** (six-state, shield port 1, address 0x60; the second
   axis gets port 2) and give it a name. The form shows only the common fields (axis,
   port, mode, direction, limits, speed, acceleration). Home sweep, backoff, timeouts,
   watchdog, idle/host-loss behavior, reference strategy and shield address are under
   **Advanced** and keep safe defaults. Both axes must share one shield address;
   display address collisions are rejected.
2. Save, then **Apply to Device**. Saving never Home/Move commands a motor and does
   not reach the device by itself: the form tells you to Apply, and an **Apply needed**
   banner stays on the page until the device confirms the saved configuration (Trenino
   records a fingerprint of what the device last confirmed and compares it with what is
   saved; names and calibration do not count). With no device connected the page says
   why Apply is unavailable instead of hiding the button. Apply is never blocked;
   with a display at 0x70 it only shows the warning described above. To reverse direction click
   **Flip direction** on the axis (or update `reverse` over MCP), Apply, then
   re-align the needle by hand and Assign reference again. An axis-only panel uses the canonical eight-byte empty legacy configuration
   `02 <configuration id, little endian> 00 00 ff`. ConfigurationStored must confirm
   its identity before axis setup. It removes old modules and resets/releases
   axes; independent SetOutput pins and removed display contents are not cleared.
   Each axis shows a **Next step** line (Apply needed, set reference, take manual
   control, recover, Resume train control) plus a one-line glossary for reference,
   manual control and commissioning. A fault is shown only while the session is
   faulted; it clears once the session reconfigures or an acknowledgement succeeds.
3. Take manual control. Automatic targets pause. For **host reference**, physically
   align the pointer and explicitly Assign reference to the entered coordinate.
   Enable energizes a phase; it does not create a reference.
4. Use small jog increments and conservative speed/acceleration to verify direction
   and travel. Jog requires a fresh stationary known estimate. Stop cancels command
   generation immediately; a moving Stop may lose reference. Release disables
   bridges and always loses reference.
5. For deliberately selected **internal stop**, physically verify direction, sweep,
   backoff, speed and timeout before Home. Home runs a bounded sweep/backoff without
   a sensor. Acceptance is separate from completion. Completion means **Assumed
   internal-stop reference**, never detection of a stop or proof of shaft movement.
6. Record physical commissioning only after checking the real dial. Continuous
   gauges require **idle hold**; idle release loses reference after every completion.
7. Release manual control and explicitly Resume train control. Outside the guided
   wizard, browser/process loss stops manual motion and leaves automatic output paused
   until Resume.

Manual startup is default. Commissioned internal-stop axes with idle hold can
explicitly opt into Home on connect, causing one bounded movement on each genuine
new UART connection after acknowledged setup. Restarting the Trenino server counts
as a new connection: the device is rediscovered afterwards, so the needle re-homes. Train
activation, form save, legacy Apply, recovery, a session crash and duplicate device
events for an already-connected device do not authorize a fresh automatic Home. An uncertain Home outcome remains blocked for recovery.
The Home is a one-shot latch: starting an Apply (deployment) or any session fault
consumes it, and paused or leased axes are never homed automatically.

Request IDs are 16-bit and shared by a session. The firmware sources available to
this project (v3.0.0) contain no stepper protocol, so nothing guarantees that an ID can
be reused without an intervening Reset. Before the counter would wrap, the session
therefore performs an acknowledged Reset and reconfigure, which discards every
reference (a gauge needs a reference again after roughly 65,000 requests, typically
hours of driving). Once setup completes the manager re-homes the axes that qualify for
Home on connect, so those gauges recover on their own; others stay awaiting reference.
Wrapping without a Reset is only acceptable once firmware is shown to allow it.

## Dial calibration (per axis)

The dial belongs to the hardware, not the train. Calibrate it once per axis under
**Stepper axes** on the configuration page (**Calibrate dial** on the axis card, below the
commissioning controls); every train gauge on that axis shares it. A refit of the needle
is measured once, not per train.

The editor holds the dial unit ("Dial shows": raw, m/s, km/h or mph), the measured points
and the review checkbox. Measuring needs no saved gauge. Preview shows the target for a
dial value without moving anything. **Take manual control**, **Move to test value** and
**Capture stationary estimated position** are enabled only when possible and each states
what is missing. Saving never moves the motor.

Record 2-32 strictly increasing dial values with strictly monotonic positions (increasing
or decreasing), inside axis soft limits. Add/edit/remove/reorder rows. Capture records the
entered dial reading with a fresh stationary known position **estimate**, not a sensor
measurement. Editing the points or unit withdraws the review; a dial saved unreviewed
disables every gauge on the axis. Changing the axis mode or soft limits marks the dial
invalid and unreviewed and disables all its gauges; re-measure and review it again.
Saving candidate points does not certify physical calibration.

## Train binding

In the train editor choose **Gauges -> Add gauge**. The form has three numbered steps:
(1) axis (shows whether its dial is calibrated, with a link to calibrate it), (2) endpoint
and "Simulator reports in" unit, (3) save/enable. Multiplier, offset, stale time,
out-of-range and inactive behavior are under **Advanced**. Every disabled control states
what is missing. Save never moves the motor; you can save disabled, finish commissioning and
the dial, then enable from the saved gauge. Enabling needs a commissioned hold axis with a
valid, reviewed dial. A raw simulator unit only fits a raw dial. An enabled gauge that
cannot move shows a reason (simulator not connected, not commissioned, device
disconnected, fault, needs reference, manual pause), and a hint names the detected train
identifier when none of the profile's identifiers match it (detection stays read-only).
Select an axis and a verified endpoint through the API explorer or enter it offline. Verify
the reported units. A selected value key chooses that numeric field. Without a key only one
unambiguous numeric value in a valid node is accepted. Invalid/missing data never becomes
zero.

Units are raw, m/s, km/h and mph; raw converts only to raw. The gauge sets the unit the
simulator reports, the axis dial sets the unit the dial shows. Mapping order is unit
conversion, optional absolute value, multiplier, offset, piecewise linear
interpolation and integer-target rounding. Intermediate calculations retain their
precision; display formatting does not change the target. Negative input remains
negative unless absolute input is explicitly selected. Choose clamp or reject
outside the calibration domain.

## Editable Class 323 starter

Two optional starters exist. The dial starter (**Fill with Class 323 speedometer
starter** in the axis dial editor) suggests 0–100 mph, approximately 240° / 720
six-state transitions, points 0 mph → 0 and 100 mph → 720. The gauge starter in the train
wizard only suggests m/s input. These are **unverified estimates**, saved disabled/unreviewed
and awaiting calibration review. The endpoint is blank; m/s input and mph dial must be
verified. With these candidate points, 44.704 m/s converts to 100 mph and targets 720.

Hardware candidates: port 1/address 0x60, min 0/max 720, maximum speed 100
transitions/s, acceleration 200 transitions/s², watchdog 1000 ms, idle hold,
host-loss release. Direction is unverified. Host reference/manual startup stay
default. Independently commissioned internal-stop candidates: sweep 1080,
backoff 10, speed 100, timeout 15000 ms, assigned position 0. The Home sweep must
cover **whole motor travel**, not merely the 720-transition dial arc. No candidate
is assumed safe for an untested motor. Replace all values with measured ones.

## Failure and recovery

KeepAlive runs independently of simulator HTTP, including during Home. Status
polling is faster while moving/homing. Acceptance does not imply completion.
Retries use identical bytes/IDs at most twice; superseded Home/Move commands are
never replayed. Uncertainty, serial loss, reboot, Release, moving Stop and shared
I2C faults invalidate trustworthy reference and buffered targets. Host-loss hold
retains a phase, not trustworthy position; a shared I2C fault affects both axes.

The gauge controller never stalls on a stuck simulator subscription cleanup: a failed
cleanup is retried three times, then those subscription IDs are abandoned (never reused,
because the old subscription may still exist) and polling resumes on a fresh ID range.
Reloading bindings keeps healthy subscriptions when the endpoints are unchanged.
Subscribe, poll and set_target failures are kept per gauge, together with controller
state (train, simulator connected, cleaning, retries, last error), and the MCP tool
`get_gauge_runtime` returns the latest sample, converted value, target, stale flag and
failure for each gauge, so a gauge that is not moving can be diagnosed.

Invalid/stale simulator data retains the last target only until stale timeout.
Inactive clears queued targets and lets any move in progress finish (the needle holds where it lands). The former inactive `release` option
can no longer be chosen; stored values behave as hold, because Release discards the
reference and would strand the gauge. Train changes and
simulator loss apply the outgoing policy and discard previous samples. Recovery
requires acknowledged reset/configure and fresh reference; only fresh simulator
data may drive again.

## MCP

Axis tools provide list/create/update/delete/status, `apply_stepper_configuration`
(never moves, never blocked; the result carries a `warning` when a 0x70 display is configured) and explicit control; gauge
tools provide list/create/update/delete and pure preview (no points: a binding only
chooses its speed source), and `get_dial_calibration` / `update_dial_calibration` read and
write the per-axis dial. Shared contexts enforce
the same validation as UI. Runtime control claims a 60-second opaque lease,
renewed only explicitly. Every `control_stepper_axis` motion or recovery operation (everything except `claim`,
`renew`, `release_lease` and `resume`) supplies an operation token. Identical
token/arguments reuse admission instead of restarting motion; changed content
rejects. Up to 100 records are retained for the lease lifetime, then new operations
reject until a new lease (Stop and Release are always accepted; refusals are not recorded,
so a retry with the same token runs again). Expiry Stops and leaves automatic control paused, except that an accepted
move or home always finishes: if the lease expires while the axis is moving or homing,
the Stop and cleanup are deferred until it is stationary (bounded at five minutes), and
in the meantime the holder can still renew, stop or release the lease while other
commands are refused. Explicit Stop, fault and host loss still stop motion immediately. Losing the MCP
process or connection does **not** stop motion by itself: the lease has no monitor,
so the axis keeps its state until the lease expires (at most 60 seconds, plus any
deferral while an accepted move or home finishes), and then Stop runs. Status reports each axis's `lease`
(`owner`, `expires_in_ms`, `finishing_motion`) or null. A refused claim or resume names
the holder (MCP session with time left, or the Trenino UI) and what to do about it.
Status distinguishes pending acceptance from completion.

Deleting an axis stays possible while its session is faulted, unsupported, still
starting or the axis was never applied: the Release is skipped, and dropping the
session stops KeepAlive so the firmware's host-loss behaviour takes over.

## Physical acceptance

Automated UART/simulator tests do **not** validate actual winding order, electrical
ratings, polarity, acceleration, travel, stop contact, lost steps, endpoint units,
pointer load or needle fit. Verify these conservatively on the actual hardware.
Measure intermediate marks and both end limits. Test power-cycle/reconnect and the
chosen startup policy deliberately, with Stop/Release accessible. Needle fit
remains separate mechanical work; no real motor validation is claimed.
