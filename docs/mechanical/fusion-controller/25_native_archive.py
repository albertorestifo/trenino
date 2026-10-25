import adsk.core as C,adsk.fusion as F
def run(_context:str):
 d=F.Design.cast(C.Application.get().activeProduct)
 if not d.exportManager.execute(d.exportManager.createFusionArchiveExportOptions('C:/Users/Alberto/Documents/tsw_io/docs/mechanical/fusion-controller/Fusion-Train-Controller.f3d')):raise RuntimeError('Native export failed')
 print('Final native archive exported with clean feature history')
