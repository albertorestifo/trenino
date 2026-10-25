exec(open('C:/Users/Alberto/Documents/tsw_io/docs/mechanical/fusion-controller/opposite-sides/helpers.py').read())

def run(_context:str):
 app,d,r=setup();c=next(o.component for o in r.occurrences if o.component.name.startswith('P32 '))
 box(c,(-28,11.5,25),(-25.5,14.8,35),JOIN,'Carry clamp boss footprint directly to print bed')
 done(d,'03f-supported-clamp-boss')
