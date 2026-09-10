@tool
class_name FxvDiffHelper
extends RefCounted

## Utility for diffing repository files against their published or local base revisions.

enum DiffResult { OPENED, UNCHANGED, ERROR }

static func get_base_revision_for_file(repo_relative_path: String) -> String:
	var cache := FxvStateCache.get_instance()
	var status := cache.get_latest_status()
	if status == null:
		return ""

	var file_item := cache.get_status_by_path(repo_relative_path)

	# 1. If file has pending workspace modifications, diff against local snapshot or published HEAD
	if file_item != null and file_item.needs_snapshot:
		if status.head_commit != null:
			if status.head_commit.local_snapshot != null:
				return status.head_commit.local_snapshot.revision_display
			if status.head_commit.published_head != null:
				return status.head_commit.published_head.revision_display
		if status.sync_status != null and status.sync_status.synced_revision != null:
			if not status.current_branch.is_empty():
				return "%s.%s" % [status.current_branch, str(status.sync_status.synced_revision)]
			return str(status.sync_status.synced_revision)

	# 2. If file has unpublished changes, prefer the published remote base
	if status.sync_status != null and status.sync_status.synced_revision != null:
		if not status.current_branch.is_empty():
			return "%s.%s" % [status.current_branch, str(status.sync_status.synced_revision)]
		return str(status.sync_status.synced_revision)

	if status.head_commit != null and status.head_commit.published_head != null:
		return status.head_commit.published_head.revision_display

	# 3. Fall back to local snapshot
	if status.head_commit != null and status.head_commit.local_snapshot != null:
		return status.head_commit.local_snapshot.revision_display

	return ""


static func diff_file_against_base(repo_relative_path: String, explicit_base_revision: String = "") -> DiffResult:
	if repo_relative_path.is_empty():
		return DiffResult.ERROR

	var base_rev := explicit_base_revision
	if base_rev.is_empty():
		base_rev = get_base_revision_for_file(repo_relative_path)

	if base_rev.is_empty():
		push_warning("[FlexVault] No base revision available to compare '%s' against." % repo_relative_path)
		return DiffResult.ERROR

	var repo_root := FxvSettings.get_repository_root()
	var working_file := FxvMetaHelper.to_absolute_path(repo_relative_path, repo_root)

	# Create temporary directory and file for base version
	var temp_dir := OS.get_user_data_dir().path_join("flexvault_diff")
	DirAccess.make_dir_recursive_absolute(temp_dir)

	var safe_rev := base_rev.replace(".", "_").replace("/", "_").replace("\\", "_")
	var base_filename := "%s_%s" % [safe_rev, repo_relative_path.get_file()]
	var base_temp_path := temp_dir.path_join(base_filename)

	var success := FxvRunner.cat_to_file(repo_relative_path, base_rev, base_temp_path)
	if not success:
		push_error("[FlexVault] Failed to retrieve base revision '%s' of '%s'." % [base_rev, repo_relative_path])
		return DiffResult.ERROR

	if _files_identical(base_temp_path, working_file):
		DirAccess.remove_absolute(base_temp_path)
		return DiffResult.UNCHANGED

	open_diff_tool(base_temp_path, working_file)
	return DiffResult.OPENED


static func diff_file_between_revisions(repo_relative_path: String, revision_a: String, revision_b: String) -> DiffResult:
	if repo_relative_path.is_empty() or revision_a.is_empty() or revision_b.is_empty():
		return DiffResult.ERROR

	var temp_dir := OS.get_user_data_dir().path_join("flexvault_diff")
	DirAccess.make_dir_recursive_absolute(temp_dir)

	var safe_a := revision_a.replace(".", "_").replace("/", "_").replace("\\", "_")
	var safe_b := revision_b.replace(".", "_").replace("/", "_").replace("\\", "_")
	var temp_path_a := temp_dir.path_join("%s_%s" % [safe_a, repo_relative_path.get_file()])
	var temp_path_b := temp_dir.path_join("%s_%s" % [safe_b, repo_relative_path.get_file()])

	if not FxvRunner.cat_to_file(repo_relative_path, revision_a, temp_path_a):
		push_error("[FlexVault] Failed to retrieve revision '%s' of '%s'." % [revision_a, repo_relative_path])
		return DiffResult.ERROR
	if not FxvRunner.cat_to_file(repo_relative_path, revision_b, temp_path_b):
		push_error("[FlexVault] Failed to retrieve revision '%s' of '%s'." % [revision_b, repo_relative_path])
		return DiffResult.ERROR

	if _files_identical(temp_path_a, temp_path_b):
		DirAccess.remove_absolute(temp_path_a)
		DirAccess.remove_absolute(temp_path_b)
		return DiffResult.UNCHANGED

	open_diff_tool(temp_path_a, temp_path_b)
	return DiffResult.OPENED


## True only when both files exist and hash identically. A missing working file (e.g. the
## file was deleted in the workspace) or missing base is never reported as "identical" —
## that is a real difference worth showing in the diff tool, not a no-op.
static func _files_identical(path_a: String, path_b: String) -> bool:
	if not (FileAccess.file_exists(path_a) and FileAccess.file_exists(path_b)):
		return false
	var hash_a := FileAccess.get_md5(path_a)
	return not hash_a.is_empty() and hash_a == FileAccess.get_md5(path_b)


static func open_diff_tool(left_path: String, right_path: String) -> void:
	# 1. Custom tool from EditorSettings or environment
	var custom_diff_tool := FxvSettings.get_diff_tool()
	if custom_diff_tool.is_empty():
		custom_diff_tool = OS.get_environment("FXV_DIFF_TOOL")
	if custom_diff_tool.is_empty():
		custom_diff_tool = OS.get_environment("DIFF")

	if not custom_diff_tool.is_empty():
		var pid := OS.create_process(custom_diff_tool, [left_path, right_path], false)
		if pid > 0:
			return

	# 2. Check popular diff tools
	var candidates: Array = []
	var os_name := OS.get_name()
	if os_name == "Windows":
		var prog_files := OS.get_environment("ProgramFiles")
		var local_app_data := OS.get_environment("LOCALAPPDATA")

		candidates.append("code.cmd")
		candidates.append("code")
		if not prog_files.is_empty():
			candidates.append(prog_files.path_join("Beyond Compare 4").path_join("BCompare.exe"))
			candidates.append(prog_files.path_join("Beyond Compare 5").path_join("BCompare.exe"))
			candidates.append(prog_files.path_join("WinMerge").path_join("WinMergeU.exe"))
			candidates.append(prog_files.path_join("KDiff3").path_join("kdiff3.exe"))
		if not local_app_data.is_empty():
			candidates.append(local_app_data.path_join("Programs").path_join("Microsoft VS Code").path_join("Code.exe"))
	else:
		candidates = ["code", "bcompare", "opendiff", "meld", "kdiff3"]

	for cand in candidates:
		var cand_str: String = str(cand)
		var is_code := cand_str.ends_with("code") or cand_str.ends_with("Code.exe") or cand_str.ends_with("code.cmd")
		var diff_args := ["--diff", left_path, right_path] if is_code else [left_path, right_path]

		if (cand_str.contains("/") or cand_str.contains("\\")) and not FileAccess.file_exists(cand_str):
			continue

		var pid := OS.create_process(cand_str, diff_args, false)
		if pid > 0:
			return

	# Fallback: open directory or file
	OS.shell_open(ProjectSettings.globalize_path(right_path))

