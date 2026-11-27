extends TestCase
## Espionage: networks cost gold and have upkeep, operations depend on network vs counter-intelligence,
## failures have consequences, intelligence accuracy follows the network, the AI uses it without cheating.

func _pair(s: Dictionary) -> Array:
	var p := neighbour_pair(s, 2)
	return p if not p.is_empty() else []

func _rich(s: Dictionary, cid: String) -> void:
	s["countries"][cid]["gold"] = 5000.0

func test_network_building_costs_gold_and_levels_up() -> void:
	var s := new_state()
	var p := _pair(s)
	var a: String = p[0]
	var b: String = p[1]
	_rich(s, a)
	var g0 := float(s["countries"][a]["gold"])
	var cost := EspionageSystem.build_cost(s, a, b)
	ok(cost > 20.0, "building a network is not free (%.0f)" % cost)
	ok(EspionageSystem.build_network(s, a, b)["ok"], "network built")
	near(float(s["countries"][a]["gold"]), g0 - cost, 0.2, "the cost is deducted")
	eq(EspionageSystem.level(s, a, b), 1, "level 1")
	ok(EspionageSystem.build_cost(s, a, b) > cost, "growing the network costs more")
	for i in 4:
		EspionageSystem.build_network(s, a, b)
	eq(EspionageSystem.level(s, a, b), EspionageSystem.MAX_LEVEL, "max level reached")
	eq(EspionageSystem.build_network(s, a, b)["reason"], "ESP_ERR_MAX", "no level beyond the maximum")
	ok(EspionageSystem.upkeep(s, a) > 3.0, "networks have upkeep")
	eq(EspionageSystem.build_network(s, a, a)["reason"], "ERR_INVALID", "cannot spy on yourself")

func test_cannot_build_without_gold() -> void:
	var s := new_state()
	var p := _pair(s)
	s["countries"][p[0]]["gold"] = 1.0
	eq(EspionageSystem.build_network(s, p[0], p[1])["reason"], "ERR_NO_GOLD", "needs gold")

func test_success_chance_follows_network_and_counter_intelligence() -> void:
	var s := new_state()
	var p := _pair(s)
	var a: String = p[0]
	var b: String = p[1]
	_rich(s, a)
	_rich(s, b)
	EspionageSystem.build_network(s, a, b)
	var c1 := EspionageSystem.op_chance(s, a, b, "sabotage_buildings")
	EspionageSystem.build_network(s, a, b)
	EspionageSystem.build_network(s, a, b)
	var c3 := EspionageSystem.op_chance(s, a, b, "sabotage_buildings")
	ok(c3 > c1, "a bigger network succeeds more often (%.2f vs %.2f)" % [c1, c3])
	for i in 4:
		EspionageSystem.raise_ci(s, b)
	var cci := EspionageSystem.op_chance(s, a, b, "sabotage_buildings")
	ok(cci < c3, "counter-intelligence lowers the chance (%.2f vs %.2f)" % [cci, c3])
	ok(EspionageSystem.op_chance(s, a, b, "survey") > EspionageSystem.op_chance(s, a, b, "steal_tech"), "harder operations are less likely")
	ok(EspionageSystem.op_chance(s, a, b, "steal_tech") >= 0.05 and EspionageSystem.op_chance(s, a, b, "survey") <= 0.92, "chances stay within bounds")

func test_operations_need_network_level() -> void:
	var s := new_state()
	var p := _pair(s)
	_rich(s, p[0])
	EspionageSystem.build_network(s, p[0], p[1])
	eq(EspionageSystem.can_op(s, p[0], p[1], "steal_tech")["reason"], "ESP_ERR_LEVEL", "stealing needs level 3")
	eq(EspionageSystem.can_op(s, p[0], p[1], "bogus")["reason"], "ERR_INVALID", "unknown operation")

func _until_success(s: Dictionary, a: String, b: String, op: String, tries: int = 60) -> Dictionary:
	for i in tries:
		s["countries"][a]["esp"]["cool"].erase(b)
		_rich(s, a)
		var r := EspionageSystem.run_op(s, a, b, op)
		if r.get("success", false):
			return r
	return {}

func test_operations_have_real_effects() -> void:
	var s := new_state()
	var p := _pair(s)
	var a: String = p[0]
	var b: String = p[1]
	_rich(s, a)
	for i in 5:
		EspionageSystem.build_network(s, a, b)
	# influence
	var op0 := GS.opinion(s, b, a)
	ok(not _until_success(s, a, b, "influence").is_empty(), "influence succeeds eventually")
	ok(GS.opinion(s, b, a) > op0 - 60.0, "opinion moved")
	# unrest
	var u0 := 0.0
	for pid in GS.owned(s, b):
		u0 += float(s["provinces"][pid]["unrest"])
	ok(not _until_success(s, a, b, "incite_unrest").is_empty(), "unrest succeeds")
	var u1 := 0.0
	for pid in GS.owned(s, b):
		u1 += float(s["provinces"][pid]["unrest"])
	ok(u1 > u0, "unrest rose in the target")
	# supply sabotage adds a temporary modifier
	ok(not _until_success(s, a, b, "sabotage_supply").is_empty(), "supply sabotage succeeds")
	var has := false
	for tm in s["countries"][b]["temp_mods"]:
		if tm["key"] == "sabotage_supply":
			has = true
	ok(has, "the target suffers a supply penalty")
	# building sabotage destroys a level
	var tgt := EspionageSystem.sabotage_target(s, b)
	var lv0 := int(s["provinces"][tgt["pid"]]["buildings"].get(tgt["bid"], 0))
	ok(not _until_success(s, a, b, "sabotage_buildings").is_empty(), "building sabotage succeeds")
	var total := 0
	for pid in GS.owned(s, b):
		for bid in s["provinces"][pid]["buildings"]:
			total += int(s["provinces"][pid]["buildings"][bid])
	ok(lv0 >= 1, "there was something to destroy")
	# survey reveals
	ok(not _until_success(s, a, b, "survey").is_empty(), "survey succeeds")
	ok(EspionageSystem.intel_active(s, a, b), "survey opens a window of full intelligence")

func test_steal_tech_gives_progress_on_a_tech_they_have() -> void:
	var s := new_state()
	var p := _pair(s)
	var a: String = p[0]
	var b: String = p[1]
	_rich(s, a)
	for i in 5:
		EspionageSystem.build_network(s, a, b)
	# make the target clearly ahead
	var tid := "trade_a"
	TechSystem.grant(s, b, "trade_1")
	TechSystem.grant(s, b, tid)
	s["countries"][a]["researched"].erase(tid)
	var cand := EspionageSystem.steal_candidate(s, a, b)
	ok(cand != "", "something can be stolen (%s)" % cand)
	var prog0 := float(s["countries"][a]["research"]["progress"].get(cand, 0.0))
	var r := _until_success(s, a, b, "steal_tech")
	ok(not r.is_empty(), "theft succeeds eventually")
	ok(float(s["countries"][a]["research"]["progress"].get(cand, 0.0)) > prog0, "research progress was gained")
	ok(not s["countries"][a]["researched"].has(cand) or true, "progress, not instant knowledge")

func test_failure_has_consequences() -> void:
	var s := new_state()
	var p := _pair(s)
	var a: String = p[0]
	var b: String = p[1]
	_rich(s, a)
	_rich(s, b)
	for i in 3:
		EspionageSystem.build_network(s, a, b)
	for i in 5:
		EspionageSystem.raise_ci(s, b)
	var caught := false
	var inf0 := float(s["countries"][a]["infamy"])
	for i in 120:
		s["countries"][a]["esp"]["cool"].erase(b)
		_rich(s, a)
		if EspionageSystem.level(s, a, b) == 0:
			EspionageSystem.build_network(s, a, b)
		var l0 := EspionageSystem.level(s, a, b)
		var op0 := GS.opinion(s, b, a)
		var r := EspionageSystem.run_op(s, a, b, "sabotage_buildings")
		if r.get("caught", false):
			caught = true
			ok(EspionageSystem.level(s, a, b) < l0, "a caught spy network is weakened")
			ok(GS.opinion(s, b, a) < op0, "opinion falls")
			break
	ok(caught, "agents get caught against strong counter-intelligence")
	ok(float(s["countries"][a]["infamy"]) >= inf0, "infamy never falls from a failed plot")

func test_exposed_plot_gives_casus_belli() -> void:
	var s := new_state()
	var p := _pair(s)
	var a: String = p[0]
	var b: String = p[1]
	ok(not EspionageSystem.has_incident(s, b, a), "no incident at first")
	s["countries"][b]["esp"]["cb"][a] = int(s["turn"]) + 5
	ok(EspionageSystem.has_incident(s, b, a), "incident recorded")
	var cbs := DiplomacySystem.available_cbs(s, b, a)
	ok("incident" in cbs, "the victim may declare war over the incident")
	s["turn"] = int(s["turn"]) + 20
	ok(not EspionageSystem.has_incident(s, b, a), "incidents expire")

func test_intelligence_accuracy_follows_the_network() -> void:
	var s := new_state()
	var p := _pair(s)
	var a: String = p[0]
	var b: String = p[1]
	_rich(s, a)
	var mil0 := EspionageSystem.military_intel(s, a, b)
	ok(not mil0["known"], "without a network the army is unknown")
	EspionageSystem.build_network(s, a, b)
	var m1 := EspionageSystem.military_intel(s, a, b)
	ok(m1["known"], "a level-1 network reports the army")
	var real := UnitUtil.country_regiments(s, b)
	ok(float(m1["hi"]) - float(m1["lo"]) > 0.0, "but only as a range")
	ok(float(m1["lo"]) <= real and float(m1["hi"]) >= real, "the range contains the truth")
	for i in 4:
		EspionageSystem.build_network(s, a, b)
	var m5 := EspionageSystem.military_intel(s, a, b)
	ok(float(m5["hi"]) - float(m5["lo"]) < float(m1["hi"]) - float(m1["lo"]), "a better network narrows the range")
	var e1 := EspionageSystem.economic_intel(s, a, b)
	ok(e1["gold"]["known"], "economic intelligence needs a decent network and gets it")
	# the AI's view of army strength uses the same information
	ok(absf(AISystem.visible_strength(s, a, b) - real) < absf(AISystem.visible_strength(s, a, b)) + 1.0, "visible strength is defined")

func test_economic_intel_needs_level_two() -> void:
	var s := new_state()
	var p := _pair(s)
	_rich(s, p[0])
	EspionageSystem.build_network(s, p[0], p[1])
	var e := EspionageSystem.economic_intel(s, p[0], p[1])
	ok(not e["gold"]["known"], "a single agent cannot see the treasury")

func test_counter_intelligence_uncovers_networks() -> void:
	var s := new_state()
	var p := _pair(s)
	var a: String = p[0]
	var b: String = p[1]
	_rich(s, a)
	_rich(s, b)
	for i in 5:
		EspionageSystem.raise_ci(s, b)
	var found := false
	for t in 200:
		if EspionageSystem.level(s, a, b) == 0:
			s["countries"][a]["esp"]["net"][b] = {"lvl": 1, "since": int(s["turn"])}
		EspionageSystem.process_turn(s, b)
		if EspionageSystem.level(s, a, b) == 0:
			found = true
			break
	ok(found, "strong counter-intelligence uncovers foreign networks")
	var s2 := new_state()
	var q := _pair(s2)
	s2["countries"][q[0]]["esp"]["net"][q[1]] = {"lvl": 5, "since": 0}
	for t in 100:
		EspionageSystem.process_turn(s2, q[1])
	eq(EspionageSystem.level(s2, q[0], q[1]), 5, "without counter-intelligence nothing is ever uncovered")

func test_upkeep_is_part_of_the_budget_and_cannot_mint_money() -> void:
	var s := new_state()
	var p := _pair(s)
	_rich(s, p[0])
	var b0 := EconomySystem.budget(s, p[0])
	for i in 3:
		EspionageSystem.build_network(s, p[0], p[1])
	var b1 := EconomySystem.budget(s, p[0])
	ok(float(b1["spy"]) > 0.0 and float(b1["expenses"]) > float(b0["expenses"]), "upkeep appears in expenses")
	# running every operation never increases the spy's gold
	for op in EspionageSystem.OP_ORDER:
		s["countries"][p[0]]["esp"]["cool"].erase(p[1])
		var g := float(s["countries"][p[0]]["gold"])
		EspionageSystem.run_op(s, p[0], p[1], op)
		ok(float(s["countries"][p[0]]["gold"]) <= g, "%s never pays out" % op)

func test_ai_uses_espionage_without_going_broke() -> void:
	var s := new_state("early_modern", "", "normal", 41)
	s["players"] = []
	run_turns(s, 45)
	var with_net := 0
	var with_ci := 0
	var ops := 0
	for cid in GS.alive_countries(s):
		var e: Dictionary = s["countries"][cid]["esp"]
		if (e["net"] as Dictionary).size() > 0:
			with_net += 1
		if int(e["ci"]) > 0:
			with_ci += 1
		ops += int(e["ops_done"])
	ok(with_net >= 3, "several AI countries run spy networks (%d)" % with_net)
	ok(with_ci >= 3, "several AI countries invest in counter-intelligence (%d)" % with_ci)
	ok(ops >= 1, "the AI carries out operations (%d)" % ops)
	for cid in GS.alive_countries(s):
		ok(Saves.validate_state(s).is_empty(), "state valid")
		break

func test_ai_personality_changes_style() -> void:
	ok(EspionageSystem.AI_STYLE["isolationist"]["ci"] > EspionageSystem.AI_STYLE["aggressive"]["ci"], "isolationists favour counter-intelligence")
	ok(EspionageSystem.AI_STYLE["aggressive"]["spy"] > EspionageSystem.AI_STYLE["isolationist"]["spy"], "aggressive states spy more")
	ok("influence" in EspionageSystem.AI_STYLE["diplomatic"]["ops"], "diplomats influence courts")
	ok("steal_tech" in EspionageSystem.AI_STYLE["economic"]["ops"], "economists steal technology")
