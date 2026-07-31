class_name Lizard
extends ChainBody


const JOINT_COUNT: int = 14
const ARM_COUNT: int = 4
const ARM_JOINT_COUNT: int = 3
const PROCESSING_REFERENCE_FPS: float = 60.0

@export_group("Lizard Appearance")
@export var body_widths: Array[float] = [
	52.0, 58.0, 40.0, 60.0, 68.0, 71.0, 65.0,
	50.0, 28.0, 15.0, 11.0, 9.0, 7.0, 7.0,
]

@export_group("Arms")
@export_range(1.0, 128.0, 1.0) var front_arm_link_size: float = 52.0
@export_range(1.0, 128.0, 1.0) var rear_arm_link_size: float = 36.0
@export_range(0.0, 128.0, 1.0) var arm_outline_width: float = 40.0
@export_range(0.0, 128.0, 1.0) var arm_width: float = 32.0
@export_range(0.0, 256.0, 1.0) var step_distance: float = 200.0
@export_range(0.0, 1.0, 0.01) var step_speed: float = 0.4
@export_range(0.0, 128.0, 1.0) var foot_reach: float = 80.0
@export_range(0.0, 128.0, 1.0) var shoulder_inset: float = 20.0
@export_range(0.0, 128.0, 1.0) var rear_elbow_offset: float = 30.0

var arms: Array[Chain] = []
var arm_desired: Array[Vector2] = []


func _on_spine_created() -> void:
	arms.clear()
	arm_desired.clear()
	for i in range(ARM_COUNT):
		var arm_link_size := front_arm_link_size if i < 2 else rear_arm_link_size
		arms.append(Chain.new(spine.joints[0], ARM_JOINT_COUNT, arm_link_size))
		arm_desired.append(Vector2.ZERO)


func _after_spine_resolved(delta: float) -> void:
	# Processing applies this lerp once per rendered frame. Convert the exported
	# 60 FPS weight to a time-based weight so high refresh rates do not make the
	# feet jump toward their new targets more aggressively.
	var clamped_step_speed := clampf(step_speed, 0.0, 1.0)
	var step_weight := 1.0 - pow(
		1.0 - clamped_step_speed,
		maxf(delta, 0.0) * PROCESSING_REFERENCE_FPS
	)
	for i in range(arms.size()):
		var side := 1.0 if i % 2 == 0 else -1.0
		var body_index := 3 if i < 2 else 7
		var reach_angle := PI / 4.0 if i < 2 else PI / 3.0
		var desired_position := _body_position(
			body_index, reach_angle * side, foot_reach
		)
		if desired_position.distance_to(arm_desired[i]) > step_distance:
			arm_desired[i] = desired_position

		var moving_foot := arms[i].joints[0].lerp(arm_desired[i], step_weight)
		var shoulder := _body_position(
			body_index, PI / 2.0 * side, -shoulder_inset
		)
		arms[i].fabrik_resolve(moving_foot, shoulder)


func _draw_chain_body() -> void:
	_draw_arms()
	_draw_filled_path(_build_body_outline(), body_color)
	draw_circle(_body_position(0, 3.0 * PI / 5.0, -7.0), eye_radius, Color.WHITE)
	draw_circle(_body_position(0, -3.0 * PI / 5.0, -7.0), eye_radius, Color.WHITE)


func _draw_additional_debug_chains() -> void:
	for arm in arms:
		arm.draw(self)


func _draw_arms() -> void:
	for i in range(arms.size()):
		var shoulder := arms[i].joints[2]
		var foot := arms[i].joints[0]
		var elbow := arms[i].joints[1]
		var shoulder_to_foot := foot - shoulder
		var perpendicular := Vector2(-shoulder_to_foot.y, shoulder_to_foot.x)
		if not perpendicular.is_zero_approx():
			perpendicular = perpendicular.normalized() * rear_elbow_offset
		if i == 2:
			elbow -= perpendicular
		elif i == 3:
			elbow += perpendicular

		var path := _build_arm_path(shoulder, elbow, foot)
		_draw_round_capped_polyline(path, outline_color, arm_outline_width)
		_draw_round_capped_polyline(path, body_color, arm_width)


func _draw_round_capped_polyline(
	path: PackedVector2Array,
	color: Color,
	width: float
) -> void:
	if path.size() < 2 or width <= 0.0:
		return
	draw_polyline(path, color, width, true)
	var cap_radius := width * 0.5
	draw_circle(path[0], cap_radius, color, true, -1.0, true)
	draw_circle(path[-1], cap_radius, color, true, -1.0, true)


func _build_arm_path(shoulder: Vector2, elbow: Vector2, foot: Vector2) -> PackedVector2Array:
	var shape := _new_processing_shape()
	shape.begin_shape()
	shape.vertex(shoulder)
	shape.bezier_vertex(elbow, elbow, foot)
	return shape.end_shape()


func _build_body_outline() -> PackedVector2Array:
	var shape := _new_processing_shape()
	shape.begin_shape()
	for i in range(JOINT_COUNT):
		shape.curve_vertex(_body_position(i, PI / 2.0))
	for i in range(JOINT_COUNT - 1, -1, -1):
		shape.curve_vertex(_body_position(i, -PI / 2.0))

	shape.curve_vertex(_body_position_xy(0, -PI / 6.0, -8.0, -10.0))
	shape.curve_vertex(_body_position_xy(0, 0.0, -6.0, -4.0))
	shape.curve_vertex(_body_position_xy(0, PI / 6.0, -8.0, -10.0))
	for i in range(3):
		shape.curve_vertex(_body_position(i, PI / 2.0))
	return shape.end_shape(true)


func _body_position_xy(
	index: int,
	angle_offset: float,
	x_length_offset: float,
	y_length_offset: float
) -> Vector2:
	var angle := spine.angles[index] + angle_offset
	return spine.joints[index] + Vector2(
		cos(angle) * (_body_radius(index) + x_length_offset),
		sin(angle) * (_body_radius(index) + y_length_offset)
	)


func _minimum_joint_count() -> int:
	return JOINT_COUNT


func _body_radius(index: int) -> float:
	if index < 0 or index >= body_widths.size():
		return 0.0
	return body_widths[index]
