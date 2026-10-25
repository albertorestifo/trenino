from pathlib import Path
p=Path('docs/mechanical/fusion-controller/ASSEMBLY-AND-PRINT-GUIDE.md')
s=p.read_text();s += '\nThe final crossblock uses mounting rows Y=-70/-62 mm at Z=53.5 mm. Its rear edge stops at Y=-74 mm, 1 mm inside the existing rail face. This separates the four mounting inserts from both the cam relief and the vertical cup guides. The narrowest nominal installed-insert outer wall is 1.7 mm (assuming 4.6 mm insert OD). The guide bores remain at X5/19, Y=-55.\n'
p.write_text(s)
