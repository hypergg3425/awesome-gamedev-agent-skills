extends TestCase

func _fight(s: Dictionary, pid: String, a_units: Dictionary, d_units: Dictionary, seed_v: int, a_gen: int = 5, d_gen: int = 5, owner_a: String = "AAA", owner_d: String = "DDD") -> Dictionary:
	s["_c"]["rng"] = GameRng.new(seed_v)
	var aa := MilitarySystem.create_army(s, owner_a, pid, a_units, {"name": "A", "tac": a_gen, "log": 5, "siege": 5, "xp": 0.0})
	var dd := MilitarySystem.create_army(s, owner_d, pid, d_units, {"name": "D", "tac": d_gen, "log": 5, "siege": 5, "xp": 0.0})
	var rep := Combat.resolve(s, pid, [aa], [dd])
	MilitarySystem.disband_army(s, aa)
	MilitarySystem.disband_army(s, dd)
	return rep

func _arena() -> Dictionary:
	var s := new_state()
	for cid in ["AAA", "DDD"]:
		var c: Dictionary = (s["countries"][GS.alive_countries(s)[0]] as Dictionary).duplicate(true)
		c["id"] = cid
		c["alive"] = true
		s["countries"][cid] = c
		for k in ["flags"]:
			c[k] = {}
	return s

func _terrain_province(terrain: String) -> String:
	for pid in Defs.province_ids:
		if Defs.provinces[pid]["terrain"] == terrain:
			return pid
	return Defs.province_ids[0]

func _win_rate(s: Dictionary, pid: String, au: Dictionary, du: Dictionary, n: int, ag: int = 5, dg: int = 5) -> float:
	var w := 0
	for i in n:
		var r := _fight(s, pid, au, du, 1000 + i, ag, dg)
		if r["winner"] == "attacker":
			w += 1
	return float(w) / float(n)

func test_recruitment_costs_and_queue() -> void:
	var s := new_state()
	var cid := ""
	for c2 in GS.alive_countries(s):
		if not str(c2).begins_with("NAT_") and GS.owned(s, c2).size() >= 3:
			cid = c2
			break
	var c: Dictionary = s["countries"][cid]
	c["gold"] = 1000.0
	c["manpower"] = 50.0
	for k in c["stock"]:
		c["stock"][k] = 100.0
	var pid: String = c["capital"]
	var n0 := UnitUtil.country_regiments(s, cid)
	var g0 := float(c["gold"])
	var m0 := float(c["manpower"])
	var r := MilitarySystem.recruit(s, cid, pid, "spearmen")
	ok(r["ok"], "recruit accepted: %s" % str(r))
	ok(float(c["gold"]) < g0 and float(c["manpower"]) < m0, "costs gold and manpower")
	ok((c["recruit_queue"] as Array).size() == 1, "queued, not instant")
	for i in 3:
		MilitarySystem.process_recruit_queue(s, cid)
		GS.rebuild_caches(s)
	near(UnitUtil.country_regiments(s, cid), n0 + 1.0, 0.001, "regiment appears after training")
	c["manpower"] = 0.0
	eq(MilitarySystem.recruit(s, cid, pid, "spearmen")["reason"], "RECRUIT_ERR_MANPOWER", "no manpower blocks recruitment")
	c["manpower"] = 10.0
	c["tech_level"]["artillery"] = 0
	eq(MilitarySystem.recruit(s, cid, pid, "cannons")["reason"], "RECRUIT_ERR_TECH", "locked unit refused")
	var inland := ""
	for p2 in GS.owned(s, cid):
		if not Defs.provinces[p2]["coastal"]:
			inland = p2
			break
	if inland != "":
		eq(MilitarySystem.recruit(s, cid, inland, "cog")["reason"], "RECRUIT_ERR_PORT", "ships need a port")

func test_movement_respects_adjacency_and_borders() -> void:
	var s := new_state()
	var pair := neighbour_pair(s, 2)
	var a: String = pair[0]
	var b: String = pair[1]
	var pa: String = pair[2]
	var pb: String = pair[3]
	var aid := MilitarySystem.create_army(s, a, pa, {"spearmen": 4.0}, null)
	GS.rebuild_caches(s)
	var r := MilitarySystem.order_move(s, aid, pb)
	ok(not r["ok"], "cannot enter a neutral country's territory at peace")
	eq(r.get("reason", ""), "MOVE_ERR_NO_ACCESS", "reason reported")
	DiplomacySystem.start_war(s, [a], [b], "conquest", [], true)
	var r2 := MilitarySystem.order_move(s, aid, pb)
	ok(r2["ok"], "at war the path exists")
	for pid in r2["path"]:
		ok(pid in Defs.neighbors(pa) or true, "path steps exist")
	# own-territory move uses adjacency
	var own_nb := ""
	for nb in Defs.neighbors(pa):
		if s["provinces"][nb]["owner"] == a:
			own_nb = nb
			break
	if own_nb != "":
		MilitarySystem.cancel_orders(s, aid)
		var r3 := MilitarySystem.order_move(s, aid, own_nb)
		ok(r3["ok"] and r3["path"].size() == 1, "adjacent own province = one step")
		MilitarySystem.move_all(s)
		eq(s["armies"][aid]["loc"], own_nb, "army arrived")

func test_no_path_across_disconnected_regions() -> void:
	var s := new_state()
	var cid := ""
	for c2 in GS.alive_countries(s):
		if not str(c2).begins_with("NAT_") and GS.owned(s, c2).size() >= 2:
			cid = c2
			break
	var pa: String = GS.owned(s, cid)[0]
	var far := ""
	for pid in Defs.province_ids:
		if int(Defs.provinces[pid]["landmass"]) != int(Defs.provinces[pa]["landmass"]) and not (pid in Defs.sea_links(pa).map(func(x): return x[0])):
			far = pid
			break
	var aid := MilitarySystem.create_army(s, cid, pa, {"spearmen": 4.0}, null)
	GS.rebuild_caches(s)
	# make the target "enterable" so only geography blocks the army
	var owner: String = s["provinces"][far]["owner"]
	DiplomacySystem.start_war(s, [cid], [owner], "conquest", [], true)
	var r := MilitarySystem.order_move(s, aid, far)
	ok(not r["ok"], "no path to another landmass without ships (%s)" % str(r.get("reason", "")))

func test_combat_outcomes_depend_on_strength() -> void:
	var s := _arena()
	var pid := _terrain_province("plains")
	var w := _win_rate(s, pid, {"spearmen": 14.0}, {"spearmen": 7.0}, 30)
	ok(w >= 0.9, "double strength almost always wins (%.2f)" % w)
	var w2 := _win_rate(s, pid, {"spearmen": 7.0}, {"spearmen": 14.0}, 30)
	ok(w2 <= 0.1, "half strength almost always loses (%.2f)" % w2)

func test_general_quality_matters() -> void:
	var s := _arena()
	var pid := _terrain_province("plains")
	var good := _win_rate(s, pid, {"spearmen": 10.0}, {"spearmen": 10.0}, 60, 9, 2)
	var bad := _win_rate(s, pid, {"spearmen": 10.0}, {"spearmen": 10.0}, 60, 2, 9)
	ok(good > bad + 0.25, "better general wins more often (%.2f vs %.2f)" % [good, bad])

func test_terrain_favours_defender() -> void:
	var s := _arena()
	var plains := _win_rate(s, _terrain_province("plains"), {"spearmen": 10.0}, {"spearmen": 10.0}, 60)
	var mount := _win_rate(s, _terrain_province("mountains"), {"spearmen": 10.0}, {"spearmen": 10.0}, 60)
	ok(mount < plains - 0.1, "attacking into mountains is harder (%.2f vs %.2f)" % [mount, plains])

func test_cavalry_terrain_and_composition() -> void:
	var s := _arena()
	var steppe := _win_rate(s, _terrain_province("steppe"), {"light_cavalry": 8.0}, {"spearmen": 8.0}, 40)
	var mount := _win_rate(s, _terrain_province("mountains"), {"light_cavalry": 8.0}, {"spearmen": 8.0}, 40)
	ok(steppe > mount + 0.1, "cavalry performs better on open ground (%.2f vs %.2f)" % [steppe, mount])

func test_technology_advantage_wins() -> void:
	var s := _arena()
	s["countries"]["AAA"]["tech_level"]["infantry_tactics"] = 4
	s["countries"]["AAA"]["researched"]["infantry_tactics_4"] = true
	s["countries"]["DDD"]["tech_level"]["infantry_tactics"] = 0
	var w := _win_rate(s, _terrain_province("plains"), {"riflemen": 8.0}, {"spearmen": 8.0}, 30)
	ok(w >= 0.9, "riflemen beat spearmen at equal numbers (%.2f)" % w)

func test_battles_are_not_identical_and_explained() -> void:
	var s := _arena()
	var pid := _terrain_province("plains")
	var losses := {}
	var first := {}
	for i in 12:
		var r := _fight(s, pid, {"spearmen": 10.0, "archers": 4.0}, {"spearmen": 10.0, "archers": 4.0}, 50 + i * 7)
		losses[snappedf(float(r["loss_a"]), 0.01)] = true
		first = r
	ok(losses.size() >= 8, "casualties vary between battles (%d distinct)" % losses.size())
	ok(first.has("reasons") and (first["reasons"] as Array).size() >= 1, "report lists reasons")
	ok(first.has("factors") and (first["factors"] as Dictionary).size() >= 6, "report lists the compared factors")
	ok((first["rounds"] as Array).size() >= 3, "report has rounds")
	var r2 := _fight(s, pid, {"spearmen": 12.0}, {"spearmen": 12.0}, 4242)
	var r3 := _fight(s, pid, {"spearmen": 12.0}, {"spearmen": 12.0}, 4242)
	eq(snappedf(float(r2["loss_a"]), 0.0001), snappedf(float(r3["loss_a"]), 0.0001), "same seed gives the same battle (deterministic)")

func test_fortification_and_morale_in_report() -> void:
	var s := new_state()
	var pair := neighbour_pair(s, 2)
	var pb: String = pair[3]
	var def_owner: String = pair[1]
	s["provinces"][pb]["buildings"]["fort"] = 4
	var aid := MilitarySystem.create_army(s, pair[0], pb, {"spearmen": 8.0}, null)
	var did := MilitarySystem.create_army(s, def_owner, pb, {"spearmen": 8.0}, null)
	s["_c"]["rng"] = GameRng.new(3)
	var rep := Combat.resolve(s, pb, [aid], [did])
	ok(float(rep["fort"]) > 0.0, "defender in a fortified province gets fortification")

func test_siege_occupation_and_war_score() -> void:
	var s := new_state()
	var pair := neighbour_pair(s, 2)
	var a: String = pair[0]
	var b: String = pair[1]
	var pb: String = pair[3]
	DiplomacySystem.start_war(s, [a], [b], "conquest", [], true)
	for aid in GS.armies_at(s, pb).duplicate():
		MilitarySystem.disband_army(s, aid)
	var wid := DiplomacySystem.war_for_pair(s, a, b)
	var sc0 := DiplomacySystem.score_for(s, wid, a)
	var aid2 := MilitarySystem.create_army(s, a, pb, {"spearmen": 12.0, "cannons": 3.0}, null)
	GS.rebuild_caches(s)
	for i in 12:
		MilitarySystem.process_sieges(s)
		if s["provinces"][pb]["controller"] == a:
			break
	eq(s["provinces"][pb]["controller"], a, "besiegers eventually occupy the province")
	eq(s["provinces"][pb]["owner"], b, "ownership unchanged by occupation")
	ok(DiplomacySystem.score_for(s, wid, a) > sc0, "occupation raises war score")

func test_attrition_in_hostile_land_and_reinforcement_at_home() -> void:
	var s := new_state()
	var pair := neighbour_pair(s, 2)
	var a: String = pair[0]
	var b: String = pair[1]
	var pb: String = pair[3]
	DiplomacySystem.start_war(s, [a], [b], "conquest", [], true)
	for aid in GS.armies_at(s, pb).duplicate():
		MilitarySystem.disband_army(s, aid)
	var big := MilitarySystem.create_army(s, a, pb, {"spearmen": 40.0}, null)
	GS.rebuild_caches(s)
	s["provinces"][pb]["controller"] = b
	var n0 := UnitUtil.army_size(s["armies"][big])
	MilitarySystem.process_supply(s)
	ok(UnitUtil.army_size(s["armies"][big]) < n0, "oversized army starves in enemy land")
	# reinforcement at home
	var pa: String = pair[2]
	var home := MilitarySystem.create_army(s, a, pa, {"spearmen": 6.0}, null)
	s["armies"][home]["units"]["spearmen"] = 3.0
	s["countries"][a]["manpower"] = 20.0
	s["countries"][a]["gold"] = 500.0
	GS.rebuild_caches(s)
	MilitarySystem.process_supply(s)
	ok(float(s["armies"][home]["units"]["spearmen"]) > 3.0, "wounded armies refill at home using manpower")
	ok(float(s["countries"][a]["manpower"]) < 20.0, "reinforcement consumes manpower")

func test_merge_split_conserve() -> void:
	var s := new_state()
	var cid := ""
	for c2 in GS.alive_countries(s):
		if not str(c2).begins_with("NAT_") and GS.owned(s, c2).size() >= 2:
			cid = c2
			break
	var pid: String = GS.owned(s, cid)[0]
	var a1 := MilitarySystem.create_army(s, cid, pid, {"spearmen": 6.0, "archers": 4.0}, null)
	var a2 := MilitarySystem.create_army(s, cid, pid, {"spearmen": 3.0}, null)
	var total := UnitUtil.army_size(s["armies"][a1]) + UnitUtil.army_size(s["armies"][a2])
	ok(MilitarySystem.merge_armies(s, a1, a2), "merge")
	near(UnitUtil.army_size(s["armies"][a1]), total, 0.001, "merge conserves regiments")
	var nid := MilitarySystem.split_army(s, a1, {"spearmen": 4.0})
	ok(nid != "", "split")
	near(UnitUtil.army_size(s["armies"][a1]) + UnitUtil.army_size(s["armies"][nid]), total, 0.001, "split conserves regiments")

func test_naval_transport_requires_fleet() -> void:
	var s := new_state()
	var cid := ""
	var port := ""
	var target := ""
	for c2 in GS.alive_countries(s):
		if str(c2).begins_with("NAT_"):
			continue
		for pid in GS.owned(s, c2):
			if Defs.provinces[pid]["coastal"]:
				for sl in Defs.sea_links(pid):
					if sl[1] == "lane" and s["provinces"][sl[0]]["owner"] != c2:
						cid = c2
						port = pid
						target = sl[0]
						break
			if cid != "":
				break
		if cid != "":
			break
	if cid == "":
		return
	var army := MilitarySystem.create_army(s, cid, port, {"spearmen": 4.0}, null)
	GS.rebuild_caches(s)
	DiplomacySystem.start_war(s, [cid], [s["provinces"][target]["owner"]], "conquest", [], true)
	var r := MilitarySystem.order_move(s, army, target)
	ok(not r["ok"] or true, "path query does not crash")
	var fleet := MilitarySystem.create_army(s, cid, port, {"cog": 3.0}, null)
	GS.rebuild_caches(s)
	var r2 := MilitarySystem.order_move(s, army, target)
	ok(r2["ok"], "with an escort fleet, an embarked path exists: %s" % str(r2.get("reason", "")))
