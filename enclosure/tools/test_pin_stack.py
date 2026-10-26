"""Regress parsing of the measured ESP pin stack from an OpenSCAD export."""

import tempfile
import unittest
from pathlib import Path

from validate import check_pin_stack


class PinStackTest(unittest.TestCase):
    def test_combined_openscad_echo_reports_model_b_tail(self):
        with tempfile.TemporaryDirectory() as directory:
            log = Path(directory) / "base.log"
            log.write_text(
                "ECHO: case_mm = [53, 27.72, 13], "
                "esp_pin_stack_mm = [4.5, 2.5, 1.6, 0.4]\n",
                encoding="utf-8",
            )
            result = check_pin_stack(log, 4.5)
        self.assertAlmostEqual(result["pin_tail_below_shield_mm"], 0.4)

    def test_wrong_esp_pin_length_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            log = Path(directory) / "base.log"
            log.write_text(
                "ECHO: esp_pin_stack_mm = [5.4, 2.5, 1.6, 1.3]\n",
                encoding="utf-8",
            )
            with self.assertRaisesRegex(RuntimeError, "differs from the intended assembly"):
                check_pin_stack(log, 4.5)


if __name__ == "__main__":
    unittest.main()
