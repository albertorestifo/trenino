exec(open('C:/Users/Alberto/Documents/tsw_io/docs/mechanical/fusion-controller/opposite-sides/helpers.py').read())

def run(_context:str):
 app,d,r=setup()
 panel=next(o.component for o in r.occurrences if o.component.name.startswith('G03S'))
 box(panel,(21.9,-24,-29.8),(25.1,24,-29.5),CUT,'Panel lower adjustment clearance')
 box(panel,(21.9,-24,-.5),(25.1,24,-.2),CUT,'Panel upper adjustment clearance')
 for pre,x in [('P01S',-24),('P02S',12)]:
  c=next(o.component for o in r.occurrences if o.component.name.startswith(pre))
  for f in reversed(list(c.features.extrudeFeatures)):
   if f.name.startswith('Brace mounting clearance'):f.deleteMe()
  for yy in [-60,60]:
   for zz in [30,40]:circle(c,'x',x-.1,yy,zz,1.7,12.2,CUT,'Lower brace mounting clearance')
 for o in r.occurrences:
  if o.component.name.startswith(('P30 ','HARDWARE Brace M3')):
   m=o.transform2;v=m.translation;v.z-=.5;m.translation=v;o.transform2=m
 done(d,'03c-lower-braces')
