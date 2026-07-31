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

var chain: Chain


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if use_viewport_center_as_lock_anchor:
		lock_anchor = get_viewport_rect().get_center()
	chain = Chain.new(lock_anchor, chain_segments, link_size, angle_constraint)
	queue_redraw()


func _process(_delta: float) -> void:
	var target := get_local_mouse_position()

	if locked:
		chain.fabrik_resolve(target, lock_anchor)
	else:
		chain.resolve(target)

	queue_redraw()


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
