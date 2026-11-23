extends TestCase

func test_growth_is_bounded_by_capacity() -> void:
	var s := new_state()
	var cid: String = GS.alive_countries(s)[0]
	var pid: String = GS.owned(s, cid)[0]
	var p: Dictionary = s["provinces"][pid]
	var cap := PopulationSystem.pop_cap(s, pid)
	p["pop"] = cap * 1.4
	var before := float(p["pop"])
	PopulationSystem.process_turn(s)
	ok(float(p["pop"]) < before, "over capacity shrinks")
	p["pop"] = cap * 0.4
	before = float(p["pop"])
	PopulationSystem.process_turn(s)
	ok(float(p["pop"]) > before * 0.999, "under capacity does not collapse")

func test_migration_conserves_population() -> void:
	var s := new_state()
	var total0 := 0.0
	for pid in Defs.province_ids:
		total0 += float(s["provinces"][pid]["pop"])
	PopulationSystem._migrate(s)
	var total1 := 0.0
	for pid in Defs.province_ids:
		total1 += float(s["provinces"][pid]["pop"])
	near(total0, total1, 0.001, "migration only moves people")

func test_class_shares_sane() -> void:
	var s := new_state()
	PopulationSystem.process_turn(s)
	for pid in Defs.province_ids.slice(0, 80):
		var cl: Dictionary = s["provinces"][pid]["classes"]
		var tot := 0.0
		for k in cl:
			tot += float(cl[k])
			ok(float(cl[k]) >= 0.0, "class share non-negative")
		near(tot, 1.0, 0.01, "class shares of %s sum to 1" % pid)

func test_population_drives_manpower_and_taxes() -> void:
	var s := new_state()
	var cid := ""
	for c2 in GS.alive_countries(s):
		if not str(c2).begins_with("NAT_") and GS.owned(s, c2).size() >= 2:
			cid = c2
			break
	var pid: String = GS.owned(s, cid)[0]
	var a := EconomySystem.province_calc(s, pid)
	s["provinces"][pid]["pop"] = float(s["provinces"][pid]["pop"]) * 2.0
	EconomySystem.invalidate_calc(s)
	var b := EconomySystem.province_calc(s, pid)
	ok(float(b["manpower"]) > float(a["manpower"]) * 1.8, "manpower scales with population")
	ok(float(b["tax"]) > float(a["tax"]) * 1.8, "tax scales with population")
	ok(float(b["food_cons"]) > float(a["food_cons"]) * 1.8, "food consumption scales with population")

func test_unrest_reacts_to_culture_and_religion() -> void:
	var s := new_state()
	var cid := ""
	for c2 in GS.alive_countries(s):
		if not str(c2).begins_with("NAT_") and GS.owned(s, c2).size() >= 2:
			cid = c2
			break
	var pid: String = GS.owned(s, cid)[0]
	var p: Dictionary = s["provinces"][pid]
	p["culture"] = s["countries"][cid]["culture"]
	p["religion"] = s["countries"][cid]["religion"]
	var base := float(PopulationSystem.unrest_target(s, pid)["parts"].get("UNREST_CULTURE", 0.0)) + float(PopulationSystem.unrest_target(s, pid)["parts"].get("UNREST_RELIGION", 0.0))
	p["culture"] = "alien"
	p["religion"] = "alien_faith"
	var diff := float(PopulationSystem.unrest_target(s, pid)["parts"].get("UNREST_CULTURE", 0.0)) + float(PopulationSystem.unrest_target(s, pid)["parts"].get("UNREST_RELIGION", 0.0))
	ok(diff > base + 10.0, "foreign culture and religion raise unrest (%f -> %f)" % [base, diff])
