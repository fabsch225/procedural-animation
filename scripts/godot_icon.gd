extends StaticBody2D


func _ready() -> void:
	get_viewport().size_changed.connect(_center_in_viewport)
	_center_in_viewport()


func _center_in_viewport() -> void:
	position = get_viewport_rect().get_center()
