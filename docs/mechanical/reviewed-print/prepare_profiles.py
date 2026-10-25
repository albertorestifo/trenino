"""Create isolated Bambu P2S/PLA process profiles for reviewed object checks."""
import json, pathlib, shutil
ROOT=pathlib.Path(__file__).parent
SOURCE=ROOT.parent/"slicer-check"/"profiles"
OUT=ROOT/"profiles"
OUT.mkdir(parents=True,exist_ok=True)
for name in ("machine-p2s-04-full.json","filament-pla-basic-p2s-full.json"):
    p=SOURCE/name
    if not p.is_file(): raise FileNotFoundError(p)
    shutil.copy2(p,OUT/name)
base_path=SOURCE/"process-fork.json"
if not base_path.is_file(): raise FileNotFoundError(base_path)
base=json.loads(base_path.read_text(encoding="utf-8"))
for filename,support in (("process-reviewed.json","0"),("process-reviewed-supports.json","1")):
    profile=dict(base)
    profile.update(name="0.20mm Standard @BBL P2S — reviewed CLI check",
                   print_settings_id="0.20mm Standard @BBL P2S — reviewed CLI check",
                   layer_height="0.2",wall_loops="5",top_shell_layers="5",bottom_shell_layers="5",
                   sparse_infill_density="35%",sparse_infill_pattern="gyroid",
                   enable_support=support,support_type="tree(auto)",support_on_build_plate_only="0")
    (OUT/filename).write_text(json.dumps(profile,indent=2,ensure_ascii=False)+"\n",encoding="utf-8")
print(f"Prepared two process profiles and copied machine/filament profiles to {OUT}")
