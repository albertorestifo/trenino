# Lever A/B comparison — geared development copy

## Independent builds

- **A: AIDesignedLever v6** — saved coupling baseline. Its native archive, printable files and illustrated assembly guide remain in `../inventory-support-free-revision/`.
- **B: AIDesignedLever Gear Comparison** — separate Fusion document copied from A. Prototype print geometry; see PRINT-README.md for the released files and remaining physical checks.

The geared copy uses a 48-tooth lever gear and 24-tooth potentiometer pinion: the potentiometer rotates twice as far, in the opposite direction. Both use module 1.25, 20-degree pressure angle and an 8 mm face. Nominal center distance is 45 mm; initial modeled distance is 45.15 mm. The potentiometer sits above the lever shaft to reduce the axial envelope. The lever, cams, follower, spring and rail interfaces are retained for comparison.

The intended lever range of ±52 degrees produces ±104 degrees at the potentiometer. Confirm actual usable electrical and mechanical travel with margin before assembly. The provisional sensor envelope and supplied nut/washer assumptions remain unmeasured. Twice the shaft travel does not establish twice the accuracy; taper, noise, backlash and calibration affect usable resolution.

## Assembly differences for B (draft)

Use A's illustrated guide for unchanged parts. Replace its right plate, both shaft halves, coupling pieces and sensor carriage with P02G, P05G, G01, G02 and G03. Do not mix their instructions or print files.

1. Install the two additional sensor-support inserts in P02G from the inboard side before fitting the plate. Assemble the split shaft using its original joining screws and keys.
2. Fit G01 on the short D-shaped stub. Its split faces down at the lever's neutral position. Fit its insert and M3×12 clamp screw, then tighten only enough to retain the gear.
3. Mount the potentiometer on G03 using its supplied washer and nut. Fit G02 on the sensor shaft with its split pointing 30 degrees past upward toward negative Y at neutral (120 degrees measured from positive Y toward positive Z); keep the modeled tooth phase. Set the potentiometer near the center of its usable travel first.
4. Attach G03 using two M3×12 screws. Adjust the mesh without forcing the teeth together. The design target is 45.0–45.5 mm center distance; the slots permit more movement, but that is not a recommended operating range.
5. Slowly move the lever through its full range without electrical power. Stop if the potentiometer reaches an internal stop or the gears bind. Check both clamp openings stay outside the engaged tooth sectors throughout travel.
6. Calibrate each assembly separately, including direction reversal for the geared sensor.

Remove G01 and its clamp before withdrawing a cam: the larger gear obstructs the cam service path. Use the revised pinion with its open clamp tool channel. Physical retention and fit still require a prototype test.

## Hardware planning

Combined A/B Maker Inventory project: `349e5de5-10ca-4315-a996-d8666f7ebc03`.

Both assemblies together provisionally require 39 M3 heat-set inserts; M3 screws: 6×8 mm, 6×10 mm, 10×12 mm, 3×16 mm and 20×20 mm; 6 M3 nuts; 8 M5×14 screws; 8 rail T-nuts; 4 623ZZ bearings; 2 potentiometers; and 2 stocked compression springs. No cut metal is required. Estimated stock is sufficient, but this uses every documented M3×20 screw in the kit. Recount those before building both. The inventory project is a plan, not a stock reservation or deduction.

Spring rate and compressed length remain assumptions. Use the same preload for the comparison and verify the spring does not bind before applying force.

## Fair performance and assembly test

Use the same cam type, lever travel, print material, printer settings, spring preload, ADC, supply voltage, filtering and sampling rate. Record print time and material separately. Ideally swap the same potentiometer between builds after the initial side-by-side test to separate sensor variation from mechanism behavior.

1. **Assembly:** time from sorted parts to calibrated operation. Record insert installation separately, tools used, adjustments, reprints and mistakes. Repeat once after learning each assembly; alternate build order.
2. **Packing:** measure the installed maximum width and the minimum practical spacing between adjacent levers, including screw access and moving clearance.
3. **Backlash:** at center and near both ends, approach a fixed pointer mark from each direction. Record the lever angle moved after reversal before the sensor responds. Repeat 10 times at each position; distinguish friction and ADC noise from lost motion.
4. **Repeatability:** visit each detent from both directions for 20 cycles. Record raw ADC readings and compare distributions at each detent, rather than only averages.
5. **Range and noise:** record endpoint counts, then hold at five positions for 10 seconds each at a fixed sample rate. Record peak-to-peak noise and standard deviation. Fit a calibration curve for each build; do not assume the cheap potentiometers are linear.
6. **Feel and service:** record binding, tooth ripple, slipping clamps, and the time to change a cam and replace the potentiometer. Repeat the measurements after at least 500 full-stroke cycles.

No performance winner is established until measured. Prefer the version that achieves useful repeatability and packing with less assembly and adjustment effort.

## Current evidence

The copied design contains the geared components. A planar involute-profile check sampled the ±52-degree lever range in 0.25-degree increments without profile overlap at center distances 45.0, 45.15 and 45.5 mm. The calculated transverse contact ratio at 45.15 mm is about 1.56. This check excludes clamp cuts, shaft fits, manufacturing tolerances and elastic deflection; it does not replace the pending assembly and print checks.
