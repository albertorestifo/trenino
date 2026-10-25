exec(open('C:/Users/Alberto/Documents/tsw_io/docs/mechanical/fusion-controller/opposite-sides/helpers.py').read())

def run(_context:str):
 app,d,r=setup();carrier=next(o.component for o in r.occurrences if o.component.name.startswith('P32 '))
 cuts=[f for f in carrier.features.extrudeFeatures if f.name.startswith('Flange clearance and axial float relief')];assert len(cuts)==1
 cuts[0].deleteMe()
 bush=next(o.component for o in r.occurrences if o.component.name.startswith('P03 '))
 box(bush,(-37.3,-13,52),(-37,13,78),CUT,'One mm flange provides carrier clearance without underside pocket')
 done(d,'03e-flat-carrier-bed')
