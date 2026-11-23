extends TestCase

func _pair() -> Array:
	var s := new_state()
	var p := neighbour_pair(s, 2)
	return [s, p[0], p[1]]

func test_alliance_acceptance_depends_on_opinion_and_reasons() -> void:
	var a := _pair()
	var s: Dictionary = a[0]
	var x: String = a[1]
	var y: String = a[2]
	GS.rel(s, x, y)["op"][y] = -150.0
	var low := DiplomacySystem.evaluate(s, "alliance", x, y)
	ok(not low["accept"], "hostile nation refuses an alliance")
	ok((low["reasons"] as Array).size() >= 3, "UI gets a breakdown of reasons")
	GS.rel(s, x, y)["op"][y] = 120.0
	s["countries"][y]["religion"] = s["countries"][x]["religion"]
	var high := DiplomacySystem.evaluate(s, "alliance", x, y)
	ok(float(high["score"]) > float(low["score"]) + 20.0, "opinion changes the score")
	ok(high["accept"] or float(high["score"]) > 10.0, "friendly nation is receptive (score %.1f)" % float(high["score"]))

func test_alliance_formation_and_break_penalties() -> void:
	var a := _pair()
	var s: Dictionary = a[0]
	var x: String = a[1]
	var y: String = a[2]
	GS.rel(s, x, y)["op"][y] = 180.0
	GS.rel(s, x, y)["op"][x] = 180.0
	s["countries"][y]["religion"] = s["countries"][x]["religion"]
	s["ai"][y]["personality"] = "diplomatic"
	var r := DiplomacySystem.perform(s, "alliance", x, y)
	ok(r["ok"], "action performed")
	if r.get("accepted", false):
		ok(GS.allied(s, x, y), "alliance recorded")
		var pres0 := float(s["countries"][x]["prestige"])
		var op_before := GS.opinion(s, y, x)
		DiplomacySystem.perform(s, "break_alliance", x, y)
		ok(not GS.allied(s, x, y), "alliance broken")
		ok(float(s["countries"][x]["prestige"]) < pres0, "breaking an alliance costs prestige")
		ok(GS.opinion(s, y, x) < op_before, "partner resents it")
	else:
		fail("a loved neighbour should accept (score %s)" % str(r["eval"]["score"]))

func test_war_declaration_rules() -> void:
	var a := _pair()
	var s: Dictionary = a[0]
	var x: String = a[1]
	var y: String = a[2]
	var res := DiplomacySystem.declare_war(s, x, y, "conquest")
	ok(res["ok"], "declare war on a neighbour")
	ok(GS.at_war(s, x, y), "state is at war")
	eq(DiplomacySystem.declare_war(s, x, y, "conquest")["reason"], "WAR_ERR_ALREADY", "cannot declare twice")
	ok(float(s["countries"][x]["infamy"]) > 0.0, "unjustified conquest builds infamy")
	ok(GS.opinion(s, y, x) < -40.0, "victim hates the aggressor")
	# truce blocks a new war after peace
	var wid := DiplomacySystem.war_for_pair(s, x, y)
	DiplomacySystem.make_peace(s, wid, x, y, {"white": true})
	ok(not GS.at_war(s, x, y), "peace ends the war")
	eq(DiplomacySystem.declare_war(s, x, y, "conquest")["reason"], "WAR_ERR_TRUCE", "truce prevents immediate re-war")

func test_cannot_attack_ally() -> void:
	var a := _pair()
	var s: Dictionary = a[0]
	var x: String = a[1]
	var y: String = a[2]
	GS.rel(s, x, y)["alliance"] = true
	eq(DiplomacySystem.declare_war(s, x, y, "conquest")["reason"], "WAR_ERR_ALLIED", "allies must break the pact first")

func test_allies_and_vassals_join_wars() -> void:
	var a := _pair()
	var s: Dictionary = a[0]
	var x: String = a[1]
	var y: String = a[2]
	var third := ""
	for c in GS.alive_countries(s):
		if c != x and c != y and not str(c).begins_with("NAT_") and not DiplomacySystem.borders(s, c, x):
			third = c
			break
	GS.rel(s, y, third)["alliance"] = true
	var vas := ""
	for c in GS.alive_countries(s):
		if c not in [x, y, third] and not str(c).begins_with("NAT_"):
			vas = c
			break
	DiplomacySystem.make_vassal(s, y, vas, false)
	DiplomacySystem.declare_war(s, x, y, "conquest")
	var wid := DiplomacySystem.war_for_pair(s, x, y)
	var w: Dictionary = s["wars"][wid]
	ok(third in w["defenders"], "defensive ally honours the pact")
	ok(vas in w["defenders"], "vassal follows its overlord")

func test_peace_terms_transfer_provinces_and_evaluation_monotonic() -> void:
	var a := _pair()
	var s: Dictionary = a[0]
	var x: String = a[1]
	var y: String = a[2]
	DiplomacySystem.declare_war(s, x, y, "conquest")
	var wid := DiplomacySystem.war_for_pair(s, x, y)
	var pb: String = GS.owned(s, y)[0]
	var terms := {"provinces": [pb], "white": false}
	var ev0 := DiplomacySystem.peace_eval(s, wid, x, y, terms)
	s["wars"][wid]["score"] = 70.0 if x in s["wars"][wid]["attackers"] else -70.0
	var ev1 := DiplomacySystem.peace_eval(s, wid, x, y, terms)
	ok(float(ev1["score"]) > float(ev0["score"]), "winning raises acceptance")
	ok(ev1["accept"], "a heavily winning side can demand a province")
	var r := DiplomacySystem.make_peace(s, wid, x, y, terms)
	ok(r["ok"], "peace made")
	eq(s["provinces"][pb]["owner"], x, "province transferred")
	ok(not GS.at_war(s, x, y), "war over")
	ok(int(GS.rel(s, x, y)["truce_until"]) > int(s["turn"]), "truce set")
	ok(float(s["countries"][x]["stats"].get("wars_won", 0.0)) >= 1.0, "war counted in statistics")

func test_white_peace_and_gifts_and_vassals() -> void:
	var a := _pair()
	var s: Dictionary = a[0]
	var x: String = a[1]
	var y: String = a[2]
	s["countries"][x]["gold"] = 1000.0
	var op0 := GS.opinion(s, y, x)
	var g0 := float(s["countries"][y]["gold"])
	var r := DiplomacySystem.perform(s, "gift", x, y, {"gold": 200.0})
	ok(r["ok"], "gift sent")
	ok(GS.opinion(s, y, x) > op0, "gifts improve relations")
	near(float(s["countries"][y]["gold"]), g0 + 200.0, 0.001, "gold transferred")
	DiplomacySystem.make_vassal(s, x, y, true)
	eq(GS.overlord_of(s, y), x, "vassal relationship")
	var ev := DiplomacySystem.evaluate(s, "annex_vassal", x, y)
	ok(not ev["ok"], "annexation needs time (%s)" % str(ev.get("reason", "")))
	DiplomacySystem.release_vassal(s, x, y)
	eq(GS.overlord_of(s, y), "", "released")

func test_nap_break_penalty_and_trade_agreement() -> void:
	var a := _pair()
	var s: Dictionary = a[0]
	var x: String = a[1]
	var y: String = a[2]
	GS.rel(s, x, y)["nap_until"] = 40
	var pres0 := float(s["countries"][x]["prestige"])
	DiplomacySystem.declare_war(s, x, y, "conquest")
	ok(float(s["countries"][x]["prestige"]) < pres0, "breaking a pact costs prestige")
	DiplomacySystem.make_peace(s, DiplomacySystem.war_for_pair(s, x, y), x, y, {"white": true})
	var s2 := new_state()
	var p := neighbour_pair(s2, 2)
	GS.rel(s2, p[0], p[1])["op"][p[1]] = 100.0
	var ev := DiplomacySystem.evaluate(s2, "trade", p[0], p[1])
	ok(ev["ok"], "trade evaluable")
	var done := DiplomacySystem.perform(s2, "trade", p[0], p[1])
	if done.get("accepted", false):
		ok(GS.rel(s2, p[0], p[1])["trade"], "trade agreement recorded")

func test_coalition_forms_against_infamous_state() -> void:
	var a := _pair()
	var s: Dictionary = a[0]
	var tgt: String = a[1]
	s["countries"][tgt]["infamy"] = 80.0
	var made := 0
	for c in GS.alive_countries(s):
		if c != tgt and not str(c).begins_with("NAT_") and made < 4:
			GS.rel(s, c, tgt)["op"][c] = -120.0
			made += 1
	var id := DiplomacySystem.form_coalition_against(s, tgt)
	ok(id != "", "coalition formed")
	if id != "":
		ok((s["coalitions"][id]["members"] as Array).size() >= 2, "has members")

func test_embargo_blocks_trade_route() -> void:
	var a := _pair()
	var s: Dictionary = a[0]
	var x: String = a[1]
	var y: String = a[2]
	DiplomacySystem.perform(s, "embargo", x, y)
	ok(GS.rel(s, x, y)["embargo"][x], "embargo set")
	var t := TradeSystem.compute(s)
	for pid in t["by_province"]:
		var d: Dictionary = t["by_province"][pid]
		if d["hub"] == "":
			continue
		var o1: String = s["provinces"][pid]["owner"]
		var o2: String = s["provinces"][d["hub"]]["owner"]
		if (o1 == x and o2 == y) or (o1 == y and o2 == x):
			fail("embargoed countries still trade")
			break
