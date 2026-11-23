class_name PanelsDiplomacy
extends RefCounted
## Diplomacy sheet: relations list, per-country actions with acceptance previews, proposals.

static var focus_cid := ""
static var _screen: CampaignScreen
static var _sheet: Sheet

static func build(sheet: Sheet, screen: CampaignScreen) -> void:
	_screen = screen
	_sheet = sheet
	sheet.add_tab("relations", "TAB_RELATIONS", func(b: VBoxContainer) -> void: _relations(b, screen))
	sheet.add_tab("proposals", "TAB_PROPOSALS", func(b: VBoxContainer) -> void: _proposals(b, screen))

static func focus_country(cid: String) -> void:
	focus_cid = cid
	if _sheet:
		_sheet.select_tab("relations")

static func _relations(b: VBoxContainer, screen: CampaignScreen) -> void:
	var s: Dictionary = Game.state
	var me: String = Game.active_player
	if focus_cid != "" and s["countries"].has(focus_cid) and s["countries"][focus_cid].get("alive", false):
		_country_detail(b, screen, focus_cid)
		return
	b.add_child(UI.label(Loc.t("DIPLO_INTRO"), "Small", -1, true))
	var list: Array = []
	for oid in GS.alive_countries(s):
		if oid == me:
			continue
		var near := DiplomacySystem.borders(s, me, oid)
		var r := GS.rel(s, me, oid) if (near or s["relations"].has(GS.rel_key(me, oid))) else {}
		var key := 0
		if GS.at_war(s, me, oid):
			key = 0
		elif not r.is_empty() and r["alliance"]:
			key = 1
		elif near:
			key = 2
		elif not r.is_empty():
			key = 3
		else:
			key = 4
		if str(oid).begins_with("NAT_"):
			key = 5
		list.append([key, -DiplomacySystem.power_score(s, oid), oid])
	list.sort()
	for it in list:
		var oid: String = it[2]
		var oc: Dictionary = s["countries"][oid]
		var h := Button.new()
		h.theme_type_variation = "Tab"
		h.custom_minimum_size = Vector2(0, 58)
		h.focus_mode = Control.FOCUS_NONE
		var hb := HBoxContainer.new()
		hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.set_anchors_preset(Control.PRESET_FULL_RECT)
		hb.offset_left = 8
		hb.offset_right = -8
		var fv := FlagView.make(oc["flag"], Util.color_from(oc["color"]), Vector2(48, 32))
		hb.add_child(fv)
		var nm := UI.label(GS.country_name(s, oid), "Value")
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		nm.clip_text = true
		hb.add_child(nm)
		var ic := _status_icons(s, me, oid)
		hb.add_child(ic)
		var op := GS.opinion(s, oid, me)
		var ol := UI.label("%+d" % int(op), "Value")
		ol.add_theme_color_override("font_color", Fmt.opinion_color(op))
		ol.custom_minimum_size = Vector2(54, 0)
		ol.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		ol.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(ol)
		h.add_child(hb)
		h.pressed.connect(func() -> void:
			Audio.sfx("ui_click")
			focus_cid = oid
			_sheet.refresh())
		b.add_child(h)

static func _status_icons(s: Dictionary, me: String, oid: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var r := GS.rel(s, me, oid)
	var tags: Array = []
	if GS.at_war(s, me, oid):
		tags.append(["war", UI.BAD])
	if r["alliance"]:
		tags.append(["alliance", UI.GOOD])
	if GS.overlord_of(s, oid) == me or GS.overlord_of(s, me) == oid:
		tags.append(["vassal", Color("7fd0c4")])
	if r["trade"]:
		tags.append(["trade_agreement", Color("8fb0e8")])
	if int(r["nap_until"]) > int(s["turn"]):
		tags.append(["nap", Color("d8d0b8")])
	if r["guarantee"].get(oid, false) or r["guarantee"].get(me, false):
		tags.append(["guarantee", Color("d8d0b8")])
	for t in tags:
		var ir := UI.icon_rect(t[0], 24, t[1])
		ir.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(ir)
	return h

static func _country_detail(b: VBoxContainer, screen: CampaignScreen, oid: String) -> void:
	var s: Dictionary = Game.state
	var me: String = Game.active_player
	var oc: Dictionary = s["countries"][oid]
	var r := GS.rel(s, me, oid)
	b.add_child(UI.button("‹ " + Loc.t("UI_BACK"), func() -> void:
		focus_cid = ""
		_sheet.refresh(), "Flat", "back"))
	var top := Sheet.card(b)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	h.add_child(FlagView.make(oc["flag"], Util.color_from(oc["color"]), Vector2(84, 56)))
	var v := VBoxContainer.new()
	v.add_child(UI.label(GS.country_name(s, oid), "Heading"))
	v.add_child(UI.label("%s – %s" % [Defs.gov_name(oc["gov"]), str(oc["ruler"]["name"])], "Small"))
	h.add_child(v)
	top.add_child(h)
	var op := GS.opinion(s, oid, me)
	top.add_child(UI.progress(op + 200.0, 400.0, Fmt.opinion_color(op), "%s %+d" % [Loc.t("DIPLO_OPINION"), int(op)]))
	Sheet.kv(top, Loc.t("DIPLO_THEIR_OPINION"), "%+d" % int(GS.opinion(s, me, oid)))
	Sheet.kv(top, Loc.t("DIPLO_TRUST"), "%d" % int(float(r["trust"])))
	Sheet.kv(top, Loc.t("C_PROVINCES"), str(GS.owned(s, oid).size()))
	Sheet.kv(top, Loc.t("C_MILITARY"), "%s %s" % [UI.fmt(AISystem.visible_strength(s, me, oid)), Loc.t("UI_REGIMENTS")] if oid in s["players"] or true else "")
	Sheet.kv(top, Loc.t("C_RELIGION"), Fmt.religion_name(oc["religion"]))
	Sheet.kv(top, Loc.t("C_INFAMY"), "%d" % int(float(oc.get("infamy", 0.0))))
	var ol := GS.overlord_of(s, oid)
	if ol != "":
		Sheet.kv(top, Loc.t("DIPLO_OVERLORD"), GS.country_name(s, ol))
	if int(r["truce_until"]) > int(s["turn"]):
		Sheet.kv(top, Loc.t("DIPLO_TRUCE"), Loc.tf("GOV_TURNS", {"n": int(r["truce_until"]) - int(s["turn"])}), "", UI.WARN)
	top.add_child(_status_icons(s, me, oid))
	# actions
	var act := Sheet.card(b)
	Sheet.header(act, Loc.t("DIPLO_ACTIONS"))
	var at_war := GS.at_war(s, me, oid)
	if at_war:
		var wid := DiplomacySystem.war_for_pair(s, me, oid)
		var wl := UI.label(Loc.tf("DIPLO_AT_WAR_WITH", {"score": int(DiplomacySystem.score_for(s, wid, me))}), "Bad", -1, true)
		act.add_child(wl)
		var pb := UI.button(Loc.t("ACT_PEACE"), func() -> void: PeaceDialog.show_peace(screen, wid, oid), "Primary", "peace")
		act.add_child(pb)
	else:
		var wb := UI.button(Loc.t("ACT_DECLARE_WAR"), func() -> void: _declare_war(screen, oid), "Primary", "war")
		act.add_child(wb)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	act.add_child(grid)
	var items := [["alliance", "alliance", not r["alliance"]], ["break_alliance", "alliance", r["alliance"]], ["nap", "nap", int(r["nap_until"]) <= int(s["turn"])],
		["defensive", "defensive", not r["defensive"] and not r["alliance"]], ["access", "access", not r["access"].get(me, false)], ["trade", "trade_agreement", not r["trade"]],
		["guarantee", "guarantee", not r["guarantee"].get(oid, false)], ["vassalize", "vassal", GS.overlord_of(s, oid) == ""], ["gift", "gift", true],
		["improve", "relations", true], ["embargo", "embargo", not r["embargo"].get(me, false)], ["transfer", "transfer", true],
		["assist", "assist", r["alliance"] and not GS.wars_of(s, me).is_empty()], ["release_vassal", "vassal", GS.overlord_of(s, oid) == me],
		["annex_vassal", "vassal", GS.overlord_of(s, oid) == me], ["coalition", "coalition", true]]
	for it in items:
		if not it[2] or (at_war and it[0] not in ["gift"]):
			continue
		var action: String = it[0]
		var btn := UI.button(Loc.t("ACT_" + action.to_upper()), func() -> void: _do_action(screen, action, oid), "", it[1])
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(btn)

static func _declare_war(screen: CampaignScreen, oid: String) -> void:
	var s: Dictionary = Game.state
	var me: String = Game.active_player
	var chk := DiplomacySystem.can_declare(s, me, oid, "conquest")
	if not chk["ok"]:
		screen.toast(NoteFmt.error_text(str(chk["reason"]), chk.get("params", {})), "warning")
		return
	var cbs := DiplomacySystem.available_cbs(s, me, oid)
	var dlg := Dialogs.custom(screen.overlay_layer, Loc.tf("WAR_DECLARE_TITLE", {"country": GS.country_name(s, oid)}), 640.0)
	var box: VBoxContainer = dlg["box"]
	box.add_child(UI.label(Loc.t("WAR_CB_HINT"), "Small", -1, true))
	for cb in cbs:
		var cb_s: String = cb
		var bt := UI.button(Loc.t("CB_" + cb_s.to_upper()), func() -> void:
			dlg["close"].call()
			Dialogs.confirm(screen.overlay_layer, Loc.t("ACT_DECLARE_WAR"), Loc.tf("WAR_CONFIRM", {"country": GS.country_name(s, oid), "cb": Loc.t("CB_" + cb_s.to_upper())}), func() -> void:
				var r := Game.cmd_declare_war(oid, cb_s)
				if r.get("ok", false):
					Audio.sfx("war_declared")
					_sheet.refresh(), Loc.t("ACT_DECLARE_WAR"), true), "Primary" if cb_s != "conquest" else "")
		box.add_child(bt)
		box.add_child(UI.label(Loc.t("CBD_" + cb_s.to_upper()), "Tiny", -1, true))

static func _do_action(screen: CampaignScreen, action: String, oid: String) -> void:
	var s: Dictionary = Game.state
	var me: String = Game.active_player
	match action:
		"gift":
			var maxg := floorf(float(Game.pc()["gold"]))
			Dialogs.amount(screen.overlay_layer, Loc.t("ACT_GIFT"), Loc.t("GIFT_HINT"), 10.0, maxf(maxg, 20.0), 10.0, minf(50.0, maxg), func(v: float) -> void:
				_apply(screen, "gift", oid, {"gold": v}), " " + Loc.t("RES_GOLD"))
			return
		"transfer":
			_transfer_dialog(screen, oid)
			return
		"coalition":
			# form a coalition against the most infamous neighbour of this country, or against the selected target
			_coalition_dialog(screen, oid)
			return
		"vassalize":
			var ev := DiplomacySystem.evaluate(s, "vassalize", me, oid, {"gold": 0.0})
			_preview_then(screen, "vassalize", oid, ev, {})
			return
	var ev2 := DiplomacySystem.evaluate(s, action, me, oid, {})
	if not ev2["ok"]:
		screen.toast(NoteFmt.error_text(str(ev2["reason"])), "warning")
		return
	_preview_then(screen, action, oid, ev2, {})

static func _preview_then(screen: CampaignScreen, action: String, oid: String, ev: Dictionary, params: Dictionary) -> void:
	var dlg := Dialogs.custom(screen.overlay_layer, Loc.t("ACT_" + action.to_upper()), 640.0)
	var box: VBoxContainer = dlg["box"]
	box.add_child(UI.label(Loc.t("ACTD_" + action.to_upper()), "Small", -1, true))
	if action not in ["break_alliance", "embargo", "improve", "release_vassal", "annex_vassal", "gift"]:
		var verdict := Loc.t("DIPLO_LIKELY_ACCEPT") if ev["accept"] else Loc.t("DIPLO_LIKELY_REFUSE")
		var vl := UI.label("%s  (%+.0f / %.0f)" % [verdict, float(ev["score"]), float(ev["threshold"])], "Good" if ev["accept"] else "Bad")
		box.add_child(vl)
		for rs in ev["reasons"]:
			var l := UI.label("%s   %s" % [Loc.t(str(rs["key"])), UI.signed(float(rs["value"]), 1)], "Small")
			l.add_theme_color_override("font_color", UI.color_for(float(rs["value"])))
			box.add_child(l)
	var h := HBoxContainer.new()
	var no := UI.button(Loc.t("UI_CANCEL"), func() -> void: dlg["close"].call())
	no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var yes := UI.button(Loc.t("DIPLO_PROPOSE") if action not in ["break_alliance", "embargo", "improve", "release_vassal", "annex_vassal"] else Loc.t("UI_CONFIRM"), func() -> void:
		dlg["close"].call()
		_apply(screen, action, oid, params), "Primary")
	yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(no)
	h.add_child(yes)
	box.add_child(h)

static func _apply(screen: CampaignScreen, action: String, oid: String, params: Dictionary) -> void:
	var r := Game.cmd_diplomacy(action, oid, params)
	if not r.get("ok", false):
		return
	if r.get("accepted", true):
		Audio.sfx("diplomacy_notify")
		screen.toast(Loc.tf("DIPLO_DONE", {"action": Loc.t("ACT_" + action.to_upper()), "country": GS.country_name(Game.state, oid)}), "diplomacy")
	else:
		Audio.sfx("ui_error")
		screen.toast(Loc.tf("DIPLO_REFUSED", {"country": GS.country_name(Game.state, oid)}), "cross")
	_sheet.refresh()

static func _transfer_dialog(screen: CampaignScreen, oid: String) -> void:
	var s: Dictionary = Game.state
	var me: String = Game.active_player
	var give: Array = []
	var want: Array = []
	var dlg := Dialogs.custom(screen.overlay_layer, Loc.t("ACT_TRANSFER"), 700.0)
	var box: VBoxContainer = dlg["box"]
	box.add_child(UI.label(Loc.t("TRANSFER_HINT"), "Small", -1, true))
	var summary := UI.label("", "Value", -1, true)
	var recompute := func() -> void:
		var ev := DiplomacySystem.evaluate(s, "transfer", me, oid, {"give": give, "want": want})
		summary.text = "%s %+.0f (%s)" % [Loc.t("DIPLO_OFFER_BALANCE"), float(ev["score"]), Loc.t("DIPLO_LIKELY_ACCEPT") if ev["accept"] else Loc.t("DIPLO_LIKELY_REFUSE")]
	box.add_child(summary)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 14)
	for side in ["give", "want"]:
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(UI.label(Loc.t("TRANSFER_" + side.to_upper()), "Sub"))
		var src := me if side == "give" else oid
		var arr: Array = give if side == "give" else want
		for pid in GS.owned(s, src):
			if s["countries"][src]["capital"] == pid:
				continue
			var cb := CheckBox.new()
			cb.text = "%s (%.0f)" % [Defs.province_name(pid), DiplomacySystem.prov_value(s, pid)]
			cb.toggled.connect(func(on: bool) -> void:
				if on:
					arr.append(pid)
				else:
					arr.erase(pid)
				recompute.call())
			v.add_child(cb)
		cols.add_child(UI.scroll(v, 260))
	box.add_child(cols)
	recompute.call()
	var yes := UI.button(Loc.t("DIPLO_PROPOSE"), func() -> void:
		dlg["close"].call()
		_apply(screen, "transfer", oid, {"give": give.duplicate(), "want": want.duplicate()}), "Primary")
	box.add_child(yes)

static func _coalition_dialog(screen: CampaignScreen, oid: String) -> void:
	var s: Dictionary = Game.state
	var dlg := Dialogs.custom(screen.overlay_layer, Loc.t("ACT_COALITION"), 640.0)
	var box: VBoxContainer = dlg["box"]
	box.add_child(UI.label(Loc.t("COALITION_HINT"), "Small", -1, true))
	var list: Array = []
	for cid in GS.alive_countries(s):
		if cid != Game.active_player and not str(cid).begins_with("NAT_") and float(s["countries"][cid].get("infamy", 0.0)) > 5.0:
			list.append([float(s["countries"][cid]["infamy"]), cid])
	list.sort_custom(func(x, y): return x[0] > y[0])
	if list.is_empty():
		box.add_child(UI.label(Loc.t("COALITION_NONE"), "Small"))
	for it in list.slice(0, 8):
		var tgt: String = it[1]
		box.add_child(UI.button("%s  (%s %d)" % [GS.country_name(s, tgt), Loc.t("C_INFAMY"), int(it[0])], func() -> void:
			dlg["close"].call()
			var r := Game.cmd_form_coalition(tgt)
			if r.get("ok", false):
				screen.toast(Loc.tf("COALITION_FORMED", {"country": GS.country_name(s, tgt)}), "coalition"), "", "coalition"))

static func _proposals(b: VBoxContainer, screen: CampaignScreen) -> void:
	var s: Dictionary = Game.state
	var me: String = Game.active_player
	var any := false
	for r in s["pending_requests"]:
		if r["to"] != me:
			continue
		any = true
		var box := Sheet.card(b)
		box.add_child(UI.label(DiplomacyPrompts.request_text(s, r), "Value", -1, true))
		var h := HBoxContainer.new()
		var no := UI.button(Loc.t("UI_DECLINE"), func() -> void:
			Game.cmd_respond_request(r["id"], false))
		no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var yes := UI.button(Loc.t("UI_ACCEPT"), func() -> void:
			Game.cmd_respond_request(r["id"], true), "Primary")
		yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(no)
		h.add_child(yes)
		box.add_child(h)
	if not any:
		b.add_child(UI.label(Loc.t("DIPLO_NO_PROPOSALS"), "Small", -1, true))
	# coalitions against us
	for k in s["coalitions"]:
		var co: Dictionary = s["coalitions"][k]
		if co["target"] == me:
			var names: Array = []
			for m in co["members"]:
				names.append(GS.country_name(s, m))
			var cb := Sheet.card(b)
			cb.add_child(UI.label(Loc.tf("COALITION_AGAINST_YOU", {"members": ", ".join(names)}), "Bad", -1, true))
