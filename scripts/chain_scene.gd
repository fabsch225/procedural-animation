class_name ChainScene
extends Node2D


@export_group("Chain")
@export_range(2, 128, 1) var chain_segments: int = 8
@export_range(1.0, 200.0, 1.0) var link_size: float = 80.0
@export_range(1.0, 100.0, 1.0) var point_size: float = 32.0
@export_range(1.0, 100.0, 1.0) var line_thickness: float = 14.0
@export_range(0.0, TAU, 0.01, "radians") var angle_constraint: float = TAU

@export_group("Lock")
@export var locked: bool = false
@export var use_viewport_center_as_lock_anchor: bool = true
@export var lock_anchor: Vector2 = Vector2.ZERO

@export_group("Collision")
@export var collision_obstacle_path: NodePath
@export_range(0.0, 100.0, 1.0) var collision_padding: float = 0.0

var chain: Chain
var collision_obstacle: StaticBody2D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if use_viewport_center_as_lock_anchor:
		lock_anchor = get_viewport_rect().get_center()
	collision_obstacle = get_node_or_null(collision_obstacle_path) as StaticBody2D
	chain = Chain.new(lock_anchor, chain_segments, link_size, angle_constraint)
	queue_redraw()


func _process(_delta: float) -> void:
	var target := get_local_mouse_position()

	if locked:
		chain.fabrik_resolve(target, lock_anchor)
	else:
		chain.resolve(target)

	_apply_collision_constraint()
	queue_redraw()


func _apply_collision_constraint() -> void:
	if collision_obstacle == null:
		return

	var collision_polygon := collision_obstacle.get_node_or_null("CollisionPolygon2D") as CollisionPolygon2D
	if collision_polygon != null:
		var polygon := PackedVector2Array()
		for point in collision_polygon.polygon:
			polygon.append(to_local(collision_polygon.to_global(point)))

		chain.constrain_against_polygon(polygon, _collision_clearance())
		return

	var collision_shape := collision_obstacle.get_node_or_null("CollisionShape2D") as CollisionShape2D
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
