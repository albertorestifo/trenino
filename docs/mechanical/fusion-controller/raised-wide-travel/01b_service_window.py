exec(open('C:/Users/Alberto/Documents/tsw_io/docs/mechanical/fusion-controller/common.py').read())
def run(_context:str):
 d=F.Design.cast(C.Application.get().activeProduct);r=d.rootComponent
 assert C.Application.get().activeDocument.dataFile.id=='urn:adsk.wipprod:dm.lineage:peR4meb5QLiO5tE5ANITQg'
 c=next(o.component for o in r.occurrences if o.component.name.startswith('P02R'))
 assert not any(f.name.startswith('Wide cam service opening') for f in c.features)
 outer=[(-52*math.sin(math.radians(t)),65-52*math.cos(math.radians(t))) for t in range(-76,77,2)]
 inner=[(-26*math.sin(math.radians(t)),65-26*math.cos(math.radians(t))) for t in range(76,-77,-2)]
 poly(c,'x',23.9,outer+inner,12.2,CUT,'Wide cam service opening')
 bad=[(o.component.name,f.name,f.errorOrWarningMessage) for o in r.allOccurrences for f in o.component.features if f.healthState!=F.FeatureHealthStates.HealthyFeatureHealthState]
 assert not bad,str(bad)
 print('Service aperture widened for 140 degree cam blank; native features healthy')
