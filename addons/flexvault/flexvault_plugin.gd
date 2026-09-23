@tool
extends EditorPlugin

## FlexVault EditorPlugin entry point for Godot Engine.

var _bottom_dock: FxvBottomDock
var _state_cache: FxvStateCache
var _auto_refresh_timer: Timer
var _import_refresh_debounce: Timer
var _on_resources_reimported: Callable

## A project-wide reimport is worth a checkpoint; reimporting a couple of files isn't.
const BULK_REIMPORT_SNAPSHOT_THRESHOLD := 15

## Same idea for scene saves: only snapshot if the node count changed by a lot since the last
## save (bulk delete/instantiate), not on every Ctrl+S. Keyed per scene path rather than a
## single scalar, since Godot commonly has several scenes open in tabs and saves them
## independently - comparing scene A's node count against scene B's last-seen count would
## produce a bogus delta.
const NODE_COUNT_DELTA_THRESHOLD := 10
var _last_known_node_counts: Dictionary = {} # scene_file_path (String) -> node count (int)

## One save/reimport/delete gesture can fire its signal more than once in a row - debounce so
## we don't spawn a pile of overlapping fxv processes for it.
const AUTO_SNAPSHOT_DEBOUNCE_SECONDS := 2.0
var _last_auto_snapshot_time_msec: int = -1

## Shared across every trigger (targeted and periodic alike): skip firing a new auto-snapshot
## while one is still running rather than let two `fxv snapshot` processes race the CLI's
## draft-branch head update against the same workspace - observed live in testing as a
## transient "Draft branch head commit ... not found in workspace" status error when a
## reimport-triggered snapshot and a scene-save-triggered snapshot landed close together.
var _snapshot_in_flight: bool = false
## Safety net in case snapshot_async's callback is never delivered (e.g. the background Thread
## never reaches its deferred call) - without this, a single stuck response would leave
## _snapshot_in_flight true forever and silently disable every future auto-snapshot trigger.
const SNAPSHOT_WATCHDOG_SECONDS := 120.0
var _snapshot_watchdog_timer: Timer
## Bumped on every attempt so a callback (or the watchdog) from a superseded attempt can tell
## it's stale and not clobber the state of whatever attempt is actually running now - e.g. the
## watchdog fires and clears _snapshot_in_flight, a new auto-snapshot starts, and only then the
## original (timed-out) snapshot_async call finally delivers its callback.
var _snapshot_attempt_id: int = 0

## Fallback checkpoint for entropy that none of the targeted hooks catch (e.g. editing
## resource properties directly in the Inspector). Only fires while there are pending changes;
## see FxvSettings.get_periodic_snapshot_seconds() (0 disables it).
const PERIODIC_SNAPSHOT_CHECK_INTERVAL_SECONDS := 30.0
var _periodic_snapshot_timer: Timer
var _last_periodic_snapshot_time_msec: int = -1

func _enter_tree() -> void:
	# Must run before anything below that could trigger an auto-snapshot (timers, filesystem/
	# reimport signals) - once a path is captured into a snapshot, adding it to .fxvignore no
	# longer removes it from tracking, so the default ignores have to land first.
	FxvIgnoreChecker.ensure_default_ignores()

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

	# Debounced immediate refresh when Godot notices files changed on disk (import, move,
	# delete), instead of waiting for the next 10-second poll.
	_import_refresh_debounce = Timer.new()
	_import_refresh_debounce.wait_time = 0.3
	_import_refresh_debounce.one_shot = true
	_import_refresh_debounce.timeout.connect(_on_import_refresh_debounce_timeout)
	add_child(_import_refresh_debounce)

	_on_resources_reimported = func(paths: PackedStringArray): _on_resources_reimported_handler(paths)
	var resource_fs := EditorInterface.get_resource_filesystem()
	resource_fs.filesystem_changed.connect(_on_filesystem_changed)
	resource_fs.resources_reimported.connect(_on_resources_reimported)

	# Deletions don't go through the undo stack, so they're worth an unconditional checkpoint
	# regardless of how many files are removed at once (unlike reimports, there's no small-batch
	# case that isn't worth it).
	var file_system_dock := EditorInterface.get_file_system_dock()
	file_system_dock.file_removed.connect(_on_file_removed)
	file_system_dock.folder_removed.connect(_on_folder_removed)

	# Fallback checkpoint: periodically snapshot if there are pending changes none of the
	# targeted hooks above caught (e.g. Inspector-only edits to a resource).
	_periodic_snapshot_timer = Timer.new()
	_periodic_snapshot_timer.wait_time = PERIODIC_SNAPSHOT_CHECK_INTERVAL_SECONDS
	_periodic_snapshot_timer.autostart = true
	_periodic_snapshot_timer.one_shot = false
	_periodic_snapshot_timer.timeout.connect(_on_periodic_snapshot_timer_timeout)
	add_child(_periodic_snapshot_timer)
	# Baseline so a workspace with existing pending changes doesn't snapshot immediately on
	# editor open; wait a full interval first like any other periodic tick.
	_last_periodic_snapshot_time_msec = Time.get_ticks_msec()

	_snapshot_watchdog_timer = Timer.new()
	_snapshot_watchdog_timer.wait_time = SNAPSHOT_WATCHDOG_SECONDS
	_snapshot_watchdog_timer.one_shot = true
	_snapshot_watchdog_timer.timeout.connect(_on_snapshot_watchdog_timeout)
	add_child(_snapshot_watchdog_timer)

	# Initial version check and refresh
	if FxvSettings.is_in_flexvault_repository():
		if FxvRunner.ensure_version_checked():
			# Register this plugin instance with fxv's integration registry. Best-effort:
			# failures are logged and never block editor startup.
			FxvRunner.register_integration_async()
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

	if _import_refresh_debounce != null:
		_import_refresh_debounce.queue_free()

	if _periodic_snapshot_timer != null:
		_periodic_snapshot_timer.queue_free()

	if _snapshot_watchdog_timer != null:
		_snapshot_watchdog_timer.queue_free()

	var resource_fs := EditorInterface.get_resource_filesystem()
	if resource_fs.filesystem_changed.is_connected(_on_filesystem_changed):
		resource_fs.filesystem_changed.disconnect(_on_filesystem_changed)
	if _on_resources_reimported.is_valid() and resource_fs.resources_reimported.is_connected(_on_resources_reimported):
		resource_fs.resources_reimported.disconnect(_on_resources_reimported)

	var file_system_dock := EditorInterface.get_file_system_dock()
	if file_system_dock.file_removed.is_connected(_on_file_removed):
		file_system_dock.file_removed.disconnect(_on_file_removed)
	if file_system_dock.folder_removed.is_connected(_on_folder_removed):
		file_system_dock.folder_removed.disconnect(_on_folder_removed)

	if _state_cache != null:
		_state_cache.clear()

	FxvSettings.invalidate_repo_root()
	FxvVersionGuard.reset_cached_version()


func _on_request_refresh() -> void:
	_state_cache.refresh()

func _on_timer_refresh() -> void:
	# Skip this tick rather than poll status while a snapshot is still writing its draft-branch
	# head - reading concurrently can observe a transient "commit not found" error. The next
	# 10s tick (or the refresh right after the snapshot's own filesystem_changed) picks it up.
	if _snapshot_in_flight:
		return
	if FxvSettings.is_auto_refresh_enabled() and FxvSettings.is_in_flexvault_repository():
		_state_cache.refresh(true, false) # skip remote metadata check on periodic poll, keep disk scan enabled

func _on_filesystem_changed() -> void:
	if FxvSettings.is_in_flexvault_repository():
		_import_refresh_debounce.start()

func _on_import_refresh_debounce_timeout() -> void:
	if _snapshot_in_flight:
		return
	if FxvSettings.is_auto_refresh_enabled() and FxvSettings.is_in_flexvault_repository():
		_state_cache.refresh(true, false)

func _on_resources_reimported_handler(paths: PackedStringArray) -> void:
	_on_filesystem_changed()
	# The reimport already happened by the time this fires - Godot doesn't expose a pre-reimport
	# hook - so this is a checkpoint taken right after a big batch reimport, not a true "before".
	if paths.size() >= BULK_REIMPORT_SNAPSHOT_THRESHOLD:
		_trigger_auto_snapshot("Auto-snapshot after bulk reimport (%d files)" % paths.size())

## The editor calls this as part of saving a scene. It's not a true pre-save hook (Godot doesn't
## expose one to plugins), but it's close enough, and it's the only save-adjacent signal we get.
##
## Known limitation: this reads get_edited_scene_root() - the focused scene tab - not
## necessarily the scene that was actually just written to disk. A single Ctrl+S always matches
## (the focused scene is the one being saved), but EditorInterface.save_all_scenes() can write a
## background tab while a different scene is focused, in which case this checks the wrong
## scene's node count against its baseline. There's no public API to identify which scene a
## given _save_external_data() call corresponds to, nor to read a non-focused open scene's node
## tree, so this can't be fully fixed - only the common single-scene-save case is covered.
func _save_external_data() -> void:
	if not FxvSettings.is_in_flexvault_repository():
		return

	var scene_root := EditorInterface.get_edited_scene_root()
	if scene_root == null:
		return

	var scene_path := scene_root.scene_file_path
	if scene_path.is_empty():
		return

	var current_count := _count_nodes(scene_root)
	if not _last_known_node_counts.has(scene_path):
		_last_known_node_counts[scene_path] = current_count
		return

	var baseline_count: int = _last_known_node_counts[scene_path]
	var delta := abs(current_count - baseline_count)
	if delta < NODE_COUNT_DELTA_THRESHOLD:
		# Don't advance the baseline here - a run of small saves (e.g. 9 nodes deleted, then 9
		# more) should accumulate toward the next delta instead of each save silently resetting
		# what "since the last save" means and losing the count that came before it.
		return

	_last_known_node_counts[scene_path] = current_count
	var scene_name := scene_path.get_file()
	_trigger_auto_snapshot("Auto-snapshot before scene save (%s, %d nodes changed)" % [scene_name, delta])

func _count_nodes(node: Node) -> int:
	var count := 1
	for child in node.get_children():
		count += _count_nodes(child)
	return count

## Deletions are non-undoable regardless of batch size, so unlike reimport there's no
## small-batch case that isn't worth a checkpoint.
func _on_file_removed(file: String) -> void:
	if not FxvSettings.is_in_flexvault_repository():
		return
	_trigger_auto_snapshot("Auto-snapshot after file deleted (%s)" % file.get_file())

func _on_folder_removed(folder: String) -> void:
	if not FxvSettings.is_in_flexvault_repository():
		return
	_trigger_auto_snapshot("Auto-snapshot after folder deleted (%s)" % folder.get_file())

func _on_periodic_snapshot_timer_timeout() -> void:
	if not FxvSettings.is_in_flexvault_repository():
		return

	var interval_sec := FxvSettings.get_periodic_snapshot_seconds()
	if interval_sec <= 0.0:
		return

	var now_msec := Time.get_ticks_msec()
	if _last_periodic_snapshot_time_msec >= 0 and (now_msec - _last_periodic_snapshot_time_msec) < int(interval_sec * 1000.0):
		return

	if _state_cache.get_changed_files().is_empty():
		return

	# Only mark done on success - a failed attempt retries on the next check tick instead of
	# waiting out the full interval again.
	_trigger_auto_snapshot("Auto-snapshot (periodic, pending changes)", func() -> void:
		_last_periodic_snapshot_time_msec = Time.get_ticks_msec()
	)

## Fires an `fxv snapshot`, guarded by the shared debounce and in-flight checks so every
## trigger (targeted or periodic) goes through one place. `on_success` (if given) runs only
## when the CLI call actually succeeds - used by the periodic trigger to advance its own
## retry-on-failure timestamp.
func _trigger_auto_snapshot(description: String, on_success: Callable = Callable()) -> void:
	var now_msec := Time.get_ticks_msec()
	if _last_auto_snapshot_time_msec >= 0 and (now_msec - _last_auto_snapshot_time_msec) < int(AUTO_SNAPSHOT_DEBOUNCE_SECONDS * 1000.0):
		return
	if _snapshot_in_flight:
		# Another auto-snapshot is still running - skip this one rather than run two
		# `fxv snapshot` processes concurrently against the same workspace. Same best-effort
		# spirit as the debounce above.
		return
	_last_auto_snapshot_time_msec = now_msec
	_snapshot_in_flight = true
	_snapshot_attempt_id += 1
	var this_attempt_id := _snapshot_attempt_id
	_snapshot_watchdog_timer.start()

	print("[FlexVault] Auto-snapshot fired: %s" % description)
	# Fire-and-forget - best-effort, never blocks the editor operation it's guarding.
	FxvRunner.snapshot_async(description, func(res: FxvRunner.FxvResult) -> void:
		if this_attempt_id != _snapshot_attempt_id:
			# A later attempt has already started (the watchdog gave up on this one and let a
			# new one through) - this callback is stale, don't touch state that belongs to it.
			return
		_snapshot_watchdog_timer.stop()
		_snapshot_in_flight = false
		if res.success:
			if on_success.is_valid():
				on_success.call()
		else:
			push_warning("[FlexVault] Auto-snapshot failed: " + res.error_message)
	)

func _on_snapshot_watchdog_timeout() -> void:
	if _snapshot_in_flight:
		push_warning("[FlexVault] Auto-snapshot response never arrived after %.0fs - resetting so future auto-snapshots aren't blocked." % SNAPSHOT_WATCHDOG_SECONDS)
		_snapshot_in_flight = false


func _on_menu_refresh() -> void:
	_state_cache.refresh()

func _on_menu_sync() -> void:
	if not FxvSafetyGuards.ensure_safe_to_mutate("Sync Workspace"):
		return
	FxvRunner.sync_workspace_async(func(res: FxvRunner.FxvResult) -> void:
		if res.success:
			var conflicted: Array = res.data.conflicted_files if res.data is FxvDto.WorkspaceSyncPayload else []
			FxvRunner.apply_default_resolve_preference(conflicted, func(_applied: bool) -> void:
				_state_cache.refresh()
				EditorInterface.get_resource_filesystem().scan()
			)
		else:
			push_error("[FlexVault] Sync failed: " + res.error_message)
	)

func _on_menu_docs() -> void:
	OS.shell_open("https://docs.fxv.dev")

func _on_menu_discord() -> void:
	OS.shell_open("https://discord.gg/KCMHRQBDf")
