class_name Commanders
extends RefCounted
## Generals and admirals: skills, traits, experience, promotion, death and capture, replacement.
## A commander is a plain Dictionary stored in army["general"]:
## {"name", "tac", "log", "siege", "xp", "traits": [ids], "level", "naval": bool, "battles", "age"}.
## Armies created from scenario data may carry older dictionaries without the newer keys; every accessor
## therefore uses defaults.

## Trait effects. att/def = fractional battle-power change when attacking/defending; tac/log/siege = skill points;
## morale = army morale multiplier; terrain = tac bonus on a terrain; river = share of the river-crossing penalty removed;
## death = additive risk of dying in a lost battle; xp = experience gain multiplier; weather/raid/gunnery/blockade/convoy are naval.
const TRAITS := {
	"aggressive": {"att": 0.05, "def": -0.04, "death": 0.02},
	"steadfast": {"def": 0.06},
	"cautious": {"log": 2, "att": -0.03, "death": -0.02},
	"siege_master": {"siege": 3},
	"logistician": {"log": 2},
	"inspiring": {"morale": 0.06},
	"cavalry_master": {"cav": 0.07},
	"artillerist": {"art": 0.07},
	"mountain_fighter": {"terrain": {"mountains": 2, "hills": 2, "forest": 1}},
	"bridge_builder": {"river": 0.5, "siege": 1},
	"reckless": {"tac": 1, "death": 0.06},
	"veteran": {"xp": 1.5},
	"brilliant": {"tac": 2},
	"incompetent": {"tac": -2, "log": -1},
	"sea_dog": {"weather": 0.5, "log": 1},
	"gunnery_expert": {"gunnery": 0.08},
	"boarding_master": {"boarding": 0.08},
	"raider": {"raid": 0.25},
	"blockader": {"blockade": 0.25},
	"convoy_master": {"convoy": 0.25},
}
const LAND_TRAITS: Array[String] = ["aggressive", "steadfast", "cautious", "siege_master", "logistician", "inspiring", "cavalry_master",
	"artillerist", "mountain_fighter", "bridge_builder", "reckless", "veteran", "brilliant", "incompetent"]
const NAVAL_TRAITS: Array[String] = ["sea_dog", "gunnery_expert", "boarding_master", "raider", "blockader", "convoy_master", "aggressive",
	"cautious", "inspiring", "brilliant", "incompetent", "veteran"]
const MAX_TRAITS := 3
const LEVEL_XP := [30.0, 45.0, 65.0, 90.0, 120.0, 160.0]

static func make(s: Dictionary, cid: String, mil: int, naval: bool = false) -> Dictionary:
	var rng := GS.rng_of(s)
	var m := Mods.country(s, cid)
	var bonus := clampi(int(round(float(m.get("general_skill", 0.0)))), -2, 3)
	var g := {"name": PoliticsSystem.random_name(s, cid, rng) + " " + str(rng.pick(PoliticsSystem.SURN)),
		"tac": clampi(int(rng.gauss(float(mil), 1.5)) + bonus, 1, 9), "log": clampi(int(rng.gauss(float(mil), 1.5)), 1, 9),
		"siege": clampi(int(rng.gauss(float(mil) - 0.5, 1.6)), 1, 9), "xp": 0.0, "traits": [], "level": 1, "naval": naval,
		"battles": 0, "age": 28 + rng.randi_range(0, 22)}
	var pool: Array[String] = NAVAL_TRAITS if naval else LAND_TRAITS
	var n := 0
	var r := rng.randf()
	if r < 0.55:
		n = 1
	if r < 0.15:
		n = 2
	for i in n:
		var t: String = str(rng.pick(pool))
		if t not in g["traits"] and not _conflicts(g["traits"], t):
			(g["traits"] as Array).append(t)
	return g

static func _conflicts(have: Array, t: String) -> bool:
	for pair in [["brilliant", "incompetent"], ["aggressive", "cautious"], ["aggressive", "steadfast"], ["reckless", "cautious"]]:
		if (t == pair[0] and pair[1] in have) or (t == pair[1] and pair[0] in have):
			return true
	return false

static func traits_of(g: Variant) -> Array:
	if g == null:
		return []
	return (g as Dictionary).get("traits", [])

## Sum of a numeric trait effect over the commander's traits.
static func bonus(g: Variant, key: String) -> float:
	var v := 0.0
	for t in traits_of(g):
		v += float(TRAITS.get(t, {}).get(key, 0.0))
	return v

## Effective tactical skill on a given terrain.
static func eff_tac(g: Variant, terrain: String) -> float:
	if g == null:
		return 0.0
	var v := float((g as Dictionary).get("tac", 0)) + bonus(g, "tac")
	for t in traits_of(g):
		v += float(TRAITS.get(t, {}).get("terrain", {}).get(terrain, 0.0))
	return clampf(v, 0.0, 12.0)

static func eff_log(g: Variant) -> float:
	return 0.0 if g == null else clampf(float((g as Dictionary).get("log", 0)) + bonus(g, "log"), 0.0, 12.0)

static func eff_siege(g: Variant) -> float:
	return 0.0 if g == null else clampf(float((g as Dictionary).get("siege", 0)) + bonus(g, "siege"), 0.0, 12.0)

static func trait_names(g: Variant) -> String:
	var out: Array = []
	for t in traits_of(g):
		out.append(Loc.t("TRAIT_" + str(t).to_upper()))
	return ", ".join(out)

## Add experience; returns true on promotion. Promotion raises a skill by one (tactics for battle xp,
## logistics for supply xp, siege for siege xp) and sometimes grants a trait.
static func gain_xp(s: Dictionary, g: Variant, amount: float, skill: String = "tac") -> bool:
	if g == null:
		return false
	var gd: Dictionary = g
	gd["xp"] = float(gd.get("xp", 0.0)) + amount * (1.0 + bonus(g, "xp") * 0.5 if bonus(g, "xp") > 0.0 else 1.0)
	var lvl := int(gd.get("level", 1))
	if lvl > LEVEL_XP.size():
		return false
	if float(gd["xp"]) < float(LEVEL_XP[lvl - 1]):
		return false
	gd["xp"] = 0.0
	gd["level"] = lvl + 1
	if int(gd.get(skill, 0)) < 9:
		gd[skill] = int(gd.get(skill, 0)) + 1
	var rng := GS.rng_of(s)
	var tr: Array = gd.get("traits", [])
	if tr.size() < MAX_TRAITS and rng.chance(0.35):
		var pool: Array[String] = NAVAL_TRAITS if bool(gd.get("naval", false)) else LAND_TRAITS
		var t: String = str(rng.pick(pool))
		if t not in tr and t != "incompetent" and not _conflicts(tr, t):
			tr.append(t)
			gd["traits"] = tr
	return true

## Death or capture of commanders after a battle. Returns event dictionaries for the report.
static func after_battle(s: Dictionary, winners: Array, losers: Array, rout: bool, rep: Dictionary) -> Array:
	var rng := GS.rng_of(s)
	var events: Array = []
	for side in [losers, winners]:
		var is_loser: bool = side == losers
		for aid in side:
			if not s["armies"].has(aid):
				continue
			var a: Dictionary = s["armies"][aid]
			var g: Variant = a.get("general")
			if g == null:
				continue
			var gd: Dictionary = g
			gd["battles"] = int(gd.get("battles", 0)) + 1
			var risk := 0.012 + bonus(g, "death") * 0.5
			var cap := 0.0
			if is_loser:
				risk = 0.04 + (0.08 if rout else 0.0) + bonus(g, "death")
				cap = 0.05 + (0.10 if rout else 0.0)
			risk = clampf(risk, 0.0, 0.5)
			var roll := rng.randf()
			if roll < risk:
				events.append({"kind": "died", "name": str(gd.get("name", "")), "owner": a["owner"], "aid": aid, "naval": bool(a.get("naval", false))})
				a["general"] = null
				a["general_wait"] = int(s["turn"]) + 2
			elif is_loser and roll < risk + cap:
				events.append({"kind": "captured", "name": str(gd.get("name", "")), "owner": a["owner"], "aid": aid, "naval": bool(a.get("naval", false))})
				_ransom(s, a, gd, winners)
				a["general"] = null
				a["general_wait"] = int(s["turn"]) + 3
			elif not is_loser:
				if gain_xp(s, g, 5.0 + float(rep.get("loss_d" if rep.get("winner") == "attacker" else "loss_a", 0.0)) * 0.5, "tac"):
					events.append({"kind": "promoted", "name": str(gd.get("name", "")), "owner": a["owner"], "aid": aid, "naval": bool(a.get("naval", false))})
	return events

static func _ransom(s: Dictionary, loser_army: Dictionary, g: Dictionary, winners: Array) -> void:
	var lo: String = loser_army["owner"]
	var capt := ""
	for wid in winners:
		if s["armies"].has(wid):
			capt = s["armies"][wid]["owner"]
			break
	if capt == "" or capt == "REB" or lo == "REB" or not s["countries"].has(capt) or not s["countries"].has(lo):
		return
	var price := minf(6.0 * float(int(g.get("tac", 1)) + int(g.get("log", 1)) + int(g.get("siege", 1))), maxf(0.0, float(s["countries"][lo]["gold"])) * 0.2)
	s["countries"][lo]["gold"] = float(s["countries"][lo]["gold"]) - price
	s["countries"][capt]["gold"] = float(s["countries"][capt]["gold"]) + price
	s["countries"][capt]["prestige"] = float(s["countries"][capt]["prestige"]) + 2.0
	GS.stat_add(s, capt, "commanders_captured", 1.0)

## Replace missing commanders for armies/fleets of a country that sit on friendly ground (or in a port).
static func assign_missing(s: Dictionary, cid: String) -> void:
	var c: Dictionary = s["countries"][cid]
	var mil := int(c["ruler"]["mil"])
	var budget := 1
	for aid in GS.armies_of(s, cid):
		if budget <= 0:
			break
		var a: Dictionary = s["armies"][aid]
		if a.get("general") != null or a["loc"] == "" or int(a.get("general_wait", -1)) > int(s["turn"]):
			continue
		var naval := bool(a.get("naval", false))
		var need := 2.0 if naval else 5.0
		if UnitUtil.army_size(a) < need or float(c["gold"]) < 25.0:
			continue
		if not MilitarySystem.is_friendly_ground(s, cid, a["loc"]):
			continue
		c["gold"] = float(c["gold"]) - 15.0
		a["general"] = make(s, cid, mil, naval)
		budget -= 1
