@tool
class_name FxvIgnoreChecker
extends RefCounted

## Prompts once per editor startup to exclude Godot's generated folders from FlexVault tracking.

const DEFAULT_IGNORES: Array[String] = [".godot/"]

const SETTING_DISMISSED_PREFIX: String = "version_control/flexvault/ignore_prompt_dismissed_"

static func check_and_prompt_on_startup() -> void:
	if not FxvSettings.is_in_flexvault_repository():
		return

	var repo_root := FxvSettings.get_repository_root()
	var missing := _get_missing_entries(repo_root)
	if missing.is_empty():
		return

	var editor_settings := EditorInterface.get_editor_settings()
	var setting_key := SETTING_DISMISSED_PREFIX + str(repo_root.hash())
	var dismissed: Array = []
	if editor_settings != null and editor_settings.has_setting(setting_key):
		dismissed = editor_settings.get_setting(setting_key)

	var to_prompt: Array = missing.filter(func(entry): return not dismissed.has(entry))
	if to_prompt.is_empty():
		return

	var dialog := ConfirmationDialog.new()
	dialog.title = "FlexVault"
	dialog.dialog_text = "Exclude Godot's generated folders from tracking?\n\n%s" % "\n".join(to_prompt)
	dialog.ok_button_text = "Add to .fxvignore"
	dialog.cancel_button_text = "Not Now"
	EditorInterface.get_base_control().add_child(dialog)

	dialog.confirmed.connect(func() -> void:
		FxvContextMenu._append_unique_lines(repo_root.path_join(".fxvignore"), to_prompt)
		print("[FlexVault] Added %d default ignore(s) to .fxvignore" % to_prompt.size())
		dialog.queue_free()
	, CONNECT_ONE_SHOT)
	dialog.canceled.connect(func() -> void:
		if editor_settings != null:
			editor_settings.set_setting(setting_key, dismissed + to_prompt)
		dialog.queue_free()
	, CONNECT_ONE_SHOT)

	dialog.popup_centered()


static func _get_missing_entries(repo_root: String) -> Array:
	var fxvignore_path := repo_root.path_join(".fxvignore")
	var existing := {}

	if FileAccess.file_exists(fxvignore_path):
		var reader := FileAccess.open(fxvignore_path, FileAccess.READ)
		if reader != null:
			var content := reader.get_as_text()
			reader.close()
			for line in content.split("\n"):
				var trimmed := line.strip_edges()
				if not trimmed.is_empty() and not trimmed.begins_with("#"):
					existing[trimmed] = true

	return DEFAULT_IGNORES.filter(func(entry): return not existing.has(entry))
