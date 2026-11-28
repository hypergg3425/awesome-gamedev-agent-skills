extends Control
## Screen-space overlay: country/province/sea labels, army markers, routes, indicators.
## All content is supplied by the campaign controller through `data` (labels, markers, routes).

var view: MapView
var data: Dictionary = {"country_labels": [], "markers": [], "routes": [], "sieges": [], "cities": [], "battles": [], "supply": [], "trade": [], "mode": "political"}
var font: Font
var show_province_labels := true
var show_country_labels := true
var last_draw_usec := 0         # CPU cost of the last _draw (measured by tests/map_shots)
var last_city_glyphs := 0
var _width_cache: Dictionary = {}

func _ready() -> void:
	font = ThemeDB.fallback_font

## String width cache: text shaping is the dominant CPU cost of the label passes.
func _tw(txt: String, fs: int) -> float:
	var key := txt + "|" + str(fs)
	if not _width_cache.has(key):
		if _width_cache.size() > 4000:
			_width_cache.clear()
		_width_cache[key] = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	return _width_cache[key]

func _draw() -> void:
	if view == null:
		return
	var t0 := Time.get_ticks_usec()
	var z := view.zoom
	var vr := Rect2(Vector2.ZERO, size)
	# sea labels
	if z < MapZoom.SEA_LABEL_MAX:
		for s in Defs.seas:
			var sp: Vector2 = view.world_to_screen(Vector2(s["pos"][0], s["pos"][1]))
			if not vr.grow(-20).has_point(sp):
				continue
			var txt: String = s["name_tr"] if Loc.lang == "tr" else s["name"]
			var fs := int(clampf(float(s.get("size", 5)) * z * 1.1, 10, 22))
			var w := _tw(txt, fs)
			draw_string(font, sp - Vector2(w * 0.5, 0), txt.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.7, 0.8, 0.9, 0.35))
	# country labels
	if show_country_labels and z < MapZoom.COUNTRY_LABEL_MAX:
		for c in data.get("country_labels", []):
			var sp: Vector2 = view.world_to_screen(c["pos"])
			var ext: float = c["extent"] * z
			if ext < 36.0 or not vr.grow(60).has_point(sp):
				continue
			var fs := int(clampf(ext * 0.115, 11, 34))
			var txt: String = c["text"]
			var tw := _tw(txt, fs)
			var rot: float = c.get("rot", 0.0)
			draw_set_transform(sp, rot, Vector2.ONE)
			draw_string_outline(font, Vector2(-tw * 0.5, fs * 0.35), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0.05, 0.04, 0.03, 0.55))
			draw_string(font, Vector2(-tw * 0.5, fs * 0.35), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.97, 0.93, 0.82, 0.88))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# province labels
	if show_province_labels and z > MapZoom.PROVINCE_LABEL_MIN:
		for pi in view.n_prov:
			var r: Rect2 = view.prov_bbox[pi]
			if Defs.provinces[Defs.province_ids[pi]].get("archipelago", false) and z < 5.0:
				continue
			var wpx := r.size.x * z
			if wpx < 70.0:
				continue
			var sp: Vector2 = view.world_to_screen(view.prov_center[pi])
			if not vr.has_point(sp):
				continue
			var fs := int(clampf(wpx * 0.075, 10, 17))
			var txt: String = Defs.province_name(Defs.province_ids[pi]).split(" (")[0]   # long scenario names: short form on the map, full name in panels
			var tw := _tw(txt, fs)
			draw_string_outline(font, sp + Vector2(-tw * 0.5, 18), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, Color(0, 0, 0, 0.55))
			draw_string(font, sp + Vector2(-tw * 0.5, 18), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 0.97, 0.88, 0.92))
	# routes
	for r in data.get("routes", []):
		var pts: PackedVector2Array = PackedVector2Array()
		for p in r["points"]:
			pts.append(view.world_to_screen(p))
		if pts.size() >= 2:
			draw_polyline(pts, r.get("color", Color(1, 0.85, 0.3, 0.9)), 3.0, true)
			draw_circle(pts[pts.size() - 1], 5.0, r.get("color", Color(1, 0.85, 0.3, 0.9)))
	# trade routes, supply lines, settlements / infrastructure, battles
	MapMarkerPainter.draw_trade(self, view, data.get("trade", []))
	MapMarkerPainter.draw_supply(self, view, data.get("supply", []))
	last_city_glyphs = MapMarkerPainter.draw_cities(self, view, font, data.get("cities", []))
	MapMarkerPainter.draw_battles(self, view, data.get("battles", []))
	# sieges / fronts
	for s in data.get("sieges", []):
		var sp: Vector2 = view.world_to_screen(s["pos"])
		if vr.grow(10).has_point(sp):
			draw_arc(sp, 14.0, 0, TAU * float(s.get("progress", 0.5)), 24, Color(0.95, 0.35, 0.2), 3.0)
	# army markers (screen-space shields)
	var mf := font
	for m in data.get("markers", []):
		var sp: Vector2 = view.world_to_screen(m["pos"])
		if not vr.grow(20).has_point(sp):
			continue
		var col: Color = m["color"]
		var sz := 11.0 + (3.0 if m.get("selected", false) else 0.0)
		var rect := Rect2(sp - Vector2(sz * 1.3, sz * 0.8), Vector2(sz * 2.6, sz * 1.6))
		draw_rect(rect.grow(2), Color(0.05, 0.04, 0.03, 0.95), true)
		draw_rect(rect, col, true)
		if m.get("naval", false):
			draw_line(rect.position + Vector2(4, rect.size.y - 4), rect.position + Vector2(rect.size.x - 4, rect.size.y - 4), Color(1, 1, 1, 0.8), 2.0)
		if m.get("selected", false):
			draw_rect(rect.grow(4), Color(1, 0.9, 0.3), false, 2.0)
		var txt := str(m["text"])
		var fs := 12
		var tw := _tw(txt, fs)
		var lum := col.get_luminance()
		draw_string(mf, sp + Vector2(-tw * 0.5, 4.5), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.BLACK if lum > 0.55 else Color.WHITE)
	last_draw_usec = Time.get_ticks_usec() - t0
