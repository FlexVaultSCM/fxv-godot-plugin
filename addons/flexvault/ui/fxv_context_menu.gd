@tool
class_name FxvContextMenu
extends RefCounted

## Context menu actions for Godot FileSystem dock.

static func register_actions(file_system_dock: FileSystemDock, plugin: EditorPlugin) -> void:
	if file_system_dock == null:
		return

	# FileSystemDock allows custom context menu entries or connecting to file context menu
	# In Godot 4, we can connect to file_system_dock signals or custom popups
