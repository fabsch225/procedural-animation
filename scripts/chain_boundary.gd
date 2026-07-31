class_name ChainBoundary
extends StaticBody2D


enum BoundaryType {
	SOFT,
	HARD,
}

const GROUP: StringName = &"chain_boundaries"

@export var boundary_type: BoundaryType = BoundaryType.SOFT

@export_group("Hard Boundary")
@export_range(0.0, 1.0, 0.01) var squishiness: float = 1.0
@export_range(0.0, 1.0, 0.01) var mouse_target_clamping: float = 0.0
@export_range(0.0, 1.0, 0.01) var friction: float = 0.0


func _ready() -> void:
	add_to_group(GROUP)
