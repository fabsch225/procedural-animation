extends Node

const ENTER_FULLSCREEN_ICON: Texture2D = preload("res://ui/icons/2x/larger.png")

const EXIT_FULLSCREEN_ICON: Texture2D = preload("res://ui/icons/2x/smaller.png")

const PAUSE_ICON: Texture2D = preload("res://ui/icons/2x/pause.png")

const UNPAUSE_ICON: Texture2D = preload("res://ui/icons/2x/open.png")

enum RightClickBehavior {
	ANCHOR,
	PAUSE,
}

enum LeftClickBehavior {
	CYCLE,
	PAUSE,
}

@export var hide_mouse_cursor: bool = false

@onready var pause_layer: CanvasLayer = $Pause
@onready var controls_container: Control = $UI/ControlsMargin/ControlsContainer
@onready var pause_button: TextureButton = controls_container.get_node("PauseButton")
@onready var debug_chain_toggle: CheckButton = $Pause/DebugPanel/Margin/Options/DebugChain
@onready var ui_bounds_toggle: CheckButton = $Pause/DebugPanel/Margin/Options/UIBounds
@onready var right_click_behavior: OptionButton = $Pause/DebugPanel/Margin/Options/RightClickRow/Behavior
@onready var left_click_behavior: OptionButton = $Pause/DebugPanel/Margin/Options/LeftClickRow/Behavior
@onready var body_switcher: BodySwitcher = $World/bodies
@onready var fullscreen_button: TextureButton = controls_container.get_node("FullscreenButton")
@onready var control_debug_overlay: ControlDebugOverlay = $DebugOverlay/ControlBounds
@onready var creature_level_slider: HSlider = $Pause/DebugPanel/Margin/Options/CreatureRow/Level
@onready var creature_level_value: Label = $Pause/DebugPanel/Margin/Options/CreatureRow/Value
@onready var randomize_creature_button: Button = $Pause/DebugPanel/Margin/Options/RandomizeButton
@onready var creature_summary_label: Label = $Pause/DebugPanel/Margin/Options/CreatureSummary
@onready var zoo_button: Button = $Pause/DebugPanel/Margin/Options/ZooButton

var _windowed_mode_before_fullscreen: int = DisplayServer.WINDOW_MODE_WINDOWED


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	pause_layer.visible = get_tree().paused
	debug_chain_toggle.set_pressed_no_signal(body_switcher.debug_chain)
	debug_chain_toggle.toggled.connect(_on_debug_chain_toggled)
	ui_bounds_toggle.set_pressed_no_signal(control_debug_overlay.debug_enabled)
	ui_bounds_toggle.toggled.connect(_on_ui_bounds_toggled)
	right_click_behavior.item_selected.connect(_on_right_click_behavior_selected)
	_set_right_click_behavior(right_click_behavior.selected)
	left_click_behavior.item_selected.connect(_on_left_click_behavior_selected)
	_set_left_click_behavior(left_click_behavior.selected)
	_setup_creature_controls()
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
	if event is InputEventKey:
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
		elif event.is_action_pressed(&"randomize_creature") and not event.echo:
			randomize_creature()
			consume_input()
		elif not event.echo and event.pressed and _level_from_keycode(event.keycode) > 0:
			set_creature_level(_level_from_keycode(event.keycode))
			consume_input()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_action_pressed(&"pause"):
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


func _on_right_click_behavior_selected(index: int) -> void:
	_set_right_click_behavior(index)


func _on_left_click_behavior_selected(index: int) -> void:
	_set_left_click_behavior(index)


func _set_right_click_behavior(index: int) -> void:
	var behavior := clampi(
		index, RightClickBehavior.ANCHOR, RightClickBehavior.PAUSE
	) as RightClickBehavior
	right_click_behavior.select(behavior)
	_remove_mouse_button_from_action(&"anchor", MOUSE_BUTTON_RIGHT)
	_remove_mouse_button_from_action(&"pause", MOUSE_BUTTON_RIGHT)

	var right_click := InputEventMouseButton.new()
	right_click.button_index = MOUSE_BUTTON_RIGHT
	var action := &"pause" if behavior == RightClickBehavior.PAUSE else &"anchor"
	InputMap.action_add_event(action, right_click)
	_update_pause_button()


func _set_left_click_behavior(index: int) -> void:
	var behavior := clampi(
		index, LeftClickBehavior.CYCLE, LeftClickBehavior.PAUSE
	) as LeftClickBehavior
	left_click_behavior.select(behavior)
	_remove_mouse_button_from_action(&"next_body", MOUSE_BUTTON_LEFT)
	_remove_mouse_button_from_action(&"pause", MOUSE_BUTTON_LEFT)

	var left_click := InputEventMouseButton.new()
	left_click.button_index = MOUSE_BUTTON_LEFT
	var action := &"pause" if behavior == LeftClickBehavior.PAUSE else &"next_body"
	InputMap.action_add_event(action, left_click)
	_update_pause_button()


func _remove_mouse_button_from_action(
	action: StringName,
	button: MouseButton
) -> void:
	for input_event in InputMap.action_get_events(action):
		if input_event is InputEventMouseButton \
				and (input_event as InputEventMouseButton).button_index == button:
			InputMap.action_erase_event(action, input_event)


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
	var input_events := InputMap.action_get_events(action)
	var mapped_keycodes: Array[int] = []
	for input_event in input_events:
		if input_event is InputEventKey:
			mapped_keycodes.append((input_event as InputEventKey).keycode)
	for input_event in input_events:
		var event_label := ""
		if input_event is InputEventKey:
			var key_event := input_event as InputEventKey
			# Treat keypad Enter as an alternate physical way to press Enter in
			# compact UI text when both are mapped; it remains a real binding.
			if key_event.keycode == KEY_KP_ENTER and KEY_ENTER in mapped_keycodes:
				continue
			event_label = _compact_key_label(key_event)
		elif input_event is InputEventMouseButton:
			event_label = _compact_mouse_button_label(input_event)
		else:
			event_label = input_event.as_text()
		if not event_label.is_empty() and event_label not in labels:
			labels.append(event_label)
	return " / ".join(labels)


func _compact_key_label(event: InputEventKey) -> String:
	match event.keycode:
		KEY_ESCAPE:
			return "Esc"
		KEY_SPACE:
			return "Space"
		_:
			return event.as_text_keycode()


func _compact_mouse_button_label(event: InputEventMouseButton) -> String:
	match event.button_index:
		MOUSE_BUTTON_LEFT:
			return "LMB"
		MOUSE_BUTTON_RIGHT:
			return "RMB"
		_:
			return event.as_text()


# --- Creature randomizer ----------------------------------------------------


func _setup_creature_controls() -> void:
	var creature := body_switcher.get_creature()
	if creature != null:
		creature_level_slider.set_value_no_signal(float(creature.creature_level))
		creature.creature_changed.connect(_on_creature_changed)
		_on_creature_changed(creature.traits)
	creature_level_slider.value_changed.connect(_on_creature_level_changed)
	randomize_creature_button.pressed.connect(_on_randomize_creature_pressed)
	zoo_button.pressed.connect(_on_zoo_button_pressed)
	randomize_creature_button.tooltip_text = _with_action_hotkey(
		"Roll a brand new creature at the current level", &"randomize_creature"
	)
	creature_level_value.text = str(int(creature_level_slider.value))


# Rolls a new creature and makes sure it is the body on screen.
func randomize_creature() -> void:
	var creature := body_switcher.get_creature()
	if creature == null:
		return
	var index := body_switcher.find_body_index(creature)
	if index >= 0 and index != body_switcher.active_body_index:
		body_switcher.activate_body(index)
	creature.reroll(int(creature_level_slider.value))


func set_creature_level(level: int) -> void:
	var clamped := clampi(level, 1, 10)
	creature_level_slider.set_value_no_signal(float(clamped))
	creature_level_value.text = str(clamped)
	var creature := body_switcher.get_creature()
	if creature != null:
		creature.creature_level = clamped
	randomize_creature()


func _on_creature_level_changed(value: float) -> void:
	creature_level_value.text = str(int(value))
	var creature := body_switcher.get_creature()
	if creature != null:
		creature.creature_level = int(value)


func _on_randomize_creature_pressed() -> void:
	randomize_creature()


func _on_zoo_button_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/zoo.tscn")


func _on_creature_changed(new_traits: CreatureTraits) -> void:
	if new_traits == null:
		return
	creature_summary_label.text = "%s\n%s" % [
		new_traits.display_name, new_traits.summary()
	]
	body_switcher.refresh_body_names()


# Number row 1-9 picks a level directly, 0 means level 10.
func _level_from_keycode(keycode: Key) -> int:
	if keycode == KEY_0:
		return 10
	if keycode >= KEY_1 and keycode <= KEY_9:
		return int(keycode) - int(KEY_0)
	return 0


func _is_fullscreen() -> bool:
	var mode := DisplayServer.window_get_mode()
	return mode == DisplayServer.WINDOW_MODE_FULLSCREEN \
		or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
