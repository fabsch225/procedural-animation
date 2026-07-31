class_name NonZeroPathTessellator2D
extends RefCounted


const DEFAULT_EPSILON: float = 0.001


## Tessellates one closed, possibly self-intersecting contour with the NON_ZERO
## winding rule used by JavaFX/Processing. The returned point array contains
## explicit triangles; no subsequent polygon triangulation is required.
static func tessellate(
	contour: PackedVector2Array,
	epsilon: float = DEFAULT_EPSILON
) -> PackedVector2Array:
	var points := _clean_contour(contour, epsilon)
	if points.size() < 3:
		return PackedVector2Array()

	var edges := _build_edges(points, epsilon)
	if edges.size() < 2:
		return PackedVector2Array()

	var scanline_events := _collect_scanline_events(points, edges, epsilon)
	if scanline_events.size() < 2:
		return PackedVector2Array()

	return _tessellate_slabs(edges, scanline_events, epsilon)


static func _clean_contour(contour: PackedVector2Array, epsilon: float) -> PackedVector2Array:
	var cleaned := PackedVector2Array()
	var epsilon_squared := epsilon * epsilon

	for point in contour:
		if cleaned.is_empty() or cleaned[-1].distance_squared_to(point) > epsilon_squared:
			cleaned.append(point)

	if cleaned.size() > 1 and cleaned[0].distance_squared_to(cleaned[-1]) <= epsilon_squared:
		cleaned.remove_at(cleaned.size() - 1)

	return cleaned


static func _build_edges(points: PackedVector2Array, epsilon: float) -> Array[PathEdge]:
	var edges: Array[PathEdge] = []
	for i in range(points.size()):
		var edge := PathEdge.new(points[i], points[(i + 1) % points.size()], i)
		# Horizontal edges do not change winding during a horizontal sweep.
		if absf(edge.b.y - edge.a.y) > epsilon:
			edges.append(edge)
	return edges


static func _collect_scanline_events(
	points: PackedVector2Array,
	edges: Array[PathEdge],
	epsilon: float
) -> Array[float]:
	var events: Array[float] = []
	for point in points:
		events.append(point.y)

	# Broad phase: edges sorted by their left bound only need comparison while
	# their X ranges overlap. This avoids an unconditional O(n^2) pass.
	var x_sorted: Array[PathEdge] = edges.duplicate()
	x_sorted.sort_custom(func(left: PathEdge, right: PathEdge) -> bool:
		return left.min_x < right.min_x
	)

	for i in range(x_sorted.size()):
		var first := x_sorted[i]
		for j in range(i + 1, x_sorted.size()):
			var second := x_sorted[j]
			if second.min_x > first.max_x + epsilon:
				break
			if second.min_y > first.max_y + epsilon or second.max_y < first.min_y - epsilon:
				continue
			if _edges_are_adjacent(first.index, second.index, points.size()):
				continue

			var intersection := Geometry2D.segment_intersects_segment(
				first.a, first.b, second.a, second.b
			)
			if intersection is Vector2:
				events.append((intersection as Vector2).y)

	events.sort()
	var unique_events: Array[float] = []
	for event_y in events:
		if unique_events.is_empty() or absf(event_y - unique_events[-1]) > epsilon:
			unique_events.append(event_y)
	return unique_events


static func _edges_are_adjacent(first: int, second: int, point_count: int) -> bool:
	var difference := absi(first - second)
	return difference == 1 or difference == point_count - 1


static func _tessellate_slabs(
	edges: Array[PathEdge],
	events: Array[float],
	epsilon: float
) -> PackedVector2Array:
	var triangles := PackedVector2Array()
	var min_y_sorted: Array[PathEdge] = edges.duplicate()
	min_y_sorted.sort_custom(func(left: PathEdge, right: PathEdge) -> bool:
		return left.min_y < right.min_y
	)

	var active_edges: Array[PathEdge] = []
	var next_edge_index := 0

	for slab_index in range(events.size() - 1):
		var top_y := events[slab_index]
		var bottom_y := events[slab_index + 1]
		if bottom_y - top_y <= epsilon:
			continue
		var middle_y := (top_y + bottom_y) * 0.5

		while next_edge_index < min_y_sorted.size() \
				and min_y_sorted[next_edge_index].min_y < middle_y:
			active_edges.append(min_y_sorted[next_edge_index])
			next_edge_index += 1

		var surviving_edges: Array[PathEdge] = []
		var crossings: Array[ScanCrossing] = []
		for edge in active_edges:
			if edge.max_y <= middle_y:
				continue
			surviving_edges.append(edge)
			crossings.append(ScanCrossing.new(edge, edge.x_at(middle_y)))
		active_edges = surviving_edges

		if crossings.size() < 2:
			continue
		crossings.sort_custom(func(left: ScanCrossing, right: ScanCrossing) -> bool:
			if is_equal_approx(left.x, right.x):
				return left.edge.winding_delta < right.edge.winding_delta
			return left.x < right.x
		)

		var winding := 0
		for crossing_index in range(crossings.size() - 1):
			var left_crossing := crossings[crossing_index]
			winding += left_crossing.edge.winding_delta
			if winding == 0:
				continue

			var right_crossing := crossings[crossing_index + 1]
			if right_crossing.x - left_crossing.x <= epsilon:
				continue

			_append_slab_triangles(
				triangles,
				left_crossing.edge,
				right_crossing.edge,
				top_y,
				bottom_y,
				epsilon
			)

	return triangles


static func _append_slab_triangles(
	triangles: PackedVector2Array,
	left_edge: PathEdge,
	right_edge: PathEdge,
	top_y: float,
	bottom_y: float,
	epsilon: float
) -> void:
	var top_left := Vector2(left_edge.x_at(top_y), top_y)
	var top_right := Vector2(right_edge.x_at(top_y), top_y)
	var bottom_right := Vector2(right_edge.x_at(bottom_y), bottom_y)
	var bottom_left := Vector2(left_edge.x_at(bottom_y), bottom_y)

	_append_triangle(triangles, top_left, top_right, bottom_right, epsilon)
	_append_triangle(triangles, top_left, bottom_right, bottom_left, epsilon)


static func _append_triangle(
	triangles: PackedVector2Array,
	a: Vector2,
	b: Vector2,
	c: Vector2,
	epsilon: float
) -> void:
	if absf((b - a).cross(c - a)) <= epsilon * epsilon:
		return
	triangles.append(a)
	triangles.append(b)
	triangles.append(c)


class PathEdge:
	var a: Vector2
	var b: Vector2
	var index: int
	var min_x: float
	var max_x: float
	var min_y: float
	var max_y: float
	var winding_delta: int

	func _init(a_: Vector2, b_: Vector2, index_: int) -> void:
		a = a_
		b = b_
		index = index_
		min_x = minf(a.x, b.x)
		max_x = maxf(a.x, b.x)
		min_y = minf(a.y, b.y)
		max_y = maxf(a.y, b.y)
		winding_delta = 1 if b.y > a.y else -1

	func x_at(y: float) -> float:
		return a.x + (y - a.y) * (b.x - a.x) / (b.y - a.y)


class ScanCrossing:
	var edge: PathEdge
	var x: float

	func _init(edge_: PathEdge, x_: float) -> void:
		edge = edge_
		x = x_
