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
@export_range(-PI, PI, 0.01, "radians") var initial_heading: float = 0.0
@export_range(-PI / 2.0, PI / 2.0, 0.01, "radians") var initial_joint_bend: float = 0.06

@export_group("Anchor")
@export var anchored: bool = false

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
var anchor_position: Vector2 = Vector2.ZERO
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
	var constrained_initial_bend := clampf(
		initial_joint_bend, -angle_constraint, angle_constraint
	)
	spine.set_curved_pose(origin, initial_heading, constrained_initial_bend)
	anchor_position = spine.joints.back()
	_on_spine_created()
	queue_redraw()


func activate() -> void:
	visible = true
	process_mode = Node.PROCESS_MODE_PAUSABLE
	queue_redraw()


func deactivate() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED


func is_active() -> bool:
	return process_mode != Node.PROCESS_MODE_DISABLED


func _process(delta: float) -> void:
	var head := spine.joints[0]
	var offset := get_local_mouse_position() - head
	var target := head
	if not offset.is_zero_approx():
		var distance := minf(movement_speed * delta, offset.length())
		target = head + offset.normalized() * distance

	if anchored:
		spine.fabrik_resolve(target, anchor_position)
	elif target != head:
		spine.resolve(target)
	_after_spine_resolved(delta)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"anchor"):
		toggle_anchor()
		get_viewport().set_input_as_handled()


func toggle_anchor() -> void:
	if not anchored and spine != null and not spine.joints.is_empty():
		anchor_position = spine.joints.back()
	anchored = not anchored


func _draw() -> void:
	if spine == null or spine.joints.size() < _minimum_joint_count():
		return
	_draw_chain_body()
	if debug_chain:
		spine.draw(self)
		_draw_additional_debug_chains()


func _on_spine_created() -> void:
	pass


func _after_spine_resolved(_delta: float) -> void:
	pass


func _draw_additional_debug_chains() -> void:
	pass


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
