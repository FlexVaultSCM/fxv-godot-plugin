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

	var res_12 = FxvVersionGuard.check_version("0.12.0")
	assert(res_12["compatible"] == true, "0.12.0 should be compatible")

	var res_old = FxvVersionGuard.check_version("0.10.1")
	assert(res_old["compatible"] == false, "0.10.1 should be incompatible")

	var res_high = FxvVersionGuard.check_version("0.13.0")
	assert(res_high["compatible"] == false, "0.13.0 should be incompatible")
	assert(res_high["error"].find("update the FlexVault Godot plugin") != -1, "High version error message mismatch: " + res_high["error"])

	FxvVersionGuard.set_incompatible("custom error")
	assert(FxvVersionGuard.is_compatible() == false, "Should be marked incompatible")
	assert(FxvVersionGuard.get_last_error_message() == "custom error", "Error message mismatch")
	FxvVersionGuard.reset_cached_version()

	assert(FxvVersionGuard.get_min_version_string() == "0.11.0", "Min version string mismatch")
	assert(FxvVersionGuard.get_max_version_string() == "0.13.0", "Max version string mismatch")

	# Regression: SemVer's _to_string() override must actually be dispatched to by .to_string(),
	# not fall back to Object's default "<RefCounted#...>" representation.
	var res_low = FxvVersionGuard.check_version("0.5.0")
	assert(res_low["error"].find("RefCounted") == -1, "check_version() error leaked default Object repr: " + res_low["error"])
	assert(res_low["error"].find("0.11.0") != -1 and res_low["error"].find("0.13.0") != -1, "check_version() error missing version bounds: " + res_low["error"])
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

	# resolve_openable_repo_path resolves existing base asset for .uid/.import companions
	var resolved_base = FxvMetaHelper.resolve_openable_repo_path("addons/flexvault/flexvault_plugin.gd.uid", repo_root)
	assert(resolved_base == "addons/flexvault/flexvault_plugin.gd", "Should resolve .uid companion to existing script: " + resolved_base)
	var resolved_missing = FxvMetaHelper.resolve_openable_repo_path("missing/file.gd.uid", repo_root)
	assert(resolved_missing == "missing/file.gd.uid", "Should keep companion path when base asset does not exist: " + resolved_missing)
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

	# Fetch payload DTO test
	var fetch_dict = {
		"bytes_downloaded": 1024,
		"repaired_files": ["corrupt.bin"]
	}
	var fetch_payload = FxvDto.FetchPayload.from_dict(fetch_dict)
	assert(fetch_payload.bytes_downloaded == 1024, "Bytes downloaded mismatch")
	assert(fetch_payload.repaired_files == ["corrupt.bin"], "Repaired files mismatch")
	print("FxvDto OK.")

func test_settings():
	print("Testing FxvSettings...")
	var proj_root = FxvSettings.get_project_root()
	assert(not proj_root.is_empty(), "Project root should not be empty")
	var repo_root = FxvSettings.get_repository_root()
	assert(not repo_root.is_empty(), "Repository root should not be empty")
	var bin_path = FxvSettings.get_effective_binary_path()
	assert(not bin_path.is_empty(), "Effective binary path should not be empty")
	var fetch_period = FxvSettings.get_fetch_period_seconds()
	assert(fetch_period == 120.0, "Default fetch period should be 120.0: " + str(fetch_period))

	var win_cands = FxvSettings.build_terminal_launch_candidates("C:/Projects/MyGame", "Windows")
	assert(win_cands.size() >= 3, "Windows should have at least 3 terminal candidates")
	assert(win_cands[0]["command"] == "wt.exe", "First Windows candidate should be wt.exe")
	assert(win_cands[0]["args"] == ["-d", "C:\\Projects\\MyGame"], "wt.exe args mismatch: " + str(win_cands[0]["args"]))
	assert(win_cands[1]["command"] == "powershell.exe", "Second Windows candidate should be powershell.exe")

	var mac_cands = FxvSettings.build_terminal_launch_candidates("/Users/dev/MyGame", "macOS")
	assert(mac_cands.size() == 1 and mac_cands[0]["command"] == "open", "macOS candidate should use open -a Terminal")
	assert(mac_cands[0]["args"] == ["-a", "Terminal", "/Users/dev/MyGame"], "macOS args mismatch")

	var linux_cands = FxvSettings.build_terminal_launch_candidates("/home/dev/MyGame", "Linux")
	assert(linux_cands.size() >= 3, "Linux should have multiple terminal candidates")
	assert(linux_cands[0]["command"] == "x-terminal-emulator", "First Linux candidate should be x-terminal-emulator")
	print("FxvSettings OK.")

func test_runner():
	print("Testing FxvRunner...")
	var has_checked = FxvRunner.ensure_version_checked()
	print("ensure_version_checked result: ", has_checked)

	var full_args = FxvRunner.build_integration_register_args("/tmp/ws", "0.6.0", "0.11.0", "0.13.0")
	assert(full_args == ["integration", "register", "--name", "godot", "--plugin-version", "0.6.0", "--min", "0.11.0", "--max-version", "0.13.0", "--workspace", "/tmp/ws"], "Full integration register args mismatch: " + str(full_args))

	var unknown_plugin_args = FxvRunner.build_integration_register_args("/tmp/ws", "Unknown", "0.11.0", "0.13.0")
	assert(not unknown_plugin_args.has("--plugin-version"), "Unknown plugin version should be omitted: " + str(unknown_plugin_args))

	var empty_plugin_args = FxvRunner.build_integration_register_args("/tmp/ws", "", "0.11.0", "0.13.0")
	assert(not empty_plugin_args.has("--plugin-version"), "Empty plugin version should be omitted: " + str(empty_plugin_args))

	var fetch_args = FxvRunner.build_fetch_args()
	assert(fetch_args == ["fetch"], "Fetch args mismatch: " + str(fetch_args))
	var fetch_repair_args = FxvRunner.build_fetch_args(true)
	assert(fetch_repair_args == ["fetch", "--repair"], "Fetch repair args mismatch: " + str(fetch_repair_args))
	print("FxvRunner OK.")

func test_ui():
	print("Testing FxvBottomDock UI...")
	var dock = FxvBottomDock.new()
	assert(dock != null, "Dock instantiation failed")
	dock._build_ui()
	assert(dock._publish_btn != null, "Publish button should be created")
	assert(dock._terminal_btn != null, "Terminal button should be created")
	assert(dock._terminal_btn.text == "Terminal", "Terminal button text should be 'Terminal'")
	dock._update_publish_button()
	assert(dock._publish_btn.text == "Publish", "Publish button text should default to 'Publish'")
	assert(dock._publish_btn.disabled == false, "Publish button should not be disabled when not busy and not playing")

	dock._busy = true
	dock._update_publish_button()
	assert(dock._publish_btn.disabled == true, "Publish button should be disabled when busy")
	assert(dock._publish_btn.text == "Publish", "Publish button text should remain 'Publish' when busy and not playing")

	dock._busy = false
	dock._update_publish_button()
	assert(dock._publish_btn.disabled == false, "Publish button should be re-enabled when busy clears")

	dock.free()
	print("FxvBottomDock OK.")



