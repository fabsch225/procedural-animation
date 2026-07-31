extends Control


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
			get_viewport().set_input_as_handled()
	elif event is InputEventKey:
		if event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
			toggle_pause()
			get_viewport().set_input_as_handled()


func toggle_pause() -> void:
	get_tree().paused = not get_tree().paused
