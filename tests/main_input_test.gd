extends SceneTree


var failures: int = 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_assert_input_actions()
	var main_scene: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main_scene)
	await process_frame
	paused = false

	_send_key(main_scene, KEY_ENTER)
	_assert_paused(main_scene, false, "removed Enter binding")
	_send_key(main_scene, KEY_SPACE)
	_assert_paused(main_scene, true, "Space")
	_send_key(main_scene, KEY_ESCAPE)
	_assert_paused(main_scene, false, "Escape")
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


func _assert_input_actions() -> void:
	_assert_action_keys(&"pause", [KEY_ESCAPE, KEY_SPACE])
	_assert_action_keys(&"fullscreen", [KEY_F])
	_assert_action_keys(&"restart", [KEY_R])


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
	var fullscreen_button := main_scene.get_node(
		"UI/Controls/FullscreenButton"
	) as TextureButton
	var pause_button := main_scene.get_node("UI/Controls/PauseButton") as TextureButton
	if not fullscreen_button.tooltip_text.ends_with("(%s)" % fullscreen_hotkey):
		_fail("fullscreen tooltip did not use its Input Map binding")
	if not pause_button.tooltip_text.ends_with("(%s)" % pause_hotkey):
		_fail("pause tooltip did not use its Input Map bindings")


func _assert_pause_button(main_scene: Node) -> void:
	var pause_button := main_scene.get_node("UI/Controls/PauseButton") as TextureButton
	if pause_button == null or not pause_button.visible:
		_fail("pause button was not available while unpaused")
		return
	if pause_button.texture_normal.resource_path.get_file() != "pause.png" \
			or not pause_button.tooltip_text.begins_with("Pause "):
		_fail("unpaused pause button did not show its pause state")
	pause_button.pressed.emit()
	_assert_paused(main_scene, true, "pause button")
	if pause_button.texture_normal.resource_path.get_file() != "open.png" \
			or not pause_button.tooltip_text.begins_with("Unpause "):
		_fail("paused pause button did not show its unpause state")
	pause_button.pressed.emit()
	_assert_paused(main_scene, false, "second pause button click")


func _send_key(main_scene: Node, keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	main_scene.call(&"_input", event)


func _assert_paused(main_scene: Node, expected: bool, source: String) -> void:
	var pause_layer := main_scene.get_node("Pause") as CanvasLayer
	if paused != expected or pause_layer.visible != expected:
		_fail("%s did not set pause state to %s" % [source, expected])


func _fail(message: String) -> void:
	failures += 1
	push_error(message)
