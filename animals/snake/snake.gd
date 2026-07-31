extends Node2D
class_name Snake

var following_mouse := true
@export var paused_color := Color(0.5,0.5,0.5)


# =====================================================
# Snake Parameters
# =====================================================

@export_category("Snake")

@export var spine_length: int = 48
@export var link_size: float = 64.0
@export var follow_speed: float = 8.0



# =====================================================
# Body Parameters
# =====================================================

@export_category("Body")

@export var head_width: float = 38.0
@export var second_width: float = 40.0
@export var tail_width: float = 12.0

@export var body_color := Color(
	0.67,
	0.22,
	0.19
)

@export var outline_color := Color.WHITE

@export var outline_width: float = 5.0



# =====================================================
# Eyes
# =====================================================

@export_category("Eyes")

@export var eye_size: float = 12.0
@export var eye_forward_offset: float = 40.0
@export var eye_side_offset: float = 28.0



# =====================================================
# Internal
# =====================================================

var spine: Chain

var body_mesh: MeshInstance2D
var outline_mesh: MeshInstance2D

var eyes: Node2D
var left_eye: Polygon2D
var right_eye: Polygon2D



# =====================================================
# Setup
# =====================================================

func _ready():

	spine = Chain.new(
		global_position,
		spine_length,
		link_size,
		PI / 8.0
	)

	create_visuals()

	update_mesh()

	update_pause_color()




# =====================================================
# Pause
# =====================================================

func _input(event):

	if event is InputEventKey:

		if event.keycode == KEY_ESCAPE and event.pressed:

			following_mouse = !following_mouse
			update_pause_color()



	if event is InputEventMouseButton:

		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:

			following_mouse = !following_mouse
			update_pause_color()



func update_pause_color():

	if body_mesh == null:
		return


	if following_mouse:
		body_mesh.modulate = body_color
	else:
		body_mesh.modulate = paused_color



# =====================================================
# Create Visual Nodes
# =====================================================

func setup_eye_shape(eye: Polygon2D):
	# Create a simple box/diamond shape based on eye_size
	var half = eye_size / 2.0
	var pool_points = PackedVector2Array([
		Vector2(-half, -half),
		Vector2(half, -half),
		Vector2(half, half),
		Vector2(-half, half)
	])
	eye.polygon = pool_points
	eye.color = Color.WHITE # Change to whatever color you like


func create_visuals():
	# 1. Initialize outline mesh first (renders behind body)
	if not outline_mesh:
		outline_mesh = MeshInstance2D.new()
		add_child(outline_mesh)
	outline_mesh.mesh = ImmediateMesh.new()

	# 2. Initialize body mesh
	if not body_mesh:
		body_mesh = MeshInstance2D.new()
		add_child(body_mesh)
	body_mesh.mesh = ImmediateMesh.new()

	# 3. FIX EYE CRASH: Initialize eyes base node
	if not eyes:
		eyes = Node2D.new()
		add_child(eyes)

	# Initialize left eye
	if not left_eye:
		left_eye = Polygon2D.new()
		eyes.add_child(left_eye)
		setup_eye_shape(left_eye) # Helper function to give the eye a shape

	# Initialize right eye
	if not right_eye:
		right_eye = Polygon2D.new()
		eyes.add_child(right_eye)
		setup_eye_shape(right_eye)

#func create_visuals():
#
	#outline_mesh = MeshInstance2D.new()
	#add_child(outline_mesh)
#
	#outline_mesh.modulate = outline_color
#
#
#
	#body_mesh = MeshInstance2D.new()
	#add_child(body_mesh)
#
	#body_mesh.modulate = body_color
#
#
#
	#eyes = Node2D.new()
	#add_child(eyes)
#
#
#
	#left_eye = Polygon2D.new()
	#right_eye = Polygon2D.new()
#
#
	#left_eye.polygon = make_circle(
		#eye_size,
		#20
	#)
#
	#right_eye.polygon = make_circle(
		#eye_size,
		#20
	#)
#
#
	#left_eye.color = Color.WHITE
	#right_eye.color = Color.WHITE
#
#
	#eyes.add_child(left_eye)
	#eyes.add_child(right_eye)



# =====================================================
# Movement
# =====================================================

func _process(delta):
	if not following_mouse:
		return


	var head_pos = spine.joints[0]

	var mouse_pos = get_global_mouse_position()

	var offset = mouse_pos - head_pos

	var distance = offset.length()



	if distance > 0.001:

		var target = (
			head_pos
			+
			offset.normalized()
			*
			min(
				follow_speed,
				distance
			)
		)


		spine.resolve(target)



	update_mesh()

	update_eyes()



# =====================================================
# Width Profile
# =====================================================

func body_width(index:int)->float:


	if index == 0:
		return head_width


	if index == 1:
		return second_width



	var t = float(index) / float(
		spine.joints.size() - 1
	)


	return lerp(
		second_width,
		tail_width,
		t
	)



# =====================================================
# Mesh Update
# =====================================================

#func update_mesh():
#
	#update_body_mesh(
		#outline_mesh,
		#outline_width
	#)
#
#
	#update_body_mesh(
		#body_mesh,
		#0
	#)

func update_mesh():
	var points: Array[Vector2] = spine.joints
	var num_points = points.size()

	if num_points < 2:
		return

	# SAFETY CHECK: If meshes aren't ready, skip this frame to prevent crashing
	if body_mesh == null or outline_mesh == null:
		return
	if body_mesh.mesh == null or outline_mesh.mesh == null:
		return

	var body_imm: ImmediateMesh = body_mesh.mesh
	var outline_imm: ImmediateMesh = outline_mesh.mesh

	body_imm.clear_surfaces()
	outline_imm.clear_surfaces()

	# Arrays to hold computed side vertices
	var body_left_vertices = PackedVector2Array()
	var body_right_vertices = PackedVector2Array()
	var outline_left_vertices = PackedVector2Array()
	var outline_right_vertices = PackedVector2Array()

	# 1. Calculate and map widths and perpendicular vectors
	for i in range(num_points):
		var w = 0.0
		if i == 0:
			w = head_width
		elif i == 1:
			w = second_width
		else:
			var body_t = float(i - 1) / float(num_points - 2)
			w = lerp(second_width, tail_width, body_t)

		var out_w = w + (outline_width * 2.0)

		# Find direction vector of the current segment
		var dir := Vector2.ZERO
		if i == 0:
			dir = (points[i] - points[i + 1]).normalized()
		elif i == num_points - 1:
			dir = (points[i - 1] - points[i]).normalized()
		else:
			var dir_prev = (points[i - 1] - points[i]).normalized()
			var dir_next = (points[i] - points[i + 1]).normalized()
			dir = (dir_prev + dir_next).normalized()

		# Normal vector (perpendicular to the spine direction)
		var normal = Vector2(-dir.y, dir.x)

		# Generate vertices relative to global coordinate system or local parent space
		# Note: If drawing locally, subtract global_position if nodes aren't matching origin
		var p = points[i] - global_position

		body_left_vertices.append(p + normal * (w / 2.0))
		body_right_vertices.append(p - normal * (w / 2.0))
		outline_left_vertices.append(p + normal * (out_w / 2.0))
		outline_right_vertices.append(p - normal * (out_w / 2.0))

	# 2. Build the Triangles (Outline first, then Body on top)
	render_quad_strip(outline_imm, outline_left_vertices, outline_right_vertices, outline_color)
	render_quad_strip(body_imm, body_left_vertices, body_right_vertices, body_color)


# Helper function to generate triangle strips for ImmediateMesh
func render_quad_strip(imm: ImmediateMesh, left: PackedVector2Array, right: PackedVector2Array, color: Color):
	imm.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(left.size() - 1):
		# Triangle 1
		imm.surface_set_color(color)
		imm.surface_add_vertex(Vector3(left[i].x, left[i].y, 0))
		imm.surface_add_vertex(Vector3(right[i].x, right[i].y, 0))
		imm.surface_add_vertex(Vector3(left[i + 1].x, left[i + 1].y, 0))

		# Triangle 2
		imm.surface_add_vertex(Vector3(right[i].x, right[i].y, 0))
		imm.surface_add_vertex(Vector3(right[i + 1].x, right[i + 1].y, 0))
		imm.surface_add_vertex(Vector3(left[i + 1].x, left[i + 1].y, 0))
	imm.surface_end()


func update_body_mesh(
	mesh_instance: MeshInstance2D,
	extra_width: float
):


	var vertices = PackedVector2Array()

	var indices = PackedInt32Array()



	# -------------------------
	# Spine ribbon vertices
	# -------------------------

	for i in range(spine.joints.size()):

		vertices.append(
			get_side_point(
				i,
				PI/2,
				extra_width
			)
		)

		vertices.append(
			get_side_point(
				i,
				-PI/2,
				extra_width
			)
		)



	# -------------------------
	# Head cap vertices
	# -------------------------

	var head_index = vertices.size()


	var head = spine.joints[0]

	var head_angle = spine.angles[0]


	for j in range(5):

		var angle = lerp(
			-PI/2,
			PI/2,
			float(j)/4.0
		)


		vertices.append(
			head
			+
			Vector2.RIGHT.rotated(
				head_angle + angle
			)
			*
			(
				head_width
				+
				extra_width
			)
		)



	# -------------------------
	# Body triangles
	# -------------------------

	for i in range(
		spine.joints.size()-1
	):

		var a = i * 2
		var b = a + 1
		var c = a + 2
		var d = a + 3


		indices.append(a)
		indices.append(b)
		indices.append(c)


		indices.append(b)
		indices.append(d)
		indices.append(c)



	# -------------------------
	# Head cap triangles
	# -------------------------

	for i in range(4):

		indices.append(0)

		indices.append(
			head_index + i + 1
		)

		indices.append(
			head_index + i
		)



	# -------------------------
	# Build mesh
	# -------------------------

	var arrays = []

	arrays.resize(
		Mesh.ARRAY_MAX
	)


	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices



	var mesh = ArrayMesh.new()


	mesh.add_surface_from_arrays(
		Mesh.PRIMITIVE_TRIANGLES,
		arrays
	)


	mesh_instance.mesh = mesh



# =====================================================
# Spine Offset Point
# =====================================================

func get_side_point(
	index:int,
	side:float,
	extra:float
)->Vector2:


	var angle = (
		spine.angles[index]
		+
		side
	)


	return (
		spine.joints[index]
		+
		Vector2.RIGHT.rotated(angle)
		*
		(
			body_width(index)
			+
			extra
		)
	)



# =====================================================
# Eyes
# =====================================================

func update_eyes():

	var angle = spine.angles[0]


	var forward = Vector2.RIGHT.rotated(
		angle
	)


	var side = Vector2.UP.rotated(
		angle
	)



	left_eye.position = (
		spine.joints[0]
		+
		forward * eye_forward_offset
		+
		side * eye_side_offset
	)



	right_eye.position = (
		spine.joints[0]
		+
		forward * eye_forward_offset
		-
		side * eye_side_offset
	)



# =====================================================
# Circle Helper
# =====================================================

func make_circle(
	radius:float,
	points:int
)->PackedVector2Array:


	var result = PackedVector2Array()


	for i in range(points):

		var angle = (
			float(i)
			/
			points
			*
			TAU
		)


		result.append(
			Vector2(
				cos(angle),
				sin(angle)
			)
			*
			radius
		)


	return result
