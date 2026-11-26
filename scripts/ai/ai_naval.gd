class_name AINaval
extends RefCounted
## AI use of the military/naval overhaul: doctrine review, unit improvement, fleet building by role, missions
## (blockade, commerce raiding, convoy escort, patrol), returning to port before supplies fail, and bringing escorts
## to armies that wait for a landing. The AI pays for everything out of its own treasury and manpower and sees only
## what a human sees (no income, supply or combat bonuses). Called once per AI turn from AISystem._military.

const MAX_FLEET_ORDERS := 3

static func run(s: Dictionary, cid: String, ai: Dictionary, P: Dictionary, W: Dictionary, rng: GameRng) -> void:
	var pers: String = ai["personality"]
	DoctrineSystem.ai_review(s, cid, pers)
	_upgrade_one(s, cid)
	var ports := _port_levels(s, cid)
	if ports <= 0.0:
		return
	var at_war := not GS.wars_of(s, cid).is_empty()
	_recruit_fleet(s, cid, W, P, ports, at_war, rng)
	_organise(s, cid, at_war, rng)
	_fleet_orders(s, cid, at_war, P)
	_landing_escorts(s, cid, at_war)

static func _port_levels(s: Dictionary, cid: String) -> float:
	var n := 0.0
	for pid in GS.owned(s, cid):
		n += float(int(s["provinces"][pid]["buildings"].get("port", 0)))
	return n

## Improve one unit type per few turns when the treasury is comfortable.
static func _upgrade_one(s: Dictionary, cid: String) -> void:
	if int(s["turn"]) % 5 != int(cid.hash() % 5):
		return
	var c: Dictionary = s["countries"][cid]
	var income := maxf(10.0, float(c.get("budget", {}).get("income", 20.0)))
	if float(c["gold"]) < income * 5.0:
		return
	for aid in GS.armies_of(s, cid):
		var a: Dictionary = s["armies"][aid]
		if a["loc"] == "" or a["transit"] != null or not (a["path"] as Array).is_empty():
			continue
		for uid in a["units"].keys():
			var nxt := UnitUtil.upgrade_of(s, cid, uid)
			if nxt == "":
				continue
			var cost := MilitarySystem.upgrade_cost(s, cid, uid) * float(a["units"][uid])
			if cost <= float(c["gold"]) * 0.25:
				if bool(MilitarySystem.upgrade_units(s, aid, uid).get("ok", false)):
					return

## --- building -----------------------------------------------------------------------------------------------------
static func _recruit_fleet(s: Dictionary, cid: String, W: Dictionary, P: Dictionary, ports: float, at_war: bool, rng: GameRng) -> void:
	var c: Dictionary = s["countries"][cid]
	var b: Dictionary = c.get("budget", {})
	var income := maxf(10.0, float(b.get("income", 20.0)))
	var navy_w := float(W.get("navy", 1.0))
	var want := clampf(0.3 * ports * navy_w + (3.0 if at_war and _foe_has_navy(s, cid) else 0.0), 0.0, 14.0)
	var have := UnitUtil.country_regiments(s, cid, true)
	var queued := 0
	for q in c["recruit_queue"]:
		if bool(Defs.units[q["uid"]]["naval"]):
			queued += 1
	if have + float(queued) >= want or not bool(P["plan"]):
		return
	var share := (float(b.get("army", 0.0)) + float(b.get("navy", 0.0))) / income
	if share > (0.55 if at_war else 0.38) or float(c["gold"]) < income * 3.0 or not rng.chance(0.35):
		return
	var uid := _pick_ship(s, cid, have)
	if uid == "":
		return
	var pid := _port_province(s, cid)
	if pid != "":
		MilitarySystem.recruit(s, cid, pid, uid)

static func _foe_has_navy(s: Dictionary, cid: String) -> bool:
	for e in GS.enemies_of(s, cid):
		if UnitUtil.country_regiments(s, e, true) >= 2.0:
			return true
	return false

## Keep a mix of about half battle line, a quarter cruisers/raiders and a quarter transports.
static func _pick_ship(s: Dictionary, cid: String, have: float) -> String:
	var by_role := {"line": 0.0, "cruiser": 0.0, "transport": 0.0}
	for aid in GS.armies_of(s, cid):
		var a: Dictionary = s["armies"][aid]
		if not bool(a.get("naval", false)):
			continue
		for uid in a["units"]:
			var r := NavalSystem.ship_role(uid)
			var key := "line" if r in ["line", "galley"] else ("cruiser" if r in ["cruiser", "raider"] else "transport")
			by_role[key] = float(by_role[key]) + float(a["units"][uid])
	var tot := maxf(have, 1.0)
	var want := {"line": 0.5, "cruiser": 0.25, "transport": 0.25}
	var role := "line"
	var bd := -1.0
	for r in want:
		var d := float(want[r]) - float(by_role[r]) / tot
		if d > bd:
			bd = d
			role = r
	var best := ""
	var bv := -1.0
	for uid in UnitUtil.available_units(s, cid):
		var u: Dictionary = Defs.units[uid]
		if not bool(u["naval"]):
			continue
		var r2 := NavalSystem.ship_role(uid)
		var key2 := "line" if r2 in ["line", "galley"] else ("cruiser" if r2 in ["cruiser", "raider"] else "transport")
		if key2 != role:
			continue
		var v := float(u["transport"]) if role == "transport" else UnitUtil.power(uid) / maxf(float(u["cost"].get("gold", 1.0)), 1.0) * 10.0 + UnitUtil.power(uid) * 0.05
		if v > bv:
			bv = v
			best = uid
	return best

static func _port_province(s: Dictionary, cid: String) -> String:
	var best := ""
	var bl := 0
	for pid in GS.owned(s, cid):
		var p: Dictionary = s["provinces"][pid]
		if p["controller"] == cid and int(p["buildings"].get("port", 0)) > bl and p.get("siege") == null:
			bl = int(p["buildings"].get("port", 0))
			best = pid
	return best

## --- organisation -------------------------------------------------------------------------------------------------
static func _my_fleets(s: Dictionary, cid: String) -> Array:
	var out: Array = []
	for aid in GS.armies_of(s, cid):
		var a: Dictionary = s["armies"][aid]
		if bool(a.get("naval", false)) and a["loc"] != "" and a["transit"] == null:
			out.append(aid)
	return out

## Split mixed fleets by role (so transports can convoy while battle fleets blockade) and set sensible missions.
static func _organise(s: Dictionary, cid: String, at_war: bool, _rng: GameRng) -> void:
	for aid in _my_fleets(s, cid):
		var a: Dictionary = s["armies"][aid]
		if UnitUtil.army_size(a) >= 4.0 and NavalSystem.squadrons(a).size() >= 2 and (a["path"] as Array).is_empty() and NavalSystem.in_friendly_port(s, a):
			NavalSystem.split_by_role(s, aid)
	for aid in _my_fleets(s, cid):
		var a2: Dictionary = s["armies"][aid]
		var sq := NavalSystem.squadrons(a2)
		if sq.is_empty():
			continue
		sq.sort_custom(func(x, y): return float(x["n"]) > float(y["n"]))
		var m: String = NavalSystem.ROLE_MISSION.get(sq[0]["role"], "patrol")
		if not at_war:
			m = "convoy" if m == "convoy" else "patrol"
		elif m == "patrol" and _best_blockade_target(s, cid, aid) != "":
			m = "blockade"
		a2["mission"] = m

## --- movement ---------------------------------------------------------------------------------------------------
static func _fleet_orders(s: Dictionary, cid: String, at_war: bool, P: Dictionary) -> void:
	var orders := 0
	var enemies: Array = GS.enemies_of(s, cid)
	for aid in _my_fleets(s, cid):
		if orders >= MAX_FLEET_ORDERS:
			break
		var a: Dictionary = s["armies"][aid]
		if not (a["path"] as Array).is_empty():
			continue
		var target := ""
		var endurance := 4.0
		for uid in a["units"]:
			endurance = float(Defs.units[uid].get("endurance", 4.0))
			break
		# low on supplies or beaten: go home
		if (int(a.get("at_sea", 0)) >= int(endurance) - 1 or float(a["morale"]) < 30.0) and not NavalSystem.in_friendly_port(s, a):
			target = _nearest_port(s, cid, aid)
		elif at_war and bool(P["plan"]):
			match str(a.get("mission", "patrol")):
				"blockade":
					target = _best_blockade_target(s, cid, aid)
				"raid":
					target = _best_raid_target(s, cid, aid, enemies)
				"convoy", "patrol":
					target = _best_convoy_post(s, cid, aid, enemies)
		if target == "" or target == a["loc"]:
			continue
		if _hostile_navy_at(s, cid, target) > NavalSystem.fleet_strength(s, a) * 1.1:
			continue
		if bool(MilitarySystem.order_move(s, aid, target).get("ok", false)):
			orders += 1

static func _hostile_navy_at(s: Dictionary, cid: String, pid: String) -> float:
	var v := 0.0
	for aid in GS.armies_at(s, pid):
		var a: Dictionary = s["armies"][aid]
		if bool(a.get("naval", false)) and GS.at_war(s, cid, a["owner"]):
			v += NavalSystem.fleet_strength(s, a)
	return v

static func _candidates(s: Dictionary, from: String, pids: Array, limit: int) -> Array:
	var cf: Array = Defs.provinces[from]["centroid"]
	var scored: Array = []
	for pid in pids:
		var cp: Array = Defs.provinces[pid]["centroid"]
		scored.append([Vector2(float(cf[0]) - float(cp[0]), float(cf[1]) - float(cp[1])).length(), pid])
	scored.sort_custom(func(x, y): return x[0] < y[0])
	var out: Array = []
	for i in range(mini(limit, scored.size())):
		out.append(scored[i][1])
	return out

## The reachable candidate with the cheapest sea path.
static func _cheapest(s: Dictionary, aid: String, pids: Array) -> String:
	var best := ""
	var bc := 1e18
	for pid in _candidates(s, s["armies"][aid]["loc"], pids, 5):
		var r := MilitarySystem.find_path(s, aid, pid)
		if bool(r["ok"]) and float(r["cost"]) < bc:
			bc = float(r["cost"])
			best = pid
	return best

static func _nearest_port(s: Dictionary, cid: String, aid: String) -> String:
	var ports: Array = []
	for pid in GS.owned(s, cid):
		var p: Dictionary = s["provinces"][pid]
		if p["controller"] == cid and int(p["buildings"].get("port", 0)) > 0 and not NavalSystem.is_blockaded(s, pid):
			ports.append(pid)
	return _cheapest(s, aid, ports)

## Enemy-held ports the fleet is strong enough to close.
static func _best_blockade_target(s: Dictionary, cid: String, aid: String) -> String:
	var a: Dictionary = s["armies"][aid]
	var power := NavalSystem.fleet_attr(s, a, "blockade")
	var ports: Array = []
	for e in GS.enemies_of(s, cid):
		for pid in GS.owned(s, e):
			var p: Dictionary = s["provinces"][pid]
			if int(p["buildings"].get("port", 0)) > 0 and p["controller"] == e and power >= 1.0 + 0.25 * float(int(p["buildings"].get("fort", 0))):
				ports.append(pid)
	return _cheapest(s, aid, ports)

## A coastal province in the zone where the enemy has the most port levels.
static func _best_raid_target(s: Dictionary, cid: String, aid: String, enemies: Array) -> String:
	var zone_levels := {}
	for e in enemies:
		for pid in GS.owned(s, e):
			var lv := int(s["provinces"][pid]["buildings"].get("port", 0))
			if lv > 0:
				var z := SeaZones.zone_of(pid)
				zone_levels[z] = float(zone_levels.get(z, 0.0)) + float(lv)
	var best_z := ""
	var bl := 0.0
	for z in zone_levels:
		if float(zone_levels[z]) > bl:
			bl = float(zone_levels[z])
			best_z = z
	if best_z == "":
		return ""
	var spots: Array = []
	for pid in SeaZones.members(best_z):
		if s["provinces"][pid]["controller"] in enemies:
			continue
		if int(s["provinces"][pid]["buildings"].get("port", 0)) > 0 or Defs.provinces[pid]["coastal"]:
			spots.append(pid)
	return _cheapest(s, aid, spots)

## Escorts and patrols go where enemy raiders threaten our trade, otherwise home.
static func _best_convoy_post(s: Dictionary, cid: String, aid: String, enemies: Array) -> String:
	var best_z := ""
	var bs := 0.0
	var levels := {}
	for pid in GS.owned(s, cid):
		var lv := int(s["provinces"][pid]["buildings"].get("port", 0))
		if lv > 0:
			var z := SeaZones.zone_of(pid)
			levels[z] = float(levels.get(z, 0.0)) + float(lv)
	for z in levels:
		var foe := 0.0
		for fid in s["armies"]:
			var f: Dictionary = s["armies"][fid]
			if bool(f.get("naval", false)) and f["owner"] in enemies and SeaZones.zone_of_fleet(f) == z:
				foe += NavalSystem.fleet_attr(s, f, "raid")
		var sc: float = float(levels[z]) * (1.0 + foe)
		if sc > bs:
			bs = sc
			best_z = z
	if best_z == "":
		return ""
	var ports: Array = []
	for pid in SeaZones.members(best_z):
		if s["provinces"][pid]["controller"] == cid and int(s["provinces"][pid]["buildings"].get("port", 0)) > 0:
			ports.append(pid)
	return _cheapest(s, aid, ports)

## An idle army waiting in a port with a sea link to an enemy province gets an escort fleet brought to it.
static func _landing_escorts(s: Dictionary, cid: String, at_war: bool) -> void:
	if not at_war:
		return
	var enemies: Array = GS.enemies_of(s, cid)
	for aid in GS.armies_of(s, cid):
		var a: Dictionary = s["armies"][aid]
		if bool(a.get("naval", false)) or a["loc"] == "" or a["transit"] != null or not (a["path"] as Array).is_empty():
			continue
		var loc: String = a["loc"]
		if s["provinces"][loc]["controller"] != cid or int(s["provinces"][loc]["buildings"].get("port", 0)) < 1:
			continue
		var wants_landing := false
		for sl in Defs.sea_links(loc):
			if sl[1] == "lane" and s["provinces"][sl[0]]["controller"] in enemies:
				wants_landing = true
				break
		if not wants_landing or MilitarySystem._find_escort(s, a) != "":
			continue
		var need := UnitUtil.army_size(a)
		for fid in _my_fleets(s, cid):
			var f: Dictionary = s["armies"][fid]
			if (f["path"] as Array).is_empty() and f["loc"] != loc and UnitUtil.transport_capacity(f) * (1.0 + Mods.get_mod(s, cid, "naval_transport")) >= need:
				if bool(MilitarySystem.order_move(s, fid, loc).get("ok", false)):
					return
