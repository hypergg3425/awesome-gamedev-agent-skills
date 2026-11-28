extends Node2D
## Rivers and mountain passes (Defs.features) in world space. A river is drawn along the longest shared border of the two
## provinces it separates (the data only says which pair of provinces a named river runs between: approximate). Passes are
## small saddle markers at the middle of the border of their pair. Widths are screen-pixel based; visibility follows MapZoom.

var view: MapView
var rivers: Array = []     # [{pts: PackedVector2Array, width: int, name: String}]
var passes: Array = []     # [{pos: Vector2, name: String}]
const RIVER_COL := Color(0.30, 0.55, 0.82)

func build(geom: MapGeometry) -> void:
	rivers.clear()
	passes.clear()
	var pair_line := {}
	for b in geom.borders:
		var key := Util.pair_key(str(Defs.province_ids[int(b["a"])]), str(Defs.province_ids[int(b["b"])]))
		pair_line[key] = MapLines.longest(b["lines"])
	for r in Defs.features.get("rivers", []):
		var arr: Array = r
		var key := Util.pair_key(str(arr[0]), str(arr[1]))
		if not pair_line.has(key) or (pair_line[key] as PackedVector2Array).size() < 2:
			continue
		var meta: Dictionary = arr[2] if arr.size() > 2 and arr[2] is Dictionary else {}
		rivers.append({"pts": MapLines.chaikin(MapLines.chaikin(pair_line[key])), "width": clampi(int(meta.get("width", 1)), 1, 3), "name": str(meta.get("name", ""))})
	for p in Defs.features.get("passes", []):
		var arr2: Array = p
		var key2 := Util.pair_key(str(arr2[0]), str(arr2[1]))
		if not pair_line.has(key2) or (pair_line[key2] as PackedVector2Array).size() < 2:
			continue
		var meta2: Dictionary = arr2[2] if arr2.size() > 2 and arr2[2] is Dictionary else {}
		passes.append({"pos": MapLines.midpoint(pair_line[key2]), "name": str(meta2.get("name", ""))})
	queue_redraw()

func _draw() -> void:
	if view == null:
		return
	var z := maxf(view.zoom, 0.05)
	for r in rivers:
		var w: int = r["width"]
		if not MapZoom.show_rivers(z, w):
			continue
		var px := 0.9 + 0.8 * float(w)
		draw_polyline(r["pts"], Color(0.04, 0.12, 0.22, 0.35), (px + 1.6) / z, true)
		draw_polyline(r["pts"], RIVER_COL, px / z, true)
	if MapZoom.show_passes(z):
		for p in passes:
			var c: Vector2 = p["pos"]
			var s := 6.0 / z
			var pts := PackedVector2Array([c + Vector2(-s, s * 0.6), c + Vector2(0, -s), c + Vector2(s, s * 0.6)])
			draw_colored_polygon(pts, Color(0.96, 0.9, 0.7, 0.95))
			pts.append(pts[0])
			draw_polyline(pts, Color(0.12, 0.08, 0.05, 0.95), 1.6 / z, true)
			draw_line(c + Vector2(-s * 0.6, s * 0.6), c + Vector2(s * 0.6, s * 0.6), Color(0.12, 0.08, 0.05, 0.95), 2.2 / z)
