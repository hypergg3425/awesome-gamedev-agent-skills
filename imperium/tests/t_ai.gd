extends TestCase

func _sim(scn: String, turns: int, seed_v: int, diff: String = "normal") -> Dictionary:
	var s := new_state(scn, "", diff, seed_v)
	s["players"] = []
	var errs := run_turns(s, turns)
	return {"s": s, "errs": errs}

func test_ai_makes_strategic_decisions_over_many_turns() -> void:
	var r := _sim("early_modern", 90, 21)
	var s: Dictionary = r["s"]
	ok((r["errs"] as Array).is_empty(), "90 turns complete: %s" % str(r["errs"]))
	var built := 0.0
	var raised := 0.0
	var techs := 0.0
	var wars := int(s["next_war_id"]) - 1
	for cid in GS.alive_countries(s):
		var st: Dictionary = s["countries"][cid]["stats"]
		built += float(st.get("buildings_built", 0.0))
		raised += float(st.get("regiments_raised", 0.0))
		techs += float(st.get("techs", 0.0))
	ok(built > 30.0, "AI constructs buildings (%d)" % int(built))
	ok(raised > 30.0, "AI recruits armies (%d)" % int(raised))
	ok(techs > 20.0, "AI researches technologies (%d)" % int(techs))
	ok(wars >= 2, "AI declares wars (%d)" % wars)
	var errs := Saves.validate_state(s)
	ok(errs.is_empty(), "no invalid ownership or references: %s" % str(errs.slice(0, 3)))

func test_ai_is_stable_and_solvent() -> void:
	var r := _sim("early_modern", 70, 5)
	var s: Dictionary = r["s"]
	for cid in GS.alive_countries(s):
		var c: Dictionary = s["countries"][cid]
		ok(float(c["gold"]) > -50.0, "%s not deeply negative (%.0f)" % [cid, float(c["gold"])])
		ok(float(c["debt"]) < float(c.get("budget", {}).get("income", 50.0)) * 40.0 + 2000.0, "%s debt manageable" % cid)
		var b: Dictionary = c.get("budget", {})
		if float(b.get("income", 0.0)) > 60.0:
			ok(float(b.get("army", 0.0)) + float(b.get("navy", 0.0)) < float(b["income"]) * 1.2, "%s maintenance affordable (%.0f vs %.0f)" % [cid, float(b.get("army", 0.0)), float(b["income"])])
		ok(not is_nan(float(c["stability"])), "stability finite")

func test_no_orphaned_state_after_long_run() -> void:
	var r := _sim("early_modern", 120, 3)
	var s: Dictionary = r["s"]
	# armies exist only for living owners at valid locations
	for aid in s["armies"]:
		var a: Dictionary = s["armies"][aid]
		ok(a["owner"] == "REB" or s["countries"][a["owner"]]["alive"], "army owner alive (%s)" % aid)
		ok(UnitUtil.army_size(a) > 0.0, "no empty armies kept")
	for wid in s["wars"]:
		var w: Dictionary = s["wars"][wid]
		if not w.get("ended", false):
			ok(not (w["attackers"] as Array).is_empty() and not (w["defenders"] as Array).is_empty(), "active war has two sides")
			for x in w["attackers"] + w["defenders"]:
				ok(s["countries"][x]["alive"], "war participant alive")
	# no deadlock: the world still changes
	ok(int(s["turn"]) == 120 or s["game_over"], "campaign reached turn 120 or ended with a recorded outcome (%s)" % str(s.get("victory_type", "")))

func test_ai_does_not_read_hidden_information() -> void:
	var s := new_state("early_modern", "", "normal", 8)
	var observer := ""
	var target := ""
	var best := -1.0
	for a in GS.alive_countries(s):
		if str(a).begins_with("NAT_"):
			continue
		for b in GS.alive_countries(s):
			if a == b or str(b).begins_with("NAT_") or DiplomacySystem.borders(s, a, b):
				continue
			var actual := UnitUtil.country_regiments(s, b)
			if actual > best:
				best = actual
				observer = a
				target = b
	var normal := AISystem.visible_strength(s, observer, target)
	s["difficulty"] = "expert"
	var expert := AISystem.visible_strength(s, observer, target)
	ok(absf(expert - best) < 0.01, "expert difficulty documents full information")
	s["difficulty"] = "normal"
	ok(absf(normal - best) > 0.01, "normal AI does not see a distant nation's exact army (%.1f vs %.1f)" % [normal, best])

func test_difficulty_changes_decision_quality_not_resources() -> void:
	var e := AISystem.DIFF["easy"]
	var h := AISystem.DIFF["hard"]
	ok(float(e["skip"]) > float(h["skip"]), "easy AI skips actions more often")
	ok(bool(h["plan"]) and not bool(e["plan"]), "hard AI plans, easy does not")
	for d in AISystem.DIFF:
		for k in AISystem.DIFF[d]:
			ok(not str(k).contains("gold") and not str(k).contains("income") and not str(k).contains("bonus"), "difficulty has no economic cheat knob (%s.%s)" % [d, k])

func test_personalities_differ() -> void:
	var w_agg: Dictionary = AISystem.PERS_W["aggressive"]
	var w_iso: Dictionary = AISystem.PERS_W["isolationist"]
	ok(float(w_agg["war"]) > float(w_iso["war"]) * 3.0, "aggressive wants war far more than isolationists")
	for p in Const.PERSONALITIES:
		ok(AISystem.PERS_W.has(p), "weights exist for %s" % p)

func test_ai_turn_resolution_with_player_present() -> void:
	var s := new_state("early_modern")
	var errs := run_turns(s, 20)
	ok(errs.is_empty(), "turns resolve with a human player")
	ok(s["countries"][s["player"]]["alive"], "player persists")
	# AI never acts for the player
	var tax := float(s["countries"][s["player"]]["tax_rate"])
	near(tax, 0.25, 0.0001, "player's policies untouched by AI")
