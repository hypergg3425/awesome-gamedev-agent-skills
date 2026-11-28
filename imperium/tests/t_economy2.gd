extends TestCase
## Economy depth: employment, specialisation, credit, crises, shortages, and bounded money creation.

func _country(s: Dictionary) -> String:
	var best := ""
	var bn := 0
	for cid in GS.alive_countries(s):
		if not bool(s["countries"][cid].get("native", false)) and GS.owned(s, cid).size() > bn:
			bn = GS.owned(s, cid).size()
			best = cid
	return best

func test_province_stats_and_specialisation() -> void:
	var s := new_state()
	var cid := _country(s)
	var specs := 0
	for pid in GS.owned(s, cid):
		var pc := EconomySystem.province_calc(s, pid)
		ok(float(pc["emp"]) >= 0.3 and float(pc["emp"]) <= 1.0, "employment bounded")
		ok(float(pc["ind"]) >= 0.0 and float(pc["ind"]) <= 10.0, "industry bounded")
		if str(pc["spec"]) != "":
			specs += 1
	ok(specs >= 1, "regions specialise (%d)" % specs)
	var st := EconomyDepth.country_stats(s, cid)
	ok(float(st["urbanisation"]) > 0.0 and float(st["employment"]) > 0.3, "country totals")

func test_unemployment_raises_unrest_and_jobs_come_from_buildings() -> void:
	var s := new_state()
	var cid := _country(s)
	var pid: String = GS.owned(s, cid)[0]
	var p: Dictionary = s["provinces"][pid]
	p["buildings"] = {}
	p["pop"] = 400.0
	EconomySystem.invalidate_calc(s)
	var e0 := float(EconomySystem.province_calc(s, pid)["emp"])
	var u0 := float(PopulationSystem.unrest_target(s, pid)["total"])
	p["buildings"] = {"workshop": 3, "farm": 3, "market": 3, "mine": 3}
	EconomySystem.invalidate_calc(s)
	var e1 := float(EconomySystem.province_calc(s, pid)["emp"])
	ok(e1 > e0, "buildings create jobs (%.2f -> %.2f)" % [e0, e1])
	ok(float(PopulationSystem.unrest_target(s, pid)["total"]) <= u0, "more jobs, no more unrest")

func test_credit_rating_and_interest_follow_debt() -> void:
	var s := new_state()
	var cid := _country(s)
	var c: Dictionary = s["countries"][cid]
	c["debt"] = 0.0
	var good := EconomyDepth.credit_score(s, cid)
	c["debt"] = 5000.0
	var bad := EconomyDepth.credit_score(s, cid)
	ok(bad < good, "debt lowers the score (%.0f vs %.0f)" % [good, bad])
	EconomyDepth.st(c)["score"] = good
	var r_good := EconomySystem.interest_rate(s, cid)
	EconomyDepth.st(c)["score"] = bad
	var r_bad := EconomySystem.interest_rate(s, cid)
	ok(r_bad > r_good, "a poor rating pays more interest")
	ok(EconomyDepth.limit_factor(c) < 1.0 and EconomyDepth.rating_of(bad) != "A", "and borrows less")
	eq(EconomyDepth.rating_of(90.0), "A", "A rating")
	eq(EconomyDepth.rating_of(10.0), "D", "D rating")

func test_loans_and_repayment_are_net_worth_neutral() -> void:
	var s := new_state()
	var cid := _country(s)
	var c: Dictionary = s["countries"][cid]
	c["debt"] = 0.0
	var room := EconomyDepth.loan_room(s, cid)
	ok(room > 50.0, "some credit is available")
	var w0 := float(c["gold"]) - float(c["debt"])
	ok(EconomyDepth.take_loan(s, cid, 50.0)["ok"], "loan taken")
	ok(float(c["gold"]) - float(c["debt"]) <= w0, "net worth does not rise by borrowing")
	eq(EconomyDepth.take_loan(s, cid, room * 5.0)["reason"], "ECO_ERR_CREDIT_LIMIT", "limited by the credit line")
	var d0 := float(c["debt"])
	ok(EconomyDepth.repay(s, cid, 20.0)["ok"], "repaid")
	near(float(c["debt"]), d0 - 20.0, 0.01, "debt falls")
	EconomyDepth.st(c)["phase"] = "crisis"
	EconomyDepth.st(c)["cause"] = "bank_run"
	eq(EconomyDepth.take_loan(s, cid, 10.0)["reason"], "ECO_ERR_CREDIT_FROZEN", "a banking crisis freezes credit")

func test_default_records_forgiveness_and_starts_a_crisis() -> void:
	var s := new_state()
	var cid := _country(s)
	var c: Dictionary = s["countries"][cid]
	c["debt"] = 1000.0
	var f0 := float(s["econ"]["forgiven"])
	EconomySystem._bankruptcy(s, cid, 500.0)
	ok(float(s["econ"]["forgiven"]) > f0, "forgiven debt is accounted")
	eq(str(EconomyDepth.st(c)["phase"]), "crisis", "default starts a crisis")
	ok(int(EconomyDepth.st(c)["default_turn"]) == int(s["turn"]), "the default is remembered")
	ok(EconomyDepth.credit_score(s, cid) < 62.0, "and hurts creditworthiness")

func test_crises_lower_and_booms_raise_income() -> void:
	var s := new_state()
	var cid := _country(s)
	var c: Dictionary = s["countries"][cid]
	var inc0 := float(EconomySystem.budget(s, cid)["income"])
	c["temp_mods"].append({"mods": EconomyDepth._phase_mods("crisis"), "until": int(s["turn"]) + 1, "key": "eco_crisis"})
	Mods.invalidate(s)
	EconomySystem.invalidate_calc(s)
	var inc_c := float(EconomySystem.budget(s, cid)["income"])
	c["temp_mods"] = [{"mods": EconomyDepth._phase_mods("boom"), "until": int(s["turn"]) + 1, "key": "eco_boom"}]
	Mods.invalidate(s)
	EconomySystem.invalidate_calc(s)
	var inc_b := float(EconomySystem.budget(s, cid)["income"])
	ok(inc_c < inc0 and inc_b > inc0, "crisis %.0f < normal %.0f < boom %.0f" % [inc_c, inc0, inc_b])

func test_shortage_slows_industry() -> void:
	var s := new_state()
	var cid := _country(s)
	var c: Dictionary = s["countries"][cid]
	var pid: String = GS.owned(s, cid)[0]
	s["provinces"][pid]["buildings"]["factory"] = 2
	c["stock"]["coal"] = 0.0
	EconomySystem.invalidate_calc(s)
	c["budget"] = EconomySystem.budget(s, cid)
	EconomyDepth._shortages(s, cid, c, EconomyDepth.st(c))
	ok(EconomyDepth.st(c)["shortage"].has("coal"), "a coal shortage is detected")
	var has := false
	for tm in c["temp_mods"]:
		if tm["key"] == "shortage" and float(tm["mods"].get("prod", 0.0)) < 0.0:
			has = true
	ok(has, "and slows production")

func test_market_has_history_and_reacts_to_demand() -> void:
	var s := new_state()
	run_turns(s, 4)
	ok((s["market"]["iron"]["hist"] as Array).size() >= 3, "price history is kept")
	var p0 := float(s["market"]["coal"]["price"])
	for i in 6:
		TradeSystem.update_market(s, {"coal": 0.0}, {"coal": 400.0})
	ok(float(s["market"]["coal"]["price"]) > p0, "scarcity raises prices")

func test_trade_never_creates_money() -> void:
	var s := new_state()
	for a in GS.alive_countries(s):
		for b in GS.alive_countries(s):
			if a < b and DiplomacySystem.borders(s, a, b):
				GS.rel(s, a, b)["trade"] = true
	TradeSystem.invalidate(s)
	var t := TradeSystem.compute(s)
	ok(float(t["paid"]) <= float(t["commerce"]) + 0.001, "payouts %.1f never exceed commerce %.1f" % [float(t["paid"]), float(t["commerce"])])

func test_world_gold_growth_is_bounded() -> void:
	var s := new_state("early_modern", "", "normal", 31)
	s["players"] = []
	var w0 := 0.0
	var cum_income := 0.0
	for cid in GS.alive_countries(s):
		w0 += float(s["countries"][cid]["gold"]) - float(s["countries"][cid]["debt"])
	var f0 := float(s["econ"]["forgiven"])
	for t in 40:
		TurnManager.end_turn(s)
		var gwp := 0.0
		var inc := 0.0
		for pid in s["provinces"]:
			if s["provinces"][pid]["owner"] != "":
				var pc := EconomySystem.province_calc(s, pid)
				gwp += float(pc["tax"]) + float(pc["production"]) + float(pc["commerce"])
		for cid in GS.alive_countries(s):
			var b: Dictionary = s["countries"][cid].get("budget", {})
			inc += float(b.get("income", 0.0))
			gwp += float(b.get("export", 0.0))
		cum_income += inc
		ok(inc <= gwp * 1.02 + 5.0, "turn %d: world income %.0f within gross product %.0f" % [t, inc, gwp])
	var w1 := 0.0
	for cid in GS.alive_countries(s):
		w1 += float(s["countries"][cid]["gold"]) - float(s["countries"][cid]["debt"])
	var gain := w1 - w0
	ok(gain <= cum_income + (float(s["econ"]["forgiven"]) - f0) + 1.0, "world net worth grew by %.0f, bounded by income %.0f" % [gain, cum_income])
	ok(w1 < w0 + cum_income * 0.9 + 1000.0, "and expenses really leave the system")

func test_ai_manages_debt_without_cheating() -> void:
	var s := new_state("early_modern", "", "normal", 32)
	s["players"] = []
	run_turns(s, 40)
	for cid in GS.alive_countries(s):
		var c: Dictionary = s["countries"][cid]
		ok(float(c["gold"]) > -1.0, "%s treasury not negative" % cid)
		ok(float(c["debt"]) < 20000.0, "%s debt bounded" % cid)
