class_name HabitatDecor
extends Node2D


# Procedural, always-moving scenery for one pen. Everything is generated from
# a seed at setup and animated with a shared clock, so no two pens look alike
# and nothing is ever static.


const GROUND_RATIO: float = 0.16

var habitat: CreatureTraits.Habitat = CreatureTraits.Habitat.BASIC
var area: Rect2 = Rect2(-160.0, -110.0, 320.0, 220.0)

var _time: float = 0.0
var _plants: Array[Dictionary] = []
var _blobs: Array[Dictionary] = []
var _motes: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func setup(
	new_habitat: CreatureTraits.Habitat,
	new_area: Rect2,
	decor_seed: int
) -> void:
	habitat = new_habitat
	area = new_area
	_rng.seed = decor_seed if decor_seed != 0 else 1
	_build()
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


# --- Generation -------------------------------------------------------------


func _build() -> void:
	_plants.clear()
	_blobs.clear()
	_motes.clear()

	match habitat:
		CreatureTraits.Habitat.WATER:
			_build_reef()
		CreatureTraits.Habitat.ALIEN:
			_build_void()
		_:
			_build_meadow()


func _ground_y() -> float:
	return area.end.y - area.size.y * GROUND_RATIO


func _random_x(inset: float = 24.0) -> float:
	return _rng.randf_range(area.position.x + inset, area.end.x - inset)


func _build_meadow() -> void:
	var tuft_count := int(round(area.size.x / 46.0))
	for i in range(tuft_count):
		_plants.append({
			"kind": "tuft",
			"position": Vector2(_random_x(), _ground_y() + _rng.randf_range(-16.0, 26.0)),
			"blades": _rng.randi_range(3, 6),
			"length": _rng.randf_range(0.09, 0.2) * area.size.y,
			"width": _rng.randf_range(4.0, 8.0),
			"lean": _rng.randf_range(-0.35, 0.35),
			"phase": _rng.randf() * TAU,
			"speed": _rng.randf_range(0.7, 1.5),
			"color": Color.from_hsv(
				_rng.randf_range(0.22, 0.36), _rng.randf_range(0.35, 0.6),
				_rng.randf_range(0.34, 0.58)
			),
		})

	for i in range(_rng.randi_range(2, 4)):
		_blobs.append({
			"kind": "bush",
			"position": Vector2(_random_x(60.0), _ground_y() + _rng.randf_range(-8.0, 20.0)),
			"radius": _rng.randf_range(0.06, 0.11) * area.size.y,
			"lobes": _rng.randi_range(4, 6),
			"phase": _rng.randf() * TAU,
			"color": Color.from_hsv(
				_rng.randf_range(0.24, 0.34), _rng.randf_range(0.4, 0.65),
				_rng.randf_range(0.26, 0.42)
			),
		})

	for i in range(_rng.randi_range(3, 6)):
		_plants.append({
			"kind": "flower",
			"position": Vector2(_random_x(40.0), _ground_y() + _rng.randf_range(-10.0, 22.0)),
			"length": _rng.randf_range(0.12, 0.24) * area.size.y,
			"width": 3.5,
			"lean": _rng.randf_range(-0.3, 0.3),
			"phase": _rng.randf() * TAU,
			"speed": _rng.randf_range(0.6, 1.2),
			"petals": _rng.randi_range(5, 8),
			"petal_radius": _rng.randf_range(6.0, 11.0),
			"color": Color.from_hsv(0.3, 0.45, 0.4),
			"bloom_color": Color.from_hsv(
				_rng.randf(), _rng.randf_range(0.5, 0.85), _rng.randf_range(0.8, 1.0)
			),
		})


func _build_reef() -> void:
	var kelp_count := int(round(area.size.x / 62.0))
	for i in range(kelp_count):
		_plants.append({
			"kind": "kelp",
			"position": Vector2(_random_x(20.0), area.end.y - _rng.randf_range(0.0, 20.0)),
			"blades": _rng.randi_range(2, 4),
			"length": _rng.randf_range(0.3, 0.72) * area.size.y,
			"width": _rng.randf_range(7.0, 15.0),
			"lean": _rng.randf_range(-0.25, 0.25),
			"phase": _rng.randf() * TAU,
			"speed": _rng.randf_range(0.5, 0.9),
			"color": Color.from_hsv(
				_rng.randf_range(0.33, 0.47), _rng.randf_range(0.45, 0.75),
				_rng.randf_range(0.35, 0.6)
			),
		})

	for i in range(_rng.randi_range(2, 4)):
		_plants.append({
			"kind": "coral",
			"position": Vector2(_random_x(50.0), _ground_y() + _rng.randf_range(0.0, 24.0)),
			"length": _rng.randf_range(0.14, 0.26) * area.size.y,
			"width": _rng.randf_range(8.0, 14.0),
			"lean": _rng.randf_range(-0.2, 0.2),
			"phase": _rng.randf() * TAU,
			"speed": _rng.randf_range(0.4, 0.8),
			"color": Color.from_hsv(
				_rng.randf_range(0.9, 1.0) if _rng.randf() < 0.6 else _rng.randf_range(0.02, 0.09),
				_rng.randf_range(0.5, 0.8), _rng.randf_range(0.7, 0.95)
			),
		})

	for i in range(_rng.randi_range(3, 5)):
		_blobs.append({
			"kind": "rock",
			"position": Vector2(_random_x(30.0), area.end.y - _rng.randf_range(2.0, 26.0)),
			"radius": _rng.randf_range(0.05, 0.1) * area.size.y,
			"lobes": 1,
			"phase": 0.0,
			"color": Color.from_hsv(
				_rng.randf_range(0.5, 0.62), _rng.randf_range(0.12, 0.3),
				_rng.randf_range(0.24, 0.38)
			),
		})

	for i in range(14):
		_motes.append({
			"x": _random_x(12.0),
			"wobble": _rng.randf_range(6.0, 22.0),
			"radius": _rng.randf_range(2.5, 7.0),
			"speed": _rng.randf_range(0.06, 0.18),
			"offset": _rng.randf(),
		})


func _build_void() -> void:
	var crystal_count := int(round(area.size.x / 58.0))
	for i in range(crystal_count):
		_plants.append({
			"kind": "crystal",
			"position": Vector2(_random_x(18.0), area.end.y - _rng.randf_range(0.0, 26.0)),
			"length": _rng.randf_range(0.12, 0.4) * area.size.y,
			"width": _rng.randf_range(9.0, 22.0),
			"lean": _rng.randf_range(-0.4, 0.4),
			"phase": _rng.randf() * TAU,
			"speed": _rng.randf_range(0.8, 1.8),
			"color": Color.from_hsv(
				_rng.randf_range(0.7, 0.95), _rng.randf_range(0.4, 0.7),
				_rng.randf_range(0.55, 0.85)
			),
		})

	for i in range(_rng.randi_range(3, 5)):
		_plants.append({
			"kind": "frond",
			"position": Vector2(_random_x(40.0), _ground_y() + _rng.randf_range(-4.0, 26.0)),
			"length": _rng.randf_range(0.2, 0.42) * area.size.y,
			"width": _rng.randf_range(4.0, 8.0),
			"lean": _rng.randf_range(-0.5, 0.5),
			"phase": _rng.randf() * TAU,
			"speed": _rng.randf_range(0.5, 1.1),
			"petal_radius": _rng.randf_range(7.0, 14.0),
			"color": Color.from_hsv(
				_rng.randf_range(0.24, 0.42), _rng.randf_range(0.45, 0.8),
				_rng.randf_range(0.5, 0.8)
			),
			"bloom_color": Color.from_hsv(
				_rng.randf_range(0.16, 0.34), _rng.randf_range(0.5, 0.9), 1.0
			),
		})

	for i in range(_rng.randi_range(4, 7)):
		_motes.append({
			"x": _random_x(30.0),
			"y": _rng.randf_range(area.position.y + 30.0, _ground_y()),
			"wobble": _rng.randf_range(18.0, 60.0),
			"radius": _rng.randf_range(5.0, 12.0),
			"speed": _rng.randf_range(0.3, 0.8),
			"offset": _rng.randf() * TAU,
			"color": Color.from_hsv(
				_rng.randf_range(0.14, 0.36), _rng.randf_range(0.4, 0.8), 1.0
			),
		})


# --- Drawing ----------------------------------------------------------------


func _draw() -> void:
	_draw_ground()
	for blob in _blobs:
		_draw_blob(blob)
	for plant in _plants:
		_draw_plant(plant)
	_draw_motes()


func _draw_ground() -> void:
	var ground_top := _ground_y()
	var rect := Rect2(
		Vector2(area.position.x, ground_top),
		Vector2(area.size.x, area.end.y - ground_top)
	)
	draw_rect(rect, _ground_color(), true)

	# A soft, uneven lip so the ground does not read as a flat bar.
	var lip := PackedVector2Array()
	var steps := 24
	for i in range(steps + 1):
		var weight := float(i) / float(steps)
		var x := lerpf(area.position.x, area.end.x, weight)
		var bump := sin(weight * 9.0 + _time * 0.25) * 5.0 + cos(weight * 21.0) * 3.0
		lip.append(Vector2(x, ground_top + bump))
	lip.append(Vector2(area.end.x, area.end.y))
	lip.append(Vector2(area.position.x, area.end.y))
	draw_colored_polygon(lip, _ground_color())


func _ground_color() -> Color:
	match habitat:
		CreatureTraits.Habitat.WATER:
			return Color(0.13, 0.24, 0.3)
		CreatureTraits.Habitat.ALIEN:
			return Color(0.17, 0.11, 0.24)
		_:
			return Color(0.16, 0.22, 0.16)


func _draw_blob(blob: Dictionary) -> void:
	var center: Vector2 = blob["position"]
	var radius: float = blob["radius"]
	var lobes: int = blob["lobes"]
	var color: Color = blob["color"]

	if lobes <= 1:
		draw_circle(center, radius, color)
		return

	var breathe := 1.0 + 0.04 * sin(_time * 0.9 + float(blob["phase"]))
	for lobe in range(lobes):
		var angle := TAU * float(lobe) / float(lobes)
		var offset := Vector2.from_angle(angle) * radius * 0.55
		draw_circle(center + offset, radius * 0.62 * breathe, color)
	draw_circle(center, radius * 0.85 * breathe, color)


func _draw_plant(plant: Dictionary) -> void:
	match String(plant["kind"]):
		"tuft":
			_draw_tuft(plant)
		"kelp":
			_draw_tuft(plant)
		"coral":
			_draw_coral(plant)
		"crystal":
			_draw_crystal(plant)
		"flower":
			_draw_flower(plant)
		"frond":
			_draw_flower(plant)


func _sway(plant: Dictionary, extra: float = 0.0) -> float:
	return sin(_time * float(plant["speed"]) + float(plant["phase"]) + extra)


func _draw_tuft(plant: Dictionary) -> void:
	var base: Vector2 = plant["position"]
	var blades: int = plant["blades"]
	var length: float = plant["length"]
	var width: float = plant["width"]
	var lean: float = plant["lean"]
	var color: Color = plant["color"]

	for blade in range(blades):
		var spread := 0.0
		if blades > 1:
			spread = lerpf(-0.5, 0.5, float(blade) / float(blades - 1))
		var wave := _sway(plant, float(blade) * 0.6) * 0.35
		var polygon := _taper(
			base + Vector2(spread * width * 1.6, 0.0),
			-PI / 2.0 + lean * 0.4 + spread * 0.35,
			length * lerpf(0.7, 1.0, 1.0 - absf(spread)),
			lean + wave,
			width,
			0.03,
			8
		)
		draw_colored_polygon(polygon, color)


func _draw_coral(plant: Dictionary) -> void:
	var base: Vector2 = plant["position"]
	var length: float = plant["length"]
	var width: float = plant["width"]
	var color: Color = plant["color"]
	var wave := _sway(plant) * 0.18

	draw_colored_polygon(
		_taper(base, -PI / 2.0, length, float(plant["lean"]) + wave, width, 0.35, 8), color
	)
	for side_index in range(2):
		var side := 1.0 if side_index == 0 else -1.0
		var branch_base := base + Vector2(0.0, -length * 0.55)
		draw_colored_polygon(
			_taper(
				branch_base,
				-PI / 2.0 + side * 0.7,
				length * 0.6,
				side * 0.5 + wave,
				width * 0.7,
				0.25,
				8
			),
			color
		)


func _draw_crystal(plant: Dictionary) -> void:
	var base: Vector2 = plant["position"]
	var length: float = plant["length"]
	var width: float = plant["width"]
	var color: Color = plant["color"]
	var pulse := 0.5 + 0.5 * sin(_time * float(plant["speed"]) + float(plant["phase"]))
	var direction := -PI / 2.0 + float(plant["lean"]) * 0.5
	var tip := base + Vector2.from_angle(direction) * length
	var normal := Vector2.from_angle(direction + PI / 2.0) * width

	draw_colored_polygon(
		PackedVector2Array([
			base + normal,
			base + normal * 0.4 + Vector2.from_angle(direction) * length * 0.55,
			tip,
			base - normal * 0.4 + Vector2.from_angle(direction) * length * 0.55,
			base - normal,
		]),
		color.lerp(Color.WHITE, 0.1 + 0.25 * pulse)
	)
	draw_colored_polygon(
		PackedVector2Array([
			base + normal * 0.35,
			tip,
			base - normal * 0.15,
		]),
		color.lerp(Color.WHITE, 0.45 + 0.35 * pulse)
	)


func _draw_flower(plant: Dictionary) -> void:
	var base: Vector2 = plant["position"]
	var length: float = plant["length"]
	var width: float = plant["width"]
	var color: Color = plant["color"]
	var bloom_color: Color = plant["bloom_color"]
	var petal_radius: float = plant["petal_radius"]
	var wave := _sway(plant) * 0.45
	var curve := float(plant["lean"]) + wave

	var stem := _taper(base, -PI / 2.0, length, curve, width, 0.4, 10)
	draw_colored_polygon(stem, color)

	var tip := _axis_tip(base, -PI / 2.0, length, curve, 10)
	var pulse := 0.85 + 0.15 * sin(_time * 1.6 + float(plant["phase"]))
	var petals := int(plant.get("petals", 6))
	for petal in range(petals):
		var angle := TAU * float(petal) / float(petals) + _time * 0.2
		draw_circle(
			tip + Vector2.from_angle(angle) * petal_radius * 1.05,
			petal_radius * 0.72 * pulse,
			bloom_color
		)
	draw_circle(tip, petal_radius * 0.8, bloom_color.lerp(Color.WHITE, 0.35))


func _draw_motes() -> void:
	if habitat == CreatureTraits.Habitat.WATER:
		for mote in _motes:
			var travel := fposmod(_time * float(mote["speed"]) + float(mote["offset"]), 1.0)
			var y := lerpf(area.end.y, area.position.y + 8.0, travel)
			var x := float(mote["x"]) + sin(travel * 9.0 + float(mote["offset"]) * TAU) \
				* float(mote["wobble"])
			var fade := clampf(1.0 - travel, 0.0, 1.0)
			draw_circle(
				Vector2(x, y), float(mote["radius"]), Color(0.8, 0.94, 1.0, 0.16 + 0.24 * fade)
			)
		return

	if habitat == CreatureTraits.Habitat.ALIEN:
		for mote in _motes:
			var phase := _time * float(mote["speed"]) + float(mote["offset"])
			var center := Vector2(
				float(mote["x"]) + sin(phase) * float(mote["wobble"]),
				float(mote["y"]) + cos(phase * 0.7) * float(mote["wobble"]) * 0.5
			)
			var color: Color = mote["color"]
			var glow := color
			glow.a = 0.18
			draw_circle(center, float(mote["radius"]) * 2.4, glow)
			draw_circle(center, float(mote["radius"]), color)


# --- Geometry ---------------------------------------------------------------


func _taper(
	base: Vector2,
	direction: float,
	length: float,
	curve: float,
	width: float,
	tip_ratio: float,
	segments: int
) -> PackedVector2Array:
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var position := base
	var angle := direction
	var step := length / float(maxi(1, segments))

	for i in range(segments + 1):
		var t := float(i) / float(segments)
		var half_width := lerpf(width, width * tip_ratio, pow(t, 0.85))
		var normal := Vector2.from_angle(angle + PI / 2.0) * half_width
		left.append(position + normal)
		right.append(position - normal)
		position += Vector2.from_angle(angle) * step
		angle += curve / float(maxi(1, segments))

	var polygon := left.duplicate()
	for i in range(right.size() - 1, -1, -1):
		polygon.append(right[i])
	return polygon


func _axis_tip(
	base: Vector2,
	direction: float,
	length: float,
	curve: float,
	segments: int
) -> Vector2:
	var position := base
	var angle := direction
	var step := length / float(maxi(1, segments))
	for i in range(segments):
		position += Vector2.from_angle(angle) * step
		angle += curve / float(maxi(1, segments))
	return position
