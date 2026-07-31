extends SceneTree


func _init() -> void:
	var shape := ProcessingShape2D.new()
	shape.adaptive_curve_flattening = false
	shape.curve_resolution = 4
	shape.begin_shape()
	shape.vertex(Vector2.ZERO)
	shape.bezier_vertex(Vector2(0, 10), Vector2(10, 10), Vector2(10, 0))
	var path := shape.end_shape()

	if path.size() != 5:
		push_error("bezier_vertex produced %d points, expected 5" % path.size())
		quit(1)
		return
	if not path[0].is_equal_approx(Vector2.ZERO):
		push_error("bezier_vertex changed its starting anchor")
		quit(1)
		return
	if not path[-1].is_equal_approx(Vector2(10, 0)):
		push_error("bezier_vertex did not reach its ending anchor")
		quit(1)
		return

	print("ProcessingShape2D tests passed")
	quit()
