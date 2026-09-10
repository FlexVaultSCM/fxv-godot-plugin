@tool
class_name FxvMetaHelper
extends RefCounted

## Path and metadata utility for Godot projects tracked by FlexVault.
## Godot companion files include:
## - Import metadata: e.g. "icon.svg.import" companion to "icon.svg"
## - UID (.uid) files if present

const IMPORT_EXTENSION: String = ".import"
const UID_EXTENSION: String = ".uid"

static func normalize_separators(p_path: String) -> String:
	if p_path.is_empty():
		return ""
	var normalized := p_path.replace("\\", "/")
	while normalized.ends_with("/") and normalized.length() > 1:
		normalized = normalized.substr(0, normalized.length() - 1)
	return normalized


static func is_import_file(p_path: String) -> bool:
	if p_path.is_empty():
		return false
	return p_path.ends_with(IMPORT_EXTENSION)


static func is_uid_file(p_path: String) -> bool:
	if p_path.is_empty():
		return false
	return p_path.ends_with(UID_EXTENSION)


static func get_logical_asset_path(p_path: String) -> String:
	if p_path.is_empty():
		return ""
	if is_import_file(p_path):
		return p_path.substr(0, p_path.length() - IMPORT_EXTENSION.length())
	if is_uid_file(p_path):
		return p_path.substr(0, p_path.length() - UID_EXTENSION.length())
	return p_path


static func get_companion_import_path(p_asset_path: String) -> String:
	if p_asset_path.is_empty():
		return ""
	if is_import_file(p_asset_path):
		return p_asset_path
	return p_asset_path + IMPORT_EXTENSION


static func get_companion_uid_path(p_asset_path: String) -> String:
	if p_asset_path.is_empty():
		return ""
	if is_uid_file(p_asset_path):
		return p_asset_path
	return p_asset_path + UID_EXTENSION


static func to_repo_relative_path(p_path: String, repo_root: String, project_root: String = "") -> String:
	if p_path.is_empty():
		return ""

	var norm_path := normalize_separators(p_path)
	var norm_repo := normalize_separators(repo_root)

	# Handle Godot 'res://' prefix
	if norm_path.begins_with("res://"):
		norm_path = norm_path.substr(6) # Strip "res://"
		if not project_root.is_empty():
			var norm_proj := normalize_separators(project_root)
			norm_path = normalize_separators(norm_proj.path_join(norm_path))

	# If path is rooted / absolute
	if norm_path.is_absolute_path():
		if norm_path == norm_repo:
			return ""
		if norm_path.begins_with(norm_repo + "/"):
			return norm_path.substr(norm_repo.length() + 1)
		return norm_path

	# If already repo-relative, check if combining with repo_root exists or return as is
	return norm_path


static func to_absolute_path(p_repo_relative_path: String, repo_root: String) -> String:
	if p_repo_relative_path.is_empty():
		return normalize_separators(repo_root)

	var norm_path := normalize_separators(p_repo_relative_path)
	if norm_path.is_absolute_path():
		return norm_path

	var norm_repo := normalize_separators(repo_root)
	return normalize_separators(norm_repo.path_join(norm_path))


static func to_project_res_path(p_path: String, repo_root: String, project_root: String) -> String:
	var abs_path := to_absolute_path(p_path, repo_root)
	var norm_proj := normalize_separators(project_root)

	if abs_path == norm_proj:
		return "res://"
	if abs_path.begins_with(norm_proj + "/"):
		return "res://" + abs_path.substr(norm_proj.length() + 1)

	return abs_path


## Expands a list of file or folder paths to include companion .import and .uid files,
## but only if they actually exist on disk or in the known files list.
static func expand_with_companions(
	paths: Array,
	repo_root: String,
	known_files: Array = []
) -> Array:
	var result_set: Dictionary = {}
	var known_set: Dictionary = {}
	for kf in known_files:
		known_set[normalize_separators(str(kf))] = true

	for raw in paths:
		if str(raw).strip_edges().is_empty():
			continue

		var p_str := str(raw)
		var abs_path := to_absolute_path(p_str, repo_root)
		var repo_rel := to_repo_relative_path(abs_path, repo_root)

		var dir_access := DirAccess.open(abs_path)
		if dir_access != null:
			# It's an existing directory on disk
			_safe_enumerate_directory(abs_path, repo_root, known_set, result_set)
		else:
			# Check if it was a deleted directory in known_files
			var folder_prefix := normalize_separators(repo_rel).trim_suffix("/") + "/"
			var is_deleted_folder := false
			for kf in known_files:
				var kf_str: String = str(kf)
				if normalize_separators(kf_str).begins_with(folder_prefix):
					is_deleted_folder = true
					result_set[kf_str] = true
					_add_companion_if_appropriate(kf_str, repo_root, known_set, result_set)

			if not is_deleted_folder:
				result_set[repo_rel] = true
				_add_companion_if_appropriate(repo_rel, repo_root, known_set, result_set)

	var res_array: Array = []
	for k in result_set.keys():
		res_array.append(k)
	res_array.sort()
	return res_array


static func _add_companion_if_appropriate(
	repo_rel: String,
	repo_root: String,
	known_set: Dictionary,
	out_set: Dictionary
) -> void:
	if is_import_file(repo_rel):
		var base_asset := get_logical_asset_path(repo_rel)
		var base_abs := to_absolute_path(base_asset, repo_root)
		if FileAccess.file_exists(base_abs) or known_set.has(base_asset):
			out_set[base_asset] = true
	else:
		var companion_import := get_companion_import_path(repo_rel)
		var import_abs := to_absolute_path(companion_import, repo_root)
		if FileAccess.file_exists(import_abs) or known_set.has(companion_import):
			out_set[companion_import] = true

	if is_uid_file(repo_rel):
		var base_asset := get_logical_asset_path(repo_rel)
		var base_abs := to_absolute_path(base_asset, repo_root)
		if FileAccess.file_exists(base_abs) or known_set.has(base_asset):
			out_set[base_asset] = true
	else:
		var companion_uid := get_companion_uid_path(repo_rel)
		var uid_abs := to_absolute_path(companion_uid, repo_root)
		if FileAccess.file_exists(uid_abs) or known_set.has(companion_uid):
			out_set[companion_uid] = true


static func _safe_enumerate_directory(
	abs_dir: String,
	repo_root: String,
	known_set: Dictionary,
	out_set: Dictionary
) -> void:
	var da := DirAccess.open(abs_dir)
	if da == null:
		return

	da.list_dir_begin()
	var item_name := da.get_next()
	while not item_name.is_empty():
		if item_name != "." and item_name != ".." and item_name != ".godot" and item_name != ".fxv_workspace":
			var item_abs := abs_dir.path_join(item_name)
			if da.current_is_dir():
				_safe_enumerate_directory(item_abs, repo_root, known_set, out_set)
			else:
				var repo_rel := to_repo_relative_path(item_abs, repo_root)
				out_set[repo_rel] = true
				_add_companion_if_appropriate(repo_rel, repo_root, known_set, out_set)
		item_name = da.get_next()
	da.list_dir_end()

