@tool
class_name FxvSettings
extends RefCounted

## Manages FlexVault settings in EditorSettings and project repository discovery.

const SETTING_BINARY_PATH: String = "version_control/flexvault/binary_path"
const SETTING_DIFF_TOOL: String = "version_control/flexvault/diff_tool"
const SETTING_AUTO_REFRESH: String = "version_control/flexvault/auto_refresh"
const SETTING_TIMEOUT_SECONDS: String = "version_control/flexvault/timeout_seconds"

static var _cached_repo_root: String = ""
static var _searched_repo_root: bool = false

static func register_settings() -> void:
	if not Engine.is_editor_hint():
		return
	var editor_settings := EditorInterface.get_editor_settings()
	if editor_settings == null:
		return

	if not editor_settings.has_setting(SETTING_BINARY_PATH):
		editor_settings.set_setting(SETTING_BINARY_PATH, "")
	editor_settings.add_property_info({
		"name": SETTING_BINARY_PATH,
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_FILE,
		"hint_string": "*.exe" if OS.get_name() == "Windows" else ""
	})

	if not editor_settings.has_setting(SETTING_DIFF_TOOL):
		editor_settings.set_setting(SETTING_DIFF_TOOL, "")
	editor_settings.add_property_info({
		"name": SETTING_DIFF_TOOL,
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_FILE,
		"hint_string": "*.exe" if OS.get_name() == "Windows" else ""
	})

	if not editor_settings.has_setting(SETTING_AUTO_REFRESH):
		editor_settings.set_setting(SETTING_AUTO_REFRESH, true)
	editor_settings.add_property_info({
		"name": SETTING_AUTO_REFRESH,
		"type": TYPE_BOOL
	})


static func get_diff_tool() -> String:
	if not Engine.is_editor_hint():
		return ""
	var editor_settings := EditorInterface.get_editor_settings()
	if editor_settings != null and editor_settings.has_setting(SETTING_DIFF_TOOL):
		return str(editor_settings.get_setting(SETTING_DIFF_TOOL)).strip_edges()
	return ""


static func is_auto_refresh_enabled() -> bool:
	if not Engine.is_editor_hint():
		return false
	var editor_settings := EditorInterface.get_editor_settings()
	if editor_settings != null and editor_settings.has_setting(SETTING_AUTO_REFRESH):
		return bool(editor_settings.get_setting(SETTING_AUTO_REFRESH))
	return true


static func get_custom_binary_path() -> String:
	if not Engine.is_editor_hint():
		return ""
	var editor_settings := EditorInterface.get_editor_settings()
	if editor_settings != null and editor_settings.has_setting(SETTING_BINARY_PATH):
		return str(editor_settings.get_setting(SETTING_BINARY_PATH))
	return ""


static func set_custom_binary_path(path: String) -> void:
	if not Engine.is_editor_hint():
		return
	var editor_settings := EditorInterface.get_editor_settings()
	if editor_settings != null:
		editor_settings.set_setting(SETTING_BINARY_PATH, path)
	FxvVersionGuard.reset_cached_version()



static func get_effective_binary_path() -> String:
	var custom := get_custom_binary_path().strip_edges()
	if not custom.is_empty() and FileAccess.file_exists(custom):
		return custom

	var auto_disc := auto_discover_binary()
	if not auto_disc.is_empty():
		return auto_disc

	var os_name := OS.get_name()
	return "fxv.exe" if os_name == "Windows" else "fxv"


static func auto_discover_binary() -> String:
	var os_name := OS.get_name()
	var bin_name := "fxv.exe" if os_name == "Windows" else "fxv"

	if os_name == "Windows":
		var local_app_data := OS.get_environment("LOCALAPPDATA")
		if not local_app_data.is_empty():
			var cand := local_app_data.path_join("fxv").path_join("bin").path_join(bin_name)
			if FileAccess.file_exists(cand):
				return cand

		var prog_files := OS.get_environment("ProgramFiles")
		if not prog_files.is_empty():
			var cand2 := prog_files.path_join("FlexVault").path_join("bin").path_join(bin_name)
			if FileAccess.file_exists(cand2):
				return cand2
	else:
		var unix_paths := [
			"/usr/local/bin/" + bin_name,
			"/opt/homebrew/bin/" + bin_name,
			OS.get_environment("HOME").path_join(".cargo/bin/" + bin_name)
		]
		for p in unix_paths:
			if FileAccess.file_exists(p):
				return p

	var path_env := OS.get_environment("PATH")
	if not path_env.is_empty():
		var sep := ";" if os_name == "Windows" else ":"
		var dirs := path_env.split(sep, false)
		for dir in dirs:
			var trimmed := dir.strip_edges()
			if not trimmed.is_empty():
				var candidate := trimmed.path_join(bin_name)
				if FileAccess.file_exists(candidate):
					return candidate

	return ""


static func get_project_root() -> String:
	return ProjectSettings.globalize_path("res://").trim_suffix("/").trim_suffix("\\")


static func get_repository_root() -> String:
	if _searched_repo_root and not _cached_repo_root.is_empty():
		return _cached_repo_root

	var current := get_project_root()
	while not current.is_empty():
		var marker := current.path_join(".fxv_workspace")
		if DirAccess.dir_exists_absolute(marker):
			_cached_repo_root = current.replace("\\", "/")
			_searched_repo_root = true
			return _cached_repo_root

		var parent := current.get_base_dir()
		if parent == current:
			break
		current = parent

	_cached_repo_root = get_project_root().replace("\\", "/")
	_searched_repo_root = true
	return _cached_repo_root


static func is_in_flexvault_repository() -> bool:
	var root := get_repository_root()
	if root.is_empty():
		return false
	return DirAccess.dir_exists_absolute(root.path_join(".fxv_workspace"))


static func invalidate_repo_root() -> void:
	_cached_repo_root = ""
	_searched_repo_root = false
