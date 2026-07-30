extends Node2D
class_name Chain


# =====================================================
# Presets
# =====================================================

@export_category("Presets")

enum ChainPreset {
	CUSTOM,
	WORM
}

@export var preset: ChainPreset = ChainPreset.CUSTOM:
	set(value):
		preset = value
		apply_preset()



# =====================================================
# Chain Parameters
# =====================================================

@export_category("Chain")

@export var joint_count: int = 10:
	set(value):
		joint_count = max(2, value)
		if is_inside_tree():
			initialize_chain(global_position)


@export var link_size: float = 20.0



# =====================================================
# IK Settings
# =====================================================

@export_category("IK Settings")

@export var use_fabrik: bool = true
@export var use_anchor: bool = true

@export var anchor: Vector2

@export_range(0.0, TAU, 0.01)
var angle_constraint: float = TAU



# =====================================================
# Appearance
# =====================================================

@export_category("Appearance")

@export var point_size: float = 10.0
@export var outline_size: float = 14.0
@export var body_size: float = 6.0

@export var point_color: Color = Color(0.2, 0.22, 0.3)
@export var outline_color: Color = Color.WHITE
@export var body_color: Color = Color.WHITE



# =====================================================
# Internal Data
# =====================================================

var joints: Array[Vector2] = []
var angles: Array[float] = []



# =====================================================
# Setup
# =====================================================

func _init(
	origin: Vector2 = Vector2.ZERO,
	joint_count_: int = 10,
	link_size_: float = 20.0,
	angle_constraint_: float = TAU
):

	joint_count = joint_count_
	link_size = link_size_
	angle_constraint = angle_constraint_

	initialize_chain(origin)


func _ready():

	# Default anchor to screen center
	if anchor == Vector2.ZERO:
		anchor = get_viewport_rect().size * 0.5

	initialize_chain(global_position)



func initialize_chain(origin: Vector2):

	joints.clear()
	angles.clear()

	joints.append(origin)
	angles.append(0.0)

	for i in range(1, joint_count):

		joints.append(
			joints[i - 1] + Vector2(0, link_size)
		)

		angles.append(0.0)



# =====================================================
# Preset System
# =====================================================

func apply_preset():

	match preset:


		ChainPreset.WORM:

			# Chain
			joint_count = 25
			link_size = 15.0


			# IK
			use_fabrik = true
			use_anchor = false
			angle_constraint = TAU


			# Appearance
			point_size = 8.0
			outline_size = 12.0
			body_size = 14.0


			point_color = Color(0.2, 0.8, 0.25)
			outline_color = Color.WHITE
			body_color = Color(0.15, 0.7, 0.2)


			if is_inside_tree():
				initialize_chain(global_position)



# =====================================================
# Process
# =====================================================

func _process(delta):

	var target = get_global_mouse_position()


	if use_fabrik:
		fabrik_resolve(target)
	else:
		resolve(target)


	queue_redraw()



# =====================================================
# Utility
# =====================================================

func constrain_distance(
	position: Vector2,
	target: Vector2,
	distance: float
) -> Vector2:

	var direction = (
		position - target
	).normalized()

	return target + direction * distance



func constrain_angle(
	angle: float,
	previous_angle: float,
	constraint: float
) -> float:

	var difference = wrapf(
		angle - previous_angle,
		-PI,
		PI
	)

	difference = clamp(
		difference,
		-constraint,
		constraint
	)

	return previous_angle + difference



# =====================================================
# Angle Based Solver
# =====================================================

func resolve(target: Vector2):

	angles[0] = (
		target - joints[0]
	).angle()

	joints[0] = target


	for i in range(1, joints.size()):

		var current_angle = (
			joints[i - 1] - joints[i]
		).angle()


		angles[i] = constrain_angle(
			current_angle,
			angles[i - 1],
			angle_constraint
		)


		joints[i] = (
			joints[i - 1]
			-
			Vector2.RIGHT.rotated(angles[i])
			*
			link_size
		)



# =====================================================
# FABRIK Solver
# =====================================================

func fabrik_resolve(target: Vector2):

	# Forward pass
	joints[0] = target


	for i in range(1, joints.size()):

		joints[i] = constrain_distance(
			joints[i],
			joints[i - 1],
			link_size
		)



	# Optional tail anchor

	if use_anchor:

		joints[joints.size() - 1] = anchor


		for i in range(
			joints.size() - 2,
			-1,
			-1
		):

			joints[i] = constrain_distance(
				joints[i],
				joints[i + 1],
				link_size
			)



# =====================================================
# Drawing
# =====================================================

func _draw():


	# Body segments

	for i in range(joints.size() - 1):

		draw_line(
			joints[i],
			joints[i + 1],
			body_color,
			body_size
		)



	# Joint points

	for joint in joints:


		# Outline

		draw_circle(
			joint,
			outline_size,
			outline_color
		)


		# Fill

		draw_circle(
			joint,
			point_size,
			point_color
		)
