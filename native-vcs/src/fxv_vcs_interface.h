#ifndef FXV_VCS_INTERFACE_H
#define FXV_VCS_INTERFACE_H

#include <godot_cpp/classes/editor_vcs_interface.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/typed_array.hpp>

namespace godot {

// Bridges Godot's built-in Project > Version Control panel to the `fxv` CLI, so a FlexVault
// workspace shows up there instead of the "No VCS plugins are available" dialog.
//
// FlexVault has no git-style staging area - every changed file is always part of the next
// `fxv snapshot`. _get_modified_files_data() reports everything as TREE_AREA_STAGED to match
// that model (the Unstaged list is intentionally always empty), and stage/unstage are no-ops.
class FxvVcsInterface : public EditorVCSInterface {
	GDCLASS(FxvVcsInterface, EditorVCSInterface);

protected:
	static void _bind_methods();

public:
	bool _initialize(const String &p_project_path) override;
	bool _shut_down() override;
	String _get_vcs_name() override;

	TypedArray<Dictionary> _get_modified_files_data() override;
	void _stage_file(const String &p_file_path) override;
	void _unstage_file(const String &p_file_path) override;
	void _discard_file(const String &p_file_path) override;
	void _commit(const String &p_msg) override;
	TypedArray<Dictionary> _get_diff(const String &p_identifier, int32_t p_area) override;

	TypedArray<Dictionary> _get_previous_commits(int32_t p_max_commits) override;
	TypedArray<String> _get_branch_list() override;
	String _get_current_branch_name() override;
	bool _checkout_branch(const String &p_branch_name) override;

private:
	String repo_project_path;
};

} // namespace godot

#endif // FXV_VCS_INTERFACE_H
