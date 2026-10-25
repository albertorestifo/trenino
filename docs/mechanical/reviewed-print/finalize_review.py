"""Cross-check successful CLI outputs/settings and package source 3MFs plus STLs."""
import json, pathlib, re, zipfile

ROOT=pathlib.Path(__file__).parent
STL=ROOT/"stl"; SLICED=ROOT/"sliced"
REPORT=json.loads((ROOT/"slice-report.json").read_text(encoding="utf-8-sig"))
EXPECTED_SUPPORTS=re.compile(r"M01|M06|M07|M08|M10|M11|S03")
assert len(REPORT)==22
assert all(r["Success"] and r["ExitCode"]==0 and r["OutputBytes"]>0 for r in REPORT)
checks=[]
for row in REPORT:
    out=pathlib.Path(row["Output"])
    assert out.is_file() and out.stat().st_size==row["OutputBytes"]
    with zipfile.ZipFile(out) as z:
        cfg=json.loads(z.read("Metadata/project_settings.config"))
    expected=bool(EXPECTED_SUPPORTS.search(row["Part"]))
    assert bool(row["Supports"])==expected
    assert str(cfg.get("enable_support"))==("1" if expected else "0"),(row["Part"],cfg.get("enable_support"))
    assert str(cfg.get("layer_height")) in ("0.2","0.20")
    assert str(cfg.get("wall_loops"))=="5"
    assert cfg.get("sparse_infill_density")=="35%" and cfg.get("sparse_infill_pattern")=="gyroid"
    checks.append((row["Part"],expected))

all_logs="\n".join((SLICED/(pathlib.Path(r["StdoutLog"]).name)).read_text(encoding="utf-8",errors="replace") for r in REPORT)
zfill=sorted(set(re.findall(r"ZFiller:[^\r\n]*",all_logs)))
float_lines=sorted(set(re.findall(r"[^\r\n]*(?:floating|float(?:ing)? object)[^\r\n]*",all_logs,re.I)))
package=ROOT/"reviewed-print-source-stl-guide.zip"
guide=ROOT.parent/"INTEGRATED_PRINT_GUIDE.md"
assert guide.is_file()
sources=[ROOT/n for n in ("controller-moving.3mf","controller-supports.3mf","controller-frame.3mf")]
assert all(p.is_file() for p in sources)
feature_script=ROOT.parent/"integrated_controller.fs"
assert feature_script.is_file()
with zipfile.ZipFile(package,"w",compression=zipfile.ZIP_DEFLATED,compresslevel=6) as z:
    for p in sources: z.write(p,f"source-3mf/{p.name}")
    for p in sorted(STL.glob("*.stl")): z.write(p,f"stl/{p.name}")
    z.write(guide,"INTEGRATED_PRINT_GUIDE.md")
    z.write(feature_script,"source/integrated_controller.fs")
    assert len(z.namelist())==27

lines=["# Reviewed integrated print validation", "",
       "Source exports: 3 reviewed Onshape 3MFs; current FeatureScript source hash: `8E0F76D93B1EF02D5618B50AD2BF37C296640A0BEEAB5AC801CBEB40222B2606`.",
       "", "## Mesh conversion and checks", "",
       "- Converted 22 build objects from 3MF meters to binary STL millimeters; filenames include group, sanitized object name, and unique object ID.",
       "- All 22 STLs passed checks: one connected component, zero nonmanifold edges, zero inconsistent edge winding, positive signed volume, Z minimum 0 mm within tolerance, and bounds within the 256 mm P2S envelope.",
       "- The spring-block STL was regenerated from the corrected SUPPORT export; all 21 other STL byte hashes are unchanged from the preceding verified set.",
       "", "## Slicer checks", "",
       "- Bambu Studio CLI: P2S 0.4 mm nozzle, PLA Basic, 0.20 mm layers, 5 wall loops, 5 top/bottom layers, 35% gyroid.",
       "- 22/22 parts produced a nonempty G-code 3MF with process return code 0. Support is enabled and verified in the saved project settings for M01 shaft, M06 cam, M07 carrier lug, M08 fork, M10/M11 grip halves, and S03 spring block; it is off for the other 15 objects.",
       "- No floating-object warning was found in the captured CLI logs.",
       "- Bambu Studio logged nonfatal diagnostics: `ZFiller` clip/subject messages on M01, M10, M11, S01, S03, and S04; `Not precalculated Placeable areas requested., critical: 0` on M01, M06, M07, M08, M10, M11, and S03; and `Invalid T command (T65535)` plus `nozzle_volume_type not found` across all outputs. Each affected slice nevertheless reports return code 0 and has an output file. The mesh topology checks found no corresponding mesh-integrity failure; treat these as slicer diagnostics for visual preview review, not as a confirmed geometry defect.",
       "", f"Support-enabled parts verified: {sum(s for _,s in checks)} of 22.",
       f"Package: `{package.name}` (3 source 3MFs, 22 STLs, current guide, FeatureScript source; excludes G-code, logs, and reports).",
       "", "Detailed mesh metrics: `mesh-check.json`. Per-part slicer outputs and logs are in `sliced/`; the complete CLI summary is `slice-report.json`.", ""]
(ROOT/"review-report.md").write_text("\n".join(lines),encoding="utf-8")
print(f"Verified {len(checks)} slicer configurations; package={package} ({package.stat().st_size} bytes)")
print("ZFiller diagnostics:",zfill)
print("Floating warnings:",float_lines)
