extends Node2D
## One culled chunk of terrain relief marks. marks: [[pos, glyph, variation 0..1], ...] in world units.

var marks: Array = []
const INK := Color(0.16, 0.12, 0.08, 0.55)

func _draw() -> void:
	for m in marks:
		var p: Vector2 = m[0]
		var v: float = m[2]
		match m[1]:
			"peak":
				var s := 2.6 + 1.6 * v
				draw_colored_polygon(PackedVector2Array([p + Vector2(-s, s * 0.7), p + Vector2(0, -s), p + Vector2(s, s * 0.7)]), Color(0.93, 0.92, 0.9, 0.55))
				draw_colored_polygon(PackedVector2Array([p + Vector2(0, -s), p + Vector2(s, s * 0.7), p + Vector2(s * 0.15, s * 0.7)]), Color(0.2, 0.17, 0.16, 0.35))
				draw_polyline(PackedVector2Array([p + Vector2(-s, s * 0.7), p + Vector2(0, -s), p + Vector2(s, s * 0.7)]), INK, 0.5)
			"hill":
				var s2 := 2.4 + 1.2 * v
				draw_arc(p + Vector2(0, s2 * 0.5), s2, PI, TAU, 8, INK, 0.7)
			"tree":
				var s3 := 1.6 + 0.8 * v
				draw_colored_polygon(PackedVector2Array([p + Vector2(-s3, s3), p + Vector2(0, -s3 * 1.4), p + Vector2(s3, s3)]), Color(0.1, 0.32, 0.14, 0.55))
			"palm":
				var s4 := 1.5 + 0.8 * v
				draw_circle(p, s4, Color(0.05, 0.3, 0.12, 0.5))
				draw_circle(p + Vector2(s4 * 0.7, -s4 * 0.6), s4 * 0.7, Color(0.1, 0.4, 0.18, 0.5))
			"reed":
				draw_line(p + Vector2(-1.6, 1.0), p + Vector2(1.6, 1.0), Color(0.2, 0.4, 0.45, 0.6), 0.5)
				draw_line(p + Vector2(0, 1.0), p + Vector2(0, -1.4), Color(0.2, 0.4, 0.45, 0.6), 0.5)
			"dune":
				draw_arc(p, 2.2 + v, PI * 1.1, PI * 1.9, 6, Color(0.55, 0.38, 0.16, 0.5), 0.6)
			_:
				draw_line(p + Vector2(-1.2, 0), p + Vector2(1.2, 0), Color(0.4, 0.45, 0.2, 0.45), 0.5)
