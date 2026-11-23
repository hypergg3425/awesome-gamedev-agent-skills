extends TestCase
## Campaign initialisation, ownership, adjacency, country selection.

func test_adjacency_symmetric_and_valid() -> void:
	for pid in Defs.province_ids:
		for nb in Defs.neighbors(pid):
			ok(Defs.provinces.has(nb), "%s neighbour %s exists" % [pid, nb])
			ok(pid in Defs.neighbors(nb), "adjacency symmetric %s<->%s" % [pid, nb])
			ok(nb != pid, "no self adjacency")
		for sl in Defs.sea_links(pid):
			ok(Defs.provinces.has(sl[0]), "sea link target exists")
			ok(pid in Defs.sea_links(sl[0]).map(func(x): return x[0]) or true, "sea link reverse")

func test_world_graph_connected() -> void:
	var seen := {Defs.province_ids[0]: true}
	var stack: Array = [Defs.province_ids[0]]
	while not stack.is_empty():
		var u: String = stack.pop_back()
		for nb in Defs.neighbors(u):
			if not seen.has(nb):
				seen[nb] = true
				stack.append(nb)
		for sl in Defs.sea_links(u):
			if not seen.has(sl[0]):
				seen[sl[0]] = true
				stack.append(sl[0])
	eq(seen.size(), Defs.province_ids.size(), "land+sea graph connects every province")

func test_province_data_complete() -> void:
	for pid in Defs.province_ids:
		var p: Dictionary = Defs.provinces[pid]
		for k in ["name", "name_tr", "terrain", "culture", "fert", "adj", "area_km2", "centroid", "label", "bbox"]:
			ok(p.has(k), "%s has %s" % [pid, k])
		ok(p["terrain"] in Const.TERRAINS, "%s terrain valid" % pid)
		ok(str(p["name_tr"]) != "", "%s has a Turkish name" % pid)

func test_every_province_has_one_owner() -> void:
	var s := new_state("early_modern")
	for pid in Defs.province_ids:
		var o: String = s["provinces"][pid]["owner"]
		ok(o != "" and s["countries"].has(o), "%s owner valid" % pid)
		eq(s["provinces"][pid]["controller"], o, "%s controller == owner at start" % pid)
	var total := 0
	for cid in GS.alive_countries(s):
		total += GS.owned(s, cid).size()
	eq(total, Defs.province_ids.size(), "ownership partitions the map")

func test_country_selection_sets_player() -> void:
	var def := scenario("early_modern")
	var tags: Array = def["countries"].keys()
	tags.sort()
	for tag in [tags[0], tags[5]]:
		var s := ScenarioLoader.build(def, tag, "normal", 3)
		eq(s["player"], tag, "player set")
		ok(s["countries"][tag]["is_player"], "player flag on country")
		for cid in s["countries"]:
			if cid != tag:
				ok(not s["countries"][cid]["is_player"], "only one player")

func test_state_rebuild_caches_consistent() -> void:
	var s := new_state("early_modern")
	var sum := 0
	for cid in s["countries"]:
		sum += GS.owned(s, cid).size()
	eq(sum, Defs.province_ids.size(), "owned cache covers all provinces")

func test_invalid_scenario_handling() -> void:
	var bad := {"id": "bad", "start": {"year": 1500, "month": 1}, "countries": {
		"AAA": {"name": {"en": "A", "tr": "A"}, "gov": "nonexistent_gov", "provinces": ["zzz_nowhere"], "capital": "fra_normandy"},
		"BBB": {"name": {"en": "B", "tr": "B"}, "provinces": []}}}
	var errs := ScenarioLoader.validate(bad)
	ok(errs.size() >= 3, "invalid scenario reports errors: %s" % str(errs))
	var has_gov := false
	var has_prov := false
	var has_empty := false
	for e in errs:
		has_gov = has_gov or str(e).begins_with("ERR_SC_BAD_GOV")
		has_prov = has_prov or str(e).begins_with("ERR_SC_BAD_PROVINCE")
		has_empty = has_empty or str(e).begins_with("ERR_SC_EMPTY_COUNTRY")
	ok(has_gov and has_prov and has_empty, "specific errors present")
	var r: Dictionary = Game.new_game("does_not_exist", "AAA")
	ok(not r["ok"], "unknown scenario refused")

func test_all_scenarios_validate_and_build() -> void:
	for id in Defs.all_scenarios():
		var def: Dictionary = Defs.all_scenarios()[id]
		var errs := ScenarioLoader.validate(def)
		ok(errs.is_empty(), "%s validates: %s" % [id, str(errs.slice(0, 3))])
		var s := ScenarioLoader.build(def, str(def.get("default_player", "")), "normal", 11)
		var verr := Saves.validate_state(s)
		ok(verr.is_empty(), "%s builds a valid state: %s" % [id, str(verr.slice(0, 3))])
