import configparser
import ctypes
import os
import unittest

REPO_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GDEXTENSION_PATH = os.path.join(REPO_DIR, "addons", "flexvault_vcs", "flexvault_vcs.gdextension")


def split_lines(text: str) -> list:
    if not text:
        return []
    normalized = text.replace("\r\n", "\n")
    if normalized.endswith("\n"):
        normalized = normalized[:-1]
    if not normalized:
        return [""]
    return normalized.split("\n")


def diff_lines(a: list, b: list) -> list:
    n = len(a)
    m = len(b)
    if n * m > 4000000:
        ops = [("DELETE", i, -1) for i in range(n)]
        ops.extend([("INSERT", -1, j) for j in range(m)])
        return ops

    lcs = [[0] * (m + 1) for _ in range(n + 1)]
    for i in range(n - 1, -1, -1):
        for j in range(m - 1, -1, -1):
            if a[i] == b[j]:
                lcs[i][j] = lcs[i + 1][j + 1] + 1
            else:
                lcs[i][j] = max(lcs[i + 1][j], lcs[i][j + 1])

    ops = []
    i, j = 0, 0
    while i < n and j < m:
        if a[i] == b[j]:
            ops.append(("EQUAL", i, j))
            i += 1
            j += 1
        elif lcs[i + 1][j] >= lcs[i][j + 1]:
            ops.append(("DELETE", i, -1))
            i += 1
        else:
            ops.append(("INSERT", -1, j))
            j += 1
    while i < n:
        ops.append(("DELETE", i, -1))
        i += 1
    while j < m:
        ops.append(("INSERT", -1, j))
        j += 1
    return ops


def build_hunks(old_text: str, new_text: str, context: int = 2) -> list:
    old_lines = split_lines(old_text)
    new_lines = split_lines(new_text)
    ops = diff_lines(old_lines, new_lines)

    hunks = []
    op_count = len(ops)
    idx = 0

    while idx < op_count:
        if ops[idx][0] == "EQUAL":
            idx += 1
            continue

        run_start = idx
        run_end = idx
        while run_end < op_count:
            if ops[run_end][0] != "EQUAL":
                run_end += 1
            else:
                lookahead = run_end
                while lookahead < op_count and ops[lookahead][0] == "EQUAL":
                    lookahead += 1
                if lookahead < op_count and (lookahead - run_end) <= 2 * context:
                    run_end = lookahead
                else:
                    break

        context_start = max(0, run_start - context)
        context_end = min(op_count, run_end + context)

        hunk_ops = ops[context_start:context_end]
        hunks.append(hunk_ops)
        idx = context_end

    return hunks


class TestNativeVcsExtension(unittest.TestCase):
    def test_gdextension_manifest_structure(self):
        self.assertTrue(os.path.exists(GDEXTENSION_PATH), "flexvault_vcs.gdextension must exist")
        parser = configparser.ConfigParser()
        parser.read(GDEXTENSION_PATH)

        self.assertIn("configuration", parser.sections())
        self.assertEqual(parser.get("configuration", "entry_symbol").strip('"'), "fxv_vcs_library_init")
        self.assertEqual(parser.get("configuration", "compatibility_minimum").strip('"'), "4.1")
        self.assertEqual(parser.get("configuration", "reloadable").strip('"'), "false")

        self.assertIn("libraries", parser.sections())
        libs = dict(parser.items("libraries"))
        self.assertIn("windows.debug.x86_64", libs)
        self.assertIn("windows.release.x86_64", libs)
        self.assertIn("linux.debug.x86_64", libs)
        self.assertIn("linux.release.x86_64", libs)
        self.assertIn("macos.debug", libs)
        self.assertIn("macos.release", libs)

    def test_line_diff_added_file(self):
        old_text = ""
        new_text = "Line 1\nLine 2\n"
        hunks = build_hunks(old_text, new_text)
        self.assertEqual(len(hunks), 1)
        hunk = hunks[0]
        self.assertEqual(len(hunk), 2)
        self.assertTrue(all(op[0] == "INSERT" for op in hunk))
        self.assertEqual(hunk[0][2], 0)
        self.assertEqual(hunk[1][2], 1)

    def test_line_diff_deleted_file(self):
        old_text = "Line 1\nLine 2\n"
        new_text = ""
        hunks = build_hunks(old_text, new_text)
        self.assertEqual(len(hunks), 1)
        hunk = hunks[0]
        self.assertEqual(len(hunk), 2)
        self.assertTrue(all(op[0] == "DELETE" for op in hunk))
        self.assertEqual(hunk[0][1], 0)
        self.assertEqual(hunk[1][1], 1)

    def test_line_diff_identical_text(self):
        text = "Line 1\nLine 2\nLine 3\n"
        hunks = build_hunks(text, text)
        self.assertEqual(len(hunks), 0, "Identical text should yield 0 hunks")

    def test_line_diff_coalescing_adjacent_runs(self):
        # 1 equal line separating two edits: should merge into 1 hunk
        old_text = "A\nB\nC\nD\nE\nF\nG\n"
        new_text = "A\nB_mod\nC\nD_mod\nE\nF\nG\n"
        hunks = build_hunks(old_text, new_text, context=2)
        self.assertEqual(len(hunks), 1, "Edits separated by <= 2*context should coalesce into 1 hunk")

    def test_line_diff_separating_distant_runs(self):
        # 10 equal lines separating two edits: should form 2 distinct hunks
        old_lines = ["header"] + [f"eq_{i}" for i in range(10)] + ["footer"]
        new_lines = ["header_mod"] + [f"eq_{i}" for i in range(10)] + ["footer_mod"]
        old_text = "\n".join(old_lines) + "\n"
        new_text = "\n".join(new_lines) + "\n"
        hunks = build_hunks(old_text, new_text, context=2)
        self.assertEqual(len(hunks), 2, "Edits separated by > 2*context should form 2 distinct hunks")

    def test_windows_dll_export_if_built(self):
        dll_path = os.path.join(
            REPO_DIR, "addons", "flexvault_vcs", "bin", "libfxv_vcs.windows.template_debug.x86_64.dll"
        )
        if not os.path.exists(dll_path):
            self.skipTest("DLL not built locally, skipping export check")

        # Load library and check export
        dll = ctypes.CDLL(dll_path)
        init_fn = getattr(dll, "fxv_vcs_library_init", None)
        self.assertIsNotNone(init_fn, "fxv_vcs_library_init symbol must be exported by the DLL")


if __name__ == "__main__":
    unittest.main()
