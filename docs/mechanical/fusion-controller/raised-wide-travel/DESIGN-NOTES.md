# Raised, wide-travel locomotive lever

Revision date: 25 October 2026. Separate Fusion document: AIDesignedLever Raised Wide Travel. Earlier recessed and coupling versions remain available for comparison.

## Layout

The module hangs from the existing top rails. Rail top remains Z55 mm; pivot rises from Z18 to Z30 mm, so it is 25 mm below the rail tops. The main gear reaches Z61.25, only 6.25 mm above the rails. Pot axis is Z-15.15. A small raised local housing can eventually cover the mechanism. No top panel or cosmetic housing is designed in this revision.

Mechanical travel target is +/-60 degrees, 120 degrees total. Interchangeable cams put stable end gates at +/-58 degrees, leaving 2 degrees to the structural stops. Gate span is 116 degrees: 7 positions are 19.33 degrees apart; 8 positions are 16.57 degrees apart. An 8-position cam has no central gate; zero lies midway between the central pair. Choose a 7-position cam when a central neutral notch is required. Three- and five-position alternatives use the same end gates and mounting pattern.

The 48/24 tooth gearing retains two degrees of sensor rotation for one degree of lever rotation. Full mechanical travel requires 240 degrees of pot travel, plus margin before its internal stops. This is a design target, not a measured electrical range. Do not force the pot against its stops. Confirm mechanical and usable electrical travel before fitting the pinion for full-range operation. Existing stop positions are fixed, not continuously adjustable.

## Measured potentiometer

User reported shaft diameter 6 mm, 15 mm body-front-to-tip projection including the M7 threaded bushing, and 8 mm exposed rotating shaft. Bushing length 7 mm is inferred by subtraction. Body is 11.2 x 9.5 x 6.6 mm excluding protruding terminals; the 11.2/9.5 orientation is a modeling assumption. Rotating shaft occupies X41..49 mm. The pinion occupies X40.5..48.5, with bushing relief to X41.3, providing about 7.2 mm of cylindrical engagement and 0.5 mm shaft projection. Thread pitch, terminal projection/direction, shaft texture, electrical taper and actual travel are not established. Preserve wiring space and verify supplied mounting nut/washer.

These measurements were saved to Maker Inventory part c4d42b8a-8252-402c-a14a-8a8e318ed8de, version 3. Stock remained ten estimated pieces; no stock was consumed.

## Shaft and gear questions

The structural shaft is split longitudinally to print on broad flat faces while retaining circular bearing journals, different diameters and axial shoulders. A full-length D flat would interrupt those round running surfaces; a flat confined to the drive section would not support the rest of the shaft on the bed. This revision retains the existing shaft geometry, joining hardware and printed bushes. It does not claim to solve their physical wear, compliance or print issues.

The large gear is one connected printed part, not two gear halves. Its radial slit lets the M3 clamp tighten the D-shaped bore around the drive stub. That reduces hub movement but does not eliminate tooth backlash. This is not a spring-loaded anti-backlash gear.

## Meaningful hardware improvement

A metal axle running in two ball bearings is the strongest candidate for improving rigidity, smoothness and wear compared with split printed journals. Inventory already lists ten 608ZZ bearings (8 x 22 x 7 mm), and two each of M8 x70/x80/x100 partially threaded bolts. Their unthreaded lengths are unknown: threads must not substitute for a smooth bearing seat. These are candidates for a separate axle/bearing redesign, not drop-in replacements or required purchases for this revision. A ground, factory-cut 8 mm shaft would avoid the bolt-seat uncertainty and respect the no-cutting requirement. Amazon Spain listing verified in the browser on 25 October 2026: [DollaTek five 8 x 100 mm carbon-steel shafts](https://www.amazon.es/dp/B081JNJPV2), shown in stock at EUR 9.99 for the pack. This is a candidate for the bearing redesign, not a drop-in replacement for this printed shaft. Listing dimensional tolerance was not established; check the bearing fit. Price and stock can change.

## Assembly changes

Use both new sideplates and one new cam together. Do not mix the old 100-degree cams with the new 116-degree gate spacing. Stock stop cores remain M3x20 with captive M3 plain nuts. Top-rail fasteners remain M5x14 and T-nuts at the original height; shorter hangers lift the mechanism without lifting the rail seats. All remaining fasteners and spring arrangement carry forward from the geared assembly. Install and test mechanical movement without the sensor first, then center and fit the sensor after confirming its available travel.

Spring rate and solid height remain assumptions from the earlier revision. The wider cam changes spacing while retaining 1.4 mm nominal lift. Confirm gate force, spring compression, return into each notch, reversal readings and shaft end float on the physical prototype. This is not a structural load or fatigue certification.
