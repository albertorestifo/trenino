exec(open('C:/Users/Alberto/Documents/tsw_io/docs/mechanical/fusion-controller/common.py').read())
def run(_context:str):
 root=F.Design.cast(C.Application.get().activeProduct).rootComponent
 def co(pre):return next(o.component for o in root.allOccurrences if o.component.name.startswith(pre))
 for pre,xx in [('P01',-30),('P02',30)]:
  c=co(pre)
  for yy in [-76,54]:circle(c,'y',yy,xx,45,2.7,22,CUT,'Restore rail bolt clearance after hole filling')
  for yy in [-55,43]:circle(c,'y',yy,xx,45,5.3,12,CUT,'Restore rail head access after hole filling')
 circle(co('P07'),'x',-18.1,0,65,10.2,11.0,CUT,'Stop lug clearance for concentric thrust spacer')
 for o in root.allOccurrences:
  for s in o.component.sketches:s.isLightBulbOn=False
 print('Rail bores restored and stop lug relieved around spacer')
