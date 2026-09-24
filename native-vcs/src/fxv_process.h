#ifndef FXV_PROCESS_H
#define FXV_PROCESS_H

#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/variant.hpp>

// Thin bridge to the `fxv` CLI, mirroring addons/flexvault/core/fxv_runner.gd's envelope
// handling so the native VCS panel and the GDScript dock report identical state.
namespace fxv {

struct CliResult {
	bool success = false;
	int exit_code = -1;
	godot::Variant data;
	godot::String error_message;
	godot::String raw_stdout;
};

// Resolves the fxv executable the same way FxvSettings.get_effective_binary_path() does:
// EditorSettings override, then well-known install locations, then bare PATH lookup.
godot::String find_binary();

// Runs `fxv <args> --format json --unattended --no-color` (format is skipped for commands
// that don't emit JSON) and unwraps the {program, message: {kind, payload}} envelope.
CliResult run(const godot::PackedStringArray &p_args);

// Runs `fxv cat [-r <revision>] <path>` and returns the raw file content. Unlike run(), this
// is not JSON-wrapped - the CLI just prints the file bytes.
bool cat(const godot::String &p_repo_relative_path, const godot::String &p_revision, godot::String &r_content);

} // namespace fxv

#endif // FXV_PROCESS_H
