class_name DiplomacySystem
extends RefCounted
## Diplomacy: relations, treaties, wars, peace deals, vassals, coalitions. Every action has an
## acceptance evaluation that returns a score and the reasons behind it (shown in the UI).

const TRUCE_TURNS := 16
const ACTIONS := ["alliance", "break_alliance", "nap", "defensive", "access", "trade", "vassalize", "release_vassal", "guarantee",
	"gift", "improve", "sanction", "transfer", "assist", "coalition", "embargo", "declare_war", "peace", "annex_vassal"]

## --- strength / value helpers -------------------------------------------------------------------
static func military_power(s: Dictionary, cid: String) -> float:
	return UnitUtil.country_military_strength(s, cid) * (1.0 + Mods.get_mod(s, cid, "inf_atk"))

static func economic_power(s: Dictionary, cid: String) -> float:
	var b: Dictionary = s["countries"][cid].get("budget", {})
	return maxf(1.0, float(b.get("income", 10.0)))

static func total_pop(s: Dictionary, cid: String) -> float:
	var cache: Dictionary = s["_c"].get("pop_total", {})
	if cache.has(cid):
		return cache[cid]
	var t := 0.0
	for pid in GS.owned(s, cid):
		t += float(s["provinces"][pid]["pop"])
	cache[cid] = t
	s["_c"]["pop_total"] = cache
	return t

static func power_score(s: Dictionary, cid: String) -> float:
	return military_power(s, cid) * 0.5 + economic_power(s, cid) * 1.5 + total_pop(s, cid) * 0.02

static func prov_value(s: Dictionary, pid: String) -> float:
	var p: Dictionary = s["provinces"][pid]
	var v := 3.0 + float(p["dev"]) * 1.1 + float(p["pop"]) / 260.0
	var owner: String = p["owner"]
	if s["countries"].has(owner) and s["countries"][owner].get("capital", "") == pid:
		v += 14.0
	v += Mods.fort_level(s, pid) * 0.8
	return v

## Per-turn indexes (cleared by GS.rebuild_caches): which countries touch, who claims what.
static func _idx(s: Dictionary) -> Dictionary:
	var c: Dictionary = s["_c"]
	if c.has("dipl_idx"):
		return c["dipl_idx"]
	var touch := {}
	var claims := {}
	for pid in Defs.province_ids:
		var p: Dictionary = s["provinces"][pid]
		var o: String = p["owner"]
		if o == "":
			continue
		for nb in Defs.neighbors(pid):
			var o2: String = s["provinces"][nb]["owner"]
			if o2 != o and o2 != "":
				touch[o + ">" + o2] = true
		for sl in Defs.sea_links(pid):
			if sl[1] == "strait":
				var o3: String = s["provinces"][sl[0]]["owner"]
				if o3 != o and o3 != "":
					touch[o + ">" + o3] = true
		var seen := {}
		for cl in p["claims"]:
			seen[cl] = true
		for cl in p["cores"]:
			seen[cl] = true
		for cl in seen:
			if cl != o:
				var k: String = cl + ">" + o
				claims[k] = int(claims.get(k, 0)) + 1
	var idx := {"touch": touch, "claims": claims}
	c["dipl_idx"] = idx
	return idx

static func borders(s: Dictionary, a: String, b: String) -> bool:
	return _idx(s)["touch"].has(a + ">" + b)

static func claim_count(s: Dictionary, claimer: String, target: String) -> int:
	return int(ceil(float(_idx(s)["claims"].get(claimer + ">" + target, 0)) / Defs.province_scale))  # per classic-province equivalent

static func can_reach(s: Dictionary, a: String, b: String) -> bool:
	if borders(s, a, b):
		return true
	# naval reach: both have coastal provinces and attacker has a port
	var port := false
	for pid in GS.owned(s, a):
		if int(s["provinces"][pid]["buildings"].get("port", 0)) > 0:
			port = true
			break
	if not port:
		return false
	for pid in GS.owned(s, b):
		if Defs.provinces[pid]["coastal"]:
			return true
	return false

static func claims_on(s: Dictionary, claimer: String, target: String) -> Array:
	var out: Array = []
	for pid in GS.owned(s, target):
		if claimer in s["provinces"][pid]["claims"] or claimer in s["provinces"][pid]["cores"]:
			out.append(pid)
	return out

## --- evaluation of diplomatic actions -------------------------------------------------------------------
static func _add(reasons: Array, key: String, v: float) -> void:
	if absf(v) >= 0.5:
		reasons.append({"key": key, "value": snappedf(v, 0.1)})

static func common_enemies(s: Dictionary, a: String, b: String) -> int:
	var ea := GS.enemies_of(s, a)
	var n := 0
	for e in GS.enemies_of(s, b):
		if e in ea:
			n += 1
	return n

static func personality(s: Dictionary, cid: String) -> String:
	return str(s["ai"].get(cid, {}).get("personality", "opportunistic"))

## Returns {accept, score, threshold, reasons, ok(bool), reason(key)}
static func evaluate(s: Dictionary, action: String, from: String, to: String, params: Dictionary = {}) -> Dictionary:
	var res := {"accept": false, "score": 0.0, "threshold": 0.0, "reasons": [], "ok": true, "reason": ""}
	if from == to or not s["countries"].get(to, {}).get("alive", false) or not s["countries"].get(from, {}).get("alive", false):
		res["ok"] = false
		res["reason"] = "ERR_INVALID"
		return res
	var r := GS.rel(s, from, to)
	var reasons: Array = res["reasons"]
	var at_war := GS.at_war(s, from, to)
	var turn := int(s["turn"])
	var op := GS.opinion(s, to, from)
	var pers := personality(s, to)
	var score := 0.0
	var thr := 0.0
	var pf := power_score(s, from)
	var pt := power_score(s, to)
	var ratio := pf / maxf(pt, 1.0)
	var same_rel: bool = s["countries"][from]["religion"] == s["countries"][to]["religion"]
	var same_cul: bool = s["countries"][from]["culture"] == s["countries"][to]["culture"]
	var bb_from := float(s["countries"][from].get("infamy", 0.0))
	match action:
		"alliance", "defensive", "nap", "trade", "access", "guarantee", "gift", "improve", "assist", "vassalize", "transfer":
			if at_war:
				res["ok"] = false
				res["reason"] = "DIPLO_ERR_AT_WAR"
				return res
	match action:
		"alliance":
			if r["alliance"]:
				res["ok"] = false
				res["reason"] = "DIPLO_ERR_HAVE"
				return res
			thr = 30.0
			_add(reasons, "DR_OPINION", op * 0.25)
			score += op * 0.25
			var ce := float(common_enemies(s, from, to)) * 14.0
			_add(reasons, "DR_COMMON_ENEMY", ce)
			score += ce
			var rel_b := 10.0 if same_rel else -9.0
			_add(reasons, "DR_RELIGION_SAME" if same_rel else "DR_RELIGION_DIFF", rel_b)
			score += rel_b
			var cul_b := 6.0 if same_cul else 0.0
			_add(reasons, "DR_CULTURE", cul_b)
			score += cul_b
			var strength := clampf((ratio - 0.5) * 8.0, -8.0, 12.0) if ratio >= 0.5 else (ratio - 0.5) * 16.0
			_add(reasons, "DR_STRENGTH", strength)
			score += strength
			var trust := (float(r["trust"]) - 50.0) * 0.3
			_add(reasons, "DR_TRUST", trust)
			score += trust
			var claim_pen := -float(claim_count(s, from, to) + claim_count(s, to, from)) * 8.0
			_add(reasons, "DR_CLAIMS", claim_pen)
			score += claim_pen
			var bb := -bb_from * 0.5
			_add(reasons, "DR_INFAMY", bb)
			score += bb
			var pp: float = {"diplomatic": 12.0, "isolationist": -18.0, "aggressive": -4.0, "defensive": 6.0, "coalition_builder": 14.0, "naval_trade": 4.0}.get(pers, 0.0)
			_add(reasons, "DR_PERSONALITY", pp)
			score += pp
			var sh := 6.0 if borders(s, from, to) else 0.0
			if r["trade"]:
				_add(reasons, "DR_TRADE_PARTNER", 8.0)
				score += 8.0
			if DynastySystem.married(s, from, to):
				_add(reasons, "DR_DYNASTIC_TIES", 18.0)
				score += 18.0
			if sh != 0.0 and ce <= 0.0:
				_add(reasons, "DR_BORDER_FRICTION", -6.0)
				score -= 6.0
			if int(r["truce_until"]) > turn:
				_add(reasons, "DR_RECENT_WAR", -15.0)
				score -= 15.0
			if GS.overlord_of(s, to) != "" or GS.overlord_of(s, from) != "":
				res["ok"] = false
				res["reason"] = "DIPLO_ERR_VASSAL"
				return res
		"break_alliance":
			if not r["alliance"]:
				res["ok"] = false
				res["reason"] = "DIPLO_ERR_NO_ALLIANCE"
				return res
			res["accept"] = true
			return res
		"nap":
			if int(r["nap_until"]) > turn:
				res["ok"] = false
				res["reason"] = "DIPLO_ERR_HAVE"
				return res
			thr = 5.0
			_add(reasons, "DR_OPINION", op * 0.2)
			score += op * 0.2
			var cl := -float(claim_count(s, from, to)) * 6.0
			_add(reasons, "DR_CLAIMS", cl)
			score += cl
			var wk := 8.0 if ratio < 0.7 else (-5.0 if ratio > 2.0 else 3.0)
			_add(reasons, "DR_STRENGTH", wk)
			score += wk
			var pp2: float = {"diplomatic": 10.0, "isolationist": 8.0, "aggressive": -14.0, "expansionist": -10.0, "opportunistic": -6.0}.get(pers, 0.0)
			_add(reasons, "DR_PERSONALITY", pp2)
			score += pp2
			var bb2 := -bb_from * 0.4
			_add(reasons, "DR_INFAMY", bb2)
			score += bb2
		"defensive":
			thr = 15.0
			_add(reasons, "DR_OPINION", op * 0.22)
			score += op * 0.22
			var ce2 := float(common_enemies(s, from, to)) * 12.0 + (8.0 if borders(s, from, to) and ratio < 1.0 else 0.0)
			_add(reasons, "DR_COMMON_ENEMY", ce2)
			score += ce2
			var rb := 6.0 if same_rel else -4.0
			_add(reasons, "DR_RELIGION_SAME" if same_rel else "DR_RELIGION_DIFF", rb)
			score += rb
			var pp3: float = {"diplomatic": 8.0, "isolationist": -10.0, "defensive": 8.0}.get(pers, 0.0)
			_add(reasons, "DR_PERSONALITY", pp3)
			score += pp3
		"access":
			thr = 16.0
			_add(reasons, "DR_OPINION", op * 0.25)
			score += op * 0.25
			if r["alliance"]:
				_add(reasons, "DR_ALLIES", 25.0)
				score += 25.0
			if r["trade"]:
				_add(reasons, "DR_TRADE_PARTNER", 6.0)
				score += 6.0
			var thr_pen := -clampf(ratio - 1.0, 0.0, 3.0) * 6.0
			_add(reasons, "DR_THREAT", thr_pen)
			score += thr_pen
			var cl3 := -float(claim_count(s, from, to)) * 10.0
			_add(reasons, "DR_CLAIMS", cl3)
			score += cl3
			var pp4: float = {"isolationist": -14.0, "diplomatic": 5.0}.get(pers, 0.0)
			_add(reasons, "DR_PERSONALITY", pp4)
			score += pp4
		"trade":
			if r["trade"]:
				res["ok"] = false
				res["reason"] = "DIPLO_ERR_HAVE"
				return res
			if r["embargo"].get(to, false) or r["embargo"].get(from, false):
				res["ok"] = false
				res["reason"] = "DIPLO_ERR_EMBARGO"
				return res
			thr = 6.0
			_add(reasons, "DR_OPINION", op * 0.2)
			score += op * 0.2
			var gain := 8.0
			_add(reasons, "DR_MUTUAL_GAIN", gain)
			score += gain
			var pp5: float = {"economic": 12.0, "diplomatic": 6.0, "isolationist": -12.0, "aggressive": -3.0}.get(pers, 0.0)
			_add(reasons, "DR_PERSONALITY", pp5)
			score += pp5
			if not same_rel:
				_add(reasons, "DR_RELIGION_DIFF", -3.0)
				score -= 3.0
			if not borders(s, from, to) and not (can_reach(s, from, to) and can_reach(s, to, from)):
				res["ok"] = false
				res["reason"] = "DIPLO_ERR_NO_ROUTE"
				return res
		"guarantee":
			if r["guarantee"].get(to, false):
				res["ok"] = false
				res["reason"] = "DIPLO_ERR_HAVE"
				return res
			thr = 0.0
			_add(reasons, "DR_OPINION", op * 0.15)
			score += op * 0.15 + 12.0
			_add(reasons, "DR_PROTECTION", 12.0)
		"vassalize":
			thr = 45.0
			if GS.overlord_of(s, to) != "":
				res["ok"] = false
				res["reason"] = "DIPLO_ERR_VASSAL"
				return res
			_add(reasons, "DR_OPINION", op * 0.2)
			score += op * 0.2
			var rr := clampf(ratio - 1.0, 0.0, 4.0) * 9.0
			_add(reasons, "DR_STRENGTH", rr)
			score += rr
			var threatened := float(GS.enemies_of(s, to).size()) * 10.0
			_add(reasons, "DR_THREATENED", threatened)
			score += threatened
			var gold := float(params.get("gold", 0.0))
			var sweet := gold / maxf(economic_power(s, to), 5.0) * 20.0
			_add(reasons, "DR_PAYMENT", sweet)
			score += sweet
			if bool(s["countries"][to].get("is_player", false)):
				score -= 15.0
		"gift":
			res["accept"] = true
			return res
		"improve":
			res["accept"] = true
			return res
		"assist":
			thr = 12.0
			if not r["alliance"]:
				res["ok"] = false
				res["reason"] = "DIPLO_ERR_NO_ALLIANCE"
				return res
			_add(reasons, "DR_OPINION", op * 0.25)
			score += op * 0.25
			var stren := clampf(power_score(s, to) / maxf(power_score(s, from), 1.0), 0.2, 2.0) * 6.0
			_add(reasons, "DR_STRENGTH", stren)
			score += stren
			score += 10.0
			_add(reasons, "DR_ALLIES", 10.0)
		"transfer":
			thr = 10.0
			var give: Array = params.get("give", [])
			var want: Array = params.get("want", [])
			var vg := 0.0
			var vw := 0.0
			for pid in give:
				vg += prov_value(s, pid)
			for pid in want:
				vw += prov_value(s, pid)
			vw += float(params.get("gold_want", 0.0)) / 8.0
			vg += float(params.get("gold_give", 0.0)) / 8.0
			var bal := vg - vw * 1.25
			_add(reasons, "DR_OFFER_VALUE", bal)
			score += bal
			_add(reasons, "DR_OPINION", op * 0.1)
			score += op * 0.1
		"coalition":
			thr = 10.0
			_add(reasons, "DR_OPINION", op * 0.2)
			score += op * 0.2
			var tgt := str(params.get("target", ""))
			if tgt == "":
				res["ok"] = false
				res["reason"] = "ERR_INVALID"
				return res
			var tbb := float(s["countries"][tgt].get("infamy", 0.0)) * 0.6
			_add(reasons, "DR_INFAMY_TARGET", tbb)
			score += tbb
			var topin := -GS.opinion(s, to, tgt) * 0.2
			_add(reasons, "DR_DISLIKE_TARGET", topin)
			score += topin
			var tb := 6.0 if borders(s, to, tgt) else 0.0
			_add(reasons, "DR_BORDER_FRICTION", tb)
			score += tb
		"annex_vassal":
			if GS.overlord_of(s, to) != from:
				res["ok"] = false
				res["reason"] = "DIPLO_ERR_NOT_VASSAL"
				return res
			var t0: int = int(s["countries"][to].get("vassal_since", turn))
			if turn - t0 < 24:
				res["ok"] = false
				res["reason"] = "DIPLO_ERR_TOO_EARLY"
				params["need_turns"] = 24 - (turn - t0)
				return res
			res["accept"] = true
			return res
		"embargo", "sanction":
			res["accept"] = true
			return res
		"release_vassal":
			res["accept"] = GS.overlord_of(s, to) == from
			res["ok"] = res["accept"]
			if not res["ok"]:
				res["reason"] = "DIPLO_ERR_NOT_VASSAL"
			return res
		_:
			res["ok"] = false
			res["reason"] = "ERR_INVALID"
			return res
	res["score"] = snappedf(score, 0.1)
	res["threshold"] = thr
	res["accept"] = score >= thr
	return res

## Execute an action (after AI acceptance for others). Returns {ok, accepted, ...}
static func perform(s: Dictionary, action: String, from: String, to: String, params: Dictionary = {}) -> Dictionary:
	var ev := evaluate(s, action, from, to, params)
	if not ev["ok"]:
		return {"ok": false, "reason": ev["reason"], "eval": ev}
	var r := GS.rel(s, from, to)
	var turn := int(s["turn"])
	if action in ["alliance", "defensive", "nap", "access", "trade", "guarantee", "vassalize", "transfer", "assist", "coalition"]:
		if not ev["accept"]:
			GS.add_opinion(s, to, from, -1.0)
			return {"ok": true, "accepted": false, "eval": ev}
	match action:
		"alliance":
			r["alliance"] = true
			r["defensive"] = true
			r["trust"] = minf(100.0, float(r["trust"]) + 10.0)
			GS.add_opinion(s, to, from, 15.0)
			GS.add_opinion(s, from, to, 15.0)
			GS.stat_add(s, from, "alliances", 1.0)
			GS.stat_add(s, to, "alliances", 1.0)
			GS.history(s, from, "diplomacy", "HIST_ALLIANCE", {"other": to})
		"break_alliance":
			r["alliance"] = false
			r["trust"] = maxf(0.0, float(r["trust"]) - 15.0)
			GS.add_opinion(s, to, from, -25.0)
			s["countries"][from]["prestige"] = float(s["countries"][from]["prestige"]) - 8.0
			GS.history(s, from, "diplomacy", "HIST_ALLIANCE_BROKEN", {"other": to})
		"nap":
			r["nap_until"] = turn + 40
			GS.add_opinion(s, to, from, 5.0)
		"defensive":
			r["defensive"] = true
			GS.add_opinion(s, to, from, 8.0)
		"access":
			r["access"][from] = true
			r["access_grant"] = {from: true, to: r.get("access_grant", {}).get(to, false)}
			GS.add_opinion(s, to, from, 2.0)
		"trade":
			r["trade"] = true
			GS.add_opinion(s, to, from, 8.0)
			GS.add_opinion(s, from, to, 8.0)
			TradeSystem.invalidate(s)
		"guarantee":
			r["guarantee"][to] = true      # `from` guarantees `to`
			GS.add_opinion(s, to, from, 20.0)
			GS.stat_add(s, from, "guarantees", 1.0)
		"vassalize":
			make_vassal(s, from, to, true)
		"gift":
			var g := float(params.get("gold", 0.0))
			var c: Dictionary = s["countries"][from]
			if g <= 0.0 or float(c["gold"]) < g:
				return {"ok": false, "reason": "ERR_NO_GOLD", "params": {"need": int(g)}}
			c["gold"] = float(c["gold"]) - g
			s["countries"][to]["gold"] = float(s["countries"][to]["gold"]) + g
			var inc := economic_power(s, to)
			GS.add_opinion(s, to, from, clampf(g / maxf(inc, 10.0) * 12.0, 1.0, 40.0))
			r["gifted"] = float(r["gifted"]) + g
			GS.stat_add(s, from, "gifts", g)
			return {"ok": true, "accepted": true, "eval": ev}
		"improve":
			var c2: Dictionary = s["countries"][from]
			if float(c2["admin"]) < 10.0:
				return {"ok": false, "reason": "ERR_NO_ADMIN", "params": {"need": 10}}
			c2["admin"] = float(c2["admin"]) - 10.0
			r["improving"][from] = 12
			return {"ok": true, "accepted": true, "eval": ev}
		"assist":
			var wars := GS.wars_of(s, from)
			var joined := false
			for wid in wars:
				if join_war(s, to, wid, from):
					joined = true
			if not joined:
				return {"ok": false, "reason": "DIPLO_ERR_CANNOT_JOIN", "eval": ev}
		"transfer":
			for pid in params.get("give", []):
				transfer_province(s, pid, from, to)
			for pid in params.get("want", []):
				transfer_province(s, pid, to, from)
			var gg := float(params.get("gold_give", 0.0))
			var gw := float(params.get("gold_want", 0.0))
			s["countries"][from]["gold"] = float(s["countries"][from]["gold"]) - gg + gw
			s["countries"][to]["gold"] = float(s["countries"][to]["gold"]) + gg - gw
			GS.add_opinion(s, to, from, 5.0)
		"coalition":
			pass
		"embargo":
			r["embargo"][from] = true
			GS.add_opinion(s, to, from, -30.0)
			TradeSystem.invalidate(s)
		"sanction":
			r["sanction"][from] = true
			GS.add_opinion(s, to, from, -20.0)
			TradeSystem.invalidate(s)
		"release_vassal":
			release_vassal(s, from, to)
		"annex_vassal":
			annex_vassal(s, from, to)
	return {"ok": true, "accepted": true, "eval": ev}

static func lift_embargo(s: Dictionary, from: String, to: String) -> void:
	var r := GS.rel(s, from, to)
	r["embargo"][from] = false
	r["sanction"][from] = false
	TradeSystem.invalidate(s)

## --- vassals ------------------------------------------------------------------------------------------------
static func make_vassal(s: Dictionary, overlord: String, vassal: String, announce: bool = true) -> void:
	var v: Dictionary = s["countries"][vassal]
	v["overlord"] = overlord
	v["vassal_since"] = s["turn"]
	var r := GS.rel(s, overlord, vassal)
	r["alliance"] = false
	r["access"][overlord] = true
	r["access"][vassal] = true
	GS.add_opinion(s, vassal, overlord, 10.0)
	if announce:
		GS.history(s, overlord, "diplomacy", "HIST_VASSAL", {"other": vassal})
		GS.stat_add(s, overlord, "vassals_created", 1.0)
	# vassals leave wars against their overlord's allies handled elsewhere

static func release_vassal(s: Dictionary, overlord: String, vassal: String) -> void:
	s["countries"][vassal]["overlord"] = ""
	GS.add_opinion(s, vassal, overlord, 30.0)
	GS.history(s, overlord, "diplomacy", "HIST_VASSAL_RELEASED", {"other": vassal})

static func annex_vassal(s: Dictionary, overlord: String, vassal: String) -> Dictionary:
	var c: Dictionary = s["countries"][overlord]
	var cost := 30.0 + GS.owned(s, vassal).size() * 8.0
	if float(c["admin"]) < cost:
		return {"ok": false, "reason": "ERR_NO_ADMIN", "params": {"need": int(cost)}}
	c["admin"] = float(c["admin"]) - cost
	annex_country(s, vassal, overlord, true)
	return {"ok": true}

## Absorb a whole country (annexation / peaceful integration).
static func annex_country(s: Dictionary, target: String, by: String, peaceful: bool) -> void:
	for pid in GS.owned(s, target).duplicate():
		transfer_province(s, pid, target, by)
	GS.stat_add(s, by, "countries_annexed", 1.0)
	GS.history(s, by, "diplomacy", "HIST_ANNEXED", {"other": target})
	_kill_country(s, target, by)

static func transfer_province(s: Dictionary, pid: String, from: String, to: String) -> void:
	var p: Dictionary = s["provinces"][pid]
	p["owner"] = to
	p["controller"] = to
	p["siege"] = null
	p["queue"] = []
	p["conquered_turn"] = s["turn"]
	if to not in p["cores"] and to in s["countries"]:
		pass
	# armies of the loser in the province are displaced
	for aid in GS.armies_at(s, pid).duplicate():
		var a: Dictionary = s["armies"][aid]
		if a["owner"] == from and s["armies"].has(aid):
			MilitarySystem.disband_army(s, aid) if not GS.allied(s, from, to) and GS.at_war(s, from, to) else null
	GS.rebuild_caches(s)
	Mods.invalidate(s)
	TradeSystem.invalidate(s)

static func _kill_country(s: Dictionary, cid: String, by: String) -> void:
	var c: Dictionary = s["countries"][cid]
	if not c["alive"]:
		return
	c["alive"] = false
	c["destroyed_turn"] = s["turn"]
	c["destroyed_by"] = by
	for aid in GS.armies_of(s, cid).duplicate():
		MilitarySystem.disband_army(s, aid)
	for oid in GS.vassals_of(s, cid):
		s["countries"][oid]["overlord"] = ""
	# end wars
	for wid in GS.wars_of(s, cid):
		var w: Dictionary = s["wars"][wid]
		w["attackers"].erase(cid)
		w["defenders"].erase(cid)
		if w["attackers"].is_empty() or w["defenders"].is_empty():
			w["ended"] = true
			w["end_turn"] = s["turn"]
	for k in s["relations"].keys():
		var rr: Dictionary = s["relations"][k]
		if cid in k.split("|"):
			rr["alliance"] = false
	GS.history(s, cid, "diplomacy", "HIST_DESTROYED", {"by": by})
	GS.note(s, cid, "diplomacy", "NOTE_DESTROYED", {"by": by})
	for oid in GS.alive_countries(s):
		GS.note(s, oid, "world", "NOTE_COUNTRY_FELL", {"country": cid})
	if s["player"] == cid:
		s["player_destroyed"] = true

static func check_destroyed(s: Dictionary) -> void:
	for cid in GS.alive_countries(s):
		if GS.owned(s, cid).is_empty():
			_kill_country(s, cid, "")

## --- wars ----------------------------------------------------------------------------------------------------
static func can_declare(s: Dictionary, a: String, b: String, cb: String) -> Dictionary:
	if a == b or not s["countries"][b].get("alive", false):
		return {"ok": false, "reason": "ERR_INVALID"}
	if b == "REB":
		return {"ok": false, "reason": "ERR_INVALID"}
	if GS.at_war(s, a, b):
		return {"ok": false, "reason": "WAR_ERR_ALREADY"}
	var r := GS.rel(s, a, b)
	if int(r["truce_until"]) > int(s["turn"]):
		return {"ok": false, "reason": "WAR_ERR_TRUCE", "params": {"turns": int(r["truce_until"]) - int(s["turn"])}}
	if GS.overlord_of(s, a) == b or GS.overlord_of(s, b) == a and false:
		return {"ok": false, "reason": "WAR_ERR_VASSAL"}
	if not can_reach(s, a, b):
		return {"ok": false, "reason": "WAR_ERR_NO_REACH"}
	if GS.allied(s, a, b) and cb != "liberation":
		return {"ok": false, "reason": "WAR_ERR_ALLIED"}
	if int(s["turn"]) < 1 and not bool(s.get("custom", false)) and false:
		return {"ok": false, "reason": "ERR_INVALID"}
	return {"ok": true}

static func available_cbs(s: Dictionary, a: String, b: String) -> Array:
	var out: Array = []
	var claims := claims_on(s, a, b)
	if not claims.is_empty():
		out.append("claim")
	var ca: Dictionary = s["countries"][a]
	var cbd: Dictionary = s["countries"][b]
	if ca["religion"] != cbd["religion"] and "holy_war" in Defs.governments.get(ca["gov"], {}).get("features", []):
		out.append("holy_war")
	if GS.vassals_of(s, b).size() > 0 and false:
		out.append("liberation")
	for wid in GS.wars_of(s, a):
		pass
	if float(cbd.get("infamy", 0.0)) >= 40.0 and not GS.allied(s, a, b):
		out.append("containment")
	if EspionageSystem.has_incident(s, a, b):
		out.append("incident")
	out.append("conquest")   # always possible, but infamous
	return out

static func declare_war(s: Dictionary, a: String, b: String, cb: String, goals: Array = []) -> Dictionary:
	var chk := can_declare(s, a, b, cb)
	if not chk["ok"]:
		return chk
	var r := GS.rel(s, a, b)
	# breaking a non-aggression pact
	if int(r["nap_until"]) > int(s["turn"]):
		r["nap_until"] = -1
		s["countries"][a]["prestige"] = float(s["countries"][a]["prestige"]) - 25.0
		s["countries"][a]["stability"] = maxf(0.0, float(s["countries"][a]["stability"]) - 3.0)
		for oid in GS.alive_countries(s):
			if oid != a:
				GS.add_opinion(s, oid, a, -8.0)
	if GS.allied(s, a, b):
		r["alliance"] = false
	var wid := start_war(s, [a], [b], cb, goals, false)
	# infamy for unjustified aggression
	var infamy: float = {"conquest": 14.0, "claim": 4.0, "holy_war": 3.0, "containment": 2.0, "liberation": 0.0, "reconquest": 1.0, "incident": 1.0}.get(cb, 8.0)
	if cb == "conquest":
		infamy += 0.0
	var ac: Dictionary = s["countries"][a]
	ac["infamy"] = minf(100.0, float(ac.get("infamy", 0.0)) + infamy)
	GS.add_opinion(s, b, a, -60.0)
	for oid in GS.alive_countries(s):
		if oid != a and oid != b:
			GS.add_opinion(s, oid, a, -infamy * 0.4)
			if GS.allied(s, oid, b):
				GS.add_opinion(s, oid, a, -20.0)
	GS.history(s, a, "war", "HIST_WAR_DECLARED", {"other": b, "cb": cb})
	return {"ok": true, "war": wid}

static func start_war(s: Dictionary, attackers: Array, defenders: Array, cb: String, goals: Array, at_start: bool) -> String:
	var wid := "W%d" % int(s["next_war_id"])
	s["next_war_id"] = int(s["next_war_id"]) + 1
	var w := {"id": wid, "attackers": attackers.duplicate(), "defenders": defenders.duplicate(), "leader_a": attackers[0], "leader_d": defenders[0],
		"start_turn": s["turn"], "cb": cb, "goals": goals, "score": 0.0, "ended": false, "battles": 0, "occupied": {}}
	s["wars"][wid] = w
	for x in attackers + defenders:
		GS.rel(s, attackers[0], x)
	# vassals follow overlords; allies are called
	if not at_start:
		for d in defenders.duplicate():
			_summon(s, wid, d, "defenders")
		for a in attackers.duplicate():
			_summon(s, wid, a, "attackers")
	else:
		for vs in attackers + defenders:
			pass
	for x in attackers + defenders:
		GS.stat_add(s, x, "wars", 1.0)
		var tr := GS.rel(s, attackers[0], x)
	for x in attackers:
		for y in defenders:
			var rr := GS.rel(s, x, y)
			rr["wars_fought"] = int(rr["wars_fought"]) + 1
			rr["alliance"] = false
	TradeSystem.invalidate(s)
	return wid

static func _summon(s: Dictionary, wid: String, member: String, side: String) -> void:
	var w: Dictionary = s["wars"][wid]
	var leader: String = w["leader_a"] if side == "attackers" else w["leader_d"]
	# vassals of the member always join
	for v in GS.vassals_of(s, member):
		if v not in w["attackers"] and v not in w["defenders"] and not _on_other_side(w, v, side):
			(w[side] as Array).append(v)
	# allies
	for oid in GS.alive_countries(s):
		if oid == member or oid in w["attackers"] or oid in w["defenders"]:
			continue
		var r := GS.rel(s, member, oid)
		var joins := false
		if bool(r["alliance"]):
			if side == "defenders":
				joins = true   # defensive pacts are honoured; those with strong obligations fail only if hostile to the leader
			else:
				joins = _ally_accepts_offensive(s, oid, member, wid)
		elif side == "defenders" and bool(r["guarantee"].get(member, false)):
			# guarantors defend, but only if they can afford the war
			joins = power_score(s, oid) > 0.25 * power_score(s, leader) and not GS.at_war(s, oid, member)
		if joins and not _on_other_side(w, oid, side):
			if int(GS.rel(s, oid, leader)["truce_until"]) <= int(s["turn"]) or side == "defenders":
				(w[side] as Array).append(oid)
				for v in GS.vassals_of(s, oid):
					if v not in w["attackers"] and v not in w["defenders"]:
						(w[side] as Array).append(v)
				GS.note(s, oid, "diplomacy", "NOTE_ALLY_JOINED", {"other": member}, "")
				GS.stat_add(s, oid, "wars", 1.0)

static func _on_other_side(w: Dictionary, cid: String, side: String) -> bool:
	return cid in (w["defenders"] if side == "attackers" else w["attackers"])

static func _ally_accepts_offensive(s: Dictionary, ally: String, caller: String, wid: String) -> bool:
	var w: Dictionary = s["wars"][wid]
	var op := GS.opinion(s, ally, caller)
	var sc := op * 0.2 + 8.0
	if personality(s, ally) == "isolationist":
		sc -= 20.0
	if personality(s, ally) == "aggressive":
		sc += 8.0
	var enemies: Array = w["defenders"]
	for e in enemies:
		if GS.allied(s, ally, e):
			return false
		sc -= 0.0
	return sc > 6.0 and not bool(s["countries"][ally].get("is_player", false))

static func join_war(s: Dictionary, cid: String, wid: String, ally_of: String) -> bool:
	var w: Dictionary = s["wars"][wid]
	if w.get("ended", false) or cid in w["attackers"] or cid in w["defenders"]:
		return false
	var side := "attackers" if ally_of in w["attackers"] else "defenders"
	var other: Array = w["defenders"] if side == "attackers" else w["attackers"]
	for e in other:
		if GS.allied(s, cid, e):
			return false
		if int(GS.rel(s, cid, e)["truce_until"]) > int(s["turn"]):
			return false
	(w[side] as Array).append(cid)
	GS.stat_add(s, cid, "wars", 1.0)
	TradeSystem.invalidate(s)
	return true

## --- war score / peace -------------------------------------------------------------------------------------------
static func side_of(w: Dictionary, cid: String) -> String:
	if cid in w["attackers"]:
		return "attackers"
	if cid in w["defenders"]:
		return "defenders"
	return ""

static func add_score(s: Dictionary, wid: String, side: String, v: float) -> void:
	var w: Dictionary = s["wars"][wid]
	w["score"] = clampf(float(w["score"]) + (v if side == "attackers" else -v), -100.0, 100.0)

static func on_battle(s: Dictionary, winner: String, loser: String, losses: float) -> void:
	for wid in GS.wars_of(s, winner):
		var w: Dictionary = s["wars"][wid]
		if loser in w["attackers"] or loser in w["defenders"]:
			if side_of(w, winner) != side_of(w, loser):
				add_score(s, wid, side_of(w, winner), clampf(losses * 0.9 + 0.6, 0.3, 6.0))
				w["battles"] = int(w["battles"]) + 1

static func on_occupation(s: Dictionary, by: String, owner: String, pid: String) -> void:
	for wid in GS.wars_of(s, by):
		var w: Dictionary = s["wars"][wid]
		if side_of(w, owner) != "" and side_of(w, by) != side_of(w, owner):
			var v := prov_value(s, pid) * 0.7
			add_score(s, wid, side_of(w, by), v)
			w["occupied"][pid] = by

static func war_for_pair(s: Dictionary, a: String, b: String) -> String:
	for wid in GS.wars_of(s, a):
		var w: Dictionary = s["wars"][wid]
		if side_of(w, a) != "" and side_of(w, b) != "" and side_of(w, a) != side_of(w, b):
			return wid
	return ""

## War score from the point of view of `cid` (positive = winning)
static func score_for(s: Dictionary, wid: String, cid: String) -> float:
	var w: Dictionary = s["wars"][wid]
	var sc := float(w["score"])
	return sc if side_of(w, cid) == "attackers" else -sc

static func terms_cost(s: Dictionary, winner: String, loser: String, terms: Dictionary) -> float:
	var cost := 0.0
	for pid in terms.get("provinces", []):
		var v := prov_value(s, pid) * 0.9
		if winner in s["provinces"][pid]["claims"] or winner in s["provinces"][pid]["cores"]:
			v *= 0.7
		cost += v
	cost += float(terms.get("gold", 0.0)) / maxf(economic_power(s, loser) * 4.0, 20.0) * 30.0
	if terms.get("vassalize", false):
		cost += 40.0 + float(GS.owned(s, loser).size()) * 2.0
	if terms.get("release", []).size() > 0:
		cost += float(terms["release"].size()) * 6.0
	if terms.get("annex", false):
		cost += 100.0
	return cost

## AI/ player peace evaluation: proposer sends terms to receiver.
static func peace_eval(s: Dictionary, wid: String, proposer: String, receiver: String, terms: Dictionary) -> Dictionary:
	var w: Dictionary = s["wars"][wid]
	var reasons: Array = []
	var S := score_for(s, wid, proposer)    # proposer's lead
	var exh_r := float(s["countries"][receiver].get("war_exhaustion", 0.0))
	var exh_p := float(s["countries"][proposer].get("war_exhaustion", 0.0))
	var cost := terms_cost(s, proposer, receiver, terms) if not terms.get("white", false) else 0.0
	_add(reasons, "DR_WARSCORE", S)
	_add(reasons, "DR_EXHAUSTION", exh_r * 0.35)
	_add(reasons, "DR_TERMS_COST", -cost)
	var len_bonus := minf(10.0, float(int(s["turn"]) - int(w["start_turn"])) * 0.12)
	_add(reasons, "DR_WAR_LENGTH", len_bonus)
	var total := S + exh_r * 0.35 + len_bonus - cost
	var accept: bool
	var pers := personality(s, receiver)
	var stubborn: float = {"aggressive": 8.0, "defensive": 0.0, "diplomatic": -6.0, "isolationist": -4.0}.get(pers, 0.0)
	_add(reasons, "DR_PERSONALITY", -stubborn)
	if terms.get("white", false):
		# receiver accepts a white peace unless they are clearly winning
		var lead := -S
		accept = lead <= 8.0 + exh_r * 0.35 + len_bonus - stubborn
		total = 8.0 + exh_r * 0.35 + len_bonus - stubborn - lead
	else:
		accept = total >= stubborn + (0.0 if cost <= S else 5.0)
		# a receiver on the verge of collapse always accepts reasonable demands
		if S >= 60.0 and cost <= S:
			accept = true
	return {"accept": accept, "score": snappedf(total, 0.1), "cost": snappedf(cost, 0.1), "reasons": reasons, "lead": S}

## The losing side offers concessions to the winner. The winner accepts once the offer is worth enough
## relative to its lead (it will not accept a token gesture while crushing the conceder).
static func concession_eval(s: Dictionary, wid: String, conceder: String, winner: String, terms: Dictionary) -> Dictionary:
	var lead := score_for(s, wid, winner)
	var worth := terms_cost(s, winner, conceder, terms)
	var reasons: Array = []
	_add(reasons, "DR_WARSCORE", lead)
	_add(reasons, "DR_TERMS_COST", worth)
	var exh := float(s["countries"][winner].get("war_exhaustion", 0.0))
	_add(reasons, "DR_EXHAUSTION", exh * 0.3)
	var need := maxf(0.0, lead * 0.55 - exh * 0.3)
	var accept := worth >= need
	return {"accept": accept, "score": snappedf(worth - need, 0.1), "cost": snappedf(worth, 0.1), "reasons": reasons, "lead": lead}

static func make_peace(s: Dictionary, wid: String, proposer: String, receiver: String, terms: Dictionary) -> Dictionary:
	var w: Dictionary = s["wars"].get(wid, {})
	if w.is_empty() or w.get("ended", false):
		return {"ok": false, "reason": "ERR_INVALID"}
	if side_of(w, proposer) == "" or side_of(w, receiver) == "" or side_of(w, proposer) == side_of(w, receiver):
		return {"ok": false, "reason": "ERR_INVALID"}
	var winner := proposer
	var loser := receiver
	if terms.get("white", false):
		pass
	# transfer demanded provinces
	for pid in terms.get("provinces", []):
		var from: String = s["provinces"][pid]["owner"]
		var to_c := winner
		transfer_province(s, pid, from, to_c)
		GS.stat_add(s, to_c, "provinces_conquered", 1.0)
		s["provinces"][pid]["conquered_turn"] = s["turn"]
		if to_c == s["player"]:
			GS.note(s, to_c, "diplomacy", "NOTE_PROVINCE_GAINED", {"province": pid}, pid)
	if float(terms.get("gold", 0.0)) > 0.0:
		var g := minf(float(terms["gold"]), maxf(0.0, float(s["countries"][loser]["gold"])) + 50.0)
		s["countries"][loser]["gold"] = float(s["countries"][loser]["gold"]) - g
		s["countries"][winner]["gold"] = float(s["countries"][winner]["gold"]) + g
	if terms.get("vassalize", false):
		make_vassal(s, winner, loser, true)
	if terms.get("annex", false):
		annex_country(s, loser, winner, false)
	# occupied provinces revert to their owners
	for pid in s["provinces"]:
		var p: Dictionary = s["provinces"][pid]
		if p["controller"] != p["owner"]:
			if (p["controller"] == winner and p["owner"] == loser) or (p["controller"] == loser and p["owner"] == winner):
				p["controller"] = p["owner"]
				p["siege"] = null
	# the loser's armies on the winner's soil go home (disbanded for simplicity if no route)
	for aid in GS.armies_of(s, loser).duplicate():
		var a: Dictionary = s["armies"].get(aid, {})
		if a.is_empty() or a["loc"] == "":
			continue
		var po: String = s["provinces"][a["loc"]]["owner"]
		if po == winner:
			MilitarySystem.disband_army(s, aid)
	for aid in GS.armies_of(s, winner).duplicate():
		var a2: Dictionary = s["armies"].get(aid, {})
		if a2.is_empty() or a2["loc"] == "":
			continue
		if s["provinces"][a2["loc"]]["owner"] == loser:
			MilitarySystem.disband_army(s, aid)
	# bookkeeping: truce, stats, wars won
	var winner_leads := score_for(s, wid, winner) > 0.0
	var r := GS.rel(s, winner, loser)
	r["truce_until"] = int(s["turn"]) + TRUCE_TURNS
	if side_of(w, proposer) == "attackers" and (w["leader_a"] == proposer or w["leader_d"] == receiver) or w["leader_a"] in [proposer, receiver] and w["leader_d"] in [proposer, receiver]:
		w["ended"] = true
		w["end_turn"] = s["turn"]
		w["result"] = "white" if terms.get("white", false) else ("attacker_win" if score_for(s, wid, w["leader_a"]) > 0 else "defender_win")
		for x in w["attackers"] + w["defenders"]:
			for y in w["attackers"] + w["defenders"]:
				if side_of(w, x) != side_of(w, y):
					GS.rel(s, x, y)["truce_until"] = int(s["turn"]) + TRUCE_TURNS
		for cid in w["attackers"] + w["defenders"]:
			if s["countries"].has(cid):
				s["countries"][cid]["war_exhaustion"] = maxf(0.0, float(s["countries"][cid]["war_exhaustion"]) * 0.5)
	else:
		# separate peace: the smaller participant leaves the war
		var leaver := receiver if receiver not in [w["leader_a"], w["leader_d"]] else proposer
		w["attackers"].erase(leaver)
		w["defenders"].erase(leaver)
	if not terms.get("white", false):
		GS.stat_add(s, winner, "wars_won", 1.0)
		GS.stat_add(s, loser, "wars_lost", 1.0)
		s["countries"][winner]["prestige"] = float(s["countries"][winner]["prestige"]) + 20.0
		GS.history(s, winner, "war", "HIST_PEACE_WON", {"other": loser})
		GS.history(s, loser, "war", "HIST_PEACE_LOST", {"other": winner})
		GS.add_opinion(s, loser, winner, -40.0)
	else:
		GS.history(s, winner, "war", "HIST_PEACE_WHITE", {"other": loser})
	GS.rebuild_caches(s)
	check_destroyed(s)
	TradeSystem.invalidate(s)
	return {"ok": true}

## --- per-turn upkeep -------------------------------------------------------------------------------------------------
static func target_opinion(s: Dictionary, a: String, b: String) -> float:
	var ca: Dictionary = s["countries"][a]
	var cb: Dictionary = s["countries"][b]
	var t := 0.0
	if ca["religion"] == cb["religion"]:
		t += 12.0
	else:
		t -= 10.0
	if ca["culture"] == cb["culture"]:
		t += 6.0
	var r := GS.rel(s, a, b)
	if r["alliance"]:
		t += 40.0
	if r["trade"]:
		t += 12.0
	if int(r["nap_until"]) > int(s["turn"]):
		t += 6.0
	if r["guarantee"].get(a, false):
		t += 10.0     # b guarantees a
	if GS.overlord_of(s, a) == b or GS.overlord_of(s, b) == a:
		t += 10.0
	t -= float(claim_count(s, b, a)) * 6.0     # b has claims on a
	t -= float(cb.get("infamy", 0.0)) * 0.5
	t += Mods.get_mod(s, b, "diplo") * 15.0
	if DynastySystem.married(s, a, b):
		t += 20.0
	t -= float(r["wars_fought"]) * 8.0
	if borders(s, a, b):
		t -= 6.0
	if r["embargo"].get(b, false) or r["sanction"].get(b, false):
		t -= 25.0
	return t

static func process_turn(s: Dictionary) -> void:
	var alive := GS.alive_countries(s)
	# opinions drift toward targets only for pairs that already have a relation record or share a border
	var keys: Array = s["relations"].keys()
	keys.sort()
	var half := int(s["turn"]) % 2
	var ki := -1
	for k in keys:
		ki += 1
		if ki % 2 != half:
			continue
		var r: Dictionary = s["relations"][k]
		var parts: PackedStringArray = k.split("|")
		var a: String = parts[0]
		var b: String = parts[1]
		if not s["countries"].get(a, {}).get("alive", false) or not s["countries"].get(b, {}).get("alive", false):
			continue
		for pair in [[a, b], [b, a]]:
			var x: String = pair[0]
			var y: String = pair[1]
			var cur := float(r["op"].get(x, 0.0))
			var tgt := target_opinion(s, x, y)
			cur += clampf((tgt - cur) * 0.12, -8.0, 8.0)
			if int(r["improving"].get(x, 0)) > 0:
				cur += 5.0
				r["improving"][x] = int(r["improving"][x]) - 1
			if GS.at_war(s, x, y):
				cur -= 1.5
			r["op"][x] = clampf(cur, Const.OPINION_MIN, Const.OPINION_MAX)
		r["trust"] = clampf(float(r["trust"]) + (0.5 if r["alliance"] else (-0.2 if GS.at_war(s, a, b) else 0.0)), 0.0, 100.0)
		# allies at war with each other break up
		if r["alliance"] and GS.at_war(s, a, b):
			r["alliance"] = false
	# first contact: make sure bordering countries have relation records
	if int(s["turn"]) % 4 == 0:
		for a in alive:
			for pid in GS.owned(s, a):
				for nb in Defs.neighbors(pid):
					var o: String = s["provinces"][nb]["owner"]
					if o != a and o != "" and o != "REB" and o > a:
						GS.rel(s, a, o)
	# infamy decays
	for cid in alive:
		var c: Dictionary = s["countries"][cid]
		c["infamy"] = maxf(0.0, float(c.get("infamy", 0.0)) - 0.8)
	_update_coalitions(s)
	_prune_wars(s)

static func _update_coalitions(s: Dictionary) -> void:
	# a coalition forms against very infamous countries; it is a real object with members
	for k in s["coalitions"].keys():
		var co: Dictionary = s["coalitions"][k]
		if not s["countries"].get(co["target"], {}).get("alive", false) or float(s["countries"][co["target"]].get("infamy", 0.0)) < 10.0:
			s["coalitions"].erase(k)

static func form_coalition_against(s: Dictionary, target: String) -> String:
	var members: Array = []
	for cid in GS.alive_countries(s):
		if cid == target or str(cid).begins_with("NAT_"):
			continue
		if GS.opinion(s, cid, target) < -35.0 and (borders(s, cid, target) or common_enemies(s, cid, target) > 0 or GS.opinion(s, cid, target) < -70.0):
			if not GS.allied(s, cid, target):
				members.append(cid)
	if members.size() < 2:
		return ""
	for k in s["coalitions"]:
		if s["coalitions"][k]["target"] == target:
			s["coalitions"][k]["members"] = members
			return k
	var id := "C%d" % int(s["next_coalition_id"])
	s["next_coalition_id"] = int(s["next_coalition_id"]) + 1
	s["coalitions"][id] = {"id": id, "target": target, "members": members, "turn": s["turn"]}
	for m in members:
		GS.note(s, m, "diplomacy", "NOTE_COALITION", {"other": target})
	GS.note(s, target, "diplomacy", "NOTE_COALITION_AGAINST_YOU", {"count": members.size()})
	return id

static func coalition_war(s: Dictionary, coalition_id: String) -> String:
	var co: Dictionary = s["coalitions"].get(coalition_id, {})
	if co.is_empty():
		return ""
	var target: String = co["target"]
	var atk: Array = []
	for m in co["members"]:
		if s["countries"].get(m, {}).get("alive", false) and not GS.at_war(s, m, target) and int(GS.rel(s, m, target)["truce_until"]) <= int(s["turn"]):
			atk.append(m)
	if atk.size() < 2:
		return ""
	var wid := start_war(s, atk, [target], "coalition", [], false)
	for m in atk:
		GS.add_opinion(s, target, m, -40.0)
	s["coalitions"].erase(coalition_id)
	GS.history(s, atk[0], "war", "HIST_COALITION_WAR", {"other": target})
	return wid

static func _prune_wars(s: Dictionary) -> void:
	for wid in s["wars"].keys():
		var w: Dictionary = s["wars"][wid]
		if w.get("ended", false) and int(s["turn"]) - int(w.get("end_turn", 0)) > 40:
			s["wars"].erase(wid)
