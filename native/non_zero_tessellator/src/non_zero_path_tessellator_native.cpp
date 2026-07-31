#include "non_zero_path_tessellator_native.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/vector2.hpp>

#include <algorithm>
#include <cmath>
#include <vector>

namespace godot {
namespace {

struct PathEdge {
	Vector2 a;
	Vector2 b;
	int index = 0;
	double min_x = 0.0;
	double max_x = 0.0;
	double min_y = 0.0;
	double max_y = 0.0;
	int winding_delta = 0;

	PathEdge(const Vector2 &p_a, const Vector2 &p_b, int p_index) :
			a(p_a), b(p_b), index(p_index) {
		min_x = std::min<double>(a.x, b.x);
		max_x = std::max<double>(a.x, b.x);
		min_y = std::min<double>(a.y, b.y);
		max_y = std::max<double>(a.y, b.y);
		winding_delta = b.y > a.y ? 1 : -1;
	}

	double x_at(double p_y) const {
		return a.x + (p_y - a.y) * (b.x - a.x) / (b.y - a.y);
	}
};

struct ScanCrossing {
	const PathEdge *edge = nullptr;
	double x = 0.0;
};

double cross(const Vector2 &p_first, const Vector2 &p_second) {
	return static_cast<double>(p_first.x) * p_second.y - static_cast<double>(p_first.y) * p_second.x;
}

bool segments_intersect(
		const Vector2 &p_a,
		const Vector2 &p_b,
		const Vector2 &p_c,
		const Vector2 &p_d,
		double p_epsilon,
		Vector2 &r_intersection) {
	const Vector2 first_direction = p_b - p_a;
	const Vector2 second_direction = p_d - p_c;
	const double denominator = cross(first_direction, second_direction);
	if (std::abs(denominator) <= p_epsilon) {
		return false;
	}

	const Vector2 offset = p_c - p_a;
	const double first_weight = cross(offset, second_direction) / denominator;
	const double second_weight = cross(offset, first_direction) / denominator;
	if (first_weight < -p_epsilon || first_weight > 1.0 + p_epsilon ||
			second_weight < -p_epsilon || second_weight > 1.0 + p_epsilon) {
		return false;
	}

	r_intersection = p_a + first_direction * first_weight;
	return true;
}

bool edges_are_adjacent(int p_first, int p_second, int p_point_count) {
	const int difference = std::abs(p_first - p_second);
	return difference == 1 || difference == p_point_count - 1;
}

void append_triangle(
		PackedVector2Array &r_triangles,
		const Vector2 &p_a,
		const Vector2 &p_b,
		const Vector2 &p_c,
		double p_epsilon) {
	if (std::abs(cross(p_b - p_a, p_c - p_a)) <= p_epsilon * p_epsilon) {
		return;
	}
	r_triangles.append(p_a);
	r_triangles.append(p_b);
	r_triangles.append(p_c);
}

} // namespace

void NonZeroPathTessellatorNative::_bind_methods() {
	ClassDB::bind_method(
			D_METHOD("tessellate", "contour", "epsilon"),
			&NonZeroPathTessellatorNative::tessellate,
			DEFVAL(0.001));
}

PackedVector2Array NonZeroPathTessellatorNative::tessellate(
		const PackedVector2Array &p_contour,
		double p_epsilon) const {
	PackedVector2Array points;
	const double epsilon_squared = p_epsilon * p_epsilon;
	for (int i = 0; i < p_contour.size(); ++i) {
		const Vector2 point = p_contour[i];
		if (points.is_empty() || points[points.size() - 1].distance_squared_to(point) > epsilon_squared) {
			points.append(point);
		}
	}
	if (points.size() > 1 && points[0].distance_squared_to(points[points.size() - 1]) <= epsilon_squared) {
		points.remove_at(points.size() - 1);
	}
	if (points.size() < 3) {
		return PackedVector2Array();
	}

	std::vector<PathEdge> edges;
	edges.reserve(points.size());
	for (int i = 0; i < points.size(); ++i) {
		PathEdge edge(points[i], points[(i + 1) % points.size()], i);
		if (std::abs(edge.b.y - edge.a.y) > p_epsilon) {
			edges.push_back(edge);
		}
	}
	if (edges.size() < 2) {
		return PackedVector2Array();
	}

	std::vector<double> events;
	events.reserve(points.size());
	for (int i = 0; i < points.size(); ++i) {
		events.push_back(points[i].y);
	}

	std::vector<const PathEdge *> x_sorted;
	x_sorted.reserve(edges.size());
	for (const PathEdge &edge : edges) {
		x_sorted.push_back(&edge);
	}
	std::sort(x_sorted.begin(), x_sorted.end(), [](const PathEdge *p_left, const PathEdge *p_right) {
		return p_left->min_x < p_right->min_x;
	});

	for (size_t i = 0; i < x_sorted.size(); ++i) {
		const PathEdge *first = x_sorted[i];
		for (size_t j = i + 1; j < x_sorted.size(); ++j) {
			const PathEdge *second = x_sorted[j];
			if (second->min_x > first->max_x + p_epsilon) {
				break;
			}
			if (second->min_y > first->max_y + p_epsilon || second->max_y < first->min_y - p_epsilon) {
				continue;
			}
			if (edges_are_adjacent(first->index, second->index, points.size())) {
				continue;
			}

			Vector2 intersection;
			if (segments_intersect(first->a, first->b, second->a, second->b, p_epsilon, intersection)) {
				events.push_back(intersection.y);
			}
		}
	}

	std::sort(events.begin(), events.end());
	std::vector<double> unique_events;
	unique_events.reserve(events.size());
	for (double event_y : events) {
		if (unique_events.empty() || std::abs(event_y - unique_events.back()) > p_epsilon) {
			unique_events.push_back(event_y);
		}
	}
	if (unique_events.size() < 2) {
		return PackedVector2Array();
	}

	std::vector<const PathEdge *> min_y_sorted;
	min_y_sorted.reserve(edges.size());
	for (const PathEdge &edge : edges) {
		min_y_sorted.push_back(&edge);
	}
	std::sort(min_y_sorted.begin(), min_y_sorted.end(), [](const PathEdge *p_left, const PathEdge *p_right) {
		return p_left->min_y < p_right->min_y;
	});

	PackedVector2Array triangles;
	std::vector<const PathEdge *> active_edges;
	size_t next_edge_index = 0;

	for (size_t slab_index = 0; slab_index + 1 < unique_events.size(); ++slab_index) {
		const double top_y = unique_events[slab_index];
		const double bottom_y = unique_events[slab_index + 1];
		if (bottom_y - top_y <= p_epsilon) {
			continue;
		}
		const double middle_y = (top_y + bottom_y) * 0.5;

		while (next_edge_index < min_y_sorted.size() && min_y_sorted[next_edge_index]->min_y < middle_y) {
			active_edges.push_back(min_y_sorted[next_edge_index]);
			++next_edge_index;
		}

		std::vector<const PathEdge *> surviving_edges;
		std::vector<ScanCrossing> crossings;
		surviving_edges.reserve(active_edges.size());
		crossings.reserve(active_edges.size());
		for (const PathEdge *edge : active_edges) {
			if (edge->max_y <= middle_y) {
				continue;
			}
			surviving_edges.push_back(edge);
			crossings.push_back({ edge, edge->x_at(middle_y) });
		}
		active_edges.swap(surviving_edges);
		if (crossings.size() < 2) {
			continue;
		}

		std::sort(crossings.begin(), crossings.end(), [](const ScanCrossing &p_left, const ScanCrossing &p_right) {
			if (std::abs(p_left.x - p_right.x) <= 0.0000001) {
				return p_left.edge->winding_delta < p_right.edge->winding_delta;
			}
			return p_left.x < p_right.x;
		});

		int winding = 0;
		for (size_t crossing_index = 0; crossing_index + 1 < crossings.size(); ++crossing_index) {
			const ScanCrossing &left = crossings[crossing_index];
			winding += left.edge->winding_delta;
			if (winding == 0) {
				continue;
			}
			const ScanCrossing &right = crossings[crossing_index + 1];
			if (right.x - left.x <= p_epsilon) {
				continue;
			}

			const Vector2 top_left(left.edge->x_at(top_y), top_y);
			const Vector2 top_right(right.edge->x_at(top_y), top_y);
			const Vector2 bottom_right(right.edge->x_at(bottom_y), bottom_y);
			const Vector2 bottom_left(left.edge->x_at(bottom_y), bottom_y);
			append_triangle(triangles, top_left, top_right, bottom_right, p_epsilon);
			append_triangle(triangles, top_left, bottom_right, bottom_left, p_epsilon);
		}
	}

	return triangles;
}

} // namespace godot
