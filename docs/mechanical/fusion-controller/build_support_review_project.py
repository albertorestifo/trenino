"""Build a new editable Bambu project; derive settings from the user's previously reviewed project."""
from pathlib import Path
import zipfile,json,struct,xml.etree.ElementTree as E
R=Path(__file__).parent;NS='http://schemas.microsoft.com/3dmanufacturing/core/2015/02'
E.register_namespace('',NS)
def el(tag,**attrs):return E.Element('{'+NS+'}'+tag,attrs)
def child(parent,tag,**attrs):v=el(tag,**attrs);parent.append(v);return v
with zipfile.ZipFile(R/'Changed-Parts-P2S-PLA.3mf') as z:settings=json.loads(z.read('Metadata/project_settings.config'))
settings.update(enable_support='0',brim_type='outer_only',brim_width='5',brim_object_gap='0.1',bridge_speed='25')
model=el('model',unit='millimeter');child(model,'metadata',name='Application').text='BambuStudio-02.04.00.70'
child(model,'metadata',name='BambuStudio:3mfVersion').text='1'
resources=child(model,'resources');build=child(model,'build');config=E.Element('config')
files=[p for p in sorted((R/'stl').glob('*.stl')) if int(p.name[1:3]) in [9,10,17,18,19,20]]
positions=[(80,105),(120,105),(165,105),(80,155),(120,155),(160,150),(195,150)]
assert len(files)==7
for idx,(p,(cx,cy)) in enumerate(zip(files,positions),1):
 raw=p.read_bytes();n=struct.unpack_from('<I',raw,80)[0];verts=[];ids={};tris=[]
 for k in range(n):
  r=struct.unpack_from('<12fH',raw,84+50*k);tri=[]
  for j in [3,6,9]:
   v=tuple(round(x,5) for x in r[j:j+3])
   if v not in ids:ids[v]=len(verts);verts.append(v)
   tri.append(ids[v])
  tris.append(tri)
 obj=child(resources,'object',id=str(idx),type='model',name=p.stem);mesh=child(obj,'mesh');vs=child(mesh,'vertices');ts=child(mesh,'triangles')
 for x,y,z in verts:child(vs,'vertex',x=str(x-128),y=str(y-128),z=str(z))
 for a,b,c in tris:child(ts,'triangle',v1=str(a),v2=str(b),v3=str(c))
 child(build,'item',objectid=str(idx),transform=f'1 0 0 0 1 0 0 0 1 {cx} {cy} 0',printable='1')
 o=E.SubElement(config,'object',id=str(idx));E.SubElement(o,'metadata',key='name',value=p.name);E.SubElement(o,'metadata',key='extruder',value='1')
 part=E.SubElement(o,'part',id=str(idx),subtype='normal_part');E.SubElement(part,'metadata',key='name',value=p.name)
plate=E.SubElement(config,'plate');E.SubElement(plate,'metadata',key='plater_id',value='1')
for idx in range(1,8):
 i=E.SubElement(plate,'model_instance');E.SubElement(i,'metadata',key='object_id',value=str(idx));E.SubElement(i,'metadata',key='instance_id',value='0');E.SubElement(i,'metadata',key='identify_id',value=str(100+idx))
out=R/'support-revision'/'Support-Reduced-P2S-PLA.3mf'
with zipfile.ZipFile(out,'w',zipfile.ZIP_DEFLATED) as z:
 z.writestr('[Content_Types].xml','<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="model" ContentType="application/vnd.ms-package.3dmanufacturing-3dmodel+xml"/><Default Extension="config" ContentType="text/xml"/></Types>')
 z.writestr('_rels/.rels','<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Target="/3D/3dmodel.model" Id="rel0" Type="http://schemas.microsoft.com/3dmanufacturing/2013/01/3dmodel"/></Relationships>')
 z.writestr('3D/3dmodel.model',E.tostring(model,encoding='utf-8',xml_declaration=True))
 z.writestr('Metadata/model_settings.config',E.tostring(config,encoding='utf-8',xml_declaration=True))
 z.writestr('Metadata/project_settings.config',json.dumps(settings,indent=2))
print(out)
