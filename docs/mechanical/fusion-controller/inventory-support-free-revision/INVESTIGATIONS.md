# Three investigation results — 25 October 2026

The user requested one investigator per topic and parent-only Fusion modifications. Investigators returned findings in conversation; this consolidated record preserves them. Their long standalone report writes were interrupted, so no missing report is treated as evidence.

## Inventory investigator
The old hardware BOM could not be satisfied as written: M3x25/35/80, M4 preload screw/nut, M5x16 and the small metal sleeves were absent or unconfirmed. Stock springs are OD9/10, not the old OD8 candidate. The tube is OD8/ID6, not the old assumed ID5.2; user explicitly rejected cutting stock.

Confirmed purchased identities are mapped in `inventory-check.json` and the Maker Inventory draft. M3 kit contents document20 each of5/6/8/10/12/16/20mm and160 nuts. Most quantities are historical estimates, not a physical recount. Only the CNC Kitchen100-insert count is user-confirmed known stock. The pot is A10K with a seller15mm shaft label, without shaft/bushing/body drawing. Washer assortment has unknown individual dimensions, so it is not used for generic washer requirements.

## Coupling investigator
Recommended integrated shaft tongue, floating disc and one-piece split sensor clamp with shortened adjustable mount. Three printed sensor-drive parts including mount replace five. Input tongue X40.35..43.35; disc X41..49; output tongue X46.65..49.65; output clamp X49.65..58.65. Disc grooves4.2mm wide and2.8mm deep leave2.4mm web. Nominal face gap0.65mm and groove-bottom gap0.45mm require shaft end-float verification.

Using the same provisional sensor envelope, body end moves X97→83.15, saving13.85mm. A compliant one-piece coupler or nested shaft could save more, but introduces unvalidated wind-up, fatigue and sensor-loading risks. The selected floating design preserves alignment tolerance. Sensor shaft diameter6mm, M7 bushing and envelope remain assumptions;15mm seller length does not establish its datum. The clamp insert pocket opens atY-9; M3x16 fromY9 gives approximately3.7mm insert engagement. Through socket avoids a blind roof; lower tongue prong needs continuous support in axial printing.

## FDM investigator
P05's old horizontal orientation leaves journals/stub above the bed. A Y=0 longitudinal split preserves round journals and longitudinal paths. Two recessed M3x8 joining screws atX±15/Z65 and loose alignment keys avoid protrusions under print faces. Installed insert radial wall is approximately1.85mm at its end; fit and strength remain physical tests.

P07 stop lug grows from the rotor/stem footprint in X-max-down orientation; it is not inherently a floating island. Transverse holes and short insert-pocket bridges require actual slice review. P13 stays Z-max down; do not teardrop the4mm insert pilots because retention circumference and wall are constrained. P11's8.3mm teardrop apex would leave only0.131mm under its old roof; reinforce above it first and flatten lower cheek lobes. Bearing inner-race pad undersides need45-degree print ramps and must avoid shields.

Captured split printed pivot halves print flat, but are not proven equivalent in strength to a metal sleeve. Bearing pads must clear shields/corner radii. Existing grips' roof ramps address large roofs; hardware openings still need review. Bushes, cap, cams, cup, collar and spacers are straightforward support-free candidates. Disc groove width4.2mm is a deliberate short bridge. Default-profile verification is necessary; historical custom brim/bridge-speed settings do not establish current printability.
