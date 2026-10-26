"""Regression tests for an independent, print-oriented 3MF export."""

import struct
import tempfile
import unittest
import xml.etree.ElementTree as ET
import zipfile
from pathlib import Path

from package_3mf import MODEL_NS, create_package, verify_package


def write_tetrahedron(path: Path, origin: tuple[float, float, float]) -> None:
    """Write a small watertight binary STL at the selected source position."""
    x, y, z = origin
    points = (
        (x, y, z),
        (x + 2, y, z),
        (x, y + 3, z),
        (x, y, z + 4),
    )
    faces = ((0, 2, 1), (0, 1, 3), (0, 3, 2), (1, 2, 3))
    body = bytearray(80)
    body.extend(struct.pack("<I", len(faces)))
    for face in faces:
        vertices = tuple(axis for index in face for axis in points[index])
        body.extend(struct.pack("<12fH", 0, 0, 1, *vertices, 0))
    path.write_bytes(body)


class Package3mfTest(unittest.TestCase):
    def test_two_parts_are_on_bed_with_gap_and_unmodified_faces(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            base = root / "base.stl"
            lid = root / "lid.stl"
            output = root / "corrected.3mf"
            write_tetrahedron(base, (-7, -4, 0))
            write_tetrahedron(lid, (-7, -1.2, 0))
            parts = create_package(base, lid, output, gap_mm=8)
            verify_package(output, parts, 8)

            with zipfile.ZipFile(output) as archive:
                self.assertEqual(archive.testzip(), None)
                model = ET.fromstring(archive.read("3D/3dmodel.model"))
                self.assertNotIn(str(root).encode(), archive.read("3D/3dmodel.model"))

            ns = {"m": MODEL_NS}
            objects = model.findall("./m:resources/m:object", ns)
            items = model.findall("./m:build/m:item", ns)
            self.assertEqual(len(objects), 2)
            self.assertEqual(len(items), 2)
            self.assertEqual([item.attrib["printable"] for item in items], ["1", "1"])
            self.assertEqual(
                [len(obj.findall("./m:mesh/m:triangles/m:triangle", ns)) for obj in objects],
                [4, 4],
            )
            base_position = [float(v) for v in items[0].attrib["transform"].split()][9:]
            lid_position = [float(v) for v in items[1].attrib["transform"].split()][9:]
            self.assertAlmostEqual(lid_position[0] - base_position[0], 10)
            self.assertEqual(base_position[2], 0)
            self.assertEqual(lid_position[2], 0)

    def test_existing_output_is_preserved_without_force(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            base = root / "base.stl"
            lid = root / "lid.stl"
            output = root / "existing.3mf"
            write_tetrahedron(base, (0, 0, 0))
            write_tetrahedron(lid, (0, 0, 0))
            output.write_bytes(b"user project")
            with self.assertRaises(FileExistsError):
                create_package(base, lid, output)
            self.assertEqual(output.read_bytes(), b"user project")


if __name__ == "__main__":
    unittest.main()
