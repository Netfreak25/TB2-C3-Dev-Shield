"""Regress the enclosed USB-C port in the delivered enclosure meshes."""

import unittest

from validate import MODEL_B_ELEVATION_MM, MODEL_B_ROOT, ROOT, check_usb_entry


class UsbEntryTest(unittest.TestCase):
    def test_exported_case_has_framed_usb_port(self):
        check_usb_entry(ROOT / "TB2_C3_Case_base.stl",
                        ROOT / "TB2_C3_Case_lid.stl",
                        ROOT.parent / "hardware/design.json")

    def test_model_b_usb_port_is_raised_with_the_pcb(self):
        result = check_usb_entry(MODEL_B_ROOT / "TB2_C3_Case_base.stl",
                                 MODEL_B_ROOT / "TB2_C3_Case_lid.stl",
                                 ROOT.parent / "hardware/design.json", MODEL_B_ELEVATION_MM)
        self.assertAlmostEqual(result["base_port_floor_mm"], 11.5)

    def test_old_usb_port_height_is_rejected_for_model_b(self):
        with self.assertRaisesRegex(RuntimeError, "USB port is open or obstructed"):
            check_usb_entry(ROOT / "TB2_C3_Case_base.stl",
                            ROOT / "TB2_C3_Case_lid.stl",
                            ROOT.parent / "hardware/design.json", MODEL_B_ELEVATION_MM)


if __name__ == "__main__":
    unittest.main()
