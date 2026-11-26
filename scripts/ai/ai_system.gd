class_name AISystem
extends RefCounted
## Strategic AI. Layers: assessment -> economy -> military -> diplomacy. Personalities change
## weights, difficulty changes decision quality (never resources). The AI only reasons about
## information a human could see (visible armies/borders) unless the difficulty documents
## otherwise ("expert" has full information about army sizes - stated in the settings text).

const DIFF := {
	"easy": {"skip": 0.45, "force": 0.7, "plan": false, "full_info": false, "war_prudence": 0.8, "coalition": false, "construct": 0.6},
	"normal": {"skip": 0.15, "force": 1.0, "plan": true, "full_info": false, "war_prudence": 1.0, "coalition": true, "construct": 1.0},
	"hard": {"skip": 0.0, "force": 1.15, "plan": true, "full_info": false, "war_prudence": 1.15, "coalition": true, "construct": 1.2},
	"expert": {"skip": 0.0, "force": 1.25, "plan": true, "full_info": true, "war_prudence": 1.3, "coalition": true, "construct": 1.3},
}
const PERS_W := {
	"aggressive": {"war": 1.6, "army": 1.4, "econ": 0.8, "dipl": 0.6, "tax_cap": 0.40, "need_ratio": 1.0},
	"defensive": {"war": 0.35, "army": 1.15, "econ": 1.0, "dipl": 1.2, "tax_cap": 0.35, "need_ratio": 2.0},
	"expansionist": {"war": 1.3, "army": 1.25, "econ": 1.0, "dipl": 0.9, "tax_cap": 0.40, "need_ratio": 1.25},
	"diplomatic": {"war": 0.4, "army": 0.9, "econ": 1.0, "dipl": 1.6, "tax_cap": 0.32, "need_ratio": 1.8},
	"economic": {"war": 0.5, "army": 0.8, "econ": 1.5, "dipl": 1.1, "tax_cap": 0.35, "need_ratio": 1.6},
	"opportunistic": {"war": 0.9, "army": 1.0, "econ": 1.0, "dipl": 1.0, "tax_cap": 0.38, "need_ratio": 1.4},
	"isolationist": {"war": 0.25, "army": 0.9, "econ": 1.1, "dipl": 0.3, "tax_cap": 0.33, "need_ratio": 2.2},
	# "trade": weight of ports/trade buildings and trade agreements; "navy": appetite for fleets; "coalition": appetite for
	# alliances and for forming coalitions against dangerous neighbours. Missing keys mean 1.0 (see _w()).
	"naval_trade": {"war": 0.5, "army": 0.85, "econ": 1.3, "dipl": 1.2, "tax_cap": 0.36, "need_ratio": 1.8, "trade": 2.2, "navy": 3.0},
	"coalition_builder": {"war": 0.45, "army": 1.0, "econ": 1.0, "dipl": 1.7, "tax_cap": 0.34, "need_ratio": 1.7, "coalition": 2.2},
}

static func _w(W: Dictionary, key: String) -> float:
	return float(W.get(key, 1.0))

static func new_ai_state(s: Dictionary, cid: String, pers: String) -> Dictionary:
	if pers == "" or pers not in Const.PERSONALITIES:
		var c: Dictionary = s["countries"][cid]
		var g: String = c.get("gov", "")
		pers = {"tribal_confederation": "aggressive", "merchant_republic": "naval_trade", "theocracy": "defensive", "military_government": "aggressive",
			"empire": "expansionist", "republic": "diplomatic", "constitutional_monarchy": "diplomatic", "feudal_kingdom": "opportunistic",
			"absolute_monarchy": "expansionist"}.get(g, "opportunistic")
		if bool(c.get("native", false)):
			pers = "isolationist"
	return {"personality": pers, "target": "", "last_war_turn": -99, "last_diplo": -99, "last_build": -99, "plan": {}, "focus": ""}

static func params(s: Dictionary) -> Dictionary:
	return DIFF.get(str(s["difficulty"]), DIFF["normal"])

## --- visible information --------------------------------------------------------------------------
static func visible_strength(s: Dictionary, observer: String, target: String) -> float:
	var P := params(s)
	if bool(P["full_info"]):
		return UnitUtil.country_regiments(s, target)
	var seen := 0.0
	var near := {}
	for pid in GS.owned(s, observer):
		near[pid] = true
		for nb in Defs.neighbors(pid):
			near[nb] = true
			for nb2 in Defs.neighbors(nb):
				near[nb2] = true
	for aid in s["armies"]:
		var a: Dictionary = s["armies"][aid]
		if a["owner"] == target and not a.get("naval", false) and a["loc"] in near:
			seen += UnitUtil.army_size(a)
	# rumour: a rough estimate from the target's size (not its actual army)
	var rumour := DiplomacySystem.total_pop(s, target) * 0.0013
	return maxf(seen, rumour * 0.7)

static func my_regiments(s: Dictionary, cid: String) -> float:
	return UnitUtil.country_regiments(s, cid)

## --- main entry ---------------------------------------------------------------------------------------
static func run(s: Dictionary, cid: String) -> void:
	var c: Dictionary = s["countries"][cid]
	if not c["alive"] or cid in s["players"] or cid == "REB":
		return
	var ai: Dictionary = s["ai"][cid]
	var P := params(s)
	var rng := GS.rng_of(s)
	var pers: String = ai["personality"]
	var W: Dictionary = PERS_W.get(pers, PERS_W["opportunistic"])
	if bool(c.get("native", false)):
		_native_turn(s, cid, ai, rng)
		return
	if rng.chance(float(P["skip"])) and int(s["turn"]) % 2 == 0:
		return
	_economy(s, cid, ai, P, W, rng)
	_research(s, cid, ai, W, rng)
	_military(s, cid, ai, P, W, rng)
	_diplomacy(s, cid, ai, P, W, rng)

static func _native_turn(s: Dictionary, cid: String, ai: Dictionary, rng: GameRng) -> void:
	# tribes keep a modest defensive force and rebuild it slowly
	var c: Dictionary = s["countries"][cid]
	if (int(s["turn"]) + hash(cid)) % 3 == 0:
		_economy(s, cid, ai, params(s), PERS_W["isolationist"], rng)
		_research(s, cid, ai, PERS_W["isolationist"], rng)
	var want := maxf(2.0, DiplomacySystem.total_pop(s, cid) * 0.0009)
	if my_regiments(s, cid) < want and float(c["manpower"]) > 2.0 and float(c["gold"]) > 20.0 and int(s["turn"]) % 3 == 0:
		var u := UnitUtil.best_of(s, cid, "infantry")
		var owned := GS.owned(s, cid)
		if u != "" and not owned.is_empty():
			MilitarySystem.recruit(s, cid, str(rng.pick(owned)), u)
	# retake own provinces from rebels
	_suppress_rebels(s, cid)

## --- economy ---------------------------------------------------------------------------------------------
static func _economy(s: Dictionary, cid: String, ai: Dictionary, P: Dictionary, W: Dictionary, rng: GameRng) -> void:
	var c: Dictionary = s["countries"][cid]
	var b: Dictionary = c.get("budget", {})
	var income := float(b.get("income", 20.0))
	var net := float(b.get("net", 0.0))
	var at_war := not GS.wars_of(s, cid).is_empty()
	# taxes
	var tr := float(c["tax_rate"])
	var cap := float(W["tax_cap"])
	var happy := float(c["stability"]) > 55.0
	if (net < 0.0 and float(c["gold"]) < income * 2.0) or float(c["debt"]) > income * 3.0:
		if happy and tr < cap:
			tr += 0.03
		elif not happy and float(c["stability"]) < 35.0:
			tr = maxf(0.12, tr - 0.02)
	elif float(c["gold"]) > income * 8.0 and tr > 0.22:
		tr -= 0.02
	elif float(c["stability"]) < 40.0 and tr > 0.15:
		tr -= 0.03
	elif net > income * 0.25 and float(c["gold"]) > income * 3.0 and float(c["stability"]) > 70.0 and tr < 0.28:
		tr += 0.01
	c["tax_rate"] = clampf(tr, 0.1, cap)
	# funding
	c["army_funding"] = 1.0 if at_war or float(c["gold"]) > income * 2.0 else 0.8
	if float(c["gold"]) < 0.0 or (net < -income * 0.2 and not at_war):
		c["army_funding"] = 0.7
	# construction every 2 turns, staggered
	if (int(s["turn"]) + hash(cid)) % 3 == 0:
		_build(s, cid, ai, P, W, rng, at_war)
	# development
	var dev_rounds := 1 + int(maxf(0.0, float(c["gold"]) - 250.0) / maxf(income * 6.0, 120.0))
	for dev_i in mini(dev_rounds, 3):
		if float(c["gold"]) > 250.0 and float(c["admin"]) > 40.0 and not at_war and rng.chance(0.6 * float(P["construct"])):
			_develop_best(s, cid)

	# invest surplus treasure in research / administration
	var surplus := float(c["gold"]) - income * 6.0
	if surplus > income * 2.0:
		TechSystem.invest(s, cid, minf(surplus * 0.6, income * 8.0))
		if float(c["admin"]) < 120.0:
			EconomySystem.buy_admin(s, cid, 20.0)
	# reforms: adopt one occasionally when affordable
	if float(c["admin"]) > 90.0 and float(c["gold"]) > 150.0 and rng.chance(0.08):
		var opts: Array = []
		for rid in Defs.reforms:
			if PoliticsSystem.can_adopt_reform(s, cid, rid)["ok"] and _reform_fits(s, cid, rid):
				opts.append(rid)
		opts.sort()
		if not opts.is_empty():
			PoliticsSystem.adopt_reform(s, cid, str(rng.pick(opts)))
	# government transitions for big states
	if float(c["admin"]) > 150.0 and rng.chance(0.01):
		for o in PoliticsSystem.government_options(s, cid):
			if o["ok"] and o["to"] in ["empire", "constitutional_monarchy"] and float(c["stability"]) > 60.0:
				PoliticsSystem.change_government(s, cid, o["to"])
				break

static func _develop_best(s: Dictionary, cid: String) -> void:
	var c: Dictionary = s["countries"][cid]
	if true:
		var best := ""
		var bp := -1.0
		for pid in GS.owned(s, cid):
			var p: Dictionary = s["provinces"][pid]
			if p["controller"] == cid and float(p["unrest"]) < 30.0:
				var sc := float(p["pop"]) / (1.0 + float(p["dev"]))
				if sc > bp:
					bp = sc
					best = pid
		if best != "":
			ConstructionSystem.develop(s, cid, best)

static func _reform_fits(s: Dictionary, cid: String, rid: String) -> bool:
	var c: Dictionary = s["countries"][cid]
	var r: Dictionary = Defs.reforms[rid]
	# avoid reforms that anger the most powerful class heavily
	for k in r["disadvantages"]:
		if str(k).ends_with("_sat"):
			var cls := str(k).substr(0, str(k).length() - 4)
			if cls in c["classes"] and float(c["classes"][cls].get("power", 0.0)) > 0.3 and float(r["disadvantages"][k]) < -6.0:
				return false
	if rid == "conscription" and "mercenary_contracts" in c["reforms"]:
		return false
	if rid in ["war_economy", "mercenary_contracts"] and GS.wars_of(s, cid).is_empty():
		return false
	return true

static func _build(s: Dictionary, cid: String, ai: Dictionary, P: Dictionary, W: Dictionary, rng: GameRng, at_war: bool) -> void:
	var c: Dictionary = s["countries"][cid]
	var gold := float(c["gold"])
	var income := maxf(10.0, float(c.get("budget", {}).get("income", 20.0)))
	var reserve := income * (1.5 if at_war else 0.6)
	if gold < reserve + 40.0:
		return
	var owned: Array = GS.owned(s, cid).duplicate()
	owned.sort_custom(func(a, b): return float(s["provinces"][a]["pop"]) > float(s["provinces"][b]["pop"]))
	var b: Dictionary = c.get("budget", {})
	var food_bal := float(b.get("food_balance", 0.0))
	var n_builds := clampi(1 + int(gold / maxf(income * 4.0, 60.0)), 1, 4)
	var frontier := ScenarioLoader._frontier_provinces(s, cid)
	for build_i in n_builds:
		if not _build_one(s, cid, ai, P, W, rng, at_war, owned, food_bal, frontier, reserve):
			break

static func _build_one(s: Dictionary, cid: String, ai: Dictionary, P: Dictionary, W: Dictionary, rng: GameRng, at_war: bool, owned: Array, food_bal: float, frontier: Array, reserve: float) -> bool:
	var c: Dictionary = s["countries"][cid]
	var gold := float(c["gold"])
	var best := {}
	var best_score := 0.0
	var considered := 0
	for pid in owned:
		var p: Dictionary = s["provinces"][pid]
		if p["controller"] != cid or (p["queue"] as Array).size() >= ConstructionSystem.max_queue(s, cid):
			continue
		considered += 1
		if considered > int(7.0 * float(P["construct"])):
			break
		var pd: Dictionary = Defs.provinces[pid]
		for bid in Defs.buildings:
			var bd: Dictionary = Defs.buildings[bid]
			var chk := ConstructionSystem.can_build(s, cid, pid, bid)
			if not chk["ok"]:
				continue
			var cost := float(chk["cost"].get("gold", 30.0))
			if gold - cost < reserve:
				continue
			var lv := int(chk["level"])
			var sc := _building_score(s, cid, pid, bid, lv, food_bal, at_war, W, frontier)
			sc = sc / maxf(cost, 20.0) * 100.0 / float(lv)
			if sc > best_score:
				best_score = sc
				best = {"pid": pid, "bid": bid, "short": not chk["shortage"].is_empty()}
	if not best.is_empty() and best_score > 1.0:
		var r := ConstructionSystem.start_build(s, cid, best["pid"], best["bid"], gold > 400.0)
		ai["last_build"] = s["turn"]
		return bool(r.get("ok", false))
	return false

static func _building_score(s: Dictionary, cid: String, pid: String, bid: String, lv: int, food_bal: float, at_war: bool, W: Dictionary, frontier: Array) -> float:
	var c: Dictionary = s["countries"][cid]
	var p: Dictionary = s["provinces"][pid]
	var pd: Dictionary = Defs.provinces[pid]
	var pop := float(p["pop"])
	var sc := 0.0
	var econ := float(W["econ"])
	var army := float(W["army"])
	match bid:
		"farm":
			sc = (6.0 + (22.0 if food_bal < 0.0 else 0.0)) * float(pd["fert"]) * minf(pop / 200.0, 2.0)
		"market": sc = (6.0 + pop / 120.0) * econ
		"workshop": sc = (5.0 + pop / 150.0) * econ
		"mine": sc = (4.0 + float(pd["iron"] + pd["stone"]) * 5.0 + (6.0 if float(c["stock"]["iron"]) < 15.0 else 0.0)) * (1.0 if int(c["tech_level"].get("resource_extraction", 0)) >= 1 else 0.7)
		"sawmill": sc = 3.0 + (10.0 if float(c["stock"]["wood"]) < 15.0 else 0.0) + float(pd["wood"]) * 4.0
		"port": sc = (8.0 + (10.0 if pd["coastal"] else 0.0)) * econ * _w(W, "trade")
		"trading_center": sc = (7.0 + pop / 100.0) * econ * _w(W, "trade")
		"barracks": sc = (3.0 + (9.0 if float(c["manpower"]) < float(c["manpower_max"]) * 0.4 else 0.0)) * army
		"fort": sc = (4.0 + (14.0 if (pid in frontier and at_war) else (5.0 if pid in frontier else 0.0))) * army
		"arsenal": sc = 3.0 * army
		"military_academy": sc = 3.0 * army
		"government_office": sc = 5.0 + (18.0 if float(EconomySystem.admin_capacity(s, cid)["overextension"]) > 0.0 else 0.0)
		"court": sc = 3.0 + (10.0 if float(p["unrest"]) > 25.0 else 0.0)
		"tax_office": sc = 5.0 + pop / 130.0
		"admin_center": sc = 6.0 + (16.0 if float(EconomySystem.admin_capacity(s, cid)["overextension"]) > 0.0 else 0.0)
		"road": sc = 4.0 + (3.0 if pid in frontier else 0.0)
		"bridge": sc = 3.0
		"canal": sc = 3.0 * econ
		"railway": sc = 7.0 * econ
		"university": sc = 6.0 + float(p["literacy"]) * 10.0
		"hospital": sc = 2.0 + float(p["disease"]) * 0.3
		"cultural_institution": sc = 3.0
		"religious_building": sc = 2.0 + (8.0 if p["religion"] != c["religion"] else 0.0) + (6.0 if float(p["unrest"]) > 30.0 else 0.0)
	return sc

static func _research(s: Dictionary, cid: String, ai: Dictionary, W: Dictionary, rng: GameRng) -> void:
	var c: Dictionary = s["countries"][cid]
	var pers: String = ai["personality"]
	var pref: Array = {"aggressive": ["military", "administration"], "defensive": ["military", "economic"], "expansionist": ["military", "administration"],
		"diplomatic": ["society", "administration"], "economic": ["economic", "society"], "opportunistic": ["economic", "military"],
		"isolationist": ["economic", "society"], "naval_trade": ["economic", "administration"], "coalition_builder": ["administration", "society"]}.get(pers, ["economic", "military"])
	for b in Const.BRANCHES:
		if str(c["research"]["current"].get(b, "")) != "":
			continue
		var best := ""
		var bs := 1e9
		for tid in TechSystem.available(s, cid):
			var t: Dictionary = Defs.techs[tid]
			if t["branch"] != b:
				continue
			var sc := float(t["cost_rp"]) * (0.8 if b in pref else 1.1)
			# needs an affordable fee
			if float(c["gold"]) < float(t["cost_gold"]) + 30.0:
				continue
			if sc < bs:
				bs = sc
				best = tid
		if best != "":
			TechSystem.start_research(s, cid, best)
	# focus allocation: the preferred branches get more points
	for b in Const.BRANCHES:
		c["research"]["alloc"][b] = 1.6 if b in pref else 0.8

## --- military ----------------------------------------------------------------------------------------------------
static func desired_regiments(s: Dictionary, cid: String, W: Dictionary, P: Dictionary, at_war: bool) -> float:
	var pop := DiplomacySystem.total_pop(s, cid)
	var base := pop * 0.0018 * float(W["army"]) * float(P["force"])
	var rich := float(s["countries"][cid]["gold"]) > maxf(100.0, float(s["countries"][cid].get("budget", {}).get("income", 20.0))) * 6.0
	if rich:
		base *= 1.35
	if at_war:
		base *= 1.5
	# threat awareness: neighbours' visible strength
	var threat := 0.0
	var seen := {}
	for pid in GS.owned(s, cid):
		for nb in Defs.neighbors(pid):
			var o: String = s["provinces"][nb]["owner"]
			if o != cid and o != "" and not seen.has(o) and not s["countries"][o].get("native", false):
				seen[o] = true
				threat += visible_strength(s, cid, o) * (0.25 if GS.allied(s, cid, o) else (0.55 if GS.opinion(s, cid, o) > 20.0 else 0.8))
	base = maxf(base, threat * 0.6)
	return clampf(base, 3.0, 90.0)

static func _military(s: Dictionary, cid: String, ai: Dictionary, P: Dictionary, W: Dictionary, rng: GameRng) -> void:
	var c: Dictionary = s["countries"][cid]
	var at_war := not GS.wars_of(s, cid).is_empty()
	var b: Dictionary = c.get("budget", {})
	var income := maxf(10.0, float(b.get("income", 20.0)))
	# --- recruitment
	var have := my_regiments(s, cid) + float((c["recruit_queue"] as Array).size())
	var want := desired_regiments(s, cid, W, P, at_war)
	# budget: do not spend more than a share of income on upkeep
	var upkeep_share := (float(b.get("army", 0.0)) + float(b.get("navy", 0.0))) / income
	var max_share := 0.62 if at_war else (0.38 + (0.12 if float(c["gold"]) > income * 8.0 else 0.0))
	if have < want and upkeep_share < max_share and float(c["manpower"]) >= 1.0 and float(c["gold"]) > 25.0:
		var n_try := 3 if at_war else 2
		for i in n_try:
			var uid := _pick_unit(s, cid, rng, at_war)
			if uid == "":
				break
			var pid := _recruit_province(s, cid, uid)
			if pid == "":
				continue
			if not MilitarySystem.recruit(s, cid, pid, uid)["ok"]:
				break
	# overspending: disband the weakest when broke in peace
	if not at_war and float(c["gold"]) < 0.0 and float(b.get("net", 0.0)) < 0.0 and rng.chance(0.3):
		var armies := GS.armies_of(s, cid)
		var worst := ""
		var wp := 1e9
		for aid in armies:
			var a: Dictionary = s["armies"][aid]
			if a.get("naval", false):
				continue
			var pw := UnitUtil.army_strength_points(a)
			if pw < wp:
				wp = pw
				worst = aid
		if worst != "":
			MilitarySystem.disband_army(s, worst, true)
	# fleet for coastal commercial powers
	var navy_w := _w(W, "navy")
	if P["plan"] and not at_war and float(c["gold"]) > income * 6.0 and UnitUtil.country_regiments(s, cid, true) < 2.0 * navy_w and rng.chance(0.05 * navy_w):
		var wu := UnitUtil.best_of(s, cid, "naval")
		for pid in GS.owned(s, cid):
			if Defs.provinces[pid]["coastal"] and int(s["provinces"][pid]["buildings"].get("port", 0)) > 0:
				if wu != "":
					MilitarySystem.recruit(s, cid, pid, wu)
				break
	_suppress_rebels(s, cid)
	AINaval.run(s, cid, ai, P, W, rng)
	if at_war:
		_war_orders(s, cid, ai, P, rng)
	else:
		_peace_posture(s, cid, ai, P, rng)

static func _pick_unit(s: Dictionary, cid: String, rng: GameRng, at_war: bool) -> String:
	var classes: Array = ["infantry", "infantry", "infantry", "heavy_infantry", "archers", "cavalry", "heavy_cavalry", "artillery"]
	var art_need := at_war and int(s["turn"]) > 8
	if art_need:
		classes += ["artillery", "artillery", "engineer"]
	# count what we have to keep the mix reasonable
	var counts := {}
	var tot := 0.0
	for aid in GS.armies_of(s, cid):
		var a: Dictionary = s["armies"][aid]
		if a.get("naval", false):
			continue
		for uid in a["units"]:
			var cl: String = Defs.units[uid]["cls"]
			counts[cl] = float(counts.get(cl, 0.0)) + float(a["units"][uid])
			tot += float(a["units"][uid])
	var shares := {"infantry": 0.38, "heavy_infantry": 0.12, "archers": 0.14, "cavalry": 0.14, "heavy_cavalry": 0.08, "artillery": 0.09, "engineer": 0.05}
	var best_cls := ""
	var best_def := -1.0
	for cl in shares:
		var u := UnitUtil.best_of(s, cid, cl)
		if u == "":
			continue
		var deficit := float(shares[cl]) - float(counts.get(cl, 0.0)) / maxf(tot, 1.0)
		if deficit > best_def:
			best_def = deficit
			best_cls = cl
	if best_cls == "":
		return ""
	var uid := UnitUtil.best_of(s, cid, best_cls)
	# specials: prefer them for infantry/cavalry classes
	for sp in s["countries"][cid]["special_units"]:
		if Defs.units.has(sp) and Defs.units[sp]["cls"] == best_cls and UnitUtil.is_available(s, cid, sp):
			if UnitUtil.power(sp) >= UnitUtil.power(uid) * 0.9:
				uid = sp
	return uid

static func _recruit_province(s: Dictionary, cid: String, uid: String) -> String:
	var c: Dictionary = s["countries"][cid]
	var naval := bool(Defs.units[uid]["naval"])
	var best := ""
	var bs := -1.0
	for pid in GS.owned(s, cid):
		var p: Dictionary = s["provinces"][pid]
		if p["controller"] != cid or p.get("siege") != null:
			continue
		if naval and int(p["buildings"].get("port", 0)) < 1:
			continue
		var sc := float(p["pop"]) * (1.0 + float(p["buildings"].get("barracks", 0)) * 0.6) + (200.0 if pid == c["capital"] else 0.0)
		for q in c["recruit_queue"]:
			if q["pid"] == pid:
				sc *= 0.5
		if sc > bs:
			bs = sc
			best = pid
	return best

static func _suppress_rebels(s: Dictionary, cid: String) -> void:
	for pid in GS.owned(s, cid):
		var p: Dictionary = s["provinces"][pid]
		if p["controller"] == "REB" or _rebels_in(s, pid):
			var best := ""
			var bd := 99.0
			for aid in GS.armies_of(s, cid):
				var a: Dictionary = s["armies"][aid]
				if a.get("naval", false) or a["loc"] == "" or not (a["path"] as Array).is_empty():
					continue
				if a["loc"] == pid:
					best = ""
					break
				var d := _hops(a["loc"], pid, 4)
				if d < bd and UnitUtil.army_size(a) >= 2.0:
					bd = d
					best = aid
			if best != "":
				MilitarySystem.order_move(s, best, pid)

static func _rebels_in(s: Dictionary, pid: String) -> bool:
	for aid in GS.armies_at(s, pid):
		if s["armies"][aid]["owner"] == "REB":
			return true
	return false

static func _hops(a: String, b: String, limit: int) -> int:
	if a == b:
		return 0
	var frontier: Array = [a]
	var seen := {a: 0}
	while not frontier.is_empty():
		var u: String = frontier.pop_front()
		var d: int = seen[u]
		if d >= limit:
			continue
		for nb in Defs.neighbors(u):
			if not seen.has(nb):
				seen[nb] = d + 1
				if nb == b:
					return d + 1
				frontier.append(nb)
	return 99

static func _land_armies(s: Dictionary, cid: String) -> Array:
	var out: Array = []
	for aid in GS.armies_of(s, cid):
		var a: Dictionary = s["armies"][aid]
		if not a.get("naval", false) and a["loc"] != "" and a["transit"] == null:
			out.append(aid)
	return out

static func _war_orders(s: Dictionary, cid: String, ai: Dictionary, P: Dictionary, rng: GameRng) -> void:
	var enemies: Array = GS.enemies_of(s, cid)
	if enemies.is_empty():
		return
	var armies := _land_armies(s, cid)
	# merge idle stacks that share a province (keeps a strong main army)
	if bool(P["plan"]):
		var by_loc := {}
		for aid in armies:
			var a: Dictionary = s["armies"][aid]
			if (a["path"] as Array).is_empty():
				if not by_loc.has(a["loc"]):
					by_loc[a["loc"]] = []
				by_loc[a["loc"]].append(aid)
		for loc in by_loc:
			var lst: Array = by_loc[loc]
			if lst.size() >= 2:
				lst.sort_custom(func(x, y): return UnitUtil.army_size(s["armies"][x]) > UnitUtil.army_size(s["armies"][y]))
				for i in range(1, lst.size()):
					if UnitUtil.army_size(s["armies"][lst[0]]) < float(Const.ARMY_SIZE_CAP) and s["armies"].has(lst[i]):
						MilitarySystem.merge_armies(s, lst[0], lst[i])
		armies = _land_armies(s, cid)
	armies.sort_custom(func(x, y): return UnitUtil.army_size(s["armies"][x]) > UnitUtil.army_size(s["armies"][y]))
	var orders := 0
	var enemy_set := {}
	for e in enemies:
		enemy_set[e] = true
	for aid in armies:
		if orders >= 6:
			break
		var a: Dictionary = s["armies"][aid]
		var loc: String = a["loc"]
		if not (a["path"] as Array).is_empty():
			continue
		# keep sieging
		var lp: Dictionary = s["provinces"][loc]
		if lp.get("siege") != null and lp["siege"]["by"] == cid and float(lp["siege"]["progress"]) < 1.0:
			continue
		var size := UnitUtil.army_size(a)
		# stay and recover when badly beaten
		if float(a["morale"]) < 25.0 and s["provinces"][loc]["controller"] == cid:
			continue
		var target := _best_target(s, cid, a, enemy_set, P)
		if target != "" and target != loc:
			var r := MilitarySystem.order_move(s, aid, target)
			if r["ok"]:
				orders += 1

static func _best_target(s: Dictionary, cid: String, a: Dictionary, enemy_set: Dictionary, P: Dictionary) -> String:
	var loc: String = a["loc"]
	var size := UnitUtil.army_size(a) * (0.5 + float(a["morale"]) / 200.0)
	var depth := 4 if bool(P["plan"]) else 2
	var frontier: Array = [loc]
	var seen := {loc: 0}
	var best := ""
	var bs := -1e9
	while not frontier.is_empty():
		var u: String = frontier.pop_front()
		var d: int = seen[u]
		var up: Dictionary = s["provinces"][u]
		if u != loc:
			var ctrl: String = up["controller"]
			var owner: String = up["owner"]
			var sc := -1e9
			var hostile_ctrl: bool = ctrl in enemy_set or ctrl == "REB"
			var enemy_owned_ours: bool = owner == cid and hostile_ctrl
			if hostile_ctrl or (owner in enemy_set and ctrl == owner):
				var v := DiplomacySystem.prov_value(s, u)
				sc = v / (1.0 + float(d) * 0.8)
				if enemy_owned_ours:
					sc *= 1.8      # retake first
				# hostile stacks present
				var foe := 0.0
				for aid2 in GS.armies_at(s, u):
					var o: String = s["armies"][aid2]["owner"]
					if o in enemy_set or o == "REB":
						foe += UnitUtil.army_size(s["armies"][aid2])
				if foe > size * 1.15:
					sc -= 30.0 + foe
				elif foe > 0.0:
					sc += 6.0   # a battle we can win
				sc -= Mods.fort_level(s, u) * (0.6 if UnitUtil.army_size(a) > 8.0 else 2.0)
			if sc > bs:
				bs = sc
				best = u
		if d >= (4 if bool(P["plan"]) else 2):
			continue
		for nb in Defs.neighbors(u):
			if not seen.has(nb) and MilitarySystem.can_enter(s, cid, nb):
				seen[nb] = d + 1
				frontier.append(nb)
	# nothing in reach by land: look for a coastal landing if we have ships
	if best == "" or bs < 0.0:
		if Defs.provinces[loc]["coastal"] and bool(P["plan"]):
			for sl in Defs.sea_links(loc):
				var tp: String = sl[0]
				if sl[1] != "lane":
					continue
				var o2: String = s["provinces"][tp]["controller"]
				if o2 in enemy_set:
					var v2 := DiplomacySystem.prov_value(s, tp)
					if v2 > bs and MilitarySystem._find_escort(s, a) != "":
						bs = v2
						best = tp
	return best if bs > -1e8 else ""

static func _peace_posture(s: Dictionary, cid: String, ai: Dictionary, P: Dictionary, rng: GameRng) -> void:
	if int(s["turn"]) % 3 != (hash(cid) % 3 + 3) % 3:
		return
	var armies := _land_armies(s, cid)
	if armies.is_empty():
		return
	var c: Dictionary = s["countries"][cid]
	# merge duplicates quietly
	var by_loc := {}
	for aid in armies:
		var a: Dictionary = s["armies"][aid]
		if (a["path"] as Array).is_empty():
			if not by_loc.has(a["loc"]):
				by_loc[a["loc"]] = aid
			elif MilitarySystem.merge_armies(s, by_loc[a["loc"]], aid):
				pass
	armies = _land_armies(s, cid)
	# desired posts: capital plus frontier provinces facing the strongest non-friendly neighbours
	var posts: Array = [c["capital"]]
	for pid in ScenarioLoader._frontier_provinces(s, cid):
		var threat := false
		for nb in Defs.neighbors(pid):
			var o: String = s["provinces"][nb]["owner"]
			if o != cid and o != "" and not GS.allied(s, cid, o) and (GS.opinion(s, cid, o) < 30.0 or s["countries"][o].get("native", false) == false):
				threat = true
		if threat and pid not in posts:
			posts.append(pid)
		if posts.size() >= 3:
			break
	# assign armies without a post to posts lacking coverage
	var covered := {}
	for aid in armies:
		covered[s["armies"][aid]["loc"]] = true
	for aid in armies:
		var a: Dictionary = s["armies"][aid]
		if not (a["path"] as Array).is_empty():
			continue
		if a["loc"] in posts or a["loc"] == c["capital"]:
			continue
		# only move armies that are not already on a threatened/owned spot with a purpose
		for post in posts:
			if not covered.has(post):
				if MilitarySystem.order_move(s, aid, post)["ok"]:
					covered[post] = true
					break

## --- diplomacy -----------------------------------------------------------------------------------------------------------
static func _diplomacy(s: Dictionary, cid: String, ai: Dictionary, P: Dictionary, W: Dictionary, rng: GameRng) -> void:
	var c: Dictionary = s["countries"][cid]
	var turn := int(s["turn"])
	_peace_talks(s, cid, ai, P, rng)
	# respond to coalitions
	var builder: bool = ai["personality"] == "coalition_builder"
	var co_period := 3 if builder else 5
	var co_infamy := 15.0 if builder else 30.0
	if bool(P["coalition"]) and turn % co_period == (hash(cid) % co_period + co_period) % co_period:
		for oid in GS.alive_countries(s):
			if oid != cid and float(s["countries"][oid].get("infamy", 0.0)) >= co_infamy and GS.opinion(s, cid, oid) < -30.0 and DiplomacySystem.borders(s, cid, oid):
				var coid := DiplomacySystem.form_coalition_against(s, oid)
				if coid != "":
					var co: Dictionary = s["coalitions"][coid]
					var members_power := 0.0
					for m in co["members"]:
						members_power += DiplomacySystem.power_score(s, m)
					if members_power > DiplomacySystem.power_score(s, oid) * 1.2 and cid in co["members"] and GS.wars_of(s, cid).is_empty():
						DiplomacySystem.coalition_war(s, coid)
				break
	if turn - int(ai["last_diplo"]) < 3:
		return
	ai["last_diplo"] = turn
	# gather relevant neighbours
	var neigh: Array = []
	for pid in GS.owned(s, cid):
		for nb in Defs.neighbors(pid):
			var o: String = s["provinces"][nb]["owner"]
			if o != cid and o != "" and o != "REB" and o not in neigh and s["countries"][o]["alive"]:
				neigh.append(o)
		for sl in Defs.sea_links(pid):
			if sl[1] == "strait":
				var o2: String = s["provinces"][sl[0]]["owner"]
				if o2 != cid and o2 != "" and o2 not in neigh and s["countries"][o2]["alive"]:
					neigh.append(o2)
	neigh.sort()
	var dw := float(W["dipl"])
	# alliances / pacts / trade
	for o in neigh:
		if s["countries"][o].get("native", false):
			continue
		var r := GS.rel(s, cid, o)
		if GS.at_war(s, cid, o):
			continue
		if rng.chance(0.07 * dw * (_w(W, "trade") if not r["trade"] else _w(W, "coalition"))):
			if not r["trade"]:
				_propose(s, cid, o, "trade", {})
			elif not r["alliance"] and rng.chance(0.4 * minf(_w(W, "coalition"), 2.0)):
				_propose(s, cid, o, "alliance", {})
			elif int(r["nap_until"]) < turn and rng.chance(0.3) and ai["personality"] != "aggressive":
				_propose(s, cid, o, "nap", {})
		if float(GS.opinion(s, cid, o)) > 20.0 and rng.chance(0.03 * dw) and not bool(r["access"].get(cid, false)):
			_propose(s, cid, o, "access", {})
	# war declaration
	if GS.wars_of(s, cid).size() < (2 if ai["personality"] == "aggressive" else 1) and turn >= 2 and turn - int(ai["last_war_turn"]) >= 6:
		var wchance := 0.05 * float(W["war"]) * float(P["war_prudence"]) * (1.0 if turn > 4 else 0.3)
		if rng.chance(wchance):
			_consider_war(s, cid, ai, P, W, neigh, rng)
	# vassalisation of much weaker neighbours (expansionists / empires)
	if ai["personality"] in ["expansionist", "diplomatic"] and rng.chance(0.015):
		for o in neigh:
			if o in s["countries"] and s["countries"][o]["alive"] and not s["countries"][o].get("native", false) and GS.overlord_of(s, o) == "":
				if DiplomacySystem.power_score(s, cid) > DiplomacySystem.power_score(s, o) * 3.0 and not GS.wars_of(s, o).is_empty():
					_propose(s, cid, o, "vassalize", {"gold": 0.0})
					break
	# annex vassals when able
	for v in GS.vassals_of(s, cid):
		var ev := DiplomacySystem.evaluate(s, "annex_vassal", cid, v, {})
		if ev["ok"] and float(c["admin"]) > 120.0 and rng.chance(0.05):
			DiplomacySystem.annex_vassal(s, cid, v)

static func _propose(s: Dictionary, from: String, to: String, action: String, params: Dictionary) -> void:
	if to in s["players"]:
		# AI proposals to a human player become requests the player can accept or decline
		var pend: Array = s["pending_requests"]
		if pend.size() >= 4:
			return
		for r in pend:
			if r["from"] == from and r["action"] == action:
				return
		var k := GS.rel(s, from, to)
		if int(k["last_action"].get(action + from, -99)) > int(s["turn"]) - 12:
			return
		k["last_action"][action + from] = s["turn"]
		# the proposer only asks when it would itself accept
		var ev := DiplomacySystem.evaluate(s, action, to, from, params)
		if not ev["ok"]:
			return
		pend.append({"id": "R%d_%s_%s" % [int(s["turn"]), from, action], "from": from, "to": to, "action": action, "params": params, "turn": s["turn"]})
		GS.note(s, to, "diplomacy", "NOTE_PROPOSAL", {"other": from, "action": action})
		return
	var res := DiplomacySystem.perform(s, action, from, to, params)
	if res.get("accepted", false) and to in s["players"]:
		GS.note(s, to, "diplomacy", "NOTE_PACT", {"other": from, "action": action})

## Handle the player's answer to an AI proposal.
static func respond_request(s: Dictionary, req_id: String, accept: bool) -> Dictionary:
	var pend: Array = s["pending_requests"]
	for i in range(pend.size()):
		if pend[i]["id"] == req_id:
			var r: Dictionary = pend[i]
			pend.remove_at(i)
			if accept:
				# the proposer (from) asks the player (to): execute as if proposer acts on player and the player agrees
				var action: String = r["action"]
				var from: String = r["from"]
				var to: String = r["to"]
				var rel := GS.rel(s, from, to)
				match action:
					"alliance":
						rel["alliance"] = true
						rel["defensive"] = true
						GS.add_opinion(s, from, to, 15.0)
						GS.add_opinion(s, to, from, 15.0)
						GS.stat_add(s, from, "alliances", 1.0)
						GS.stat_add(s, to, "alliances", 1.0)
					"trade":
						rel["trade"] = true
						GS.add_opinion(s, from, to, 8.0)
						GS.add_opinion(s, to, from, 8.0)
						TradeSystem.invalidate(s)
					"nap":
						rel["nap_until"] = int(s["turn"]) + 40
					"access":
						rel["access"][from] = true
						rel["access"][to] = true
					"defensive":
						rel["defensive"] = true
					"vassalize":
						DiplomacySystem.make_vassal(s, from, to, true)
				return {"ok": true, "accepted": true}
			else:
				GS.add_opinion(s, r["from"], r["to"], -3.0)
				return {"ok": true, "accepted": false}
	return {"ok": false}

static func _consider_war(s: Dictionary, cid: String, ai: Dictionary, P: Dictionary, W: Dictionary, neigh: Array, rng: GameRng) -> void:
	var c: Dictionary = s["countries"][cid]
	var my_power := DiplomacySystem.power_score(s, cid)
	var my_force := my_regiments(s, cid)
	var best := ""
	var bs := -1e9
	var best_cb := "conquest"
	for o in neigh:
		var oc: Dictionary = s["countries"][o]
		if oc.get("native", false) and false:
			continue
		if not DiplomacySystem.can_declare(s, cid, o, "conquest")["ok"]:
			continue
		var rel := GS.rel(s, cid, o)
		if GS.allied(s, cid, o) or GS.overlord_of(s, cid) == o or GS.overlord_of(s, o) == cid:
			continue
		# strength of the target including its allies as visible
		var tp := DiplomacySystem.power_score(s, o)
		var allies := 0.0
		for oid in GS.alive_countries(s):
			if oid != o and (GS.allied(s, o, oid) or GS.overlord_of(s, oid) == o):
				allies += DiplomacySystem.power_score(s, oid) * 0.7
		var ratio := my_power / maxf(tp + allies, 1.0)
		var seen := visible_strength(s, cid, o)
		var force_ratio := my_force / maxf(seen, 1.0)
		var need: float = {"aggressive": 1.0, "expansionist": 1.25, "opportunistic": 1.45, "defensive": 2.2, "diplomatic": 2.0, "economic": 2.0, "isolationist": 3.0, "naval_trade": 2.1, "coalition_builder": 2.3}.get(ai["personality"], 1.5) * (1.0 if P["plan"] else 0.85)
		var claims := DiplomacySystem.claims_on(s, cid, o)
		var cb := "conquest"
		if not claims.is_empty():
			cb = "claim"
			need *= 0.75
		if ratio < need and force_ratio < need:
			continue
		var gain := 0.0
		for pid in GS.owned(s, o):
			gain += DiplomacySystem.prov_value(s, pid) * (1.5 if pid in claims else 1.0)
		var sc: float = gain * 0.12 + (ratio - need) * 6.0 + float(claims.size()) * 5.0
		if oc.get("native", false):
			sc += 4.0     # tribes are soft targets
		if float(c.get("infamy", 0.0)) > 40.0 and cb == "conquest":
			sc -= 25.0
		if not GS.wars_of(s, o).is_empty():
			sc += 5.0   # opportunism
		if oc["religion"] != c["religion"]:
			sc += 2.0
		sc -= GS.opinion(s, cid, o) * -0.0
		if sc > bs:
			bs = sc
			best = o
			best_cb = cb
	if best != "" and bs > 0.0:
		var res := DiplomacySystem.declare_war(s, cid, best, best_cb)
		if res["ok"]:
			ai["last_war_turn"] = s["turn"]
			ai["target"] = best
			if best in s["players"]:
				GS.note(s, best, "war", "NOTE_WAR_ON_YOU", {"other": cid, "cb": best_cb})

static func _peace_talks(s: Dictionary, cid: String, ai: Dictionary, P: Dictionary, rng: GameRng) -> void:
	if int(s["turn"]) % 2 != (hash(cid) % 2 + 2) % 2:
		return
	for wid in GS.wars_of(s, cid):
		var w: Dictionary = s["wars"][wid]
		var side := DiplomacySystem.side_of(w, cid)
		var foes: Array = w["defenders"] if side == "attackers" else w["attackers"]
		# only leaders negotiate for the whole war
		var leader: String = w["leader_a"] if side == "attackers" else w["leader_d"]
		if leader != cid:
			continue
		var foe_leader: String = w["leader_d"] if side == "attackers" else w["leader_a"]
		if not s["countries"].get(foe_leader, {}).get("alive", false):
			continue
		var lead := DiplomacySystem.score_for(s, wid, cid)
		var exh := float(c_exh(s, cid))
		var length := int(s["turn"]) - int(w["start_turn"])
		if lead >= 18.0:
			var terms := build_demands(s, cid, foe_leader, wid, lead)
			if foe_leader in s["players"]:
				if length > 4 and rng.chance(0.25):
					_propose_peace_to_player(s, cid, foe_leader, wid, terms)
			else:
				var ev := DiplomacySystem.peace_eval(s, wid, cid, foe_leader, terms)
				if ev["accept"] and (not terms["provinces"].is_empty() or terms.get("vassalize", false) or float(terms.get("gold", 0.0)) > 0.0):
					DiplomacySystem.make_peace(s, wid, cid, foe_leader, terms)
					return
		elif lead <= -18.0 or (length > 20 and exh > 40.0 and lead < 10.0) or (length > 40 and lead < 20.0):
			if foe_leader in s["players"]:
				if rng.chance(0.25):
					_propose_peace_to_player(s, cid, foe_leader, wid, {"white": true})
			else:
				var ev4 := DiplomacySystem.peace_eval(s, wid, cid, foe_leader, {"white": true})
				if ev4["accept"]:
					DiplomacySystem.make_peace(s, wid, cid, foe_leader, {"white": true})
					return

static func c_exh(s: Dictionary, cid: String) -> float:
	return float(s["countries"][cid].get("war_exhaustion", 0.0))

static func _propose_peace_to_player(s: Dictionary, from: String, to: String, wid: String, terms: Dictionary) -> void:
	var pend: Array = s["pending_requests"]
	for r in pend:
		if r["action"] == "peace" and r["from"] == from:
			return
	if pend.size() >= 4:
		return
	pend.append({"id": "P%d_%s_%s" % [int(s["turn"]), from, wid], "from": from, "to": to, "action": "peace", "params": {"war": wid, "terms": terms}, "turn": s["turn"]})
	GS.note(s, to, "war", "NOTE_PEACE_OFFER", {"other": from})

static func build_demands(s: Dictionary, cid: String, foe: String, wid: String, lead: float) -> Dictionary:
	# take provinces we occupy first, then claimed ones, until the war score budget is used
	var budget := lead * 0.92
	var cands: Array = []
	for pid in GS.owned(s, foe):
		var p: Dictionary = s["provinces"][pid]
		var v := DiplomacySystem.prov_value(s, pid) * 0.9
		if cid in p["claims"] or cid in p["cores"]:
			v *= 0.7
		var pri := v
		if p["controller"] == cid:
			pri += 20.0
		if cid in p["claims"]:
			pri += 12.0
		cands.append([pri, pid, v])
	cands.sort_custom(func(a, b): return a[0] > b[0])
	var take: Array = []
	var cost := 0.0
	for cd in cands:
		var pid: String = cd[1]
		var p2: Dictionary = s["provinces"][pid]
		# only provinces we can hold: occupied or bordering ours
		if p2["controller"] != cid and not _borders_owned(s, pid, cid):
			continue
		if cost + float(cd[2]) <= budget:
			take.append(pid)
			cost += float(cd[2])
	var terms := {"provinces": take, "white": false}
	if take.is_empty() and lead >= 25.0:
		var g := minf(float(s["countries"][foe]["gold"]) * 0.8, lead * 3.0)
		if g > 20.0:
			terms["gold"] = g
	elif lead - cost > 15.0 and take.size() > 0:
		terms["gold"] = minf(float(s["countries"][foe]["gold"]) * 0.5, (lead - cost) * 3.0)
	return terms

static func build_concessions(s: Dictionary, cid: String, foe: String, behind: float) -> Dictionary:
	var give: Array = []
	var budget := behind * 0.5
	var cost := 0.0
	var cands: Array = []
	for pid in GS.owned(s, cid):
		var p: Dictionary = s["provinces"][pid]
		if p["controller"] == foe:
			cands.append([DiplomacySystem.prov_value(s, pid) * 0.9, pid])
	cands.sort_custom(func(a, b): return a[0] < b[0])
	for cd in cands:
		if cost + float(cd[0]) <= budget and pid_not_capital(s, cid, cd[1]):
			give.append(cd[1])
			cost += float(cd[0])
	return {"provinces": give, "white": false}

static func pid_not_capital(s: Dictionary, cid: String, pid: String) -> bool:
	return s["countries"][cid]["capital"] != pid

static func _borders_owned(s: Dictionary, pid: String, cid: String) -> bool:
	for nb in Defs.neighbors(pid):
		if s["provinces"][nb]["owner"] == cid:
			return true
	return false
