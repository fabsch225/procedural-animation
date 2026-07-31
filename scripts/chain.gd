extends RefCounted
class_name Chain


# =====================================================
# Chain Data
# =====================================================

var joints: Array[Vector2] = []
var angles: Array[float] = []


var link_size: float
var angle_constraint: float



# =====================================================
# Constructor
# =====================================================

func _init(
	origin: Vector2 = Vector2.ZERO,
	joint_count: int = 10,
	link_size_: float = 20.0,
	angle_constraint_: float = TAU
):

	link_size = link_size_
	angle_constraint = angle_constraint_


	joints.clear()
	angles.clear()


	for i in range(joint_count):

		joints.append(
			origin + Vector2(
				0,
				i * link_size
			)
		)

		angles.append(
			PI / 2.0
		)



# =====================================================
# Angle Solver
# =====================================================

func resolve(target: Vector2):


	# Move head

	angles[0] = (
		target - joints[0]
	).angle()


	joints[0] = target



	# Follow chain

	for i in range(1, joints.size()):


		var current_angle = (
			joints[i - 1]
			-
			joints[i]
		).angle()



		angles[i] = constrain_angle(
			current_angle,
			angles[i - 1],
			angle_constraint
		)



		joints[i] = (
			joints[i - 1]
			-
			Vector2.RIGHT.rotated(
				angles[i]
			)
			*
			link_size
		)



# =====================================================
# FABRIK Solver (optional)
# =====================================================

func fabrik_resolve(
	target: Vector2,
	anchor: Vector2
):


	# Forward pass

	joints[0] = target


	for i in range(1, joints.size()):

		joints[i] = constrain_distance(
			joints[i],
			joints[i-1],
			link_size
		)



	# Backward pass

	joints[joints.size()-1] = anchor


	for i in range(
		joints.size()-2,
		-1,
		-1
	):

		joints[i] = constrain_distance(
			joints[i],
			joints[i+1],
			link_size
		)



# =====================================================
# Helpers
# =====================================================

func constrain_distance(
	position: Vector2,
	anchor: Vector2,
	distance: float
) -> Vector2:


	var direction = (
		position - anchor
	).normalized()


	return (
		anchor
		+
		direction * distance
	)



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
