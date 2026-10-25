from pathlib import Path
import re
root=Path('docs/mechanical/fusion-controller');p=root/'ASSEMBLY-AND-PRINT-GUIDE.md';s=p.read_text(encoding='utf-8')
s=s.replace('P01\u2013P24','P01\u2013P26').replace('27 print files total','29 print files total')
table='''| Item | Quantity | Purpose |
|---|---:|---|
| CNC Kitchen M3 x 5.7 mm heat-set insert | 16 | Shaft 1, rotor 4, grip 2, crossblock 4, input clamp 1, output clamp 2, carriage rails 2 |
| M3 x 8 | 1 | Shaft retaining cap |
| M3 x 10 | 3 | Selected cam |
| M3 x 12 | 2 | Sensor carriage |
| M3 x 16 | 4 | Coupling clamps 3, rotor clamp 1 |
| M3 x 20 | 5 | Crossblock 4, roller axle 1 |
| M3 x 25 | 4 | Grip 2, stop reinforcement 2 |
| M3 x 35 | 2 | Spring cup guides |
| M3 x 80 | 1 | Follower pivot through the retained metal sleeve |
| M3 plain nuts | 3 | Roller axle and cup guides |
| M3 locknuts, nominal AF5.5 x 4 mm high | 3 | Stops 2, follower pivot 1 |
| M3 washers, OD7 / ID3.4 x 0.5 mm | 12 | Coupling 3, carriage 2, guides 2, rotor 1, stops 2, pivot 2 |
| M4 x 25 socket-head screw, head OD7 | 1 | Preload adjuster |
| M4 nut, nominal AF7 x 3.2 mm high | 1 | Retained preload reaction nut |
| M5 x 16 button-head screws | 4 | Accessible top-slot rail mounts |
| M5 metal spacer, OD10 / ID5.4 x 3 mm | 4 | A metal washer stack totaling 3 mm per bolt can substitute |
| Matching M5 roll-in/drop-in 2020 T-nuts | 4 | Top rail slots; use the user's compatible T-nuts |
| Metal sleeve OD8 / ID5.2 x 48 mm | 1 | Structural follower pivot sleeve; retain with M3 bolt and printed P25/P26 centering inserts |
| Metal sleeve OD4 / ID3.2 x 10 mm | 1 | Roller axle sleeve |
| Metal sleeve OD4 / ID3.2 x 6 mm | 2 | Cup guide sleeves |
| RK097 with supplied nut/washer | 1 | Unverified AliExpress variant; replaceable mount and clamp |
| Compression spring | 1 | See spring selection below |

'''
s=re.sub(r'\| Item \| Quantity \| Purpose \|.*?(?=Insert bores)',table,s,flags=re.S)
s=s.replace('two M5 stop nuts into P01; install stop core bolts','two M3 locknuts into the recessed P01 stop pockets; install M3 x 25 stop bolts with 0.5 mm washers')
s=s.replace('Seat bushes in plates. Slide P23 onto the shaft, then the rotor and P24; assemble shaft/bushes and cap.','Seat printed bushes P03/P04 in printed plates P01/P02. Slide printed spacer P23 onto printed shaft P05, then printed rotor P07 and spacer P24; assemble through the bushes and fit printed retaining cap P06.')
s=s.replace('Install follower between P21/P22 on the 48 mm sleeve, then the M5 pivot bolt.','Fit printed P25/P26 centering inserts flush into the ends of the retained 48 mm METAL pivot sleeve. Install the follower between printed P21/P22 spacers on that sleeve. Use an M3 x 80 pivot bolt with a 0.5 mm washer at each plate and an M3 locknut. P25/P26 center the smaller bolt; they do not replace the structural metal sleeve.')
s=s.replace('M3 \u00d7 30 bolts','M3 x 35 bolts')
s=re.sub(r'Mount plates to the inner upper extrusion faces.*?(?=7\. Set the lever)', 'Seat the revised P01/P02 flanges on top of the upper rails. Tighten four M5 x 16 screws from above, each with a 3 mm TOTAL metal spacer/washer stack, into compatible M5 T-nuts in the top slots. Use roll-in/drop-in T-nuts when rail ends are blocked. The rail top is Z55, head seat Z66 and screw tip Z50; the actual extrusion web is Z48.8, giving 1.2 mm nominal tip clearance. Do not add washers beyond the specified total. Verify actual T-nut engagement (at least 3 mm full threads or the supplier requirement) and no bottoming.\n7. Set the lever',s,flags=re.S).replace('7. Set the lever7. Set the lever','7. Set the lever')
s=s.replace('Print P03/P04 bushes, P05 shaft, P06 cap and P23/P24 thrust spacers.','Print P03/P04 bushes, P05 shaft, P06 cap, P23/P24 thrust spacers and P25/P26 centering inserts. Use a small brim for the two 5 mm-diameter centering inserts and clean their bores carefully.')
s+='\n## Mount-access revision\n\nP01 and P02 now use accessible vertical mounting screws into the TOP rail slots. The old side-entry rail screws and buried pockets are obsolete. Both plates retain their broad-face print orientations and are190 mm across the new mounting flanges. Stop cores and follower pivot use M3 locknuts; the preload adjuster still needs its separate M4 nut. Confirm your actual M3 locknuts fit the4 mm-high modeled envelope.\n'
(root/'ASSEMBLY-AND-PRINT-GUIDE.revised.md').write_text(s,encoding='utf-8')
assert 'M5 \u00d7 25' not in s and 'M5 \u00d7 80' not in s and '\ufffd' not in s
print('Rebuilt hardware table and assembly instructions with explicit UTF-8 encoding')
