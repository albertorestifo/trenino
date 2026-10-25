import pathlib,json,struct,zipfile,xml.etree.ElementTree as E,hashlib
R=pathlib.Path(__file__).parent
NS='http://schemas.microsoft.com/3dmanufacturing/core/2015/02';E.register_namespace('',NS)
def tag(n):return '{'+NS+'}'+n
rows=json.loads((R/'mesh-check.json').read_text());main=[r for r in rows if not r['file'].startswith(('P08-Cam-3','P08-Cam-5'))]
plates=[]
for r in sorted(main,key=lambda v:v['size_mm'][1],reverse=True):
 w,h,z=r['size_mm'];done=False
 for plate in plates:
  for shelf in plate['shelves']:
   if h<=shelf['height'] and shelf['x']+w<=246:
    plate['parts'].append((r,shelf['x'],shelf['y']));shelf['x']+=w+8;done=True;break
  if done:break
  y=sum(s['height']+8 for s in plate['shelves'])+10
  if y+h<=246:
   plate['shelves'].append(dict(x=10+w+8,y=y,height=h));plate['parts'].append((r,10,y));done=True;break
 if not done:plates.append(dict(shelves=[dict(x=10+w+8,y=10,height=h)],parts=[(r,10,10)]))
out=R/'plates';out.mkdir(exist_ok=True);manifest=[]
for idx,plate in enumerate(plates,1):
 model=E.Element(tag('model'),{'unit':'millimeter','xml:lang':'en-US'});res=E.SubElement(model,tag('resources'));build=E.SubElement(model,tag('build'));files=[]
 for oid,(r,x,y) in enumerate(plate['parts'],1):
  x+=0.123 if idx==3 else 0; y+=0.123 if idx==3 else 0
  data=(R/'stl'/r['file']).read_bytes();n=struct.unpack_from('<I',data,80)[0];coords=[];faces=[];lookup={}
  for i in range(n):
   rec=struct.unpack_from('<12fH',data,84+50*i);face=[]
   for j in [3,6,9]:
    p=tuple(round(v,8) for v in rec[j:j+3])
    if p not in lookup:lookup[p]=len(coords);coords.append(p)
    face.append(lookup[p])
   faces.append(face)
  mn=[min(v[k] for v in coords) for k in range(3)]
  obj=E.SubElement(res,tag('object'),{'id':str(oid),'type':'model','name':r['file'][:-4]});mesh=E.SubElement(obj,tag('mesh'));vv=E.SubElement(mesh,tag('vertices'));tt=E.SubElement(mesh,tag('triangles'))
  for a,b,c in coords:E.SubElement(vv,tag('vertex'),dict(x=f'{a-mn[0]+x:.8f}',y=f'{b-mn[1]+y:.8f}',z=f'{c-mn[2]:.8f}'))
  for a,b,c in faces:E.SubElement(tt,tag('triangle'),dict(v1=str(a),v2=str(b),v3=str(c)))
  E.SubElement(build,tag('item'),{'objectid':str(oid)});files.append(r['file'])
 path=out/f'Plate-{idx:02d}.3mf'
 with zipfile.ZipFile(path,'w',zipfile.ZIP_DEFLATED) as z:
  z.writestr('[Content_Types].xml','<?xml version="1.0"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="model" ContentType="application/vnd.ms-package.3dmanufacturing-3dmodel+xml"/></Types>')
  z.writestr('_rels/.rels','<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Target="/3D/3dmodel.model" Id="rel0" Type="http://schemas.microsoft.com/3dmanufacturing/2013/01/3dmodel"/></Relationships>')
  z.writestr('3D/3dmodel.model',E.tostring(model,encoding='utf-8',xml_declaration=True))
 with zipfile.ZipFile(path) as z:assert z.testzip() is None
 manifest.append(dict(plate=path.name,parts=files,sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
(R/'plate-manifest.json').write_text(json.dumps(manifest,indent=2));print(json.dumps(manifest,indent=2))


