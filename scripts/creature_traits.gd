class_name CreatureTraits
extends RefCounted


# Every knob the abstract animal understands. A CreatureTraits instance is a
# complete recipe: the randomizer fills one in, and Creature draws it.


enum BodyProfile {
	SERPENT,
	FUSIFORM,
	BULKY,
	TADPOLE,
	SEGMENTED,
}

enum HornStyle {
	NONE,
	SPIKE,
	CURVED,
	ANTLER,
	CROWN,
}

enum SpikeStyle {
	NONE,
	SIDE_SPINES,
	RIDGE_FIN,
	PLATES,
}

enum EarStyle {
	NONE,
	ROUND,
	POINTED,
	FLOPPY,
}

## Where a creature lives. WILD means "no environment constraints" and is what
## the animation sandbox uses; the zoo pens use the other three.
enum Habitat {
	WILD,
	BASIC,
	WATER,
	ALIEN,
}

enum TailTip {
	NONE,
	CAUDAL_FIN,
	SPADE,
	CLUB,
	PLUME,
	STINGER,
}

const HABITAT_NAMES: Array[String] = [
	"wild", "meadow", "reef", "void",
]

const PROFILE_NAMES: Array[String] = [
	"serpent", "swimmer", "walker", "tadpole", "grub",
]

const HORN_NAMES: Array[String] = [
	"", "spiked", "horned", "antlered", "crowned",
]

const SPIKE_NAMES: Array[String] = [
	"", "spiny", "finned", "plated",
]

const EAR_NAMES: Array[String] = [
	"", "round-eared", "pointy-eared", "lop-eared",
]

const TAIL_NAMES: Array[String] = [
	"", "fin-tailed", "spade-tailed", "club-tailed", "plume-tailed", "stinger-tailed",
]

var display_name: String = "creature"
var habitat: Habitat = Habitat.WILD
var level: int = 5
var creature_seed: int = 0

# Spine and motion.
var profile: BodyProfile = BodyProfile.SERPENT
var joint_count: int = 16
var link_size: float = 46.0
var angle_constraint: float = PI / 8.0
var movement_speed: float = 620.0
var body_widths: Array[float] = []

# Palette.
var body_color: Color = Color(0.42, 0.55, 0.68)
var outline_color: Color = Color(0.95, 0.95, 0.95)
var accent_color: Color = Color(0.85, 0.62, 0.32)
var fin_color: Color = Color(0.51, 0.76, 0.84)
var eye_color: Color = Color.WHITE
var pupil_color: Color = Color(0.09, 0.1, 0.13)

# Head and face.
var eye_radius: float = 12.0
var eye_pair_count: int = 1
var eye_angle: float = PI / 2.0
var has_pupils: bool = true
var has_nostrils: bool = false
var whisker_count: int = 0
var whisker_length: float = 96.0

# Head decoration.
var horn_style: HornStyle = HornStyle.NONE
var horn_pairs: int = 1
var horn_length: float = 70.0
var horn_width: float = 14.0
var horn_curve: float = 0.9
var horn_spread: float = 0.7
var ear_style: EarStyle = EarStyle.NONE
var ear_size: float = 44.0
var antenna_pairs: int = 0
var antenna_length: float = 96.0
var antenna_bulb: float = 11.0
var has_frill: bool = false
var frill_size: float = 1.7
var frill_points: int = 9

# Spine decoration.
var spike_style: SpikeStyle = SpikeStyle.NONE
var spike_size: float = 32.0
var spike_spacing: int = 2
var stripe_count: int = 0
var stripe_width: float = 7.0

# Limbs.
var leg_pairs: int = 0
var leg_link_size: float = 46.0
var leg_width: float = 26.0
var leg_outline_width: float = 36.0
var foot_reach: float = 78.0
var step_distance: float = 190.0
var step_speed: float = 0.4
var shoulder_inset: float = 18.0
var toe_count: int = 0
var toe_length: float = 20.0

# Fins and wings.
var pectoral_fins: bool = false
var pelvic_fins: bool = false
var fin_scale: float = 1.0
var wing_pairs: int = 0
var wing_span: float = 220.0
var wing_fingers: int = 3
var wing_flap_speed: float = 2.6

# Tail.
var tail_tip: TailTip = TailTip.NONE
var tail_size: float = 62.0


func body_radius(index: int) -> float:
	if body_widths.is_empty():
		return 24.0
	return body_widths[clampi(index, 0, body_widths.size() - 1)]


func profile_name() -> String:
	return PROFILE_NAMES[profile]


func habitat_name() -> String:
	return HABITAT_NAMES[habitat]


# A short, human readable list of what this creature actually has, used by the
# pause panel and by the generated name.
func feature_words() -> PackedStringArray:
	var words := PackedStringArray()
	if horn_style != HornStyle.NONE:
		words.append(HORN_NAMES[horn_style])
	if wing_pairs > 0:
		words.append("winged")
	if leg_pairs > 0:
		words.append("%d-legged" % (leg_pairs * 2))
	if spike_style != SpikeStyle.NONE:
		words.append(SPIKE_NAMES[spike_style])
	if has_frill:
		words.append("frilled")
	if ear_style != EarStyle.NONE:
		words.append(EAR_NAMES[ear_style])
	if antenna_pairs > 0:
		words.append("antennaed")
	if pectoral_fins or pelvic_fins:
		words.append("finned")
	if whisker_count > 0:
		words.append("whiskered")
	if tail_tip != TailTip.NONE:
		words.append(TAIL_NAMES[tail_tip])
	if eye_pair_count > 1:
		words.append("%d-eyed" % (eye_pair_count * 2))
	if stripe_count > 0:
		words.append("striped")
	return words


func summary() -> String:
	var parts := PackedStringArray()
	parts.append("level %d" % level)
	if habitat != Habitat.WILD:
		parts.append(habitat_name())
	parts.append(profile_name())
	parts.append("%d joints" % joint_count)
	for word in feature_words():
		parts.append(word)
	parts.append("seed %d" % creature_seed)
	return ", ".join(parts)


# --- Saving -----------------------------------------------------------------


# Serialises every script variable, so new traits are picked up automatically
# rather than needing a hand-written field list kept in sync.
func to_dict() -> Dictionary:
	var data := {}
	for property in get_property_list():
		if not (int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var key := String(property["name"])
		var value: Variant = get(key)
		if value is Color:
			var color := value as Color
			data[key] = [color.r, color.g, color.b, color.a]
		elif value is Array:
			var numbers := []
			for entry in (value as Array):
				numbers.append(entry)
			data[key] = numbers
		else:
			data[key] = value
	return data


static func from_dict(data: Dictionary) -> CreatureTraits:
	var traits := CreatureTraits.new()
	for key_variant in data.keys():
		var key := String(key_variant)
		var current: Variant = traits.get(key)
		if current == null:
			continue
		var value: Variant = data[key]
		match typeof(current):
			TYPE_INT:
				traits.set(key, int(value))
			TYPE_FLOAT:
				traits.set(key, float(value))
			TYPE_BOOL:
				traits.set(key, bool(value))
			TYPE_STRING:
				traits.set(key, String(value))
			TYPE_COLOR:
				if value is Array and (value as Array).size() >= 3:
					var parts := value as Array
					traits.set(key, Color(
						float(parts[0]),
						float(parts[1]),
						float(parts[2]),
						float(parts[3]) if parts.size() > 3 else 1.0
					))
			TYPE_ARRAY:
				var widths: Array[float] = []
				if value is Array:
					for entry in (value as Array):
						widths.append(float(entry))
				traits.set(key, widths)
	return traits
