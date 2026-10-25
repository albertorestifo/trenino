exec(open('C:/Users/Alberto/Documents/tsw_io/docs/mechanical/fusion-controller/common.py').read())

def run(_context: str):
 d=F.Design.cast(C.Application.get().activeProduct);root=d.rootComponent
 c=next(o.component for o in root.allOccurrences if o.component.name.startswith('P11 '))
 circle(c,'x',3.9,0,12,1.7,16.2,CUT,'Restore axle bore after adding print feet')
 rr=5.8/math.sqrt(3)
 poly(c,'x',3.9,[(rr*math.cos(i*math.pi/3),12+rr*math.sin(i*math.pi/3)) for i in range(6)],1.6,CUT,'Restore nut installation recess after print foot')
 c=next(o.component for o in root.allOccurrences if o.component.name.startswith('P15 '))
 box(c,(8,-59,56),(16,-51,57.1),CUT,'Retain one mm preload travel before head meets collar')
 c.name='P15 Recessed preload limit collar 1 mm';c.bRepBodies.item(0).name=c.name
 for o in root.allOccurrences:
  for s in o.component.sketches:s.isLightBulbOn=False
 print('Restored fork hardware passages and corrected collar stop to allow one mm preload adjustment.')
