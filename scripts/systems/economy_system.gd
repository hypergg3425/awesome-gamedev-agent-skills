class_name EconomySystem
extends RefCounted
## Deterministic national economy. All numbers per turn (one season). Everything here is a pure
## function of the state (plus the state's seeded RNG), so it is fully testable.

const TAX_PER_KPOP := 0.016
const FOOD_PER_KPOP := 1.0
const MANPOWER_RATE := 0.010
const BASE_PRICE := {"food": 1.2, "iron": 4.0, "wood": 2.0, "stone": 3.0, "coal": 3.0, "lux": 8.0}

static func labor(pop: float) -> float:
	return clampf(sqrt(pop / 250.0), 0.3, 2.2)

## Detailed numbers for one province (read-only).
static func province_calc(s: Dictionary, pid: String) -> Dictionary:
	var cache: Dictionary = s["_c"].get("pcalc", {})
	if cache.has(pid):
		return cache[pid]
	var r := _province_calc(s, pid)
	cache[pid] = r
	s["_c"]["pcalc"] = cache
	return r

static func invalidate_calc(s: Dictionary) -> void:
	s["_c"].erase("pcalc")
	s["_c"].erase("admin_cap")

static func _province_calc(s: Dictionary, pid: String) -> Dictionary:
	var p: Dictionary = s["provinces"][pid]
	var pd: Dictionary = Defs.provinces[pid]
	var owner: String = p["owner"]
	var c: Dictionary = s["countries"].get(owner, {})
	var m: Dictionary = Mods.country(s, owner) if not c.is_empty() else {}
	var pm := Mods.province(s, pid)
	var pop := float(p["pop"])
	var cls: Dictionary = p["classes"]
	var dev := float(p["dev"])
	var devast := clampf(float(p.get("devastation", 0.0)), 0.0, 0.9)
	var unrest := clampf(float(p.get("unrest", 0.0)), 0.0, 100.0)
	var stab_f := 1.0 - unrest / 220.0
	var r := {"tax": 0.0, "production": 0.0, "food_prod": 0.0, "food_cons": pop * FOOD_PER_KPOP * 0.97, "mats": {}, "manpower": 0.0,
		"upkeep": 0.0, "commerce": 0.0, "pop": pop}
	var tax_rate := float(c.get("tax_rate", 0.25))
	var tax_mult := 1.0 + float(m.get("tax", 0.0)) + float(pm.get("tax_mult", 0.0)) + dev * 0.03 + 1.5 * (float(cls.get("merchants", 0.0)) + float(cls.get("artisans", 0.0)))
	r["tax"] = pop * tax_rate * TAX_PER_KPOP * tax_mult * stab_f * (1.0 - devast)
	var peas := float(cls.get("peasants", 0.7))
	var fert := float(pd["fert"])
	r["food_prod"] = pop * peas * fert * 1.4 * (1.0 + float(m.get("food", 0.0)) + float(pm.get("food_mult", 0.0))) * (1.0 - devast)
	var lab := labor(pop) * (1.0 - devast)
	var mine_mult := 1.0 + float(m.get("mine", 0.0)) + float(pm.get("mine_mult", 0.0))
	var prodm := 1.0 + float(m.get("prod", 0.0))
	var mats: Dictionary = r["mats"]
	mats["iron"] = float(pd["iron"]) * 1.6 * lab * mine_mult * prodm * 0.8
	mats["wood"] = float(pd["wood"]) * 2.0 * lab * (1.0 + float(pm.get("wood_mult", 0.0))) * prodm
	mats["stone"] = float(pd["stone"]) * 1.5 * lab * mine_mult * prodm * 0.8
	var coal_tech := 1.0 if (owner != "" and int(c.get("tech_level", {}).get("resource_extraction", 0)) >= 3) else 0.25
	mats["coal"] = float(pd["coal"]) * 1.4 * lab * mine_mult * prodm * coal_tech
	mats["lux"] = float(pd["lux"]) * 0.9 * lab * prodm
	var workshop_ok := true
	if int(p["buildings"].get("workshop", 0)) > 0 and int(c.get("tech_level", {}).get("industry", 0)) >= 3:
		# steam-era workshops burn coal; handled at country level (coal_need)
		r["coal_need"] = 0.3 * float(p["buildings"]["workshop"])
	r["production"] = pop * float(cls.get("artisans", 0.03)) * 0.05 * (1.0 + float(pm.get("prod_mult", 0.0)) + float(m.get("prod", 0.0))) * (1.0 - devast) * stab_f
	r["commerce"] = pop * float(p.get("urban", 0.05)) * 0.035 * (1.0 + float(m.get("trade", 0.0)) + 0.1 * float(p["buildings"].get("market", 0))
		+ 2.0 * float(cls.get("merchants", 0.0))) * (1.0 - devast) * stab_f
	r["manpower"] = pop * MANPOWER_RATE * (1.0 + float(pm.get("manpower_mult", 0.0)) + float(m.get("manpower", 0.0))) * (1.0 - devast) * clampf(1.2 - unrest / 100.0, 0.3, 1.0)
	var up := 0.0
	for bid in p["buildings"]:
		up += float(Defs.buildings[bid]["upkeep"]) * float(p["buildings"][bid])
	r["upkeep"] = up
	r["admin_cap"] = float(pm.get("admin_cap", 0.0))
	r["trade_power"] = float(pm.get("trade_power", 0.0))
	return r

static func manpower_max(s: Dictionary, cid: String) -> float:
	var tot := 0.0
	for pid in GS.owned(s, cid):
		var p: Dictionary = s["provinces"][pid]
		if p["controller"] != cid:
			continue
		tot += float(province_calc(s, pid)["manpower"])
	return tot

static func admin_capacity(s: Dictionary, cid: String) -> Dictionary:
	var cache: Dictionary = s["_c"].get("admin_cap", {})
	if cache.has(cid) and int(cache[cid]["turn"]) == int(s["turn"]):
		return cache[cid]["v"]
	var v := _admin_capacity_calc(s, cid)
	cache[cid] = {"turn": s["turn"], "v": v}
	s["_c"]["admin_cap"] = cache
	return v

static func _admin_capacity_calc(s: Dictionary, cid: String) -> Dictionary:
	var c: Dictionary = s["countries"][cid]
	var m := Mods.country(s, cid)
	var cap := 10.0
	var used := 0.0
	var devsum := 0.0
	for pid in GS.owned(s, cid):
		var p: Dictionary = s["provinces"][pid]
		var pm := Mods.province(s, pid)
		cap += float(pm.get("admin_cap", 0.0))
		devsum += float(p["dev"])
		used += 1.0 + 0.12 * float(p["dev"])
	cap += devsum * 0.25
	cap *= 1.0 + float(m.get("admin_cap", 0.0))
	used += 1.5 * float(GS.vassals_of(s, cid).size())
	var over_mod := float(m.get("overextension", 0.0))
	var ratio := used / maxf(cap, 1.0)
	var over := maxf(0.0, ratio - 1.0) * clampf(1.0 + over_mod, 0.2, 1.5)
	return {"cap": cap, "used": used, "ratio": ratio, "overextension": over}

## Full budget preview for a country. No state mutation.
static func budget(s: Dictionary, cid: String) -> Dictionary:
	var c: Dictionary = s["countries"][cid]
	var m := Mods.country(s, cid)
	var b := {"tax": 0.0, "production": 0.0, "trade": 0.0, "export": 0.0, "tribute": 0.0, "loot": 0.0, "income": 0.0,
		"army": 0.0, "navy": 0.0, "buildings": 0.0, "admin": 0.0, "interest": 0.0, "subsidy": 0.0, "food_import": 0.0,
		"expenses": 0.0, "net": 0.0, "food_prod": 0.0, "food_cons": 0.0, "food_army": 0.0, "mats": {"iron": 0.0, "wood": 0.0, "stone": 0.0, "coal": 0.0, "lux": 0.0},
		"manpower": 0.0, "pop": 0.0, "provinces": 0, "coal_need": 0.0}
	var ac := admin_capacity(s, cid)
	var over := float(ac["overextension"])
	var trade_res := TradeSystem.country_trade(s, cid)
	for pid in GS.owned(s, cid):
		var p: Dictionary = s["provinces"][pid]
		var pc := province_calc(s, pid)
		b["pop"] += float(p["pop"])
		b["provinces"] += 1
		b["buildings"] += float(pc["upkeep"])
		b["coal_need"] += float(pc.get("coal_need", 0.0))
		if p["controller"] != cid:
			continue   # occupied by an enemy: no income, no production
		b["tax"] += float(pc["tax"]) * (1.0 - minf(0.45, over * 0.5))
		b["production"] += float(pc["production"])
		b["food_prod"] += float(pc["food_prod"])
		b["food_cons"] += float(pc["food_cons"])
		b["manpower"] += float(pc["manpower"])
		for k in pc["mats"]:
			b["mats"][k] = float(b["mats"][k]) + float(pc["mats"][k])
	# provinces we control but do not own pay a share (occupation income)
	for pid in GS.controlled(s, cid):
		var p: Dictionary = s["provinces"][pid]
		if p["owner"] != cid:
			var pc := province_calc(s, pid)
			b["loot"] += float(pc["tax"]) * 0.35
	b["trade"] = float(trade_res.get("income", 0.0))
	# tribute from vassals
	for vid in GS.vassals_of(s, cid):
		var vb: Dictionary = s["countries"][vid].get("budget", {})
		b["tribute"] += maxf(0.0, float(vb.get("income", 0.0))) * 0.12
	if c["overlord"] != "":
		var ob := float(b["tax"]) + float(b["production"]) + float(b["trade"])
		b["subsidy"] = ob * 0.12
	# army upkeep
	var fund := float(c["army_funding"])
	var upm := 1.0 + float(m.get("army_upkeep", 0.0))
	for aid in s["armies"]:
		var a: Dictionary = s["armies"][aid]
		if a["owner"] != cid:
			continue
		var u := UnitUtil.army_upkeep(s, a) * upm * fund
		if a.get("naval", false):
			b["navy"] += u * (1.0 + float(m.get("navy_upkeep", 0.0)))
		else:
			b["army"] += u
		b["food_army"] += UnitUtil.army_size(a) * 0.8 if a["loc"] != "" and s["provinces"][a["loc"]]["controller"] == cid else 0.0
	# recruitment queue is paid up-front; admin
	b["admin"] = 0.8 * pow(maxf(float(b["provinces"]), 1.0), 1.15) * (1.0 + float(m.get("corruption", 0.0))) * (1.0 + over * 0.5)
	# interest
	b["interest"] = float(c["debt"]) * interest_rate(s, cid)
	# food import cost estimate (only when food shortage and import policy on)
	var food_bal := float(b["food_prod"]) - float(b["food_cons"]) - float(b["food_army"])
	b["food_balance"] = food_bal
	var stock_f := float(c["stock"]["food"])
	if food_bal < 0.0 and stock_f + food_bal < 0.0 and bool(c.get("import_food", true)) and TradeSystem.has_market_access(s, cid):
		b["food_import"] = minf(-(stock_f + food_bal), 200.0) * float(s["market"].get("food", {}).get("price", 1.2)) * 1.5
	# surplus sales (materials above reserve)
	b["export"] = export_value(s, cid, b)
	b["income"] = float(b["tax"]) + float(b["production"]) + float(b["trade"]) + float(b["export"]) + float(b["tribute"]) + float(b["loot"])
	b["expenses"] = float(b["army"]) + float(b["navy"]) + float(b["buildings"]) + float(b["admin"]) + float(b["interest"]) + float(b["subsidy"]) + float(b["food_import"])
	b["net"] = float(b["income"]) - float(b["expenses"])
	b["overextension"] = over
	b["admin_cap"] = ac["cap"]
	b["admin_used"] = ac["used"]
	return b

static func reserve_target(s: Dictionary, cid: String) -> float:
	return 40.0 + 6.0 * float(GS.owned(s, cid).size())

static func export_value(s: Dictionary, cid: String, b: Dictionary) -> float:
	if not TradeSystem.has_market_access(s, cid):
		return 0.0
	var c: Dictionary = s["countries"][cid]
	var res_cap := reserve_target(s, cid)
	var eff := 0.6 * (1.0 + float(Mods.get_mod(s, cid, "trade")))
	var total := 0.0
	for k in ["iron", "wood", "stone", "coal", "lux"]:
		var have := float(c["stock"][k]) + float(b["mats"][k])
		var cap := res_cap * (0.5 if k == "lux" else 1.0)
		if have > cap:
			total += (have - cap) * float(s["market"].get(k, {}).get("price", BASE_PRICE[k])) * eff
	return total

static func interest_rate(s: Dictionary, cid: String) -> float:
	var m := Mods.country(s, cid)
	return clampf(0.025 * (1.0 + float(m.get("interest", 0.0))) * (1.0 + float(s["countries"][cid].get("inflation", 0.0)) * 0.5), 0.005, 0.1)

static func credit_limit(s: Dictionary, cid: String) -> float:
	var b: Dictionary = s["countries"][cid].get("budget", {})
	var m := Mods.country(s, cid)
	return (120.0 + maxf(0.0, float(b.get("income", 20.0))) * 6.0) * (1.0 + float(m.get("credit", 0.0)))

## Apply a country's economic turn. Returns the budget used.
static func process_turn(s: Dictionary, cid: String) -> Dictionary:
	var c: Dictionary = s["countries"][cid]
	if not c["alive"]:
		return {}
	var b := budget(s, cid)
	var m := Mods.country(s, cid)
	# --- gold
	var export_done := false
	c["gold"] = float(c["gold"]) + float(b["income"]) - float(b["expenses"])
	# --- materials
	for k in ["iron", "wood", "stone", "coal", "lux"]:
		c["stock"][k] = float(c["stock"][k]) + float(b["mats"][k])
		if k == "coal":
			c["stock"][k] = maxf(0.0, float(c["stock"][k]) - float(b["coal_need"]))
		var cap := reserve_target(s, cid) * (0.5 if k == "lux" else 1.0)
		if float(c["stock"][k]) > cap and TradeSystem.has_market_access(s, cid):
			c["stock"][k] = cap
		elif float(c["stock"][k]) > cap * 3.0:
			c["stock"][k] = cap * 3.0
	# lux consumption by upper classes (happiness)
	var lux_need := float(b["pop"]) * 0.00006
	var lux_ok := true
	if float(c["stock"]["lux"]) >= lux_need:
		c["stock"]["lux"] = float(c["stock"]["lux"]) - lux_need
	else:
		c["stock"]["lux"] = 0.0
		lux_ok = false
	c["lux_ok"] = lux_ok or lux_need < 0.05
	# --- food (national granary: provinces' surpluses cover each other's deficits)
	var balance := float(b["food_prod"]) - float(b["food_cons"]) - float(b["food_army"])
	var stock := float(c["stock"]["food"]) + balance
	var granary_cap := 60.0 + float(b["pop"]) * 0.4
	c["food_ratio"] = 1.0
	if stock < 0.0:
		# try to import (costed inside budget())
		var shortage := -stock
		var imported := 0.0
		if float(b["food_import"]) > 0.0:
			imported = shortage
			c["gold"] = float(c["gold"]) - 0.0  # cost already counted in expenses
			stock = 0.0
			c["flags"]["food_imported"] = int(s["turn"])
		else:
			var need := float(b["food_cons"]) + float(b["food_army"])
			c["food_ratio"] = clampf(1.0 - shortage / maxf(need, 1.0), 0.0, 1.0)
			stock = 0.0
			GS.note(s, cid, "economy", "NOTE_FAMINE", {"pct": int((1.0 - float(c["food_ratio"])) * 100.0)})
	c["stock"]["food"] = minf(stock, granary_cap)
	# food surplus above the granary is sold cheaply
	if stock > granary_cap and TradeSystem.has_market_access(s, cid):
		# surplus beyond the granary spoils; only a small, bounded share is sold
		c["gold"] = float(c["gold"]) + minf((stock - granary_cap) * 0.02 * float(s["market"].get("food", {}).get("price", 1.2)), float(b["food_cons"]) * 0.004)
	# --- admin points
	var gain := 2.0 + sqrt(float(b["pop"]) / 400.0) * 0.8 + float(b["admin_cap"]) * 0.04
	gain *= 1.0 + float(m.get("admin_cap", 0.0)) * 0.5
	if float(b.get("overextension", 0.0)) > 0.0:
		gain *= maxf(0.3, 1.0 - float(b["overextension"]))
	c["admin"] = minf(float(c["admin"]) + gain, 500.0)
	# --- manpower regeneration
	var mpmax := float(b["manpower"])
	c["manpower_max"] = mpmax
	c["manpower"] = minf(mpmax * 1.0, float(c["manpower"]) + mpmax * 0.12 * (1.0 + float(m.get("manpower_recovery", 0.0))))
	if float(c["manpower"]) > mpmax:
		c["manpower"] = mpmax
	# --- inflation decays; borrowing is handled after
	c["inflation"] = float(c["inflation"]) * 0.92
	c["budget"] = b
	# --- debt / bankruptcy
	if float(c["gold"]) < 0.0:
		var deficit := -float(c["gold"])
		var room := credit_limit(s, cid) - float(c["debt"])
		if deficit <= room:
			c["debt"] = float(c["debt"]) + deficit
			c["gold"] = 0.0
			c["inflation"] = minf(0.6, float(c["inflation"]) + deficit / maxf(credit_limit(s, cid), 50.0) * 0.15)
			GS.note(s, cid, "economy", "NOTE_LOAN", {"amount": int(deficit)})
		else:
			_bankruptcy(s, cid, deficit - maxf(room, 0.0))
	elif float(c["debt"]) > 0.0 and float(c["gold"]) > 150.0 + float(b["income"]) * 2.0:
		# repay surplus automatically
		var pay := minf(float(c["debt"]), float(c["gold"]) - (150.0 + float(b["income"]) * 2.0))
		c["debt"] = float(c["debt"]) - pay
		c["gold"] = float(c["gold"]) - pay
	# --- idle treasure leaks away (court waste, embezzlement, minor expenses)
	var idle_cap := 10.0 * maxf(float(b["income"]), 50.0)
	if float(c["gold"]) > idle_cap:
		var leak := (float(c["gold"]) - idle_cap) * 0.04
		c["gold"] = float(c["gold"]) - leak
		b["leak"] = leak
	# --- bookkeeping
	c["budget"] = b
	GS.stat_add(s, cid, "total_income", float(b["income"]))
	var hist: Array = c["history_income"]
	hist.append(snappedf(float(b["income"]), 0.1))
	if hist.size() > 40:
		hist.pop_front()
	return b

## Buy administrative points with gold (5 gold each, plus inflation).
static func buy_admin(s: Dictionary, cid: String, points: float) -> Dictionary:
	var c: Dictionary = s["countries"][cid]
	var cost := points * 5.0 * (1.0 + float(c.get("inflation", 0.0)))
	if float(c["gold"]) < cost:
		return {"ok": false, "reason": "ERR_NO_GOLD", "params": {"need": int(cost)}}
	if float(c["admin"]) + points > 500.0:
		return {"ok": false, "reason": "ECON_ERR_ADMIN_CAP"}
	c["gold"] = float(c["gold"]) - cost
	c["admin"] = float(c["admin"]) + points
	return {"ok": true}

static func _bankruptcy(s: Dictionary, cid: String, overshoot: float) -> void:
	var c: Dictionary = s["countries"][cid]
	c["bankrupt_turns"] = int(c["bankrupt_turns"]) + 1
	c["debt"] = float(c["debt"]) * 0.7
	c["gold"] = 0.0
	c["stability"] = maxf(0.0, float(c["stability"]) - 12.0)
	c["inflation"] = minf(0.8, float(c["inflation"]) + 0.2)
	c["prestige"] = float(c["prestige"]) - 20.0
	GS.note(s, cid, "economy", "NOTE_BANKRUPT", {})
	GS.history(s, cid, "economy", "HIST_BANKRUPT", {})
	# disband the costliest 20% of land armies (mercenaries leave when unpaid)
	var armies: Array = GS.armies_of(s, cid)
	armies.sort_custom(func(a, b): return UnitUtil.army_upkeep(s, s["armies"][a]) > UnitUtil.army_upkeep(s, s["armies"][b]))
	var n := int(ceil(float(armies.size()) * 0.2))
	for i in range(mini(n, armies.size())):
		MilitarySystem.disband_army(s, armies[i])
