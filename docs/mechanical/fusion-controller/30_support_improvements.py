"""Incremental support reduction on v4. Run once, never on a rebuilt/modified model blindly."""
exec(open('C:/Users/Alberto/Documents/tsw_io/docs/mechanical/fusion-controller/common.py').read())

def run(_context:str):
 app=C.Application.get();d=F.Design.cast(app.activeProduct);root=d.rootComponent
 def co(pre):return next(o.component for o in root.allOccurrences if o.component.name.startswith(pre))
 assert not any(f.name.startswith('Support-free flange ramp') for f in co('P17').features),'Already applied'
 tm=F.TemporaryBRepManager.get()
 before={o.component.name:tm.copy(o.component.bRepBodies.item(0)) for o in root.allOccurrences if o.component.name.startswith('P')}
 c=co('P17');s=sk(c,'y',0,'Support-free flange ramp profile')
 pts=[s.modelToSketchSpace(p(x,0,65+r)) for x,r in [(44,7),(48,11),(48,7)]]
 for i in range(3):s.sketchCurves.sketchLines.addByTwoPoints(pts[i],pts[(i+1)%3])
 axis=s.sketchCurves.sketchLines.addByTwoPoints(s.modelToSketchSpace(p(40,0,65)),s.modelToSketchSpace(p(51,0,65)))
 axis.isConstruction=True;s.isComputeDeferred=False
 assert s.profiles.count==1
 ri=c.features.revolveFeatures.createInput(s.profiles.item(0),axis,JOIN)
 ri.setAngleExtent(False,C.ValueInput.createByString('360 deg'))
 f=c.features.revolveFeatures.add(ri);f.name='Support-free flange ramp 45 degrees';s.isLightBulbOn=False
 # New ramp must not bridge the clamp split or refill its transverse hardware holes.
 box(c,(40.4,-.2,65),(50.6,.2,79),CUT,'Preserve clamp flexure through flange ramp')
 circle(c,'y',-7.2,45.5,73,2,7.1,CUT,'Preserve insert pocket through flange ramp')
 circle(c,'y',.1,45.5,73,1.7,9,CUT,'Preserve clamp screw through flange ramp')
 for prefix,sg in [('P09',-1),('P10',1)]:
  c=co(prefix)
  # In upright printing, roof progresses from the closed socket back to the open split face.
  # No material is added into the stem socket; screw rows at Z180/190 stay unchanged.
  poly(c,'y',-7.2,[(0,196),(sg*7.2,196),(0,203.2)],14.4,CUT,'Upright socket roof 45 degrees')
 report=[]
 for o in root.allOccurrences:
  c=o.component
  for s in c.sketches:s.isLightBulbOn=False
  if c.name not in before:continue
  assert c.bRepBodies.count==1 and c.bRepBodies.item(0).isSolid,c.name
  old=before[c.name];new=c.bRepBodies.item(0);q=tm.copy(old)
  assert tm.booleanOperation(q,new,F.BooleanTypes.IntersectionBooleanType)
  inter=q.volume if q.isValid and q.faces.count else 0
  report.append({'part':c.name,'before_mm3':old.volume*1000,'after_mm3':new.volume*1000,'removed_mm3':(old.volume-inter)*1000,'added_mm3':(new.volume-inter)*1000})
 bad=[{'part':o.component.name,'feature':f.name,'error':f.errorOrWarningMessage} for o in root.allOccurrences for f in o.component.features if f.healthState!=F.FeatureHealthStates.HealthyFeatureHealthState]
 result={'changes':report,'unhealthy':bad}
 open(ROOTDIR+'/support-revision/native-change-check.json','w').write(json.dumps(result,indent=2))
 print(json.dumps(result))
