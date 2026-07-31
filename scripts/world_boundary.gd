class_name WorldBoundary
extends ChainBoundary


@export_range(1.0, 200.0, 1.0) var wall_thickness: float = 32.0

func _ready() -> void:
	super._ready()
	get_viewport().size_changed.connect(_fit_to_viewport)
	_fit_to_viewport()


func _fit_to_viewport() -> void:
	var viewport_size := get_viewport_rect().size
	var half_thickness := wall_thickness * 0.5

	_set_wall($Top, Vector2(viewport_size.x * 0.5, -half_thickness), Vector2(viewport_size.x + wall_thickness * 2.0, wall_thickness))
	_set_wall($Bottom, Vector2(viewport_size.x * 0.5, viewport_size.y + half_thickness), Vector2(viewport_size.x + wall_thickness * 2.0, wall_thickness))
	_set_wall($Left, Vector2(-half_thickness, viewport_size.y * 0.5), Vector2(wall_thickness, viewport_size.y + wall_thickness * 2.0))
	_set_wall($Right, Vector2(viewport_size.x + half_thickness, viewport_size.y * 0.5), Vector2(wall_thickness, viewport_size.y + wall_thickness * 2.0))


func _set_wall(wall: StaticBody2D, wall_position: Vector2, wall_size: Vector2) -> void:
	wall.position = wall_position
	var collision_shape := wall.get_node("CollisionShape2D") as CollisionShape2D
	var rectangle_shape := collision_shape.shape as RectangleShape2D
	rectangle_shape.size = wall_size


# Hard constraint: keeps a point inside the playable viewport at all times.
func constrain_point(point: Vector2, clearance: float) -> Vector2:
	var local_point := to_local(point)
	var viewport_size := get_viewport_rect().size

	local_point.x = clampf(local_point.x, clearance, viewport_size.x - clearance)
	local_point.y = clampf(local_point.y, clearance, viewport_size.y - clearance)

	return to_global(local_point)
