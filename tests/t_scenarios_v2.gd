extends TestCase
## Scenario reconstruction v2: ownership, capitals, rulers, names layer, claims, start dates, approximations.

const IDS: Array[String] = ["medieval_europe", "hundred_years_war", "fall_of_constantinople", "early_modern", "age_of_revolutions", "industrial_era", "world_conquest"]
const START := {"medieval_europe": [1066, 9], "hundred_years_war": [1337, 5], "fall_of_constantinople": [1453, 4], "early_modern": [1519, 6],
	"age_of_revolutions": [1789, 7], "industrial_era": [1871, 1], "world_conquest": [1900, 1]}
# [scenario, country, birth year, tolerance]: ruler age at the start date must match the documented birth year
const BIRTHS := [["medieval_europe", "ENG", 1022, 1], ["medieval_europe", "NRM", 1028, 1], ["medieval_europe", "NOR", 1015, 1], ["medieval_europe", "SEL", 1029, 2], ["medieval_europe", "ZIR", 1031, 1],
	["hundred_years_war", "ENG", 1312, 1], ["hundred_years_war", "FRA", 1293, 1], ["hundred_years_war", "CAS", 1311, 1], ["hundred_years_war", "SRB", 1308, 1],
	["fall_of_constantinople", "OTT", 1432, 1], ["fall_of_constantinople", "BYZ", 1405, 1], ["fall_of_constantinople", "ALB", 1405, 1], ["fall_of_constantinople", "ETH", 1399, 1], ["fall_of_constantinople", "TIM", 1422, 1],
	["early_modern", "SPA", 1500, 1], ["early_modern", "FRA", 1494, 1], ["early_modern", "ENG", 1491, 1], ["early_modern", "SAF", 1487, 1],
	["age_of_revolutions", "FRA", 1754, 1], ["age_of_revolutions", "GBR", 1738, 1], ["age_of_revolutions", "OTT", 1761, 1], ["age_of_revolutions", "SPA", 1748, 1],
	["industrial_era", "GBR", 1819, 1], ["industrial_era", "GER", 1797, 1], ["industrial_era", "JPN", 1852, 1], ["industrial_era", "ITA", 1820, 1],
	["world_conquest", "GBR", 1819, 1], ["world_conquest", "RUS", 1868, 1], ["world_conquest", "GER", 1859, 1]]
const NAME_CHECKS := [["fall_of_constantinople", "tur_constantinople", "Constantinople (besieged)"], ["medieval_europe", "rus_moscow", "Rostov-Suzdal"],
	["industrial_era", "can_british_columbia", "colony"], ["hundred_years_war", "rus_novgorod", "Novgorod"], ["medieval_europe", "chn_yunnan", "Dali"]]

func _built() -> Dictionary:
	var out := {}
	for id in IDS:
		out[id] = new_state(id)
	return out

func test_every_scenario_loads_and_validates() -> void:
	for id in IDS:
		var def := scenario(id)
		ok(not def.is_empty(), "%s exists" % id)
		var errs := ScenarioLoader.validate(def)
		ok(errs.is_empty(), "%s validate(): %s" % [id, str(errs.slice(0, 4))])
		var s := new_state(id)
		var verrs := Saves.validate_state(s)
		ok(verrs.is_empty(), "%s state valid: %s" % [id, str(verrs.slice(0, 3))])

func test_ownership_capitals_rulers() -> void:
	var built := _built()
	for id in IDS:
		var s: Dictionary = built[id]
		for pid in Defs.province_ids:
			var o: String = s["provinces"][pid]["owner"]
			ok(o != "" and s["countries"].has(o), "%s: %s has an owner" % [id, pid])
		var nat_generic := 0
		for cid in s["countries"]:
			if cid == "REB":
				continue
			var c: Dictionary = s["countries"][cid]
			if str(cid).begins_with("NAT_"):
				nat_generic += 1
			ok(bool(c["alive"]), "%s: %s alive" % [id, cid])
			ok(str(c["capital"]) != "" and Defs.provinces.has(c["capital"]) and s["provinces"][c["capital"]]["owner"] == cid, "%s: %s capital owned" % [id, cid])
			ok(str(c["ruler"]["name"]) != "" and str(c["ruler"]["name"]) != "Unknown" and int(c["ruler"]["age"]) > 0, "%s: %s has a ruler" % [id, cid])
			ok(c.has("approximate") and c.has("note"), "%s: %s carries the approximate flag" % [id, cid])
		eq(nat_generic, 0, "%s: no generic NAT_ filler left" % id)
		var heirs := 0
		for cid in s["countries"]:
			if cid != "REB" and s["countries"][cid]["heir"] != null:
				heirs += 1
		ok(heirs >= 8, "%s: at least 8 countries with heirs (%d)" % [id, heirs])

func test_country_counts_reasonable() -> void:
	for id in IDS:
		var def := scenario(id)
		ok((def["countries"] as Dictionary).size() <= 140, "%s keeps the country count mobile-friendly (%d)" % [id, (def["countries"] as Dictionary).size()])

func test_names_layer() -> void:
	var built := _built()
	for id in IDS:
		var s: Dictionary = built[id]
		ok((s["names"] as Dictionary).size() >= 20, "%s names layer filled (%d)" % [id, (s["names"] as Dictionary).size()])
	for chk in NAME_CHECKS:
		var s: Dictionary = built[chk[0]]
		var nm := Defs.province_name_in(s, chk[1])
		ok(nm.contains(chk[2]), "%s %s is named '%s' (got '%s')" % [chk[0], chk[1], chk[2], nm])
		ok(nm != str(Defs.provinces[chk[1]]["name"]), "%s %s differs from the modern name" % [chk[0], chk[1]])
	# an unknown id or a state without a names layer falls back to the modern name
	var keep: Dictionary = Game.state
	Game.state = {}   # Defs.province_name consults the active campaign; compare against the no-campaign name
	eq(Defs.province_name_in({}, "tur_constantinople"), Defs.province_name("tur_constantinople"), "empty state falls back")
	Game.state = keep
	# Turkish names and the default fallback
	var old_lang := Loc.lang
	Loc.lang = "tr"
	ok(Defs.province_name_in(built["fall_of_constantinople"], "tur_constantinople").contains("kuşatma"), "Turkish scenario name is used")
	Loc.lang = old_lang

func test_names_survive_save_load() -> void:
	var s := new_state("fall_of_constantinople")
	var back: Dictionary = Saves.migrate(JSON.parse_string(JSON.stringify(Saves.export_state(s))))
	eq(Defs.province_name_in(back, "tur_constantinople"), Defs.province_name_in(s, "tur_constantinople"), "names layer survives a JSON round trip")
	ok((back["geo_layer"] as Array).size() >= 1, "geo layer survives")

func test_claims_valid() -> void:
	for id in IDS:
		var def := scenario(id)
		var s := new_state(id)
		for cid in def.get("claims", {}):
			ok(s["countries"].has(cid), "%s claims: country %s exists" % [id, cid])
			for pat in def["claims"][cid]:
				var hit := false
				for pid in Defs.province_ids:
					if Util.glob_match(str(pat).lstrip("-"), pid):
						hit = true
						break
				ok(hit, "%s claims: pattern %s matches" % [id, pat])
		var claimed := 0
		for pid in s["provinces"]:
			for cid in s["provinces"][pid]["claims"]:
				ok(s["countries"].has(cid), "%s: claim holder %s exists" % [id, cid])
				ok(s["provinces"][pid]["owner"] != cid, "%s: %s does not claim its own province %s" % [id, cid, pid])
				claimed += 1
		ok(claimed > 5 or id == "world_conquest", "%s has claims" % id)

func test_start_dates_and_ages() -> void:
	for id in IDS:
		var def := scenario(id)
		eq(int(def["start"]["year"]), int(START[id][0]), "%s start year" % id)
		eq(int(def["start"]["month"]), int(START[id][1]), "%s start month" % id)
	for b in BIRTHS:
		var s := new_state(str(b[0]))
		var age := int(s["countries"][b[2 - 1]]["ruler"]["age"])
		var expected := int(START[b[0]][0]) - int(b[2])
		ok(absi(age - expected) <= int(b[3]), "%s %s ruler age %d vs birth-year age %d" % [b[0], b[1], age, expected])

func test_france_1871_leader() -> void:
	var s := new_state("industrial_era")
	ok(str(s["countries"]["FRA"]["ruler"]["name"]).contains("Trochu"), "Government of National Defence leads France in January 1871")

func test_overrides_exact_beats_glob() -> void:
	var over := {"sunni": ["tur_*"], "orthodox": ["tur_pontus"]}
	eq(ScenarioLoader._override_for(over, "tur_pontus"), "orthodox", "exact id wins over a glob")
	eq(ScenarioLoader._override_for(over, "tur_cilicia"), "sunni", "glob applies otherwise")
	eq(ScenarioLoader._override_for(over, "fra_loire"), "", "no match is empty")

func test_claims_removal_pattern() -> void:
	var def := scenario("medieval_europe").duplicate(true)
	def["claims"] = {"ENG": ["fra_*", "-fra_loire"]}
	var s := ScenarioLoader.build(def, "ENG", "normal", 5)
	ok("ENG" in s["provinces"]["fra_normandy"]["claims"], "glob claim applied")
	ok("ENG" not in s["provinces"]["fra_loire"]["claims"], "'-' removes a claim")

func test_sixty_turns_each_scenario_short() -> void:
	for id in IDS:
		var s := new_state(id)
		var t0 := Time.get_ticks_msec()
		var errs := run_turns(s, 6)
		ok(errs.is_empty(), "%s runs 6 turns" % id)
		print("      %s: %d countries, 6 turns %d ms" % [id, s["countries"].size() - 1, Time.get_ticks_msec() - t0])
