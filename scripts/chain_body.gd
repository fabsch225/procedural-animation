@abstract
class_name ChainBody
extends Node2D


@export_group("Body")
@export var body_name: String = "chain body"

@export_group("Movement")
@export_range(2, 128, 1) var joint_count: int = 12
@export_range(1.0, 200.0, 1.0) var link_size: float = 64.0
@export_range(0.0, TAU, 0.01, "radians") var angle_constraint: float = PI / 8.0
@export_range(1.0, 2000.0, 1.0) var movement_speed: float = 480.0
@export var start_at_viewport_center: bool = true

@export_group("Shared Appearance")
@export var body_color: Color = Color.WHITE
@export var outline_color: Color = Color.WHITE
@export_range(0.0, 32.0, 0.5) var outline_width: float = 4.0
@export_range(1, 64, 1) var processing_curve_resolution: int = 16
@export var processing_adaptive_curves: bool = true
@export_range(0.01, 2.0, 0.01) var processing_curve_tolerance: float = 0.35
@export_range(1.0, 64.0, 1.0) var eye_radius: float = 12.0
@export var debug_chain: bool = false

var spine: Chain
var _native_tessellator: Object
var _native_tessellator_checked: bool = false
var _native_error_reported: bool = false


@abstract func _minimum_joint_count() -> int
@abstract func _body_radius(index: int) -> float
@abstract func _draw_chain_body() -> void


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	var required_joint_count := _minimum_joint_count()
	if joint_count < required_joint_count:
		push_warning(
			"%s requires at least %d joints; increasing Joint Count from %d."
			% [body_name, required_joint_count, joint_count]
		)
		joint_count = required_joint_count

	var origin := Vector2.ZERO
	if start_at_viewport_center:
		origin = to_local(
			get_viewport().get_canvas_transform().affine_inverse()
			* get_viewport_rect().get_center()
		)
	spine = Chain.new(origin, joint_count, link_size, angle_constraint)
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
	if spine == null or spine.joints.size() < _minimum_joint_count():
		return
	_draw_chain_body()
	if debug_chain:
		spine.draw(self)


func _body_position(
	index: int,
	angle_offset: float,
	length_offset: float = 0.0
) -> Vector2:
	return spine.joints[index] + Vector2.from_angle(
		spine.angles[index] + angle_offset
	) * (_body_radius(index) + length_offset)


func _draw_standard_eyes(length_offset: float = -18.0) -> void:
	draw_circle(_body_position(0, PI / 2.0, length_offset), eye_radius, Color.WHITE)
	draw_circle(_body_position(0, -PI / 2.0, length_offset), eye_radius, Color.WHITE)


func _new_processing_shape() -> ProcessingShape2D:
	var shape := ProcessingShape2D.new()
	shape.curve_resolution = processing_curve_resolution
	shape.adaptive_curve_flattening = processing_adaptive_curves
	shape.curve_tolerance = processing_curve_tolerance
	return shape


func _draw_filled_path(path: PackedVector2Array, color: Color) -> void:
	var triangles := _tessellate_path(path)
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


func _tessellate_path(path: PackedVector2Array) -> PackedVector2Array:
	var native := _get_native_tessellator()
	if native != null:
		var result: Variant = native.call(&"tessellate", path)
		if result is PackedVector2Array:
			return result as PackedVector2Array
	if not _native_error_reported:
		push_error(
			"Native tessellator is unavailable for %s. Build " % body_name
			+ "native/non_zero_tessellator before using this body."
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


func get_tessellator_backend() -> StringName:
	return &"gdextension" if _get_native_tessellator() != null else &"unavailable"
