@tool
extends SceneTree

func _init():
	print("--- Running Godot In-Engine Tests ---")
	test_version_guard()
	test_meta_helper()
	test_dto()
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
	print("FxvDto OK.")

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
	print("FxvRunner OK.")

func test_ui():
	print("Testing FxvBottomDock UI...")
	var dock = FxvBottomDock.new()
	assert(dock != null, "Dock instantiation failed")
	dock.free()
	print("FxvBottomDock OK.")


