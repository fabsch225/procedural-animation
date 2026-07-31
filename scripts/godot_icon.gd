extends ChainBoundary


enum BoundaryShape {
	CIRCLE,
	SQUARE,
	VERTICAL_PILLAR,
	HORIZONTAL_PILLAR,
}

@export_group("Boundary Shape")
@export var boundary_shape: BoundaryShape = BoundaryShape.CIRCLE
@export_range(1.0, 500.0, 1.0) var circle_radius: float = 99.0
@export_range(1.0, 1000.0, 1.0) var square_size: float = 198.0
@export_range(1.0, 500.0, 1.0) var pillar_thickness: float = 64.0
@export var pillar_reaches_screen_edges: bool = true
@export_range(1.0, 5000.0, 1.0) var pillar_length: float = 800.0

@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	super._ready()
	get_viewport().size_changed.connect(_center_in_viewport)
	_center_in_viewport()


func _center_in_viewport() -> void:
	position = get_viewport_rect().get_center()
	_update_collision_shape()


func _update_collision_shape() -> void:
	match boundary_shape:
		BoundaryShape.CIRCLE:
			var circle := CircleShape2D.new()
			circle.radius = circle_radius
			collision_shape.shape = circle

		BoundaryShape.SQUARE:
			collision_shape.shape = _rectangle_shape(Vector2(square_size, square_size))

		BoundaryShape.VERTICAL_PILLAR:
			collision_shape.shape = _rectangle_shape(Vector2(pillar_thickness, _pillar_length(true)))

		BoundaryShape.HORIZONTAL_PILLAR:
			collision_shape.shape = _rectangle_shape(Vector2(_pillar_length(false), pillar_thickness))


func _pillar_length(is_vertical: bool) -> float:
	if pillar_reaches_screen_edges:
		var viewport_size := get_viewport_rect().size
		return viewport_size.y if is_vertical else viewport_size.x

	return pillar_length


func _rectangle_shape(size: Vector2) -> RectangleShape2D:
	var rectangle := RectangleShape2D.new()
	rectangle.size = size
	return rectangle
