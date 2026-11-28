extends Node
## Turn-phase timing profile. godot --headless --path . res://tests/perf.tscn -- <scenario> <turns> [seed]
## Select the map set with IMPERIUM_MAP_SET=extended. Prints mean ms per phase, worst turn and save/load cost.

func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	var sc := a[0] if a.size() > 0 else "world_conquest"
	var turns := int(a[1]) if a.size() > 1 else 10
	var def: Dictionary = Defs.all_scenarios()[sc]
	var s := ScenarioLoader.build(def, def["default_player"], "normal", int(a[2]) if a.size() > 2 else 1)
	s["players"] = []
	var sums := {}
	var worst := 0
	var total := 0
	for i in turns:
		var t0 := Time.get_ticks_msec()
		var r := TurnManager.end_turn(s)
		var dt := Time.get_ticks_msec() - t0
		total += dt
		worst = maxi(worst, dt)
		for k in r["timing"]:
			sums[k] = int(sums.get(k, 0)) + int(r["timing"][k])
	var t1 := Time.get_ticks_msec()
	Saves.save_slot("perf_tmp", s)
	var save_ms := Time.get_ticks_msec() - t1
	t1 = Time.get_ticks_msec()
	Saves.load_slot("perf_tmp")
	var load_ms := Time.get_ticks_msec() - t1
	Saves.delete_slot("perf_tmp")
	var parts: Array = []
	for k in sums:
		parts.append("%s %.0f" % [k, float(sums[k]) / turns])
	print("PERF %s map=%s countries=%d turns=%d mean=%.0f ms worst=%d | %s | save %d ms load %d ms" % [sc, Defs.map_set, GS.alive_countries(s).size(), turns, float(total) / turns, worst, " ".join(parts), save_ms, load_ms])
	get_tree().quit()
