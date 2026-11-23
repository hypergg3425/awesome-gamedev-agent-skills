class_name PopulationSystem
extends RefCounted
## Population growth, hunger, migration, urbanisation, literacy, class structure and local unrest.
## Population drives manpower, taxes, production, recruitment, stability and development.

const BASE_GROWTH := 0.0045      # per turn (season) at zero pressure
const MIGRATION_RATE := 0.006

static func pop_cap(s: Dictionary, pid: String) -> float:
	var p: Dictionary = s["provinces"][pid]
	if not p.has("cap"):
		p["cap"] = float(p["pop"]) * 1.9
	var owner: String = p["owner"]
	var m: Dictionary = Mods.country(s, owner) if owner != "" else {}
	var pm := Mods.province(s, pid)
	var cap := float(p["cap"]) * (1.0 + float(m.get("food", 0.0)) * 0.8 + float(pm.get("pop_cap", 0.0)) + float(p["dev"]) * 0.02)
	return cap

## Target unrest of a province and the breakdown (for the UI).
static func unrest_target(s: Dictionary, pid: String) -> Dictionary:
	var p: Dictionary = s["provinces"][pid]
	var owner: String = p["owner"]
	var c: Dictionary = s["countries"].get(owner, {})
	var parts := {}
	if c.is_empty():
		return {"total": 0.0, "parts": parts}
	var m := Mods.country(s, owner)
	var pm := Mods.province(s, pid)
	parts["UNREST_TAX"] = (float(c["tax_rate"]) - 0.25) * 150.0
	parts["UNREST_STABILITY"] = (50.0 - float(c["stability"])) * 0.35
	var over := float(EconomySystem.admin_capacity(s, owner)["overextension"])
	parts["UNREST_OVEREXT"] = over * 30.0
	if p["culture"] != c["culture"]:
		parts["UNREST_CULTURE"] = 8.0
	if p["religion"] != c["religion"]:
		parts["UNREST_RELIGION"] = 6.0 * (1.0 + float(m.get("unrest_minority", 0.0)) * 5.0)
	var conq := int(s["turn"]) - int(p.get("conquered_turn", -999))
	if conq < 24:
		parts["UNREST_CONQUEST"] = 10.0 * (1.0 - float(conq) / 24.0)
	var hunger := (1.0 - float(c.get("food_ratio", 1.0))) * 60.0
	if hunger > 0.0:
		parts["UNREST_HUNGER"] = hunger
	parts["UNREST_WAR"] = float(c.get("war_exhaustion", 0.0)) * 0.3
	var cs := 0.0
	var wsum := 0.0
	for cls in Const.CLASSES:
		var pw := float(p["classes"].get(cls, 0.0)) * _class_weight(cls)
		cs += pw * (50.0 - float(c["classes"][cls]["sat"]))
		wsum += pw
	parts["UNREST_CLASSES"] = cs / maxf(wsum, 0.001) * 0.45
	parts["UNREST_BUILDINGS"] = -float(pm.get("stability_local", 0.0)) * 2.0
	var garrison := 0.0
	for aid in GS.armies_at(s, pid):
		var a: Dictionary = s["armies"][aid]
		if a["owner"] == owner and not a.get("naval", false):
			garrison += UnitUtil.army_size(a)
	parts["UNREST_GARRISON"] = -minf(garrison * 1.6, 8.0)
	parts["UNREST_GOV"] = float(m.get("unrest", 0.0)) * 100.0
	if p["controller"] != owner:
		parts["UNREST_OCCUPIED"] = 15.0
	var total := 0.0
	for k in parts:
		total += float(parts[k])
	return {"total": clampf(total, 0.0, 100.0), "parts": parts}

static func _class_weight(cls: String) -> float:
	return {"nobility": 8.0, "clergy": 5.0, "merchants": 5.0, "military": 4.0, "artisans": 2.0, "peasants": 0.7}.get(cls, 1.0)

static func process_turn(s: Dictionary) -> void:
	var rng := GS.rng_of(s)
	# first pass: growth, hunger, disease, classes, unrest
	for pid in Defs.province_ids:
		var p: Dictionary = s["provinces"][pid]
		var owner: String = p["owner"]
		if owner == "" :
			continue
		var c: Dictionary = s["countries"].get(owner, {})
		if c.is_empty() or not c.get("alive", false):
			continue
		var m := Mods.country(s, owner)
		var pm := Mods.province(s, pid)
		var pop := float(p["pop"])
		var cap := pop_cap(s, pid)
		var happy := clampf(1.1 - float(p["unrest"]) / 120.0, 0.4, 1.1)
		var growth := BASE_GROWTH * (1.0 + float(m.get("pop_growth", 0.0)) + float(pm.get("pop_growth", 0.0))) * happy
		growth *= clampf(1.0 - pop / cap, -0.6, 1.0)
		if growth < 0.0:
			growth *= 0.6
		# hunger
		var fr := float(c.get("food_ratio", 1.0))
		if fr < 1.0:
			growth -= (1.0 - fr) * 0.05
			p["disease"] = minf(100.0, float(p["disease"]) + (1.0 - fr) * 8.0)
		# disease
		var resist := clampf(float(pm.get("disease_resist", 0.0)) - float(m.get("disease", 0.0)), 0.0, 0.9)
		var d := float(p["disease"])
		var chance := 0.0035 * (0.4 + float(p["urban"]) * 4.0) * (1.0 - resist)
		if d < 1.0 and rng.chance(chance):
			p["disease"] = 12.0 + rng.randf() * 18.0
			if owner == s["player"]:
				GS.note(s, owner, "disaster", "NOTE_OUTBREAK", {}, pid)
		if d > 0.5:
			growth -= d / 100.0 * 0.12 * (1.0 - resist)
			p["disease"] = maxf(0.0, d * (0.82 - resist * 0.2) - 0.5)
		# war damage recovery
		p["devastation"] = maxf(0.0, float(p["devastation"]) * 0.88 - 0.005)
		if p["controller"] != owner:
			growth -= 0.004
		pop = maxf(5.0, pop * (1.0 + growth))
		p["pop"] = pop
		# urbanisation & literacy
		var dev := float(p["dev"])
		var urb_cap := 0.1 + 0.04 * dev
		p["urban"] = minf(urb_cap, float(p["urban"]) + 0.0006 * (0.5 + float(pm.get("trade_power", 0.0))))
		var lit_gain := 0.0004 * (1.0 + float(m.get("literacy", 0.0)) * 20.0 + float(pm.get("literacy", 0.0)) * 15.0)
		p["literacy"] = minf(0.95, float(p["literacy"]) + lit_gain)
		# natural development drift
		if float(c["stability"]) > 55.0 and pop > cap * 0.75 and float(p["devastation"]) < 0.05 and float(p["unrest"]) < 30.0:
			p["dev"] = minf(10.0, dev + 0.006)
		# class structure follows development and buildings
		var u := float(p["urban"])
		var cl: Dictionary = p["classes"]
		cl["merchants"] = 0.008 + u * 0.15 + float(pm.get("merchant_share", 0.0))
		cl["artisans"] = 0.02 + u * 0.35 + float(pm.get("artisan_share", 0.0))
		cl["clergy"] = 0.015 + 0.004 * dev + float(pm.get("clergy_share", 0.0))
		cl["nobility"] = 0.02 + (0.01 if "vassals" in Defs.governments.get(c["gov"], {}).get("features", []) else 0.0)
		cl["military"] = 0.01
		var rest := 1.0 - float(cl["merchants"]) - float(cl["artisans"]) - float(cl["clergy"]) - float(cl["nobility"]) - float(cl["military"])
		cl["peasants"] = maxf(0.2, rest)
		# unrest moves towards target
		if (int(Defs.province_index[pid]) + int(s["turn"])) % 2 == 0:
			var ut := unrest_target(s, pid)
			p["unrest"] = clampf(lerpf(float(p["unrest"]), float(ut["total"]), 0.4), 0.0, 100.0)
			p["stab"] = clampf(100.0 - float(p["unrest"]), 0.0, 100.0)
	# second pass: migration between provinces of the same owner
	_migrate(s)

static func _attract(s: Dictionary, pid: String) -> float:
	var p: Dictionary = s["provinces"][pid]
	var cap := pop_cap(s, pid)
	return (100.0 - float(p["unrest"])) / 100.0 * 0.5 + float(p["dev"]) * 0.04 - float(p["pop"]) / cap * 0.6 - float(p["devastation"]) * 0.8

static func _migrate(s: Dictionary) -> void:
	var moves: Array = []
	var att := {}
	for pid in Defs.province_ids:
		att[pid] = _attract(s, pid)
	for pid in Defs.province_ids:
		var p: Dictionary = s["provinces"][pid]
		var owner: String = p["owner"]
		if owner == "" or p["controller"] != owner:
			continue
		var best := ""
		var ba: float = float(att[pid]) + 0.18
		for nb in Defs.neighbors(pid):
			var q: Dictionary = s["provinces"][nb]
			if q["owner"] == owner and q["controller"] == owner:
				var a: float = float(att[nb])
				if a > ba:
					ba = a
					best = nb
		if best != "":
			moves.append([pid, best, float(p["pop"]) * MIGRATION_RATE * minf(1.0, (ba - float(att[pid]) - 0.18) * 3.0 + 0.4)])
	for mv in moves:
		var src: Dictionary = s["provinces"][mv[0]]
		var dst: Dictionary = s["provinces"][mv[1]]
		var amt := minf(float(mv[2]), float(src["pop"]) * 0.03)
		if float(src["pop"]) - amt < 10.0:
			continue
		src["pop"] = float(src["pop"]) - amt
		dst["pop"] = float(dst["pop"]) + amt
