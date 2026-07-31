class_name BodySwitcher
extends Node2D


@export var starting_body_index: int = 0
@export var body_name_label_path: NodePath = ^"../../UI/BodyName"

var active_body_index: int = -1
var bodies: Array[Node] = []
@onready var body_name_label := get_node_or_null(body_name_label_path) as Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_refresh_bodies()
	if not bodies.is_empty():
		activate_body(starting_body_index)


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or not event.pressed:
		return

	if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		cycle_body(1)
	elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
		cycle_body(-1)
	else:
		return

	get_viewport().set_input_as_handled()


func cycle_body(direction: int = 1) -> void:
	if bodies.is_empty() or direction == 0:
		return

	activate_body(active_body_index + direction)


func activate_body(index: int) -> void:
	if bodies.is_empty():
		active_body_index = -1
		return

	active_body_index = wrapi(index, 0, bodies.size())
	for i in range(bodies.size()):
		if i == active_body_index:
			bodies[i].activate()
		else:
			bodies[i].deactivate()

	_update_body_name()


func _update_body_name() -> void:
	if body_name_label == null or active_body_index < 0:
		return

	body_name_label.text = str(bodies[active_body_index].get("body_name"))


func _refresh_bodies() -> void:
	bodies.clear()
	for child in get_children():
		if child.has_method(&"activate") and child.has_method(&"deactivate"):
			bodies.append(child)
