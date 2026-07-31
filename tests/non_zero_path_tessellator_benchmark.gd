extends SceneTree


const GDSCRIPT_TESSELLATOR := preload("res://scripts/non_zero_path_tessellator_2d.gd")
const WARMUP_RUNS: int = 3
const MEASURED_RUNS: int = 30
const CONTOUR_POINTS: int = 192


func _init() -> void:
	if not ClassDB.class_exists(&"NonZeroPathTessellatorNative"):
		push_error("NonZeroPathTessellatorNative is not registered; build the GDExtension first")
		quit(1)
		return

	var native_tessellator: Object = ClassDB.instantiate(&"NonZeroPathTessellatorNative")
	var contour := _build_self_intersecting_contour(CONTOUR_POINTS)

	for _run in range(WARMUP_RUNS):
		GDSCRIPT_TESSELLATOR.tessellate(contour)
		native_tessellator.call(&"tessellate", contour)

	var gdscript_result_size := 0
	var started_usec := Time.get_ticks_usec()
	for _run in range(MEASURED_RUNS):
		var result: PackedVector2Array = GDSCRIPT_TESSELLATOR.tessellate(contour)
		gdscript_result_size += result.size()
	var gdscript_usec := Time.get_ticks_usec() - started_usec

	var native_result_size := 0
	started_usec = Time.get_ticks_usec()
	for _run in range(MEASURED_RUNS):
		var result: Variant = native_tessellator.call(&"tessellate", contour)
		if result is PackedVector2Array:
			native_result_size += (result as PackedVector2Array).size()
	var native_usec := Time.get_ticks_usec() - started_usec

	if gdscript_result_size != native_result_size:
		push_error(
			"Benchmark backends returned different vertex totals: %d vs %d"
			% [gdscript_result_size, native_result_size]
		)
		quit(1)
		return

	var gdscript_average := float(gdscript_usec) / float(MEASURED_RUNS)
	var native_average := float(native_usec) / float(MEASURED_RUNS)
	print("Tessellator benchmark: %d-point self-intersecting contour, %d runs" % [
		CONTOUR_POINTS, MEASURED_RUNS,
	])
	print("  GDScript: %.2f us/run" % gdscript_average)
	print("  GDExtension: %.2f us/run" % native_average)
	print("  Native speedup: %.2fx" % (gdscript_average / maxf(native_average, 0.001)))
	quit()


func _build_self_intersecting_contour(point_count: int) -> PackedVector2Array:
	var contour := PackedVector2Array()
	for i in range(point_count):
		var angle := TAU * float(i) / float(point_count)
		contour.append(Vector2(
			cos(angle * 3.0) * 220.0 + cos(angle * 11.0) * 18.0,
			sin(angle * 4.0) * 170.0 + sin(angle * 9.0) * 14.0
		))
	return contour
