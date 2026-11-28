extends TestCase
## Structural and soak checks for the researched scenarios added in v2.0 (Third Crusade 1187,
## Peace of Westphalia 1648, Eve of Austerlitz 1805).

const IDS: Array[String] = ["third_crusade", "westphalia", "austerlitz"]
const EFFECTS := ["gold", "manpower", "stability", "legitimacy", "prestige", "admin", "inflation", "debt", "stock", "set_flag", "clear_flag", "temp_mod", "class_sat", "pop_pct", "province_unrest", "province_pop_pct", "province_devastation", "province_dev", "add_building", "destroy_building", "ruler_skill", "kill_ruler", "spawn_rebels", "relation", "research_points", "add_claim", "trigger_event", "disband_pct", "add_regiments", "change_religion_province", "war_exhaustion", "reform_cost_free"]

func _events_of(id: String) -> Array:
	var out: Array = []
	for eid in Util.sorted_keys(Defs.events):
		var tr: Dictionary = Defs.events[eid].get("trigger", {})
		if id in tr.get("scenarios", []):
			out.append(Defs.events[eid])
	return out

func test_scenarios_load_and_validate() -> void:
	for id in IDS:
		var def: Dictionary = scenario(id)
		ok(not def.is_empty(), "%s is registered" % id)
		if def.is_empty():
			continue
		eq(ScenarioLoader.validate(def), [], "%s passes ScenarioLoader.validate" % id)
		ok(bool(def.get("approximate", false)), "%s is flagged approximate" % id)
		ok(str(def.get("note", {}).get("en", "")).length() > 200 and str(def.get("note", {}).get("tr", "")).length() > 200, "%s has a real EN+TR honesty note" % id)
		ok(str(def["desc"].get("tr", "")) != "" and str(def["name"].get("tr", "")) != "", "%s bilingual name and description" % id)
		ok((def["countries"] as Dictionary).size() >= 40, "%s names at least 40 polities (%d)" % [id, (def["countries"] as Dictionary).size()])
		ok((def.get("objectives", []) as Array).size() >= 6, "%s has objectives" % id)

func test_capitals_ownership_and_claims() -> void:
	for id in IDS:
		var def: Dictionary = scenario(id)
		var s := new_state(id)
		for cid in def["countries"]:
			var c: Dictionary = s["countries"][cid]
			ok(c["alive"], "%s/%s alive" % [id, cid])
			ok(s["provinces"][c["capital"]]["owner"] == cid, "%s/%s owns its capital %s" % [id, cid, c["capital"]])
			var r: Dictionary = def["countries"][cid]["ruler"]
			ok(str(r.get("name", "")) != "" and int(r.get("age", 0)) > 0, "%s/%s has a named ruler with an age" % [id, cid])
		for cid in def.get("claims", {}):
			ok(s["countries"].has(cid), "%s claimant %s exists" % [id, cid])
			for pat in def["claims"][cid]:
				var hit := false
				for pid in Defs.province_ids:
					if Util.glob_match(str(pat), pid):
						hit = true
						ok(s["provinces"][pid]["owner"] != cid, "%s: %s claims a province it does not already own (%s)" % [id, cid, pid])
				ok(hit, "%s claim pattern %s resolves" % [id, str(pat)])
		for w in def["relations"]["wars"]:
			for a in w["attackers"] + w["defenders"]:
				ok(s["countries"].has(a), "%s war participant %s exists" % [id, a])
		ok(Saves.validate_state(s).is_empty(), "%s starting state validates" % id)

func test_province_names_are_valid_and_bilingual() -> void:
	for id in IDS:
		var pn: Dictionary = scenario(id).get("province_names", {})
		ok(pn.size() >= 80, "%s has scenario-specific province names (%d)" % [id, pn.size()])
		for pid in pn:
			ok(Defs.provinces.has(pid), "%s province_names key %s exists" % [id, pid])
			ok(str(pn[pid].get("en", "")) != "" and str(pn[pid].get("tr", "")) != "", "%s %s name is bilingual" % [id, pid])

func test_scenario_events_are_well_formed() -> void:
	for id in IDS:
		var def: Dictionary = scenario(id)
		var evs := _events_of(id)
		var hist := 0
		var rnd := 0
		for e in evs:
			var eid: String = e["id"]
			ok(e["options"].size() >= 2 and e["options"].size() <= 4, "%s offers a choice" % eid)
			ok(str(e["title"].get("tr", "")) != "" and str(e["text"].get("tr", "")) != "", "%s bilingual" % eid)
			var tr: Dictionary = e["trigger"]
			for tag in tr.get("countries", []):
				ok(def["countries"].has(tag), "%s trigger country %s is in the scenario" % [eid, tag])
			var tips := {}
			for o in e["options"]:
				ok(str(o["name"].get("tr", "")) != "" and str(o["tip"].get("tr", "")) != "", "%s/%s has EN+TR name and tip" % [eid, o["id"]])
				tips[JSON.stringify(o["effects"])] = true
				for fx in o["effects"]:
					ok(fx["type"] in EFFECTS, "%s effect %s known" % [eid, fx["type"]])
					if fx["type"] == "add_claim" and fx.has("province"):
						ok(Defs.provinces.has(fx["province"]), "%s claim province exists" % eid)
					if fx["type"] == "relation" and fx.get("target", "") not in ["random_neighbor", "enemy"]:
						ok(def["countries"].has(fx["target"]), "%s relation target %s in scenario" % [eid, fx["target"]])
			eq(tips.size(), e["options"].size(), "%s options have different consequences" % eid)
			if e.get("historical", false):
				hist += 1
				ok(str(e.get("source", "")).length() > 20, "%s cites a source" % eid)
				ok(tr.has("date_from") and tr.has("date_to") and tr.has("countries"), "%s has a date window and country list" % eid)
				ok(int(tr["date_to"]["year"]) * 12 + int(tr["date_to"]["month"]) >= int(tr["date_from"]["year"]) * 12 + int(tr["date_from"]["month"]), "%s window is ordered" % eid)
			else:
				rnd += 1
				ok(str(e.get("source", "")) == "", "%s random event has no source" % eid)
		ok(hist >= 8, "%s has at least 8 historical events (%d)" % [id, hist])
		ok(rnd >= 3, "%s has at least 3 clearly random events (%d)" % [id, rnd])
		for eid in def.get("events", []):
			ok(Defs.events.has(eid), "%s lists existing event %s" % [id, eid])

func test_every_event_option_applies_cleanly() -> void:
	for id in IDS:
		var def: Dictionary = scenario(id)
		for e in _events_of(id):
			var tags: Array = e["trigger"].get("countries", def["countries"].keys().slice(0, 3))
			var cid: String = str(tags[0])
			for o in e["options"]:
				var s := new_state(id, cid)
				s["countries"][cid]["gold"] = 3000.0
				var pid := ""
				if e.get("scope", "country") == "province":
					pid = str(GS.owned(s, cid)[0])
				var entry := {"uid": "t", "id": e["id"], "cid": cid, "pid": pid, "other": "", "turn": 0}
				s["events"]["pending"].append(entry)
				var h0 := state_hash(s)
				ok(EventSystem.apply_option(s, entry, str(o["id"])), "%s/%s applies" % [e["id"], o["id"]])
				ok(state_hash(s) != h0, "%s/%s changes the state" % [e["id"], o["id"]])
				ok(Saves.validate_state(s).is_empty(), "%s/%s leaves a valid state" % [e["id"], o["id"]])

func test_historical_events_fire_in_window() -> void:
	var expect := {"third_crusade": "tc_audita_tremendi", "westphalia": "wp_prague", "austerlitz": "au_boulogne"}
	for id in IDS:
		var s := new_state(id)
		var seen := false
		for i in 6:
			TurnManager.end_turn(s)
			for k in s["events"]["fired"]:
				if str(k).begins_with(expect[id] + "|"):
					seen = true
		ok(seen, "%s: %s fired within the first six turns" % [id, expect[id]])

func test_sixty_turn_ai_simulation_stays_valid() -> void:
	for id in IDS:
		var s := new_state(id)
		s["players"] = []
		var errs := run_turns(s, 60)
		ok(errs.is_empty(), "%s: 60 turns run (%s)" % [id, str(errs)])
		ok(Saves.validate_state(s).is_empty(), "%s: state valid after 60 turns: %s" % [id, str(Saves.validate_state(s).slice(0, 3))])
		var nan_found := 0
		for cid in GS.alive_countries(s):
			for k in ["gold", "debt", "stability", "legitimacy", "prestige", "manpower"]:
				var v := float(s["countries"][cid][k])
				if is_nan(v) or is_inf(v):
					nan_found += 1
		eq(nan_found, 0, "%s: no NaN/inf in country state" % id)
		ok(GS.alive_countries(s).size() >= 30, "%s: world still populated (%d alive)" % [id, GS.alive_countries(s).size()])
