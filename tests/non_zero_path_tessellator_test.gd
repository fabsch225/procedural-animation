extends SceneTree


const Tessellator := preload("res://scripts/non_zero_path_tessellator_2d.gd")
const TOLERANCE: float = 0.01

var failures: int = 0


func _init() -> void:
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
		print("NonZeroPathTessellator2D tests passed")
		quit()
	else:
		push_error("NonZeroPathTessellator2D: %d test(s) failed" % failures)
		quit(1)


func _test_area(test_name: String, contour: PackedVector2Array, expected_area: float) -> void:
	var triangles: PackedVector2Array = Tessellator.tessellate(contour)
	if triangles.size() % 3 != 0:
		failures += 1
		push_error("%s returned incomplete triangles" % test_name)
		return

	var area := 0.0
	for i in range(0, triangles.size(), 3):
		area += absf(
			(triangles[i + 1] - triangles[i]).cross(triangles[i + 2] - triangles[i])
		) * 0.5
	if absf(area - expected_area) > TOLERANCE:
		failures += 1
		push_error("%s area was %f, expected %f" % [test_name, area, expected_area])
