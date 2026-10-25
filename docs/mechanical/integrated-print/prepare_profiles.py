"""Prepare isolated P2S PLA CLI presets for the integrated object checks."""
import json
import pathlib

ROOT = pathlib.Path(__file__).parent
base = json.loads((ROOT.parent / "slicer-check/profiles/process-fork.json").read_text(encoding="utf-8"))
for name, support in (("process-integrated.json", "0"), ("process-integrated-supports.json", "1")):
    profile = dict(base)
    profile["name"] = "0.20mm Standard @BBL P2S — integrated CLI check"
    profile["print_settings_id"] = profile["name"]
    profile["enable_support"] = support
    profile["support_type"] = "tree(auto)"
    profile["support_on_build_plate_only"] = "0"
    profile["wall_loops"] = "5"
    profile["top_shell_layers"] = "5"
    profile["bottom_shell_layers"] = "5"
    profile["sparse_infill_density"] = "35%"
    profile["sparse_infill_pattern"] = "gyroid"
    profile["layer_height"] = "0.2"
    (ROOT / name).write_text(json.dumps(profile, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
