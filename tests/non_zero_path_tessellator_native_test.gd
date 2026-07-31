extends SceneTree


const GDSCRIPT_TESSELLATOR := preload("res://scripts/non_zero_path_tessellator_2d.gd")
const TOLERANCE: float = 0.01

var failures: int = 0
var native_tessellator: Object


func _init() -> void:
	if not ClassDB.class_exists(&"NonZeroPathTessellatorNative"):
		push_error("NonZeroPathTessellatorNative is not registered; build the GDExtension first")
		quit(1)
		return

	native_tessellator = ClassDB.instantiate(&"NonZeroPathTessellatorNative")
	_test_area(
		"simple square",
		PackedVector2Array([
			Vector2(0, 0), Vector2(10, 0), Vector2(10, 10), Vector2(0, 10),
		]),
		100.0
	)
	_test_area(
		"self-crossing bow tie",
		PackedVector2Array([
			Vector2(0, 0), Vector2(10, 10), Vector2(0, 10), Vector2(10, 0),
		]),
		50.0
	)
	_test_area(
		"twice-wound square",
		PackedVector2Array([
			Vector2(0, 0), Vector2(10, 0), Vector2(10, 10), Vector2(0, 10),
			Vector2(0, 0), Vector2(10, 0), Vector2(10, 10), Vector2(0, 10),
		]),
		100.0
	)
	_test_area(
		"opposite windings cancel",
		PackedVector2Array([
			Vector2(0, 0), Vector2(10, 0), Vector2(10, 10), Vector2(0, 10),
			Vector2(0, 0), Vector2(0, 10), Vector2(10, 10), Vector2(10, 0),
		]),
		0.0
	)

	if failures == 0:
		print("NonZeroPathTessellatorNative parity tests passed")
		quit()
	else:
		push_error("NonZeroPathTessellatorNative: %d test(s) failed" % failures)
		quit(1)


func _test_area(test_name: String, contour: PackedVector2Array, expected_area: float) -> void:
	var native_triangles := _native_tessellate(contour)
	var gdscript_triangles: PackedVector2Array = GDSCRIPT_TESSELLATOR.tessellate(contour)
	var native_area := _triangle_area(native_triangles)
	var gdscript_area := _triangle_area(gdscript_triangles)

	if native_triangles.size() % 3 != 0:
		failures += 1
		push_error("%s returned incomplete native triangles" % test_name)
		return
	if absf(native_area - expected_area) > TOLERANCE:
		failures += 1
		push_error("%s native area was %f, expected %f" % [test_name, native_area, expected_area])
	if absf(native_area - gdscript_area) > TOLERANCE:
		failures += 1
		push_error(
			"%s backends differ: native %f, GDScript %f"
			% [test_name, native_area, gdscript_area]
		)


func _native_tessellate(contour: PackedVector2Array) -> PackedVector2Array:
	var result: Variant = native_tessellator.call(&"tessellate", contour)
	if result is PackedVector2Array:
		return result as PackedVector2Array
	return PackedVector2Array()


func _triangle_area(triangles: PackedVector2Array) -> float:
	var area := 0.0
	for i in range(0, triangles.size(), 3):
		area += absf(
			(triangles[i + 1] - triangles[i]).cross(triangles[i + 2] - triangles[i])
		) * 0.5
	return area
