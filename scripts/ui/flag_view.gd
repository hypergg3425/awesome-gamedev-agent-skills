class_name FlagView
extends Control
## Procedural heraldic flag. Original stylised banners drawn from {p: pattern, c: [colours], charge}.

var spec: Dictionary = {}
var fallback_color := Color.GRAY

func setup(flag: Dictionary, color: Color) -> FlagView:
	spec = flag
	fallback_color = color
	custom_minimum_size = Vector2(54, 36) if custom_minimum_size == Vector2.ZERO else custom_minimum_size
	queue_redraw()
	return self

func _col(i: int, d: Color) -> Color:
	var arr: Array = spec.get("c", [])
	if i < arr.size():
		return Color.html(str(arr[i]))
	return d

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var pat := str(spec.get("p", "plain"))
	var c0 := _col(0, fallback_color)
	var c1 := _col(1, c0.lightened(0.4))
	var c2 := _col(2, c1.lightened(0.3))
	draw_rect(r, c0, true)
	match pat:
		"hstripes":
			var cols := [c0, c1, c2] if (spec.get("c", []) as Array).size() >= 3 else [c0, c1]
			var h := r.size.y / float(cols.size())
			for i in cols.size():
				draw_rect(Rect2(0, h * i, r.size.x, h + 1), cols[i], true)
		"vstripes":
			var cols2 := [c0, c1, c2] if (spec.get("c", []) as Array).size() >= 3 else [c0, c1]
			var w := r.size.x / float(cols2.size())
			for i in cols2.size():
				draw_rect(Rect2(w * i, 0, w + 1, r.size.y), cols2[i], true)
		"pale":
			draw_rect(Rect2(r.size.x * 0.25, 0, r.size.x * 0.5, r.size.y), c1, true)
			draw_rect(Rect2(r.size.x * 0.75, 0, r.size.x * 0.25, r.size.y), c2 if (spec.get("c", []) as Array).size() >= 3 else c0, true)
		"cross":
			var t := r.size.y * 0.22
			if (spec.get("c", []) as Array).size() >= 3:
				draw_rect(Rect2(0, r.size.y * 0.5 - t * 0.7, r.size.x, t * 1.4), c2, true)
				draw_rect(Rect2(r.size.x * 0.5 - t * 0.7, 0, t * 1.4, r.size.y), c2, true)
			draw_rect(Rect2(0, r.size.y * 0.5 - t * 0.5, r.size.x, t), c1, true)
			draw_rect(Rect2(r.size.x * 0.5 - t * 0.5, 0, t, r.size.y), c1, true)
		"nordic":
			var t2 := r.size.y * 0.2
			if (spec.get("c", []) as Array).size() >= 3:
				draw_rect(Rect2(0, r.size.y * 0.5 - t2 * 0.75, r.size.x, t2 * 1.5), c2, true)
				draw_rect(Rect2(r.size.x * 0.3 - t2 * 0.75, 0, t2 * 1.5, r.size.y), c2, true)
			draw_rect(Rect2(0, r.size.y * 0.5 - t2 * 0.5, r.size.x, t2), c1, true)
			draw_rect(Rect2(r.size.x * 0.3 - t2 * 0.5, 0, t2, r.size.y), c1, true)
		"saltire":
			_band(Vector2(0, 0), r.size, r.size.y * 0.24, c1)
			_band(Vector2(r.size.x, 0), Vector2(0, r.size.y), r.size.y * 0.24, c1)
		"canton":
			draw_rect(Rect2(0, 0, r.size.x * 0.42, r.size.y * 0.55), c1, true)
		"bend":
			_band(Vector2(0, 0), r.size, r.size.y * 0.32, c1)
		"chevron":
			draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(r.size.x * 0.55, r.size.y * 0.5), Vector2(0, r.size.y)]), c1)
		"quartered":
			draw_rect(Rect2(r.size.x * 0.5, 0, r.size.x * 0.5, r.size.y * 0.5), c1, true)
			draw_rect(Rect2(0, r.size.y * 0.5, r.size.x * 0.5, r.size.y * 0.5), c1, true)
		"disc":
			draw_circle(r.size * 0.5, r.size.y * 0.32, c1)
		"border":
			var b := r.size.y * 0.12
			draw_rect(r, c1, false, b * 2.0)
	_charge(str(spec.get("charge", "none")), r, c1 if pat in ["plain", "hstripes", "vstripes", "quartered"] else c1.lightened(0.0), c2)
	draw_rect(r, Color(0, 0, 0, 0.55), false, 1.5)

func _charge(kind: String, r: Rect2, col: Color, col2: Color) -> void:
	var c := r.size * 0.5
	if str(spec.get("p", "")) == "canton":
		c = Vector2(r.size.x * 0.21, r.size.y * 0.275)
	var s := r.size.y * 0.26
	var fg := Color.WHITE if col.get_luminance() < 0.55 else Color(0.12, 0.1, 0.08)
	if str(spec.get("p", "")) in ["plain", "hstripes", "vstripes"]:
		fg = _col(1, Color.WHITE)
		if (spec.get("c", []) as Array).size() < 2:
			fg = Color.WHITE
	if str(spec.get("p", "")) == "disc":
		fg = _col(2, Color.WHITE)
	match kind:
		"star":
			var pts := PackedVector2Array()
			for i in 10:
				var a := -PI / 2.0 + i * PI / 5.0
				var rr := s if i % 2 == 0 else s * 0.42
				pts.append(c + Vector2(cos(a), sin(a)) * rr)
			draw_colored_polygon(pts, fg)
		"crescent":
			draw_circle(c, s, fg)
			draw_circle(c + Vector2(s * 0.42, 0), s * 0.85, _bg_at(c + Vector2(s * 0.42, 0)))
		"sun":
			draw_circle(c, s * 0.55, fg)
			for i in 12:
				var a2 := i * TAU / 12.0
				draw_line(c + Vector2(cos(a2), sin(a2)) * s * 0.7, c + Vector2(cos(a2), sin(a2)) * s * 1.05, fg, 1.6)
		"cross":
			draw_rect(Rect2(c.x - s * 0.18, c.y - s, s * 0.36, s * 2.0), fg, true)
			draw_rect(Rect2(c.x - s, c.y - s * 0.18, s * 2.0, s * 0.36), fg, true)
		"fleur":
			draw_circle(c + Vector2(0, -s * 0.1), s * 0.3, fg)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s * 0.28, -s * 0.15), c + Vector2(-s * 0.28, -s * 0.15)]), fg)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.7, s * 0.1), c + Vector2(-s * 0.15, -s * 0.4), c + Vector2(-s * 0.1, s * 0.3)]), fg)
			draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.7, s * 0.1), c + Vector2(s * 0.15, -s * 0.4), c + Vector2(s * 0.1, s * 0.3)]), fg)
			draw_rect(Rect2(c.x - s * 0.5, c.y + s * 0.4, s, s * 0.14), fg, true)
			draw_rect(Rect2(c.x - s * 0.1, c.y + s * 0.1, s * 0.2, s * 0.8), fg, true)
		"crown":
			var base := c + Vector2(0, s * 0.5)
			draw_rect(Rect2(base.x - s, base.y - s * 0.3, s * 2, s * 0.4), fg, true)
			draw_colored_polygon(PackedVector2Array([base + Vector2(-s, -s * 0.3), base + Vector2(-s, -s * 1.1), base + Vector2(-s * 0.5, -s * 0.6), base + Vector2(0, -s * 1.2), base + Vector2(s * 0.5, -s * 0.6), base + Vector2(s, -s * 1.1), base + Vector2(s, -s * 0.3)]), fg)
		"tower":
			draw_rect(Rect2(c.x - s * 0.55, c.y - s * 0.6, s * 1.1, s * 1.6), fg, true)
			for i in 3:
				draw_rect(Rect2(c.x - s * 0.55 + i * s * 0.45, c.y - s * 0.95, s * 0.3, s * 0.4), fg, true)
		"eagle":
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s * 1.1, -s * 0.3), c + Vector2(s * 0.45, s * 0.1), c + Vector2(s * 0.3, s), c + Vector2(-s * 0.3, s), c + Vector2(-s * 0.45, s * 0.1), c + Vector2(-s * 1.1, -s * 0.3)]), fg)
		"lion":
			draw_circle(c + Vector2(s * 0.5, -s * 0.5), s * 0.35, fg)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.8, s), c + Vector2(-s * 0.6, -s * 0.2), c + Vector2(s * 0.4, -s * 0.4), c + Vector2(s * 0.6, s), c + Vector2(s * 0.1, s * 0.4)]), fg)
		"dragon":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-s, s * 0.5), c + Vector2(-s * 0.4, -s * 0.8), c + Vector2(s * 0.2, -s * 0.2), c + Vector2(s, -s * 0.9), c + Vector2(s * 0.6, s * 0.3), c + Vector2(s * 0.1, s * 0.8)]), fg)
		"anchor":
			draw_arc(c + Vector2(0, s * 0.2), s * 0.8, 0.1, PI - 0.1, 14, fg, 2.0)
			draw_line(c + Vector2(0, -s), c + Vector2(0, s * 0.9), fg, 2.4)
			draw_line(c + Vector2(-s * 0.4, -s * 0.5), c + Vector2(s * 0.4, -s * 0.5), fg, 2.0)

## Draw a diagonal band between two corners, clipped to the flag rectangle.
func _band(a: Vector2, b: Vector2, w: float, col: Color) -> void:
	var d := (b - a).normalized()
	var n := Vector2(-d.y, d.x) * w * 0.5
	var poly := PackedVector2Array([a - d * 20.0 + n, b + d * 20.0 + n, b + d * 20.0 - n, a - d * 20.0 - n])
	var box := PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)])
	for piece in Geometry2D.intersect_polygons(poly, box):
		draw_colored_polygon(piece, col)

func _bg_at(_p: Vector2) -> Color:
	var pat := str(spec.get("p", "plain"))
	return _col(0, fallback_color) if pat not in ["disc"] else _col(1, fallback_color)

static func make(flag: Dictionary, color: Color, size_v: Vector2 = Vector2(54, 36)) -> FlagView:
	var f := FlagView.new()
	f.custom_minimum_size = size_v
	f.size = size_v
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return f.setup(flag, color)
