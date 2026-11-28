extends TestCase

func test_budget_deterministic_and_consistent() -> void:
	var s := new_state()
	for cid in GS.alive_countries(s).slice(0, 12):
		var b1 := EconomySystem.budget(s, cid)
		EconomySystem.invalidate_calc(s)
		var b2 := EconomySystem.budget(s, cid)
		near(float(b1["net"]), float(b2["net"]), 0.0001, "%s budget deterministic" % cid)
		near(float(b1["income"]) - float(b1["expenses"]), float(b1["net"]), 0.001, "%s net = income - expenses" % cid)
		var parts := float(b1["tax"]) + float(b1["production"]) + float(b1["trade"]) + float(b1["export"]) + float(b1["tribute"]) + float(b1["loot"])
		near(parts, float(b1["income"]), 0.001, "%s income is the sum of its sources" % cid)

func test_turn_applies_net_to_treasury() -> void:
	var s := new_state()
	TradeSystem.compute(s)
	var cid: String = "FRA" if s["countries"].has("FRA") else GS.alive_countries(s)[0]
	var c: Dictionary = s["countries"][cid]
	c["gold"] = 5000.0
	var b := EconomySystem.budget(s, cid)
	var before := float(c["gold"])
	var b2 := EconomySystem.process_turn(s, cid)
	var delta := float(c["gold"]) - before
	var leak := float(b2.get("leak", 0.0))
	ok(absf(delta - (float(b["net"]) - leak)) < 60.0, "treasury change ~= net (delta %.1f net %.1f leak %.1f)" % [delta, float(b["net"]), leak])

func test_higher_taxes_more_income_more_unrest() -> void:
	var s := new_state()
	var cid: String = s["player"]   # a major power: small tribal states have a lower tax ceiling
	var c: Dictionary = s["countries"][cid]
	c["tax_rate"] = 0.15
	EconomySystem.invalidate_calc(s)
	var low := float(EconomySystem.budget(s, cid)["tax"])
	var pid: String = GS.owned(s, cid)[0]
	var u_low := float(PopulationSystem.unrest_target(s, pid)["parts"]["UNREST_TAX"])
	c["tax_rate"] = 0.45
	EconomySystem.invalidate_calc(s)
	var high := float(EconomySystem.budget(s, cid)["tax"])
	var u_high := float(PopulationSystem.unrest_target(s, pid)["parts"]["UNREST_TAX"])
	ok(high > low * 2.0, "tripling taxes more than doubles revenue (%f -> %f)" % [low, high])
	ok(u_high > u_low + 20.0, "excess taxation raises unrest (%f -> %f)" % [u_low, u_high])

func test_military_spending_hurts_budget() -> void:
	var s := new_state()
	var cid: String = s["player"]
	var base := float(EconomySystem.budget(s, cid)["net"])
	var pid: String = GS.owned(s, cid)[0]
	MilitarySystem.create_army(s, cid, pid, {"spearmen": 40.0}, null)
	EconomySystem.invalidate_calc(s)
	var after := float(EconomySystem.budget(s, cid)["net"])
	ok(after < base - 25.0, "adding 40 regiments cuts net income (%f -> %f)" % [base, after])

func test_food_shortage_has_consequences() -> void:
	var s := new_state()
	TradeSystem.compute(s)
	var cid := ""
	for c2 in GS.alive_countries(s):
		if not str(c2).begins_with("NAT_") and GS.owned(s, c2).size() >= 3:
			cid = c2
			break
	var c: Dictionary = s["countries"][cid]
	c["import_food"] = false
	c["stock"]["food"] = 0.0
	for pid in GS.owned(s, cid):
		s["provinces"][pid]["devastation"] = 0.85
	EconomySystem.invalidate_calc(s)
	var pop0 := DiplomacySystem.total_pop(s, cid)
	for i in 6:
		s["_c"].erase("pop_total")
		EconomySystem.process_turn(s, cid)
		PopulationSystem.process_turn(s)
		EconomySystem.invalidate_calc(s)
	ok(float(c["food_ratio"]) < 1.0, "food ratio below 1 under famine (%f)" % float(c["food_ratio"]))
	s["_c"].erase("pop_total")
	ok(DiplomacySystem.total_pop(s, cid) < pop0, "population declines during famine")
	var hungry: Dictionary = PopulationSystem.unrest_target(s, GS.owned(s, cid)[0])["parts"]
	ok(hungry.has("UNREST_HUNGER"), "hunger shows up as an unrest source")

func test_food_import_costs_gold() -> void:
	var s := new_state()
	TradeSystem.compute(s)
	var cid := ""
	for c2 in GS.alive_countries(s):
		if not str(c2).begins_with("NAT_") and GS.owned(s, c2).size() >= 3:
			cid = c2
			break
	var c: Dictionary = s["countries"][cid]
	c["import_food"] = true
	c["stock"]["food"] = 0.0
	for pid in GS.owned(s, cid):
		s["provinces"][pid]["devastation"] = 0.8
	EconomySystem.invalidate_calc(s)
	var b := EconomySystem.budget(s, cid)
	ok(float(b["food_import"]) > 0.0, "shortage creates an import bill")

func test_debt_and_bankruptcy() -> void:
	var s := new_state()
	TradeSystem.compute(s)
	var cid := ""
	for c2 in GS.alive_countries(s):
		if not str(c2).begins_with("NAT_") and GS.owned(s, c2).size() >= 3:
			cid = c2
			break
	var c: Dictionary = s["countries"][cid]
	c["budget"] = EconomySystem.budget(s, cid)
	var lim := EconomySystem.credit_limit(s, cid)
	c["gold"] = -(lim * 0.4) - float(c["budget"]["net"])
	EconomySystem.process_turn(s, cid)
	ok(float(c["gold"]) >= 0.0 and float(c["debt"]) > 0.0, "small deficit becomes a loan (debt %f)" % float(c["debt"]))
	var b := EconomySystem.budget(s, cid)
	ok(float(b["interest"]) > 0.0, "debt accrues interest")
	var armies0 := GS.armies_of(s, cid).size()
	c["gold"] = -9.0e6
	c["debt"] = 0.0
	EconomySystem.process_turn(s, cid)
	ok(int(c["bankrupt_turns"]) >= 1, "huge deficit triggers bankruptcy")
	ok(GS.armies_of(s, cid).size() <= armies0, "bankruptcy disbands armies")
	ok(float(c["stability"]) < 80.0, "bankruptcy hurts stability")

func test_no_infinite_money_over_long_run() -> void:
	var s := new_state("early_modern", "", "normal", 99)
	s["players"] = []
	run_turns(s, 80)
	for cid in GS.alive_countries(s):
		var c: Dictionary = s["countries"][cid]
		var inc := maxf(50.0, float(c.get("budget", {}).get("income", 0.0)))
		ok(float(c["gold"]) < inc * 60.0 + 3000.0, "%s treasury %.0f not runaway vs income %.0f" % [cid, float(c["gold"]), inc])
		ok(float(c["debt"]) < 20000.0, "%s debt bounded" % cid)
		ok(not is_nan(float(c["gold"])) and not is_inf(float(c["gold"])), "%s gold finite" % cid)

func test_trade_uses_real_connectivity() -> void:
	var s := new_state()
	var t := TradeSystem.compute(s)
	ok(t["income"].size() > 10, "trade produces income for many countries")
	var any_foreign := false
	for pid in t["by_province"]:
		var d: Dictionary = t["by_province"][pid]
		if d["hub"] != "" and s["provinces"][d["hub"]]["owner"] != s["provinces"][pid]["owner"]:
			any_foreign = true
			break
	ok(any_foreign, "some provinces trade through foreign hubs")
	# a war cuts routes: put two neighbours at war and check their cross-border flows vanish
	var pair := neighbour_pair(s, 2)
	if pair.size() > 0:
		DiplomacySystem.start_war(s, [pair[0]], [pair[1]], "conquest", [], true)
		TradeSystem.invalidate(s)
		var t2 := TradeSystem.compute(s)
		for pid in t2["by_province"]:
			var d2: Dictionary = t2["by_province"][pid]
			if d2["hub"] == "":
				continue
			var o1: String = s["provinces"][pid]["owner"]
			var o2: String = s["provinces"][d2["hub"]]["owner"]
			if (o1 == pair[0] and o2 == pair[1]) or (o1 == pair[1] and o2 == pair[0]):
				fail("trade flows across a war front")
				break
