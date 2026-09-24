#ifndef FXV_LINE_DIFF_H
#define FXV_LINE_DIFF_H

#include <godot_cpp/classes/editor_vcs_interface.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/typed_array.hpp>

// FlexVault has no local git-style object database to diff against, so instead of shelling
// out per hunk we pull the two full file blobs (working copy + `fxv cat`) and diff them here.
namespace fxv_line_diff {

// Builds Godot's diff-hunk Dictionary structure (via EditorVCSInterface's own
// create_diff_hunk/create_diff_line/add_line_diffs_into_diff_hunk helpers) for the given
// old/new file contents. `p_self` only supplies those helper methods; it isn't mutated.
godot::TypedArray<godot::Dictionary> build_hunks(godot::EditorVCSInterface &p_self, const godot::String &p_old_text, const godot::String &p_new_text);

} // namespace fxv_line_diff

#endif // FXV_LINE_DIFF_H
