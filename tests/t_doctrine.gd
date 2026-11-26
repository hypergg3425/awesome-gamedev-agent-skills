extends TestCase
## Doctrines: data, unlocks by technology and era, effects through the national modifiers, switching cost and
## cool-down, retraining, AI choice, save round trip.

func _country(s: Dictionary) -> String:
	for cid in GS.alive_countries(s):
		if not str(cid).begins_with("NAT_") and GS.owned(s, cid).size() >= 3:
			return cid
	return ""

func test_data_has_enough_doctrines_with_texts() -> void:
	var d := DoctrineSystem.defs()
	ok(d.size() >= 10, "at least ten doctrines (%d)" % d.size())
	ok(DoctrineSystem.ids_for_slot("land").size() >= 6, "at least six land doctrines")
	ok(DoctrineSystem.ids_for_slot("naval").size() >= 3, "naval doctrines exist")
	for did in d:
		var def: Dictionary = d[did]
		ok(def["name"].has("en") and def["name"].has("tr") and def["desc"].has("tr"), "%s has EN+TR name and description" % did)
		ok(def["slot"] in DoctrineSystem.SLOTS, "%s has a slot" % did)
		ok(not (def["mods"] as Dictionary).is_empty(), "%s has effects" % did)
		for k in def["mods"]:
			ok(Loc.has_lang("MOD_" + str(k).to_upper(), "en") and Loc.has_lang("MOD_" + str(k).to_upper(), "tr"), "%s: modifier text for %s" % [did, k])
		for req in def["unlock"]:
			ok(Defs.tech_lines.has(req[0]), "%s unlocks through a real tech line (%s)" % [did, req[0]])

func test_unlocking_by_tech_and_year() -> void:
	var s := new_state()
	var cid := _country(s)
	var c: Dictionary = s["countries"][cid]
	for line in c["tech_level"]:
		c["tech_level"][line] = 0
	ok(DoctrineSystem.is_unlocked(s, cid, "feudal_levy"), "feudal host needs nothing")
	ok(not DoctrineSystem.is_unlocked(s, cid, "linear_firepower"), "linear firepower is locked at tech 0")
	c["tech_level"]["infantry_tactics"] = 3
	ok(DoctrineSystem.is_unlocked(s, cid, "linear_firepower"), "unlocked by infantry tactics III")
	c["tech_level"]["artillery"] = 3
	c["tech_level"]["cavalry_doctrine"] = 2
	s["start_year"] = 1500
	s["turn"] = 0
	ok(not DoctrineSystem.is_unlocked(s, cid, "corps_system"), "corps system also needs the era (year 1790)")
	s["start_year"] = 1800
	ok(DoctrineSystem.is_unlocked(s, cid, "corps_system"), "corps system in 1800 with the techs")
	ok("corps_system" in DoctrineSystem.available(s, cid, "land"), "listed as available")

func test_effects_flow_into_national_modifiers_and_battle() -> void:
	var s := new_state()
	var cid := _country(s)
	var c: Dictionary = s["countries"][cid]
	DoctrineSystem.ensure(s, cid)
	c["doctrine"]["land"] = "feudal_levy"
	c["doctrine"]["since"]["land"] = -99
	Mods.invalidate(s)
	var m0 := Mods.get_mod(s, cid, "cav_atk")
	c["doctrine"]["land"] = "mounted_manoeuvre"
	Mods.invalidate(s)
	ok(Mods.get_mod(s, cid, "pursuit") > 0.4, "doctrine adds pursuit")
	ok(Mods.get_mod(s, cid, "river_pen") < 0.0, "doctrine eases river crossings")
	ok(Mods.get_mod(s, cid, "cav_atk") != m0, "cavalry attack changes with doctrine")

func test_switching_costs_gold_has_cooldown_and_retraining() -> void:
	var s := new_state()
	var cid := _country(s)
	var c: Dictionary = s["countries"][cid]
	for line in c["tech_level"]:
		c["tech_level"][line] = 3
	s["start_year"] = 1850
	s["turn"] = 40
	DoctrineSystem.ensure(s, cid)
	var cur := DoctrineSystem.current(c, "land")
	var other := ""
	for did in DoctrineSystem.available(s, cid, "land"):
		if did != cur:
			other = did
			break
	ok(other != "", "another doctrine is available")
	c["gold"] = 0.0
	eq(DoctrineSystem.adopt(s, cid, other)["reason"], "ERR_NO_GOLD", "needs gold")
	c["gold"] = 5000.0
	eq(DoctrineSystem.adopt(s, cid, cur)["reason"], "DOC_ERR_SAME", "same doctrine refused")
	var aid := MilitarySystem.create_army(s, cid, GS.owned(s, cid)[0], {"spearmen": 4.0}, null)
	var cost := float(DoctrineSystem.switch_cost(s, cid, "land", other)["gold"])
	s["armies"][aid]["discipline"] = 60.0
	var r := DoctrineSystem.adopt(s, cid, other)
	ok(r["ok"], "adopt: %s" % str(r))
	near(float(c["gold"]), 5000.0 - cost, 0.01, "gold deducted")
	eq(DoctrineSystem.current(c, "land"), other, "doctrine changed")
	ok(float(s["armies"][aid]["discipline"]) < 60.0, "troops lose drill while retraining")
	near(DoctrineSystem.strength(s, c, "land"), 0.5, 0.001, "half effect right after the switch")
	eq(DoctrineSystem.can_switch(s, cid, cur)["reason"], "DOC_ERR_COOLDOWN", "cool-down before the next switch")
	s["turn"] = 40 + DoctrineSystem.RETRAIN_TURNS
	near(DoctrineSystem.strength(s, c, "land"), 1.0, 0.001, "full effect after retraining")
	s["turn"] = 40 + DoctrineSystem.COOLDOWN_TURNS
	ok(DoctrineSystem.can_switch(s, cid, cur)["ok"], "switch allowed after the cool-down")

func test_ai_scores_follow_army_and_personality() -> void:
	var s := new_state()
	var cid := _country(s)
	for line in s["countries"][cid]["tech_level"]:
		s["countries"][cid]["tech_level"][line] = 3
	s["start_year"] = 1850
	var fort := DoctrineSystem.ai_score(s, cid, "fortress_defence", "defensive")
	var fort_agg := DoctrineSystem.ai_score(s, cid, "fortress_defence", "aggressive")
	ok(fort > fort_agg, "defenders value fortress doctrine more (%.3f vs %.3f)" % [fort, fort_agg])
	var fire := DoctrineSystem.ai_score(s, cid, "linear_firepower", "aggressive")
	var fire_def := DoctrineSystem.ai_score(s, cid, "linear_firepower", "defensive")
	ok(fire > fire_def, "aggressive AIs value firepower more")
	var conv_trade := DoctrineSystem.ai_score(s, cid, "convoy_system", "naval_trade")
	var conv_agg := DoctrineSystem.ai_score(s, cid, "convoy_system", "isolationist")
	ok(conv_trade > conv_agg, "naval traders value convoys")

func test_ai_review_switches_when_clearly_better_and_affordable() -> void:
	var s := new_state()
	var cid := _country(s)
	var c: Dictionary = s["countries"][cid]
	for line in c["tech_level"]:
		c["tech_level"][line] = 4
	s["start_year"] = 1880
	s["turn"] = 60
	DoctrineSystem.ensure(s, cid)
	c["doctrine"]["land"] = "feudal_levy"
	c["doctrine"]["since"]["land"] = -99
	c["gold"] = 20000.0
	var switched := ""
	for t in 8:
		s["turn"] = 60 + t
		switched = DoctrineSystem.ai_review(s, cid, "aggressive")
		if switched != "":
			break
	ok(switched != "" and DoctrineSystem.current(c, "land") != "feudal_levy", "an advanced AI abandons the feudal host (%s)" % switched)
	var gold_after := float(c["gold"])
	ok(gold_after < 20000.0, "the AI paid for it")
	c["gold"] = 1.0
	c["doctrine"]["land"] = "feudal_levy"
	c["doctrine"]["since"]["land"] = -99
	var none := ""
	for t in 8:
		s["turn"] = 80 + t
		none += DoctrineSystem.ai_review(s, cid, "aggressive")
	eq(none, "", "a broke AI cannot switch")

func test_doctrine_state_survives_save_round_trip() -> void:
	var s := new_state()
	var cid := _country(s)
	DoctrineSystem.ensure(s, cid)
	var copy: Dictionary = JSON.parse_string(JSON.stringify(Saves.export_state(s)))
	NavalSystem.ensure_fields(copy)
	for slot in DoctrineSystem.SLOTS:
		eq(DoctrineSystem.current(copy["countries"][cid], slot), DoctrineSystem.current(s["countries"][cid], slot), "doctrine round trip (%s)" % slot)
	copy["countries"][cid].erase("doctrine")
	NavalSystem.ensure_fields(copy)
	ok(DoctrineSystem.current(copy["countries"][cid], "land") != "", "missing doctrine is restored by ensure_fields on load")

func test_every_country_gets_a_valid_doctrine_at_start() -> void:
	var s := new_state("industrial_era")
	var bad := 0
	for cid in GS.alive_countries(s):
		var c: Dictionary = s["countries"][cid]
		var d := DoctrineSystem.current(c, "land")
		if d == "" or not DoctrineSystem.is_unlocked(s, cid, d):
			bad += 1
	eq(bad, 0, "all countries start with an unlocked land doctrine")
