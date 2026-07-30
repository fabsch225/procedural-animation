extends Node2D
class_name Snake


# =====================================================
# Snake Parameters
# =====================================================

@export_category("Snake")

@export var spine_length: int = 48
@export var link_size: float = 64.0

@export var follow_speed: float = 8.0

@export var body_color: Color = Color(0.67, 0.22, 0.19)
@export var outline_color: Color = Color.WHITE


@export_category("Body")

@export var head_width: float = 76.0
@export var second_width: float = 80.0
@export var tail_width: float = 64.0



# =====================================================
# Internal
# =====================================================

var spine: Chain



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

	queue_redraw()



# =====================================================
# Movement
# =====================================================

func _process(delta):
	var head_pos = spine.joints[0]
	var mouse_pos = get_global_mouse_position()

	var offset = mouse_pos - head_pos
	var distance = offset.length()


	if distance > 0.001:

		var direction = offset / distance

		var target_pos = (
			head_pos +
			direction * min(follow_speed, distance)
		)

		spine.resolve(target_pos)


	queue_redraw()



# =====================================================
# Body Shape
# =====================================================

func body_width(index: int) -> float:

	if index == 0:
		return head_width

	elif index == 1:
		return second_width

	else:
		return max(
			8.0,
			tail_width - index
		)



func get_body_position(
	index: int,
	angle_offset: float,
	length_offset: float = 0.0
) -> Vector2:


	var joint = spine.joints[index]

	var angle = (
		spine.angles[index]
		+
		angle_offset
	)


	return joint + Vector2.RIGHT.rotated(angle) * (
		body_width(index)
		+
		length_offset
	)



# =====================================================
# Drawing
# =====================================================

func _draw():


	if spine == null:
		return

	if spine.joints.size() < 3:
		return



	# -------------------------
	# Body
	# -------------------------

	var points: PackedVector2Array = []


	# Right side

	for i in range(spine.joints.size()):

		points.append(
			get_body_position(
				i,
				PI / 2
			)
		)



	# Tail cap

	points.append(
		get_body_position(
			spine.joints.size() - 1,
			PI
		)
	)



	# Left side

	for i in range(
		spine.joints.size() - 1,
		-1,
		-1
	):

		points.append(
			get_body_position(
				i,
				-PI / 2
			)
		)



	# Head roundness

	points.append(
		get_body_position(
			0,
			-PI / 6
		)
	)

	points.append(
		get_body_position(
			0,
			0
		)
	)

	points.append(
		get_body_position(
			0,
			PI / 6
		)
	)



	# Draw filled polygon

	if points.size() < 3:
		return

	draw_colored_polygon(
		points,
		body_color
	)



	# Outline

	for i in range(points.size()):

		draw_line(
			points[i],
			points[(i + 1) % points.size()],
			outline_color,
			4.0
		)



	# -------------------------
	# Eyes
	# -------------------------

	var left_eye = get_body_position(
		0,
		PI / 2,
		-18
	)

	var right_eye = get_body_position(
		0,
		-PI / 2,
		-18
	)


	draw_circle(
		left_eye,
		12,
		Color.WHITE
	)

	draw_circle(
		right_eye,
		12,
		Color.WHITE
	)


	# pupils

	draw_circle(
		left_eye,
		5,
		Color.BLACK
	)

	draw_circle(
		right_eye,
		5,
		Color.BLACK
	)



# =====================================================
# Debug
# =====================================================

func debug_display():

	spine.queue_redraw()
