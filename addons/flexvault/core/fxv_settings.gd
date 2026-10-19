@tool
class_name FxvSettings
extends RefCounted

## Manages FlexVault settings in EditorSettings and project repository discovery.

const SETTING_BINARY_PATH: String = "version_control/flexvault/binary_path"
const SETTING_DIFF_TOOL: String = "version_control/flexvault/diff_tool"
const SETTING_TIMEOUT_SECONDS: String = "version_control/flexvault/timeout_seconds"
const SETTING_DEFAULT_RESOLVE_PREFERENCE: String = "version_control/flexvault/default_resolve_preference"
const SETTING_PERIODIC_SNAPSHOT_SECONDS: String = "version_control/flexvault/periodic_snapshot_seconds"
const SETTING_FETCH_PERIOD_SECONDS: String = "version_control/flexvault/fetch_period_seconds"
const SETTING_CHECK_FOR_UPDATES: String = "version_control/flexvault/check_for_updates"

const DOCS_URL: String = "https://docs.fxv.dev/how-to/godot-plugin/"
const DISCORD_URL: String = "https://fxv.dev/discord"

const RESOLVE_PREFERENCE_ASK: int = 0
const RESOLVE_PREFERENCE_MINE: int = 1
const RESOLVE_PREFERENCE_THEIRS: int = 2

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
		# Global, not FILE: this points at an executable anywhere on disk, not a res:// resource.
		# PROPERTY_HINT_FILE's picker (and manual entry) is confined to the project filesystem.
		"hint": PROPERTY_HINT_GLOBAL_FILE,
		"hint_string": "*.exe" if OS.get_name() == "Windows" else ""
	})

	if not editor_settings.has_setting(SETTING_DIFF_TOOL):
		editor_settings.set_setting(SETTING_DIFF_TOOL, "")
	editor_settings.add_property_info({
		"name": SETTING_DIFF_TOOL,
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_GLOBAL_FILE,
		"hint_string": "*.exe" if OS.get_name() == "Windows" else ""
	})

	if not editor_settings.has_setting(SETTING_TIMEOUT_SECONDS):
		editor_settings.set_setting(SETTING_TIMEOUT_SECONDS, 0.0)
	editor_settings.add_property_info({
		"name": SETTING_TIMEOUT_SECONDS,
		"type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "0,600,1,suffix:s"
	})

	if not editor_settings.has_setting(SETTING_DEFAULT_RESOLVE_PREFERENCE):
		editor_settings.set_setting(SETTING_DEFAULT_RESOLVE_PREFERENCE, RESOLVE_PREFERENCE_ASK)
	editor_settings.add_property_info({
		"name": SETTING_DEFAULT_RESOLVE_PREFERENCE,
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "Ask Each Time:0,Keep Mine:1,Take Theirs:2"
	})

	if not editor_settings.has_setting(SETTING_PERIODIC_SNAPSHOT_SECONDS):
		editor_settings.set_setting(SETTING_PERIODIC_SNAPSHOT_SECONDS, 300.0)
	editor_settings.add_property_info({
		"name": SETTING_PERIODIC_SNAPSHOT_SECONDS,
		"type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "0,3600,1,suffix:s"
	})

	if not editor_settings.has_setting(SETTING_FETCH_PERIOD_SECONDS):
		editor_settings.set_setting(SETTING_FETCH_PERIOD_SECONDS, 120.0)
	editor_settings.add_property_info({
		"name": SETTING_FETCH_PERIOD_SECONDS,
		"type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "0,3600,1,suffix:s"
	})

	if not editor_settings.has_setting(SETTING_CHECK_FOR_UPDATES):
		editor_settings.set_setting(SETTING_CHECK_FOR_UPDATES, true)
	editor_settings.add_property_info({
		"name": SETTING_CHECK_FOR_UPDATES,
		"type": TYPE_BOOL,
	})


static func get_diff_tool() -> String:
	if not Engine.is_editor_hint():
		return ""
	var editor_settings := EditorInterface.get_editor_settings()
	if editor_settings != null and editor_settings.has_setting(SETTING_DIFF_TOOL):
		return str(editor_settings.get_setting(SETTING_DIFF_TOOL)).strip_edges()
	return ""



## Seconds to wait for an async CLI call before it is reported as timed out. 0 disables
## the watchdog (the default): the editor waits indefinitely, matching prior behavior.
static func get_command_timeout_seconds() -> float:
	if not Engine.is_editor_hint():
		return 0.0
	var editor_settings := EditorInterface.get_editor_settings()
	if editor_settings != null and editor_settings.has_setting(SETTING_TIMEOUT_SECONDS):
		return float(editor_settings.get_setting(SETTING_TIMEOUT_SECONDS))
	return 0.0


## One of RESOLVE_PREFERENCE_ASK / _MINE / _THEIRS. When not ASK, a sync that produces
## conflicts is automatically resolved with this preference instead of leaving the files
## conflicted for a manual choice.
static func get_default_resolve_preference() -> int:
	if not Engine.is_editor_hint():
		return RESOLVE_PREFERENCE_ASK
	var editor_settings := EditorInterface.get_editor_settings()
	if editor_settings != null and editor_settings.has_setting(SETTING_DEFAULT_RESOLVE_PREFERENCE):
		return int(editor_settings.get_setting(SETTING_DEFAULT_RESOLVE_PREFERENCE))
	return RESOLVE_PREFERENCE_ASK


## Seconds between periodic auto-snapshot attempts while there are pending changes. 0
## disables the periodic fallback entirely.
static func get_periodic_snapshot_seconds() -> float:
	if not Engine.is_editor_hint():
		return 300.0
	var editor_settings := EditorInterface.get_editor_settings()
	if editor_settings != null and editor_settings.has_setting(SETTING_PERIODIC_SNAPSHOT_SECONDS):
		return float(editor_settings.get_setting(SETTING_PERIODIC_SNAPSHOT_SECONDS))
	return 300.0


## Seconds between periodic fxv fetch attempts to pull remote metadata. 0
## disables periodic fetch.
static func get_fetch_period_seconds() -> float:
	if not Engine.is_editor_hint():
		return 120.0
	var editor_settings := EditorInterface.get_editor_settings()
	if editor_settings != null and editor_settings.has_setting(SETTING_FETCH_PERIOD_SECONDS):
		return float(editor_settings.get_setting(SETTING_FETCH_PERIOD_SECONDS))
	return 120.0


## Whether to check GitHub release manifests for newer compatible plugin versions on startup.
static func get_check_for_updates() -> bool:
	if not Engine.is_editor_hint():
		return true
	var editor_settings := EditorInterface.get_editor_settings()
	if editor_settings != null and editor_settings.has_setting(SETTING_CHECK_FOR_UPDATES):
		return bool(editor_settings.get_setting(SETTING_CHECK_FOR_UPDATES))
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


## Builds an ordered list of terminal launch candidate dictionaries for the given working
## directory and OS name. Each entry has keys: "command" (String), "args" (Array[String]),
## and "open_console" (bool).
static func build_terminal_launch_candidates(working_dir: String, os_name: String = "") -> Array:
	var candidates: Array = []
	if working_dir.strip_edges().is_empty():
		return candidates

	var target_os := os_name if not os_name.is_empty() else OS.get_name()

	if target_os == "Windows":
		var win_dir := working_dir.replace("/", "\\")
		var escaped_ps_dir := win_dir.replace("'", "''")
		candidates.append({
			"command": "wt.exe",
			"args": ["-d", win_dir],
			"open_console": false
		})
		candidates.append({
			"command": "powershell.exe",
			"args": ["-NoExit", "-Command", "Set-Location -LiteralPath '%s'" % escaped_ps_dir],
			"open_console": true
		})
		candidates.append({
			"command": "cmd.exe",
			"args": ["/K", "cd /d \"%s\"" % win_dir],
			"open_console": true
		})
	elif target_os == "macOS":
		candidates.append({
			"command": "open",
			"args": ["-a", "Terminal", working_dir],
			"open_console": false
		})
	else:
		candidates.append({
			"command": "x-terminal-emulator",
			"args": ["--working-directory=" + working_dir],
			"open_console": false
		})
		candidates.append({
			"command": "gnome-terminal",
			"args": ["--working-directory=" + working_dir],
			"open_console": false
		})
		candidates.append({
			"command": "konsole",
			"args": ["--workdir", working_dir],
			"open_console": false
		})
		candidates.append({
			"command": "xfce4-terminal",
			"args": ["--working-directory=" + working_dir],
			"open_console": false
		})
		candidates.append({
			"command": "kitty",
			"args": ["--directory", working_dir],
			"open_console": false
		})
		candidates.append({
			"command": "alacritty",
			"args": ["--working-directory", working_dir],
			"open_console": false
		})
		candidates.append({
			"command": "wezterm",
			"args": ["start", "--cwd", working_dir],
			"open_console": false
		})
		candidates.append({
			"command": "xterm",
			"args": ["-e", "cd '%s' && exec ${SHELL:-/bin/sh}" % working_dir.replace("'", "'\\''")],
			"open_console": false
		})

	return candidates


## Resolves `cmd` on `PATH` (or as an explicit path) and returns the full path if found, or
## an empty string if the executable does not exist. Pre-checking before `OS.create_process`
## avoids Godot's C++ engine error spam (`ERROR: Could not create child process`) when probing
## terminal emulator candidates that are not installed on the current system.
static func resolve_executable_in_path(cmd: String, os_name: String = "") -> String:
	var trimmed := cmd.strip_edges()
	if trimmed.is_empty():
		return ""

	var target_os := os_name if not os_name.is_empty() else OS.get_name()
	if trimmed.contains("/") or trimmed.contains("\\"):
		return trimmed if FileAccess.file_exists(trimmed) else ""

	var path_env := OS.get_environment("PATH")
	if not path_env.is_empty():
		var sep := ";" if target_os == "Windows" else ":"
		var names: Array[String] = [trimmed]
		if target_os == "Windows" and not trimmed.to_lower().ends_with(".exe"):
			names.append(trimmed + ".exe")
		for dir in path_env.split(sep, false):
			var dir_trimmed := dir.strip_edges().trim_prefix("\"").trim_suffix("\"")
			if dir_trimmed.is_empty():
				continue
			for n in names:
				var candidate := dir_trimmed.path_join(n)
				if FileAccess.file_exists(candidate):
					return candidate

	if target_os == "Windows":
		var sys_root := OS.get_environment("SystemRoot")
		if not sys_root.is_empty():
			var sys32 := sys_root.path_join("System32").path_join(trimmed)
			if FileAccess.file_exists(sys32):
				return sys32
			var ps_dir := sys_root.path_join("System32").path_join("WindowsPowerShell").path_join("v1.0").path_join(trimmed)
			if FileAccess.file_exists(ps_dir):
				return ps_dir
	elif target_os == "macOS":
		if FileAccess.file_exists("/usr/bin/open") and trimmed == "open":
			return "/usr/bin/open"

	return ""


static func open_workspace_in_terminal() -> bool:
	var working_dir := get_repository_root()
	if working_dir.is_empty() or not DirAccess.dir_exists_absolute(working_dir):
		push_error("[FlexVault] Cannot open terminal: workspace directory not found.")
		return false

	var os_name := OS.get_name()
	var candidates := build_terminal_launch_candidates(working_dir, os_name)
	for cand in candidates:
		var cmd: String = cand["command"]
		if resolve_executable_in_path(cmd, os_name).is_empty():
			continue
		var args: Array = cand["args"]
		var open_console: bool = cand.get("open_console", false)
		var pid := OS.create_process(cmd, args, open_console)
		if pid > 0:
			return true

	push_error("[FlexVault] Failed to launch a terminal in '%s'." % working_dir)
	return false

