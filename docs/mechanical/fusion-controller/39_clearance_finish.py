exec(open('C:/Users/Alberto/Documents/tsw_io/docs/mechanical/fusion-controller/common.py').read())

def run(_context: str):
 root=F.Design.cast(C.Application.get().activeProduct).rootComponent
 right=next(o.component for o in root.allOccurrences if o.component.name.startswith('P02 '))
 for yy in [20.8,-21.4]:circle(right,'y',yy,60.15,65,1.7,.6,CUT,'Clear stocked carriage screw tip beyond insert')
 fork=next(o.component for o in root.allOccurrences if o.component.name.startswith('P11 '))
 poly(fork,'y',-2.5,[(7,9.5),(8.1,9.5),(8.1,10.7),(7,9.6)],5,CUT,'Support-free lower ramp under left inner-race pad')
 poly(fork,'y',-2.5,[(15.9,9.5),(17,9.5),(17,9.6),(15.9,10.7)],5,CUT,'Support-free lower ramp under right inner-race pad')
 for o in root.allOccurrences:
  for s in o.component.sketches:s.isLightBulbOn=False
 print('Carriage tip relief and inner-race pad print ramps completed.')
