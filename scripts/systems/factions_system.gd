class_name FactionsSystem
extends RefCounted
## Internal politics: six factions (court, nobility, merchants, clergy, military, popular) with influence and
## loyalty derived from class satisfaction and power, demands the ruler can grant or suppress, corruption,
## coups and the government-change transition. Government-specific mechanics live in gov_mechanics.gd,
## civil wars / independence movements in civil_war.gd.
## State: country["fac"] = {f:{fid:{inf,loy,dem,unmet,cool,low}}, corr, trans, move:{pid:progress}, mech:{}, log:[], coup_cool, civil_cool}

const FACTIONS: Array[String] = ["court", "nobility", "merchants", "clergy", "military", "popular"]
const CLASS_OF := {"nobility": "nobility", "merchants": "merchants", "clergy": "clergy", "military": "military", "popular": "peasants"}
const DEMAND_TURNS := 8
const MAX_LOG := 20

static func new_state() -> Dictionary:
	var f := {}
	for fid in FACTIONS:
		f[fid] = {"inf": 1.0 / 6.0, "loy": 55.0, "dem": null, "unmet": 0, "cool": 0, "low": 0}
	return {"f": f, "corr": 20.0, "trans": null, "move": {}, "mech": {}, "log": [], "coup_cool": 0, "civil_cool": 0, "uprising_cool": 0, "fight_cool": 0}

static func st(c: Dictionary) -> Dictionary:
	if not c.has("fac"):
		c["fac"] = new_state()
	return c["fac"]

static func loyalty(c: Dictionary, fid: String) -> float:
	return float(st(c)["f"][fid]["loy"])

static func influence(c: Dictionary, fid: String) -> float:
	return float(st(c)["f"][fid]["inf"])

static func shift_loyalty(c: Dictionary, fid: String, v: float) -> void:
	var f: Dictionary = st(c)["f"][fid]
	f["loy"] = clampf(float(f["loy"]) + v, 0.0, 100.0)

static func politics_of(c: Dictionary) -> Dictionary:
	return Defs.governments.get(c.get("gov", ""), {}).get("politics", {})

static func tax_cap(c: Dictionary) -> float:
	return float(politics_of(c).get("tax_cap", 0.6))

static func corruption(c: Dictionary) -> float:
	return float(st(c)["corr"])

## multiplier applied to national tax income (neutral at 20 % corruption)
static func tax_factor(c: Dictionary) -> float:
	return clampf(1.0 - 0.30 * (corruption(c) - 20.0) / 100.0, 0.7, 1.06)

static func mean_loyalty(c: Dictionary) -> float:
	var t := 0.0
	var w := 0.0
	for fid in FACTIONS:
		var f: Dictionary = st(c)["f"][fid]
		t += float(f["loy"]) * float(f["inf"])
		w += float(f["inf"])
	return t / maxf(w, 0.0001)

static func _log(c: Dictionary, s: Dictionary, key: String, params: Dictionary) -> void:
	var lg: Array = st(c)["log"]
	lg.append({"turn": int(s["turn"]), "key": key, "p": params})
	while lg.size() > MAX_LOG:
		lg.pop_front()

## --- influence and loyalty ------------------------------------------------------------------------------------
static func _raw_influence(s: Dictionary, cid: String, c: Dictionary) -> Dictionary:
	var cl: Dictionary = c["classes"]
	var pw := func(k: String) -> float: return float(cl.get(k, {}).get("power", 0.15))
	var bias: Dictionary = politics_of(c).get("bias", {})
	var leg := float(c["legitimacy"]) / 100.0
	var raw := {
		"court": 0.10 + 0.16 * leg + 0.015 * float(TechSystem.level(c, "centralization")) + 0.01 * float(TechSystem.level(c, "bureaucracy")),
		"nobility": pw.call("nobility"),
		"merchants": pw.call("merchants") + 0.5 * pw.call("artisans"),
		"clergy": pw.call("clergy"),
		"military": pw.call("military") + 0.02 * minf(_regiments(s, cid) / 10.0, 5.0),
		"popular": pw.call("peasants") + 0.5 * pw.call("artisans"),
	}
	var tot := 0.0
	for fid in FACTIONS:
		raw[fid] = maxf(0.01, float(raw[fid])) * float(bias.get(fid, 1.0))
		tot += float(raw[fid])
	for fid in FACTIONS:
		raw[fid] = float(raw[fid]) / tot
	return raw

## regiments per country, computed in one pass per turn
static func _regiments(s: Dictionary, cid: String) -> float:
	if int(s["_c"].get("regs_turn", -1)) != int(s["turn"]):
		var d := {}
		for aid in s["armies"]:
			var a: Dictionary = s["armies"][aid]
			if not a.get("naval", false):
				d[a["owner"]] = float(d.get(a["owner"], 0.0)) + UnitUtil.army_size(a)
		s["_c"]["regs"] = d
		s["_c"]["regs_turn"] = s["turn"]
	return float(s["_c"]["regs"].get(cid, 0.0))

static func _loyalty_target(s: Dictionary, cid: String, c: Dictionary, fid: String, mods: Dictionary) -> float:
	var f: Dictionary = st(c)["f"][fid]
	var t := 50.0
	if fid == "court":
		t = float(c["legitimacy"]) * 0.55 + float(c["stability"]) * 0.30 + 12.0 - corruption(c) * 0.18
	elif fid == "popular":
		t = float(c["classes"]["peasants"]["sat"]) * 0.7 + float(c["classes"]["artisans"]["sat"]) * 0.3
	elif fid == "merchants":
		t = float(c["classes"]["merchants"]["sat"]) * 0.75 + float(c["classes"]["artisans"]["sat"]) * 0.25
	else:
		t = float(c["classes"][CLASS_OF[fid]]["sat"])
	var bias := float(politics_of(c).get("bias", {}).get(fid, 1.0))
	t += clampf((bias - 1.0) * 8.0, -6.0, 8.0)
	t -= float(f["unmet"]) * 2.5
	t += float(mods.get("faction_loyalty", 0.0)) * 100.0 * 0.4
	return clampf(t, 2.0, 98.0)

## --- demands ----------------------------------------------------------------------------------------------------------
static func _demand_pool(fid: String) -> Array:
	return {
		"nobility": [{"type": "tax_cap", "value": 0.30}, {"type": "gold", "value": 1.0}],
		"merchants": [{"type": "tax_cap", "value": 0.28}, {"type": "gold", "value": 0.8}],
		"clergy": [{"type": "gold", "value": 0.7}],
		"military": [{"type": "funding_min", "value": 0.9}, {"type": "gold", "value": 1.0}],
		"popular": [{"type": "tax_cap", "value": 0.20}, {"type": "food_ok", "value": 1.0}],
		"court": [{"type": "gold", "value": 0.9}],
	}[fid]

static func demand_cost(s: Dictionary, cid: String, d: Dictionary) -> float:
	var inc := maxf(10.0, float(s["countries"][cid].get("budget", {}).get("income", 20.0)))
	return snappedf(30.0 + inc * 2.2 * float(d["value"]), 0.1)

static func demand_met(c: Dictionary, d: Dictionary) -> bool:
	match str(d["type"]):
		"tax_cap": return float(c["tax_rate"]) <= float(d["value"]) + 0.001
		"funding_min": return float(c["army_funding"]) >= float(d["value"]) - 0.001
		"food_ok": return float(c.get("food_ratio", 1.0)) >= 0.999
	return false

static func _issue_demands(s: Dictionary, cid: String, c: Dictionary, rng: GameRng) -> void:
	var fs: Dictionary = st(c)["f"]
	for fid in FACTIONS:
		var f: Dictionary = fs[fid]
		if f["dem"] != null or int(f["cool"]) > int(s["turn"]):
			continue
		if float(f["inf"]) < 0.14 or float(f["loy"]) > 55.0:
			continue
		var pool := _demand_pool(fid)
		var d: Dictionary = (pool[rng.randi_range(0, pool.size() - 1)] as Dictionary).duplicate()
		if str(d["type"]) == "tax_cap" and float(c["tax_rate"]) <= float(d["value"]):
			d = {"type": "gold", "value": 0.8}
		if str(d["type"]) == "funding_min" and float(c["army_funding"]) >= float(d["value"]):
			d = {"type": "gold", "value": 1.0}
		if str(d["type"]) == "food_ok" and float(c.get("food_ratio", 1.0)) >= 0.999:
			d = {"type": "gold", "value": 0.8}
		d["until"] = int(s["turn"]) + DEMAND_TURNS
		f["dem"] = d
		GS.note(s, cid, "politics", "NOTE_FACTION_DEMAND", {"faction": fid})
		_log(c, s, "demand", {"f": fid, "type": d["type"]})

static func _process_demands(s: Dictionary, cid: String, c: Dictionary) -> void:
	var fs: Dictionary = st(c)["f"]
	for fid in FACTIONS:
		var f: Dictionary = fs[fid]
		var d: Variant = f["dem"]
		if not (d is Dictionary):
			continue
		if str(d["type"]) != "gold" and demand_met(c, d):
			f["loy"] = clampf(float(f["loy"]) + 7.0, 0.0, 100.0)
			f["dem"] = null
			f["cool"] = int(s["turn"]) + 10
			f["unmet"] = maxi(0, int(f["unmet"]) - 1)
			_log(c, s, "granted", {"f": fid})
		elif int(d["until"]) < int(s["turn"]):
			f["dem"] = null
			f["cool"] = int(s["turn"]) + 6
			f["unmet"] = int(f["unmet"]) + 1
			f["loy"] = clampf(float(f["loy"]) - 6.0, 0.0, 100.0)
			GS.note(s, cid, "politics", "NOTE_FACTION_ANGRY", {"faction": fid})
			_log(c, s, "ignored", {"f": fid})

static func can_concede(s: Dictionary, cid: String, fid: String) -> Dictionary:
	var c: Dictionary = s["countries"][cid]
	var d: Variant = st(c)["f"][fid]["dem"]
	if not (d is Dictionary):
		return {"ok": false, "reason": "FAC_ERR_NO_DEMAND"}
	if str(d["type"]) == "gold":
		var cost := demand_cost(s, cid, d)
		if float(c["gold"]) < cost:
			return {"ok": false, "reason": "ERR_NO_GOLD", "params": {"need": int(ceil(cost))}}
		return {"ok": true, "cost": cost}
	if str(d["type"]) == "food_ok":
		return {"ok": false, "reason": "FAC_ERR_POLICY"}
	return {"ok": true, "cost": 0.0}

static func concede(s: Dictionary, cid: String, fid: String) -> Dictionary:
	var chk := can_concede(s, cid, fid)
	if not chk["ok"]:
		return chk
	var c: Dictionary = s["countries"][cid]
	var f: Dictionary = st(c)["f"][fid]
	var d: Dictionary = f["dem"]
	match str(d["type"]):
		"gold": c["gold"] = float(c["gold"]) - float(chk["cost"])
		"tax_cap":
			c["tax_rate"] = minf(float(c["tax_rate"]), float(d["value"]))
			EconomySystem.invalidate_calc(s)
		"funding_min": c["army_funding"] = maxf(float(c["army_funding"]), float(d["value"]))
	f["loy"] = clampf(float(f["loy"]) + 14.0, 0.0, 100.0)
	f["dem"] = null
	f["cool"] = int(s["turn"]) + 10
	f["unmet"] = maxi(0, int(f["unmet"]) - 1)
	_log(c, s, "granted", {"f": fid})
	return {"ok": true}

static func suppress(s: Dictionary, cid: String, fid: String) -> Dictionary:
	var c: Dictionary = s["countries"][cid]
	if fid == "court":
		return {"ok": false, "reason": "FAC_ERR_SUPPRESS_COURT"}
	var f: Dictionary = st(c)["f"][fid]
	if int(f["cool"]) > int(s["turn"]) + 8:
		return {"ok": false, "reason": "FAC_ERR_COOLDOWN"}
	if float(c["admin"]) < 15.0:
		return {"ok": false, "reason": "ERR_NO_ADMIN", "params": {"need": 15}}
	c["admin"] = float(c["admin"]) - 15.0
	c["stability"] = maxf(0.0, float(c["stability"]) - 3.0)
	c["legitimacy"] = maxf(0.0, float(c["legitimacy"]) - 4.0)
	f["inf"] = maxf(0.03, float(f["inf"]) - 0.05)
	f["loy"] = clampf(float(f["loy"]) - 8.0, 0.0, 100.0)
	f["dem"] = null
	f["cool"] = int(s["turn"]) + 14
	shift_loyalty(c, "popular", -2.0)
	_log(c, s, "suppressed", {"f": fid})
	return {"ok": true}

static func fight_corruption(s: Dictionary, cid: String) -> Dictionary:
	var c: Dictionary = s["countries"][cid]
	var fs := st(c)
	if int(fs["fight_cool"]) > int(s["turn"]):
		return {"ok": false, "reason": "FAC_ERR_COOLDOWN"}
	if float(c["admin"]) < 20.0:
		return {"ok": false, "reason": "ERR_NO_ADMIN", "params": {"need": 20}}
	if float(c["gold"]) < 60.0:
		return {"ok": false, "reason": "ERR_NO_GOLD", "params": {"need": 60}}
	c["admin"] = float(c["admin"]) - 20.0
	c["gold"] = float(c["gold"]) - 60.0
	fs["corr"] = maxf(0.0, float(fs["corr"]) - 10.0)
	fs["fight_cool"] = int(s["turn"]) + 8
	shift_loyalty(c, "court", -6.0)
	return {"ok": true}

## --- corruption -------------------------------------------------------------------------------------------------------------
static func corruption_target(s: Dictionary, cid: String, c: Dictionary) -> float:
	var pol := politics_of(c)
	var corr_p: Array = pol.get("corr", [0.08, 0.01])
	var prov := float(GS.owned(s, cid).size())
	var t := 10.0 + 90.0 * (float(corr_p[0]) + float(corr_p[1]) * prov) * 0.9
	t += float(EconomySystem.admin_capacity(s, cid)["overextension"]) * 25.0
	t += (influence(c, "court") - 0.17) * 40.0
	t += (50.0 - float(c["stability"])) * 0.2
	t -= float(TechSystem.level(c, "bureaucracy")) * 4.0
	t += Mods.get_mod(s, cid, "corruption") * 60.0
	var gl := float(Defs.governments.get(c["gov"], {}).get("politics", {}).get("land_cap", 99))
	if prov > gl:
		t += (prov - gl) * 1.5
	if float(c["ruler"].get("adm", 5)) < 4.0:
		t += 4.0
	return clampf(t, 0.0, 90.0)

## --- main turn --------------------------------------------------------------------------------------------------------------------
## Called from PoliticsSystem.process_turn after class satisfaction and power were updated.
static func process_turn(s: Dictionary, cid: String, rng: GameRng) -> void:
	var c: Dictionary = s["countries"][cid]
	if bool(c.get("native", false)):
		return
	var fs := st(c)
	var mods := Mods.country(s, cid)
	var raw := _raw_influence(s, cid, c)
	var any_low := false
	for fid in FACTIONS:
		var f: Dictionary = fs["f"][fid]
		f["inf"] = lerpf(float(f["inf"]), float(raw[fid]), 0.2)
		f["loy"] = lerpf(float(f["loy"]), _loyalty_target(s, cid, c, fid, mods), 0.15)
		if float(f["loy"]) < 22.0 and float(f["inf"]) >= 0.15:
			f["low"] = int(f["low"]) + 1
			any_low = true
		else:
			f["low"] = maxi(0, int(f["low"]) - 1)
	# corruption drifts towards its target
	fs["corr"] = clampf(lerpf(float(fs["corr"]), corruption_target(s, cid, c), 0.05), 0.0, 100.0)
	_enforce_tax_cap(s, cid, c)
	GovMechanics.process(s, cid, c, rng)
	_process_demands(s, cid, c)
	_issue_demands(s, cid, c, rng)
	_process_transition(s, cid, c)
	# stability feedback: loyal factions steady the realm, angry powerful ones shake it
	c["stability"] = clampf(float(c["stability"]) + (mean_loyalty(c) - 50.0) * 0.012 - maxf(0.0, corruption(c) - 40.0) * 0.004, 0.0, 100.0)
	c["prestige"] = float(c["prestige"]) + float(mods.get("prestige", 0.0)) * 6.0
	if any_low:
		_check_unrest_outcomes(s, cid, c, rng)
	_check_coup(s, cid, c, rng)

## taxes above what the ruling order tolerates anger the factions that would have to consent
static func _enforce_tax_cap(s: Dictionary, cid: String, c: Dictionary) -> void:
	var cap := tax_cap(c)
	if float(c["tax_rate"]) > cap + 0.001:
		var over := float(c["tax_rate"]) - cap
		for fid in ["nobility", "merchants", "popular"]:
			shift_loyalty(c, fid, -over * 30.0)

static func _check_unrest_outcomes(s: Dictionary, cid: String, c: Dictionary, rng: GameRng) -> void:
	var fs := st(c)
	var prov := GS.owned(s, cid).size()
	for fid in FACTIONS:
		var f: Dictionary = fs["f"][fid]
		var low := int(f["low"])
		if low >= 5 and int(fs["uprising_cool"]) <= int(s["turn"]) and fid != "court":
			_faction_uprising(s, cid, c, fid, rng)
			fs["uprising_cool"] = int(s["turn"]) + 12
		var civil := float(politics_of(c).get("civil", 1.0)) * (2.0 if fs["trans"] != null else 1.0)
		if low >= 10 and prov >= 6 and int(fs["civil_cool"]) <= int(s["turn"]) and float(c["stability"]) < 32.0 and rng.chance(0.06 * civil):
			CivilWar.start(s, cid, "faction", fid, "", rng)
			return

## rebels appear in the provinces where the angry faction is strongest (existing REB pseudo-country)
static func _faction_uprising(s: Dictionary, cid: String, c: Dictionary, fid: String, rng: GameRng) -> void:
	var owned: Array = GS.owned(s, cid).duplicate()
	owned.sort_custom(func(a, b): return float(s["provinces"][a]["unrest"]) > float(s["provinces"][b]["unrest"]))
	var n := 0
	for pid in owned:
		if n >= 2:
			break
		var p: Dictionary = s["provinces"][pid]
		if p["controller"] != cid:
			continue
		var size := clampf(roundf(float(p["pop"]) * 0.004 * (0.5 + influence(c, fid) * 3.0)), 1.0, 6.0)
		var aid := MilitarySystem.spawn_rebels(s, pid, size)
		s["armies"][aid]["faction"] = fid
		p["unrest"] = minf(100.0, float(p["unrest"]) + 8.0)
		n += 1
	GS.note(s, cid, "uprising", "NOTE_FACTION_UPRISING", {"faction": fid})
	GS.history(s, cid, "uprising", "HIST_FACTION_UPRISING", {"faction": fid})
	_log(c, s, "uprising", {"f": fid})

## --- coups ---------------------------------------------------------------------------------------------------------------------------
static func coup_chance(s: Dictionary, cid: String, c: Dictionary) -> float:
	var fs := st(c)
	if int(fs["coup_cool"]) > int(s["turn"]):
		return 0.0
	var pol := politics_of(c)
	var ml := loyalty(c, "military")
	var mi := influence(c, "military")
	var p := 0.0
	if mi >= 0.18 and ml < 35.0 and float(c["stability"]) < 45.0:
		p += 0.012 * (1.0 + (35.0 - ml) / 35.0)
	if float(c["stability"]) < 22.0 and float(c["legitimacy"]) < 28.0:
		p += 0.03
	p *= float(pol.get("coup", 1.0))
	if fs["trans"] != null:
		p *= 2.0
	p *= clampf(1.0 - Mods.get_mod(s, cid, "coup_guard"), 0.3, 1.0)
	return p

static func _check_coup(s: Dictionary, cid: String, c: Dictionary, rng: GameRng) -> void:
	var p := coup_chance(s, cid, c)
	if p > 0.0 and rng.chance(p):
		coup(s, cid, rng)

static func coup(s: Dictionary, cid: String, rng: GameRng) -> void:
	var c: Dictionary = s["countries"][cid]
	var fs := st(c)
	PoliticsSystem._coup(s, cid, rng)
	fs["coup_cool"] = int(s["turn"]) + 24
	shift_loyalty(c, "military", 25.0)
	shift_loyalty(c, "popular", -8.0)
	shift_loyalty(c, "nobility", -8.0)
	shift_loyalty(c, "court", -12.0)
	fs["corr"] = minf(100.0, float(fs["corr"]) + 4.0)
	_log(c, s, "coup", {})
	GS.stat_add(s, cid, "coups", 1.0)

## --- government change ------------------------------------------------------------------------------------------------------------------------
static func on_government_change(s: Dictionary, cid: String, old_gov: String, new_gov: String) -> void:
	var c: Dictionary = s["countries"][cid]
	var fs := st(c)
	var ob: Dictionary = Defs.governments.get(old_gov, {}).get("politics", {}).get("bias", {})
	var nb: Dictionary = Defs.governments.get(new_gov, {}).get("politics", {}).get("bias", {})
	for fid in FACTIONS:
		var d := float(nb.get(fid, 1.0)) - float(ob.get(fid, 1.0))
		shift_loyalty(c, fid, clampf(d * 12.0, -18.0, 10.0) - 4.0)
	var turns := int(Defs.governments.get(new_gov, {}).get("politics", {}).get("transition", 6))
	fs["trans"] = {"from": old_gov, "to": new_gov, "start": int(s["turn"]), "until": int(s["turn"]) + turns}
	c["legitimacy"] = maxf(20.0, float(c["legitimacy"]) - 12.0)
	fs["corr"] = minf(100.0, float(fs["corr"]) + 4.0)
	fs["mech"] = {}
	_log(c, s, "gov_change", {"from": old_gov, "to": new_gov})

static func _process_transition(s: Dictionary, cid: String, c: Dictionary) -> void:
	var tr: Variant = st(c)["trans"]
	if not (tr is Dictionary):
		return
	if int(s["turn"]) > int(tr["until"]):
		st(c)["trans"] = null
		GS.note(s, cid, "politics", "NOTE_TRANSITION_DONE", {"gov": tr["to"]})
		return
	c["temp_mods"].append({"mods": {"unrest": 0.04, "tax": -0.04}, "until": int(s["turn"]) + 1, "key": "transition"})
	Mods.invalidate(s)

static func in_transition(c: Dictionary) -> bool:
	return st(c)["trans"] != null

## reform side effects: one-off faction loyalty changes
static func on_reform(c: Dictionary, rid: String) -> void:
	var fx: Dictionary = Defs.reforms.get(rid, {}).get("fx", {})
	for fid in fx:
		if fid in FACTIONS:
			shift_loyalty(c, str(fid), float(fx[fid]))

static func on_election(s: Dictionary, cid: String) -> String:
	var c: Dictionary = s["countries"][cid]
	var best := ""
	var bv := -1.0
	for fid in FACTIONS:
		var v := influence(c, fid) * loyalty(c, fid)
		if fid != "court" and v > bv:
			bv = v
			best = fid
	for fid in FACTIONS:
		shift_loyalty(c, fid, 10.0 if fid == best else -3.0)
	return best

## --- AI ------------------------------------------------------------------------------------------------------------------------------------
static func ai_turn(s: Dictionary, cid: String, rng: GameRng) -> void:
	var c: Dictionary = s["countries"][cid]
	if bool(c.get("native", false)):
		return
	var fs := st(c)
	var inc := maxf(10.0, float(c.get("budget", {}).get("income", 20.0)))
	for fid in FACTIONS:
		var f: Dictionary = fs["f"][fid]
		var d: Variant = f["dem"]
		if not (d is Dictionary):
			continue
		if str(d["type"]) == "tax_cap":
			if float(f["inf"]) > 0.2 and float(c["tax_rate"]) - float(d["value"]) < 0.08 and float(c["gold"]) > inc * 2.0:
				concede(s, cid, fid)
		elif str(d["type"]) == "funding_min":
			if float(c["gold"]) > inc * 2.0:
				concede(s, cid, fid)
		elif str(d["type"]) == "gold":
			var cost := demand_cost(s, cid, d)
			if float(c["gold"]) - cost > inc * 4.0 and float(f["loy"]) < 45.0:
				concede(s, cid, fid)
		elif rng.chance(0.2) and float(f["loy"]) < 25.0 and fid != "court" and float(c["admin"]) > 40.0:
			suppress(s, cid, fid)
	if corruption(c) > 45.0 and float(c["admin"]) > 70.0 and float(c["gold"]) > 150.0 and rng.chance(0.15):
		fight_corruption(s, cid)
	# keep taxes within what the government's ruling order accepts
	if float(c["tax_rate"]) > tax_cap(c):
		c["tax_rate"] = tax_cap(c)
	DynastySystem.ai_turn(s, cid, rng)

## --- event hooks (data-driven events) ------------------------------------------------------------------------------------------------------------------
static func event_cond(s: Dictionary, cid: String, t: String, cond: Dictionary) -> bool:
	var c: Dictionary = s["countries"][cid]
	if bool(c.get("native", false)):
		return false
	var v := float(cond.get("value", 0))
	var fid := str(cond.get("faction", "nobility"))
	match t:
		"corruption_above": return corruption(c) > v
		"faction_loyalty_below": return fid in FACTIONS and loyalty(c, fid) < v
		"faction_loyalty_above": return fid in FACTIONS and loyalty(c, fid) > v
		"faction_influence_above": return fid in FACTIONS and influence(c, fid) * 100.0 > v
		"in_regency": return int(c.get("regency", 0)) > 0
		"in_succession_dispute": return DynastySystem.st(c)["crisis"] != null
		"in_transition": return in_transition(c)
	return false

static func event_effect(s: Dictionary, cid: String, t: String, fx: Dictionary) -> bool:
	var c: Dictionary = s["countries"][cid]
	var v := float(fx.get("value", 0))
	match t:
		"faction_loyalty":
			var fid := str(fx.get("faction", "nobility"))
			if fid in FACTIONS:
				shift_loyalty(c, fid, v)
			return true
		"corruption":
			st(c)["corr"] = clampf(corruption(c) + v, 0.0, 100.0)
			return true
	return false

static func validate(s: Dictionary, cid: String) -> Array:
	var errs: Array = []
	var f: Variant = s["countries"][cid].get("fac")
	if not (f is Dictionary):
		return ["country %s: fac missing" % cid]
	for fid in FACTIONS:
		if not (f["f"].get(fid) is Dictionary):
			errs.append("country %s: faction %s missing" % [cid, fid])
			continue
		var x: Dictionary = f["f"][fid]
		if is_nan(float(x["loy"])) or float(x["loy"]) < 0.0 or float(x["loy"]) > 100.0:
			errs.append("country %s: faction %s loyalty out of range" % [cid, fid])
	if float(f["corr"]) < 0.0 or float(f["corr"]) > 100.0:
		errs.append("country %s: corruption out of range" % cid)
	return errs
