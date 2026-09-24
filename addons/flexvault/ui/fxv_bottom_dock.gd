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
var _publish_btn: Button
var _revert_btn: Button
var _diff_btn: Button
var _sync_btn: Button
var _resolve_mine_btn: Button
var _resolve_theirs_btn: Button
var _status_label: Label
var _spinner: TextureRect
var _spinner_timer: Timer
var _spinner_frame: int = 1
var _branch_btn: MenuButton
var _branch_menu: PopupMenu
var _user_branch_label: Label
var _login_edit: LineEdit
var _login_btn: Button
var _docs_btn: Button
var _discord_btn: Button

# History controls
var _history_tree: Tree
var _history_refresh_btn: Button
var _goto_btn: Button
var _history_details_tree: Tree
var _history_details_label: Label
var _history_diff_current_btn: Button
var _history_diff_previous_btn: Button
var _change_info_cache: Dictionary = {}
var _history_loaded_fingerprint: String = ""

var _confirm_dialog: ConfirmationDialog
var _busy: bool = false

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


	_sync_btn = Button.new()
	_sync_btn.text = "Sync Workspace"
	toolbar.add_child(_sync_btn)

	_branch_btn = MenuButton.new()
	_branch_btn.text = "Branch: -"
	_branch_btn.tooltip_text = "Click to view and switch branches"
	_branch_btn.flat = false
	_branch_menu = _branch_btn.get_popup()
	toolbar.add_child(_branch_btn)

	toolbar.add_spacer(false)

	_user_branch_label = Label.new()
	_user_branch_label.text = "User: -%s" % _version_suffix()
	toolbar.add_child(_user_branch_label)

	_login_edit = LineEdit.new()
	_login_edit.placeholder_text = "Username"
	_login_edit.custom_minimum_size = Vector2(110, 0)
	toolbar.add_child(_login_edit)

	_login_btn = Button.new()
	_login_btn.text = "Log In"
	toolbar.add_child(_login_btn)

	_spinner = TextureRect.new()
	_spinner.custom_minimum_size = Vector2(16, 16)
	_spinner.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_spinner.visible = false
	toolbar.add_child(_spinner)

	_spinner_timer = Timer.new()
	_spinner_timer.wait_time = 0.08
	_spinner_timer.timeout.connect(_on_spinner_timer_timeout)
	add_child(_spinner_timer)

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
	_changes_tree.hide_root = true
	_changes_tree.select_mode = Tree.SELECT_MULTI
	_changes_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree_container.add_child(_changes_tree)

	# Tree actions toolbar
	var tree_actions := HBoxContainer.new()
	tree_container.add_child(tree_actions)

	_diff_btn = Button.new()
	_diff_btn.text = "Diff Against Previous"
	_diff_btn.disabled = true
	_diff_btn.tooltip_text = "Select a file above to diff it against its base revision."
	tree_actions.add_child(_diff_btn)

	_revert_btn = Button.new()
	_revert_btn.text = "Revert Selected"
	_revert_btn.disabled = true
	_revert_btn.tooltip_text = "Select one or more files above to revert them."
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
	commit_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	changes_split.add_child(commit_panel)

	var desc_lbl := Label.new()
	desc_lbl.text = "Description:"
	commit_panel.add_child(desc_lbl)

	_commit_msg_edit = TextEdit.new()
	_commit_msg_edit.placeholder_text = "Enter publish description..."
	_commit_msg_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	commit_panel.add_child(_commit_msg_edit)

	var commit_btn_row := HBoxContainer.new()
	commit_panel.add_child(commit_btn_row)

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
	_goto_btn.text = "Switch to Selected Revision"
	_goto_btn.disabled = true
	_goto_btn.tooltip_text = "Select a revision in the history list first."
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
	_history_tree.hide_root = true
	_history_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	history_split.add_child(_history_tree)

	var details_container := VBoxContainer.new()
	details_container.custom_minimum_size = Vector2(0, 100)
	details_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
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
	_history_details_tree.hide_root = true
	_history_details_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details_container.add_child(_history_details_tree)

	var details_actions := HBoxContainer.new()
	details_container.add_child(details_actions)

	_history_diff_current_btn = Button.new()
	_history_diff_current_btn.text = "Diff Against Current"
	_history_diff_current_btn.disabled = true
	_history_diff_current_btn.tooltip_text = "Select a file above to diff its selected revision against the current workspace."
	details_actions.add_child(_history_diff_current_btn)

	_history_diff_previous_btn = Button.new()
	_history_diff_previous_btn.text = "Diff Against Previous"
	_history_diff_previous_btn.disabled = true
	_history_diff_previous_btn.tooltip_text = "Select a file above to diff its selected revision against the previous revision."
	details_actions.add_child(_history_diff_previous_btn)

func _connect_signals() -> void:
	_publish_btn.pressed.connect(_on_publish_pressed)
	_sync_btn.pressed.connect(_on_sync_pressed)
	_branch_btn.about_to_popup.connect(_on_branch_menu_about_to_popup)
	_branch_menu.index_pressed.connect(_on_branch_menu_item_selected)
	_revert_btn.pressed.connect(_on_revert_pressed)
	_diff_btn.pressed.connect(_on_diff_pressed)
	_resolve_mine_btn.pressed.connect(func(): _on_resolve_pressed("mine"))
	_resolve_theirs_btn.pressed.connect(func(): _on_resolve_pressed("theirs"))
	_tabs.tab_changed.connect(_on_tab_changed)
	_history_refresh_btn.pressed.connect(_load_history)
	_goto_btn.pressed.connect(_on_goto_pressed)
	_history_tree.item_selected.connect(_on_history_row_selected)
	_history_tree.item_selected.connect(_update_selection_dependent_buttons)
	_history_tree.item_selected.connect(_update_history_details_buttons)
	_history_details_tree.item_selected.connect(_update_history_details_buttons)
	_history_diff_current_btn.pressed.connect(_on_history_diff_current_pressed)
	_history_diff_previous_btn.pressed.connect(_on_history_diff_previous_pressed)
	_changes_tree.multi_selected.connect(func(_item: TreeItem, _column: int, _selected: bool): _update_selection_dependent_buttons())
	_docs_btn.pressed.connect(func(): OS.shell_open("https://docs.fxv.dev"))
	_discord_btn.pressed.connect(func(): OS.shell_open("https://discord.gg/KCMHRQBDf"))
	_login_btn.pressed.connect(_on_login_pressed)
	_login_edit.text_submitted.connect(func(_text: String): _on_login_pressed())

	var cache := FxvStateCache.get_instance()
	cache.state_changed.connect(_on_state_changed)

## " | fxv <cli version> / plugin <plugin version> (beta)", omitting either half that isn't known yet
## (CLI version check hasn't completed, or plugin.cfg couldn't be read).
func _version_suffix() -> String:
	var cli_version := FxvVersionGuard.get_last_version_string()
	var plugin_version := FxvVersionGuard.get_plugin_version()
	if cli_version.is_empty() and plugin_version.is_empty():
		return ""
	var parts: Array[String] = []
	if not cli_version.is_empty():
		parts.append("fxv %s" % cli_version)
	if not plugin_version.is_empty():
		parts.append("plugin %s (beta)" % plugin_version)
	return " | %s" % " / ".join(parts)

func _on_tab_changed(tab_idx: int) -> void:
	if tab_idx == 1: # History tab
		_load_history(false)

func _on_state_changed() -> void:
	var cache := FxvStateCache.get_instance()
	var status := cache.get_latest_status()

	if status != null:
		var behind := ""
		var is_behind := status.sync_status != null and not status.sync_status.up_to_date
		if is_behind:
			behind = " (%d revs behind)" % status.sync_status.revisions_behind
			_sync_btn.text = "Sync Workspace%s" % behind
			_sync_btn.add_theme_color_override("font_color", Color(1.0, 0.7, 0.2))
			_sync_btn.tooltip_text = "The published branch has changes not yet in your workspace. Click to sync."
		else:
			_sync_btn.text = "Sync Workspace"
			_sync_btn.remove_theme_color_override("font_color")
			_sync_btn.tooltip_text = ""
		var unpublished := ""
		if status.unpublished_changes > 0:
			unpublished = " | %d unpublished change%s" % [status.unpublished_changes, "" if status.unpublished_changes == 1 else "s"]
		var rev_str := status.head_revision_display
		var is_logged_in := not status.current_user.is_empty()
		_branch_btn.text = "Branch: %s" % (status.current_branch if not status.current_branch.is_empty() else "-")
		_branch_btn.tooltip_text = "Current branch: %s (head: %s). Click to switch branches." % [status.current_branch, rev_str]
		_user_branch_label.text = "User: %s (%s)%s%s%s" % [status.current_user if is_logged_in else "logged out", rev_str, behind, unpublished, _version_suffix()]
		_login_edit.visible = not is_logged_in
		_login_btn.visible = not is_logged_in

	_update_changes_tree()
	if _tabs.current_tab == 1:
		# Unforced: skips the reload (and the selection loss that comes with it) unless
		# the workspace head actually moved, so routine background status polls while the
		# History tab is open don't flicker or drop the current selection.
		_load_history(false)

func _update_changes_tree() -> void:
	_changes_tree.clear()
	var root := _changes_tree.create_item()

	var cache := FxvStateCache.get_instance()
	var changed_files := cache.get_changed_files()

	for f in changed_files:
		var item := _changes_tree.create_item(root)
		item.set_text(0, f.path)
		var status_text := f.effective_state.capitalize()
		if not f.needs_snapshot and f.is_unpublished:
			status_text += " (unpublished)"
		item.set_text(1, status_text)

		item.set_text(2, _format_size(f.size))

		# Status color
		var col := Color.WHITE
		match f.effective_state.to_lower():
			"added": col = Color(0.3, 0.9, 0.4)
			"modified": col = Color(0.4, 0.7, 1.0)
			"deleted": col = Color(0.95, 0.3, 0.3)
			"conflicted": col = Color(1.0, 0.6, 0.2)
		item.set_custom_color(1, col)

		if f.conflict_state != null:
			item.set_tooltip_text(1, f.conflict_state.description)

	var has_conflicts := cache.has_conflicts()
	_resolve_mine_btn.visible = has_conflicts
	_resolve_theirs_btn.visible = has_conflicts

	# Rebuilding the tree above drops any prior selection.
	_update_selection_dependent_buttons()

## Diff Against Previous only makes sense for a single file; Revert Selected works on any non-empty
## selection. Both stay disabled with nothing selected instead of no-op'ing on click.
func _update_selection_dependent_buttons() -> void:
	var has_selection := _changes_tree.get_next_selected(null) != null
	_diff_btn.disabled = _busy or not has_selection
	_revert_btn.disabled = _busy or not has_selection
	_goto_btn.disabled = _busy or _history_tree.get_next_selected(null) == null

## Both diff buttons need a file selected in the changed-files detail list; Diff Against
## Previous additionally needs an older revision to exist (nothing to compare the oldest
## revision in the loaded history against).
func _update_history_details_buttons() -> void:
	var has_selection := _history_details_tree.get_next_selected(null) != null
	_history_diff_current_btn.disabled = _busy or not has_selection
	_history_diff_previous_btn.disabled = _busy or not has_selection or _get_previous_history_revision().is_empty()

## The revision immediately below the selected one in the history list, i.e. the next-older
## entry. The list is CLI-ordered newest first, so this is the row directly after it.
func _get_previous_history_revision() -> String:
	var selected := _history_tree.get_selected()
	if selected == null:
		return ""
	var next_item := selected.get_next()
	if next_item == null:
		return ""
	var meta = next_item.get_metadata(0)
	if meta is FxvDto.CommitRef:
		return meta.revision_display
	return ""

func _set_busy(busy: bool) -> void:
	_busy = busy
	_publish_btn.disabled = busy
	_sync_btn.disabled = busy
	_branch_btn.disabled = busy
	_resolve_mine_btn.disabled = busy
	_resolve_theirs_btn.disabled = busy
	_history_refresh_btn.disabled = busy
	_login_btn.disabled = busy
	_update_selection_dependent_buttons()
	_update_history_details_buttons()
	_spinner.visible = busy
	if busy:
		_spinner_frame = 1
		_spinner.texture = get_theme_icon("Progress%d" % _spinner_frame, "EditorIcons")
		_spinner_timer.start()
	else:
		_spinner_timer.stop()

## EditorIcons ships 8 frames ("Progress1".."Progress8") meant to be cycled by editor
## plugins to fake an indeterminate spinner; there's no dedicated spinner Control node.
func _on_spinner_timer_timeout() -> void:
	_spinner_frame = (_spinner_frame % 8) + 1
	_spinner.texture = get_theme_icon("Progress%d" % _spinner_frame, "EditorIcons")


func _get_selected_paths() -> Array:
	var paths: Array = []
	var item := _changes_tree.get_next_selected(null)
	while item != null:
		paths.append(item.get_text(0))
		item = _changes_tree.get_next_selected(item)
	return paths

## Publish snapshots the workspace first, then publishes the resulting draft. Manual snapshotting
## is intentionally not exposed in the UI - the plugin takes snapshots automatically on
## high-entropy editor operations (see FlexVaultPlugin's auto-snapshot triggers), and Publish is
## the only user-facing action that commits a workspace snapshot, matching the Unreal and Unity
## plugins (both combine the two into one "Publish"/"Check In" action with a shared description).
## `fxv publish` only publishes already-committed draft snapshots, not raw workspace edits, so a
## bare publish call would silently no-op on a dirty-but-unsnapshotted workspace. Login is checked
## before snapshotting (not just before publishing) so a logged-out user doesn't end up with a
## local snapshot and a failed publish.
func _on_publish_pressed() -> void:
	if not FxvSafetyGuards.ensure_safe_to_mutate("Publish"):
		return
	var desc := _commit_msg_edit.text.strip_edges()
	if desc.is_empty():
		_status_label.text = "Publish requires a description."
		return

	var status := FxvStateCache.get_instance().get_latest_status()
	if status != null and status.current_user.is_empty():
		_status_label.text = "Publish requires logging in first."
		return
	if status != null and status.unpublished_changes == 0 and status.workspace_changes_count == 0:
		_status_label.text = "Nothing to publish."
		return

	_status_label.text = "Taking snapshot..."
	_set_busy(true)
	FxvRunner.snapshot_async(desc, func(snapshot_res: FxvRunner.FxvResult) -> void:
		if not snapshot_res.success:
			_set_busy(false)
			var snapshot_reason := snapshot_res.error_message if not snapshot_res.error_message.is_empty() else "unknown error"
			_status_label.text = "Publish failed: could not snapshot (%s)." % snapshot_reason
			push_error("[FlexVault] Publish's snapshot step failed: " + snapshot_res.error_message)
			return

		_status_label.text = "Publishing..."
		FxvRunner.publish_async(desc, func(publish_res: FxvRunner.FxvResult) -> void:
			_set_busy(false)
			if publish_res.success:
				_commit_msg_edit.text = ""
				_status_label.text = "Published successfully."
				request_refresh.emit()
			else:
				var publish_reason := publish_res.error_message if not publish_res.error_message.is_empty() else "unknown error"
				_status_label.text = "Publish failed: %s" % publish_reason
				push_error("[FlexVault] Publish failed: " + publish_res.error_message)
		)
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
			var conflicted: Array = res.data.conflicted_files if res.data is FxvDto.WorkspaceSyncPayload else []
			FxvRunner.apply_default_resolve_preference(conflicted, func(applied: bool) -> void:
				if applied:
					_status_label.text = "Workspace synced; conflicts auto-resolved."
				request_refresh.emit()
				EditorInterface.get_resource_filesystem().scan()
			)
		else:
			var reason := res.error_message if not res.error_message.is_empty() else "unknown error"
			_status_label.text = "Sync failed: %s" % reason
			push_error("[FlexVault] Sync failed: " + res.error_message)
	)

func _on_branch_menu_about_to_popup() -> void:
	_branch_menu.clear()
	_branch_menu.add_item("Loading branches...", 0)
	_branch_menu.set_item_disabled(0, true)

	FxvRunner.get_branch_list_async(func(res: FxvRunner.FxvResult) -> void:
		_branch_menu.clear()
		if not res.success or not (res.data is FxvDto.BranchListPayload):
			_branch_menu.add_item("Failed to load branches", 0)
			_branch_menu.set_item_disabled(0, true)
			return

		var payload: FxvDto.BranchListPayload = res.data
		var cache := FxvStateCache.get_instance()
		var status := cache.get_latest_status()
		var current_branch: String = status.current_branch if status != null else ""

		if payload.branches.is_empty():
			_branch_menu.add_item("No branches found", 0)
			_branch_menu.set_item_disabled(0, true)
			return

		for i in range(payload.branches.size()):
			var b := payload.branches[i]
			var label := b.branch
			if b.retired:
				label += " (retired)"
			elif b.local_only:
				label += " (local only)"
			if b.branch == current_branch:
				label = "● " + label
			_branch_menu.add_item(label, i)
			_branch_menu.set_item_metadata(i, b.branch)
			if b.branch == current_branch or b.retired:
				_branch_menu.set_item_disabled(i, b.branch == current_branch)
	)

func _on_branch_menu_item_selected(index: int) -> void:
	var branch_name = _branch_menu.get_item_metadata(index)
	if branch_name is String and not branch_name.is_empty():
		_switch_branch(branch_name)

func _switch_branch(target_branch: String) -> void:
	if not FxvSafetyGuards.ensure_safe_to_mutate("Branch Switch"):
		return
	_status_label.text = "Switching to branch '%s'..." % target_branch
	_set_busy(true)
	FxvRunner.branch_switch_async(target_branch, func(res: FxvRunner.FxvResult) -> void:
		_set_busy(false)
		if res.success:
			_status_label.text = "Switched to branch '%s'." % target_branch
			request_refresh.emit()
			EditorInterface.get_resource_filesystem().scan()
		else:
			var reason := res.error_message if not res.error_message.is_empty() else "unknown error"
			_status_label.text = "Branch switch failed: %s" % reason
			push_error("[FlexVault] Branch switch failed: " + res.error_message)
	)


func _on_login_pressed() -> void:
	var username := _login_edit.text.strip_edges()
	if username.is_empty():
		_status_label.text = "Enter a username to log in."
		return
	_status_label.text = "Logging in as '%s'..." % username
	_set_busy(true)
	FxvRunner.login_async(username, func(res: FxvRunner.FxvResult) -> void:
		_set_busy(false)
		if res.success:
			_login_edit.text = ""
			_status_label.text = "Logged in as '%s'." % username
			request_refresh.emit()
		else:
			var reason := res.error_message if not res.error_message.is_empty() else "unknown error"
			_status_label.text = "Login failed: %s" % reason
			push_error("[FlexVault] Login failed: " + res.error_message)
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
			var reason := res.error_message if not res.error_message.is_empty() else "unknown error"
			_status_label.text = "Revert failed: %s" % reason
			push_error("[FlexVault] Revert failed: " + res.error_message)
	)

func _on_diff_pressed() -> void:
	var paths := _get_selected_paths()
	if paths.size() == 0:
		_status_label.text = "Select a file to diff."
		return
	_status_label.text = "Opening diff viewer..."
	match FxvDiffHelper.diff_file_against_base(paths[0]):
		FxvDiffHelper.DiffResult.UNCHANGED:
			_status_label.text = "%s has no differences against its base revision." % paths[0]
		FxvDiffHelper.DiffResult.ERROR:
			_status_label.text = "Failed to open diff for %s." % paths[0]
		FxvDiffHelper.DiffResult.OPENED:
			_status_label.text = "Diff viewer opened for %s." % paths[0]

func _on_history_diff_current_pressed() -> void:
	var file_item := _history_details_tree.get_selected()
	var rev := _get_selected_history_revision()
	var rev_spec := _get_selected_history_revision_spec()
	if file_item == null or rev.is_empty():
		_status_label.text = "Select a revision and file to diff."
		return

	var path := file_item.get_text(0)
	_status_label.text = "Opening diff viewer..."
	match FxvDiffHelper.diff_file_against_base(path, rev_spec):
		FxvDiffHelper.DiffResult.UNCHANGED:
			_status_label.text = "%s has no differences between %s and the current workspace." % [path, rev]
		FxvDiffHelper.DiffResult.ERROR:
			_status_label.text = "Failed to open diff for %s." % path
		FxvDiffHelper.DiffResult.OPENED:
			_status_label.text = "Diff viewer opened for %s (%s vs current)." % [path, rev]

func _on_history_diff_previous_pressed() -> void:
	var file_item := _history_details_tree.get_selected()
	var rev := _get_selected_history_revision()
	var prev_rev := _get_previous_history_revision()
	var rev_spec := _get_selected_history_revision_spec()
	var prev_rev_spec := _get_previous_history_revision_spec()
	if file_item == null or rev.is_empty() or prev_rev.is_empty():
		_status_label.text = "Select a revision and file to diff."
		return

	var path := file_item.get_text(0)
	_status_label.text = "Opening diff viewer..."
	match FxvDiffHelper.diff_file_between_revisions(path, prev_rev_spec, rev_spec):
		FxvDiffHelper.DiffResult.UNCHANGED:
			_status_label.text = "%s has no differences between %s and %s." % [path, prev_rev, rev]
		FxvDiffHelper.DiffResult.ERROR:
			_status_label.text = "Failed to open diff for %s." % path
		FxvDiffHelper.DiffResult.OPENED:
			_status_label.text = "Diff viewer opened for %s (%s vs %s)." % [path, prev_rev, rev]

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
			var reason := res.error_message if not res.error_message.is_empty() else "unknown error"
			_status_label.text = "Resolve failed: %s" % reason
			push_error("[FlexVault] Resolve failed: " + res.error_message)
	)

## Cheap signature of "what history should currently look like." Used to skip redundant
## reloads (and the selection loss / flicker they cause) when nothing has actually
## changed since the last load, e.g. a routine background status poll.
func _current_history_fingerprint() -> String:
	var status := FxvStateCache.get_instance().get_latest_status()
	if status == null:
		return ""
	return "%s|%s" % [status.current_branch, status.head_revision_display]


## `force`: always reload (used by the Refresh History button and the initial load).
## When false, skips the reload entirely if the workspace head hasn't moved since the
## last successful load, so the tree, selection, and loaded change-info detail are left
## untouched.
func _load_history(force: bool = true) -> void:
	if not force and _history_tree.get_root() != null:
		var fp := _current_history_fingerprint()
		if not fp.is_empty() and fp == _history_loaded_fingerprint:
			return

	var previously_selected_rev := _get_selected_history_revision()

	_history_tree.clear()
	_history_tree.create_item()
	_history_details_tree.clear()
	_history_details_label.text = "Select a revision to see changed files."

	_status_label.text = "Loading history..."
	_set_busy(true)
	FxvRunner.get_history_async(_on_history_loaded.bind(previously_selected_rev), 50)


func _on_history_loaded(res: FxvRunner.FxvResult, previously_selected_rev: String) -> void:
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

		var restored_item: TreeItem = null
		for entry in hp.entries:
			var item := _history_tree.create_item(root)
			item.set_metadata(0, entry)
			if not previously_selected_rev.is_empty() and entry.revision_display == previously_selected_rev:
				restored_item = item
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

		if restored_item != null:
			restored_item.select(0)
			if _change_info_cache.has(previously_selected_rev):
				_render_change_info(previously_selected_rev, _change_info_cache[previously_selected_rev])

		_history_loaded_fingerprint = _current_history_fingerprint()
		_status_label.text = "History loaded (%d commits)." % hp.entries.size()
	else:
		_status_label.text = "Failed to load history."


static func _format_timestamp(timestamp_millis: int) -> String:
	if timestamp_millis <= 0:
		return "-"
	var unix_sec := int(timestamp_millis / 1000)
	var dt := Time.get_datetime_dict_from_unix_time(unix_sec)
	return "%04d-%02d-%02d %02d:%02d" % [dt.year, dt.month, dt.day, dt.hour, dt.minute]


## Returns the CommitRef stored as row metadata, or null if the row predates that
## (defensively falls back to reconstructing just the revision string from the label).
func _get_selected_history_entry() -> FxvDto.CommitRef:
	var selected := _history_tree.get_selected()
	if selected == null:
		return null
	var meta = selected.get_metadata(0)
	if meta is FxvDto.CommitRef:
		return meta
	return null


func _get_selected_history_revision() -> String:
	var entry := _get_selected_history_entry()
	if entry != null:
		return entry.revision_display
	var selected := _history_tree.get_selected()
	if selected == null:
		return ""
	return selected.get_text(0).trim_prefix("● ").strip_edges()


## CLI-safe counterpart to _get_selected_history_revision() - use this one for anything that
## calls back into the fxv CLI (diff, changeinfo); the other is for display/status text only.
## See FxvDto.CommitRef.revision_spec for why the two differ for unpublished draft commits.
func _get_selected_history_revision_spec() -> String:
	var entry := _get_selected_history_entry()
	if entry != null:
		return entry.revision_spec
	return _get_selected_history_revision()


## CLI-safe counterpart to _get_previous_history_revision(), see _get_selected_history_revision_spec().
func _get_previous_history_revision_spec() -> String:
	var selected := _history_tree.get_selected()
	if selected == null:
		return ""
	var next_item := selected.get_next()
	if next_item == null:
		return ""
	var meta = next_item.get_metadata(0)
	if meta is FxvDto.CommitRef:
		return meta.revision_spec
	return _get_previous_history_revision()


func _on_history_row_selected() -> void:
	var display_rev := _get_selected_history_revision()
	if display_rev.is_empty():
		return

	# revision_display is a human-readable label - for a purely local draft commit (no
	# published revision yet) it reads like "main.unpublished.1", which the CLI's revision-spec
	# parser rejects ("Invalid branch revision number: unpublished"). revision_spec is the same
	# shape but CLI-safe ("main.-.1"); display_rev stays revision_display for the UI/cache key.
	var entry := _get_selected_history_entry()
	var query_rev := entry.revision_spec if entry != null else display_rev

	if _change_info_cache.has(display_rev):
		_render_change_info(display_rev, _change_info_cache[display_rev])
		return

	_history_details_tree.clear()
	_history_details_tree.create_item()
	_history_details_label.text = "Loading changed files for %s..." % display_rev
	FxvRunner.get_change_info_async(query_rev, func(res: FxvRunner.FxvResult) -> void:
		if res.success and res.data is FxvDto.ChangeInfoPayload:
			_change_info_cache[display_rev] = res.data
			_render_change_info(display_rev, res.data)
		else:
			var reason := res.error_message if not res.error_message.is_empty() else "unknown error"
			_history_details_label.text = "Failed to load changed files for %s: %s" % [display_rev, reason]
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
	# Rebuilding the tree above drops any prior selection.
	_update_history_details_buttons()


static func _format_size(size: int) -> String:
	if size <= 0:
		return ""
	if size < 1024:
		return "%d B" % size
	if size < 1048576:
		return "%.1f KB" % (size / 1024.0)
	return "%.1f MB" % (size / 1048576.0)


func _on_goto_pressed() -> void:
	if _history_tree.get_selected() == null:
		_status_label.text = "Select a revision in history first."
		return

	var rev := _get_selected_history_revision()
	var rev_spec := _get_selected_history_revision_spec()
	if rev.is_empty():
		_status_label.text = "Invalid revision selected."
		return
	if not FxvSafetyGuards.ensure_safe_to_mutate("Goto Revision"):
		return

	_status_label.text = "Switching workspace to revision %s..." % rev
	_set_busy(true)
	FxvRunner.goto_revision_async(rev_spec, func(res: FxvRunner.FxvResult) -> void:
		_set_busy(false)
		if res.success:
			_status_label.text = "Switched to %s." % rev
			request_refresh.emit()
			EditorInterface.get_resource_filesystem().scan()
		else:
			var reason := res.error_message if not res.error_message.is_empty() else "unknown error"
			_status_label.text = "Goto failed: %s" % reason
			push_error("[FlexVault] Goto revision failed: " + res.error_message)
	)
