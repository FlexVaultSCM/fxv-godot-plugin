@tool
class_name FxvVersionGuard
extends RefCounted

## Semantic version comparison and compatibility guard for FlexVault CLI.
## Pinned compatible range: [0.5.0, 0.10.0)

const MIN_MAJOR: int = 0
const MIN_MINOR: int = 5
const MIN_PATCH: int = 0

const MAX_MAJOR: int = 0
const MAX_MINOR: int = 10
const MAX_PATCH: int = 0

static var _cached_is_compatible: Variant = null
static var _cached_version_string: String = ""
static var _cached_error_message: String = ""

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

	func to_string() -> String:
		return "%d.%d.%d" % [major, minor, patch]


static func parse_semver(version_str: String) -> SemVer:
	if version_str.is_empty():
		return null
	var cleaned := version_str.strip_edges()
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
