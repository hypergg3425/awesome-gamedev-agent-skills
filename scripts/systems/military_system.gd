class_name MilitarySystem
extends RefCounted
## Armies: recruitment, orders, pathfinding, movement, battles, retreats, sieges, supply, attrition.
## Regiments are 1000 men; ships are squadrons. Rebels are the pseudo-country "REB".

const SEA_KM_PER_TURN := 380.0

## --- creation ---------------------------------------------------------------------------------
static func create_army(s: Dictionary, cid: String, loc: String, units: Dictionary, general: Variant = null) -> String:
	var aid := "A%d" % int(s["next_army_id"])
	s["next_army_id"] = int(s["next_army_id"]) + 1
	var naval := true
	for uid in units:
		if not bool(Defs.units[uid]["naval"]):
			naval = false
	if general is Dictionary and not (general as Dictionary).has("xp"):
		general = (general as Dictionary).duplicate()
		general["xp"] = 0.0  # scenario-authored generals carry no xp field
	var a := {"id": aid, "owner": cid, "loc": loc, "units": units.duplicate(), "target": units.duplicate(), "general": general,
		"morale": 80.0, "xp": 0.0, "path": [], "transit": null, "naval": naval, "prev_loc": loc, "arrived": -1, "supply": 1.0,
		"name": "", "last_battle": -99, "discipline": 30.0 if cid == "REB" else 50.0, "mission": "patrol", "at_sea": 0}
	if general == null and cid != "REB" and UnitUtil.army_size(a) >= (3.0 if naval else 6.0):
		a["general"] = Commanders.make(s, cid, int(s["countries"][cid]["ruler"]["mil"]), naval)
	s["armies"][aid] = a
	GS.move_army_cache(s, aid, "", loc)
	return aid

static func make_general(s: Dictionary, cid: String, mil: int) -> Dictionary:
	return Commanders.make(s, cid, mil, false)

static func disband_army(s: Dictionary, aid: String, refund_manpower: bool = false) -> void:
	var a: Dictionary = s["armies"].get(aid, {})
	if a.is_empty():
		return
	if refund_manpower and not a.get("naval", false) and a["owner"] in s["countries"]:
		var c: Dictionary = s["countries"][a["owner"]]
		c["manpower"] = minf(float(c["manpower_max"]), float(c["manpower"]) + UnitUtil.army_size(a) * 0.3)
	if a["loc"] != "":
		GS.move_army_cache(s, aid, a["loc"], "")
	s["armies"].erase(aid)

static func spawn_rebels(s: Dictionary, pid: String, size: float) -> String:
	var aid := create_army(s, "REB", pid, {"spearmen": size}, null)
	s["armies"][aid]["morale"] = 70.0
	s["armies"][aid]["name"] = "rebels"
	s["armies"][aid]["born"] = s["turn"]
	return aid

## --- recruitment --------------------------------------------------------------------------------
static func recruit_cost(s: Dictionary, cid: String, uid: String) -> Dictionary:
	var u: Dictionary = Defs.units[uid]
	var m := Mods.country(s, cid)
	var mult := clampf(1.0 + float(m.get("recruit_cost", 0.0)), 0.4, 2.0) * (1.0 + float(m.get("cost_inflation", 0.0)))
	var out := {}
	for k in u["cost"]:
		out[k] = snappedf(float(u["cost"][k]) * (mult if k != "manpower" else 1.0), 0.1)
	return out

static func can_recruit(s: Dictionary, cid: String, pid: String, uid: String) -> Dictionary:
	var c: Dictionary = s["countries"][cid]
	var p: Dictionary = s["provinces"].get(pid, {})
	var u: Dictionary = Defs.units.get(uid, {})
	if p.is_empty() or u.is_empty():
		return {"ok": false, "reason": "ERR_INVALID"}
	if p["owner"] != cid or p["controller"] != cid:
		return {"ok": false, "reason": "ERR_NOT_YOURS"}
	if p.get("siege") != null:
		return {"ok": false, "reason": "BUILD_ERR_SIEGE"}
	if not UnitUtil.is_available(s, cid, uid):
		return {"ok": false, "reason": "RECRUIT_ERR_TECH"}
	if u["naval"] and (not Defs.provinces[pid]["coastal"] or int(p["buildings"].get("port", 0)) < 1):
		return {"ok": false, "reason": "RECRUIT_ERR_PORT"}
	var queued := 0
	for q in c["recruit_queue"]:
		if q["pid"] == pid:
			queued += 1
	var pm := Mods.province(s, pid)
	var limit := 1 + int(pm.get("recruit_speed", 0.0) * 10.0 / 1.0) / 1 + (1 if float(p["dev"]) >= 4.0 else 0)
	limit = clampi(limit, 1, 5)
	if queued >= limit:
		return {"ok": false, "reason": "RECRUIT_ERR_LIMIT"}
	var cost := recruit_cost(s, cid, uid)
	if float(c["manpower"]) < float(cost.get("manpower", 0.0)):
		return {"ok": false, "reason": "RECRUIT_ERR_MANPOWER"}
	if float(c["gold"]) < float(cost.get("gold", 0.0)):
		return {"ok": false, "reason": "ERR_NO_GOLD", "params": {"need": int(cost["gold"])}}
	for k in cost:
		if k in ["gold", "manpower"]:
			continue
		if float(c["stock"].get(k, 0.0)) < float(cost[k]):
			return {"ok": false, "reason": "RECRUIT_ERR_MATERIAL", "params": {"what": Loc.t("RES_" + k.to_upper())}}
	return {"ok": true, "cost": cost}

static func recruit(s: Dictionary, cid: String, pid: String, uid: String) -> Dictionary:
	var chk := can_recruit(s, cid, pid, uid)
	if not chk["ok"]:
		return chk
	var c: Dictionary = s["countries"][cid]
	var cost: Dictionary = chk["cost"]
	c["gold"] = float(c["gold"]) - float(cost["gold"])
	c["manpower"] = float(c["manpower"]) - float(cost.get("manpower", 0.0))
	for k in cost:
		if k in ["gold", "manpower"]:
			continue
		c["stock"][k] = float(c["stock"][k]) - float(cost[k])
		TradeSystem.record_use(s, k, float(cost[k]))
	var u: Dictionary = Defs.units[uid]
	var t := 1
	if u["cls"] in ["artillery", "heavy_cavalry", "engineer"]:
		t = 2
	if u["naval"]:
		t = 3
	var pm := Mods.province(s, pid)
	t = maxi(1, t - (1 if float(pm.get("recruit_speed", 0.0)) >= 0.2 else 0))
	if "mercenaries" in Defs.governments.get(c["gov"], {}).get("features", []) or "mercenary_contracts" in c["reforms"]:
		t = 1
	c["recruit_queue"].append({"uid": uid, "pid": pid, "left": t})
	return {"ok": true, "turns": t}

static func process_recruit_queue(s: Dictionary, cid: String) -> void:
	var c: Dictionary = s["countries"][cid]
	var keep: Array = []
	for q in c["recruit_queue"]:
		q["left"] = int(q["left"]) - 1
		if int(q["left"]) > 0:
			keep.append(q)
			continue
		var pid: String = q["pid"]
		if s["provinces"][pid]["controller"] != cid:
			c["manpower"] = float(c["manpower"]) + 0.8   # province lost: men return
			continue
		var naval := bool(Defs.units[q["uid"]]["naval"])
		var target := ""
		for aid in GS.armies_at(s, pid):
			var a: Dictionary = s["armies"][aid]
			if a["owner"] == cid and bool(a.get("naval", false)) == naval and a["path"].is_empty() and a["transit"] == null:
				target = aid
				break
		if target != "":
			var a: Dictionary = s["armies"][target]
			a["units"][q["uid"]] = float(a["units"].get(q["uid"], 0.0)) + 1.0
			a["target"][q["uid"]] = float(a["target"].get(q["uid"], 0.0)) + 1.0
			var tot := maxf(UnitUtil.army_size(a), 1.0)
			a["morale"] = (float(a["morale"]) * (tot - 1.0) + 80.0) / tot
			_dilute(a, 1.0, tot)
		else:
			create_army(s, cid, pid, {q["uid"]: 1.0}, null)
		GS.stat_add(s, cid, "regiments_raised", 1.0)
	c["recruit_queue"] = keep

## --- merge / split ---------------------------------------------------------------------------------
static func merge_armies(s: Dictionary, a_id: String, b_id: String) -> bool:
	var a: Dictionary = s["armies"].get(a_id, {})
	var b: Dictionary = s["armies"].get(b_id, {})
	if a.is_empty() or b.is_empty() or a_id == b_id or a["owner"] != b["owner"] or a["loc"] != b["loc"] or a["loc"] == "":
		return false
	if bool(a.get("naval", false)) != bool(b.get("naval", false)):
		return false
	var na := UnitUtil.army_size(a)
	var nb := UnitUtil.army_size(b)
	for uid in b["units"]:
		a["units"][uid] = float(a["units"].get(uid, 0.0)) + float(b["units"][uid])
	for uid in b["target"]:
		a["target"][uid] = float(a["target"].get(uid, 0.0)) + float(b["target"][uid])
	a["morale"] = (float(a["morale"]) * na + float(b["morale"]) * nb) / maxf(na + nb, 1.0)
	a["xp"] = (float(a["xp"]) * na + float(b["xp"]) * nb) / maxf(na + nb, 1.0)
	a["discipline"] = (float(a.get("discipline", 50.0)) * na + float(b.get("discipline", 50.0)) * nb) / maxf(na + nb, 1.0)
	if a["general"] == null or (b["general"] != null and float(b["general"]["tac"]) > float(a["general"]["tac"])):
		a["general"] = b["general"]
	disband_army(s, b_id)
	return true

static func split_army(s: Dictionary, aid: String, units: Dictionary) -> String:
	var a: Dictionary = s["armies"].get(aid, {})
	if a.is_empty() or a["loc"] == "":
		return ""
	var take := {}
	var tgt := {}
	for uid in units:
		var have := float(a["units"].get(uid, 0.0))
		var n := minf(float(units[uid]), have)
		if n >= 1.0 and have - n >= 0.0:
			n = floorf(n)
			take[uid] = n
	if take.is_empty():
		return ""
	var left := 0.0
	for uid in a["units"]:
		left += float(a["units"][uid]) - float(take.get(uid, 0.0))
	if left < 0.5:
		return ""   # cannot take everything
	for uid in take:
		a["units"][uid] = float(a["units"][uid]) - float(take[uid])
		a["target"][uid] = maxf(0.0, float(a["target"].get(uid, 0.0)) - float(take[uid]))
		tgt[uid] = take[uid]
		if float(a["units"][uid]) <= 0.001:
			a["units"].erase(uid)
	var nid := create_army(s, a["owner"], a["loc"], take, null)
	s["armies"][nid]["morale"] = a["morale"]
	s["armies"][nid]["xp"] = a["xp"]
	s["armies"][nid]["discipline"] = a.get("discipline", 50.0)
	return nid

## --- passability & pathfinding --------------------------------------------------------------------
static func link_between(a: String, b: String) -> Array:
	if b in Defs.neighbors(a):
		return ["land", 0]
	for sl in Defs.sea_links(a):
		if sl[0] == b:
			return [sl[1], int(sl[2])]
	return ["", 0]

static func can_enter(s: Dictionary, owner: String, pid: String) -> bool:
	var p: Dictionary = s["provinces"][pid]
	var o: String = p["owner"]
	var c: String = p["controller"]
	if o == owner or c == owner:
		return true
	if GS.at_war(s, owner, o) or GS.at_war(s, owner, c):
		return true
	if o == "" or o == "REB":
		return true
	for x in [o, c]:
		if x == "" or x == owner:
			continue
		if GS.allied(s, owner, x):
			return true
		var r := GS.rel(s, owner, x)
		if r["access"].get(owner, false) and r["access"].get(x, false) or (r["access"].get(x, false) and x == o and r["access"].get(owner, false)):
			return true
		# vassal / overlord
		if GS.overlord_of(s, owner) == x or GS.overlord_of(s, x) == owner:
			return true
		# military access: x grants owner (stored as access[owner]=true meaning owner may enter x)
		if r["access"].get(owner, false) and r["access"].get(x, false) == false and bool(r.get("access_grant", {}).get(owner, false)):
			return true
	return false

const PASS_LIMIT := 8.0   ## regiments that can file through a mountain pass without delay or losses

static func move_cost(s: Dictionary, a: Dictionary, pid: String, link: String, from: String = "") -> float:
	var t: String = Defs.provinces[pid]["terrain"]
	var cost := float(Const.TERRAIN_MOVE.get(t, 1.0))
	var infra := float(Mods.province(s, pid).get("infra", 0.0)) + float(Mods.province(s, pid).get("move_bonus", 0.0)) * 4.0
	cost /= (1.0 + clampf(infra * 0.1, 0.0, 0.6))
	if link == "strait":
		cost += 1.0
	if from != "" and link == "land":
		cost += river_cost(s, a, from, pid) + pass_cost(a, from, pid, cost)
	return cost

## Extra movement points to ford or bridge a river (bridges, pontoon engineers and river doctrines reduce it).
static func river_cost(s: Dictionary, a: Dictionary, from: String, to: String) -> float:
	if not GeoFeatures.river_between(from, to):
		return 0.0
	var c := 0.5 * float(GeoFeatures.river_width(from, to))
	if int(s["provinces"][to]["buildings"].get("bridge", 0)) > 0 or int(s["provinces"][from]["buildings"].get("bridge", 0)) > 0:
		c *= 0.3
	var bridging := 0.0
	var n := maxf(UnitUtil.army_size(a), 0.001)
	for uid in a["units"]:
		if UnitUtil.has_tag(uid, "bridging"):
			bridging += float(a["units"][uid])
	c *= 1.0 - clampf(bridging / n * 2.0, 0.0, 0.6)
	c *= maxf(0.2, 1.0 + Mods.get_mod(s, a["owner"], "river_pen"))
	return c

## Passes are bottlenecks: big armies take longer to file through.
static func pass_cost(a: Dictionary, from: String, to: String, base: float) -> float:
	if not GeoFeatures.pass_between(from, to):
		return 0.0
	var over := maxf(0.0, UnitUtil.army_size(a) - PASS_LIMIT) / PASS_LIMIT
	return 0.5 + base * minf(over, 1.5)

static func move_points(s: Dictionary, a: Dictionary) -> float:
	var mp := 99.0
	for uid in a["units"]:
		if float(a["units"][uid]) > 0.0:
			mp = minf(mp, float(Defs.units[uid]["move"]))
	if mp > 90.0:
		mp = 2.0
	var m := Mods.country(s, a["owner"])
	mp *= 1.0 + float(m.get("move", 0.0))
	if a.get("naval", false):
		return mp
	# weather slows land armies
	if a["loc"] != "":
		mp *= float(Combat.weather_for(s, a["loc"])["move"])
	return mp

## Dijkstra pathfinding. Land armies may take one sea hop (embark) at the start of the path.
static func find_path(s: Dictionary, aid: String, target: String) -> Dictionary:
	var a: Dictionary = s["armies"].get(aid, {})
	if a.is_empty() or a["loc"] == "":
		return {"ok": false, "reason": "MOVE_ERR_TRANSIT"}
	var start: String = a["loc"]
	if start == target:
		return {"ok": true, "path": [], "cost": 0.0}
	if not Defs.provinces.has(target):
		return {"ok": false, "reason": "ERR_INVALID"}
	var naval: bool = bool(a.get("naval", false))
	var owner: String = a["owner"]
	if not naval and not can_enter(s, owner, target):
		return {"ok": false, "reason": "MOVE_ERR_NO_ACCESS"}
	var can_embark := false
	if not naval:
		can_embark = _find_escort(s, a) != ""
	var heap := TradeSystem.MinHeap.new()
	var dist := {start: 0.0}
	var prev := {}
	var embarked := {start: false}
	heap.push(0.0, 0)
	var names: Array = [start]
	var idxmap := {start: 0}
	while not heap.is_empty():
		var top := heap.pop()
		var du: float = top[0]
		var u: String = names[top[1]]
		if du > float(dist.get(u, 1e18)) + 0.0001:
			continue
		if u == target:
			break
		var edges: Array = []
		if naval:
			for sl in Defs.sea_links(u):
				edges.append([sl[0], sl[1], int(sl[2])])
		else:
			for nb in Defs.neighbors(u):
				edges.append([nb, "land", 0])
			for sl in Defs.sea_links(u):
				if sl[1] == "strait":
					edges.append([sl[0], "strait", int(sl[2])])
				elif sl[1] == "lane" and can_embark and u == start:
					edges.append([sl[0], "lane", int(sl[2])])
		for e in edges:
			var v: String = e[0]
			if naval:
				if not Defs.provinces[v]["coastal"]:
					continue
			else:
				if not can_enter(s, owner, v):
					continue
			var c := 0.0
			if e[1] == "lane":
				c = maxf(1.0, ceil(float(e[2]) / SEA_KM_PER_TURN)) * 1.5
			elif naval:
				c = maxf(1.0, ceil(float(e[2]) / SEA_KM_PER_TURN))
			else:
				c = move_cost(s, a, v, e[1], u)
			var nd := du + c
			if nd < float(dist.get(v, 1e18)):
				dist[v] = nd
				prev[v] = u
				if not idxmap.has(v):
					idxmap[v] = names.size()
					names.append(v)
				heap.push(nd, idxmap[v])
	if not dist.has(target):
		return {"ok": false, "reason": "MOVE_ERR_NO_PATH"}
	var path: Array = []
	var cur := target
	while cur != start:
		path.push_front(cur)
		cur = prev[cur]
	return {"ok": true, "path": path, "cost": dist[target]}

static func _find_escort(s: Dictionary, a: Dictionary) -> String:
	var need := UnitUtil.army_size(a)
	var cap_total := 0.0
	var best := ""
	for aid in GS.armies_at(s, a["loc"]):
		var f: Dictionary = s["armies"][aid]
		if f["owner"] == a["owner"] and f.get("naval", false) and f["transit"] == null:
			var cap := UnitUtil.transport_capacity(f) * (1.0 + Mods.get_mod(s, a["owner"], "naval_transport"))
			if cap >= need:
				if best == "" or cap > UnitUtil.transport_capacity(s["armies"][best]):
					best = aid
	return best

static func order_move(s: Dictionary, aid: String, target: String) -> Dictionary:
	var a: Dictionary = s["armies"].get(aid, {})
	if a.is_empty():
		return {"ok": false, "reason": "ERR_INVALID"}
	if a["transit"] != null:
		return {"ok": false, "reason": "MOVE_ERR_TRANSIT"}
	var r := find_path(s, aid, target)
	if not r["ok"]:
		return r
	a["path"] = r["path"]
	return r

static func cancel_orders(s: Dictionary, aid: String) -> void:
	if s["armies"].has(aid):
		s["armies"][aid]["path"] = []

## --- turn processing ---------------------------------------------------------------------------------
static func hostile_present(s: Dictionary, owner: String, pid: String) -> bool:
	for aid in GS.armies_at(s, pid):
		var o: String = s["armies"][aid]["owner"]
		if o != owner and GS.at_war(s, owner, o):
			return true
	return false

static func move_all(s: Dictionary) -> void:
	var ids: Array = s["armies"].keys()
	ids.sort()
	for aid in ids:
		if not s["armies"].has(aid):
			continue
		var a: Dictionary = s["armies"][aid]
		if a["transit"] != null:
			a["transit"]["left"] = int(a["transit"]["left"]) - 1
			if int(a["transit"]["left"]) <= 0:
				_arrive(s, aid)
			continue
		if (a["path"] as Array).is_empty():
			continue
		var mp := move_points(s, a)
		var first := true
		while not (a["path"] as Array).is_empty():
			var nxt: String = a["path"][0]
			var lk: Array = link_between(a["loc"], nxt)
			var link: String = lk[0]
			if link == "":
				a["path"] = []
				break
			if not bool(a.get("naval", false)) and not can_enter(s, a["owner"], nxt):
				a["path"] = []
				if a["owner"] == s["player"]:
					GS.note(s, a["owner"], "military", "NOTE_MOVE_BLOCKED", {"province": nxt}, nxt)
				break
			if link == "lane" or (bool(a.get("naval", false))):
				var km := int(lk[1])
				var turns := maxi(1, int(ceil(float(km) / (SEA_KM_PER_TURN * maxf(1.0, mp / 3.0)))))
				if not bool(a.get("naval", false)):
					var esc := _find_escort(s, a)
					if esc == "":
						a["path"] = []
						break
					var landing := NavalSystem.landing_check(s, a, esc, nxt)
					if not bool(landing["ok"]):
						a["path"] = []
						if a["owner"] == s["player"]:
							GS.note(s, a["owner"], "military", "NOTE_LANDING_REFUSED", {"province": nxt}, nxt)
						break
					_begin_transit(s, esc, nxt, turns)
					_begin_transit(s, aid, nxt, turns)
					s["armies"][aid]["escort"] = esc
					a["path"].pop_front()
					break
				if link == "strait" or link == "lane":
					if not first and mp < 1.0:
						break
					_begin_transit(s, aid, nxt, turns)
					a["path"].pop_front()
					break
			var cost := move_cost(s, a, nxt, link, a["loc"])
			if not first and mp < cost * 0.75:
				break
			mp = maxf(0.0, mp - cost)
			first = false
			var came_from: String = a["loc"]
			_set_loc(s, aid, nxt)
			_cross_effects(s, a, came_from, nxt)
			a["path"].pop_front()
			a["arrived"] = s["turn"]
			if hostile_present(s, a["owner"], nxt) or (s["provinces"][nxt]["controller"] != a["owner"] and GS.at_war(s, a["owner"], s["provinces"][nxt]["controller"])):
				break

## Losses and fatigue of crossing a mountain pass with an oversized army, and of fording a river without a bridge.
static func _cross_effects(s: Dictionary, a: Dictionary, from: String, to: String) -> void:
	if GeoFeatures.pass_between(from, to):
		var over := maxf(0.0, UnitUtil.army_size(a) - PASS_LIMIT) / PASS_LIMIT
		if over > 0.0:
			_attrit(a, clampf(0.02 * over, 0.0, 0.08))
	if GeoFeatures.river_between(from, to) and river_cost(s, a, from, to) > 0.0 and not bool(a.get("naval", false)):
		a["morale"] = maxf(10.0, float(a["morale"]) - 1.5 * float(GeoFeatures.river_width(from, to)))

static func _set_loc(s: Dictionary, aid: String, to: String) -> void:
	var a: Dictionary = s["armies"][aid]
	var from: String = a["loc"]
	a["prev_loc"] = from
	a["loc"] = to
	GS.move_army_cache(s, aid, from, to)

static func _begin_transit(s: Dictionary, aid: String, to: String, turns: int) -> void:
	var a: Dictionary = s["armies"][aid]
	a["prev_loc"] = a["loc"]
	GS.move_army_cache(s, aid, a["loc"], "")
	a["transit"] = {"to": to, "left": turns, "from": a["loc"]}
	a["loc"] = ""

static func _arrive(s: Dictionary, aid: String) -> void:
	var a: Dictionary = s["armies"][aid]
	var to: String = a["transit"]["to"]
	a["loc"] = to
	GS.move_army_cache(s, aid, "", to)
	a["transit"] = null
	a["arrived"] = s["turn"]
	if not a.get("naval", false):
		a["morale"] = maxf(10.0, float(a["morale"]) - 8.0)
		a["discipline"] = maxf(10.0, float(a.get("discipline", 50.0)) - 4.0)
		a["amphibious"] = s["turn"]

## Resolve all battles in provinces where hostile armies meet.
static func resolve_battles(s: Dictionary) -> Array:
	var reports: Array = []
	var provs: Array = []
	for pid in s["_c"]["armies_at"]:
		if pid != "" and (s["_c"]["armies_at"][pid] as Array).size() >= 2:
			provs.append(pid)
	provs.sort()
	for pid in provs:
		for naval in [true, false]:
			var rep := _battle_in(s, pid, naval)
			if not rep.is_empty():
				reports.append(rep)
	return reports

static func _battle_in(s: Dictionary, pid: String, naval: bool) -> Dictionary:
	var here: Array = []
	for aid in GS.armies_at(s, pid):
		var a: Dictionary = s["armies"].get(aid, {})
		if not a.is_empty() and bool(a.get("naval", false)) == naval:
			here.append(aid)
	if here.size() < 2:
		return {}
	here.sort()
	# aggressor: an army that arrived this turn that is at war with someone present
	var agg := ""
	for aid in here:
		var a: Dictionary = s["armies"][aid]
		for bid in here:
			if bid != aid and GS.at_war(s, a["owner"], s["armies"][bid]["owner"]):
				if int(a.get("arrived", -1)) == int(s["turn"]) or a["owner"] == "REB":
					agg = aid
					break
		if agg != "":
			break
	if agg == "":
		# nobody moved: if two hostile stacks share a province anyway, the lower id attacks
		for aid in here:
			for bid in here:
				if bid != aid and GS.at_war(s, s["armies"][aid]["owner"], s["armies"][bid]["owner"]):
					agg = aid
					break
			if agg != "":
				break
	if agg == "":
		return {}
	var ao: String = s["armies"][agg]["owner"]
	var side_a: Array = []
	var side_d: Array = []
	for aid in here:
		var o: String = s["armies"][aid]["owner"]
		if o == ao or (o != "REB" and ao != "REB" and _same_side(s, ao, o)):
			side_a.append(aid)
		elif GS.at_war(s, ao, o) or o == "REB" or ao == "REB":
			side_d.append(aid)
	if side_d.is_empty():
		return {}
	var sea_assault := false
	for aid in side_a:
		if int(s["armies"][aid].get("amphibious", -9)) == int(s["turn"]):
			sea_assault = true
	var rep := Combat.resolve(s, pid, side_a, side_d, sea_assault)
	if rep.is_empty():
		return {}
	_apply_battle(s, rep)
	return rep

static func _same_side(s: Dictionary, a: String, b: String) -> bool:
	if a == b:
		return true
	if GS.allied(s, a, b):
		return true
	for wid in s["wars"]:
		var w: Dictionary = s["wars"][wid]
		if w.get("ended", false):
			continue
		if (a in w["attackers"] and b in w["attackers"]) or (a in w["defenders"] and b in w["defenders"]):
			return true
	return false

static func _apply_battle(s: Dictionary, rep: Dictionary) -> void:
	var rng := GS.rng_of(s)
	var side_a: Array = rep["side_a_ids"]
	var side_d: Array = rep["side_d_ids"]
	var att_wins: bool = rep["winner"] == "attacker"
	var la := float(rep["loss_a"])
	var ld := float(rep["loss_d"])
	Combat.apply_losses(s, side_a, la, rng)
	Combat.apply_losses(s, side_d, ld, rng)
	var winners: Array = side_a if att_wins else side_d
	var losers: Array = side_d if att_wins else side_a
	var pid: String = rep["pid"]
	rep["events"] = Commanders.after_battle(s, winners, losers, bool(rep.get("rout", false)), rep)
	# stats and experience
	var owners_a: Array = rep["attackers"]["owners"]
	var owners_d: Array = rep["defenders"]["owners"]
	for o in owners_a:
		if s["countries"].has(o):
			GS.stat_add(s, o, "battles", 1.0)
			GS.stat_add(s, o, "casualties_taken", la * 1000.0 / maxf(1.0, owners_a.size()))
			GS.stat_add(s, o, "casualties_inflicted", ld * 1000.0 / maxf(1.0, owners_a.size()))
			GS.stat_add(s, o, "battles_won" if att_wins else "battles_lost", 1.0)
	for o in owners_d:
		if s["countries"].has(o):
			GS.stat_add(s, o, "battles", 1.0)
			GS.stat_add(s, o, "casualties_taken", ld * 1000.0 / maxf(1.0, owners_d.size()))
			GS.stat_add(s, o, "casualties_inflicted", la * 1000.0 / maxf(1.0, owners_d.size()))
			GS.stat_add(s, o, "battles_won" if not att_wins else "battles_lost", 1.0)
	for aid in winners:
		if s["armies"].has(aid):
			var a: Dictionary = s["armies"][aid]
			var xp_gain := 3.0 * (1.0 + Mods.get_mod(s, a["owner"], "xp_gain"))
			a["xp"] = minf(100.0, float(a["xp"]) + xp_gain)
			a["morale"] = clampf(float(a["morale"]) - 6.0, 25.0, 95.0)
			a["discipline"] = minf(100.0, float(a.get("discipline", 50.0)) + 2.0)
			a["last_battle"] = s["turn"]
	for aid in losers:
		if s["armies"].has(aid):
			var a: Dictionary = s["armies"][aid]
			a["morale"] = maxf(5.0, float(a["morale"]) - 25.0)
			a["discipline"] = maxf(10.0, float(a.get("discipline", 50.0)) - 8.0)
			a["xp"] = minf(100.0, float(a["xp"]) + 1.0)   # the beaten learn a little too
			a["last_battle"] = s["turn"]
			a["path"] = []
	# winner prestige, war score
	var wowner: String = (owners_a if att_wins else owners_d)[0]
	var lowner: String = (owners_d if att_wins else owners_a)[0]
	if s["countries"].has(wowner) and wowner != "REB":
		s["countries"][wowner]["prestige"] = float(s["countries"][wowner]["prestige"]) + minf(25.0, (la if not att_wins else ld) * 1.2 + 2.0)
	if s["countries"].has(lowner) and lowner != "REB":
		s["countries"][lowner]["prestige"] = float(s["countries"][lowner]["prestige"]) - 1.5
	DiplomacySystem.on_battle(s, wowner, lowner, float(rep["loss_d"] if att_wins else rep["loss_a"]))
	# retreat of losers
	for aid in losers.duplicate():
		if s["armies"].has(aid):
			_retreat(s, aid, pid)
	# remove empty armies
	for aid in side_a + side_d:
		if s["armies"].has(aid) and UnitUtil.army_size(s["armies"][aid]) < 0.2:
			disband_army(s, aid)
	# devastation
	s["provinces"][pid]["devastation"] = minf(0.6, float(s["provinces"][pid]["devastation"]) + 0.04 + (la + ld) * 0.004)
	# logs
	var compact := {"turn": s["turn"], "pid": pid, "winner": rep["winner"], "att": owners_a, "def": owners_d, "la": snappedf(la, 0.1), "ld": snappedf(ld, 0.1), "reasons": rep["reasons"], "naval": bool(rep.get("naval", false))}
	(s["battle_log"] as Array).append(compact)
	if (s["battle_log"] as Array).size() > 80:
		(s["battle_log"] as Array).pop_front()
	var lb: Array = s["_c"].get("battles_turn", [])
	lb.append(rep)
	s["_c"]["battles_turn"] = lb
	for o in owners_a + owners_d:
		if o == s["player"] or o in s["players"]:
			GS.note(s, o, "battle", "NOTE_BATTLE", {"province": pid, "won": (o in (owners_a if att_wins else owners_d))}, pid)

static func _retreat(s: Dictionary, aid: String, pid: String) -> void:
	var a: Dictionary = s["armies"][aid]
	var owner: String = a["owner"]
	var naval := bool(a.get("naval", false))
	if owner == "REB":
		disband_army(s, aid)   # rebels are dispersed
		return
	var best := ""
	var bs := -1e9
	var cands: Array = []
	if naval:
		for sl in Defs.sea_links(pid):
			cands.append(sl[0])
	else:
		cands = Defs.neighbors(pid).duplicate()
	var size := UnitUtil.army_size(a)
	for nb in cands:
		var q: Dictionary = s["provinces"][nb]
		if naval and not Defs.provinces[nb]["coastal"]:
			continue
		if not can_enter(s, owner, nb):
			continue
		if hostile_present(s, owner, nb):
			continue
		var sc := 0.0
		if q["controller"] == owner:
			sc += 10.0
		elif q["owner"] == owner:
			sc += 6.0
		elif GS.allied(s, owner, q["controller"]):
			sc += 5.0
		if nb == a.get("prev_loc", ""):
			sc += 4.0
		if GS.at_war(s, owner, q["controller"]):
			sc -= 12.0
		if naval and q["controller"] == owner and int(q["buildings"].get("port", 0)) > 0:
			sc += 8.0   # fleets limp to their own ports
		if not naval:
			# a river or a pass behind the retreating army slows the withdrawal
			if GeoFeatures.river_between(pid, nb) and river_cost(s, a, pid, nb) > 0.0:
				sc -= 3.0
			if GeoFeatures.pass_between(pid, nb) and size > PASS_LIMIT:
				sc -= 2.0
		sc += float(q["pop"]) * 0.0005
		if sc > bs:
			bs = sc
			best = nb
	if best == "":
		disband_army(s, aid)
		if owner == s["player"]:
			GS.note(s, owner, "military", "NOTE_ARMY_DESTROYED", {"province": pid}, pid)
		return
	if not naval:
		# stragglers lost while crossing a river with the enemy behind
		if GeoFeatures.river_between(pid, best):
			_attrit(a, clampf(0.03 * river_cost(s, a, pid, best) * 2.0, 0.0, 0.1))
		if GeoFeatures.pass_between(pid, best) and size > PASS_LIMIT:
			_attrit(a, 0.03)
	_set_loc(s, aid, best)
	a["path"] = []
	a["retreated"] = s["turn"]

## --- sieges ---------------------------------------------------------------------------------------------------
static func siege_points(s: Dictionary, armies: Array) -> float:
	var pts := 0.0
	for aid in armies:
		var a: Dictionary = s["armies"][aid]
		var m := Mods.country(s, a["owner"])
		var gsk := Commanders.eff_siege(a["general"])
		var p := 0.0
		for uid in a["units"]:
			var u: Dictionary = Defs.units[uid]
			var cnt := float(a["units"][uid])
			p += cnt * (float(u["siege"]) + (0.4 if u["cls"] in ["infantry", "heavy_infantry"] else 0.1))
		pts += p * (1.0 + float(m.get("siege", 0.0)) + gsk * 0.04)
	return pts

static func process_sieges(s: Dictionary) -> void:
	var provs: Array = []
	for pid in s["provinces"]:
		provs.append(pid)
	provs.sort()
	for pid in provs:
		var p: Dictionary = s["provinces"][pid]
		var ctrl: String = p["controller"]
		var owner: String = p["owner"]
		# hostile land armies in this province
		var besiegers: Array = []
		var defenders := false
		for aid in GS.armies_at(s, pid):
			var a: Dictionary = s["armies"][aid]
			if a.get("naval", false):
				continue
			var o: String = a["owner"]
			if o == ctrl or (_same_side(s, o, ctrl) and o != "REB" and ctrl != "REB"):
				defenders = true
			elif GS.at_war(s, o, ctrl) or (o != ctrl and GS.at_war(s, o, owner) and o != owner) or (o == "REB" and ctrl != "REB") or (ctrl == "REB" and o == owner):
				besiegers.append(aid)
		if besiegers.is_empty() or defenders:
			if p.get("siege") != null:
				var sg: Dictionary = p["siege"]
				sg["progress"] = float(sg["progress"]) * 0.5
				if float(sg["progress"]) < 0.05:
					p["siege"] = null
			continue
		var bowner: String = s["armies"][besiegers[0]]["owner"]
		if p.get("siege") == null or p["siege"]["by"] != bowner:
			p["siege"] = {"by": bowner, "progress": 0.0, "turns": 0}
		var pts := siege_points(s, besiegers)
		var fl := Mods.fort_level(s, pid)
		var needed := 1.2 + fl * 2.2 + float(p["pop"]) / 500.0
		needed *= 1.0 + Mods.get_mod(s, ctrl, "siege_def")
		var nav := NavalSystem.siege_support(s, pid, bowner)
		pts += float(nav["bombard"])
		needed *= 1.0 - 0.35 * float(nav["blockade"])
		if bowner == "REB":
			needed = 2.0
		var sg: Dictionary = p["siege"]
		sg["blockade"] = nav["blockade"]
		sg["turns"] = int(sg["turns"]) + 1
		sg["progress"] = float(sg["progress"]) + pts / needed
		sg["pts"] = pts
		if float(sg["progress"]) >= 1.0:
			_occupy(s, pid, bowner, besiegers)
			p["siege"] = null

static func _occupy(s: Dictionary, pid: String, by: String, armies: Array) -> void:
	var p: Dictionary = s["provinces"][pid]
	var old_ctrl: String = p["controller"]
	p["controller"] = by
	p["occupied_turn"] = s["turn"]
	p["devastation"] = minf(0.7, float(p["devastation"]) + 0.12)
	p["pop"] = float(p["pop"]) * 0.985
	p["queue"] = []
	for cid in [by, old_ctrl, p["owner"]]:
		if s["countries"].has(cid) and cid != "REB":
			pass
	if by != "REB":
		GS.stat_add(s, by, "sieges_won", 1.0)
		DiplomacySystem.on_occupation(s, by, p["owner"], pid)
		# loot
		var loot := float(EconomySystem.province_calc(s, pid)["tax"]) * 2.0
		s["countries"][by]["gold"] = float(s["countries"][by]["gold"]) + loot
	for o in [by, p["owner"]]:
		if o == s["player"]:
			GS.note(s, o, "military", "NOTE_PROVINCE_OCCUPIED" if o == by else "NOTE_PROVINCE_LOST_OCC", {"province": pid}, pid)
	# own-army liberation of own province
	if by == p["owner"]:
		p["occupied_turn"] = -1

## --- supply, attrition, reinforcement ---------------------------------------------------------------------
static func supply_cap(s: Dictionary, owner: String, pid: String) -> float:
	var pd: Dictionary = Defs.provinces[pid]
	var p: Dictionary = s["provinces"][pid]
	var m := Mods.country(s, owner)
	var cap := 3.0 + float(p["pop"]) / 220.0 * float(pd["fert"]) * 1.4 + float(Mods.province(s, pid).get("infra", 0.0)) * 0.6
	cap *= float(Const.TERRAIN_FORAGE.get(pd["terrain"], 0.8))
	cap *= 1.0 + float(m.get("supply", 0.0))
	cap *= 1.0 - float(p["devastation"]) * 0.6
	# supply line: within one hop of friendly ground; a river or a pass between thins the line, bridges restore it
	var line := 0.0
	for nb in pd["adj"]:
		if s["provinces"][nb]["controller"] == owner:
			var f := 1.0
			if GeoFeatures.river_between(pid, nb):
				var bridged := int(p["buildings"].get("bridge", 0)) > 0 or int(s["provinces"][nb]["buildings"].get("bridge", 0)) > 0
				f *= 0.85 if bridged else 0.5
			if GeoFeatures.pass_between(pid, nb):
				f *= 0.6
			line = maxf(line, f)
	cap += 2.5 * line * (1.0 + float(m.get("supply", 0.0)))
	return cap

static func is_friendly_ground(s: Dictionary, owner: String, pid: String) -> bool:
	var p: Dictionary = s["provinces"][pid]
	if p["controller"] == owner:
		return true
	if p["controller"] != "" and p["controller"] != "REB" and (GS.allied(s, owner, p["controller"]) or GS.overlord_of(s, owner) == p["controller"] or GS.overlord_of(s, p["controller"]) == owner):
		return true
	return false

## Discipline ceiling of an army: drill, doctrine, barracks and the commander.
static func discipline_cap(s: Dictionary, a: Dictionary, loc: String) -> float:
	var cap := 55.0 + Mods.get_mod(s, a["owner"], "discipline") * 100.0 + float(int(s["provinces"][loc]["buildings"].get("barracks", 0))) * 4.0
	var g: Variant = a.get("general")
	if g != null:
		cap += float(int((g as Dictionary).get("tac", 0))) * 1.0
	return clampf(cap, 35.0, 95.0)

static func process_supply(s: Dictionary) -> void:
	for cid in GS.alive_countries(s):
		if not bool(s["countries"][cid].get("native", false)):
			Commanders.assign_missing(s, cid)
	var ids: Array = s["armies"].keys()
	ids.sort()
	for aid in ids:
		if not s["armies"].has(aid):
			continue
		var a: Dictionary = s["armies"][aid]
		var owner: String = a["owner"]
		var loc: String = a["loc"]
		if owner == "REB" or (loc == "" and not bool(a.get("naval", false))):
			continue
		var c: Dictionary = s["countries"][owner]
		var m := Mods.country(s, owner)
		var funding := float(c["army_funding"])
		if funding < 0.8:
			a["discipline"] = maxf(10.0, float(a.get("discipline", 50.0)) - (0.8 - funding) * 8.0)
		if funding < 0.6 and float(c["gold"]) < 0.0:
			_attrit(a, 0.01)   # unpaid troops desert
			a["morale"] = maxf(10.0, float(a["morale"]) - 2.0)
		if bool(a.get("naval", false)):
			NavalSystem.fleet_supply(s, aid)
			if s["armies"].has(aid) and UnitUtil.army_size(s["armies"][aid]) < 0.3:
				disband_army(s, aid)
			continue
		var size := UnitUtil.army_size(a)
		var w := Combat.weather_for(s, loc)
		var friendly := is_friendly_ground(s, owner, loc)
		a["supply"] = 1.0
		if friendly:
			a["morale"] = minf(70.0 + 25.0 * funding, float(a["morale"]) + 5.0)
			if s["provinces"][loc]["controller"] == owner:
				reinforce(s, a, c, 0.12)
				_drill(s, a, loc, funding)
			if float(w["attrition"]) > 0.0 and s["provinces"][loc]["owner"] != owner:
				_attrit(a, float(w["attrition"]) * 0.5 * (1.0 - float(m.get("attrition", 0.0))))
			continue
		# foreign soil: foraging limited
		var cap := supply_cap(s, owner, loc)
		cap += NavalSystem.fleet_supply_aid(s, owner, loc)
		var over := maxf(0.0, size - cap)
		var supply_ratio := clampf(cap / maxf(size, 0.001), 0.3, 1.0)
		if int(a.get("amphibious", -9)) == int(s["turn"]):
			supply_ratio = minf(supply_ratio, 0.7)   # a fresh landing has only what the ships carried
		a["supply"] = supply_ratio
		var loss_pct := over / maxf(size, 0.001) * 0.10 + float(w["attrition"])
		loss_pct *= 1.0 + float(m.get("attrition", 0.0))
		if a["general"] != null:
			loss_pct *= 1.0 - Commanders.eff_log(a["general"]) * 0.03
		if loss_pct > 0.0:
			_attrit(a, loss_pct)
		a["morale"] = maxf(10.0, float(a["morale"]) - (3.0 if supply_ratio < 1.0 else 1.0))
		if supply_ratio < 0.8:
			a["discipline"] = maxf(10.0, float(a.get("discipline", 50.0)) - 2.0)
		if loss_pct > 0.02 and owner == s["player"]:
			GS.note(s, owner, "military", "NOTE_ATTRITION", {"province": loc, "pct": int(loss_pct * 100.0)}, loc)
		if UnitUtil.army_size(a) < 0.3:
			disband_army(s, aid)

## Peacetime drill on friendly ground raises discipline towards its ceiling and trickles experience.
static func _drill(s: Dictionary, a: Dictionary, loc: String, funding: float) -> void:
	var cap := discipline_cap(s, a, loc)
	var d := float(a.get("discipline", 50.0))
	if d < cap:
		a["discipline"] = minf(cap, d + 2.0 * funding)
	elif d > cap + 5.0:
		a["discipline"] = d - 1.0
	if float(a["xp"]) < 30.0 and int(s["turn"]) - int(a.get("last_battle", -99)) > 1:
		a["xp"] = float(a["xp"]) + 0.3 * (1.0 + float(int(s["provinces"][loc]["buildings"].get("barracks", 0))) * 0.5)

static func _attrit(a: Dictionary, pct: float) -> void:
	pct = clampf(pct, 0.0, 0.5)
	for uid in a["units"].keys():
		a["units"][uid] = float(a["units"][uid]) * (1.0 - pct)
		if float(a["units"][uid]) < 0.05:
			a["units"].erase(uid)

## New men join with no experience and little drill: dilute the army's averages.
static func _dilute(a: Dictionary, added: float, total: float) -> void:
	var old := maxf(total - added, 0.0)
	a["xp"] = float(a["xp"]) * old / maxf(total, 0.001)
	a["discipline"] = (float(a.get("discipline", 50.0)) * old + 30.0 * added) / maxf(total, 0.001)

static func reinforce(s: Dictionary, a: Dictionary, c: Dictionary, rate: float) -> void:
	for uid in a["target"]:
		var want := float(a["target"][uid])
		var have := float(a["units"].get(uid, 0.0))
		if have >= want - 0.01:
			continue
		var add := minf(want - have, maxf(0.25, want * rate))
		var naval := bool(Defs.units[uid]["naval"])
		if not naval:
			var mp := float(c["manpower"])
			add = minf(add, mp)
			if add <= 0.0:
				continue
			c["manpower"] = mp - add
		var gold := float(Defs.units[uid]["cost"]["gold"]) * add * 0.35
		if float(c["gold"]) < gold:
			continue
		c["gold"] = float(c["gold"]) - gold
		a["units"][uid] = have + add
		_dilute(a, add, UnitUtil.army_size(a))

## Improve every regiment of a unit type in an army to the next unit of its chain (e.g. spearmen -> pikemen).
## Costs 60% of the price difference per regiment; experience is kept, discipline drops while the men retrain.
static func upgrade_cost(s: Dictionary, cid: String, uid: String) -> float:
	var nxt := UnitUtil.upgrade_of(s, cid, uid)
	if nxt == "":
		return -1.0
	var diff := float(recruit_cost(s, cid, nxt).get("gold", 0.0)) - float(recruit_cost(s, cid, uid).get("gold", 0.0))
	return maxf(3.0, diff * 0.6)

static func upgrade_units(s: Dictionary, aid: String, uid: String) -> Dictionary:
	var a: Dictionary = s["armies"].get(aid, {})
	if a.is_empty() or not a["units"].has(uid):
		return {"ok": false, "reason": "ERR_INVALID"}
	var cid: String = a["owner"]
	var nxt := UnitUtil.upgrade_of(s, cid, uid)
	if nxt == "":
		return {"ok": false, "reason": "UPGRADE_ERR_NONE"}
	if a["loc"] == "" or not is_friendly_ground(s, cid, a["loc"]) or (a.get("naval", false) and int(s["provinces"][a["loc"]]["buildings"].get("port", 0)) < 1):
		return {"ok": false, "reason": "UPGRADE_ERR_PLACE"}
	var n := float(a["units"][uid])
	var cost := upgrade_cost(s, cid, uid) * n
	var c: Dictionary = s["countries"][cid]
	if float(c["gold"]) < cost:
		return {"ok": false, "reason": "ERR_NO_GOLD", "params": {"need": int(cost)}}
	for k in Defs.units[nxt]["cost"]:
		if k in ["gold", "manpower"]:
			continue
		if float(c["stock"].get(k, 0.0)) < float(Defs.units[nxt]["cost"][k]) * 0.3 * n:
			return {"ok": false, "reason": "RECRUIT_ERR_MATERIAL", "params": {"what": Loc.t("RES_" + str(k).to_upper())}}
	c["gold"] = float(c["gold"]) - cost
	a["units"].erase(uid)
	a["units"][nxt] = float(a["units"].get(nxt, 0.0)) + n
	var tgt := float(a["target"].get(uid, 0.0))
	a["target"].erase(uid)
	a["target"][nxt] = float(a["target"].get(nxt, 0.0)) + maxf(tgt, n)
	a["discipline"] = maxf(10.0, float(a.get("discipline", 50.0)) - 6.0)
	GS.stat_add(s, cid, "regiments_upgraded", n)
	return {"ok": true, "to": nxt, "cost": cost}

static func process_turn_pre(s: Dictionary) -> void:
	move_all(s)

static func rebels_upkeep(s: Dictionary) -> void:
	# rebel armies lose cohesion over time and vanish after a year unless they hold ground
	var ids: Array = s["armies"].keys()
	for aid in ids:
		var a: Dictionary = s["armies"][aid]
		if a["owner"] == "REB" and int(s["turn"]) - int(a.get("born", 0)) > 12:
			var pid: String = a["loc"]
			if pid != "" and s["provinces"][pid]["controller"] != "REB":
				disband_army(s, aid)
