class_name Util
extends RefCounted


# Constrains a position to exactly `distance` units from `anchor`.
static func constrain_distance(position: Vector2, anchor: Vector2, distance: float) -> Vector2:
	return anchor + (position - anchor).normalized() * distance


# Constrains an angle to within `constraint` radians of `anchor`.
static func constrain_angle(angle: float, anchor: float, constraint: float) -> float:
	if abs(relative_angle_diff(angle, anchor)) <= constraint:
		return simplify_angle(angle)

	if relative_angle_diff(angle, anchor) > constraint:
		return simplify_angle(anchor - constraint)

	return simplify_angle(anchor + constraint)


# Returns the signed radians needed to turn `angle` to match `anchor`.
static func relative_angle_diff(angle: float, anchor: float) -> float:
	angle = simplify_angle(angle + PI - anchor)
	return PI - angle


# Simplifies an angle into the range [0, TAU).
static func simplify_angle(angle: float) -> float:
	return fposmod(angle, TAU)
