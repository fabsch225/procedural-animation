class_name ChainScene
extends Node2D


@export_group("Body")
@export var body_name: String = "chain"

@export_group("Chain")
@export_range(2, 128, 1) var chain_segments: int = 8
@export_range(1.0, 200.0, 1.0) var link_size: float = 80.0
@export_range(1.0, 100.0, 1.0) var point_size: float = 32.0
@export_range(1.0, 100.0, 1.0) var line_thickness: float = 14.0
@export_range(0.0, TAU, 0.01, "radians") var angle_constraint: float = TAU

@export_group("Camera")
@export var camera_enabled: bool = false
@export var camera_position_smoothing_enabled: bool = true
@export_range(0.1, 20.0, 0.1) var camera_position_smoothing_speed: float = 5.0

@export_group("Lock")
@export var locked: bool = false
@export var use_viewport_center_as_lock_anchor: bool = true
@export var lock_anchor: Vector2 = Vector2.ZERO

@export_group("Soft Collisions")
@export var soft_collisions_enabled: bool = true
@export_range(0.0, 100.0, 1.0) var collision_padding: float = 0.0

@export_group("Hard Boundaries")
@export var hard_boundaries_enabled: bool = true



var chain: Chain
@onready var chain_camera: Camera2D = $Camera2D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if use_viewport_center_as_lock_anchor:
		lock_anchor = get_viewport_rect().get_center()
	chain = Chain.new(lock_anchor, chain_segments, link_size, angle_constraint)
	_update_camera()
	queue_redraw()


func activate() -> void:
	visible = true
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if is_instance_valid(chain_camera):
		_update_camera()


func deactivate() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	if is_instance_valid(chain_camera):
		chain_camera.enabled = false


func is_active() -> bool:
	return process_mode != Node.PROCESS_MODE_DISABLED


func _process(_delta: float) -> void:
	var target := _get_constrained_mouse_target()

	if locked:
		chain.fabrik_resolve(target, lock_anchor)
	else:
		chain.resolve(target)

	_apply_boundary_constraints()
	_update_camera()
	queue_redraw()


func _update_camera() -> void:
	chain_camera.enabled = camera_enabled
	chain_camera.position_smoothing_enabled = camera_position_smoothing_enabled
	chain_camera.position_smoothing_speed = camera_position_smoothing_speed

	if not camera_enabled or chain == null or chain.joints.is_empty():
		return

	var chain_center := Vector2.ZERO
	for joint in chain.joints:
		chain_center += joint
	chain_camera.position = chain_center / chain.joints.size()


func _get_constrained_mouse_target() -> Vector2:
	var target := get_local_mouse_position()

	if hard_boundaries_enabled:
		for boundary in _get_hard_boundaries():
			var constrained_target := _constrain_target_to_hard_boundary(target, boundary)
			var partially_clamped_target := target.lerp(constrained_target, boundary.mouse_target_clamping)
			target = _constrain_target_to_hard_boundary(partially_clamped_target, boundary)

	return target


func _constrain_target_to_hard_boundary(target: Vector2, boundary: ChainBoundary) -> Vector2:
	if boundary is WorldBoundary:
		return to_local((boundary as WorldBoundary).constrain_point(to_global(target), _collision_clearance()))

	var collision_polygon := boundary.get_node_or_null("CollisionPolygon2D") as CollisionPolygon2D
	if collision_polygon != null:
		var polygon := PackedVector2Array()
		for point in collision_polygon.polygon:
			polygon.append(to_local(collision_polygon.to_global(point)))
		return _sweep_target_against_polygon(chain.joints[0], target, polygon, _collision_clearance(), boundary.friction)

	var collision_shape := boundary.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape == null or collision_shape.shape == null:
		return target

	var circle_shape := collision_shape.shape as CircleShape2D
	if circle_shape != null:
		var scale := collision_shape.global_transform.get_scale().abs()
		var radius := circle_shape.radius * maxf(scale.x, scale.y) + _collision_clearance()
		return _sweep_target_against_circle(chain.joints[0], target, to_local(collision_shape.global_position), radius, boundary.friction)

	var rectangle_shape := collision_shape.shape as RectangleShape2D
	if rectangle_shape != null:
		var half_size := rectangle_shape.size * 0.5
		var polygon := PackedVector2Array([
			Vector2(-half_size.x, -half_size.y),
			Vector2(half_size.x, -half_size.y),
			Vector2(half_size.x, half_size.y),
			Vector2(-half_size.x, half_size.y),
		])

		for i in range(polygon.size()):
			polygon[i] = to_local(collision_shape.to_global(polygon[i]))

		return _sweep_target_against_polygon(chain.joints[0], target, polygon, _collision_clearance(), boundary.friction)

	return target


func _sweep_target_against_circle(start: Vector2, target: Vector2, center: Vector2, radius: float, friction: float) -> Vector2:
	var position := start
	var motion := target - start

	for _collision in range(3):
		if motion.length_squared() <= 0.0001:
			break

		var steps := maxi(1, ceili(motion.length() / maxf(radius * 0.25, 4.0)))
		var last_safe_position := position
		var blocked := false

		for step in range(1, steps + 1):
			var candidate := position.lerp(position + motion, float(step) / float(steps))
			if candidate.distance_squared_to(center) < radius * radius:
				blocked = true
				break
			last_safe_position = candidate

		if not blocked:
			return position + motion

		var normal := (last_safe_position - center).normalized()
		if normal == Vector2.ZERO:
			normal = Vector2.UP
		var travelled_fraction := position.distance_to(last_safe_position) / motion.length()
		position = last_safe_position
		motion = (motion * (1.0 - travelled_fraction)).slide(normal) * (1.0 - friction)

	return position


func _sweep_target_against_polygon(start: Vector2, target: Vector2, polygon: PackedVector2Array, clearance: float, friction: float) -> Vector2:
	if polygon.size() < 3:
		return target

	var position := start
	var motion := target - start

	for _collision in range(3):
		if motion.length_squared() <= 0.0001:
			break

		var steps := maxi(1, ceili(motion.length() / maxf(clearance * 0.5, 4.0)))
		var last_safe_position := position
		var blocked := false

		for step in range(1, steps + 1):
			var candidate := position.lerp(position + motion, float(step) / float(steps))
			var closest_point := _closest_polygon_point(candidate, polygon)
			var is_blocked := Geometry2D.is_point_in_polygon(candidate, polygon) \
				or candidate.distance_squared_to(closest_point) < clearance * clearance

			if is_blocked:
				blocked = true
				break
			last_safe_position = candidate

		if not blocked:
			return position + motion

		var closest_point := _closest_polygon_point(last_safe_position, polygon)
		var normal := (last_safe_position - closest_point).normalized()
		if normal == Vector2.ZERO:
			normal = Vector2.UP
		var travelled_fraction := position.distance_to(last_safe_position) / motion.length()
		position = last_safe_position
		motion = (motion * (1.0 - travelled_fraction)).slide(normal) * (1.0 - friction)

	return position


func _closest_polygon_point(point: Vector2, polygon: PackedVector2Array) -> Vector2:
	var closest_point := polygon[0]
	var closest_distance_squared := INF

	for i in range(polygon.size()):
		var candidate := Geometry2D.get_closest_point_to_segment(point, polygon[i], polygon[(i + 1) % polygon.size()])
		var distance_squared := point.distance_squared_to(candidate)

		if distance_squared < closest_distance_squared:
			closest_distance_squared = distance_squared
			closest_point = candidate

	return closest_point


func _apply_boundary_constraints() -> void:
	var hard_world_boundaries: Array[WorldBoundary] = []

	for node in get_tree().get_nodes_in_group(ChainBoundary.GROUP):
		var boundary := node as ChainBoundary
		if boundary == null or not boundary.is_visible_in_tree():
			continue

		if boundary.boundary_type == ChainBoundary.BoundaryType.SOFT:
			if soft_collisions_enabled:
				if boundary is WorldBoundary:
					_apply_world_boundary_walls(boundary as WorldBoundary)
				else:
					_apply_static_body_constraint(boundary)
		elif hard_boundaries_enabled:
			if boundary is WorldBoundary:
				hard_world_boundaries.append(boundary as WorldBoundary)
			else:
				for _iteration in range(3):
					_apply_static_body_constraint(boundary)

	for boundary in hard_world_boundaries:
		_apply_hard_boundary_constraint(boundary)


func _apply_world_boundary_walls(boundary: WorldBoundary) -> void:
	for child in boundary.get_children():
		_apply_static_body_constraint(child as StaticBody2D)


func _apply_hard_boundary_constraint(boundary: WorldBoundary) -> void:
	var minimum_joint_distance := link_size * (1.0 - boundary.squishiness)

	# Iterate so spacing and containment settle together at corners and walls.
	for _iteration in range(3):
		_constrain_joints_to_hard_boundary(boundary)
		chain.constrain_minimum_joint_distance(minimum_joint_distance)

	_constrain_joints_to_hard_boundary(boundary)


func _constrain_joints_to_hard_boundary(boundary: WorldBoundary) -> void:
	for i in range(chain.joints.size()):
		var joint_global_position := to_global(chain.joints[i])
		chain.joints[i] = to_local(boundary.constrain_point(joint_global_position, _collision_clearance()))


func _get_hard_boundaries() -> Array[ChainBoundary]:
	var boundaries: Array[ChainBoundary] = []

	for node in get_tree().get_nodes_in_group(ChainBoundary.GROUP):
		var boundary := node as ChainBoundary
		if boundary != null \
				and boundary.is_visible_in_tree() \
				and boundary.boundary_type == ChainBoundary.BoundaryType.HARD:
			boundaries.append(boundary)

	return boundaries


func _apply_static_body_constraint(obstacle: StaticBody2D) -> void:
	if obstacle == null:
		return

	var collision_polygon := obstacle.get_node_or_null("CollisionPolygon2D") as CollisionPolygon2D
	if collision_polygon != null:
		var polygon := PackedVector2Array()
		for point in collision_polygon.polygon:
			polygon.append(to_local(collision_polygon.to_global(point)))

		chain.constrain_against_polygon(polygon, _collision_clearance())
		return

	var collision_shape := obstacle.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape == null or collision_shape.shape == null:
		return

	var circle_shape := collision_shape.shape as CircleShape2D
	if circle_shape != null:
		var scale := collision_shape.global_transform.get_scale().abs()
		var radius := circle_shape.radius * maxf(scale.x, scale.y) + _collision_clearance()
		chain.constrain_against_circle(to_local(collision_shape.global_position), radius)
		return

	var rectangle_shape := collision_shape.shape as RectangleShape2D
	if rectangle_shape != null:
		var half_size := rectangle_shape.size * 0.5
		var polygon := PackedVector2Array([
			Vector2(-half_size.x, -half_size.y),
			Vector2(half_size.x, -half_size.y),
			Vector2(half_size.x, half_size.y),
			Vector2(-half_size.x, half_size.y),
		])

		for i in range(polygon.size()):
			polygon[i] = to_local(collision_shape.to_global(polygon[i]))

		chain.constrain_against_polygon(polygon, _collision_clearance())


func _collision_clearance() -> float:
	return point_size * 0.5 + collision_padding


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if not locked and chain != null:
				lock_anchor = chain.joints.back()

			locked = not locked
			get_viewport().set_input_as_handled()


func _draw() -> void:
	if chain != null:
		chain.draw(self, line_thickness, point_size)
