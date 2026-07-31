class_name Pointer
extends HotswapMouseCursor


@export_group("Pointer Mode")
@export var hotswap_enabled: bool = true
@export var override_cursor: Texture2D
@export var override_hotspot: Vector2 = Vector2.ZERO

@export_group("Pointing Hand Override")
@export var pointing_hand_override: Texture2D
@export var pointing_hand_hotspot: Vector2 = Vector2.ZERO

@onready var file_name_label: Label = $FileNameLabel


func _ready() -> void:
	if hotswap_enabled:
		file_name_label.visible = true
		super._ready()
		cursor_changed.connect(_on_cursor_changed)

		if cursor_index >= 0:
			_on_cursor_changed(cursor_paths[cursor_index], cursor_index)
	else:
		file_name_label.visible = false
		_apply_override_cursor()
	_apply_pointing_hand_override()


func _exit_tree() -> void:
	Input.set_custom_mouse_cursor(null, Input.CURSOR_POINTING_HAND)
	super._exit_tree()


func _unhandled_input(event: InputEvent) -> void:
	if hotswap_enabled:
		super._unhandled_input(event)


func _apply_override_cursor() -> void:
	Input.set_custom_mouse_cursor(override_cursor, cursor_shape, override_hotspot)

	if override_cursor != null:
		file_name_label.text = override_cursor.resource_path.get_file()
	else:
		file_name_label.text = "System cursor"


func _apply_pointing_hand_override() -> void:
	Input.set_custom_mouse_cursor(
		pointing_hand_override,
		Input.CURSOR_POINTING_HAND,
		pointing_hand_hotspot
	)


func _on_cursor_changed(cursor_path: String, _index: int) -> void:
	var folder_prefix := cursor_folder.trim_suffix("/") + "/"
	file_name_label.text = cursor_path.trim_prefix(folder_prefix)
