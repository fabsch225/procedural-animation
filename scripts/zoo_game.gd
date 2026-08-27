class_name ZooGame
extends Node2D


# A small zoo built on the procedural creature system. Buy eggs to hatch
# level 1 animals, buy pens of three habitats to house them, and breed two
# animals of the SAME level into one that is one or two levels higher. The pen
# a creature is born into decides its colours and locks some features on or
# off, so a reef animal is always finned and blue.


const STARTING_MONEY: float = 130.0
const MAX_ENCLOSURES: int = 12
const EGG_COST: float = 40.0
const CELL_GAP: float = 20.0
const GRID_TOP_MARGIN: float = 124.0
const GRID_BOTTOM_MARGIN: float = 78.0
const SCROLL_STEP: float = 280.0
const SCROLL_SMOOTHING: float = 12.0
const SAVE_PATH: String = "user://zoo_save.json"
const SAVE_FILE_NAME: String = "zoo_save.json"
const SAVE_VERSION: int = 1
const AUTOSAVE_INTERVAL: float = 5.0
const ERASE_CONFIRM_TIME: float = 4.0

@onready var enclosure_root: Node2D = $Enclosures
@onready var music: MusicPlayer = $Music
@onready var money_label: Label = $UI/Root/Layout/Top/MoneyLabel
@onready var income_label: Label = $UI/Root/Layout/Top/IncomeLabel
@onready var egg_button: Button = $UI/Root/Layout/Top/EggButton
@onready var erase_button: Button = $UI/Root/Layout/Top/EraseButton
@onready var back_button: Button = $UI/Root/Layout/Top/BackButton
@onready var basic_button: Button = $UI/Root/Layout/PenRow/BasicButton
@onready var water_button: Button = $UI/Root/Layout/PenRow/WaterButton
@onready var alien_button: Button = $UI/Root/Layout/PenRow/AlienButton
@onready var scroll_left_button: Button = $UI/Root/Layout/PenRow/ScrollLeft
@onready var scroll_right_button: Button = $UI/Root/Layout/PenRow/ScrollRight
@onready var status_label: Label = $UI/Root/Layout/StatusLabel
@onready var help_label: Label = $UI/Root/Layout/HelpLabel

var money: float = STARTING_MONEY
var enclosures: Array[Enclosure] = []
var selected_enclosure: Enclosure = null
var scroll_offset: float = 0.0
var scroll_target: float = 0.0
var _autosave_clock: float = AUTOSAVE_INTERVAL
var _erase_armed: bool = false
var _erase_clock: float = 0.0


func _ready() -> void:
	var loaded := load_game()
	if not loaded:
		_start_new_zoo()
	_layout_enclosures()

	egg_button.pressed.connect(_on_egg_pressed)
	erase_button.pressed.connect(_on_erase_pressed)
	#back_button.pressed.connect(_on_back_pressed)
	basic_button.pressed.connect(_on_buy_pen.bind(CreatureTraits.Habitat.BASIC))
	water_button.pressed.connect(_on_buy_pen.bind(CreatureTraits.Habitat.WATER))
	alien_button.pressed.connect(_on_buy_pen.bind(CreatureTraits.Habitat.ALIEN))
	scroll_left_button.pressed.connect(_scroll_by.bind(-SCROLL_STEP))
	scroll_right_button.pressed.connect(_scroll_by.bind(SCROLL_STEP))
	get_viewport().size_changed.connect(_layout_enclosures)

	help_label.text = (
		"Scroll with the mouse wheel or the arrow keys. Click a pen to select "
		+ "it, then click a second pen holding an animal of the SAME level to "
		+ "breed them. The habitat decides the child's colours and which "
		+ "features it can have."
	)
	music.play_for_habitat(newest_habitat())
	if loaded:
		_set_status("Zoo restored: %d pens, %d coins." % [enclosures.size(), int(money)])
	else:
		_set_status("Buy an egg to hatch your first animal.")
	_update_ui()


func _process(delta: float) -> void:
	money += total_income() * delta

	_autosave_clock -= delta
	if _autosave_clock <= 0.0:
		_autosave_clock = AUTOSAVE_INTERVAL
		save_game()

	if _erase_armed:
		_erase_clock -= delta
		if _erase_clock <= 0.0:
			_disarm_erase()

	scroll_offset = lerpf(
		scroll_offset, scroll_target, clampf(delta * SCROLL_SMOOTHING, 0.0, 1.0)
	)
	enclosure_root.position.x = -scroll_offset
	_update_ui()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var button := event as InputEventMouseButton
		match button.button_index:
			MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_RIGHT:
				_scroll_by(SCROLL_STEP)
				get_viewport().set_input_as_handled()
				return
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_LEFT:
				_scroll_by(-SCROLL_STEP)
				get_viewport().set_input_as_handled()
				return
			MOUSE_BUTTON_LEFT:
				var point := get_global_mouse_position()
				for enclosure in enclosures:
					if enclosure.hit_test(point):
						_on_enclosure_clicked(enclosure)
						get_viewport().set_input_as_handled()
						return
				_clear_selection()
		return

	if event is InputEventKey and (event as InputEventKey).pressed \
			and not (event as InputEventKey).echo:
		match (event as InputEventKey).keycode:
			KEY_RIGHT, KEY_D:
				_scroll_by(SCROLL_STEP)
				get_viewport().set_input_as_handled()
			KEY_LEFT, KEY_A:
				_scroll_by(-SCROLL_STEP)
				get_viewport().set_input_as_handled()


# --- Layout and scrolling ---------------------------------------------------


func cell_size() -> Vector2:
	var viewport_size := get_viewport_rect().size
	return Vector2(
		maxf(260.0, (viewport_size.x - CELL_GAP * 3.0) * 0.5),
		maxf(200.0, viewport_size.y - GRID_TOP_MARGIN - GRID_BOTTOM_MARGIN)
	)


func content_width() -> float:
	var cell := cell_size()
	return CELL_GAP + float(enclosures.size()) * (cell.x + CELL_GAP)


func max_scroll() -> float:
	return maxf(0.0, content_width() - get_viewport_rect().size.x)


func _layout_enclosures() -> void:
	var cell := cell_size()
	for i in range(enclosures.size()):
		var enclosure := enclosures[i]
		enclosure.configure(enclosure.habitat, cell, enclosure.decor_seed)
		enclosure.refit()
		enclosure.position = Vector2(
			CELL_GAP + float(i) * (cell.x + CELL_GAP) + cell.x * 0.5,
			GRID_TOP_MARGIN + cell.y * 0.5
		)
	scroll_target = clampf(scroll_target, 0.0, max_scroll())


func _scroll_by(amount: float) -> void:
	scroll_target = clampf(scroll_target + amount, 0.0, max_scroll())


func _scroll_to_enclosure(index: int) -> void:
	var cell := cell_size()
	var left := CELL_GAP + float(index) * (cell.x + CELL_GAP)
	scroll_target = clampf(
		left + cell.x * 0.5 - get_viewport_rect().size.x * 0.5, 0.0, max_scroll()
	)


# --- Economy ----------------------------------------------------------------


func total_income() -> float:
	var income := 0.0
	for enclosure in enclosures:
		income += enclosure.income_per_second()
	return income


static func habitat_base_cost(habitat: CreatureTraits.Habitat) -> float:
	match habitat:
		CreatureTraits.Habitat.WATER:
			return 280.0
		CreatureTraits.Habitat.ALIEN:
			return 760.0
		_:
			return 90.0


static func habitat_cost_growth(habitat: CreatureTraits.Habitat) -> float:
	match habitat:
		CreatureTraits.Habitat.WATER:
			return 1.5
		CreatureTraits.Habitat.ALIEN:
			return 1.45
		_:
			return 1.55


# Each habitat has its own price ladder, so a second reef pen costs more than
# the first but does not make meadow pens dearer.
func habitat_cost(habitat: CreatureTraits.Habitat) -> float:
	var owned := 0
	for enclosure in enclosures:
		if enclosure.habitat == habitat:
			owned += 1
	return habitat_base_cost(habitat) * pow(habitat_cost_growth(habitat), float(owned))


func _on_egg_pressed() -> void:
	if money < EGG_COST:
		_set_status("Not enough coins for an egg.")
		return

	var pen := selected_enclosure
	if pen == null or not pen.is_empty():
		pen = _first_empty_enclosure()
	if pen == null:
		_set_status("Every pen is full. Buy another pen, or breed two animals.")
		return

	money -= EGG_COST
	var hatched := CreatureRandomizer.generate(1, 0, pen.habitat)
	_place_creature(pen, hatched)
	_clear_selection()
	_scroll_to_enclosure(pen.pen_index)
	_set_status("A %s egg hatched: %s." % [
		Enclosure.habitat_label(pen.habitat).to_lower(), hatched.display_name
	])
	_update_ui()
	save_game()


func _on_buy_pen(habitat: CreatureTraits.Habitat) -> void:
	if enclosures.size() >= MAX_ENCLOSURES:
		_set_status("The zoo is full at %d pens." % MAX_ENCLOSURES)
		return
	var cost := habitat_cost(habitat)
	if money < cost:
		_set_status("Not enough coins for a %s pen." % Enclosure.habitat_label(habitat).to_lower())
		return

	money -= cost
	var pen := _create_enclosure(habitat)
	_layout_enclosures()
	_scroll_to_enclosure(pen.pen_index)
	music.play_for_habitat(habitat)
	_set_status("Built a %s pen. The music follows your newest habitat." % Enclosure.habitat_label(habitat).to_lower())
	_update_ui()
	save_game()


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")


# --- Pens and creatures -----------------------------------------------------


func _create_enclosure(
		habitat: CreatureTraits.Habitat,
		decor_seed: int = 0
) -> Enclosure:
	var enclosure := Enclosure.new()
	enclosure.name = "Enclosure%d" % enclosures.size()
	enclosure.pen_index = enclosures.size()
	enclosure.habitat = habitat
	enclosure.size = cell_size()
	enclosure.decor_seed = decor_seed if decor_seed != 0 else randi_range(1, 1 << 30)
	enclosure_root.add_child(enclosure)
	enclosures.append(enclosure)
	return enclosure


func _place_creature(pen: Enclosure, creature_traits: CreatureTraits) -> void:
	var creature := Creature.new()
	creature.name = "Creature"
	creature.traits = creature_traits
	creature.randomize_on_ready = false
	creature.start_at_viewport_center = false
	creature.control_mode = Creature.ControlMode.ROAM
	pen.set_creature(creature)


# The most recently built pen sets the mood; the zoo's soundtrack follows it.
func newest_habitat() -> CreatureTraits.Habitat:
	if enclosures.is_empty():
		return CreatureTraits.Habitat.BASIC
	return enclosures[enclosures.size() - 1].habitat


func _first_empty_enclosure() -> Enclosure:
	for enclosure in enclosures:
		if enclosure.is_empty():
			return enclosure
	return null


func _on_enclosure_clicked(enclosure: Enclosure) -> void:
	if enclosure.is_empty():
		_select(enclosure)
		_set_status(
			"%s pen selected. Buy an egg to fill it."
			% Enclosure.habitat_label(enclosure.habitat)
		)
		return

	if not enclosure.is_ready_to_breed():
		_select(enclosure)
		_set_status("Lv %d %s is still growing - %s until it can breed." % [
			enclosure.creature_level(),
			enclosure.creature.traits.display_name,
			Enclosure.format_duration(enclosure.creature.seconds_until_mature()),
		])
		return

	if selected_enclosure == enclosure:
		_clear_selection()
		_set_status("Selection cleared.")
		return

	if selected_enclosure == null or not selected_enclosure.is_ready_to_breed():
		_select(enclosure)
		_set_status(
			"Selected Lv %d %s. Click another animal of the same level to breed."
			% [enclosure.creature_level(), enclosure.creature.traits.display_name]
		)
		return

	if selected_enclosure.creature_level() != enclosure.creature_level():
		_select(enclosure)
		_set_status(
			"Only animals of the same level can breed. Selected Lv %d instead."
			% enclosure.creature_level()
		)
		return

	_breed(selected_enclosure, enclosure)


func _breed(first: Enclosure, second: Enclosure) -> void:
	if not first.is_ready_to_breed() or not second.is_ready_to_breed():
		_set_status("Both animals have to be fully grown before they can breed.")
		return

	var parent_a := first.creature.traits
	var parent_b := second.creature.traits
	if parent_a.level >= CreatureRandomizer.MAX_LEVEL:
		_clear_selection()
		_set_status("Level %d is the top of the tree." % CreatureRandomizer.MAX_LEVEL)
		return

	var child := CreatureRandomizer.merge(parent_a, parent_b, 0, second.habitat)
	var gained := child.level - parent_a.level

	_clear_selection()
	first.clear_creature()
	second.clear_creature()
	_place_creature(second, child)
	_scroll_to_enclosure(second.pen_index)
	_set_status("Two Lv %d animals bred into a Lv %d %s (+%d, %.1f/s). It needs %s to grow up." % [
		parent_a.level, child.level, child.display_name, gained,
		Enclosure.level_income(child.level),
		Enclosure.format_duration(Creature.maturity_time_for_level(child.level)),
	])
	_update_ui()
	save_game()


func _select(enclosure: Enclosure) -> void:
	_clear_selection()
	selected_enclosure = enclosure
	enclosure.selected = true


func _clear_selection() -> void:
	if selected_enclosure != null:
		selected_enclosure.selected = false
	selected_enclosure = null


# --- UI ---------------------------------------------------------------------


func _set_status(text: String) -> void:
	status_label.text = text


func _update_ui() -> void:
	money_label.text = "%d coins" % int(floor(money))
	income_label.text = "+%.1f / s" % total_income()

	var has_space := _first_empty_enclosure() != null \
		or (selected_enclosure != null and selected_enclosure.is_empty())
	egg_button.disabled = money < EGG_COST or not has_space
	egg_button.text = "Buy egg (%d)" % int(EGG_COST)

	_update_pen_button(basic_button, CreatureTraits.Habitat.BASIC)
	_update_pen_button(water_button, CreatureTraits.Habitat.WATER)
	_update_pen_button(alien_button, CreatureTraits.Habitat.ALIEN)

	var scrollable := max_scroll() > 1.0
	scroll_left_button.disabled = not scrollable or scroll_target <= 1.0
	scroll_right_button.disabled = not scrollable or scroll_target >= max_scroll() - 1.0


func _update_pen_button(button: Button, habitat: CreatureTraits.Habitat) -> void:
	if enclosures.size() >= MAX_ENCLOSURES:
		button.disabled = true
		button.text = "%s (full)" % Enclosure.habitat_label(habitat)
		return
	var cost := habitat_cost(habitat)
	button.disabled = money < cost
	button.text = "%s (%d)" % [Enclosure.habitat_label(habitat), int(cost)]


# --- Persistence ------------------------------------------------------------


func _exit_tree() -> void:
	save_game()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()


static func habitat_from_index(index: int) -> CreatureTraits.Habitat:
	match index:
		1:
			return CreatureTraits.Habitat.BASIC
		2:
			return CreatureTraits.Habitat.WATER
		3:
			return CreatureTraits.Habitat.ALIEN
		_:
			return CreatureTraits.Habitat.WILD


func save_game() -> void:
	var pens := []
	for enclosure in enclosures:
		var entry := {
			"habitat": int(enclosure.habitat),
			"decor_seed": enclosure.decor_seed,
		}
		if enclosure.creature != null:
			entry["creature"] = {
				"traits": enclosure.creature.traits.to_dict(),
				"age": enclosure.creature.age,
			}
		pens.append(entry)

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"version": SAVE_VERSION,
		"money": money,
		"pens": pens,
	}))
	file.close()


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return false
	var text := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		return false
	var data := parsed as Dictionary
	if int(data.get("version", 0)) != SAVE_VERSION:
		return false
	var pens: Variant = data.get("pens", [])
	if not pens is Array or (pens as Array).is_empty():
		return false

	money = float(data.get("money", STARTING_MONEY))
	for entry_variant in (pens as Array):
		if not entry_variant is Dictionary:
			continue
		var entry := entry_variant as Dictionary
		var pen := _create_enclosure(
			habitat_from_index(int(entry.get("habitat", 1))),
			int(entry.get("decor_seed", 0))
		)
		if not entry.has("creature"):
			continue
		var creature_data: Variant = entry["creature"]
		if not creature_data is Dictionary:
			continue
		var housed := creature_data as Dictionary
		var saved_traits: Variant = housed.get("traits", {})
		if not saved_traits is Dictionary:
			continue
		_place_creature(pen, CreatureTraits.from_dict(saved_traits as Dictionary))
		if pen.creature != null:
			pen.creature.age = float(housed.get("age", 0.0))

	return not enclosures.is_empty()


func erase_save() -> void:
	var directory := DirAccess.open("user://")
	if directory != null and directory.file_exists(SAVE_FILE_NAME):
		directory.remove(SAVE_FILE_NAME)


func _start_new_zoo() -> void:
	_create_enclosure(CreatureTraits.Habitat.BASIC)
	_create_enclosure(CreatureTraits.Habitat.BASIC)


func _reset_zoo() -> void:
	erase_save()
	_clear_selection()
	for enclosure in enclosures:
		enclosure.clear_creature()
		enclosure_root.remove_child(enclosure)
		enclosure.queue_free()
	enclosures.clear()

	money = STARTING_MONEY
	scroll_offset = 0.0
	scroll_target = 0.0
	_autosave_clock = AUTOSAVE_INTERVAL
	_start_new_zoo()
	_layout_enclosures()
	music.play_for_habitat(newest_habitat())
	_update_ui()


# Erasing wipes real progress, so the button arms itself first and only wipes
# on a second tap within a few seconds.
func _on_erase_pressed() -> void:
	if not _erase_armed:
		_erase_armed = true
		_erase_clock = ERASE_CONFIRM_TIME
		erase_button.text = "Erase? tap again"
		_set_status("This wipes the whole zoo. Tap again to confirm.")
		return

	_disarm_erase()
	_reset_zoo()
	_set_status("Save erased. Starting a fresh zoo.")


func _disarm_erase() -> void:
	_erase_armed = false
	_erase_clock = 0.0
	erase_button.text = "Erase save"
