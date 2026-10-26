"""Check the delivered low floor and closed module roof against the PCB layout."""

import unittest

from validate import (
    MODEL_A_PCB_UNDERSIDE_MM,
    MODEL_A_SUPPORT_DEPTH_MM,
    MODEL_B_PCB_UNDERSIDE_MM,
    MODEL_B_PIN_TAIL_MM,
    MODEL_B_ROOT,
    MODEL_B_SUPPORT_DEPTH_MM,
    ROOT,
    check_esp_pin_clearance,
    check_module_roof,
    check_pcb_seats,
    check_solder_reliefs,
)


class LowProfileTest(unittest.TestCase):
    def test_every_through_hole_has_a_solder_well(self):
        result = check_solder_reliefs(ROOT / "TB2_C3_Case_base.stl",
                                      ROOT.parent / "hardware/design.json")
        self.assertEqual(result["covered_pads"], 48)

    def test_module_roof_and_button_accesses(self):
        check_module_roof(ROOT / "TB2_C3_Case_lid.stl",
                          ROOT.parent / "hardware/design.json")

    def test_model_a_four_seats(self):
        result = check_pcb_seats(ROOT / "TB2_C3_Case_base.stl",
                                 ROOT.parent / "hardware/design.json",
                                 MODEL_A_PCB_UNDERSIDE_MM, MODEL_A_SUPPORT_DEPTH_MM)
        self.assertEqual(result["seat_count"], 4)

    def test_model_b_four_raised_seats_and_pin_clearance(self):
        base = MODEL_B_ROOT / "TB2_C3_Case_base.stl"
        design = ROOT.parent / "hardware/design.json"
        result = check_pcb_seats(base, design, MODEL_B_PCB_UNDERSIDE_MM,
                                 MODEL_B_SUPPORT_DEPTH_MM)
        self.assertEqual(result["seat_count"], 4)
        pin_result = check_esp_pin_clearance(base, design, MODEL_B_PCB_UNDERSIDE_MM,
                                             MODEL_B_PIN_TAIL_MM)
        self.assertEqual(pin_result["module_pads_checked"], 32)
        self.assertGreaterEqual(pin_result["normal_floor_clearance_mm"], 0.3)

    def test_old_base_is_rejected_for_model_b(self):
        with self.assertRaisesRegex(RuntimeError, "PCB seat missing"):
            check_pcb_seats(ROOT / "TB2_C3_Case_base.stl",
                            ROOT.parent / "hardware/design.json",
                            MODEL_B_PCB_UNDERSIDE_MM, MODEL_B_SUPPORT_DEPTH_MM)


if __name__ == "__main__":
    unittest.main()
