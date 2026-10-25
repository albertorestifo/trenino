exec(open('C:/Users/Alberto/Documents/tsw_io/docs/mechanical/fusion-controller/common.py').read())
def run(_context:str):
 root=F.Design.cast(C.Application.get().activeProduct).rootComponent
 c=next(o.component for o in root.allOccurrences if o.component.name.startswith('P17'))
 circle(c,'y',9,45.5,73,3.6,4,CUT,'Flat clearance around coupler washer on ramp')
 for s in c.sketches:s.isLightBulbOn=False
 print('Washer seat relieved to Y9 with 0.1 mm radial margin')
