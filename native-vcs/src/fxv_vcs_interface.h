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
class FlexVault : public EditorVCSInterface {
	GDCLASS(FlexVault, EditorVCSInterface);

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

	// Godot's EditorVCSInterface marks these virtuals "required" - the engine hard-errors the
	// moment it calls one that isn't overridden at all, even if the corresponding UI action
	// (credentials, remotes, push/pull/fetch, live per-keystroke diff) is never used. FlexVault
	// has no equivalent concept for any of these (single server, no git-style remotes, no
	// staging), so they're safe no-ops/empty-results rather than real functionality.
	void _set_credentials(const String &p_username, const String &p_password, const String &p_ssh_public_key_path, const String &p_ssh_private_key_path, const String &p_ssh_passphrase) override;
	TypedArray<String> _get_remotes() override;
	void _create_branch(const String &p_branch_name) override;
	void _remove_branch(const String &p_branch_name) override;
	void _create_remote(const String &p_remote_name, const String &p_remote_url) override;
	void _remove_remote(const String &p_remote_name) override;
	void _pull(const String &p_remote) override;
	void _push(const String &p_remote, bool p_force) override;
	void _fetch(const String &p_remote) override;
	TypedArray<Dictionary> _get_line_diff(const String &p_file_path, const String &p_text) override;

private:
	String repo_project_path;
};

} // namespace godot

#endif // FXV_VCS_INTERFACE_H
