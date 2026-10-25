exec(open('C:/Users/Alberto/Documents/tsw_io/docs/mechanical/fusion-controller/common.py').read())
def run(_context:str):
 d=F.Design.cast(C.Application.get().activeProduct);root=d.rootComponent
 right=next(o.component for o in root.allOccurrences if o.component.name.startswith('P02'))
 outer=[(-52*math.sin(math.radians(t)),65-52*math.cos(math.radians(t))) for t in range(-66,67,2)]
 inner=[(-26*math.sin(math.radians(t)),65-26*math.cos(math.radians(t))) for t in range(66,-67,-2)]
 poly(right,'x',23.9,outer+inner,12.2,CUT,'Cam lateral service opening')
 for sg in [-1,1]:box(right,(36,18 if sg>0 else -28,48.9),(80.1,28 if sg>0 else -18,56),CUT,'Clear service path beneath sensor rails')
 print('Cam service window built, sensor rails clear above Z56')
