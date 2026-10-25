exec(open('C:/Users/Alberto/Documents/tsw_io/docs/mechanical/fusion-controller/opposite-sides/helpers.py').read())

def run(_context:str):
 app,d,r=setup();c=next(o.component for o in r.occurrences if o.component.name.startswith('P07S'))
 box(c,(-7,21.4,25),(-5,22.5,35),JOIN,'Carry rotor clamp seat directly to print bed')
 done(d,'03g-supported-rotor-clamp')
