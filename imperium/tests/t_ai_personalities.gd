extends TestCase
## Every one of the nine personalities is exercised on its own (all AI countries forced to that personality)
## and the two newest ones are checked for genuinely different behaviour, not just a label.

func _forced_state(p: String, seed_v: int) -> Dictionary:
	var s := new_state("early_modern", "", "normal", seed_v)
	s["players"] = []
	for cid in GS.alive_countries(s):
		if s["countries"][cid].get("native", false):
			continue
		s["ai"][cid]["personality"] = p
	return s

func _count(s: Dictionary, what: String) -> float:
	var n := 0.0
	for cid in GS.alive_countries(s):
		var c: Dictionary = s["countries"][cid]
		if c.get("native", false):
			continue
		match what:
			"port_trade":
				for pid in GS.owned(s, cid):
					var b: Dictionary = s["provinces"][pid]["buildings"]
					n += float(b.get("port", 0)) + float(b.get("trading_center", 0))
			"fleet":
				n += UnitUtil.country_regiments(s, cid, true)
			"alliances":
				for o in GS.alive_countries(s):
					if o != cid and GS.allied(s, cid, o):
						n += 0.5
	return n

func test_nine_personalities_exist_and_are_documented_count() -> void:
	eq(Const.PERSONALITIES.size(), 9, "nine personalities")
	for p in Const.PERSONALITIES:
		ok(AISystem.PERS_W.has(p), "weights for " + p)

func test_each_personality_runs_stably() -> void:
	for p in Const.PERSONALITIES:
		var s := _forced_state(p, 11)
		var errs := run_turns(s, 24)
		ok(errs.is_empty(), "%s: 24 turns resolve" % p)
		var bad := Saves.validate_state(s)
		ok(bad.is_empty(), "%s: state valid (%s)" % [p, str(bad.slice(0, 2))])

func test_naval_trade_builds_ports_and_fleets_more_than_aggressive() -> void:
	var a := 0.0
	var b := 0.0
	var fa := 0.0
	var fb := 0.0
	for seed_v in [3, 4]:
		var sn := _forced_state("naval_trade", seed_v)
		var sa := _forced_state("aggressive", seed_v)
		run_turns(sn, 40)
		run_turns(sa, 40)
		a += _count(sn, "port_trade")
		b += _count(sa, "port_trade")
		fa += _count(sn, "fleet")
		fb += _count(sa, "fleet")
	ok(a > b, "naval_trade has more ports/trade centres (%.0f vs %.0f)" % [a, b])
	ok(fa >= fb, "naval_trade has at least as many ships (%.1f vs %.1f)" % [fa, fb])

func test_coalition_builder_has_more_alliances_than_isolationist() -> void:
	var a := 0.0
	var b := 0.0
	for seed_v in [5, 6]:
		var sc := _forced_state("coalition_builder", seed_v)
		var si := _forced_state("isolationist", seed_v)
		run_turns(sc, 40)
		run_turns(si, 40)
		a += _count(sc, "alliances")
		b += _count(si, "alliances")
	ok(a > b, "coalition_builder forms more alliances (%.1f vs %.1f)" % [a, b])
