import adsk.core as C, adsk.fusion as F
ROOTDIR='C:/Users/Alberto/Documents/tsw_io/docs/mechanical/fusion-controller'
def run(_context:str):
 app=C.Application.get();d=F.Design.cast(app.activeProduct)
 frame=next(o for o in d.rootComponent.allOccurrences if o.component.name.startswith('REFERENCE - fixed'))
 frame.isLightBulbOn=False;app.activeViewport.fit();app.activeViewport.refresh()
 app.activeViewport.saveAsImageFile(ROOTDIR+'/fusion-closeup.png',1600,1200)
 frame.isLightBulbOn=True;app.activeViewport.fit();app.activeViewport.refresh()
 app.activeViewport.saveAsImageFile(ROOTDIR+'/fusion-overview.png',1600,1000)
 print('Saved assembly and close-up viewport images')
