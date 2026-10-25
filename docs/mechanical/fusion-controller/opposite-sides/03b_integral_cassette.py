exec(open('C:/Users/Alberto/Documents/tsw_io/docs/mechanical/fusion-controller/opposite-sides/helpers.py').read())

def run(_context:str):
 app,d,r=setup();c=next(o.component for o in r.occurrences if o.component.name.startswith('P33 '))
 spacers=[o for o in r.occurrences if o.component.name.startswith('P34 ')]
 assert len(spacers)==2
 oldvolume=c.bRepBodies.item(0).volume+sum(o.component.bRepBodies.item(0).volume for o in spacers)
 for yy in [-55,-15]:
  circle(c,'x',-45.2,yy,-39,6,11.7,JOIN,'Integral compression post removes loose spacer')
  circle(c,'x',-45.3,yy,-39,1.7,11.9,CUT,'Continuous cassette screw bore')
 assert c.bRepBodies.count==1
 assert abs(c.bRepBodies.item(0).volume-oldvolume)<1e-5
 for o in spacers:o.deleteMe()
 c.name='P33 Integral follower support cassette'
 done(d,'03b-integral-cassette')
