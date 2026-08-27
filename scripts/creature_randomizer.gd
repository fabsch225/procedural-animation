class_name CreatureRandomizer
extends RefCounted


# Builds a complete CreatureTraits recipe. `level` runs from 1 to 10: low
# levels give small, plain animals, high levels give large, loud ones with
# many stacked features.


const MIN_LEVEL: int = 1
const MAX_LEVEL: int = 10

const NAME_PREFIXES: Array[String] = [
	"dust", "moss", "ember", "tide", "glass", "thorn", "amber", "storm",
	"cinder", "willow", "murk", "quartz", "bramble", "opal", "sable",
	"lumen", "grim", "nectar", "cobalt", "fen",
]

const NAME_SUFFIXES: Array[String] = [
	"ling", "wyrm", "kin", "mander", "drake", "fin", "creep", "hopper",
	"gnaw", "prowl", "skitter", "warden", "howl", "bloom", "snapper",
]

const TIER_ADJECTIVES: Array[String] = [
	"tiny", "little", "scruffy", "sprightly", "bold",
	"grand", "regal", "resplendent", "mythic", "impossible",
]


static func generate(
		level: int,
		creature_seed: int = 0,
		habitat: CreatureTraits.Habitat = CreatureTraits.Habitat.WILD
) -> CreatureTraits:
	var clamped_level := clampi(level, MIN_LEVEL, MAX_LEVEL)
	var used_seed := creature_seed
	while used_seed == 0:
		used_seed = randi()

	var rng := RandomNumberGenerator.new()
	rng.seed = used_seed

	var t := float(clamped_level - MIN_LEVEL) / float(MAX_LEVEL - MIN_LEVEL)
	var traits := CreatureTraits.new()
	traits.level = clamped_level
	traits.creature_seed = used_seed
	traits.profile = _pick_profile(rng, t)

	_apply_spine(traits, rng, t)
	_apply_palette(traits, rng, t)
	_apply_head(traits, rng, t)
	_apply_spine_decoration(traits, rng, t)
	_apply_limbs(traits, rng, t)
	_apply_tail(traits, rng, t)
	apply_habitat(traits, habitat, rng)
	traits.display_name = _build_name(traits, rng)
	return traits


static func _pick_profile(rng: RandomNumberGenerator, t: float) -> CreatureTraits.BodyProfile:
	var weights := {
		CreatureTraits.BodyProfile.SERPENT: 1.0,
		CreatureTraits.BodyProfile.FUSIFORM: 1.0,
		CreatureTraits.BodyProfile.BULKY: 0.9 + 0.5 * t,
		CreatureTraits.BodyProfile.TADPOLE: 0.7,
		CreatureTraits.BodyProfile.SEGMENTED: 0.6 + 0.4 * t,
	}
	var total := 0.0
	for key in weights:
		total += weights[key]
	var roll := rng.randf() * total
	for key in weights:
		roll -= weights[key]
		if roll <= 0.0:
			return key as CreatureTraits.BodyProfile
	return CreatureTraits.BodyProfile.SERPENT


static func _apply_spine(traits: CreatureTraits, rng: RandomNumberGenerator, t: float) -> void:
	var scale := lerpf(0.62, 1.5, t)
	var peak_width := lerpf(34.0, 96.0, t) * rng.randf_range(0.88, 1.12)

	match traits.profile:
		CreatureTraits.BodyProfile.SERPENT:
			traits.joint_count = int(round(lerpf(18.0, 44.0, t))) + rng.randi_range(-2, 4)
			traits.link_size = lerpf(28.0, 44.0, t)
			traits.angle_constraint = PI / rng.randf_range(7.0, 12.0)
			peak_width *= 0.72
		CreatureTraits.BodyProfile.FUSIFORM:
			traits.joint_count = int(round(lerpf(11.0, 20.0, t))) + rng.randi_range(-1, 2)
			traits.link_size = lerpf(44.0, 74.0, t)
			traits.angle_constraint = PI / rng.randf_range(5.0, 8.0)
		CreatureTraits.BodyProfile.BULKY:
			traits.joint_count = int(round(lerpf(12.0, 22.0, t))) + rng.randi_range(-1, 2)
			traits.link_size = lerpf(46.0, 78.0, t)
			traits.angle_constraint = PI / rng.randf_range(6.0, 10.0)
		CreatureTraits.BodyProfile.TADPOLE:
			traits.joint_count = int(round(lerpf(11.0, 19.0, t))) + rng.randi_range(-1, 2)
			traits.link_size = lerpf(40.0, 66.0, t)
			traits.angle_constraint = PI / rng.randf_range(5.0, 9.0)
			peak_width *= 1.15
		CreatureTraits.BodyProfile.SEGMENTED:
			traits.joint_count = int(round(lerpf(16.0, 34.0, t))) + rng.randi_range(-2, 3)
			traits.link_size = lerpf(34.0, 54.0, t)
			traits.angle_constraint = PI / rng.randf_range(7.0, 11.0)
			peak_width *= 0.86

	traits.joint_count = clampi(traits.joint_count, 10, 64)
	traits.link_size *= lerpf(0.9, 1.1, rng.randf())
	traits.movement_speed = lerpf(760.0, 480.0, t) * rng.randf_range(0.85, 1.15)
	traits.body_widths = _build_body_widths(traits, rng, peak_width)
	traits.eye_radius = clampf(peak_width * 0.22, 7.0, 26.0) * lerpf(0.9, 1.15, rng.randf())
	traits.fin_scale = scale
	traits.tail_size = peak_width * rng.randf_range(0.8, 1.5)


static func _build_body_widths(
	traits: CreatureTraits,
	rng: RandomNumberGenerator,
	peak_width: float
) -> Array[float]:
	var widths: Array[float] = []
	var count := traits.joint_count
	var segment_waves := float(rng.randi_range(4, 9))

	for i in range(count):
		var u := float(i) / float(maxi(1, count - 1))
		var shape := 1.0

		match traits.profile:
			CreatureTraits.BodyProfile.SERPENT:
				shape = lerpf(0.86, 1.0, minf(u / 0.08, 1.0)) if u < 0.08 else 1.0 - 0.88 * pow((u - 0.08) / 0.92, 1.35)
			CreatureTraits.BodyProfile.FUSIFORM:
				if u < 0.22:
					shape = lerpf(0.8, 1.0, smoothstep(0.0, 0.22, u))
				else:
					shape = lerpf(1.0, 0.2, pow((u - 0.22) / 0.78, 1.25))
			CreatureTraits.BodyProfile.BULKY:
				if u < 0.14:
					shape = lerpf(0.78, 0.56, smoothstep(0.0, 0.14, u))
				elif u < 0.42:
					shape = lerpf(0.56, 1.0, smoothstep(0.14, 0.42, u))
				else:
					shape = lerpf(1.0, 0.09, pow((u - 0.42) / 0.58, 1.15))
			CreatureTraits.BodyProfile.TADPOLE:
				shape = maxf(0.08, pow(1.0 - u, 2.1))
				if u < 0.1:
					shape = lerpf(0.9, 1.0, smoothstep(0.0, 0.1, u))
			CreatureTraits.BodyProfile.SEGMENTED:
				var base := 1.0 - 0.7 * pow(u, 1.3)
				shape = base * (0.86 + 0.16 * cos(u * PI * segment_waves))

		var width := peak_width * shape * rng.randf_range(0.95, 1.05)
		widths.append(maxf(5.0, width))

	return widths


static func _apply_palette(traits: CreatureTraits, rng: RandomNumberGenerator, t: float) -> void:
	var hue := rng.randf()
	var saturation := clampf(lerpf(0.32, 0.72, t) * rng.randf_range(0.8, 1.2), 0.1, 0.95)
	var value := clampf(lerpf(0.52, 0.9, t) * rng.randf_range(0.9, 1.1), 0.25, 1.0)

	traits.body_color = Color.from_hsv(hue, saturation, value)
	traits.accent_color = Color.from_hsv(
		fposmod(hue + rng.randf_range(0.35, 0.62), 1.0),
		clampf(saturation * 1.1, 0.1, 1.0),
		clampf(value * 1.15, 0.2, 1.0)
	)
	traits.fin_color = Color.from_hsv(
		fposmod(hue + rng.randf_range(-0.09, 0.09), 1.0),
		clampf(saturation * 0.72, 0.05, 1.0),
		clampf(value * 1.2, 0.2, 1.0)
	)

	# High level creatures earn a metallic outline instead of the usual white.
	if rng.randf() < 0.15 + 0.45 * t:
		traits.outline_color = Color.from_hsv(
			fposmod(hue + 0.5, 1.0), 0.35, 1.0
		).lerp(Color(1.0, 0.88, 0.55), rng.randf())
	else:
		traits.outline_color = Color(0.95, 0.95, 0.95)

	traits.eye_color = Color.WHITE if rng.randf() > 0.25 * t else Color.from_hsv(
		fposmod(hue + 0.5, 1.0), 0.35, 1.0
	)
	traits.pupil_color = Color(0.09, 0.1, 0.13)


static func _apply_head(traits: CreatureTraits, rng: RandomNumberGenerator, t: float) -> void:
	var head_width := traits.body_radius(0)

	if _chance(rng, 0.28, 0.52, t):
		var horn_styles: Array[CreatureTraits.HornStyle] = [
			CreatureTraits.HornStyle.SPIKE,
			CreatureTraits.HornStyle.CURVED,
			CreatureTraits.HornStyle.ANTLER,
			CreatureTraits.HornStyle.CROWN,
		]
		traits.horn_style = horn_styles[rng.randi_range(0, horn_styles.size() - 1)]
		traits.horn_pairs = 1
		if traits.level >= 5 and rng.randf() < 0.35 + 0.3 * t:
			traits.horn_pairs = 2
		if traits.level >= 8 and rng.randf() < 0.3:
			traits.horn_pairs = 3
		traits.horn_length = head_width * rng.randf_range(1.0, 2.4) * lerpf(0.8, 1.5, t)
		traits.horn_width = head_width * rng.randf_range(0.18, 0.34)
		traits.horn_curve = rng.randf_range(-0.4, 1.6)
		traits.horn_spread = rng.randf_range(0.35, 1.0)

	if _chance(rng, 0.18, 0.3, t):
		var ear_styles: Array[CreatureTraits.EarStyle] = [
			CreatureTraits.EarStyle.ROUND,
			CreatureTraits.EarStyle.POINTED,
			CreatureTraits.EarStyle.FLOPPY,
		]
		traits.ear_style = ear_styles[rng.randi_range(0, ear_styles.size() - 1)]
		traits.ear_size = head_width * rng.randf_range(0.7, 1.5)

	if _chance(rng, 0.14, 0.34, t):
		traits.antenna_pairs = 1 if rng.randf() > 0.25 * t else 2
		traits.antenna_length = head_width * rng.randf_range(1.6, 3.4)
		traits.antenna_bulb = head_width * rng.randf_range(0.12, 0.3)

	if _chance(rng, 0.12, 0.36, t):
		traits.has_frill = true
		traits.frill_size = rng.randf_range(1.5, 2.6)
		traits.frill_points = rng.randi_range(6, 14)

	if _chance(rng, 0.18, 0.3, t):
		traits.whisker_count = rng.randi_range(2, 4)
		traits.whisker_length = head_width * rng.randf_range(1.4, 3.0)

	traits.eye_pair_count = 1
	if traits.level >= 6 and rng.randf() < 0.28:
		traits.eye_pair_count = 2
	if traits.level >= 9 and rng.randf() < 0.18:
		traits.eye_pair_count = 3
	traits.eye_angle = rng.randf_range(PI / 2.6, PI / 1.6)
	traits.has_nostrils = rng.randf() < 0.4
	traits.eye_radius *= lerpf(1.0, 1.25, t)


static func _apply_spine_decoration(
	traits: CreatureTraits,
	rng: RandomNumberGenerator,
	t: float
) -> void:
	if _chance(rng, 0.3, 0.45, t):
		var spike_styles: Array[CreatureTraits.SpikeStyle] = [
			CreatureTraits.SpikeStyle.SIDE_SPINES,
			CreatureTraits.SpikeStyle.RIDGE_FIN,
			CreatureTraits.SpikeStyle.PLATES,
		]
		traits.spike_style = spike_styles[rng.randi_range(0, spike_styles.size() - 1)]
		traits.spike_size = traits.body_radius(0) * rng.randf_range(0.45, 1.1) * lerpf(0.8, 1.4, t)
		traits.spike_spacing = rng.randi_range(1, 3)

	if rng.randf() < 0.4:
		traits.stripe_count = rng.randi_range(3, 4 + traits.level)
		traits.stripe_width = clampf(traits.body_radius(0) * 0.18, 3.0, 14.0)


static func _apply_limbs(traits: CreatureTraits, rng: RandomNumberGenerator, t: float) -> void:
	var legs_wanted := _chance(rng, 0.3, 0.35, t)
	if traits.profile == CreatureTraits.BodyProfile.BULKY:
		legs_wanted = rng.randf() < 0.9

	if legs_wanted:
		traits.leg_pairs = 2
		if rng.randf() < 0.25:
			traits.leg_pairs = 1
		if traits.level >= 7 and rng.randf() < 0.3:
			traits.leg_pairs = 3
		var reach := traits.body_radius(0) * lerpf(1.1, 1.7, t)
		traits.leg_link_size = reach * rng.randf_range(0.6, 0.9)
		traits.leg_width = traits.body_radius(0) * rng.randf_range(0.3, 0.55)
		traits.leg_outline_width = traits.leg_width + rng.randf_range(8.0, 18.0)
		traits.foot_reach = reach * rng.randf_range(0.9, 1.4)
		traits.step_distance = traits.leg_link_size * rng.randf_range(2.4, 3.8)
		traits.step_speed = rng.randf_range(0.28, 0.55)
		traits.shoulder_inset = traits.body_radius(0) * 0.3
		if rng.randf() < 0.35 + 0.4 * t:
			traits.toe_count = rng.randi_range(3, 4)
			traits.toe_length = traits.leg_width * rng.randf_range(0.7, 1.2)

	if _chance(rng, 0.28, 0.3, t):
		traits.pectoral_fins = true
		traits.pelvic_fins = rng.randf() < 0.55
	if traits.profile == CreatureTraits.BodyProfile.FUSIFORM and rng.randf() < 0.7:
		traits.pectoral_fins = true

	if traits.level >= 4 and _chance(rng, 0.0, 0.5, t):
		traits.wing_pairs = 1
		if traits.level >= 9 and rng.randf() < 0.3:
			traits.wing_pairs = 2
		traits.wing_span = traits.body_radius(0) * rng.randf_range(2.6, 5.0) * lerpf(0.8, 1.3, t)
		traits.wing_fingers = rng.randi_range(3, 5)
		traits.wing_flap_speed = rng.randf_range(1.6, 4.0)


static func _apply_tail(traits: CreatureTraits, rng: RandomNumberGenerator, t: float) -> void:
	if not _chance(rng, 0.45, 0.4, t):
		return

	var options: Array[CreatureTraits.TailTip] = [
		CreatureTraits.TailTip.CAUDAL_FIN,
		CreatureTraits.TailTip.SPADE,
		CreatureTraits.TailTip.PLUME,
	]
	if traits.level >= 4:
		options.append(CreatureTraits.TailTip.STINGER)
	if traits.level >= 6:
		options.append(CreatureTraits.TailTip.CLUB)
		options.append(CreatureTraits.TailTip.PLUME)

	traits.tail_tip = options[rng.randi_range(0, options.size() - 1)]
	traits.tail_size *= rng.randf_range(0.8, 1.3)


static func _build_name(traits: CreatureTraits, rng: RandomNumberGenerator) -> String:
	var stem := "%s%s" % [
		NAME_PREFIXES[rng.randi_range(0, NAME_PREFIXES.size() - 1)],
		NAME_SUFFIXES[rng.randi_range(0, NAME_SUFFIXES.size() - 1)],
	]
	var adjective := TIER_ADJECTIVES[clampi(traits.level - 1, 0, TIER_ADJECTIVES.size() - 1)]
	var words := traits.feature_words()
	var flavour := ""
	if not words.is_empty():
		flavour = "%s " % words[rng.randi_range(0, words.size() - 1)]
	return "%s %s%s" % [adjective, flavour, stem]


static func _chance(rng: RandomNumberGenerator, base: float, gain: float, t: float) -> bool:
	return rng.randf() < clampf(base + gain * t, 0.0, 1.0)


# Fuses two animals into a child one level higher. Features are inherited
# rather than re-rolled, so a horned parent and a winged parent make a horned,
# winged child; proportions are re-derived from the child's own body so a
# level 9 fusion is genuinely bigger than its parents.
static func merge(
		parent_a: CreatureTraits,
		parent_b: CreatureTraits,
		creature_seed: int = 0,
		habitat: CreatureTraits.Habitat = CreatureTraits.Habitat.WILD
) -> CreatureTraits:
	var used_seed := creature_seed
	while used_seed == 0:
		used_seed = randi()

	var rng := RandomNumberGenerator.new()
	rng.seed = used_seed

	var child := CreatureTraits.new()
	var gain := 2 if rng.randf() < level_bonus_chance(habitat) else 1
	child.level = clampi(maxi(parent_a.level, parent_b.level) + gain, MIN_LEVEL, MAX_LEVEL)
	child.creature_seed = used_seed
	child.profile = parent_a.profile if rng.randf() < 0.5 else parent_b.profile

	var t := float(child.level - MIN_LEVEL) / float(MAX_LEVEL - MIN_LEVEL)
	_apply_spine(child, rng, t)
	_inherit_palette(child, parent_a, parent_b, rng, t)
	_inherit_features(child, parent_a, parent_b, rng, t)

	# Every fusion has a chance of throwing in something neither parent had.
	if rng.randf() < 0.2 + 0.3 * t:
		_mutate(child, rng, t)

	apply_habitat(child, habitat, rng)
	child.display_name = _build_name(child, rng)
	return child


static func _inherit_palette(
	child: CreatureTraits,
	parent_a: CreatureTraits,
	parent_b: CreatureTraits,
	rng: RandomNumberGenerator,
	t: float
) -> void:
	var blend := rng.randf_range(0.25, 0.75)
	child.body_color = parent_a.body_color.lerp(parent_b.body_color, blend)
	child.accent_color = parent_a.accent_color.lerp(parent_b.accent_color, 1.0 - blend)
	child.fin_color = parent_a.fin_color.lerp(parent_b.fin_color, blend)
	child.eye_color = parent_a.eye_color if rng.randf() < 0.5 else parent_b.eye_color
	child.pupil_color = parent_a.pupil_color

	# Blending two colors dulls them, so fusions get their saturation back.
	child.body_color = child.body_color.lerp(
		Color.from_hsv(child.body_color.h, clampf(child.body_color.s * 1.4, 0.0, 1.0), 
		clampf(child.body_color.v * 1.08, 0.0, 1.0)), 0.7
	)
	child.accent_color = child.accent_color.lerp(
		Color.from_hsv(child.accent_color.h, clampf(child.accent_color.s * 1.3, 0.0, 1.0),
		clampf(child.accent_color.v * 1.12, 0.0, 1.0)), 0.7
	)

	var gold := Color(1.0, 0.88, 0.55)
	if rng.randf() < 0.25 + 0.5 * t:
		child.outline_color = gold.lerp(
			parent_a.outline_color if rng.randf() < 0.5 else parent_b.outline_color,
			rng.randf_range(0.0, 0.5)
		)
	else:
		child.outline_color = parent_a.outline_color if rng.randf() < 0.5 else parent_b.outline_color


static func _inherit_features(
	child: CreatureTraits,
	parent_a: CreatureTraits,
	parent_b: CreatureTraits,
	rng: RandomNumberGenerator,
	t: float
) -> void:
	var head := child.body_radius(0)
	var parents: Array[CreatureTraits] = [parent_a, parent_b]

	# --- Horns ---
	var horned: Array[CreatureTraits] = []
	for parent in parents:
		if parent.horn_style != CreatureTraits.HornStyle.NONE:
			horned.append(parent)
	if not horned.is_empty():
		var source := horned[rng.randi_range(0, horned.size() - 1)]
		child.horn_style = source.horn_style
		child.horn_pairs = maxi(parent_a.horn_pairs, parent_b.horn_pairs)
		if horned.size() == 2:
			# Two horned parents make something grander than either.
			if rng.randf() < 0.5:
				child.horn_style = CreatureTraits.HornStyle.ANTLER if rng.randf() < 0.5 \
					else CreatureTraits.HornStyle.CROWN
			if rng.randf() < 0.5:
				child.horn_pairs += 1
		child.horn_pairs = clampi(child.horn_pairs, 1, 3)
		child.horn_length = head * _ratio(source.horn_length, source) * rng.randf_range(1.0, 1.2)
		child.horn_width = head * _ratio(source.horn_width, source)
		child.horn_curve = lerpf(parent_a.horn_curve, parent_b.horn_curve, rng.randf())
		child.horn_spread = source.horn_spread

	# --- Ears ---
	var eared: Array[CreatureTraits] = []
	for parent in parents:
		if parent.ear_style != CreatureTraits.EarStyle.NONE:
			eared.append(parent)
	if not eared.is_empty():
		var source := eared[rng.randi_range(0, eared.size() - 1)]
		child.ear_style = source.ear_style
		child.ear_size = head * _ratio(source.ear_size, source)

	# --- Antennae ---
	if parent_a.antenna_pairs > 0 or parent_b.antenna_pairs > 0:
		var source := parent_a if parent_a.antenna_pairs > 0 else parent_b
		if parent_a.antenna_pairs > 0 and parent_b.antenna_pairs > 0 and rng.randf() < 0.5:
			source = parent_b
		child.antenna_pairs = clampi(
			maxi(parent_a.antenna_pairs, parent_b.antenna_pairs), 1, 3
		)
		child.antenna_length = head * _ratio(source.antenna_length, source)
		child.antenna_bulb = head * _ratio(source.antenna_bulb, source)

	# --- Frill ---
	if parent_a.has_frill or parent_b.has_frill:
		var source := parent_a if parent_a.has_frill else parent_b
		child.has_frill = true
		child.frill_size = maxf(parent_a.frill_size, parent_b.frill_size) \
			if parent_a.has_frill and parent_b.has_frill else source.frill_size
		child.frill_points = source.frill_points

	# --- Whiskers ---
	if parent_a.whisker_count > 0 or parent_b.whisker_count > 0:
		var source := parent_a if parent_a.whisker_count > 0 else parent_b
		child.whisker_count = maxi(parent_a.whisker_count, parent_b.whisker_count)
		child.whisker_length = head * _ratio(source.whisker_length, source)

	# --- Eyes ---
	child.eye_pair_count = clampi(maxi(parent_a.eye_pair_count, parent_b.eye_pair_count), 1, 3)
	if parent_a.eye_pair_count == parent_b.eye_pair_count and rng.randf() < 0.2 + 0.2 * t:
		child.eye_pair_count = clampi(child.eye_pair_count + 1, 1, 3)
	child.eye_angle = lerpf(parent_a.eye_angle, parent_b.eye_angle, rng.randf())
	child.has_pupils = parent_a.has_pupils or parent_b.has_pupils
	child.has_nostrils = parent_a.has_nostrils or parent_b.has_nostrils

	# --- Spine decoration ---
	var spiny: Array[CreatureTraits] = []
	for parent in parents:
		if parent.spike_style != CreatureTraits.SpikeStyle.NONE:
			spiny.append(parent)
	if not spiny.is_empty():
		var source := spiny[rng.randi_range(0, spiny.size() - 1)]
		child.spike_style = source.spike_style
		child.spike_size = head * _ratio(source.spike_size, source) * rng.randf_range(1.0, 1.25)
		child.spike_spacing = source.spike_spacing

	child.stripe_count = maxi(parent_a.stripe_count, parent_b.stripe_count)
	if child.stripe_count > 0:
		child.stripe_count = clampi(child.stripe_count, 3, 4 + child.level)
		child.stripe_width = clampf(head * 0.18, 3.0, 14.0)

	# --- Legs ---
	if parent_a.leg_pairs > 0 or parent_b.leg_pairs > 0:
		var source := parent_a if parent_a.leg_pairs > 0 else parent_b
		if parent_a.leg_pairs > 0 and parent_b.leg_pairs > 0 and rng.randf() < 0.5:
			source = parent_b
		child.leg_pairs = clampi(maxi(parent_a.leg_pairs, parent_b.leg_pairs), 1, 3)
		if parent_a.leg_pairs > 0 and parent_b.leg_pairs > 0 and rng.randf() < 0.35:
			child.leg_pairs = clampi(child.leg_pairs + 1, 1, 3)
		child.leg_link_size = head * _ratio(source.leg_link_size, source)
		child.leg_width = head * _ratio(source.leg_width, source)
		child.leg_outline_width = child.leg_width + 12.0
		child.foot_reach = head * _ratio(source.foot_reach, source)
		child.step_distance = child.leg_link_size * 3.0
		child.step_speed = lerpf(parent_a.step_speed, parent_b.step_speed, rng.randf())
		child.shoulder_inset = head * 0.3
		child.toe_count = maxi(parent_a.toe_count, parent_b.toe_count)
		child.toe_length = child.leg_width * 0.9

	# --- Fins ---
	child.pectoral_fins = parent_a.pectoral_fins or parent_b.pectoral_fins
	child.pelvic_fins = parent_a.pelvic_fins or parent_b.pelvic_fins

	# --- Wings ---
	if parent_a.wing_pairs > 0 or parent_b.wing_pairs > 0:
		var source := parent_a if parent_a.wing_pairs > 0 else parent_b
		child.wing_pairs = clampi(maxi(parent_a.wing_pairs, parent_b.wing_pairs), 1, 2)
		if parent_a.wing_pairs > 0 and parent_b.wing_pairs > 0 and rng.randf() < 0.4:
			child.wing_pairs = 2
		child.wing_span = head * _ratio(source.wing_span, source) * rng.randf_range(1.0, 1.2)
		child.wing_fingers = maxi(parent_a.wing_fingers, parent_b.wing_fingers)
		child.wing_flap_speed = lerpf(
			parent_a.wing_flap_speed, parent_b.wing_flap_speed, rng.randf()
		)

	# --- Tail ---
	var tailed: Array[CreatureTraits] = []
	for parent in parents:
		if parent.tail_tip != CreatureTraits.TailTip.NONE:
			tailed.append(parent)
	if not tailed.is_empty():
		var source := tailed[rng.randi_range(0, tailed.size() - 1)]
		child.tail_tip = source.tail_tip
		child.tail_size = head * _ratio(source.tail_size, source) * rng.randf_range(1.0, 1.2)


# Adds one feature the child did not inherit, so fusions keep surprising.
static func _mutate(child: CreatureTraits, rng: RandomNumberGenerator, t: float) -> void:
	var head := child.body_radius(0)
	var missing: Array[String] = []
	if child.horn_style == CreatureTraits.HornStyle.NONE:
		missing.append("horns")
	if child.wing_pairs <= 0 and child.level >= 4:
		missing.append("wings")
	if child.spike_style == CreatureTraits.SpikeStyle.NONE:
		missing.append("spikes")
	if not child.has_frill:
		missing.append("frill")
	if child.ear_style == CreatureTraits.EarStyle.NONE:
		missing.append("ears")
	if child.tail_tip == CreatureTraits.TailTip.NONE:
		missing.append("tail")
	if child.antenna_pairs <= 0:
		missing.append("antennae")
	if missing.is_empty():
		return

	match missing[rng.randi_range(0, missing.size() - 1)]:
		"horns":
			var horn_styles: Array[CreatureTraits.HornStyle] = [
				CreatureTraits.HornStyle.SPIKE,
				CreatureTraits.HornStyle.CURVED,
				CreatureTraits.HornStyle.ANTLER,
				CreatureTraits.HornStyle.CROWN,
			]
			child.horn_style = horn_styles[rng.randi_range(0, horn_styles.size() - 1)]
			child.horn_pairs = 1 if rng.randf() > t else 2
			child.horn_length = head * rng.randf_range(1.2, 2.4)
			child.horn_width = head * rng.randf_range(0.18, 0.32)
			child.horn_curve = rng.randf_range(-0.4, 1.5)
			child.horn_spread = rng.randf_range(0.35, 1.0)
		"wings":
			child.wing_pairs = 1
			child.wing_span = head * rng.randf_range(3.0, 4.6)
			child.wing_fingers = rng.randi_range(3, 5)
			child.wing_flap_speed = rng.randf_range(1.6, 3.6)
		"spikes":
			var spike_styles: Array[CreatureTraits.SpikeStyle] = [
				CreatureTraits.SpikeStyle.SIDE_SPINES,
				CreatureTraits.SpikeStyle.RIDGE_FIN,
				CreatureTraits.SpikeStyle.PLATES,
			]
			child.spike_style = spike_styles[rng.randi_range(0, spike_styles.size() - 1)]
			child.spike_size = head * rng.randf_range(0.5, 1.1)
			child.spike_spacing = rng.randi_range(1, 3)
		"frill":
			child.has_frill = true
			child.frill_size = rng.randf_range(1.6, 2.6)
			child.frill_points = rng.randi_range(6, 14)
		"ears":
			var ear_styles: Array[CreatureTraits.EarStyle] = [
				CreatureTraits.EarStyle.ROUND,
				CreatureTraits.EarStyle.POINTED,
				CreatureTraits.EarStyle.FLOPPY,
			]
			child.ear_style = ear_styles[rng.randi_range(0, ear_styles.size() - 1)]
			child.ear_size = head * rng.randf_range(0.8, 1.5)
		"tail":
			var tails: Array[CreatureTraits.TailTip] = [
				CreatureTraits.TailTip.CAUDAL_FIN,
				CreatureTraits.TailTip.SPADE,
				CreatureTraits.TailTip.PLUME,
				CreatureTraits.TailTip.STINGER,
				CreatureTraits.TailTip.CLUB,
			]
			child.tail_tip = tails[rng.randi_range(0, tails.size() - 1)]
			child.tail_size = head * rng.randf_range(0.9, 1.6)
		"antennae":
			child.antenna_pairs = 1
			child.antenna_length = head * rng.randf_range(2.0, 3.4)
			child.antenna_bulb = head * rng.randf_range(0.14, 0.3)


# Feature sizes are stored in pixels, so inheritance goes through the ratio to
# the parent's head width and is rebuilt against the child's own head.
static func _ratio(value: float, source: CreatureTraits) -> float:
	return value / maxf(1.0, source.body_radius(0))


# --- Habitats ---------------------------------------------------------------


# How likely a fusion in this habitat jumps two levels instead of one.
static func level_bonus_chance(habitat: CreatureTraits.Habitat) -> float:
	match habitat:
		CreatureTraits.Habitat.WATER:
			return 0.25
		CreatureTraits.Habitat.ALIEN:
			return 0.4
		_:
			return 0.15


# Reshapes a finished recipe to fit the pen it will live in. The habitat owns
# the palette and locks a few features on or off, so a reef animal is always
# blue and finned and a void animal always has antennae.
static func apply_habitat(
	traits: CreatureTraits,
	habitat: CreatureTraits.Habitat,
	rng: RandomNumberGenerator
) -> void:
	traits.habitat = habitat
	if habitat == CreatureTraits.Habitat.WILD:
		return

	match habitat:
		CreatureTraits.Habitat.BASIC:
			_shape_meadow(traits, rng)
		CreatureTraits.Habitat.WATER:
			_shape_reef(traits, rng)
		CreatureTraits.Habitat.ALIEN:
			_shape_void(traits, rng)

	_apply_habitat_palette(traits, habitat, rng)


static func _shape_meadow(traits: CreatureTraits, rng: RandomNumberGenerator) -> void:
	traits.pectoral_fins = false
	traits.pelvic_fins = false
	if traits.tail_tip == CreatureTraits.TailTip.CAUDAL_FIN:
		traits.tail_tip = CreatureTraits.TailTip.PLUME if rng.randf() < 0.5 \
			else CreatureTraits.TailTip.SPADE
	if traits.spike_style == CreatureTraits.SpikeStyle.RIDGE_FIN:
		traits.spike_style = CreatureTraits.SpikeStyle.SIDE_SPINES
	# Meadow animals only take to the air once they are grand enough.
	if traits.level < 7:
		traits.wing_pairs = 0
	if traits.leg_pairs <= 0 and rng.randf() < 0.8:
		_grant_legs(traits, rng)


static func _shape_reef(traits: CreatureTraits, rng: RandomNumberGenerator) -> void:
	traits.leg_pairs = 0
	traits.toe_count = 0
	traits.wing_pairs = 0
	traits.ear_style = CreatureTraits.EarStyle.NONE
	traits.pectoral_fins = true
	traits.pelvic_fins = rng.randf() < 0.65
	traits.tail_tip = CreatureTraits.TailTip.CAUDAL_FIN
	traits.fin_scale = maxf(traits.fin_scale, 1.0) * rng.randf_range(1.0, 1.3)
	if traits.spike_style == CreatureTraits.SpikeStyle.SIDE_SPINES:
		traits.spike_style = CreatureTraits.SpikeStyle.RIDGE_FIN
	if traits.spike_style == CreatureTraits.SpikeStyle.NONE and rng.randf() < 0.5:
		traits.spike_style = CreatureTraits.SpikeStyle.RIDGE_FIN
		traits.spike_size = traits.body_radius(0) * rng.randf_range(0.5, 0.9)
		traits.spike_spacing = 2


static func _shape_void(traits: CreatureTraits, rng: RandomNumberGenerator) -> void:
	if traits.antenna_pairs <= 0:
		_grant_antennae(traits, rng)
	if traits.horn_style == CreatureTraits.HornStyle.NONE and rng.randf() < 0.7:
		var head := traits.body_radius(0)
		traits.horn_style = CreatureTraits.HornStyle.CROWN
		traits.horn_pairs = 1
		traits.horn_length = head * rng.randf_range(1.2, 2.2)
		traits.horn_width = head * rng.randf_range(0.16, 0.3)
		traits.horn_curve = rng.randf_range(-0.3, 0.6)
		traits.horn_spread = rng.randf_range(0.4, 0.9)
	if traits.level >= 3:
		traits.eye_pair_count = maxi(2, traits.eye_pair_count)
	if not traits.has_frill and rng.randf() < 0.45:
		traits.has_frill = true
		traits.frill_size = rng.randf_range(1.7, 2.6)
		traits.frill_points = rng.randi_range(7, 14)
	if traits.spike_style == CreatureTraits.SpikeStyle.NONE and rng.randf() < 0.55:
		traits.spike_style = CreatureTraits.SpikeStyle.PLATES
		traits.spike_size = traits.body_radius(0) * rng.randf_range(0.5, 0.9)
		traits.spike_spacing = rng.randi_range(1, 3)


static func _apply_habitat_palette(
	traits: CreatureTraits,
	habitat: CreatureTraits.Habitat,
	rng: RandomNumberGenerator
) -> void:
	var t := float(traits.level - MIN_LEVEL) / float(MAX_LEVEL - MIN_LEVEL)
	var hue := 0.3
	var accent_hue := 0.1
	var saturation := 0.5
	var value := 0.7

	match habitat:
		CreatureTraits.Habitat.BASIC:
			hue = rng.randf_range(0.06, 0.36)
			accent_hue = fposmod(hue + rng.randf_range(0.4, 0.62), 1.0)
			saturation = rng.randf_range(0.35, 0.62)
			value = rng.randf_range(0.48, 0.76)
		CreatureTraits.Habitat.WATER:
			hue = rng.randf_range(0.44, 0.64)
			accent_hue = fposmod(hue + rng.randf_range(0.06, 0.22), 1.0)
			saturation = rng.randf_range(0.45, 0.8)
			value = rng.randf_range(0.58, 0.9)
		CreatureTraits.Habitat.ALIEN:
			hue = rng.randf_range(0.72, 0.97)
			accent_hue = fposmod(0.26 + rng.randf_range(-0.06, 0.08), 1.0)
			saturation = rng.randf_range(0.62, 0.95)
			value = rng.randf_range(0.68, 1.0)

	# Level still reads through the habitat: higher levels are richer.
	saturation = clampf(saturation * lerpf(0.82, 1.16, t), 0.08, 1.0)
	value = clampf(value * lerpf(0.9, 1.1, t), 0.2, 1.0)

	traits.body_color = Color.from_hsv(hue, saturation, value)
	traits.accent_color = Color.from_hsv(
		accent_hue, clampf(saturation * 1.12, 0.0, 1.0), clampf(value * 1.15, 0.0, 1.0)
	)
	traits.fin_color = Color.from_hsv(
		fposmod(hue + rng.randf_range(0.03, 0.09), 1.0),
		clampf(saturation * 0.72, 0.0, 1.0),
		clampf(value * 1.2, 0.0, 1.0)
	)

	match habitat:
		CreatureTraits.Habitat.WATER:
			traits.outline_color = Color(0.86, 0.95, 1.0)
		CreatureTraits.Habitat.ALIEN:
			traits.outline_color = Color.from_hsv(accent_hue, 0.3, 1.0)
		_:
			traits.outline_color = Color(0.95, 0.93, 0.86)


static func _grant_legs(traits: CreatureTraits, rng: RandomNumberGenerator) -> void:
	var head := traits.body_radius(0)
	traits.leg_pairs = 2 if rng.randf() < 0.72 else 1
	traits.leg_link_size = head * rng.randf_range(0.8, 1.2)
	traits.leg_width = head * rng.randf_range(0.3, 0.5)
	traits.leg_outline_width = traits.leg_width + 12.0
	traits.foot_reach = head * rng.randf_range(1.1, 1.6)
	traits.step_distance = traits.leg_link_size * 3.0
	traits.step_speed = rng.randf_range(0.3, 0.5)
	traits.shoulder_inset = head * 0.3
	traits.toe_count = 3 if rng.randf() < 0.6 else 0
	traits.toe_length = traits.leg_width * 0.9


static func _grant_antennae(traits: CreatureTraits, rng: RandomNumberGenerator) -> void:
	var head := traits.body_radius(0)
	traits.antenna_pairs = 1 if rng.randf() < 0.7 else 2
	traits.antenna_length = head * rng.randf_range(2.0, 3.4)
	traits.antenna_bulb = head * rng.randf_range(0.14, 0.3)
