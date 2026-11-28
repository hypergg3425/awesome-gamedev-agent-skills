class_name PanelsEconomy2
extends RefCounted
## Extra tabs of the economy sheet: credit and debt, economic cycle, regions (employment, urbanisation, industry,
## specialisation), shortages and market prices.

static func add_tabs(sheet: Sheet, _screen: CampaignScreen) -> void:
	sheet.add_tab("credit", "ECO_TAB_CREDIT", func(b: VBoxContainer) -> void: _credit(b))
	sheet.add_tab("regions", "ECO_TAB_REGIONS", func(b: VBoxContainer) -> void: _regions(b))

static func _credit(b: VBoxContainer) -> void:
	var s: Dictionary = Game.state
	var cid: String = Game.active_player
	var c: Dictionary = Game.pc()
	var e := EconomyDepth.st(c)
	var top := Sheet.card(b)
	top.add_child(UI.label(Loc.t("ECO_CREDIT_INTRO"), "Small", -1, true))
	var rating := str(e["rating"])
	Sheet.kv(top, Loc.t("ECO_RATING"), "%s  (%d)" % [rating, int(float(e["score"]))], Loc.t("ECO_RATING_TIP"), UI.GOOD if rating in ["A", "B"] else UI.BAD)
	Sheet.kv(top, Loc.t("ECO_INTEREST"), "%.1f%%" % (EconomySystem.interest_rate(s, cid) * 100.0), Loc.t("ECO_INTEREST_TIP"))
	Sheet.kv(top, Loc.t("BUD_DEBT"), UI.fmt(float(c["debt"])))
	Sheet.kv(top, Loc.t("ECO_CREDIT_ROOM"), UI.fmt(EconomyDepth.loan_room(s, cid)))
	Sheet.kv(top, Loc.t("ECO_PHASE"), Loc.t("ECO_PHASE_" + str(e["phase"]).to_upper()), "", UI.GOOD if str(e["phase"]) == "boom" else (UI.BAD if str(e["phase"]) in ["slump", "crisis"] else Color("f4ecd6")))
	if str(e["cause"]) != "":
		Sheet.kv(top, Loc.t("ECO_CAUSE"), Loc.t("ECO_CAUSE_" + str(e["cause"]).to_upper()))
	var act := Sheet.card(b)
	Sheet.header(act, Loc.t("ECO_LOANS"))
	var row := HFlowContainer.new()
	for amt in [50, 100, 250]:
		var a: int = amt
		var bt := UI.button(Loc.tf("ECO_BORROW", {"n": a}), func() -> void: Game.cmd_take_loan(float(a)))
		bt.disabled = EconomyDepth.loan_room(s, cid) < float(a)
		row.add_child(bt)
	for amt in [50, 100, 250]:
		var a2: int = amt
		var bt2 := UI.button(Loc.tf("ECO_REPAY", {"n": a2}), func() -> void: Game.cmd_repay_debt(float(a2)))
		bt2.disabled = float(c["debt"]) <= 0.0 or float(c["gold"]) < 1.0
		row.add_child(bt2)
	act.add_child(row)
	var lg: Array = e["log"]
	if not lg.is_empty():
		var hc := Sheet.card(b)
		Sheet.header(hc, Loc.t("ECO_HISTORY"))
		for i in range(lg.size() - 1, maxi(-1, lg.size() - 7), -1):
			hc.add_child(UI.label("%s: %s (%s)" % [Loc.tf("UI_TURN_N", {"n": int(lg[i]["turn"]) + 1}), Loc.t("ECO_PHASE_" + str(lg[i]["phase"]).to_upper()), Loc.t("ECO_CAUSE_" + str(lg[i]["cause"]).to_upper())], "Tiny", -1, true))

static func _regions(b: VBoxContainer) -> void:
	var s: Dictionary = Game.state
	var cid: String = Game.active_player
	var c: Dictionary = Game.pc()
	var st := EconomyDepth.country_stats(s, cid)
	var top := Sheet.card(b)
	Sheet.kv(top, Loc.t("ECO_EMPLOYMENT"), Fmt.pct(float(st["employment"])), Loc.t("ECO_EMPLOYMENT_TIP"), UI.GOOD if float(st["employment"]) > 0.85 else UI.WARN)
	Sheet.kv(top, Loc.t("ECO_URBANISATION"), Fmt.pct(float(st["urbanisation"])))
	Sheet.kv(top, Loc.t("ECO_INDUSTRY"), "%.1f / 10" % float(st["industrial"]), Loc.t("ECO_INDUSTRY_TIP"))
	var sp := Sheet.card(b)
	Sheet.header(sp, Loc.t("ECO_SPECIALISATION"))
	if (st["specs"] as Dictionary).is_empty():
		sp.add_child(UI.label(Loc.t("UI_NONE"), "Small"))
	for k in Util.sorted_keys(st["specs"]):
		Sheet.kv(sp, Loc.t("ECO_SPEC_" + str(k).to_upper()), str(int(st["specs"][k])), Loc.t("ECO_SPEC_TIP"))
	var sh: Dictionary = EconomyDepth.st(c)["shortage"]
	var shc := Sheet.card(b)
	Sheet.header(shc, Loc.t("ECO_SHORTAGES"))
	if sh.is_empty():
		shc.add_child(UI.label(Loc.t("ECO_NO_SHORTAGE"), "Small"))
	for k in Util.sorted_keys(sh):
		var l := UI.label("%s: %s" % [Loc.t("RES_" + str(k).to_upper()), Loc.t("ECO_SHORT_" + str(k).to_upper())], "Small", -1, true)
		l.add_theme_color_override("font_color", UI.BAD)
		shc.add_child(l)
	var mk := Sheet.card(b)
	Sheet.header(mk, Loc.t("ECO_MARKET"))
	for k in ["food", "iron", "wood", "stone", "coal", "lux"]:
		var m: Dictionary = s["market"][k]
		var base := float(EconomySystem.BASE_PRICE[k])
		var rel := float(m["price"]) / base - 1.0
		Sheet.kv(mk, Loc.t("RES_" + str(k).to_upper()), "%.2f  (%s%%)" % [float(m["price"]), UI.signed(rel * 100.0, 0)], "", UI.color_for(-rel))
	Sheet.kv(mk, Loc.t("ECO_PRICE_INDEX"), "%.2f" % EconomyDepth.price_index(s))
