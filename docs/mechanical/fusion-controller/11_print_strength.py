exec(open('C:/Users/Alberto/Documents/tsw_io/docs/mechanical/fusion-controller/common.py').read())
def run(_context:str):
 d=F.Design.cast(C.Application.get().activeProduct);root=d.rootComponent
 rotor=next(o.component for o in root.allOccurrences if o.component.name.startswith('P07'))
 next(f for f in rotor.features.extrudeFeatures if f.name.startswith('Integral axial locating hub')).deleteMe()
 shaft=next(o.component for o in root.allOccurrences if o.component.name.startswith('P05'))
 box(shaft,(37.25,6.5,54),(40.45,11,76),CUT,'Flat shoulder aligns with shaft print bed')
 for name,x in [('P23 Left rotor thrust spacer',-23.85),('P24 Right rotor thrust spacer',7)]:
  c=comp(root,name);b=circle(c,'x',x,0,65,10,16.85,name='Controlled rotor axial clearance');b.name=c.name
  circle(c,'x',x-.1,0,65,8.2,17.05,CUT,'Free spacer bore')
 for o in root.allOccurrences:
  for s in o.component.sketches:s.isLightBulbOn=False
  o.component.isOriginFolderLightBulbOn=False
 print('Lever now prints on broad face, shaft shoulder flattened, rotor end float nominal0.3 mm')
