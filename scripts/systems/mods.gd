class_name Mods
extends RefCounted
## Aggregated modifiers. National modifiers come from government, technology, reforms, ruler,
## traditions, stability and temporary event effects. Province modifiers come from buildings.

## Building effects that also act nationally, with a soft cap on the summed value (diminishing returns).
const NATIONAL := {"general_skill": 2.0, "morale": 0.10, "legit": 0.5, "overextension": -0.20, "prestige": 0.8, "recruit_cost": -0.20,
	"religion_unity": 0.30, "naval_transport": 0.20, "credit": 0.5, "interest": -0.25, "spy_net": 0.5, "counter_intel": 0.5, "coup_guard": 0.5}

static func _add(into: Dictionary, src: Dictionary, mult: float = 1.0) -> void:
	for k in src:
		var v: Variant = src[k]
		if v is float or v is int:
			into[k] = float(into.get(k, 0.0)) + float(v) * mult

static func country(s: Dictionary, cid: String) -> Dictionary:
	var cache: Dictionary = s["_c"].get("mods", {})
	if int(s["_c"].get("mods_turn", -1)) != int(s["turn"]):
		cache = {}
		s["_c"]["mods"] = cache
		s["_c"]["mods_turn"] = s["turn"]
	if cache.has(cid):
		return cache[cid]
	var c: Dictionary = s["countries"].get(cid, {})
	var m := {}
	if c.is_empty():
		return m
	var gov: Dictionary = Defs.governments.get(c.get("gov", ""), {})
	_add(m, gov.get("mods", {}))
	for tid in c.get("researched", {}):
		var t: Dictionary = Defs.techs.get(tid, {})
		_add(m, t.get("effects", {}))
	for rid in c.get("reforms", []):
		var r: Dictionary = Defs.reforms.get(rid, {})
		_add(m, r.get("advantages", {}))
		_add(m, r.get("disadvantages", {}))
	_add(m, c.get("mods", {}))
	for tm in c.get("temp_mods", []):
		if int(tm.get("until", 0)) >= int(s["turn"]):
			_add(m, tm.get("mods", {}))
	_add_national_buildings(s, cid, m)
	# ruler (a regent governs for minors and incapacitated rulers)
	var ru: Dictionary = DynastySystem.effective_ruler(c)
	var adm := float(ru.get("adm", 5)) - 5.0
	var dip := float(ru.get("dip", 5)) - 5.0
	var mil := float(ru.get("mil", 5)) - 5.0
	var sk_w := 1.0
	if "ruler_skill_matters" in gov.get("features", []):
		sk_w = 1.6
	m["tax"] = float(m.get("tax", 0.0)) + adm * 0.01 * sk_w
	m["admin_cap"] = float(m.get("admin_cap", 0.0)) + adm * 0.015 * sk_w
	m["diplo"] = float(m.get("diplo", 0.0)) + dip * 0.03 * sk_w
	m["general_skill"] = float(m.get("general_skill", 0.0)) + mil * 0.25 * sk_w
	m["morale"] = float(m.get("morale", 0.0)) + mil * 0.01 * sk_w
	# stability effects
	var stab := float(c.get("stability", 50.0))
	if stab < 30.0:
		m["tax"] = float(m.get("tax", 0.0)) - (30.0 - stab) * 0.006
		m["prod"] = float(m.get("prod", 0.0)) - (30.0 - stab) * 0.004
		m["morale"] = float(m.get("morale", 0.0)) - (30.0 - stab) * 0.003
	elif stab > 70.0:
		m["tax"] = float(m.get("tax", 0.0)) + (stab - 70.0) * 0.002
		m["research"] = float(m.get("research", 0.0)) + (stab - 70.0) * 0.002
	# inflation hurts purchasing power
	m["cost_inflation"] = float(c.get("inflation", 0.0))
	# overlord relation: vassals pay tribute handled in economy
	cache[cid] = m
	return m

static func _add_national_buildings(s: Dictionary, cid: String, m: Dictionary) -> void:
	var sums := {}
	for pid in GS.owned(s, cid):
		var p: Dictionary = s["provinces"][pid]
		if p["controller"] != cid:
			continue
		for bid in p["buildings"]:
			var eff: Dictionary = Defs.buildings.get(bid, {}).get("effects", {})
			for k in NATIONAL:
				if eff.has(k):
					sums[k] = float(sums.get(k, 0.0)) + float(eff[k]) * float(p["buildings"][bid])
	for k in sums:
		var cap: float = NATIONAL[k]
		var v: float = float(sums[k])
		m[k] = float(m.get(k, 0.0)) + cap * (1.0 - exp(-v / cap))

## Total national granary capacity from buildings (food storage).
static func granary_total(s: Dictionary, cid: String) -> float:
	var t := 0.0
	for pid in GS.owned(s, cid):
		var lv := int(s["provinces"][pid]["buildings"].get("granary", 0))
		if lv > 0:
			t += float(Defs.buildings["granary"]["effects"]["granary"]) * float(lv)
	return t

static func get_mod(s: Dictionary, cid: String, key: String) -> float:
	return float(country(s, cid).get(key, 0.0))

static func invalidate(s: Dictionary) -> void:
	GS.invalidate_mods(s)

## --- province-local building modifiers -----------------------------------------------------
static func province(s: Dictionary, pid: String) -> Dictionary:
	var p: Dictionary = s["provinces"][pid]
	var m := {}
	for bid in p.get("buildings", {}):
		var lv := int(p["buildings"][bid])
		var b: Dictionary = Defs.buildings.get(bid, {})
		_add(m, b.get("effects", {}), float(lv))
	# dev gives a small base
	m["infra"] = float(m.get("infra", 0.0)) + float(p.get("dev", 1.0)) * 0.15
	return m

static func building_slots(p: Dictionary) -> int:
	return 2 + int(floor(float(p.get("dev", 1.0))))

static func used_slots(p: Dictionary) -> int:
	var n := (p.get("buildings", {}) as Dictionary).size()
	for q in p.get("queue", []):
		if int(q.get("level", 1)) == 1:
			n += 1
	return n

## Effective fortification level of a province (0..~8).
static func fort_level(s: Dictionary, pid: String) -> float:
	var p: Dictionary = s["provinces"][pid]
	var lv := float(int(p.get("buildings", {}).get("fort", 0)))
	var owner: String = p.get("owner", "")
	lv += get_mod(s, owner, "fort_def") * 4.0
	var t: String = Defs.provinces[pid]["terrain"]
	lv += float(Const.TERRAIN_DEF.get(t, 0.0)) * 4.0
	if Defs.provinces[pid].get("archipelago", false):
		lv += 0.5
	return lv
