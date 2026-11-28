extends TestCase
## Extended map set (data/map600): data integrity, geometry, parents mapping, features and scenario upgrade.

const MAX_MESH_VERTS := 230000

var _prev := ""

func _use_extended() -> void:
	_prev = Defs.map_set
	Defs.use_map_set("extended")

func _restore() -> void:
	Defs.use_map_set(_prev)

func test_counts_and_adjacency() -> void:
	_use_extended()
	ok(Defs.province_ids.size() >= 600, "at least 600 provinces (%d)" % Defs.province_ids.size())
	var bad_sym := 0
	var no_name := 0
	for pid in Defs.province_ids:
		var p: Dictionary = Defs.provinces[pid]
		if str(p["name"]) == "" or str(p["name_tr"]) == "":
			no_name += 1
		for nb in p["adj"]:
			if not Defs.provinces.has(nb) or not (pid in Defs.provinces[nb]["adj"]):
				bad_sym += 1
		for sl in p["sea"]:
			if not Defs.provinces.has(sl[0]) or not Defs.provinces[sl[0]]["coastal"] or not p["coastal"]:
				bad_sym += 1
	eq(bad_sym, 0, "adjacency / sea links symmetric and valid")
	eq(no_name, 0, "every province has en+tr names")
	# every province reachable inside its landmass
	var by_lm := {}
	for pid in Defs.province_ids:
		var lm := int(Defs.provinces[pid]["landmass"])
		if not by_lm.has(lm):
			by_lm[lm] = []
		by_lm[lm].append(pid)
	var unreachable := 0
	for lm in by_lm:
		var members: Array = by_lm[lm]
		var seen := {members[0]: true}
		var stack: Array = [members[0]]
		while not stack.is_empty():
			var u: String = stack.pop_back()
			for v in Defs.neighbors(u):
				if not seen.has(v):
					seen[v] = true
					stack.append(v)
		unreachable += members.size() - seen.size()
	eq(unreachable, 0, "all provinces reachable by land within their landmass")
	_restore()

func test_parents_partition_classic_ids() -> void:
	_use_extended()
	var classic: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/map/provinces.json"))
	eq(Defs.parents.size(), (classic as Array).size(), "parents.json lists every classic id")
	var seen := {}
	var dup := 0
	for c in classic:
		var pid: String = c["id"]
		ok(Defs.parents.has(pid), "parent entry for " + pid)
		for kid in Defs.parents.get(pid, []):
			if seen.has(kid):
				dup += 1
			seen[kid] = pid
			ok(Defs.provinces.has(kid), "child exists " + str(kid))
			eq(str(Defs.provinces[kid]["parent"]), pid, "child parent field " + str(kid))
	eq(dup, 0, "no child under two parents")
	eq(seen.size(), Defs.province_ids.size(), "children cover the extended map")
	_restore()

func test_geometry_loads_and_mesh_size() -> void:
	_use_extended()
	var t0 := Time.get_ticks_msec()
	var g := MapGeometry.new()
	ok(g.load_file("res://data/map600/geometry.bin", Defs.province_ids.size()), "geometry.bin loads")
	var ms := Time.get_ticks_msec() - t0
	var verts := 0
	var bad_idx := 0
	for pi in g.polys.size():
		if (g.polys[pi] as Array).is_empty():
			bad_idx += 1
		for poly in g.polys[pi]:
			var v: PackedVector2Array = poly["v"]
			verts += v.size()
			for ix in poly["i"]:
				if ix < 0 or ix >= v.size():
					bad_idx += 1
	eq(bad_idx, 0, "triangle indices in range and every province has a polygon")
	ok(verts <= MAX_MESH_VERTS, "mesh vertices %d <= %d (mobile budget)" % [verts, MAX_MESH_VERTS])
	print("map600: %d provinces, %d mesh vertices, geometry load %d ms" % [Defs.province_ids.size(), verts, ms])
	var gc := MapGeometry.new()
	var t1 := Time.get_ticks_msec()
	gc.load_file("res://data/map/geometry.bin", 410)
	var cv := 0
	for pl in gc.polys:
		for poly in pl:
			cv += (poly["v"] as PackedVector2Array).size()
	print("classic: 410 provinces, %d mesh vertices, geometry load %d ms" % [cv, Time.get_ticks_msec() - t1])
	# hit test: the label point of every province lies inside one of its polygons
	var miss := 0
	for pi in g.polys.size():
		var lp := Vector2(Defs.provinces[Defs.province_ids[pi]]["label"][0], Defs.provinces[Defs.province_ids[pi]]["label"][1])
		var hit := false
		for poly in g.polys[pi]:
			if Geometry2D.is_point_in_polygon(lp, poly["v"]):
				hit = true
				break
		if not hit:
			miss += 1
	eq(miss, 0, "label points hit their own province polygon")
	_restore()

func test_features_reference_valid_pairs() -> void:
	for set_id in ["classic", "extended"]:
		_prev = Defs.map_set
		Defs.use_map_set(set_id)
		var f: Dictionary = Defs.features
		ok(not f.is_empty(), set_id + " features.json loaded")
		var bad := 0
		for key in ["rivers", "passes"]:
			ok((f.get(key, []) as Array).size() > 20, "%s has %s" % [set_id, key])
			for e in f.get(key, []):
				if not Defs.provinces.has(e[0]) or not Defs.provinces.has(e[1]) or not (e[1] in Defs.provinces[e[0]]["adj"]):
					bad += 1
				if str(e[2].get("name", "")) == "":
					bad += 1
		for e in f.get("straits", []):
			var linked: bool = e[1] in Defs.provinces[e[0]]["adj"]
			for sl in Defs.provinces[e[0]]["sea"]:
				if sl[0] == e[1]:
					linked = true
			if not linked:
				bad += 1
		eq(bad, 0, set_id + " features reference valid adjacent/linked pairs")
		ok((f.get("lakes", []) as Array).size() > 10, set_id + " has lakes")
		_restore()

func test_scenarios_upgrade_to_extended() -> void:
	_use_extended()
	var classic_counts := {}
	for sid in Defs.scenarios:
		var def: Dictionary = Defs.scenarios[sid]
		eq(str(def.get("map_set", "classic")), "classic", sid + " is authored on classic ids")
		var up := MapUpgrade.upgrade_def(def)
		var errs := ScenarioLoader.validate(up)
		eq(errs.size(), 0, sid + " upgraded scenario validates: " + str(errs))
		var cd: Dictionary = def["countries"]
		var ucd: Dictionary = up["countries"]
		for cid in cd:
			ok(ucd.has(cid), "country kept " + cid)
		# classic owner of every classic province == owner of each child
		var s := ScenarioLoader.build(up, str(def.get("default_player", "")), "normal", 5)
		eq(str(s["map_set"]), "extended", sid + " state records the map set")
		var mism := 0
		for parent in Defs.parents:
			var owners := {}
			for kid in Defs.parents[parent]:
				owners[str(s["provinces"][kid]["owner"])] = true
			if owners.size() != 1:
				mism += 1
		eq(mism, 0, sid + ": all children of a parent share the parent's owner")
		var player: String = def.get("default_player", "")
		ok(GS.owned(s, player).size() >= 1, sid + " player owns provinces")
		ok(s["provinces"].size() == Defs.province_ids.size(), sid + " state covers every extended province")
		if sid == "hundred_years_war":
			ok(MapUpgrade.core_of("fra_normandy") == "fra_normandy", "core child keeps the parent id")
	_restore()

func test_save_roundtrip_on_extended() -> void:
	_use_extended()
	var def: Dictionary = MapUpgrade.upgrade_def(Defs.scenarios["early_modern"])
	var s := ScenarioLoader.build(def, str(def["default_player"]), "normal", 9)
	run_turns(s, 3)
	var r: Dictionary = Saves.save_slot("t_map600", s)
	ok(r["ok"], "saved")
	Defs.use_map_set("classic")
	var l: Dictionary = Saves.load_slot("t_map600")
	ok(l["ok"], "load switches the map set back to extended: %s" % str(l.get("reason", "")))
	eq(Defs.map_set, "extended", "map set restored from the save")
	Saves.delete_slot("t_map600")
	_restore()
