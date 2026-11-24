class_name EconomyDepth
extends RefCounted
## Economy depth on top of EconomySystem: employment / urbanisation / industrial development per province,
## regional specialisation, market demand, creditworthiness and loans, boom / bust cycles and resource
## shortages. Nothing here creates money: bonuses are bounded multipliers on existing output, credit is
## borrowing (net worth neutral) and every crisis lowers income.
## State: country["eco"] = {score, rating, phase, phase_until, cause, cool, shortage:{}, default_turn, log:[], boom_turns}

const PHASES := ["normal", "boom", "slump", "crisis"]
const MAX_LOG := 16
const SPEC_BUILDINGS := {"granary": ["farm", "granary", "canal"], "timber": ["sawmill"], "ore": ["mine"], "luxury": ["market", "port"], "entrepot": ["market", "port", "trading_center"], "manufacturing": ["workshop", "factory"]}

static func new_state() -> Dictionary:
	return {"score": 60.0, "rating": "B", "phase": "normal", "phase_until": 0, "cause": "", "cool": 0, "shortage": {}, "default_turn": -999, "log": [], "inc": []}

static func st(c: Dictionary) -> Dictionary:
	if not c.has("eco"):
		c["eco"] = new_state()
	return c["eco"]

## --- province statistics -----------------------------------------------------------------------------------------------
static func province_stats(p: Dictionary, pd: Dictionary, pm: Dictionary, m: Dictionary) -> Dictionary:
	var pop := float(p["pop"])
	var dev := float(p["dev"])
	var labor := pop * 0.42
	var jobs := pop * 0.28 * (0.6 + 0.4 * float(pd["fert"])) + pop * float(p.get("urban", 0.05)) * 0.15
	var ind := 0.0
	for bid in p["buildings"]:
		var lv := float(p["buildings"][bid])
		var b: Dictionary = Defs.buildings.get(bid, {})
		jobs += float(b.get("jobs", 1.0)) * lv * (1.0 + 0.15 * dev)
		ind += lv * float({"workshop": 1.0, "factory": 2.5, "mine": 0.6, "sawmill": 0.4, "railway": 0.8, "bank": 0.3, "stock_exchange": 0.5, "shipyard": 0.4}.get(bid, 0.0))
	jobs *= 1.0 + float(m.get("employment", 0.0))
	var emp := clampf(jobs / maxf(labor, 0.1), 0.3, 1.0)
	ind *= 0.5 + float(p.get("literacy", 0.05)) * 2.0
	return {"labor": labor, "jobs": jobs, "employment": emp, "industrial": minf(ind, 10.0), "urban_pop": pop * float(p.get("urban", 0.05))}

## The province's regional specialisation: the resource stream it is naturally best at.
static func specialisation(p: Dictionary, pd: Dictionary, r: Dictionary) -> Dictionary:
	var scores := {
		"granary": float(pd["fert"]) * 1.2,
		"timber": float(pd["wood"]) * 1.3,
		"ore": (float(pd["iron"]) + float(pd["stone"]) + float(pd["coal"])) * 0.55,
		"luxury": float(pd["lux"]) * 2.0,
		"entrepot": float(p.get("urban", 0.05)) * 3.0 + (0.5 if bool(pd.get("coastal", false)) else 0.0) * 0.5,
		"manufacturing": float(p["classes"].get("artisans", 0.03)) * 4.0,
	}
	var best := ""
	var bv := 0.45
	for k in scores:
		if float(scores[k]) > bv:
			bv = float(scores[k])
			best = k
	if best == "":
		return {"id": "", "bonus": 0.0}
	var match_lv := 0.0
	for bid in SPEC_BUILDINGS[best]:
		match_lv += float(p["buildings"].get(bid, 0))
	return {"id": best, "bonus": minf(0.08 + 0.03 * match_lv, 0.20) * clampf(float(p["dev"]) / 4.0, 0.3, 1.0)}

## Applies employment, industrial and specialisation effects to a province calculation (called by EconomySystem).
static func adjust(s: Dictionary, p: Dictionary, pd: Dictionary, pm: Dictionary, m: Dictionary, r: Dictionary) -> void:
	var ps := province_stats(p, pd, pm, m)
	var spec := specialisation(p, pd, r)
	r["emp"] = ps["employment"]
	r["ind"] = ps["industrial"]
	r["spec"] = spec["id"]
	r["tax"] = float(r["tax"]) * (0.92 + 0.08 * float(ps["employment"]))
	var b := float(spec["bonus"])
	match str(spec["id"]):
		"granary": r["food_prod"] = float(r["food_prod"]) * (1.0 + b)
		"timber": r["mats"]["wood"] = float(r["mats"]["wood"]) * (1.0 + b)
		"ore":
			for k in ["iron", "stone", "coal"]:
				r["mats"][k] = float(r["mats"][k]) * (1.0 + b)
		"luxury": r["mats"]["lux"] = float(r["mats"]["lux"]) * (1.0 + b)
		"entrepot": r["commerce"] = float(r["commerce"]) * (1.0 + b)
		"manufacturing": r["production"] = float(r["production"]) * (1.0 + b)
	if int(p["buildings"].get("factory", 0)) > 0:
		r["coal_need"] = float(r.get("coal_need", 0.0)) + 0.6 * float(p["buildings"]["factory"])

## country totals (for the UI): population-weighted employment, urbanisation, industrial index
static func country_stats(s: Dictionary, cid: String) -> Dictionary:
	var pop := 0.0
	var emp := 0.0
	var urb := 0.0
	var ind := 0.0
	var specs := {}
	for pid in GS.owned(s, cid):
		var p: Dictionary = s["provinces"][pid]
		var pc := EconomySystem.province_calc(s, pid)
		var w := float(p["pop"])
		pop += w
		emp += float(pc.get("emp", 1.0)) * w
		urb += float(p.get("urban", 0.05)) * w
		ind += float(pc.get("ind", 0.0)) * w
		var sp := str(pc.get("spec", ""))
		if sp != "":
			specs[sp] = int(specs.get(sp, 0)) + 1
	return {"employment": emp / maxf(pop, 1.0), "urbanisation": urb / maxf(pop, 1.0), "industrial": ind / maxf(pop, 1.0), "specs": specs}

## --- market ---------------------------------------------------------------------------------------------------------------
## Extra demand from population and industry (added to the recorded construction / recruitment demand).
static func demand_extra(s: Dictionary) -> Dictionary:
	var d := {"lux": 0.0, "wood": 0.0, "coal": 0.0, "iron": 0.0, "stone": 0.0}
	var winter := GS.season_idx(int(GS.date_of(s)["month"])) == 3
	for pid in Defs.province_ids:
		var p: Dictionary = s["provinces"][pid]
		if p["owner"] == "":
			continue
		var pop := float(p["pop"])
		var cl: Dictionary = p["classes"]
		d["lux"] += pop * (float(cl.get("nobility", 0.0)) * 0.2 + float(cl.get("merchants", 0.0)) * 0.15) * 0.05
		d["wood"] += pop * 0.0015 * (1.3 if winter else 1.0)
		d["coal"] += pop * float(p.get("urban", 0.05)) * 0.0015 * (1.6 if winter else 1.0)
		var b: Dictionary = p["buildings"]
		if not b.is_empty():
			d["coal"] += float(b.get("factory", 0)) * 0.8 + float(b.get("workshop", 0)) * 0.1
			d["iron"] += float(b.get("factory", 0)) * 0.5 + float(b.get("arsenal", 0)) * 0.3
			d["stone"] += float(b.get("fort", 0)) * 0.1
	return d

static func record_history(s: Dictionary) -> void:
	for k in s["market"]:
		var m: Dictionary = s["market"][k]
		var h: Array = m.get("hist", [])
		h.append(float(m["price"]))
		while h.size() > 12:
			h.pop_front()
		m["hist"] = h

static func price_index(s: Dictionary) -> float:
	var t := 0.0
	var n := 0.0
	for k in s["market"]:
		t += float(s["market"][k]["price"]) / float(EconomySystem.BASE_PRICE[k])
		n += 1.0
	return t / maxf(n, 1.0)

## --- creditworthiness ----------------------------------------------------------------------------------------------------------
static func credit_score(s: Dictionary, cid: String) -> float:
	var c: Dictionary = s["countries"][cid]
	var inc := maxf(float(c.get("budget", {}).get("income", 20.0)), 10.0)
	var e := st(c)
	var sc := 62.0
	sc -= 38.0 * minf(float(c["debt"]) / (inc * 8.0 + 100.0), 1.6)
	sc += (float(c["stability"]) - 50.0) * 0.25
	if int(c["bankrupt_turns"]) > 0:
		sc -= 12.0
	var since := int(s["turn"]) - int(e["default_turn"])
	if since < 60:
		sc -= 25.0 * (1.0 - float(since) / 60.0)
	sc += Mods.get_mod(s, cid, "credit") * 25.0
	sc -= float(c.get("inflation", 0.0)) * 30.0
	sc += {"merchant_republic": 9.0, "republic": 4.0, "constitutional_monarchy": 4.0, "tribal_confederation": -9.0, "military_government": -5.0}.get(str(c["gov"]), 0.0)
	if float(c["gold"]) > inc * 3.0:
		sc += 5.0
	if not GS.wars_of(s, cid).is_empty():
		sc -= 4.0
	return clampf(sc, 0.0, 100.0)

static func rating_of(score: float) -> String:
	if score >= 78.0:
		return "A"
	if score >= 58.0:
		return "B"
	if score >= 38.0:
		return "C"
	return "D"

## multiplier on the base interest rate (A ~0.8 ... D ~2.2)
static func rate_premium(c: Dictionary) -> float:
	var sc := float(st(c)["score"])
	return clampf(0.75 + (100.0 - sc) / 100.0 * 1.5, 0.75, 2.3)

static func limit_factor(c: Dictionary) -> float:
	return 0.45 + float(st(c)["score"]) / 100.0 * 0.75

static func credit_frozen(c: Dictionary) -> bool:
	return str(st(c)["phase"]) == "crisis" and str(st(c)["cause"]) == "bank_run"

static func loan_room(s: Dictionary, cid: String) -> float:
	var c: Dictionary = s["countries"][cid]
	if credit_frozen(c):
		return 0.0
	return maxf(0.0, EconomySystem.credit_limit(s, cid) - float(c["debt"]))

static func take_loan(s: Dictionary, cid: String, amount: float) -> Dictionary:
	var c: Dictionary = s["countries"][cid]
	if amount <= 0.0:
		return {"ok": false, "reason": "ERR_INVALID"}
	if credit_frozen(c):
		return {"ok": false, "reason": "ECO_ERR_CREDIT_FROZEN"}
	var room := loan_room(s, cid)
	if amount > room + 0.01:
		return {"ok": false, "reason": "ECO_ERR_CREDIT_LIMIT", "params": {"room": int(room)}}
	c["debt"] = float(c["debt"]) + amount
	c["gold"] = float(c["gold"]) + amount * 0.98   # a 2 % origination fee is lost
	GS.stat_add(s, cid, "loans", 1.0)
	return {"ok": true}

static func repay(s: Dictionary, cid: String, amount: float) -> Dictionary:
	var c: Dictionary = s["countries"][cid]
	var pay := minf(minf(amount, float(c["debt"])), float(c["gold"]))
	if pay <= 0.0:
		return {"ok": false, "reason": "ECO_ERR_NOTHING_TO_REPAY"}
	c["debt"] = float(c["debt"]) - pay
	c["gold"] = float(c["gold"]) - pay
	return {"ok": true, "paid": pay}

## called by the bankruptcy routine
static func on_default(s: Dictionary, cid: String, forgiven: float) -> void:
	var c: Dictionary = s["countries"][cid]
	st(c)["default_turn"] = int(s["turn"])
	s["econ"]["forgiven"] = float(s["econ"].get("forgiven", 0.0)) + forgiven
	_enter(s, cid, c, "crisis", "default", 8)

## --- cycles ---------------------------------------------------------------------------------------------------------------------
static func _enter(s: Dictionary, cid: String, c: Dictionary, phase: String, cause: String, turns: int) -> void:
	var e := st(c)
	e["phase"] = phase
	e["cause"] = cause
	e["phase_until"] = int(s["turn"]) + turns
	e["cool"] = int(s["turn"]) + turns + 14
	var lg: Array = e["log"]
	lg.append({"turn": int(s["turn"]), "phase": phase, "cause": cause})
	while lg.size() > MAX_LOG:
		lg.pop_front()
	if phase != "normal":
		GS.note(s, cid, "economy", "NOTE_ECO_" + phase.to_upper(), {"cause": cause})
		GS.history(s, cid, "economy", "HIST_ECO_" + phase.to_upper(), {"cause": cause})

static func _phase_mods(phase: String) -> Dictionary:
	match phase:
		"boom": return {"tax": 0.05, "trade": 0.08, "prod": 0.04}
		"slump": return {"tax": -0.06, "trade": -0.08, "prod": -0.04}
		"crisis": return {"tax": -0.10, "trade": -0.12, "prod": -0.06, "unrest": 0.03}
	return {}

static func process_turn(s: Dictionary, cid: String, rng: GameRng) -> void:
	var c: Dictionary = s["countries"][cid]
	if bool(c.get("native", false)):
		return
	var e := st(c)
	var b: Dictionary = c.get("budget", {})
	var inc := float(b.get("income", 0.0))
	var hist: Array = e["inc"]
	hist.append(snappedf(inc, 0.1))
	while hist.size() > 12:
		hist.pop_front()
	e["score"] = credit_score(s, cid)
	e["rating"] = rating_of(float(e["score"]))
	_shortages(s, cid, c, e)
	# phases expire; boom may end in a bust
	var phase := str(e["phase"])
	if phase != "normal" and int(s["turn"]) >= int(e["phase_until"]):
		var was := phase
		e["phase"] = "normal"
		e["cause"] = ""
		if was == "boom" and (float(c.get("inflation", 0.0)) > 0.12 or float(c["debt"]) > inc * 4.0) and rng.chance(0.5):
			_enter(s, cid, c, "slump", "bust", 6)
			c["inflation"] = minf(0.8, float(c.get("inflation", 0.0)) + 0.05)
		phase = str(e["phase"])
	if phase != "normal":
		c["temp_mods"].append({"mods": _phase_mods(phase), "until": int(s["turn"]) + 1, "key": "eco_" + phase})
		if phase == "crisis":
			c["stability"] = maxf(0.0, float(c["stability"]) - 0.4)
	elif int(e["cool"]) <= int(s["turn"]) and hist.size() >= 6:
		_check_triggers(s, cid, c, e, rng, hist)

static func _avg(a: Array, from: int, to: int) -> float:
	var t := 0.0
	var n := 0.0
	for i in range(maxi(from, 0), mini(to, a.size())):
		t += float(a[i])
		n += 1.0
	return t / maxf(n, 1.0)

static func _check_triggers(s: Dictionary, cid: String, c: Dictionary, e: Dictionary, rng: GameRng, hist: Array) -> void:
	var inc := float(hist[hist.size() - 1])
	var recent := _avg(hist, hist.size() - 3, hist.size())
	var before := _avg(hist, hist.size() - 9, hist.size() - 3)
	var growth := recent / maxf(before, 1.0) - 1.0
	var at_war := not GS.wars_of(s, cid).is_empty()
	var trade_share := float(c.get("budget", {}).get("trade", 0.0)) / maxf(inc, 1.0)
	# crises
	if float(c["debt"]) > EconomySystem.credit_limit(s, cid) * 0.8 and float(e["score"]) < 40.0 and rng.chance(0.12):
		_enter(s, cid, c, "crisis", "bank_run", 8)
		c["inflation"] = minf(0.8, float(c.get("inflation", 0.0)) + 0.08)
		return
	if float(c.get("food_ratio", 1.0)) < 0.8 and rng.chance(0.25):
		_enter(s, cid, c, "slump", "harvest_failure", 6)
		return
	if growth < -0.25 and trade_share > 0.15 and rng.chance(0.3):
		_enter(s, cid, c, "slump", "trade_collapse", 6)
		return
	if float(c["war_exhaustion"]) > 60.0 and float(c.get("budget", {}).get("net", 0.0)) < 0.0 and rng.chance(0.2):
		_enter(s, cid, c, "slump", "war_strain", 6)
		return
	# booms
	if not at_war and float(c["stability"]) > 60.0 and growth > 0.03 and rng.chance(0.06):
		var cause := "trade_expansion" if trade_share > 0.3 else ("good_harvests" if float(c.get("food_ratio", 1.0)) >= 1.0 and float(c.get("budget", {}).get("food_balance", 0.0)) > 5.0 else "investment")
		_enter(s, cid, c, "boom", cause, rng.randi_range(8, 12))

## --- shortages -----------------------------------------------------------------------------------------------------------------
static func _shortages(s: Dictionary, cid: String, c: Dictionary, e: Dictionary) -> void:
	var sh := {}
	var b: Dictionary = c.get("budget", {})
	var queue_n := 0
	for pid in GS.owned(s, cid):
		queue_n += (s["provinces"][pid]["queue"] as Array).size()
	var need_coal := float(b.get("coal_need", 0.0))
	if need_coal > 0.05 and float(c["stock"]["coal"]) < need_coal + 0.5:
		sh["coal"] = clampf(1.0 - float(c["stock"]["coal"]) / maxf(need_coal, 0.1), 0.2, 1.0)
	if UnitUtil.country_regiments(s, cid) > 3.0 and float(c["stock"]["iron"]) < 2.0:
		sh["iron"] = clampf(1.0 - float(c["stock"]["iron"]) / 2.0, 0.2, 1.0)
	if queue_n > 0 and float(c["stock"]["wood"]) < 2.0:
		sh["wood"] = clampf(1.0 - float(c["stock"]["wood"]) / 2.0, 0.2, 1.0)
	if queue_n > 0 and float(c["stock"]["stone"]) < 2.0:
		sh["stone"] = clampf(1.0 - float(c["stock"]["stone"]) / 2.0, 0.2, 1.0)
	e["shortage"] = sh
	var mods := {}
	for k in sh:
		var v := float(sh[k])
		match k:
			"coal": mods["prod"] = float(mods.get("prod", 0.0)) - 0.08 * v
			"iron": mods["recruit_cost"] = float(mods.get("recruit_cost", 0.0)) + 0.15 * v
			"wood": mods["build_speed"] = float(mods.get("build_speed", 0.0)) - 0.25 * v
			"stone": mods["build_cost"] = float(mods.get("build_cost", 0.0)) + 0.10 * v
	if not mods.is_empty():
		c["temp_mods"].append({"mods": mods, "until": int(s["turn"]) + 1, "key": "shortage"})

## --- AI -----------------------------------------------------------------------------------------------------------------------------------
static func ai_turn(s: Dictionary, cid: String) -> void:
	var c: Dictionary = s["countries"][cid]
	var inc := maxf(10.0, float(c.get("budget", {}).get("income", 20.0)))
	# repay expensive debt as soon as the treasury is comfortable; never borrow on purpose
	if float(c["debt"]) > 0.0 and float(c["gold"]) > inc * 5.0 + 60.0:
		repay(s, cid, float(c["gold"]) - (inc * 4.0 + 40.0))
	# poor credit standing: tighten the belt
	var e := st(c)
	if str(e["rating"]) == "D" and float(c["debt"]) > inc * 2.0:
		c["army_funding"] = minf(float(c["army_funding"]), 0.8)

## --- validation --------------------------------------------------------------------------------------------------------------------------
static func validate(s: Dictionary, cid: String) -> Array:
	var errs: Array = []
	var e: Variant = s["countries"][cid].get("eco")
	if not (e is Dictionary):
		return ["country %s: eco missing" % cid]
	if str(e["phase"]) not in PHASES:
		errs.append("country %s: bad economic phase" % cid)
	if is_nan(float(e["score"])):
		errs.append("country %s: bad credit score" % cid)
	return errs
