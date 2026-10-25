exec(open('C:/Users/Alberto/Documents/tsw_io/docs/mechanical/fusion-controller/direct-v6-build-fixes/helpers.py').read())
def run(_context: str):
 d=F.Design.cast(C.Application.get().activeProduct);root=d.rootComponent
 for o in root.occurrences:o.isGrounded=False
 expected={}
 for o in root.occurrences:
  n=o.component.name
  dz=0 if n.startswith(('REFERENCE - fixed','HARDWARE Rail M5')) else -3.5
  dx=-.32 if n.startswith('P16 ') else -.2 if n.startswith('HARDWARE Compact carriage') else 0
  m=C.Matrix3D.create();m.translation=C.Vector3D.create(dx,0,dz);o.transform2=m;expected[n]=[dx,0,dz]
 assert d.snapshots.hasPendingSnapshot
 d.snapshots.add().name='Capture measured sensor and recessed assembly positions'
 for o in root.occurrences:o.isGrounded=True
 for o in root.occurrences:assert max(abs(a-b) for a,b in zip(o.transform2.translation.asArray(),expected[o.component.name]))<1e-7,o.component.name
 finishstage(d,'04b-captured-positions')
