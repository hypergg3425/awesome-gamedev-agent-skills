class_name PeaceDialog
extends RefCounted
## Peace negotiation window: white peace, demands (when winning) or concessions (when losing).

static func show_peace(screen: CampaignScreen, wid: String, foe: String) -> void:
	var s: Dictionary = Game.state
	var me: String = Game.active_player
	var w: Dictionary = s["wars"][wid]
	var lead := DiplomacySystem.score_for(s, wid, me)
	var winning := lead > 0.0
	var dlg := Dialogs.custom(screen.overlay_layer, Loc.tf("PEACE_TITLE", {"country": GS.country_name(s, foe)}), 760.0)
	var box: VBoxContainer = dlg["box"]
	box.add_child(UI.progress(lead + 100.0, 200.0, UI.GOOD if winning else UI.BAD, "%s %+d" % [Loc.t("WAR_SCORE"), int(lead)]))
	var chosen: Array = []
	var gold_amt := [0.0]
	var vassal := [false]
	var result := UI.label("", "Value", -1, true)
	var reasons_box := VBoxContainer.new()
	var evaluate := func() -> Dictionary:
		var terms := {"provinces": chosen.duplicate(), "gold": gold_amt[0], "vassalize": vassal[0], "white": chosen.is_empty() and gold_amt[0] <= 0.0 and not vassal[0]}
		var ev: Dictionary
		if winning or terms["white"]:
			ev = DiplomacySystem.peace_eval(s, wid, me, foe, terms)
		else:
			ev = DiplomacySystem.concession_eval(s, wid, me, foe, terms)
		var cost := DiplomacySystem.terms_cost(s, me if winning else foe, foe if winning else me, terms) if not terms["white"] else 0.0
		result.text = "%s  (%s %.0f)" % [Loc.t("DIPLO_LIKELY_ACCEPT") if ev["accept"] else Loc.t("DIPLO_LIKELY_REFUSE"), Loc.t("PEACE_COST"), cost]
		result.add_theme_color_override("font_color", UI.GOOD if ev["accept"] else UI.BAD)
		UI.clear(reasons_box)
		for rs in ev["reasons"]:
			var l := UI.label("%s   %s" % [Loc.t(str(rs["key"])), UI.signed(float(rs["value"]), 1)], "Tiny")
			l.add_theme_color_override("font_color", UI.color_for(float(rs["value"])))
			reasons_box.add_child(l)
		return {"terms": terms, "ev": ev}
	box.add_child(UI.label(Loc.t("PEACE_HINT_WIN") if winning else Loc.t("PEACE_HINT_LOSE"), "Small", -1, true))
	var scroll_box := VBoxContainer.new()
	scroll_box.add_theme_constant_override("separation", 4)
	box.add_child(UI.scroll(scroll_box, 220))
	var src := foe if winning else me
	scroll_box.add_child(UI.label(Loc.t("PEACE_PROVINCES_WIN") if winning else Loc.t("PEACE_PROVINCES_LOSE"), "Sub"))
	for pid in GS.owned(s, src):
		if s["countries"][src]["capital"] == pid and not winning:
			continue
		var p: Dictionary = s["provinces"][pid]
		var cb := CheckBox.new()
		var tag := ""
		if p["controller"] == me:
			tag = " ✓" + Loc.t("PEACE_OCCUPIED")
		elif p["controller"] == foe:
			tag = " ✗"
		cb.text = "%s  (%.0f)%s" % [Defs.province_name(pid), DiplomacySystem.prov_value(s, pid) * 0.9, tag]
		cb.toggled.connect(func(on: bool) -> void:
			if on:
				chosen.append(pid)
			else:
				chosen.erase(pid)
			evaluate.call())
		scroll_box.add_child(cb)
	if winning:
		var gb := CheckBox.new()
		var tgt := minf(float(s["countries"][foe]["gold"]) * 0.6, 400.0)
		gb.text = Loc.tf("PEACE_GOLD", {"gold": int(tgt)})
		gb.toggled.connect(func(on: bool) -> void:
			gold_amt[0] = tgt if on else 0.0
			evaluate.call())
		scroll_box.add_child(gb)
		var vb := CheckBox.new()
		vb.text = Loc.t("PEACE_VASSALIZE")
		vb.toggled.connect(func(on: bool) -> void:
			vassal[0] = on
			evaluate.call())
		scroll_box.add_child(vb)
	box.add_child(result)
	box.add_child(reasons_box)
	var h := HBoxContainer.new()
	var no := UI.button(Loc.t("UI_CANCEL"), func() -> void: dlg["close"].call())
	no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var yes := UI.button(Loc.t("PEACE_SEND"), func() -> void:
		var r: Dictionary = evaluate.call()
		var terms: Dictionary = r["terms"]
		var res: Dictionary
		if winning or terms["white"]:
			res = Game.cmd_peace(wid, foe, terms)
		else:
			res = Game.cmd_concede(wid, foe, terms)
		if res.get("accepted", false):
			dlg["close"].call()
			Audio.sfx("peace_bell")
			screen.toast(Loc.tf("PEACE_MADE", {"country": GS.country_name(Game.state, foe)}), "peace")
		else:
			Audio.sfx("ui_error")
			screen.toast(Loc.t("PEACE_REFUSED"), "cross"), "Primary", "peace")
	yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(no)
	h.add_child(yes)
	box.add_child(h)
	evaluate.call()
