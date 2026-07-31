#ifndef NON_ZERO_PATH_TESSELLATOR_NATIVE_H
#define NON_ZERO_PATH_TESSELLATOR_NATIVE_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>

namespace godot {

class NonZeroPathTessellatorNative : public RefCounted {
	GDCLASS(NonZeroPathTessellatorNative, RefCounted)

protected:
	static void _bind_methods();

public:
	PackedVector2Array tessellate(const PackedVector2Array &p_contour, double p_epsilon = 0.001) const;
};

} // namespace godot

#endif
