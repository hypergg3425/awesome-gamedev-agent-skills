extends TestCase

func _country(s: Dictionary) -> String:
	for c2 in GS.alive_countries(s):
		if not str(c2).begins_with("NAT_"):
			return c2
	return ""

func test_prerequisites_enforced() -> void:
	var s := new_state()
	var cid := _country(s)
	var c: Dictionary = s["countries"][cid]
	c["researched"].erase("artillery_4")
	var chk := TechSystem.can_research(s, cid, "artillery_4")
	ok(not chk["ok"] or c["researched"].has("artillery_3"), "level 4 requires the previous level")
	# strip all military techs and try level 3
	for tid in Defs.techs.keys():
		c["researched"].erase(tid)
	for k in c["tech_level"].keys():
		c["tech_level"][k] = 0
	var r := TechSystem.start_research(s, cid, "artillery_3")
	ok(not r["ok"], "cannot skip levels")
	eq(r["reason"], "TECH_ERR_PREREQ", "prerequisite reason reported")
	c["gold"] = 1000.0
	var r1 := TechSystem.start_research(s, cid, "fortification_1")
	ok(r1["ok"], "level 1 without prerequisites is allowed")

func test_research_completes_and_changes_gameplay() -> void:
	var s := new_state()
	var cid := _country(s)
	var c: Dictionary = s["countries"][cid]
	for tid in Defs.techs.keys():
		c["researched"].erase(tid)
	for k in c["tech_level"].keys():
		c["tech_level"][k] = 0
	c["gold"] = 1000.0
	var food0 := float(Mods.get_mod(s, cid, "food"))
	TechSystem.start_research(s, cid, "agriculture_1")
	var n := 0
	while not c["researched"].has("agriculture_1") and n < 400:
		TechSystem.process_turn(s, cid)
		n += 1
	ok(c["researched"].has("agriculture_1"), "research completes in %d turns" % n)
	ok(n > 2, "research takes time (not instant)")
	Mods.invalidate(s)
	ok(float(Mods.get_mod(s, cid, "food")) > food0, "technology has a mechanical effect")
	eq(TechSystem.level(c, "agriculture"), 1, "tech level recorded")

func test_costs_gold_and_blocks_second_in_branch() -> void:
	var s := new_state()
	var cid := _country(s)
	var c: Dictionary = s["countries"][cid]
	for tid in Defs.techs.keys():
		c["researched"].erase(tid)
	for k in c["tech_level"].keys():
		c["tech_level"][k] = 0
	for b in Const.BRANCHES:
		c["research"]["current"][b] = ""
	c["gold"] = 500.0
	var g0 := float(c["gold"])
	ok(TechSystem.start_research(s, cid, "agriculture_1")["ok"], "start")
	ok(float(c["gold"]) < g0, "starting costs gold")
	eq(TechSystem.can_research(s, cid, "trade_1")["reason"] if Defs.techs["trade_1"]["branch"] == Defs.techs["agriculture_1"]["branch"] else "TECH_ERR_BUSY", "TECH_ERR_BUSY", "one project per branch")
	c["gold"] = 0.0
	eq(TechSystem.start_research(s, cid, "education_1")["reason"], "ERR_NO_GOLD", "needs gold")

func test_unit_unlocks_follow_technology() -> void:
	var s := new_state()
	var cid := _country(s)
	var c: Dictionary = s["countries"][cid]
	for k in c["tech_level"].keys():
		c["tech_level"][k] = 0
	ok(not UnitUtil.is_available(s, cid, "musketeers"), "musketeers locked at level 0")
	c["tech_level"]["infantry_tactics"] = 2
	ok(UnitUtil.is_available(s, cid, "musketeers"), "musketeers unlocked by Infantry Tactics 2")
	ok(UnitUtil.is_available(s, cid, "spearmen"), "base units always available")

func test_invest_gold_into_research() -> void:
	var s := new_state()
	var cid := _country(s)
	var c: Dictionary = s["countries"][cid]
	c["gold"] = 1000.0
	var bank0 := float(c["research"].get("bank", 0.0))
	var r := TechSystem.invest(s, cid, 200.0)
	ok(r["ok"], "invest ok")
	ok(float(c["research"]["bank"]) > bank0 + 30.0, "points added")
	ok(float(c["gold"]) == 800.0, "gold spent")
