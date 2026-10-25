"""Export the reviewed Onshape print groups to uniquely named binary STLs (mm)."""
from __future__ import annotations
import json, math, pathlib, re, struct, xml.etree.ElementTree as ET, zipfile

ROOT = pathlib.Path(__file__).parent
OUT = ROOT / "stl"
NS = {"m": "http://schemas.microsoft.com/3dmanufacturing/core/2015/02"}
EXPECTED = {"controller-moving.3mf": 13, "controller-supports.3mf": 6, "controller-frame.3mf": 3}

def export(source: pathlib.Path) -> list[dict]:
    with zipfile.ZipFile(source) as archive:
        model = ET.fromstring(archive.read("3D/3dmodel.model"))
    if model.attrib.get("unit") != "meter":
        raise ValueError(f"Expected meter units: {source}")
    objects = model.findall("m:resources/m:object", NS)
    items = model.findall("m:build/m:item", NS)
    if len(objects) != EXPECTED[source.name] or len(items) != len(objects):
        raise ValueError(f"Expected {EXPECTED[source.name]} objects/build items, found {len(objects)}/{len(items)} in {source}")
    item_ids = {i.attrib["objectid"] for i in items}
    rows = []
    group = source.stem.removeprefix("controller-")
    OUT.mkdir(parents=True, exist_ok=True)
    for obj in objects:
        oid = obj.attrib["id"]
        item = next((i for i in items if i.attrib.get("objectid") == oid), None)
        if oid not in item_ids or item is None or "transform" in item.attrib:
            raise ValueError(f"Missing or transformed build item: object {oid}")
        mesh = obj.find("m:mesh", NS)
        if mesh is None:
            raise ValueError(f"No direct mesh: object {oid}")
        verts = [tuple(1000*float(v.attrib[a]) for a in ("x", "y", "z")) for v in mesh.findall("m:vertices/m:vertex", NS)]
        tris = [tuple(int(t.attrib[a]) for a in ("v1", "v2", "v3")) for t in mesh.findall("m:triangles/m:triangle", NS)]
        safe = re.sub(r"[^A-Za-z0-9._-]+", "-", obj.attrib.get("name", "object")).strip("-.") or "object"
        path = OUT / f"{group}-{safe}-id{oid}.stl"
        with path.open("wb") as out:
            out.write(f"Onshape reviewed {group} object {oid}; metre to millimetre".encode("ascii")[:80].ljust(80,b" "))
            out.write(struct.pack("<I", len(tris)))
            for ids in tris:
                a,b,c = (verts[i] for i in ids)
                u=[b[i]-a[i] for i in range(3)]; v=[c[i]-a[i] for i in range(3)]
                n=[u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0]]
                length=math.sqrt(sum(x*x for x in n))
                if not length: raise ValueError(f"Degenerate triangle in {path}")
                out.write(struct.pack("<12fH", *(x/length for x in n), *a,*b,*c,0))
        rows.append(dict(source=source.name, object_id=oid, object_name=obj.attrib.get("name", ""), file=path.name, triangles=len(tris)))
    return rows

def main() -> None:
    missing=[n for n in EXPECTED if not (ROOT/n).is_file()]
    if missing: raise SystemExit("Missing reviewed exports: " + ", ".join(missing))
    records=[]
    for name in EXPECTED: records.extend(export(ROOT/name))
    if len(records)!=22: raise ValueError(f"Expected 22 total objects, got {len(records)}")
    (ROOT/"conversion-report.json").write_text(json.dumps(records,indent=2)+"\n",encoding="utf-8")
    print(f"Exported {len(records)} reviewed meshes")
if __name__ == "__main__": main()
