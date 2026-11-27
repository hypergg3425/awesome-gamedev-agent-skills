extends Node
## Campaign controller (autoload "Game"): owns the state dictionary, exposes player commands and
## emits signals for the UI. All game rules live in the static systems; this class only glues
## them to the engine (signals, autosave, hot-seat turn order).

signal state_changed()
signal turn_ended(summary: Dictionary)
signal game_over(info: Dictionary)
signal command_failed(reason: String, params: Dictionary)
signal selection_changed(pid: String)
signal achievement_unlocked(id: String)

var state: Dictionary = {}
var active_player := ""
var hotseat_index := 0
var last_summary: Dictionary = {}
var selected_province := ""
var selected_army := ""
var in_campaign := false

## Android back button / gesture. Screens may define on_back_requested(); otherwise sub-screens return
## to the main menu and the main menu quits.
func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_GO_BACK_REQUEST:
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	if scene.has_method("on_back_requested"):
		scene.call("on_back_requested")
	elif scene.scene_file_path.ends_with("main_menu.tscn") or scene.scene_file_path.ends_with("boot.tscn"):
		get_tree().quit()
	else:
		Nav.go(get_tree(), "menu")

func has_state() -> bool:
	return not state.is_empty()

## --- lifecycle ------------------------------------------------------------------------------------
func new_game(scenario_id: String, player: String, difficulty: String = "normal", seed_value: int = 0, hotseat: Array = []) -> Dictionary:
	var defs: Dictionary = Defs.all_scenarios()
	if not defs.has(scenario_id):
		return {"ok": false, "reason": "SC_ERR_UNKNOWN"}
	var def: Dictionary = defs[scenario_id]
	var errs := ScenarioLoader.validate(def)
	if not errs.is_empty():
		return {"ok": false, "reason": "SC_ERR_INVALID", "errors": errs}
	if seed_value == 0:
		seed_value = int(Time.get_unix_time_from_system()) % 1000000 + 1
	state = ScenarioLoader.build(def, player, difficulty, seed_value)
	if not hotseat.is_empty():
		state["players"] = hotseat.duplicate()
		for p in hotseat:
			state["countries"][p]["is_player"] = true
		state["player"] = hotseat[0]
	for p in state["players"]:
		state["countries"][p]["stats"]["start_provinces"] = GS.owned(state, p).size()
	# first budget snapshot so the UI has numbers on turn zero
	TradeSystem.compute(state)
	for cid in GS.alive_countries(state):
		state["countries"][cid]["budget"] = EconomySystem.budget(state, cid)
	hotseat_index = 0
	active_player = state["player"]
	selected_province = ""
	selected_army = ""
	in_campaign = true
	state_changed.emit()
	return {"ok": true}

func load_game(slot: String) -> Dictionary:
	var r: Dictionary = Saves.load_slot(slot)
	if not r["ok"]:
		return r
	state = r["state"]
	hotseat_index = 0
	active_player = state["player"]
	in_campaign = true
	selected_province = ""
	selected_army = ""
	state_changed.emit()
	return r

func save_game(slot: String) -> Dictionary:
	if state.is_empty():
		return {"ok": false, "reason": "ERR_INVALID"}
	return Saves.save_slot(slot, state)

func quit_to_menu() -> void:
	in_campaign = false

func player() -> String:
	return active_player

func pc() -> Dictionary:
	return state["countries"].get(active_player, {})

## --- turn -----------------------------------------------------------------------------------------------
func pending_events() -> Array:
	var out: Array = []
	for e in state["events"]["pending"]:
		if e["cid"] == active_player:
			out.append(e)
	return out

func can_end_turn() -> Dictionary:
	if bool(state.get("game_over", false)):
		return {"ok": false, "reason": "GAME_OVER"}
	if not pending_events().is_empty():
		return {"ok": false, "reason": "TURN_ERR_EVENTS"}
	return {"ok": true}

func end_turn() -> Dictionary:
	var chk := can_end_turn()
	if not chk["ok"]:
		command_failed.emit(chk["reason"], {})
		return chk
	# hot-seat: pass the device to the next human before resolving
	if state["players"].size() > 1 and hotseat_index < state["players"].size() - 1:
		hotseat_index += 1
		active_player = state["players"][hotseat_index]
		selected_province = ""
		selected_army = ""
		state_changed.emit()
		return {"ok": true, "passed": true}
	var summary := TurnManager.end_turn(state)
	hotseat_index = 0
	active_player = state["player"] if state["players"].size() <= 1 else state["players"][0]
	last_summary = summary
	for aid in Achievements.check(state):
		achievement_unlocked.emit(aid)
	if bool(Settings.get_value("autosave")) and not bool(state.get("game_over", false)):
		Saves.autosave(state)
	turn_ended.emit(summary)
	state_changed.emit()
	if bool(state.get("game_over", false)):
		game_over.emit({"winner": state.get("winner", ""), "type": state.get("victory_type", "")})
	return summary

## --- helpers for UI --------------------------------------------------------------------------------------------
func notes_this_turn(for_player: String = "") -> Array:
	var pl := active_player if for_player == "" else for_player
	var out: Array = []
	var t := int(state["turn"]) - 1
	for n in state["notes"]:
		if int(n["turn"]) >= t and n["cid"] == pl:
			out.append(n)
	return out

func _result(r: Dictionary) -> Dictionary:
	if r.get("ok", false):
		state_changed.emit()
	else:
		command_failed.emit(str(r.get("reason", "ERR_INVALID")), r.get("params", {}))
	return r

## --- commands (player actions) -------------------------------------------------------------------------------------------
func cmd_recruit(pid: String, uid: String) -> Dictionary:
	return _result(MilitarySystem.recruit(state, active_player, pid, uid))

func cmd_move(aid: String, target: String) -> Dictionary:
	var a: Dictionary = state["armies"].get(aid, {})
	if a.is_empty() or a["owner"] != active_player:
		return _result({"ok": false, "reason": "ERR_NOT_YOURS"})
	return _result(MilitarySystem.order_move(state, aid, target))

func cmd_cancel_move(aid: String) -> Dictionary:
	MilitarySystem.cancel_orders(state, aid)
	state_changed.emit()
	return {"ok": true}

func cmd_merge(a: String, b: String) -> Dictionary:
	return _result({"ok": MilitarySystem.merge_armies(state, a, b), "reason": "ERR_INVALID"})

func cmd_split(aid: String, units: Dictionary) -> Dictionary:
	var nid := MilitarySystem.split_army(state, aid, units)
	return _result({"ok": nid != "", "reason": "ERR_INVALID", "army": nid})

func cmd_disband(aid: String) -> Dictionary:
	var a: Dictionary = state["armies"].get(aid, {})
	if a.is_empty() or a["owner"] != active_player:
		return _result({"ok": false, "reason": "ERR_NOT_YOURS"})
	MilitarySystem.disband_army(state, aid, true)
	return _result({"ok": true})

## --- doctrines, fleets, unit improvements (workstream E) ---
func cmd_set_doctrine(did: String) -> Dictionary:
	return _result(DoctrineSystem.adopt(state, active_player, did))

func cmd_set_mission(aid: String, mission: String) -> Dictionary:
	var a: Dictionary = state["armies"].get(aid, {})
	if a.is_empty() or a["owner"] != active_player:
		return _result({"ok": false, "reason": "ERR_NOT_YOURS"})
	return _result(NavalSystem.set_mission(state, aid, mission))

func cmd_split_fleet(aid: String) -> Dictionary:
	var a: Dictionary = state["armies"].get(aid, {})
	if a.is_empty() or a["owner"] != active_player:
		return _result({"ok": false, "reason": "ERR_NOT_YOURS"})
	var made := NavalSystem.split_by_role(state, aid)
	return _result({"ok": not made.is_empty(), "reason": "ERR_INVALID", "fleets": made})

func cmd_upgrade_units(aid: String, uid: String) -> Dictionary:
	var a: Dictionary = state["armies"].get(aid, {})
	if a.is_empty() or a["owner"] != active_player:
		return _result({"ok": false, "reason": "ERR_NOT_YOURS"})
	return _result(MilitarySystem.upgrade_units(state, aid, uid))

func cmd_build(pid: String, bid: String, allow_buy: bool = false) -> Dictionary:
	return _result(ConstructionSystem.start_build(state, active_player, pid, bid, allow_buy))

func cmd_cancel_build(pid: String, index: int) -> Dictionary:
	return _result({"ok": ConstructionSystem.cancel_build(state, active_player, pid, index), "reason": "ERR_INVALID"})

func cmd_demolish(pid: String, bid: String) -> Dictionary:
	return _result({"ok": ConstructionSystem.demolish(state, active_player, pid, bid), "reason": "ERR_INVALID"})

func cmd_develop(pid: String) -> Dictionary:
	return _result(ConstructionSystem.develop(state, active_player, pid))

func cmd_research(tid: String) -> Dictionary:
	return _result(TechSystem.start_research(state, active_player, tid))

func cmd_cancel_research(branch: String) -> Dictionary:
	var c := pc()
	c["research"]["current"][branch] = ""
	state_changed.emit()
	return {"ok": true}

func cmd_set_research_alloc(branch: String, w: float) -> void:
	pc()["research"]["alloc"][branch] = clampf(w, 0.0, 3.0)
	state_changed.emit()

func cmd_set_tax(rate: float) -> void:
	pc()["tax_rate"] = clampf(rate, 0.05, 0.6)
	EconomySystem.invalidate_calc(state)
	var c := pc()
	c["budget"] = EconomySystem.budget(state, active_player)
	state_changed.emit()

func cmd_set_funding(f: float) -> void:
	pc()["army_funding"] = clampf(f, 0.4, 1.0)
	EconomySystem.invalidate_calc(state)
	pc()["budget"] = EconomySystem.budget(state, active_player)
	state_changed.emit()

func cmd_set_import_food(on: bool) -> void:
	pc()["import_food"] = on
	state_changed.emit()

func cmd_adopt_reform(rid: String) -> Dictionary:
	return _result(PoliticsSystem.adopt_reform(state, active_player, rid))

func cmd_change_gov(to: String) -> Dictionary:
	return _result(PoliticsSystem.change_government(state, active_player, to))

func cmd_diplomacy(action: String, to: String, params: Dictionary = {}) -> Dictionary:
	var r := DiplomacySystem.perform(state, action, active_player, to, params)
	if r.get("ok", false):
		state_changed.emit()
	else:
		command_failed.emit(str(r.get("reason", "ERR_INVALID")), r.get("params", {}))
	return r

func cmd_declare_war(target: String, cb: String) -> Dictionary:
	return _result(DiplomacySystem.declare_war(state, active_player, target, cb))

func cmd_peace(wid: String, other: String, terms: Dictionary) -> Dictionary:
	var ev := DiplomacySystem.peace_eval(state, wid, active_player, other, terms)
	if ev["accept"]:
		var r := DiplomacySystem.make_peace(state, wid, active_player, other, terms)
		r["eval"] = ev
		r["accepted"] = true
		return _result(r)
	state_changed.emit()
	return {"ok": true, "accepted": false, "eval": ev}

func cmd_concede(wid: String, winner: String, terms: Dictionary) -> Dictionary:
	var ev := DiplomacySystem.concession_eval(state, wid, active_player, winner, terms)
	if ev["accept"]:
		var r := DiplomacySystem.make_peace(state, wid, winner, active_player, terms)
		r["eval"] = ev
		r["accepted"] = true
		return _result(r)
	state_changed.emit()
	return {"ok": true, "accepted": false, "eval": ev}

func cmd_accept_peace_from(wid: String, from: String, terms: Dictionary) -> Dictionary:
	# the AI offers terms that favour it: evaluate from its side and apply the terms to us
	var r := DiplomacySystem.make_peace(state, wid, from, active_player, terms)
	return _result(r)

func cmd_respond_request(req_id: String, accept: bool) -> Dictionary:
	for r in state["pending_requests"]:
		if r["id"] == req_id and r["action"] == "peace":
			state["pending_requests"].erase(r)
			if accept:
				var terms: Dictionary = r["params"]["terms"]
				var wid: String = r["params"]["war"]
				var res := DiplomacySystem.make_peace(state, wid, r["from"], active_player, terms)
				return _result(res)
			state_changed.emit()
			return {"ok": true, "accepted": false}
	return _result(AISystem.respond_request(state, req_id, accept))

func cmd_event_choice(uid: String, option_id: String) -> Dictionary:
	for e in state["events"]["pending"]:
		if e["uid"] == uid:
			var ok := EventSystem.apply_option(state, e, option_id)
			return _result({"ok": ok, "reason": "ERR_INVALID"})
	return _result({"ok": false, "reason": "ERR_INVALID"})

func cmd_form_coalition(target: String) -> Dictionary:
	var id := DiplomacySystem.form_coalition_against(state, target)
	return _result({"ok": id != "", "reason": "DIPLO_ERR_NO_COALITION", "id": id})

## --- v2.1 systems: espionage, dynasty, factions, credit ----------------------------------------------------------------------
func cmd_spy_build(target: String) -> Dictionary:
	return _result(EspionageSystem.build_network(state, active_player, target))

func cmd_spy_dismantle(target: String) -> Dictionary:
	EspionageSystem.dismantle(state, active_player, target)
	state_changed.emit()
	return {"ok": true}

func cmd_spy_op(target: String, op: String) -> Dictionary:
	return _result(EspionageSystem.run_op(state, active_player, target, op))

func cmd_counter_intel() -> Dictionary:
	return _result(EspionageSystem.raise_ci(state, active_player))

func cmd_propose_marriage(to: String, royal_id: int) -> Dictionary:
	return _result(DynastySystem.propose_marriage(state, active_player, to, royal_id))

func cmd_designate_heir(royal_id: int) -> Dictionary:
	return _result(DynastySystem.designate(state, active_player, royal_id))

func cmd_buy_off_rival() -> Dictionary:
	return _result(DynastySystem.buy_off_rival(state, active_player))

func cmd_faction_concede(fid: String) -> Dictionary:
	return _result(FactionsSystem.concede(state, active_player, fid))

func cmd_faction_suppress(fid: String) -> Dictionary:
	return _result(FactionsSystem.suppress(state, active_player, fid))

func cmd_fight_corruption() -> Dictionary:
	return _result(FactionsSystem.fight_corruption(state, active_player))

func cmd_take_loan(amount: float) -> Dictionary:
	return _result(EconomyDepth.take_loan(state, active_player, amount))

func cmd_repay_debt(amount: float) -> Dictionary:
	return _result(EconomyDepth.repay(state, active_player, amount))

## --- selection -----------------------------------------------------------------------------------------------------------------
func select_province(pid: String) -> void:
	selected_province = pid
	selection_changed.emit(pid)

func select_army(aid: String) -> void:
	selected_army = aid
	state_changed.emit()
