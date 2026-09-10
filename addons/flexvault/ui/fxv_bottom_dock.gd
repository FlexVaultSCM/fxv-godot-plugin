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

# History controls
var _history_tree: Tree
var _history_refresh_btn: Button
var _goto_btn: Button

var _confirm_dialog: ConfirmationDialog

func _init() -> void:
	name = "FlexVault"
	custom_minimum_size = Vector2(400, 250)

func _ready() -> void:
	_build_ui()
	_connect_signals()

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
	tree_actions.add_child(_resolve_mine_btn)

	_resolve_theirs_btn = Button.new()
	_resolve_theirs_btn.text = "Resolve (Theirs)"
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

	_history_tree = Tree.new()
	_history_tree.columns = 4
	_history_tree.set_column_title(0, "Revision")
	_history_tree.set_column_title(1, "Author")
	_history_tree.set_column_title(2, "Description")
	_history_tree.set_column_title(3, "Hash")
	_history_tree.column_titles_visible = true
	_history_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_history_view.add_child(_history_tree)

func _connect_signals() -> void:
	_refresh_btn.pressed.connect(func(): request_refresh.emit())
	_snapshot_btn.pressed.connect(_on_snapshot_pressed)
	_publish_btn.pressed.connect(_on_publish_pressed)
	_sync_btn.pressed.connect(_on_sync_pressed)
	_revert_btn.pressed.connect(_on_revert_pressed)
	_diff_btn.pressed.connect(_on_diff_pressed)
	_resolve_mine_btn.pressed.connect(func(): _on_resolve_pressed("mine"))
	_resolve_theirs_btn.pressed.connect(func(): _on_resolve_pressed("theirs"))
	_history_refresh_btn.pressed.connect(_load_history)
	_goto_btn.pressed.connect(_on_goto_pressed)

	var cache := FxvStateCache.get_instance()
	cache.state_changed.connect(_on_state_changed)

func _on_state_changed() -> void:
	var cache := FxvStateCache.get_instance()
	var status := cache.get_latest_status()

	if status != null:
		var behind := ""
		if status.sync_status != null and not status.sync_status.up_to_date:
			behind = " (%d revs behind)" % status.sync_status.revisions_behind
		_user_branch_label.text = "Branch: %s%s | User: %s" % [status.current_branch, behind, status.current_user]

	_update_changes_tree()

func _update_changes_tree() -> void:
	_changes_tree.clear()
	var root := _changes_tree.create_item()

	var cache := FxvStateCache.get_instance()
	var changed_files := cache.get_changed_files()

	for f in changed_files:
		var item := _changes_tree.create_item(root)
		item.set_text(0, f.path)
		item.set_text(1, f.effective_state.capitalize())

		# Format size
		var size_str := ""
		if f.size > 0:
			if f.size < 1024:
				size_str = "%d B" % f.size
			elif f.size < 1048576:
				size_str = "%.1f KB" % (f.size / 1024.0)
			else:
				size_str = "%.1f MB" % (f.size / 1048576.0)
		item.set_text(2, size_str)

		# Status color
		var col := Color.WHITE
		match f.effective_state.to_lower():
			"added": col = Color(0.3, 0.9, 0.4)
			"modified": col = Color(0.4, 0.7, 1.0)
			"deleted": col = Color(0.95, 0.3, 0.3)
			"conflicted": col = Color(1.0, 0.6, 0.2)
		item.set_custom_color(1, col)

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
	var res := FxvRunner.snapshot(desc)
	if res.success:
		_commit_msg_edit.text = ""
		_status_label.text = "Snapshot taken successfully."
		request_refresh.emit()
	else:
		_status_label.text = "Snapshot failed."
		push_error("[FlexVault] Snapshot failed: " + res.error_message)

func _on_publish_pressed() -> void:
	if not FxvSafetyGuards.ensure_safe_to_mutate("Publish"):
		return
	var desc := _commit_msg_edit.text.strip_edges()
	if desc.is_empty():
		_status_label.text = "Publish requires a description."
		return
	_status_label.text = "Publishing..."
	var res := FxvRunner.publish(desc)
	if res.success:
		_commit_msg_edit.text = ""
		_status_label.text = "Published successfully."
		request_refresh.emit()
	else:
		_status_label.text = "Publish failed."
		push_error("[FlexVault] Publish failed: " + res.error_message)

func _on_sync_pressed() -> void:
	if not FxvSafetyGuards.ensure_safe_to_mutate("Sync Workspace"):
		return
	_status_label.text = "Syncing workspace..."
	var res := FxvRunner.sync_workspace()
	if res.success:
		_status_label.text = "Workspace synced."
		request_refresh.emit()
		EditorInterface.get_resource_filesystem().scan()
	else:
		_status_label.text = "Sync failed."
		push_error("[FlexVault] Sync failed: " + res.error_message)

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
	var res := FxvRunner.revert(expanded)
	if res.success:
		_status_label.text = "Reverted %d items." % expanded.size()
		request_refresh.emit()
		EditorInterface.get_resource_filesystem().scan()
	else:
		_status_label.text = "Revert failed."
		push_error("[FlexVault] Revert failed: " + res.error_message)

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
	var res := FxvRunner.resolve(mode, expanded)
	if res.success:
		_status_label.text = "Resolved conflict(s)."
		request_refresh.emit()
		EditorInterface.get_resource_filesystem().scan()
	else:
		_status_label.text = "Resolve failed."
		push_error("[FlexVault] Resolve failed: " + res.error_message)

func _load_history() -> void:
	_history_tree.clear()
	var root := _history_tree.create_item()

	_status_label.text = "Loading history..."
	var res := FxvRunner.get_history(50)
	if res.success and res.data is FxvDto.HistoryPayload:
		var hp: FxvDto.HistoryPayload = res.data
		for entry in hp.entries:
			var item := _history_tree.create_item(root)
			item.set_text(0, entry.revision_display)
			item.set_text(1, entry.author_display_name if not entry.author_display_name.is_empty() else entry.author_id)
			item.set_text(2, entry.description)
			var hash_str := entry.commit_hash.substr(0, 8) if not entry.commit_hash.is_empty() else "-"
			item.set_text(3, hash_str)
		_status_label.text = "History loaded (%d commits)." % hp.entries.size()
	else:
		_status_label.text = "Failed to load history."


func _on_goto_pressed() -> void:
	var selected := _history_tree.get_selected()
	if selected == null:
		_status_label.text = "Select a revision in history first."
		return

	var rev := selected.get_text(0)
	if not FxvSafetyGuards.ensure_safe_to_mutate("Goto Revision"):
		return

	_status_label.text = "Switching workspace to revision %s..." % rev
	var res := FxvRunner.goto_revision(rev)
	if res.success:
		_status_label.text = "Switched to %s." % rev
		request_refresh.emit()
		EditorInterface.get_resource_filesystem().scan()
	else:
		_status_label.text = "Goto failed."
		push_error("[FlexVault] Goto revision failed: " + res.error_message)
