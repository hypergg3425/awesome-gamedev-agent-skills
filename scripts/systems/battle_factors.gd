class_name BattleFactors
extends RefCounted
## Every factor that decides a land battle, with its numeric contribution. A factor is a Dictionary
## {"key": Loc key, "kind": "power" | "protect" | "inc" | "info", "a": x, "d": y, "va": raw, "vd": raw, "note": String}.
##  power   multiplies the side's damage output (a, d are multipliers; 1.0 = neutral)
##  protect multiplies the casualties the side suffers (below 1.0 = better protected)
##  inc     already included in the base strength (technology, doctrine): listed so the report shows its weight
##  info    raw numbers for the report only (army sizes, morale, ...)
## Contribution shown to the player is (multiplier - 1) * 100 %.

## Counter matrix: bonus of the row class against the column class (fractions of damage).
const COUNTER := {
	"cav": {"arch": 0.5, "art": 0.6, "inf": 0.15, "pike": -0.5, "hinf": -0.1, "eng": 0.3},
	"hcav": {"inf": 0.45, "arch": 0.5, "art": 0.5, "pike": -0.35, "hinf": 0.1, "cav": 0.15, "eng": 0.3},
	"pike": {"cav": 0.45, "hcav": 0.45, "arch": -0.1, "art": -0.2},
	"inf": {"arch": 0.1, "art": 0.2, "cav": -0.1},
	"hinf": {"arch": 0.3, "inf": 0.15, "art": 0.2, "cav": 0.1},
	"arch": {"hcav": 0.35, "hinf": 0.25, "pike": 0.3, "cav": 0.1, "inf": 0.05},
	"art": {"pike": 0.45, "inf": 0.25, "hinf": 0.2, "arch": 0.1, "cav": 0.15, "hcav": 0.2},
	"eng": {},
}
const RIVER_PENALTY := 0.07      # attacker power loss per river width point (fully crossed)
const PASS_PROTECT := 0.15       # defender casualty reduction when the attack came through a pass
const KEYS := ["inf_atk", "inf_def", "cav_atk", "art_atk", "naval_atk", "morale", "fort_def", "discipline", "pursuit", "river_pen", "anti_cav"]

## Combat class of a unit for the counter matrix.
static func counter_class(uid: String) -> String:
	var u: Dictionary = Defs.units[uid]
	var cls: String = u["cls"]
	var pike := UnitUtil.has_tag(uid, "pike")
	match cls:
		"infantry":
			return "pike" if pike else "inf"
		"heavy_infantry":
			return "pike" if pike else "hinf"
		"archers":
			return "arch"
		"cavalry":
			return "cav"
		"heavy_cavalry":
			return "hcav"
		"artillery":
			return "art"
		"engineer":
			return "eng"
	return "inf"

static func shares(counts: Dictionary) -> Dictionary:
	var out := {}
	var n := 0.0
	for uid in counts:
		var k := counter_class(uid)
		out[k] = float(out.get(k, 0.0)) + float(counts[uid])
		n += float(counts[uid])
	if n > 0.0:
		for k in out:
			out[k] = float(out[k]) / n
	return out

static func counter_mult(sh_own: Dictionary, sh_foe: Dictionary, anti_cav: float) -> float:
	var v := 0.0
	for i in sh_own:
		var row: Dictionary = COUNTER.get(i, {})
		for j in sh_foe:
			v += float(sh_own[i]) * float(sh_foe[j]) * float(row.get(j, 0.0))
	# doctrines against cavalry strengthen the pike/infantry share
	v += anti_cav * (float(sh_own.get("pike", 0.0)) + 0.3 * float(sh_own.get("inf", 0.0))) * (float(sh_foe.get("cav", 0.0)) + float(sh_foe.get("hcav", 0.0)))
	return clampf(1.0 + v, 0.7, 1.55)

## Battle context: what the attackers crossed to get here.
static func context(s: Dictionary, pid: String, pa: Dictionary, assault: bool) -> Dictionary:
	var crossed := 0.0
	var passed := 0.0
	var width := 0
	var rname := ""
	var pname := ""
	var total := 0.0
	var bridged := false
	var turn := int(s["turn"])
	for aid in pa["armies"]:
		var a: Dictionary = s["armies"][aid]
		var sz := UnitUtil.army_size(a)
		total += sz
		if assault or int(a.get("arrived", -1)) != turn or str(a.get("prev_loc", "")) in ["", pid]:
			continue
		var from: String = a["prev_loc"]
		if GeoFeatures.river_between(from, pid):
			crossed += sz
			width = maxi(width, GeoFeatures.river_width(from, pid))
			rname = GeoFeatures.river_name(from, pid)
			bridged = bridged or int(s["provinces"][pid]["buildings"].get("bridge", 0)) > 0 or int(s["provinces"][from]["buildings"].get("bridge", 0)) > 0
		if GeoFeatures.pass_between(from, pid):
			passed += sz
			pname = GeoFeatures.pass_name(from, pid)
	return {"river_share": crossed / maxf(total, 0.001), "river_width": width, "river_name": rname, "bridged": bridged,
		"pass_share": passed / maxf(total, 0.001), "pass_name": pname, "assault": assault}

static func entry(key: String, kind: String, a: float, d: float, va: float = 0.0, vd: float = 0.0) -> Dictionary:
	return {"key": key, "kind": kind, "a": a, "d": d, "va": va, "vd": vd}

## Compute all factors. Returns {"list": Array, "pa": power mult, "pd": power mult, "cd": defender casualty mult,
## "ma": morale delta, "md": morale delta, "width_mult": float, "ctx": context}.
static func compute(s: Dictionary, pid: String, pa: Dictionary, pd: Dictionary, assault: bool, weather: Dictionary, fort: float, tdef: float, luck: Array) -> Dictionary:
	var ctx := context(s, pid, pa, assault)
	var terrain: String = Defs.provinces[pid]["terrain"]
	var list: Array = []
	var pow_a := 1.0
	var pow_d := 1.0
	var cas_d := 1.0
	var mor_a := 0.0
	var mor_d := 0.0
	# numbers / commanders / morale (information)
	list.append(entry("FACTOR_NUMBERS", "info", float(pa["n"]), float(pd["n"]), float(pa["n"]), float(pd["n"])))
	# commanders
	var tacdiff := clampf(float(pa["tac"]) - float(pd["tac"]), -9.0, 9.0)
	var g_a := 1.0 + 0.035 * tacdiff + Commanders.bonus(pa["gen"], "att") + Commanders.bonus(pa["gen"], "cav") * float(pa["cav_share"]) + Commanders.bonus(pa["gen"], "art") * float(pa["art_share"])
	var g_d := 1.0 - 0.035 * tacdiff + Commanders.bonus(pd["gen"], "def") + Commanders.bonus(pd["gen"], "cav") * float(pd["cav_share"]) + Commanders.bonus(pd["gen"], "art") * float(pd["art_share"])
	list.append(entry("FACTOR_GENERAL", "power", g_a, g_d, float(pa["tac"]), float(pd["tac"])))
	pow_a *= g_a
	pow_d *= g_d
	# terrain: protection for the defender, light mountain troops fight better in rough ground
	var mt_a := 1.0
	var mt_d := 1.0
	if terrain in ["mountains", "hills", "forest"]:
		mt_a += 0.12 * float(pa["mountain_share"])
		mt_d += 0.12 * float(pd["mountain_share"])
	list.append(entry("FACTOR_TERRAIN", "protect", mt_a, (1.0 - tdef) / mt_d, 0.0, tdef * 100.0))
	pow_a *= mt_a
	cas_d *= (1.0 - tdef) / mt_d
	# fortification (engineers blunt it)
	var fort_eff := fort * (1.0 - clampf(float(pa["eng_share"]) * 1.5, 0.0, 0.4))
	var fort_prot := 1.0 - clampf(fort_eff * 0.06, 0.0, 0.5)
	list.append(entry("FACTOR_FORT", "protect", 1.0, fort_prot, 0.0, fort_eff))
	cas_d *= fort_prot
	# river crossing
	var rs := float(ctx["river_share"])
	var rw := int(ctx["river_width"])
	var river_a := 1.0
	var river_prot := 1.0
	if rs > 0.0 and rw > 0:
		var pen := RIVER_PENALTY * float(rw) * rs
		pen *= maxf(0.0, 1.0 + float(pa["mods"].get("river_pen", 0.0)))
		pen *= 1.0 - Commanders.bonus(pa["gen"], "river")
		pen *= 1.0 - clampf(float(pa["bridging_share"]) * 2.0, 0.0, 0.6)
		if bool(ctx["bridged"]):
			pen *= 0.5
		river_a = 1.0 - clampf(pen, 0.0, 0.4)
		river_prot = 1.0 - clampf(0.03 * float(rw) * rs, 0.0, 0.1)
		mor_a -= 3.0 * float(rw) * rs
	list.append(entry("FACTOR_RIVER", "power", river_a, river_prot, float(rw) * rs, float(rw) * rs))
	pow_a *= river_a
	cas_d *= river_prot
	# mountain pass
	var ps := float(ctx["pass_share"])
	var pass_prot := 1.0 - PASS_PROTECT * ps
	list.append(entry("FACTOR_PASS", "protect", 1.0, pass_prot, 0.0, ps * 100.0))
	cas_d *= pass_prot
	mor_a -= 4.0 * ps
	# weather: attacker penalty in bad seasons, mud for horses and guns on both sides
	var mud := float(weather.get("mud", 0.0))
	var wa := float(weather["attack"]) * (1.0 - mud * (0.30 * float(pa["cav_share"]) + 0.35 * float(pa["art_share"])))
	var wd := 1.0 - mud * (0.30 * float(pd["cav_share"]) + 0.35 * float(pd["art_share"]))
	list.append(entry("FACTOR_WEATHER", "power", wa, wd, float(weather["season"]), mud))
	pow_a *= wa
	pow_d *= wd
	if float(weather["attrition"]) > 0.0:
		mor_a -= 2.0
		mor_d -= 1.0
	# discipline, experience
	var dis_a := clampf(0.85 + float(pa["disc"]) / 100.0 * 0.3 + float(pa["mods"].get("discipline", 0.0)), 0.7, 1.35)
	var dis_d := clampf(0.85 + float(pd["disc"]) / 100.0 * 0.3 + float(pd["mods"].get("discipline", 0.0)), 0.7, 1.35)
	list.append(entry("FACTOR_DISCIPLINE", "power", dis_a, dis_d, float(pa["disc"]), float(pd["disc"])))
	pow_a *= dis_a
	pow_d *= dis_d
	var xp_a := 1.0 + float(pa["xp"]) / 400.0
	var xp_d := 1.0 + float(pd["xp"]) / 400.0
	list.append(entry("FACTOR_EXPERIENCE", "power", xp_a, xp_d, float(pa["xp"]), float(pd["xp"])))
	pow_a *= xp_a
	pow_d *= xp_d
	# technology and doctrine are inside the base strength
	list.append(entry("FACTOR_TECH", "inc", float(pa["tech_mult"]), float(pd["tech_mult"])))
	list.append(entry("FACTOR_DOCTRINE", "inc", float(pa["doc_mult"]), float(pd["doc_mult"])))
	# supply
	var sup_a := clampf(float(pa["supply"]), 0.4, 1.0)
	var sup_d := clampf(float(pd["supply"]), 0.4, 1.0)
	list.append(entry("FACTOR_SUPPLY", "power", sup_a, sup_d, sup_a * 100.0, sup_d * 100.0))
	pow_a *= sup_a
	pow_d *= sup_d
	# unit composition: counters
	var sh_a: Dictionary = pa["class_share"]
	var sh_d: Dictionary = pd["class_share"]
	var cm_a := counter_mult(sh_a, sh_d, float(pa["mods"].get("anti_cav", 0.0)))
	var cm_d := counter_mult(sh_d, sh_a, float(pd["mods"].get("anti_cav", 0.0)))
	list.append(entry("FACTOR_COMPOSITION", "power", cm_a, cm_d))
	pow_a *= cm_a
	pow_d *= cm_d
	# amphibious landing
	var am := 0.8 if assault else 1.0
	list.append(entry("FACTOR_AMPHIB", "power", am, 1.0))
	pow_a *= am
	if assault:
		mor_a -= 8.0
	# morale (the dynamic value is applied each round)
	list.append(entry("FACTOR_MORALE", "info", 1.0, 1.0, float(pa["morale"]) + mor_a, float(pd["morale"]) + mor_d))
	# luck of the day (seeded)
	list.append(entry("FACTOR_LUCK", "power", float(luck[0]), float(luck[1])))
	pow_a *= float(luck[0])
	pow_d *= float(luck[1])
	return {"list": list, "pa": pow_a, "pd": pow_d, "cd": cas_d, "ma": mor_a, "md": mor_d, "ctx": ctx,
		"width_mult": 1.0 - 0.35 * ps}

## Pretty numeric contribution of a factor for a side in percent.
static func contribution_pct(f: Dictionary, side: String) -> float:
	match str(f["kind"]):
		"power", "inc":
			return (float(f[side]) - 1.0) * 100.0
		"protect":
			return (1.0 / maxf(float(f[side]), 0.01) - 1.0) * 100.0 if side == "d" else (float(f[side]) - 1.0) * 100.0
	return 0.0
