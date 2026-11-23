class_name Combat
extends RefCounted
## Land battle resolution. The outcome depends on numbers inside the combat width, commanders (skill and traits),
## terrain, rivers and passes crossed, weather and season, morale, discipline, experience, technology, doctrine,
## supply, unit-composition counters, fortification and seeded luck. The report lists every factor with its numeric
## contribution (BattleFactors) so the player can see why a battle was won. Naval battles are in NavalCombat.

const ROUNDS_PER_PHASE := 3
const K_DAMAGE := 0.06
const CLASS_MOD := {"cavalry": "cav_atk", "heavy_cavalry": "cav_atk", "artillery": "art_atk", "naval": "naval_atk"}

## Build the combat profile of a set of armies.
static func profile(s: Dictionary, army_ids: Array, pid: String, defending: bool, weather: Dictionary) -> Dictionary:
	var counts := {}
	var n := 0.0
	var morale_w := 0.0
	var supply_w := 0.0
	var xp_w := 0.0
	var disc_w := 0.0
	var funding_w := 0.0
	var mods_acc := {}
	var doc_acc := {}
	for k in BattleFactors.KEYS:
		mods_acc[k] = 0.0
		doc_acc[k] = 0.0
	var owners := {}
	var naval := false
	var gen: Variant = null
	var gen_owner := ""
	var best_tac := -1.0
	var terrain: String = Defs.provinces[pid]["terrain"]
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
		disc_w += float(a.get("discipline", 50.0)) * sz
		supply_w += float(a.get("supply", 1.0)) * sz
		var m := Mods.country(s, a["owner"])
		var dm := DoctrineSystem.mods_of(s, s["countries"][a["owner"]])
		for k in mods_acc:
			mods_acc[k] += float(m.get(k, 0.0)) * sz
			doc_acc[k] += float(dm.get(k, 0.0)) * sz
		var g: Variant = a.get("general")
		if g != null:
			var et := Commanders.eff_tac(g, terrain) + float(m.get("general_skill", 0.0))
			if et > best_tac:
				best_tac = et
				gen = g
				gen_owner = a["owner"]
		funding_w += float(s["countries"][a["owner"]].get("army_funding", 1.0)) * sz
	if n <= 0.0:
		return {"n": 0.0}
	for k in mods_acc:
		mods_acc[k] /= n
		doc_acc[k] /= n
	var fire := 0.0
	var shock := 0.0
	var dfn := 0.0
	var p_raw := 0.0
	var p_tech := 0.0
	var cav_n := 0.0
	var art_n := 0.0
	var eng_n := 0.0
	var bridge_n := 0.0
	var mtn_n := 0.0
	var comp := {}
	for uid in counts:
		var u: Dictionary = Defs.units[uid]
		var c := float(counts[uid])
		var cls: String = u["cls"]
		var f := float(u["fire"])
		var sh := float(u["shock"])
		var tmul := 1.0
		match cls:
			"cavalry", "heavy_cavalry":
				tmul = float(Const.TERRAIN_CAV.get(terrain, 1.0))
				cav_n += c
			"artillery":
				tmul = float(Const.TERRAIN_ART.get(terrain, 1.0))
				art_n += c
			"engineer":
				eng_n += c
		if UnitUtil.has_tag(uid, "bridging"):
			bridge_n += c
		if UnitUtil.has_tag(uid, "mountain"):
			mtn_n += c
		var key: String = CLASS_MOD.get(cls, "inf_atk")
		var amod := float(mods_acc[key])
		var dmod := 1.0 + (float(mods_acc["inf_def"]) if cls != "naval" else 0.0)
		fire += c * f * tmul * (1.0 + amod)
		shock += c * sh * tmul * (1.0 + amod)
		dfn += c * float(u["defense"]) * dmod
		p_raw += c * (f + sh) * tmul
		p_tech += c * (f + sh) * tmul * (1.0 + amod - float(doc_acc[key]))
		comp[cls] = float(comp.get(cls, 0.0)) + c
	var p_all := fire + shock
	var funding := funding_w / n
	var morale_total := (morale_w / n) * (1.0 + float(mods_acc["morale"])) * (0.7 + 0.3 * funding)
	if gen != null:
		morale_total *= 1.0 + Commanders.bonus(gen, "morale")
	var disc_mods := {"discipline": float(mods_acc["discipline"]), "river_pen": float(mods_acc["river_pen"]), "anti_cav": float(mods_acc["anti_cav"])}
	return {"n": n, "fire": fire, "shock": shock, "def": dfn, "morale": morale_total, "avg_morale": (morale_w / n) / 100.0,
		"tac": maxf(best_tac, 0.0), "gen": gen, "gen_owner": gen_owner, "supply": supply_w / n, "xp": xp_w / n, "disc": disc_w / n,
		"counts": counts, "comp": comp, "class_share": BattleFactors.shares(counts), "cav_share": cav_n / n, "art_share": art_n / n,
		"eng_share": eng_n / n, "bridging_share": bridge_n / n, "mountain_share": mtn_n / n, "owners": owners.keys(),
		"fort_mod": float(mods_acc["fort_def"]), "naval": naval, "armies": army_ids.duplicate(), "mods": disc_mods,
		"tech_mult": p_tech / maxf(p_raw, 0.001), "doc_mult": p_all / maxf(p_tech, 0.001), "pursuit_mod": float(mods_acc["pursuit"])}

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
	var mud := 0.0
	if season == 3 and absf(lat) > 38.0:
		attr = 0.03 + (absf(lat) - 38.0) * 0.0015
		mv = 0.8
		atk = 0.95
		if t == "arctic":
			attr += 0.03
	if season == 1 and (t == "desert"):
		attr = 0.04
		atk = 0.92
	if t == "mountains" and season == 3:
		attr += 0.02
	if t in ["jungle", "marsh"] and season in [1, 2]:
		attr += 0.015
	# spring thaw and autumn rains turn roads to mud in temperate lowlands
	if absf(lat) > 35.0 and season in [0, 2] and t in ["plains", "marsh", "forest", "steppe"]:
		mud = 1.0 if (season == 0 or t == "marsh") else 0.6
		mv *= 1.0 - 0.15 * mud
	return {"attrition": attr, "move": mv, "attack": atk, "season": season, "mud": mud}

## Resolve a battle. side_a = attacking army ids, side_d = defending army ids.
static func resolve(s: Dictionary, pid: String, side_a: Array, side_d: Array, assault_from_sea: bool = false) -> Dictionary:
	var rng := GS.rng_of(s)
	var weather := weather_for(s, pid)
	var pa := profile(s, side_a, pid, false, weather)
	var pdf := profile(s, side_d, pid, true, weather)
	if float(pa.get("n", 0.0)) <= 0.0 or float(pdf.get("n", 0.0)) <= 0.0:
		return {}
	if bool(pa["naval"]) and bool(pdf["naval"]):
		return NavalCombat.resolve(s, pid, side_a, side_d, pa, pdf)
	var prov: Dictionary = s["provinces"][pid]
	var fort := 0.0
	if prov["owner"] in pdf["owners"] or prov["controller"] in pdf["owners"]:
		fort = Mods.fort_level(s, pid)
	var tdef: float = float(Const.TERRAIN_DEF.get(Defs.provinces[pid]["terrain"], 0.0))
	var luck := [clampf(1.0 + rng.gauss(0.0, 0.045), 0.9, 1.1), clampf(1.0 + rng.gauss(0.0, 0.045), 0.9, 1.1)]
	var fx := BattleFactors.compute(s, pid, pa, pdf, assault_from_sea, weather, fort, tdef, luck)
	var width := width_for(pid, false) * float(fx["width_mult"])
	# effective engaged strength with reserves
	var ea := minf(float(pa["n"]), width) + 0.35 * maxf(0.0, float(pa["n"]) - width)
	var ed := minf(float(pdf["n"]), width) + 0.35 * maxf(0.0, float(pdf["n"]) - width)
	var ma: float = float(pa["morale"]) + float(fx["ma"])
	var md: float = float(pdf["morale"]) + float(fx["md"])
	var scale_a := ea / float(pa["n"])
	var scale_d := ed / float(pdf["n"])
	var pw_a := float(fx["pa"])
	var pw_d := float(fx["pd"])
	var cas_mult_d := float(fx["cd"])
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
			var fa := cur_na / start_na
			var fd := cur_nd / start_nd
			var dice_a := 0.85 + 0.3 * rng.randf()
			var dice_d := 0.85 + 0.3 * rng.randf()
			var dmg_a := wa * scale_a * fa * dice_a * pw_a * (ma / 100.0 + 0.35)
			var dmg_d := wd * scale_d * fd * dice_d * pw_d * (md / 100.0 + 0.35)
			var cas_d := minf(dmg_a * K_DAMAGE / (dpd + 5.0) * cas_mult_d, cur_nd * 0.35)
			var cas_a := minf(dmg_d * K_DAMAGE / (dpa + 5.0), cur_na * 0.35)
			cur_nd -= cas_d
			cur_na -= cas_a
			losses_d += cas_d
			losses_a += cas_a
			# morale: casualty shock + steady attrition of will (discipline steadies the troops)
			var steady_a := clampf(1.15 - float(pa["disc"]) / 400.0, 0.85, 1.15)
			var steady_d := clampf(1.15 - float(pdf["disc"]) / 400.0, 0.85, 1.15)
			ma -= ((cas_a / maxf(cur_na + cas_a, 0.5)) * 55.0 + 1.2 + (1.5 if dmg_d > dmg_a else 0.0)) * steady_a
			md -= ((cas_d / maxf(cur_nd + cas_d, 0.5)) * 55.0 + 1.2 + (1.5 if dmg_a > dmg_d else 0.0)) * steady_d
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
	# pursuit: cavalry-heavy winners destroy more of the loser
	var win_prof: Dictionary = pa if att_wins else pdf
	var pursuit := clampf(float(win_prof["cav_share"]) * 0.25 + 0.04 + float(win_prof["pursuit_mod"]) * 0.1, 0.02, 0.22)
	var lose_n: float = cur_nd if att_wins else cur_na
	var pcas := lose_n * pursuit * (1.0 if ended == "rout" else 0.5)
	if att_wins:
		cur_nd -= pcas
		losses_d += pcas
	else:
		cur_na -= pcas
		losses_a += pcas
	var factors := legacy_factors(fx["list"])
	return {
		"pid": pid, "turn": s["turn"], "naval": false, "winner": "attacker" if att_wins else "defender",
		"attackers": _side_info(s, pa), "defenders": _side_info(s, pdf),
		"start_a": start_na, "start_d": start_nd, "loss_a": losses_a, "loss_d": losses_d,
		"end_a": maxf(0.0, cur_na), "end_d": maxf(0.0, cur_nd),
		"morale_a": ma, "morale_d": md, "factors": factors, "modifiers": fx["list"], "power": [pw_a, pw_d],
		"reasons": reasons_of(fx["list"], att_wins), "rounds": rounds,
		"terrain": Defs.provinces[pid]["terrain"], "fort": fort, "width": width, "rout": ended == "rout",
		"side_a_ids": side_a.duplicate(), "side_d_ids": side_d.duplicate(), "weather": weather["season"],
		"river": {"name": fx["ctx"]["river_name"], "width": fx["ctx"]["river_width"], "share": fx["ctx"]["river_share"], "bridged": fx["ctx"]["bridged"]},
		"pass": {"name": fx["ctx"]["pass_name"], "share": fx["ctx"]["pass_share"]},
		"commanders": {"a": commander_info(pa), "d": commander_info(pdf)}, "events": [],
	}

## Old-style {key: [attacker value, defender value]} table (kept for the UI and tests).
static func legacy_factors(list: Array) -> Dictionary:
	var out := {}
	for f in list:
		var k: String = f["key"]
		match str(f["kind"]):
			"info":
				out[k] = [float(f["va"]), float(f["vd"])]
			"inc":
				out[k] = [(float(f["a"]) - 1.0) * 100.0, (float(f["d"]) - 1.0) * 100.0]
			_:
				out[k] = [BattleFactors.contribution_pct(f, "a"), BattleFactors.contribution_pct(f, "d")]
	return out

## Strongest advantages of the winner, as Loc keys.
static func reasons_of(list: Array, att_wins: bool) -> Array:
	var scored: Array = []
	for f in list:
		if str(f["kind"]) == "info":
			continue
		var adv := BattleFactors.contribution_pct(f, "a") - BattleFactors.contribution_pct(f, "d")
		if str(f["kind"]) == "protect":
			adv = -BattleFactors.contribution_pct(f, "d") + BattleFactors.contribution_pct(f, "a")
		var w := adv if att_wins else -adv
		if w > 3.0 and f["key"] != "FACTOR_LUCK":
			scored.append([w, f["key"]])
	scored.sort_custom(func(a, b): return a[0] > b[0])
	var out: Array = []
	for i in range(mini(3, scored.size())):
		out.append(scored[i][1])
	if out.is_empty():
		out.append("FACTOR_LUCK")
	return out

static func commander_info(p: Dictionary) -> Dictionary:
	var g: Variant = p.get("gen")
	if g == null:
		return {}
	var gd: Dictionary = g
	return {"name": gd.get("name", ""), "tac": gd.get("tac", 0), "traits": (gd.get("traits", []) as Array).duplicate(), "owner": p.get("gen_owner", "")}

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
		for uid in a["units"].keys():
			if float(a["units"][uid]) < 0.05:
				a["units"].erase(uid)
	return removed
