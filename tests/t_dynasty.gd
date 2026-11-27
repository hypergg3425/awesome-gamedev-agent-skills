extends TestCase
## Dynasties: succession laws, heir quality, regency, death, marriages, claims, unions, disputes.

func _monarchy(s: Dictionary, gov: String = "absolute_monarchy") -> String:
	for cid in GS.alive_countries(s):
		var c: Dictionary = s["countries"][cid]
		if str(c["gov"]) == gov and not bool(c.get("native", false)):
			return cid
	# make one
	for cid in GS.alive_countries(s):
		var c2: Dictionary = s["countries"][cid]
		if not bool(c2.get("native", false)):
			c2["gov"] = gov
			DynastySystem.st(c2)["law"] = DynastySystem.law_of(gov)
			DynastySystem.init_country(s, cid)
			return cid
	return ""

func _royal(id: int, name: String, age: float, sex: String, rel: String) -> Dictionary:
	return {"id": id, "name": name, "age": age, "sex": sex, "adm": 6, "dip": 6, "mil": 6, "health": 90.0, "rel": rel, "spouse": null}

func _set_family(c: Dictionary, royals: Array) -> void:
	var d := DynastySystem.st(c)
	d["royals"] = royals
	d["next_id"] = 100
	d["crisis"] = null
	DynastySystem.refresh_heir(c)

func test_hereditary_countries_have_a_family() -> void:
	var s := new_state()
	var n := 0
	for cid in GS.alive_countries(s):
		var c: Dictionary = s["countries"][cid]
		var d := DynastySystem.st(c)
		if DynastySystem.is_hereditary(c) and not bool(c.get("native", false)):
			n += 1
			ok(d["name"] != "", "%s has a dynasty name" % cid)
			ok(c["ruler"].has("health") and c["ruler"].has("sex"), "%s ruler has health" % cid)
			ok((d["royals"] as Array).size() >= 1, "%s has royals" % cid)
			ok(d["consort"] != null, "%s has a consort" % cid)
	ok(n >= 5, "many hereditary realms (%d)" % n)

func test_laws_follow_government() -> void:
	eq(DynastySystem.law_of("absolute_monarchy"), "agnatic", "absolute monarchy is agnatic")
	eq(DynastySystem.law_of("constitutional_monarchy"), "cognatic", "constitutional monarchy is cognatic")
	eq(DynastySystem.law_of("empire"), "designated", "empire designates")
	eq(DynastySystem.law_of("feudal_kingdom"), "agnatic", "feudal kingdom is agnatic")
	eq(DynastySystem.law_of("republic"), "elective", "republic elects")

func test_agnatic_excludes_women_cognatic_does_not() -> void:
	var s := new_state()
	var cid := _monarchy(s)
	var c: Dictionary = s["countries"][cid]
	_set_family(c, [_royal(1, "Anna", 12.0, "f", "child"), _royal(2, "Karl", 30.0, "m", "sibling")])
	eq(str(c["heir"]["name"]), "Karl", "the agnatic heir is the brother, not the daughter")
	DynastySystem.st(c)["law"] = "cognatic"
	DynastySystem.refresh_heir(c)
	eq(str(c["heir"]["name"]), "Anna", "cognatic law puts the child first")

func test_eldest_child_first_and_heir_quality_from_parents() -> void:
	var s := new_state()
	var cid := _monarchy(s, "constitutional_monarchy")
	var c: Dictionary = s["countries"][cid]
	_set_family(c, [_royal(1, "Young", 5.0, "m", "child"), _royal(2, "Old", 17.0, "m", "child"), _royal(3, "Bro", 40.0, "m", "sibling")])
	eq(str(c["heir"]["name"]), "Old", "primogeniture: the eldest child")
	var line := DynastySystem.line_of_succession(c)
	eq(str(line[2]["name"]), "Bro", "siblings follow children")
	var good := 0.0
	var bad := 0.0
	var rng := GS.rng_of(s)
	var d := DynastySystem.st(c)
	c["ruler"]["adm"] = 9
	c["ruler"]["dip"] = 9
	c["ruler"]["mil"] = 9
	for i in 60:
		var r := DynastySystem._new_royal(s, cid, d, rng, 0.0, "child", 9.0)
		good += DynastySystem.quality(r)
	for i in 60:
		var r2 := DynastySystem._new_royal(s, cid, d, rng, 0.0, "child", 3.0)
		bad += DynastySystem.quality(r2)
	ok(good > bad + 60.0, "children of able rulers are more able")

func test_death_chance_rises_with_age_and_frailty() -> void:
	ok(DynastySystem.death_chance(30.0, 90.0, 0.0) < DynastySystem.death_chance(65.0, 90.0, 0.0), "age raises the risk")
	ok(DynastySystem.death_chance(65.0, 90.0, 0.0) < DynastySystem.death_chance(80.0, 90.0, 0.0), "old age raises it again")
	ok(DynastySystem.death_chance(50.0, 90.0, 0.0) < DynastySystem.death_chance(50.0, 20.0, 0.0), "frailty raises the risk")
	ok(DynastySystem.death_chance(50.0, 50.0, 0.5) < DynastySystem.death_chance(50.0, 50.0, 0.0), "medicine protects")

func test_ruler_death_passes_the_crown() -> void:
	var s := new_state()
	var cid := _monarchy(s)
	var c: Dictionary = s["countries"][cid]
	_set_family(c, [_royal(1, "Heir", 24.0, "m", "child")])
	c["legitimacy"] = 90.0
	var old := str(c["ruler"]["name"])
	PoliticsSystem.ruler_dies(s, cid, GS.rng_of(s))
	eq(str(c["ruler"]["name"]), "Heir", "the heir becomes ruler")
	ok(str(c["ruler"]["name"]) != old, "the ruler changed")
	eq(int(c["regency"]), 0, "an adult needs no regent")

func test_minor_heir_means_regency_with_a_regent() -> void:
	var s := new_state()
	var cid := _monarchy(s)
	var c: Dictionary = s["countries"][cid]
	_set_family(c, [_royal(1, "Boy", 6.0, "m", "child"), _royal(2, "Uncle", 38.0, "m", "sibling")])
	c["legitimacy"] = 95.0
	PoliticsSystem.ruler_dies(s, cid, GS.rng_of(s))
	ok(int(c["regency"]) > 20, "a six-year-old needs a long regency (%d)" % int(c["regency"]))
	var d := DynastySystem.st(c)
	ok(d["regent"] is Dictionary, "a regent governs")
	var eff := DynastySystem.effective_ruler(c)
	ok(int(eff["adm"]) <= int(d["regent"]["adm"]), "the regent's skills apply, a little weaker")
	Mods.invalidate(s)
	var has_cost := false
	DynastySystem._update_regency(s, cid, c, d)
	for tm in c["temp_mods"]:
		if tm["key"] == "regency":
			has_cost = true
	ok(has_cost, "regency has a real cost")
	# the regency ends as the ruler grows up
	c["ruler"]["age"] = 15.9
	DynastySystem._update_regency(s, cid, c, d)
	ok(int(c["regency"]) > 0, "still a regency at 15.9")
	c["ruler"]["age"] = 16.5
	DynastySystem._update_regency(s, cid, c, d)
	eq(int(c["regency"]), 0, "the regency ends at majority")

func test_incapacitated_ruler_needs_a_regent() -> void:
	var s := new_state()
	var cid := _monarchy(s)
	var c: Dictionary = s["countries"][cid]
	var d := DynastySystem.st(c)
	c["ruler"]["ill"] = true
	DynastySystem._update_regency(s, cid, c, d)
	ok(int(c["regency"]) > 0, "illness means regency")
	c["ruler"]["ill"] = false
	DynastySystem._update_regency(s, cid, c, d)
	eq(int(c["regency"]), 0, "recovery ends it")

func test_extinct_dynasty_starts_a_legitimacy_crisis() -> void:
	var s := new_state()
	var cid := _monarchy(s)
	var c: Dictionary = s["countries"][cid]
	_set_family(c, [])
	DynastySystem.st(c)["marriages"] = []
	c["legitimacy"] = 80.0
	var name0 := str(DynastySystem.st(c)["name"])
	PoliticsSystem.ruler_dies(s, cid, GS.rng_of(s))
	ok(float(c["legitimacy"]) < 60.0, "legitimacy collapses (%.0f)" % float(c["legitimacy"]))
	ok(str(DynastySystem.st(c)["name"]) != name0, "a new dynasty")
	ok(c["heir"] != null, "and a fresh heir")

func test_royal_marriage_ties_houses() -> void:
	var s := new_state()
	var p := neighbour_pair(s, 1)
	var a: String = p[0]
	var b: String = p[1]
	for cid in [a, b]:
		s["countries"][cid]["gov"] = "absolute_monarchy"
		DynastySystem.st(s["countries"][cid])["law"] = "agnatic"
		DynastySystem.init_country(s, cid)
	_set_family(s["countries"][a], [_royal(1, "Princess", 20.0, "f", "sibling")])
	_set_family(s["countries"][b], [_royal(2, "Prince", 22.0, "m", "sibling")])
	GS.add_opinion(s, b, a, 120.0)
	var op0 := GS.opinion(s, a, b)
	var chk := DynastySystem.can_propose_marriage(s, a, b, 1)
	ok(chk["ok"], "proposal possible")
	var r := DynastySystem.propose_marriage(s, a, b, 1)
	ok(r["ok"] and r["accepted"], "the match is accepted (%s)" % str(r.get("eval", {}).get("score", "")))
	ok(DynastySystem.married(s, a, b) and DynastySystem.married(s, b, a), "both houses record it")
	ok(GS.opinion(s, a, b) > op0, "opinion rises")
	eq(DynastySystem.can_propose_marriage(s, a, b, 1)["reason"], "DYN_ERR_MARRIED", "the houses are now joined")
	# dynastic ties help an alliance
	var ev := DiplomacySystem.evaluate(s, "alliance", a, b, {})
	var has := false
	for rr in ev["reasons"]:
		if rr["key"] == "DR_DYNASTIC_TIES":
			has = true
	ok(has, "an alliance evaluation counts dynastic ties")

func test_marriage_refused_when_disliked() -> void:
	var s := new_state()
	var p := neighbour_pair(s, 1)
	var a: String = p[0]
	var b: String = p[1]
	for cid in [a, b]:
		s["countries"][cid]["gov"] = "absolute_monarchy"
		DynastySystem.init_country(s, cid)
	_set_family(s["countries"][a], [_royal(1, "Princess", 20.0, "f", "sibling")])
	_set_family(s["countries"][b], [_royal(2, "Prince", 22.0, "m", "sibling")])
	GS.add_opinion(s, b, a, -190.0)
	s["countries"][b]["religion"] = "sunni"
	s["countries"][a]["religion"] = "catholic"
	var r := DynastySystem.propose_marriage(s, a, b, 1)
	ok(r["ok"] and not r["accepted"], "a hated suitor is refused")

func test_republics_cannot_marry() -> void:
	var s := new_state()
	var rep := _monarchy(s, "republic")
	var mon := _monarchy(s, "absolute_monarchy")
	eq(DynastySystem.can_propose_marriage(s, mon, rep, 1)["reason"], "DYN_ERR_NO_DYNASTY", "both must be hereditary")

func test_inheritance_by_marriage_creates_a_personal_union() -> void:
	var s := new_state()
	var p := neighbour_pair(s, 1)
	var a: String = p[0]
	var b: String = p[1]
	for cid in [a, b]:
		s["countries"][cid]["gov"] = "absolute_monarchy"
		DynastySystem.init_country(s, cid)
	_set_family(s["countries"][a], [_royal(1, "Princess", 20.0, "f", "sibling")])
	_set_family(s["countries"][b], [_royal(2, "Prince", 22.0, "m", "sibling")])
	DynastySystem.marry(s, a, DynastySystem.royal_by_id(s["countries"][a], 1), b, DynastySystem.royal_by_id(s["countries"][b], 2))
	_set_family(s["countries"][a], [])
	GS.at_war(s, a, b)
	PoliticsSystem.ruler_dies(s, a, GS.rng_of(s))
	eq(str(s["countries"][a].get("union_with", "")), b, "the realm falls to the spouse's house")
	eq(GS.overlord_of(s, a), b, "as a personal union")
	eq(str(DynastySystem.st(s["countries"][a])["name"]), str(DynastySystem.st(s["countries"][b])["name"]), "under the new dynasty")

func test_succession_dispute_and_resolution() -> void:
	var s := new_state()
	var cid := _monarchy(s)
	var c: Dictionary = s["countries"][cid]
	_set_family(c, [_royal(1, "Boy", 5.0, "m", "child"), _royal(2, "Uncle", 38.0, "m", "sibling")])
	c["legitimacy"] = 20.0
	var risk := DynastySystem.dispute_risk(s, cid, c, DynastySystem.st(c), {"age": 5.0, "adm": 3, "dip": 3, "mil": 3})
	ok(risk > 0.35, "a weak child on a shaky throne invites a dispute (%.2f)" % risk)
	var safe := DynastySystem.dispute_risk(s, cid, c, DynastySystem.st(c), {"age": 30.0, "adm": 7, "dip": 7, "mil": 7})
	ok(safe < risk, "an adult able heir is safer")
	# force a dispute and resolve it both ways
	var d := DynastySystem.st(c)
	d["crisis"] = {"rival": _royal(2, "Uncle", 38.0, "m", "sibling"), "start": 0, "ends": 99, "foreign": ""}
	c["gold"] = 5000.0
	var buy := DynastySystem.buy_off_rival(s, cid)
	ok(buy["ok"], "the rival's backers can be bought off")
	ok(d["crisis"] == null, "the dispute ends")
	var ruler0 := str(c["ruler"]["name"])
	d["crisis"] = {"rival": _royal(2, "Uncle", 38.0, "m", "sibling"), "start": 0, "ends": 99, "foreign": ""}
	DynastySystem.resolve_crisis(s, cid, false, GS.rng_of(s))
	eq(str(c["ruler"]["name"]), "Uncle", "a lost dispute puts the rival on the throne")
	ok(str(c["ruler"]["name"]) != ruler0, "ruler changed")
	var exiled := false
	for r in d["royals"]:
		if str(r["name"]) == ruler0:
			exiled = true
	ok(exiled, "the deposed ruler becomes a pretender in the family")

func test_dispute_hurts_the_realm_until_resolved() -> void:
	var s := new_state()
	var cid := _monarchy(s)
	var c: Dictionary = s["countries"][cid]
	var d := DynastySystem.st(c)
	d["crisis"] = {"rival": _royal(2, "Uncle", 38.0, "m", "sibling"), "start": int(s["turn"]), "ends": int(s["turn"]) + 8, "foreign": ""}
	var leg := float(c["legitimacy"])
	DynastySystem._process_crisis(s, cid, c, d, GS.rng_of(s))
	ok(float(c["legitimacy"]) < leg, "legitimacy bleeds")
	var has := false
	for tm in c["temp_mods"]:
		if tm["key"] == "succession_dispute":
			has = true
	ok(has, "unrest and lower taxes during the dispute")

func test_designated_heir_in_empires() -> void:
	var s := new_state()
	var cid := _monarchy(s, "empire")
	var c: Dictionary = s["countries"][cid]
	c["admin"] = 200.0
	_set_family(c, [_royal(1, "Eldest", 30.0, "m", "child"), _royal(2, "Able", 20.0, "f", "child")])
	var r := DynastySystem.designate(s, cid, 2)
	ok(r["ok"], "designation possible")
	eq(str(c["heir"]["name"]), "Able", "the designated successor leads the line")
	var s2 := new_state()
	var cid2 := _monarchy(s2, "absolute_monarchy")
	_set_family(s2["countries"][cid2], [_royal(1, "A", 30.0, "m", "child")])
	eq(DynastySystem.designate(s2, cid2, 1)["reason"], "DYN_ERR_LAW", "other laws do not allow it")

func test_throne_claims_expire() -> void:
	var s := new_state()
	var p := neighbour_pair(s, 2)
	var a: String = p[0]
	var b: String = p[1]
	DynastySystem._grant_claims(s, a, b, 4)
	var granted: Array = DynastySystem.st(s["countries"][a])["claims"][0]["pids"]
	ok(granted.size() > 0, "claims on the realm's provinces")
	for pid in granted:
		ok(a in s["provinces"][pid]["claims"], "claim recorded")
	s["turn"] = int(s["turn"]) + 10
	DynastySystem._expire_claims(s, a, DynastySystem.st(s["countries"][a]))
	var left := 0
	for pid in granted:
		if a in s["provinces"][pid]["claims"]:
			left += 1
	eq(left, 0, "claims lapse")

func test_hundred_turns_keep_families_valid() -> void:
	var s := new_state("early_modern", "", "normal", 77)
	s["players"] = []
	run_turns(s, 100)
	var deaths := 0
	for cid in GS.alive_countries(s):
		var c: Dictionary = s["countries"][cid]
		deaths += int(c["stats"].get("rulers", 0))
		for r in DynastySystem.st(c)["royals"]:
			ok(float(r["age"]) < 110.0 and float(r["health"]) >= 0.0, "%s royal sane" % cid)
	ok(deaths >= 3, "rulers die and are replaced over 25 years (%d)" % deaths)
	var errs := Saves.validate_state(s)
	ok(errs.is_empty(), "state valid: %s" % str(errs.slice(0, 3)))
