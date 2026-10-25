exec(open('C:/Users/Alberto/Documents/tsw_io/docs/mechanical/fusion-controller/direct-v6-build-fixes/helpers.py').read())
def run(_context: str):
 d=F.Design.cast(C.Application.get().activeProduct);root=d.rootComponent
 for o in root.occurrences:
  if o.component.name.startswith(('REFERENCE - fixed','HARDWARE Rail M5')):
   o.isGrounded=True
   continue
  m=o.transform2;v=m.translation;v.z-=3.5;m.translation=v;o.transform2=m
  o.isGrounded=True
 if d.userParameters.itemByName('PivotHeight'):d.userParameters.itemByName('PivotHeight').expression='30 mm'
 finishstage(d,'04-recess')
 C.Application.get().activeViewport.fit()
