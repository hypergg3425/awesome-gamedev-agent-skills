class_name TurnManager
extends RefCounted
## Orchestrates one full turn (one season). Order matters and is documented in
## docs/TECHNICAL_ARCHITECTURE.md: orders -> AI -> movement/combat -> economy -> population -> diplomacy -> events -> victory.

static func end_turn(s: Dictionary) -> Dictionary:
	if bool(s["game_over"]):
		return {"ok": false, "reason": "GAME_OVER"}
	SimExt.ensure(s)
	var summary := {"battles": [], "turn": s["turn"], "timing": {}}
	var _t := Time.get_ticks_msec()
	s["_c"]["battles_turn"] = []
	s["_c"]["demand"] = {}
	GS.rebuild_caches(s)
	Mods.invalidate(s)
	var alive := GS.alive_countries(s)
	# 1. AI decisions (orders are executed in the movement phase below)
	for cid in alive:
		if cid not in s["players"]:
			AISystem.run(s, cid)
	summary["timing"]["ai"] = Time.get_ticks_msec() - _t
	_t = Time.get_ticks_msec()
	# 2. recruitment queues, movement, battles, sieges, supply
	for cid in alive:
		MilitarySystem.process_recruit_queue(s, cid)
	MilitarySystem.move_all(s)
	GS.rebuild_caches(s)
	var reports := MilitarySystem.resolve_battles(s)
	summary["battles"] = reports
	MilitarySystem.process_sieges(s)
	GS.rebuild_caches(s)
	MilitarySystem.process_supply(s)
	NavalSystem.process_turn(s)
	MilitarySystem.rebels_upkeep(s)
	GS.rebuild_caches(s)
	summary["timing"]["military"] = Time.get_ticks_msec() - _t
	_t = Time.get_ticks_msec()
	# 3. economy of every country (trade cache is refreshed after occupation changes)
	TradeSystem.compute(s)
	var production := {}
	for cid in GS.alive_countries(s):
		var b := EconomySystem.process_turn(s, cid)
		if b.is_empty():
			continue
		for k in b["mats"]:
			production[k] = float(production.get(k, 0.0)) + float(b["mats"][k])
		production["food"] = float(production.get("food", 0.0)) + float(b["food_prod"])
		ConstructionSystem.process_turn(s, cid)
		TechSystem.process_turn(s, cid)
		SimExt.economy_phase(s, cid)
	summary["timing"]["economy"] = Time.get_ticks_msec() - _t
	_t = Time.get_ticks_msec()
	# 4. population and politics
	PopulationSystem.process_turn(s)
	EconomySystem.invalidate_calc(s)
	for cid in GS.alive_countries(s):
		PoliticsSystem.process_turn(s, cid)
	SimExt.world_phase(s)
	var demand: Dictionary = s["_c"].get("demand", {})
	demand["food"] = float(demand.get("food", 0.0)) + DiplomacySystem.total_pop(s, "") * 0.0
	var tot_pop := 0.0
	for cid in GS.alive_countries(s):
		tot_pop += DiplomacySystem.total_pop(s, cid)
	demand["food"] = tot_pop * 0.97
	demand["iron"] = float(demand.get("iron", 0.0)) + UnitUtil_total_regiments(s) * 0.15
	TradeSystem.update_market(s, production, demand)
	summary["timing"]["population"] = Time.get_ticks_msec() - _t
	_t = Time.get_ticks_msec()
	# 5. diplomacy upkeep, events, victory
	DiplomacySystem.process_turn(s)
	DiplomacySystem.check_destroyed(s)
	EventSystem.process_turn(s)
	# expire stale proposals
	var keep: Array = []
	for r in s["pending_requests"]:
		if int(s["turn"]) - int(r["turn"]) <= 8:
			keep.append(r)
	s["pending_requests"] = keep
	VictorySystem.process_turn(s)
	VictorySystem.snapshot(s)
	summary["timing"]["end"] = Time.get_ticks_msec() - _t
	s["turn"] = int(s["turn"]) + 1
	GS.rebuild_caches(s)
	NavalSystem.ensure_fields(s)   # countries created during the turn (civil wars, independence) get the same defaults a loaded save would add
	GS.quantize(s)
	GS.save_rng(s)
	summary["ok"] = true
	return summary

static func UnitUtil_total_regiments(s: Dictionary) -> float:
	var n := 0.0
	for aid in s["armies"]:
		n += UnitUtil.army_size(s["armies"][aid])
	return n
