import adsk.core as C,adsk.fusion as F,json,os,re
ROOTDIR='C:/Users/Alberto/Documents/tsw_io/docs/mechanical/fusion-controller'
def run(_context:str):
 app=C.Application.get();d=F.Design.cast(app.activeProduct);root=d.rootComponent;ex=d.exportManager
 os.makedirs(ROOTDIR+'/raw-stl',exist_ok=True);rows=[]
 for o in root.allOccurrences:
  c=o.component
  if not re.match(r'^P\d\d ',c.name):continue
  if c.bRepBodies.count!=1 or not c.bRepBodies.item(0).isSolid:raise RuntimeError('Non-single solid '+c.name)
  safe=re.sub('[^A-Za-z0-9_-]+','-',c.name).strip('-')
  opt=ex.createSTLExportOptions(c.bRepBodies.item(0),ROOTDIR+'/raw-stl/'+safe+'.stl')
  opt.unitType=F.DistanceUnits.MillimeterDistanceUnits
  opt.meshRefinement=F.MeshRefinementSettings.MeshRefinementHigh
  if not ex.execute(opt):raise RuntimeError('STL export failed '+c.name)
  b=c.bRepBodies.item(0)
  rows.append({'name':c.name,'file':safe+'.stl','volume_cm3':b.volume,'bounds_mm':[[v*10 for v in b.boundingBox.minPoint.asArray()],[v*10 for v in b.boundingBox.maxPoint.asArray()]]})
 open(ROOTDIR+'/export-manifest.json','w').write(json.dumps(rows,indent=2))
 opt=ex.createFusionArchiveExportOptions(ROOTDIR+'/Fusion-Train-Controller.f3d')
 if not ex.execute(opt):raise RuntimeError('Native archive export failed')
 app.activeViewport.saveAsImageFile(ROOTDIR+'/fusion-overview.png',1600,1000)
 print(json.dumps({'exported_printables':len(rows),'native_archive':'Fusion-Train-Controller.f3d'}))

