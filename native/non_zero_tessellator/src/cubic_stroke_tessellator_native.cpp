#include "cubic_stroke_tessellator_native.h"

#include <godot_cpp/core/class_db.hpp>

#include <algorithm>
#include <cmath>
#include <vector>

namespace godot {
namespace {

constexpr double PI = 3.14159265358979323846;
constexpr double MAX_TANGENT_ANGLE_COSINE = 0.9238795325112867; // 22.5 degrees.
constexpr int MIN_CIRCLE_SEGMENTS = 8;
constexpr int MAX_CIRCLE_SEGMENTS = 64;
constexpr int MAX_RECURSION_DEPTH = 12;
constexpr size_t MAX_SAMPLE_POINTS = 4096;

struct CubicSegment {
	Vector2 start;
	Vector2 control_1;
	Vector2 control_2;
	Vector2 end;
};

bool is_finite(const Vector2 &p_point) {
	return std::isfinite(p_point.x) && std::isfinite(p_point.y);
}

double vector_length(const Vector2 &p_vector) {
	return std::sqrt(static_cast<double>(p_vector.length_squared()));
}

double vector_dot(const Vector2 &p_first, const Vector2 &p_second) {
	return static_cast<double>(p_first.x) * p_second.x +
			static_cast<double>(p_first.y) * p_second.y;
}

double vector_cross(const Vector2 &p_first, const Vector2 &p_second) {
	return static_cast<double>(p_first.x) * p_second.y -
			static_cast<double>(p_first.y) * p_second.x;
}

double point_line_distance(
		const Vector2 &p_point,
		const Vector2 &p_start,
		const Vector2 &p_end,
		double p_epsilon) {
	const Vector2 baseline = p_end - p_start;
	const double baseline_length = vector_length(baseline);
	if (baseline_length <= p_epsilon) {
		return vector_length(p_point - p_start);
	}
	return std::abs(vector_cross(baseline, p_point - p_start)) / baseline_length;
}

Vector2 first_usable_tangent(const CubicSegment &p_curve, double p_epsilon) {
	const Vector2 candidates[] = {
		p_curve.control_1 - p_curve.start,
		p_curve.control_2 - p_curve.start,
		p_curve.end - p_curve.start,
	};
	for (const Vector2 &candidate : candidates) {
		if (vector_length(candidate) > p_epsilon) {
			return candidate;
		}
	}
	return Vector2();
}

Vector2 last_usable_tangent(const CubicSegment &p_curve, double p_epsilon) {
	const Vector2 candidates[] = {
		p_curve.end - p_curve.control_2,
		p_curve.end - p_curve.control_1,
		p_curve.end - p_curve.start,
	};
	for (const Vector2 &candidate : candidates) {
		if (vector_length(candidate) > p_epsilon) {
			return candidate;
		}
	}
	return Vector2();
}

bool tangents_are_smooth(const CubicSegment &p_curve, double p_epsilon) {
	const Vector2 start_tangent = first_usable_tangent(p_curve, p_epsilon);
	const Vector2 end_tangent = last_usable_tangent(p_curve, p_epsilon);
	const Vector2 edge_0 = p_curve.control_1 - p_curve.start;
	const Vector2 edge_1 = p_curve.control_2 - p_curve.control_1;
	const Vector2 edge_2 = p_curve.end - p_curve.control_2;
	const Vector2 middle_tangent = edge_0 * 0.25 + edge_1 * 0.5 + edge_2 * 0.25;

	const double start_length = vector_length(start_tangent);
	const double middle_length = vector_length(middle_tangent);
	const double end_length = vector_length(end_tangent);
	if (start_length <= p_epsilon || middle_length <= p_epsilon || end_length <= p_epsilon) {
		return false;
	}

	const double start_middle_cosine = vector_dot(start_tangent, middle_tangent) /
			(start_length * middle_length);
	const double middle_end_cosine = vector_dot(middle_tangent, end_tangent) /
			(middle_length * end_length);
	return start_middle_cosine >= MAX_TANGENT_ANGLE_COSINE &&
			middle_end_cosine >= MAX_TANGENT_ANGLE_COSINE;
}

bool cubic_is_flat_enough(
		const CubicSegment &p_curve,
		double p_tolerance,
		double p_epsilon) {
	const double chord_length = vector_length(p_curve.end - p_curve.start);
	const double control_length =
			vector_length(p_curve.control_1 - p_curve.start) +
			vector_length(p_curve.control_2 - p_curve.control_1) +
			vector_length(p_curve.end - p_curve.control_2);

	if (control_length <= p_tolerance) {
		return true;
	}
	if (chord_length <= p_epsilon) {
		return false;
	}

	const double flatness = std::max(
			point_line_distance(p_curve.control_1, p_curve.start, p_curve.end, p_epsilon),
			point_line_distance(p_curve.control_2, p_curve.start, p_curve.end, p_epsilon));
	const double length_excess = std::max(0.0, control_length - chord_length);
	return flatness <= p_tolerance &&
			length_excess <= p_tolerance * 2.0 &&
			tangents_are_smooth(p_curve, p_epsilon);
}

void split_cubic(
		const CubicSegment &p_curve,
		CubicSegment &r_left,
		CubicSegment &r_right) {
	const Vector2 point_01 = (p_curve.start + p_curve.control_1) * 0.5;
	const Vector2 point_12 = (p_curve.control_1 + p_curve.control_2) * 0.5;
	const Vector2 point_23 = (p_curve.control_2 + p_curve.end) * 0.5;
	const Vector2 point_012 = (point_01 + point_12) * 0.5;
	const Vector2 point_123 = (point_12 + point_23) * 0.5;
	const Vector2 midpoint = (point_012 + point_123) * 0.5;

	r_left = { p_curve.start, point_01, point_012, midpoint };
	r_right = { midpoint, point_123, point_23, p_curve.end };
}

void append_sample(std::vector<Vector2> &r_samples, const Vector2 &p_point, double p_epsilon) {
	if (r_samples.empty() || vector_length(r_samples.back() - p_point) > p_epsilon) {
		r_samples.push_back(p_point);
	}
}

void flatten_cubic(
		const CubicSegment &p_curve,
		double p_tolerance,
		double p_epsilon,
		int p_depth,
		int p_max_depth,
		std::vector<Vector2> &r_samples) {
	if (r_samples.size() >= MAX_SAMPLE_POINTS) {
		return;
	}
	if (p_depth >= p_max_depth || cubic_is_flat_enough(p_curve, p_tolerance, p_epsilon)) {
		append_sample(r_samples, p_curve.end, p_epsilon);
		return;
	}

	CubicSegment left;
	CubicSegment right;
	split_cubic(p_curve, left, right);
	flatten_cubic(left, p_tolerance, p_epsilon, p_depth + 1, p_max_depth, r_samples);
	flatten_cubic(right, p_tolerance, p_epsilon, p_depth + 1, p_max_depth, r_samples);
}

void append_triangle(
		PackedVector2Array &r_triangles,
		const Vector2 &p_a,
		const Vector2 &p_b,
		const Vector2 &p_c,
		double p_epsilon) {
	if (!is_finite(p_a) || !is_finite(p_b) || !is_finite(p_c)) {
		return;
	}
	if (std::abs(vector_cross(p_b - p_a, p_c - p_a)) <= p_epsilon * p_epsilon) {
		return;
	}
	r_triangles.append(p_a);
	r_triangles.append(p_b);
	r_triangles.append(p_c);
}

void append_disk(
		PackedVector2Array &r_triangles,
		const Vector2 &p_center,
		double p_radius,
		int p_segments,
		double p_epsilon) {
	for (int segment = 0; segment < p_segments; ++segment) {
		const double first_angle = static_cast<double>(segment) * 2.0 * PI / p_segments;
		const double second_angle = static_cast<double>(segment + 1) * 2.0 * PI / p_segments;
		const Vector2 first = p_center + Vector2(
				std::cos(first_angle) * p_radius,
				std::sin(first_angle) * p_radius);
		const Vector2 second = p_center + Vector2(
				std::cos(second_angle) * p_radius,
				std::sin(second_angle) * p_radius);
		append_triangle(r_triangles, p_center, first, second, p_epsilon);
	}
}

int calculate_circle_segments(double p_radius, double p_tolerance, int p_requested_segments) {
	if (p_requested_segments > 0) {
		return std::clamp(p_requested_segments, MIN_CIRCLE_SEGMENTS, MAX_CIRCLE_SEGMENTS);
	}
	const double cosine = std::clamp(1.0 - p_tolerance / p_radius, -1.0, 1.0);
	const double half_step = std::acos(cosine);
	if (!std::isfinite(half_step) || half_step <= 0.0) {
		return MAX_CIRCLE_SEGMENTS;
	}
	return std::clamp(
			static_cast<int>(std::ceil(PI / half_step)),
			MIN_CIRCLE_SEGMENTS,
			MAX_CIRCLE_SEGMENTS);
}

} // namespace

void CubicStrokeTessellatorNative::_bind_methods() {
	ClassDB::bind_method(
			D_METHOD(
					"tessellate",
					"start",
					"control_1",
					"control_2",
					"end",
					"width",
					"tolerance",
					"max_depth",
					"circle_segments"),
			&CubicStrokeTessellatorNative::tessellate,
			DEFVAL(0.2),
			DEFVAL(12),
			DEFVAL(0));
}

PackedVector2Array CubicStrokeTessellatorNative::tessellate(
		const Vector2 &p_start,
		const Vector2 &p_control_1,
		const Vector2 &p_control_2,
		const Vector2 &p_end,
		double p_width,
		double p_tolerance,
		int p_max_depth,
		int p_circle_segments) const {
	if (!is_finite(p_start) || !is_finite(p_control_1) ||
			!is_finite(p_control_2) || !is_finite(p_end) ||
			!std::isfinite(p_width) || p_width <= 0.0) {
		return PackedVector2Array();
	}

	const double radius = p_width * 0.5;
	const double tolerance = std::isfinite(p_tolerance)
			? std::clamp(std::abs(p_tolerance), 0.001, std::max(radius * 0.5, 0.001))
			: 0.2;
	const double epsilon = std::max(tolerance * 0.001, 0.000001);
	const int max_depth = std::clamp(p_max_depth, 1, MAX_RECURSION_DEPTH);
	const int circle_segments = calculate_circle_segments(radius, tolerance, p_circle_segments);

	const CubicSegment curve = { p_start, p_control_1, p_control_2, p_end };
	std::vector<Vector2> samples;
	samples.reserve(64);
	samples.push_back(p_start);
	flatten_cubic(curve, tolerance, epsilon, 0, max_depth, samples);
	if (samples.size() == 1 && vector_length(samples.front() - p_end) > epsilon) {
		samples.push_back(p_end);
	}

	PackedVector2Array triangles;
	for (size_t index = 0; index + 1 < samples.size(); ++index) {
		const Vector2 start = samples[index];
		const Vector2 end = samples[index + 1];
		const Vector2 direction = end - start;
		const double length = vector_length(direction);
		if (length <= epsilon) {
			continue;
		}
		const Vector2 normal(
				-direction.y / length * radius,
				direction.x / length * radius);
		const Vector2 start_left = start + normal;
		const Vector2 end_left = end + normal;
		const Vector2 end_right = end - normal;
		const Vector2 start_right = start - normal;
		append_triangle(triangles, start_left, end_left, end_right, epsilon);
		append_triangle(triangles, start_left, end_right, start_right, epsilon);
	}

	// A round stroke is the Minkowski sum of its center path and a disk. Adding
	// one disk per adaptive sample makes every artificial subdivision a round
	// continuation instead of a miter join, including at cusps and reversals.
	for (const Vector2 &sample : samples) {
		append_disk(triangles, sample, radius, circle_segments, epsilon);
	}

	return triangles;
}

} // namespace godot
