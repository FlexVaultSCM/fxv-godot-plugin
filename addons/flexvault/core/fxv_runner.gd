@tool
class_name FxvRunner
extends RefCounted

## Executes the fxv CLI and deserializes JSON wire-format payloads.

class FxvResult extends RefCounted:
	var success: bool = false
	var exit_code: int = -1
	var data: Variant = null
	var error_message: String = ""
	var raw_stdout: String = ""
	var raw_stderr: String = ""


static func ensure_version_checked(custom_binary_path: String = "") -> bool:
	if FxvVersionGuard.is_compatible() != null:
		return bool(FxvVersionGuard.is_compatible())

	var bin_path := custom_binary_path if not custom_binary_path.is_empty() else FxvSettings.get_effective_binary_path()
	if bin_path.is_empty():
		return false

	var output: Array = []
	var exit_code := OS.execute(bin_path, ["--version"], output, true)
	if exit_code == 0 and output.size() > 0:
		var stdout_str: String = str(output[0]).strip_edges()
		var parts := stdout_str.split(" ")
		var version_part := parts[1] if parts.size() > 1 else parts[0]
		return FxvVersionGuard.check_and_cache(version_part)

	return false


static func run_command(
	args: Array,
	custom_binary_path: String = "",
	custom_working_dir: String = ""
) -> FxvResult:
	var result := FxvResult.new()

	if FxvVersionGuard.is_compatible() == false:
		result.success = false
		result.error_message = FxvVersionGuard.get_last_error_message()
		if result.error_message.is_empty():
			result.error_message = "Incompatible FlexVault CLI version."
		return result

	var bin_path := custom_binary_path if not custom_binary_path.is_empty() else FxvSettings.get_effective_binary_path()
	var working_dir := custom_working_dir if not custom_working_dir.is_empty() else FxvSettings.get_repository_root()

	if bin_path.is_empty():
		result.success = false
		result.error_message = "FlexVault CLI executable (fxv) could not be located."
		return result

	var full_args: Array = []
	for a in args:
		full_args.append(str(a))

	var primary_cmd: String = full_args[0].to_lower() if full_args.size() > 0 else ""
	var is_json_cmd := (primary_cmd != "snapshot" and primary_cmd != "publish")

	if is_json_cmd and not full_args.has("--format"):
		full_args.append("--format")
		full_args.append("json")

	if not full_args.has("--unattended"):
		full_args.append("--unattended")

	if not full_args.has("--no-color"):
		full_args.append("--no-color")

	# Execute CLI
	# Note: OS.execute in Godot captures stdout and stderr combined into the output array.
	var output: Array = []
	var prev_dir := ""
	# On desktop systems, changing directory or running with proper working directory is essential
	var exit_code: int = -1

	# We can use OS.execute
	# In Godot 4, OS.execute(path, args, output, read_stderr, open_console)
	exit_code = OS.execute(bin_path, full_args, output, true)

	result.exit_code = exit_code
	result.raw_stdout = str(output[0]) if output.size() > 0 else ""

	if not result.raw_stdout.is_empty():
		var trimmed := result.raw_stdout.strip_edges()
		var first_brace := trimmed.find("{")
		var last_brace := trimmed.rfind("}")
		if first_brace >= 0 and last_brace > first_brace:
			var json_str := trimmed.substr(first_brace, last_brace - first_brace + 1)
			var json_obj = JSON.parse_string(json_str)
			if json_obj is Dictionary:
				var envelope: Dictionary = json_obj
				var program_dict: Dictionary = envelope.get("program", {})
				if program_dict.has("version") and not str(program_dict["version"]).is_empty():
					var v_str: String = str(program_dict["version"])
					if not FxvVersionGuard.check_and_cache(v_str):
						result.success = false
						result.error_message = FxvVersionGuard.get_last_error_message()
						return result

				var msg_dict: Dictionary = envelope.get("message", {})
				if not msg_dict.is_empty():
					var kind: String = msg_dict.get("kind", "")
					if kind == "error":
						var payload: Dictionary = msg_dict.get("payload", {})
						result.success = false
						result.error_message = payload.get("message", "FlexVault CLI returned an error.")
						return result

					result.success = (result.exit_code == 0)
					result.data = msg_dict.get("payload", null)
					return result

	result.success = (result.exit_code == 0)
	if not result.success:
		result.error_message = result.raw_stdout if not result.raw_stdout.is_empty() else "Command failed with exit code %d" % result.exit_code

	return result


static func get_status(skip_scan: bool = false) -> FxvResult:
	var args := ["status"]
	if skip_scan:
		args.append("--skip-scan")
		args.append("--skip-remote-update")

	var res := run_command(args)
	if res.success and res.data is Dictionary:
		res.data = FxvDto.StatusPayload.from_dict(res.data)
	return res


static func snapshot(description: String) -> FxvResult:
	var args := ["snapshot"]
	if not description.is_empty():
		args.append("-d")
		args.append(description)
	return run_command(args)


static func publish(description: String) -> FxvResult:
	var args := ["publish"]
	if not description.is_empty():
		args.append("-d")
		args.append(description)
	return run_command(args)


static func sync_workspace(revision: String = "") -> FxvResult:
	var args := ["sync"]
	if not revision.is_empty():
		args.append(revision)
	var res := run_command(args)
	if res.success and res.data is Dictionary:
		res.data = FxvDto.WorkspaceSyncPayload.from_dict(res.data)
	return res


static func goto_revision(revision: String) -> FxvResult:
	var args := ["goto", revision]
	var res := run_command(args)
	if res.success and res.data is Dictionary:
		res.data = FxvDto.WorkspaceSyncPayload.from_dict(res.data)
	return res


static func revert(paths: Array) -> FxvResult:
	var args := ["revert"]
	for p in paths:
		if not str(p).strip_edges().is_empty():
			args.append(str(p))
	var res := run_command(args)
	if res.success and res.data is Dictionary:
		res.data = FxvDto.WorkspaceSyncPayload.from_dict(res.data)
	return res


static func resolve(action_mode: String, paths: Array = []) -> FxvResult:
	# action_mode: "mine", "theirs", "undo"
	var args := ["resolve"]
	if action_mode == "mine":
		args.append("--mine")
	elif action_mode == "theirs":
		args.append("--theirs")
	elif action_mode == "undo":
		args.append("--undo")

	if paths.size() > 0:
		for p in paths:
			if not str(p).strip_edges().is_empty():
				args.append(str(p))
	else:
		args.append("--all")

	var res := run_command(args)
	if res.success and res.data is Dictionary:
		res.data = FxvDto.WorkspaceSyncPayload.from_dict(res.data)
	return res


static func get_history(count: int = 30, branch: String = "") -> FxvResult:
	var args := ["history"]
	if count > 0:
		args.append("-n")
		args.append(str(count))
	if not branch.is_empty():
		args.append("-b")
		args.append(branch)

	var res := run_command(args)
	if res.success and res.data is Dictionary:
		res.data = FxvDto.HistoryPayload.from_dict(res.data)
	return res


static func get_change_info(revision: String) -> FxvResult:
	var args := ["changeinfo", revision]
	var res := run_command(args)
	if res.success and res.data is Dictionary:
		res.data = FxvDto.ChangeInfoPayload.from_dict(res.data)
	return res


static func login(username: String) -> FxvResult:
	return run_command(["login", username])


static func logout() -> FxvResult:
	return run_command(["logout"])


static func cat_to_file(repo_relative_path: String, revision: String, destination_file_path: String) -> bool:
	if FxvVersionGuard.is_compatible() == false:
		push_error("[FlexVault] cat_to_file blocked: " + FxvVersionGuard.get_last_error_message())
		return false

	var bin_path := FxvSettings.get_effective_binary_path()
	var working_dir := FxvSettings.get_repository_root()

	var output: Array = []
	var args := ["cat", revision, repo_relative_path]
	var exit_code := OS.execute(bin_path, args, output, true)

	if exit_code == 0 and output.size() > 0:
		var raw: String = str(output[0])
		var f := FileAccess.open(destination_file_path, FileAccess.WRITE)
		if f != null:
			f.store_string(raw)
			f.close()
			return true
	return false
