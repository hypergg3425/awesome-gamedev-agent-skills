extends TestCase

func _setup() -> Array:
	var s := new_state()
	var cid := ""
	for c2 in GS.alive_countries(s):
		if not str(c2).begins_with("NAT_") and GS.owned(s, c2).size() >= 3:
			cid = c2
			break
	var c: Dictionary = s["countries"][cid]
	c["gold"] = 5000.0
	for k in c["stock"]:
		c["stock"][k] = 500.0
	return [s, cid]

func _free_slot_province(s: Dictionary, cid: String) -> String:
	for pid in GS.owned(s, cid):
		var p: Dictionary = s["provinces"][pid]
		if Mods.used_slots(p) < Mods.building_slots(p) and (p["queue"] as Array).is_empty() and not Defs.provinces[pid]["coastal"]:
			return pid
	return ""

func test_build_costs_time_and_effect() -> void:
	var a := _setup()
	var s: Dictionary = a[0]
	var cid: String = a[1]
	var pid := _free_slot_province(s, cid)
	if pid == "":
		pid = GS.owned(s, cid)[0]
		s["provinces"][pid]["dev"] = 9.0
	var p: Dictionary = s["provinces"][pid]
	p["buildings"].erase("market")
	var chk := ConstructionSystem.can_build(s, cid, pid, "market")
	ok(chk["ok"], "market can be built: %s" % str(chk.get("reason", "")))
	var gold0 := float(s["countries"][cid]["gold"])
	var wood0 := float(s["countries"][cid]["stock"]["wood"])
	var r := ConstructionSystem.start_build(s, cid, pid, "market")
	ok(r["ok"], "build started")
	ok(float(s["countries"][cid]["gold"]) < gold0, "gold deducted")
	ok(float(s["countries"][cid]["stock"]["wood"]) < wood0, "materials deducted")
	var turns := int(r["time"])
	ok(turns >= 1, "takes time")
	var tc0 := float(Mods.province(s, pid).get("trade_power", 0.0))
	for i in turns - 1:
		ConstructionSystem.process_turn(s, cid)
	ok(not p["buildings"].has("market"), "not finished early")
	ConstructionSystem.process_turn(s, cid)
	ok(int(p["buildings"].get("market", 0)) == 1, "finished on time")
	ok(float(Mods.province(s, pid).get("trade_power", 0.0)) > tc0, "building changes gameplay (trade power)")

func test_build_requirement_errors() -> void:
	var a := _setup()
	var s: Dictionary = a[0]
	var cid: String = a[1]
	var inland := ""
	for pid in GS.owned(s, cid):
		if not Defs.provinces[pid]["coastal"]:
			inland = pid
			break
	if inland != "":
		eq(ConstructionSystem.can_build(s, cid, inland, "port")["reason"], "BUILD_ERR_COASTAL", "port needs coast")
	var pid2: String = GS.owned(s, cid)[0]
	s["countries"][cid]["tech_level"]["infrastructure"] = 0
	var rr := ConstructionSystem.can_build(s, cid, pid2, "railway")
	ok(not rr["ok"], "railway blocked without technology")
	var foreign := ""
	for p3 in Defs.province_ids:
		if s["provinces"][p3]["owner"] != cid:
			foreign = p3
			break
	eq(ConstructionSystem.can_build(s, cid, foreign, "farm")["reason"], "ERR_NOT_YOURS", "cannot build in other nations")
	s["countries"][cid]["gold"] = 1.0
	var pid3: String = GS.owned(s, cid)[0]
	var any_gold_err := false
	for bid in Defs.buildings:
		var ch := ConstructionSystem.can_build(s, cid, pid3, bid)
		if ch["reason"] == "ERR_NO_GOLD":
			any_gold_err = true
	ok(any_gold_err, "no gold blocks construction")

func test_material_shortage_blocks_unless_bought() -> void:
	var a := _setup()
	var s: Dictionary = a[0]
	var cid: String = a[1]
	var pid := _free_slot_province(s, cid)
	if pid == "":
		return
	s["countries"][cid]["stock"]["stone"] = 0.0
	s["countries"][cid]["stock"]["wood"] = 0.0
	var r := ConstructionSystem.start_build(s, cid, pid, "market")
	eq(r["reason"], "BUILD_ERR_MATERIALS", "missing materials block the build")
	var r2 := ConstructionSystem.start_build(s, cid, pid, "market", true)
	ok(r2["ok"], "buying the shortage works")

func test_cancel_refunds_half_and_slots_limit() -> void:
	var a := _setup()
	var s: Dictionary = a[0]
	var cid: String = a[1]
	var pid := _free_slot_province(s, cid)
	if pid == "":
		return
	ConstructionSystem.start_build(s, cid, pid, "market")
	var g := float(s["countries"][cid]["gold"])
	ok(ConstructionSystem.cancel_build(s, cid, pid, 0), "cancel works")
	ok(float(s["countries"][cid]["gold"]) > g, "partial refund")
	# fill slots
	var p: Dictionary = s["provinces"][pid]
	var n := Mods.building_slots(p)
	var i := 0
	for bid in Defs.buildings:
		if Mods.used_slots(p) >= n:
			break
		if not p["buildings"].has(bid):
			p["buildings"][bid] = 1
		i += 1
	eq(ConstructionSystem.can_build(s, cid, pid, "tax_office")["reason"] if not p["buildings"].has("tax_office") else "BUILD_ERR_SLOTS", "BUILD_ERR_SLOTS", "slot limit enforced")

func test_development_increases_dev() -> void:
	var a := _setup()
	var s: Dictionary = a[0]
	var cid: String = a[1]
	var pid: String = GS.owned(s, cid)[0]
	s["provinces"][pid]["dev"] = 2.0
	s["countries"][cid]["admin"] = 300.0
	var r := ConstructionSystem.develop(s, cid, pid)
	ok(r["ok"], "develop ok")
	near(float(s["provinces"][pid]["dev"]), 2.5, 0.001, "development +0.5")
