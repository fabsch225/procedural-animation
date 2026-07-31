class_name ProcessingShape2D
extends RefCounted


@export_range(1, 64, 1) var curve_resolution: int = 16
@export_range(-5.0, 1.0, 0.01) var curve_tightness: float = 0.0
@export var adaptive_curve_flattening: bool = true
@export_range(0.01, 4.0, 0.01) var curve_tolerance: float = 0.35
@export_range(1, 16, 1) var maximum_curve_depth: int = 10

var _curve_vertices := PackedVector2Array()
var _path := PackedVector2Array()
var _shape_started: bool = false


func begin_shape() -> void:
	_curve_vertices.clear()
	_path.clear()
	_shape_started = true


func vertex(point: Vector2) -> void:
	_assert_shape_started()
	_path.append(point)


func curve_vertex(point: Vector2) -> void:
	_assert_shape_started()
	_curve_vertices.append(point)
	if _curve_vertices.size() < 4:
		return

	var count := _curve_vertices.size()
	_append_curve_segment(
		_curve_vertices[count - 4],
		_curve_vertices[count - 3],
		_curve_vertices[count - 2],
		_curve_vertices[count - 1]
	)


func end_shape(close: bool = false) -> PackedVector2Array:
	_assert_shape_started()
	_shape_started = false
	if close and not _path.is_empty() and not _path[-1].is_equal_approx(_path[0]):
		_path.append(_path[0])
	return _path.duplicate()


func _append_curve_segment(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2) -> void:
	# Processing converts each four-point curveVertex window to a cubic
	# Bézier. At the default tightness of 0, this is Catmull-Rom / 6.
	var handle_scale := (1.0 - curve_tightness) / 6.0
	var control_1 := p1 + (p2 - p0) * handle_scale
	var control_2 := p2 - (p3 - p1) * handle_scale

	if _path.is_empty():
		_path.append(p1)

	if adaptive_curve_flattening:
		_append_cubic_adaptive(p1, control_1, control_2, p2, 0)
		return

	for step in range(1, curve_resolution + 1):
		var weight := float(step) / float(curve_resolution)
		var inverse := 1.0 - weight
		_path.append(
			inverse * inverse * inverse * p1
			+ 3.0 * inverse * inverse * weight * control_1
			+ 3.0 * inverse * weight * weight * control_2
			+ weight * weight * weight * p2
		)


func _append_cubic_adaptive(
	p0: Vector2,
	p1: Vector2,
	p2: Vector2,
	p3: Vector2,
	depth: int
) -> void:
	if depth >= maximum_curve_depth or _cubic_is_flat_enough(p0, p1, p2, p3):
		_path.append(p3)
		return

	var p01 := (p0 + p1) * 0.5
	var p12 := (p1 + p2) * 0.5
	var p23 := (p2 + p3) * 0.5
	var p012 := (p01 + p12) * 0.5
	var p123 := (p12 + p23) * 0.5
	var midpoint := (p012 + p123) * 0.5
	_append_cubic_adaptive(p0, p01, p012, midpoint, depth + 1)
	_append_cubic_adaptive(midpoint, p123, p23, p3, depth + 1)


func _cubic_is_flat_enough(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2) -> bool:
	var baseline := p3 - p0
	var baseline_length := baseline.length()
	if baseline_length <= 0.000001:
		return maxf(p0.distance_to(p1), p0.distance_to(p2)) <= curve_tolerance

	var first_distance := absf(baseline.cross(p1 - p0)) / baseline_length
	var second_distance := absf(baseline.cross(p2 - p0)) / baseline_length
	return maxf(first_distance, second_distance) <= curve_tolerance


func _assert_shape_started() -> void:
	assert(_shape_started, "begin_shape() must be called before adding vertices")
