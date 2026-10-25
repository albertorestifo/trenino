import adsk.core as C,adsk.fusion as F,json,os,re
OUT='C:/Users/Alberto/Documents/tsw_io/docs/mechanical/fusion-controller/one-piece-shaft'

def run(_context: str):
 app=C.Application.get();d=F.Design.cast(app.activeProduct);root=d.rootComponent;ex=d.exportManager
 os.makedirs(OUT+'/raw-stl',exist_ok=True);rows=[];bad=[]
 for o in root.allOccurrences:
  c=o.component
  for f in c.features:
   if f.healthState!=F.FeatureHealthStates.HealthyFeatureHealthState:bad.append([c.name,f.name,f.errorOrWarningMessage])
  if not c.name.startswith(('P05 ','P08 Cam 9')):continue
  for b in c.bRepBodies:
   assert b.isSolid and b.isValid,b.name
   name=b.name if c.bRepBodies.count>1 else c.name
   safe=re.sub('[^A-Za-z0-9_-]+','-',name).strip('-')
   opt=ex.createSTLExportOptions(b,OUT+'/raw-stl/'+safe+'.stl')
   opt.unitType=F.DistanceUnits.MillimeterDistanceUnits;opt.meshRefinement=F.MeshRefinementSettings.MeshRefinementHigh
   assert ex.execute(opt),name
   rows.append({'component':c.name,'name':name,'file':safe+'.stl','volume_mm3':b.volume*1000,'assembly_transform':o.transform2.asArray(),'bounds_mm':[[v*10 for v in p.asArray()] for p in [b.boundingBox.minPoint,b.boundingBox.maxPoint]]})
 assert not bad,str(bad)
 with open(OUT+'/export-manifest.json','w') as f:json.dump(rows,f,indent=2)
 assert ex.execute(ex.createFusionArchiveExportOptions(OUT+'/Direct-Pot-One-Piece-Shaft.f3d'))
 with open(OUT+'/native-health.json','w') as f:json.dump({'document':app.activeDocument.name,'modified':app.activeDocument.isModified,'unhealthy':bad,'print_files':len(rows),'features':sum(o.component.features.count for o in root.allOccurrences)},f,indent=2)
 print(json.dumps({'exported':len(rows),'native_archive':OUT+'/Direct-Pot-One-Piece-Shaft.f3d','unhealthy':bad}))
