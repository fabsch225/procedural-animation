#include "register_types.h"

#include "non_zero_path_tessellator_native.h"

#include <gdextension_interface.h>
#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/godot.hpp>

using namespace godot;

void initialize_non_zero_tessellator_module(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
		return;
	}
	GDREGISTER_CLASS(NonZeroPathTessellatorNative);
}

void uninitialize_non_zero_tessellator_module(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
		return;
	}
}

extern "C" {
GDExtensionBool GDE_EXPORT non_zero_tessellator_library_init(
		GDExtensionInterfaceGetProcAddress p_get_proc_address,
		GDExtensionClassLibraryPtr p_library,
		GDExtensionInitialization *r_initialization) {
	GDExtensionBinding::InitObject init_object(p_get_proc_address, p_library, r_initialization);
	init_object.register_initializer(initialize_non_zero_tessellator_module);
	init_object.register_terminator(uninitialize_non_zero_tessellator_module);
	init_object.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
	return init_object.init();
}
}
