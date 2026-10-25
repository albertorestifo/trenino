import pathlib,struct,json,math,hashlib,collections
ROOT=pathlib.Path(__file__).parent
out=ROOT/'stl';out.mkdir(exist_ok=True)
rows=[]
for r in json.loads((ROOT/'export-manifest.json').read_text()):
 name=r['file'];num=int(name[1:3]);raw=(ROOT/'raw-stl'/name).read_bytes();n=struct.unpack_from('<I',raw,80)[0]
 assert len(raw)==84+50*n,(name,'not binary')
 if num in [4,7,16,19]:rot=lambda v:(v[1],-v[2],-v[0]);orientation='X maximum face down'
 elif num in [5,25,26,28]:
  lower='lower' in name.lower()
  rot=(lambda v:(v[0],v[2],-v[1])) if lower else (lambda v:(v[0],-v[2],v[1]))
  orientation='Y maximum split face down' if lower else 'Y minimum split face down'
 elif num in [13,14]:rot=lambda v:(v[0],-v[1],-v[2]);orientation='Z maximum face down'
 elif num in [9,10,11,15,27]:rot=lambda v:v;orientation='Z minimum face down'
 else:rot=lambda v:(v[1],v[2],v[0]);orientation='X minimum face down'
 records=[struct.unpack_from('<12fH',raw,84+50*i) for i in range(n)]
 verts=[rot(v[j:j+3]) for v in records for j in [3,6,9]]
 mn=[min(v[i] for v in verts) for i in range(3)];mx=[max(v[i] for v in verts) for i in range(3)];size=[b-a for a,b in zip(mn,mx)]
 native=sorted(b-a for a,b in zip(*r['bounds_mm']))
 assert max(abs(a-b) for a,b in zip(sorted(size),native))<.05,(name,'scale mismatch')
 assert all(v<250 for v in size),(name,'build volume')
 offset=[128-(mn[0]+mx[0])/2,128-(mn[1]+mx[1])/2,-mn[2]]
 edges=collections.Counter();direct=collections.Counter();bedarea=0;volume=0
 def key(v):return tuple(round(x,4) for x in v)
 with (out/name).open('wb') as f:
  f.write(('mm; '+orientation).encode()[:80].ljust(80,b' '));f.write(struct.pack('<I',n))
  for v in records:
   triangle=[tuple(a+b for a,b in zip(rot(v[j:j+3]),offset)) for j in [3,6,9]]
   f.write(struct.pack('<12fH',*rot(v[:3]),*[x for p in triangle for x in p],0))
   a,b,c=triangle
   volume+=(a[0]*(b[1]*c[2]-b[2]*c[1])+a[1]*(b[2]*c[0]-b[0]*c[2])+a[2]*(b[0]*c[1]-b[1]*c[0]))/6
   if max(p[2] for p in triangle)<.001:bedarea+=abs((b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0]))/2
   keys=[key(p) for p in triangle]
   for aa,bb in zip(keys,keys[1:]+keys[:1]):
    if aa==bb:continue
    edges[tuple(sorted((aa,bb)))]+=1;direct[(aa,bb)]+=1
 unpaired=sum(v!=2 for v in edges.values());badwinding=sum(direct[(a,b)]!=direct[(b,a)] for a,b in edges)
 rows.append(dict(file=name,orientation=orientation,size_mm=size,bed_area_mm2=bedarea,volume_mm3=volume,native_volume_mm3=r['volume_mm3'],unpaired_edges=unpaired,inconsistent_edges=badwinding,triangles=n,sha256=hashlib.sha256((out/name).read_bytes()).hexdigest(),support_strategy='No generated supports; inspect local bridges with default profile'))
(ROOT/'mesh-check.json').write_text(json.dumps(rows,indent=2))
assert all(r['unpaired_edges']==0 and r['inconsistent_edges']==0 and r['bed_area_mm2']>.1 and r['volume_mm3']>0 for r in rows),[(r['file'],r['unpaired_edges'],r['inconsistent_edges'],r['bed_area_mm2']) for r in rows if r['unpaired_edges'] or r['inconsistent_edges'] or r['bed_area_mm2']<=.1]
print(json.dumps({'files':len(rows),'all_closed_consistent_and_on_bed':True,'min_bed_area_mm2':min(r['bed_area_mm2'] for r in rows)}))

# Same split bed face, rotated in-plane to avoid a slicer numerical clipping error.
p=out/'P05-Shaft-lower-half.stl';data=p.read_bytes();cc=math.sqrt(.5)
def bedrot(v,point=False):
 x,y,z=v
 if point:x-=128;y-=128
 return (cc*(x-y)+(128 if point else 0),cc*(x+y)+(128 if point else 0),z)
n=struct.unpack_from('<I',data,80)[0];updated=bytearray(data[:84]);verts=[]
for i in range(n):
 q=struct.unpack_from('<12fH',data,84+50*i);vv=[bedrot(q[j:j+3],True) for j in [3,6,9]];verts+=vv
 updated+=struct.pack('<12fH',*bedrot(q[:3]),*[v for pt in vv for v in pt],0)
p.write_bytes(updated)
for row in rows:
 if row['file']==p.name:
  row['orientation']+='; 45 degree rotation in bed plane'
  row['size_mm']=[max(v[k] for v in verts)-min(v[k] for v in verts) for k in range(3)]
  row['sha256']=hashlib.sha256(updated).hexdigest()
(ROOT/'mesh-check.json').write_text(json.dumps(rows,indent=2))
