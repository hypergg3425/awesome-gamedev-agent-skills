class_name FlagCharges
extends RefCounted
## Heraldic charges for FlagView, drawn as flat polygons with a dark keyline so they stay legible on any field.
## Every shape is defined in a unit box (-1..1) and scaled by `s`; original stylised designs (no real-world arms copied).

const KINDS := ["star", "crescent", "sun", "cross", "fleur", "crown", "tower", "eagle", "lion", "dragon", "anchor", "sword", "wheat", "tree", "ship", "castle", "rose", "key", "moon_star", "horse"]

static func _pts(c: Vector2, s: float, unit: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in unit:
		out.append(c + (p as Vector2) * s)
	return out

static func _fill(ci: CanvasItem, pts: PackedVector2Array, col: Color, key: Color, lw: float) -> void:
	if pts.size() < 3:
		return
	var tri := Geometry2D.triangulate_polygon(pts)
	if tri.is_empty():
		for piece in Geometry2D.offset_polygon(pts, 0.01):
			ci.draw_colored_polygon(piece, col)
	else:
		ci.draw_colored_polygon(pts, col)
	if lw > 0.0:
		var closed := PackedVector2Array(pts)
		closed.append(pts[0])
		ci.draw_polyline(closed, key, lw, true)

static func draw(ci: CanvasItem, kind: String, c: Vector2, s: float, fg: Color, bg: Color) -> void:
	var key := Color(0, 0, 0, 0.55) if fg.get_luminance() > 0.45 else Color(1, 1, 1, 0.45)
	var lw := 1.0 if s > 7.0 else 0.0
	match kind:
		"star":
			var p := PackedVector2Array()
			for i in 10:
				var a := -PI / 2.0 + i * PI / 5.0
				p.append(c + Vector2(cos(a), sin(a)) * (s if i % 2 == 0 else s * 0.42))
			_fill(ci, p, fg, key, lw)
		"crescent":
			ci.draw_circle(c, s, fg)
			ci.draw_circle(c + Vector2(s * 0.42, 0), s * 0.82, bg)
			var st := PackedVector2Array()
			for i in 10:
				var a2 := -PI / 2.0 + i * PI / 5.0
				st.append(c + Vector2(s * 0.5, 0) + Vector2(cos(a2), sin(a2)) * (s * 0.32 if i % 2 == 0 else s * 0.13))
			_fill(ci, st, fg, key, 0.0)
		"moon_star":
			ci.draw_circle(c + Vector2(-s * 0.2, 0), s, fg)
			ci.draw_circle(c + Vector2(s * 0.12, 0), s * 0.82, bg)
			var st2 := PackedVector2Array()
			for i in 10:
				var a3 := -PI / 2.0 + i * PI / 5.0
				st2.append(c + Vector2(s * 0.55, 0) + Vector2(cos(a3), sin(a3)) * (s * 0.38 if i % 2 == 0 else s * 0.16))
			_fill(ci, st2, fg, key, 0.0)
		"sun":
			for i in 16:
				var a4 := i * TAU / 16.0
				var w := 0.12
				var tip := c + Vector2(cos(a4), sin(a4)) * s * (1.1 if i % 2 == 0 else 0.9)
				var l := c + Vector2(cos(a4 - w), sin(a4 - w)) * s * 0.62
				var r := c + Vector2(cos(a4 + w), sin(a4 + w)) * s * 0.62
				ci.draw_colored_polygon(PackedVector2Array([l, tip, r]), fg)
			ci.draw_circle(c, s * 0.58, fg)
			ci.draw_arc(c, s * 0.58, 0, TAU, 20, key, 1.0, true)
		"cross":
			_fill(ci, _pts(c, s, [Vector2(-0.18, -1), Vector2(0.18, -1), Vector2(0.18, -0.18), Vector2(1, -0.18), Vector2(1, 0.18), Vector2(0.18, 0.18),
				Vector2(0.18, 1), Vector2(-0.18, 1), Vector2(-0.18, 0.18), Vector2(-1, 0.18), Vector2(-1, -0.18), Vector2(-0.18, -0.18)]), fg, key, lw)
		"fleur":
			_fill(ci, _pts(c, s, [Vector2(0, -1), Vector2(0.22, -0.55), Vector2(0.2, -0.1), Vector2(0.16, 0.25), Vector2(-0.16, 0.25), Vector2(-0.2, -0.1), Vector2(-0.22, -0.55)]), fg, key, lw)
			_fill(ci, _pts(c, s, [Vector2(-0.12, -0.1), Vector2(-0.55, -0.62), Vector2(-0.95, -0.35), Vector2(-0.85, 0.12), Vector2(-0.5, 0.2), Vector2(-0.2, 0.12)]), fg, key, lw)
			_fill(ci, _pts(c, s, [Vector2(0.12, -0.1), Vector2(0.55, -0.62), Vector2(0.95, -0.35), Vector2(0.85, 0.12), Vector2(0.5, 0.2), Vector2(0.2, 0.12)]), fg, key, lw)
			_fill(ci, _pts(c, s, [Vector2(-0.55, 0.32), Vector2(0.55, 0.32), Vector2(0.55, 0.5), Vector2(-0.55, 0.5)]), fg, key, lw)
			_fill(ci, _pts(c, s, [Vector2(-0.12, 0.55), Vector2(0.12, 0.55), Vector2(0.32, 1), Vector2(0, 0.8), Vector2(-0.32, 1)]), fg, key, lw)
		"crown":
			_fill(ci, _pts(c, s, [Vector2(-1, 0.55), Vector2(-1, -0.55), Vector2(-0.5, 0.0), Vector2(0, -0.85), Vector2(0.5, 0.0), Vector2(1, -0.55), Vector2(1, 0.55)]), fg, key, lw)
			ci.draw_rect(Rect2(c + Vector2(-s, s * 0.45), Vector2(s * 2.0, s * 0.3)), fg.darkened(0.18))
			for gx in [-1.0, 0.0, 1.0]:
				ci.draw_circle(c + Vector2(gx * s, -s * (0.55 if gx != 0.0 else 0.85)), maxf(s * 0.13, 0.8), bg)
		"tower", "castle":
			_fill(ci, _pts(c, s, [Vector2(-0.6, 1), Vector2(-0.6, -0.4), Vector2(-0.8, -0.4), Vector2(-0.8, -0.95), Vector2(-0.45, -0.95), Vector2(-0.45, -0.7), Vector2(-0.15, -0.7),
				Vector2(-0.15, -0.95), Vector2(0.15, -0.95), Vector2(0.15, -0.7), Vector2(0.45, -0.7), Vector2(0.45, -0.95), Vector2(0.8, -0.95), Vector2(0.8, -0.4), Vector2(0.6, -0.4), Vector2(0.6, 1)]), fg, key, lw)
			ci.draw_colored_polygon(_pts(c, s, [Vector2(-0.2, 1), Vector2(-0.2, 0.35), Vector2(0, 0.15), Vector2(0.2, 0.35), Vector2(0.2, 1)]), bg)
		"eagle":
			var wing := [Vector2(0, -0.35), Vector2(0.35, -0.7), Vector2(0.75, -0.55), Vector2(1.05, -0.8), Vector2(0.95, -0.2), Vector2(0.7, 0.1), Vector2(0.4, 0.2), Vector2(0.2, 0.15)]
			var rw_pts: Array = []
			for p in wing:
				rw_pts.append(Vector2(-p.x, p.y))
			_fill(ci, _pts(c, s, wing), fg, key, lw)
			_fill(ci, _pts(c, s, rw_pts), fg, key, lw)
			_fill(ci, _pts(c, s, [Vector2(-0.3, -0.4), Vector2(0.3, -0.4), Vector2(0.38, 0.35), Vector2(0.55, 0.95), Vector2(0.15, 0.78), Vector2(0, 1.0), Vector2(-0.15, 0.78), Vector2(-0.55, 0.95), Vector2(-0.38, 0.35)]), fg, key, lw)
			_fill(ci, _pts(c, s, [Vector2(-0.34, -0.95), Vector2(-0.1, -0.98), Vector2(-0.05, -0.42), Vector2(-0.3, -0.42)]), fg, key, lw)
			_fill(ci, _pts(c, s, [Vector2(0.34, -0.95), Vector2(0.1, -0.98), Vector2(0.05, -0.42), Vector2(0.3, -0.42)]), fg, key, lw)
			_fill(ci, _pts(c, s, [Vector2(-0.34, -0.95), Vector2(-0.62, -0.84), Vector2(-0.34, -0.8)]), fg.darkened(0.12), key, 0.0)
			_fill(ci, _pts(c, s, [Vector2(0.34, -0.95), Vector2(0.62, -0.84), Vector2(0.34, -0.8)]), fg.darkened(0.12), key, 0.0)
		"lion":
			_fill(ci, _pts(c, s, [Vector2(-0.65, 1), Vector2(-0.5, 0.25), Vector2(-0.8, -0.1), Vector2(-0.6, -0.4), Vector2(-0.3, -0.05), Vector2(-0.1, -0.4), Vector2(0.05, -0.8),
				Vector2(0.4, -0.95), Vector2(0.65, -0.75), Vector2(0.6, -0.5), Vector2(0.85, -0.35), Vector2(0.6, -0.2), Vector2(0.45, 0.1), Vector2(0.65, 0.55), Vector2(0.9, 1.0), Vector2(0.5, 1),
				Vector2(0.25, 0.55), Vector2(0.05, 0.9), Vector2(0.25, 1.0), Vector2(-0.2, 1.0), Vector2(-0.3, 0.6)]), fg, key, lw)
			_fill(ci, _pts(c, s, [Vector2(-0.8, -0.1), Vector2(-1.0, -0.6), Vector2(-0.7, -0.35)]), fg, key, 0.0)
			ci.draw_circle(c + Vector2(0.42, -0.68) * s, maxf(s * 0.07, 0.7), bg)
		"dragon":
			_fill(ci, _pts(c, s, [Vector2(-1, 0.7), Vector2(-0.7, 0.35), Vector2(-0.55, -0.1), Vector2(-0.2, -0.55), Vector2(-0.35, -0.95), Vector2(0.05, -0.7), Vector2(0.45, -0.85),
				Vector2(0.95, -0.5), Vector2(0.55, -0.3), Vector2(0.25, -0.05), Vector2(0.55, 0.4), Vector2(0.95, 0.95), Vector2(0.4, 0.75), Vector2(0.0, 0.45), Vector2(-0.4, 0.85)]), fg, key, lw)
			_fill(ci, _pts(c, s, [Vector2(-0.2, -0.3), Vector2(0.2, -0.65), Vector2(0.75, -1.0), Vector2(0.45, -0.3), Vector2(0.1, 0.0)]), fg.darkened(0.18), key, 0.0)
		"anchor":
			ci.draw_arc(c + Vector2(0, s * 0.15), s * 0.78, 0.15, PI - 0.15, 16, fg, maxf(s * 0.2, 1.6), true)
			ci.draw_line(c + Vector2(0, -s * 0.75), c + Vector2(0, s * 0.95), fg, maxf(s * 0.2, 1.6), true)
			ci.draw_line(c + Vector2(-s * 0.4, -s * 0.38), c + Vector2(s * 0.4, -s * 0.38), fg, maxf(s * 0.16, 1.4), true)
			ci.draw_arc(c + Vector2(0, -s * 0.88), s * 0.16, 0, TAU, 10, fg, maxf(s * 0.12, 1.2), true)
		"sword":
			_fill(ci, _pts(c, s, [Vector2(-0.1, -1), Vector2(0.1, -1), Vector2(0.1, 0.45), Vector2(-0.1, 0.45)]), fg, key, lw)
			_fill(ci, _pts(c, s, [Vector2(-0.55, 0.45), Vector2(0.55, 0.45), Vector2(0.55, 0.62), Vector2(-0.55, 0.62)]), fg, key, lw)
			_fill(ci, _pts(c, s, [Vector2(-0.1, 0.62), Vector2(0.1, 0.62), Vector2(0.1, 0.95), Vector2(-0.1, 0.95)]), fg, key, lw)
		"wheat":
			ci.draw_line(c + Vector2(0, s), c + Vector2(0, -s * 0.8), fg, maxf(s * 0.1, 1.0), true)
			for i in 5:
				var y := -s * 0.7 + i * s * 0.32
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, y), c + Vector2(-s * 0.4, y - s * 0.2), c + Vector2(-s * 0.2, y + s * 0.05)]), fg)
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, y), c + Vector2(s * 0.4, y - s * 0.2), c + Vector2(s * 0.2, y + s * 0.05)]), fg)
		"tree":
			ci.draw_rect(Rect2(c + Vector2(-s * 0.1, s * 0.4), Vector2(s * 0.2, s * 0.6)), fg)
			for i in 3:
				var w2 := 0.85 - i * 0.2
				var yy := -0.2 - i * 0.42 + 0.5
				_fill(ci, _pts(c, s, [Vector2(-w2, yy), Vector2(0, yy - 0.7), Vector2(w2, yy)]), fg, key, lw)
		"ship":
			_fill(ci, _pts(c, s, [Vector2(-1, 0.35), Vector2(1, 0.35), Vector2(0.65, 0.85), Vector2(-0.65, 0.85)]), fg, key, lw)
			ci.draw_line(c + Vector2(0, 0.35 * s), c + Vector2(0, -s), fg, maxf(s * 0.1, 1.0), true)
			_fill(ci, _pts(c, s, [Vector2(0.05, -0.9), Vector2(0.75, 0.2), Vector2(0.05, 0.2)]), fg, key, lw)
			_fill(ci, _pts(c, s, [Vector2(-0.05, -0.65), Vector2(-0.6, 0.2), Vector2(-0.05, 0.2)]), fg, key, lw)
		"rose":
			for i in 5:
				var a5 := -PI / 2.0 + i * TAU / 5.0
				ci.draw_circle(c + Vector2(cos(a5), sin(a5)) * s * 0.55, s * 0.42, fg)
			ci.draw_circle(c, s * 0.28, bg)
			ci.draw_circle(c, s * 0.14, fg)
		"key":
			ci.draw_arc(c + Vector2(0, -s * 0.55), s * 0.38, 0, TAU, 14, fg, maxf(s * 0.18, 1.5), true)
			ci.draw_line(c + Vector2(0, -s * 0.2), c + Vector2(0, s), fg, maxf(s * 0.16, 1.4), true)
			ci.draw_line(c + Vector2(0, s * 0.6), c + Vector2(s * 0.4, s * 0.6), fg, maxf(s * 0.16, 1.4), true)
			ci.draw_line(c + Vector2(0, s * 0.9), c + Vector2(s * 0.3, s * 0.9), fg, maxf(s * 0.16, 1.4), true)
		"horse":
			_fill(ci, _pts(c, s, [Vector2(-0.9, 1), Vector2(-0.7, 0.2), Vector2(-0.3, -0.1), Vector2(-0.1, -0.7), Vector2(0.15, -1), Vector2(0.55, -0.85), Vector2(0.95, -0.4), Vector2(0.7, -0.2),
				Vector2(0.35, -0.25), Vector2(0.3, 0.2), Vector2(0.6, 1), Vector2(0.25, 1), Vector2(0.0, 0.4), Vector2(-0.3, 0.9), Vector2(-0.4, 1.0)]), fg, key, lw)
