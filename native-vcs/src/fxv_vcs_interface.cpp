#include "fxv_vcs_interface.h"

#include "fxv_line_diff.h"
#include "fxv_process.h"

#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/variant/array.hpp>

using namespace godot;

namespace {

EditorVCSInterface::ChangeType map_change_type(const String &p_workspace_state) {
	String s = p_workspace_state.to_lower();
	if (s == "added") {
		return EditorVCSInterface::CHANGE_TYPE_NEW;
	}
	if (s == "deleted") {
		return EditorVCSInterface::CHANGE_TYPE_DELETED;
	}
	if (s == "renamed") {
		return EditorVCSInterface::CHANGE_TYPE_RENAMED;
	}
	if (s == "conflicted") {
		return EditorVCSInterface::CHANGE_TYPE_UNMERGED;
	}
	// "modified" and "maybe_changed" both surface as a plain modification - the CLI's
	// maybe_changed just means "size/mtime differs, content not yet hashed to confirm".
	return EditorVCSInterface::CHANGE_TYPE_MODIFIED;
}

// Mirrors FxvDto.CommitRef.revision_display in addons/flexvault/core/fxv_dto.gd, so the
// native diff base and the GDScript dock's diff base agree on which revision "current" means.
String revision_display(const Dictionary &p_commit_ref) {
	if (p_commit_ref.is_empty()) {
		return String();
	}
	Dictionary commit = p_commit_ref.get("commit", Dictionary());
	String branch = commit.get("branch", "");
	Variant revision = commit.get("revision", Variant());
	Variant draft_revision = commit.get("draft_revision", Variant());
	String type = commit.get("type", "");

	if (type == "draft" && draft_revision.get_type() != Variant::NIL && (int64_t)draft_revision > 0) {
		if (revision.get_type() != Variant::NIL) {
			return branch + "." + String::num_int64((int64_t)revision) + "." + String::num_int64((int64_t)draft_revision);
		}
		return branch + ".unpublished." + String::num_int64((int64_t)draft_revision);
	}
	if (revision.get_type() != Variant::NIL) {
		return branch + "." + String::num_int64((int64_t)revision);
	}
	return branch;
}

// Mirrors FxvDiffHelper.get_base_revision_for_file in
// addons/flexvault/core/fxv_diff_helper.gd.
String base_revision_for_file(const Dictionary &p_status, const String &p_file_path) {
	Array files = p_status.get("files", Array());
	bool needs_snapshot = false;
	for (int i = 0; i < files.size(); i++) {
		Dictionary f = files[i];
		if (String(f.get("path", "")) == p_file_path) {
			String ws = String(f.get("workspace_state", "")).to_lower();
			needs_snapshot = !ws.is_empty() && ws != "unchanged";
			break;
		}
	}

	Dictionary head_commit = p_status.get("head_commit", Dictionary());
	Dictionary sync_status = p_status.get("sync_status", Dictionary());
	String current_branch = p_status.get("current_branch", "");

	auto synced_revision_display = [&]() -> String {
		if (sync_status.is_empty() || sync_status.get("synced_revision", Variant()).get_type() == Variant::NIL) {
			return String();
		}
		int64_t synced = (int64_t)sync_status["synced_revision"];
		if (!current_branch.is_empty()) {
			return current_branch + "." + String::num_int64(synced);
		}
		return String::num_int64(synced);
	};

	if (needs_snapshot) {
		Dictionary local_snapshot = head_commit.get("local_snapshot", Dictionary());
		if (!local_snapshot.is_empty()) {
			return revision_display(local_snapshot);
		}
		Dictionary published_head = head_commit.get("published_head", Dictionary());
		if (!published_head.is_empty()) {
			return revision_display(published_head);
		}
		String synced = synced_revision_display();
		if (!synced.is_empty()) {
			return synced;
		}
	}

	String synced = synced_revision_display();
	if (!synced.is_empty()) {
		return synced;
	}

	Dictionary published_head = head_commit.get("published_head", Dictionary());
	if (!published_head.is_empty()) {
		return revision_display(published_head);
	}

	Dictionary local_snapshot = head_commit.get("local_snapshot", Dictionary());
	if (!local_snapshot.is_empty()) {
		return revision_display(local_snapshot);
	}

	return String();
}

} // namespace

namespace godot {

void FxvVcsInterface::_bind_methods() {
	// Nothing script-facing to expose beyond the EditorVCSInterface overrides below.
}

bool FxvVcsInterface::_initialize(const String &p_project_path) {
	repo_project_path = p_project_path;

	PackedStringArray args;
	args.push_back("status");
	args.push_back("--skip-remote-update");
	args.push_back("--skip-scan");

	fxv::CliResult res = fxv::run(args);
	if (!res.success) {
		popup_error("FlexVault VCS plugin could not start: " + res.error_message);
		return false;
	}
	return true;
}

bool FxvVcsInterface::_shut_down() {
	return true;
}

String FxvVcsInterface::_get_vcs_name() {
	return "FlexVault";
}

TypedArray<Dictionary> FxvVcsInterface::_get_modified_files_data() {
	TypedArray<Dictionary> result;

	PackedStringArray args;
	args.push_back("status");
	fxv::CliResult res = fxv::run(args);
	if (!res.success || res.data.get_type() != Variant::DICTIONARY) {
		return result;
	}

	Dictionary payload = res.data;
	Array files = payload.get("files", Array());
	for (int i = 0; i < files.size(); i++) {
		Dictionary f = files[i];
		String path = f.get("path", "");
		if (path.is_empty()) {
			continue;
		}

		Dictionary conflict = f.get("conflict_state", Dictionary());
		String workspace_state = String(f.get("workspace_state", "")).to_lower();
		bool is_conflicted = !conflict.is_empty() || workspace_state == "conflicted";

		if (is_conflicted) {
			result.push_back(create_status_file(path, EditorVCSInterface::CHANGE_TYPE_UNMERGED, EditorVCSInterface::TREE_AREA_STAGED));
			continue;
		}
		if (workspace_state.is_empty() || workspace_state == "unchanged") {
			continue;
		}

		result.push_back(create_status_file(path, map_change_type(workspace_state), EditorVCSInterface::TREE_AREA_STAGED));
	}

	return result;
}

void FxvVcsInterface::_stage_file(const String &p_file_path) {
	// No-op: FlexVault has no staging area, every pending change ships with the next snapshot.
}

void FxvVcsInterface::_unstage_file(const String &p_file_path) {
	// No-op, see _stage_file.
}

void FxvVcsInterface::_discard_file(const String &p_file_path) {
	PackedStringArray args;
	args.push_back("revert");
	args.push_back(p_file_path);
	fxv::run(args);
}

void FxvVcsInterface::_commit(const String &p_msg) {
	PackedStringArray args;
	args.push_back("snapshot");
	if (!p_msg.is_empty()) {
		args.push_back("-d");
		args.push_back(p_msg);
	}
	fxv::run(args);
}

TypedArray<Dictionary> FxvVcsInterface::_get_diff(const String &p_identifier, int32_t p_area) {
	TypedArray<Dictionary> result;

	// Per-commit history diffs aren't exposed by the fxv CLI yet - only the working-tree
	// diff (staged/unstaged) is supported in this first pass.
	if (p_area == EditorVCSInterface::TREE_AREA_COMMIT) {
		return result;
	}

	PackedStringArray status_args;
	status_args.push_back("status");
	fxv::CliResult status_res = fxv::run(status_args);
	if (!status_res.success || status_res.data.get_type() != Variant::DICTIONARY) {
		return result;
	}
	Dictionary status = status_res.data;

	String base_rev = base_revision_for_file(status, p_identifier);
	if (base_rev.is_empty()) {
		return result;
	}

	String old_content;
	fxv::cat(p_identifier, base_rev, old_content);

	String new_content;
	Ref<FileAccess> f = FileAccess::open(repo_project_path.path_join(p_identifier), FileAccess::READ);
	if (f.is_valid()) {
		new_content = f->get_as_text();
	}

	Dictionary diff_file = create_diff_file(p_identifier, p_identifier);
	TypedArray<Dictionary> hunks = fxv_line_diff::build_hunks(*this, old_content, new_content);
	diff_file = add_diff_hunks_into_diff_file(diff_file, hunks);
	result.push_back(diff_file);
	return result;
}

TypedArray<Dictionary> FxvVcsInterface::_get_previous_commits(int32_t p_max_commits) {
	TypedArray<Dictionary> result;

	PackedStringArray args;
	args.push_back("history");
	args.push_back("-n");
	args.push_back(String::num_int64(p_max_commits > 0 ? p_max_commits : 30));

	fxv::CliResult res = fxv::run(args);
	if (!res.success || res.data.get_type() != Variant::DICTIONARY) {
		return result;
	}

	Dictionary payload = res.data;
	Array entries = payload.get("entries", Array());
	for (int i = 0; i < entries.size(); i++) {
		Dictionary e = entries[i];
		String msg = e.get("description", "");
		String author = e.get("author_display_name", "");
		if (author.is_empty()) {
			author = e.get("author_id", "");
		}
		String id = e.get("commit_hash", "");
		if (id.is_empty()) {
			id = revision_display(e);
		}
		int64_t ts_millis = (int64_t)e.get("timestamp_millis_since_epoch_utc", 0);

		result.push_back(create_commit(msg, author, id, ts_millis / 1000, 0));
	}

	return result;
}

TypedArray<String> FxvVcsInterface::_get_branch_list() {
	TypedArray<String> result;

	PackedStringArray args;
	args.push_back("branch");
	args.push_back("list");
	fxv::CliResult res = fxv::run(args);
	if (!res.success || res.data.get_type() != Variant::DICTIONARY) {
		return result;
	}

	Dictionary payload = res.data;
	Array branches = payload.get("branches", Array());
	String current = _get_current_branch_name();

	for (int i = 0; i < branches.size(); i++) {
		Dictionary b = branches[i];
		String name = b.get("branch", "");
		if (name.is_empty()) {
			continue;
		}
		if (name == current) {
			result.push_front(name);
		} else {
			result.push_back(name);
		}
	}

	return result;
}

String FxvVcsInterface::_get_current_branch_name() {
	PackedStringArray args;
	args.push_back("status");
	args.push_back("--skip-remote-update");
	args.push_back("--skip-scan");

	fxv::CliResult res = fxv::run(args);
	if (!res.success || res.data.get_type() != Variant::DICTIONARY) {
		return String();
	}
	Dictionary payload = res.data;
	return payload.get("current_branch", "");
}

bool FxvVcsInterface::_checkout_branch(const String &p_branch_name) {
	PackedStringArray args;
	args.push_back("branch");
	args.push_back("switch");
	args.push_back(p_branch_name);

	fxv::CliResult res = fxv::run(args);
	return res.success;
}

} // namespace godot
