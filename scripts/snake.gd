class_name Snake
extends Node2D


enum OutlineMode {
	SILHOUETTE,
	OVERLAPPING,
}

@export_group("Movement")
@export_range(2, 128, 1) var joint_count: int = 48
@export_range(1.0, 200.0, 1.0) var link_size: float = 64.0
@export_range(0.0, TAU, 0.01, "radians") var angle_constraint: float = PI / 8.0
@export_range(1.0, 2000.0, 1.0) var movement_speed: float = 480.0
@export var start_at_viewport_center: bool = true

@export_group("Appearance")
@export var body_color: Color = Color8(172, 57, 49)
@export var outline_color: Color = Color.WHITE
@export var outline_mode: OutlineMode = OutlineMode.SILHOUETTE
@export_range(0.0, 32.0, 0.5) var outline_width: float = 4.0
@export_range(1, 8, 1) var curve_subdivisions: int = 3
@export_range(1.0, 64.0, 1.0) var eye_radius: float = 12.0
@export var debug_chain: bool = false

var spine: Chain


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	var origin := Vector2.ZERO
	if start_at_viewport_center:
		origin = to_local(get_viewport().get_canvas_transform().affine_inverse() * get_viewport_rect().get_center())
	spine = Chain.new(origin, joint_count, link_size, angle_constraint)
	queue_redraw()


func _process(delta: float) -> void:
	var head := spine.joints[0]
	var offset := get_local_mouse_position() - head

	if not offset.is_zero_approx():
		var distance := minf(movement_speed * delta, offset.length())
		spine.resolve(head + offset.normalized() * distance)

	queue_redraw()


func _draw() -> void:
	if spine == null or spine.joints.size() < 2:
		return

	var samples := _build_body_samples()
	# Every piece is convex, so self-crossings never require triangulating one
	# large, self-intersecting outline. Draw from tail to head for stable overlap.
	if outline_mode == OutlineMode.SILHOUETTE:
		_draw_body(samples, 0.0, outline_color)
		_draw_body(samples, outline_width, body_color)
	else:
		_draw_body(samples, 0.0, body_color)
		_draw_overlapping_outline(samples)

	_draw_eyes()
	if debug_chain:
		spine.draw(self)


func _draw_body(samples: Array[BodySample], inset: float, color: Color) -> void:
	for i in range(samples.size() - 2, -1, -1):
		_draw_tapered_capsule(
			samples[i].position,
			samples[i + 1].position,
			maxf(0.0, samples[i].radius - inset),
			maxf(0.0, samples[i + 1].radius - inset),
			color
		)


func _draw_overlapping_outline(samples: Array[BodySample]) -> void:
	if outline_width <= 0.0:
		return

	var outline := PackedVector2Array()
	var last_sample := samples.size() - 1

	# First side, from head to tail.
	for i in range(samples.size()):
		outline.append(samples[i].position + _sample_normal(samples, i) * samples[i].radius)

	# Rounded tail, continuing around the end of the centerline.
	var tail_normal := _sample_normal(samples, last_sample)
	var tail_angle := tail_normal.angle()
	for step in range(1, 9):
		var angle := tail_angle + PI * float(step) / 8.0
		outline.append(samples[last_sample].position + Vector2.from_angle(angle) * samples[last_sample].radius)

	# Opposite side, from tail back to head.
	for i in range(last_sample - 1, -1, -1):
		outline.append(samples[i].position - _sample_normal(samples, i) * samples[i].radius)

	# Rounded head. Going through the reverse tangent closes the outer contour.
	var head_normal := _sample_normal(samples, 0)
	var head_angle := (-head_normal).angle()
	for step in range(1, 9):
		var angle := head_angle + PI * float(step) / 8.0
		outline.append(samples[0].position + Vector2.from_angle(angle) * samples[0].radius)

	outline.append(outline[0])
	draw_polyline(outline, outline_color, outline_width, true)


func _sample_normal(samples: Array[BodySample], index: int) -> Vector2:
	var previous := samples[maxi(0, index - 1)].position
	var next := samples[mini(samples.size() - 1, index + 1)].position
	var tangent := next - previous
	if tangent.is_zero_approx():
		return Vector2.UP
	return tangent.normalized().orthogonal()


func _build_body_samples() -> Array[BodySample]:
	var samples: Array[BodySample] = []
	var last_joint := spine.joints.size() - 1

	for i in range(last_joint):
		var p0 := spine.joints[maxi(i - 1, 0)]
		var p1 := spine.joints[i]
		var p2 := spine.joints[i + 1]
		var p3 := spine.joints[mini(i + 2, last_joint)]

		for step in range(curve_subdivisions):
			var weight := float(step) / float(curve_subdivisions)
			var position := _catmull_rom(p0, p1, p2, p3, weight)
			var radius := lerpf(_body_radius(i), _body_radius(i + 1), weight)
			samples.append(BodySample.new(position, radius))

	samples.append(BodySample.new(spine.joints[last_joint], _body_radius(last_joint)))
	return samples


func _draw_tapered_capsule(
	start: Vector2,
	end: Vector2,
	start_radius: float,
	end_radius: float,
	color: Color
) -> void:
	var direction := end - start
	if direction.is_zero_approx():
		return

	var normal := direction.normalized().orthogonal()
	_draw_tapered_segment(start, end, normal, start_radius, end_radius, color)
	draw_circle(start, start_radius, color)
	draw_circle(end, end_radius, color)


func _draw_tapered_segment(
	start: Vector2,
	end: Vector2,
	normal: Vector2,
	start_radius: float,
	end_radius: float,
	color: Color
) -> void:
	var quad := PackedVector2Array([
		start + normal * start_radius,
		end + normal * end_radius,
		end - normal * end_radius,
		start - normal * start_radius,
	])
	draw_colored_polygon(quad, color)


func _draw_eyes() -> void:
	var head_angle := spine.angles[0]
	var eye_distance := maxf(0.0, _body_radius(0) - 18.0)
	var left_eye := spine.joints[0] + Vector2.from_angle(head_angle + PI / 2.0) * eye_distance
	var right_eye := spine.joints[0] + Vector2.from_angle(head_angle - PI / 2.0) * eye_distance
	draw_circle(left_eye, eye_radius, Color.WHITE)
	draw_circle(right_eye, eye_radius, Color.WHITE)


func _body_radius(index: int) -> float:
	match index:
		0:
			return 76.0
		1:
			return 80.0
		_:
			return maxf(4.0, 64.0 - index)


func _catmull_rom(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, weight: float) -> Vector2:
	var weight_squared := weight * weight
	var weight_cubed := weight_squared * weight
	return 0.5 * (
		2.0 * p1
		+ (-p0 + p2) * weight
		+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * weight_squared
		+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * weight_cubed
	)


class BodySample:
	var position: Vector2
	var radius: float

	func _init(position_: Vector2, radius_: float) -> void:
		position = position_
		radius = radius_
