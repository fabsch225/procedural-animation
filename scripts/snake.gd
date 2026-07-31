class_name Snake
extends ChainBody


enum OutlineMode {
	SILHOUETTE,
	OVERLAPPING,
}

enum BodyRenderMode {
	GODOT_RIBBON,
	PROCESSING_VECTOR_FILL,
}

@export_group("Snake Appearance")
@export var body_render_mode: BodyRenderMode = BodyRenderMode.GODOT_RIBBON
@export var outline_mode: OutlineMode = OutlineMode.SILHOUETTE
@export_range(1, 20, 1) var curve_subdivisions: int = 12


func _draw_chain_body() -> void:
	if body_render_mode == BodyRenderMode.PROCESSING_VECTOR_FILL:
		_draw_processing_vector_body()
		_draw_standard_eyes()
		return

	var samples := _build_body_samples()
	# Every piece is convex, so self-crossings never require triangulating one
	# large, self-intersecting outline. Draw from tail to head for stable overlap.
	if outline_mode == OutlineMode.SILHOUETTE:
		_draw_body(samples, 0.0, outline_color)
		_draw_body(samples, outline_width, body_color)
	else:
		_draw_body(samples, 0.0, body_color)
		_draw_overlapping_outline(samples)

	_draw_standard_eyes()


func _draw_processing_vector_body() -> void:
	var path := _build_processing_outline()
	_draw_filled_path(path, body_color)


func get_active_tessellator_backend() -> StringName:
	match body_render_mode:
		BodyRenderMode.PROCESSING_VECTOR_FILL:
			return get_tessellator_backend()
		_:
			return &"not_applicable"


func _build_processing_outline() -> PackedVector2Array:
	var shape := _new_processing_shape()
	shape.begin_shape()

	for i in range(spine.joints.size()):
		shape.curve_vertex(_body_position(i, PI / 2.0))

	var tail_index := spine.joints.size() - 1
	shape.curve_vertex(_body_position(tail_index, PI))

	for i in range(tail_index, -1, -1):
		shape.curve_vertex(_body_position(i, -PI / 2.0))

	shape.curve_vertex(_body_position(0, -PI / 6.0))
	shape.curve_vertex(_body_position(0, 0.0))
	shape.curve_vertex(_body_position(0, PI / 6.0))

	# Processing curveVertex needs repeated leading vertices to render the
	# final segments of a closed curve, matching the original Snake.pde.
	for i in range(mini(3, spine.joints.size())):
		shape.curve_vertex(_body_position(i, PI / 2.0))

	return shape.end_shape(true)


func _draw_body(samples: Array[BodySample], inset: float, color: Color) -> void:
	for i in range(samples.size() - 2, -1, -1):
		var start_radius := maxf(0.0, samples[i].radius - inset)
		var end_radius := maxf(0.0, samples[i + 1].radius - inset)
		var start_normal := _sample_normal(samples, i)
		var end_normal := _sample_normal(samples, i + 1)
		var start_left := samples[i].position + start_normal * start_radius
		var end_left := samples[i + 1].position + end_normal * end_radius
		var end_right := samples[i + 1].position - end_normal * end_radius
		var start_right := samples[i].position - start_normal * start_radius
		_draw_triangle(start_left, end_left, end_right, color)
		_draw_triangle(start_left, end_right, start_right, color)

	var head_radius := maxf(0.0, samples[0].radius - inset)
	draw_colored_polygon(_build_head_cap(samples, head_radius), color)
	var tail_radius := maxf(0.0, samples.back().radius - inset)
	draw_colored_polygon(_build_tail_cap(samples, tail_radius), color)


func _draw_triangle(a: Vector2, b: Vector2, c: Vector2, color: Color) -> void:
	draw_primitive(
		PackedVector2Array([a, b, c]),
		PackedColorArray([color, color, color]),
		PackedVector2Array()
	)


func _draw_overlapping_outline(samples: Array[BodySample]) -> void:
	if outline_width <= 0.0:
		return

	var outline := PackedVector2Array()
	var last_sample := samples.size() - 1

	# First side, from head to tail.
	for i in range(samples.size()):
		outline.append(samples[i].position + _sample_normal(samples, i) * samples[i].radius)

	# Rounded tail, continuing around the end of the centerline.
	var tail_normal := _sample_normal(samples, last_sample)
	var tail_angle := tail_normal.angle()
	for step in range(1, 17):
		var angle := tail_angle + PI * float(step) / 16.0
		outline.append(samples[last_sample].position + Vector2.from_angle(angle) * samples[last_sample].radius)

	# Opposite side, from tail back to head.
	for i in range(last_sample - 1, -1, -1):
		outline.append(samples[i].position - _sample_normal(samples, i) * samples[i].radius)

	# Processing-style head profile, traversed from the second side back to the first.
	var head_cap := _build_head_cap(samples, samples[0].radius)
	for i in range(head_cap.size() - 2, -1, -1):
		outline.append(head_cap[i])

	outline.append(outline[0])
	draw_polyline(outline, outline_color, outline_width, true)


func _sample_normal(samples: Array[BodySample], index: int) -> Vector2:
	var previous := samples[maxi(0, index - 1)].position
	var next := samples[mini(samples.size() - 1, index + 1)].position
	var tangent := next - previous
	if tangent.is_zero_approx():
		return Vector2.UP
	return tangent.normalized().orthogonal()


func _build_head_cap(samples: Array[BodySample], radius: float) -> PackedVector2Array:
	var center := samples[0].position
	var tangent := (samples[1].position - center).normalized()
	if tangent.is_zero_approx():
		tangent = Vector2.DOWN
	var forward := -tangent
	var normal := tangent.orthogonal()

	var left_root := center + normal * radius
	var left_snout := center + forward * radius * 0.88 + normal * radius * 0.38
	var right_snout := center + forward * radius * 0.88 - normal * radius * 0.38
	var right_root := center - normal * radius
	var points := PackedVector2Array([left_root])

	_append_bezier_points(
		points,
		left_root,
		center + forward * radius * 0.12 + normal * radius * 0.92,
		center + forward * radius * 0.68 + normal * radius * 0.68,
		left_snout,
		12
	)
	_append_bezier_points(
		points,
		left_snout,
		center + forward * radius * 1.02 + normal * radius * 0.30,
		center + forward * radius * 1.02 - normal * radius * 0.30,
		right_snout,
		12
	)
	_append_bezier_points(
		points,
		right_snout,
		center + forward * radius * 0.68 - normal * radius * 0.68,
		center + forward * radius * 0.12 - normal * radius * 0.92,
		right_root,
		12
	)
	return points


func _build_tail_cap(samples: Array[BodySample], radius: float) -> PackedVector2Array:
	var last_sample := samples.size() - 1
	var center := samples[last_sample].position
	var normal := _sample_normal(samples, last_sample)
	var start_angle := normal.angle()
	var points := PackedVector2Array([center, center + normal * radius])

	for step in range(1, 17):
		var angle := start_angle + PI * float(step) / 16.0
		points.append(center + Vector2.from_angle(angle) * radius)

	return points


func _append_bezier_points(
	points: PackedVector2Array,
	p0: Vector2,
	p1: Vector2,
	p2: Vector2,
	p3: Vector2,
	steps: int
) -> void:
	for step in range(1, steps + 1):
		var weight := float(step) / float(steps)
		var inverse := 1.0 - weight
		points.append(
			inverse * inverse * inverse * p0
			+ 3.0 * inverse * inverse * weight * p1
			+ 3.0 * inverse * weight * weight * p2
			+ weight * weight * weight * p3
		)


func _build_body_samples() -> Array[BodySample]:
	var samples: Array[BodySample] = []
	var last_joint := spine.joints.size() - 1

	for i in range(last_joint):
		var p0 := spine.joints[maxi(i - 1, 0)]
		var p1 := spine.joints[i]
		var p2 := spine.joints[i + 1]
		var p3 := spine.joints[mini(i + 2, last_joint)]
		var r0 := _body_radius(maxi(i - 1, 0))
		var r1 := _body_radius(i)
		var r2 := _body_radius(i + 1)
		var r3 := _body_radius(mini(i + 2, last_joint))

		for step in range(curve_subdivisions):
			var weight := float(step) / float(curve_subdivisions)
			var position := _catmull_rom(p0, p1, p2, p3, weight)
			var radius := maxf(4.0, _catmull_rom_float(r0, r1, r2, r3, weight))
			samples.append(BodySample.new(position, radius))

	samples.append(BodySample.new(spine.joints[last_joint], _body_radius(last_joint)))
	return samples


func _minimum_joint_count() -> int:
	return 2


func _body_radius(index: int) -> float:
	match index:
		0:
			return 76.0
		1:
			return 80.0
		_:
			return maxf(4.0, 64.0 - index)


func _catmull_rom(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, weight: float) -> Vector2:
	var weight_squared := weight * weight
	var weight_cubed := weight_squared * weight
	return 0.5 * (
		2.0 * p1
		+ (-p0 + p2) * weight
		+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * weight_squared
		+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * weight_cubed
	)


func _catmull_rom_float(p0: float, p1: float, p2: float, p3: float, weight: float) -> float:
	var weight_squared := weight * weight
	var weight_cubed := weight_squared * weight
	return 0.5 * (
		2.0 * p1
		+ (-p0 + p2) * weight
		+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * weight_squared
		+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * weight_cubed
	)


class BodySample:
	var position: Vector2
	var radius: float

	func _init(position_: Vector2, radius_: float) -> void:
		position = position_
		radius = radius_
