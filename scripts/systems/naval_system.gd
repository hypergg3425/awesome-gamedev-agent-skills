class_name NavalSystem
extends RefCounted
## Naval overhaul: fleet organisation (flagship, squadrons by role, missions), naval supply and attrition away from
## ports, maritime transport capacity, sea control per sea zone, blockades of ports, commerce raiding and convoy
## protection of trade, amphibious landing rules and naval support of sieges. Fleets are armies with naval = true that
## move along sea links between coastal provinces (see MilitarySystem.find_path) and so never teleport.
## Persistent data lives in state["naval"]; everything else is recomputed from the fleets each turn.

const MISSIONS: Array[String] = ["patrol", "blockade", "raid", "convoy"]
## How much of a fleet's raiding / escorting / blockading strength a mission contributes.
const MISSION_RAID := {"patrol": 0.45, "blockade": 0.2, "raid": 1.0, "convoy": 0.1}
const MISSION_ESCORT := {"patrol": 0.6, "blockade": 0.3, "raid": 0.2, "convoy": 1.0}
const MISSION_BLOCKADE := {"patrol": 0.8, "blockade": 1.25, "raid": 0.4, "convoy": 0.6}
const ROLE_MISSION := {"line": "patrol", "cruiser": "raid", "raider": "raid", "transport": "convoy", "galley": "patrol"}
const LOOT_SHARE := 0.3         # share of the trade a raider destroys that it captures
const MAX_RAID_LOSS := 0.5      # of the seaborne part of a country's trade income

## --- state ----------------------------------------------------------------------------------------------
## Defaults for fields added after v3 saves; called on load, on new games and defensively each turn.
static func ensure_fields(s: Dictionary) -> void:
	if not (s.get("naval") is Dictionary):
		s["naval"] = {}
	var nv: Dictionary = s["naval"]
	for k in ["control", "blockades", "raids", "convoys", "stats"]:
		if not (nv.get(k) is Dictionary):
			nv[k] = {}
	nv["turn"] = int(nv.get("turn", -1))
	for aid in s["armies"]:
		var a: Dictionary = s["armies"][aid]
		if not a.has("discipline"):
			a["discipline"] = 30.0 if a["owner"] == "REB" else 50.0
		if not a.has("mission"):
			a["mission"] = "patrol"
		if not a.has("at_sea"):
			a["at_sea"] = 0
		var g: Variant = a.get("general")
		if g is Dictionary and not (g as Dictionary).has("traits"):
			(g as Dictionary)["traits"] = []
			(g as Dictionary)["level"] = 1
			(g as Dictionary)["battles"] = 0
	for cid in s["countries"]:
		DoctrineSystem.ensure(s, cid)

static func country_stats(s: Dictionary, cid: String) -> Dictionary:
	var st: Dictionary = s["naval"]["stats"]
	if not st.has(cid):
		st[cid] = {"raided": 0.0, "looted": 0.0, "sunk_raiders": 0.0, "landings": 0.0, "intercepted": 0.0}
	return st[cid]

## --- fleet organisation ---------------------------------------------------------------------------------
static func ship_role(uid: String) -> String:
	return str(Defs.units[uid].get("role", "line"))

## Flagship: the costliest ship type in the fleet.
static func flagship(a: Dictionary) -> String:
	var best := ""
	var bc := -1.0
	for uid in a["units"]:
		if float(a["units"][uid]) <= 0.0:
			continue
		var c := float(Defs.units[uid]["cost"].get("gold", 0.0))
		if c > bc:
			bc = c
			best = uid
	return best

## Squadrons are the fleet grouped by ship role: battle line, cruisers, raiders, galleys, transports.
static func squadrons(a: Dictionary) -> Array:
	var by := {}
	for uid in a["units"]:
		var n := float(a["units"][uid])
		if n <= 0.0:
			continue
		var r := ship_role(uid)
		if not by.has(r):
			by[r] = {"role": r, "units": {}, "n": 0.0, "speed": 99.0}
		by[r]["units"][uid] = n
		by[r]["n"] = float(by[r]["n"]) + n
		by[r]["speed"] = minf(float(by[r]["speed"]), float(Defs.units[uid]["move"]))
	var out: Array = by.values()
	out.sort_custom(func(x, y): return str(x["role"]) < str(y["role"]))
	return out

static func set_mission(s: Dictionary, aid: String, mission: String) -> Dictionary:
	var a: Dictionary = s["armies"].get(aid, {})
	if a.is_empty() or not bool(a.get("naval", false)) or mission not in MISSIONS:
		return {"ok": false, "reason": "ERR_INVALID"}
	a["mission"] = mission
	return {"ok": true}

## Detach every role other than the largest into its own squadron fleet with a fitting mission.
static func split_by_role(s: Dictionary, aid: String) -> Array:
	var a: Dictionary = s["armies"].get(aid, {})
	var out: Array = []
	if a.is_empty() or not bool(a.get("naval", false)) or a["loc"] == "":
		return out
	var sq := squadrons(a)
	if sq.size() < 2:
		return out
	sq.sort_custom(func(x, y): return float(x["n"]) > float(y["n"]))
	for i in range(1, sq.size()):
		var nid := MilitarySystem.split_army(s, aid, sq[i]["units"])
		if nid != "":
			s["armies"][nid]["mission"] = ROLE_MISSION.get(sq[i]["role"], "patrol")
			s["armies"][nid]["xp"] = a["xp"]
			out.append(nid)
	a["mission"] = ROLE_MISSION.get(sq[0]["role"], "patrol")
	return out

static func readiness(a: Dictionary) -> float:
	return clampf(float(a["morale"]) / 100.0, 0.2, 1.0) * clampf(float(a.get("supply", 1.0)), 0.4, 1.0)

## Combat-power points of a fleet (sea control / escort comparisons).
static func fleet_strength(s: Dictionary, a: Dictionary) -> float:
	var v := 0.0
	for uid in a["units"]:
		v += UnitUtil.power(uid) * float(a["units"][uid])
	return v * readiness(a) * (1.0 + Mods.get_mod(s, a["owner"], "naval_atk"))

## Sum over ships of count x attribute (raid / escort / blockade), modified by doctrine and admiral.
static func fleet_attr(s: Dictionary, a: Dictionary, attr: String) -> float:
	var v := 0.0
	for uid in a["units"]:
		v += float(Defs.units[uid].get(attr, 0.0)) * float(a["units"][uid])
	var key: String = {"raid": "raid", "escort": "convoy", "blockade": "blockade"}.get(attr, "")
	var mult := 1.0
	if key != "":
		mult += Mods.get_mod(s, a["owner"], key) + Commanders.bonus(a.get("general"), key)
	return v * maxf(mult, 0.1) * readiness(a)

static func transport_capacity(s: Dictionary, cid: String) -> float:
	var cap := 0.0
	for aid in GS.armies_of(s, cid):
		var a: Dictionary = s["armies"][aid]
		if bool(a.get("naval", false)):
			cap += UnitUtil.transport_capacity(a)
	return cap * (1.0 + Mods.get_mod(s, cid, "naval_transport"))

## --- supply and attrition at sea --------------------------------------------------------------------------
static func in_friendly_port(s: Dictionary, a: Dictionary) -> bool:
	var loc: String = a["loc"]
	if loc == "":
		return false
	var p: Dictionary = s["provinces"][loc]
	if int(p["buildings"].get("port", 0)) < 1:
		return false
	return MilitarySystem.is_friendly_ground(s, a["owner"], loc) and blockade_level(s, loc) < 0.5

static func fleet_supply(s: Dictionary, aid: String) -> void:
	var a: Dictionary = s["armies"][aid]
	var owner: String = a["owner"]
	if owner == "REB":
		return
	var c: Dictionary = s["countries"][owner]
	var m := Mods.country(s, owner)
	if in_friendly_port(s, a):
		a["at_sea"] = 0
		a["supply"] = 1.0
		a["morale"] = minf(90.0, float(a["morale"]) + 6.0)
		var cap := minf(80.0, float(55.0 + Mods.get_mod(s, owner, "discipline") * 100.0 + 15.0))
		a["discipline"] = minf(cap, float(a.get("discipline", 50.0)) + 1.5)
		if s["provinces"][a["loc"]]["controller"] == owner:
			MilitarySystem.reinforce(s, a, c, 0.15)
		return
	a["at_sea"] = int(a.get("at_sea", 0)) + 1
	var endurance := _endurance(a) * (1.0 + 0.04 * Commanders.eff_log(a.get("general"))) * (1.0 + float(m.get("supply", 0.0)))
	var excess := maxf(0.0, float(a["at_sea"]) - endurance)
	var loss := 0.0
	if excess > 0.0:
		loss += 0.015 * excess
		a["morale"] = maxf(10.0, float(a["morale"]) - 2.0 * excess)
		a["discipline"] = maxf(10.0, float(a.get("discipline", 50.0)) - 1.0)
	# storms: winter and the tropical autumn, heavier for rough-water-sensitive hulls
	var ref: String = a["loc"] if a["loc"] != "" else str(a["transit"]["from"])
	var w := Combat.weather_for(s, ref)
	var storm := 0.0
	if int(w["season"]) == 3 and absf(float(Defs.provinces[ref]["lat"])) > 35.0:
		storm = 0.012
	elif int(w["season"]) == 2 and absf(float(Defs.provinces[ref]["lat"])) < 25.0:
		storm = 0.012
	if storm > 0.0:
		loss += storm * NavalCombat._avg_attr(s, [aid], "rough", 1.0) * (1.0 - Commanders.bonus(a.get("general"), "weather") * 0.5)
	loss *= 1.0 + float(m.get("attrition", 0.0))
	a["supply"] = clampf(1.0 - 0.07 * excess, 0.4, 1.0)
	if loss > 0.0:
		MilitarySystem._attrit(a, loss)

static func _endurance(a: Dictionary) -> float:
	var tot := 0.0
	var n := 0.0
	for uid in a["units"]:
		var c := float(a["units"][uid])
		tot += float(Defs.units[uid].get("endurance", 4.0)) * c
		n += c
	return tot / maxf(n, 0.001)

## Supply that friendly ships anchored next to a landing add to the army ashore.
static func fleet_supply_aid(s: Dictionary, owner: String, loc: String) -> float:
	var aid_total := 0.0
	for fid in GS.armies_at(s, loc):
		var f: Dictionary = s["armies"][fid]
		if bool(f.get("naval", false)) and f["owner"] == owner and f["transit"] == null:
			aid_total += UnitUtil.transport_capacity(f) * 0.15
	return minf(aid_total, 4.0)

## --- sea control ---------------------------------------------------------------------------------------------
static func _zone_of_fleet(a: Dictionary) -> String:
	return SeaZones.zone_of_fleet(a)

## Influence of every country in a sea zone: ships present (power / 10, scaled by readiness and doctrine) plus
## coastal ports and their fortifications in the zone. Returns {country: score}.
static func sea_control(s: Dictionary, sea_id: String) -> Dictionary:
	return compute_control(s).get(sea_id, {})

static func compute_control(s: Dictionary, force: bool = false) -> Dictionary:
	ensure_fields(s)
	var nv: Dictionary = s["naval"]
	if not force and int(nv["turn"]) == int(s["turn"]) and s["_c"].get("control_ok", false):
		return nv["control"]
	var ctl := {}
	for aid in s["armies"]:
		var a: Dictionary = s["armies"][aid]
		if not bool(a.get("naval", false)) or a["owner"] == "REB":
			continue
		var z := _zone_of_fleet(a)
		if z == "":
			continue
		if not ctl.has(z):
			ctl[z] = {}
		ctl[z][a["owner"]] = float(ctl[z].get(a["owner"], 0.0)) + fleet_strength(s, a) * 0.1
	for pid in Defs.province_ids:
		var p: Dictionary = s["provinces"][pid]
		var lv := int(p["buildings"].get("port", 0))
		if lv < 1 or p["controller"] == "" or p["controller"] == "REB":
			continue
		var z2 := SeaZones.zone_of(pid)
		if z2 == "":
			continue
		if not ctl.has(z2):
			ctl[z2] = {}
		var c: String = p["controller"]
		ctl[z2][c] = float(ctl[z2].get(c, 0.0)) + 1.5 * float(lv) + 0.4 * float(int(p["buildings"].get("fort", 0)))
	for z3 in ctl:
		for c2 in ctl[z3]:
			ctl[z3][c2] = snappedf(float(ctl[z3][c2]), 0.001)
	nv["control"] = ctl
	nv["turn"] = s["turn"]
	s["_c"]["control_ok"] = true
	return ctl

## Sum of the control scores of a country's side (itself and its allies) vs the countries at war with it.
static func side_control(s: Dictionary, cid: String, zone: String, force: bool = false) -> Dictionary:
	var own := 0.0
	var foe := 0.0
	var z: Dictionary = compute_control(s, force).get(zone, {})
	for c in z:
		if c == cid or GS.allied(s, cid, c):
			own += float(z[c])
		elif GS.at_war(s, cid, c):
			foe += float(z[c])
	return {"own": own, "foe": foe}

## --- blockades -------------------------------------------------------------------------------------------------
## 0..1 blockade level of a coastal province: hostile ships there (weighted by blockade value and mission) against the
## strength needed to close a port with that much fortification, minus the defender's own ships.
static func blockade_level(s: Dictionary, pid: String) -> float:
	var p: Dictionary = s["provinces"].get(pid, {})
	if p.is_empty() or not bool(Defs.provinces[pid]["coastal"]):
		return 0.0
	var ctrl: String = p["controller"]
	var foe := 0.0
	var own := 0.0
	var any_foe := false
	for aid in GS.armies_at(s, pid):
		var a: Dictionary = s["armies"][aid]
		if not bool(a.get("naval", false)) or a["transit"] != null:
			continue
		if a["owner"] != ctrl and GS.at_war(s, a["owner"], ctrl):
			any_foe = true
			foe += fleet_attr(s, a, "blockade") * float(MISSION_BLOCKADE.get(a.get("mission", "patrol"), 0.8))
		elif a["owner"] == ctrl or GS.allied(s, a["owner"], ctrl):
			own += fleet_attr(s, a, "blockade") * 0.8
	if not any_foe:
		return 0.0
	var required := 1.0 + 0.25 * float(int(p["buildings"].get("fort", 0)))
	return clampf((maxf(0.0, foe - own) / required - 0.5), 0.0, 1.0)

static func is_blockaded(s: Dictionary, pid: String) -> bool:
	return blockade_level(s, pid) >= 0.5

## Who blockades a province right now ("" if nobody).
static func blockader_of(s: Dictionary, pid: String) -> String:
	if blockade_level(s, pid) < 0.5:
		return ""
	var best := ""
	var bs := 0.0
	for aid in GS.armies_at(s, pid):
		var a: Dictionary = s["armies"][aid]
		if bool(a.get("naval", false)) and a["transit"] == null and GS.at_war(s, a["owner"], s["provinces"][pid]["controller"]):
			var v := fleet_attr(s, a, "blockade")
			if v > bs:
				bs = v
				best = a["owner"]
	return best

## Naval support of a land siege of a coastal province.
static func siege_support(s: Dictionary, pid: String, besieger: String) -> Dictionary:
	var out := {"bombard": 0.0, "blockade": 0.0}
	if not bool(Defs.provinces[pid]["coastal"]):
		return out
	var ctrl: String = s["provinces"][pid]["controller"]
	var guns := 0.0
	for aid in GS.armies_at(s, pid):
		var a: Dictionary = s["armies"][aid]
		if not bool(a.get("naval", false)) or a["transit"] != null:
			continue
		if a["owner"] == besieger or (GS.at_war(s, a["owner"], ctrl) and a["owner"] != ctrl):
			for uid in a["units"]:
				if ship_role(uid) in ["line", "cruiser"]:
					guns += float(Defs.units[uid]["fire"]) * float(a["units"][uid]) * 0.04
	out["bombard"] = minf(guns, 4.0)
	out["blockade"] = blockade_level(s, pid)
	return out

## --- amphibious operations ------------------------------------------------------------------------------------
## A landing needs an escort fleet at the embarkation port and must not be hopeless against enemy sea control.
static func landing_check(s: Dictionary, army: Dictionary, escort_id: String, target: String) -> Dictionary:
	var owner: String = army["owner"]
	var esc: Dictionary = s["armies"].get(escort_id, {})
	if esc.is_empty():
		return {"ok": false, "reason": "LANDING_ERR_NO_ESCORT"}
	var zone := SeaZones.lane_zone(str(army["loc"]), target)
	var zone_t := SeaZones.zone_of(target)
	var worst := 0.0
	var own_best := 0.0
	for z in [zone, zone_t]:
		if z == "":
			continue
		var sc := side_control(s, owner, z, true)
		worst = maxf(worst, float(sc["foe"]) - 1.5 * float(sc["own"]))
		own_best = maxf(own_best, float(sc["own"]))
	if worst > 1.0:
		return {"ok": false, "reason": "LANDING_ERR_SEA_CONTROL"}
	var assault: bool = GS.at_war(s, owner, s["provinces"][target]["controller"])
	return {"ok": true, "assault": assault, "sea_control": own_best}

## --- per-turn processing ------------------------------------------------------------------------------------------
static func process_turn(s: Dictionary) -> void:
	ensure_fields(s)
	s["_c"]["control_ok"] = false
	var nv: Dictionary = s["naval"]
	var ctl := compute_control(s, true)
	for aid in s["armies"]:
		var a: Dictionary = s["armies"][aid]
		if bool(a.get("naval", false)):
			a["flagship"] = flagship(a)
	# blockade registry (informational: UI / maps read it)
	var blk := {}
	for pid in Defs.province_ids:
		if not bool(Defs.provinces[pid]["coastal"]):
			continue
		var armies_here: Array = GS.armies_at(s, pid)
		if armies_here.is_empty():
			continue
		var lv := blockade_level(s, pid)
		if lv > 0.0:
			var prev: Dictionary = (nv["blockades"] as Dictionary).get(pid, {})
			var by := blockader_of(s, pid)
			var since := int(prev.get("since", s["turn"])) if prev.get("by", "") == by else int(s["turn"])
			blk[pid] = {"by": by, "level": snappedf(lv, 0.001), "since": since}
	nv["blockades"] = blk
	_process_raids(s, ctl)
	_process_interception(s)

## Raiders and escorts per zone, and the share of every country's seaborne trade lost this turn.
static func _process_raids(s: Dictionary, _ctl: Dictionary) -> void:
	var nv: Dictionary = s["naval"]
	var by_zone := {}
	for aid in s["armies"]:
		var a: Dictionary = s["armies"][aid]
		if not bool(a.get("naval", false)) or a["owner"] == "REB":
			continue
		var z := _zone_of_fleet(a)
		if z == "":
			continue
		if not by_zone.has(z):
			by_zone[z] = []
		by_zone[z].append(aid)
	var raids := {}
	var convoys := {}
	for cid in GS.alive_countries(s):
		if GS.wars_of(s, cid).is_empty():
			continue
		var ports := {}
		var total_ports := 0.0
		for pid in GS.owned(s, cid):
			var lv := float(int(s["provinces"][pid]["buildings"].get("port", 0)))
			if lv > 0.0:
				var z := SeaZones.zone_of(pid)
				ports[z] = float(ports.get(z, 0.0)) + lv
				total_ports += lv
		if total_ports <= 0.0:
			continue
		var loss_frac := 0.0
		var saved_frac := 0.0
		var by_raider := {}
		var escort_all := 0.0
		for z in ports:
			var raid := 0.0
			var esc := 0.0
			var raiders_of := {}
			for aid in by_zone.get(z, []):
				var a: Dictionary = s["armies"][aid]
				if a["owner"] == cid or GS.allied(s, a["owner"], cid):
					esc += fleet_attr(s, a, "escort") * float(MISSION_ESCORT.get(a.get("mission", "patrol"), 0.6))
				elif GS.at_war(s, a["owner"], cid):
					var r := fleet_attr(s, a, "raid") * float(MISSION_RAID.get(a.get("mission", "patrol"), 0.45))
					raid += r
					raiders_of[a["owner"]] = float(raiders_of.get(a["owner"], 0.0)) + r
			escort_all += esc
			if raid <= 0.0:
				continue
			var pressure_open := raid / (raid + 1.5)
			var pressure := raid / (raid + 1.2 * esc + 1.5)
			var w: float = float(ports[z]) / total_ports
			loss_frac += w * pressure * MAX_RAID_LOSS
			saved_frac += w * (pressure_open - pressure) * MAX_RAID_LOSS
			for r_owner in raiders_of:
				by_raider[r_owner] = float(by_raider.get(r_owner, 0.0)) + w * float(raiders_of[r_owner])
			_escort_hunts_raiders(s, by_zone.get(z, []), cid, raid, esc)
		var sea_share := clampf(0.1 + 0.05 * total_ports, 0.1, 0.5)
		if loss_frac > 0.0:
			raids[cid] = {"frac": snappedf(loss_frac * sea_share, 0.0001), "by": by_raider}
		convoys[cid] = {"escort": snappedf(escort_all, 0.001), "saved": snappedf(saved_frac * sea_share, 0.0001)}
	nv["raids"] = raids
	nv["convoys"] = convoys

## Escorts in a zone wear down the raiders hunting there; raiders hurt the escorts less.
static func _escort_hunts_raiders(s: Dictionary, fleets: Array, victim: String, raid: float, esc: float) -> void:
	if esc <= 0.0:
		return
	var hit := clampf(0.04 * esc / (raid + esc + 0.1), 0.0, 0.06)
	for aid in fleets:
		if not s["armies"].has(aid):
			continue
		var a: Dictionary = s["armies"][aid]
		if a["owner"] != victim and GS.at_war(s, a["owner"], victim) and a.get("mission", "patrol") in ["raid", "patrol"]:
			MilitarySystem._attrit(a, hit)
			country_stats(s, victim)["sunk_raiders"] = float(country_stats(s, victim)["sunk_raiders"]) + hit * UnitUtil.army_size(a)
			if UnitUtil.army_size(a) < 0.3:
				MilitarySystem.disband_army(s, aid)

## Fleets (and the troops they carry) sailing through water dominated by an enemy may be intercepted.
static func _process_interception(s: Dictionary) -> void:
	var rng := GS.rng_of(s)
	var ids: Array = s["armies"].keys()
	ids.sort()
	for aid in ids:
		if not s["armies"].has(aid):
			continue
		var a: Dictionary = s["armies"][aid]
		if not bool(a.get("naval", false)) or a["transit"] == null or a["owner"] == "REB":
			continue
		var carrying := false
		for oid in s["armies"]:
			if str(s["armies"][oid].get("escort", "")) == aid and s["armies"][oid]["transit"] != null:
				carrying = true
				break
		if not carrying:
			continue
		var z := SeaZones.zone_of_fleet(a)
		var sc := side_control(s, a["owner"], z, true)
		var foe := float(sc["foe"])
		if foe <= 0.5:
			continue
		var p := clampf(0.45 * foe / (foe + float(sc["own"]) + 1.0), 0.0, 0.4)
		if rng.randf() >= p:
			continue
		var frac := 0.25 + 0.2 * rng.randf()
		MilitarySystem._attrit(a, frac)
		for oid in s["armies"].keys():
			var o: Dictionary = s["armies"][oid]
			if str(o.get("escort", "")) == aid and o["transit"] != null:
				MilitarySystem._attrit(o, frac)
				if UnitUtil.army_size(o) < 0.3:
					MilitarySystem.disband_army(s, oid)
		country_stats(s, a["owner"])["intercepted"] = float(country_stats(s, a["owner"])["intercepted"]) + 1.0
		if a["owner"] == s["player"]:
			GS.note(s, a["owner"], "military", "NOTE_CONVOY_INTERCEPTED", {"pct": int(frac * 100.0)}, "")
		if UnitUtil.army_size(a) < 0.3:
			MilitarySystem.disband_army(s, aid)

## --- trade hook (called by TradeSystem.compute after payouts) ---------------------------------------------------
## Commerce raiding reduces the victim's income and enriches the raiders; a merchant marine adds a little.
static func adjust_trade(s: Dictionary, res: Dictionary) -> void:
	ensure_fields(s)
	var income: Dictionary = res["income"]
	var raids: Dictionary = s["naval"]["raids"]
	for cid in income.keys():
		if not s["countries"].has(cid):
			continue
		var mm := _merchant_bonus(s, cid)
		if mm > 0.0:
			income[cid] = float(income[cid]) * (1.0 + 0.06 * mm)
	for victim in raids:
		if not income.has(victim):
			continue
		var frac := float(raids[victim]["frac"])
		var lost := float(income[victim]) * frac
		income[victim] = float(income[victim]) - lost
		var tot := 0.0
		for r in raids[victim]["by"]:
			tot += float(raids[victim]["by"][r])
		country_stats(s, victim)["raided"] = float(country_stats(s, victim)["raided"]) + lost
		for r in raids[victim]["by"]:
			var gain := lost * LOOT_SHARE * float(raids[victim]["by"][r]) / maxf(tot, 0.001)
			income[r] = float(income.get(r, 0.0)) + gain
			country_stats(s, r)["looted"] = float(country_stats(s, r)["looted"]) + gain

## 0..1: how well the merchant fleet (transport capacity) covers the country's seaborne trade.
static func _merchant_bonus(s: Dictionary, cid: String) -> float:
	var levels := 0.0
	for pid in GS.owned(s, cid):
		levels += float(int(s["provinces"][pid]["buildings"].get("port", 0)))
	if levels <= 0.0:
		return 0.0
	return clampf(transport_capacity(s, cid) / (2.0 + 1.2 * levels), 0.0, 1.0)

## Summary used by the UI.
static func country_summary(s: Dictionary, cid: String) -> Dictionary:
	ensure_fields(s)
	var raids: Dictionary = s["naval"]["raids"]
	var conv: Dictionary = s["naval"]["convoys"].get(cid, {"escort": 0.0, "saved": 0.0})
	var blocked: Array = []
	for pid in s["naval"]["blockades"]:
		if s["provinces"][pid]["controller"] == cid:
			blocked.append(pid)
	blocked.sort()
	return {"raid_loss": float(raids.get(cid, {}).get("frac", 0.0)), "convoy_escort": float(conv["escort"]), "convoy_saved": float(conv["saved"]),
		"blockaded": blocked, "transport": transport_capacity(s, cid), "merchant": _merchant_bonus(s, cid), "stats": country_stats(s, cid)}
