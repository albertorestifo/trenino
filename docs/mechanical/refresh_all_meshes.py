import math, pathlib, struct, xml.etree.ElementTree as ET, zipfile
root=pathlib.Path(__file__).parent
ns={'m':'http://schemas.microsoft.com/3dmanufacturing/core/2015/02'}
with zipfile.ZipFile(root/'Cam-Detent-FDM-P2S-layout.3mf') as archive:
    model=ET.fromstring(archive.read('3D/3dmodel.model'))
assert model.attrib['unit']=='meter'
objects=model.findall('m:resources/m:object',ns)
assert len(objects)==5
for obj in objects:
    key=next(k for k in ['Roller','Hub','Cam','Fork','Bracket'] if k in obj.attrib['name'])
    item=next(i for i in model.findall('m:build/m:item',ns) if i.attrib['objectid']==obj.attrib['id'])
    assert 'transform' not in item.attrib
    verts=[tuple(1000*float(v.attrib[a]) for a in ('x','y','z')) for v in obj.findall('m:mesh/m:vertices/m:vertex',ns)]
    tris=[tuple(int(t.attrib[a]) for a in ('v1','v2','v3')) for t in obj.findall('m:mesh/m:triangles/m:triangle',ns)]
    dst=next(p for p in (root/'fdm-stl').glob('*.stl') if (' — '+key+' — ') in p.name)
    with dst.open('wb') as out:
        out.write(b'Onshape CNC Kitchen M3 revision; source metres converted to millimetres'.ljust(80,b' '))
        out.write(struct.pack('<I',len(tris)))
        for indices in tris:
            a,b,c=[verts[i] for i in indices]
            u=[b[i]-a[i] for i in range(3)]; v=[c[i]-a[i] for i in range(3)]
            n=[u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0]]
            length=math.sqrt(sum(x*x for x in n)); assert length>0
            out.write(struct.pack('<12fH',*[x/length for x in n],*a,*b,*c,0))
    print(key, len(tris))
