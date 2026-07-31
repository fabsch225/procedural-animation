class_name Chain
extends RefCounted


var joints: Array[Vector2] = []
var link_size: float
var angles: Array[float] = []
var angle_constraint: float


func _init(
	origin: Vector2,
	joint_count: int,
	link_size_: float,
	angle_constraint_: float = TAU
) -> void:
	link_size = link_size_
	angle_constraint = angle_constraint_

	joints.append(origin)
	angles.append(0.0)

	for i in range(1, joint_count):
		joints.append(joints[i - 1] + Vector2(0.0, link_size))
		angles.append(0.0)


# Resolves the chain toward a target while limiting adjacent joint angles.
func resolve(position: Vector2) -> void:
	angles[0] = (position - joints[0]).angle()
	joints[0] = position

	for i in range(1, joints.size()):
		var current_angle := (joints[i - 1] - joints[i]).angle()
		angles[i] = Util.constrain_angle(current_angle, angles[i - 1], angle_constraint)
		joints[i] = joints[i - 1] - Vector2.RIGHT.rotated(angles[i]) * link_size


# Resolves the chain using one forward and one backward FABRIK pass.
func fabrik_resolve(position: Vector2, anchor: Vector2) -> void:
	joints[0] = position

	for i in range(1, joints.size()):
		joints[i] = Util.constrain_distance(joints[i], joints[i - 1], link_size)

	joints[joints.size() - 1] = anchor

	for i in range(joints.size() - 2, -1, -1):
		joints[i] = Util.constrain_distance(joints[i], joints[i + 1], link_size)


# Draws the chain on a CanvasItem, such as the node calling this method in _draw().
func draw(canvas: CanvasItem, line_thickness: float = 8.0, point_size: float = 32.0) -> void:
	for i in range(joints.size() - 1):
		canvas.draw_line(joints[i], joints[i + 1], Color.WHITE, line_thickness)

	for joint in joints:
		var outer_radius := point_size * 0.5
		var inner_radius := maxf(0.0, outer_radius - line_thickness * 0.5)
		canvas.draw_circle(joint, outer_radius, Color.WHITE)
		canvas.draw_circle(joint, inner_radius, Color8(42, 44, 53))
