#include "register_types.h"

#include "fxv_vcs_interface.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/godot.hpp>

using namespace godot;

void initialize_fxv_vcs_module(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_EDITOR) {
		return;
	}
	// Registering the class is all that's needed - Godot's Version Control Settings dialog
	// discovers it via ClassDB::get_inheriters_from_class("EditorVCSInterface") and
	// instantiates it itself once the user picks "FlexVault" from that list.
	ClassDB::register_class<FlexVault>();
}

void uninitialize_fxv_vcs_module(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_EDITOR) {
		return;
	}
}

extern "C" {
GDExtensionBool GDE_EXPORT fxv_vcs_library_init(GDExtensionInterfaceGetProcAddress p_get_proc_address, GDExtensionClassLibraryPtr p_library, GDExtensionInitialization *r_initialization) {
	godot::GDExtensionBinding::InitObject init_obj(p_get_proc_address, p_library, r_initialization);

	init_obj.register_initializer(initialize_fxv_vcs_module);
	init_obj.register_terminator(uninitialize_fxv_vcs_module);
	init_obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_EDITOR);

	return init_obj.init();
}
}
