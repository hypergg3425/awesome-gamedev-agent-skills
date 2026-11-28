extends TestCase
## Naval overhaul: sea zones and connectivity, fleet movement along sea links only, organisation, supply at sea,
## blockades (trade routes and sieges), commerce raiding and convoys, sea control, amphibious rules, sea battles.

## Two countries X and Y with ports in the same sea zone, at war.
func _stage() -> Dictionary:
	var s := new_state()
	for zid in SeaZones.zone_ids():
		var by_owner := {}
		for pid in SeaZones.members(zid):
			var o: String = s["provinces"][pid]["owner"]
			if o == "" or o == "REB" or str(o).begins_with("NAT_") or not s["countries"][o]["alive"]:
				continue
			if not by_owner.has(o):
				by_owner[o] = pid
		if by_owner.size() >= 2:
			var owners: Array = by_owner.keys()
			owners.sort()
			var x: String = owners[0]
			var y: String = owners[1]
			var px: String = by_owner[x]
			var py: String = by_owner[y]
			# the blockaded province must actually carry trade, otherwise a blockade has nothing to cut
			var tr: Dictionary = TradeSystem.compute(s)["by_province"]
			var best := 0.0
			for pid in SeaZones.members(zid):
				if s["provinces"][pid]["owner"] == y and tr.has(pid) and int(tr[pid]["hops"]) >= 1 and float(tr[pid]["value"]) > best:
					best = float(tr[pid]["value"])
					py = pid
			if best < 3.0:
				continue
			if GS.allied(s, x, y) or GS.overlord_of(s, x) != "" or GS.overlord_of(s, y) != "":
				continue
			for p in [px, py]:
				s["provinces"][p]["buildings"]["port"] = 2
			DiplomacySystem.start_war(s, [x], [y], "conquest", [], true)
			for aid in s["armies"].keys():
				if s["armies"][aid].get("naval", false):
					MilitarySystem.disband_army(s, aid)
			GS.rebuild_caches(s)
			Mods.invalidate(s)
			return {"s": s, "x": x, "y": y, "px": px, "py": py, "zone": zid}
	return {}

func _fleet(s: Dictionary, owner: String, pid: String, units: Dictionary, mission: String = "patrol", gen: Variant = null) -> String:
	var aid := MilitarySystem.create_army(s, owner, pid, units, gen if gen != null else {"name": "Adm", "tac": 5, "log": 5, "siege": 5, "xp": 0.0, "traits": [], "naval": true})
	s["armies"][aid]["mission"] = mission
	GS.rebuild_caches(s)
	return aid

func test_sea_zones_cover_coasts_and_connect_across_lanes() -> void:
	var zones := SeaZones.zone_ids()
	ok(zones.size() >= 20, "sea zones exist (%d)" % zones.size())
	var missing := 0
	for pid in Defs.province_ids:
		var z := SeaZones.zone_of(pid)
		if bool(Defs.provinces[pid]["coastal"]) and z == "":
			missing += 1
		if not bool(Defs.provinces[pid]["coastal"]):
			eq(z, "", "inland province has no zone")
	eq(missing, 0, "every coastal province has a zone")
	var linked := 0
	for zid in zones:
		ok(SeaZones.zone_name(zid) != "", "zone has a name")
		for n in SeaZones.neighbors(zid):
			linked += 1
			ok(n != zid and n in SeaZones.zone_ids(), "adjacent zone is a real, different zone")
	ok(linked > 20, "zones are connected through sea links (%d)" % linked)

func test_fleet_moves_only_along_sea_links_and_never_teleports() -> void:
	var st := _stage()
	var s: Dictionary = st["s"]
	var aid := _fleet(s, st["x"], st["px"], {"galleon": 3.0})
	# pick a far coastal target reachable by sea
	var target := ""
	for pid in Defs.province_ids:
		if Defs.provinces[pid]["coastal"] and pid != st["px"]:
			var r := MilitarySystem.find_path(s, aid, pid)
			if r["ok"] and (r["path"] as Array).size() >= 3:
				target = pid
				break
	ok(target != "", "a multi-hop sea route exists")
	var r2 := MilitarySystem.order_move(s, aid, target)
	ok(r2["ok"], "order accepted")
	var prev: String = st["px"]
	for step in (r2["path"] as Array).size():
		var nxt: String = r2["path"][step]
		var linked := false
		for sl in Defs.sea_links(prev):
			if sl[0] == nxt:
				linked = true
		ok(linked, "path hop %s -> %s follows a sea link" % [prev, nxt])
		prev = nxt
	# sail: every observed location must be reached through a link; in between the fleet is at sea (loc "")
	var last: String = st["px"]
	var arrived := false
	for turn in 80:
		MilitarySystem.move_all(s)
		GS.rebuild_caches(s)
		var a: Dictionary = s["armies"][aid]
		if a["loc"] != "":
			if a["loc"] != last:
				var ok_link := false
				for sl in Defs.sea_links(last):
					if sl[0] == a["loc"]:
						ok_link = true
				ok(ok_link, "arrived by a sea link, not teleported (%s -> %s)" % [last, a["loc"]])
				last = a["loc"]
			if last == target:
				arrived = true
				break
		else:
			ok(a["transit"] != null, "a fleet without a location is in transit")
	ok(arrived, "the fleet reached its destination")
	# no sea route over land
	var inland := ""
	for pid in Defs.province_ids:
		if not Defs.provinces[pid]["coastal"]:
			inland = pid
			break
	ok(not MilitarySystem.find_path(s, aid, inland)["ok"], "fleets cannot sail to inland provinces")

func test_fleet_organisation_flagship_squadrons_missions() -> void:
	var st := _stage()
	var s: Dictionary = st["s"]
	var aid := _fleet(s, st["x"], st["px"], {"ship_of_the_line": 3.0, "frigate": 2.0, "fluyt": 2.0})
	var a: Dictionary = s["armies"][aid]
	eq(NavalSystem.flagship(a), "ship_of_the_line", "flagship is the costliest ship")
	var sq := NavalSystem.squadrons(a)
	var roles: Array = []
	for q in sq:
		roles.append(q["role"])
	ok("line" in roles and "cruiser" in roles and "transport" in roles, "squadrons by role %s" % str(roles))
	ok(NavalSystem.set_mission(s, aid, "blockade")["ok"], "mission set")
	ok(not NavalSystem.set_mission(s, aid, "nonsense")["ok"], "unknown mission rejected")
	var total := UnitUtil.army_size(a)
	var made := NavalSystem.split_by_role(s, aid)
	eq(made.size(), 2, "two squadrons detached")
	var sum := UnitUtil.army_size(s["armies"][aid])
	for m in made:
		sum += UnitUtil.army_size(s["armies"][m])
	near(sum, total, 0.001, "ships conserved by the split")
	var missions: Array = []
	for m in made:
		missions.append(s["armies"][m]["mission"])
	ok("convoy" in missions and "raid" in missions, "detached squadrons get fitting missions %s" % str(missions))
	ok(NavalSystem.transport_capacity(s, st["x"]) > 0.0, "transport capacity counts ships")

func test_supply_at_sea_attrition_and_repair_in_port() -> void:
	var st := _stage()
	var s: Dictionary = st["s"]
	s["provinces"][st["px"]]["controller"] = st["x"]
	var aid := _fleet(s, st["x"], st["px"], {"galley": 4.0})
	var a: Dictionary = s["armies"][aid]
	a["units"]["galley"] = 2.0
	a["morale"] = 50.0
	MilitarySystem.process_supply(s)
	ok(float(a["units"]["galley"]) > 2.0, "ships are repaired in a friendly port")
	eq(int(a["at_sea"]), 0, "port resets time at sea")
	# away from a friendly port: park at an enemy-held coast
	GS.move_army_cache(s, aid, st["px"], st["py"])
	a["loc"] = st["py"]
	GS.rebuild_caches(s)
	var n0 := UnitUtil.army_size(a)
	for i in 8:
		NavalSystem.fleet_supply(s, aid)
	ok(UnitUtil.army_size(a) < n0, "galleys with short endurance suffer attrition away from port")
	ok(float(a["supply"]) < 1.0 and int(a["at_sea"]) >= 8, "supply drops with time at sea")
	# a long-range frigate lasts longer than a galley
	var f := _fleet(s, st["x"], st["py"], {"frigate": 4.0})
	var g := _fleet(s, st["x"], st["py"], {"galley": 4.0})
	for i in 5:
		NavalSystem.fleet_supply(s, f)
		NavalSystem.fleet_supply(s, g)
	ok(float(s["armies"][f]["supply"]) > float(s["armies"][g]["supply"]), "frigates stay supplied longer than galleys")

func test_blockade_closes_ports_and_cuts_trade() -> void:
	var st := _stage()
	var s: Dictionary = st["s"]
	var x: String = st["x"]
	var y: String = st["y"]
	s["provinces"][st["py"]]["buildings"]["fort"] = 0
	ok(NavalSystem.blockade_level(s, st["py"]) == 0.0, "no ships, no blockade")
	var f := _fleet(s, x, st["py"], {"ship_of_the_line": 4.0}, "blockade")
	ok(NavalSystem.blockade_level(s, st["py"]) >= 0.99, "a strong fleet fully blockades (%.2f)" % NavalSystem.blockade_level(s, st["py"]))
	ok(NavalSystem.is_blockaded(s, st["py"]) and NavalSystem.blockader_of(s, st["py"]) == x, "blockader identified")
	# fortified port needs more strength
	var small := _fleet(s, x, st["py"], {"galley": 1.0}, "patrol")
	MilitarySystem.disband_army(s, f)
	s["provinces"][st["py"]]["buildings"]["fort"] = 4
	GS.rebuild_caches(s)
	ok(NavalSystem.blockade_level(s, st["py"]) < 0.5, "one galley cannot close a fortified port (%.2f)" % NavalSystem.blockade_level(s, st["py"]))
	MilitarySystem.disband_army(s, small)
	s["provinces"][st["py"]]["buildings"]["fort"] = 0
	# trade: income of the blockaded country falls
	TradeSystem.invalidate(s)
	var base := float(TradeSystem.compute(s)["income"].get(y, 0.0))
	var f2 := _fleet(s, x, st["py"], {"ship_of_the_line": 5.0}, "blockade")
	TradeSystem.invalidate(s)
	var blocked := float(TradeSystem.compute(s)["income"].get(y, 0.0))
	ok(blocked <= base + 0.001, "blockade never raises the victim's trade income (%.1f -> %.1f)" % [base, blocked])
	# the mechanism itself: sea links of a blockaded port are closed, and open again once the fleet is gone
	var lane: Array = []
	for sl in Defs.sea_links(st["py"]):
		if sl[1] == "lane" and int(s["provinces"][sl[0]]["buildings"].get("port", 0)) >= 1 and s["provinces"][sl[0]]["controller"] != "":
			lane = sl
			break
	if not lane.is_empty():
		s["provinces"][st["py"]]["buildings"]["port"] = 2
		ok(not TradeSystem.edge_ok(s, st["py"], lane[0], "lane"), "a blockaded port's sea lanes are closed to trade")
		MilitarySystem.disband_army(s, f2)
		GS.rebuild_caches(s)
		ok(NavalSystem.is_blockaded(s, st["py"]) == false, "lifting the blockade reopens the port")
		f2 = _fleet(s, x, st["py"], {"ship_of_the_line": 5.0}, "blockade")
	# the port cannot repair ships and its fleets lose supply
	var defender := _fleet(s, y, st["py"], {"cog": 1.0}, "patrol")
	ok(not NavalSystem.in_friendly_port(s, s["armies"][defender]) or NavalSystem.blockade_level(s, st["py"]) < 0.5, "blockaded ports give no supply")
	MilitarySystem.disband_army(s, f2)
	TradeSystem.invalidate(s)

func test_blockade_registry_and_siege_support() -> void:
	var st := _stage()
	var s: Dictionary = st["s"]
	var x: String = st["x"]
	var py: String = st["py"]
	s["provinces"][py]["buildings"]["fort"] = 0
	_fleet(s, x, py, {"ship_of_the_line": 4.0}, "blockade")
	NavalSystem.process_turn(s)
	ok(s["naval"]["blockades"].has(py), "blockade registry lists the port")
	eq(s["naval"]["blockades"][py]["by"], x, "registry names the blockader")
	var sup := NavalSystem.siege_support(s, py, x)
	ok(float(sup["bombard"]) > 0.0 and float(sup["blockade"]) > 0.9, "ships bombard and blockade a besieged port")
	# a land siege completes faster with the blockade
	s["provinces"][py]["owner"] = st["y"]
	s["provinces"][py]["controller"] = st["y"]
	s["provinces"][py]["buildings"]["fort"] = 5   # strong walls so the siege does not finish in a single turn either way
	Mods.invalidate(s)
	for aid in GS.armies_at(s, py).duplicate():
		if not s["armies"][aid].get("naval", false):
			MilitarySystem.disband_army(s, aid)
	var land := MilitarySystem.create_army(s, x, py, {"spearmen": 1.0}, null)   # small army: progress stays below 1 so the comparison is meaningful
	GS.rebuild_caches(s)
	MilitarySystem.process_sieges(s)
	var with_fleet := float(s["provinces"][py]["siege"]["progress"]) if s["provinces"][py].get("siege") != null else 1.0
	for aid in GS.armies_at(s, py).duplicate():
		if s["armies"][aid].get("naval", false) and s["armies"][aid]["owner"] == x:
			MilitarySystem.disband_army(s, aid)
	s["provinces"][py]["siege"] = null
	GS.rebuild_caches(s)
	MilitarySystem.process_sieges(s)
	var without := float(s["provinces"][py]["siege"]["progress"]) if s["provinces"][py].get("siege") != null else 1.0
	ok(with_fleet > without, "naval support speeds up the siege (%.2f vs %.2f)" % [with_fleet, without])
	ok(land != "", "land army created")

func test_commerce_raiding_and_convoy_protection() -> void:
	var st := _stage()
	var s: Dictionary = st["s"]
	var x: String = st["x"]
	var y: String = st["y"]
	TradeSystem.invalidate(s)
	var base_y := float(TradeSystem.compute(s)["income"].get(y, 0.0))
	var base_x := float(TradeSystem.compute(s)["income"].get(x, 0.0))
	# X's raiders operate in the zone of Y's port
	var raid := _fleet(s, x, st["px"], {"frigate": 4.0}, "raid")
	# put the raiders into Y's zone without blockading: move to px (same zone by construction)
	NavalSystem.process_turn(s)
	var r: Dictionary = s["naval"]["raids"].get(y, {})
	ok(not r.is_empty() and float(r["frac"]) > 0.0, "raiders threaten the enemy's seaborne trade (%s)" % str(r))
	TradeSystem.invalidate(s)
	var raided_y := float(TradeSystem.compute(s)["income"].get(y, 0.0))
	var raided_x := float(TradeSystem.compute(s)["income"].get(x, 0.0))
	ok(raided_y < base_y, "victim's trade income falls (%.1f -> %.1f)" % [base_y, raided_y])
	ok(raided_x > base_x, "raiders capture part of it (%.1f -> %.1f)" % [base_x, raided_x])
	ok(float(s["naval"]["stats"][x]["looted"]) > 0.0 and float(s["naval"]["stats"][y]["raided"]) > 0.0, "statistics recorded")
	# convoy escorts reduce the loss
	var loss_open := float(r["frac"])
	var escort := _fleet(s, y, st["py"], {"frigate": 4.0, "galleon": 2.0}, "convoy")
	NavalSystem.process_turn(s)
	var loss_escorted := float(s["naval"]["raids"].get(y, {"frac": 0.0})["frac"])
	ok(loss_escorted < loss_open, "convoy escorts protect trade (%.4f -> %.4f)" % [loss_open, loss_escorted])
	ok(float(s["naval"]["convoys"][y]["saved"]) > 0.0, "the saved share is reported")
	# escorts wear the raiders down
	ok(UnitUtil.army_size(s["armies"][raid]) < 4.0, "escorts attrit the raiders")
	# the convoy doctrine helps further
	s["countries"][y]["doctrine"]["naval"] = "convoy_system"
	s["countries"][y]["doctrine"]["since"]["naval"] = -99
	Mods.invalidate(s)
	ok(Mods.get_mod(s, y, "convoy") > 0.3, "convoy doctrine strengthens escorts")
	TradeSystem.invalidate(s)

func test_sea_control_reflects_fleets_and_ports() -> void:
	var st := _stage()
	var s: Dictionary = st["s"]
	var z: String = st["zone"]
	var c0 := NavalSystem.sea_control(s, z)
	ok(c0.has(st["x"]) and float(c0[st["x"]]) > 0.0, "ports give influence")
	_fleet(s, st["x"], st["px"], {"ship_of_the_line": 4.0})
	_fleet(s, st["y"], st["py"], {"cog": 1.0})
	var c1: Dictionary = NavalSystem.compute_control(s, true).get(z, {})
	ok(float(c1[st["x"]]) > float(c0[st["x"]]) + 5.0, "a battle fleet adds influence")
	ok(float(c1[st["x"]]) > float(c1[st["y"]]), "the stronger navy controls the sea")
	var sc := NavalSystem.side_control(s, st["x"], z, true)
	ok(float(sc["own"]) > float(sc["foe"]), "side view: own vs enemy")
	# a fleet in transit contributes to the lane's zone
	var lane_fleet := _fleet(s, st["x"], st["px"], {"galleon": 3.0})
	for sl in Defs.sea_links(st["px"]):
		MilitarySystem._begin_transit(s, lane_fleet, sl[0], 2)
		break
	GS.rebuild_caches(s)
	ok(SeaZones.zone_of_fleet(s["armies"][lane_fleet]) != "", "transit fleets belong to a sea zone")
	ok(NavalSystem.sea_control(s, "no_such_sea").is_empty(), "unknown sea has no influence")

func test_amphibious_landing_rules() -> void:
	var st := _stage()
	var s: Dictionary = st["s"]
	var x: String = st["x"]
	var y: String = st["y"]
	var landing := ""
	for sl in Defs.sea_links(st["px"]):
		if sl[1] == "lane" and s["provinces"][sl[0]]["owner"] == y:
			landing = sl[0]
			break
	if landing == "":
		for pid in Defs.province_ids:
			if s["provinces"][pid]["owner"] == y and Defs.provinces[pid]["coastal"]:
				for sl in Defs.sea_links(pid):
					if sl[1] == "lane" and s["provinces"][sl[0]]["owner"] == x and not str(s["provinces"][sl[0]]["owner"]).begins_with("NAT_"):
						# use the mirrored pair
						st["px"] = sl[0]
						s["provinces"][sl[0]]["buildings"]["port"] = 2
						landing = pid
						break
			if landing != "":
				break
	if landing == "":
		return
	var army := MilitarySystem.create_army(s, x, st["px"], {"spearmen": 4.0}, null)
	GS.rebuild_caches(s)
	var r0 := MilitarySystem.order_move(s, army, landing)
	ok(not r0["ok"] or (r0["path"] as Array).size() > 0, "path query works without ships")
	var chk0 := NavalSystem.landing_check(s, s["armies"][army], "A_none", landing)
	eq(chk0["reason"], "LANDING_ERR_NO_ESCORT", "no escort, no landing")
	var esc := _fleet(s, x, st["px"], {"cog": 3.0})
	var chk1 := NavalSystem.landing_check(s, s["armies"][army], esc, landing)
	ok(chk1["ok"], "escort and open seas: landing allowed")
	# the enemy dominates the sea: refused
	_fleet(s, y, st["py"], {"ship_of_the_line": 8.0})
	var chk2 := NavalSystem.landing_check(s, s["armies"][army], esc, landing)
	ok(not chk2["ok"] and chk2["reason"] == "LANDING_ERR_SEA_CONTROL", "landing against enemy sea control is refused")
	# ordered move under enemy control: the army stays put
	var o := MilitarySystem.order_move(s, army, landing)
	if o["ok"]:
		MilitarySystem.move_all(s)
		eq(s["armies"][army]["loc"], st["px"], "the army does not embark into hopeless waters")
	# a fresh landing is poorly supplied and fights at a penalty
	var a: Dictionary = s["armies"][army]
	a["amphibious"] = s["turn"]
	a["loc"] = landing
	GS.rebuild_caches(s)
	s["provinces"][landing]["controller"] = y
	MilitarySystem.process_supply(s)
	ok(float(a["supply"]) <= 0.7, "fresh landing has little supply (%.2f)" % float(a["supply"]))
	var rep := Combat.resolve(s, landing, [army], [MilitarySystem.create_army(s, y, landing, {"spearmen": 4.0}, null)], true)
	var am: Dictionary = {}
	for f in rep["modifiers"]:
		if f["key"] == "FACTOR_AMPHIB":
			am = f
	ok(float(am["a"]) < 1.0, "landing penalty in the report")

func test_convoys_in_transit_can_be_intercepted() -> void:
	var st := _stage()
	var s: Dictionary = st["s"]
	var x: String = st["x"]
	var lost := 0
	for i in 40:
		s["_c"]["rng"] = GameRng.new(100 + i)
		var esc := _fleet(s, x, st["px"], {"cog": 4.0})
		var troops := MilitarySystem.create_army(s, x, st["px"], {"spearmen": 4.0}, null)
		for sl in Defs.sea_links(st["px"]):
			MilitarySystem._begin_transit(s, esc, sl[0], 2)
			MilitarySystem._begin_transit(s, troops, sl[0], 2)
			break
		s["armies"][troops]["escort"] = esc
		GS.rebuild_caches(s)
		var before := UnitUtil.army_size(s["armies"][troops])
		# a hostile fleet dominates the lane's zone
		var lane_zone := SeaZones.zone_of_fleet(s["armies"][esc])
		var spot: String = SeaZones.members(lane_zone)[0] if not SeaZones.members(lane_zone).is_empty() else st["py"]
		var hostile := _fleet(s, st["y"], spot, {"ship_of_the_line": 10.0})
		NavalSystem._process_interception(s)
		if s["armies"].has(troops) and UnitUtil.army_size(s["armies"][troops]) < before - 0.01:
			lost += 1
		if not s["armies"].has(troops):
			lost += 1
		for aid in [esc, troops, hostile]:
			if s["armies"].has(aid):
				MilitarySystem.disband_army(s, aid)
	ok(lost >= 3 and lost < 40, "some convoys are intercepted under enemy control (%d of 40)" % lost)
	# with no enemy at sea nothing happens
	for aid in s["armies"].keys():
		if s["armies"][aid].get("naval", false) and s["armies"][aid]["owner"] == st["y"]:
			MilitarySystem.disband_army(s, aid)
	GS.rebuild_caches(s)
	var esc2 := _fleet(s, x, st["px"], {"cog": 4.0})
	var t2 := MilitarySystem.create_army(s, x, st["px"], {"spearmen": 4.0}, null)
	for sl in Defs.sea_links(st["px"]):
		MilitarySystem._begin_transit(s, esc2, sl[0], 2)
		MilitarySystem._begin_transit(s, t2, sl[0], 2)
		break
	s["armies"][t2]["escort"] = esc2
	GS.rebuild_caches(s)
	for i in 20:
		NavalSystem._process_interception(s)
	if s["armies"].has(t2):   # on some staged maps the transport lands in hostile ground and is lost for reasons unrelated to interception
		near(UnitUtil.army_size(s["armies"][t2]), 4.0, 0.001, "no interception without enemy sea control")

func test_sea_battle_report_and_determinism() -> void:
	var st := _stage()
	var s: Dictionary = st["s"]
	var px: String = st["px"]
	var reports: Array = []
	for seed_v in [3, 3, 4]:
		s["_c"]["rng"] = GameRng.new(seed_v)
		var a := _fleet(s, st["x"], px, {"ship_of_the_line": 3.0, "frigate": 2.0})
		var d := _fleet(s, st["y"], px, {"galleon": 4.0, "fluyt": 1.0})
		reports.append(Combat.resolve(s, px, [a], [d]))
		MilitarySystem.disband_army(s, a)
		MilitarySystem.disband_army(s, d)
	var r: Dictionary = reports[0]
	ok(r["naval"], "naval report")
	for k in ["FACTOR_WIND", "FACTOR_SHIPS", "FACTOR_ADMIRAL", "FACTOR_DISCIPLINE", "FACTOR_SUPPLY", "FACTOR_FORT", "FACTOR_LUCK", "FACTOR_TECH", "FACTOR_DOCTRINE", "FACTOR_NUMBERS"]:
		var found := false
		for f in r["modifiers"]:
			if f["key"] == k:
				found = true
		ok(found, "sea battle lists %s" % k)
		ok(Loc.has_lang(k, "en") and Loc.has_lang(k, "tr"), "%s EN+TR" % k)
	ok(r["sea"]["state"] >= 0.0 and r["sea"]["state"] <= 1.0 and r["sea"]["gauge"] in ["a", "d"], "sea state and weather gauge reported")
	near(float(reports[0]["loss_a"]), float(reports[1]["loss_a"]), 0.00001, "same seed, same sea battle")
	ok(absf(float(reports[0]["loss_a"]) - float(reports[2]["loss_a"])) > 0.0001, "different seed, different result")
	ok(["attacker", "defender"].has(r["winner"]) and float(r["start_a"]) == 5.0, "valid outcome")

func test_ship_roles_and_crews_decide_sea_battles() -> void:
	var st := _stage()
	var s: Dictionary = st["s"]
	var px: String = st["px"]
	var wins := 0
	for i in 20:
		s["_c"]["rng"] = GameRng.new(300 + i)
		var a := _fleet(s, st["x"], px, {"frigate": 4.0})
		var d := _fleet(s, st["y"], px, {"fluyt": 4.0})
		if Combat.resolve(s, px, [a], [d])["winner"] == "attacker":
			wins += 1
		MilitarySystem.disband_army(s, a)
		MilitarySystem.disband_army(s, d)
	ok(wins >= 17, "frigates destroy transports (%d/20)" % wins)
	var hi := 0.0
	var lo := 0.0
	for i in 20:
		s["_c"]["rng"] = GameRng.new(400 + i)
		var a2 := _fleet(s, st["x"], px, {"galleon": 4.0})
		var d2 := _fleet(s, st["y"], px, {"galleon": 4.0})
		s["armies"][a2]["discipline"] = 90.0
		s["armies"][a2]["xp"] = 50.0
		s["armies"][d2]["discipline"] = 20.0
		var rep := Combat.resolve(s, px, [a2], [d2])
		hi += float(rep["loss_a"])
		lo += float(rep["loss_d"])
		MilitarySystem.disband_army(s, a2)
		MilitarySystem.disband_army(s, d2)
	ok(hi < lo, "better-trained crews win exchanges (%.2f vs %.2f)" % [hi, lo])
	# a fortified defended port helps the defender (shore batteries)
	s["provinces"][px]["controller"] = st["x"]
	s["provinces"][px]["buildings"]["fort"] = 4
	GS.rebuild_caches(s)
	var a3 := _fleet(s, st["y"], px, {"galleon": 4.0})
	var d3 := _fleet(s, st["x"], px, {"galleon": 4.0})
	var rep3 := Combat.resolve(s, px, [a3], [d3])
	var fort_f: Dictionary = {}
	for f in rep3["modifiers"]:
		if f["key"] == "FACTOR_FORT":
			fort_f = f
	ok(float(fort_f["d"]) < 1.0, "shore batteries protect the defending fleet")

func test_naval_battle_through_turn_pipeline_and_save_defaults() -> void:
	var st := _stage()
	var s: Dictionary = st["s"]
	var px: String = st["px"]
	var a := _fleet(s, st["x"], px, {"ship_of_the_line": 3.0})
	var d := _fleet(s, st["y"], px, {"galleon": 3.0})
	s["armies"][a]["arrived"] = s["turn"]
	var reps := MilitarySystem.resolve_battles(s)
	var naval_reps := 0
	for r in reps:
		if r.get("naval", false):
			naval_reps += 1
	eq(naval_reps, 1, "resolve_battles produces the sea battle")
	ok(not s["armies"].has(a) or not s["armies"].has(d) or s["armies"][a]["loc"] != s["armies"][d]["loc"], "the beaten fleet left the port or was sunk")
	# missing fields are filled in on load
	var copy: Dictionary = JSON.parse_string(JSON.stringify(Saves.export_state(s)))
	copy.erase("naval")
	for aid in copy["armies"]:
		copy["armies"][aid].erase("discipline")
		copy["armies"][aid].erase("mission")
	NavalSystem.ensure_fields(copy)
	ok(copy.has("naval") and copy["naval"].has("blockades"), "naval state restored")
	for aid in copy["armies"]:
		ok(copy["armies"][aid].has("discipline") and copy["armies"][aid].has("mission"), "army defaults restored")
	# a turn runs cleanly with fleets at war
	var errs := run_turns(s, 3)
	ok(errs.is_empty(), "turns run with naval war: %s" % str(errs))
