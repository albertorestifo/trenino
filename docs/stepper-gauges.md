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

An unregistered PCA9685 responds to ALLCALL 0x70. **Disconnect any 0x70 display,
register the shield alone, then reconnect and Apply the display configuration.**
Repeat after EEPROM erase, address change or shield replacement. Software cannot
safely discover an unknown responder by probing writes. Ordinary resource
conflicts never automatically ForgetDriver.

## Configure and commission

1. In Hardware configurations, select a panel and open **Stepper axes → Add axis**.
   Every electrical, timing, soft limit and reference field is editable. Both axes
   must share one shield address; display address collisions are rejected.
2. Save, then **Apply to Device**. Saving never Home/Move commands a motor. An
   axis-only panel uses the canonical eight-byte empty legacy configuration
   `02 <configuration id, little endian> 00 00 ff`. ConfigurationStored must confirm
   its identity before axis setup. It removes old modules and resets/releases
   axes; independent SetOutput pins and removed display contents are not cleared.
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
7. Release manual control and explicitly Resume train control. Browser/process loss
   stops manual motion and leaves automatic output paused until Resume.

Manual startup is default. Commissioned internal-stop axes with idle hold can
explicitly opt into Home on connect, causing one bounded movement on each genuine
new UART connection after acknowledged setup. Train activation, form save, legacy
Apply, host/session restart, recovery and duplicate device events do not authorize
a fresh automatic Home. An uncertain Home outcome remains blocked for recovery.

## Train binding and calibration

In the train editor choose **Gauges → Add gauge**. Select an axis and a verified
endpoint through the API explorer or enter it offline. Verify the reported units.
A selected value key chooses that numeric field. Without a key only one
unambiguous numeric value in a valid node is accepted. Invalid/missing data never
becomes zero.

Units are raw, m/s, km/h and mph; raw converts only to raw. Mapping order is unit
conversion, optional absolute value, multiplier, offset, piecewise linear
interpolation and integer-target rounding. Intermediate calculations retain their
precision; display formatting does not change the target. Negative input remains
negative unless absolute input is explicitly selected. Choose clamp or reject
outside the calibration domain.

Record 2–32 strictly increasing dial values with strictly monotonic positions
(increasing or decreasing), inside axis soft limits. Add/edit/remove/reorder rows.
Preview shows converted value, target estimate and clamp state without movement.
Test value deliberately moves only with a manual lease. Capture position records
the entered dial reading with a fresh stationary known position **estimate**, not
a sensor measurement. Review calibration after mode/axis/bounds changes. Save
disabled, review the measured calibration, commission hardware, then enable the
binding. Saving candidate points does not certify physical calibration.

## Editable Class 323 starter

The optional starter suggests 0–100 mph, approximately 240° / 720 six-state
transitions, points 0 mph → 0 and 100 mph → 720. These are **unverified estimates**,
saved disabled and awaiting calibration review.
The endpoint is blank; m/s input and mph output must be verified. With these
candidate points, 44.704 m/s converts to 100 mph and targets 720.

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

Invalid/stale simulator data retains the last target only until stale timeout.
Inactive hold sends Stop, inactive release sends Release. Train changes and
simulator loss apply the outgoing policy and discard previous samples. Recovery
requires acknowledged reset/configure and fresh reference; only fresh simulator
data may drive again.

## MCP

Axis tools provide list/create/update/delete/status and explicit control; gauge
tools provide list/create/update/delete and pure preview. Shared contexts enforce
the same validation as UI. Runtime control claims a 60-second opaque lease,
renewed only explicitly. Every mutation supplies an operation token. Identical
token/arguments reuse admission instead of restarting motion; changed content
rejects. Up to 100 records are retained for the lease lifetime, then new operations
reject until a new lease. Expiry Stops and leaves automatic control paused.
Status distinguishes pending acceptance from completion.

## Physical acceptance

Automated UART/simulator tests do **not** validate actual winding order, electrical
ratings, polarity, acceleration, travel, stop contact, lost steps, endpoint units,
pointer load or needle fit. Verify these conservatively on the actual hardware.
Measure intermediate marks and both end limits. Test power-cycle/reconnect and the
chosen startup policy deliberately, with Stop/Release accessible. Needle fit
remains separate mechanical work; no real motor validation is claimed.
