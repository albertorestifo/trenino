exec(open('C:/Users/Alberto/Documents/tsw_io/docs/mechanical/fusion-controller/common.py').read())
def run(_context: str):
 app=C.Application.get();d=F.Design.cast(app.activeProduct);r=d.rootComponent
 assert app.activeDocument.dataFile.id=='urn:adsk.wipprod:dm.lineage:8phaaOK2S5SnbORU7BqJyQ'
 for pre,x in [('P01R',-36),('P02R',24)]:
  c=next(o.component for o in r.occurrences if o.component.name.startswith(pre))
  for yy in [-62,-70]:circle(c,'x',x-.1,yy,53.5,1.7,12.2,CUT,'Preserve crossblock screw through suspension arm')
  for s in c.sketches:s.isLightBulbOn=False
 print('Restored four existing crossblock screw bores through the new hanging arms')
