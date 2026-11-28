extends TestCase
## Extended event effects / conditions (EventExt), plain-text consequence lines and dialog illustration mapping.

func _entry(cid: String, other: String = "", pid: String = "") -> Dictionary:
	return {"uid": "t2", "id": "none", "cid": cid, "pid": pid, "other": other, "turn": 0}

func _fx(s: Dictionary, entry: Dictionary, fx: Dictionary) -> void:
	EventSystem.apply_effect(s, entry, fx)

func _valid(s: Dictionary, msg: String) -> void:
	var errs := Saves.validate_state(s)
	ok(errs.is_empty(), "%s leaves a valid state %s" % [msg, str(errs.slice(0, 2))])

func test_transfer_province_give_and_take() -> void:
	var s := new_state()
	var pair := neighbour_pair(s, 3)
	ok(pair.size() == 4, "fixture pair")
	var a: String = pair[0]
	var b: String = pair[1]
	var na := GS.owned(s, a).size()
	var nb := GS.owned(s, b).size()
	_fx(s, _entry(a, b), {"type": "transfer_province", "direction": "give", "target": "other"})
	eq(GS.owned(s, a).size(), na - 1, "giver loses a province")
	eq(GS.owned(s, b).size(), nb + 1, "receiver gains it")
	ok(s["provinces"][s["countries"][a]["capital"]]["owner"] == a, "capital is never given away")
	_valid(s, "give")
	var s2 := new_state()
	var pair2 := neighbour_pair(s2, 3)
	var c: String = pair2[0]
	var d: String = pair2[1]
	var nc := GS.owned(s2, c).size()
	for q in GS.owned(s2, d):
		if q != pair2[3]:
			s2["countries"][d]["capital"] = q
			break
	_fx(s2, _entry(c, d), {"type": "transfer_province", "direction": "take", "target": "other", "core": true})
	eq(GS.owned(s2, c).size(), nc + 1, "taker gains a province")
	_valid(s2, "take")

func test_vassal_effects() -> void:
	var s := new_state()
	var cid := ""
	for c in GS.alive_countries(s):
		if not str(c).begins_with("NAT_") and GS.owned(s, c).size() >= 6 and GS.vassals_of(s, c).is_empty() and GS.overlord_of(s, c) == "":
			cid = c
			break
	ok(cid != "", "a large country")
	var n := GS.owned(s, cid).size()
	_fx(s, _entry(cid), {"type": "create_vassal"})
	eq(GS.vassals_of(s, cid).size(), 1, "a vassal state was created")
	eq(GS.owned(s, cid).size(), n - 1, "it took one province")
	var v: String = GS.vassals_of(s, cid)[0]
	ok(GS.overlord_of(s, v) == cid and s["countries"][v]["alive"], "overlord set, vassal alive")
	_valid(s, "create_vassal")
	run_turns(s, 2)
	ok(true, "state keeps running after the new country exists")
	var s2 := new_state()
	var pair := neighbour_pair(s2, 1)
	_fx(s2, _entry(pair[0], pair[1]), {"type": "vassalize", "target": "other"})
	eq(GS.overlord_of(s2, pair[1]), pair[0], "other becomes a vassal")
	_valid(s2, "vassalize")

func test_military_effects() -> void:
	var s := new_state()
	var cid: String = s["player"]
	var armies_before := GS.armies_of(s, cid).size()
	var reg := UnitUtil.country_regiments(s, cid)
	_fx(s, _entry(cid), {"type": "spawn_army", "class": "infantry", "n": 4})
	eq(GS.armies_of(s, cid).size(), armies_before + 1, "a new army")
	near(UnitUtil.country_regiments(s, cid), reg + 4.0, 0.01, "of the requested size")
	var aid: String = GS.armies_of(s, cid)[-1]
	ok(s["armies"][aid]["general"] != null, "with a commander")
	for a in GS.armies_of(s, cid):
		s["armies"][a]["general"] = null
	_fx(s, _entry(cid), {"type": "spawn_general", "mil": 8, "trait": "brilliant"})
	var have := 0
	for a in GS.armies_of(s, cid):
		if s["armies"][a]["general"] != null:
			have += 1
			ok(int(s["armies"][a]["general"]["tac"]) >= 8, "general is skilled")
	eq(have, 1, "exactly one army got the general")
	var coastal := ""
	for c in GS.alive_countries(s):
		if not str(c).begins_with("NAT_") and Defs.provinces[s["countries"][c]["capital"]].get("coastal", false):
			coastal = c
			break
	var nav := UnitUtil.country_regiments(s, coastal, true)
	_fx(s, _entry(coastal), {"type": "spawn_fleet", "n": 2})
	near(UnitUtil.country_regiments(s, coastal, true), nav + 2.0, 0.01, "fleet raised")
	_valid(s, "military effects")

func test_dynasty_and_espionage_effects() -> void:
	var s := new_state()
	var cid := ""
	for c in GS.alive_countries(s):
		if not str(c).begins_with("NAT_") and DynastySystem.is_hereditary(s["countries"][c]):
			cid = c
			break
	var c: Dictionary = s["countries"][cid]
	var royals := (DynastySystem.st(c)["royals"] as Array).size()
	_fx(s, _entry(cid), {"type": "add_royal"})
	eq((DynastySystem.st(c)["royals"] as Array).size(), royals + 1, "royal added")
	c["ruler"]["health"] = 50.0
	_fx(s, _entry(cid), {"type": "ruler_health", "value": 30})
	near(float(c["ruler"]["health"]), 80.0, 0.01, "ruler health")
	_fx(s, _entry(cid), {"type": "ruler_health", "value": 100})
	near(float(c["ruler"]["health"]), 100.0, 0.01, "health clamped")
	if c.get("heir") != null:
		var hid := int(c["heir"]["id"])
		var before := int(DynastySystem.royal_by_id(c, hid)["mil"])
		_fx(s, _entry(cid), {"type": "heir_skill", "skill": "mil", "value": 1})
		eq(int(DynastySystem.royal_by_id(c, hid)["mil"]), mini(9, before + 1), "heir skill")
	var ci := EspionageSystem.ci_level(s, cid)
	_fx(s, _entry(cid), {"type": "ci_level", "value": 2})
	eq(EspionageSystem.ci_level(s, cid), mini(EspionageSystem.MAX_LEVEL, ci + 2), "counter-intel raised")
	_fx(s, _entry(cid), {"type": "ci_level", "value": -20})
	eq(EspionageSystem.ci_level(s, cid), 0, "counter-intel floors at 0")
	var other: String = neighbour_pair(s)[1] if cid == "" else ""
	for o in GS.alive_countries(s):
		if o != cid and not str(o).begins_with("NAT_"):
			other = o
			break
	_fx(s, _entry(cid, other), {"type": "spy_network", "target": "other", "value": 2})
	eq(EspionageSystem.level(s, cid, other), 2, "spy network built")
	_fx(s, _entry(cid, other), {"type": "spy_network", "target": "other", "value": -5})
	eq(EspionageSystem.level(s, cid, other), 0, "and removed")
	_valid(s, "dynasty/espionage effects")

func test_economy_government_civil_war_alliance() -> void:
	var s := new_state()
	var pair := neighbour_pair(s, 1)
	var cid: String = pair[0]
	var other: String = pair[1]
	var c: Dictionary = s["countries"][cid]
	_fx(s, _entry(cid), {"type": "eco_phase", "phase": "boom", "turns": 5})
	eq(EconomyDepth.st(c)["phase"], "boom", "economy phase")
	ok(EventSystem._cond(s, cid, {"type": "eco_phase_is", "phase": "boom"}, {"type": "eco_phase_is", "phase": "boom"}), "eco_phase_is condition")
	c["gov"] = "absolute_monarchy"
	c["flags"] = c["flags"]
	_fx(s, _entry(cid), {"type": "force_government", "to": "constitutional_monarchy"})
	eq(str(c["gov"]), "constitutional_monarchy", "government forced without tech")
	_fx(s, _entry(cid, other), {"type": "alliance", "target": "other"})
	ok(GS.allied(s, cid, other), "alliance formed")
	var pid: String = GS.owned(s, cid)[0]
	_fx(s, _entry(cid, "", pid), {"type": "add_core"})
	ok(cid in s["provinces"][pid]["cores"], "core added")
	_valid(s, "economy/government/alliance")
	# civil war needs size
	var s2 := new_state()
	var big := ""
	for k in GS.alive_countries(s2):
		if not str(k).begins_with("NAT_") and CivilWar.can_start(s2, k):
			big = k
			break
	var wars: int = s2["wars"].size()
	_fx(s2, _entry(big), {"type": "civil_war", "faction": "military"})
	ok(s2["wars"].size() == wars + 1 and s2["countries"][big].has("civil_war"), "civil war started")
	_valid(s2, "civil war")

func test_conditions() -> void:
	var s := new_state()
	var cid: String = s["player"]
	ok(EventExt.cond(s, cid, "ci_level_at_least", {"value": 0}), "ci >= 0")
	ok(not EventExt.cond(s, cid, "ci_level_at_least", {"value": 4}), "ci < 4")
	ok(EventExt.cond(s, cid, "royals_below", {"value": 99}), "royals_below")
	ok(not EventExt.cond(s, cid, "vassals_at_least", {"value": 99}), "not 99 vassals")
	ok(EventExt.cond(s, cid, "faction_loyalty_between", {"faction": "nobility", "min": 0, "max": 100}), "loyalty in range")
	for t in EventExt.NEW_COND_TYPES:
		EventExt.cond(s, cid, t, {"value": 1})
	ok(true, "all new conditions evaluate")

func test_descriptions_and_tone() -> void:
	Loc.lang = "en"
	for t in EventExt.NEW_EFFECT_TYPES:
		ok(Loc.strings.has("EVFX_" + t), "EVFX key for " + t)
	for ex in [{"type": "gold", "value": -60}, {"type": "stock", "res": "iron", "value": 5}, {"type": "class_sat", "class": "clergy", "value": 4},
			{"type": "temp_mod", "mods": {"trade": 0.06}, "turns": 10}, {"type": "force_government", "to": "republic"}, {"type": "add_regiments", "unit": "pikemen", "n": 3},
			{"type": "faction_loyalty", "faction": "court", "value": -4}]:
		var line := EventExt.describe(ex)
		ok(line != "" and not "{" in line, "described: " + line)
	eq(EventExt.describe({"type": "gold", "value": -60}), "Gold -60", "signed value text")
	eq(EventExt.describe({"type": "stability", "value": 3}), "Stability +3", "positive sign")
	eq(EventExt.describe({"type": "set_flag", "flag": "x"}), "", "flags are not shown")
	eq(EventExt.tone({"type": "gold", "value": -5}), -1, "losing gold is bad")
	eq(EventExt.tone({"type": "debt", "value": 5}), -1, "more debt is bad")
	eq(EventExt.tone({"type": "inflation", "value": -0.02}), 1, "less inflation is good")
	eq(EventExt.tone({"type": "spawn_army"}), 1, "an army is good")
	Loc.lang = "tr"
	eq(EventExt.describe({"type": "gold", "value": -60}), "Altın -60", "Turkish text")
	Loc.lang = "en"

func test_every_event_option_is_describable() -> void:
	var empty := 0
	for id in Defs.events:
		for o in Defs.events[id]["options"]:
			if EventExt.describe_option(o).is_empty():
				empty += 1
	eq(empty, 0, "every option has at least one visible consequence line")
	for id in Defs.events:
		for o in Defs.events[id]["options"]:
			for fx in o["effects"]:
				var t := str(fx["type"])
				ok(t in EventSystem.KNOWN_EFFECTS or t in EventExt.NEW_EFFECT_TYPES, "%s effect %s is implemented" % [id, t])

func test_illustrations_map_to_real_art() -> void:
	var missing := 0
	for id in Defs.events:
		var p := EventDialog.image_path(Defs.events[id])
		if p == "" or not ResourceLoader.exists(p):
			missing += 1
	eq(missing, 0, "every event resolves to an illustration")
	ok(EventDialog.image_path({"image": "siege"}).ends_with("ev_battle.png"), "siege falls back to battle art")
	ok(EventDialog.image_path({"category": "food"}).ends_with("ev_famine.png"), "category default")

func test_new_events_present_and_labelled() -> void:
	var hist := 0
	var rnd := 0
	for id in Defs.events:
		var e: Dictionary = Defs.events[id]
		if str(id).begins_with("g_"):
			rnd += 1
			ok(not e["historical"] and not e.has("source"), "%s is labelled random" % id)
		if e.get("historical", false) and e.has("reference"):
			hist += 1
			var tr: Dictionary = e["trigger"]
			ok(tr.has("date_from") and tr.has("date_to") and tr.has("scenarios") and tr.has("countries"), "%s has window, scenario and countries" % id)
			ok(str(e["source"]) != "" and str(e["reference"]) != "", "%s has source and reference" % id)
	ok(rnd >= 15, "new random systems events (%d)" % rnd)
	ok(hist >= 15, "new historical events with a reference (%d)" % hist)

func test_new_random_event_chain_runs() -> void:
	# every new random event can be fired for a country that meets its conditions without breaking the state
	var s := new_state()
	var cid: String = s["player"]
	for id in Defs.events:
		if not str(id).begins_with("g_"):
			continue
		var e: Dictionary = Defs.events[id]
		var s2 := new_state()
		s2["countries"][cid]["gold"] = 3000.0
		var pid := ""
		if e.get("scope", "country") == "province":
			pid = GS.owned(s2, cid)[0]
		var other := ""
		for pair_o in GS.alive_countries(s2):
			if pair_o != cid and not str(pair_o).begins_with("NAT_"):
				other = pair_o
				break
		for o in e["options"]:
			var s3 := new_state()
			s3["countries"][cid]["gold"] = 3000.0
			var entry := {"uid": "t3", "id": id, "cid": cid, "pid": pid, "other": other, "turn": 0}
			s3["events"]["pending"].append(entry)
			EventSystem.apply_option(s3, entry, str(o["id"]))
			_valid(s3, "%s/%s" % [id, o["id"]])
