@tool
class_name FxvContextMenu
extends RefCounted

## FlexVault actions that operate on the current selection in Godot's FileSystem dock.
##
## Godot's FileSystemDock has no supported API for adding entries to its native
## right-click menu prior to Godot 4.3's EditorContextMenuPlugin, so these are exposed
## under Project > Tools instead and act on FileSystemDock.get_selected_paths() at the
## moment they're invoked. This still removes the need to find the selected file again in
## the bottom dock's flat Changes list.

const MENU_REVERT: String = "FlexVault: Revert Selection"
const MENU_DIFF: String = "FlexVault: Diff Selection Against Base"
const MENU_RESOLVE_MINE: String = "FlexVault: Resolve Selection (Mine)"
const MENU_RESOLVE_THEIRS: String = "FlexVault: Resolve Selection (Theirs)"

static var _confirm_dialog: ConfirmationDialog = null


static func register_actions(plugin: EditorPlugin) -> void:
	plugin.add_tool_menu_item(MENU_REVERT, Callable(FxvContextMenu, "_on_revert"))
	plugin.add_tool_menu_item(MENU_DIFF, Callable(FxvContextMenu, "_on_diff"))
	plugin.add_tool_menu_item(MENU_RESOLVE_MINE, Callable(FxvContextMenu, "_on_resolve").bind("mine"))
	plugin.add_tool_menu_item(MENU_RESOLVE_THEIRS, Callable(FxvContextMenu, "_on_resolve").bind("theirs"))


static func unregister_actions(plugin: EditorPlugin) -> void:
	plugin.remove_tool_menu_item(MENU_REVERT)
	plugin.remove_tool_menu_item(MENU_DIFF)
	plugin.remove_tool_menu_item(MENU_RESOLVE_MINE)
	plugin.remove_tool_menu_item(MENU_RESOLVE_THEIRS)
	if _confirm_dialog != null:
		_confirm_dialog.queue_free()
		_confirm_dialog = null


static func _get_selected_repo_paths() -> Array:
	var dock := EditorInterface.get_file_system_dock()
	if dock == null:
		return []
	var repo_root := FxvSettings.get_repository_root()
	var project_root := FxvSettings.get_project_root()
	var out: Array = []
	for p in dock.get_selected_paths():
		var rel := FxvMetaHelper.to_repo_relative_path(str(p), repo_root, project_root)
		if not rel.is_empty():
			out.append(rel)
	return out


static func _expand_selection(paths: Array) -> Array:
	var repo_root := FxvSettings.get_repository_root()
	var known: Array = []
	for item in FxvStateCache.get_instance().get_changed_files():
		known.append(item.path)
	return FxvMetaHelper.expand_with_companions(paths, repo_root, known)


static func _on_revert() -> void:
	if not FxvSettings.is_in_flexvault_repository():
		return
	var paths := _get_selected_repo_paths()
	if paths.is_empty():
		push_warning("[FlexVault] Select one or more files in the FileSystem dock first.")
		return

	var expanded := _expand_selection(paths)
	_confirm(
		"Revert %d selected item(s) to their published base? Uncommitted changes will be lost." % expanded.size(),
		func() -> void:
			if not FxvSafetyGuards.ensure_safe_to_mutate("Revert"):
				return
			FxvRunner.revert_async(expanded, func(res: FxvRunner.FxvResult) -> void:
				if res.success:
					FxvStateCache.get_instance().refresh()
					EditorInterface.get_resource_filesystem().scan()
				else:
					push_error("[FlexVault] Revert failed: " + res.error_message)
			)
	)


static func _on_diff() -> void:
	if not FxvSettings.is_in_flexvault_repository():
		return
	var paths := _get_selected_repo_paths()
	if paths.is_empty():
		push_warning("[FlexVault] Select a single file in the FileSystem dock first.")
		return
	FxvDiffHelper.diff_file_against_base(paths[0])


static func _on_resolve(mode: String) -> void:
	if not FxvSettings.is_in_flexvault_repository():
		return
	var paths := _get_selected_repo_paths()
	if paths.is_empty():
		push_warning("[FlexVault] Select one or more conflicted files in the FileSystem dock first.")
		return

	var expanded := _expand_selection(paths)
	var action_name := "Keep Mine" if mode == "mine" else "Take Theirs"
	_confirm(
		"Resolve %d selected file(s) with action: %s? This clears their conflict state." % [expanded.size(), action_name],
		func() -> void:
			if not FxvSafetyGuards.ensure_safe_to_mutate("Resolve"):
				return
			FxvRunner.resolve_async(mode, expanded, func(res: FxvRunner.FxvResult) -> void:
				if res.success:
					FxvStateCache.get_instance().refresh()
					EditorInterface.get_resource_filesystem().scan()
				else:
					push_error("[FlexVault] Resolve failed: " + res.error_message)
			)
	)


static func _confirm(message: String, on_confirmed: Callable) -> void:
	if _confirm_dialog == null:
		_confirm_dialog = ConfirmationDialog.new()
		_confirm_dialog.title = "FlexVault"
		EditorInterface.get_base_control().add_child(_confirm_dialog)

	for connection in _confirm_dialog.confirmed.get_connections():
		_confirm_dialog.confirmed.disconnect(connection["callable"])
	_confirm_dialog.confirmed.connect(on_confirmed, CONNECT_ONE_SHOT)
	_confirm_dialog.dialog_text = message
	_confirm_dialog.popup_centered()
