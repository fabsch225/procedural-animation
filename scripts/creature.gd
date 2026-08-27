class_name Creature
extends ChainBody


# An abstract animal. Everything it looks like comes from a CreatureTraits
# recipe, so one node can be a horned six-legged serpent one moment and a
# winged finned tadpole the next.


const PROCESSING_REFERENCE_FPS: float = 60.0
const LEG_JOINT_COUNT: int = 3
## A level 1 hatchling matures in half a minute; a level 10 animal takes six.
const MINIMUM_MATURITY_TIME: float = 30.0
const MAXIMUM_MATURITY_TIME: float = 360.0
## How small a newborn starts, as a fraction of its adult size.
const NEWBORN_SCALE: float = 0.38

signal creature_changed(new_traits: CreatureTraits)

enum ControlMode {
	## The head chases the mouse, like every other body in the sandbox scene.
	FOLLOW_MOUSE,
	## The creature wanders on its own inside `roam_bounds`, for the zoo.
	ROAM,
}

@export_group("Behaviour")
@export var control_mode: ControlMode = ControlMode.FOLLOW_MOUSE
## Local-space rectangle the roaming head stays inside.
@export var roam_bounds: Rect2 = Rect2(-200.0, -140.0, 400.0, 280.0)
@export_range(0.05, 1.0, 0.01) var roam_speed_scale: float = 0.35
@export_range(0.0, 12.0, 0.1) var roam_pause_time: float = 2.5
## Radians per second the roaming head may turn. Low values give long, lazy
## arcs; the body can only follow what the head does smoothly.
@export_range(0.2, 12.0, 0.1) var roam_turn_rate: float = 1.8

@export_group("Creature")
@export_range(1, 10, 1) var creature_level: int = 5
## Leave at 0 to roll a fresh seed every time.
@export var creature_seed: int = 0
@export var randomize_on_ready: bool = true

var traits: CreatureTraits
var legs: Array[Chain] = []
var leg_desired: Array[Vector2] = []
var _time: float = 0.0
## Seconds this animal has been alive, and how long it needs to grow up.
var age: float = 0.0
var maturity_time: float = MINIMUM_MATURITY_TIME
var _roam_target: Vector2 = Vector2.ZERO
var _roam_wait: float = 0.0
var _heading: float = 0.0
var _roam_rng := RandomNumberGenerator.new()


func _ready() -> void:
	if traits == null:
		traits = CreatureRandomizer.generate(
			creature_level, 0 if randomize_on_ready else 20260827
		)
	_apply_traits()
	super()
	_roam_rng.randomize()
	_heading = spine.angles[0]
	_pick_roam_target()
	creature_changed.emit(traits)


# Roaming creatures steer themselves; mouse-driven ones fall back to the
# shared ChainBody behaviour.
func _process(delta: float) -> void:
	age += delta
	if control_mode == ControlMode.FOLLOW_MOUSE:
		super(delta)
		return

	var head := spine.joints[0]
	_roam_wait -= delta

	# Retarget well before arriving. A head that reaches its goal and then jumps
	# to a new bearing turns through a large angle in one frame, and because
	# Chain.resolve rebuilds every joint from the head that snaps the whole body
	# into a new pose at once.
	var arrive_distance := maxf(48.0, link_size * 2.0)
	if _roam_wait <= 0.0 or head.distance_to(_roam_target) <= arrive_distance:
		_pick_roam_target()
	if not roam_bounds.has_point(head):
		_roam_target = roam_bounds.get_center()

	# Steer instead of teleporting the heading: the direction changes by at most
	# roam_turn_rate * delta per frame, so the spine follows the head around a
	# curve the way it does when it is chasing a moving mouse.
	var desired := (_roam_target - head).angle()
	var turn := Util.relative_angle_diff(_heading, desired)
	var maximum_turn := roam_turn_rate * delta
	_heading = Util.simplify_angle(_heading + clampf(turn, -maximum_turn, maximum_turn))

	# Animals ease off in a tight turn and open up again on the straight.
	var turn_factor := clampf(absf(turn) / PI, 0.0, 1.0)
	var speed := movement_speed * roam_speed_scale * lerpf(1.0, 0.55, turn_factor)
	var target := head + Vector2.from_angle(_heading) * speed * delta

	if anchored:
		spine.fabrik_resolve(target, anchor_position)
	else:
		spine.resolve(target)
	_after_spine_resolved(delta)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if control_mode == ControlMode.ROAM:
		return
	super(event)


# --- Growing up -------------------------------------------------------------


static func maturity_time_for_level(level: int) -> float:
	return lerpf(
		MINIMUM_MATURITY_TIME,
		MAXIMUM_MATURITY_TIME,
		float(clampi(level, 1, 10) - 1) / 9.0
	)


func maturity_ratio() -> float:
	return clampf(age / maxf(maturity_time, 0.001), 0.0, 1.0)


func is_mature() -> bool:
	return maturity_ratio() >= 1.0


func seconds_until_mature() -> float:
	return maxf(0.0, maturity_time - age)


# Newborns grow quickly at first and then ease into their adult size.
func growth_factor() -> float:
	return lerpf(NEWBORN_SCALE, 1.0, pow(maturity_ratio(), 0.6))


# Picks a goal that is far away and roughly ahead, so the creature never has to
# double back on itself to reach it.
func _pick_roam_target() -> void:
	var head := Vector2.ZERO
	if spine != null and not spine.joints.is_empty():
		head = spine.joints[0]

	var best := roam_bounds.get_center()
	var best_score := -INF

	for attempt in range(6):
		var candidate := Vector2(
			_roam_rng.randf_range(roam_bounds.position.x, roam_bounds.end.x),
			_roam_rng.randf_range(roam_bounds.position.y, roam_bounds.end.y)
		)
		var offset := candidate - head
		if offset.is_zero_approx():
			continue
		var turn := absf(Util.relative_angle_diff(_heading, offset.angle()))
		var score := offset.length() * (1.0 - 0.65 * turn / PI)
		if score > best_score:
			best_score = score
			best = candidate

	_roam_target = best
	_roam_wait = _roam_rng.randf_range(roam_pause_time, roam_pause_time * 3.0)


# Rolls a brand new animal without losing the current head position.
func reroll(level: int = -1, new_seed: int = 0) -> void:
	if level > 0:
		creature_level = clampi(level, 1, 10)
	traits = CreatureRandomizer.generate(creature_level, new_seed)
	_apply_traits()
	_rebuild_spine()
	creature_changed.emit(traits)


func apply_creature_traits(new_traits: CreatureTraits) -> void:
	if new_traits == null:
		return
	traits = new_traits
	creature_level = traits.level
	_apply_traits()
	_rebuild_spine()
	creature_changed.emit(traits)


func _apply_traits() -> void:
	body_name = traits.display_name
	joint_count = traits.joint_count
	link_size = traits.link_size
	angle_constraint = traits.angle_constraint
	movement_speed = traits.movement_speed
	body_color = traits.body_color
	outline_color = traits.outline_color
	eye_radius = traits.eye_radius
	maturity_time = maturity_time_for_level(traits.level)


func _rebuild_spine() -> void:
	var origin := Vector2.ZERO
	var heading := 0.0
	if spine != null and not spine.joints.is_empty():
		origin = spine.joints[0]
		heading = spine.angles[0]
	elif is_inside_tree():
		origin = to_local(
			get_viewport().get_canvas_transform().affine_inverse()
			* get_viewport_rect().get_center()
		)

	spine = Chain.new(origin, joint_count, link_size, angle_constraint)
	spine.set_curved_pose(
		origin, heading, clampf(initial_joint_bend, -angle_constraint, angle_constraint)
	)
	anchor_position = spine.joints.back()
	_heading = spine.angles[0]
	_on_spine_created()
	queue_redraw()


func _minimum_joint_count() -> int:
	return 8


func _body_radius(index: int) -> float:
	return traits.body_radius(index)


# --- Legs -------------------------------------------------------------------


func _on_spine_created() -> void:
	legs.clear()
	leg_desired.clear()
	for i in range(traits.leg_pairs * 2):
		var leg := Chain.new(spine.joints[0], LEG_JOINT_COUNT, traits.leg_link_size)
		var desired := _leg_desired_position(i)
		var shoulder := _leg_shoulder_position(i)
		leg.set_curved_pose(desired, (desired - shoulder).angle())
		for _iteration in range(4):
			leg.fabrik_resolve(desired, shoulder)
		legs.append(leg)
		leg_desired.append(desired)


func _after_spine_resolved(delta: float) -> void:
	_time += delta

	var step_weight := 1.0 - pow(
		1.0 - clampf(traits.step_speed, 0.0, 1.0),
		maxf(delta, 0.0) * PROCESSING_REFERENCE_FPS
	)
	for i in range(legs.size()):
		var desired := _leg_desired_position(i)
		if desired.distance_to(leg_desired[i]) > traits.step_distance:
			leg_desired[i] = desired
		var moving_foot := legs[i].joints[0].lerp(leg_desired[i], step_weight)
		legs[i].fabrik_resolve(moving_foot, _leg_shoulder_position(i))


func _leg_body_index(index: int) -> int:
	var joints := spine.joints.size()
	var pair := index / 2
	var pairs := maxi(1, traits.leg_pairs)
	var u := 0.2 if pairs == 1 else lerpf(0.16, 0.58, float(pair) / float(pairs - 1))
	return clampi(int(round(u * float(joints - 1))), 1, joints - 2)


func _leg_side(index: int) -> float:
	return 1.0 if index % 2 == 0 else -1.0


func _leg_desired_position(index: int) -> Vector2:
	var body_index := _leg_body_index(index)
	var reach_angle := PI / 4.0 if index / 2 == 0 else PI / 3.0
	return _body_position(body_index, reach_angle * _leg_side(index), traits.foot_reach)


func _leg_shoulder_position(index: int) -> Vector2:
	return _body_position(
		_leg_body_index(index), PI / 2.0 * _leg_side(index), -traits.shoulder_inset
	)


func _draw_additional_debug_chains() -> void:
	for leg in legs:
		leg.draw(self)


# --- Drawing ----------------------------------------------------------------


func _draw_chain_body() -> void:
	_draw_wings()
	_draw_legs()
	_draw_tail_tip()
	_draw_fins()
	_draw_side_spines()
	_draw_frill()
	_draw_horns()
	_draw_ears()
	_draw_antennae()

	_fill_shape(_build_body_outline(), body_color)

	_draw_ridge_fin()
	_draw_plates()
	_draw_stripes()
	_draw_whiskers()
	_draw_face()


func _build_body_outline() -> PackedVector2Array:
	var count := spine.joints.size()
	var shape := _new_processing_shape()
	shape.begin_shape()
	for i in range(count):
		shape.curve_vertex(_body_position(i, PI / 2.0))
	shape.curve_vertex(_body_position(count - 1, PI))
	for i in range(count - 1, -1, -1):
		shape.curve_vertex(_body_position(i, -PI / 2.0))
	shape.curve_vertex(_body_position(0, -PI / 6.0))
	shape.curve_vertex(_body_position(0, 0.0, 4.0))
	shape.curve_vertex(_body_position(0, PI / 6.0))
	for i in range(mini(3, count)):
		shape.curve_vertex(_body_position(i, PI / 2.0))
	return shape.end_shape(true)


# Fills a closed path, preferring the native non-zero tessellator and falling
# back to Godot's polygon triangulation when the GDExtension is not built.
func _fill_shape(
	path: PackedVector2Array,
	fill_color: Color,
	stroke_width: float = -1.0
) -> void:
	if path.size() < 3:
		return

	var triangles := PackedVector2Array()
	var native := _get_native_tessellator()
	if native != null:
		var result: Variant = native.call(&"tessellate", path)
		if result is PackedVector2Array:
			triangles = result as PackedVector2Array

	if triangles.is_empty():
		draw_colored_polygon(path, fill_color)
	else:
		var indices := PackedInt32Array()
		indices.resize(triangles.size())
		for i in range(indices.size()):
			indices[i] = i
		var colors := PackedColorArray()
		colors.resize(triangles.size())
		colors.fill(fill_color)
		RenderingServer.canvas_item_add_triangle_array(
			get_canvas_item(), indices, triangles, colors
		)

	var width := outline_width if stroke_width < 0.0 else stroke_width
	if width > 0.0:
		var closed := path.duplicate()
		if not closed[closed.size() - 1].is_equal_approx(closed[0]):
			closed.append(closed[0])
		draw_polyline(closed, outline_color, width, true)


func _draw_ellipse(center: Vector2, size: Vector2, rotation_: float, color: Color) -> void:
	var points := PackedVector2Array()
	var half_size := size * 0.5
	for step in range(40):
		var angle := TAU * float(step) / 40.0
		var local_point := Vector2(cos(angle) * half_size.x, sin(angle) * half_size.y)
		points.append(center + local_point.rotated(rotation_))
	draw_colored_polygon(points, color)
	if outline_width > 0.0:
		points.append(points[0])
		draw_polyline(points, outline_color, outline_width, true)


# Walks an imaginary pen forward from `base`, turning by `curve` over its
# whole length. Used for horns, ears, spines, antennae and whiskers.
func _axis(
	base: Vector2,
	direction: float,
	length: float,
	curve: float,
	segments: int = 10
) -> Axis:
	var axis := Axis.new()
	var position := base
	var angle := direction
	var step := length / float(maxi(1, segments))
	for i in range(segments + 1):
		axis.positions.append(position)
		axis.angles.append(angle)
		position += Vector2.from_angle(angle) * step
		angle += curve / float(maxi(1, segments))
	return axis


func _build_taper(axis: Axis, width: float, tip_ratio: float = 0.0) -> PackedVector2Array:
	var count := axis.positions.size()
	if count < 2:
		return PackedVector2Array()

	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in range(count):
		var t := float(i) / float(count - 1)
		var half_width := lerpf(width, width * tip_ratio, pow(t, 0.85))
		var normal := Vector2.from_angle(axis.angles[i] + PI / 2.0) * half_width
		left.append(axis.positions[i] + normal)
		right.append(axis.positions[i] - normal)

	var path := left.duplicate()
	for i in range(right.size() - 1, -1, -1):
		path.append(right[i])
	return path


func _draw_horns() -> void:
	if traits.horn_style == CreatureTraits.HornStyle.NONE:
		return

	for pair in range(traits.horn_pairs):
		var joint_index := mini(pair, spine.joints.size() - 1)
		var lane := 0.0 if traits.horn_pairs == 1 else float(pair) / float(traits.horn_pairs - 1)
		var length := traits.horn_length * lerpf(1.0, 0.62, lane)
		var width := traits.horn_width * lerpf(1.0, 0.7, lane)
		for side_index in range(2):
			var side := 1.0 if side_index == 0 else -1.0
			var base := _body_position(
				joint_index, side * traits.horn_spread, -_body_radius(joint_index) * 0.3
			)
			var direction := spine.angles[joint_index] + side * traits.horn_spread
			match traits.horn_style:
				CreatureTraits.HornStyle.SPIKE:
					_draw_horn(base, direction, length, width, side * 0.15)
				CreatureTraits.HornStyle.CURVED:
					_draw_horn(base, direction, length, width, side * traits.horn_curve)
				CreatureTraits.HornStyle.ANTLER:
					_draw_antler(base, direction, length, width, side)
				CreatureTraits.HornStyle.CROWN:
					_draw_crown(joint_index, side, length, width)


func _draw_horn(
	base: Vector2,
	direction: float,
	length: float,
	width: float,
	curve: float
) -> void:
	var axis := _axis(base, direction, length, curve, 12)
	_fill_shape(_build_taper(axis, width, 0.06), traits.accent_color)


func _draw_antler(
	base: Vector2,
	direction: float,
	length: float,
	width: float,
	side: float
) -> void:
	var axis := _axis(base, direction, length, side * traits.horn_curve, 12)
	_fill_shape(_build_taper(axis, width, 0.08), traits.accent_color)

	var branch_positions: Array[float] = [0.38, 0.66]
	for branch in range(branch_positions.size()):
		var index := clampi(
			int(round(branch_positions[branch] * float(axis.positions.size() - 1))),
			0,
			axis.positions.size() - 1
		)
		var branch_axis := _axis(
			axis.positions[index],
			axis.angles[index] - side * (0.7 - 0.2 * float(branch)),
			length * (0.5 - 0.12 * float(branch)),
			side * 0.5,
			8
		)
		_fill_shape(
			_build_taper(branch_axis, width * (0.62 - 0.14 * float(branch)), 0.05),
			traits.accent_color
		)


func _draw_crown(joint_index: int, side: float, length: float, width: float) -> void:
	var spike_count := 3
	for i in range(spike_count):
		var spread := lerpf(0.15, 1.15, float(i) / float(spike_count - 1))
		var base := _body_position(
			joint_index, side * spread, -_body_radius(joint_index) * 0.25
		)
		var axis := _axis(
			base,
			spine.angles[joint_index] + side * spread,
			length * lerpf(1.0, 0.6, float(i) / float(spike_count - 1)),
			side * 0.12,
			8
		)
		_fill_shape(_build_taper(axis, width * 0.7, 0.05), traits.accent_color)


func _draw_ears() -> void:
	if traits.ear_style == CreatureTraits.EarStyle.NONE:
		return

	var joint_index := mini(1, spine.joints.size() - 1)
	for side_index in range(2):
		var side := 1.0 if side_index == 0 else -1.0
		var base := _body_position(joint_index, side * 1.15, -_body_radius(joint_index) * 0.25)
		var direction := spine.angles[joint_index] + side * 1.25
		var curve := 0.0
		var tip_ratio := 0.05
		var width := traits.ear_size * 0.42

		match traits.ear_style:
			CreatureTraits.EarStyle.ROUND:
				tip_ratio = 0.85
				width = traits.ear_size * 0.5
			CreatureTraits.EarStyle.POINTED:
				tip_ratio = 0.04
			CreatureTraits.EarStyle.FLOPPY:
				curve = side * 1.5
				tip_ratio = 0.25

		var axis := _axis(base, direction, traits.ear_size, curve, 10)
		_fill_shape(_build_taper(axis, width, tip_ratio), body_color)
		var inner := _axis(base, direction, traits.ear_size * 0.72, curve, 10)
		_fill_shape(_build_taper(inner, width * 0.5, tip_ratio), traits.accent_color, 0.0)


func _draw_antennae() -> void:
	if traits.antenna_pairs <= 0:
		return

	for pair in range(traits.antenna_pairs):
		var joint_index := mini(pair, spine.joints.size() - 1)
		var length := traits.antenna_length * lerpf(1.0, 0.7, float(pair) * 0.5)
		for side_index in range(2):
			var side := 1.0 if side_index == 0 else -1.0
			var base := _body_position(joint_index, side * 0.45, -_body_radius(joint_index) * 0.2)
			var sway := sin(_time * 1.8 + float(pair) + side) * 0.18
			var axis := _axis(
				base,
				spine.angles[joint_index] + side * 0.55,
				length,
				side * (0.9 + sway),
				12
			)
			_fill_shape(_build_taper(axis, traits.antenna_bulb * 0.35, 0.35), traits.accent_color, 0.0)
			var tip := axis.positions[axis.positions.size() - 1]
			draw_circle(tip, traits.antenna_bulb, traits.accent_color)
			if outline_width > 0.0:
				draw_arc(tip, traits.antenna_bulb, 0.0, TAU, 24, outline_color, outline_width * 0.6, true)


func _draw_frill() -> void:
	if not traits.has_frill:
		return

	var joint_index := mini(1, spine.joints.size() - 1)
	var center := spine.joints[joint_index]
	var radius := _body_radius(joint_index) * traits.frill_size
	var base_angle := spine.angles[joint_index]
	var points := PackedVector2Array()
	var steps := maxi(24, traits.frill_points * 4)

	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var angle := base_angle + lerpf(PI * 0.42, PI * 1.58, t)
		var wobble := 1.0 + 0.16 * cos(t * TAU * float(traits.frill_points))
		points.append(center + Vector2.from_angle(angle) * radius * wobble)

	points.append(center)
	_fill_shape(points, traits.accent_color)


func _draw_side_spines() -> void:
	if traits.spike_style != CreatureTraits.SpikeStyle.SIDE_SPINES:
		return

	var count := spine.joints.size()
	var index := 1
	while index < count - 1:
		var falloff := 1.0 - 0.55 * float(index) / float(count)
		var length := traits.spike_size * falloff
		if length > 3.0:
			for side_index in range(2):
				var side := 1.0 if side_index == 0 else -1.0
				var base := _body_position(index, side * PI / 2.0, -3.0)
				var axis := _axis(
					base,
					spine.angles[index] + side * (PI / 2.0 + 0.6),
					length,
					side * 0.25,
					6
				)
				_fill_shape(_build_taper(axis, length * 0.3, 0.04), traits.accent_color)
		index += maxi(1, traits.spike_spacing)


func _draw_ridge_fin() -> void:
	if traits.spike_style != CreatureTraits.SpikeStyle.RIDGE_FIN:
		return

	var count := spine.joints.size()
	if count < 8:
		return

	var start := clampi(int(round(float(count) * 0.22)), 1, count - 5)
	var finish := clampi(start + maxi(3, int(round(float(count) * 0.3))), start + 3, count - 1)
	var middle := (start + finish) / 2
	var bend_1 := Util.relative_angle_diff(spine.angles[0], spine.angles[middle])
	var bend_2 := Util.relative_angle_diff(spine.angles[0], spine.angles[finish])
	var flare := 16.0 * traits.fin_scale
	var lift := traits.spike_size * 0.5

	var shape := _new_processing_shape()
	shape.begin_shape()
	shape.vertex(spine.joints[start])
	shape.bezier_vertex(
		spine.joints[start + 1], spine.joints[middle], spine.joints[finish]
	)
	shape.bezier_vertex(
		spine.joints[middle]
		+ Vector2.from_angle(spine.angles[middle] + PI / 2.0) * (bend_2 * flare + lift),
		spine.joints[start + 1]
		+ Vector2.from_angle(spine.angles[start + 1] + PI / 2.0) * (bend_1 * flare + lift),
		spine.joints[start]
	)
	_fill_shape(shape.end_shape(), traits.fin_color)


func _draw_plates() -> void:
	if traits.spike_style != CreatureTraits.SpikeStyle.PLATES:
		return

	var count := spine.joints.size()
	var index := 1
	while index < count - 1:
		var radius := _body_radius(index)
		if radius > 6.0:
			_draw_ellipse(
				spine.joints[index],
				Vector2(radius * 1.15, radius * 0.6),
				spine.angles[index],
				traits.accent_color
			)
		index += maxi(1, traits.spike_spacing + 1)


func _draw_stripes() -> void:
	if traits.stripe_count <= 0 or outline_width <= 0.0:
		return

	var count := spine.joints.size()
	for stripe in range(traits.stripe_count):
		var weight := float(stripe + 1) / float(traits.stripe_count + 1)
		var index := clampi(int(round(weight * float(count - 1))), 1, count - 2)
		if _body_radius(index) < 8.0:
			continue
		draw_line(
			_body_position(index, PI / 2.0, -3.0),
			_body_position(index, -PI / 2.0, -3.0),
			traits.accent_color,
			traits.stripe_width,
			true
		)


func _draw_fins() -> void:
	var count := spine.joints.size()

	if traits.pectoral_fins:
		var index := clampi(int(round(float(count) * 0.24)), 1, count - 2)
		var size := Vector2(150.0, 60.0) * traits.fin_scale
		var reference := spine.angles[maxi(index - 1, 0)]
		_draw_ellipse(_body_position(index, PI / 3.0), size, reference - PI / 4.0, traits.fin_color)
		_draw_ellipse(_body_position(index, -PI / 3.0), size, reference + PI / 4.0, traits.fin_color)

	if traits.pelvic_fins:
		var index := clampi(int(round(float(count) * 0.58)), 1, count - 2)
		var size := Vector2(92.0, 30.0) * traits.fin_scale
		var reference := spine.angles[maxi(index - 1, 0)]
		_draw_ellipse(_body_position(index, PI / 2.0), size, reference - PI / 4.0, traits.fin_color)
		_draw_ellipse(_body_position(index, -PI / 2.0), size, reference + PI / 4.0, traits.fin_color)


func _draw_wings() -> void:
	if traits.wing_pairs <= 0:
		return

	var count := spine.joints.size()
	var membrane := traits.fin_color
	membrane.a = 0.92

	for pair in range(traits.wing_pairs):
		var weight := 0.24 if traits.wing_pairs == 1 else lerpf(0.2, 0.46, float(pair))
		var index := clampi(int(round(weight * float(count - 1))), 1, count - 2)
		var flap := 0.72 + 0.28 * sin(_time * traits.wing_flap_speed + float(pair) * 1.3)
		var span := traits.wing_span * flap

		for side_index in range(2):
			var side := 1.0 if side_index == 0 else -1.0
			var root := _body_position(index, side * PI / 2.0, -6.0)
			var base_angle := spine.angles[index] + side * (PI / 2.0 - 0.25)
			var path := PackedVector2Array([root])
			var tips: Array[Vector2] = []

			for finger in range(traits.wing_fingers + 1):
				var t := float(finger) / float(traits.wing_fingers)
				var angle := base_angle + side * lerpf(-0.5, 1.25, t)
				var reach := span * lerpf(1.0, 0.52, pow(t, 1.3))
				var tip := root + Vector2.from_angle(angle) * reach
				tips.append(tip)
				path.append(tip)

			path.append(root + Vector2.from_angle(base_angle + side * 1.5) * span * 0.22)
			_fill_shape(path, membrane)

			for tip in tips:
				draw_line(root, tip, traits.accent_color, 5.0, true)


func _draw_legs() -> void:
	for i in range(legs.size()):
		var leg := legs[i]
		var shoulder := leg.joints[2]
		var elbow := leg.joints[1]
		var foot := leg.joints[0]

		# Bend the elbow away from the body so opposing legs do not overlap.
		var shoulder_to_foot := foot - shoulder
		var perpendicular := Vector2(-shoulder_to_foot.y, shoulder_to_foot.x)
		if not perpendicular.is_zero_approx():
			perpendicular = perpendicular.normalized() * (traits.leg_link_size * 0.35)
		elbow += perpendicular * _leg_side(i)

		var curve := PackedVector2Array()
		for step in range(13):
			var t := float(step) / 12.0
			curve.append(shoulder.lerp(elbow, t).lerp(elbow.lerp(foot, t), t))

		if traits.leg_outline_width > 0.0:
			draw_circle(foot, traits.leg_outline_width * 0.5, outline_color)
			draw_polyline(curve, outline_color, traits.leg_outline_width, true)
		draw_circle(foot, traits.leg_width * 0.5, body_color)
		draw_polyline(curve, body_color, traits.leg_width, true)

		_draw_toes(foot, (foot - elbow).angle())


func _draw_toes(foot: Vector2, direction: float) -> void:
	if traits.toe_count <= 0:
		return

	for toe in range(traits.toe_count):
		var spread := 0.0
		if traits.toe_count > 1:
			spread = lerpf(-0.55, 0.55, float(toe) / float(traits.toe_count - 1))
		var axis := _axis(foot, direction + spread, traits.toe_length, spread * 0.4, 4)
		_fill_shape(_build_taper(axis, traits.leg_width * 0.22, 0.15), body_color)


func _draw_tail_tip() -> void:
	var count := spine.joints.size()
	var tail := spine.joints[count - 1]
	var tail_angle := spine.angles[count - 1]
	var backward := tail_angle + PI

	match traits.tail_tip:
		CreatureTraits.TailTip.NONE:
			return
		CreatureTraits.TailTip.CAUDAL_FIN:
			_draw_caudal_fin()
		CreatureTraits.TailTip.SPADE:
			_draw_ellipse(
				tail + Vector2.from_angle(backward) * traits.tail_size * 0.45,
				Vector2(traits.tail_size * 1.5, traits.tail_size),
				tail_angle,
				traits.fin_color
			)
		CreatureTraits.TailTip.CLUB:
			var center := tail + Vector2.from_angle(backward) * traits.tail_size * 0.35
			for spike in range(6):
				var angle := TAU * float(spike) / 6.0
				var axis := _axis(center, angle, traits.tail_size * 0.75, 0.0, 4)
				_fill_shape(_build_taper(axis, traits.tail_size * 0.16, 0.05), traits.accent_color)
			draw_circle(center, traits.tail_size * 0.5, traits.accent_color)
			if outline_width > 0.0:
				draw_arc(
					center, traits.tail_size * 0.5, 0.0, TAU, 32,
					outline_color, outline_width, true
				)
		CreatureTraits.TailTip.PLUME:
			for strand in range(3):
				var offset := lerpf(-0.5, 0.5, float(strand) / 2.0)
				var sway := sin(_time * 2.4 + float(strand)) * 0.25
				var axis := _axis(
					tail, backward + offset, traits.tail_size * 2.0, offset + sway, 10
				)
				_fill_shape(
					_build_taper(axis, traits.tail_size * 0.3, 0.05), traits.fin_color
				)
		CreatureTraits.TailTip.STINGER:
			var axis := _axis(tail, backward, traits.tail_size * 2.2, 0.55, 10)
			_fill_shape(_build_taper(axis, traits.tail_size * 0.32, 0.02), traits.accent_color)


func _draw_caudal_fin() -> void:
	var count := spine.joints.size()
	var start := maxi(1, count - 5)
	var head_to_tail := Util.relative_angle_diff(spine.angles[0], spine.angles[count - 1])
	var shape := _new_processing_shape()
	shape.begin_shape()

	for i in range(start, count):
		var distance := float(i - start)
		var width := (
			0.9 * head_to_tail * distance * distance
			+ traits.tail_size * 0.16 * distance
		)
		shape.curve_vertex(
			spine.joints[i] + Vector2.from_angle(spine.angles[i] - PI / 2.0) * width
		)

	for i in range(count - 1, start - 1, -1):
		var distance := float(i - start)
		var width := (
			clampf(head_to_tail * 6.0, -14.0, 14.0)
			- traits.tail_size * 0.16 * distance
		)
		shape.curve_vertex(
			spine.joints[i] + Vector2.from_angle(spine.angles[i] + PI / 2.0) * width
		)

	_fill_shape(shape.end_shape(true), traits.fin_color)


func _draw_whiskers() -> void:
	if traits.whisker_count <= 0:
		return

	for whisker in range(traits.whisker_count):
		var lane := 0.0
		if traits.whisker_count > 1:
			lane = float(whisker) / float(traits.whisker_count - 1)
		for side_index in range(2):
			var side := 1.0 if side_index == 0 else -1.0
			var base := _body_position(0, side * lerpf(0.35, 0.95, lane), -4.0)
			var sway := sin(_time * 3.0 + float(whisker) * 0.8 + side) * 0.22
			var axis := _axis(
				base,
				spine.angles[0] + side * lerpf(0.5, 1.05, lane),
				traits.whisker_length * lerpf(1.0, 0.75, lane),
				side * (0.8 + sway),
				10
			)
			draw_polyline(axis.positions, traits.accent_color, 4.0, true)


func _draw_face() -> void:
	for pair in range(traits.eye_pair_count):
		var joint_index := mini(pair, spine.joints.size() - 1)
		var angle := traits.eye_angle - 0.14 * float(pair)
		var radius := eye_radius * (1.0 - 0.18 * float(pair))
		var inset := -_body_radius(joint_index) * 0.2
		for side_index in range(2):
			var side := 1.0 if side_index == 0 else -1.0
			var center := _body_position(joint_index, side * angle, inset)
			draw_circle(center, radius, traits.eye_color)
			if traits.has_pupils:
				var look := Vector2.from_angle(spine.angles[0]) * radius * 0.34
				draw_circle(center + look, radius * 0.46, traits.pupil_color)

	if traits.has_nostrils:
		var nostril_radius := maxf(2.0, eye_radius * 0.22)
		draw_circle(_body_position(0, PI / 9.0, -2.0), nostril_radius, traits.pupil_color)
		draw_circle(_body_position(0, -PI / 9.0, -2.0), nostril_radius, traits.pupil_color)


class Axis:
	var positions := PackedVector2Array()
	var angles := PackedFloat32Array()
