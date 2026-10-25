import adsk.core as C,adsk.fusion as F,json,os,re
OUT='C:/Users/Alberto/Documents/tsw_io/docs/mechanical/fusion-controller/raised-wide-travel'

def run(_context: str):
 app=C.Application.get();d=F.Design.cast(app.activeProduct);root=d.rootComponent;ex=d.exportManager
 assert app.activeDocument.dataFile.id=='urn:adsk.wipprod:dm.lineage:peR4meb5QLiO5tE5ANITQg'
 os.makedirs(OUT+'/raw-stl',exist_ok=True);rows=[];bad=[]
 for o in root.allOccurrences:
  c=o.component
  for f in c.features:
   if f.healthState!=F.FeatureHealthStates.HealthyFeatureHealthState:bad.append([c.name,f.name,f.errorOrWarningMessage])
  if not re.match(r'^[PG]\d\d[GR]? ',c.name):continue
  for b in c.bRepBodies:
   assert b.isSolid and b.isValid,b.name
   name=b.name if c.bRepBodies.count>1 else c.name
   safe=re.sub('[^A-Za-z0-9_-]+','-',name).strip('-')
   opt=ex.createSTLExportOptions(b,OUT+'/raw-stl/'+safe+'.stl')
   opt.unitType=F.DistanceUnits.MillimeterDistanceUnits;opt.meshRefinement=F.MeshRefinementSettings.MeshRefinementHigh
   assert ex.execute(opt),name
   rows.append({'component':c.name,'name':name,'file':safe+'.stl','volume_mm3':b.volume*1000,'bounds_mm':[[v*10 for v in p.asArray()] for p in [b.boundingBox.minPoint,b.boundingBox.maxPoint]]})
 assert not bad,str(bad)
 with open(OUT+'/export-manifest.json','w') as f:json.dump(rows,f,indent=2)
 assert ex.execute(ex.createFusionArchiveExportOptions(OUT+'/Raised-Wide-Travel.f3d'))
 with open(OUT+'/native-health.json','w') as f:json.dump({'document':app.activeDocument.name,'modified':app.activeDocument.isModified,'unhealthy':bad,'print_files':len(rows),'features':sum(o.component.features.count for o in root.allOccurrences)},f,indent=2)
 print(json.dumps({'exported':len(rows),'native_archive':OUT+'/Raised-Wide-Travel.f3d','unhealthy':bad}))


