extends SceneTree


const BOUNDS_EPSILON: float = 0.05

var failures: int = 0
var native_stroker: Object


func _init() -> void:
	if not ClassDB.class_exists(&"CubicStrokeTessellatorNative"):
		push_error("CubicStrokeTessellatorNative is not registered; build the GDExtension first")
		quit(1)
		return

	native_stroker = ClassDB.instantiate(&"CubicStrokeTessellatorNative")
	_test_stroke(
		"straight cubic",
		Vector2(0.0, 0.0),
		Vector2(30.0, 0.0),
		Vector2(70.0, 0.0),
		Vector2(100.0, 0.0),
		20.0
	)
	_test_stroke(
		"lizard repeated elbow controls",
		Vector2(0.0, 0.0),
		Vector2(60.0, 90.0),
		Vector2(60.0, 90.0),
		Vector2(120.0, 0.0),
		40.0
	)
	_test_stroke(
		"cusp and reversal",
		Vector2(0.0, 0.0),
		Vector2(100.0, 0.0),
		Vector2(-100.0, 0.0),
		Vector2(0.0, 0.0),
		32.0
	)
	_test_stroke(
		"fully degenerate cubic",
		Vector2(5.0, 5.0),
		Vector2(5.0, 5.0),
		Vector2(5.0, 5.0),
		Vector2(5.0, 5.0),
		20.0
	)
	_test_invalid_inputs()

	if failures == 0:
		print("CubicStrokeTessellatorNative tests passed")
		quit()
	else:
		push_error("CubicStrokeTessellatorNative: %d test(s) failed" % failures)
		quit(1)


func _test_stroke(
	test_name: String,
	start: Vector2,
	control_1: Vector2,
	control_2: Vector2,
	end: Vector2,
	width: float
) -> void:
	var triangles := _native_tessellate(
		start, control_1, control_2, end, width
	)
	if triangles.is_empty():
		_fail("%s returned no triangles" % test_name)
		return
	if triangles.size() % 3 != 0:
		_fail("%s returned incomplete triangles" % test_name)
		return

	# A Bezier curve stays inside its control-point convex hull. Its round
	# stroke must therefore stay inside that hull's AABB expanded by radius.
	var bounds := Rect2(start, Vector2.ZERO)
	for point in [control_1, control_2, end]:
		bounds = bounds.expand(point)
	bounds = bounds.grow(width * 0.5 + BOUNDS_EPSILON)
	for point in triangles:
		if not point.is_finite() or not bounds.has_point(point):
			_fail("%s returned an invalid spike vertex: %s" % [test_name, point])
			return

	for i in range(0, triangles.size(), 3):
		var twice_area := absf(
			(triangles[i + 1] - triangles[i]).cross(
				triangles[i + 2] - triangles[i]
			)
		)
		if twice_area <= 0.000001:
			_fail("%s returned a degenerate triangle" % test_name)
			return


func _test_invalid_inputs() -> void:
	var invalid_point := _native_tessellate(
		Vector2(NAN, 0.0), Vector2.ZERO, Vector2.ONE, Vector2.RIGHT, 10.0
	)
	if not invalid_point.is_empty():
		_fail("non-finite coordinates should return no triangles")

	var invalid_width := _native_tessellate(
		Vector2.ZERO, Vector2.RIGHT, Vector2.RIGHT * 2.0, Vector2.RIGHT * 3.0, 0.0
	)
	if not invalid_width.is_empty():
		_fail("a non-positive width should return no triangles")


func _native_tessellate(
	start: Vector2,
	control_1: Vector2,
	control_2: Vector2,
	end: Vector2,
	width: float
) -> PackedVector2Array:
	var result: Variant = native_stroker.call(
		&"tessellate", start, control_1, control_2, end, width, 0.2, 12, 0
	)
	if result is PackedVector2Array:
		return result as PackedVector2Array
	return PackedVector2Array()


func _fail(message: String) -> void:
	failures += 1
	push_error(message)
