import math, pathlib, struct, xml.etree.ElementTree as ET, zipfile
root=pathlib.Path(__file__).parent
src=root/'Cam-Detent-FDM-P2S-layout.3mf'
ns={'m':'http://schemas.microsoft.com/3dmanufacturing/core/2015/02'}
with zipfile.ZipFile(src) as archive:
    model=ET.fromstring(archive.read('3D/3dmodel.model'))
assert model.attrib['unit']=='meter'
objects=model.findall('m:resources/m:object',ns)
obj=next(o for o in objects if 'Bracket' in o.attrib['name'])
item=next(i for i in model.findall('m:build/m:item',ns) if i.attrib['objectid']==obj.attrib['id'])
assert 'transform' not in item.attrib
verts=[tuple(1000*float(v.attrib[a]) for a in ('x','y','z')) for v in obj.findall('m:mesh/m:vertices/m:vertex',ns)]
tris=[tuple(int(t.attrib[a]) for a in ('v1','v2','v3')) for t in obj.findall('m:mesh/m:triangles/m:triangle',ns)]
dst=next((root/'fdm-stl').glob('*05*Bracket*.stl'))
with dst.open('wb') as out:
    out.write(b'Final Onshape bracket; 3MF metres converted to STL millimetres'.ljust(80,b' '))
    out.write(struct.pack('<I',len(tris)))
    for indices in tris:
        a,b,c=[verts[i] for i in indices]
        u=[b[i]-a[i] for i in range(3)]; v=[c[i]-a[i] for i in range(3)]
        n=[u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0]]
        length=math.sqrt(sum(x*x for x in n)); assert length>0
        out.write(struct.pack('<12fH',*[x/length for x in n],*a,*b,*c,0))
print(dst)
print('triangles',len(tris))
