class_name NavalCombat
extends RefCounted
## Sea battles between fleets that meet in a province. Own factors: wind and sea state (the weather gauge), ship-role
## matchups, crews (morale, discipline, experience), the admiral (tactics, gunnery, boarding), technology, doctrine,
## supply (time at sea), shore batteries of a defended port, numbers and seeded luck. Same report format as land
## battles so the report view renders both.

## Bonus of the row role against the column role.
const ROLE_COUNTER := {
	"line": {"cruiser": 0.30, "raider": 0.30, "transport": 0.50, "galley": 0.25},
	"cruiser": {"transport": 0.50, "raider": 0.10, "galley": 0.10, "line": -0.15},
	"raider": {"transport": 0.55, "cruiser": -0.10, "line": -0.25},
	"galley": {"transport": 0.50, "raider": 0.0, "line": -0.20, "cruiser": -0.10},
	"transport": {"transport": 0.0},
}
const K_DAMAGE := 0.06

static func roles(s: Dictionary, army_ids: Array) -> Dictionary:
	var counts := {}
	var n := 0.0
	for aid in army_ids:
		var a: Dictionary = s["armies"][aid]
		for uid in a["units"]:
			var r := str(Defs.units[uid].get("role", "line"))
			counts[r] = float(counts.get(r, 0.0)) + float(a["units"][uid])
			n += float(a["units"][uid])
	if n > 0.0:
		for r in counts:
			counts[r] = float(counts[r]) / n
	return counts

static func _avg_attr(s: Dictionary, army_ids: Array, attr: String, fallback: float) -> float:
	var tot := 0.0
	var n := 0.0
	for aid in army_ids:
		var a: Dictionary = s["armies"][aid]
		for uid in a["units"]:
			var c := float(a["units"][uid])
			tot += float(Defs.units[uid].get(attr, fallback)) * c
			n += c
	return tot / maxf(n, 0.001)

static func role_mult(own: Dictionary, foe: Dictionary) -> float:
	var v := 0.0
	for i in own:
		var row: Dictionary = ROLE_COUNTER.get(i, {})
		for j in foe:
			v += float(own[i]) * float(foe[j]) * float(row.get(j, 0.0))
	return clampf(1.0 + v, 0.7, 1.5)

## Sea state 0..1 for a province and turn: season, latitude and a seeded gust.
static func sea_state(s: Dictionary, pid: String, rng: GameRng) -> float:
	var w := Combat.weather_for(s, pid)
	var base: float = [0.3, 0.2, 0.4, 0.6][int(w["season"])]
	var lat := absf(float(Defs.provinces[pid]["lat"]))
	if lat > 45.0:
		base += 0.1
	elif lat < 20.0 and int(w["season"]) == 2:
		base += 0.15   # tropical storm season
	return clampf(base + rng.gauss(0.0, 0.12), 0.0, 1.0)

static func resolve(s: Dictionary, pid: String, side_a: Array, side_d: Array, pa: Dictionary, pd: Dictionary) -> Dictionary:
	var rng := GS.rng_of(s)
	var prov: Dictionary = s["provinces"][pid]
	var weather := Combat.weather_for(s, pid)
	var state := sea_state(s, pid, rng)
	var ra := roles(s, side_a)
	var rd := roles(s, side_d)
	# weather gauge: faster ships with a skilled, sea-wise admiral hold the wind
	var gauge_a := _avg_attr(s, side_a, "move", 3.0) + float(pa["tac"]) * 0.25 + Commanders.bonus(pa["gen"], "weather")
	var gauge_d := _avg_attr(s, side_d, "move", 3.0) + float(pd["tac"]) * 0.25 + Commanders.bonus(pd["gen"], "weather")
	var gauge_win := "a" if gauge_a + rng.randf() * 0.8 > gauge_d + rng.randf() * 0.8 else "d"
	var rough_a := _avg_attr(s, side_a, "rough", 1.0)
	var rough_d := _avg_attr(s, side_d, "rough", 1.0)
	var w_a := (1.0 - 0.16 * state * (rough_a - 0.45)) * (1.06 if gauge_win == "a" else 1.0) * float(weather["attack"] if state > 0.5 else 1.0)
	var w_d := (1.0 - 0.16 * state * (rough_d - 0.45)) * (1.06 if gauge_win == "d" else 1.0)
	var fort := 0.0
	if prov["controller"] in pd["owners"] and int(prov["buildings"].get("port", 0)) > 0:
		fort = Mods.fort_level(s, pid) * 0.6   # shore batteries cover a defended port
	var luck := [clampf(1.0 + rng.gauss(0.0, 0.05), 0.9, 1.1), clampf(1.0 + rng.gauss(0.0, 0.05), 0.9, 1.1)]
	var list: Array = []
	list.append(BattleFactors.entry("FACTOR_NUMBERS", "info", float(pa["n"]), float(pd["n"]), float(pa["n"]), float(pd["n"])))
	var tacdiff := clampf(float(pa["tac"]) - float(pd["tac"]), -9.0, 9.0)
	var g_a := 1.0 + 0.035 * tacdiff + Commanders.bonus(pa["gen"], "gunnery") + Commanders.bonus(pa["gen"], "boarding") * 0.5
	var g_d := 1.0 - 0.035 * tacdiff + Commanders.bonus(pd["gen"], "gunnery") + Commanders.bonus(pd["gen"], "boarding") * 0.5
	list.append(BattleFactors.entry("FACTOR_ADMIRAL", "power", g_a, g_d, float(pa["tac"]), float(pd["tac"])))
	list.append(BattleFactors.entry("FACTOR_WIND", "power", w_a, w_d, state * 100.0, 100.0 if gauge_win == "d" else 0.0))
	var rm_a := role_mult(ra, rd)
	var rm_d := role_mult(rd, ra)
	list.append(BattleFactors.entry("FACTOR_SHIPS", "power", rm_a, rm_d))
	var dis_a := clampf(0.85 + float(pa["disc"]) / 100.0 * 0.3 + float(pa["mods"].get("discipline", 0.0)), 0.7, 1.35)
	var dis_d := clampf(0.85 + float(pd["disc"]) / 100.0 * 0.3 + float(pd["mods"].get("discipline", 0.0)), 0.7, 1.35)
	list.append(BattleFactors.entry("FACTOR_DISCIPLINE", "power", dis_a, dis_d, float(pa["disc"]), float(pd["disc"])))
	var xp_a := 1.0 + float(pa["xp"]) / 400.0
	var xp_d := 1.0 + float(pd["xp"]) / 400.0
	list.append(BattleFactors.entry("FACTOR_EXPERIENCE", "power", xp_a, xp_d, float(pa["xp"]), float(pd["xp"])))
	list.append(BattleFactors.entry("FACTOR_TECH", "inc", float(pa["tech_mult"]), float(pd["tech_mult"])))
	list.append(BattleFactors.entry("FACTOR_DOCTRINE", "inc", float(pa["doc_mult"]), float(pd["doc_mult"])))
	var sup_a := clampf(float(pa["supply"]), 0.4, 1.0)
	var sup_d := clampf(float(pd["supply"]), 0.4, 1.0)
	list.append(BattleFactors.entry("FACTOR_SUPPLY", "power", sup_a, sup_d, sup_a * 100.0, sup_d * 100.0))
	var fort_prot := 1.0 - clampf(fort * 0.06, 0.0, 0.4)
	list.append(BattleFactors.entry("FACTOR_FORT", "protect", 1.0, fort_prot, 0.0, fort))
	list.append(BattleFactors.entry("FACTOR_MORALE", "info", 1.0, 1.0, float(pa["morale"]), float(pd["morale"])))
	list.append(BattleFactors.entry("FACTOR_LUCK", "power", float(luck[0]), float(luck[1])))
	var pw_a: float = g_a * w_a * rm_a * dis_a * xp_a * sup_a * float(luck[0])
	var pw_d: float = g_d * w_d * rm_d * dis_d * xp_d * sup_d * float(luck[1])
	var cas_mult_d := fort_prot
	var ma: float = float(pa["morale"]) * (1.0 + float(pa["mods"].get("naval_morale", 0.0)))
	var md: float = float(pd["morale"]) * (1.0 + float(pd["mods"].get("naval_morale", 0.0)))
	var start_na: float = float(pa["n"])
	var start_nd: float = float(pd["n"])
	var cur_na := start_na
	var cur_nd := start_nd
	var width := Combat.width_for(pid, true)
	var scale_a := (minf(start_na, width) + 0.35 * maxf(0.0, start_na - width)) / start_na
	var scale_d := (minf(start_nd, width) + 0.35 * maxf(0.0, start_nd - width)) / start_nd
	var dpa: float = float(pa["def"]) / start_na
	var dpd: float = float(pd["def"]) / start_nd
	var losses_a := 0.0
	var losses_d := 0.0
	var rounds: Array = []
	var ended := ""
	var rnum := 0
	for phase in ["fire", "fire", "shock"]:
		for r in 3:
			rnum += 1
			var wa := float(pa["fire"]) if phase == "fire" else float(pa["shock"]) + 0.25 * float(pa["fire"])
			var wd := float(pd["fire"]) if phase == "fire" else float(pd["shock"]) + 0.25 * float(pd["fire"])
			var dice_a := 0.85 + 0.3 * rng.randf()
			var dice_d := 0.85 + 0.3 * rng.randf()
			var dmg_a := wa * scale_a * (cur_na / start_na) * dice_a * pw_a * (ma / 100.0 + 0.35)
			var dmg_d := wd * scale_d * (cur_nd / start_nd) * dice_d * pw_d * (md / 100.0 + 0.35)
			var cas_d := minf(dmg_a * K_DAMAGE / (dpd + 5.0) * cas_mult_d, cur_nd * 0.35)
			var cas_a := minf(dmg_d * K_DAMAGE / (dpa + 5.0), cur_na * 0.35)
			cur_nd -= cas_d
			cur_na -= cas_a
			losses_d += cas_d
			losses_a += cas_a
			ma -= (cas_a / maxf(cur_na + cas_a, 0.5)) * 55.0 + 1.0 + (1.5 if dmg_d > dmg_a else 0.0)
			md -= (cas_d / maxf(cur_nd + cas_d, 0.5)) * 55.0 + 1.0 + (1.5 if dmg_a > dmg_d else 0.0)
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
	# the beaten fleet is hunted by the faster winner
	var lose_n := cur_nd if att_wins else cur_na
	var chase := lose_n * 0.05 * (1.0 if ended == "rout" else 0.5)
	if att_wins:
		cur_nd -= chase
		losses_d += chase
	else:
		cur_na -= chase
		losses_a += chase
	return {
		"pid": pid, "turn": s["turn"], "naval": true, "winner": "attacker" if att_wins else "defender",
		"attackers": Combat._side_info(s, pa), "defenders": Combat._side_info(s, pd),
		"start_a": start_na, "start_d": start_nd, "loss_a": losses_a, "loss_d": losses_d,
		"end_a": maxf(0.0, cur_na), "end_d": maxf(0.0, cur_nd), "morale_a": ma, "morale_d": md,
		"factors": Combat.legacy_factors(list), "modifiers": list, "power": [pw_a, pw_d], "reasons": Combat.reasons_of(list, att_wins),
		"rounds": rounds, "terrain": "sea", "fort": fort, "width": width, "rout": ended == "rout",
		"side_a_ids": side_a.duplicate(), "side_d_ids": side_d.duplicate(), "weather": weather["season"],
		"river": {"name": "", "width": 0, "share": 0.0, "bridged": false}, "pass": {"name": "", "share": 0.0},
		"sea": {"state": state, "gauge": gauge_win, "zone": SeaZones.zone_of(pid)},
		"commanders": {"a": Combat.commander_info(pa), "d": Combat.commander_info(pd)}, "events": [],
	}
