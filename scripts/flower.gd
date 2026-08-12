class_name Flower
extends ChainBody


const LEAF_JOINT_INDICES: Array[int] = [3, 6, 8]

@export_group("Stem")
@export_range(2.0, 48.0, 1.0) var stem_width: float = 18.0
@export var stem_color: Color = Color(0.321569, 0.47451, 0.435294)

@export_group("Leaves")
@export_range(20.0, 160.0, 1.0) var leaf_length: float = 82.0
@export_range(8.0, 80.0, 1.0) var leaf_width: float = 34.0
@export var leaf_color: Color = Color(0.321569, 0.47451, 0.435294)

@export_group("Blossom")
@export_range(5, 16, 1) var petal_count: int = 10
@export_range(20.0, 100.0, 1.0) var petal_length: float = 52.0
@export_range(10.0, 70.0, 1.0) var petal_width: float = 32.0
@export_range(10.0, 80.0, 1.0) var flower_center_radius: float = 31.0
@export var flower_center_color: Color = Color(0.67451, 0.223529, 0.192157)


func _minimum_joint_count() -> int:
	return LEAF_JOINT_INDICES.back() + 1


func _body_radius(index: int) -> float:
	return flower_center_radius if index == 0 else stem_width * 0.5


func _draw_chain_body() -> void:
	for leaf_index in range(LEAF_JOINT_INDICES.size()):
		var joint_index := LEAF_JOINT_INDICES[leaf_index]
		if joint_index < spine.joints.size():
			_draw_leaf(joint_index, 1.0 if leaf_index % 2 == 0 else -1.0)

	_draw_stem()
	for petal_index in range(petal_count):
		_draw_filled_outline(_build_petal_outline(petal_index), body_color)

	draw_circle(
		spine.joints[0],
		flower_center_radius + outline_width,
		outline_color
	)
	draw_circle(spine.joints[0], flower_center_radius, flower_center_color)
	draw_circle(
		spine.joints[0] - Vector2.from_angle(spine.angles[0]) * 7.0,
		flower_center_radius * 0.32,
		flower_center_color.darkened(0.18)
	)


func _draw_stem() -> void:
	var stem_points := PackedVector2Array(spine.joints)
	for joint in spine.joints:
		draw_circle(joint, stem_width * 0.5 + outline_width, outline_color)
	draw_polyline(
		stem_points,
		outline_color,
		stem_width + outline_width * 2.0,
		true
	)
	for joint in spine.joints:
		draw_circle(joint, stem_width * 0.5, stem_color)
	draw_polyline(stem_points, stem_color, stem_width, true)


func _draw_leaf(joint_index: int, side: float) -> void:
	_draw_filled_outline(_build_leaf_outline(joint_index, side), leaf_color)


func _draw_filled_outline(points: PackedVector2Array, color: Color) -> void:
	if points.size() < 3:
		return
	draw_colored_polygon(points, color)
	var closed_points := points.duplicate()
	closed_points.append(points[0])
	draw_polyline(closed_points, outline_color, outline_width, true)


func _build_leaf_outline(joint_index: int, side: float) -> PackedVector2Array:
	if spine == null or joint_index < 0 or joint_index >= spine.joints.size():
		return PackedVector2Array()
	var base := spine.joints[joint_index]
	var stem_direction := Vector2.from_angle(spine.angles[joint_index])
	var leaf_direction := stem_direction.rotated(side * PI / 2.0)
	var tip := base + leaf_direction * leaf_length + stem_direction * 12.0
	var axis := (tip - base).normalized()
	var normal := axis.orthogonal()
	var control_center := base.lerp(tip, 0.52)
	var points := PackedVector2Array()
	var curve_steps := 8
	for step in range(curve_steps + 1):
		var t := float(step) / float(curve_steps)
		points.append(_quadratic_bezier(
			base,
			control_center + normal * leaf_width,
			tip,
			t
		))
	for step in range(curve_steps, -1, -1):
		var t := float(step) / float(curve_steps)
		points.append(_quadratic_bezier(
			base,
			control_center - normal * leaf_width,
			tip,
			t
		))
	return points


func _build_petal_outline(petal_index: int) -> PackedVector2Array:
	if spine == null or petal_count < 1:
		return PackedVector2Array()
	var center := spine.joints[0]
	var angle := spine.angles[0] + TAU * float(petal_index) / float(petal_count)
	var axis := Vector2.from_angle(angle)
	var normal := axis.orthogonal()
	var base := center + axis * flower_center_radius * 0.45
	var tip := center + axis * (flower_center_radius + petal_length)
	var control_center := center + axis * (
		flower_center_radius + petal_length * 0.48
	)
	var points := PackedVector2Array()
	var curve_steps := 8
	for step in range(curve_steps + 1):
		var t := float(step) / float(curve_steps)
		points.append(_quadratic_bezier(
			base,
			control_center + normal * petal_width,
			tip,
			t
		))
	for step in range(curve_steps, -1, -1):
		var t := float(step) / float(curve_steps)
		points.append(_quadratic_bezier(
			base,
			control_center - normal * petal_width,
			tip,
			t
		))
	return points


func _quadratic_bezier(
	start: Vector2,
	control: Vector2,
	end: Vector2,
	t: float
) -> Vector2:
	var inverse_t := 1.0 - t
	return inverse_t * inverse_t * start \
		+ 2.0 * inverse_t * t * control \
		+ t * t * end
