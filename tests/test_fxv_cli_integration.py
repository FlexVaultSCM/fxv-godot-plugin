import os
import shutil
import subprocess
import unittest

def find_fxv_binary():
    custom = os.environ.get("FXV_BIN")
    if custom and os.path.exists(custom):
        return custom
    which_path = shutil.which("fxv.exe" if os.name == "nt" else "fxv")
    if which_path and os.path.exists(which_path):
        return which_path
    repo_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    candidates = [
        os.path.join(repo_dir, "..", "fxv-core", "target", "debug", "fxv.exe" if os.name == "nt" else "fxv"),
        os.path.join(repo_dir, "..", "fxv-core", "target", "release", "fxv.exe" if os.name == "nt" else "fxv"),
        os.path.expanduser(r"~\AppData\Local\fxv\bin\fxv.exe") if os.name == "nt" else "/usr/local/bin/fxv"
    ]
    for c in candidates:
        if os.path.exists(c):
            return c
    return None

FXV_CLI = find_fxv_binary()

class TestFxvCliIntegration(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if not FXV_CLI or not os.path.exists(FXV_CLI):
            raise unittest.SkipTest("fxv CLI binary not found")


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
