exec(open('C:/Users/Alberto/Documents/tsw_io/docs/mechanical/fusion-controller/07_hardware.py').read().split('def run(_context:str):')[0])
def run(_context:str):
 app=C.Application.get();d=F.Design.cast(app.activeProduct);root=d.rootComponent
 def co(pre):return next(o.component for o in root.allOccurrences if o.component.name.startswith(pre))
 bracket=co('P13')
 box(bracket,(-24,-66,52),(24,-44,57),JOIN,'Raise mount clear of rail bolt axes')
 for yy in [-59,-51]:
  for x in [-24,15.3]:
   circle(bracket,'x',x,yy,44,2.01,8.7,JOIN,'Close old block mounting hole')
   circle(bracket,'x',x-.1,yy,52,2,8.9,CUT,'Raised M3 block insert')
  for pre,x in [('P01',-36),('P02',24)]:
   plate=co(pre)
   circle(plate,'x',x,yy,44,1.71,12,JOIN,'Close old plate mounting hole')
   circle(plate,'x',x-.1,yy,52,1.7,12.2,CUT,'Raised M3 block fastener')
 circle(bracket,'z',51.9,12,-55,2.2,5.2,CUT,'Continue adjuster bore')
 for xx in [5,19]:circle(bracket,'z',51.9,xx,-55,1.7,5.2,CUT,'Continue guide bore')
 circle(bracket,'x',-24.1,0,65,51,48.2,CUT,'Preserve cam sweep clearance')
 remove=[o for o in root.allOccurrences if o.component.name.startswith(('P15','HARDWARE Cup guide M3','HARDWARE Cup guide washer','HARDWARE Spring block M3'))]
 for o in remove:o.deleteMe()
 c=comp(root,'P15 Preload limit collar 4 mm')
 b=circle(c,'z',57,12,-55,3.3,4,name='One mm maximum extra compression');b.name=c.name
 circle(c,'z',56.9,12,-55,2.25,4.2,CUT,'Adjuster clearance')
 for xx in [5,19]:
  bolt(root,'Cup guide M3x30 '+str(xx),'z',32,62,xx,-55,1.5,2.85,1.65,-1)
  washer(root,'Cup guide washer '+str(xx),'z',57,xx,-55,3.5,1.7,.5)
  nut(root,'Cup guide M3 nut '+str(xx),'z',57.5,xx,-55,5.5,2.4,1.5)
 for yy in [-59,-51]:
  for sx in [-1,1]:bolt(root,'Spring block M3x20 '+str((yy,sx)),'x',sx*36,sx*16,yy,52,1.5,2.85,1.65,sx)
 circle(co('P17'),'y',9,45.5,73,3.6,2,CUT,'Clamp washer clearance at flange')
 for o in root.allOccurrences:
  for s in o.component.sketches:s.isLightBulbOn=False
  o.component.isOriginFolderLightBulbOn=False
 print('Separated rail and crossblock fasteners; preload collar and guide hardware corrected')
