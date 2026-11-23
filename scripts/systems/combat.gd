class_name Combat
extends RefCounted
## Battle resolution. Outcomes depend on composition, terrain, general skill, morale, supply,
## technology, fortification, weather and numbers (not just totals), and the report explains why.

const ROUNDS_PER_PHASE := 3
const K_DAMAGE := 0.06

## Build the combat profile of a set of armies.
static func profile(s: Dictionary, army_ids: Array, pid: String, defending: bool, weather: Dictionary) -> Dictionary:
	var counts := {}
	var n := 0.0
	var morale_w := 0.0
	var best_tac := 0.0
	var mods_acc := {"inf_atk": 0.0, "inf_def": 0.0, "cav_atk": 0.0, "art_atk": 0.0, "naval_atk": 0.0, "morale": 0.0, "fort_def": 0.0}
	var supply_w := 0.0
	var xp_w := 0.0
	var funding_w := 0.0
	var owners := {}
	var naval := false
	for aid in army_ids:
		var a: Dictionary = s["armies"][aid]
		var sz := UnitUtil.army_size(a)
		if sz <= 0.0:
			continue
		naval = naval or bool(a.get("naval", false))
		owners[a["owner"]] = true
		for uid in a["units"]:
			counts[uid] = float(counts.get(uid, 0.0)) + float(a["units"][uid])
		n += sz
		morale_w += float(a["morale"]) * sz
		xp_w += float(a.get("xp", 0.0)) * sz
		supply_w += float(a.get("supply", 1.0)) * sz
		var m := Mods.country(s, a["owner"])
		for k in mods_acc:
			mods_acc[k] += float(m.get(k, 0.0)) * sz
		var g: Variant = a.get("general")
		if g != null:
			best_tac = maxf(best_tac, float(g["tac"]) + float(m.get("general_skill", 0.0)))
		funding_w += float(s["countries"][a["owner"]].get("army_funding", 1.0)) * sz
	if n <= 0.0:
		return {"n": 0.0}
	for k in mods_acc:
		mods_acc[k] /= n
	var terrain: String = Defs.provinces[pid]["terrain"] if not naval else "plains"
	var fire := 0.0
	var shock := 0.0
	var dfn := 0.0
	var cav_n := 0.0
	var art_n := 0.0
	var inf_n := 0.0
	var comp := {}
	for uid in counts:
		var u: Dictionary = Defs.units[uid]
		var c := float(counts[uid])
		var cls: String = u["cls"]
		var f := float(u["fire"])
		var sh := float(u["shock"])
		var df := float(u["defense"])
		var tmul := 1.0
		var amod := 0.0
		match cls:
			"cavalry", "heavy_cavalry":
				tmul = float(Const.TERRAIN_CAV.get(terrain, 1.0))
				amod = float(mods_acc["cav_atk"])
				cav_n += c
			"artillery":
				tmul = float(Const.TERRAIN_ART.get(terrain, 1.0))
				amod = float(mods_acc["art_atk"])
				art_n += c
			"naval":
				amod = float(mods_acc["naval_atk"])
			_:
				amod = float(mods_acc["inf_atk"])
				inf_n += c
		var dmod := 1.0 + (float(mods_acc["inf_def"]) if cls != "naval" else 0.0)
		fire += c * f * tmul * (1.0 + amod)
		shock += c * sh * tmul * (1.0 + amod)
		dfn += c * df * dmod
		comp[cls] = float(comp.get(cls, 0.0)) + c
	var avg_morale := (morale_w / n) / 100.0
	var funding := funding_w / n
	var morale_total := (morale_w / n) * (1.0 + float(mods_acc["morale"])) * (0.7 + 0.3 * funding)
	return {"n": n, "fire": fire, "shock": shock, "def": dfn, "morale": morale_total, "avg_morale": avg_morale,
		"tac": best_tac, "supply": supply_w / n, "xp": xp_w / n, "counts": counts, "comp": comp, "cav_share": cav_n / n,
		"art_share": art_n / n, "owners": owners.keys(), "fort_mod": float(mods_acc["fort_def"]), "naval": naval,
		"armies": army_ids.duplicate()}

static func width_for(pid: String, naval: bool) -> float:
	if naval:
		return 16.0
	var t: String = Defs.provinces[pid]["terrain"]
	return Const.BASE_COMBAT_WIDTH * {"plains": 1.25, "steppe": 1.3, "forest": 0.9, "hills": 0.85, "marsh": 0.8, "mountains": 0.65,
		"desert": 1.1, "jungle": 0.75, "arctic": 1.0}.get(t, 1.0)

static func weather_for(s: Dictionary, pid: String) -> Dictionary:
	var d := GS.date_of(s)
	var pd: Dictionary = Defs.provinces[pid]
	var lat := float(pd["lat"])
	var season := GS.season_idx(int(d["month"]))
	if lat < 0.0:
		season = (season + 2) % 4
	var t: String = pd["terrain"]
	var attr := 0.0
	var mv := 1.0
	var atk := 1.0
	if season == 3 and absf(lat) > 38.0:
		attr = 0.03 + (absf(lat) - 38.0) * 0.0015
		mv = 0.8
		atk = 0.95
		if t == "arctic":
			attr += 0.03
	if season == 1 and (t == "desert") :
		attr = 0.04
		atk = 0.92
	if t == "mountains" and season == 3:
		attr += 0.02
	if t in ["jungle", "marsh"] and season in [1, 2]:
		attr += 0.015
	return {"attrition": attr, "move": mv, "attack": atk, "season": season}

## Resolve a battle. side_a = attacking army ids, side_d = defending army ids.
static func resolve(s: Dictionary, pid: String, side_a: Array, side_d: Array, assault_from_sea: bool = false) -> Dictionary:
	var rng := GS.rng_of(s)
	var weather := weather_for(s, pid)
	var pa := profile(s, side_a, pid, false, weather)
	var pdf := profile(s, side_d, pid, true, weather)
	if float(pa.get("n", 0.0)) <= 0.0 or float(pdf.get("n", 0.0)) <= 0.0:
		return {}
	var naval := bool(pa["naval"]) and bool(pdf["naval"])
	var owner_d: String = pdf["owners"][0]
	var prov: Dictionary = s["provinces"][pid]
	var fort := 0.0
	if not naval and prov["owner"] in pdf["owners"] or (not naval and prov["controller"] in pdf["owners"]):
		fort = Mods.fort_level(s, pid)
	var width := width_for(pid, naval)
	var tdef: float = float(Const.TERRAIN_DEF.get(Defs.provinces[pid]["terrain"], 0.0)) if not naval else 0.0
	# effective engaged strength with reserves
	var ea := minf(float(pa["n"]), width) + 0.35 * maxf(0.0, float(pa["n"]) - width)
	var ed := minf(float(pdf["n"]), width) + 0.35 * maxf(0.0, float(pdf["n"]) - width)
	var factors := {}
	var ma: float = float(pa["morale"])
	var md: float = float(pdf["morale"])
	var att_pen := 1.0
	if assault_from_sea:
		att_pen = 0.8
		ma -= 8.0
	var atk_weather := float(weather["attack"])
	var scale_a := ea / float(pa["n"])
	var scale_d := ed / float(pdf["n"])
	var tacdiff := float(pa["tac"]) - float(pdf["tac"])
	var gen_a := 1.0 + 0.035 * clampf(tacdiff, -9.0, 9.0)
	var gen_d := 1.0 - 0.035 * clampf(tacdiff, -9.0, 9.0)
	var supply_a := clampf(float(pa["supply"]), 0.4, 1.0)
	var supply_d := clampf(float(pdf["supply"]), 0.4, 1.0)
	var xp_a := 1.0 + float(pa["xp"]) / 400.0
	var xp_d := 1.0 + float(pdf["xp"]) / 400.0
	factors["FACTOR_NUMBERS"] = [float(pa["n"]), float(pdf["n"])]
	factors["FACTOR_GENERAL"] = [float(pa["tac"]), float(pdf["tac"])]
	factors["FACTOR_TERRAIN"] = [0.0, tdef * 100.0]
	factors["FACTOR_FORT"] = [0.0, fort * 6.0]
	factors["FACTOR_MORALE"] = [ma, md]
	factors["FACTOR_SUPPLY"] = [supply_a * 100.0, supply_d * 100.0]
	factors["FACTOR_WEATHER"] = [atk_weather * 100.0, 100.0]
	factors["FACTOR_TECH"] = [(float(Mods.get_mod(s, pa["owners"][0], "inf_atk")) + float(Mods.get_mod(s, pa["owners"][0], "art_atk"))) * 50.0,
		(float(Mods.get_mod(s, owner_d, "inf_atk")) + float(Mods.get_mod(s, owner_d, "art_atk"))) * 50.0]
	factors["FACTOR_COMPOSITION"] = [float(pa["cav_share"]) * 100.0 + float(pa["art_share"]) * 100.0, float(pdf["cav_share"]) * 100.0 + float(pdf["art_share"]) * 100.0]
	var losses_a := 0.0
	var losses_d := 0.0
	var rounds: Array = []
	var start_na: float = float(pa["n"])
	var start_nd: float = float(pdf["n"])
	var cur_na: float = start_na
	var cur_nd: float = start_nd
	var dpa: float = float(pa["def"]) / start_na
	var dpd: float = float(pdf["def"]) / start_nd
	var phases := ["fire", "shock", "shock"]
	var ended := ""
	var rnum := 0
	for ph in phases.size():
		var phase: String = phases[ph]
		for r in ROUNDS_PER_PHASE:
			rnum += 1
			var wa := float(pa["fire"]) if phase == "fire" else float(pa["shock"]) + 0.25 * float(pa["fire"])
			var wd := float(pdf["fire"]) if phase == "fire" else float(pdf["shock"]) + 0.25 * float(pdf["fire"])
			# strength scales as casualties mount
			var fa := cur_na / start_na
			var fd := cur_nd / start_nd
			var dice_a := 0.85 + 0.3 * rng.randf()
			var dice_d := 0.85 + 0.3 * rng.randf()
			var dmg_a := wa * scale_a * fa * dice_a * gen_a * supply_a * xp_a * atk_weather * att_pen * (ma / 100.0 + 0.35)
			var dmg_d := wd * scale_d * fd * dice_d * gen_d * supply_d * xp_d * (md / 100.0 + 0.35)
			# defender's terrain and fortifications blunt the attack
			dmg_a *= (1.0 - tdef) * (1.0 - clampf(fort * 0.06, 0.0, 0.5))
			var cas_d := dmg_a * K_DAMAGE / (dpd + 5.0)
			var cas_a := dmg_d * K_DAMAGE / (dpa + 5.0)
			cas_d = minf(cas_d, cur_nd * 0.35)
			cas_a = minf(cas_a, cur_na * 0.35)
			cur_nd -= cas_d
			cur_na -= cas_a
			losses_d += cas_d
			losses_a += cas_a
			# morale: casualty shock + steady attrition of will
			ma -= (cas_a / maxf(cur_na + cas_a, 0.5)) * 55.0 + 1.2 + (1.5 if dmg_d > dmg_a else 0.0)
			md -= (cas_d / maxf(cur_nd + cas_d, 0.5)) * 55.0 + 1.2 + (1.5 if dmg_a > dmg_d else 0.0)
			rounds.append({"n": rnum, "phase": phase, "la": snappedf(cas_a, 0.01), "ld": snappedf(cas_d, 0.01), "ma": snappedf(ma, 0.1), "md": snappedf(md, 0.1)})
			if ma <= 0.0 or md <= 0.0 or cur_na < 0.3 or cur_nd < 0.3:
				ended = "rout"
				break
		if ended != "":
			break
	var att_wins: bool
	if ma <= 0.0 and md > 0.0:
		att_wins = false
	elif md <= 0.0 and ma > 0.0:
		att_wins = true
	else:
		att_wins = (ma * cur_na) > (md * cur_nd)
	# pursuit: cavalry heavy winners destroy more of the loser
	var win_prof: Dictionary = pa if att_wins else pdf
	var lose_prof: Dictionary = pdf if att_wins else pa
	var pursuit := clampf(float(win_prof["cav_share"]) * 0.25 + 0.04, 0.02, 0.18)
	if naval:
		pursuit = 0.05
	var lose_n: float = cur_nd if att_wins else cur_na
	var pcas := lose_n * pursuit * (1.0 if ended == "rout" else 0.5)
	if att_wins:
		cur_nd -= pcas
		losses_d += pcas
	else:
		cur_na -= pcas
		losses_a += pcas
	# determine the main reasons
	var reasons: Array = []
	var order := ["FACTOR_NUMBERS", "FACTOR_GENERAL", "FACTOR_TERRAIN", "FACTOR_FORT", "FACTOR_MORALE", "FACTOR_SUPPLY", "FACTOR_WEATHER", "FACTOR_TECH", "FACTOR_COMPOSITION"]
	var scored: Array = []
	for k in order:
		var pair: Array = factors[k]
		var diff := float(pair[0]) - float(pair[1])
		var norm := maxf(1.0, maxf(absf(float(pair[0])), absf(float(pair[1]))))
		var advantage := diff / norm
		if k == "FACTOR_TERRAIN" or k == "FACTOR_FORT":
			advantage = -float(pair[1]) / 40.0
		var winner_adv := advantage if att_wins else -advantage
		if winner_adv > 0.05:
			scored.append([winner_adv, k])
	scored.sort_custom(func(a, b): return a[0] > b[0])
	for i in range(mini(3, scored.size())):
		reasons.append(scored[i][1])
	if reasons.is_empty():
		reasons.append("FACTOR_LUCK")
	return {
		"pid": pid, "turn": s["turn"], "naval": naval, "winner": "attacker" if att_wins else "defender",
		"attackers": _side_info(s, pa), "defenders": _side_info(s, pdf),
		"start_a": start_na, "start_d": start_nd, "loss_a": losses_a, "loss_d": losses_d,
		"end_a": maxf(0.0, cur_na), "end_d": maxf(0.0, cur_nd),
		"morale_a": ma, "morale_d": md, "factors": factors, "rounds": rounds, "reasons": reasons,
		"terrain": Defs.provinces[pid]["terrain"], "fort": fort, "width": width, "rout": ended == "rout",
		"side_a_ids": side_a.duplicate(), "side_d_ids": side_d.duplicate(),
		"weather": weather["season"],
	}

static func _side_info(s: Dictionary, p: Dictionary) -> Dictionary:
	return {"owners": p["owners"], "n": p["n"], "counts": p["counts"], "tac": p["tac"], "morale": p["morale"]}

## Distribute casualties (in regiments) across a set of armies proportionally to their size.
static func apply_losses(s: Dictionary, army_ids: Array, loss: float, rng: GameRng) -> float:
	var total := 0.0
	for aid in army_ids:
		total += UnitUtil.army_size(s["armies"][aid])
	if total <= 0.0:
		return 0.0
	var removed := 0.0
	for aid in army_ids:
		var a: Dictionary = s["armies"][aid]
		var sz := UnitUtil.army_size(a)
		var share := loss * sz / total
		var frac := clampf(share / maxf(sz, 0.001), 0.0, 1.0)
		for uid in a["units"].keys():
			var cur := float(a["units"][uid])
			var cl := cur * frac
			a["units"][uid] = maxf(0.0, cur - cl)
			removed += cl
		# clean
		for uid in a["units"].keys():
			if float(a["units"][uid]) < 0.05:
				a["units"].erase(uid)
	return removed
