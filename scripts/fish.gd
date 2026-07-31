class_name Fish
extends ChainBody


const JOINT_COUNT: int = 12
const BODY_JOINT_COUNT: int = 10

@export_group("Fish Appearance")
@export var fin_color: Color = Color8(129, 195, 215)
@export var body_widths: Array[float] = [
	68.0, 81.0, 84.0, 83.0, 77.0, 64.0, 51.0, 38.0, 32.0, 19.0,
]
@export_range(8, 96, 1) var ellipse_resolution: int = 40


func _draw_chain_body() -> void:
	var angles := spine.angles
	var head_to_mid_1 := Util.relative_angle_diff(angles[0], angles[6])
	var head_to_mid_2 := Util.relative_angle_diff(angles[0], angles[7])
	var head_to_tail := head_to_mid_1 + Util.relative_angle_diff(angles[6], angles[11])

	_draw_ellipse(
		_body_position(3, PI / 3.0), Vector2(160.0, 64.0),
		angles[2] - PI / 4.0, fin_color
	)
	_draw_ellipse(
		_body_position(3, -PI / 3.0), Vector2(160.0, 64.0),
		angles[2] + PI / 4.0, fin_color
	)
	_draw_ellipse(
		_body_position(7, PI / 2.0), Vector2(96.0, 32.0),
		angles[6] - PI / 4.0, fin_color
	)
	_draw_ellipse(
		_body_position(7, -PI / 2.0), Vector2(96.0, 32.0),
		angles[6] + PI / 4.0, fin_color
	)

	_draw_filled_path(_build_caudal_fin(head_to_tail), fin_color)
	_draw_filled_path(_build_body_outline(), body_color)
	_draw_filled_path(_build_dorsal_fin(head_to_mid_1, head_to_mid_2), fin_color)

	_draw_standard_eyes()


func _build_caudal_fin(head_to_tail: float) -> PackedVector2Array:
	var shape := _new_processing_shape()
	shape.begin_shape()
	for i in range(8, JOINT_COUNT):
		var distance_from_body := float(i - 8)
		var tail_width := 1.5 * head_to_tail * distance_from_body * distance_from_body
		shape.curve_vertex(
			spine.joints[i]
			+ Vector2.from_angle(spine.angles[i] - PI / 2.0) * tail_width
		)
	for i in range(JOINT_COUNT - 1, 7, -1):
		var tail_width := clampf(head_to_tail * 6.0, -13.0, 13.0)
		shape.curve_vertex(
			spine.joints[i]
			+ Vector2.from_angle(spine.angles[i] + PI / 2.0) * tail_width
		)
	return shape.end_shape(true)


func _build_body_outline() -> PackedVector2Array:
	var shape := _new_processing_shape()
	shape.begin_shape()
	for i in range(BODY_JOINT_COUNT):
		shape.curve_vertex(_body_position(i, PI / 2.0))
	shape.curve_vertex(_body_position(BODY_JOINT_COUNT - 1, PI))
	for i in range(BODY_JOINT_COUNT - 1, -1, -1):
		shape.curve_vertex(_body_position(i, -PI / 2.0))
	shape.curve_vertex(_body_position(0, -PI / 6.0))
	shape.curve_vertex(_body_position(0, 0.0, 4.0))
	shape.curve_vertex(_body_position(0, PI / 6.0))
	for i in range(3):
		shape.curve_vertex(_body_position(i, PI / 2.0))
	return shape.end_shape(true)


func _build_dorsal_fin(head_to_mid_1: float, head_to_mid_2: float) -> PackedVector2Array:
	var joints := spine.joints
	var angles := spine.angles
	var shape := _new_processing_shape()
	shape.begin_shape()
	shape.vertex(joints[4])
	shape.bezier_vertex(joints[5], joints[6], joints[7])
	shape.bezier_vertex(
		joints[6] + Vector2.from_angle(angles[6] + PI / 2.0) * head_to_mid_2 * 16.0,
		joints[5] + Vector2.from_angle(angles[5] + PI / 2.0) * head_to_mid_1 * 16.0,
		joints[4]
	)
	return shape.end_shape()


func _minimum_joint_count() -> int:
	return JOINT_COUNT


func _body_radius(index: int) -> float:
	if index < 0 or index >= body_widths.size():
		return 0.0
	return body_widths[index]


func _draw_ellipse(center: Vector2, size: Vector2, rotation: float, color: Color) -> void:
	var points := PackedVector2Array()
	var half_size := size * 0.5
	for step in range(ellipse_resolution):
		var angle := TAU * float(step) / float(ellipse_resolution)
		var local_point := Vector2(cos(angle) * half_size.x, sin(angle) * half_size.y)
		points.append(center + local_point.rotated(rotation))
	draw_colored_polygon(points, color)
	if outline_width > 0.0:
		points.append(points[0])
		draw_polyline(points, outline_color, outline_width, true)
