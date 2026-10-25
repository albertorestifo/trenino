exec(open('C:/Users/Alberto/Documents/tsw_io/docs/mechanical/fusion-controller/07_hardware.py').read().split('def run(_context:str):')[0])
OUT=ROOTDIR+'/direct-v6-build-fixes'
def co(root,pre):return next(o.component for o in root.occurrences if o.component.name.startswith(pre+' '))
def hexhole(c,axis,pos,u,v,af,depth,name,phase=0):
 rr=af/math.sqrt(3)
 return poly(c,axis,pos,[(u+rr*math.cos(i*math.pi/3+phase),v+rr*math.sin(i*math.pi/3+phase)) for i in range(6)],depth,CUT,name)
def finishstage(d,name):
 bad=[(c.name,f.name,f.errorOrWarningMessage) for c in d.allComponents for f in c.features if f.healthState!=F.FeatureHealthStates.HealthyFeatureHealthState]
 assert not bad,str(bad)
 for c in d.allComponents:
  c.isOriginFolderLightBulbOn=False
  for s in c.sketches:s.isLightBulbOn=False
 open(OUT+'/'+name+'-done.json','w').write(json.dumps({'unhealthy':bad,'features':sum(c.features.count for c in d.allComponents)}))
 print(name+' complete')
