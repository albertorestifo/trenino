exec(open('C:/Users/Alberto/Documents/tsw_io/docs/mechanical/fusion-controller/common.py').read())
def run(_context:str):
 root=F.Design.cast(C.Application.get().activeProduct).rootComponent
 c=comp(root,'P18 Tight fit alternate disc - 4.1 mm slots')
 b=circle(c,'x',52,0,65,12,8,name='Optional closer running fit');b.name=c.name
 box(c,(51.9,-13,62.95),(54.5,13,67.05),CUT,'Input 4.1 slot')
 box(c,(57.5,-2.05,52),(60.1,2.05,78),CUT,'Output 4.1 slot')
 for s in c.sketches:s.isLightBulbOn=False
 next(o for o in root.allOccurrences if o.component==c).isLightBulbOn=False
 print('Optional 4.1 mm coupling disc added; fit and free-slide test required')
