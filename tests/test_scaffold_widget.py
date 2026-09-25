import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "tools" / "scaffold_widget.py"


class ScaffoldWidgetTests(unittest.TestCase):
    def test_all_documented_tiers_generate_named_widgets(self):
        with tempfile.TemporaryDirectory() as directory:
            for tier in ("1", "1b", "1c", "2", "3", "4", "5"):
                name = f"review_widget_{tier.replace('1b', 'b').replace('1c', 'c')}"
                result = subprocess.run(
                    [sys.executable, str(SCRIPT), tier, name, "--output-dir", directory],
                    capture_output=True, text=True, check=True,
                )
                output = Path(directory) / f"{name}.lua"
                self.assertEqual(result.stdout.strip(), str(output))
                self.assertIn('name = "Review Widget', output.read_text())

    def test_existing_widget_is_not_overwritten(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "already_there.lua"
            output.write_text("original")
            result = subprocess.run(
                [sys.executable, str(SCRIPT), "1", "already_there", "--output-dir", directory],
                capture_output=True, text=True,
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(output.read_text(), "original")


if __name__ == "__main__":
    unittest.main()
