class_name UnitUtil
extends RefCounted
## Unit availability and army statistics helpers.

static func is_available(s: Dictionary, cid: String, uid: String) -> bool:
	var u: Dictionary = Defs.units.get(uid, {})
	if u.is_empty():
		return false
	var c: Dictionary = s["countries"][cid]
	var t: Variant = u.get("tech")
	if t is Array and (t as Array).size() == 2:
		if TechSystem.level(c, t[0]) < int(t[1]):
			return false
	var cults: Array = u.get("cultures", [])
	var ctrs: Array = u.get("countries", [])
	if not ctrs.is_empty():
		return uid in c.get("special_units", [])
	if not cults.is_empty():
		return str(c.get("culture", "")) in cults or uid in c.get("special_units", [])
	return true

static func available_units(s: Dictionary, cid: String) -> Array:
	var out: Array = []
	for uid in Defs.units:
		if is_available(s, cid, uid):
			out.append(uid)
	out.sort()
	return out

static func power(uid: String) -> float:
	var u: Dictionary = Defs.units[uid]
	return float(u["fire"]) + float(u["shock"]) + float(u["defense"]) + float(u["morale"]) * 0.5

## best available unit in a class by power per gold
static func best_of(s: Dictionary, cid: String, cls: String) -> String:
	var best := ""
	var bp := -1.0
	for uid in Defs.units:
		var u: Dictionary = Defs.units[uid]
		if u["cls"] != cls or not is_available(s, cid, uid):
			continue
		var pw := power(uid)
		# regional specials are preferred when available (they are stronger)
		if pw > bp:
			bp = pw
			best = uid
	return best

static func army_size(a: Dictionary) -> float:
	var n := 0.0
	for uid in a["units"]:
		n += float(a["units"][uid])
	return n

static func army_upkeep(s: Dictionary, a: Dictionary) -> float:
	var up := 0.0
	for uid in a["units"]:
		up += float(Defs.units[uid]["upkeep"]) * float(a["units"][uid])
	return up

static func army_strength_points(a: Dictionary) -> float:
	var v := 0.0
	for uid in a["units"]:
		v += power(uid) * float(a["units"][uid])
	return v

static func has_naval(a: Dictionary) -> bool:
	for uid in a["units"]:
		if Defs.units[uid]["naval"]:
			return true
	return false

static func is_naval_army(a: Dictionary) -> bool:
	return bool(a.get("naval", false))

static func transport_capacity(a: Dictionary) -> float:
	var cap := 0.0
	for uid in a["units"]:
		cap += float(Defs.units[uid]["transport"]) * float(a["units"][uid])
	return cap

static func country_military_strength(s: Dictionary, cid: String) -> float:
	var v := 0.0
	for aid in s["armies"]:
		var a: Dictionary = s["armies"][aid]
		if a["owner"] == cid:
			v += army_strength_points(a)
	return v

static func country_regiments(s: Dictionary, cid: String, naval: bool = false) -> float:
	var n := 0.0
	for aid in s["armies"]:
		var a: Dictionary = s["armies"][aid]
		if a["owner"] == cid and bool(a.get("naval", false)) == naval:
			n += army_size(a)
	return n
