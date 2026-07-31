extends Node


const ENTER_FULLSCREEN_ICON: Texture2D = preload("res://ui/icons/2x/larger.png")

const EXIT_FULLSCREEN_ICON: Texture2D = preload("res://ui/icons/2x/smaller.png")

const PAUSE_ICON: Texture2D = preload("res://ui/icons/2x/pause.png")

const UNPAUSE_ICON: Texture2D = preload("res://ui/icons/2x/open.png")

@export var hide_mouse_cursor: bool = false

@onready var pause_layer: CanvasLayer = $Pause
@onready var pause_button: TextureButton = $UI/Controls/PauseButton
@onready var pause_debug_panel: Control = $Pause/DebugPanel
@onready var debug_chain_toggle: CheckButton = $Pause/DebugPanel/Margin/Options/DebugChain
@onready var ui_bounds_toggle: CheckButton = $Pause/DebugPanel/Margin/Options/UIBounds
@onready var body_switcher: BodySwitcher = $World/bodies
@onready var body_name_menu: MenuButton = $UI/Controls/BodyName
@onready var fullscreen_button: TextureButton = $UI/Controls/FullscreenButton
@onready var control_debug_overlay: ControlDebugOverlay = $DebugOverlay/ControlBounds

var _windowed_mode_before_fullscreen: int = DisplayServer.WINDOW_MODE_WINDOWED


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	pause_layer.visible = get_tree().paused
	debug_chain_toggle.set_pressed_no_signal(body_switcher.debug_chain)
	debug_chain_toggle.toggled.connect(_on_debug_chain_toggled)
	ui_bounds_toggle.set_pressed_no_signal(control_debug_overlay.debug_enabled)
	ui_bounds_toggle.toggled.connect(_on_ui_bounds_toggled)
	pause_button.pressed.connect(_on_pause_button_pressed)
	fullscreen_button.pressed.connect(_on_fullscreen_button_pressed)
	get_viewport().size_changed.connect(_update_fullscreen_button)
	if not _is_fullscreen():
		_windowed_mode_before_fullscreen = DisplayServer.window_get_mode()
	_update_fullscreen_button()
	_update_pause_button()
	Input.mouse_mode = (
		Input.MOUSE_MODE_HIDDEN
		if hide_mouse_cursor
		else Input.MOUSE_MODE_VISIBLE
	)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if _is_mouse_over_pause_button() \
					or _is_mouse_over_body_name_menu() \
					or _is_mouse_over_fullscreen_button():
				return
			if get_tree().paused and _is_mouse_over_pause_debug_panel():
				return
			toggle_pause()
			consume_input()
	elif event is InputEventKey:
		if event.is_action_pressed(&"restart") and not event.echo:
			consume_input()
			get_tree().paused = false
			get_tree().reload_current_scene()
		elif event.is_action_pressed(&"fullscreen") and not event.echo:
			_on_fullscreen_button_pressed()
			consume_input()
		elif event.is_action_pressed(&"pause") and not event.echo:
			toggle_pause()
			consume_input()


func toggle_pause() -> void:
	get_tree().paused = not get_tree().paused
	pause_layer.visible = get_tree().paused
	_update_pause_button()


func consume_input() -> void:
	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()


func _on_debug_chain_toggled(enabled: bool) -> void:
	body_switcher.debug_chain = enabled


func _on_ui_bounds_toggled(enabled: bool) -> void:
	control_debug_overlay.debug_enabled = enabled


func _on_pause_button_pressed() -> void:
	toggle_pause()


func _on_fullscreen_button_pressed() -> void:
	if _is_fullscreen():
		var restore_mode := _windowed_mode_before_fullscreen
		if restore_mode != DisplayServer.WINDOW_MODE_WINDOWED \
				and restore_mode != DisplayServer.WINDOW_MODE_MAXIMIZED:
			restore_mode = DisplayServer.WINDOW_MODE_WINDOWED
		DisplayServer.window_set_mode(restore_mode)
	else:
		_windowed_mode_before_fullscreen = DisplayServer.window_get_mode()
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	_update_fullscreen_button.call_deferred()


func _update_fullscreen_button() -> void:
	if not is_instance_valid(fullscreen_button):
		return
	var fullscreen := _is_fullscreen()
	var icon := EXIT_FULLSCREEN_ICON if fullscreen else ENTER_FULLSCREEN_ICON
	fullscreen_button.texture_normal = icon
	fullscreen_button.texture_hover = icon
	fullscreen_button.texture_pressed = icon
	var action_text := "Exit fullscreen" if fullscreen else "Enter fullscreen"
	fullscreen_button.tooltip_text = _with_action_hotkey(action_text, &"fullscreen")


func _update_pause_button() -> void:
	if not is_instance_valid(pause_button):
		return
	var paused := get_tree().paused
	var icon := UNPAUSE_ICON if paused else PAUSE_ICON
	pause_button.texture_normal = icon
	pause_button.texture_hover = icon
	pause_button.texture_pressed = icon
	var action_text := "Unpause" if paused else "Pause"
	pause_button.tooltip_text = _with_action_hotkey(action_text, &"pause")


func _with_action_hotkey(label: String, action: StringName) -> String:
	var hotkey := _get_action_hotkey_text(action)
	return label if hotkey.is_empty() else "%s (%s)" % [label, hotkey]


func _get_action_hotkey_text(action: StringName) -> String:
	var labels := PackedStringArray()
	for input_event in InputMap.action_get_events(action):
		var event_label := ""
		if input_event is InputEventKey:
			event_label = (input_event as InputEventKey).as_text_keycode()
		else:
			event_label = input_event.as_text()
		if not event_label.is_empty() and event_label not in labels:
			labels.append(event_label)
	return " / ".join(labels)


func _is_fullscreen() -> bool:
	var mode := DisplayServer.window_get_mode()
	return mode == DisplayServer.WINDOW_MODE_FULLSCREEN \
		or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN


func _is_mouse_over_fullscreen_button() -> bool:
	return fullscreen_button.is_visible_in_tree() \
		and fullscreen_button.get_global_rect().has_point(
			get_viewport().get_mouse_position()
		)


func _is_mouse_over_pause_button() -> bool:
	return pause_button.is_visible_in_tree() \
		and pause_button.get_global_rect().has_point(
			get_viewport().get_mouse_position()
		)


func _is_mouse_over_body_name_menu() -> bool:
	return body_name_menu.is_visible_in_tree() \
		and body_name_menu.get_global_rect().has_point(
			get_viewport().get_mouse_position()
		)


func _is_mouse_over_pause_debug_panel() -> bool:
	return pause_debug_panel.get_global_rect().has_point(get_viewport().get_mouse_position())
