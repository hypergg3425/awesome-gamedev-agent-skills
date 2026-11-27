extends TestCase
## Save reliability: autosave, slots, corruption handling, interrupted writes, migration chain,
## long-campaign determinism, lifecycle autosaves and hot-seat mid-turn persistence.

func _hash(s: Dictionary) -> int:
	return JSON.stringify(JSON.parse_string(JSON.stringify(Saves.export_state(s), "", false, true)), "", false, true).hash()

func _write_raw(slot: String, txt: String, suffix: String = "") -> void:
	var f := FileAccess.open(Saves.slot_path(slot) + suffix, FileAccess.WRITE)
	f.store_string(txt)
	f.close()

func _cleanup(slot: String) -> void:
	Saves.delete_slot(slot)
	for suf in [".corrupt", ".tmp"]:
		DirAccess.remove_absolute(Saves.slot_path(slot) + suf)

func test_manual_save_and_multiple_slots() -> void:
	var s := new_state()
	run_turns(s, 2)
	var s2 := new_state("early_modern", "", "normal", 99)
	run_turns(s2, 4)
	ok(Saves.save_slot("t2_a", s)["ok"], "slot a saved")
	ok(Saves.save_slot("t2_b", s2)["ok"], "slot b saved")
	var la: Dictionary = Saves.load_slot("t2_a")
	var lb: Dictionary = Saves.load_slot("t2_b")
	ok(la["ok"] and lb["ok"], "both load")
	eq(_hash(la["state"]), _hash(s), "slot a independent")
	eq(_hash(lb["state"]), _hash(s2), "slot b independent")
	eq(int(lb["state"]["turn"]), 4, "slot b keeps its own turn")
	ok(not la.get("recovered", true), "no recovery needed")
	_cleanup("t2_a")
	_cleanup("t2_b")

func test_autosave_rotation_and_quick() -> void:
	var s := new_state()
	for t in 7:
		s["turn"] = t
		Saves.autosave(s)
	for slot in ["auto_1", "auto_2", "auto_3", "last"]:
		ok(Saves.has_save(slot), "autosave slot " + slot)
	ok(Saves.autosave_quick(s)["ok"], "quick autosave")
	var l: Dictionary = Saves.load_slot("last")
	ok(l["ok"] and int(l["state"]["turn"]) == 6, "last = most recent")

func test_corruption_variants_never_delete() -> void:
	var s := new_state()
	Saves.save_slot("t2_c", s)
	run_turns(s, 1)
	Saves.save_slot("t2_c", s)   # .bak holds turn 0
	var good := FileAccess.get_file_as_string(Saves.slot_path("t2_c"))
	var variants := {
		"truncated": good.substr(0, good.length() / 3),
		"garbled": good.substr(0, good.length() / 2) + "@@@@garbage@@@@" + good.substr(good.length() / 2 + 15),
		"empty": "",
	}
	var parsed: Dictionary = JSON.parse_string(good)
	parsed["crc"] = int(parsed["crc"]) + 1
	variants["crc_mismatch"] = JSON.stringify(parsed)
	for k in variants:
		_write_raw("t2_c", variants[k])
		DirAccess.remove_absolute(Saves.slot_path("t2_c") + ".corrupt")
		var l: Dictionary = Saves.load_slot("t2_c")
		ok(l["ok"] and l.get("recovered", false), "%s: recovered from .bak" % k)
		eq(int(l["state"]["turn"]), 0, "%s: backup is the previous save" % k)
		ok(FileAccess.file_exists(Saves.slot_path("t2_c") + ".corrupt"), "%s: kept as .corrupt" % k)
		eq(FileAccess.get_file_as_string(Saves.slot_path("t2_c") + ".corrupt"), variants[k], "%s: corrupt copy is the original bytes" % k)
		ok(Saves.load_slot("t2_c")["ok"], "%s: slot healed for the next load" % k)
	# nothing to recover from: explicit failure, the broken file is not removed
	_write_raw("t2_c", "garbage")
	_write_raw("t2_c", "garbage2", ".bak")
	var l2: Dictionary = Saves.load_slot("t2_c")
	ok(not l2["ok"] and str(l2["reason"]).begins_with("SAVE_ERR"), "unrecoverable reports an error")
	ok(FileAccess.file_exists(Saves.slot_path("t2_c")), "broken main file still on disk")
	ok(FileAccess.file_exists(Saves.slot_path("t2_c") + ".corrupt"), "and preserved as .corrupt")
	var listed := false
	for m in Saves.list_saves():
		if m["slot"] == "t2_c":
			listed = bool(m.get("corrupt", false))
	ok(listed, "listing flags the corrupt slot")
	_cleanup("t2_c")

func test_interrupted_save_is_atomic() -> void:
	var s := new_state()
	Saves.save_slot("t2_i", s)
	var before := FileAccess.get_file_as_string(Saves.slot_path("t2_i"))
	run_turns(s, 2)
	for mode in ["write", "rename", "truncate"]:
		Saves.test_fail = mode
		var r: Dictionary = Saves.save_slot("t2_i", s)
		Saves.test_fail = ""
		ok(not r["ok"], "%s failure reported" % mode)
		eq(FileAccess.get_file_as_string(Saves.slot_path("t2_i")), before, "%s failure leaves previous save byte-identical" % mode)
		ok(not FileAccess.file_exists(Saves.slot_path("t2_i") + ".tmp"), "%s failure leaves no temp file" % mode)
		var l: Dictionary = Saves.load_slot("t2_i")
		ok(l["ok"] and int(l["state"]["turn"]) == 0 and not l.get("recovered", false), "%s: previous save still loads" % mode)
	# a leftover half-written temp file (crash during write) is ignored and replaced
	_write_raw("t2_i", "{\"half", ".tmp")
	ok(Saves.save_slot("t2_i", s)["ok"], "save after a crashed write")
	ok(int(Saves.load_slot("t2_i")["state"]["turn"]) == 2, "new save is current")
	_cleanup("t2_i")

func test_bad_main_does_not_poison_backup() -> void:
	# a good save written twice keeps a good .bak
	var s := new_state()
	Saves.save_slot("t2_p", s)
	Saves.save_slot("t2_p", s)
	ok(Saves.load_slot("t2_p")["ok"], "main ok")
	var bak := Saves.slot_path("t2_p") + ".bak"
	ok(FileAccess.file_exists(bak), "backup exists")
	var jp: Variant = JSON.parse_string(FileAccess.get_file_as_string(bak))
	ok(jp is Dictionary and int((jp as Dictionary)["crc"]) == str((jp as Dictionary)["state_json"]).hash(), "backup passes its checksum")
	_cleanup("t2_p")

func test_migration_chain_v1_to_v4() -> void:
	var s := new_state()
	run_turns(s, 3)
	var old := Saves.export_state(s).duplicate(true)
	old["version"] = 1
	for k in ["pending_requests", "battle_log", "coalitions", "next_coalition_id", "flags", "econ", "rebel_hold"]:
		old.erase(k)
	for cid in old["countries"]:
		var c: Dictionary = old["countries"][cid]
		for k in ["esp", "fac", "eco", "dyn", "infamy", "war_exhaustion", "class_offsets", "victory_hold"]:
			c.erase(k)
	var body := JSON.stringify(old, "", false, true)
	_write_raw("t2_v1", JSON.stringify({"format": "imperium-save", "version": 1, "meta": {}, "crc": body.hash(), "len": body.length(), "state_json": body}))
	var l: Dictionary = Saves.load_slot("t2_v1")
	ok(l["ok"], "v1 save loads: %s %s" % [str(l.get("reason", "")), str(l.get("errors", ""))])
	if l["ok"]:
		var m: Dictionary = l["state"]
		eq(int(m["version"]), 4, "chain reaches v4")
		ok(m.has("econ") and m.has("coalitions") and m.has("pending_requests"), "v2/v3/v4 root fields present")
		var c: Dictionary = m["countries"][m["player"]]
		ok(c.has("esp") and c.has("fac") and c.has("eco") and c.has("dyn"), "v4 country state present")
		ok(c.has("infamy") and c.has("class_offsets"), "v2/v3 country fields present")
		ok(Saves.validate_state(m).is_empty(), "migrated state validates")
		ok(TurnManager.end_turn(m).get("ok", false), "migrated campaign keeps running")
	_cleanup("t2_v1")

func test_long_campaign_save_load_identical() -> void:
	# 150 turns uninterrupted vs 150 turns with two save/load cycles, on a v4 state (espionage/dynasty/factions/naval)
	var sc := "austerlitz"
	var a := new_state(sc, "", "normal", 4242)
	run_turns(a, 150)
	var b := new_state(sc, "", "normal", 4242)
	run_turns(b, 50)
	for part in 2:
		ok(Saves.save_slot("t2_long", b)["ok"], "save %d" % part)
		var l: Dictionary = Saves.load_slot("t2_long")
		ok(l["ok"], "load %d" % part)
		if not l["ok"]:
			return
		b = l["state"]
		run_turns(b, 50)
	var c: Dictionary = a["countries"][a["player"]]
	ok(c.has("esp") and c.has("dyn") and c.has("fac") and c.has("eco"), "state carries the v4 systems")
	eq(int(b["turn"]), int(a["turn"]), "same turn")
	eq(_hash(b), _hash(a), "150-turn campaign with save/load cycles is identical to the uninterrupted run")
	_cleanup("t2_long")

func test_lifecycle_autosave() -> void:
	var keep_state: Dictionary = Game.state
	var keep_in: bool = Game.in_campaign
	Game.state = new_state()
	Game.active_player = Game.state["player"]
	Game.in_campaign = true
	Game.state["turn"] = 11
	Saves.delete_slot("last")
	Game._notification(MainLoop.NOTIFICATION_APPLICATION_PAUSED)
	var l: Dictionary = Saves.load_slot("last")
	ok(l["ok"] and int(l["state"]["turn"]) == 11, "backgrounding writes an autosave")
	Saves.delete_slot("last")
	Game.turn_busy = true
	Game._notification(MainLoop.NOTIFICATION_APPLICATION_PAUSED)
	ok(not Saves.has_save("last"), "no save while a turn is resolving")
	Game.turn_busy = false
	Game._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	ok(Saves.has_save("last"), "close request writes an autosave")
	Saves.delete_slot("last")
	Game.state["game_over"] = true
	ok(not Game.lifecycle_autosave(), "no lifecycle save after game over")
	Game.in_campaign = false
	Game.state["game_over"] = false
	ok(not Game.lifecycle_autosave(), "no lifecycle save outside a campaign")
	Game.state = keep_state
	Game.in_campaign = keep_in
	Saves.delete_slot("last")

func test_hotseat_index_persisted() -> void:
	var keep_state: Dictionary = Game.state
	var def := scenario("early_modern")
	var cs: Array = []
	for c in GS.alive_countries(new_state()):
		if not str(c).begins_with("NAT_") and c != "REB":
			cs.append(c)
		if cs.size() == 3:
			break
	var r: Dictionary = Game.new_game("early_modern", cs[0], "normal", 5, cs)
	ok(r["ok"], "hotseat game")
	Game.end_turn()   # passes to player 2
	eq(Game.hotseat_index, 1, "now player 2")
	ok(Saves.save_slot("t2_hot", Game._state_for_save())["ok"], "mid-turn save")
	Game.end_turn()   # player 3
	var lr: Dictionary = Game.load_game("t2_hot")
	ok(lr["ok"], "load")
	eq(Game.hotseat_index, 1, "load resumes at the saved seat, not player 1")
	eq(Game.active_player, cs[1], "active player restored")
	ok(not Game.state.has("hotseat_index"), "transient key removed from live state")
	Game.end_turn()
	eq(Game.hotseat_index, 2, "turn order continues")
	Game.end_turn()
	eq(Game.hotseat_index, 0, "turn resolved, back to first seat")
	eq(int(Game.state["turn"]), 1, "exactly one turn resolved")
	_cleanup("t2_hot")
	Game.state = keep_state
	Game.in_campaign = false
