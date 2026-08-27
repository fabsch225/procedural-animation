@tool
extends McpTestSuite

## Covers the procedural creature generator, trait inheritance when two
## animals are fused, and the zoo scene's buy/hatch/fuse loop.


func suite_name() -> String:
	return "zoo_creatures"


func test_randomizer_produces_valid_traits() -> void:
	for level in range(1, 11):
		for attempt in range(12):
			var traits := CreatureRandomizer.generate(level, level * 1000 + attempt + 1)
			assert_eq(traits.level, level, "generated level should match the request")
			assert_true(traits.joint_count >= 10, "joint count should stay usable")
			assert_eq(
				traits.body_widths.size(),
				traits.joint_count,
				"every joint needs a body width"
			)
			for width in traits.body_widths:
				assert_true(
					width > 0.0 and is_finite(width), "body widths must be positive"
				)
			assert_true(traits.link_size > 0.0, "link size must be positive")
			assert_true(traits.movement_speed > 0.0, "movement speed must be positive")
			assert_true(not traits.display_name.is_empty(), "creatures need a name")
			assert_true(
				traits.leg_pairs >= 0 and traits.leg_pairs <= 3, "leg pairs stay in range"
			)
			assert_true(
				traits.eye_pair_count >= 1 and traits.eye_pair_count <= 3,
				"eye pairs stay in range"
			)


func test_higher_levels_make_bigger_creatures() -> void:
	var small_width := 0.0
	var large_width := 0.0
	var small_joints := 0
	var large_joints := 0
	var samples := 24

	for attempt in range(samples):
		var small := CreatureRandomizer.generate(1, attempt + 1)
		var large := CreatureRandomizer.generate(10, attempt + 1)
		small_width += small.body_radius(0)
		large_width += large.body_radius(0)
		small_joints += small.joint_count
		large_joints += large.joint_count

	assert_gt(
		large_width / float(samples),
		small_width / float(samples),
		"level 10 creatures should be wider on average than level 1"
	)
	assert_gt(
		float(large_joints) / float(samples),
		float(small_joints) / float(samples),
		"level 10 creatures should have longer spines on average"
	)


func test_fusion_inherits_features_from_both_parents() -> void:
	var horned := CreatureRandomizer.generate(3, 4242)
	horned.horn_style = CreatureTraits.HornStyle.CURVED
	horned.horn_pairs = 1
	horned.horn_length = horned.body_radius(0) * 2.0
	horned.horn_width = horned.body_radius(0) * 0.25
	horned.wing_pairs = 0
	horned.leg_pairs = 0

	var winged := CreatureRandomizer.generate(3, 777)
	winged.horn_style = CreatureTraits.HornStyle.NONE
	winged.wing_pairs = 1
	winged.wing_span = winged.body_radius(0) * 3.0
	winged.wing_fingers = 3
	winged.leg_pairs = 2
	winged.leg_link_size = winged.body_radius(0)
	winged.leg_width = winged.body_radius(0) * 0.4
	winged.foot_reach = winged.body_radius(0) * 1.3

	var child := CreatureRandomizer.merge(
		horned, winged, 99, CreatureTraits.Habitat.ALIEN
	)

	assert_true(
		child.level == 4 or child.level == 5,
		"breeding two level 3 animals gives level 4 or 5"
	)
	assert_ne(
		child.horn_style,
		CreatureTraits.HornStyle.NONE,
		"the horned parent's horns should carry over"
	)
	assert_gt(child.horn_length, 0.0, "inherited horns need a length")
	assert_gt(child.wing_pairs, 0, "the winged parent's wings should carry over")
	assert_gt(child.wing_span, 0.0, "inherited wings need a span")
	assert_gt(child.leg_pairs, 0, "the legged parent's legs should carry over")
	assert_eq(
		child.body_widths.size(), child.joint_count, "the child rebuilds its own body"
	)
	assert_true(not child.display_name.is_empty(), "fusions need a name")


func test_fusion_stops_at_the_top_level() -> void:
	var first := CreatureRandomizer.generate(10, 11)
	var second := CreatureRandomizer.generate(10, 12)
	var child := CreatureRandomizer.merge(first, second, 13)
	assert_eq(child.level, 10, "level 10 is the ceiling")


func test_income_grows_with_level() -> void:
	var previous := 0.0
	for level in range(1, 11):
		var income := Enclosure.level_income(level)
		assert_gt(income, previous, "income should rise with every level")
		previous = income


func _make_stage() -> SubViewport:
	var stage := SubViewport.new()
	stage.size = Vector2i(1280, 720)
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	Engine.get_main_loop().root.add_child(stage)
	track(stage)
	return stage


func _house_creature(
		stage: SubViewport,
		level: int,
		seed_value: int,
		habitat: CreatureTraits.Habitat = CreatureTraits.Habitat.BASIC
) -> Enclosure:
	var pen := Enclosure.new()
	pen.habitat = habitat
	pen.size = Vector2(540.0, 430.0)
	stage.add_child(pen)

	var creature := Creature.new()
	creature.traits = CreatureRandomizer.generate(level, seed_value, habitat)
	creature.randomize_on_ready = false
	creature.start_at_viewport_center = false
	pen.set_creature(creature)
	return pen


func test_enclosure_houses_and_scales_a_creature() -> void:
	var stage := _make_stage()
	var pen := _house_creature(stage, 1, 4321)
	var creature := pen.creature

	assert_true(not pen.is_empty(), "the pen should hold its creature")
	assert_eq(
		creature.spine.joints.size(),
		creature.traits.joint_count,
		"the spine matches the trait joint count"
	)
	assert_eq(
		creature.control_mode,
		Creature.ControlMode.ROAM,
		"penned creatures wander instead of chasing the mouse"
	)
	assert_true(
		creature.scale.x > 0.0 and creature.scale.x <= 0.55,
		"animals are scaled down to leave room inside the pen"
	)
	assert_gt(creature.roam_bounds.size.x, 0.0, "roaming needs a real area")
	assert_eq(
		pen.income_per_second(),
		Enclosure.level_income(1),
		"income comes from the housed creature's level"
	)


func test_roaming_stays_inside_the_pen() -> void:
	var stage := _make_stage()
	var pen := _house_creature(stage, 4, 8888)
	var creature := pen.creature
	var bounds := creature.roam_bounds.grow(creature.link_size * 2.0)

	for step in range(240):
		creature._process(1.0 / 60.0)

	var head := creature.spine.joints[0]
	assert_true(
		is_finite(head.x) and is_finite(head.y), "the head position stays finite"
	)
	assert_true(bounds.has_point(head), "a roaming head stays near its pen")

	for joint in creature.spine.joints:
		assert_true(
			is_finite(joint.x) and is_finite(joint.y), "every joint stays finite"
		)


func test_fusing_two_penned_creatures() -> void:
	var stage := _make_stage()
	var first := _house_creature(stage, 3, 2468)
	var second := _house_creature(stage, 3, 1357)

	var child_traits := CreatureRandomizer.merge(
		first.creature.traits, second.creature.traits, 24680, second.habitat
	)
	assert_true(
		child_traits.level == 4 or child_traits.level == 5,
		"breeding lifts the child one or two levels"
	)

	first.clear_creature()
	second.clear_creature()
	assert_true(first.is_empty(), "both parents leave their pens")
	assert_true(second.is_empty(), "both parents leave their pens")

	var child := Creature.new()
	child.traits = child_traits
	child.randomize_on_ready = false
	child.start_at_viewport_center = false
	second.set_creature(child)

	assert_true(not second.is_empty(), "the fusion moves into a pen")
	assert_eq(child.body_name, child_traits.display_name, "the pen shows the new name")
	assert_gt(
		second.income_per_second(),
		Enclosure.level_income(3),
		"a bred animal earns more than either parent"
	)


func test_creature_geometry_is_finite() -> void:
	var stage := _make_stage()

	for level in [1, 5, 10]:
		var pen := _house_creature(stage, level, level * 31 + 7)
		var creature := pen.creature

		var outline := creature._build_body_outline()
		assert_gt(outline.size(), 8, "the body outline should have real geometry")
		for point in outline:
			assert_true(
				is_finite(point.x) and is_finite(point.y),
				"outline points must be finite"
			)

		assert_eq(
			creature.legs.size(),
			creature.traits.leg_pairs * 2,
			"a creature builds one chain per leg"
		)
		for leg in creature.legs:
			assert_eq(
				leg.joints.size(), Creature.LEG_JOINT_COUNT, "legs keep their joints"
			)

		var axis := creature._axis(Vector2.ZERO, 0.0, 60.0, 0.8, 8)
		var taper := creature._build_taper(axis, 12.0, 0.1)
		assert_gt(taper.size(), 8, "tapered features build a closed outline")
		for point in taper:
			assert_true(
				is_finite(point.x) and is_finite(point.y),
				"feature outlines must be finite"
			)


func test_reef_habitat_locks_swimming_features() -> void:
	for attempt in range(20):
		var traits := CreatureRandomizer.generate(
			(attempt % 10) + 1, attempt + 501, CreatureTraits.Habitat.WATER
		)
		assert_eq(traits.habitat, CreatureTraits.Habitat.WATER, "habitat is recorded")
		assert_eq(traits.leg_pairs, 0, "reef animals have no legs")
		assert_eq(traits.wing_pairs, 0, "reef animals have no wings")
		assert_true(traits.pectoral_fins, "reef animals always have fins")
		assert_eq(
			traits.tail_tip,
			CreatureTraits.TailTip.CAUDAL_FIN,
			"reef animals always have a swimming tail"
		)
		assert_true(
			traits.body_color.h >= 0.4 and traits.body_color.h <= 0.72,
			"reef colours stay in the blue-green family"
		)


func test_meadow_habitat_keeps_animals_on_the_ground() -> void:
	for attempt in range(20):
		var level := (attempt % 6) + 1
		var traits := CreatureRandomizer.generate(
			level, attempt + 901, CreatureTraits.Habitat.BASIC
		)
		assert_false(traits.pectoral_fins, "meadow animals have no fins")
		assert_false(traits.pelvic_fins, "meadow animals have no fins")
		assert_eq(traits.wing_pairs, 0, "meadow animals below level 7 cannot fly")
		assert_ne(
			traits.tail_tip,
			CreatureTraits.TailTip.CAUDAL_FIN,
			"meadow animals do not get swimming tails"
		)


func test_void_habitat_adds_alien_features() -> void:
	for attempt in range(20):
		var traits := CreatureRandomizer.generate(
			(attempt % 8) + 3, attempt + 1301, CreatureTraits.Habitat.ALIEN
		)
		assert_gt(traits.antenna_pairs, 0, "void animals always grow antennae")
		assert_gt(traits.eye_pair_count, 1, "void animals above level 2 have extra eyes")
		assert_true(
			traits.body_color.h >= 0.68 or traits.body_color.h <= 0.02,
			"void colours stay violet to magenta"
		)


func test_wild_habitat_leaves_traits_untouched() -> void:
	var wild := CreatureRandomizer.generate(6, 4242)
	var reef := CreatureRandomizer.generate(6, 4242, CreatureTraits.Habitat.WATER)
	assert_eq(wild.habitat, CreatureTraits.Habitat.WILD, "the sandbox stays unconstrained")
	assert_eq(
		wild.joint_count, reef.joint_count, "the habitat only reshapes features, not the spine"
	)
	assert_ne(wild.body_color, reef.body_color, "the habitat repaints the animal")


func test_habitat_shapes_bred_children() -> void:
	var first := CreatureRandomizer.generate(4, 31, CreatureTraits.Habitat.BASIC)
	var second := CreatureRandomizer.generate(4, 32, CreatureTraits.Habitat.BASIC)
	var child := CreatureRandomizer.merge(first, second, 33, CreatureTraits.Habitat.WATER)

	assert_eq(child.habitat, CreatureTraits.Habitat.WATER, "the child belongs to its pen")
	assert_eq(child.leg_pairs, 0, "a reef child loses its parents' legs")
	assert_true(child.pectoral_fins, "a reef child gains fins")
	assert_true(child.level >= 5 and child.level <= 6, "breeding lifts one or two levels")


func test_pens_carry_their_own_scenery() -> void:
	var stage := _make_stage()
	for habitat in [
		CreatureTraits.Habitat.BASIC,
		CreatureTraits.Habitat.WATER,
		CreatureTraits.Habitat.ALIEN,
	]:
		var pen := _house_creature(stage, 3, 77 + int(habitat), habitat)
		assert_eq(pen.habitat, habitat, "the pen remembers its habitat")
		assert_eq(
			pen.creature.traits.habitat, habitat, "its animal is shaped by the habitat"
		)
		assert_true(
			pen.creature.scale.x > 0.0 and pen.creature.scale.x <= 0.55,
			"a big pen still leaves room around its animal"
		)
		var decor_found := false
		for child in pen.get_children():
			if child is HabitatDecor:
				decor_found = true
				assert_eq(
					(child as HabitatDecor).habitat, habitat, "decor matches the habitat"
				)
		assert_true(decor_found, "every pen grows its own scenery")


func test_roaming_never_snaps_the_body() -> void:
	var stage := _make_stage()
	var pen := _house_creature(stage, 5, 24601)
	var creature := pen.creature
	var delta := 1.0 / 60.0

	# What one frame is allowed to change: the head only ever moves a step of
	# speed * delta, and every joint behind it only swings by its link length
	# times the bounded heading change.
	var step_limit := creature.movement_speed * creature.roam_speed_scale * delta
	# A joint may drift a step plus a little constraint slack. A snap moves it by
	# a whole link or more, so a quarter link is a wide but decisive line.
	var joint_limit := step_limit + creature.link_size * 0.25
	var turn_limit := creature.roam_turn_rate * delta * 1.5 + 0.001

	var previous_joints := creature.spine.joints.duplicate()
	var previous_heading := creature.spine.angles[0]
	var worst_joint_move := 0.0
	var worst_turn := 0.0

	# Long enough to reach several goal points and to turn around at the bounds.
	for step in range(600):
		creature._process(delta)
		var joints := creature.spine.joints
		for i in range(joints.size()):
			worst_joint_move = maxf(
				worst_joint_move, previous_joints[i].distance_to(joints[i])
			)
		worst_turn = maxf(
			worst_turn,
			absf(Util.relative_angle_diff(previous_heading, creature.spine.angles[0]))
		)
		previous_joints = joints.duplicate()
		previous_heading = creature.spine.angles[0]

	assert_true(
		worst_turn <= turn_limit,
		"the heading turned %.3f rad in one frame, limit %.3f" % [worst_turn, turn_limit]
	)
	assert_true(
		worst_joint_move <= joint_limit,
		"a joint moved %.1f px in one frame, limit %.1f - the body snapped"
		% [worst_joint_move, joint_limit]
	)


func test_roaming_keeps_moving_forward() -> void:
	var stage := _make_stage()
	var pen := _house_creature(stage, 2, 1998)
	var creature := pen.creature
	var delta := 1.0 / 60.0
	var travelled := 0.0
	var previous := creature.spine.joints[0]

	for step in range(300):
		creature._process(delta)
		travelled += previous.distance_to(creature.spine.joints[0])
		previous = creature.spine.joints[0]

	var slowest := creature.movement_speed * creature.roam_speed_scale * 0.55
	assert_gt(
		travelled,
		slowest * 300.0 * delta * 0.9,
		"a roaming animal should keep swimming rather than stopping on its goal"
	)


func test_maturity_time_scales_with_level() -> void:
	assert_eq(
		Creature.maturity_time_for_level(1),
		Creature.MINIMUM_MATURITY_TIME,
		"a hatchling grows up in half a minute"
	)
	assert_eq(
		Creature.maturity_time_for_level(10),
		Creature.MAXIMUM_MATURITY_TIME,
		"a level 10 animal takes six minutes"
	)
	var previous := 0.0
	for level in range(1, 11):
		var span := Creature.maturity_time_for_level(level)
		assert_gt(span, previous, "every level takes longer to raise")
		previous = span


func test_creatures_grow_and_only_then_breed() -> void:
	var stage := _make_stage()
	var pen := _house_creature(stage, 1, 5150)
	var creature := pen.creature

	assert_false(creature.is_mature(), "a newborn is not ready to breed")
	assert_false(pen.is_ready_to_breed(), "its pen reports it as not ready")
	var newborn_scale := creature.scale.x
	assert_true(newborn_scale > 0.0, "a newborn is still visible")

	# Halfway through its childhood it must be bigger, but still not breedable.
	creature.age = creature.maturity_time * 0.5
	pen.refit()
	var teen_scale := creature.scale.x
	assert_gt(teen_scale, newborn_scale, "the animal grows while it matures")
	assert_false(creature.is_mature(), "half grown is not grown")

	creature.age = creature.maturity_time
	pen.refit()
	assert_gt(creature.scale.x, teen_scale, "it keeps growing to its adult size")
	assert_true(creature.is_mature(), "a fully aged animal is ready")
	assert_true(pen.is_ready_to_breed(), "its pen reports it as ready")
	assert_eq(
		creature.growth_factor(), 1.0, "an adult is drawn at its full pen size"
	)


func test_traits_survive_a_save_round_trip() -> void:
	for attempt in range(12):
		var habitat := ZooGame.habitat_from_index(attempt % 4)
		var original := CreatureRandomizer.generate(
			(attempt % 10) + 1, attempt + 7001, habitat
		)
		var restored := CreatureTraits.from_dict(
			JSON.parse_string(JSON.stringify(original.to_dict()))
		)

		assert_eq(restored.level, original.level, "level survives a save")
		assert_eq(restored.habitat, original.habitat, "habitat survives a save")
		assert_eq(restored.profile, original.profile, "profile survives a save")
		assert_eq(
			restored.display_name, original.display_name, "the name survives a save"
		)
		assert_eq(
			restored.joint_count, original.joint_count, "the spine survives a save"
		)
		assert_eq(
			restored.body_widths.size(),
			original.body_widths.size(),
			"body widths survive a save"
		)
		assert_true(
			restored.body_color.is_equal_approx(original.body_color),
			"colours survive a save"
		)
		assert_eq(restored.leg_pairs, original.leg_pairs, "legs survive a save")
		assert_eq(restored.horn_style, original.horn_style, "horns survive a save")
		assert_eq(restored.tail_tip, original.tail_tip, "the tail survives a save")
		assert_eq(
			restored.pectoral_fins, original.pectoral_fins, "fins survive a save"
		)


func test_restored_traits_still_build_a_creature() -> void:
	var stage := _make_stage()
	var original := CreatureRandomizer.generate(6, 3141, CreatureTraits.Habitat.ALIEN)
	var restored := CreatureTraits.from_dict(
		JSON.parse_string(JSON.stringify(original.to_dict()))
	)

	var pen := Enclosure.new()
	pen.habitat = CreatureTraits.Habitat.ALIEN
	pen.size = Vector2(540.0, 430.0)
	stage.add_child(pen)

	var creature := Creature.new()
	creature.traits = restored
	creature.randomize_on_ready = false
	creature.start_at_viewport_center = false
	pen.set_creature(creature)
	creature.age = creature.maturity_time

	assert_eq(
		creature.spine.joints.size(),
		restored.joint_count,
		"a restored animal rebuilds its spine"
	)
	assert_eq(
		creature.legs.size(), restored.leg_pairs * 2, "a restored animal rebuilds its legs"
	)
	var outline := creature._build_body_outline()
	assert_gt(outline.size(), 8, "a restored animal still draws")


func test_habitat_index_round_trip() -> void:
	var habitats: Array[CreatureTraits.Habitat] = [
		CreatureTraits.Habitat.WILD,
		CreatureTraits.Habitat.BASIC,
		CreatureTraits.Habitat.WATER,
		CreatureTraits.Habitat.ALIEN,
	]
	for habitat in habitats:
		assert_eq(
			ZooGame.habitat_from_index(int(habitat)),
			habitat,
			"a saved habitat index maps back to the same habitat"
		)


func test_every_habitat_has_a_track() -> void:
	var habitats: Array[CreatureTraits.Habitat] = [
		CreatureTraits.Habitat.BASIC,
		CreatureTraits.Habitat.WATER,
		CreatureTraits.Habitat.ALIEN,
	]
	var paths := {}
	for habitat in habitats:
		var path := MusicPlayer.track_path(habitat)
		assert_true(
			ResourceLoader.exists(path), "%s is missing from the project" % path
		)
		paths[path] = true
	assert_eq(paths.size(), 3, "each habitat gets its own track")


func test_music_crossfades_instead_of_cutting() -> void:
	var stage := _make_stage()
	var music := MusicPlayer.new()
	music.play_on_ready = false
	music.crossfade_time = 2.0
	stage.add_child(music)

	music.play_for_habitat(CreatureTraits.Habitat.BASIC)
	assert_eq(
		music.current_habitat, CreatureTraits.Habitat.BASIC, "the meadow track starts"
	)

	# Settle the opening fade, then swap habitats.
	for step in range(180):
		music._process(1.0 / 60.0)
	assert_false(music.is_crossfading(), "the opening fade finishes")

	music.play_for_habitat(CreatureTraits.Habitat.ALIEN)
	assert_eq(music.current_habitat, CreatureTraits.Habitat.ALIEN, "the void track takes over")
	assert_true(music.is_crossfading(), "swapping habitats starts a crossfade")

	# Halfway through the swap both voices must be audible: that is what makes
	# it a crossfade rather than a cut.
	for step in range(60):
		music._process(1.0 / 60.0)
	var audible := 0
	for child in music.get_children():
		if child is AudioStreamPlayer and (child as AudioStreamPlayer).volume_db > MusicPlayer.SILENT_DB:
			audible += 1
	assert_eq(audible, 2, "both tracks are heard during the swap")

	for step in range(180):
		music._process(1.0 / 60.0)
	assert_false(music.is_crossfading(), "the crossfade completes")


func test_repeating_a_habitat_does_not_restart_the_track() -> void:
	var stage := _make_stage()
	var music := MusicPlayer.new()
	music.play_on_ready = false
	stage.add_child(music)

	music.play_for_habitat(CreatureTraits.Habitat.WATER)
	for step in range(300):
		music._process(1.0 / 60.0)

	music.play_for_habitat(CreatureTraits.Habitat.WATER)
	assert_false(
		music.is_crossfading(),
		"building a second pen of the same habitat leaves the music alone"
	)


func test_track_levels_are_matched() -> void:
	# The three source recordings differ by ~10 LUFS, so each carries an offset.
	var meadow := MusicPlayer.track_gain_db(CreatureTraits.Habitat.BASIC)
	var reef := MusicPlayer.track_gain_db(CreatureTraits.Habitat.WATER)
	var void_gain := MusicPlayer.track_gain_db(CreatureTraits.Habitat.ALIEN)
	for gain in [meadow, reef, void_gain]:
		assert_true(gain <= 0.0 and gain > -24.0, "matching gains only attenuate")
	assert_true(meadow < reef, "the loudest recording is pulled down the most")


func test_eggs_get_dearer_with_every_purchase() -> void:
	var zoo := ZooGame.new()

	assert_eq(zoo.eggs_bought, 0, "a fresh zoo has bought no eggs")
	assert_eq(zoo.egg_cost(), ZooGame.EGG_BASE_COST, "the first egg is the base price")

	var previous := zoo.egg_cost()
	for purchase in range(1, 21):
		zoo.eggs_bought = purchase
		var cost := zoo.egg_cost()
		assert_gt(cost, previous, "egg %d costs more than the one before" % purchase)
		previous = cost

	# The ladder has to bite hard enough that breeding beats buying eggs, but
	# not so hard that the early game stalls.
	zoo.eggs_bought = 5
	assert_true(
		zoo.egg_cost() < ZooGame.EGG_BASE_COST * 3.0,
		"the sixth egg is still affordable early on"
	)
	zoo.eggs_bought = 20
	assert_gt(
		zoo.egg_cost(),
		ZooGame.EGG_BASE_COST * 10.0,
		"twenty eggs in, hatching is far dearer than breeding"
	)

	zoo.free()
