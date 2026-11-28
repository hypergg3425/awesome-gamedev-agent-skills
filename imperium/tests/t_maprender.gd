extends TestCase
## Map rendering: mode colours / legends / markers / zoom policy on BOTH map sets, geometry layers, mode-strip layout.

var _prev := ""
var _lang := ""

func _use(set_id: String) -> void:
	_prev = Defs.map_set
	Defs.use_map_set(set_id)

func _restore() -> void:
	Defs.use_map_set(_prev)

## State on the given map set with some turns played (wars, armies, battles).
func _state(set_id: String) -> Dictionary:
	_use(set_id)
	var def: Dictionary = Defs.all_scenarios()["early_modern"]
	if set_id == "extended":
		def = MapUpgrade.upgrade_def(def)
	var s := ScenarioLoader.build(def, str(def["default_player"]), "normal", 31)
	run_turns(s, 4)
	return s

func _valid(c: Color) -> bool:
	return is_finite(c.r) and is_finite(c.g) and is_finite(c.b) and c.r >= 0.0 and c.g >= 0.0 and c.b >= 0.0 and c.r <= 1.001 and c.g <= 1.001 and c.b <= 1.001 and c.a > 0.99

func _bounds() -> Rect2:
	var b: Array = Defs.map_meta.get("bounds", [0, 0, 3600, 1400])
	return Rect2(b[0], b[1], b[2] - b[0], b[3] - b[1]).grow(2.0)

func _centers() -> Array:
	var out: Array = []
	for pid in Defs.province_ids:
		var l: Array = Defs.provinces[pid]["label"]
		out.append(Vector2(l[0], l[1]))
	return out

func test_mode_list() -> void:
	eq(MapModes.MODES.size(), 15, "15 map modes")
	for m in ["political", "terrain", "economic", "diplomatic", "military", "population", "supply", "trade"]:
		ok(m in MapModes.MODES, "original mode kept: " + m)
	for m in ["religion", "culture", "infrastructure", "unrest", "admin", "development", "naval"]:
		ok(m in MapModes.MODES, "new mode: " + m)
		ok(ResourceLoader.exists("res://assets/icons/mode_%s.svg" % m), "icon for " + m)

func _colors_for(set_id: String) -> void:
	var s := _state(set_id)
	var me: String = s["player"]
	for mode in MapModes.MODES:
		var ctx := MapModes.context(s, me, mode)
		var bad := 0
		var distinct := {}
		for pid in Defs.province_ids:
			var c := MapModes.color(mode, s, pid, ctx)
			if not _valid(c):
				bad += 1
			distinct[c.to_html(false)] = true
		eq(bad, 0, "%s/%s: every province colour is valid" % [set_id, mode])
		ok(distinct.size() >= 3, "%s/%s: mode is not flat (%d colours)" % [set_id, mode, distinct.size()])
	# scores
	var cnt := 0
	for pid in Defs.province_ids:
		var a := MapModes.admin_control(s, pid)
		var inf := MapModes.infra_score(s, pid)
		if a < 0.0 or a > 1.0 or inf < 0.0 or is_nan(inf):
			cnt += 1
	eq(cnt, 0, set_id + ": admin_control in 0..1, infra score finite")
	_restore()

func test_colors_classic() -> void:
	_colors_for("classic")

func test_colors_extended() -> void:
	_colors_for("extended")

func test_colorblind_ramps_differ() -> void:
	ok(MapModes.ramp(0.0, true) != MapModes.ramp(0.0, false), "colour-blind ramp differs at the low end")
	ok(MapModes.ramp_warn(1.0, true) != MapModes.ramp_warn(1.0, false), "colour-blind warning ramp differs")
	ok(MapModes.ramp_admin(0.0, true) != MapModes.ramp_admin(0.0, false), "colour-blind admin ramp differs")

func test_legends_localised() -> void:
	var s := _state("classic")
	var me: String = s["player"]
	var saved: String = Loc.lang
	var texts := {}
	for lang in ["en", "tr"]:
		Loc.set_language(lang)
		texts[lang] = []
		for mode in MapModes.MODES:
			var leg := MapModes.legend(mode, s, me)
			var n: int = (leg["items"] as Array).size() + (leg["stops"] as Array).size()
			ok(n > 0, "%s/%s legend is not empty" % [lang, mode])
			if leg["kind"] == "ramp":
				ok(str(leg["lo"]) != "" and str(leg["hi"]) != "" and (leg["stops"] as Array).size() >= 3, "%s/%s ramp has stops and labels" % [lang, mode])
			var all: Array = [str(leg["title"]), str(leg["note"]), str(leg["lo"]), str(leg["hi"])]
			for it in leg["items"]:
				all.append(str(it["text"]))
				ok(_valid(it["color"]), "%s/%s legend swatch colour valid" % [lang, mode])
			for tx in all:
				ok(not (tx.begins_with("LEG_") or tx.begins_with("MODE_") or tx.begins_with("TERRAIN_") or tx.begins_with("REL_") or tx.begins_with("CULT_")), "%s/%s no raw key shown: %s" % [lang, mode, tx])
			ok(str(leg["title"]) != "", "%s/%s title" % [lang, mode])
			texts[lang].append(str(leg["title"]) + str(leg["note"]) + str(leg["lo"]))
	var differ := 0
	for i in MapModes.MODES.size():
		if texts["en"][i] != texts["tr"][i]:
			differ += 1
	ok(differ >= 13, "legend texts are translated (%d of 15 differ EN/TR)" % differ)
	Loc.set_language(saved)
	_restore()

func test_legend_widget() -> void:
	var s := _state("classic")
	var lg := MapLegend.new()
	for mode in MapModes.MODES:
		lg.show_mode(mode, s, s["player"])
		ok(lg.get_child(0).get_child_count() >= 2, "legend widget has content for " + mode)
	lg.collapsed = true
	lg.show_mode("terrain", s, s["player"])
	eq(lg.get_child(0).get_child_count(), 1, "collapsed legend shows only the title")
	lg.free()
	_restore()

func _markers_for(set_id: String) -> void:
	var s := _state(set_id)
	var me: String = s["player"]
	var pc := _centers()
	var bb := _bounds()
	var cities := MapMarkers.cities(s, pc)
	eq(cities.size(), Defs.province_ids.size(), set_id + ": one settlement marker per province")
	var out := 0
	var last_rank := 9
	var sorted_ok := true
	for c in cities:
		if not bb.has_point(c["pos"]):
			out += 1
		if int(c["rank"]) > last_rank:
			sorted_ok = false
		last_rank = int(c["rank"])
		ok(int(c["rank"]) >= 0 and int(c["rank"]) <= 3, "rank range")
	eq(out, 0, set_id + ": settlement markers inside the map bounds")
	ok(sorted_ok, set_id + ": settlement list sorted by priority")
	var caps := 0
	for c in cities:
		if int(c["rank"]) == 3:
			caps += 1
	ok(caps >= GS.alive_countries(s).size() - 10, "%s: capitals are rank 3 (%d)" % [set_id, caps])
	var rank_counts := [0, 0, 0, 0]
	for c in cities:
		rank_counts[int(c["rank"])] += 1
	ok(rank_counts[2] + rank_counts[3] >= 5 and rank_counts[0] >= 1, "%s: rank spread %s" % [set_id, str(rank_counts)])
	for b in MapMarkers.battles(s, pc):
		ok(bb.has_point(b["pos"]), "battle marker inside bounds")
	for l in MapMarkers.supply_lines(s, me, pc):
		for p in (l["points"] as PackedVector2Array):
			ok(bb.has_point(p), "supply line inside bounds")
		ok((l["points"] as PackedVector2Array).size() >= 2, "supply line has two ends")
	var tr := MapMarkers.trade_routes(s, pc)
	ok(tr.size() <= MapMarkers.MAX_TRADE_ROUTES, "trade routes capped")
	for r in tr:
		ok(bb.has_point(r["a"]) and bb.has_point(r["b"]) and float(r["w"]) >= 0.0 and float(r["w"]) <= 1.0, "trade route valid")
	var ctx := MapModes.context(s, me, "naval")
	for t in MapMarkers.sea_tint(s, ctx):
		ok(bb.grow(400.0).has_point(t["pos"]) and float(t["radius"]) > 0.0, "sea tint valid")
	_restore()

func test_markers_classic() -> void:
	_markers_for("classic")

func test_markers_extended() -> void:
	_markers_for("extended")

func test_supply_line_from_foreign_army() -> void:
	var s := _state("classic")
	var me: String = s["player"]
	# put one of the player's armies on a foreign province next to the realm
	var aids := GS.armies_of(s, me)
	var moved := false
	for aid in aids:
		var a: Dictionary = s["armies"][aid]
		if bool(a.get("naval", false)):
			continue
		for pid in GS.owned(s, me):
			for nb in Defs.neighbors(pid):
				if s["provinces"][nb]["controller"] != me and not MilitarySystem.is_friendly_ground(s, me, nb):
					a["loc"] = nb
					moved = true
					break
			if moved:
				break
		if moved:
			break
	ok(moved, "found a foreign province next to the realm")
	var lines := MapMarkers.supply_lines(s, me, _centers())
	ok(lines.size() >= 1, "an army abroad gets a supply line")
	if lines.size() >= 1:
		eq(int(lines[0]["hops"]), 1, "adjacent foreign province: one hop home")
		ok((lines[0]["color"] as Color).g > (lines[0]["color"] as Color).r, "one hop is drawn green")
	_restore()

func test_zoom_thresholds() -> void:
	eq(MapZoom.tier(0.4), MapZoom.LOW, "low tier")
	eq(MapZoom.tier(MapZoom.MID_ZOOM), MapZoom.MID, "mid tier starts at MID_ZOOM")
	eq(MapZoom.tier(MapZoom.HIGH_ZOOM), MapZoom.HIGH, "high tier starts at HIGH_ZOOM")
	var last_rank := 99
	var last_tier := -1
	for i in 60:
		var z := 0.3 * pow(1.07, float(i))
		var r := MapZoom.min_city_rank(z)
		ok(r <= last_rank, "min city rank never rises with zoom (z=%.2f)" % z)
		last_rank = r
		ok(MapZoom.tier(z) >= last_tier, "tier is monotonic")
		last_tier = MapZoom.tier(z)
	eq(MapZoom.min_city_rank(0.5), 2, "world view shows capitals and major cities only")
	eq(MapZoom.min_city_rank(5.0), 0, "close view shows every settlement")
	ok(not MapZoom.show_rivers(0.5, 3) and MapZoom.show_rivers(1.2, 3), "great rivers appear at medium zoom")
	ok(not MapZoom.show_rivers(1.5, 1) and MapZoom.show_rivers(3.0, 1), "small rivers only when zoomed in")
	ok(not MapZoom.show_passes(1.5) and MapZoom.show_passes(3.5), "passes only at high zoom")
	ok(not MapZoom.show_relief(1.0) and MapZoom.show_relief(3.0), "relief marks only when zoomed in")
	ok(not MapZoom.show_roads(2.0) and MapZoom.show_roads(3.5), "roads only at high zoom")
	ok(MapZoom.COUNTRY_LABEL_MAX <= MapZoom.PROVINCE_LABEL_MIN, "country and province names never overlap in zoom range")
	ok(MapZoom.marker_scale(0.2) >= 0.75 and MapZoom.marker_scale(14.0) <= 1.5, "marker scale clamped")

func test_lines() -> void:
	var v := PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(10, 10), Vector2(20, 10)])
	var sm := MapLines.chaikin(v)
	eq(sm[0], v[0], "chaikin keeps the start")
	eq(sm[sm.size() - 1], v[v.size() - 1], "chaikin keeps the end")
	ok(sm.size() > v.size(), "chaikin adds points")
	var ring := PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(10, 10), Vector2(0, 0)])
	var rs := MapLines.chaikin(ring)
	ok(rs[0].is_equal_approx(rs[rs.size() - 1]), "closed ring stays closed")
	var inside := true
	for p in rs:
		if p.x < -0.01 or p.x > 10.01 or p.y < -0.01 or p.y > 10.01:
			inside = false
	ok(inside, "closed ring smoothing stays inside the hull (no stray points)")
	near(MapLines.length(v), 30.0, 0.001, "polyline length")
	ok(MapLines.midpoint(v).is_equal_approx(Vector2(10, 5)), "midpoint at half length")
	var dec := MapLines.decimate(PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(2, 0), Vector2(3, 0), Vector2(4, 0), Vector2(5, 0), Vector2(6, 0)]), 3)
	eq(dec.size(), 3, "decimate keeps every third point and the end")

func _geometry_features(set_id: String) -> void:
	_use(set_id)
	var geom := Defs.load_geometry()
	var fl: Node2D = Node2D.new()
	fl.set_script(preload("res://scripts/map/feature_layer.gd"))
	fl.build(geom)
	var feats_r: int = (Defs.features.get("rivers", []) as Array).size()
	var feats_p: int = (Defs.features.get("passes", []) as Array).size()
	ok(fl.rivers.size() >= int(feats_r * 0.9), "%s: rivers resolved to border lines (%d of %d)" % [set_id, fl.rivers.size(), feats_r])
	ok(fl.passes.size() >= int(feats_p * 0.9), "%s: passes resolved (%d of %d)" % [set_id, fl.passes.size(), feats_p])
	var bb := _bounds().grow(10.0)
	var bad := 0
	for r in fl.rivers:
		for p in (r["pts"] as PackedVector2Array):
			if not bb.has_point(p):
				bad += 1
	for p in fl.passes:
		if not bb.has_point(p["pos"]):
			bad += 1
	eq(bad, 0, set_id + ": river / pass geometry inside the map")
	fl.free()
	_restore()

func test_features_classic() -> void:
	_geometry_features("classic")

func test_features_extended() -> void:
	_geometry_features("extended")

func _view_for(set_id: String) -> void:
	_use(set_id)
	var t0 := Time.get_ticks_msec()
	var mv := MapView.new()
	mv.size = Vector2(1280, 720)
	mv.setup(Defs.load_geometry(), Defs.map_meta)
	var setup_ms := Time.get_ticks_msec() - t0
	print("  [maprender] %s: MapView.setup %d ms" % [set_id, setup_ms])
	ok(setup_ms < 30000, "%s: map view builds in reasonable time (%d ms)" % [set_id, setup_ms])
	eq(mv.relief.size(), mv.n_prov, set_id + ": relief amplitude per province")
	var rmin := 9.0
	var rmax := -1.0
	for v in mv.relief:
		rmin = minf(rmin, v)
		rmax = maxf(rmax, v)
	ok(rmin >= 0.0 and rmax <= 1.0 and rmax > rmin, "relief amplitudes in 0..1 and varied")
	eq(mv.color_img.get_height(), 3, "data texture has colour, highlight and relief rows")
	ok(mv.water_layer.get_child_count() > 3 and mv.water_layer.get_child_count() == mv.border_layer.get_child_count(), "coast chunks for water and outline")
	var lines := 0
	for ch in mv.border_layer.get_children():
		lines += (ch.hi as Array).size()
	var raw := 0
	for pl in Defs.load_geometry().coasts:
		for l in pl:
			if (l as PackedVector2Array).size() >= 2:
				raw += 1
	eq(lines, raw, set_id + ": every coast polyline is kept in a chunk")
	# relief marks: built lazily, inside their province
	t0 = Time.get_ticks_msec()
	mv.relief_layer.ensure_built()
	var relief_ms := Time.get_ticks_msec() - t0
	print("  [maprender] %s: relief build %d ms, %d marks" % [set_id, relief_ms, mv.relief_layer.count])
	ok(mv.relief_layer.count > 500, "%s: relief marks exist (%d)" % [set_id, mv.relief_layer.count])
	ok(relief_ms < 20000, "%s: relief build time (%d ms)" % [set_id, relief_ms])
	var checked := 0
	var outside := 0
	for ch in mv.relief_layer.get_children():
		for m in (ch.marks as Array).slice(0, 40):
			checked += 1
			var pi := mv.province_at_world(m[0])
			if pi < 0:
				outside += 1
	ok(checked > 100 and outside <= checked / 20, "%s: relief marks lie on land (%d of %d off-land)" % [set_id, outside, checked])
	# zoom tiers toggle the relief layer
	mv.zoom = 4.0
	mv._apply_camera()
	ok(mv.relief_layer.visible, "relief visible when zoomed in")
	mv.zoom = 0.8
	mv._apply_camera()
	ok(not mv.relief_layer.visible, "relief hidden when zoomed out")
	Settings.set_value("animations", false, false)
	mv._apply_animation_setting()
	near(float(mv.ocean_mat.get_shader_parameter("animate")), 0.0, 0.0001, "ocean shimmer frozen when animations are off")
	Settings.set_value("animations", true, false)
	mv._apply_animation_setting()
	near(float(mv.ocean_mat.get_shader_parameter("animate")), 1.0, 0.0001, "ocean shimmer runs when animations are on")
	mv.free()
	_restore()

func test_map_view_classic() -> void:
	_view_for("classic")

func test_map_view_extended() -> void:
	_view_for("extended")

func test_shaders_compile() -> void:
	for p in ["province_fill", "ocean"]:
		var sh: Shader = load("res://assets/shaders/%s.gdshader" % p)
		ok(sh != null and sh.get_code().length() > 100, p + " shader loads")

func test_mode_strip_layout() -> void:
	for vs in [Vector2(800, 360), Vector2(1280, 720), Vector2(2000, 1000)]:
		var ins := {"left": 0.0, "top": 0.0, "right": 0.0, "bottom": 0.0}
		var l := CampaignLayout.compute(vs, ins, 0.0, 9, 52.0, false, 15)
		var modes: Rect2 = l["modes"]
		var avail: Rect2 = l["avail"]
		ok(avail.grow(1.0).encloses(modes), "%s: 15-mode strip fits the screen %s in %s" % [str(vs), str(modes), str(avail)])
		var bw := CampaignLayout.mode_button_width(float(l["tb"]), bool(l["compact"]))
		var cols: int = l["mode_cols"]
		ok(cols >= 5, "%s: at least 5 columns" % str(vs))
		ok(modes.size.x >= float(cols) * bw, "%s: strip is wide enough for %d columns (button %.0f)" % [str(vs), cols, bw])
		ok(modes.size.y >= float(ceili(15.0 / float(cols))) * float(l["tb"]), "%s: strip has room for every row of touch-size buttons" % str(vs))
		ok(not modes.intersects(l["hud"]), "%s: strip does not cover the HUD" % str(vs))
		var lg: Rect2 = l["legend"]
		ok(not lg.intersects(l["hud"]) and not lg.intersects(l["end"]), "%s: legend clear of HUD and end-turn" % str(vs))
	var one := CampaignLayout.compute(Vector2(1280, 720), {"left": 0.0, "top": 0.0, "right": 0.0, "bottom": 0.0}, 0.0, 9, 52.0, false, 8)
	ok((one["modes"] as Rect2).size.y <= 2.0 * float(one["tb"]) + 20.0, "8 modes fit in two rows or less")
