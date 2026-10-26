"""Export the two dock parts and check meshes, nominal fit and assembly paths."""

import argparse
import ast
import collections
import hashlib
import json
import math
import os
import re
import shutil
import struct
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "TB2_C3_Case.scad"
WORK = ROOT / ".build"
MODEL_B_ROOT = ROOT / "model-b"
MODEL_B_SOURCE = MODEL_B_ROOT / "TB2_C3_Case_B.scad"
PARTS = ("base", "lid")
COLLISIONS = ("case", "hardware", "fasteners", "usb", "cable", "lid_path",
              "light_guide_tolerance")
ZERO_VOLUME_MM3 = 0.0001
GEOMETRY_TOLERANCE_MM = 0.00001
CUT_SURFACE_TOLERANCE_MM = 0.02
LIGHT_RING_RADIUS_MM = 2.2
LIGHT_RING_SAMPLES = 72
LIGHT_TUBE_PRINT_HEIGHT_MM = 6.2
USB_FRONT_SAMPLE_MM = 0.6
USB_TONGUE_WIDTH_MM = 8.4
USB_PORT_WIDTH_MM = 10.4
USB_SHOULDER_OFFSET_MM = USB_PORT_WIDTH_MM/2 + 0.5
USB_ENTRY_FLOOR_MM = 7.5
USB_BASE_SEAM_MM = 11.8
USB_LID_ROOF_MM = 1.2
USB_PORT_ROOF_MM = 1.1
SOLDER_RELIEF_FLOOR_MM = 0.8
PCB_FLOOR_RIB_MM = 1.6
BUTTON_CENTERS_MM = ((8.8, 8.7), (14.3, 8.7))
BUTTON_INNER_SAMPLE_MM = 1.0
BUTTON_OUTER_SAMPLE_MM = 2.0
PAD_EDGE_SAMPLE_FRACTION = 0.9
MODEL_A_PIN_EXPOSED_MM = 5.4
MODEL_B_PIN_EXPOSED_MM = 4.5
HEADER_SPACER_MM = 2.5
SHIELD_THICKNESS_MM = 1.6
MAX_SOLDER_TAIL_MM = 1.3


def vertical_surfaces(path, x, y):
    """Find mesh surfaces along a vertical ray, without relying on CAD datums."""
    data = path.read_bytes()
    hits = []
    for index in range(struct.unpack_from("<I", data, 80)[0]):
        values = struct.unpack_from("<12fH", data, 84 + 50 * index)
        a, b, c = [values[start:start + 3] for start in (3, 6, 9)]
        determinant = (b[1]-c[1])*(a[0]-c[0]) + (c[0]-b[0])*(a[1]-c[1])
        if abs(determinant) < 1e-10:
            continue
        u = ((b[1]-c[1])*(x-c[0]) + (c[0]-b[0])*(y-c[1])) / determinant
        v = ((c[1]-a[1])*(x-c[0]) + (a[0]-c[0])*(y-c[1])) / determinant
        if min(u, v, 1-u-v) >= -1e-8:
            hits.append(round(u*a[2] + v*b[2] + (1-u-v)*c[2], 5))
    return sorted(set(hits))


def check_pcb_orientation(lid_path, design_path):
    """Check actual exported geometry against the independent PCB layout file.

    PCB image Y points down. World Y points up; printing the lid outside-down
    reverses Y again. Thus the delivered lid STL must use the PCB's original
    X/Y values for its apertures and LED skin. This detects a mirrored case
    even if its internal hardware model has the same orientation error.
    """
    design = json.loads(design_path.read_text(encoding="utf-8"))
    pads = design["pads"]
    led = [p for p in pads if p["ref"] == "D1"]
    x = sum(p["x"] for p in led)/len(led)
    y = sum(p["y"] for p in led)/len(led)
    skin = vertical_surfaces(lid_path, x, y)
    wrong_side = vertical_surfaces(lid_path, x, design["board_mm"][1]-y)
    if len(skin) != 2 or abs(skin[0]) > GEOMETRY_TOLERANCE_MM or abs(skin[1]-0.2) > GEOMETRY_TOLERANCE_MM:
        raise RuntimeError(f"LED cover is not at the PCB's D1 location: surfaces {skin}")
    if len(wrong_side) != 2 or wrong_side[1]-wrong_side[0] <= 0.2 + GEOMETRY_TOLERANCE_MM:
        raise RuntimeError(f"Unexpected LED pocket at the reflected D1 location: {wrong_side}")
    for pad in pads:
        if (pad["ref"] in ("J1", "JP1")
                and vertical_surfaces(lid_path, pad["x"], pad["y"])):
            raise RuntimeError(f"Lid obstructs PCB pad {pad['ref']}/{pad['pin']}")
    return {"pcb_source": "hardware/design.json", "d1_print_xy_mm": [x, y],
            "skin_surfaces_mm": skin, "reflected_position_surfaces_mm": wrong_side,
            "connector_and_jumper_pads_clear": True}


def check_light_channel(lid_path, design_path):
    """Require a continuous deep ring around the PCB's LED in the printed STL.

    A blind pocket in a flat roof cannot satisfy this check: every sampled
    ray must cross a wall that projects 5.0 mm below the 1.2-mm roof.
    """
    design = json.loads(design_path.read_text(encoding="utf-8"))
    pads = [p for p in design["pads"] if p["ref"] == "D1"]
    center = [sum(p[axis] for p in pads)/len(pads) for axis in ("x", "y")]
    for index in range(LIGHT_RING_SAMPLES):
        angle = math.tau * (index + 0.5)/LIGHT_RING_SAMPLES
        x = center[0] + LIGHT_RING_RADIUS_MM * math.cos(angle)
        y = center[1] + LIGHT_RING_RADIUS_MM * math.sin(angle)
        surfaces = vertical_surfaces(lid_path, x, y)
        if (len(surfaces) != 2 or abs(surfaces[0]) > GEOMETRY_TOLERANCE_MM
                or surfaces[1] < LIGHT_TUBE_PRINT_HEIGHT_MM - GEOMETRY_TOLERANCE_MM):
            raise RuntimeError(f"Missing continuous LED tube at angle {math.degrees(angle):.1f}: {surfaces}")
    return {"ring_samples": LIGHT_RING_SAMPLES, "sample_radius_mm": LIGHT_RING_RADIUS_MM,
            "wall_depth_from_outer_face_mm": LIGHT_TUBE_PRINT_HEIGHT_MM,
            "projection_below_roof_mm": LIGHT_TUBE_PRINT_HEIGHT_MM-USB_LID_ROOF_MM}


def check_module_roof(lid_path, design_path):
    """Require a closed roof above both the ESP32 and its USB-C receptacle."""
    design = json.loads(design_path.read_text(encoding="utf-8"))
    module = design["module_mm"]
    center_x = module[0] + module[2]/2
    roof = vertical_surfaces(lid_path, center_x, 15)
    if (len(roof) != 2 or abs(roof[0]) > GEOMETRY_TOLERANCE_MM
            or abs(roof[1]-USB_LID_ROOF_MM) > CUT_SURFACE_TOLERANCE_MM):
        raise RuntimeError(f"ESP32 roof is absent or the wrong thickness: {roof}")
    for name, (x, y) in zip(("BOOT", "RESET"), BUTTON_CENTERS_MM):
        for dx, dy in ((0, 0), (BUTTON_INNER_SAMPLE_MM, 0),
                       (-BUTTON_INNER_SAMPLE_MM, 0), (0, BUTTON_INNER_SAMPLE_MM),
                       (0, -BUTTON_INNER_SAMPLE_MM)):
            if vertical_surfaces(lid_path, x+dx, y+dy):
                raise RuntimeError(f"{name} access hole is blocked at offset {(dx, dy)}")
        for dx, dy in ((BUTTON_OUTER_SAMPLE_MM, 0), (-BUTTON_OUTER_SAMPLE_MM, 0),
                       (0, BUTTON_OUTER_SAMPLE_MM), (0, -BUTTON_OUTER_SAMPLE_MM)):
            if not vertical_surfaces(lid_path, x+dx, y+dy):
                raise RuntimeError(f"{name} access hole removed too much roof")
        if not vertical_surfaces(lid_path, x, design["board_mm"][1]-y):
            raise RuntimeError(f"{name} access hole is reflected across the board")
    usb_roof = vertical_surfaces(lid_path, center_x, 3)
    if (len(usb_roof) != 2 or abs(usb_roof[0]) > GEOMETRY_TOLERANCE_MM
            or abs(usb_roof[1]-USB_PORT_ROOF_MM) > CUT_SURFACE_TOLERANCE_MM):
        raise RuntimeError(f"USB roof is open or too thin: {usb_roof}")
    return {"pcb_source": "hardware/design.json", "roof_thickness_mm": roof[1]-roof[0],
            "button_centers_mm": [list(point) for point in BUTTON_CENTERS_MM],
            "usb_roof_thickness_mm": usb_roof[1]-usb_roof[0]}


def check_solder_reliefs(base_path, design_path):
    """Probe every released THT pad and an intact floor rib in the exported base."""
    design = json.loads(design_path.read_text(encoding="utf-8"))
    board_depth = design["board_mm"][1]
    for pad in design["pads"]:
        sample = pad["diameter"]/2*PAD_EDGE_SAMPLE_FRACTION
        for dx, dy in ((0, 0), (sample, 0), (-sample, 0), (0, sample), (0, -sample)):
            surfaces = vertical_surfaces(base_path, pad["x"]+dx,
                                         board_depth-pad["y"]-dy)
            if (len(surfaces) != 2 or abs(surfaces[0]) > GEOMETRY_TOLERANCE_MM
                    or abs(surfaces[1]-SOLDER_RELIEF_FLOOR_MM) > GEOMETRY_TOLERANCE_MM):
                raise RuntimeError(f"Missing solder well under {pad['ref']}/{pad['pin']}: {surfaces}")
    rib = vertical_surfaces(base_path, 12, board_depth/2)
    if (len(rib) != 2 or abs(rib[1]-PCB_FLOOR_RIB_MM) > GEOMETRY_TOLERANCE_MM):
        raise RuntimeError(f"Intact floor rib missing: {rib}")
    return {"pcb_source": "hardware/design.json", "covered_pads": len(design["pads"]),
            "well_floor_mm": SOLDER_RELIEF_FLOOR_MM,
            "intact_rib_floor_mm": PCB_FLOOR_RIB_MM}


def check_usb_entry(base_path, lid_path, design_path):
    """Check a framed USB-C port and continuous plastic around its tongue.

    The module center comes from the independent PCB header footprint.
    The base and print-oriented lid have opposite Y transforms.
    """
    design = json.loads(design_path.read_text(encoding="utf-8"))
    module_pads = [pad for pad in design["pads"] if pad["ref"] in ("JL", "JR")]
    center_x = (min(pad["x"] for pad in module_pads) + max(pad["x"] for pad in module_pads)) / 2
    base_y = design["board_mm"][1] + USB_FRONT_SAMPLE_MM
    lid_y = -USB_FRONT_SAMPLE_MM
    for offset in (-USB_TONGUE_WIDTH_MM/2, 0, USB_TONGUE_WIDTH_MM/2):
        x = center_x + offset
        base = vertical_surfaces(base_path, x, base_y)
        lid = vertical_surfaces(lid_path, x, lid_y)
        if (len(base) != 2 or abs(base[0]) > GEOMETRY_TOLERANCE_MM
                or abs(base[1] - USB_ENTRY_FLOOR_MM) > CUT_SURFACE_TOLERANCE_MM
                or len(lid) != 2 or abs(lid[0]) > GEOMETRY_TOLERANCE_MM
                or abs(lid[1]-USB_PORT_ROOF_MM) > CUT_SURFACE_TOLERANCE_MM):
            raise RuntimeError(f"USB port is open or obstructed at x={x}: base={base}, lid={lid}")
    for offset in (-USB_SHOULDER_OFFSET_MM, USB_SHOULDER_OFFSET_MM):
        x = center_x + offset
        base = vertical_surfaces(base_path, x, base_y)
        lid = vertical_surfaces(lid_path, x, lid_y)
        if (len(base) != 2 or abs(base[1]-USB_BASE_SEAM_MM) > GEOMETRY_TOLERANCE_MM
                or len(lid) != 2 or abs(lid[1]-USB_LID_ROOF_MM) > GEOMETRY_TOLERANCE_MM):
            raise RuntimeError(f"USB-side shoulders are missing at x={x}: base={base}, lid={lid}")
    return {"pcb_source": "hardware/design.json", "module_center_x_mm": center_x,
            "nominal_port_width_mm": USB_PORT_WIDTH_MM,
            "base_port_floor_mm": USB_ENTRY_FLOOR_MM,
            "top_bridge_mm": USB_PORT_ROOF_MM, "continuous_shoulders": True}


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


def export(scad, selector, output, source=SOURCE, work=WORK):
    """Run CGAL and retain the exact export log for diagnostic use."""
    proc = subprocess.run([scad, "--export-format", "binstl", "-D", f'part="{selector}"',
                           "-o", str(output), str(source)], capture_output=True, text=True,
                          encoding="utf-8", errors="replace", timeout=180, check=False)
    log = proc.stdout + proc.stderr
    (work / f"{selector}.log").write_text(log, encoding="utf-8")
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


def check_pin_stack(log_path, exposed_mm):
    """Check the rendered ESP pin stack against the measured exposed length."""
    log = log_path.read_text(encoding="utf-8")
    match = re.search(r"\besp_pin_stack_mm = (\[[^\]\r\n]+\])", log)
    if not match:
        raise RuntimeError(f"OpenSCAD did not report the ESP pin stack: {log_path}")
    values = ast.literal_eval(match.group(1))
    if len(values) != 4 or not all(isinstance(value, (int, float)) for value in values):
        raise RuntimeError(f"Invalid ESP pin stack in {log_path}: {values}")
    exposed, spacer, shield, tail = values
    expected = (exposed_mm, HEADER_SPACER_MM, SHIELD_THICKNESS_MM,
                exposed_mm - HEADER_SPACER_MM - SHIELD_THICKNESS_MM)
    if any(abs(actual - nominal) > GEOMETRY_TOLERANCE_MM
           for actual, nominal in zip(values, expected)):
        raise RuntimeError(f"ESP pin stack differs from the intended assembly: {values} != {expected}")
    if tail <= 0 or tail > MAX_SOLDER_TAIL_MM:
        raise RuntimeError(f"ESP pin tip cannot be accommodated by this base: {tail} mm")
    return {"pin_exposed_below_esp_mm": exposed, "header_spacer_mm": spacer,
            "shield_thickness_mm": shield, "pin_tail_below_shield_mm": tail}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--preview-only", action="store_true")
    parser.add_argument("--model-b", action="store_true",
                        help="export the 4.5-mm ESP-pin model into enclosure/model-b")
    args = parser.parse_args()
    output_root = MODEL_B_ROOT if args.model_b else ROOT
    source = MODEL_B_SOURCE if args.model_b else SOURCE
    work = output_root / ".build"
    scad = executable("OPENSCAD", "openscad", "OpenSCAD/openscad.com")
    if not source.is_file():
        raise FileNotFoundError(f"Missing OpenSCAD source: {source}")
    work.mkdir(parents=True, exist_ok=True)
    if args.preview_only:
        for name in ("assembly", "exploded", "section", "layout", "top", "led_section",
                     "usb_front", "usb_connected"):
            center_z = 32 if name == "exploded" else 11
            target_y = 31 if name == "layout" else 11.26
            camera = ("70,90,55,19.5,8,9" if name == "section" else
                      f"100,-115,110,19.5,{target_y},{center_z}")
            if name == "top":
                camera = "19.5,11.26,0,0,0,0,150"
            elif name == "led_section":
                camera = "45,-20,22,36,3,9.5"
            elif name in ("usb_front", "usb_connected"):
                camera = "19.5,130,35,19.5,11.26,13"
            selector = "assembly" if name in ("top", "usb_front") else name
            command = [scad, "--preview", "--imgsize=1500,1100",
                       "--projection=o", "--colorscheme=Tomorrow", f"--camera={camera}",
                       "-D", f'part="{selector}"', "-o", str(output_root / (name + ".png")), str(source)]
            if name not in ("section", "top", "led_section", "usb_front"):
                command.append("--viewall")
            proc = subprocess.run(command, capture_output=True, text=True, timeout=90, check=False)
            (work / f"{name}-preview.log").write_text(proc.stdout+proc.stderr, encoding="utf-8")
            if (proc.returncode or "ERROR:" in proc.stdout + proc.stderr
                    or not (output_root / (name + ".png")).is_file()):
                raise RuntimeError(f"Preview failed: {name}; inspect its log")
        print("Eight previews rendered; inspect them before delivery.")
        return
    slicer = executable("PRUSASLICER", "prusa-slicer", "Prusa3D/PrusaSlicer/prusa-slicer-console.exe")
    report = {"status": "unverified build candidate", "physical_fit_tested": False,
              "source_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
              "parts": {}, "collisions": {}}
    if args.model_b:
        report["shared_source_sha256"] = hashlib.sha256(SOURCE.read_bytes()).hexdigest()
    for part in PARTS:
        path = output_root / f"TB2_C3_Case_{part}.stl"
        info = export(scad, part, path, source=source, work=work)
        if not info or not info["closed_edges"] or info["connected_parts"] != 1:
            raise RuntimeError(f"Mesh validation failed: {part}: {info}")
        proc = subprocess.run([slicer, "--info", str(path)], capture_output=True, text=True, timeout=60, check=False)
        log = proc.stdout + proc.stderr
        (work / f"{part}-slicer.log").write_text(log, encoding="utf-8")
        fields = {key.strip(): value.strip() for line in log.splitlines() if "=" in line
                  for key, value in [line.split("=", 1)]}
        if proc.returncode or fields.get("manifold") != "yes" or fields.get("number_of_parts") != "1":
            raise RuntimeError(f"Slicer mesh check failed: {part}; inspect log")
        info["sha256"] = hashlib.sha256(path.read_bytes()).hexdigest()
        info["slicer_manifold"] = True
        report["parts"][part] = info
        print(f"{part}: one closed mesh, {info['volume_mm3']} mm3", flush=True)
    report["esp_pin_stack"] = check_pin_stack(
        work / "base.log", MODEL_B_PIN_EXPOSED_MM if args.model_b else MODEL_A_PIN_EXPOSED_MM)
    print(f"ESP pin stack: {report['esp_pin_stack']['pin_tail_below_shield_mm']:.1f} mm "
          "metal tail under shield", flush=True)
    report["pcb_orientation"] = check_pcb_orientation(
        output_root / "TB2_C3_Case_lid.stl", ROOT.parent / "hardware/design.json")
    print("PCB orientation: D1, J1 and JP1 match the released layout", flush=True)
    report["module_roof"] = check_module_roof(
        output_root / "TB2_C3_Case_lid.stl", ROOT.parent / "hardware/design.json")
    print("ESP32 and USB roof: closed except for BOOT and RESET accesses", flush=True)
    report["solder_reliefs"] = check_solder_reliefs(
        output_root / "TB2_C3_Case_base.stl", ROOT.parent / "hardware/design.json")
    print("Solder wells: all THT pads relieved; central floor rib intact", flush=True)
    report["light_channel"] = check_light_channel(
        output_root / "TB2_C3_Case_lid.stl", ROOT.parent / "hardware/design.json")
    print(f"LED tube: continuous wall extends "
          f"{LIGHT_TUBE_PRINT_HEIGHT_MM-USB_LID_ROOF_MM:.1f} mm below the lid roof",
          flush=True)
    report["usb_entry"] = check_usb_entry(
        output_root / "TB2_C3_Case_base.stl", output_root / "TB2_C3_Case_lid.stl",
        ROOT.parent / "hardware/design.json")
    print("USB entry: enclosed port with intact side shoulders", flush=True)
    for name in COLLISIONS:
        info = export(scad, "collision_" + name, work / ("collision_" + name + ".stl"),
                      source=source, work=work)
        volume = info["volume_mm3"] if info else 0
        report["collisions"][name] = {
            "volume_mm3": volume,
            "planar_contact_only": bool(info and info.get("planar_contact_only")),
        }
        if volume > ZERO_VOLUME_MM3:
            raise RuntimeError(f"Nominal collision: {name}: {volume} mm3")
        print(f"{name}: no volumetric collision", flush=True)
    probe = export(scad, "led_membrane_probe", work / "led_membrane_probe.stl",
                   source=source, work=work)
    if not probe or not probe["closed_edges"] or probe["connected_parts"] != 1:
        raise RuntimeError("LED membrane is missing or not a closed connected solid")
    thickness = probe["bounds_mm"][2][1] - probe["bounds_mm"][2][0]
    if abs(thickness - 0.2) > 0.00001:
        raise RuntimeError(f"Expected one 0.2 mm LED-cover layer, found {thickness} mm")
    report["led_membrane"] = {"thickness_mm": round(thickness, 5), "closed": True}
    print("LED cover: continuous 0.2 mm skin", flush=True)
    (output_root / "validation.json").write_text(
        json.dumps(report, indent=2) + "\n", encoding="utf-8", newline="\n")
    print("Geometry checks passed. Actual module, cable, print and fit remain unverified.")


if __name__ == "__main__":
    main()
