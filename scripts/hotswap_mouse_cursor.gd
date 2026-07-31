class_name HotswapMouseCursor
extends Node


signal cursor_changed(cursor_path: String, index: int)

static var image_extensions: PackedStringArray = PackedStringArray([
	"png", "jpg", "jpeg", "webp", "svg"
])

@export_group("Cursor Source")
@export_file var cursor_files: PackedStringArray = []
@export_dir var cursor_folder: String = "res://ui/pointers/1_single"
@export var scan_subfolders: bool = true

@export_group("Cursor Settings")
@export_enum(
	"Arrow:0", "I-Beam:1", "Pointing Hand:2", "Cross:3", "Wait:4", "Busy:5",
	"Drag:6", "Can Drop:7", "Forbidden:8", "Vertical Resize:9", "Horizontal Resize:10",
	"Backward Diagonal Resize:11", "Forward Diagonal Resize:12", "Move:13",
	"Vertical Split:14", "Horizontal Split:15", "Help:16"
) var cursor_shape: int = Input.CURSOR_ARROW
@export var hotspot: Vector2 = Vector2.ZERO
@export var wrap_around: bool = true
@export var initial_cursor_index: int = 0

var cursor_paths: PackedStringArray = []
var cursor_textures: Array[Texture2D] = []
var cursor_index: int = -1


func _ready() -> void:
	reload_cursors()


func _exit_tree() -> void:
	Input.set_custom_mouse_cursor(null, cursor_shape)


# Loads the explicit file list, or scans cursor_folder when the list is empty.
func reload_cursors() -> void:
	var candidate_paths := cursor_files.duplicate()
	if candidate_paths.is_empty():
		candidate_paths = _find_cursor_paths(cursor_folder)

	# A lexical sort keeps numbered subfolders grouped and ordered (1_single, 2_double, ...).
	candidate_paths.sort()
	cursor_paths.clear()
	cursor_textures.clear()

	for cursor_path in candidate_paths:
		var cursor_texture := load(cursor_path) as Texture2D
		if cursor_texture != null:
			cursor_paths.append(cursor_path)
			cursor_textures.append(cursor_texture)

	if cursor_textures.is_empty():
		cursor_index = -1
		Input.set_custom_mouse_cursor(null, cursor_shape)
		return

	set_cursor_index(initial_cursor_index)


func set_cursor_index(index: int) -> void:
	if cursor_textures.is_empty():
		return

	if wrap_around:
		cursor_index = wrapi(index, 0, cursor_textures.size())
	else:
		cursor_index = clampi(index, 0, cursor_textures.size() - 1)

	Input.set_custom_mouse_cursor(cursor_textures[cursor_index], cursor_shape, hotspot)
	cursor_changed.emit(cursor_paths[cursor_index], cursor_index)


func cycle_cursor(amount: int) -> void:
	set_cursor_index(cursor_index + amount)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			cycle_cursor(-1)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cycle_cursor(1)
			get_viewport().set_input_as_handled()


func _find_cursor_paths(directory_path: String) -> PackedStringArray:
	var paths := PackedStringArray()
	var directory := DirAccess.open(directory_path)

	if directory == null:
		push_warning("HotswapMouseCursor could not open folder: %s" % directory_path)
		return paths

	directory.list_dir_begin()
	var entry := directory.get_next()

	while not entry.is_empty():
		var entry_path := directory_path.path_join(entry)

		if directory.current_is_dir():
			if scan_subfolders and not entry.begins_with("."):
				paths.append_array(_find_cursor_paths(entry_path))
		elif entry.get_extension().to_lower() in image_extensions:
			paths.append(entry_path)

		entry = directory.get_next()

	directory.list_dir_end()
	return paths
