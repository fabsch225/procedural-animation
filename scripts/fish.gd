class_name Fish
extends Node2D


const JOINT_COUNT: int = 12
const BODY_JOINT_COUNT: int = 10

@export_group("Body")
@export var body_name: String = "fish"

@export_group("Movement")
@export_range(1.0, 200.0, 1.0) var link_size: float = 64.0
@export_range(0.0, TAU, 0.01, "radians") var angle_constraint: float = PI / 8.0
@export_range(1.0, 2000.0, 1.0) var movement_speed: float = 960.0
@export var start_at_viewport_center: bool = true

@export_group("Appearance")
@export var body_color: Color = Color8(58, 124, 165)
@export var fin_color: Color = Color8(129, 195, 215)
@export var outline_color: Color = Color.WHITE
@export_range(0.0, 32.0, 0.5) var outline_width: float = 4.0
@export var body_widths: Array[float] = [
	68.0, 81.0, 84.0, 83.0, 77.0, 64.0, 51.0, 38.0, 32.0, 19.0,
]
@export_range(1, 64, 1) var processing_curve_resolution: int = 16
@export var processing_adaptive_curves: bool = true
@export_range(0.01, 2.0, 0.01) var processing_curve_tolerance: float = 0.35
@export_range(8, 96, 1) var ellipse_resolution: int = 40
@export_range(1.0, 64.0, 1.0) var eye_radius: float = 12.0
@export var debug_chain: bool = false

var spine: Chain
var _native_tessellator: Object
var _native_tessellator_checked: bool = false
var _native_error_reported: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	var origin := Vector2.ZERO
	if start_at_viewport_center:
		origin = to_local(
			get_viewport().get_canvas_transform().affine_inverse()
			* get_viewport_rect().get_center()
		)
	spine = Chain.new(origin, JOINT_COUNT, link_size, angle_constraint)
	queue_redraw()


func activate() -> void:
	visible = true
	process_mode = Node.PROCESS_MODE_PAUSABLE


func deactivate() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED


func is_active() -> bool:
	return process_mode != Node.PROCESS_MODE_DISABLED


func _process(delta: float) -> void:
	var head := spine.joints[0]
	var offset := get_local_mouse_position() - head
	if not offset.is_zero_approx():
		var distance := minf(movement_speed * delta, offset.length())
		spine.resolve(head + offset.normalized() * distance)
	queue_redraw()


func _draw() -> void:
	if spine == null or spine.joints.size() < JOINT_COUNT:
		return

	var angles := spine.angles
	var head_to_mid_1 := Util.relative_angle_diff(angles[0], angles[6])
	var head_to_mid_2 := Util.relative_angle_diff(angles[0], angles[7])
	var head_to_tail := head_to_mid_1 + Util.relative_angle_diff(angles[6], angles[11])

	_draw_ellipse(
		_body_position(3, PI / 3.0), Vector2(160.0, 64.0),
		angles[2] - PI / 4.0, fin_color
	)
	_draw_ellipse(
		_body_position(3, -PI / 3.0), Vector2(160.0, 64.0),
		angles[2] + PI / 4.0, fin_color
	)
	_draw_ellipse(
		_body_position(7, PI / 2.0), Vector2(96.0, 32.0),
		angles[6] - PI / 4.0, fin_color
	)
	_draw_ellipse(
		_body_position(7, -PI / 2.0), Vector2(96.0, 32.0),
		angles[6] + PI / 4.0, fin_color
	)

	_draw_filled_path(_build_caudal_fin(head_to_tail), fin_color)
	_draw_filled_path(_build_body_outline(), body_color)
	_draw_filled_path(_build_dorsal_fin(head_to_mid_1, head_to_mid_2), fin_color)

	draw_circle(_body_position(0, PI / 2.0, -18.0), eye_radius, Color.WHITE)
	draw_circle(_body_position(0, -PI / 2.0, -18.0), eye_radius, Color.WHITE)

	if debug_chain:
		spine.draw(self)


func _build_caudal_fin(head_to_tail: float) -> PackedVector2Array:
	var shape := _new_processing_shape()
	shape.begin_shape()
	for i in range(8, JOINT_COUNT):
		var distance_from_body := float(i - 8)
		var tail_width := 1.5 * head_to_tail * distance_from_body * distance_from_body
		shape.curve_vertex(
			spine.joints[i]
			+ Vector2.from_angle(spine.angles[i] - PI / 2.0) * tail_width
		)
	for i in range(JOINT_COUNT - 1, 7, -1):
		var tail_width := clampf(head_to_tail * 6.0, -13.0, 13.0)
		shape.curve_vertex(
			spine.joints[i]
			+ Vector2.from_angle(spine.angles[i] + PI / 2.0) * tail_width
		)
	return shape.end_shape(true)


func _build_body_outline() -> PackedVector2Array:
	var shape := _new_processing_shape()
	shape.begin_shape()
	for i in range(BODY_JOINT_COUNT):
		shape.curve_vertex(_body_position(i, PI / 2.0))
	shape.curve_vertex(_body_position(BODY_JOINT_COUNT - 1, PI))
	for i in range(BODY_JOINT_COUNT - 1, -1, -1):
		shape.curve_vertex(_body_position(i, -PI / 2.0))
	shape.curve_vertex(_body_position(0, -PI / 6.0))
	shape.curve_vertex(_body_position(0, 0.0, 4.0))
	shape.curve_vertex(_body_position(0, PI / 6.0))
	for i in range(3):
		shape.curve_vertex(_body_position(i, PI / 2.0))
	return shape.end_shape(true)


func _build_dorsal_fin(head_to_mid_1: float, head_to_mid_2: float) -> PackedVector2Array:
	var joints := spine.joints
	var angles := spine.angles
	var shape := _new_processing_shape()
	shape.begin_shape()
	shape.vertex(joints[4])
	shape.bezier_vertex(joints[5], joints[6], joints[7])
	shape.bezier_vertex(
		joints[6] + Vector2.from_angle(angles[6] + PI / 2.0) * head_to_mid_2 * 16.0,
		joints[5] + Vector2.from_angle(angles[5] + PI / 2.0) * head_to_mid_1 * 16.0,
		joints[4]
	)
	return shape.end_shape()


func _new_processing_shape() -> ProcessingShape2D:
	var shape := ProcessingShape2D.new()
	shape.curve_resolution = processing_curve_resolution
	shape.adaptive_curve_flattening = processing_adaptive_curves
	shape.curve_tolerance = processing_curve_tolerance
	return shape


func _body_position(index: int, angle_offset: float, length_offset: float = 0.0) -> Vector2:
	return spine.joints[index] + Vector2.from_angle(
		spine.angles[index] + angle_offset
	) * (_body_width(index) + length_offset)


func _body_width(index: int) -> float:
	if index < 0 or index >= body_widths.size():
		return 0.0
	return body_widths[index]


func _draw_ellipse(center: Vector2, size: Vector2, rotation: float, color: Color) -> void:
	var points := PackedVector2Array()
	var half_size := size * 0.5
	for step in range(ellipse_resolution):
		var angle := TAU * float(step) / float(ellipse_resolution)
		var local_point := Vector2(cos(angle) * half_size.x, sin(angle) * half_size.y)
		points.append(center + local_point.rotated(rotation))
	draw_colored_polygon(points, color)
	if outline_width > 0.0:
		points.append(points[0])
		draw_polyline(points, outline_color, outline_width, true)


func _draw_filled_path(path: PackedVector2Array, color: Color) -> void:
	var triangles := _tessellate(path)
	if not triangles.is_empty():
		var indices := PackedInt32Array()
		indices.resize(triangles.size())
		for i in range(indices.size()):
			indices[i] = i
		var colors := PackedColorArray()
		colors.resize(triangles.size())
		colors.fill(color)
		RenderingServer.canvas_item_add_triangle_array(
			get_canvas_item(), indices, triangles, colors
		)
	if path.size() >= 2 and outline_width > 0.0:
		draw_polyline(path, outline_color, outline_width, true)


func _tessellate(path: PackedVector2Array) -> PackedVector2Array:
	var native := _get_native_tessellator()
	if native != null:
		var result: Variant = native.call(&"tessellate", path)
		if result is PackedVector2Array:
			return result as PackedVector2Array
	if not _native_error_reported:
		push_error(
			"Native fish tessellator is unavailable. Build "
			+ "native/non_zero_tessellator before using Fish."
		)
		_native_error_reported = true
	return PackedVector2Array()


func _get_native_tessellator() -> Object:
	if is_instance_valid(_native_tessellator):
		return _native_tessellator
	if _native_tessellator_checked:
		return null
	_native_tessellator_checked = true
	if ClassDB.class_exists(&"NonZeroPathTessellatorNative"):
		_native_tessellator = ClassDB.instantiate(&"NonZeroPathTessellatorNative")
	return _native_tessellator
