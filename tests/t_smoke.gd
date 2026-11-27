extends TestCase

func test_defs_loaded() -> void:
	ok(Defs.provinces.size() >= 150, "at least 150 provinces")
	ok(Defs.load_errors.is_empty(), "no data load errors: %s" % str(Defs.load_errors))
	ok(Defs.units.size() > 20 and Defs.techs.size() == 92 and Defs.buildings.size() > 15, "tables loaded")

func test_new_campaign() -> void:
	var s := new_state("early_modern")
	ok(s["countries"].size() > 20, "countries built")
	var errs := Saves.validate_state(s)
	ok(errs.is_empty(), "fresh state valid: %s" % str(errs.slice(0, 5)))

func test_ten_turns() -> void:
	var s := new_state("early_modern")
	var t0 := Time.get_ticks_msec()
	var errs := run_turns(s, 10)
	ok(errs.is_empty(), "ten turns run: %s" % str(errs))
	print("      10 turns: %d ms" % (Time.get_ticks_msec() - t0))
	eq(int(s["turn"]), 10, "turn counter advanced")

func test_all_scenarios_have_complete_ownership_and_names() -> void:
	for id in Defs.scenarios:
		var s := new_state(id)
		var unowned := 0
		for pid in s["provinces"]:
			if str(s["provinces"][pid]["owner"]) == "":
				unowned += 1
		eq(unowned, 0, "%s: every province has an owner" % id)
		ok((s["names"] as Dictionary).size() > 0, "%s: names layer present" % id)
