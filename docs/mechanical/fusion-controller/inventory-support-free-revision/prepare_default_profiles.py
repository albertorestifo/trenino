"""Resolve installed vendor defaults; no process/filament overrides."""
import json,pathlib,hashlib
ROOT=pathlib.Path(__file__).parent
BASE=pathlib.Path(r'C:\Users\Alberto\AppData\Roaming\BambuStudio\system\BBL')
out=ROOT/'default-profiles';out.mkdir(exist_ok=True)
sources=[]
def flatten(kind,name,stack=()):
 assert name not in stack,(name,stack)
 p,data=indexes[kind][name];result={}
 parent=data.get('inherits')
 if parent:result.update(flatten(kind,parent,stack+(name,)))
 for inc in data.get('include',[]):result.update(flatten(kind,inc,stack+(name,)))
 result.update(data);sources.append({'path':str(p),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
 return result
indexes={}
for kind in ['machine','process','filament']:
 indexes[kind]={}
 for p in (BASE/kind).rglob('*.json'):
  data=json.loads(p.read_text(encoding='utf-8-sig'))
  if data.get('name'):indexes[kind][data['name']]=(p,data)
names={'machine':'Bambu Lab P2S 0.4 nozzle','process':'0.20mm Standard @BBL P2S','filament':'Bambu PLA Basic @BBL P2S'}
configs={}
for kind,name in names.items():
 config=flatten(kind,name);config.pop('include',None);config['from']='User'
 # These identify the selected installed printer/extruder; they do not tune the process.
 if kind=='machine':
  config['inherits']=name;config['printer_settings_id']=name
  config['nozzle_volume_type']=['Standard']
  config['printer_extruder_id']=['1','1'];config['printer_extruder_variant']=['Direct Drive Standard','Direct Drive High Flow']
 elif kind=='process':config['print_settings_id']=name
 else:config['filament_settings_id']=[name]
 (out/(kind+'.json')).write_text(json.dumps(config,indent=2),encoding='utf-8');configs[kind]=config
assert configs['process'].get('enable_support') in ['0',0,False],configs['process'].get('enable_support')
report={'profiles':names,'process_overrides':{},'filament_overrides':{},'hardware_selection':'0.4 mm standard flow, Supertack Plate','process_values':{k:configs['process'].get(k) for k in ['enable_support','layer_height','wall_loops','sparse_infill_density','brim_type','brim_width','bridge_speed']},'source_files':sources}
(out/'provenance.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report['process_values']))
