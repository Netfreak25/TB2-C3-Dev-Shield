"""Check the delivered low floor and closed module roof against the PCB layout."""

import unittest

from validate import ROOT, check_module_roof, check_solder_reliefs


class LowProfileTest(unittest.TestCase):
    def test_every_through_hole_has_a_solder_well(self):
        result = check_solder_reliefs(ROOT / "TB2_C3_Case_base.stl",
                                      ROOT.parent / "hardware/design.json")
        self.assertEqual(result["covered_pads"], 48)

    def test_module_roof_and_button_accesses(self):
        check_module_roof(ROOT / "TB2_C3_Case_lid.stl",
                          ROOT.parent / "hardware/design.json")


if __name__ == "__main__":
    unittest.main()
