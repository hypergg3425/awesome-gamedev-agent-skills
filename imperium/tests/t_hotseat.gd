extends TestCase
## Hotseat: device passing order, per-player commands, turn resolution only after the last player, save/load of the player list.

func _clear_events() -> void:
	var guard := 0
	while not Game.pending_events().is_empty() and guard < 20:
		var e: Dictionary = Game.pending_events()[0]
		var opts: Array = e.get("options", [])
		var oid := "" if opts.is_empty() else str(opts[0].get("id", ""))
		Game.cmd_event_choice(str(e["uid"]), oid)
		guard += 1

func test_two_player_turn_order() -> void:
	var r: Dictionary = Game.new_game("early_modern", "FRA", "normal", 9, ["FRA", "ENG"])
	ok(r["ok"], "hotseat game starts")
	eq(Game.state["players"], ["FRA", "ENG"], "two human players")
	ok(Game.state["countries"]["ENG"]["is_player"], "second player flagged")
	var t0 := int(Game.state["turn"])
	eq(Game.active_player, "FRA", "first player starts")
	_clear_events()
	var a := Game.end_turn()
	ok(a.get("passed", false), "first end-turn only passes the device")
	eq(Game.active_player, "ENG", "second player is active")
	eq(int(Game.state["turn"]), t0, "turn not resolved yet")
	_clear_events()
	var b := Game.end_turn()
	ok(b.get("ok", true) and not b.get("passed", false), "second end-turn resolves the turn")
	eq(int(Game.state["turn"]), t0 + 1, "turn advanced exactly once")
	eq(Game.active_player, "FRA", "back to the first player")
	ok(Saves.validate_state(Game.state).is_empty(), "state valid after a hotseat turn")
	Game.quit_to_menu()

func test_commands_apply_to_the_active_player_only() -> void:
	Game.new_game("early_modern", "FRA", "normal", 9, ["FRA", "ENG"])
	_clear_events()
	Game.end_turn()
	eq(Game.active_player, "ENG", "ENG active")
	var gold_fra := float(Game.state["countries"]["FRA"]["gold"])
	var owned: Array = GS.owned(Game.state, "ENG")
	var started := false
	for pid in owned:
		for bid in ["farm", "market", "road"]:
			if Game.cmd_build(pid, bid, true).get("ok", false):
				started = true
				break
		if started:
			break
	ok(started, "ENG can start a building")
	eq(float(Game.state["countries"]["FRA"]["gold"]), gold_fra, "FRA's treasury untouched by ENG's command")
	var fra_pid: String = GS.owned(Game.state, "FRA")[0]
	var bad := Game.cmd_build(fra_pid, "farm", true)
	ok(not bad.get("ok", false), "ENG cannot build in a FRA province")
	Game.quit_to_menu()

func test_hotseat_players_survive_save_and_load() -> void:
	Game.new_game("early_modern", "FRA", "normal", 9, ["FRA", "ENG"])
	var sv := Game.save_game("test_hotseat_slot")
	ok(sv.get("ok", false), "saved")
	var ld := Game.load_game("test_hotseat_slot")
	ok(ld.get("ok", false), "loaded")
	eq(Game.state["players"], ["FRA", "ENG"], "player list preserved")
	eq(Game.active_player, "FRA", "restarts with the first player")
	Saves.delete_slot("test_hotseat_slot")
	Game.quit_to_menu()
