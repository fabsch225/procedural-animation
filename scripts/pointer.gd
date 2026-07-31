class_name Pointer
extends HotswapMouseCursor


@onready var file_name_label: Label = $FileNameLabel


func _ready() -> void:
	super._ready()
	cursor_changed.connect(_on_cursor_changed)

	if cursor_index >= 0:
		_on_cursor_changed(cursor_paths[cursor_index], cursor_index)


func _on_cursor_changed(cursor_path: String, _index: int) -> void:
	var folder_prefix := cursor_folder.trim_suffix("/") + "/"
	file_name_label.text = cursor_path.trim_prefix(folder_prefix)
