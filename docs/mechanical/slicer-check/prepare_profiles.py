"""Flatten the installed Bambu P2S presets for the documented CLI workflow."""

from __future__ import annotations

import copy
import json
from pathlib import Path


APP_PROFILES = Path(r"C:\Program Files\Bambu Studio\resources\profiles\BBL")
OUT = Path(__file__).parent / "profiles"
VARIANTS = ["Direct Drive Standard", "Direct Drive High Flow"]


def read_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8-sig"))


def build_index(kind: str) -> dict[str, tuple[Path, dict]]:
    result = {}
    for path in (APP_PROFILES / kind).glob("*.json"):
        data = read_json(path)
        if "name" in data:
            result[data["name"]] = (path, data)
    return result


def merge_dict(parent: dict, child: dict) -> dict:
    result = copy.deepcopy(parent)
    for key, value in child.items():
        if isinstance(value, dict) and isinstance(result.get(key), dict):
            result[key] = merge_dict(result[key], value)
        else:
            result[key] = copy.deepcopy(value)
    return result


def flatten(kind: str, leaf_name: str, indexes: dict[str, dict]) -> tuple[dict, str]:
    index = indexes[kind]
    chain = []
    current = leaf_name
    while current:
        if current not in index:
            raise KeyError(f"Missing {kind} preset in inheritance chain: {current}")
        path, profile = index[current]
        chain.append((path, profile))
        current = profile.get("inherits", "")
    merged = {}
    for _, profile in reversed(chain):
        merged = merge_dict(merged, profile)
    parent_name = chain[0][1].get("inherits", "")
    merged["from"] = "User"
    # Keep CLI's system-preset identity link while carrying all resolved keys.
    merged["inherits"] = leaf_name if kind == "machine" else parent_name
    return merged, parent_name


def save(path: Path, data: dict) -> None:
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    indexes = {kind: build_index(kind) for kind in ("machine", "process", "filament")}
    machine_name = "Bambu Lab P2S 0.4 nozzle"
    process_name = "0.20mm Standard @BBL P2S"
    filament_name = "Bambu PLA Basic @BBL P2S"

    machine, _ = flatten("machine", machine_name, indexes)
    machine["printer_settings_id"] = machine_name
    machine["printer_extruder_id"] = ["1", "1"]
    machine["printer_extruder_variant"] = VARIANTS
    machine["nozzle_volume_type"] = ["Standard"]

    # The bundled CLI overlay contains no machine_limits entry for the P2S.
    cli_config = read_json(APP_PROFILES / "cli_config.json")
    model_overlay = cli_config.get("printer", {}).get("Bambu Lab P2S", {}).get("machine_limits")
    if model_overlay:
        machine.update(model_overlay)
    save(OUT / "machine-p2s-04-full.json", machine)

    process, _ = flatten("process", process_name, indexes)
    process["print_settings_id"] = process_name
    process["print_extruder_id"] = ["1", "1"]
    process["print_extruder_variant"] = VARIANTS

    filament, _ = flatten("filament", filament_name, indexes)
    filament["filament_settings_id"] = [filament_name]
    filament["filament_extruder_variant"] = VARIANTS

    common = {
        "layer_height": "0.2",
        "wall_loops": "5",
        "top_shell_layers": "5",
        "bottom_shell_layers": "5",
        "sparse_infill_density": "35%",
        "sparse_infill_pattern": "gyroid",
        "support_type": "tree(auto)",
        "support_style": "default",
    }
    variants = {
        "bracket": {"enable_support": "1", "support_on_build_plate_only": "0", "brim_width": "5"},
        "fork": {"enable_support": "1", "support_on_build_plate_only": "0", "brim_width": "0"},
        "hub": {"enable_support": "1", "support_on_build_plate_only": "0", "brim_width": "0"},
        "cam": {"enable_support": "0", "brim_width": "0"},
        "roller": {"enable_support": "0", "brim_width": "3"},
    }
    for part, overrides in variants.items():
        config = merge_dict(process, common)
        config = merge_dict(config, overrides)
        config["name"] = f"{process_name} — {part} CLI check"
        config["print_settings_id"] = config["name"]
        save(OUT / f"process-{part}.json", config)

    save(OUT / "filament-pla-basic-p2s-full.json", filament)
    print(f"Wrote flattened CLI profiles to {OUT}")
    print(f"Machine inherits chain: {' -> '.join(p[1]['name'] for p in reversed([indexes['machine'][n] for n in [machine_name, 'fdm_bbl_3dp_001_common', 'fdm_machine_common']]))}")
    print("Process overrides: 0.20 mm, 5 walls, 5 top/bottom layers, 35% gyroid.")
    print("Supports: auto tree for bracket/fork/hub; off for cam/roller.")


if __name__ == "__main__":
    main()
