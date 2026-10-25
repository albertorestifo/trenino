import pathlib,struct,json,math
ROOT=pathlib.Path(__file__).parent
out=ROOT/'stl';out.mkdir(exist_ok=True)
manifest=json.loads((ROOT/'export-manifest.json').read_text())
rows=[]
for r in manifest:
 name=r['file'];num=int(name[1:3]);raw=(ROOT/'raw-stl'/name).read_bytes();n=struct.unpack_from('<I',raw,80)[0]
 assert len(raw)==84+50*n,(name,'not binary')
 if num in [4,7,16,19,20]: rot=lambda v:(v[1],-v[2],-v[0]);orientation='X maximum face down'
 elif num==5:rot=lambda v:(v[0],v[2],-v[1]);orientation='Y maximum face down'
 elif num in [13,14]:rot=lambda v:(v[0],-v[1],-v[2]);orientation='Z maximum face down'
 elif num in [9,10,11,15]:rot=lambda v:v;orientation='Z minimum face down'
 else:rot=lambda v:(v[1],v[2],v[0]);orientation='X minimum face down'
 records=[struct.unpack_from('<12fH',raw,84+50*i) for i in range(n)]
 verts=[rot(v[j:j+3]) for v in records for j in [3,6,9]]
 mn=[min(v[i] for v in verts) for i in range(3)];mx=[max(v[i] for v in verts) for i in range(3)];size=[b-a for a,b in zip(mn,mx)]
 native=sorted(b-a for a,b in zip(*r['bounds_mm']))
 assert max(abs(a-b) for a,b in zip(sorted(size),native))<.05,(name,'wrong units',size,native)
 offset=[128-(mn[0]+mx[0])/2,128-(mn[1]+mx[1])/2,-mn[2]]
 with (out/name).open('wb') as f:
  f.write(('Fusion controller mm; '+orientation).encode()[:80].ljust(80,b' '));f.write(struct.pack('<I',n))
  for v in records:
   xyz=[]
   for j in [3,6,9]:xyz.extend(a+b for a,b in zip(rot(v[j:j+3]),offset))
   f.write(struct.pack('<12fH',*rot(v[:3]),*xyz,0))
 rows.append(dict(file=name,orientation=orientation,size_mm=size,supports=num in [1,2,5,7,11,13]))
(ROOT/'print-orientation.json').write_text(json.dumps(rows,indent=2))
print('Oriented',len(rows),'parts; max length',max(max(r['size_mm']) for r in rows))
