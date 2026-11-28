class_name ConstructionSystem
extends RefCounted
## Buildings and province development. Costs use gold plus stockpiled materials; shortages block
## construction unless the player explicitly buys the missing materials at 150% of market price.

static func level_of(p: Dictionary, bid: String) -> int:
	return int(p["buildings"].get(bid, 0))

static func queued_level(p: Dictionary, bid: String) -> int:
	for q in p["queue"]:
		if q["bid"] == bid:
			return int(q["level"])
	return 0

static func cost_of(s: Dictionary, cid: String, bid: String, level: int) -> Dictionary:
	var b: Dictionary = Defs.buildings[bid]
	var m := Mods.country(s, cid)
	var mult := (1.0 + 0.8 * float(level - 1)) * clampf(1.0 + float(m.get("build_cost", 0.0)), 0.4, 2.0) * (1.0 + float(m.get("cost_inflation", 0.0)))
	var out := {}
	for k in b["cost"]:
		out[k] = snappedf(float(b["cost"][k]) * mult, 0.1)
	return out

static func time_of(s: Dictionary, cid: String, bid: String, level: int) -> int:
	var b: Dictionary = Defs.buildings[bid]
	var m := Mods.country(s, cid)
	var t := float(b["time"]) * (1.0 + 0.5 * float(level - 1)) / clampf(1.0 + float(m.get("build_speed", 0.0)), 0.5, 3.0)
	return maxi(1, int(ceil(t)))

static func max_queue(s: Dictionary, cid: String) -> int:
	return 1 + (1 if TechSystem.level(s["countries"][cid], "engineering") >= 2 else 0)

## Returns {ok, reason, params, cost, level, time, shortage}
static func can_build(s: Dictionary, cid: String, pid: String, bid: String) -> Dictionary:
	var c: Dictionary = s["countries"][cid]
	var p: Dictionary = s["provinces"].get(pid, {})
	var b: Dictionary = Defs.buildings.get(bid, {})
	if p.is_empty() or b.is_empty():
		return {"ok": false, "reason": "ERR_INVALID"}
	if p["owner"] != cid or p["controller"] != cid:
		return {"ok": false, "reason": "ERR_NOT_YOURS"}
	if p.get("siege") != null:
		return {"ok": false, "reason": "BUILD_ERR_SIEGE"}
	var cur := level_of(p, bid)
	var qd := queued_level(p, bid)
	if qd > 0:
		return {"ok": false, "reason": "BUILD_ERR_QUEUED"}
	var lvl := cur + 1
	if lvl > int(b["max_level"]):
		return {"ok": false, "reason": "BUILD_ERR_MAX"}
	if (p["queue"] as Array).size() >= max_queue(s, cid):
		return {"ok": false, "reason": "BUILD_ERR_QUEUE_FULL"}
	var req: Dictionary = b["requires"]
	if req.has("tech") and TechSystem.level(c, req["tech"][0]) < int(req["tech"][1]):
		return {"ok": false, "reason": "BUILD_ERR_TECH", "params": {"tech": "%s %d" % [Loc.tx(Defs.tech_lines[req["tech"][0]]["name"]), int(req["tech"][1])]}}
	if req.has("year") and int(GS.date_of(s)["year"]) < int(req["year"]):
		return {"ok": false, "reason": "BUILD_ERR_ERA", "params": {"year": int(req["year"])}}
	if req.has("terrain") and Defs.provinces[pid]["terrain"] not in req["terrain"]:
		return {"ok": false, "reason": "BUILD_ERR_TERRAIN"}
	if req.get("coastal", false) and not Defs.provinces[pid]["coastal"]:
		return {"ok": false, "reason": "BUILD_ERR_COASTAL"}
	if req.has("building") and level_of(p, req["building"][0]) < int(req["building"][1]):
		return {"ok": false, "reason": "BUILD_ERR_BUILDING", "params": {"b": Defs.building_name(req["building"][0])}}
	if req.has("min_dev") and float(p["dev"]) < float(req["min_dev"]):
		return {"ok": false, "reason": "BUILD_ERR_DEV", "params": {"dev": req["min_dev"]}}
	if cur == 0 and Mods.used_slots(p) >= Mods.building_slots(p):
		return {"ok": false, "reason": "BUILD_ERR_SLOTS"}
	if c["gov"] == "tribal_confederation" and bid in ["university", "trading_center", "admin_center", "railway", "canal", "bridge", "cultural_institution", "arsenal", "military_academy"]:
		return {"ok": false, "reason": "BUILD_ERR_GOV"}
	var cost := cost_of(s, cid, bid, lvl)
	var shortage := {}
	if float(c["gold"]) < float(cost.get("gold", 0.0)):
		return {"ok": false, "reason": "ERR_NO_GOLD", "params": {"need": int(cost["gold"])}, "cost": cost, "level": lvl, "time": time_of(s, cid, bid, lvl)}
	for k in cost:
		if k == "gold":
			continue
		var have := float(c["stock"].get(k, 0.0))
		if have < float(cost[k]):
			shortage[k] = float(cost[k]) - have
	return {"ok": true, "reason": "", "cost": cost, "level": lvl, "time": time_of(s, cid, bid, lvl), "shortage": shortage}

static func buy_cost(s: Dictionary, shortage: Dictionary) -> float:
	var g := 0.0
	for k in shortage:
		g += float(shortage[k]) * float(s["market"].get(k, {}).get("price", 3.0)) * 1.5
	return g

static func start_build(s: Dictionary, cid: String, pid: String, bid: String, allow_buy: bool = false) -> Dictionary:
	var chk := can_build(s, cid, pid, bid)
	if not chk["ok"]:
		return chk
	var c: Dictionary = s["countries"][cid]
	var cost: Dictionary = chk["cost"]
	var shortage: Dictionary = chk["shortage"]
	var extra := 0.0
	if not shortage.is_empty():
		if not allow_buy:
			return {"ok": false, "reason": "BUILD_ERR_MATERIALS", "params": {"what": _short_text(shortage), "gold": int(buy_cost(s, shortage))}, "shortage": shortage}
		extra = buy_cost(s, shortage)
		if float(c["gold"]) < float(cost["gold"]) + extra:
			return {"ok": false, "reason": "ERR_NO_GOLD", "params": {"need": int(float(cost["gold"]) + extra)}}
	c["gold"] = float(c["gold"]) - float(cost["gold"]) - extra
	for k in cost:
		if k == "gold":
			continue
		var use := minf(float(c["stock"].get(k, 0.0)), float(cost[k]))
		c["stock"][k] = float(c["stock"].get(k, 0.0)) - use
		TradeSystem.record_use(s, k, float(cost[k]))
	var t := int(chk["time"])
	s["provinces"][pid]["queue"].append({"bid": bid, "level": int(chk["level"]), "left": t, "total": t})
	return {"ok": true, "level": chk["level"], "time": t}

static func _short_text(shortage: Dictionary) -> String:
	var parts: Array = []
	for k in shortage:
		parts.append("%s %d" % [Loc.t("RES_" + k.to_upper()), int(ceil(float(shortage[k])))])
	return ", ".join(parts)

static func cancel_build(s: Dictionary, cid: String, pid: String, index: int) -> bool:
	var p: Dictionary = s["provinces"][pid]
	if p["owner"] != cid or index < 0 or index >= (p["queue"] as Array).size():
		return false
	var q: Dictionary = p["queue"][index]
	var cost := cost_of(s, cid, q["bid"], int(q["level"]))
	s["countries"][cid]["gold"] = float(s["countries"][cid]["gold"]) + float(cost.get("gold", 0.0)) * 0.5
	(p["queue"] as Array).remove_at(index)
	return true

static func demolish(s: Dictionary, cid: String, pid: String, bid: String) -> bool:
	var p: Dictionary = s["provinces"][pid]
	if p["owner"] != cid or not p["buildings"].has(bid):
		return false
	var lv := int(p["buildings"][bid]) - 1
	if lv <= 0:
		p["buildings"].erase(bid)
	else:
		p["buildings"][bid] = lv
	return true

static func process_turn(s: Dictionary, cid: String) -> void:
	for pid in GS.owned(s, cid):
		var p: Dictionary = s["provinces"][pid]
		if (p["queue"] as Array).is_empty():
			continue
		if p["controller"] != cid or p.get("siege") != null:
			continue   # work halts while occupied / besieged
		var done: Array = []
		for q in p["queue"]:
			q["left"] = int(q["left"]) - 1
			if int(q["left"]) <= 0:
				done.append(q)
		for q in done:
			p["buildings"][q["bid"]] = int(q["level"])
			(p["queue"] as Array).erase(q)
			GS.note(s, cid, "construction", "NOTE_BUILT", {"b": q["bid"], "lv": q["level"]}, pid)
			GS.stat_add(s, cid, "buildings_built", 1.0)

## --- province development ------------------------------------------------------------------
static func develop_cost(s: Dictionary, cid: String, pid: String) -> Dictionary:
	var p: Dictionary = s["provinces"][pid]
	var m := Mods.country(s, cid)
	var d := float(p["dev"])
	return {"gold": snappedf(40.0 * (1.0 + d * 0.9) * clampf(1.0 + float(m.get("build_cost", 0.0)), 0.4, 2.0), 0.1), "admin": 8.0 + d * 1.5}

static func develop_cap(s: Dictionary, cid: String) -> float:
	return 4.0 + float(TechSystem.level(s["countries"][cid], "bureaucracy")) * 1.2 + float(TechSystem.level(s["countries"][cid], "engineering")) * 0.6

static func can_develop(s: Dictionary, cid: String, pid: String) -> Dictionary:
	var p: Dictionary = s["provinces"][pid]
	if p["owner"] != cid or p["controller"] != cid:
		return {"ok": false, "reason": "ERR_NOT_YOURS"}
	var cost := develop_cost(s, cid, pid)
	if float(p["dev"]) >= develop_cap(s, cid) or float(p["dev"]) >= 10.0:
		return {"ok": false, "reason": "DEV_ERR_CAP"}
	if float(s["countries"][cid]["gold"]) < float(cost["gold"]):
		return {"ok": false, "reason": "ERR_NO_GOLD", "params": {"need": int(cost["gold"])}}
	if float(s["countries"][cid]["admin"]) < float(cost["admin"]):
		return {"ok": false, "reason": "ERR_NO_ADMIN", "params": {"need": int(cost["admin"])}}
	return {"ok": true, "cost": cost}

static func develop(s: Dictionary, cid: String, pid: String) -> Dictionary:
	var chk := can_develop(s, cid, pid)
	if not chk["ok"]:
		return chk
	var c: Dictionary = s["countries"][cid]
	c["gold"] = float(c["gold"]) - float(chk["cost"]["gold"])
	c["admin"] = float(c["admin"]) - float(chk["cost"]["admin"])
	var p: Dictionary = s["provinces"][pid]
	p["dev"] = snappedf(float(p["dev"]) + 0.5, 0.01)
	GS.stat_add(s, cid, "developments", 1.0)
	return {"ok": true}
