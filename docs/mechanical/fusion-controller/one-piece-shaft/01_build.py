exec(open('C:/Users/Alberto/Documents/tsw_io/docs/mechanical/fusion-controller/direct-v6-build-fixes/helpers.py').read())
OUT=ROOTDIR+'/one-piece-shaft'
def run(_context: str):
 app=C.Application.get();d=F.Design.cast(app.activeProduct);r=d.rootComponent
 assert app.activeDocument.dataFile.id.endswith('2iFF2PJAQnO13x73oN2c-w')
 assert not app.activeDocument.isModified,'Unexpected unsaved edits'
 assert d.exportManager.execute(d.exportManager.createFusionArchiveExportOptions(OUT+'/Before-One-Piece-v7.f3d'))
 for j in list(r.asBuiltJoints):j.deleteMe()
 for g in list(r.rigidGroups):g.deleteMe()
 for o in list(r.occurrences):
  if o.component.name.startswith(('P05 ','P28 ','HARDWARE Shaft joining')):o.deleteMe()
 c=comp(r,'P05 One-piece shaft with continuous print flat')
 b=circle(c,'x',-37.35,0,65,6,74.7,name='Continuous main journal shaft');b.name=c.name
 circle(c,'x',-23.8,0,65,8,47.6,JOIN,'Central load-bearing shaft')
 box(c,(-23.9,6.5,56),(23.9,9,74),CUT,'Preserved upper D drive flat')
 circle(c,'x',37.35,0,65,10,3,JOIN,'Integral retaining shoulder')
 box(c,(37.25,6.5,54),(40.45,11,76),CUT,'Preserved shoulder upper flat')
 box(c,(40.35,-8,63),(43.35,6.5,67),JOIN,'Integral Oldham input tongue')
 box(c,(-37.5,-10.2,54),(43.5,-4.2,76),CUT,'Continuous underside print bed flat')
 circle(c,'x',-37.45,0,65,1.7,6.8,CUT,'End cap M3 passage')
 q=1.7/math.sqrt(2)
 poly(c,'x',-37.45,[(q,65-q),(q,65+q),(1.7*math.sqrt(2),65)],6.8,CUT,'Support-free screw-passage crown')
 hexhole(c,'x',-34,0,65,5.8,2.6,'Captured cap nut pocket')
 box(c,(-34,-4.3,62.1),(-31.4,0,67.9),CUT,'Nut installation from bed flat')
 o=next(o for o in r.occurrences if o.component==c)
 m=C.Matrix3D.create();m.translation=C.Vector3D.create(0,0,-3.5);o.transform2=m
 if d.snapshots.hasPendingSnapshot:d.snapshots.add()
 assert c.bRepBodies.count==1 and c.bRepBodies.item(0).isSolid
 finishstage(d,'01-one-piece')

