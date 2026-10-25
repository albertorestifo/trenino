import zipfile,xml.etree.ElementTree as E
ns={'m':'http://schemas.microsoft.com/3dmanufacturing/core/2015/02'}
r=E.fromstring(zipfile.ZipFile('docs/mechanical/fusion-controller/fixed-frame-reference.3mf').read('3D/3dmodel.model'))
for o in r.findall('m:resources/m:object',ns):
 v=[tuple(float(q.get(k))*1000 for k in ['x','y','z']) for q in o.findall('m:mesh/m:vertices/m:vertex',ns)]
 if not(min(q[0] for q in v)<30<max(q[0] for q in v) and min(q[1] for q in v)>70 and min(q[2] for q in v)>30):continue
 hits=[]
 for t in o.findall('m:mesh/m:triangles/m:triangle',ns):
  a,b,c=[v[int(t.get(k))] for k in ['v1','v2','v3']];x,z=30,45.001
  den=(b[2]-c[2])*(a[0]-c[0])+(c[0]-b[0])*(a[2]-c[2])
  if abs(den)<1e-9:continue
  u=((b[2]-c[2])*(x-c[0])+(c[0]-b[0])*(z-c[2]))/den;w=((c[2]-a[2])*(x-c[0])+(a[0]-c[0])*(z-c[2]))/den
  if min(u,w,1-u-w)>=-1e-6:hits.append(u*a[1]+w*b[1]+(1-u-w)*c[1])
 print('Upper rail axial slot center surface crossings Y mm:',sorted(set(round(q,4) for q in hits)))
