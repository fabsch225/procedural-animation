#ifndef CUBIC_STROKE_TESSELLATOR_NATIVE_H
#define CUBIC_STROKE_TESSELLATOR_NATIVE_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/vector2.hpp>

namespace godot {

class CubicStrokeTessellatorNative : public RefCounted {
	GDCLASS(CubicStrokeTessellatorNative, RefCounted)

protected:
	static void _bind_methods();

public:
	PackedVector2Array tessellate(
			const Vector2 &p_start,
			const Vector2 &p_control_1,
			const Vector2 &p_control_2,
			const Vector2 &p_end,
			double p_width,
			double p_tolerance = 0.2,
			int p_max_depth = 12,
			int p_circle_segments = 0) const;
};

} // namespace godot

#endif
