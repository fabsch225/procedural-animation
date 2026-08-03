class_name BodySwitcher
extends Node2D


@export var starting_body_index: int = 0
@export var body_name_menu_path: NodePath = ^"../../UI/Controls/BodyName"

@export_group("Debug")
@export var debug_chain: bool = false:
	set(value):
		debug_chain = value
		_apply_debug_chain_override()

var active_body_index: int = -1
var bodies: Array[Node] = []
@onready var body_name_menu := get_node_or_null(body_name_menu_path) as MenuButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_refresh_bodies()
	_setup_body_menu()
	_apply_debug_chain_override()
	if not bodies.is_empty():
		activate_body(starting_body_index)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"next_body"):
		cycle_body(1)
	elif event.is_action_pressed(&"prev_body"):
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
	if body_name_menu == null or active_body_index < 0:
		return

	body_name_menu.text = str(bodies[active_body_index].get("body_name"))
	var popup := body_name_menu.get_popup()
	for item_index in range(popup.item_count):
		popup.set_item_checked(
			item_index, popup.get_item_id(item_index) == active_body_index
		)


func _setup_body_menu() -> void:
	if body_name_menu == null:
		return
	var popup := body_name_menu.get_popup()
	popup.clear()
	for i in range(bodies.size()):
		popup.add_radio_check_item(str(bodies[i].get("body_name")), i)
	popup.id_pressed.connect(_on_body_menu_id_pressed)


func _on_body_menu_id_pressed(id: int) -> void:
	activate_body(id)


func _refresh_bodies() -> void:
	bodies.clear()
	for child in get_children():
		if child.has_method(&"activate") and child.has_method(&"deactivate"):
			bodies.append(child)


func _apply_debug_chain_override() -> void:
	for body in bodies:
		if body is ChainBody:
			(body as ChainBody).debug_chain = debug_chain
			(body as ChainBody).queue_redraw()
