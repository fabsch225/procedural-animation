class_name Enclosure
extends Node2D


# One pen in the zoo. Holds at most one creature, scales it so the whole
# animal fits inside the fence, grows its own procedural scenery, and draws
# its own label.


const LABEL_MARGIN: Vector2 = Vector2(16.0, 12.0)
const DECOR_INSET: float = 6.0

@export var size: Vector2 = Vector2(540.0, 430.0)
var habitat: CreatureTraits.Habitat = CreatureTraits.Habitat.BASIC
@export var selected_color: Color = Color(1.0, 0.85, 0.42)
@export var empty_text: String = "empty pen"

var creature: Creature
var pen_index: int = 0
var decor_seed: int = 0
var selected: bool = false:
	set(value):
		selected = value
		queue_redraw()

var _label: Label
var _decor: HabitatDecor
var _label_clock: float = 0.0


func _ready() -> void:
	_decor = HabitatDecor.new()
	add_child(_decor)
	_decor.setup(habitat, local_rect().grow(-DECOR_INSET), decor_seed)

	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 16)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.position = -size * 0.5 + LABEL_MARGIN
	_label.size = Vector2(size.x - LABEL_MARGIN.x * 2.0, 22.0)
	add_child(_label)
	_refresh_label()


func _process(delta: float) -> void:
	if creature == null:
		return
	# The animal grows while it matures, so its scale is re-applied every frame.
	refit()
	_label_clock -= delta
	if _label_clock <= 0.0:
		_label_clock = 0.25
		_refresh_label()


func configure(
	new_habitat: CreatureTraits.Habitat,
	new_size: Vector2,
	new_seed: int
) -> void:
	habitat = new_habitat
	size = new_size
	decor_seed = new_seed
	if _decor != null:
		_decor.setup(habitat, local_rect().grow(-DECOR_INSET), decor_seed)
	if _label != null:
		_label.position = -size * 0.5 + LABEL_MARGIN
		_label.size = Vector2(size.x - LABEL_MARGIN.x * 2.0, 22.0)
	queue_redraw()


static func habitat_label(habitat_value: CreatureTraits.Habitat) -> String:
	match habitat_value:
		CreatureTraits.Habitat.WATER:
			return "Reef"
		CreatureTraits.Habitat.ALIEN:
			return "Void"
		_:
			return "Meadow"


static func habitat_ground(habitat_value: CreatureTraits.Habitat) -> Color:
	match habitat_value:
		CreatureTraits.Habitat.WATER:
			return Color(0.11, 0.29, 0.38)
		CreatureTraits.Habitat.ALIEN:
			return Color(0.13, 0.09, 0.19)
		_:
			return Color(0.19, 0.25, 0.21)


static func habitat_fence(habitat_value: CreatureTraits.Habitat) -> Color:
	match habitat_value:
		CreatureTraits.Habitat.WATER:
			return Color(0.42, 0.68, 0.78)
		CreatureTraits.Habitat.ALIEN:
			return Color(0.68, 0.45, 0.85)
		_:
			return Color(0.48, 0.52, 0.44)


func local_rect() -> Rect2:
	return Rect2(-size * 0.5, size)


func hit_test(global_point: Vector2) -> bool:
	return local_rect().has_point(to_local(global_point))


func is_empty() -> bool:
	return creature == null


func set_creature(new_creature: Creature) -> void:
	clear_creature()
	creature = new_creature
	creature.control_mode = Creature.ControlMode.ROAM
	creature.start_at_viewport_center = false
	refit()
	add_child(creature)
	move_child(_label, get_child_count() - 1)
	_refresh_label()
	queue_redraw()


# Sizes the housed creature so the whole animal fits inside the fence, and
# keeps its roaming area inside the pen. Called again whenever the pen resizes.
func refit() -> void:
	if creature == null:
		return
	var creature_traits := creature.traits
	var body_length := float(creature_traits.joint_count) * creature_traits.link_size

	# Higher level animals are allowed to fill more of the pen, so a level 10
	# fusion still reads as bigger than a hatchling even though both are scaled
	# down to leave plenty of room around them.
	var level_weight := float(creature_traits.level - 1) / 9.0
	var target_extent := minf(size.x, size.y) * lerpf(0.38, 0.55, level_weight)
	var adult_scale := clampf(
		target_extent / maxf(body_length * 0.55, 1.0), 0.05, 0.55
	)
	var creature_scale := adult_scale * creature.growth_factor()
	creature.scale = Vector2.ONE * creature_scale

	var half_extent := (size * 0.26) / creature_scale
	creature.roam_bounds = Rect2(-half_extent, half_extent * 2.0)


func clear_creature() -> void:
	if creature != null:
		remove_child(creature)
		creature.queue_free()
		creature = null
	_refresh_label()
	queue_redraw()


func creature_level() -> int:
	return 0 if creature == null else creature.traits.level


func income_per_second() -> float:
	if creature == null:
		return 0.0
	return level_income(creature.traits.level)


static func format_duration(seconds: float) -> String:
	var whole := int(ceil(maxf(seconds, 0.0)))
	return "%d:%02d" % [whole / 60, whole % 60]


func is_ready_to_breed() -> bool:
	return creature != null and creature.is_mature()


static func level_income(level: int) -> float:
	return float(level) * float(level) * 0.55 + 0.45


func _refresh_label() -> void:
	if _label == null:
		return
	var prefix := habitat_label(habitat)
	if creature == null:
		_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.4))
		_label.text = "%s  ·  %s" % [prefix, empty_text]
		return
	_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.88))
	var state := "ready to breed"
	if not creature.is_mature():
		state = "growing %d%%  ·  %s left" % [
			int(round(creature.maturity_ratio() * 100.0)),
			format_duration(creature.seconds_until_mature()),
		]
	_label.text = "%s  ·  Lv %d  %s  (%.1f/s)  ·  %s" % [
		prefix,
		creature.traits.level,
		creature.traits.display_name,
		income_per_second(),
		state,
	]


func _draw() -> void:
	var rect := local_rect()
	draw_rect(rect, habitat_ground(habitat), true)
	draw_rect(rect, habitat_fence(habitat), false, 3.0)
	if selected:
		draw_rect(rect.grow(7.0), selected_color, false, 5.0)
