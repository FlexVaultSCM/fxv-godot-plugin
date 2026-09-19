@tool
class_name FxvIgnoreChecker
extends RefCounted

## Unconditionally excludes Godot's generated folders from FlexVault tracking. Must run before
## anything in the plugin can trigger an auto-snapshot (see flexvault_plugin.gd's _enter_tree),
## since once a path is captured into a snapshot, adding it to .fxvignore afterward no longer
## removes it from tracking - .fxvignore only keeps out paths that aren't tracked yet.

const DEFAULT_IGNORES: Array[String] = [".godot/"]

static func ensure_default_ignores() -> void:
	if not FxvSettings.is_in_flexvault_repository():
		return

	var repo_root := FxvSettings.get_repository_root()
	var missing := _get_missing_entries(repo_root)
	if missing.is_empty():
		return

	var added := FxvContextMenu._append_unique_lines(repo_root.path_join(".fxvignore"), missing)
	if added > 0:
		print("[FlexVault] Added %d default ignore(s) to .fxvignore: %s" % [added, ", ".join(missing)])


static func _get_missing_entries(repo_root: String) -> Array:
	var fxvignore_path := repo_root.path_join(".fxvignore")
	var lines: Dictionary = FxvContextMenu._read_lines(fxvignore_path).lines

	var existing := {}
	for line in lines.keys():
		if not str(line).begins_with("#"):
			existing[_normalize_entry(line)] = true

	return DEFAULT_IGNORES.filter(func(entry): return not existing.has(_normalize_entry(entry)))


# ".godot", ".godot/", ".godot/*" all normalize to ".godot".
static func _normalize_entry(entry: String) -> String:
	return entry.trim_suffix("/*").trim_suffix("/")
