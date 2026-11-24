class_name EspionageSystem
extends RefCounted
## Espionage: spy networks per target country, intelligence (fog accuracy), covert operations,
## counter-intelligence. Everything costs gold from the acting country's treasury; success depends on
## the network level versus the target's counter-intelligence; failures have diplomatic consequences.
## State: country["esp"] = {net:{tid:{lvl,since}}, ci, log:[], cool:{tid:turn}, cb:{culprit:until}, intel:{tid:until}}

const MAX_LEVEL := 5
const MAX_LOG := 24
const CB_TURNS := 12
const OPS := {
	"survey": {"cost": 25.0, "min_lvl": 1, "diff": -0.10, "cool": 1},
	"influence": {"cost": 45.0, "min_lvl": 1, "diff": -0.05, "cool": 2},
	"incite_unrest": {"cost": 50.0, "min_lvl": 1, "diff": 0.0, "cool": 2},
	"sabotage_supply": {"cost": 40.0, "min_lvl": 2, "diff": 0.05, "cool": 2},
	"sabotage_buildings": {"cost": 60.0, "min_lvl": 2, "diff": 0.10, "cool": 2},
	"steal_tech": {"cost": 90.0, "min_lvl": 3, "diff": 0.15, "cool": 4},
}
const OP_ORDER: Array[String] = ["survey", "influence", "incite_unrest", "sabotage_supply", "sabotage_buildings", "steal_tech"]
## operations that, when exposed, give the victim a casus belli
const HOSTILE_OPS: Array[String] = ["incite_unrest", "sabotage_supply", "sabotage_buildings"]

static func new_state() -> Dictionary:
	return {"net": {}, "ci": 0, "log": [], "cool": {}, "cb": {}, "intel": {}, "ops_done": 0, "caught": 0}

static func st(s: Dictionary, cid: String) -> Dictionary:
	var c: Dictionary = s["countries"].get(cid, {})
	if c.is_empty():
		return {}
	if not c.has("esp"):
		c["esp"] = new_state()
	return c["esp"]

static func level(s: Dictionary, spy: String, target: String) -> int:
	var e := st(s, spy)
	if e.is_empty():
		return 0
	return int((e["net"].get(target, {}) as Dictionary).get("lvl", 0))

static func ci_level(s: Dictionary, cid: String) -> int:
	var e := st(s, cid)
	return int(e.get("ci", 0)) if not e.is_empty() else 0

## effective counter-intelligence strength of a country (level plus buildings / techs), 0..~8
static func ci_strength(s: Dictionary, cid: String) -> float:
	return float(ci_level(s, cid)) + Mods.get_mod(s, cid, "counter_intel") * 10.0

static func net_strength(s: Dictionary, spy: String, target: String) -> float:
	var l := level(s, spy, target)
	if l <= 0:
		return 0.0
	return float(l) + Mods.get_mod(s, spy, "spy_net") * 10.0

static func total_levels(s: Dictionary, cid: String) -> int:
	var n := 0
	for tid in st(s, cid).get("net", {}):
		n += int(s["countries"][cid]["esp"]["net"][tid]["lvl"])
	return n

static func max_networks(s: Dictionary, cid: String) -> int:
	return 3 + int(TechSystem.level(s["countries"][cid], "bureaucracy")) + int(Mods.get_mod(s, cid, "spy_net") * 10.0 / 2.0)

static func upkeep(s: Dictionary, cid: String) -> float:
	var e := st(s, cid)
	if e.is_empty():
		return 0.0
	return 0.7 * float(total_levels(s, cid)) + 0.9 * float(e["ci"])

static func size_factor(s: Dictionary, target: String) -> float:
	return 1.0 + 0.025 * minf(float(GS.owned(s, target).size()), 30.0)

static func can_target(s: Dictionary, spy: String, target: String) -> Dictionary:
	if spy == target or not s["countries"].get(target, {}).get("alive", false) or target == "REB" or not s["countries"].get(spy, {}).get("alive", false):
		return {"ok": false, "reason": "ERR_INVALID"}
	if bool(s["countries"][target].get("native", false)):
		return {"ok": false, "reason": "ESP_ERR_NATIVE"}
	if GS.overlord_of(s, target) == spy:
		return {"ok": false, "reason": "ESP_ERR_VASSAL"}
	if not DiplomacySystem.can_reach(s, spy, target) and not s["relations"].has(Util.pair_key(spy, target)):
		return {"ok": false, "reason": "ESP_ERR_REACH"}
	return {"ok": true}

static func build_cost(s: Dictionary, spy: String, target: String) -> float:
	var l := level(s, spy, target)
	return snappedf((35.0 + 28.0 * float(l)) * size_factor(s, target) * (1.0 + float(s["countries"][spy].get("inflation", 0.0))), 0.1)

static func can_build(s: Dictionary, spy: String, target: String) -> Dictionary:
	var chk := can_target(s, spy, target)
	if not chk["ok"]:
		return chk
	var l := level(s, spy, target)
	if l >= MAX_LEVEL:
		return {"ok": false, "reason": "ESP_ERR_MAX"}
	if l == 0 and (st(s, spy)["net"] as Dictionary).size() >= max_networks(s, spy):
		return {"ok": false, "reason": "ESP_ERR_CAPACITY", "params": {"n": max_networks(s, spy)}}
	var cost := build_cost(s, spy, target)
	if float(s["countries"][spy]["gold"]) < cost:
		return {"ok": false, "reason": "ERR_NO_GOLD", "params": {"need": int(ceil(cost))}}
	return {"ok": true, "cost": cost, "level": l + 1}

static func build_network(s: Dictionary, spy: String, target: String) -> Dictionary:
	var chk := can_build(s, spy, target)
	if not chk["ok"]:
		return chk
	var e := st(s, spy)
	var c: Dictionary = s["countries"][spy]
	c["gold"] = float(c["gold"]) - float(chk["cost"])
	var net: Dictionary = e["net"].get(target, {"lvl": 0, "since": int(s["turn"])})
	net["lvl"] = int(net["lvl"]) + 1
	e["net"][target] = net
	_log(e, s, "network", target, true, {"lvl": net["lvl"]})
	return {"ok": true, "level": net["lvl"]}

static func dismantle(s: Dictionary, spy: String, target: String) -> void:
	var e := st(s, spy)
	e["net"].erase(target)

static func ci_cost(s: Dictionary, cid: String) -> float:
	return snappedf((40.0 + 30.0 * float(ci_level(s, cid))) * (1.0 + float(s["countries"][cid].get("inflation", 0.0))), 0.1)

static func raise_ci(s: Dictionary, cid: String) -> Dictionary:
	var e := st(s, cid)
	if int(e["ci"]) >= MAX_LEVEL:
		return {"ok": false, "reason": "ESP_ERR_MAX"}
	var cost := ci_cost(s, cid)
	var c: Dictionary = s["countries"][cid]
	if float(c["gold"]) < cost:
		return {"ok": false, "reason": "ERR_NO_GOLD", "params": {"need": int(ceil(cost))}}
	c["gold"] = float(c["gold"]) - cost
	e["ci"] = int(e["ci"]) + 1
	_log(e, s, "ci", cid, true, {"lvl": e["ci"]})
	return {"ok": true, "level": e["ci"]}

static func lower_ci(s: Dictionary, cid: String) -> void:
	var e := st(s, cid)
	e["ci"] = maxi(0, int(e["ci"]) - 1)

## --- operations -----------------------------------------------------------------------------------
static func op_cost(s: Dictionary, spy: String, target: String, op: String) -> float:
	var d: Dictionary = OPS[op]
	return snappedf(float(d["cost"]) * size_factor(s, target) * (1.0 + float(s["countries"][spy].get("inflation", 0.0))), 0.1)

static func op_chance(s: Dictionary, spy: String, target: String, op: String) -> float:
	var d: Dictionary = OPS[op]
	var p := 0.30 + 0.11 * net_strength(s, spy, target) - 0.09 * ci_strength(s, target) - float(d["diff"])
	p += (float(s["countries"][spy]["ruler"].get("dip", 5)) - float(s["countries"][target]["ruler"].get("dip", 5))) * 0.01
	if GS.allied(s, spy, target):
		p += 0.08
	return clampf(p, 0.05, 0.92)

static func can_op(s: Dictionary, spy: String, target: String, op: String) -> Dictionary:
	if not OPS.has(op):
		return {"ok": false, "reason": "ERR_INVALID"}
	var chk := can_target(s, spy, target)
	if not chk["ok"]:
		return chk
	var d: Dictionary = OPS[op]
	var l := level(s, spy, target)
	if l < int(d["min_lvl"]):
		return {"ok": false, "reason": "ESP_ERR_LEVEL", "params": {"lvl": int(d["min_lvl"])}}
	var e := st(s, spy)
	if int(e["cool"].get(target, -1)) > int(s["turn"]):
		return {"ok": false, "reason": "ESP_ERR_COOLDOWN", "params": {"n": int(e["cool"][target]) - int(s["turn"])}}
	var cost := op_cost(s, spy, target, op)
	if float(s["countries"][spy]["gold"]) < cost:
		return {"ok": false, "reason": "ERR_NO_GOLD", "params": {"need": int(ceil(cost))}}
	if op == "steal_tech" and steal_candidate(s, spy, target) == "":
		return {"ok": false, "reason": "ESP_ERR_NO_TECH"}
	if op == "sabotage_buildings" and sabotage_target(s, target).is_empty():
		return {"ok": false, "reason": "ESP_ERR_NO_BUILDINGS"}
	return {"ok": true, "cost": cost, "chance": op_chance(s, spy, target, op)}

static func run_op(s: Dictionary, spy: String, target: String, op: String) -> Dictionary:
	var chk := can_op(s, spy, target, op)
	if not chk["ok"]:
		return chk
	var rng := GS.rng_of(s)
	var c: Dictionary = s["countries"][spy]
	var e := st(s, spy)
	c["gold"] = float(c["gold"]) - float(chk["cost"])
	e["cool"][target] = int(s["turn"]) + int(OPS[op]["cool"])
	e["ops_done"] = int(e["ops_done"]) + 1
	GS.stat_add(s, spy, "spy_ops", 1.0)
	var success := rng.chance(float(chk["chance"]))
	var res := {"ok": true, "success": success, "op": op, "target": target, "chance": chk["chance"]}
	if success:
		var detail := _apply_op(s, spy, target, op, rng)
		res["detail"] = detail
		_log(e, s, op, target, true, detail)
		GS.note(s, spy, "diplomacy", "NOTE_ESP_OK", {"op": op, "other": target})
		# a clean success can still be noticed
		if op in HOSTILE_OPS and rng.chance(clampf(0.10 + 0.04 * ci_strength(s, target) - 0.02 * net_strength(s, spy, target), 0.02, 0.4)):
			_exposed(s, spy, target, op, true, rng)
			res["exposed"] = true
	else:
		var caught := rng.chance(clampf(0.55 + 0.05 * ci_strength(s, target), 0.3, 0.9))
		res["caught"] = caught
		_log(e, s, op, target, false, {"caught": caught})
		if caught:
			_caught(s, spy, target, op, rng)
		else:
			GS.note(s, spy, "diplomacy", "NOTE_ESP_FAIL_QUIET", {"op": op, "other": target})
	return res

static func _caught(s: Dictionary, spy: String, target: String, op: String, rng: GameRng) -> void:
	var e := st(s, spy)
	var lvl := level(s, spy, target)
	e["caught"] = int(e["caught"]) + 1
	(e["net"][target] as Dictionary)["lvl"] = maxi(0, lvl - 1)
	if int(e["net"][target]["lvl"]) <= 0:
		e["net"].erase(target)
	GS.add_opinion(s, target, spy, -(18.0 + 4.0 * float(lvl)))
	GS.note(s, spy, "diplomacy", "NOTE_ESP_CAUGHT", {"op": op, "other": target})
	GS.note(s, target, "diplomacy", "NOTE_ESP_CAUGHT_THEM", {"op": op, "other": spy})
	_log(st(s, target), s, op, spy, true, {"foiled": true})
	if op in HOSTILE_OPS or rng.chance(0.3):
		_exposed(s, spy, target, op, false, rng)

## the plot becomes known: opinion and infamy fall out, and the victim may gain a casus belli
static func _exposed(s: Dictionary, spy: String, target: String, op: String, succeeded: bool, rng: GameRng) -> void:
	var sc: Dictionary = s["countries"][spy]
	sc["infamy"] = minf(100.0, float(sc.get("infamy", 0.0)) + (3.0 if op in HOSTILE_OPS else 1.0))
	sc["prestige"] = float(sc["prestige"]) - 4.0
	GS.add_opinion(s, target, spy, -12.0 if succeeded else -6.0)
	for oid in GS.alive_countries(s):
		if oid != spy and oid != target and GS.opinion(s, oid, spy) > -150.0 and DiplomacySystem.borders(s, oid, spy):
			GS.add_opinion(s, oid, spy, -3.0)
	if op in HOSTILE_OPS:
		st(s, target)["cb"][spy] = int(s["turn"]) + CB_TURNS
		GS.note(s, target, "diplomacy", "NOTE_ESP_CB", {"other": spy})
	GS.history(s, spy, "diplomacy", "HIST_ESP_EXPOSED", {"other": target})

static func has_incident(s: Dictionary, victim: String, culprit: String) -> bool:
	var e := st(s, victim)
	return not e.is_empty() and int(e["cb"].get(culprit, -1)) >= int(s["turn"])

## --- effects ------------------------------------------------------------------------------------------------
static func _apply_op(s: Dictionary, spy: String, target: String, op: String, rng: GameRng) -> Dictionary:
	var t: Dictionary = s["countries"][target]
	var l := level(s, spy, target)
	match op:
		"survey":
			st(s, spy)["intel"][target] = int(s["turn"]) + 6
			return {"turns": 6}
		"influence":
			var gain := 14.0 + 4.0 * float(l)
			GS.add_opinion(s, target, spy, gain)
			GS.rel(s, spy, target)["trust"] = clampf(float(GS.rel(s, spy, target)["trust"]) + 4.0, 0.0, 100.0)
			return {"opinion": int(gain)}
		"incite_unrest":
			var owned: Array = GS.owned(s, target).duplicate()
			owned.sort_custom(func(a, b): return float(s["provinces"][a]["pop"]) > float(s["provinces"][b]["pop"]))
			var hit := 0
			var rebels := 0
			for pid in owned:
				if hit >= 1 + l / 2:
					break
				var p: Dictionary = s["provinces"][pid]
				if p["controller"] != target:
					continue
				p["unrest"] = minf(100.0, float(p["unrest"]) + 9.0 + 3.0 * float(l))
				hit += 1
				if float(p["unrest"]) > 75.0 and l >= 4 and rebels == 0:
					MilitarySystem.spawn_rebels(s, pid, 1.0)
					rebels += 1
			FactionsSystem.shift_loyalty(t, "popular", -3.0)
			return {"provinces": hit, "rebels": rebels}
		"sabotage_supply":
			t["temp_mods"].append({"mods": {"supply": -0.20, "attrition": 0.12}, "until": int(s["turn"]) + 3, "key": "sabotage_supply"})
			t["stock"]["food"] = float(t["stock"]["food"]) * 0.85
			Mods.invalidate(s)
			return {"turns": 3}
		"sabotage_buildings":
			var tgt := sabotage_target(s, target)
			if tgt.is_empty():
				return {}
			ConstructionSystem.demolish(s, target, str(tgt["pid"]), str(tgt["bid"]))
			Mods.invalidate(s)
			return {"pid": tgt["pid"], "b": tgt["bid"]}
		"steal_tech":
			var tid := steal_candidate(s, spy, target)
			if tid != "":
				var sc: Dictionary = s["countries"][spy]
				var need := TechSystem.cost_rp(s, spy, tid)
				sc["research"]["progress"][tid] = float(sc["research"]["progress"].get(tid, 0.0)) + need * (0.35 + 0.05 * float(l))
				return {"tech": tid}
	return {}

## the most valuable building of the target that a saboteur could reach
static func sabotage_target(s: Dictionary, target: String) -> Dictionary:
	var best := {}
	var bv := 0.0
	for pid in GS.owned(s, target):
		var p: Dictionary = s["provinces"][pid]
		if p["controller"] != target:
			continue
		for bid in p["buildings"]:
			var v := float(Defs.buildings[bid]["cost"].get("gold", 0.0)) * float(p["buildings"][bid]) + float(p["pop"]) * 0.01
			if v > bv:
				bv = v
				best = {"pid": pid, "bid": bid}
	return best

## a technology the target owns that the spy could plausibly learn (prerequisites known, no era block)
static func steal_candidate(s: Dictionary, spy: String, target: String) -> String:
	var sc: Dictionary = s["countries"][spy]
	var tc: Dictionary = s["countries"][target]
	var best := ""
	var bc := 1e9
	var ids: Array = tc["researched"].keys()
	ids.sort()
	for tid in ids:
		if sc["researched"].has(tid) or not Defs.techs.has(tid):
			continue
		var ok := true
		for pre in Defs.techs[tid]["prereq"]:
			if not sc["researched"].has(pre):
				ok = false
				break
		if not ok or not bool(TechSystem.era_check(s, spy, tid)["ok"]):
			continue
		var cost := float(Defs.techs[tid]["cost_rp"])
		if cost < bc:
			bc = cost
			best = tid
	return best

## --- intelligence (fog of war) --------------------------------------------------------------------------------------
static func intel_active(s: Dictionary, observer: String, target: String) -> bool:
	var e := st(s, observer)
	return not e.is_empty() and int(e["intel"].get(target, -1)) >= int(s["turn"])

## 0 = nothing known, 1 = perfect
static func accuracy(s: Dictionary, observer: String, target: String) -> float:
	if observer == target:
		return 1.0
	if GS.overlord_of(s, target) == observer:
		return 1.0
	var a := net_strength(s, observer, target) / 5.0
	if intel_active(s, observer, target):
		a += 0.35
	a -= 0.04 * ci_strength(s, target)
	return clampf(a, 0.0, 1.0)

static func _noise(observer: String, target: String, turn: int, salt: String) -> float:
	## deterministic pseudo-noise in [-1, 1]; changes every two turns so the picture is stable between reports
	var h := (observer + ">" + target + ":" + salt + ":" + str(turn / 2)).hash()
	return float(h % 2001) / 1000.0 - 1.0

## Estimated value of `real` as seen by `observer`; returns {known, est, lo, hi, exact}
static func estimate(s: Dictionary, observer: String, target: String, real: float, salt: String, min_acc: float = 0.0) -> Dictionary:
	var acc := accuracy(s, observer, target)
	if acc <= min_acc and observer != target:
		return {"known": false, "est": 0.0, "lo": 0.0, "hi": 0.0, "exact": false, "acc": acc}
	var err := (1.0 - acc) * 0.6
	var est := real * (1.0 + _noise(observer, target, int(s["turn"]), salt) * err)
	return {"known": true, "est": est, "lo": real * (1.0 - err), "hi": real * (1.0 + err), "exact": err < 0.03, "acc": acc}

static func military_intel(s: Dictionary, observer: String, target: String) -> Dictionary:
	return estimate(s, observer, target, UnitUtil.country_regiments(s, target), "mil", 0.01)

static func economic_intel(s: Dictionary, observer: String, target: String) -> Dictionary:
	var tc: Dictionary = s["countries"][target]
	var out := {}
	for k in ["gold", "income", "debt"]:
		var real := float(tc["gold"]) if k == "gold" else (float(tc.get("budget", {}).get("income", 0.0)) if k == "income" else float(tc["debt"]))
		out[k] = estimate(s, observer, target, real, "eco_" + k, 0.25)
	return out

## Blend the observable strength estimate with spy information (used by the AI and the diplomacy panel).
static func refine_strength(s: Dictionary, observer: String, target: String, public_view: float) -> float:
	var acc := accuracy(s, observer, target)
	if acc <= 0.01:
		return public_view
	var seen: Dictionary = estimate(s, observer, target, UnitUtil.country_regiments(s, target), "mil", 0.0)
	return lerpf(public_view, float(seen["est"]), clampf(acc * 1.3, 0.0, 1.0))

## --- per-turn processing ------------------------------------------------------------------------------------------------
static func process_turn(s: Dictionary, cid: String) -> void:
	var c: Dictionary = s["countries"][cid]
	var e := st(s, cid)
	if e.is_empty():
		return
	# networks whose target vanished or became a vassal of ours are dropped
	for tid in (e["net"] as Dictionary).keys():
		if not s["countries"].get(tid, {}).get("alive", false) or GS.overlord_of(s, tid) == cid:
			e["net"].erase(tid)
	# detection: every foreign network inside this country may be uncovered
	var my_ci := ci_strength(s, cid)
	var rng := GS.rng_of(s)
	for oid in GS.alive_countries(s):
		if oid == cid:
			continue
		var oe := st(s, oid)
		if oe.is_empty() or not oe["net"].has(cid):
			continue
		var l := int(oe["net"][cid]["lvl"])
		var p := clampf(0.02 + 0.04 * my_ci - 0.012 * float(l), 0.0, 0.45)
		if my_ci > 0.0 and rng.chance(p):
			oe["net"].erase(cid)
			GS.add_opinion(s, cid, oid, -15.0)
			GS.note(s, cid, "diplomacy", "NOTE_ESP_UNCOVERED", {"other": oid})
			GS.note(s, oid, "diplomacy", "NOTE_ESP_UNCOVERED_THEM", {"other": cid})
			_log(e, s, "uncovered", oid, true, {"lvl": l})
	# expired casus belli
	for k in (e["cb"] as Dictionary).keys():
		if int(e["cb"][k]) < int(s["turn"]):
			e["cb"].erase(k)
	# an unpaid service falls apart (the upkeep itself is part of the budget)
	if float(c["gold"]) < 0.0 and int(c.get("bankrupt_turns", 0)) > 0:
		var worst := ""
		var wl := 0
		for tid in e["net"]:
			if int(e["net"][tid]["lvl"]) > wl:
				wl = int(e["net"][tid]["lvl"])
				worst = tid
		if worst != "":
			e["net"][worst]["lvl"] = wl - 1
			if wl - 1 <= 0:
				e["net"].erase(worst)
		elif int(e["ci"]) > 0:
			e["ci"] = int(e["ci"]) - 1

static func _log(e: Dictionary, s: Dictionary, kind: String, other: String, ok: bool, detail: Dictionary) -> void:
	var lg: Array = e["log"]
	lg.append({"turn": int(s["turn"]), "kind": kind, "other": other, "ok": ok, "d": detail})
	while lg.size() > MAX_LOG:
		lg.pop_front()

## --- AI ------------------------------------------------------------------------------------------------------------------------
## weights per personality: spy appetite, counter-intel appetite, preferred hostile / soft operations
const AI_STYLE := {
	"aggressive": {"spy": 1.2, "ci": 1.0, "ops": ["incite_unrest", "sabotage_supply", "sabotage_buildings"]},
	"defensive": {"spy": 0.5, "ci": 1.8, "ops": ["survey"]},
	"expansionist": {"spy": 1.3, "ci": 1.0, "ops": ["incite_unrest", "sabotage_buildings", "survey"]},
	"diplomatic": {"spy": 0.8, "ci": 1.0, "ops": ["influence", "survey"]},
	"economic": {"spy": 0.9, "ci": 0.8, "ops": ["steal_tech", "survey"]},
	"opportunistic": {"spy": 1.0, "ci": 1.0, "ops": ["incite_unrest", "steal_tech", "survey"]},
	"isolationist": {"spy": 0.2, "ci": 2.2, "ops": ["survey"]},
	"naval_trade": {"spy": 0.8, "ci": 0.8, "ops": ["steal_tech", "influence"]},
	"coalition_builder": {"spy": 1.0, "ci": 1.2, "ops": ["influence", "survey", "sabotage_supply"]},
}

static func ai_turn(s: Dictionary, cid: String, personality: String, rng: GameRng) -> void:
	var c: Dictionary = s["countries"][cid]
	if bool(c.get("native", false)) or (int(s["turn"]) + hash(cid)) % 3 != 0:
		return
	var style: Dictionary = AI_STYLE.get(personality, AI_STYLE["opportunistic"])
	var income := maxf(10.0, float(c.get("budget", {}).get("income", 20.0)))
	var gold := float(c["gold"])
	var reserve := income * 3.0
	var spend_cap := income * 0.6 * float(style["spy"]) + 25.0
	var e := st(s, cid)
	# counter-intelligence first: foreign agents are a real danger
	var want_ci := clampi(int(round(1.0 + float(style["ci"]) * (1.0 + float(foreign_networks_against(s, cid)) * 0.5))), 0, 4)
	if int(e["ci"]) < want_ci and gold > reserve + ci_cost(s, cid) and ci_cost(s, cid) <= spend_cap * 2.0:
		raise_ci(s, cid)
		gold = float(c["gold"])
	if float(style["spy"]) < 0.3 and not rng.chance(0.2):
		return
	# candidates: neighbours, enemies and rivals
	var cands: Array = []
	for oid in GS.alive_countries(s):
		if oid != cid and can_target(s, cid, oid)["ok"] and (DiplomacySystem.borders(s, cid, oid) or GS.at_war(s, cid, oid) or level(s, cid, oid) > 0):
			cands.append(oid)
	if cands.is_empty():
		return
	cands.sort()
	var spent := 0.0
	# score targets by personality: enemies and weak neighbours for hostile styles, tech leaders for economists
	var best := ""
	var bs := -1e9
	for oid in cands:
		var sc := 0.0
		if GS.at_war(s, cid, oid):
			sc += 8.0
		sc -= GS.opinion(s, cid, oid) * 0.05
		sc += 1.5 * float(level(s, cid, oid))
		sc += (TechSystem.avg_level(s["countries"][oid]) - TechSystem.avg_level(c)) * 4.0
		if GS.allied(s, cid, oid):
			sc -= 12.0
		sc += rng.randf() * 2.0
		if sc > bs:
			bs = sc
			best = oid
	if best == "":
		return
	var l := level(s, cid, best)
	var want_lvl := 2 if float(style["spy"]) < 1.0 else 3
	if l < want_lvl:
		var bc := build_cost(s, cid, best)
		if gold - bc > reserve and bc <= spend_cap * 2.0:
			build_network(s, cid, best)
		return
	for op in style["ops"]:
		var chk := can_op(s, cid, best, str(op))
		if not chk["ok"]:
			continue
		if float(chk["cost"]) > spend_cap - spent or float(c["gold"]) - float(chk["cost"]) < reserve:
			continue
		if float(chk["chance"]) < 0.45:
			continue
		# influence only makes sense towards states we are not fighting
		if str(op) == "influence" and GS.at_war(s, cid, best):
			continue
		if str(op) in HOSTILE_OPS and GS.allied(s, cid, best):
			continue
		run_op(s, cid, best, str(op))
		break

static func foreign_networks_against(s: Dictionary, cid: String) -> int:
	var n := 0
	for oid in GS.alive_countries(s):
		if oid != cid:
			var oe := st(s, oid)
			if not oe.is_empty() and oe["net"].has(cid):
				n += 1
	return n

## validation of the stored structure (used by Saves.validate_state)
static func validate(s: Dictionary, cid: String) -> Array:
	var errs: Array = []
	var e: Variant = s["countries"][cid].get("esp")
	if not (e is Dictionary):
		return ["country %s: esp missing" % cid]
	for tid in e["net"]:
		if not s["countries"].has(tid):
			errs.append("country %s: spy network on unknown %s" % [cid, tid])
		elif int(e["net"][tid]["lvl"]) < 0 or int(e["net"][tid]["lvl"]) > MAX_LEVEL:
			errs.append("country %s: bad network level" % cid)
	if int(e["ci"]) < 0 or int(e["ci"]) > MAX_LEVEL:
		errs.append("country %s: bad counter-intel level" % cid)
	return errs
