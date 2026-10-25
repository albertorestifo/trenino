import pathlib,sys,json,zipfile,re,math,collections
ROOT=pathlib.Path(__file__).parent
sys.path.insert(0,str(ROOT/'.validation-libs'))
from PIL import Image,ImageDraw
rows=[]; panels=[]
for p in sorted((ROOT/'diagnostic-slices').glob('*.3mf')):
 z=zipfile.ZipFile(p);g=z.read('Metadata/plate_1.gcode').decode();settings=json.loads(z.read('Metadata/project_settings.config'))
 layers=collections.defaultdict(list);x=y=0.;height=0.;feature='';active=False
 for line in g.splitlines():
  if line.startswith('; Z_HEIGHT:'):height=float(line.split(':')[1]);active=True
  if line.startswith('; FEATURE:'):feature=line.split(':',1)[1].strip()
  if not active or not line.startswith(('G1 ','G0 ','G2 ','G3 ')):continue
  v={k:float(n) for k,n in re.findall(r'([XYEIJ])(-?[\d.]+)',line.split(';')[0])};nx=v.get('X',x);ny=v.get('Y',y)
  if v.get('E',0)>0 and feature!='Custom':
   if line.startswith(('G2 ','G3 ')):
    cx=x+v.get('I',0);cy=y+v.get('J',0);r=math.hypot(x-cx,y-cy);a=math.atan2(y-cy,x-cx);b=math.atan2(ny-cy,nx-cx);da=(b-a)%(2*math.pi)
    if line.startswith('G2 '):da-=2*math.pi
    count=max(2,int(abs(da)*r/.15));px=x;py=y
    for i in range(1,count+1):
     q=a+da*i/count;qx=cx+r*math.cos(q);qy=cy+r*math.sin(q);layers[height].append((px,py,qx,qy,feature));px=qx;py=qy
   elif nx!=x or ny!=y:layers[height].append((x,y,nx,ny,feature))
  x,y=nx,ny
 bridges=[(h,math.hypot(c-a,d-b)) for h,ss in layers.items() for a,b,c,d,f in ss if 'Bridge' in f]
 supports=sum('Support' in s[-1] for ss in layers.values() for s in ss)
 assert layers and supports==0,(p.name,'empty or supports')
 hs=sorted(layers);critical=max(bridges,key=lambda t:t[1])[0] if bridges else hs[len(hs)//2]
 rows.append({'file':p.name,'layers_with_extrusion':len(layers),'max_z':max(layers),'support_segments':supports,'max_bridge_segment_mm':max((b for h,b in bridges),default=0),'bridge_layers':sorted(set(h for h,b in bridges)),'enable_support':settings.get('enable_support'),'printer_ready':False})
 extra={'P01':[18,19,20],'P02':[18,19,20],'P05':[1,2,3],'P07':[8,10,12],'P09':[20,22,25],'P10':[20,22,25],'P11':[6,8,10],'P13':[10,12,14],'P18':[2.8,3,3.2],'P19':[3,5,7]}
 chosen=[hs[0],critical,hs[-1]]
 if '--critical' in sys.argv:
  if p.name[:3] not in extra:continue
  chosen=[min(hs,key=lambda z:abs(z-h)) for h in extra[p.name[:3]]]
 for h in chosen:
  ss=layers[h];im=Image.new('RGB',(420,330),'white');draw=ImageDraw.Draw(im)
  xx=[v for a,b,c,d,f in ss for v in [a,c]];yy=[v for a,b,c,d,f in ss for v in [b,d]]
  scale=min(380/max(max(xx)-min(xx),1),265/max(max(yy)-min(yy),1));cx=(min(xx)+max(xx))/2;cy=(min(yy)+max(yy))/2
  for a,b,c,d,f in ss:draw.line((210+(a-cx)*scale,185-(b-cy)*scale,210+(c-cx)*scale,185-(d-cy)*scale),fill='red' if 'Bridge' in f else '#246080',width=1)
  draw.text((8,5),p.stem[:43],fill='black');draw.text((8,23),f'Z {h:.2f} mm; bridge paths red',fill='black');panels.append(im)
out=ROOT/'layer-review';out.mkdir(exist_ok=True)
for n in range(0,len(panels),18):
 sheet=Image.new('RGB',(1260,1980),'#ddd')
 for i,im in enumerate(panels[n:n+18]):sheet.paste(im,((i%3)*420,(i//3)*330))
 sheet.save(out/f'{"critical" if "--critical" in sys.argv else "layers"}-{n//18+1}.png')
(ROOT/'layer-check.json').write_text(json.dumps(rows,indent=2))
print(json.dumps({'parts':len(rows),'support_segments':sum(r['support_segments'] for r in rows),'max_bridge_segments':[(r['file'],round(r['max_bridge_segment_mm'],2)) for r in rows]}))
