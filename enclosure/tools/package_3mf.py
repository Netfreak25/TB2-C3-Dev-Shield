"""Package the print-oriented enclosure STLs as a clean, portable 3MF plate.

The OpenSCAD lid STL already lies outside-down. This tool translates, but
never rotates, either mesh. No printer profile or local file paths are stored.
"""

from __future__ import annotations

import argparse
import math
import os
import struct
import tempfile
import xml.etree.ElementTree as ET
import zipfile
from collections import Counter
from dataclasses import dataclass
from pathlib import Path

MODEL_NS = "http://schemas.microsoft.com/3dmanufacturing/core/2015/02"
TYPES_NS = "http://schemas.openxmlformats.org/package/2006/content-types"
RELS_NS = "http://schemas.openxmlformats.org/package/2006/relationships"
MODEL_REL = "http://schemas.microsoft.com/3dmanufacturing/2013/01/3dmodel"
MODEL_PATH = "3D/3dmodel.model"
DEFAULT_GAP_MM = 8.0
DEFAULT_OUTPUT = "TB2_C3_Case_B_corrected.3mf"
PROTECTED_PROJECT = "TB2_C3_Case_lid.3mf"
EXPECTED_MEMBERS = frozenset({"[Content_Types].xml", "_rels/.rels", MODEL_PATH})
STL_HEADER_SIZE = 84
STL_TRIANGLE_SIZE = 50
ZIP_DATE = (1980, 1, 1, 0, 0, 0)

Point = tuple[float, float, float]
Triangle = tuple[int, int, int]
Bounds = tuple[float, float, float, float, float, float]


@dataclass(frozen=True)
class Mesh:
    """One triangulated STL surface in millimetres."""

    vertices: tuple[Point, ...]
    triangles: tuple[Triangle, ...]

    def bounds(self) -> Bounds:
        """Return minimum and maximum x, y, z coordinates."""
        return (
            min(v[0] for v in self.vertices),
            max(v[0] for v in self.vertices),
            min(v[1] for v in self.vertices),
            max(v[1] for v in self.vertices),
            min(v[2] for v in self.vertices),
            max(v[2] for v in self.vertices),
        )


@dataclass(frozen=True)
class Part:
    """A named, translated printable object."""

    name: str
    mesh: Mesh
    position: Point


def read_binary_stl(path: Path) -> Mesh:
    """Parse the binary STL emitted by OpenSCAD, preserving face winding."""
    data = path.read_bytes()
    if len(data) < STL_HEADER_SIZE:
        raise ValueError(f"{path.name}: STL is shorter than its binary header")
    count = struct.unpack_from("<I", data, 80)[0]
    expected_size = STL_HEADER_SIZE + count * STL_TRIANGLE_SIZE
    if count == 0 or len(data) != expected_size:
        raise ValueError(
            f"{path.name}: expected a nonempty binary STL of {expected_size} "
            f"bytes, got {len(data)}"
        )

    vertices: list[Point] = []
    vertex_index: dict[Point, int] = {}
    triangles: list[Triangle] = []
    for face in range(count):
        values = struct.unpack_from("<12fH", data, STL_HEADER_SIZE + face * STL_TRIANGLE_SIZE)
        indices: list[int] = []
        for start in (3, 6, 9):
            point: Point = (values[start], values[start + 1], values[start + 2])
            if not all(math.isfinite(axis) for axis in point):
                raise ValueError(f"{path.name}: face {face} has a non-finite vertex")
            if point not in vertex_index:
                vertex_index[point] = len(vertices)
                vertices.append(point)
            indices.append(vertex_index[point])
        triangles.append((indices[0], indices[1], indices[2]))
    return Mesh(tuple(vertices), tuple(triangles))


def arrange_parts(base: Mesh, lid: Mesh, gap_mm: float = DEFAULT_GAP_MM) -> tuple[Part, Part]:
    """Place both print-oriented surfaces on z=0 with a horizontal gap."""
    if not math.isfinite(gap_mm) or gap_mm <= 0:
        raise ValueError("The gap between parts must be a positive finite number")
    bx0, bx1, by0, _, bz0, _ = base.bounds()
    lx0, _, ly0, _, lz0, _ = lid.bounds()
    return (
        Part("Base", base, (-bx0, -by0, -bz0)),
        Part("Lid", lid, (bx1 - bx0 + gap_mm - lx0, -ly0, -lz0)),
    )


def _format_number(value: float) -> str:
    """Keep enough decimal digits to round-trip STL float32 coordinates."""
    return format(value, ".9g")


def _model_xml(parts: tuple[Part, Part]) -> bytes:
    """Encode printable objects and their plate translations in 3MF core XML."""
    ET.register_namespace("", MODEL_NS)
    model = ET.Element(f"{{{MODEL_NS}}}model", {"unit": "millimeter"})
    resources = ET.SubElement(model, f"{{{MODEL_NS}}}resources")
    build = ET.SubElement(model, f"{{{MODEL_NS}}}build")
    for object_id, part in enumerate(parts, start=1):
        obj = ET.SubElement(
            resources,
            f"{{{MODEL_NS}}}object",
            {"id": str(object_id), "type": "model", "name": part.name},
        )
        surface = ET.SubElement(obj, f"{{{MODEL_NS}}}mesh")
        vertices = ET.SubElement(surface, f"{{{MODEL_NS}}}vertices")
        for x, y, z in part.mesh.vertices:
            ET.SubElement(
                vertices,
                f"{{{MODEL_NS}}}vertex",
                {"x": _format_number(x), "y": _format_number(y), "z": _format_number(z)},
            )
        triangles = ET.SubElement(surface, f"{{{MODEL_NS}}}triangles")
        for v1, v2, v3 in part.mesh.triangles:
            ET.SubElement(
                triangles,
                f"{{{MODEL_NS}}}triangle",
                {"v1": str(v1), "v2": str(v2), "v3": str(v3)},
            )
        transform = "1 0 0 0 1 0 0 0 1 " + " ".join(
            _format_number(axis) for axis in part.position
        )
        ET.SubElement(
            build,
            f"{{{MODEL_NS}}}item",
            {"objectid": str(object_id), "transform": transform, "printable": "1"},
        )
    return ET.tostring(model, encoding="utf-8", xml_declaration=True)


def _types_xml() -> bytes:
    ET.register_namespace("", TYPES_NS)
    root = ET.Element(f"{{{TYPES_NS}}}Types")
    ET.SubElement(
        root,
        f"{{{TYPES_NS}}}Default",
        {
            "Extension": "rels",
            "ContentType": "application/vnd.openxmlformats-package.relationships+xml",
        },
    )
    ET.SubElement(
        root,
        f"{{{TYPES_NS}}}Default",
        {
            "Extension": "model",
            "ContentType": "application/vnd.ms-package.3dmanufacturing-3dmodel+xml",
        },
    )
    return ET.tostring(root, encoding="utf-8", xml_declaration=True)


def _relationships_xml() -> bytes:
    ET.register_namespace("", RELS_NS)
    root = ET.Element(f"{{{RELS_NS}}}Relationships")
    ET.SubElement(
        root,
        f"{{{RELS_NS}}}Relationship",
        {"Target": f"/{MODEL_PATH}", "Id": "rel0", "Type": MODEL_REL},
    )
    return ET.tostring(root, encoding="utf-8", xml_declaration=True)


def _write_member(archive: zipfile.ZipFile, name: str, contents: bytes) -> None:
    info = zipfile.ZipInfo(name, ZIP_DATE)
    info.compress_type = zipfile.ZIP_DEFLATED
    info.external_attr = 0o644 << 16
    archive.writestr(info, contents, compress_type=zipfile.ZIP_DEFLATED, compresslevel=9)


def _face_counter(mesh: Mesh) -> Counter[tuple[bytes, bytes, bytes]]:
    """Compare triangle coordinates exactly at their original float32 precision."""
    return Counter(
        tuple(struct.pack("<fff", *mesh.vertices[index]) for index in triangle)
        for triangle in mesh.triangles
    )


def _mesh_from_xml(obj: ET.Element) -> Mesh:
    ns = {"m": MODEL_NS}
    vertices = tuple(
        (float(v.attrib["x"]), float(v.attrib["y"]), float(v.attrib["z"]))
        for v in obj.findall("./m:mesh/m:vertices/m:vertex", ns)
    )
    triangles = tuple(
        (int(t.attrib["v1"]), int(t.attrib["v2"]), int(t.attrib["v3"]))
        for t in obj.findall("./m:mesh/m:triangles/m:triangle", ns)
    )
    if not vertices or not triangles:
        raise ValueError("A packaged object has no mesh")
    if any(index < 0 or index >= len(vertices) for tri in triangles for index in tri):
        raise ValueError("A packaged triangle refers to a missing vertex")
    return Mesh(vertices, triangles)


def verify_package(path: Path, parts: tuple[Part, Part], gap_mm: float) -> None:
    """Check ZIP integrity, both meshes, placements, and printability."""
    with zipfile.ZipFile(path) as archive:
        if set(archive.namelist()) != EXPECTED_MEMBERS:
            raise ValueError("The 3MF contains unexpected or missing members")
        damaged = archive.testzip()
        if damaged is not None:
            raise ValueError(f"The 3MF has a damaged ZIP member: {damaged}")
        model = ET.fromstring(archive.read(MODEL_PATH))
    if model.attrib.get("unit") != "millimeter":
        raise ValueError("The 3MF unit must be millimetres")
    ns = {"m": MODEL_NS}
    objects = model.findall("./m:resources/m:object", ns)
    items = model.findall("./m:build/m:item", ns)
    if len(objects) != len(parts) or len(items) != len(parts):
        raise ValueError("The 3MF must have exactly two printable objects")
    for index, part in enumerate(parts, start=1):
        obj = objects[index - 1]
        item = items[index - 1]
        if obj.attrib.get("id") != str(index) or item.attrib.get("objectid") != str(index):
            raise ValueError("The 3MF build items do not refer to the expected meshes")
        if item.attrib.get("printable") != "1":
            raise ValueError("Both 3MF objects must be printable")
        transform = tuple(float(value) for value in item.attrib["transform"].split())
        if len(transform) != 12 or transform[:9] != (1, 0, 0, 0, 1, 0, 0, 0, 1):
            raise ValueError("The 3MF unexpectedly rotates or scales a print part")
        if any(abs(a - b) > 1e-5 for a, b in zip(transform[9:], part.position)):
            raise ValueError("A 3MF print part has the wrong plate position")
        packed_mesh = _mesh_from_xml(obj)
        if _face_counter(packed_mesh) != _face_counter(part.mesh):
            raise ValueError(f"The packaged {part.name} triangles differ from the STL")
        if abs(packed_mesh.bounds()[4] + transform[11]) > 1e-5:
            raise ValueError(f"The packaged {part.name} is not on the print bed")
    base_right = parts[0].mesh.bounds()[1] + parts[0].position[0]
    lid_left = parts[1].mesh.bounds()[0] + parts[1].position[0]
    if lid_left - base_right < gap_mm - 1e-5:
        raise ValueError("The base and lid overlap on the print bed")


def create_package(
    base_path: Path,
    lid_path: Path,
    output_path: Path,
    *,
    gap_mm: float = DEFAULT_GAP_MM,
    overwrite: bool = False,
) -> tuple[Part, Part]:
    """Write and verify an independent 3MF, then atomically install it."""
    original_project = Path(__file__).resolve().parent.parent / "model-b" / PROTECTED_PROJECT
    if output_path.resolve() == original_project.resolve():
        raise ValueError("The original slicer project is protected; select a new output")
    if output_path.exists() and not overwrite:
        raise FileExistsError(f"{output_path} already exists; use --force to replace it")
    parts = arrange_parts(read_binary_stl(base_path), read_binary_stl(lid_path), gap_mm)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(
        prefix=".package_3mf_", suffix=".tmp", dir=output_path.parent, delete=False
    ) as temporary:
        temporary_path = Path(temporary.name)
    try:
        with zipfile.ZipFile(temporary_path, "w") as archive:
            _write_member(archive, "[Content_Types].xml", _types_xml())
            _write_member(archive, "_rels/.rels", _relationships_xml())
            _write_member(archive, MODEL_PATH, _model_xml(parts))
        verify_package(temporary_path, parts, gap_mm)
        os.replace(temporary_path, output_path)
    finally:
        temporary_path.unlink(missing_ok=True)
    return parts


def main() -> None:
    """Package the enclosure's Model B STL pair from the command line."""
    model_dir = Path(__file__).resolve().parent.parent / "model-b"
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base", type=Path, default=model_dir / "TB2_C3_Case_base.stl")
    parser.add_argument("--lid", type=Path, default=model_dir / "TB2_C3_Case_lid.stl")
    parser.add_argument("--output", type=Path, default=model_dir / DEFAULT_OUTPUT)
    parser.add_argument("--gap-mm", type=float, default=DEFAULT_GAP_MM)
    parser.add_argument("--force", action="store_true", help="Replace only the selected output")
    args = parser.parse_args()
    parts = create_package(
        args.base, args.lid, args.output, gap_mm=args.gap_mm, overwrite=args.force
    )
    print(f"Verified {args.output}: {len(parts)} printable objects")
    for part in parts:
        print(f"  {part.name}: {len(part.mesh.triangles)} STL triangles, at {part.position}")


if __name__ == "__main__":
    main()
