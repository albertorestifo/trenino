# One-piece direct-drive shaft

Implement the accepted continuous-flat concept on the current recessed direct-drive lever. Preserve the positive-Y drive flat at6.5 mm, journal radius6 mm, shaft endpoints, shoulder bearing faces and Oldham tongue engagement. Replace both P05 halves by one native solid, remove joining screws/nuts and two P28 keys. Keep the existing end cap and one M3 nut/screw.

Cut a common bed plane atY=-4.2 mm through the journal, central shaft, retaining shoulder and input tongue. This gives the journals8.57 mm bed width and a maximum initial side overhang of44.43 degrees from vertical. It removes9.41% of journal area and19.09% of the existing central D-section area. It preserves the original upper drive flat; neither remaining area nor overhang angle is a strength certification.

Keep the cap-nut pocket atX-34..-31.4 and add access from the new bed flat. A45-degree roof relieves the axial M3 screw passage. The nut pocket closes across its2.6 mm axial width; inspect the actual slice. Install the nut before the left bush covers its access slot, and retain it with the cap screw during final assembly.

The prior split P04 bush and assembly order remain necessary. Recheck bush/housing/rotor insertion, native health, neutral fit, shaft motion, mesh integrity and default-profile layers. Release a one-piece shaft STL and updated package; no unsupported claim of tested strength. Record actual bush fit/wear and initial bed-layer cleanup as physical commissioning checks.


Final tongue extends to Y=+8 mm, retaining maximum 8 mm contact radius while its underside ends at Y=-4.2 mm. Total span12.2 mm; asymmetric contact requires physical wear/backlash validation. Class323 cam: nine gates -50..50 degrees, 12.5-degree pitch. Interval lifts .65,.65,.65,.9,.9,.65,.65,1.0 mm; center at0, Emergency at+50. Passive bidirectional barriers. See cam-profile-check.json and mechanical review.
