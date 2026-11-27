class_name FrameStyle
extends StyleBox
## Procedural panel/button style used by the shared theme: vertical gradient fill, rounded corners, outer border,
## optional inset hairline, top gloss, soft shadow and gold corner ornaments. Drawn with RenderingServer calls so one
## class restyles every panel, card, tab and button that uses the theme (see docs/ART_DIRECTION.md).

enum Corner { NONE, DIAMOND, FLOURISH }

var top := Color("1f3158")
var bottom := Color("14203a")
var border := Color("c9a24a")
var border_w := 2.0
var inner := Color(0, 0, 0, 0)
var inner_inset := 5.0
var radius := 8.0
var gloss := 0.0
var shadow := 0.0
var shadow_size := 10.0
var corner := Corner.NONE
var corner_color := Color("e6c876")

static func make(p_top: Color, p_bottom: Color, p_border: Color, p_bw: float = 2.0, p_radius: float = 8.0, margin: float = 10.0) -> FrameStyle:
	var s := FrameStyle.new()
	s.top = p_top
	s.bottom = p_bottom
	s.border = p_border
	s.border_w = p_bw
	s.radius = p_radius
	s.content_margin_left = margin
	s.content_margin_right = margin
	s.content_margin_top = maxf(margin - 2.0, 0.0)
	s.content_margin_bottom = maxf(margin - 2.0, 0.0)
	return s

## Rounded rectangle outline as a point list (corner arcs sampled with `seg` steps).
static func round_points(r: Rect2, rad: float, seg: int = 5) -> PackedVector2Array:
	var pts := PackedVector2Array()
	rad = minf(rad, minf(r.size.x, r.size.y) * 0.5)
	if rad < 1.0:
		pts.append(r.position)
		pts.append(Vector2(r.end.x, r.position.y))
		pts.append(r.end)
		pts.append(Vector2(r.position.x, r.end.y))
		return pts
	var centers := [Vector2(r.end.x - rad, r.position.y + rad), Vector2(r.end.x - rad, r.end.y - rad),
			Vector2(r.position.x + rad, r.end.y - rad), Vector2(r.position.x + rad, r.position.y + rad)]
	for k in 4:
		for i in seg + 1:
			var a := -PI * 0.5 + (float(k) + float(i) / float(seg)) * PI * 0.5
			pts.append((centers[k] as Vector2) + Vector2(cos(a), sin(a)) * rad)
	return pts

func _vertex_colors(pts: PackedVector2Array, r: Rect2) -> PackedColorArray:
	var cols := PackedColorArray()
	cols.resize(pts.size())
	for i in pts.size():
		cols[i] = top.lerp(bottom, clampf((pts[i].y - r.position.y) / maxf(r.size.y, 1.0), 0.0, 1.0))
	return cols

func _outline(ci: RID, pts: PackedVector2Array, col: Color, w: float) -> void:
	var closed := PackedVector2Array(pts)
	closed.append(pts[0])
	var cols := PackedColorArray()
	cols.resize(closed.size())
	cols.fill(col)
	RenderingServer.canvas_item_add_polyline(ci, closed, cols, w, true)

func _get_draw_rect(rect: Rect2) -> Rect2:
	return rect.grow(shadow_size) if shadow > 0.0 else rect

func _draw(ci: RID, rect: Rect2) -> void:
	if rect.size.x < 2.0 or rect.size.y < 2.0:
		return
	if shadow > 0.0:
		for i in 3:
			var g := shadow_size * float(3 - i) / 3.0
			var sp := round_points(Rect2(rect.position + Vector2(0, shadow_size * 0.25), rect.size).grow(g), radius + g, 4)
			RenderingServer.canvas_item_add_polygon(ci, sp, PackedColorArray([Color(0, 0, 0, shadow * 0.33)]))
	var half := border_w * 0.5
	var body := rect.grow(-half)
	var pts := round_points(body, radius - half)
	RenderingServer.canvas_item_add_polygon(ci, pts, _vertex_colors(pts, rect))
	if gloss > 0.0 and rect.size.y > 12.0:
		var gp := round_points(Rect2(body.position + Vector2(1, 1), Vector2(body.size.x - 2.0, minf(body.size.y * 0.45, 22.0))), maxf(radius - 2.0, 1.0), 4)
		var gc := PackedColorArray()
		gc.resize(gp.size())
		for i in gp.size():
			gc[i] = Color(1, 1, 1, gloss * (1.0 - clampf((gp[i].y - gp[0].y) / 22.0, 0.0, 1.0)))
		RenderingServer.canvas_item_add_polygon(ci, gp, gc)
	if border_w > 0.0 and border.a > 0.0:
		_outline(ci, pts, border, border_w)
	if inner.a > 0.0 and rect.size.x > inner_inset * 4.0 and rect.size.y > inner_inset * 4.0:
		_outline(ci, round_points(rect.grow(-inner_inset), maxf(radius - inner_inset, 2.0), 4), inner, 1.0)
	if corner != Corner.NONE and rect.size.x > 60.0 and rect.size.y > 60.0:
		_corners(ci, rect)

func _corners(ci: RID, rect: Rect2) -> void:
	var inset := inner_inset if inner.a > 0.0 else 3.0
	var d := 5.0
	var spots := [rect.position + Vector2(inset, inset), Vector2(rect.end.x - inset, rect.position.y + inset),
			rect.end - Vector2(inset, inset), Vector2(rect.position.x + inset, rect.end.y - inset)]
	var dirs := [Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1), Vector2(1, -1)]
	for i in 4:
		var c: Vector2 = spots[i]
		var dv: Vector2 = dirs[i]
		var diamond := PackedVector2Array([c + dv * Vector2(d * 1.2, d * 1.2) + Vector2(d, 0) * dv.x, c + dv * Vector2(d * 1.2, d * 1.2) + Vector2(0, d) * dv.y,
				c + dv * Vector2(d * 1.2, d * 1.2) - Vector2(d, 0) * dv.x, c + dv * Vector2(d * 1.2, d * 1.2) - Vector2(0, d) * dv.y])
		RenderingServer.canvas_item_add_polygon(ci, diamond, PackedColorArray([corner_color]))
		if corner == Corner.FLOURISH:
			var cols := PackedColorArray([corner_color, corner_color])
			RenderingServer.canvas_item_add_polyline(ci, PackedVector2Array([c + dv * Vector2(d * 2.6, 0), c + dv * Vector2(d * 6.0, 0)]), cols, 1.5, true)
			RenderingServer.canvas_item_add_polyline(ci, PackedVector2Array([c + dv * Vector2(0, d * 2.6), c + dv * Vector2(0, d * 6.0)]), cols, 1.5, true)
