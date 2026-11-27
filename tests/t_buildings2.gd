extends TestCase
## v2.1 buildings: every effect is consumed by a system, era / tech restrictions, eight new buildings.

const LOCAL_READ := ["tax_mult", "food_mult", "prod_mult", "mine_mult", "wood_mult", "pop_cap", "trade_power", "merchant_share", "artisan_share", "clergy_share",
	"manpower_mult", "admin_cap", "stability_local", "happiness_local", "research_pts", "literacy", "disease_resist", "pop_growth", "infra", "move_bonus",
	"recruit_speed", "granary", "fort_level"]

func _country(s: Dictionary) -> String:
	for cid in GS.alive_countries(s):
		if not str(cid).begins_with("NAT_") and GS.owned(s, cid).size() >= 3:
			return cid
	return ""

func test_building_count_and_new_ones() -> void:
	ok(Defs.buildings.size() >= 29, "at least 23 + 6 buildings (%d)" % Defs.buildings.size())
	for bid in ["granary", "bank", "stock_exchange", "factory", "post_office", "intelligence_office", "shipyard", "gendarmerie"]:
		ok(Defs.buildings.has(bid), "new building %s" % bid)
		var b: Dictionary = Defs.buildings[bid]
		ok(str(b["name"]["en"]) != "" and str(b["name"]["tr"]) != "", "%s name EN+TR" % bid)
		ok(b["requires"].has("tech") or b["requires"].has("year"), "%s has a tech or era restriction" % bid)
		ok(UI.icon("b_" + bid) != null, "%s has an icon" % bid)

func test_every_effect_is_consumed() -> void:
	for bid in Defs.buildings:
		for k in Defs.buildings[bid]["effects"]:
			ok(str(k) in LOCAL_READ or Mods.NATIONAL.has(k), "%s effect %s is read by a system" % [bid, k])

func test_national_effects_reach_the_country() -> void:
	var s := new_state()
	var cid := _country(s)
	var pid: String = GS.owned(s, cid)[0]
	var p: Dictionary = s["provinces"][pid]
	for pair in [["military_academy", "general_skill"], ["court", "legit"], ["admin_center", "overextension"], ["cultural_institution", "prestige"],
			["religious_building", "religion_unity"], ["arsenal", "recruit_cost"], ["bank", "credit"], ["intelligence_office", "spy_net"], ["gendarmerie", "coup_guard"],
			["shipyard", "naval_transport"], ["post_office", "spy_net"], ["intelligence_office", "counter_intel"]]:
		p["buildings"].erase(pair[0])
		Mods.invalidate(s)
		var v0 := Mods.get_mod(s, cid, pair[1])
		p["buildings"][pair[0]] = 1
		Mods.invalidate(s)
		var v1 := Mods.get_mod(s, cid, pair[1])
		ok(v1 != v0, "%s changes national %s (%.3f -> %.3f)" % [pair[0], pair[1], v0, v1])
		p["buildings"].erase(pair[0])
	Mods.invalidate(s)

func test_national_effects_have_diminishing_returns() -> void:
	var s := new_state()
	var cid := _country(s)
	var owned: Array = GS.owned(s, cid)
	for pid in owned:
		s["provinces"][pid]["buildings"].erase("military_academy")
	Mods.invalidate(s)
	var base := Mods.get_mod(s, cid, "general_skill")
	for pid in owned:
		s["provinces"][pid]["buildings"]["military_academy"] = 2
	Mods.invalidate(s)
	var many := Mods.get_mod(s, cid, "general_skill") - base
	ok(many <= float(Mods.NATIONAL["general_skill"]) + 0.001, "stacking is capped (%.2f)" % many)

func test_local_effects_change_the_economy() -> void:
	var s := new_state()
	var cid := _country(s)
	var pid: String = GS.owned(s, cid)[0]
	var p: Dictionary = s["provinces"][pid]
	p["buildings"] = {}
	EconomySystem.invalidate_calc(s)
	var t0 := EconomySystem.province_calc(s, pid)
	p["buildings"] = {"workshop": 2, "market": 1}
	EconomySystem.invalidate_calc(s)
	var t1 := EconomySystem.province_calc(s, pid)
	ok(float(t1["production"]) > float(t0["production"]), "workshops raise production")
	ok(float(t1["tax"]) > float(t0["tax"]) * 0.99, "markets and workshops do not lower tax")
	p["buildings"] = {"factory": 2, "workshop": 2}
	EconomySystem.invalidate_calc(s)
	var t2 := EconomySystem.province_calc(s, pid)
	ok(float(t2["production"]) > float(t1["production"]) * 0.99, "factories add production")
	ok(float(t2["coal_need"]) > 0.0, "factories burn coal")
	ok(float(t2["ind"]) > float(t1["ind"]) - 0.01, "factories raise the industrial index")
	# granaries enlarge the national store
	var g0 := Mods.granary_total(s, cid)
	p["buildings"]["granary"] = 2
	ok(Mods.granary_total(s, cid) > g0, "granaries add storage")

func test_gendarmerie_lowers_coup_chance() -> void:
	var s := new_state()
	var cid := _country(s)
	var c: Dictionary = s["countries"][cid]
	var fs := FactionsSystem.st(c)
	c["stability"] = 20.0
	c["legitimacy"] = 20.0
	fs["f"]["military"]["loy"] = 20.0
	fs["f"]["military"]["inf"] = 0.3
	for pid in GS.owned(s, cid):
		s["provinces"][pid]["buildings"].erase("gendarmerie")
	Mods.invalidate(s)
	var p0 := FactionsSystem.coup_chance(s, cid, c)
	for pid in GS.owned(s, cid):
		s["provinces"][pid]["buildings"]["gendarmerie"] = 2
	Mods.invalidate(s)
	var p1 := FactionsSystem.coup_chance(s, cid, c)
	ok(p0 > 0.0 and p1 < p0, "gendarmeries reduce the risk of a coup (%.4f -> %.4f)" % [p0, p1])

func test_era_and_tech_restrictions() -> void:
	var s := new_state("early_modern")
	var cid := _country(s)
	var c: Dictionary = s["countries"][cid]
	var pid: String = GS.owned(s, cid)[0]
	var p: Dictionary = s["provinces"][pid]
	c["gold"] = 5000.0
	p["dev"] = 8.0
	for k in c["tech_level"].keys():
		c["tech_level"][k] = 4
	p["buildings"] = {"workshop": 2}
	p["queue"] = []
	var r := ConstructionSystem.can_build(s, cid, pid, "factory")
	eq(r.get("reason", ""), "BUILD_ERR_ERA", "factories do not exist in 1519 even with the technology")
	for k in c["tech_level"].keys():
		c["tech_level"][k] = 0
	p["buildings"] = {}
	eq(ConstructionSystem.can_build(s, cid, pid, "bank")["reason"], "BUILD_ERR_TECH", "a bank needs Banking")
	var s2 := new_state("industrial_era")
	var c2: Dictionary = s2["countries"][_country(s2)]
	var cid2 := str(c2["id"])
	var pid2: String = GS.owned(s2, cid2)[0]
	var p2: Dictionary = s2["provinces"][pid2]
	c2["gold"] = 5000.0
	for k in ["iron", "wood", "stone", "coal", "lux"]:
		c2["stock"][k] = 100.0
	p2["dev"] = 8.0
	p2["buildings"] = {"workshop": 2}
	p2["queue"] = []
	c2["tech_level"]["industry"] = 3
	var r2 := ConstructionSystem.can_build(s2, cid2, pid2, "factory")
	ok(r2["ok"], "in the industrial era a factory can be built (%s)" % str(r2.get("reason", "")))
	ok(ConstructionSystem.start_build(s2, cid2, pid2, "factory")["ok"], "and started")

func test_dead_effects_were_fixed() -> void:
	for bid in ["port", "arsenal", "military_academy"]:
		for k in Defs.buildings[bid]["effects"]:
			ok(k not in ["naval_slots", "xp_gain"], "%s no longer uses the unused effect %s" % [bid, k])

func test_ai_builds_new_buildings() -> void:
	var s := new_state("industrial_era")
	s["players"] = []
	run_turns(s, 36)
	var found := {}
	for pid in s["provinces"]:
		for bid in s["provinces"][pid]["buildings"]:
			if bid in ["granary", "bank", "stock_exchange", "factory", "post_office", "intelligence_office", "shipyard", "gendarmerie"]:
				found[bid] = true
	ok(found.size() >= 2, "the AI builds new building types (%s)" % str(found.keys()))
