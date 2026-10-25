"""Export each integrated Onshape 3MF build object as a binary STL in mm."""
from __future__ import annotations

import json
import math
import pathlib
import re
import struct
import xml.etree.ElementTree as ET
import zipfile

ROOT = pathlib.Path(__file__).parent
OUT = ROOT / "stl"
NS = {"m": "http://schemas.microsoft.com/3dmanufacturing/core/2015/02"}
EXPECTED = {"controller-moving.3mf": 12, "controller-supports.3mf": 14,
            "controller-frame.3mf": 4}


def export(source: pathlib.Path) -> list[dict]:
    with zipfile.ZipFile(source) as archive:
        model = ET.fromstring(archive.read("3D/3dmodel.model"))
    if model.attrib.get("unit") != "meter":
        raise ValueError(f"Expected meter units: {source}")
    objects = model.findall("m:resources/m:object", NS)
    items = model.findall("m:build/m:item", NS)
    if len(objects) != EXPECTED[source.name] or len(items) != len(objects):
        raise ValueError(f"Unexpected object/build count in {source}: {len(objects)}/{len(items)}")
    item_by_id = {i.attrib["objectid"]: i for i in items}
    OUT.mkdir(parents=True, exist_ok=True)
    rows = []
    group = source.stem.removeprefix("controller-")
    for obj in objects:
        oid = obj.attrib["id"]
        if oid not in item_by_id or "transform" in item_by_id[oid].attrib:
            raise ValueError(f"Missing build item or unexpected placement transform for object {oid}")
        mesh = obj.find("m:mesh", NS)
        if mesh is None:
            raise ValueError(f"Object {oid} has no direct mesh")
        verts = [tuple(1000 * float(v.attrib[a]) for a in ("x", "y", "z"))
                 for v in mesh.findall("m:vertices/m:vertex", NS)]
        tris = [tuple(int(t.attrib[a]) for a in ("v1", "v2", "v3"))
                 for t in mesh.findall("m:triangles/m:triangle", NS)]
        name = re.sub(r"[^A-Za-z0-9._-]+", "-", obj.attrib.get("name", "object")).strip("-.")
        path = OUT / f"{group}-{name}-id{oid}.stl"
        with path.open("wb") as out:
            out.write(f"Onshape {group} object {oid}; source metres converted to millimetres".encode("ascii")[:80].ljust(80, b" "))
            out.write(struct.pack("<I", len(tris)))
            for indices in tris:
                a, b, c = [verts[i] for i in indices]
                u = [b[i] - a[i] for i in range(3)]
                v = [c[i] - a[i] for i in range(3)]
                n = [u[1]*v[2]-u[2]*v[1], u[2]*v[0]-u[0]*v[2], u[0]*v[1]-u[1]*v[0]]
                length = math.sqrt(sum(x*x for x in n))
                if not length:
                    raise ValueError(f"Degenerate triangle in {path}")
                out.write(struct.pack("<12fH", *(x/length for x in n), *a, *b, *c, 0))
        rows.append({"source": source.name, "object_id": oid, "object_name": obj.attrib.get("name", ""),
                     "file": path.name, "triangles": len(tris)})
    return rows


def main() -> None:
    missing = [name for name in EXPECTED if not (ROOT / name).exists()]
    if missing:
        raise SystemExit("Waiting for source exports: " + ", ".join(missing))
    records = []
    for name in EXPECTED:
        records.extend(export(ROOT / name))
    (ROOT / "conversion-report.json").write_text(json.dumps(records, indent=2) + "\n", encoding="utf-8")
    print(f"Exported {len(records)} object meshes to {OUT}")


if __name__ == "__main__":
    main()
