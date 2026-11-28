extends TestCase
## Scenario editor model (ScenarioModel): build, validate, save, reload, play 20 turns. No UI nodes.

func _build() -> ScenarioModel:
	var m := ScenarioModel.blank()
	var tags: Array = m.def["countries"].keys()
	# a third country from provinces of the first two, with every editable aspect touched
	var take: Array = m.provinces_of(tags[0]).slice(0, 2)
	for pid in take:
		m.assign(pid, "")
	var c := m.add_country("Third Realm", "Üçüncü Diyar", Color("2f8f4f"), take, take[0])
	m.set_name(c, "Third Realm", "Üçüncü Diyar")
	m.set_color(c, Color("2f8f4f"))
	m.set_field(c, "gov", "republic")
	m.set_field(c, "religion", "orthodox")
	m.set_field(c, "ai", "defensive")
	m.set_ruler(c, "Doge Marin", 7, 6, 4)
	m.set_treasury(c, 640.0)
	m.set_stability(c, 70.0)
	m.set_regiments(c, 5, "spearmen")
	m.add_army(c, take[0], {"spearmen": 2.0})
	m.add_relation("alliances", tags[0], tags[1])
	m.add_relation("trade", c, tags[1])
	m.set_opinion(c, tags[0], 25)
	m.set_dates(1450, 4, 80)
	m.add_objective({"id": "o1", "type": "provinces_count", "count": 6, "by_turn": 40, "score": 100, "name": {"en": "Grow", "tr": "Büyü"}, "desc": {"en": "Six provinces.", "tr": "Altı eyalet."}})
	m.set_province_name(take[0], "Old Town (1450)", "Eski Kasaba (1450)")
	m.def["id"] = "t_editor2_scn"
	m.def["name"] = {"en": "Editor Test", "tr": "Editör Testi"}
	return m

func test_build_validate_save_reload_and_play() -> void:
	var m := _build()
	var errs := m.validate()
	ok(errs.is_empty(), "scenario validates: %s" % str(errs))
	eq(m.def["countries"].size(), 3, "three countries")
	eq(m.regiments(m.def["countries"].keys()[2]), 7, "regiments total")
	var r := m.save("user://t_editor2")
	ok(r["ok"], "saved")
	var out: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(r["path"]))
	eq(str(out["map_set"]), Defs.map_set, "map_set written")
	ok(not out.has("custom"), "editor-only flag not persisted")
	eq(str(out["province_names"].values()[0]["tr"]), "Eski Kasaba (1450)", "historical name stored")
	eq(int(out["start"]["year"]), 1450, "dates stored")
	var m2 := ScenarioModel.load_file(r["path"])
	ok(m2 != null, "reloaded")
	eq(m2.owners.size(), m.owners.size(), "ownership round-trips")
	eq(m2.def["countries"]["C03"]["gov"], "republic", "government round-trips")
	near(float(m2.def["countries"]["C03"]["treasury"]), 640.0, 0.01, "starting resources round-trip")
	ok(m2.validate().is_empty(), "reloaded model validates")
	# play it
	var def: Dictionary = m2.export()
	var s := ScenarioLoader.build(def, str(def["default_player"]), "normal", 11)
	ok(Saves.validate_state(s).is_empty(), "state from the edited scenario is valid")
	eq(str(s["names"].get(m.def["countries"]["C03"]["provinces"][0], {}).get("en", "")), "Old Town (1450)", "province name layer reaches the game state")
	near(float(s["countries"]["C03"]["gold"]), 640.0, 0.01, "treasury applied")
	ok(GS.allied(s, "C01", "C02"), "alliance applied")
	eq(int(s["start_year"]), 1450, "start date applied")
	eq(run_turns(s, 20).size(), 0, "20 turns run")
	eq(int(s["turn"]), 20, "turn counter")
	ok(Saves.validate_state(s).is_empty(), "state valid after 20 turns")
	DirAccess.remove_absolute(r["path"])
	DirAccess.remove_absolute("user://t_editor2")

func test_validation_catches_errors() -> void:
	var m := ScenarioModel.blank()
	m.def["default_player"] = "ZZZ"
	ok("ED_ERR_NO_PLAYER" in m.validate(), "missing default player")
	m = ScenarioModel.blank()
	m.set_name("C01", "", "x")
	var errs := m.validate()
	var found := false
	for e in errs:
		if str(e).begins_with("ED_ERR_EMPTY_NAME"):
			found = true
	ok(found, "empty name")
	m = ScenarioModel.blank()
	m.remove_country("C02")
	ok("ED_ERR_TWO_COUNTRIES" in m.validate(), "needs two countries")
	m = ScenarioModel.blank()
	m.set_province_name("no_such_province", "A", "B")
	var bad := false
	for e in m.validate():
		if str(e).begins_with("ED_ERR_BAD_PROVINCE_NAME"):
			bad = true
	ok(bad, "bad province in the name layer")
	ok(not m.save("user://t_editor2")["ok"], "invalid scenario is not saved")

func test_assign_repairs_capitals_and_removal_cleans_relations() -> void:
	var m := ScenarioModel.blank()
	var cap: String = m.def["countries"]["C01"]["capital"]
	m.assign(cap, "C02")
	ok(m.def["countries"]["C01"]["capital"] != cap and m.def["countries"]["C01"]["capital"] != "", "old owner gets a new capital")
	m.add_relation("alliances", "C01", "C02")
	m.add_relation("wars", "C02", "C01")
	m.remove_country("C02")
	eq((m.def["relations"].get("alliances", []) as Array).size(), 0, "alliance dropped")
	eq((m.def["relations"].get("wars", []) as Array).size(), 0, "war dropped")
	ok(not m.owners.values().has("C02"), "provinces released")

func test_import_loader_interface_is_a_documented_stub() -> void:
	var l := MapImportLoader.new()
	ok(not l.load_table("x")["ok"] and l.load_table("x")["reason"] == "IMPORT_NOT_SUPPORTED", "base loader reports unsupported")
	ok(not l.load_polygons("x")["ok"], "polygons unsupported")
	ok(MapImportLoader.validate_table([]).is_empty(), "empty table passes structurally")
	ok(not MapImportLoader.validate_table([{"id": "a", "neighbors": ["b"]}]).is_empty(), "incomplete table rejected")
