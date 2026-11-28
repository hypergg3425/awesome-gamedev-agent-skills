extends Node
## AI-vs-AI soak run that reports military and naval statistics (workstream E).
## godot --headless --path . res://tests/sim_mil.tscn -- <scenario> <turns> <seed>

func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	var sc := a[0] if a.size() > 0 else "early_modern"
	var turns := int(a[1]) if a.size() > 1 else 60
	var seed_v := int(a[2]) if a.size() > 2 else 1
	var def: Dictionary = Defs.all_scenarios()[sc]
	var s := ScenarioLoader.build(def, def["default_player"], "normal", seed_v)
	s["players"] = []
	var t0 := Time.get_ticks_msec()
	var land_b := 0
	var sea_b := 0
	var river_b := 0
	var pass_b := 0
	var gens_lost := 0
	var blockade_turns := 0
	var raid_turns := 0
	var max_raid := 0.0
	var intercepted := 0.0
	var losses_a := 0.0
	var winter_b := 0
	var factor_seen := {}
	var worst_ms := 0
	var timing := {}
	var problems: Array = []
	for i in turns:
		var t1 := Time.get_ticks_msec()
		var r := TurnManager.end_turn(s)
		worst_ms = maxi(worst_ms, Time.get_ticks_msec() - t1)
		if not r.get("ok", false):
			problems.append("turn %d failed" % i)
			break
		for k in r["timing"]:
			timing[k] = int(timing.get(k, 0)) + int(r["timing"][k])
		for rep in r["battles"]:
			if rep.get("naval", false):
				sea_b += 1
			else:
				land_b += 1
			if float(rep["river"]["share"]) > 0.0:
				river_b += 1
			if float(rep["pass"]["share"]) > 0.0:
				pass_b += 1
			if int(rep.get("weather", 0)) == 3:
				winter_b += 1
			losses_a += float(rep["loss_a"]) + float(rep["loss_d"])
			for ev in rep.get("events", []):
				if ev["kind"] in ["died", "captured"]:
					gens_lost += 1
			for f in rep["modifiers"]:
				factor_seen[f["key"]] = true
		blockade_turns += (s["naval"]["blockades"] as Dictionary).size()
		var rl := 0.0
		for cid in s["naval"]["raids"]:
			rl += float(s["naval"]["raids"][cid]["frac"])
		if rl > 0.0:
			raid_turns += 1
		max_raid = maxf(max_raid, rl)
		if i % 10 == 9:
			for e in Saves.validate_state(s).slice(0, 3):
				problems.append("t%d invalid: %s" % [i, e])
	var ms := Time.get_ticks_msec() - t0
	var fleets := 0
	var ships := 0.0
	var doc := {}
	for aid in s["armies"]:
		if s["armies"][aid].get("naval", false):
			fleets += 1
			ships += UnitUtil.army_size(s["armies"][aid])
	for cid in GS.alive_countries(s):
		var d := DoctrineSystem.current(s["countries"][cid], "land")
		doc[d] = int(doc.get(d, 0)) + 1
	var looted := 0.0
	var raided := 0.0
	var captured := 0.0
	for cid in s["naval"]["stats"]:
		looted += float(s["naval"]["stats"][cid]["looted"])
		intercepted += float(s["naval"]["stats"][cid]["intercepted"])
	for cid in s["countries"]:
		captured += float(s["countries"][cid]["stats"].get("commanders_captured", 0.0))
	print("SIMMIL %s seed=%d turns=%d time=%d ms (%.0f ms/turn avg, %d ms worst)" % [sc, seed_v, turns, ms, float(ms) / turns, worst_ms])
	print("  land battles %d  sea battles %d  river-crossing %d  pass %d  winter %d  casualties(reg) %.0f" % [land_b, sea_b, river_b, pass_b, winter_b, losses_a])
	print("  commanders lost %d (captured stat %.0f)  factor kinds seen %d" % [gens_lost, captured, factor_seen.size()])
	print("  fleets %d ships %.0f  blockade-port-turns %d  raid-turns %d (peak loss share %.3f)  looted %.1f  convoys intercepted %.0f" % [fleets, ships, blockade_turns, raid_turns, max_raid, looted, intercepted])
	print("  phase ms/turn: %s" % str(_per_turn(timing, turns)))
	print("  land doctrines in force: %s" % str(doc))
	print("  features: %d rivers %d passes (%s)" % [GeoFeatures.river_count(), GeoFeatures.pass_count(), "sample" if GeoFeatures.is_sample() else "real"])
	for p in problems:
		print("  PROBLEM: " + p)
	get_tree().quit(1 if not problems.is_empty() else 0)

func _per_turn(timing: Dictionary, turns: int) -> Dictionary:
	var out := {}
	for k in timing:
		out[k] = snappedf(float(timing[k]) / float(turns), 0.1)
	return out
