import os
import subprocess
import tempfile
import unittest

FXV_CLI = r"C:\Users\churc\Desktop\Temp\flexvault\fxv-core\target\debug\fxv.exe"

class TestFxvCliIntegration(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if not os.path.exists(FXV_CLI):
            raise unittest.SkipTest("fxv CLI debug binary not found")

    def test_version_output(self):
        res = subprocess.run([FXV_CLI, "--version"], capture_output=True, text=True)
        self.assertEqual(res.returncode, 0)
        self.assertIn("fxv", res.stdout)
        version_part = res.stdout.strip().split()[1]
        major, minor, patch = [int(p) for p in version_part.split(".")]
        self.assertGreaterEqual((major, minor, patch), (0, 5, 0))
        self.assertLess((major, minor, patch), (0, 10, 0))

if __name__ == "__main__":
    unittest.main()
