class_name PanelsNaval
extends RefCounted
## Fleets tab of the military sheet: fleet organisation (flagship, squadrons, missions), supply at sea, trade
## protection / raiding / blockades and sea control of the zones where the player has ships or ports.

static func build(b: VBoxContainer, screen: CampaignScreen) -> void:
	var s: Dictionary = Game.state
	var me: String = Game.active_player
	var sum := NavalSystem.country_summary(s, me)
	var top := Sheet.card(b)
	Sheet.header(top, Loc.t("NAV_OVERVIEW"))
	Sheet.kv(top, Loc.t("NAV_TRANSPORT"), UI.fmt(float(sum["transport"])), Loc.t("NAV_TRANSPORT_TIP"))
	Sheet.kv(top, Loc.t("NAV_MERCHANT"), "%d%%" % int(float(sum["merchant"]) * 100.0))
	Sheet.kv(top, Loc.t("NAV_RAID_LOSS"), "%.1f%%" % (float(sum["raid_loss"]) * 100.0), Loc.t("NAV_RAID_TIP"), UI.BAD if float(sum["raid_loss"]) > 0.0 else Color("f4ecd6"))
	Sheet.kv(top, Loc.t("NAV_CONVOY"), "%s  (+%.1f%%)" % [UI.fmt(float(sum["convoy_escort"])), float(sum["convoy_saved"]) * 100.0], Loc.t("NAV_CONVOY_TIP"))
	var names: Array = []
	for pid in sum["blockaded"]:
		names.append(Defs.province_name(pid))
	Sheet.kv(top, Loc.t("NAV_BLOCKADED"), ", ".join(names) if not names.is_empty() else Loc.t("NAV_NONE"), "", UI.BAD if not names.is_empty() else Color("f4ecd6"))
	var st: Dictionary = sum["stats"]
	Sheet.kv(top, Loc.t("NAV_LOOTED"), UI.fmt(float(st["looted"])))
	Sheet.kv(top, Loc.t("NAV_RAIDED"), UI.fmt(float(st["raided"])))
	_sea_control(b, s, me)
	var fleets: Array = []
	for aid in GS.armies_of(s, me):
		if bool(s["armies"][aid].get("naval", false)):
			fleets.append(aid)
	if fleets.is_empty():
		b.add_child(UI.label(Loc.t("NAV_NO_FLEETS"), "Small", -1, true))
	for aid in fleets:
		_fleet_card(b, screen, s, aid)

static func _sea_control(b: VBoxContainer, s: Dictionary, me: String) -> void:
	var rows: Array = []
	for zid in SeaZones.zone_ids():
		var sc := NavalSystem.side_control(s, me, zid)
		if float(sc["own"]) > 0.0 or float(sc["foe"]) > 0.0:
			rows.append([float(sc["own"]) - float(sc["foe"]), zid, sc])
	if rows.is_empty():
		return
	rows.sort_custom(func(x, y): return absf(x[0]) > absf(y[0]))
	var card := Sheet.card(b)
	Sheet.header(card, Loc.t("NAV_SEA_CONTROL"))
	for r in rows.slice(0, 8):
		var sc2: Dictionary = r[2]
		var val := "%s  /  %s" % [UI.fmt(float(sc2["own"])), UI.fmt(float(sc2["foe"]))]
		Sheet.kv(card, SeaZones.zone_name(r[1]), val, Loc.t("NAV_SEA_CONTROL_TIP"), UI.GOOD if r[0] > 0.0 else (UI.BAD if r[0] < 0.0 else Color("f4ecd6")))

static func _fleet_card(b: VBoxContainer, screen: CampaignScreen, s: Dictionary, aid: String) -> void:
	var a: Dictionary = s["armies"][aid]
	var box := Sheet.card(b)
	var h := HBoxContainer.new()
	h.add_child(UI.icon_rect("unit_naval", 30, UI.GOLD_LIGHT))
	var where := Defs.province_name(a["loc"]) if a["loc"] != "" else Loc.t("MIL_AT_SEA")
	var zone := SeaZones.zone_of_fleet(a)
	if zone != "":
		where += " (" + SeaZones.zone_name(zone) + ")"
	var l := UI.label("%s  -  %s" % [where, UI.fmt(UnitUtil.army_size(a))], "Value")
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	box.add_child(h)
	box.add_child(UI.label(Fmt.unit_comp(a), "Tiny", -1, true))
	var fl := str(a.get("flagship", NavalSystem.flagship(a)))
	if fl != "":
		Sheet.kv(box, Loc.t("NAV_FLAGSHIP"), Defs.unit_name(fl))
	var sq: Array = []
	for q in NavalSystem.squadrons(a):
		sq.append("%s %s" % [Loc.t("ROLE_" + str(q["role"]).to_upper()), UI.fmt(float(q["n"]))])
	Sheet.kv(box, Loc.t("NAV_SQUADRONS"), ", ".join(sq))
	Sheet.kv(box, Loc.t("MIL_GENERAL"), Fmt.general_text(a["general"]).replace(Loc.t("MIL_NO_GENERAL"), Loc.t("NAV_NO_ADMIRAL")))
	box.add_child(UI.progress(float(a["morale"]), 100.0, UI.GOOD if float(a["morale"]) > 55.0 else UI.WARN, "%s %d%%" % [Loc.t("MIL_MORALE"), int(a["morale"])]))
	Sheet.kv(box, Loc.t("MIL_DISCIPLINE"), "%d   %s %d" % [int(float(a.get("discipline", 50.0))), Loc.t("MIL_XP"), int(float(a["xp"]))])
	Sheet.kv(box, Loc.t("NAV_AT_SEA"), Loc.tf("NAV_AT_SEA_FMT", {"n": int(a.get("at_sea", 0)), "supply": int(float(a.get("supply", 1.0)) * 100.0)}))
	if a["transit"] != null:
		Sheet.kv(box, Loc.t("MIL_ORDERS"), Loc.tf("MIL_IN_TRANSIT", {"to": Defs.province_name(a["transit"]["to"]), "n": int(a["transit"]["left"])}))
	elif not (a["path"] as Array).is_empty():
		Sheet.kv(box, Loc.t("MIL_ORDERS"), Loc.tf("MIL_MOVING_TO", {"to": Defs.province_name(a["path"][a["path"].size() - 1])}))
	var mh := HBoxContainer.new()
	for m in NavalSystem.MISSIONS:
		var mb := UI.button(Loc.t("MISSION_" + str(m).to_upper()), func() -> void: Game.cmd_set_mission(aid, m), "Primary" if a.get("mission", "patrol") == m else "", "")
		mb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mb.tooltip_text = Loc.t("MISSION_" + str(m).to_upper() + "_TIP")
		mh.add_child(mb)
	box.add_child(mh)
	var bh := HBoxContainer.new()
	var focus := UI.button(Loc.t("UI_FOCUS"), func() -> void:
		if a["loc"] != "":
			screen.mapview.focus_province(a["loc"], 4.0)
			screen.select_province(a["loc"])
			screen.select_army(aid), "", "map")
	focus.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bh.add_child(focus)
	if NavalSystem.squadrons(a).size() >= 2 and a["loc"] != "":
		var sp := UI.button(Loc.t("NAV_SPLIT_ROLES"), func() -> void: Game.cmd_split_fleet(aid), "", "split")
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bh.add_child(sp)
	var dis := UI.button(Loc.t("MIL_DISBAND"), func() -> void:
		Dialogs.confirm(screen.overlay_layer, Loc.t("MIL_DISBAND"), Loc.t("MIL_DISBAND_CONFIRM"), func() -> void: Game.cmd_disband(aid), Loc.t("MIL_DISBAND"), true), "", "disband")
	dis.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bh.add_child(dis)
	box.add_child(bh)
	upgrade_buttons(box, s, aid)

## Unit improvement buttons shared by the army and fleet cards.
static func upgrade_buttons(box: VBoxContainer, s: Dictionary, aid: String) -> void:
	var a: Dictionary = s["armies"][aid]
	var me: String = a["owner"]
	for uid in a["units"].keys():
		var nxt := UnitUtil.upgrade_of(s, me, uid)
		if nxt == "":
			continue
		var cost := MilitarySystem.upgrade_cost(s, me, uid) * float(a["units"][uid])
		var u: String = uid
		var ub := UI.button(Loc.tf("MIL_UPGRADE_BTN", {"from": Defs.unit_name(u), "to": Defs.unit_name(nxt), "cost": int(cost)}), func() -> void: Game.cmd_upgrade_units(aid, u), "", "")
		ub.disabled = float(s["countries"][me]["gold"]) < cost
		box.add_child(ub)
