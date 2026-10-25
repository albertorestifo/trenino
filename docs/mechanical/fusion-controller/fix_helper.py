from pathlib import Path
p=Path('docs/mechanical/fusion-controller/01_foundation.py');s=p.read_text()
a=s.index(" print('Extrude'");b=s.index('\n return e.bodies.item(0)',a)
s=s[:a]+''' ei=c.features.extrudeFeatures.createInput(s.profiles.item(0),op)
 ei.setOneSideExtent(F.DistanceExtentDefinition.create(val(depth)),F.ExtentDirections.PositiveExtentDirection)
 if op==CUT:ei.participantBodies=[b for b in c.bRepBodies]
 e=c.features.extrudeFeatures.add(ei);e.name=name;s.isLightBulbOn=False'''+s[b:]
p.write_text(s)
Path('docs/mechanical/fusion-controller/common.py').write_text(s[:s.index('def run(_context:str):')])
p=Path('docs/mechanical/fusion-controller/06_retention.py');s=p.read_text().replace("hub.features.extrudeFeatures.itemByName('M3 radial tapped plastic clamp pilot').deleteMe()","next(f for f in hub.features.extrudeFeatures if f.name.startswith('M3 radial tapped plastic clamp pilot')).deleteMe()")
p.write_text(s)
