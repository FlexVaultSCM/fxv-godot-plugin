@tool
extends SceneTree

func _init():
	print("--- Running Godot In-Engine Tests ---")
	test_version_guard()
	test_meta_helper()
	test_dto()
	test_state_cache()
	test_settings()
	test_runner()
	test_ui()
	print("--- All Godot Tests Passed Successfully! ---")
	quit(0)



func test_version_guard():
	print("Testing FxvVersionGuard...")
	var sem = FxvVersionGuard.parse_semver("0.8.0")
	assert(sem != null, "SemVer parse failed")
	assert(sem.major == 0 and sem.minor == 8 and sem.patch == 0, "SemVer values mismatch")

	var res = FxvVersionGuard.check_version("0.11.0")
	assert(res["compatible"] == true, "0.11.0 should be compatible")

	var res_old = FxvVersionGuard.check_version("0.10.1")
	assert(res_old["compatible"] == false, "0.10.1 should be incompatible")

	FxvVersionGuard.set_incompatible("custom error")
	assert(FxvVersionGuard.is_compatible() == false, "Should be marked incompatible")
	assert(FxvVersionGuard.get_last_error_message() == "custom error", "Error message mismatch")
	FxvVersionGuard.reset_cached_version()

	assert(FxvVersionGuard.get_min_version_string() == "0.11.0", "Min version string mismatch")
	assert(FxvVersionGuard.get_max_version_string() == "0.12.0", "Max version string mismatch")

	# Regression: SemVer's _to_string() override must actually be dispatched to by .to_string(),
	# not fall back to Object's default "<RefCounted#...>" representation.
	var res_low = FxvVersionGuard.check_version("0.5.0")
	assert(res_low["error"].find("RefCounted") == -1, "check_version() error leaked default Object repr: " + res_low["error"])
	assert(res_low["error"].find("0.11.0") != -1 and res_low["error"].find("0.12.0") != -1, "check_version() error missing version bounds: " + res_low["error"])
	print("FxvVersionGuard OK.")

func test_meta_helper():
	print("Testing FxvMetaHelper...")
	var norm = FxvMetaHelper.normalize_separators("res:\\test\\path\\")
	assert(norm == "res:/test/path", "Normalize failed: " + norm)

	var comp = FxvMetaHelper.get_companion_import_path("icon.svg")
	assert(comp == "icon.svg.import", "Companion import failed")

	var base = FxvMetaHelper.get_logical_asset_path("icon.svg.import")
	assert(base == "icon.svg", "Logical asset failed")

	# Test expand_with_companions filtering non-existent companions
	var repo_root = ProjectSettings.globalize_path("res://")
	var isolated = FxvMetaHelper.expand_with_companions(["scenes/player.tscn"], repo_root)
	assert(isolated == ["scenes/player.tscn"], "Non-existent companions must not be added: " + str(isolated))

	# With known_files containing companion
	var with_comp = FxvMetaHelper.expand_with_companions(["scenes/player.tscn"], repo_root, ["scenes/player.tscn.import"])
	assert(with_comp.has("scenes/player.tscn"), "Original file missing")
	assert(with_comp.has("scenes/player.tscn.import"), "Known companion missing")
	assert(not with_comp.has("scenes/player.tscn.uid"), "Non-existent uid should not be included")
	print("FxvMetaHelper OK.")


func test_dto():
	print("Testing FxvDto...")
	var file_dict = {
		"path": "scenes/main.tscn",
		"workspace_state": "modified",
		"size": 2048
	}
	var item = FxvDto.FileStatusItem.from_dict(file_dict)
	assert(item.path == "scenes/main.tscn", "Path mismatch")
	assert(item.needs_snapshot == true, "Should need snapshot")
	assert(item.effective_state == "modified", "Effective state mismatch")

	# status schema v2 (fxv >= 0.10.0): a conflict-only entry with no change axis,
	# e.g. the directory side of a file/directory clash.
	var conflict_dict = {
		"path": "assets",
		"conflict_state": {"kind": "type_change"}
	}
	var conflict_item = FxvDto.FileStatusItem.from_dict(conflict_dict)
	assert(conflict_item.is_conflicted == true, "Should be conflicted")
	assert(conflict_item.needs_snapshot == false, "Conflict-only entry has no workspace change")
	assert(conflict_item.conflict_state.kind == "type_change", "Conflict kind mismatch")

	# Branch list DTO test
	var branch_list_dict = {
		"branches": [
			{
				"branch": "main",
				"branch_unique_id": "0123456789abcdef",
				"branch_type": "global",
				"published_head": "main.10",
				"draft_head": "main.10.1",
				"local_only": false,
				"retired": false
			}
		]
	}
	var bl_payload = FxvDto.BranchListPayload.from_dict(branch_list_dict)
	assert(bl_payload.branches.size() == 1, "Branch count mismatch")
	assert(bl_payload.branches[0].branch == "main", "Branch name mismatch")
	assert(bl_payload.branches[0].branch_type == "global", "Branch type mismatch")
	assert(bl_payload.branches[0].published_head == "main.10", "Published head mismatch")
	# CommitRef revision_spec tests
	var pub_commit = FxvDto.CommitRef.from_dict({
		"commit": {"branch": "main", "revision": 10, "type": "published"},
		"description": "Initial"
	})
	assert(pub_commit.revision_spec == "main.10", "Published revision_spec mismatch: " + pub_commit.revision_spec)
	assert(pub_commit.revision_display == "main.10", "Published revision_display mismatch: " + pub_commit.revision_display)

	var draft_commit = FxvDto.CommitRef.from_dict({
		"commit": {"branch": "main", "revision": 10, "type": "draft", "draft_revision": 2},
		"description": "WIP"
	})
	assert(draft_commit.revision_spec == "main.10.2", "Draft revision_spec mismatch: " + draft_commit.revision_spec)
	assert(draft_commit.revision_display == "main.10.2", "Draft revision_display mismatch: " + draft_commit.revision_display)

	var unpub_commit = FxvDto.CommitRef.from_dict({
		"commit": {"branch": "main", "type": "draft", "draft_revision": 3},
		"description": ""
	})
	assert(unpub_commit.revision_spec == "main.-.3", "Unpublished draft revision_spec must use '-' CLI spec: " + unpub_commit.revision_spec)
	assert(unpub_commit.revision_display == "main.unpublished.3", "Unpublished draft revision_display mismatch: " + unpub_commit.revision_display)

	var raw_commit = FxvDto.CommitRef.from_dict({
		"revision_spec": "explicit.spec.1",
		"description": ""
	})
	assert(raw_commit.revision_spec == "explicit.spec.1", "Raw revision_spec override failed: " + raw_commit.revision_spec)

	var empty_commit = FxvDto.CommitRef.new()
	assert(empty_commit.revision_spec == "", "Empty CommitRef revision_spec should be empty: " + empty_commit.revision_spec)
	assert(empty_commit.revision_display == "unknown", "Empty CommitRef revision_display should be unknown: " + empty_commit.revision_display)

	var wsp = FxvDto.WorkspaceSyncPayload.from_dict({"target_revision": "main.1.1", "files_updated_count": 2})
	assert(wsp.target_revision == "main.1.1", "WorkspaceSyncPayload target_revision mismatch")
	print("FxvDto OK.")

func test_state_cache():
	print("Testing FxvStateCache...")
	# Resolution description generation
	var desc_mine = FxvStateCache.describe_resolution("mine", ["scenes/player.tscn"])
	assert(desc_mine == "Resolved conflict (mine): scenes/player.tscn", "desc_mine mismatch: " + desc_mine)

	var desc_theirs = FxvStateCache.describe_resolution("theirs", ["a.txt", "b.txt"])
	assert(desc_theirs == "Resolved 2 conflicts (theirs): a.txt, b.txt", "desc_theirs mismatch: " + desc_theirs)

	var desc_undo = FxvStateCache.describe_resolution("undo", ["a.txt"])
	assert(desc_undo == "Undid resolution of conflict: a.txt", "desc_undo mismatch: " + desc_undo)

	var long_paths = ["1.txt", "2.txt", "3.txt", "4.txt", "5.txt", "6.txt", "7.txt"]
	var desc_long = FxvStateCache.describe_resolution("mine", long_paths)
	assert(desc_long == "Resolved 7 conflicts (mine): 1.txt, 2.txt, 3.txt, 4.txt, 5.txt and 2 more", "desc_long mismatch: " + desc_long)

	var desc_empty = FxvStateCache.describe_resolution("mine", [])
	assert(desc_empty == "Resolved conflicts (mine)", "desc_empty mismatch: " + desc_empty)

	var desc_dups = FxvStateCache.describe_resolution("theirs", ["a.txt", "a.txt", "b.txt"])
	assert(desc_dups == "Resolved 2 conflicts (theirs): a.txt, b.txt", "desc_dups mismatch: " + desc_dups)

	# Session-local description caching & retrieval
	var cache = FxvStateCache.get_instance()
	cache.clear()
	assert(cache.get_resolve_description("main.1.1") == "", "Initial description should be empty")

	cache.record_resolve_description("main.1.1", "Resolved conflict (mine): a.txt")
	assert(cache.get_resolve_description("main.1.1") == "Resolved conflict (mine): a.txt", "Exact lookup mismatch")

	# Cross-format alias testing: recording with .-. can be read by .unpublished. and vice-versa
	cache.record_resolve_description("main.-.2", "Resolved conflict (theirs): b.txt")
	assert(cache.get_resolve_description("main.-.2") == "Resolved conflict (theirs): b.txt", "Spec lookup mismatch")
	assert(cache.get_resolve_description("main.unpublished.2") == "Resolved conflict (theirs): b.txt", "Display alias lookup mismatch")

	cache.record_resolve_description("feat.unpublished.5", "Resolved conflict (mine): c.txt")
	assert(cache.get_resolve_description("feat.-.5") == "Resolved conflict (mine): c.txt", "Spec alias lookup mismatch")

	# Clearing
	cache.clear()
	assert(cache.get_resolve_description("main.1.1") == "", "Should be cleared")
	assert(cache.get_resolve_description("main.-.2") == "", "Should be cleared")
	print("FxvStateCache OK.")

func test_settings():
	print("Testing FxvSettings...")
	var proj_root = FxvSettings.get_project_root()
	assert(not proj_root.is_empty(), "Project root should not be empty")
	var repo_root = FxvSettings.get_repository_root()
	assert(not repo_root.is_empty(), "Repository root should not be empty")
	var bin_path = FxvSettings.get_effective_binary_path()
	assert(not bin_path.is_empty(), "Effective binary path should not be empty")
	print("FxvSettings OK.")

func test_runner():
	print("Testing FxvRunner...")
	var has_checked = FxvRunner.ensure_version_checked()
	print("ensure_version_checked result: ", has_checked)

	var full_args = FxvRunner.build_integration_register_args("/tmp/ws", "0.6.0", "0.11.0", "0.12.0")
	assert(full_args == ["integration", "register", "--name", "godot", "--plugin-version", "0.6.0", "--min", "0.11.0", "--max-version", "0.12.0", "--workspace", "/tmp/ws"], "Full integration register args mismatch: " + str(full_args))

	var unknown_plugin_args = FxvRunner.build_integration_register_args("/tmp/ws", "Unknown", "0.11.0", "0.12.0")
	assert(not unknown_plugin_args.has("--plugin-version"), "Unknown plugin version should be omitted: " + str(unknown_plugin_args))

	var empty_plugin_args = FxvRunner.build_integration_register_args("/tmp/ws", "", "0.11.0", "0.12.0")
	assert(not empty_plugin_args.has("--plugin-version"), "Empty plugin version should be omitted: " + str(empty_plugin_args))
	print("FxvRunner OK.")

func test_ui():
	print("Testing FxvBottomDock UI...")
	var dock = FxvBottomDock.new()
	assert(dock != null, "Dock instantiation failed")
	dock._build_ui()

	# Test history rendering fallback to cached resolve description
	var cache = FxvStateCache.get_instance()
	cache.clear()
	cache.record_resolve_description("main.-.3", "Resolved conflict (mine): player.tscn")

	var normal_entry = FxvDto.CommitRef.from_dict({
		"commit": {"branch": "main", "revision": 1, "type": "published"},
		"description": "Standard commit",
		"timestamp_millis_since_epoch_utc": 1700000000000,
		"author_id": "alice"
	})
	var resolve_entry = FxvDto.CommitRef.from_dict({
		"commit": {"branch": "main", "type": "draft", "draft_revision": 3},
		"description": "",
		"timestamp_millis_since_epoch_utc": 1700000001000,
		"author_id": "bob"
	})

	var hp = FxvDto.HistoryPayload.new()
	hp.entries.append(normal_entry)
	hp.entries.append(resolve_entry)

	var res = FxvRunner.FxvResult.new()
	res.success = true
	res.data = hp

	dock._on_history_loaded(res, "")
	var tree = dock._history_tree
	assert(tree != null, "History tree missing")
	var root = tree.get_root()
	assert(root != null, "History tree root missing")
	var item1 = root.get_first_child()
	assert(item1 != null, "First item missing")
	assert(item1.get_text(3) == "Standard commit", "Normal commit description mismatch: " + item1.get_text(3))

	var item2 = item1.get_next()
	assert(item2 != null, "Second item missing")
	assert(item2.get_text(3) == "Resolved conflict (mine): player.tscn", "Resolve description fallback mismatch: " + item2.get_text(3))

	cache.clear()
	dock.free()
	print("FxvBottomDock OK.")


