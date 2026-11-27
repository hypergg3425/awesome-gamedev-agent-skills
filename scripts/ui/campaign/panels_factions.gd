class_name PanelsFactions
extends RefCounted
## Extra tabs of the politics sheet: factions with demands, corruption and government mechanics, independence movements.

static func add_tabs(sheet: Sheet, screen: CampaignScreen) -> void:
	sheet.add_tab("factions", "FAC_TAB_FACTIONS", func(b: VBoxContainer) -> void: _factions(b))
	sheet.add_tab("movements", "FAC_TAB_MOVEMENTS", func(b: VBoxContainer) -> void: _movements(b, screen))

static func _loy_color(v: float) -> Color:
	return UI.GOOD if v >= 55.0 else (UI.WARN if v >= 35.0 else UI.BAD)

static func _factions(b: VBoxContainer) -> void:
	var s: Dictionary = Game.state
	var cid: String = Game.active_player
	var c: Dictionary = Game.pc()
	var fs := FactionsSystem.st(c)
	var top := Sheet.card(b)
	top.add_child(UI.label(Defs.gov_name(c["gov"]), "Sub"))
	var mech := str(FactionsSystem.politics_of(c).get("mech", ""))
	if mech != "":
		top.add_child(UI.label(Loc.t("GOV_MECH_" + mech.to_upper()), "Tiny", -1, true))
	Sheet.kv(top, Loc.t("FAC_TAX_CAP"), Fmt.pct(FactionsSystem.tax_cap(c)), Loc.t("FAC_TAX_CAP_TIP"), UI.WARN if float(c["tax_rate"]) > FactionsSystem.tax_cap(c) else Color("f4ecd6"))
	Sheet.kv(top, Loc.t("FAC_CORRUPTION"), "%d%%" % int(FactionsSystem.corruption(c)), Loc.t("FAC_CORRUPTION_TIP"), UI.BAD if FactionsSystem.corruption(c) > 45.0 else Color("f4ecd6"))
	var cb := UI.button(Loc.t("FAC_FIGHT_CORRUPTION"), func() -> void: Game.cmd_fight_corruption())
	cb.tooltip_text = Loc.t("FAC_FIGHT_CORRUPTION_TIP")
	top.add_child(cb)
	if fs["trans"] is Dictionary:
		top.add_child(UI.label(Loc.tf("FAC_TRANSITION", {"gov": Defs.gov_name(str(fs["trans"]["to"])), "n": maxi(0, int(fs["trans"]["until"]) - int(s["turn"]) + 1)}), "Warn", -1, true))
	if c.get("civil_war") is Dictionary and s["countries"].has(str(c["civil_war"]["with"])) and s["countries"][str(c["civil_war"]["with"])].get("alive", false):
		top.add_child(UI.label(Loc.tf("FAC_CIVIL_WAR", {"other": GS.country_name(s, str(c["civil_war"]["with"]))}), "Warn", -1, true))
	var coup := FactionsSystem.coup_chance(s, cid, c)
	if coup > 0.0:
		top.add_child(UI.label(Loc.tf("FAC_COUP_RISK", {"pct": maxi(1, int(round(coup * 100.0)))}), "Warn", -1, true))
	for fid in FactionsSystem.FACTIONS:
		var f: Dictionary = fs["f"][fid]
		var box := Sheet.card(b)
		var h := HBoxContainer.new()
		var nm := UI.label(Loc.t("FACTION_" + fid.to_upper()), "Value")
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(nm)
		h.add_child(UI.label(Loc.tf("FAC_INFLUENCE", {"pct": int(round(float(f["inf"]) * 100.0))}), "Small"))
		box.add_child(h)
		box.add_child(UI.progress(float(f["loy"]), 100.0, _loy_color(float(f["loy"])), "%s %d" % [Loc.t("FAC_LOYALTY"), int(float(f["loy"]))]))
		box.add_child(UI.label(Loc.t("FACTION_WANTS_" + fid.to_upper()), "Tiny", -1, true))
		if f["dem"] is Dictionary:
			var d: Dictionary = f["dem"]
			var val := str(int(round(float(d["value"]) * 100.0))) if str(d["type"]) in ["tax_cap", "funding_min"] else str(int(FactionsSystem.demand_cost(s, cid, d)))
			box.add_child(UI.label("%s %s  (%s)" % [Loc.t("FAC_DEMAND"), Loc.tf("FD_" + str(d["type"]).to_upper(), {"value": val}), Loc.tf("FAC_DEMAND_LEFT", {"n": maxi(0, int(d["until"]) - int(s["turn"]))})], "Small", -1, true))
			var row := HBoxContainer.new()
			var chk := FactionsSystem.can_concede(s, cid, fid)
			var grant := UI.button(Loc.t("FAC_GRANT"), func() -> void: Game.cmd_faction_concede(fid), "Primary" if chk["ok"] else "")
			grant.disabled = not chk["ok"]
			grant.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if not chk["ok"]:
				grant.tooltip_text = NoteFmt.error_text(str(chk["reason"]), chk.get("params", {}))
			row.add_child(grant)
			if fid != "court":
				var sup := UI.button(Loc.t("FAC_SUPPRESS"), func() -> void:
					Dialogs.confirm(Game.get_tree().current_scene, Loc.t("FAC_SUPPRESS"), Loc.t("FAC_SUPPRESS_CONFIRM"), func() -> void: Game.cmd_faction_suppress(fid), "", true))
				sup.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				row.add_child(sup)
			box.add_child(row)
	if not (fs["log"] as Array).is_empty():
		var lc := Sheet.card(b)
		Sheet.header(lc, Loc.t("FAC_LOG"))
		var lg: Array = fs["log"]
		for i in range(lg.size() - 1, maxi(-1, lg.size() - 9), -1):
			var it: Dictionary = lg[i]
			lc.add_child(UI.label("%s: %s" % [Loc.tf("UI_TURN_N", {"n": int(it["turn"]) + 1}), Loc.t("FAC_LOG_" + str(it["key"]).to_upper())], "Tiny", -1, true))

static func _movements(b: VBoxContainer, screen: CampaignScreen) -> void:
	var s: Dictionary = Game.state
	var cid: String = Game.active_player
	var c: Dictionary = Game.pc()
	b.add_child(UI.label(Loc.t("FAC_MOVE_INTRO"), "Small", -1, true))
	var move: Dictionary = FactionsSystem.st(c)["move"]
	var list: Array = []
	for pid in move:
		list.append([-float(move[pid]), pid])
	list.sort()
	if list.is_empty():
		b.add_child(UI.label(Loc.t("FAC_MOVE_NONE"), "Small", -1, true))
	for it in list.slice(0, 12):
		var pid: String = it[1]
		var card := Sheet.card(b)
		card.add_child(UI.button("%s  –  %d / 100" % [Defs.province_name(pid), int(-float(it[0]))], func() -> void:
			screen.mapview.focus_province(pid, 4.0)
			screen.select_province(pid), "Flat", "warning"))
		card.add_child(UI.progress(-float(it[0]), CivilWar.MOVE_FREE, UI.BAD if -float(it[0]) > CivilWar.MOVE_RISING else UI.WARN))
		var g := CivilWar.movement_growth(s, cid, pid)
		for k in g["parts"]:
			var v := float(g["parts"][k])
			if absf(v) >= 0.05:
				Sheet.kv(card, Loc.t(str(k)), UI.signed(v, 1), "", UI.color_for(-v))
	var ov := str(c.get("overlord", ""))
	if ov != "":
		var oc := Sheet.card(b)
		oc.add_child(UI.label(Loc.tf("FAC_VASSAL_NOTE", {"other": GS.country_name(s, ov), "op": int(GS.opinion(s, cid, ov))}), "Small", -1, true))
	var vs := GS.vassals_of(s, cid)
	if not vs.is_empty():
		var vc := Sheet.card(b)
		Sheet.header(vc, Loc.t("FAC_VASSALS"))
		for v in vs:
			var op := GS.opinion(s, v, cid)
			var l := UI.label("%s  ·  %s %d" % [GS.country_name(s, v), Loc.t("FAC_OPINION"), int(op)], "Small")
			l.add_theme_color_override("font_color", UI.BAD if op < -30.0 else Color("f4ecd6"))
			vc.add_child(l)
