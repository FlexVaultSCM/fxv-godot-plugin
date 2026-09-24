#include "fxv_process.h"

#include <vector>

#include <godot_cpp/classes/editor_interface.hpp>
#include <godot_cpp/classes/editor_settings.hpp>
#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/classes/json.hpp>
#include <godot_cpp/classes/os.hpp>
#include <godot_cpp/variant/array.hpp>

using namespace godot;

namespace fxv {

String find_binary() {
	OS *os = OS::get_singleton();
	String os_name = os->get_name();
	String bin_name = (os_name == "Windows") ? "fxv.exe" : "fxv";

	// Same Editor Settings override key the GDScript addon exposes, so a custom binary path
	// set once (Editor Settings > Version Control > FlexVault) applies to both integrations.
	// EditorInterface has no get_singleton() of its own in godot-cpp; it's fetched through
	// the Engine singleton registry like any other editor-only singleton.
	EditorInterface *ei = Object::cast_to<EditorInterface>(Engine::get_singleton()->get_singleton("EditorInterface"));
	if (ei != nullptr) {
		Ref<EditorSettings> es = ei->get_editor_settings();
		if (es.is_valid() && es->has_setting("version_control/flexvault/binary_path")) {
			String custom = String(es->get_setting("version_control/flexvault/binary_path")).strip_edges();
			if (!custom.is_empty() && FileAccess::file_exists(custom)) {
				return custom;
			}
		}
	}

	if (os_name == "Windows") {
		String local_app_data = os->get_environment("LOCALAPPDATA");
		if (!local_app_data.is_empty()) {
			String cand = local_app_data.path_join("fxv").path_join("bin").path_join(bin_name);
			if (FileAccess::file_exists(cand)) {
				return cand;
			}
		}
		String prog_files = os->get_environment("ProgramFiles");
		if (!prog_files.is_empty()) {
			String cand = prog_files.path_join("FlexVault").path_join("bin").path_join(bin_name);
			if (FileAccess::file_exists(cand)) {
				return cand;
			}
		}
	} else {
		PackedStringArray unix_candidates;
		unix_candidates.push_back("/usr/local/bin/" + bin_name);
		unix_candidates.push_back("/opt/homebrew/bin/" + bin_name);
		String home = os->get_environment("HOME");
		if (!home.is_empty()) {
			unix_candidates.push_back(home.path_join(".cargo/bin/" + bin_name));
		}
		for (int i = 0; i < unix_candidates.size(); i++) {
			if (FileAccess::file_exists(unix_candidates[i])) {
				return unix_candidates[i];
			}
		}
	}

	String path_env = os->get_environment("PATH");
	if (!path_env.is_empty()) {
		String sep = (os_name == "Windows") ? ";" : ":";
		PackedStringArray dirs = path_env.split(sep, false);
		for (int i = 0; i < dirs.size(); i++) {
			String trimmed = dirs[i].strip_edges();
			if (trimmed.is_empty()) {
				continue;
			}
			String candidate = trimmed.path_join(bin_name);
			if (FileAccess::file_exists(candidate)) {
				return candidate;
			}
		}
	}

	// Fall back to a bare name and let the OS's own process-launch search handle it, same as
	// FxvSettings.get_effective_binary_path()'s final fallback.
	return bin_name;
}

CliResult run(const PackedStringArray &p_args) {
	CliResult result;

	String bin_path = find_binary();

	std::vector<String> args_vec;
	for (int i = 0; i < p_args.size(); i++) {
		args_vec.push_back(p_args[i]);
	}

	String primary = args_vec.size() > 0 ? args_vec[0].to_lower() : String();
	bool is_json_cmd = primary != "snapshot" && primary != "publish";

	if (is_json_cmd) {
		args_vec.push_back("--format");
		args_vec.push_back("json");
	}
	args_vec.push_back("--unattended");
	args_vec.push_back("--no-color");

	PackedStringArray full_args;
	for (size_t i = 0; i < args_vec.size(); i++) {
		full_args.push_back(args_vec[i]);
	}

	Array output;
	int exit_code = OS::get_singleton()->execute(bin_path, full_args, output, true);

	result.exit_code = exit_code;
	result.raw_stdout = output.size() > 0 ? String(output[0]) : String();

	if (!result.raw_stdout.is_empty()) {
		String trimmed = result.raw_stdout.strip_edges();
		int first_brace = trimmed.find("{");
		int last_brace = trimmed.rfind("}");
		if (first_brace >= 0 && last_brace > first_brace) {
			String json_str = trimmed.substr(first_brace, last_brace - first_brace + 1);
			Variant parsed = JSON::parse_string(json_str);
			if (parsed.get_type() == Variant::DICTIONARY) {
				Dictionary envelope = parsed;
				Dictionary msg = envelope.get("message", Dictionary());
				if (!msg.is_empty()) {
					String kind = msg.get("kind", "");
					if (kind == "error") {
						Dictionary payload = msg.get("payload", Dictionary());
						result.success = false;
						result.error_message = payload.get("message", "FlexVault CLI returned an error.");
						return result;
					}

					result.success = (exit_code == 0);
					result.data = msg.get("payload", Variant());
					return result;
				}
			}
		}
	}

	result.success = (exit_code == 0);
	if (!result.success) {
		result.error_message = !result.raw_stdout.is_empty() ? result.raw_stdout : (String("Command failed with exit code ") + String::num_int64(exit_code));
	}
	return result;
}

bool cat(const String &p_repo_relative_path, const String &p_revision, String &r_content) {
	String bin_path = find_binary();

	PackedStringArray args;
	args.push_back("cat");
	if (!p_revision.is_empty()) {
		args.push_back("-r");
		args.push_back(p_revision);
	}
	args.push_back(p_repo_relative_path);

	Array output;
	int exit_code = OS::get_singleton()->execute(bin_path, args, output, false);
	if (exit_code != 0 || output.size() == 0) {
		return false;
	}
	r_content = output[0];
	return true;
}

} // namespace fxv
