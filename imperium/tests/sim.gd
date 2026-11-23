extends Node
## AI-vs-AI campaign simulator for balance / stability analysis.
## godot --headless --path . res://tests/sim.tscn -- <scenario> <turns> <seed> [difficulty]

func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	var sc := a[0] if a.size() > 0 else "early_modern"
	var turns := int(a[1]) if a.size() > 1 else 60
	var seed_v := int(a[2]) if a.size() > 2 else 1
	var diff := a[3] if a.size() > 3 else "normal"
	var def: Dictionary = Defs.all_scenarios()[sc]
	var s := ScenarioLoader.build(def, def["default_player"], diff, seed_v)
	# the "player" is also AI-driven here so that we observe the whole world
	s["players"] = []
	var t0 := Time.get_ticks_msec()
	var problems: Array = []
	var battles := 0
	var wars_started := 0
	var max_wars := 0
	for i in turns:
		var r := TurnManager.end_turn(s)
		if not r.get("ok", false):
			problems.append("turn %d returned not ok (%s)" % [i, str(r)])
			break
		battles += (r["battles"] as Array).size()
		var active := 0
		for wid in s["wars"]:
			if not s["wars"][wid].get("ended", false):
				active += 1
		max_wars = maxi(max_wars, active)
		if i % 10 == 9:
			var errs := Saves.validate_state(s)
			for e in errs.slice(0, 3):
				problems.append("t%d invalid: %s" % [i, e])
	var ms := Time.get_ticks_msec() - t0
	var alive := GS.alive_countries(s)
	var gold_neg := 0
	var debt_big := 0
	var nan_found := 0
	var tot_income := 0.0
	var armies_n := 0
	var regs := 0.0
	for cid in alive:
		var c: Dictionary = s["countries"][cid]
		if float(c["gold"]) < -1.0:
			gold_neg += 1
		if float(c["debt"]) > 2000.0:
			debt_big += 1
		for k in ["gold", "debt", "stability", "legitimacy", "prestige", "manpower", "inflation"]:
			if is_nan(float(c[k])) or is_inf(float(c[k])):
				nan_found += 1
		tot_income += float(c.get("budget", {}).get("income", 0.0))
	for aid in s["armies"]:
		armies_n += 1
		regs += UnitUtil.army_size(s["armies"][aid])
	print("SIM %s seed=%d turns=%d time=%d ms (%.0f ms/turn)" % [sc, seed_v, turns, ms, float(ms) / turns])
	print("  alive %d/%d  wars_total %d  active_wars_peak %d  battles %d  armies %d regiments %.0f" % [alive.size(), s["countries"].size() - 1, s["next_war_id"] - 1, max_wars, battles, armies_n, regs])
	print("  gold<0: %d  debt>2000: %d  nan/inf: %d  mean income %.1f" % [gold_neg, debt_big, nan_found, tot_income / maxf(1.0, alive.size())])
	var top: Array = []
	for cid in alive:
		top.append([GS.owned(s, cid).size(), cid, float(s["countries"][cid].get("budget", {}).get("income", 0.0)), float(s["countries"][cid]["gold"]), UnitUtil.country_regiments(s, cid)])
	top.sort_custom(func(x, y): return x[0] > y[0])
	for t in top.slice(0, 8):
		print("   %-5s provinces %3d income %7.1f gold %8.1f regiments %5.1f" % [t[1], t[0], t[2], t[3], t[4]])
	var changed := 0
	for pid in s["provinces"]:
		if s["provinces"][pid]["owner"] != (s["provinces"][pid]["cores"][0] if s["provinces"][pid]["cores"].size() > 0 else ""):
			changed += 1
	print("  provinces changed hands: %d  game_over: %s %s" % [changed, str(s["game_over"]), str(s.get("victory_type", ""))])
	for p in problems:
		print("  PROBLEM: " + p)
	get_tree().quit(1 if not problems.is_empty() else 0)
