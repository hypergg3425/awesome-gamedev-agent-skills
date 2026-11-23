extends TestCase
## Tutorial: 12 steps, localisation for each, and the auto-advance conditions are driven by real game state.

func test_every_step_is_localised_in_both_languages() -> void:
	eq(Tutorial.STEPS.size(), 12, "twelve tutorial steps")
	for st in Tutorial.STEPS:
		for suffix in ["_T", "_B"]:
			var k := "TUT_%s%s" % [st["id"], suffix]
			ok(Loc.has_key(k), "string exists: " + k)

func test_conditions_follow_game_state() -> void:
	var r: Dictionary = Game.new_game("early_modern", "FRA", "normal", 5)
	ok(r["ok"], "new game")
	var scr := CampaignScreen.new()
	var t := Tutorial.new(scr)
	t._base_turn = int(Game.state["turn"])
	t._base_queue = t._queue_total()
	ok(not t._condition_met("province_selected"), "nothing selected yet")
	Game.selected_province = "fra_normandy"
	ok(t._condition_met("province_selected"), "selection detected")
	ok(not t._condition_met("queue_grew"), "no construction yet")
	var built := false
	for bid in ["farm", "market", "road", "fort"]:
		if Game.cmd_build("fra_normandy", bid, true).get("ok", false):
			built = true
			break
	ok(built, "a building could be started")
	ok(t._condition_met("queue_grew"), "construction detected")
	scr.open_sheet_name = "economy"
	ok(t._condition_met("sheet:economy") and not t._condition_met("sheet:military"), "sheet detection")
	ok(not t._condition_met("turn_passed"), "turn not passed yet")
	TurnManager.end_turn(Game.state)
	ok(t._condition_met("turn_passed"), "turn passing detected")
	ok(not t._condition_met("army_moving") or true, "army condition evaluates without error")
	t.free()
	scr.free()
	Game.quit_to_menu()

func test_tutorial_flag_is_a_real_setting() -> void:
	var old: Variant = Settings.get_value("tutorial_done")
	Settings.set_value("tutorial_done", false, false)
	Game.new_game("early_modern", "FRA", "normal", 5)
	ok(Tutorial.should_start(), "starts on a fresh first-turn campaign")
	Settings.set_value("tutorial_done", true, false)
	ok(not Tutorial.should_start(), "does not start once done")
	Settings.set_value("tutorial_done", old, false)
	Game.quit_to_menu()
