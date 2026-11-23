extends TestCase

func _norm_hash(s: Dictionary) -> int:
	# compare through a JSON round trip so int/float representation differences do not matter
	var txt := JSON.stringify(Saves.export_state(s), "", false, true)
	var parsed: Variant = JSON.parse_string(txt)
	return JSON.stringify(parsed, "", false, true).hash()

func test_roundtrip_preserves_state() -> void:
	var s := new_state()
	run_turns(s, 6)
	var r: Dictionary = Saves.save_slot("t_roundtrip", s)
	ok(r["ok"], "saved")
	var l: Dictionary = Saves.load_slot("t_roundtrip")
	ok(l["ok"], "loaded: %s" % str(l.get("reason", "")))
	if l["ok"]:
		eq(_norm_hash(l["state"]), _norm_hash(s), "loaded state equals saved state")
		eq(int(l["state"]["turn"]), 6, "turn preserved")
		eq(l["state"]["player"], s["player"], "player preserved")
	Saves.delete_slot("t_roundtrip")

func test_continuation_matches_uninterrupted_run() -> void:
	var a := new_state("early_modern", "", "normal", 321)
	run_turns(a, 14)
	var b := new_state("early_modern", "", "normal", 321)
	run_turns(b, 7)
	Saves.save_slot("t_cont", b)
	var l: Dictionary = Saves.load_slot("t_cont")
	ok(l["ok"], "load for continuation")
	var b2: Dictionary = l["state"]
	run_turns(b2, 7)
	if _norm_hash(b2) != _norm_hash(a):
		for pair in [["/tmp/claude-0/orig.json", a], ["/tmp/claude-0/loaded.json", b2]]:
			var f := FileAccess.open(pair[0], FileAccess.WRITE)
			f.store_string(JSON.stringify(JSON.parse_string(JSON.stringify(Saves.export_state(pair[1]), "", false, true)), "  ", false, true))
			f.close()
	eq(_norm_hash(b2), _norm_hash(a), "a saved campaign continues with the same strategic state")
	Saves.delete_slot("t_cont")

func test_state_contains_everything() -> void:
	var s := new_state()
	run_turns(s, 3)
	for k in ["turn", "start_year", "player", "countries", "provinces", "armies", "wars", "relations", "events", "objectives", "history", "ai", "market", "stats"]:
		ok(s.has(k), "state has %s" % k)
	var c: Dictionary = s["countries"][s["player"]]
	for k in ["gold", "stock", "researched", "reforms", "classes", "gov", "ruler", "stats", "flags"]:
		ok(c.has(k), "country has %s" % k)
	var pid: String = GS.owned(s, s["player"])[0]
	for k in ["owner", "pop", "buildings", "queue", "culture", "religion", "unrest"]:
		ok(s["provinces"][pid].has(k), "province has %s" % k)

func test_corruption_is_detected_and_backup_recovers() -> void:
	var s := new_state()
	Saves.save_slot("t_corrupt", s)
	run_turns(s, 2)
	Saves.save_slot("t_corrupt", s)    # creates a .bak of the first
	# damage the main file
	var f := FileAccess.open(Saves.slot_path("t_corrupt"), FileAccess.WRITE)
	f.store_string("{ this is not a save")
	f.close()
	var l: Dictionary = Saves.load_slot("t_corrupt")
	ok(l["ok"] and l.get("recovered", false), "falls back to the backup")
	ok(FileAccess.file_exists(Saves.slot_path("t_corrupt") + ".corrupt"), "corrupt file is kept, not silently discarded")
	# both broken -> explicit failure
	var f2 := FileAccess.open(Saves.slot_path("t_corrupt") + ".bak", FileAccess.WRITE)
	f2.store_string("garbage")
	f2.close()
	var l2: Dictionary = Saves.load_slot("t_corrupt")
	ok(not l2["ok"], "unrecoverable save reports failure")
	ok(str(l2["reason"]).begins_with("SAVE_ERR"), "with an error key")
	Saves.delete_slot("t_corrupt")
	DirAccess.remove_absolute(Saves.slot_path("t_corrupt") + ".corrupt")

func test_checksum_detects_tampering() -> void:
	var s := new_state()
	Saves.save_slot("t_tamper", s)
	var txt := FileAccess.get_file_as_string(Saves.slot_path("t_tamper"))
	var parsed: Dictionary = JSON.parse_string(txt)
	var body: String = parsed["state_json"]
	var at := body.find("\"turn\":0")
	parsed["state_json"] = body.substr(0, at) + "\"turn\":9" + body.substr(at + 8)
	var f := FileAccess.open(Saves.slot_path("t_tamper"), FileAccess.WRITE)
	f.store_string(JSON.stringify(parsed))
	f.close()
	var l: Dictionary = Saves.load_slot("t_tamper")
	ok(not l["ok"], "modified save fails verification")
	Saves.delete_slot("t_tamper")
	DirAccess.remove_absolute(Saves.slot_path("t_tamper") + ".corrupt")

func test_migration_from_old_versions() -> void:
	var s := new_state()
	var old := Saves.export_state(s).duplicate(true)
	old["version"] = 1
	old.erase("pending_requests")
	old.erase("battle_log")
	old.erase("coalitions")
	old.erase("next_coalition_id")
	var m := Saves.migrate(old)
	eq(int(m["version"]), Const.SAVE_VERSION, "migrated to the current version")
	ok(m.has("pending_requests") and m.has("coalitions") and m.has("battle_log"), "new fields added")
	m["_c"] = {}
	GS.rebuild_caches(m)
	ok(Saves.validate_state(m).is_empty(), "migrated save validates")
	# a newer save is refused rather than mangled
	var newer := Saves.export_state(s).duplicate(true)
	newer["version"] = Const.SAVE_VERSION + 5
	var body := JSON.stringify(newer)
	var f := FileAccess.open(Saves.slot_path("t_newer"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": Const.SAVE_VERSION + 5, "crc": body.hash(), "len": body.length(), "state_json": body, "meta": {}}))
	f.close()
	var l: Dictionary = Saves.load_slot("t_newer")
	eq(l.get("reason", ""), "SAVE_ERR_NEWER", "newer save refused")
	Saves.delete_slot("t_newer")
	DirAccess.remove_absolute(Saves.slot_path("t_newer") + ".corrupt")

func test_slots_listing_and_deletion() -> void:
	var s := new_state()
	Saves.save_slot("t_slot_a", s)
	Saves.save_slot("t_slot_b", s)
	var found := 0
	for m in Saves.list_saves():
		if str(m["slot"]).begins_with("t_slot_"):
			found += 1
			ok(m.has("turn") and m.has("scenario"), "metadata present")
	eq(found, 2, "both slots listed")
	Saves.delete_slot("t_slot_a")
	ok(not Saves.has_save("t_slot_a"), "slot deleted")
	Saves.delete_slot("t_slot_b")

func test_autosave_rotates() -> void:
	var s := new_state()
	for t in 5:
		s["turn"] = t
		Saves.autosave(s)
	ok(Saves.has_save("auto_1") and Saves.has_save("auto_2") and Saves.has_save("auto_3"), "three rotating autosaves")
	ok(Saves.has_save("last"), "continue slot")

func test_determinism_same_seed_same_world() -> void:
	var a := new_state("early_modern", "", "normal", 555)
	var b := new_state("early_modern", "", "normal", 555)
	run_turns(a, 12)
	run_turns(b, 12)
	eq(state_hash(a), state_hash(b), "same seed -> identical campaign")
	var c := new_state("early_modern", "", "normal", 556)
	run_turns(c, 12)
	ok(state_hash(a) != state_hash(c), "different seed -> different campaign")
