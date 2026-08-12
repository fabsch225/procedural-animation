extends SceneTree


const POSITION_EPSILON: float = 0.02

var failures: int = 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var main_scene: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main_scene)
	await process_frame

	var switcher := main_scene.get_node("World/bodies") as BodySwitcher
	if switcher == null or switcher.bodies.size() < 5:
		_fail("main scene did not initialize all switchable bodies")
		_finish(main_scene)
		return
	_assert_body_menu(
		main_scene.get_node(
			"UI/ControlsMargin/ControlsContainer/BodyName"
		) as MenuButton,
		switcher
	)
	await _assert_control_debug_overlay(main_scene)
	_assert_chain_scene_anchor(switcher.bodies[0] as ChainScene)

	paused = true
	for body_index in range(1, switcher.bodies.size()):
		switcher.activate_body(body_index)
		var body := switcher.bodies[body_index] as ChainBody
		if body == null:
			continue
		_assert_consistent_chain(body.body_name, body.spine)
		_assert_chain_body_anchor(body)
		if not body.visible:
			_fail("%s was not visible after a paused switch" % body.body_name)

	var fish := switcher.bodies[2] as Fish
	if fish != null:
		_assert_fish_has_full_body(fish)

	var lizard := switcher.bodies[3] as Lizard
	if lizard != null:
		_assert_initialized_lizard_arms(lizard)

	var flower := switcher.bodies[4] as Flower
	if flower == null:
		_fail("flower was not registered as the fifth switchable body")
	else:
		_assert_initialized_flower(flower)

	_finish(main_scene)


func _anchor_action_event() -> InputEventAction:
	var event := InputEventAction.new()
	event.action = &"anchor"
	event.pressed = true
	return event


func _assert_chain_scene_anchor(body: ChainScene) -> void:
	if body == null or body.chain == null:
		_fail("chain scene was unavailable for anchor testing")
		return
	var expected_anchor := body.chain.joints.back()
	body.call(&"_unhandled_input", _anchor_action_event())
	if not body.locked or body.lock_anchor.distance_to(expected_anchor) > POSITION_EPSILON:
		_fail("chain scene did not anchor its tail through the anchor action")
	body.call(&"_unhandled_input", _anchor_action_event())
	if body.locked:
		_fail("chain scene did not release its anchor")


func _assert_chain_body_anchor(body: ChainBody) -> void:
	var started_anchored := body.anchored
	var expected_anchor := body.spine.joints.back()
	body.call(&"_unhandled_input", _anchor_action_event())
	if body.anchored == started_anchored:
		_fail("%s did not toggle its anchor through the anchor action" % body.body_name)
	if body.anchored \
			and body.anchor_position.distance_to(expected_anchor) > POSITION_EPSILON:
		_fail("%s did not anchor its tail at the expected position" % body.body_name)
	body.call(&"_unhandled_input", _anchor_action_event())
	if body.anchored != started_anchored:
		_fail("%s did not restore its initial anchor state" % body.body_name)
	if body.anchored \
			and body.anchor_position.distance_to(expected_anchor) > POSITION_EPSILON:
		_fail("%s did not anchor its tail at the expected position" % body.body_name)


func _assert_control_debug_overlay(main_scene: Node) -> void:
	var toggle := main_scene.get_node(
		"Pause/DebugPanel/Margin/Options/UIBounds"
	) as CheckButton
	var overlay := main_scene.get_node(
		"DebugOverlay/ControlBounds"
	) as ControlDebugOverlay
	if toggle == null or overlay == null:
		_fail("control debug overlay UI was not initialized")
		return
	toggle.toggled.emit(true)
	await process_frame
	if not overlay.debug_enabled or not overlay.visible:
		_fail("Show UI bounds did not enable the debug overlay")
	toggle.toggled.emit(false)
	if overlay.debug_enabled or overlay.visible:
		_fail("Show UI bounds did not disable the debug overlay")


func _assert_body_menu(menu: MenuButton, switcher: BodySwitcher) -> void:
	if menu == null or menu.get_popup().item_count != switcher.bodies.size():
		_fail("body menu did not list every switchable body")
		return
	menu.get_popup().id_pressed.emit(2)
	if switcher.active_body_index != 2 or menu.text != "fish":
		_fail("selecting a body menu item did not activate and label the body")
		return
	var selected_item := menu.get_popup().get_item_index(2)
	if selected_item < 0 or not menu.get_popup().is_item_checked(selected_item):
		_fail("body menu did not mark the active body")


func _assert_consistent_chain(test_name: String, chain: Chain) -> void:
	if chain == null or chain.joints.size() < 2:
		_fail("%s did not create a complete spine" % test_name)
		return
	for i in range(1, chain.joints.size()):
		var expected := chain.joints[i - 1] \
			- Vector2.from_angle(chain.angles[i]) * chain.link_size
		if chain.joints[i].distance_to(expected) > POSITION_EPSILON:
			_fail("%s started with positions that did not match its angles" % test_name)
			return


func _assert_fish_has_full_body(fish: Fish) -> void:
	var result: Variant = fish.call(&"_build_body_outline")
	if not result is PackedVector2Array:
		_fail("fish did not build its initial body outline")
		return
	var outline := result as PackedVector2Array
	if outline.is_empty():
		_fail("fish initial body outline was empty")
		return
	var bounds := Rect2(outline[0], Vector2.ZERO)
	for point in outline:
		bounds = bounds.expand(point)
	if bounds.size.x < fish.link_size * 4.0 or bounds.size.y < fish.body_widths[0]:
		_fail("fish initial body outline was still collapsed: %s" % bounds)
		return
	var triangles_result: Variant = fish.call(&"_tessellate_path", outline)
	if not triangles_result is PackedVector2Array \
			or (triangles_result as PackedVector2Array).is_empty():
		_fail("fish initial body outline did not produce a visible fill")


func _assert_initialized_lizard_arms(lizard: Lizard) -> void:
	if lizard.arms.size() != Lizard.ARM_COUNT:
		_fail("lizard did not initialize all arms")
		return
	for i in range(lizard.arms.size()):
		var arm := lizard.arms[i]
		var shoulder: Vector2 = lizard.call(&"_arm_shoulder_position", i)
		if arm.joints[-1].distance_to(shoulder) > POSITION_EPSILON:
			_fail("lizard arm %d was not attached to its shoulder" % i)
			return
		for joint_index in range(1, arm.joints.size()):
			var distance := arm.joints[joint_index].distance_to(
				arm.joints[joint_index - 1]
			)
			if absf(distance - arm.link_size) > POSITION_EPSILON:
				_fail("lizard arm %d started with a compressed link" % i)
				return


func _assert_initialized_flower(flower: Flower) -> void:
	if not flower.anchored:
		_fail("flower was not chained by default")
	if flower.LEAF_JOINT_INDICES.size() < 2:
		_fail("flower did not define at least two leaves")
		return
	for leaf_index in range(flower.LEAF_JOINT_INDICES.size()):
		var outline: PackedVector2Array = flower.call(
			&"_build_leaf_outline",
			flower.LEAF_JOINT_INDICES[leaf_index],
			1.0 if leaf_index % 2 == 0 else -1.0
		)
		if outline.size() < 3:
			_fail("flower leaf %d did not create a visible outline" % leaf_index)
	var petal: PackedVector2Array = flower.call(&"_build_petal_outline", 0)
	if flower.petal_count < 5 or petal.size() < 3:
		_fail("flower did not create a complete blossom")


func _finish(main_scene: Node) -> void:
	paused = false
	main_scene.queue_free()
	await process_frame
	if failures == 0:
		print("Body initialization tests passed")
		quit()
	else:
		push_error("Body initialization: %d test(s) failed" % failures)
		quit(1)


func _fail(message: String) -> void:
	failures += 1
	push_error(message)
