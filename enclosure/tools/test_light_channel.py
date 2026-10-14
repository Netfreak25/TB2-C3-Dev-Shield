"""Require an actual LED tube, rather than only a flat lid and blind pocket."""

import struct
import tempfile
import unittest
from pathlib import Path

from validate import ROOT, check_light_channel


class LightChannelTest(unittest.TestCase):
    def test_exported_lid_has_continuous_tube(self):
        check_light_channel(ROOT / "TB2_C3_Case_lid.stl", ROOT.parent / "hardware/design.json")

    def test_flat_roof_without_tube_is_rejected(self):
        """A closed 1.6-mm plate around D1 cannot replace the projecting wall."""
        vertices = [(x, y, z) for z in (0, 1.6) for y in (17, 25) for x in (32, 40)]
        faces = ((0, 2, 1), (1, 2, 3), (4, 5, 6), (5, 7, 6),
                 (0, 1, 4), (1, 5, 4), (2, 6, 3), (3, 6, 7),
                 (0, 4, 2), (2, 4, 6), (1, 3, 5), (3, 7, 5))
        data = bytearray(80) + struct.pack("<I", len(faces))
        for face in faces:
            coordinates = [value for index in face for value in vertices[index]]
            data += struct.pack("<12fH", 0, 0, 0, *coordinates, 0)
        with tempfile.TemporaryDirectory() as directory:
            plate = Path(directory) / "roof-without-tube.stl"
            plate.write_bytes(data)
            with self.assertRaisesRegex(RuntimeError, "Missing continuous LED tube"):
                check_light_channel(plate, ROOT.parent / "hardware/design.json")


if __name__ == "__main__":
    unittest.main()
