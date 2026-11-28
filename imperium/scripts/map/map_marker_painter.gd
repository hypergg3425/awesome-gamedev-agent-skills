class_name MapMarkerPainter
extends RefCounted
## Screen-space drawing of the campaign-map markers built by MapMarkers. All drawing goes through a CanvasItem so the
## overlay stays the only node that redraws; detail depends on MapZoom, overlapping markers are culled on a coarse grid.

const CELL := 30.0
const INK := Color(0.07, 0.05, 0.04, 0.95)
const GOLD := Color(0.96, 0.8, 0.28)
const PORT_COL := Color(0.45, 0.75, 0.95)
const FORT_COL := Color(0.85, 0.82, 0.76)

## Settlements, ports, forts and roads of the provinces inside the viewport. Returns the number of glyphs drawn.
static func draw_cities(ci: CanvasItem, view: MapView, font: Font, cities: Array) -> int:
	var z := view.zoom
	var min_rank := MapZoom.min_city_rank(z)
	var sc := MapZoom.marker_scale(z)
	var vr := Rect2(Vector2.ZERO, view.size).grow(24.0)
	var taken := {}
	var drawn := 0
	for c in cities:
		var rank: int = c["rank"]
		if rank < min_rank:
			continue   # list is sorted by rank: nothing further qualifies
		var sp := view.world_to_screen(c["pos"]) + Vector2(0.0, -12.0 * sc)   # above the army shield / province label
		if not vr.has_point(sp):
			continue
		var key := Vector2i(int(floor(sp.x / (CELL * sc))), int(floor(sp.y / (CELL * sc))))
		if taken.has(key) and rank < 3:
			continue
		taken[key] = true
		_city_glyph(ci, sp, rank, sc)
		drawn += 1
		if MapZoom.show_ports(z):
			if c["port"]:
				_port_glyph(ci, sp + Vector2(9.0, 6.0) * sc, sc)
			if int(c["fort"]) > 0:
				_fort_glyph(ci, sp + Vector2(-9.0, 6.0) * sc, sc, int(c["fort"]))
		if MapZoom.show_roads(z) and int(c["road"]) > 0:
			var rw := clampf(float(c["road"]), 1.0, 4.0)
			ci.draw_line(sp + Vector2(-5, 9) * sc, sp + Vector2(5, 9) * sc, Color(0.62, 0.45, 0.28, 0.95), 1.0 + rw * 0.5)
		_city_label(ci, font, sp, c, rank, sc, z, view)
	return drawn

static func _city_glyph(ci: CanvasItem, sp: Vector2, rank: int, sc: float) -> void:
	match rank:
		3:
			var r := 6.5 * sc
			var pts := PackedVector2Array([sp + Vector2(0, -r), sp + Vector2(r, 0), sp + Vector2(0, r), sp + Vector2(-r, 0)])
			ci.draw_colored_polygon(pts, GOLD)
			pts.append(pts[0])
			ci.draw_polyline(pts, INK, 1.6)
			ci.draw_circle(sp, 1.8 * sc, INK)
		2:
			ci.draw_circle(sp, 5.0 * sc, Color(1, 1, 1, 0.95))
			ci.draw_circle(sp, 3.2 * sc, INK)
		1:
			ci.draw_rect(Rect2(sp - Vector2(3.2, 3.2) * sc, Vector2(6.4, 6.4) * sc), Color(1, 1, 1, 0.92))
			ci.draw_rect(Rect2(sp - Vector2(3.2, 3.2) * sc, Vector2(6.4, 6.4) * sc), INK, false, 1.2)
		_:
			ci.draw_circle(sp, 2.4 * sc, Color(1, 1, 1, 0.85))
			ci.draw_arc(sp, 2.4 * sc, 0, TAU, 8, INK, 1.0)

static func _city_label(ci: CanvasItem, font: Font, sp: Vector2, c: Dictionary, rank: int, sc: float, z: float, view: MapView) -> void:
	var show_name := (rank >= 2 and z >= 1.6) or z >= MapZoom.HIGH_ZOOM
	if c["generic"] and z >= MapZoom.PROVINCE_LABEL_MIN:
		show_name = false   # the province label already carries this name
	if not show_name:
		return
	var fs := 11 if rank >= 2 else 10
	var txt: String = c["name"]
	ci.draw_string_outline(font, sp + Vector2(8.0 * sc, 4.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, Color(0, 0, 0, 0.6))
	ci.draw_string(font, sp + Vector2(8.0 * sc, 4.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 0.96, 0.82, 0.95))
	var more: Array = c["more"]
	if z >= MapZoom.HIGH_ZOOM and not more.is_empty():
		var i: int = Defs.province_index[c["pid"]]
		if (view.prov_bbox[i] as Rect2).size.x * z >= 170.0:
			var t2 := " · ".join(PackedStringArray(more))
			ci.draw_string_outline(font, sp + Vector2(8.0 * sc, 16.0), t2, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, 3, Color(0, 0, 0, 0.55))
			ci.draw_string(font, sp + Vector2(8.0 * sc, 16.0), t2, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.86, 0.84, 0.76, 0.85))

static func _port_glyph(ci: CanvasItem, sp: Vector2, sc: float) -> void:
	var r := 4.2 * sc
	ci.draw_circle(sp, r + 1.2, INK)
	ci.draw_circle(sp, r, PORT_COL)
	ci.draw_line(sp + Vector2(0, -r * 0.55), sp + Vector2(0, r * 0.6), INK, 1.4)
	ci.draw_arc(sp + Vector2(0, r * 0.05), r * 0.55, 0.2, PI - 0.2, 6, INK, 1.2)

static func _fort_glyph(ci: CanvasItem, sp: Vector2, sc: float, level: int) -> void:
	var r := (3.6 + 0.5 * minf(float(level), 3.0)) * sc
	var rect := Rect2(sp - Vector2(r, r * 0.8), Vector2(r * 2.0, r * 1.6))
	ci.draw_rect(rect.grow(1.2), INK, true)
	ci.draw_rect(rect, FORT_COL, true)
	for k in 3:
		ci.draw_rect(Rect2(rect.position + Vector2(r * 2.0 * float(k) / 3.0, -2.0), Vector2(r * 0.55, 2.4)), FORT_COL, true)

## Crossed swords on a red disc for battles of the last turns; older ones fade.
static func draw_battles(ci: CanvasItem, view: MapView, battles: Array) -> void:
	var vr := Rect2(Vector2.ZERO, view.size).grow(20.0)
	var sc := MapZoom.marker_scale(view.zoom)
	for b in battles:
		var sp := view.world_to_screen(b["pos"])
		if not vr.has_point(sp):
			continue
		var a := clampf(1.0 - 0.28 * float(b["age"]), 0.35, 1.0)
		var r := 8.5 * sc
		var ring := Color(0.78, 0.16, 0.12, a) if not b["naval"] else Color(0.2, 0.4, 0.75, a)
		ci.draw_circle(sp, r + 1.5, Color(0, 0, 0, a))
		ci.draw_circle(sp, r, ring)
		var w := Color(1, 0.95, 0.85, a)
		ci.draw_line(sp + Vector2(-r, -r) * 0.62, sp + Vector2(r, r) * 0.62, w, 2.0)
		ci.draw_line(sp + Vector2(r, -r) * 0.62, sp + Vector2(-r, r) * 0.62, w, 2.0)

## Supply lines: dark under-stroke plus a coloured line and an end cap on the army.
static func draw_supply(ci: CanvasItem, view: MapView, lines: Array) -> void:
	for l in lines:
		var pts := PackedVector2Array()
		for p in (l["points"] as PackedVector2Array):
			pts.append(view.world_to_screen(p))
		ci.draw_polyline(pts, Color(0, 0, 0, 0.6), 5.0, true)
		ci.draw_polyline(pts, l["color"], 2.6, true)
		ci.draw_circle(pts[0], 4.0, l["color"])

## Trade routes as shallow arcs; thickness follows the value.
static func draw_trade(ci: CanvasItem, view: MapView, routes: Array) -> void:
	var vr := Rect2(Vector2.ZERO, view.size).grow(60.0)
	for r in routes:
		var a := view.world_to_screen(r["a"])
		var b := view.world_to_screen(r["b"])
		if not (vr.has_point(a) or vr.has_point(b)):
			continue
		var d := b - a
		var mid := (a + b) * 0.5 + Vector2(-d.y, d.x) * 0.14
		var pts := PackedVector2Array()
		for k in 13:
			var t := float(k) / 12.0
			pts.append(a.lerp(mid, t).lerp(mid.lerp(b, t), t))
		var w := 1.2 + 3.2 * float(r["w"])
		ci.draw_polyline(pts, Color(0.1, 0.07, 0.02, 0.55), w + 2.0, true)
		ci.draw_polyline(pts, Color(0.98, 0.84, 0.32, 0.9), w, true)
		ci.draw_circle(b, 2.0 + 2.5 * float(r["w"]), Color(1, 0.93, 0.6))
