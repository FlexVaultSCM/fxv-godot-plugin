@tool
extends EditorPlugin

## FlexVault EditorPlugin entry point for Godot Engine.

var _bottom_dock: FxvBottomDock
var _state_cache: FxvStateCache
var _auto_refresh_timer: Timer

func _enter_tree() -> void:
	FxvSettings.register_settings()
	_state_cache = FxvStateCache.get_instance()

	# Create bottom dock panel
	_bottom_dock = FxvBottomDock.new()
	_bottom_dock.request_refresh.connect(_on_request_refresh)
	add_control_to_bottom_panel(_bottom_dock, "FlexVault")

	# Add top menu entry under Project
	add_tool_menu_item("FlexVault: Refresh Status", Callable(self, "_on_menu_refresh"))
	add_tool_menu_item("FlexVault: Sync Workspace", Callable(self, "_on_menu_sync"))
	add_tool_menu_item("FlexVault: Documentation", Callable(self, "_on_menu_docs"))
	add_tool_menu_item("FlexVault: Discord Feedback", Callable(self, "_on_menu_discord"))
	FxvContextMenu.register_actions(self)

	# Auto-refresh timer (polls status every 10 seconds if editor is active)
	_auto_refresh_timer = Timer.new()
	_auto_refresh_timer.wait_time = 10.0
	_auto_refresh_timer.autostart = true
	_auto_refresh_timer.one_shot = false
	_auto_refresh_timer.timeout.connect(_on_timer_refresh)
	add_child(_auto_refresh_timer)

	# Initial version check and refresh
	if FxvSettings.is_in_flexvault_repository():
		FxvRunner.ensure_version_checked()
		_state_cache.refresh()

func _exit_tree() -> void:
	remove_tool_menu_item("FlexVault: Refresh Status")
	remove_tool_menu_item("FlexVault: Sync Workspace")
	remove_tool_menu_item("FlexVault: Documentation")
	remove_tool_menu_item("FlexVault: Discord Feedback")
	FxvContextMenu.unregister_actions(self)

	if _bottom_dock != null:
		remove_control_from_bottom_panel(_bottom_dock)
		_bottom_dock.queue_free()

	if _auto_refresh_timer != null:
		_auto_refresh_timer.queue_free()

	if _state_cache != null:
		_state_cache.clear()

	FxvSettings.invalidate_repo_root()
	FxvVersionGuard.reset_cached_version()


func _on_request_refresh() -> void:
	_state_cache.refresh()

func _on_timer_refresh() -> void:
	if FxvSettings.is_auto_refresh_enabled() and FxvSettings.is_in_flexvault_repository():
		_state_cache.refresh(true, false) # skip remote metadata check on periodic poll, keep disk scan enabled


func _on_menu_refresh() -> void:
	_state_cache.refresh()

func _on_menu_sync() -> void:
	if not FxvSafetyGuards.ensure_safe_to_mutate("Sync Workspace"):
		return
	FxvRunner.sync_workspace_async(func(res: FxvRunner.FxvResult) -> void:
		if res.success:
			_state_cache.refresh()
			EditorInterface.get_resource_filesystem().scan()
		else:
			push_error("[FlexVault] Sync failed: " + res.error_message)
	)

func _on_menu_docs() -> void:
	OS.shell_open("https://docs.fxv.dev")

func _on_menu_discord() -> void:
	OS.shell_open("https://discord.gg/KCMHRQBDf")
