import json
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
    if cleaned.startswith("v") or cleaned.startswith("V"):
        cleaned = cleaned[1:]
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

def process_remote_manifest(json_text, current_plugin_version, local_cli_version=""):
    res = {"update_available": False, "version": "", "cli_range": "", "cli_compatible": True}
    if not json_text or not json_text.strip():
        return res
    try:
        parsed = json.loads(json_text)
    except Exception:
        return res
    if not isinstance(parsed, dict):
        return res

    remote_ver_str = str(parsed.get("plugin_version", ""))
    remote_semver = parse_semver(remote_ver_str)
    if remote_semver is None:
        return res

    current_semver = parse_semver(current_plugin_version)
    if current_semver is None or not current_semver.is_less_than(remote_semver):
        return res

    cli_range_str = ""
    compat = parsed.get("cli_compatibility", {})
    cli_is_compatible = True

    if isinstance(compat, dict) and "min" in compat and "max" in compat:
        min_str = str(compat["min"])
        max_str = str(compat["max"])
        cli_range_str = f">= {min_str}, < {max_str}"

        if local_cli_version:
            local_cli_semver = parse_semver(local_cli_version)
            min_semver = parse_semver(min_str)
            max_semver = parse_semver(max_str)
            if local_cli_semver is not None:
                if min_semver is not None and local_cli_semver.is_less_than(min_semver):
                    cli_is_compatible = False
                if max_semver is not None and local_cli_semver.is_greater_than_or_equal(max_semver):
                    cli_is_compatible = False

    res["cli_range"] = cli_range_str
    res["cli_compatible"] = cli_is_compatible

    if not cli_is_compatible:
        return res

    res["update_available"] = True
    res["version"] = remote_ver_str
    return res

class TestVersionGuard(unittest.TestCase):
    def setUp(self):
        self.min_ver = SemVer(0, 11, 0)
        self.max_ver = SemVer(0, 13, 0)

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
        ok, _ = check_version("0.11.0", self.min_ver, self.max_ver)
        self.assertTrue(ok)

        ok, _ = check_version("0.11.5", self.min_ver, self.max_ver)
        self.assertTrue(ok)

        ok, _ = check_version("0.12.0", self.min_ver, self.max_ver)
        self.assertTrue(ok)

        ok, _ = check_version("0.12.1", self.min_ver, self.max_ver)
        self.assertTrue(ok)

        ok, _ = check_version("0.10.1", self.min_ver, self.max_ver)
        self.assertFalse(ok)

        ok, _ = check_version("0.10.9", self.min_ver, self.max_ver)
        self.assertFalse(ok)

        ok, _ = check_version("0.9.0", self.min_ver, self.max_ver)
        self.assertFalse(ok)

        ok, _ = check_version("0.13.0", self.min_ver, self.max_ver)
        self.assertFalse(ok)

        ok, _ = check_version("0.13.0-rc1", self.min_ver, self.max_ver)
        self.assertFalse(ok)

    def test_parse_prefix(self):
        v = parse_semver("v0.9.0")
        self.assertIsNotNone(v)
        self.assertEqual((v.major, v.minor, v.patch), (0, 9, 0))

        v2 = parse_semver("V1.2.3")
        self.assertIsNotNone(v2)
        self.assertEqual((v2.major, v2.minor, v2.patch), (1, 2, 3))

    def test_process_remote_manifest(self):
        manifest_json = json.dumps({
            "name": "godot",
            "plugin_version": "0.9.0",
            "tag": "v0.9.0",
            "cli_compatibility": {
                "min": "0.11.0",
                "max": "0.13.0"
            }
        })

        # Update available with compatible CLI
        res = process_remote_manifest(manifest_json, "0.8.0", "0.12.0")
        self.assertTrue(res["update_available"])
        self.assertTrue(res["cli_compatible"])
        self.assertEqual(res["version"], "0.9.0")
        self.assertEqual(res["cli_range"], ">= 0.11.0, < 0.13.0")

        # CLI incompatible (too low) -> update not suggested
        res_old_cli = process_remote_manifest(manifest_json, "0.8.0", "0.10.5")
        self.assertFalse(res_old_cli["update_available"])
        self.assertFalse(res_old_cli["cli_compatible"])

        # CLI incompatible (too high) -> update not suggested
        res_new_cli = process_remote_manifest(manifest_json, "0.8.0", "0.13.0")
        self.assertFalse(res_new_cli["update_available"])
        self.assertFalse(res_new_cli["cli_compatible"])

        # Already up to date -> no update
        res_same = process_remote_manifest(manifest_json, "0.9.0", "0.12.0")
        self.assertFalse(res_same["update_available"])

        # Current is newer -> no update
        res_newer = process_remote_manifest(manifest_json, "1.0.0", "0.12.0")
        self.assertFalse(res_newer["update_available"])

        # Manifest with 'v' prefix
        manifest_v = json.dumps({
            "name": "godot",
            "plugin_version": "v0.9.0",
            "tag": "v0.9.0",
            "cli_compatibility": {"min": "0.11.0", "max": "0.13.0"}
        })
        res_v = process_remote_manifest(manifest_v, "0.8.0", "0.12.0")
        self.assertTrue(res_v["update_available"])

        # Malformed manifest
        self.assertFalse(process_remote_manifest("", "0.8.0")["update_available"])
        self.assertFalse(process_remote_manifest("not-json", "0.8.0")["update_available"])
        self.assertFalse(process_remote_manifest("[]", "0.8.0")["update_available"])

if __name__ == "__main__":
    unittest.main()
