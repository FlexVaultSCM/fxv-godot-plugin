import re
import unittest

class SemVer:
    def __init__(self, major=0, minor=0, patch=0):
        self.major = major
        self.minor = minor
        self.patch = patch

    def compare_to(self, other):
        if self.major != other.major:
            return -1 if self.major < other.major else 1
        if self.minor != other.minor:
            return -1 if self.minor < other.minor else 1
        if self.patch != other.patch:
            return -1 if self.patch < other.patch else 1
        return 0

    def is_less_than(self, other):
        return self.compare_to(other) < 0

    def is_greater_than_or_equal(self, other):
        return self.compare_to(other) >= 0

    def __repr__(self):
        return f"{self.major}.{self.minor}.{self.patch}"

def parse_semver(version_str):
    if not version_str or not version_str.strip():
        return None
    cleaned = version_str.strip()
    parts = cleaned.split(".")
    if len(parts) < 2 or len(parts) > 3:
        return None
    if not parts[0].isdigit() or not parts[1].isdigit():
        return None
    major = int(parts[0])
    minor = int(parts[1])
    patch = 0
    if len(parts) >= 3:
        patch_part = parts[2]
        if "-" in patch_part:
            patch_part = patch_part.split("-")[0]
        if "+" in patch_part:
            patch_part = patch_part.split("+")[0]
        if not patch_part.isdigit():
            return None
        patch = int(patch_part)
    return SemVer(major, minor, patch)

def check_version(version_str, min_ver, max_ver):
    parsed = parse_semver(version_str)
    if parsed is None:
        return False, "Invalid version"
    if parsed.is_less_than(min_ver):
        return False, "Version too low"
    if parsed.is_greater_than_or_equal(max_ver):
        return False, "Version too high"
    return True, ""

class TestVersionGuard(unittest.TestCase):
    def setUp(self):
        self.min_ver = SemVer(0, 5, 0)
        self.max_ver = SemVer(0, 10, 0)

    def test_parse_valid(self):
        v = parse_semver("0.8.0")
        self.assertEqual((v.major, v.minor, v.patch), (0, 8, 0))

        v2 = parse_semver("0.5.1-beta+build123")
        self.assertEqual((v2.major, v2.minor, v2.patch), (0, 5, 1))

    def test_parse_invalid(self):
        self.assertIsNone(parse_semver(None))
        self.assertIsNone(parse_semver(""))
        self.assertIsNone(parse_semver("invalid"))
        self.assertIsNone(parse_semver("1.2.3.4"))

    def test_compatibility(self):
        ok, _ = check_version("0.5.0", self.min_ver, self.max_ver)
        self.assertTrue(ok)

        ok, _ = check_version("0.8.0", self.min_ver, self.max_ver)
        self.assertTrue(ok)

        ok, _ = check_version("0.9.9", self.min_ver, self.max_ver)
        self.assertTrue(ok)

        ok, _ = check_version("0.4.9", self.min_ver, self.max_ver)
        self.assertFalse(ok)

        ok, _ = check_version("0.10.0", self.min_ver, self.max_ver)
        self.assertFalse(ok)

if __name__ == "__main__":
    unittest.main()
