extends TestCase
## Internal politics: factions, demands, corruption, government mechanics, transitions, coups, civil wars, independence.

func _big(s: Dictionary, min_p: int = 8) -> String:
	var best := ""
	var bn := 0
	for cid in GS.alive_countries(s):
		var c: Dictionary = s["countries"][cid]
		if not bool(c.get("native", false)) and GS.owned(s, cid).size() > bn and GS.vassals_of(s, cid).is_empty():
			bn = GS.owned(s, cid).size()
			best = cid
	return best if bn >= min_p else ""

func _settle(s: Dictionary, cid: String) -> void:
	# one politics pass so that influence and loyalty are computed
	PoliticsSystem.process_turn(s, cid)

func test_every_country_has_six_factions() -> void:
	var s := new_state()
	for cid in GS.alive_countries(s):
		var fs := FactionsSystem.st(s["countries"][cid])
		for fid in FactionsSystem.FACTIONS:
			ok(fs["f"].has(fid), "%s has faction %s" % [cid, fid])
	eq(FactionsSystem.FACTIONS.size(), 6, "six factions")

func test_influence_sums_to_one_and_loyalty_is_bounded() -> void:
	var s := new_state()
	run_turns(s, 5)
	for cid in GS.alive_countries(s):
		var c: Dictionary = s["countries"][cid]
		if bool(c.get("native", false)):
			continue
		var tot := 0.0
		for fid in FactionsSystem.FACTIONS:
			var f: Dictionary = FactionsSystem.st(c)["f"][fid]
			tot += float(f["inf"])
			ok(float(f["loy"]) >= 0.0 and float(f["loy"]) <= 100.0, "%s loyalty bounded" % cid)
		near(tot, 1.0, 0.06, "%s influence normalised" % cid)

func test_government_shapes_influence() -> void:
	var s := new_state()
	var cid := _big(s, 3)
	var c: Dictionary = s["countries"][cid]
	var inf := {}
	for gov in ["merchant_republic", "military_government", "theocracy", "feudal_kingdom"]:
		c["gov"] = gov
		Mods.invalidate(s)
		for i in 25:
			PoliticsSystem.process_turn(s, cid)
		inf[gov] = {"merchants": FactionsSystem.influence(c, "merchants"), "military": FactionsSystem.influence(c, "military"),
			"clergy": FactionsSystem.influence(c, "clergy"), "nobility": FactionsSystem.influence(c, "nobility")}
	ok(inf["merchant_republic"]["merchants"] > inf["feudal_kingdom"]["merchants"], "merchant republics empower merchants")
	ok(inf["military_government"]["military"] > inf["theocracy"]["military"], "juntas empower the army")
	ok(inf["theocracy"]["clergy"] > inf["merchant_republic"]["clergy"], "theocracies empower the clergy")
	ok(inf["feudal_kingdom"]["nobility"] > inf["merchant_republic"]["nobility"], "feudal kingdoms empower the nobility")

func test_nine_governments_are_mechanically_distinct() -> void:
	var mechs := {}
	var caps := {}
	for gid in Const.GOV_IDS:
		var pol: Dictionary = Defs.governments[gid].get("politics", {})
		ok(not pol.is_empty(), "%s has politics rules" % gid)
		mechs[pol["mech"]] = true
		caps[pol["tax_cap"]] = true
		ok(Loc.has_key("GOV_MECH_" + str(pol["mech"]).to_upper()), "%s mechanic is described" % gid)
	eq(mechs.size(), 9, "nine different mechanics")
	ok(caps.size() >= 5, "different tax tolerances (%d)" % caps.size())
	ok(float(Defs.governments["feudal_kingdom"]["politics"]["civil"]) > float(Defs.governments["constitutional_monarchy"]["politics"]["civil"]), "feudal realms split more easily")
	ok(float(Defs.governments["military_government"]["politics"]["coup"]) > float(Defs.governments["theocracy"]["politics"]["coup"]), "juntas fear coups more")
	ok(float(Defs.governments["merchant_republic"]["politics"]["land_cap"]) < float(Defs.governments["empire"]["politics"]["land_cap"]), "merchant republics govern little land")

func test_every_mechanic_runs() -> void:
	var s := new_state()
	var cid := _big(s, 3)
	var c: Dictionary = s["countries"][cid]
	for gid in Const.GOV_IDS:
		c["gov"] = gid
		Mods.invalidate(s)
		for i in 6:
			PoliticsSystem.process_turn(s, cid)
		ok(Saves.validate_state(s).is_empty(), "state valid under %s" % gid)

func test_tax_cap_binds_the_budget() -> void:
	var s := new_state()
	var cid := _big(s, 3)
	var c: Dictionary = s["countries"][cid]
	c["gov"] = "absolute_monarchy"
	c["tax_rate"] = 0.55
	EconomySystem.invalidate_calc(s)
	Mods.invalidate(s)
	var t_abs := float(EconomySystem.budget(s, cid)["tax"])
	c["gov"] = "constitutional_monarchy"
	EconomySystem.invalidate_calc(s)
	Mods.invalidate(s)
	var t_con := float(EconomySystem.budget(s, cid)["tax"])
	ok(FactionsSystem.tax_cap(c) < 0.55, "a parliament caps taxes")
	ok(t_con < t_abs, "the cap lowers the effective tax (%.1f vs %.1f)" % [t_con, t_abs])
	# exceeding the cap angers the privileged orders
	c["tax_rate"] = 0.55
	var before := FactionsSystem.loyalty(c, "merchants")
	FactionsSystem._enforce_tax_cap(s, cid, c)
	ok(FactionsSystem.loyalty(c, "merchants") < before, "loyalty falls above the cap")

func test_demands_arise_and_can_be_granted_or_ignored() -> void:
	var s := new_state()
	var cid := _big(s, 3)
	var c: Dictionary = s["countries"][cid]
	var fs := FactionsSystem.st(c)
	var rng := GS.rng_of(s)
	for fid in ["nobility", "merchants", "military", "popular"]:
		fs["f"][fid]["loy"] = 20.0
		fs["f"][fid]["inf"] = 0.3
	FactionsSystem._issue_demands(s, cid, c, rng)
	var n := 0
	var target := ""
	for fid in FactionsSystem.FACTIONS:
		if fs["f"][fid]["dem"] != null:
			n += 1
			target = fid
	ok(n >= 3, "several unhappy powerful factions make demands (%d)" % n)
	# gold demands can be bought
	fs["f"][target]["dem"] = {"type": "gold", "value": 1.0, "until": int(s["turn"]) + 5}
	c["gold"] = 5000.0
	var g0 := float(c["gold"])
	var l0 := FactionsSystem.loyalty(c, target)
	ok(FactionsSystem.concede(s, cid, target)["ok"], "granted")
	ok(float(c["gold"]) < g0, "it costs gold")
	ok(FactionsSystem.loyalty(c, target) > l0, "loyalty rises")
	# an ignored demand makes things worse
	fs["f"][target]["dem"] = {"type": "gold", "value": 1.0, "until": int(s["turn"]) - 1}
	var l1 := FactionsSystem.loyalty(c, target)
	FactionsSystem._process_demands(s, cid, c)
	ok(FactionsSystem.loyalty(c, target) < l1, "ignoring a demand angers the faction")
	ok(int(fs["f"][target]["unmet"]) >= 1, "and it is remembered")

func test_policy_demand_is_met_by_policy() -> void:
	var s := new_state()
	var cid := _big(s, 3)
	var c: Dictionary = s["countries"][cid]
	var fs := FactionsSystem.st(c)
	c["tax_rate"] = 0.40
	fs["f"]["nobility"]["dem"] = {"type": "tax_cap", "value": 0.30, "until": int(s["turn"]) + 8}
	ok(not FactionsSystem.demand_met(c, fs["f"]["nobility"]["dem"]), "not met at 40 %")
	c["tax_rate"] = 0.28
	var l0 := FactionsSystem.loyalty(c, "nobility")
	FactionsSystem._process_demands(s, cid, c)
	ok(fs["f"]["nobility"]["dem"] == null, "met automatically by the policy")
	ok(FactionsSystem.loyalty(c, "nobility") > l0, "and rewarded")

func test_suppression_has_a_price() -> void:
	var s := new_state()
	var cid := _big(s, 3)
	var c: Dictionary = s["countries"][cid]
	c["admin"] = 100.0
	var stab := float(c["stability"])
	var inf := FactionsSystem.influence(c, "nobility")
	ok(FactionsSystem.suppress(s, cid, "nobility")["ok"], "suppressed")
	ok(float(c["stability"]) < stab, "stability falls")
	ok(FactionsSystem.influence(c, "nobility") < inf, "the faction loses influence")
	eq(FactionsSystem.suppress(s, cid, "court")["reason"], "FAC_ERR_SUPPRESS_COURT", "the court cannot be suppressed")

func test_corruption_grows_with_size_and_costs_tax() -> void:
	var s := new_state()
	var big := _big(s, 5)
	var small := ""
	for cid in GS.alive_countries(s):
		if not bool(s["countries"][cid].get("native", false)) and GS.owned(s, cid).size() <= 3 and GS.owned(s, cid).size() >= 1:
			small = cid
			break
	if small != "":
		s["countries"][small]["gov"] = s["countries"][big]["gov"]
		ok(FactionsSystem.corruption_target(s, big, s["countries"][big]) > FactionsSystem.corruption_target(s, small, s["countries"][small]), "bigger realms are more corrupt")
	var c: Dictionary = s["countries"][big]
	FactionsSystem.st(c)["corr"] = 70.0
	var low := FactionsSystem.tax_factor(c)
	FactionsSystem.st(c)["corr"] = 5.0
	var high := FactionsSystem.tax_factor(c)
	ok(low < high, "corruption cuts the tax take (%.2f vs %.2f)" % [low, high])
	FactionsSystem.st(c)["corr"] = 50.0
	c["admin"] = 100.0
	c["gold"] = 500.0
	ok(FactionsSystem.fight_corruption(s, big)["ok"], "anti-corruption drive")
	near(float(FactionsSystem.st(c)["corr"]), 40.0, 0.01, "it lowers corruption by ten points")
	eq(FactionsSystem.fight_corruption(s, big)["reason"], "FAC_ERR_COOLDOWN", "but not twice in a row")
	FactionsSystem.st(c)["corr"] = 50.0
	var t_low_adm := FactionsSystem.corruption_target(s, big, c)
	TechSystem.grant(s, big, "bureaucracy_3")
	Mods.invalidate(s)
	ok(FactionsSystem.corruption_target(s, big, c) < t_low_adm, "bureaucracy fights corruption")

func test_government_change_has_consequences() -> void:
	var s := new_state()
	var cid := ""
	for c0 in GS.alive_countries(s):
		var opts := PoliticsSystem.government_options(s, c0)
		for o in opts:
			if o["ok"]:
				cid = c0
		if cid != "":
			break
	if cid == "":
		cid = _big(s, 3)
		s["countries"][cid]["gov"] = "absolute_monarchy"
		s["countries"][cid]["admin"] = 500.0
		for k in s["countries"][cid]["tech_level"].keys():
			s["countries"][cid]["tech_level"][k] = 3
	var c: Dictionary = s["countries"][cid]
	c["admin"] = 500.0
	var opts2 := PoliticsSystem.government_options(s, cid)
	var to := ""
	for o in opts2:
		if o["ok"]:
			to = o["to"]
	ok(to != "", "some transition is available")
	var leg := float(c["legitimacy"])
	var stab := float(c["stability"])
	var loy := {}
	for fid in FactionsSystem.FACTIONS:
		loy[fid] = FactionsSystem.loyalty(c, fid)
	var old_gov := str(c["gov"])
	var r := PoliticsSystem.change_government(s, cid, to)
	ok(r["ok"], "changed")
	ok(FactionsSystem.in_transition(c), "a transition period begins")
	ok(float(c["stability"]) < stab, "stability shock")
	var moved := 0
	for fid in FactionsSystem.FACTIONS:
		if absf(FactionsSystem.loyalty(c, fid) - float(loy[fid])) > 2.0:
			moved += 1
	ok(moved >= 3, "factions react (%d moved)" % moved)
	var again := PoliticsSystem.government_options(s, cid)
	for o in again:
		ok(not o["ok"], "no second change during the transition")
	for i in 14:
		s["turn"] = int(s["turn"]) + 1
		PoliticsSystem.process_turn(s, cid)
	ok(not FactionsSystem.in_transition(c), "the transition ends (%s -> %s)" % [old_gov, to])

func test_reforms_shift_faction_loyalty() -> void:
	var s := new_state()
	var cid := _big(s, 3)
	var c: Dictionary = s["countries"][cid]
	c["gov"] = "feudal_kingdom"
	c["admin"] = 500.0
	c["gold"] = 5000.0
	TechSystem.grant(s, cid, "legal_reform_1")
	var l0 := FactionsSystem.loyalty(c, "nobility")
	ok(PoliticsSystem.adopt_reform(s, cid, "estates_general")["ok"], "Estates General adopted")
	ok(FactionsSystem.loyalty(c, "nobility") > l0, "the nobility approves")
	ok(Defs.reforms.size() >= 24, "government-specific reforms exist")

func test_coup_needs_military_discontent() -> void:
	var s := new_state()
	var cid := _big(s, 3)
	var c: Dictionary = s["countries"][cid]
	var fs := FactionsSystem.st(c)
	c["stability"] = 70.0
	c["legitimacy"] = 70.0
	fs["f"]["military"]["loy"] = 80.0
	eq(FactionsSystem.coup_chance(s, cid, c), 0.0, "a loyal army makes no coup")
	c["stability"] = 25.0
	fs["f"]["military"]["loy"] = 10.0
	fs["f"]["military"]["inf"] = 0.35
	ok(FactionsSystem.coup_chance(s, cid, c) > 0.0, "a discontented powerful army might")
	c["gov"] = "military_government"
	var mil := FactionsSystem.coup_chance(s, cid, c)
	c["gov"] = "theocracy"
	ok(mil > FactionsSystem.coup_chance(s, cid, c), "juntas are more coup-prone")
	var ruler0 := str(c["ruler"]["name"])
	FactionsSystem.coup(s, cid, GS.rng_of(s))
	ok(str(c["ruler"]["name"]) != ruler0, "a coup replaces the ruler")
	ok(FactionsSystem.loyalty(c, "military") > 40.0, "the army is rewarded")
	ok(FactionsSystem.coup_chance(s, cid, c) == 0.0, "and a second coup must wait")

func test_faction_uprising_spawns_rebels() -> void:
	var s := new_state()
	var cid := _big(s, 3)
	var c: Dictionary = s["countries"][cid]
	var n0 := GS.armies_of(s, "REB").size()
	FactionsSystem._faction_uprising(s, cid, c, "popular", GS.rng_of(s))
	ok(GS.armies_of(s, "REB").size() > n0, "rebels appear in the existing REB pseudo-country")

func test_civil_war_splits_the_country() -> void:
	var s := new_state("early_modern", "", "normal", 5)
	s["players"] = []
	var cid := _big(s, 8)
	var c: Dictionary = s["countries"][cid]
	var n_before := GS.owned(s, cid).size()
	var gold := float(c["gold"])
	var debt := float(c["debt"])
	var countries0: int = s["countries"].size()
	var tag := CivilWar.start(s, cid, "faction", "military", "", GS.rng_of(s))
	ok(tag != "", "a civil war breaks out")
	eq(s["countries"].size(), countries0 + 1, "a new country exists")
	var rb: Dictionary = s["countries"][tag]
	var n_parent := GS.owned(s, cid).size()
	var n_rebel := GS.owned(s, tag).size()
	eq(n_parent + n_rebel, n_before, "provinces are conserved")
	ok(n_rebel >= 2 and n_parent >= 3, "a real split (%d / %d)" % [n_parent, n_rebel])
	near(float(c["gold"]) + float(rb["gold"]), gold, 0.01, "gold is conserved, not created")
	near(float(c["debt"]) + float(rb["debt"]), debt, 0.01, "debt is shared")
	ok(GS.at_war(s, cid, tag), "the halves are at war")
	ok(str(rb["gov"]) == "military_government", "the military faction forms a junta")
	ok(not GS.owned(s, tag).has(c["capital"]), "the capital stays loyal")
	ok(rb["ruler"]["name"] != "", "the rebels have their own leader")
	ok(s["ai"].has(tag), "AI state exists")
	ok(Saves.validate_state(s).is_empty(), "state is valid: %s" % str(Saves.validate_state(s).slice(0, 3)))
	ok(not CivilWar.can_start(s, cid), "a country cannot split again immediately")
	run_turns(s, 6)
	ok(Saves.validate_state(s).is_empty(), "the war runs without breaking the state")

func test_succession_civil_war_keeps_the_government() -> void:
	var s := new_state("early_modern", "", "normal", 6)
	s["players"] = []
	var cid := _big(s, 8)
	var gov := str(s["countries"][cid]["gov"])
	var tag := CivilWar.start(s, cid, "succession", "nobility", "Pretender", GS.rng_of(s))
	ok(tag != "", "started")
	eq(str(s["countries"][tag]["gov"]), gov, "a pretender fights for the same throne")
	eq(str(s["countries"][tag]["ruler"]["name"]), "Pretender", "named leader")

func test_independence_movement_grows_and_frees_a_province() -> void:
	var s := new_state("early_modern", "", "normal", 7)
	s["players"] = []
	var cid := _big(s, 6)
	var c: Dictionary = s["countries"][cid]
	var pid := ""
	for q in GS.owned(s, cid):
		if q != c["capital"]:
			pid = q
	var p: Dictionary = s["provinces"][pid]
	p["culture"] = "african" if c["culture"] != "african" else "latin"
	p["religion"] = "animist" if c["religion"] != "animist" else "catholic"
	p["unrest"] = 80.0
	c["stability"] = 30.0
	var g := CivilWar.movement_growth(s, cid, pid)
	ok(float(g["total"]) > 1.0, "foreign, unhappy provinces drift towards independence (%.1f)" % float(g["total"]))
	FactionsSystem.st(c)["move"][pid] = 99.5
	var n0 := GS.owned(s, cid).size()
	CivilWar.process_turn(s, cid, GS.rng_of(s))
	ok(GS.owned(s, cid).size() < n0, "the province broke away")
	var found := false
	for oid in s["countries"]:
		if str(s["countries"][oid].get("parent", "")) == cid:
			found = true
			ok(GS.at_war(s, oid, cid), "the new state is at war with its former master")
	ok(found, "a new country was born")
	# a garrisoned, content core province does not
	var g2 := CivilWar.movement_growth(s, cid, str(GS.owned(s, cid)[0]))
	ok(float(g2["total"]) <= 0.5, "ordinary core provinces stay quiet")

func test_vassal_independence() -> void:
	var s := new_state("early_modern", "", "normal", 8)
	var p := neighbour_pair(s, 1)
	var over: String = p[0]
	var vas: String = p[1]
	DiplomacySystem.make_vassal(s, over, vas, false)
	s["countries"][vas]["vassal_since"] = -100
	GS.add_opinion(s, vas, over, -190.0)
	var revolted := false
	for i in 600:
		s["turn"] = 2 * (i + 1)
		CivilWar._vassal_independence(s, vas, GS.rng_of(s))
		if GS.overlord_of(s, vas) == "":
			revolted = true
			break
	ok(revolted, "a despised vassal eventually rises")
	ok(GS.at_war(s, vas, over), "against its overlord")

func test_rebel_held_province_becomes_a_state() -> void:
	var s := new_state("early_modern", "", "normal", 9)
	s["players"] = []
	var cid := _big(s, 5)
	var c: Dictionary = s["countries"][cid]
	var pid := ""
	for q in GS.owned(s, cid):
		if q != c["capital"]:
			pid = q
	var p: Dictionary = s["provinces"][pid]
	p["controller"] = "REB"
	var aid := MilitarySystem.spawn_rebels(s, pid, 3.0)
	GS.rebuild_caches(s)
	s["turn"] = 10
	CivilWar.process_rebel_holds(s, GS.rng_of(s))
	s["turn"] = 20
	var before: int = s["countries"].size()
	CivilWar.process_rebel_holds(s, GS.rng_of(s))
	eq(s["countries"].size(), before + 1, "rebels that hold ground for long found a state")
	ok(aid != "", "rebel army existed")

func test_court_events_exist_and_work() -> void:
	var n := 0
	for eid in Defs.events:
		if str(eid) in ["court_scandal", "noble_conspiracy", "bread_riots", "regency_intrigue", "transition_unrest", "army_grumbles", "merchant_petition", "clergy_sermons", "court_favourite"]:
			n += 1
			ok(Defs.events[eid]["options"].size() >= 2, "%s has real choices" % eid)
	eq(n, 9, "nine court events")
	var s := new_state()
	var cid := _big(s, 3)
	var c: Dictionary = s["countries"][cid]
	FactionsSystem.st(c)["corr"] = 60.0
	ok(EventSystem._cond(s, cid, c, {"type": "corruption_above", "value": 35}), "corruption condition")
	FactionsSystem.st(c)["f"]["clergy"]["loy"] = 10.0
	ok(EventSystem._cond(s, cid, c, {"type": "faction_loyalty_below", "faction": "clergy", "value": 30}), "loyalty condition")
	var entry := {"id": "x", "cid": cid, "pid": "", "other": "", "uid": "u"}
	EventSystem.apply_effect(s, entry, {"type": "faction_loyalty", "faction": "clergy", "value": 15})
	near(FactionsSystem.loyalty(c, "clergy"), 25.0, 0.01, "event effect changes loyalty")
	EventSystem.apply_effect(s, entry, {"type": "corruption", "value": -20})
	near(FactionsSystem.corruption(c), 40.0, 0.01, "event effect changes corruption")

func test_hundred_turns_of_politics_stay_valid() -> void:
	var s := new_state("early_modern", "", "normal", 21)
	s["players"] = []
	run_turns(s, 100)
	var civil := 0
	for cid in s["countries"]:
		if str(s["countries"][cid].get("parent", "")) != "":
			civil += 1
	ok(Saves.validate_state(s).is_empty(), "state valid: %s" % str(Saves.validate_state(s).slice(0, 3)))
	ok(civil >= 0, "splits so far: %d" % civil)
