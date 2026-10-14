"""Regress the PCB-to-case handedness using the actual exported lid mesh."""

import json
import struct
import tempfile
import unittest
from pathlib import Path

from validate import ROOT, check_pcb_orientation


class PcbOrientationTest(unittest.TestCase):
    def test_exported_lid_matches_released_pcb(self):
        """D1's thin cover and all connector openings follow the PCB layout."""
        check_pcb_orientation(ROOT / "TB2_C3_Case_lid.stl", ROOT.parent / "hardware/design.json")

    def test_reflected_lid_is_rejected(self):
        """Reproduce the former Y reflection while preserving a valid mesh."""
        design_path = ROOT.parent / "hardware/design.json"
        board_depth = json.loads(design_path.read_text(encoding="utf-8"))["board_mm"][1]
        data = bytearray((ROOT / "TB2_C3_Case_lid.stl").read_bytes())
        count = struct.unpack_from("<I", data, 80)[0]
        for index in range(count):
            offset = 84 + 50 * index
            values = list(struct.unpack_from("<12fH", data, offset))
            values[1] = -values[1]
            for coordinate in (4, 7, 10):
                values[coordinate] = board_depth - values[coordinate]
            values[6:9], values[9:12] = values[9:12], values[6:9]
            struct.pack_into("<12fH", data, offset, *values)
        with tempfile.TemporaryDirectory() as directory:
            mirrored = Path(directory) / "reflected-lid.stl"
            mirrored.write_bytes(data)
            with self.assertRaisesRegex(RuntimeError, "D1 location"):
                check_pcb_orientation(mirrored, design_path)


if __name__ == "__main__":
    unittest.main()
