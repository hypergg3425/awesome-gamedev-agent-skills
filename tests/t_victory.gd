extends TestCase

func test_territorial_victory() -> void:
	var s := new_state("early_modern")
	var pl: String = s["player"]
	# hand most of the map to the player
	var n := 0
	for pid in Defs.province_ids:
		if n < 110:
			s["provinces"][pid]["owner"] = pl
			s["provinces"][pid]["controller"] = pl
			n += 1
	GS.rebuild_caches(s)
	s["turn"] = 30
	for i in 10:
		VictorySystem.process_turn(s)
		if s["game_over"]:
			break
	ok(s["game_over"], "holding the territory target ends the game")
	eq(s["winner"], pl, "player wins")
	eq(s["victory_type"], "territory", "territorial victory recorded")

func test_victory_not_instant_at_start() -> void:
	var s := new_state("early_modern")
	for i in 8:
		VictorySystem.process_turn(s)
	ok(not s["game_over"], "no victory during the opening turns")

func test_objectives_complete_from_state() -> void:
	var s := new_state("early_modern")
	var pl: String = s["player"]
	var owned := GS.owned(s, pl).size()
	var ob := {"id": "t1", "type": "provinces_count", "count": owned, "done": false}
	ok(VictorySystem.check_objective(s, pl, ob), "owning enough provinces completes an objective")
	ob["count"] = owned + 5
	ok(not VictorySystem.check_objective(s, pl, ob), "not yet")
	ok(VictorySystem.check_objective(s, pl, {"type": "treasury", "amount": -1.0}), "treasury objective")
	ok(not VictorySystem.check_objective(s, pl, {"type": "destroy", "target": pl}), "destroy objective needs the target dead")
	s["objectives"] = [{"id": "o", "type": "provinces_count", "count": 1, "done": false, "score": 150}]
	VictorySystem.process_turn(s)
	ok(s["objectives"][0]["done"], "objectives tracked per turn")
	ok(float(VictorySystem.score(s, pl)["parts"]["SCORE_OBJECTIVES"]) >= 150.0, "objective score counted")

func test_defeat_when_player_destroyed() -> void:
	var s := new_state("early_modern")
	var pl: String = s["player"]
	for pid in GS.owned(s, pl).duplicate():
		s["provinces"][pid]["owner"] = "REB"
		s["provinces"][pid]["controller"] = "REB"
	GS.rebuild_caches(s)
	DiplomacySystem.check_destroyed(s)
	ok(not s["countries"][pl]["alive"], "landless country dies")
	VictorySystem.process_turn(s)
	ok(s["game_over"] and s["winner"] == "", "defeat ends the campaign")

func test_score_grows_with_success() -> void:
	var s := new_state("early_modern")
	var pl: String = s["player"]
	var base: float = VictorySystem.score(s, pl)["total"]
	s["countries"][pl]["stats"]["wars_won"] = 3.0
	s["countries"][pl]["stats"]["battles_won"] = 10.0
	var better: float = VictorySystem.score(s, pl)["total"]
	ok(better > base + 90.0, "wins increase the score")

func test_campaign_ends_at_turn_limit() -> void:
	var s := new_state("early_modern")
	s["turn_limit"] = 3
	for i in 5:
		if s["game_over"]:
			break
		TurnManager.end_turn(s)
	ok(s["game_over"], "campaign has a conclusion at the turn limit")
	ok(s["winner"] != "" or s["victory_type"] != "", "outcome recorded")
	eq(TurnManager.end_turn(s)["ok"], false, "no turns after the end")

func test_statistics_come_from_real_events() -> void:
	var s := new_state("early_modern")
	var pl: String = s["player"]
	var st0: Dictionary = (s["countries"][pl]["stats"] as Dictionary).duplicate()
	ok(float(st0.get("battles", 0.0)) == 0.0, "no battles before playing")
	run_turns(s, 4)
	VictorySystem.snapshot(s)
	ok(s["stats"].has("series") and s["stats"]["series"].has(pl), "time series recorded")
	ok(float(s["countries"][pl]["stats"].get("total_income", 0.0)) > 0.0, "income accumulates")
