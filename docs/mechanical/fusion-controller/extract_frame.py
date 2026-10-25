import pathlib,zipfile,xml.etree.ElementTree as E
p=pathlib.Path('docs/mechanical/fusion-controller')
n='http://schemas.microsoft.com/3dmanufacturing/core/2015/02'; ns={'m':n}
z=zipfile.ZipFile('tmp/cam_detent/original-full-device.3mf'); r=E.fromstring(z.read('3D/3dmodel.model'))
res=r.find('m:resources',ns)
for o in list(res):
 if o.tag.endswith('object') and o.get('id') not in [str(i) for i in range(12,24)]: res.remove(o)
for o in res.findall('m:object',ns):
 for v in o.findall('m:mesh/m:vertices/m:vertex',ns): v.set('x',str(float(v.get('x'))-.310))
b=r.find('m:build',ns); b.clear()
for i in range(12,24): E.SubElement(b,'{'+n+'}item',{'objectid':str(i)})
with zipfile.ZipFile(p/'fixed-frame-reference.3mf','w',zipfile.ZIP_DEFLATED) as out:
 for f in z.namelist():
  if f=='3D/3dmodel.model':out.writestr(f,E.tostring(r))
  elif f in ['[Content_Types].xml','_rels/.rels']:out.writestr(f,z.read(f))
print('Fixed frame 640 x 190 x 110 mm reference extracted')
