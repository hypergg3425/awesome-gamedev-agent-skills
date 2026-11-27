extends TestCase
## v2.1 technology expansion: 46 specialisation techs, era gating with the historical-lag rule, extra prerequisites.

const CONSUMED_MODS := ["manpower", "army_upkeep", "morale", "inf_def", "inf_atk", "cav_atk", "supply", "move", "recruit_cost", "art_atk", "siege", "attrition",
	"disease", "fort_def", "build_cost", "naval_atk", "trade", "naval_transport", "food", "pop_growth", "tariff", "diplo", "credit", "interest", "prod", "employment",
	"infra", "admin_cap", "mine", "corruption", "tax", "unrest", "spy_net", "counter_intel", "legit", "heir_quality", "prestige", "happiness", "faction_loyalty",
	"literacy", "research", "build_speed", "royal_health", "stability"]

func _country(s: Dictionary) -> String:
	for cid in GS.alive_countries(s):
		if not str(cid).begins_with("NAT_"):
			return cid
	return ""

func _strip(c: Dictionary) -> void:
	c["researched"] = {}
	for k in c["tech_level"].keys():
		c["tech_level"][k] = 0
	for b in Const.BRANCHES:
		c["research"]["current"][b] = ""

func test_original_92_kept_and_40_new_added() -> void:
	var base := 0
	var specs := 0
	for tid in Defs.techs:
		if bool(Defs.techs[tid].get("spec", false)):
			specs += 1
		else:
			base += 1
	eq(base, 92, "the 92 original technologies are unchanged")
	ok(specs >= 40, "at least 40 new technologies (%d)" % specs)
	for lid in Defs.tech_lines:
		var n := 0
		for tid in Defs.techs:
			if Defs.techs[tid]["line"] == lid and bool(Defs.techs[tid].get("spec", false)):
				n += 1
		ok(n >= 2, "line %s has %d specialisations" % [lid, n])

func test_names_and_descriptions_in_both_languages() -> void:
	for tid in Defs.techs:
		var t: Dictionary = Defs.techs[tid]
		ok(str(t["name"].get("en", "")) != "" and str(t["name"].get("tr", "")) != "", "%s name EN+TR" % tid)
		if bool(t.get("spec", false)):
			ok(str(t["desc"].get("en", "")) != "" and str(t["desc"].get("tr", "")) != "", "%s description EN+TR" % tid)
			ok(int(t["era_year"]) >= 1000, "%s has an era year" % tid)

func test_prerequisites_exist_and_graph_is_acyclic_and_reachable() -> void:
	var have := {}
	var changed := true
	var guard := 0
	while changed and guard < 20:
		changed = false
		guard += 1
		for tid in Defs.techs:
			if have.has(tid):
				continue
			var okp := true
			for pre in Defs.techs[tid]["prereq"]:
				ok(Defs.techs.has(pre), "%s prerequisite %s exists" % [tid, pre])
				if not have.has(pre):
					okp = false
			if okp:
				have[tid] = true
				changed = true
	eq(have.size(), Defs.techs.size(), "every technology is reachable from the start")

func test_specialisations_need_own_line_and_often_cross_line() -> void:
	var cross := 0
	for tid in Defs.techs:
		var t: Dictionary = Defs.techs[tid]
		if bool(t.get("spec", false)):
			ok("%s_%d" % [t["line"], int(t["level"])] in t["prereq"], "%s needs its line level %d" % [tid, int(t["level"])])
			if t["prereq"].size() > 1:
				cross += 1
	ok(cross >= 8, "several specialisations need another line (%d)" % cross)

func test_effects_touch_all_areas_and_are_consumed() -> void:
	var areas := {"military": false, "economy": false, "administration": false, "infrastructure": false, "society": false, "diplomacy": false}
	for tid in Defs.techs:
		if not bool(Defs.techs[tid].get("spec", false)):
			continue
		for k in Defs.techs[tid]["effects"]:
			ok(str(k) in CONSUMED_MODS, "%s effect %s is read by a system" % [tid, k])
			if str(k) in ["manpower", "morale", "siege", "attrition", "fort_def", "naval_atk", "art_atk"]:
				areas["military"] = true
			if str(k) in ["trade", "credit", "interest", "prod", "food", "mine", "tax", "tariff"]:
				areas["economy"] = true
			if str(k) in ["admin_cap", "corruption", "faction_loyalty", "legit"]:
				areas["administration"] = true
			if str(k) in ["infra", "build_speed", "move"]:
				areas["infrastructure"] = true
			if str(k) in ["literacy", "disease", "happiness", "research"]:
				areas["society"] = true
			if str(k) in ["diplo", "spy_net", "counter_intel"]:
				areas["diplomacy"] = true
	for a in areas:
		ok(areas[a], "new technologies touch %s" % a)

func test_era_gating_blocks_anachronisms() -> void:
	var s := new_state("medieval_europe")
	var cid := _country(s)
	var c: Dictionary = s["countries"][cid]
	_strip(c)
	c["gold"] = 100000.0
	ok(int(GS.date_of(s)["year"]) < 1100, "scenario starts in the eleventh century")
	# nineteenth-century technology is impossible even with every earlier technology in hand
	for tid in Defs.techs:
		if int(Defs.techs[tid]["level"]) <= 3 and not bool(Defs.techs[tid].get("spec", false)):
			TechSystem.grant(s, cid, tid)
	s["_c"]["lead_turn"] = -1
	var r := TechSystem.can_research(s, cid, "infrastructure_4")
	ok(not r["ok"], "Railway Age cannot be researched in the 11th century")
	eq(r.get("reason", ""), "TECH_ERR_ERA", "the reason is the era")
	var r2 := TechSystem.can_research(s, cid, "industry_4")
	eq(r2.get("reason", ""), "TECH_ERR_ERA", "Factory System is blocked too")
	# a basic technology is open
	_strip(c)
	ok(TechSystem.can_research(s, cid, "agriculture_1")["ok"], "level 1 technology is available")
	ok(not TechSystem.available(s, cid).has("artillery_3"), "level 3 is not even listed")

func test_era_opens_as_years_pass() -> void:
	var s := new_state("industrial_era")
	var cid := _country(s)
	var c: Dictionary = s["countries"][cid]
	_strip(c)
	for tid in Defs.techs:
		if Defs.techs[tid]["level"] <= 3 and not bool(Defs.techs[tid].get("spec", false)):
			c["researched"][tid] = true
	var chk := TechSystem.era_check(s, cid, "infrastructure_4")
	ok(chk["ok"], "in 1871 the railway age is open (years early %d, lead %.0f)" % [int(chk["years_early"]), float(chk["lead"])])
	ok(TechSystem.can_research(s, cid, "infrastructure_4")["ok"], "can start level 4")

func test_historical_lag_rule_rewards_leaders() -> void:
	var s := new_state("early_modern")
	var cid := _country(s)
	var c: Dictionary = s["countries"][cid]
	var base_lead := TechSystem.research_lead(s, cid)
	for k in c["tech_level"].keys():
		c["tech_level"][k] = 4
	s["_c"].erase("lead")
	s["_c"]["lead_turn"] = -1
	var ahead_lead := TechSystem.research_lead(s, cid)
	ok(ahead_lead > base_lead, "a country far ahead of the world may look further ahead (%.0f vs %.0f)" % [ahead_lead, base_lead])
	ok(ahead_lead <= TechSystem.BASE_LEAD + TechSystem.MAX_EXTRA_LEAD + 0.01, "but never more than the cap")
	var tid := "science_b"
	ok(int(Defs.techs[tid]["era_year"]) - int(GS.date_of(s)["year"]) > 100, "the test technology is far in the future of 1519")

func test_new_tech_effects_apply() -> void:
	var s := new_state()
	var cid := _country(s)
	var c: Dictionary = s["countries"][cid]
	var before := Mods.get_mod(s, cid, "spy_net")
	TechSystem.grant(s, cid, "public_admin_b")
	Mods.invalidate(s)
	ok(Mods.get_mod(s, cid, "spy_net") > before, "Secret Chancery raises spy networks")
	var c0 := Mods.get_mod(s, cid, "faction_loyalty")
	TechSystem.grant(s, cid, "legal_reform_a")
	Mods.invalidate(s)
	ok(Mods.get_mod(s, cid, "faction_loyalty") > c0, "Charters of Liberties raise faction loyalty")
	eq(TechSystem.level(c, "public_admin") >= 1, true, "granting a spec tech keeps the line level sane")

func test_ai_researches_within_era() -> void:
	var s := new_state("medieval_europe")
	s["players"] = []
	run_turns(s, 30)
	var year := int(GS.date_of(s)["year"])
	for cid in GS.alive_countries(s):
		for tid in s["countries"][cid]["researched"]:
			var t: Dictionary = Defs.techs[tid]
			if int(t["level"]) >= 4:
				fail("%s researched level 4 technology %s in %d" % [cid, tid, year])
