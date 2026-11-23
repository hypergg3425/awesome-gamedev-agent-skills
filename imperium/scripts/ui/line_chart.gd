class_name LineChart
extends Control
## Tiny dependency-free line chart for statistics panels.

var values: Array = []
var color := Color.WHITE

static func make(vals: Array, col: Color, height: float = 120.0) -> LineChart:
	var c := LineChart.new()
	c.values = vals
	c.color = col
	c.custom_minimum_size = Vector2(0, height)
	return c

func _draw() -> void:
	var r := Rect2(Vector2(46, 8), size - Vector2(56, 26))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.06, 0.12, 0.6), true)
	if values.size() < 2:
		draw_string(ThemeDB.fallback_font, Vector2(12, size.y / 2.0), "—", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.4))
		return
	var lo := 1e18
	var hi := -1e18
	for v in values:
		lo = minf(lo, float(v))
		hi = maxf(hi, float(v))
	if hi - lo < 0.0001:
		hi = lo + 1.0
	var pts := PackedVector2Array()
	for i in values.size():
		var x := r.position.x + r.size.x * float(i) / float(values.size() - 1)
		var y := r.end.y - r.size.y * (float(values[i]) - lo) / (hi - lo)
		pts.append(Vector2(x, y))
	for k in 3:
		var yy := r.position.y + r.size.y * float(k) / 2.0
		draw_line(Vector2(r.position.x, yy), Vector2(r.end.x, yy), Color(1, 1, 1, 0.08), 1.0)
	draw_polyline(pts, color, 2.5, true)
	var f := ThemeDB.fallback_font
	draw_string(f, Vector2(4, r.position.y + 12), Util.fmt_num(hi, 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.6))
	draw_string(f, Vector2(4, r.end.y), Util.fmt_num(lo, 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.6))
