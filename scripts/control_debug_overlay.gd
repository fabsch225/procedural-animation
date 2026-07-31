class_name ControlDebugOverlay
extends Control


@export var debug_enabled: bool = false:
	set(value):
		debug_enabled = value
		visible = value
		set_process(value)
		queue_redraw()
@export var show_labels: bool = true
@export var bounds_color: Color = Color(0.1, 0.9, 1.0, 0.9)
@export var label_color: Color = Color.WHITE
@export var label_background_color: Color = Color(0.04, 0.06, 0.08, 0.9)
@export_range(1.0, 6.0, 0.5) var bounds_width: float = 2.0
@export_range(8, 32, 1) var label_font_size: int = 13


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = debug_enabled
	set_process(debug_enabled)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if not debug_enabled:
		return
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return

	var overlay_inverse := get_global_transform_with_canvas().affine_inverse()
	var controls := scene_root.find_children("*", "Control", true, false)
	if scene_root is Control:
		controls.push_front(scene_root)
	for node in controls:
		var control := node as Control
		if not _should_draw_control(control):
			continue
		_draw_control_bounds(control, overlay_inverse)


func _should_draw_control(control: Control) -> bool:
	return control != null \
		and control != self \
		and not is_ancestor_of(control) \
		and control.get_viewport() == get_viewport() \
		and control.is_visible_in_tree() \
		and control.size.x > 0.0 \
		and control.size.y > 0.0


func _draw_control_bounds(control: Control, overlay_inverse: Transform2D) -> void:
	var to_overlay := overlay_inverse * control.get_global_transform_with_canvas()
	var control_size := control.size
	var corners := PackedVector2Array([
		to_overlay * Vector2.ZERO,
		to_overlay * Vector2(control_size.x, 0.0),
		to_overlay * control_size,
		to_overlay * Vector2(0.0, control_size.y),
	])
	var outline := corners.duplicate()
	outline.append(corners[0])
	draw_polyline(outline, bounds_color, bounds_width, true)

	if show_labels:
		_draw_control_label(control, corners)


func _draw_control_label(control: Control, corners: PackedVector2Array) -> void:
	var bounds := Rect2(corners[0], Vector2.ZERO)
	for corner in corners:
		bounds = bounds.expand(corner)
	var label := "%s  %d × %d" % [
		control.name, roundi(control.size.x), roundi(control.size.y)
	]
	var font := ThemeDB.fallback_font
	var text_size := font.get_string_size(
		label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, label_font_size
	)
	var baseline := bounds.position + Vector2(3.0, -4.0)
	if baseline.y - text_size.y < 0.0:
		baseline.y = bounds.position.y + text_size.y + 4.0
	var background := Rect2(
		baseline - Vector2(2.0, text_size.y),
		text_size + Vector2(4.0, 3.0)
	)
	draw_rect(background, label_background_color)
	draw_string(
		font,
		baseline,
		label,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		label_font_size,
		label_color
	)
