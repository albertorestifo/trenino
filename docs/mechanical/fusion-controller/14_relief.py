exec(open('C:/Users/Alberto/Documents/tsw_io/docs/mechanical/fusion-controller/common.py').read())
def run(_context:str):
 r=F.Design.cast(C.Application.get().activeProduct).rootComponent
 c=next(o.component for o in r.allOccurrences if o.component.name.startswith('P07'))
 circle(c,'x',-18.1,0,65,10.2,11.1,CUT,'Complete stop lug relief to rotor face')
 for s in c.sketches:s.isLightBulbOn=False
 print('Relief meets rotor face')
