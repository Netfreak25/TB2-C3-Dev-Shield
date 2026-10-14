"""Export the two dock parts and check meshes, nominal fit and assembly paths."""

import argparse
import collections
import hashlib
import json
import os
import shutil
import struct
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "TB2_C3_Case.scad"
WORK = ROOT / ".build"
PARTS = ("base", "lid")
COLLISIONS = ("case", "hardware", "fasteners", "usb", "cable", "lid_path", "module_path")
ZERO_VOLUME_MM3 = 0.0001


def executable(variable, name, windows_path):
    """Resolve a configured tool, the PATH, or its standard Windows installation."""
    value = os.environ.get(variable) or shutil.which(name)
    candidate = Path(value) if value else Path(os.environ.get("ProgramFiles", "")) / windows_path
    if not candidate.is_file():
        raise FileNotFoundError(f"Set {variable} to the installed {name} executable")
    return str(candidate.resolve())


def mesh_info(path):
    """Inspect closed edge incidence, connected components and signed STL volume."""
    data = path.read_bytes()
    count = struct.unpack_from("<I", data, 80)[0]
    if len(data) != 84 + 50 * count:
        raise ValueError(f"Expected binary STL: {path.name}")
    edges = collections.Counter()
    parents = {}
    vertices = set()
    volume = 0.0

    def root(vertex):
        parents.setdefault(vertex, vertex)
        while parents[vertex] != vertex:
            parents[vertex] = parents[parents[vertex]]
            vertex = parents[vertex]
        return vertex

    for index in range(count):
        values = struct.unpack_from("<12fH", data, 84 + 50 * index)
        points = [tuple(round(v, 5) for v in values[start:start + 3]) for start in (3, 6, 9)]
        a, b, c = points
        volume += (a[0] * (b[1]*c[2]-b[2]*c[1]) + a[1] * (b[2]*c[0]-b[0]*c[2])
                   + a[2] * (b[0]*c[1]-b[1]*c[0])) / 6
        vertices.update(points)
        for first, second in ((a, b), (b, c), (c, a)):
            edges[tuple(sorted((first, second)))] += 1
            first_root, second_root = root(first), root(second)
            parents[first_root] = second_root
    components = len({root(v) for v in vertices})
    bounds = [[min(v[i] for v in vertices), max(v[i] for v in vertices)] for i in range(3)]
    return {"triangles": count, "connected_parts": components,
            "closed_edges": all(n == 2 for n in edges.values()),
            "volume_mm3": round(abs(volume), 6), "bounds_mm": bounds}


def export(scad, selector, output):
    """Run CGAL and retain the exact export log for diagnostic use."""
    proc = subprocess.run([scad, "--export-format", "binstl", "-D", f'part="{selector}"',
                           "-o", str(output), str(SOURCE)], capture_output=True, text=True,
                          encoding="utf-8", errors="replace", timeout=180, check=False)
    log = proc.stdout + proc.stderr
    (WORK / f"{selector}.log").write_text(log, encoding="utf-8")
    if "ERROR:" in log:
        raise RuntimeError(f"OpenSCAD error in {selector}; inspect its log")
    if "WARNING:" in log:
        # CGAL can export the shared, zero-thickness seating plane as a sheet.
        # Accept only that proven planar contact in a collision result, never
        # a warning in a printable mesh or a non-planar collision object.
        known = ("WARNING: Object may not be a valid 2-manifold and may need repair!",
                 "EXPORT-WARNING: Exported object may not be a valid 2-manifold and may need repair")
        warnings = [line.strip() for line in log.splitlines() if "WARNING:" in line]
        if selector.startswith("collision_") and output.is_file() and all(w in known for w in warnings):
            info = mesh_info(output)
            if info["volume_mm3"] <= ZERO_VOLUME_MM3 and any(
                    upper-lower <= 0.00001 for lower, upper in info["bounds_mm"]):
                info["planar_contact_only"] = True
                return info
        raise RuntimeError(f"OpenSCAD diagnostic in {selector}; inspect its log")
    if "Current top level object is empty" in log:
        return None
    if proc.returncode or not output.is_file():
        raise RuntimeError(f"OpenSCAD failed for {selector}; inspect its log")
    return mesh_info(output)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--preview-only", action="store_true")
    args = parser.parse_args()
    scad = executable("OPENSCAD", "openscad", "OpenSCAD/openscad.com")
    WORK.mkdir(exist_ok=True)
    if args.preview_only:
        for name in ("assembly", "exploded", "section", "layout"):
            center_z = 32 if name == "exploded" else 11
            target_y = 31 if name == "layout" else 11.26
            camera = ("70,90,55,19.5,8,9" if name == "section" else
                      f"100,-115,110,19.5,{target_y},{center_z}")
            command = [scad, "--preview", "--imgsize=1500,1100",
                       "--projection=o", "--colorscheme=Tomorrow", f"--camera={camera}",
                       "-D", f'part="{name}"', "-o", str(ROOT / (name + ".png")), str(SOURCE)]
            if name != "section":
                command.append("--viewall")
            proc = subprocess.run(command, capture_output=True, text=True, timeout=90, check=False)
            (WORK / f"{name}-preview.log").write_text(proc.stdout+proc.stderr, encoding="utf-8")
            if proc.returncode or not (ROOT / (name + ".png")).is_file():
                raise RuntimeError(f"Preview failed: {name}")
        print("Four previews rendered; inspect them before delivery.")
        return
    slicer = executable("PRUSASLICER", "prusa-slicer", "Prusa3D/PrusaSlicer/prusa-slicer-console.exe")
    report = {"status": "unverified build candidate", "physical_fit_tested": False,
              "source_sha256": hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
              "parts": {}, "collisions": {}}
    for part in PARTS:
        path = ROOT / f"TB2_C3_Case_{part}.stl"
        info = export(scad, part, path)
        if not info or not info["closed_edges"] or info["connected_parts"] != 1:
            raise RuntimeError(f"Mesh validation failed: {part}: {info}")
        proc = subprocess.run([slicer, "--info", str(path)], capture_output=True, text=True, timeout=60, check=False)
        log = proc.stdout + proc.stderr
        (WORK / f"{part}-slicer.log").write_text(log, encoding="utf-8")
        fields = {key.strip(): value.strip() for line in log.splitlines() if "=" in line
                  for key, value in [line.split("=", 1)]}
        if proc.returncode or fields.get("manifold") != "yes" or fields.get("number_of_parts") != "1":
            raise RuntimeError(f"Slicer mesh check failed: {part}; inspect log")
        info["sha256"] = hashlib.sha256(path.read_bytes()).hexdigest()
        info["slicer_manifold"] = True
        report["parts"][part] = info
        print(f"{part}: one closed mesh, {info['volume_mm3']} mm3", flush=True)
    for name in COLLISIONS:
        info = export(scad, "collision_" + name, WORK / ("collision_" + name + ".stl"))
        volume = info["volume_mm3"] if info else 0
        report["collisions"][name] = {
            "volume_mm3": volume,
            "planar_contact_only": bool(info and info.get("planar_contact_only")),
        }
        if volume > ZERO_VOLUME_MM3:
            raise RuntimeError(f"Nominal collision: {name}: {volume} mm3")
        print(f"{name}: no volumetric collision", flush=True)
    probe = export(scad, "led_membrane_probe", WORK / "led_membrane_probe.stl")
    if not probe or not probe["closed_edges"] or probe["connected_parts"] != 1:
        raise RuntimeError("LED membrane is missing or not a closed connected solid")
    thickness = probe["bounds_mm"][2][1] - probe["bounds_mm"][2][0]
    if abs(thickness - 0.2) > 0.00001:
        raise RuntimeError(f"Expected one 0.2 mm LED-cover layer, found {thickness} mm")
    report["led_membrane"] = {"thickness_mm": round(thickness, 5), "closed": True}
    print("LED cover: continuous 0.2 mm skin", flush=True)
    (ROOT / "validation.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8", newline="\n")
    print("Geometry checks passed. Actual module, cable, print and fit remain unverified.")


if __name__ == "__main__":
    main()
