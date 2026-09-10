import os
import unittest

def normalize_separators(path):
    if not path:
        return ""
    norm = path.replace("\\", "/")
    while norm.endswith("/") and len(norm) > 1:
        norm = norm[:-1]
    return norm

def is_import_file(path):
    return bool(path and path.endswith(".import"))

def is_uid_file(path):
    return bool(path and path.endswith(".uid"))

def get_logical_asset_path(path):
    if not path:
        return ""
    if is_import_file(path):
        return path[:-len(".import")]
    if is_uid_file(path):
        return path[:-len(".uid")]
    return path

def get_companion_import_path(path):
    if not path:
        return ""
    if is_import_file(path):
        return path
    return path + ".import"

def get_companion_uid_path(path):
    if not path:
        return ""
    if is_uid_file(path):
        return path
    return path + ".uid"

def to_repo_relative_path(path, repo_root, project_root=""):
    if not path:
        return ""
    norm_path = normalize_separators(path)
    norm_repo = normalize_separators(repo_root)

    if norm_path.startswith("res://"):
        norm_path = norm_path[6:]
        if project_root:
            norm_proj = normalize_separators(project_root)
            norm_path = normalize_separators(os.path.join(norm_proj, norm_path))

    if os.path.isabs(norm_path):
        if norm_path == norm_repo:
            return ""
        if norm_path.startswith(norm_repo + "/"):
            return norm_path[len(norm_repo) + 1:]
        return norm_path

    return norm_path

def expand_with_companions(paths, repo_root, known_files=None):
    if known_files is None:
        known_files = []
    result = set()
    for raw in paths:
        if not raw or not raw.strip():
            continue
        rel = to_repo_relative_path(raw, repo_root)
        result.add(rel)
        if is_import_file(rel):
            result.add(get_logical_asset_path(rel))
        else:
            result.add(get_companion_import_path(rel))

        if is_uid_file(rel):
            result.add(get_logical_asset_path(rel))
        else:
            result.add(get_companion_uid_path(rel))
    return sorted(list(result))

class TestMetaHelper(unittest.TestCase):
    def test_normalize_separators(self):
        self.assertEqual(normalize_separators("res:\\scenes\\main.tscn"), "res:/scenes/main.tscn")
        self.assertEqual(normalize_separators("C:\\repo\\project\\"), "C:/repo/project")
        self.assertEqual(normalize_separators(""), "")

    def test_companion_paths(self):
        asset = "icon.svg"
        self.assertEqual(get_companion_import_path(asset), "icon.svg.import")
        self.assertEqual(get_companion_uid_path(asset), "icon.svg.uid")
        self.assertEqual(get_logical_asset_path("icon.svg.import"), "icon.svg")
        self.assertEqual(get_logical_asset_path("icon.svg.uid"), "icon.svg")

    def test_repo_relative_res_path(self):
        repo_root = "C:/Workspace"
        proj_root = "C:/Workspace/Game"
        res_path = "res://scenes/level1.tscn"
        rel = to_repo_relative_path(res_path, repo_root, proj_root)
        self.assertEqual(rel, "Game/scenes/level1.tscn")

    def test_expand_with_companions(self):
        repo_root = "C:/Workspace"
        expanded = expand_with_companions(["scenes/player.tscn"], repo_root)
        self.assertIn("scenes/player.tscn", expanded)
        self.assertIn("scenes/player.tscn.import", expanded)
        self.assertIn("scenes/player.tscn.uid", expanded)

if __name__ == "__main__":
    unittest.main()
