@tool
class_name FxvBottomDock
extends VBoxContainer

## Main bottom panel interface for FlexVault in Godot Editor.

signal request_refresh()

var _tabs: TabContainer
var _changes_view: VBoxContainer
var _history_view: VBoxContainer

# Changes controls
var _changes_tree: Tree
var _commit_msg_edit: TextEdit
var _snapshot_btn: Button
var _publish_btn: Button
var _revert_btn: Button
var _diff_btn: Button
var _sync_btn: Button
var _resolve_mine_btn: Button
var _resolve_theirs_btn: Button
var _refresh_btn: Button
var _status_label: Label
var _user_branch_label: Label
var _docs_btn: Button
var _discord_btn: Button

# History controls
var _history_tree: Tree
var _history_refresh_btn: Button
var _goto_btn: Button
var _history_details_tree: Tree
var _history_details_label: Label
var _change_info_cache: Dictionary = {}

var _confirm_dialog: ConfirmationDialog

func _init() -> void:
	name = "FlexVault"
	custom_minimum_size = Vector2(400, 250)

func _ready() -> void:
	_build_ui()
	_connect_signals()
	_on_state_changed()
	if FxvSettings.is_in_flexvault_repository():
		_load_history()

func _build_ui() -> void:
	_confirm_dialog = ConfirmationDialog.new()
	_confirm_dialog.title = "Confirm Revert"
	_confirm_dialog.confirmed.connect(_execute_revert)
	add_child(_confirm_dialog)

	# Top Toolbar
	var toolbar := HBoxContainer.new()
	add_child(toolbar)


	_refresh_btn = Button.new()
	_refresh_btn.text = "Refresh"
	toolbar.add_child(_refresh_btn)

	_sync_btn = Button.new()
	_sync_btn.text = "Sync Workspace"
	toolbar.add_child(_sync_btn)

	toolbar.add_spacer(false)

	_user_branch_label = Label.new()
	_user_branch_label.text = "Branch: - | User: -"
	toolbar.add_child(_user_branch_label)

	_status_label = Label.new()
	_status_label.text = "Ready"
	toolbar.add_child(_status_label)

	toolbar.add_spacer(false)

	_docs_btn = Button.new()
	_docs_btn.text = "Docs"
	_docs_btn.tooltip_text = "Open FlexVault Documentation (https://docs.fxv.dev)"
	toolbar.add_child(_docs_btn)

	_discord_btn = Button.new()
	_discord_btn.text = "Discord"
	_discord_btn.tooltip_text = "Join the FlexVault Discord community for questions and feedback"
	toolbar.add_child(_discord_btn)

	# Tab Container
	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_tabs)

	# 1. Changes Tab
	_changes_view = VBoxContainer.new()
	_changes_view.name = "Changes"
	_tabs.add_child(_changes_view)

	var changes_split := HSplitContainer.new()
	changes_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_changes_view.add_child(changes_split)

	# Left side: Changes Tree
	var tree_container := VBoxContainer.new()
	tree_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tree_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	changes_split.add_child(tree_container)

	_changes_tree = Tree.new()
	_changes_tree.columns = 3
	_changes_tree.set_column_title(0, "File")
	_changes_tree.set_column_title(1, "Status")
	_changes_tree.set_column_title(2, "Size")
	_changes_tree.column_titles_visible = true
	_changes_tree.select_mode = Tree.SELECT_MULTI
	_changes_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree_container.add_child(_changes_tree)

	# Tree actions toolbar
	var tree_actions := HBoxContainer.new()
	tree_container.add_child(tree_actions)

	_diff_btn = Button.new()
	_diff_btn.text = "Diff Base"
	tree_actions.add_child(_diff_btn)

	_revert_btn = Button.new()
	_revert_btn.text = "Revert Selected"
	tree_actions.add_child(_revert_btn)

	_resolve_mine_btn = Button.new()
	_resolve_mine_btn.text = "Resolve (Mine)"
	_resolve_mine_btn.visible = false
	tree_actions.add_child(_resolve_mine_btn)

	_resolve_theirs_btn = Button.new()
	_resolve_theirs_btn.text = "Resolve (Theirs)"
	_resolve_theirs_btn.visible = false
	tree_actions.add_child(_resolve_theirs_btn)

	# Right side: Commit / Snapshot Panel
	var commit_panel := VBoxContainer.new()
	commit_panel.custom_minimum_size = Vector2(240, 0)
	changes_split.add_child(commit_panel)

	var desc_lbl := Label.new()
	desc_lbl.text = "Description:"
	commit_panel.add_child(desc_lbl)

	_commit_msg_edit = TextEdit.new()
	_commit_msg_edit.placeholder_text = "Enter draft snapshot or publish description..."
	_commit_msg_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	commit_panel.add_child(_commit_msg_edit)

	var commit_btn_row := HBoxContainer.new()
	commit_panel.add_child(commit_btn_row)

	_snapshot_btn = Button.new()
	_snapshot_btn.text = "Snapshot"
	_snapshot_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	commit_btn_row.add_child(_snapshot_btn)

	_publish_btn = Button.new()
	_publish_btn.text = "Publish"
	_publish_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	commit_btn_row.add_child(_publish_btn)

	# 2. History Tab
	_history_view = VBoxContainer.new()
	_history_view.name = "History"
	_tabs.add_child(_history_view)

	var hist_actions := HBoxContainer.new()
	_history_view.add_child(hist_actions)

	_history_refresh_btn = Button.new()
	_history_refresh_btn.text = "Refresh History"
	hist_actions.add_child(_history_refresh_btn)

	_goto_btn = Button.new()
	_goto_btn.text = "Switch to Revision (Goto)"
	hist_actions.add_child(_goto_btn)

	var history_split := VSplitContainer.new()
	history_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_history_view.add_child(history_split)

	_history_tree = Tree.new()
	_history_tree.columns = 4
	_history_tree.set_column_title(0, "Revision")
	_history_tree.set_column_title(1, "Author")
	_history_tree.set_column_title(2, "Date/Time")
	_history_tree.set_column_title(3, "Description")
	_history_tree.column_titles_visible = true
	_history_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	history_split.add_child(_history_tree)

	var details_container := VBoxContainer.new()
	details_container.custom_minimum_size = Vector2(0, 100)
	history_split.add_child(details_container)

	_history_details_label = Label.new()
	_history_details_label.text = "Select a revision to see changed files."
	details_container.add_child(_history_details_label)

	_history_details_tree = Tree.new()
	_history_details_tree.columns = 3
	_history_details_tree.set_column_title(0, "File")
	_history_details_tree.set_column_title(1, "Action")
	_history_details_tree.set_column_title(2, "Size")
	_history_details_tree.column_titles_visible = true
	_history_details_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details_container.add_child(_history_details_tree)

func _connect_signals() -> void:
	_refresh_btn.pressed.connect(func(): request_refresh.emit())
	_snapshot_btn.pressed.connect(_on_snapshot_pressed)
	_publish_btn.pressed.connect(_on_publish_pressed)
	_sync_btn.pressed.connect(_on_sync_pressed)
	_revert_btn.pressed.connect(_on_revert_pressed)
	_diff_btn.pressed.connect(_on_diff_pressed)
	_resolve_mine_btn.pressed.connect(func(): _on_resolve_pressed("mine"))
	_resolve_theirs_btn.pressed.connect(func(): _on_resolve_pressed("theirs"))
	_tabs.tab_changed.connect(_on_tab_changed)
	_history_refresh_btn.pressed.connect(_load_history)
	_goto_btn.pressed.connect(_on_goto_pressed)
	_history_tree.item_selected.connect(_on_history_row_selected)
	_docs_btn.pressed.connect(func(): OS.shell_open("https://docs.fxv.dev"))
	_discord_btn.pressed.connect(func(): OS.shell_open("https://discord.gg/KCMHRQBDf"))

	var cache := FxvStateCache.get_instance()
	cache.state_changed.connect(_on_state_changed)

func _on_tab_changed(tab_idx: int) -> void:
	if tab_idx == 1: # History tab
		_load_history()

func _on_state_changed() -> void:
	var cache := FxvStateCache.get_instance()
	var status := cache.get_latest_status()

	if status != null:
		var behind := ""
		if status.sync_status != null and not status.sync_status.up_to_date:
			behind = " (%d revs behind)" % status.sync_status.revisions_behind
		var rev_str := status.head_revision_display
		_user_branch_label.text = "Branch: %s (%s)%s | User: %s" % [status.current_branch, rev_str, behind, status.current_user]

	_update_changes_tree()
	if _tabs.current_tab == 1:
		_load_history()

func _update_changes_tree() -> void:
	_changes_tree.clear()
	var root := _changes_tree.create_item()

	var cache := FxvStateCache.get_instance()
	var changed_files := cache.get_changed_files()

	for f in changed_files:
		var item := _changes_tree.create_item(root)
		item.set_text(0, f.path)
		item.set_text(1, f.effective_state.capitalize())

		item.set_text(2, _format_size(f.size))

		# Status color
		var col := Color.WHITE
		match f.effective_state.to_lower():
			"added": col = Color(0.3, 0.9, 0.4)
			"modified": col = Color(0.4, 0.7, 1.0)
			"deleted": col = Color(0.95, 0.3, 0.3)
			"conflicted": col = Color(1.0, 0.6, 0.2)
		item.set_custom_color(1, col)

	var has_conflicts := cache.has_conflicts()
	_resolve_mine_btn.visible = has_conflicts
	_resolve_theirs_btn.visible = has_conflicts

func _set_busy(busy: bool) -> void:
	_snapshot_btn.disabled = busy
	_publish_btn.disabled = busy
	_sync_btn.disabled = busy
	_revert_btn.disabled = busy
	_resolve_mine_btn.disabled = busy
	_resolve_theirs_btn.disabled = busy
	_goto_btn.disabled = busy
	_history_refresh_btn.disabled = busy


func _get_selected_paths() -> Array:
	var paths: Array = []
	var item := _changes_tree.get_next_selected(null)
	while item != null:
		paths.append(item.get_text(0))
		item = _changes_tree.get_next_selected(item)
	return paths

func _on_snapshot_pressed() -> void:
	if not FxvSafetyGuards.ensure_safe_to_mutate("Snapshot"):
		return
	var desc := _commit_msg_edit.text.strip_edges()
	_status_label.text = "Taking snapshot..."
	_set_busy(true)
	FxvRunner.snapshot_async(desc, func(res: FxvRunner.FxvResult) -> void:
		_set_busy(false)
		if res.success:
			_commit_msg_edit.text = ""
			_status_label.text = "Snapshot taken successfully."
			request_refresh.emit()
		else:
			_status_label.text = "Snapshot failed."
			push_error("[FlexVault] Snapshot failed: " + res.error_message)
	)

func _on_publish_pressed() -> void:
	if not FxvSafetyGuards.ensure_safe_to_mutate("Publish"):
		return
	var desc := _commit_msg_edit.text.strip_edges()
	if desc.is_empty():
		_status_label.text = "Publish requires a description."
		return
	_status_label.text = "Publishing..."
	_set_busy(true)
	FxvRunner.publish_async(desc, func(res: FxvRunner.FxvResult) -> void:
		_set_busy(false)
		if res.success:
			_commit_msg_edit.text = ""
			_status_label.text = "Published successfully."
			request_refresh.emit()
		else:
			_status_label.text = "Publish failed."
			push_error("[FlexVault] Publish failed: " + res.error_message)
	)

func _on_sync_pressed() -> void:
	if not FxvSafetyGuards.ensure_safe_to_mutate("Sync Workspace"):
		return
	_status_label.text = "Syncing workspace..."
	_set_busy(true)
	FxvRunner.sync_workspace_async(func(res: FxvRunner.FxvResult) -> void:
		_set_busy(false)
		if res.success:
			_status_label.text = "Workspace synced."
			request_refresh.emit()
			EditorInterface.get_resource_filesystem().scan()
		else:
			_status_label.text = "Sync failed."
			push_error("[FlexVault] Sync failed: " + res.error_message)
	)

func _on_revert_pressed() -> void:
	var paths := _get_selected_paths()
	if paths.size() == 0:
		_status_label.text = "No files selected to revert."
		return

	_confirm_dialog.dialog_text = "Are you sure you want to revert %d selected file(s)? Any uncommitted changes in these files will be permanently lost." % paths.size()
	_confirm_dialog.popup_centered()

func _execute_revert() -> void:
	if not FxvSafetyGuards.ensure_safe_to_mutate("Revert", false):
		return
	var paths := _get_selected_paths()
	if paths.size() == 0:
		return

	var repo_root := FxvSettings.get_repository_root()
	var known: Array = []
	for item in FxvStateCache.get_instance().get_changed_files():
		known.append(item.path)
	var expanded := FxvMetaHelper.expand_with_companions(paths, repo_root, known)

	_status_label.text = "Reverting..."
	_set_busy(true)
	FxvRunner.revert_async(expanded, func(res: FxvRunner.FxvResult) -> void:
		_set_busy(false)
		if res.success:
			_status_label.text = "Reverted %d items." % expanded.size()
			request_refresh.emit()
			EditorInterface.get_resource_filesystem().scan()
		else:
			_status_label.text = "Revert failed."
			push_error("[FlexVault] Revert failed: " + res.error_message)
	)

func _on_diff_pressed() -> void:
	var paths := _get_selected_paths()
	if paths.size() == 0:
		_status_label.text = "Select a file to diff."
		return
	_status_label.text = "Opening diff viewer..."
	FxvDiffHelper.diff_file_against_base(paths[0])

func _on_resolve_pressed(mode: String) -> void:
	if not FxvSafetyGuards.ensure_safe_to_mutate("Resolve"):
		return
	var paths := _get_selected_paths()
	var repo_root := FxvSettings.get_repository_root()
	var known: Array = []
	for item in FxvStateCache.get_instance().get_changed_files():
		known.append(item.path)
	var expanded := FxvMetaHelper.expand_with_companions(paths, repo_root, known) if paths.size() > 0 else []

	_status_label.text = "Resolving..."
	_set_busy(true)
	FxvRunner.resolve_async(mode, expanded, func(res: FxvRunner.FxvResult) -> void:
		_set_busy(false)
		if res.success:
			_status_label.text = "Resolved conflict(s)."
			request_refresh.emit()
			EditorInterface.get_resource_filesystem().scan()
		else:
			_status_label.text = "Resolve failed."
			push_error("[FlexVault] Resolve failed: " + res.error_message)
	)

func _load_history() -> void:
	_history_tree.clear()
	_history_tree.create_item()
	_history_details_tree.clear()
	_history_details_label.text = "Select a revision to see changed files."
	_change_info_cache.clear()

	_status_label.text = "Loading history..."
	_set_busy(true)
	FxvRunner.get_history_async(_on_history_loaded, 50)


func _on_history_loaded(res: FxvRunner.FxvResult) -> void:
	_set_busy(false)
	var root := _history_tree.get_root()
	if root == null:
		root = _history_tree.create_item()

	if res.success and res.data is FxvDto.HistoryPayload:
		var hp: FxvDto.HistoryPayload = res.data
		var cache := FxvStateCache.get_instance()
		var latest_status := cache.get_latest_status()
		var current_rev := latest_status.head_revision_display if latest_status != null else ""
		var current_hash := ""
		if latest_status != null and latest_status.head_commit != null:
			if latest_status.head_commit.local_snapshot != null:
				current_hash = latest_status.head_commit.local_snapshot.commit_hash
			elif latest_status.head_commit.published_head != null:
				current_hash = latest_status.head_commit.published_head.commit_hash

		for entry in hp.entries:
			var item := _history_tree.create_item(root)
			item.set_metadata(0, entry.revision_display)
			var is_current := false
			if not current_rev.is_empty() and entry.revision_display == current_rev:
				is_current = true
			elif not current_hash.is_empty() and entry.commit_hash == current_hash:
				is_current = true

			var rev_text := entry.revision_display
			if is_current:
				rev_text = "● " + rev_text
			item.set_text(0, rev_text)
			item.set_text(1, entry.author_display_name if not entry.author_display_name.is_empty() else entry.author_id)
			item.set_text(2, _format_timestamp(entry.timestamp_millis))
			item.set_text(3, entry.description)

			if is_current:
				var highlight_col := Color(0.4, 0.8, 1.0) # Accent cyan/blue
				for col_idx in range(4):
					item.set_custom_color(col_idx, highlight_col)
		_status_label.text = "History loaded (%d commits)." % hp.entries.size()
	else:
		_status_label.text = "Failed to load history."


static func _format_timestamp(timestamp_millis: int) -> String:
	if timestamp_millis <= 0:
		return "-"
	var unix_sec := int(timestamp_millis / 1000)
	var dt := Time.get_datetime_dict_from_unix_time(unix_sec)
	return "%04d-%02d-%02d %02d:%02d" % [dt.year, dt.month, dt.day, dt.hour, dt.minute]


func _on_history_row_selected() -> void:
	var selected := _history_tree.get_selected()
	if selected == null:
		return

	var meta_rev = selected.get_metadata(0)
	var rev: String = str(meta_rev) if meta_rev != null else selected.get_text(0).trim_prefix("● ").strip_edges()
	if rev.is_empty():
		return

	if _change_info_cache.has(rev):
		_render_change_info(rev, _change_info_cache[rev])
		return

	_history_details_tree.clear()
	_history_details_tree.create_item()
	_history_details_label.text = "Loading changed files for %s..." % rev
	FxvRunner.get_change_info_async(rev, func(res: FxvRunner.FxvResult) -> void:
		if res.success and res.data is FxvDto.ChangeInfoPayload:
			_change_info_cache[rev] = res.data
			_render_change_info(rev, res.data)
		else:
			_history_details_label.text = "Failed to load changed files for %s." % rev
	)


func _render_change_info(rev: String, payload: FxvDto.ChangeInfoPayload) -> void:
	_history_details_tree.clear()
	var root := _history_details_tree.create_item()

	for change in payload.changes:
		var item := _history_details_tree.create_item(root)
		item.set_text(0, change.path)
		item.set_text(1, change.action.capitalize())
		item.set_text(2, _format_size(change.size))

	_history_details_label.text = "%s — %d file(s) changed" % [rev, payload.changes.size()]


static func _format_size(size: int) -> String:
	if size <= 0:
		return ""
	if size < 1024:
		return "%d B" % size
	if size < 1048576:
		return "%.1f KB" % (size / 1024.0)
	return "%.1f MB" % (size / 1048576.0)


func _on_goto_pressed() -> void:
	var selected := _history_tree.get_selected()
	if selected == null:
		_status_label.text = "Select a revision in history first."
		return

	var meta_rev = selected.get_metadata(0)
	var rev: String = str(meta_rev) if meta_rev != null else selected.get_text(0).trim_prefix("● ").strip_edges()
	if rev.is_empty():
		_status_label.text = "Invalid revision selected."
		return
	if not FxvSafetyGuards.ensure_safe_to_mutate("Goto Revision"):
		return

	_status_label.text = "Switching workspace to revision %s..." % rev
	_set_busy(true)
	FxvRunner.goto_revision_async(rev, func(res: FxvRunner.FxvResult) -> void:
		_set_busy(false)
		if res.success:
			_status_label.text = "Switched to %s." % rev
			request_refresh.emit()
			EditorInterface.get_resource_filesystem().scan()
		else:
			_status_label.text = "Goto failed."
			push_error("[FlexVault] Goto revision failed: " + res.error_message)
	)
