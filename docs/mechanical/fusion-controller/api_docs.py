import adsk.core as C, adsk.fusion as F
def run(_context:str):
 print(F.TemporaryBRepManager.copy.__doc__)
 print(F.TemporaryBRepManager.transform.__doc__)
 print(F.TemporaryBRepManager.booleanOperation.__doc__)
 print(F.MeasureManager.__doc__ if hasattr(F,'MeasureManager') else C.MeasureManager.measureMinimumDistance.__doc__)
