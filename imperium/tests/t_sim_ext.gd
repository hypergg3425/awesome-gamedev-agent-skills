extends TestCase
## v4 save format: round trip with the new state, v3 -> v4 migration, deterministic continuation with
## espionage / dynasty / faction activity, and 100-turn simulations of three scenarios.

func _norm_hash(s: Dictionary) -> int:
	var parsed: Variant = JSON.parse_string(JSON.stringify(Saves.export_state(s), "", false, true))
	return JSON.stringify(parsed, "", false, true).hash()

func _poke(s: Dictionary) -> void:
	var p := neighbour_pair(s, 2)
	s["countries"][p[0]]["gold"] = 3000.0
	EspionageSystem.build_network(s, p[0], p[1])
	EspionageSystem.raise_ci(s, p[1])
	FactionsSystem.st(s["countries"][p[0]])["f"]["nobility"]["loy"] = 12.0

func test_save_roundtrip_with_new_state() -> void:
	var s := new_state()
	_poke(s)
	run_turns(s, 5)
	ok(Saves.save_slot("t_v4", s)["ok"], "saved")
	var l: Dictionary = Saves.load_slot("t_v4")
	ok(l["ok"], "loaded %s" % str(l.get("reason", "")))
	if l["ok"]:
		eq(_norm_hash(l["state"]), _norm_hash(s), "identical")
		for k in ["esp", "dyn", "fac", "eco"]:
			ok(l["state"]["countries"][s["player"]].has(k), "country keeps %s" % k)
		ok(l["state"].has("econ") and l["state"].has("rebel_hold"), "world keeps econ and rebel_hold")
	Saves.delete_slot("t_v4")
	eq(Const.SAVE_VERSION, 4, "save version 4")

func test_migration_from_v3() -> void:
	var s := new_state()
	run_turns(s, 2)
	var old := Saves.export_state(s).duplicate(true)
	old["version"] = 3
	old.erase("econ")
	old.erase("rebel_hold")
	for cid in old["countries"]:
		for k in ["esp", "dyn", "fac", "eco"]:
			old["countries"][cid].erase(k)
	var m := Saves.migrate(old)
	eq(int(m["version"]), 4, "migrated")
	m["_c"] = {}
	GS.rebuild_caches(m)
	ok(Saves.validate_state(m).is_empty(), "migrated state validates: %s" % str(Saves.validate_state(m).slice(0, 3)))
	run_turns(m, 3)
	ok(Saves.validate_state(m).is_empty(), "and runs")
	ok(m["countries"][m["player"]]["dyn"]["init"], "royal families are generated on first use")

func test_determinism_continuation_with_new_systems() -> void:
	var a := new_state("early_modern", "", "normal", 123)
	_poke(a)
	run_turns(a, 16)
	var b := new_state("early_modern", "", "normal", 123)
	_poke(b)
	run_turns(b, 8)
	Saves.save_slot("t_cont4", b)
	var l: Dictionary = Saves.load_slot("t_cont4")
	ok(l["ok"], "loaded")
	run_turns(l["state"], 8)
	eq(_norm_hash(l["state"]), _norm_hash(a), "a reloaded campaign continues identically")
	Saves.delete_slot("t_cont4")

func _soak(id: String, seed_v: int) -> void:
	var s := new_state(id, "", "normal", seed_v)
	s["players"] = []
	for chunk in 4:
		run_turns(s, 25)
		var errs := Saves.validate_state(s)
		ok(errs.is_empty(), "%s valid after %d turns: %s" % [id, (chunk + 1) * 25, str(errs.slice(0, 3))])
	for cid in GS.alive_countries(s):
		var c: Dictionary = s["countries"][cid]
		for k in ["gold", "debt", "stability", "legitimacy", "inflation"]:
			ok(not is_nan(float(c[k])) and not is_inf(float(c[k])), "%s %s finite" % [cid, k])
		var inc := maxf(50.0, float(c.get("budget", {}).get("income", 0.0)))
		ok(float(c["gold"]) < inc * 80.0 + 4000.0, "%s treasury %.0f not runaway" % [cid, float(c["gold"])])
		ok(float(c["debt"]) < 20000.0, "%s debt bounded" % cid)

func test_soak_medieval() -> void:
	_soak("medieval_europe", 3)

func test_soak_early_modern() -> void:
	_soak("early_modern", 4)

func test_soak_industrial() -> void:
	_soak("industrial_era", 5)
