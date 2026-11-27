class_name PanelsDynasty
extends RefCounted
## Dynasty sheet: the ruling house, line of succession, regency and disputes, royal marriage proposals and claims.

static var _royal := -1

static func build(sheet: Sheet, _screen: CampaignScreen) -> void:
	sheet.add_tab("house", "DYN_TAB_HOUSE", func(b: VBoxContainer) -> void: _house(b))
	sheet.add_tab("marriage", "DYN_TAB_MARRIAGE", func(b: VBoxContainer) -> void: _marriage(b, sheet))
	sheet.add_tab("claims", "DYN_TAB_CLAIMS", func(b: VBoxContainer) -> void: _claims(b))

static func _person(parent: Control, r: Dictionary, rel: String, extra: String = "") -> void:
	var line := "%s  ·  %s  ·  %s %d" % [str(r["name"]), rel, Loc.t("C_AGE"), int(float(r["age"]))]
	parent.add_child(UI.label(line, "Value", -1, true))
	parent.add_child(UI.label("%s %d   %s %d   %s %d   ♥ %d%s" % [Loc.t("SKILL_ADM"), int(r["adm"]), Loc.t("SKILL_DIP"), int(r["dip"]), Loc.t("SKILL_MIL"), int(r["mil"]), int(float(r.get("health", 80.0))), extra], "Tiny", -1, true))

static func _house(b: VBoxContainer) -> void:
	var s: Dictionary = Game.state
	var c: Dictionary = Game.pc()
	var d := DynastySystem.st(c)
	var top := Sheet.card(b)
	top.add_child(UI.label(str(d["name"]) if str(d["name"]) != "" else Defs.gov_name(c["gov"]), "Heading"))
	top.add_child(UI.label(Loc.t("DYN_LAW_" + str(d["law"]).to_upper()), "Small", -1, true))
	if not DynastySystem.is_hereditary(c):
		top.add_child(UI.label(Loc.t("DYN_NOT_HEREDITARY"), "Small", -1, true))
	if str(c.get("union_with", "")) != "":
		top.add_child(UI.label(Loc.tf("DYN_UNION", {"other": GS.country_name(s, str(c["union_with"]))}), "Warn"))
	var rc := Sheet.card(b)
	Sheet.header(rc, Loc.t("C_RULER"))
	_person(rc, c["ruler"], Loc.t("DYN_REL_RULER"), "   ⚠" if bool(c["ruler"].get("ill", false)) else "")
	if d["consort"] is Dictionary:
		rc.add_child(UI.label("%s: %s (%d)" % [Loc.t("DYN_CONSORT"), str(d["consort"]["name"]), int(float(d["consort"]["age"]))], "Tiny", -1, true))
	if int(c.get("regency", 0)) > 0 and d["regent"] is Dictionary:
		rc.add_child(UI.label(Loc.tf("DYN_REGENT", {"name": str(d["regent"]["name"]), "n": int(c["regency"])}), "Warn", -1, true))
	var cr: Variant = d["crisis"]
	if cr is Dictionary:
		var cc := Sheet.card(b)
		Sheet.header(cc, Loc.t("DYN_DISPUTE"))
		cc.add_child(UI.label(Loc.tf("DYN_DISPUTE_TEXT", {"rival": str(cr["rival"]["name"]), "n": maxi(0, int(cr["ends"]) - int(s["turn"]))}), "Small", -1, true))
		var bo := UI.button(Loc.tf("DYN_BUY_OFF", {"cost": int(DynastySystem.crisis_cost(s, Game.active_player))}), func() -> void: Game.cmd_buy_off_rival(), "Primary")
		bo.disabled = float(c["gold"]) < DynastySystem.crisis_cost(s, Game.active_player)
		cc.add_child(bo)
	if not DynastySystem.is_hereditary(c):
		return
	var line := DynastySystem.line_of_succession(c, false)
	var lc := Sheet.card(b)
	Sheet.header(lc, Loc.t("DYN_LINE"))
	if line.is_empty():
		lc.add_child(UI.label(Loc.t("C_NO_HEIR"), "Warn", -1, true))
	var n := 0
	for r in line:
		n += 1
		var box := VBoxContainer.new()
		_person(box, r, "%d. %s" % [n, Loc.t("DYN_REL_" + str(r["rel"]).to_upper())], "")
		if str(d["law"]) == "designated":
			var rid := int(r["id"])
			var bt := UI.button(Loc.t("DYN_DESIGNATE") if int(d["designated"]) != rid else Loc.t("DYN_DESIGNATED"), func() -> void: Game.cmd_designate_heir(rid), "Primary" if int(d["designated"]) == rid else "")
			bt.disabled = int(d["designated"]) == rid
			bt.custom_minimum_size = Vector2(0, 40)
			box.add_child(bt)
		lc.add_child(box)
		lc.add_child(UI.hsep())
	if str(d["law"]) == "agnatic":
		lc.add_child(UI.label(Loc.t("DYN_AGNATIC_NOTE"), "Tiny", -1, true))

static func _marriage(b: VBoxContainer, sheet: Sheet) -> void:
	var s: Dictionary = Game.state
	var me: String = Game.active_player
	var c: Dictionary = Game.pc()
	b.add_child(UI.label(Loc.t("DYN_MARRIAGE_INTRO"), "Small", -1, true))
	var avail := DynastySystem.marriageable(c)
	if avail.is_empty():
		b.add_child(UI.label(Loc.t("DYN_NO_MARRIAGEABLE"), "Small", -1, true))
	else:
		var pick := Sheet.card(b)
		Sheet.header(pick, Loc.t("DYN_OFFER"))
		var ids: Array = []
		for r in avail:
			ids.append(int(r["id"]))
		if _royal not in ids:
			_royal = int(ids[0])
		for r in avail:
			var rid := int(r["id"])
			var bt := UI.button("%s (%d)" % [str(r["name"]), int(float(r["age"]))], func() -> void:
				_royal = rid
				sheet.refresh(), "Primary" if rid == _royal else "Tab")
			pick.add_child(bt)
		var cands := Sheet.card(b)
		Sheet.header(cands, Loc.t("DYN_COURTS"))
		var list: Array = []
		for oid in GS.alive_countries(s):
			if oid != me and DynastySystem.is_hereditary(s["countries"][oid]) and not bool(s["countries"][oid].get("native", false)):
				list.append([-DiplomacySystem.power_score(s, oid), oid])
		list.sort()
		for it in list.slice(0, 14):
			var oid: String = it[1]
			var chk := DynastySystem.can_propose_marriage(s, me, oid, _royal)
			var h := HBoxContainer.new()
			var txt := GS.country_name(s, oid)
			if chk["ok"]:
				var ev := DynastySystem.marriage_eval(s, me, oid, DynastySystem.royal_by_id(c, _royal), chk["theirs"])
				txt += "   %s: %+d / %d" % [Loc.t("DYN_SCORE"), int(ev["score"]), int(ev["threshold"])]
			var l := UI.label(txt, "Small", -1, true)
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			h.add_child(l)
			var bt := UI.button(Loc.t("DYN_PROPOSE"), func() -> void:
				var r := Game.cmd_propose_marriage(oid, _royal)
				if r.get("ok", false):
					Dialogs.info(Game.get_tree().current_scene, Loc.t("DYN_PROPOSE"), Loc.t("DYN_ACCEPTED") if r.get("accepted", false) else Loc.t("DYN_REFUSED")), "Primary" if chk["ok"] else "")
			bt.disabled = not chk["ok"]
			bt.custom_minimum_size = Vector2(120, 44)
			if not chk["ok"]:
				bt.tooltip_text = NoteFmt.error_text(str(chk["reason"]))
			h.add_child(bt)
			cands.add_child(h)
	var mc := Sheet.card(b)
	Sheet.header(mc, Loc.t("DYN_TIES"))
	var d := DynastySystem.st(c)
	if (d["marriages"] as Array).is_empty():
		mc.add_child(UI.label(Loc.t("UI_NONE"), "Small"))
	for m in d["marriages"]:
		mc.add_child(UI.label("%s  ·  %s" % [GS.country_name(s, str(m["partner"])), str(m["theirs"])], "Small", -1, true))

static func _claims(b: VBoxContainer) -> void:
	var s: Dictionary = Game.state
	var c: Dictionary = Game.pc()
	var d := DynastySystem.st(c)
	b.add_child(UI.label(Loc.t("DYN_CLAIMS_INTRO"), "Small", -1, true))
	var cc := Sheet.card(b)
	Sheet.header(cc, Loc.t("DYN_CLAIMS_OURS"))
	if (d["claims"] as Array).is_empty():
		cc.add_child(UI.label(Loc.t("UI_NONE"), "Small"))
	for cl in d["claims"]:
		cc.add_child(UI.label(Loc.tf("DYN_CLAIM_ROW", {"other": GS.country_name(s, str(cl["on"])), "n": maxi(0, int(cl["until"]) - int(s["turn"]))}), "Small", -1, true))
	var against := Sheet.card(b)
	Sheet.header(against, Loc.t("DYN_CLAIMS_AGAINST"))
	var n := 0
	for oid in GS.alive_countries(s):
		if oid != Game.active_player and DynastySystem.st(s["countries"][oid])["claims"].size() > 0:
			for cl in DynastySystem.st(s["countries"][oid])["claims"]:
				if str(cl["on"]) == Game.active_player:
					n += 1
					against.add_child(UI.label(GS.country_name(s, oid), "Small"))
	if n == 0:
		against.add_child(UI.label(Loc.t("UI_NONE"), "Small"))
