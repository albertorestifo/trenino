exec(open('C:/Users/Alberto/Documents/tsw_io/docs/mechanical/fusion-controller/07_hardware.py').read().split('def run(_context:str):')[0])
def run(_context:str):
 root=F.Design.cast(C.Application.get().activeProduct).rootComponent
 def co(pre):return next(o.component for o in root.allOccurrences if o.component.name.startswith(pre))
 c=co('P13');box(c,(-24,-74,38),(24,-66,59),JOIN,'Extend reaction block into free rail bay')
 for xx in [-24,15.3]:
  circle(c,'x',xx,-54,53.5,2.01,8.7,JOIN,'Close mounting bore that crossed cup guide')
  circle(c,'x',xx-.1,-70,53.5,2,8.9,CUT,'Outer mounting row clear of guide')
 for pre,xx in [('P01',-36),('P02',24)]:
  circle(co(pre),'x',xx,-54,53.5,1.71,12,JOIN,'Close former inner mounting hole')
  circle(co(pre),'x',xx-.1,-70,53.5,1.7,12.2,CUT,'Matched outer mounting row')
 for xx in [5,19]:circle(c,'z',37.9,xx,-55,1.7,21.2,CUT,'Restore separate cup guide bore')
 circle(c,'x',-24.1,0,65,51,48.2,CUT,'Preserve cam envelope')
 for o in list(root.allOccurrences):
  if o.component.name.startswith('HARDWARE Spring block M3x20 (-54'):o.deleteMe()
 for sx in [-1,1]:bolt(root,'Spring block M3x20 '+str((-70,sx)),'x',sx*36,sx*16,-70,53.5,1.5,2.85,1.65,sx)
 for o in root.allOccurrences:
  for s in o.component.sketches:s.isLightBulbOn=False
 print('Final crossblock rows Y-70/-62 avoid guide tubes and leave rail clearance')
