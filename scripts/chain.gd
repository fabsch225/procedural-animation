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
		joints.append(origin)
		angles.append(0.0)

	# Keep the initial joint positions consistent with the initial angles. The
	# Processing constructor used vertical positions with zero-valued angles,
	# which is harmless after its first update but produces a malformed body if
	# it is displayed before that update (for example, while paused).
	set_curved_pose(origin)


# Places the complete chain immediately into a valid pose. `heading` is the
# head's forward direction and `joint_bend` is the angle added by each link.
func set_curved_pose(
	head_position: Vector2,
	heading: float = 0.0,
	joint_bend: float = 0.0
) -> void:
	if joints.is_empty():
		return

	joints[0] = head_position
	angles[0] = Util.simplify_angle(heading)
	for i in range(1, joints.size()):
		angles[i] = Util.simplify_angle(heading + joint_bend * float(i))
		joints[i] = joints[i - 1] - Vector2.from_angle(angles[i]) * link_size


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


# Pushes every joint outside a polygonal collision constraint.
func constrain_against_polygon(polygon: PackedVector2Array, clearance: float) -> void:
	if polygon.size() < 3:
		return

	var polygon_center := Vector2.ZERO
	for vertex in polygon:
		polygon_center += vertex
	polygon_center /= polygon.size()

	for i in range(joints.size()):
		var joint := joints[i]
		var closest_point := _closest_point_on_polygon(joint, polygon)
		var offset := joint - closest_point
		var is_inside := Geometry2D.is_point_in_polygon(joint, polygon)

		if not is_inside and offset.length_squared() >= clearance * clearance:
			continue

		if is_inside:
			offset = closest_point - joint

		if is_zero_approx(offset.length_squared()):
			offset = closest_point - polygon_center
		if is_zero_approx(offset.length_squared()):
			offset = Vector2.UP

		joints[i] = closest_point + offset.normalized() * clearance


func constrain_against_circle(center: Vector2, radius: float) -> void:
	for i in range(joints.size()):
		var offset := joints[i] - center

		if offset.length_squared() >= radius * radius:
			continue

		if is_zero_approx(offset.length_squared()):
			offset = Vector2.UP

		joints[i] = center + offset.normalized() * radius


# Prevents adjacent joints from compressing below a chosen distance.
func constrain_minimum_joint_distance(minimum_distance: float) -> void:
	for i in range(1, joints.size()):
		var offset := joints[i] - joints[i - 1]

		if offset.length_squared() >= minimum_distance * minimum_distance:
			continue

		if is_zero_approx(offset.length_squared()):
			offset = Vector2.RIGHT.rotated(angles[i])

		joints[i] = joints[i - 1] + offset.normalized() * minimum_distance


func _closest_point_on_polygon(point: Vector2, polygon: PackedVector2Array) -> Vector2:
	var closest_point := polygon[0]
	var closest_distance_squared := INF

	for i in range(polygon.size()):
		var segment_start := polygon[i]
		var segment_end := polygon[(i + 1) % polygon.size()]
		var candidate := Geometry2D.get_closest_point_to_segment(point, segment_start, segment_end)
		var distance_squared := point.distance_squared_to(candidate)

		if distance_squared < closest_distance_squared:
			closest_distance_squared = distance_squared
			closest_point = candidate

	return closest_point


# Draws the chain on a CanvasItem, such as the node calling this method in _draw().
func draw(canvas: CanvasItem, line_thickness: float = 8.0, point_size: float = 32.0) -> void:
	for i in range(joints.size() - 1):
		canvas.draw_line(joints[i], joints[i + 1], Color.WHITE, line_thickness)

	for joint in joints:
		var outer_radius := point_size * 0.5
		var inner_radius := maxf(0.0, outer_radius - line_thickness * 0.5)
		canvas.draw_circle(joint, outer_radius, Color.WHITE)
		canvas.draw_circle(joint, inner_radius, Color8(42, 44, 53))
