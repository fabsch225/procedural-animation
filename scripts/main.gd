extends Node


@export var hide_mouse_cursor: bool = false

@onready var pause_layer: CanvasLayer = $Pause
@onready var pause_debug_panel: Control = $Pause/DebugPanel
@onready var debug_chain_toggle: CheckButton = $Pause/DebugPanel/Margin/Options/DebugChain
@onready var body_switcher: BodySwitcher = $World/bodies


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	pause_layer.visible = get_tree().paused
	debug_chain_toggle.set_pressed_no_signal(body_switcher.debug_chain)
	debug_chain_toggle.toggled.connect(_on_debug_chain_toggled)
	Input.mouse_mode = (
		Input.MOUSE_MODE_HIDDEN
		if hide_mouse_cursor
		else Input.MOUSE_MODE_VISIBLE
	)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if get_tree().paused and _is_mouse_over_pause_debug_panel():
				return
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
	pause_layer.visible = get_tree().paused


func consume_input() -> void:
	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()


func _on_debug_chain_toggled(enabled: bool) -> void:
	body_switcher.debug_chain = enabled


func _is_mouse_over_pause_debug_panel() -> bool:
	return pause_debug_panel.get_global_rect().has_point(get_viewport().get_mouse_position())
