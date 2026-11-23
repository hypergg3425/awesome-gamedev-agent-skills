class_name CampaignMap
extends RefCounted
## Connects the simulation state to the MapView: colours per map mode, borders, fronts,
## labels, army markers, route previews and selection highlights.

const TERRAIN_COL := {"plains": Color("c9c27a"), "steppe": Color("d4c48a"), "forest": Color("5e8a55"), "hills": Color("a89a6a"), "mountains": Color("8c8579"),
	"desert": Color("e2c98a"), "jungle": Color("3f7d4c"), "marsh": Color("6f8f7a"), "arctic": Color("dfe6ea")}

var view: MapView
var mode := "political"
var borders: MapBorders
var owners: Array = []
var selected := ""
var preview_route: Array = []
var preview_army := ""
var _label_cache: Array = []
var _label_sig := 0
var _geom: MapGeometry

func attach(v: MapView, geom: MapGeometry) -> void:
	view = v
	_geom = geom
	borders = MapBorders.new(geom)
	var pts: Array = []
	for pid in Defs.province_ids:
		pts.append(Vector2((Defs.provinces[pid]["label"] as Array)[0], (Defs.provinces[pid]["label"] as Array)[1]))
	v.set_label_points(pts)

func color_of(cid: String, fallback: Color = Color(0.4, 0.4, 0.4)) -> Color:
	var s: Dictionary = Game.state
	if cid == "" or not s["countries"].has(cid):
		return fallback
	return Util.color_from(s["countries"][cid]["color"], fallback)

## Recolour everything from the current state.
func refresh() -> void:
	if view == null or not Game.has_state():
		return
	var s: Dictionary = Game.state
	var me: String = Game.active_player
	owners.clear()
	var cb := bool(Settings.get_value("colorblind"))
	var maxes := _maxes(s)
	for i in Defs.province_ids.size():
		var pid: String = Defs.province_ids[i]
		var p: Dictionary = s["provinces"][pid]
		owners.append(p["owner"])
		var col := _mode_color(s, pid, p, me, maxes, cb)
		var shade := 0.94 + 0.08 * float(hash(pid) % 100) / 100.0
		view.set_base_color(i, Color(col.r * shade, col.g * shade, col.b * shade))
	apply_highlights()
	_rebuild_borders(s)
	_update_overlay(s)

func _maxes(s: Dictionary) -> Dictionary:
	var m := {"inc": 1.0, "pop": 1.0, "sup": 1.0, "trade": 1.0}
	var tr := TradeSystem.ensure(s)
	for pid in Defs.province_ids:
		var p: Dictionary = s["provinces"][pid]
		var pc := EconomySystem.province_calc(s, pid)
		m["inc"] = maxf(m["inc"], float(pc["tax"]) + float(pc["production"]) + float(pc["commerce"]))
		m["pop"] = maxf(m["pop"], float(p["pop"]))
		m["trade"] = maxf(m["trade"], float(tr["by_province"].get(pid, {}).get("value", 0.0)))
	m["sup"] = 14.0
	return m

func _ramp(t: float, cb: bool) -> Color:
	t = clampf(t, 0.0, 1.0)
	if cb:
		return Color("440154").lerp(Color("21908d"), clampf(t * 2.0, 0.0, 1.0)).lerp(Color("fde725"), clampf(t * 2.0 - 1.0, 0.0, 1.0))
	return Color("2c4a6b").lerp(Color("c9a24a"), clampf(t * 2.0, 0.0, 1.0)).lerp(Color("b5322b"), clampf(t * 2.0 - 1.0, 0.0, 1.0))

func _mode_color(s: Dictionary, pid: String, p: Dictionary, me: String, mx: Dictionary, cb: bool) -> Color:
	var owner: String = p["owner"]
	match mode:
		"terrain":
			return TERRAIN_COL.get(Defs.provinces[pid]["terrain"], Color.GRAY)
		"economic":
			var pc := EconomySystem.province_calc(s, pid)
			return _ramp((float(pc["tax"]) + float(pc["production"]) + float(pc["commerce"])) / float(mx["inc"]), cb)
		"population":
			return _ramp(sqrt(float(p["pop"]) / float(mx["pop"])), cb)
		"supply":
			return _ramp(MilitarySystem.supply_cap(s, me, pid) / float(mx["sup"]), cb)
		"trade":
			var d: Dictionary = TradeSystem.ensure(s)["by_province"].get(pid, {})
			var v := sqrt(float(d.get("value", 0.0)) / float(mx["trade"]))
			var c := _ramp(v, cb)
			if float(TradeSystem.ensure(s)["power"].get(Defs.province_index[pid], 0.0)) >= 1.0:
				c = c.lightened(0.25)
			return c
		"diplomatic":
			if owner == me:
				return Color("e6c876")
			if owner == "" or not s["countries"].has(owner):
				return Color.GRAY
			if GS.at_war(s, me, owner):
				return Color("b5322b") if not cb else Color("d95f02")
			var r := GS.rel(s, me, owner)
			if GS.overlord_of(s, owner) == me or GS.overlord_of(s, me) == owner:
				return Color("3f9a8e")
			if r["alliance"]:
				return Color("4f9e5c") if not cb else Color("1b9e77")
			if int(r["truce_until"]) > int(s["turn"]):
				return Color("c28a3a")
			if r["trade"]:
				return Color("4f78b5")
			var op := GS.opinion(s, owner, me)
			return Color("8a8f98").lerp(Color("4f9e5c") if op > 0 else Color("b5322b"), clampf(absf(op) / 120.0, 0.0, 0.55))
		"military":
			var c2 := color_of(owner).darkened(0.35)
			var n := 0.0
			var foe := false
			for aid in GS.armies_at(s, pid):
				var a: Dictionary = s["armies"][aid]
				if not a.get("naval", false):
					n += UnitUtil.army_size(a)
					if GS.at_war(s, me, a["owner"]):
						foe = true
			if p["controller"] != owner:
				c2 = c2.lerp(color_of(p["controller"], Color.GRAY), 0.6)
			c2 = c2.lightened(clampf(Mods.fort_level(s, pid) * 0.04, 0.0, 0.3))
			if n > 0.0:
				c2 = c2.lerp(Color("d9534f") if foe else Color("f0d98a"), clampf(n / 20.0, 0.12, 0.75))
			return c2
		_:
			var col := color_of(owner)
			if p["controller"] != owner and s["countries"].has(p["controller"]):
				col = col.lerp(color_of(p["controller"]), 0.55)
			return col

func apply_highlights() -> void:
	if view == null:
		return
	view.clear_highlights()
	var s: Dictionary = Game.state
	if selected != "" and Defs.province_index.has(selected):
		view.set_hi_color(Defs.province_index[selected], Color(1.0, 0.92, 0.5, 0.42))
		for nb in Defs.neighbors(selected):
			view.set_hi_color(Defs.province_index[nb], Color(1, 1, 1, 0.13))
	for pid in preview_route:
		if Defs.province_index.has(pid):
			view.set_hi_color(Defs.province_index[pid], Color(0.4, 0.8, 1.0, 0.32))
	view.push_colors()

func _rebuild_borders(s: Dictionary) -> void:
	var front := func(a: int, b: int) -> bool:
		var ca: String = s["provinces"][Defs.province_ids[a]]["controller"]
		var cb2: String = s["provinces"][Defs.province_ids[b]]["controller"]
		return ca != cb2 and GS.at_war(s, ca, cb2)
	var segs := borders.build(owners, front)
	view.set_border_segments(segs["province"], segs["country"], segs["coast"], segs["front"])

func _label_signature(s: Dictionary) -> int:
	var h := 7
	for pid in Defs.province_ids:
		h = (h * 31 + hash(s["provinces"][pid]["owner"])) & 0x7fffffff
	return h

func _country_labels(s: Dictionary) -> Array:
	var sig := _label_signature(s)
	if sig == _label_sig and not _label_cache.is_empty():
		return _label_cache
	_label_sig = sig
	var out: Array = []
	for cid in GS.alive_countries(s):
		var owned := GS.owned(s, cid)
		if owned.is_empty():
			continue
		# largest landmass cluster of the country
		var by_land := {}
		for pid in owned:
			var lm := int(Defs.provinces[pid]["landmass"])
			if not by_land.has(lm):
				by_land[lm] = []
			by_land[lm].append(pid)
		var best: Array = []
		var ba := -1.0
		for lm in by_land:
			var a := 0.0
			for pid in by_land[lm]:
				a += float(Defs.provinces[pid]["area_km2"])
			if a > ba:
				ba = a
				best = by_land[lm]
		var r := Rect2()
		var first := true
		var wsum := Vector2.ZERO
		var wt := 0.0
		for pid in best:
			var i: int = Defs.province_index[pid]
			var bb: Rect2 = view.prov_bbox[i]
			r = bb if first else r.merge(bb)
			first = false
			var w := float(Defs.provinces[pid]["area_km2"])
			wsum += view.prov_center[i] * w
			wt += w
		var center := wsum / maxf(wt, 1.0)
		out.append({"text": Loc.tx(s["countries"][cid]["short"]), "pos": center, "extent": maxf(r.size.x, r.size.y * 1.4), "cid": cid})
	_label_cache = out
	return out

func _update_overlay(s: Dictionary) -> void:
	var ov := view.overlay
	var me: String = Game.active_player
	ov.show_country_labels = true
	ov.show_province_labels = bool(Settings.get_value("map_labels"))
	ov.data["country_labels"] = _country_labels(s) if bool(Settings.get_value("map_labels")) else []
	# army markers: one per (province, owner)
	var markers: Array = []
	var cap: Array = []
	var sieges: Array = []
	if bool(Settings.get_value("army_markers")):
		var groups := {}
		for aid in s["armies"]:
			var a: Dictionary = s["armies"][aid]
			if a["loc"] == "":
				continue
			var k: String = a["loc"] + "|" + a["owner"] + ("|n" if a.get("naval", false) else "")
			if not groups.has(k):
				groups[k] = {"pid": a["loc"], "owner": a["owner"], "n": 0.0, "naval": a.get("naval", false), "sel": false}
			groups[k]["n"] += UnitUtil.army_size(a)
			if aid == Game.selected_army:
				groups[k]["sel"] = true
		for k in groups:
			var g: Dictionary = groups[k]
			var i: int = Defs.province_index[g["pid"]]
			var pos: Vector2 = view.prov_center[i]
			if g["naval"]:
				pos += Vector2(0, 7.0 / maxf(view.zoom, 0.3))
			elif g["owner"] != s["provinces"][g["pid"]]["owner"]:
				pos += Vector2(0, -5.0 / maxf(view.zoom, 0.3))
			markers.append({"pos": pos, "text": str(int(round(g["n"]))), "color": color_of(g["owner"]), "selected": g["sel"], "naval": g["naval"]})
	for cid in GS.alive_countries(s):
		var cp: String = s["countries"][cid].get("capital", "")
		if cp != "" and Defs.province_index.has(cp):
			cap.append({"pos": view.prov_center[Defs.province_index[cp]] + Vector2(0, -3)})
	for pid in Defs.province_ids:
		var sg: Variant = s["provinces"][pid].get("siege")
		if sg != null:
			sieges.append({"pos": view.prov_center[Defs.province_index[pid]], "progress": clampf(float(sg["progress"]), 0.0, 1.0)})
	ov.data["markers"] = markers
	ov.data["capitals"] = cap
	ov.data["sieges"] = sieges
	var routes: Array = []
	# orders of the player's armies
	for aid in GS.armies_of(s, me):
		var a2: Dictionary = s["armies"][aid]
		if not (a2["path"] as Array).is_empty() and a2["loc"] != "":
			var pts: Array = [view.prov_center[Defs.province_index[a2["loc"]]]]
			for pid in a2["path"]:
				pts.append(view.prov_center[Defs.province_index[pid]])
			routes.append({"points": pts, "color": Color(1, 0.85, 0.3, 0.9) if aid != Game.selected_army else Color(0.5, 0.9, 1, 1)})
	if not preview_route.is_empty() and preview_army != "" and s["armies"].has(preview_army):
		var a3: Dictionary = s["armies"][preview_army]
		if a3["loc"] != "":
			var pts2: Array = [view.prov_center[Defs.province_index[a3["loc"]]]]
			for pid in preview_route:
				pts2.append(view.prov_center[Defs.province_index[pid]])
			routes.append({"points": pts2, "color": Color(0.4, 0.9, 1.0, 1.0)})
	ov.data["routes"] = routes
	ov.queue_redraw()

func select(pid: String) -> void:
	selected = pid
	apply_highlights()
	if view and view.overlay:
		view.overlay.queue_redraw()

func set_preview(aid: String, route: Array) -> void:
	preview_army = aid
	preview_route = route
	apply_highlights()
	_update_overlay(Game.state)
