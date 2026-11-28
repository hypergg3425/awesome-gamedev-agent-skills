extends TestCase
## Workstream E battle model: factor report, determinism, rivers, passes, weather, composition, discipline,
## doctrine, commanders (death / capture), movement and supply effects of rivers and passes.

const FACTOR_KEYS := ["FACTOR_NUMBERS", "FACTOR_GENERAL", "FACTOR_TERRAIN", "FACTOR_FORT", "FACTOR_RIVER", "FACTOR_PASS", "FACTOR_WEATHER",
	"FACTOR_DISCIPLINE", "FACTOR_EXPERIENCE", "FACTOR_TECH", "FACTOR_DOCTRINE", "FACTOR_SUPPLY", "FACTOR_COMPOSITION", "FACTOR_AMPHIB", "FACTOR_MORALE", "FACTOR_LUCK"]

func _arena() -> Dictionary:
	_restore()
	var s := new_state()
	for cid in ["AAA", "DDD"]:
		var c: Dictionary = (s["countries"][GS.alive_countries(s)[0]] as Dictionary).duplicate(true)
		c["id"] = cid
		c["alive"] = true
		c["flags"] = {}
		c["doctrine"] = {"land": "", "naval": "", "since": {"land": -99, "naval": -99}}
		s["countries"][cid] = c
	return s

## A plains province b and a neighbour a (so that an army can arrive at b from a).
func _pair(terrain: String = "plains") -> Array:
	for pid in Defs.province_ids:
		if Defs.provinces[pid]["terrain"] == terrain and not Defs.provinces[pid]["archipelago"]:
			for nb in Defs.neighbors(pid):
				return [nb, pid]
	return [Defs.province_ids[0], Defs.province_ids[1]]

func _clash(s: Dictionary, a_prov: String, b_prov: String, au: Dictionary, du: Dictionary, seed_v: int, arrived: bool = true, adj: Dictionary = {}, ddj: Dictionary = {}) -> Dictionary:
	s["_c"]["rng"] = GameRng.new(seed_v)
	var aid := MilitarySystem.create_army(s, "AAA", b_prov, au, {"name": "A", "tac": 5, "log": 5, "siege": 5, "xp": 0.0, "traits": []})
	var did := MilitarySystem.create_army(s, "DDD", b_prov, du, {"name": "D", "tac": 5, "log": 5, "siege": 5, "xp": 0.0, "traits": []})
	s["armies"][aid]["prev_loc"] = a_prov
	s["armies"][aid]["arrived"] = int(s["turn"]) if arrived else -1
	for k in adj:
		s["armies"][aid][k] = adj[k]
	for k in ddj:
		s["armies"][did][k] = ddj[k]
	var rep := Combat.resolve(s, b_prov, [aid], [did])
	MilitarySystem.disband_army(s, aid)
	MilitarySystem.disband_army(s, did)
	return rep

func _mod(rep: Dictionary, key: String) -> Dictionary:
	for f in rep["modifiers"]:
		if f["key"] == key:
			return f
	return {}

func _avg_ratio(s: Dictionary, a_prov: String, b_prov: String, au: Dictionary, du: Dictionary, n: int, arrived: bool = true, adj: Dictionary = {}, ddj: Dictionary = {}) -> float:
	var tot := 0.0
	for i in n:
		var r := _clash(s, a_prov, b_prov, au, du, 500 + i, arrived, adj, ddj)
		tot += float(r["loss_a"]) / maxf(float(r["loss_d"]), 0.01)
	return tot / float(n)

func _restore() -> void:
	GeoFeatures.load_dir(GeoFeatures.map_dir())

func test_report_lists_every_factor_with_en_and_tr_labels() -> void:
	var s := _arena()
	var p := _pair()
	var rep := _clash(s, p[0], p[1], {"spearmen": 8.0, "archers": 3.0}, {"spearmen": 8.0, "archers": 3.0}, 11)
	for k in FACTOR_KEYS:
		ok(not _mod(rep, k).is_empty(), "report has factor %s" % k)
		ok(Loc.has_lang(k, "en") and Loc.has_lang(k, "tr"), "%s has EN and TR labels" % k)
		ok(Loc.t(k) != k, "%s resolves" % k)
	for f in rep["modifiers"]:
		ok(["power", "protect", "inc", "info"].has(f["kind"]), "factor kind valid for %s" % f["key"])
		if f["kind"] != "info":
			ok(is_finite(BattleFactors.contribution_pct(f, "a")) and is_finite(BattleFactors.contribution_pct(f, "d")), "numeric contribution %s" % f["key"])
	ok(rep["factors"].size() == rep["modifiers"].size(), "legacy table mirrors modifiers")
	ok(rep.has("commanders") and rep["commanders"]["a"].has("name"), "commanders listed")

func test_deterministic_for_a_seed_and_varied_between_seeds() -> void:
	var s := _arena()
	var p := _pair()
	var r1 := _clash(s, p[0], p[1], {"spearmen": 10.0}, {"spearmen": 9.0}, 77)
	var r2 := _clash(s, p[0], p[1], {"spearmen": 10.0}, {"spearmen": 9.0}, 77)
	var r3 := _clash(s, p[0], p[1], {"spearmen": 10.0}, {"spearmen": 9.0}, 78)
	eq(JSON.stringify(r1["modifiers"]), JSON.stringify(r2["modifiers"]), "same seed: identical factors")
	near(float(r1["loss_a"]), float(r2["loss_a"]), 0.00001, "same seed: identical losses")
	ok(absf(float(r1["loss_a"]) - float(r3["loss_a"])) > 0.0001, "different seed: different casualties")
	var luck1 := _mod(r1, "FACTOR_LUCK")
	ok(float(luck1["a"]) != float(_mod(r3, "FACTOR_LUCK")["a"]), "luck factor is seeded")

func test_river_crossing_penalises_the_attacker() -> void:
	var s := _arena()
	var p := _pair()
	GeoFeatures.set_data({"rivers": [[p[0], p[1], {"name": "Test River", "width": 2}]]})
	var rep := _clash(s, p[0], p[1], {"spearmen": 8.0}, {"spearmen": 8.0}, 5)
	var f := _mod(rep, "FACTOR_RIVER")
	ok(float(f["a"]) < 1.0, "attacker power reduced (%.3f)" % float(f["a"]))
	ok(float(f["d"]) < 1.0, "defender protected")
	eq(rep["river"]["name"], "Test River", "report names the river")
	near(float(rep["river"]["share"]), 1.0, 0.001, "all attackers crossed")
	var with_river := _avg_ratio(s, p[0], p[1], {"spearmen": 8.0}, {"spearmen": 8.0}, 30)
	GeoFeatures.set_data({})
	var without := _avg_ratio(s, p[0], p[1], {"spearmen": 8.0}, {"spearmen": 8.0}, 30)
	ok(with_river > without * 1.05, "attacker loss ratio worse across a river (%.2f vs %.2f)" % [with_river, without])
	# an army that was already standing in the province did not cross
	GeoFeatures.set_data({"rivers": [[p[0], p[1], {"name": "Test River", "width": 2}]]})
	var stay := _clash(s, p[0], p[1], {"spearmen": 8.0}, {"spearmen": 8.0}, 5, false)
	near(float(_mod(stay, "FACTOR_RIVER")["a"]), 1.0, 0.0001, "no penalty without a crossing this turn")
	_restore()

func test_bridges_and_pontoon_engineers_reduce_the_river_penalty() -> void:
	var s := _arena()
	var p := _pair()
	GeoFeatures.set_data({"rivers": [[p[0], p[1], {"name": "R", "width": 3}]]})
	var plain := float(_mod(_clash(s, p[0], p[1], {"spearmen": 8.0}, {"spearmen": 8.0}, 5), "FACTOR_RIVER")["a"])
	s["provinces"][p[1]]["buildings"]["bridge"] = 1
	var bridged := float(_mod(_clash(s, p[0], p[1], {"spearmen": 8.0}, {"spearmen": 8.0}, 5), "FACTOR_RIVER")["a"])
	s["provinces"][p[1]]["buildings"].erase("bridge")
	var pont := float(_mod(_clash(s, p[0], p[1], {"spearmen": 5.0, "pontonniers": 3.0}, {"spearmen": 8.0}, 5), "FACTOR_RIVER")["a"])
	ok(bridged > plain, "bridge helps (%.3f > %.3f)" % [bridged, plain])
	ok(pont > plain, "pontoon engineers help (%.3f > %.3f)" % [pont, plain])
	ok(plain > 0.7, "penalty stays bounded")
	_restore()

func test_mountain_pass_protects_defender_and_narrows_the_front() -> void:
	var s := _arena()
	var p := _pair("hills")
	GeoFeatures.set_data({"passes": [[p[0], p[1], {"name": "Test Pass"}]]})
	var rep := _clash(s, p[0], p[1], {"spearmen": 12.0}, {"spearmen": 12.0}, 9)
	var f := _mod(rep, "FACTOR_PASS")
	ok(float(f["d"]) < 1.0, "defender casualties reduced (%.3f)" % float(f["d"]))
	eq(rep["pass"]["name"], "Test Pass", "report names the pass")
	GeoFeatures.set_data({})
	var open := _clash(s, p[0], p[1], {"spearmen": 12.0}, {"spearmen": 12.0}, 9)
	ok(float(rep["width"]) < float(open["width"]), "narrower combat front in a pass")
	near(float(_mod(open, "FACTOR_PASS")["d"]), 1.0, 0.0001, "no pass, no bonus")
	_restore()

func test_weather_season_and_mud() -> void:
	var s := _arena()
	var p := _pair("plains")
	var north := ""
	for pid in Defs.province_ids:
		if Defs.provinces[pid]["terrain"] in ["plains", "forest"] and float(Defs.provinces[pid]["lat"]) > 45.0:
			north = pid
			break
	if north == "":
		return
	s["start_month"] = 7   # summer
	s["turn"] = 0
	var summer := Combat.weather_for(s, north)
	s["start_month"] = 12   # winter
	var winter := Combat.weather_for(s, north)
	s["start_month"] = 3   # spring thaw
	var spring := Combat.weather_for(s, north)
	ok(float(winter["attack"]) < float(summer["attack"]), "winter weakens attackers")
	ok(float(winter["attrition"]) > float(summer["attrition"]), "winter attrition")
	ok(float(spring["mud"]) > 0.0 and float(summer["mud"]) == 0.0, "spring mud only")
	ok(float(spring["move"]) < float(summer["move"]), "mud slows marching")
	var rep := _clash(s, p[0], north, {"light_cavalry": 6.0, "cannons": 2.0}, {"light_cavalry": 6.0, "cannons": 2.0}, 3)
	ok(float(_mod(rep, "FACTOR_WEATHER")["d"]) < 1.0, "mud cuts horse and gun effectiveness")

func test_composition_counters() -> void:
	var s := _arena()
	var p := _pair("plains")
	var vs_pike := float(_mod(_clash(s, p[0], p[1], {"knights": 8.0}, {"pikemen": 8.0}, 4), "FACTOR_COMPOSITION")["a"])
	var vs_arch := float(_mod(_clash(s, p[0], p[1], {"knights": 8.0}, {"archers": 8.0}, 4), "FACTOR_COMPOSITION")["a"])
	ok(vs_pike < 1.0 and vs_arch > 1.0, "heavy cavalry loses to pikes, beats archers (%.2f / %.2f)" % [vs_pike, vs_arch])
	var art := float(_mod(_clash(s, p[0], p[1], {"cannons": 6.0}, {"pikemen": 8.0}, 4), "FACTOR_COMPOSITION")["a"])
	ok(art > 1.0, "artillery punishes dense pike blocks")
	var pike_d := float(_mod(_clash(s, p[0], p[1], {"knights": 8.0}, {"pikemen": 8.0}, 4), "FACTOR_COMPOSITION")["d"])
	ok(pike_d > 1.0, "pikes are strong against cavalry")

func test_discipline_experience_and_supply_matter() -> void:
	var s := _arena()
	var p := _pair("plains")
	var u := {"spearmen": 8.0}
	var hi := _avg_ratio(s, p[0], p[1], u, u, 25, true, {"discipline": 90.0, "xp": 60.0})
	var lo := _avg_ratio(s, p[0], p[1], u, u, 25, true, {"discipline": 20.0, "xp": 0.0})
	ok(hi < lo, "drilled veterans suffer less (%.2f vs %.2f)" % [hi, lo])
	var starving := _avg_ratio(s, p[0], p[1], u, u, 25, true, {"supply": 0.4})
	ok(starving > lo * 0.5 and starving > hi, "starving attackers do worse (%.2f)" % starving)
	var rep := _clash(s, p[0], p[1], u, u, 2, true, {"discipline": 90.0, "xp": 60.0}, {"discipline": 20.0})
	ok(float(_mod(rep, "FACTOR_DISCIPLINE")["a"]) > float(_mod(rep, "FACTOR_DISCIPLINE")["d"]), "report shows the discipline gap")
	ok(float(_mod(rep, "FACTOR_EXPERIENCE")["a"]) > 1.0, "report shows experience")

func test_doctrine_appears_in_the_report() -> void:
	var s := _arena()
	var p := _pair("plains")
	s["countries"]["AAA"]["doctrine"]["land"] = "linear_firepower"
	Mods.invalidate(s)
	var rep := _clash(s, p[0], p[1], {"musketeers": 8.0}, {"musketeers": 8.0}, 6)
	ok(float(_mod(rep, "FACTOR_DOCTRINE")["a"]) > 1.05, "doctrine contributes (%.3f)" % float(_mod(rep, "FACTOR_DOCTRINE")["a"]))
	near(float(_mod(rep, "FACTOR_DOCTRINE")["d"]), 1.0, 0.0001, "the other side has none")
	ok(float(_mod(rep, "FACTOR_DISCIPLINE")["a"]) > float(_mod(rep, "FACTOR_DISCIPLINE")["d"]), "doctrine drill shows as discipline")

func test_commander_traits_move_the_result() -> void:
	var s := _arena()
	var p := _pair("plains")
	s["_c"]["rng"] = GameRng.new(1)
	var aid := MilitarySystem.create_army(s, "AAA", p[1], {"spearmen": 8.0}, {"name": "G", "tac": 5, "log": 5, "siege": 5, "xp": 0.0, "traits": ["aggressive", "brilliant"]})
	var did := MilitarySystem.create_army(s, "DDD", p[1], {"spearmen": 8.0}, {"name": "H", "tac": 5, "log": 5, "siege": 5, "xp": 0.0, "traits": ["incompetent"]})
	var rep := Combat.resolve(s, p[1], [aid], [did])
	ok(float(_mod(rep, "FACTOR_GENERAL")["a"]) > float(_mod(rep, "FACTOR_GENERAL")["d"]) + 0.15, "traits show in the general factor")
	ok("brilliant" in rep["commanders"]["a"]["traits"], "traits in the report")
	near(Commanders.eff_tac(s["armies"][did]["general"], "plains"), 3.0, 0.001, "incompetent -2 tactics")

func test_generals_can_die_or_be_captured_and_are_replaced() -> void:
	var s := _arena()
	var p := _pair("plains")
	var died := 0
	var captured := 0
	var promoted := 0
	for i in 150:
		s["_c"]["rng"] = GameRng.new(900 + i)
		var l := MilitarySystem.create_army(s, "AAA", p[1], {"spearmen": 5.0}, {"name": "L", "tac": 4, "log": 4, "siege": 4, "xp": 0.0, "traits": []})
		var w := MilitarySystem.create_army(s, "DDD", p[1], {"spearmen": 5.0}, {"name": "W", "tac": 4, "log": 4, "siege": 4, "xp": 36.0, "traits": []})
		for ev in Commanders.after_battle(s, [w], [l], true, {"winner": "defender", "loss_a": 3.0, "loss_d": 1.0}):
			match ev["kind"]:
				"died":
					died += 1
				"captured":
					captured += 1
				"promoted":
					promoted += 1
		MilitarySystem.disband_army(s, l)
		MilitarySystem.disband_army(s, w)
	ok(died >= 8 and died <= 60, "some beaten generals die (%d of 150)" % died)
	ok(captured >= 4, "some are captured (%d)" % captured)
	ok(promoted >= 1, "winners are promoted (%d)" % promoted)
	# captured commanders are ransomed: the captor is richer, the loser poorer
	var g0 := float(s["countries"]["DDD"]["gold"])
	var l2 := MilitarySystem.create_army(s, "AAA", p[1], {"spearmen": 5.0}, {"name": "L", "tac": 6, "log": 6, "siege": 6, "xp": 0.0, "traits": []})
	var w2 := MilitarySystem.create_army(s, "DDD", p[1], {"spearmen": 5.0}, null)
	s["countries"]["AAA"]["gold"] = 500.0
	Commanders._ransom(s, s["armies"][l2], s["armies"][l2]["general"], [w2])
	ok(float(s["countries"]["DDD"]["gold"]) > g0 and float(s["countries"]["AAA"]["gold"]) < 500.0, "ransom moves gold from loser to captor")
	# replacement of a missing commander on friendly ground
	var home := ""
	for pid in GS.owned(s, "AAA"):
		home = pid
	s["armies"][l2]["general"] = null
	s["armies"][l2]["general_wait"] = -1
	s["armies"][l2]["units"]["spearmen"] = 8.0
	s["provinces"][p[1]]["controller"] = "AAA"
	s["countries"]["AAA"]["gold"] = 300.0
	Commanders.assign_missing(s, "AAA")
	ok(s["armies"][l2]["general"] != null, "a new commander is appointed (%s)" % home)

func test_rivers_and_passes_cost_movement() -> void:
	var s := _arena()
	var p := _pair("plains")
	var aid := MilitarySystem.create_army(s, "AAA", p[0], {"spearmen": 4.0}, null)
	var a: Dictionary = s["armies"][aid]
	GeoFeatures.set_data({})
	var base := MilitarySystem.move_cost(s, a, p[1], "land", p[0])
	GeoFeatures.set_data({"rivers": [[p[0], p[1], {"width": 3}]]})
	var wet := MilitarySystem.move_cost(s, a, p[1], "land", p[0])
	ok(wet > base + 1.0, "fording a great river costs movement (%.2f vs %.2f)" % [wet, base])
	s["provinces"][p[1]]["buildings"]["bridge"] = 1
	var bridged := MilitarySystem.move_cost(s, a, p[1], "land", p[0])
	ok(bridged < wet and bridged > base, "a bridge cheapens the crossing")
	s["provinces"][p[1]]["buildings"].erase("bridge")
	GeoFeatures.set_data({"passes": [[p[0], p[1], {"name": "P"}]]})
	var small := MilitarySystem.move_cost(s, a, p[1], "land", p[0])
	a["units"]["spearmen"] = 20.0
	var big := MilitarySystem.move_cost(s, a, p[1], "land", p[0])
	ok(small > base and big > small, "passes slow big armies more (%.2f / %.2f / %.2f)" % [base, small, big])
	var n0 := UnitUtil.army_size(a)
	MilitarySystem._cross_effects(s, a, p[0], p[1])
	ok(UnitUtil.army_size(a) < n0, "an oversized army loses men in a pass")
	_restore()

func test_rivers_and_passes_thin_supply_lines() -> void:
	var s := _arena()
	var p := _pair("plains")
	for nb in Defs.neighbors(p[1]):
		s["provinces"][nb]["controller"] = "AAA"
	GeoFeatures.set_data({})
	var open_cap := MilitarySystem.supply_cap(s, "AAA", p[1])
	var rivers: Array = []
	for nb in Defs.neighbors(p[1]):
		rivers.append([p[1], nb, {"width": 2}])
	GeoFeatures.set_data({"rivers": rivers})
	var river_cap := MilitarySystem.supply_cap(s, "AAA", p[1])
	var passes: Array = []
	for nb in Defs.neighbors(p[1]):
		passes.append([p[1], nb, {}])
	GeoFeatures.set_data({"passes": passes})
	var pass_cap := MilitarySystem.supply_cap(s, "AAA", p[1])
	ok(river_cap < open_cap and pass_cap < open_cap, "rivers and passes thin the supply line (%.2f / %.2f / %.2f)" % [open_cap, river_cap, pass_cap])
	_restore()

func test_discipline_maintenance_and_reinforcement_dilution() -> void:
	var s := _arena()
	var p := _pair("plains")
	s["provinces"][p[1]]["owner"] = "AAA"
	s["provinces"][p[1]]["controller"] = "AAA"
	GS.rebuild_caches(s)
	var aid := MilitarySystem.create_army(s, "AAA", p[1], {"spearmen": 6.0}, null)
	var a: Dictionary = s["armies"][aid]
	a["discipline"] = 40.0
	s["countries"]["AAA"]["army_funding"] = 1.0
	MilitarySystem.process_supply(s)
	ok(float(a["discipline"]) > 40.0, "drill on friendly ground raises discipline")
	s["countries"]["AAA"]["army_funding"] = 0.4
	var d0 := float(a["discipline"])
	MilitarySystem.process_supply(s)
	ok(float(a["discipline"]) < d0 + 0.01, "underfunded troops lose discipline")
	# new regiments dilute experience and drill
	s["countries"]["AAA"]["army_funding"] = 1.0
	a["xp"] = 40.0
	a["discipline"] = 80.0
	a["units"]["spearmen"] = 3.0
	s["countries"]["AAA"]["manpower"] = 50.0
	s["countries"]["AAA"]["gold"] = 800.0
	MilitarySystem.reinforce(s, a, s["countries"]["AAA"], 0.5)
	ok(float(a["xp"]) < 40.0 and float(a["discipline"]) < 80.0, "reinforcements dilute veterancy (xp %.1f, disc %.1f)" % [float(a["xp"]), float(a["discipline"])])

func test_unit_upgrade_chain() -> void:
	var s := _arena()
	var p := _pair("plains")
	s["provinces"][p[1]]["controller"] = "AAA"
	s["countries"]["AAA"]["tech_level"]["infantry_tactics"] = 2
	var aid := MilitarySystem.create_army(s, "AAA", p[1], {"spearmen": 4.0}, null)
	s["countries"]["AAA"]["gold"] = 500.0
	for k in s["countries"]["AAA"]["stock"]:
		s["countries"]["AAA"]["stock"][k] = 50.0
	eq(UnitUtil.upgrade_of(s, "AAA", "spearmen"), "pikemen", "next unit in the chain")
	var r := MilitarySystem.upgrade_units(s, aid, "spearmen")
	ok(r["ok"], "upgrade succeeds: %s" % str(r))
	near(float(s["armies"][aid]["units"].get("pikemen", 0.0)), 4.0, 0.001, "regiments converted")
	ok(not s["armies"][aid]["units"].has("spearmen"), "old type gone")
	ok(float(s["countries"]["AAA"]["gold"]) < 500.0, "costs gold")
	var poor := MilitarySystem.upgrade_units(s, aid, "pikemen")
	ok(not poor["ok"] or UnitUtil.upgrade_of(s, "AAA", "pikemen") != "", "chain respects tech")

func test_new_units_are_era_gated_and_base_set_preserved() -> void:
	var s := _arena()
	var base := ["spearmen", "pikemen", "musketeers", "line_infantry", "riflemen", "men_at_arms", "halberdiers", "grenadiers", "guard_infantry", "archers",
		"crossbowmen", "skirmishers", "sharpshooters", "light_cavalry", "hussars", "lancers", "mounted_rifles", "knights", "gendarmes", "cuirassiers",
		"bombards", "cannons", "field_guns", "rifled_artillery", "sappers", "field_engineers", "cog", "galley", "carrack", "galleon", "ship_of_the_line",
		"ironclad", "janissaries", "mamluks", "samurai", "longbowmen", "landsknechts", "tercios", "swiss_pikemen", "cossacks", "horse_archers", "war_elephants", "hoplites_phalanx"]
	for uid in base:
		ok(Defs.units.has(uid), "base unit %s preserved" % uid)
	ok(Defs.units.size() >= 55, "extra units added (%d)" % Defs.units.size())
	s["start_year"] = 1066
	s["turn"] = 0
	s["countries"]["AAA"]["special_units"] = ["housecarls"]
	ok(UnitUtil.is_available(s, "AAA", "housecarls"), "housecarls exist in 1066")
	s["start_year"] = 1500
	ok(not UnitUtil.is_available(s, "AAA", "housecarls"), "housecarls are gone by 1500")
	s["start_year"] = 1066
	ok(not UnitUtil.is_available(s, "AAA", "frigate"), "frigates need technology")
	s["start_year"] = 1500
	s["countries"]["AAA"]["tech_level"]["naval_warfare"] = 3
	ok(not UnitUtil.is_available(s, "AAA", "frigate"), "frigates did not exist in 1500")
	s["start_year"] = 1750
	s["countries"]["AAA"]["researched"]["naval_warfare_3"] = true
	ok(UnitUtil.is_available(s, "AAA", "frigate"), "frigates with naval technology and in the era")
	s["start_year"] = 1600
	ok(not UnitUtil.is_available(s, "AAA", "steam_cruiser"), "steam cruisers need industry as well")
