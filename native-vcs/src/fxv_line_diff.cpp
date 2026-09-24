#include "fxv_line_diff.h"

#include <algorithm>
#include <vector>

using namespace godot;

namespace {

enum class OpType { EQUAL,
	DELETE,
	INSERT };

struct Op {
	OpType type;
	int old_index; // -1 when this op has no counterpart on the old side.
	int new_index; // -1 when this op has no counterpart on the new side.
};

PackedStringArray split_lines(const String &p_text) {
	String normalized = p_text.replace("\r\n", "\n");
	// allow_empty=true so blank lines stay in the comparison instead of collapsing runs of
	// consecutive newlines.
	return normalized.split("\n", true);
}

// Plain O(n*m) LCS backtrack. Godot source files are small enough in practice that this is
// fine; the size guard below covers the pathological case (e.g. a huge generated/binary-ish
// file) by falling back to a single "whole file replaced" diff instead of hanging the editor.
std::vector<Op> diff_lines(const PackedStringArray &a, const PackedStringArray &b) {
	int n = a.size();
	int m = b.size();

	if ((int64_t)n * (int64_t)m > 4000000) {
		std::vector<Op> ops;
		ops.reserve(n + m);
		for (int i = 0; i < n; i++) {
			ops.push_back({ OpType::DELETE, i, -1 });
		}
		for (int j = 0; j < m; j++) {
			ops.push_back({ OpType::INSERT, -1, j });
		}
		return ops;
	}

	std::vector<std::vector<int>> lcs(n + 1, std::vector<int>(m + 1, 0));
	for (int i = n - 1; i >= 0; i--) {
		for (int j = m - 1; j >= 0; j--) {
			if (a[i] == b[j]) {
				lcs[i][j] = lcs[i + 1][j + 1] + 1;
			} else {
				lcs[i][j] = std::max(lcs[i + 1][j], lcs[i][j + 1]);
			}
		}
	}

	std::vector<Op> ops;
	int i = 0, j = 0;
	while (i < n && j < m) {
		if (a[i] == b[j]) {
			ops.push_back({ OpType::EQUAL, i, j });
			i++;
			j++;
		} else if (lcs[i + 1][j] >= lcs[i][j + 1]) {
			ops.push_back({ OpType::DELETE, i, -1 });
			i++;
		} else {
			ops.push_back({ OpType::INSERT, -1, j });
			j++;
		}
	}
	while (i < n) {
		ops.push_back({ OpType::DELETE, i, -1 });
		i++;
	}
	while (j < m) {
		ops.push_back({ OpType::INSERT, -1, j });
		j++;
	}
	return ops;
}

} // namespace

namespace fxv_line_diff {

TypedArray<Dictionary> build_hunks(EditorVCSInterface &p_self, const String &p_old_text, const String &p_new_text) {
	TypedArray<Dictionary> hunks;

	PackedStringArray old_lines = split_lines(p_old_text);
	PackedStringArray new_lines = split_lines(p_new_text);
	std::vector<Op> ops = diff_lines(old_lines, new_lines);

	const int context = 2;
	int op_count = (int)ops.size();
	int idx = 0;

	// One hunk per contiguous run of changes plus fixed leading/trailing context. Unlike a
	// real diff tool this doesn't merge two change runs that sit close together into a single
	// hunk - a cosmetic gap at worst, never a correctness issue.
	while (idx < op_count) {
		if (ops[idx].type == OpType::EQUAL) {
			idx++;
			continue;
		}

		int run_start = idx;
		int run_end = idx;
		while (run_end < op_count && ops[run_end].type != OpType::EQUAL) {
			run_end++;
		}

		int context_start = std::max(0, run_start - context);
		int context_end = std::min(op_count, run_end + context);

		int old_start = -1, new_start = -1, old_count = 0, new_count = 0;
		TypedArray<Dictionary> diff_lines_arr;

		for (int k = context_start; k < context_end; k++) {
			const Op &op = ops[k];
			int old_lineno = op.old_index >= 0 ? op.old_index + 1 : -1;
			int new_lineno = op.new_index >= 0 ? op.new_index + 1 : -1;
			String content;
			String status;

			if (op.type == OpType::EQUAL) {
				content = old_lines[op.old_index];
				status = " ";
				if (old_start < 0) {
					old_start = old_lineno;
				}
				if (new_start < 0) {
					new_start = new_lineno;
				}
				old_count++;
				new_count++;
			} else if (op.type == OpType::DELETE) {
				content = old_lines[op.old_index];
				status = "-";
				if (old_start < 0) {
					old_start = old_lineno;
				}
				old_count++;
			} else {
				content = new_lines[op.new_index];
				status = "+";
				if (new_start < 0) {
					new_start = new_lineno;
				}
				new_count++;
			}

			diff_lines_arr.push_back(p_self.create_diff_line(new_lineno, old_lineno, content, status));
		}

		Dictionary hunk = p_self.create_diff_hunk(std::max(old_start, 1), std::max(new_start, 1), old_count, new_count);
		hunk = p_self.add_line_diffs_into_diff_hunk(hunk, diff_lines_arr);
		hunks.push_back(hunk);

		idx = context_end;
	}

	return hunks;
}

} // namespace fxv_line_diff
