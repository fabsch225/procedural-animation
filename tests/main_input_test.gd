extends SceneTree


var failures: int = 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_assert_tooltip_delay()
	_assert_input_actions()
	var main_scene: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main_scene)
	await process_frame
	paused = false
	_assert_right_click_behavior(main_scene)
	_assert_left_click_behavior(main_scene)

	_send_key(main_scene, KEY_ENTER)
	_assert_paused(main_scene, true, "Enter")
	_send_key(main_scene, KEY_KP_ENTER)
	_assert_paused(main_scene, false, "keypad Enter")
	_send_key(main_scene, KEY_SPACE)
	_assert_paused(main_scene, true, "Space")
	_send_key(main_scene, KEY_ESCAPE)
	_assert_paused(main_scene, false, "Escape")
	_assert_left_click_cycles_body(main_scene)
	_assert_pause_indicator_layout(main_scene)
	_assert_pause_button(main_scene)
	_assert_action_tooltips(main_scene)

	paused = false
	main_scene.queue_free()
	await process_frame
	if failures == 0:
		print("Main input tests passed")
		quit()
	else:
		push_error("Main input: %d test(s) failed" % failures)
		quit(1)


func _assert_tooltip_delay() -> void:
	var delay: float = ProjectSettings.get_setting(
		&"gui/timers/tooltip_delay_sec", 0.5
	)
	if not is_equal_approx(delay, 0.05):
		_fail("project tooltip delay was not set to 0.05 seconds")


func _assert_input_actions() -> void:
	_assert_action_mouse_button(&"anchor", MOUSE_BUTTON_RIGHT)
	_assert_action_mouse_button(&"next_body", MOUSE_BUTTON_LEFT)
	_assert_action_keys(&"pause", [KEY_ESCAPE, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER])
	_assert_action_keys(&"fullscreen", [KEY_F])
	_assert_action_keys(&"restart", [KEY_R])


func _assert_action_mouse_button(action: StringName, expected_button: MouseButton) -> void:
	if not _action_has_mouse_button(action, expected_button):
		_fail("%s action is missing mouse button %d" % [action, expected_button])


func _action_has_mouse_button(action: StringName, button: MouseButton) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventMouseButton \
				and (event as InputEventMouseButton).button_index == button:
			return true
	return false


func _assert_action_keys(action: StringName, expected_keys: Array) -> void:
	var keycodes: Array[int] = []
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			keycodes.append((event as InputEventKey).keycode)
	for expected_key in expected_keys:
		if expected_key not in keycodes:
			_fail("%s action is missing %s" % [action, OS.get_keycode_string(expected_key)])


func _assert_action_tooltips(main_scene: Node) -> void:
	var fullscreen_hotkey: String = main_scene.call(
		&"_get_action_hotkey_text", &"fullscreen"
	)
	var pause_hotkey: String = main_scene.call(&"_get_action_hotkey_text", &"pause")
	var keypad_enter_event := InputEventKey.new()
	keypad_enter_event.keycode = KEY_KP_ENTER
	var fullscreen_button := main_scene.get_node(
		"UI/Controls/FullscreenButton"
	) as TextureButton
	var pause_button := main_scene.get_node("UI/Controls/PauseButton") as TextureButton
	if not fullscreen_button.tooltip_text.ends_with("(%s)" % fullscreen_hotkey):
		_fail("fullscreen tooltip did not use its Input Map binding")
	if not pause_button.tooltip_text.ends_with("(%s)" % pause_hotkey):
		_fail("pause tooltip did not use its Input Map bindings")
	for expected_label in ["Esc", "Space", "Enter"]:
		if expected_label not in pause_hotkey:
			_fail("pause tooltip omitted %s" % expected_label)
	if "Escape" in pause_hotkey \
			or "Spacebar" in pause_hotkey \
			or "Left Mouse Button" in pause_hotkey \
			or "Right Mouse Button" in pause_hotkey \
			or keypad_enter_event.as_text_keycode() in pause_hotkey:
		_fail("pause tooltip did not use compact input labels")


func _assert_right_click_behavior(main_scene: Node) -> void:
	var selector := main_scene.get_node(
		"Pause/DebugPanel/Margin/Options/RightClickRow/Behavior"
	) as OptionButton
	var pause_button := main_scene.get_node("UI/Controls/PauseButton") as TextureButton
	if selector == null or selector.item_count != 2:
		_fail("right-click behavior selector was not initialized")
		return
	var original_selection := selector.selected

	selector.select(0)
	selector.item_selected.emit(0)
	if not _action_has_mouse_button(&"anchor", MOUSE_BUTTON_RIGHT) \
			or _action_has_mouse_button(&"pause", MOUSE_BUTTON_RIGHT):
		_fail("Anchor behavior did not move right click to the anchor action")

	selector.select(1)
	selector.item_selected.emit(1)
	if _action_has_mouse_button(&"anchor", MOUSE_BUTTON_RIGHT) \
			or not _action_has_mouse_button(&"pause", MOUSE_BUTTON_RIGHT):
		_fail("Pause behavior did not move right click to the pause action")
	var pause_hotkey: String = main_scene.call(&"_get_action_hotkey_text", &"pause")
	if not pause_button.tooltip_text.ends_with("(%s)" % pause_hotkey) \
			or "RMB" not in pause_hotkey:
		_fail("pause tooltip did not update for the right-click binding")

	var right_click := InputEventMouseButton.new()
	right_click.button_index = MOUSE_BUTTON_RIGHT
	right_click.pressed = true
	main_scene.call(&"_unhandled_input", right_click)
	_assert_paused(main_scene, true, "right click")
	main_scene.call(&"_unhandled_input", right_click)
	_assert_paused(main_scene, false, "second right click")

	selector.select(original_selection)
	selector.item_selected.emit(original_selection)


func _assert_left_click_behavior(main_scene: Node) -> void:
	var selector := main_scene.get_node(
		"Pause/DebugPanel/Margin/Options/LeftClickRow/Behavior"
	) as OptionButton
	var pause_button := main_scene.get_node("UI/Controls/PauseButton") as TextureButton
	if selector == null or selector.item_count != 2:
		_fail("left-click behavior selector was not initialized")
		return
	var original_selection := selector.selected

	selector.select(0)
	selector.item_selected.emit(0)
	if not _action_has_mouse_button(&"next_body", MOUSE_BUTTON_LEFT) \
			or _action_has_mouse_button(&"pause", MOUSE_BUTTON_LEFT):
		_fail("Cycle behavior did not move left click to the cycle action")

	selector.select(1)
	selector.item_selected.emit(1)
	if _action_has_mouse_button(&"next_body", MOUSE_BUTTON_LEFT) \
			or not _action_has_mouse_button(&"pause", MOUSE_BUTTON_LEFT):
		_fail("Pause behavior did not move left click to the pause action")
	var pause_hotkey: String = main_scene.call(&"_get_action_hotkey_text", &"pause")
	if not pause_button.tooltip_text.ends_with("(%s)" % pause_hotkey) \
			or "LMB" not in pause_hotkey:
		_fail("pause tooltip did not update for the left-click binding")

	var left_click := InputEventMouseButton.new()
	left_click.button_index = MOUSE_BUTTON_LEFT
	left_click.pressed = true
	main_scene.call(&"_unhandled_input", left_click)
	_assert_paused(main_scene, true, "left click")
	main_scene.call(&"_unhandled_input", left_click)
	_assert_paused(main_scene, false, "second left click")

	selector.select(original_selection)
	selector.item_selected.emit(original_selection)


func _assert_pause_button(main_scene: Node) -> void:
	var pause_button := main_scene.get_node("UI/Controls/PauseButton") as TextureButton
	var switcher := main_scene.get_node("World/bodies") as BodySwitcher
	if pause_button == null or not pause_button.visible:
		_fail("pause button was not available while unpaused")
		return
	if pause_button.mouse_filter != Control.MOUSE_FILTER_STOP:
		_fail("pause button must consume clicks before body switching")
	var body_index_before_click := switcher.active_body_index
	if pause_button.texture_normal.resource_path.get_file() != "pause.png" \
			or not pause_button.tooltip_text.begins_with("Pause"):
		_fail("unpaused pause button did not show its pause state")
	pause_button.pressed.emit()
	_assert_paused(main_scene, true, "pause button")
	if switcher.active_body_index != body_index_before_click:
		_fail("pause button click also cycled the active body")
	if pause_button.texture_normal.resource_path.get_file() != "open.png" \
			or not pause_button.tooltip_text.begins_with("Unpause"):
		_fail("paused pause button did not show its unpause state")
	pause_button.pressed.emit()
	_assert_paused(main_scene, false, "second pause button click")


func _assert_pause_indicator_layout(main_scene: Node) -> void:
	var indicator := main_scene.get_node("Pause/PausedIndicator") as RichTextLabel
	var debug_panel := main_scene.get_node("Pause/DebugPanel") as Control
	var pause_button := main_scene.get_node("UI/Controls/PauseButton") as Control
	if indicator == null:
		_fail("paused indicator was not found")
		return
	if not indicator.bbcode_enabled or "[wave" not in indicator.text:
		_fail("paused indicator was not configured with a RichTextLabel wave")
	var indicator_rect := indicator.get_global_rect()
	if indicator_rect.position.x < debug_panel.get_global_rect().position.x - 0.01:
		_fail("paused indicator extended left of the debug panel boundary")
	if indicator_rect.end.x > pause_button.get_global_rect().position.x + 0.01:
		_fail("paused indicator extended into the pause button")


func _assert_left_click_cycles_body(main_scene: Node) -> void:
	var switcher := main_scene.get_node("World/bodies") as BodySwitcher
	var starting_index := switcher.active_body_index
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	switcher.call(&"_unhandled_input", event)
	var expected_index := wrapi(starting_index + 1, 0, switcher.bodies.size())
	if switcher.active_body_index != expected_index:
		_fail("left click did not cycle to the next body")
	if paused:
		_fail("left-click body cycling unexpectedly paused the game")


func _send_key(main_scene: Node, keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	main_scene.call(&"_input", event)


func _assert_paused(main_scene: Node, expected: bool, source: String) -> void:
	var pause_layer := main_scene.get_node("Pause") as CanvasLayer
	var indicator := main_scene.get_node("Pause/PausedIndicator") as RichTextLabel
	if paused != expected or pause_layer.visible != expected \
			or indicator.is_visible_in_tree() != expected:
		_fail("%s did not set pause state to %s" % [source, expected])


func _fail(message: String) -> void:
	failures += 1
	push_error(message)
