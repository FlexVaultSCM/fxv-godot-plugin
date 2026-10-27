@tool
class_name FxvVersionGuard
extends RefCounted

## Semantic version comparison and compatibility guard for FlexVault CLI.

const MIN_MAJOR: int = 0
const MIN_MINOR: int = 11
const MIN_PATCH: int = 0

const MAX_MAJOR: int = 0
const MAX_MINOR: int = 14
const MAX_PATCH: int = 0

static var _cached_is_compatible: Variant = null
static var _cached_version_string: String = ""
static var _cached_error_message: String = ""
static var _cached_plugin_version: String = ""

class SemVer extends RefCounted:
	var major: int = 0
	var minor: int = 0
	var patch: int = 0

	func _init(p_major: int = 0, p_minor: int = 0, p_patch: int = 0) -> void:
		major = p_major
		minor = p_minor
		patch = p_patch

	func compare_to(other: SemVer) -> int:
		if major != other.major:
			return -1 if major < other.major else 1
		if minor != other.minor:
			return -1 if minor < other.minor else 1
		if patch != other.patch:
			return -1 if patch < other.patch else 1
		return 0

	func is_less_than(other: SemVer) -> bool:
		return compare_to(other) < 0

	func is_greater_than_or_equal(other: SemVer) -> bool:
		return compare_to(other) >= 0

	func _to_string() -> String:
		return "%d.%d.%d" % [major, minor, patch]


static func parse_semver(version_str: String) -> SemVer:
	if version_str.is_empty():
		return null
	var cleaned := version_str.strip_edges()
	if cleaned.begins_with("v") or cleaned.begins_with("V"):
		cleaned = cleaned.substr(1)
	var parts := cleaned.split(".")
	if parts.size() < 2 or parts.size() > 3:
		return null
	if not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return null

	var major := parts[0].to_int()
	var minor := parts[1].to_int()
	var patch := 0

	if parts.size() >= 3:
		var patch_part := parts[2]
		var dash_idx := patch_part.find("-")
		if dash_idx >= 0:
			patch_part = patch_part.substr(0, dash_idx)
		var plus_idx := patch_part.find("+")
		if plus_idx >= 0:
			patch_part = patch_part.substr(0, plus_idx)
		if not patch_part.is_valid_int():
			return null
		patch = patch_part.to_int()

	return SemVer.new(major, minor, patch)


static func check_version(version_str: String) -> Dictionary:
	# Returns {"compatible": bool, "error": String, "version": SemVer}
	if version_str.is_empty():
		return {
			"compatible": false,
			"error": "FlexVault CLI version string is missing or empty.",
			"version": null
		}

	var parsed := parse_semver(version_str)
	if parsed == null:
		return {
			"compatible": false,
			"error": "Invalid FlexVault CLI version string '%s'." % version_str,
			"version": null
		}

	var min_ver := SemVer.new(MIN_MAJOR, MIN_MINOR, MIN_PATCH)
	var max_ver := SemVer.new(MAX_MAJOR, MAX_MINOR, MAX_PATCH)

	if parsed.is_less_than(min_ver):
		return {
			"compatible": false,
			"error": "Incompatible FlexVault CLI version '%s'. This plugin requires fxv >= %s, < %s. Please upgrade your fxv CLI executable." % [version_str, min_ver.to_string(), max_ver.to_string()],
			"version": parsed
		}

	if parsed.is_greater_than_or_equal(max_ver):
		return {
			"compatible": false,
			"error": "Incompatible FlexVault CLI version '%s'. This plugin requires fxv >= %s, < %s. Please update the FlexVault Godot plugin to match your CLI version." % [version_str, min_ver.to_string(), max_ver.to_string()],
			"version": parsed
		}

	return {
		"compatible": true,
		"error": "",
		"version": parsed
	}


static func check_and_cache(version_str: String) -> bool:
	var result := check_version(version_str)
	_cached_is_compatible = result["compatible"]
	_cached_version_string = version_str
	_cached_error_message = result["error"]
	return _cached_is_compatible


static func reset_cached_version() -> void:
	_cached_is_compatible = null
	_cached_version_string = ""
	_cached_error_message = ""
	_cached_plugin_version = ""
	_available_update_version = ""
	_available_update_cli_range = ""
	_has_checked_update = false


static func set_incompatible(error_msg: String) -> void:
	_cached_is_compatible = false
	_cached_version_string = ""
	_cached_error_message = error_msg


static func is_compatible() -> Variant:
	return _cached_is_compatible


static func get_last_version_string() -> String:
	return _cached_version_string


static func get_last_error_message() -> String:
	return _cached_error_message


static func get_min_version_string() -> String:
	return SemVer.new(MIN_MAJOR, MIN_MINOR, MIN_PATCH).to_string()


static func get_max_version_string() -> String:
	return SemVer.new(MAX_MAJOR, MAX_MINOR, MAX_PATCH).to_string()


## Reads the plugin's own version from plugin.cfg (not the fxv CLI's), cached for the process.
static func get_plugin_version() -> String:
	if not _cached_plugin_version.is_empty():
		return _cached_plugin_version

	var config := ConfigFile.new()
	if config.load("res://addons/flexvault/plugin.cfg") == OK:
		_cached_plugin_version = str(config.get_value("plugin", "version", ""))
	return _cached_plugin_version


const REMOTE_VERSION_JSON_URL := "https://github.com/FlexVaultSCM/fxv-godot-plugin/releases/latest/download/version.json"
static var _available_update_version: String = ""
static var _available_update_cli_range: String = ""
static var _has_checked_update: bool = false

static func has_checked_update() -> bool:
	return _has_checked_update

static func reset_update_check_flag() -> void:
	_has_checked_update = false

static func get_available_update_version() -> String:
	return _available_update_version

static func get_available_update_cli_range() -> String:
	return _available_update_cli_range

static func set_plugin_version_override(ver: String) -> void:
	_cached_plugin_version = ver

## Evaluates a remote version.json manifest.
## If local_cli_version is omitted, falls back to the cached CLI version from get_last_version_string().
## Only marks update_available = true if the remote version is strictly newer than the current plugin
## version AND is compatible with the installed fxv CLI version.
static func process_remote_manifest(json_text: String, local_cli_version: String = "") -> Dictionary:
	var res := { "update_available": false, "version": "", "cli_range": "", "cli_compatible": true }
	if json_text.is_empty():
		return res

	var parsed = JSON.parse_string(json_text)
	if not (parsed is Dictionary):
		return res

	var remote_ver_str: String = str(parsed.get("plugin_version", ""))
	var remote_semver := parse_semver(remote_ver_str)
	if remote_semver == null:
		return res

	var current_ver_str := get_plugin_version()
	var current_semver := parse_semver(current_ver_str)
	if current_semver == null or not current_semver.is_less_than(remote_semver):
		_available_update_version = ""
		_available_update_cli_range = ""
		return res

	var cli_range_str := ""
	var compat = parsed.get("cli_compatibility", {})
	var cli_is_compatible := true

	if compat is Dictionary and compat.has("min") and compat.has("max"):
		var min_str := str(compat["min"])
		var max_str := str(compat["max"])
		cli_range_str = ">= %s, < %s" % [min_str, max_str]

		var effective_cli := local_cli_version if not local_cli_version.is_empty() else get_last_version_string()
		if not effective_cli.is_empty():
			var local_cli_semver := parse_semver(effective_cli)
			var min_semver := parse_semver(min_str)
			var max_semver := parse_semver(max_str)

			if local_cli_semver != null:
				if min_semver != null and local_cli_semver.is_less_than(min_semver):
					cli_is_compatible = false
				if max_semver != null and local_cli_semver.is_greater_than_or_equal(max_semver):
					cli_is_compatible = false

	res["cli_range"] = cli_range_str
	res["cli_compatible"] = cli_is_compatible

	# If the remote release requires a CLI version outside our local CLI range,
	# do not suggest updating to it.
	if not cli_is_compatible:
		_available_update_version = ""
		_available_update_cli_range = ""
		return res

	_available_update_version = remote_ver_str
	_available_update_cli_range = cli_range_str
	res["update_available"] = true
	res["version"] = remote_ver_str

	return res

