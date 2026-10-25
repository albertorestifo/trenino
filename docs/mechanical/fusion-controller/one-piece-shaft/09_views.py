import adsk.core as C,adsk.fusion as F
OUT='C:/Users/Alberto/Documents/tsw_io/docs/mechanical/fusion-controller/one-piece-shaft'
def run(_context:str):
 a=C.Application.get();r=F.Design.cast(a.activeProduct).rootComponent;v=a.activeViewport
 for o in r.occurrences:
  if o.component.name.startswith('P08'):o.isLightBulbOn=o.component.name.startswith('P08 Cam 9')
  for s in o.component.sketches:s.isLightBulbOn=False
 frame=next(o for o in r.occurrences if o.component.name.startswith('REFERENCE - fixed'))
 frame.isLightBulbOn=True
 cam=v.camera;cam.isSmoothTransition=False;cam.cameraType=C.CameraTypes.OrthographicCameraType
 cam.target=C.Point3D.create(0,0,3);cam.eye=C.Point3D.create(35,-45,28);cam.upVector=C.Vector3D.create(0,0,1);cam.isFitView=True;v.camera=cam;v.refresh()
 assert v.saveAsImageFile(OUT+'/rail-mounted-layout.png',1600,1000)
 frame.isLightBulbOn=False;v.fit();v.refresh()
 assert v.saveAsImageFile(OUT+'/mechanism-detail.png',1400,1200)
 cam=v.camera;cam.eye=C.Point3D.create(-35,-45,28);cam.isFitView=True;v.camera=cam;v.refresh()
 assert v.saveAsImageFile(OUT+'/cam-service-side.png',1400,1200)
 frame.isLightBulbOn=True;v.fit();v.refresh()
 print('Saved native Fusion assembly images')
