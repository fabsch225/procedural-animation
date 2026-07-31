extends Node


@export var hide_mouse_cursor: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.mouse_mode = (
		Input.MOUSE_MODE_HIDDEN
		if hide_mouse_cursor
		else Input.MOUSE_MODE_VISIBLE
	)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			toggle_pause()
			consume_input()
	elif event is InputEventKey:
		if event.is_action_pressed(&"restart") and not event.echo:
			consume_input()
			get_tree().paused = false
			get_tree().reload_current_scene()
		elif event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
			toggle_pause()
			consume_input()


func toggle_pause() -> void:
	get_tree().paused = not get_tree().paused


func consume_input() -> void:
	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()
