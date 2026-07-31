class_name HotswapSprite2D
extends Sprite2D


signal hotswap_texture_changed(texture_path: String, index: int)

static var image_extensions: PackedStringArray = PackedStringArray([
	"png", "jpg", "jpeg", "webp", "svg"
])

@export_group("Texture Source")
@export_file var texture_files: PackedStringArray = []
@export_dir var texture_folder: String = "res://ui/pointers/1_single"
@export var scan_subfolders: bool = true

@export_group("Cycling")
@export var wrap_around: bool = true
@export var initial_texture_index: int = 0

var texture_paths: PackedStringArray = []
var loaded_textures: Array[Texture2D] = []
var texture_index: int = -1


func _ready() -> void:
	reload_textures()


# Reloads the explicit file list, or scans texture_folder when the list is empty.
func reload_textures() -> void:
	texture_paths = texture_files.duplicate()
	if texture_paths.is_empty():
		texture_paths = _find_texture_paths(texture_folder)

	texture_paths.sort()
	loaded_textures.clear()

	for texture_path in texture_paths:
		var loaded_texture := load(texture_path) as Texture2D
		if loaded_texture != null:
			loaded_textures.append(loaded_texture)

	if loaded_textures.is_empty():
		texture_index = -1
		texture = null
		return

	set_texture_index(initial_texture_index)


func set_texture_index(index: int) -> void:
	if loaded_textures.is_empty():
		return

	if wrap_around:
		texture_index = wrapi(index, 0, loaded_textures.size())
	else:
		texture_index = clampi(index, 0, loaded_textures.size() - 1)

	texture = loaded_textures[texture_index]
	hotswap_texture_changed.emit(texture_paths[texture_index], texture_index)


func cycle_texture(amount: int) -> void:
	set_texture_index(texture_index + amount)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			cycle_texture(1)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cycle_texture(-1)
			get_viewport().set_input_as_handled()


func _find_texture_paths(directory_path: String) -> PackedStringArray:
	var paths := PackedStringArray()
	var directory := DirAccess.open(directory_path)

	if directory == null:
		push_warning("HotswapSprite2D could not open folder: %s" % directory_path)
		return paths

	directory.list_dir_begin()
	var entry := directory.get_next()

	while not entry.is_empty():
		var entry_path := directory_path.path_join(entry)

		if directory.current_is_dir():
			if scan_subfolders and not entry.begins_with("."):
				paths.append_array(_find_texture_paths(entry_path))
		elif entry.get_extension().to_lower() in image_extensions:
			paths.append(entry_path)

		entry = directory.get_next()

	directory.list_dir_end()
	return paths
