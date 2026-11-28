extends TestCase

const COND_TYPES := ["stability_below", "stability_above", "legitimacy_below", "legitimacy_above", "treasury_below", "treasury_above", "debt_above", "income_below", "income_above", "at_war", "not_at_war", "at_war_with", "gov_is", "gov_in", "has_tech", "tech_avg_above", "provinces_above", "provinces_below", "food_ratio_below", "food_stock_below", "religion_is", "culture_is", "flag_set", "flag_not_set", "year_at_least", "year_before", "is_player", "is_ai", "ruler_age_above", "ruler_skill_below", "ruler_skill_above", "prestige_above", "prestige_below", "manpower_below", "has_reform", "war_exhaustion_above", "season_is", "class_sat_below", "is_vassal", "has_vassals", "alliances_at_least", "owns_province", "neighbors_tag", "armies_at_least", "inflation_above", "bankrupt_recently", "heir_missing", "capital_coastal", "corruption_above", "faction_loyalty_below", "faction_loyalty_above", "faction_influence_above", "in_regency", "in_succession_dispute", "in_transition", "spy_levels_at_least", "ci_level_at_least", "eco_phase_is", "heir_exists", "royals_below", "has_general", "vassals_at_least", "is_hereditary", "naval_regiments_at_least", "faction_loyalty_between"]

func test_event_library_is_well_formed() -> void:
	ok(Defs.events.size() >= 60, "at least 60 events loaded (%d)" % Defs.events.size())
	var hist := 0
	var rnd := 0
	for id in Defs.events:
		var e: Dictionary = Defs.events[id]
		ok((e["options"] as Array).size() >= 2, "%s offers a choice" % id)
		ok(Loc.tx(e["title"]) != "" and str(e["title"].get("tr", "")) != "" and str(e["text"].get("tr", "")) != "", "%s bilingual" % id)
		if e.get("historical", false):
			hist += 1
			ok(str(e.get("source", "")) != "", "%s historical event cites a source" % id)
		else:
			rnd += 1
			ok(not e.get("source", ""), "%s random event has no historical source" % id)
		for c in e.get("trigger", {}).get("conds", []):
			ok(c["type"] in COND_TYPES, "%s cond %s known" % [id, c["type"]])
		for o in e["options"]:
			var distinct := false
			for fx in o["effects"]:
				distinct = true
			ok(distinct, "%s option has effects" % id)
	ok(rnd >= 55, "random events present (%d)" % rnd)

func test_events_have_real_consequences() -> void:
	var s := new_state("early_modern")
	var cid: String = s["player"]
	var c: Dictionary = s["countries"][cid]
	var applied := 0
	for id in Util.sorted_keys(Defs.events).slice(0, 150):
		var e: Dictionary = Defs.events[id]
		for o in e["options"]:
			var s2 := new_state("early_modern")
			var c2: Dictionary = s2["countries"][cid]
			c2["gold"] = 2000.0
			var pid := ""
			if e.get("scope", "country") == "province":
				pid = EventSystem.pick_province(s2, cid, e, GS.rng_of(s2))
				if pid == "":
					pid = GS.owned(s2, cid)[0]
			var entry := {"uid": "t", "id": id, "cid": cid, "pid": pid, "other": "", "turn": 0}
			s2["events"]["pending"].append(entry)
			var before := JSON.stringify(Saves.export_state(s2)).hash()
			var okk := EventSystem.apply_option(s2, entry, str(o["id"]))
			if not okk:
				continue
			applied += 1
			var after := JSON.stringify(Saves.export_state(s2)).hash()
			ok(before != after, "%s/%s changes the game state" % [id, o["id"]])
			var errs := Saves.validate_state(s2)
			ok(errs.is_empty(), "%s/%s leaves a valid state: %s" % [id, o["id"], str(errs.slice(0, 2))])
	ok(applied > 100, "many event options applied (%d)" % applied)

func test_option_effects_match_declared_numbers() -> void:
	var s := new_state("early_modern")
	var cid: String = s["player"]
	var c: Dictionary = s["countries"][cid]
	c["gold"] = 1000.0
	c["stability"] = 50.0
	# find a simple event option with gold and stability effects only
	var tested := 0
	for id in Util.sorted_keys(Defs.events):
		var e: Dictionary = Defs.events[id]
		for o in e["options"]:
			var simple := true
			var dg := 0.0
			var ds := 0.0
			for fx in o["effects"]:
				if fx["type"] == "gold":
					dg += float(fx["value"])
				elif fx["type"] == "stability":
					ds += float(fx["value"])
				elif fx["type"] in ["prestige", "legitimacy", "admin"]:
					pass
				else:
					simple = false
			if simple and (dg != 0.0 or ds != 0.0) and tested < 5 and EventSystem.conds_ok(s, cid, o.get("requires", [])):
				var s2 := new_state("early_modern")
				var cc: Dictionary = s2["countries"][cid]
				cc["gold"] = 1000.0
				cc["stability"] = 50.0
				var entry := {"uid": "t", "id": id, "cid": cid, "pid": "", "other": "", "turn": 0}
				EventSystem.apply_option(s2, entry, str(o["id"]))
				near(float(cc["gold"]), 1000.0 + dg, 0.01, "%s/%s gold effect exact" % [id, o["id"]])
				near(float(cc["stability"]), clampf(50.0 + ds, 0.0, 100.0), 0.01, "%s/%s stability effect exact" % [id, o["id"]])
				tested += 1
	ok(tested >= 3, "tested simple events (%d)" % tested)

func test_triggers_respect_conditions() -> void:
	var s := new_state("early_modern")
	var cid: String = s["player"]
	var c: Dictionary = s["countries"][cid]
	var fake := {"id": "t", "trigger": {"conds": [{"type": "stability_below", "value": 40}]}}
	c["stability"] = 80.0
	ok(not EventSystem.eligible(s, cid, fake), "does not trigger when stability is high")
	c["stability"] = 20.0
	ok(EventSystem.eligible(s, cid, fake), "triggers when stability is low")
	var once := {"id": "o", "once": true, "trigger": {}}
	ok(EventSystem.eligible(s, cid, once), "once-event eligible first time")
	s["events"]["fired"]["o|" + cid] = 0
	ok(not EventSystem.eligible(s, cid, once), "once-event never repeats")
	var win := {"id": "w", "trigger": {"date_from": {"year": 1700, "month": 1}}}
	ok(not EventSystem.eligible(s, cid, win), "date window respected")

func test_historical_events_fire_in_their_window_and_are_flagged() -> void:
	var s := new_state("early_modern")
	var fired_hist := 0
	var pending_hist := 0
	for i in 60:
		TurnManager.end_turn(s)
		for e in s["events"]["pending"]:
			if Defs.events[e["id"]].get("historical", false):
				pending_hist += 1
		s["events"]["pending"] = []
	for k in s["events"]["fired"]:
		var eid: String = str(k).split("|")[0]
		if Defs.events.has(eid) and Defs.events[eid].get("historical", false):
			fired_hist += 1
			var tr: Dictionary = Defs.events[eid]["trigger"]
			ok(tr.has("date_from") and tr.has("scenarios"), "%s has a date window and scenario" % eid)
	ok(fired_hist >= 1, "at least one dated historical event fired in 15 years (%d)" % fired_hist)

func test_player_events_wait_for_choice_ai_events_resolve() -> void:
	var s := new_state("early_modern")
	var fake := {"id": "rnd_test", "category": "political", "historical": false, "title": {"en": "t", "tr": "t"}, "text": {"en": "t", "tr": "t"},
		"trigger": {}, "mtth": 1, "options": [{"id": "a", "name": {"en": "a", "tr": "a"}, "effects": [{"type": "gold", "value": 10}]},
		{"id": "b", "name": {"en": "b", "tr": "b"}, "effects": [{"type": "gold", "value": -10}]}]}
	Defs.events["rnd_test"] = fake
	var rng := GS.rng_of(s)
	var player: String = s["player"]
	var other := ""
	for c in GS.alive_countries(s):
		if c != player and not str(c).begins_with("NAT_"):
			other = c
			break
	var g0 := float(s["countries"][other]["gold"])
	EventSystem._fire(s, player, fake, rng, "")
	EventSystem._fire(s, other, fake, rng, "")
	var pend: Array = s["events"]["pending"]
	eq(pend.size(), 1, "only the player's event waits")
	ok(absf(float(s["countries"][other]["gold"]) - g0) > 1.0, "AI event resolved immediately")
	Defs.events.erase("rnd_test")

func test_scenario_event_text_uses_scenario_province_names() -> void:
	var s := new_state("fall_of_constantinople")
	var cid := "BYZ"
	var entry := {"cid": cid, "pid": "tur_constantinople", "other": ""}
	var txt := EventSystem.render(s, entry, {"en": "Fire in {province}", "tr": "{province} yangını"})
	ok(txt.contains("Constantinople (besieged)") or txt.contains("kuşatma"), "event text shows the scenario's province name: %s" % txt)
