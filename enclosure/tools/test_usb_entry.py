"""Regress the enclosed USB-C port in the delivered enclosure meshes."""

import unittest

from validate import ROOT, check_usb_entry


class UsbEntryTest(unittest.TestCase):
    def test_exported_case_has_framed_usb_port(self):
        check_usb_entry(ROOT / "TB2_C3_Case_base.stl",
                        ROOT / "TB2_C3_Case_lid.stl",
                        ROOT.parent / "hardware/design.json")


if __name__ == "__main__":
    unittest.main()
