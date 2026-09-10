@tool
class_name FxvStateCache
extends RefCounted

## Caches workspace status, path-to-status mappings, and emits update signals.

signal state_changed()

static var _instance: FxvStateCache = null

static func get_instance() -> FxvStateCache:
	if _instance == null:
		_instance = FxvStateCache.new()
	return _instance

var _path_to_status: Dictionary = {}
var _changed_files: Array[FxvDto.FileStatusItem] = []
var _workspace_changes: Array[FxvDto.FileStatusItem] = []
var _unpublished_changes: Array[FxvDto.FileStatusItem] = []
var _latest_status: FxvDto.StatusPayload = null
var _is_refreshing: bool = false
var _last_refresh_time: float = 0.0

static func _normalize_cache_key(p: String) -> String:
	var norm := FxvMetaHelper.normalize_separators(p)
	if OS.get_name() == "Windows":
		return norm.to_lower()
	return norm

func clear() -> void:
	_latest_status = null
	_path_to_status.clear()
	_changed_files.clear()
	_workspace_changes.clear()
	_unpublished_changes.clear()

func is_refreshing() -> bool:
	return _is_refreshing

func get_latest_status() -> FxvDto.StatusPayload:
	return _latest_status

func get_status_by_path(path: String) -> FxvDto.FileStatusItem:
	if path.is_empty():
		return null
	var repo_root := FxvSettings.get_repository_root()
	var proj_root := FxvSettings.get_project_root()
	var rel := _normalize_cache_key(FxvMetaHelper.to_repo_relative_path(path, repo_root, proj_root))
	return _path_to_status.get(rel, null)


func get_changed_files() -> Array[FxvDto.FileStatusItem]:
	return _changed_files.duplicate()

func get_workspace_changes() -> Array[FxvDto.FileStatusItem]:
	return _workspace_changes.duplicate()

func get_unpublished_changes() -> Array[FxvDto.FileStatusItem]:
	return _unpublished_changes.duplicate()

func has_pending_changes(path: String) -> bool:
	var item := get_status_by_path(path)
	if item != null and (item.needs_snapshot or item.is_conflicted):
		return true

	var companion := FxvMetaHelper.get_companion_import_path(path)
	var comp_item := get_status_by_path(companion)
	if comp_item != null and (comp_item.needs_snapshot or comp_item.is_conflicted):
		return true

	return false

func refresh(skip_scan: bool = false) -> void:
	if not FxvSettings.is_in_flexvault_repository():
		return

	if _is_refreshing:
		return

	_is_refreshing = true

	# Run CLI command
	var res := FxvRunner.get_status(skip_scan)
	_is_refreshing = false
	_last_refresh_time = Time.get_ticks_msec() / 1000.0

	if res.success and res.data is FxvDto.StatusPayload:
		var status_payload: FxvDto.StatusPayload = res.data
		_apply_status(status_payload)
	else:
		if not res.error_message.is_empty():
			push_warning("[FlexVault] Status refresh failed: " + res.error_message)

	state_changed.emit()

func _apply_status(status: FxvDto.StatusPayload) -> void:
	_latest_status = status
	_path_to_status.clear()
	_changed_files.clear()
	_workspace_changes.clear()
	_unpublished_changes.clear()

	for file in status.files:
		if file == null or file.path.is_empty():
			continue

		var norm_path := _normalize_cache_key(file.path)
		_path_to_status[norm_path] = file

		if file.needs_snapshot or file.is_unpublished or file.is_conflicted:
			_changed_files.append(file)

		if file.needs_snapshot or file.is_conflicted:
			_workspace_changes.append(file)

		if file.is_unpublished:
			_unpublished_changes.append(file)
