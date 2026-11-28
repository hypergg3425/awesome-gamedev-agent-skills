extends Node
## Per-subsystem timing of one turn (same order as TurnManager). godot --headless --path . res://tests/perf_detail.tscn -- <scenario> <warmup turns>

func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	var def: Dictionary = Defs.all_scenarios()[a[0]]
	var s := ScenarioLoader.build(def, def["default_player"], "normal", 1)
	s["players"] = []
	for i in int(a[1]):
		TurnManager.end_turn(s)
	var acc := {}
	var n := 6
	for i in n:
		SimExt.ensure(s)
		s["_c"]["demand"] = {}
		GS.rebuild_caches(s)
		Mods.invalidate(s)
		var alive := GS.alive_countries(s)
		var t := Time.get_ticks_usec()
		for cid in alive:
			AISystem.run(s, cid)
		_add(acc, "ai.run", t)
		t = Time.get_ticks_usec()
		for cid in alive:
			MilitarySystem.process_recruit_queue(s, cid)
		MilitarySystem.move_all(s)
		GS.rebuild_caches(s)
		MilitarySystem.resolve_battles(s)
		MilitarySystem.process_sieges(s)
		GS.rebuild_caches(s)
		MilitarySystem.process_supply(s)
		NavalSystem.process_turn(s)
		MilitarySystem.rebels_upkeep(s)
		GS.rebuild_caches(s)
		_add(acc, "military", t)
		t = Time.get_ticks_usec()
		TradeSystem.compute(s)
		_add(acc, "trade.compute", t)
		var production := {}
		for cid in GS.alive_countries(s):
			t = Time.get_ticks_usec()
			var b := EconomySystem.process_turn(s, cid)
			_add(acc, "econ.process_turn", t)
			if b.is_empty():
				continue
			for k in b["mats"]:
				production[k] = float(production.get(k, 0.0)) + float(b["mats"][k])
			t = Time.get_ticks_usec()
			ConstructionSystem.process_turn(s, cid)
			_add(acc, "construction", t)
			t = Time.get_ticks_usec()
			TechSystem.process_turn(s, cid)
			_add(acc, "tech", t)
			t = Time.get_ticks_usec()
			SimExt.economy_phase(s, cid)
			_add(acc, "simext.economy_phase", t)
		t = Time.get_ticks_usec()
		PopulationSystem.process_turn(s)
		_add(acc, "population", t)
		EconomySystem.invalidate_calc(s)
		t = Time.get_ticks_usec()
		for cid in GS.alive_countries(s):
			PoliticsSystem.process_turn(s, cid)
		SimExt.world_phase(s)
		_add(acc, "politics", t)
		t = Time.get_ticks_usec()
		TradeSystem.update_market(s, production, {"food": 1.0})
		_add(acc, "market", t)
		t = Time.get_ticks_usec()
		DiplomacySystem.process_turn(s)
		DiplomacySystem.check_destroyed(s)
		_add(acc, "diplomacy", t)
		t = Time.get_ticks_usec()
		EventSystem.process_turn(s)
		_add(acc, "events", t)
		t = Time.get_ticks_usec()
		VictorySystem.process_turn(s)
		VictorySystem.snapshot(s)
		_add(acc, "victory", t)
		t = Time.get_ticks_usec()
		s["turn"] = int(s["turn"]) + 1
		GS.rebuild_caches(s)
		_add(acc, "rebuild_caches", t)
		t = Time.get_ticks_usec()
		GS.quantize(s)
		_add(acc, "quantize", t)
	var keys: Array = acc.keys()
	keys.sort_custom(func(x, y): return acc[x] > acc[y])
	for k in keys:
		print("DETAIL %-22s %7.1f ms/turn" % [k, float(acc[k]) / 1000.0 / n])
	get_tree().quit()

func _add(acc: Dictionary, k: String, t0: int) -> void:
	acc[k] = int(acc.get(k, 0)) + Time.get_ticks_usec() - t0
