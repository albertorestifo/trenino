import adsk.core as C, adsk.fusion as F
def run(_context:str):
 for cls,methods in [(F.ExportManager,['createSTLExportOptions','createFusionArchiveExportOptions']),(F.STLExportOptions,['unitType']),(F.AsBuiltJoints,['createInput']),(F.AsBuiltJointInput,['setAsRevoluteJointMotion']),(F.JointGeometry,['createByNonPlanarFace']),(F.RigidGroups,['add'])]:
  for name in methods:print(cls.__name__,name,getattr(cls,name).__doc__)
