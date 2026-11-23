class_name PanelsEconomy
extends RefCounted
## Economy sheet: budget, tax & funding policy, resources / market, trade, history chart.

static func build(sheet: Sheet, screen: CampaignScreen) -> void:
	sheet.add_tab("budget", "TAB_BUDGET", func(b: VBoxContainer) -> void: _budget(b, screen))
	sheet.add_tab("resources", "TAB_RESOURCES", func(b: VBoxContainer) -> void: _resources(b, screen))
	sheet.add_tab("trade", "TAB_TRADE", func(b: VBoxContainer) -> void: _trade(b, screen))
	sheet.add_tab("history", "TAB_HISTORY", func(b: VBoxContainer) -> void: _history(b, screen))

static func _budget(b: VBoxContainer, screen: CampaignScreen) -> void:
	var s: Dictionary = Game.state
	var cid: String = Game.active_player
	var c: Dictionary = Game.pc()
	var bud: Dictionary = c.get("budget", {})
	var top := Sheet.card(b)
	var h := HBoxContainer.new()
	h.add_child(UI.stat("gold", UI.fmt(float(c["gold"])), Fmt.RES_COLOR["gold"], Loc.t("BUD_TREASURY"), "Num"))
	h.add_child(UI.stat("debt", UI.fmt(float(c["debt"])), UI.BAD if float(c["debt"]) > 0.0 else Color("f4ecd6"), Loc.t("BUD_DEBT"), "Num"))
	h.add_child(UI.stat("inflation", "%d%%" % int(float(c["inflation"]) * 100.0), Color("f4ecd6"), Loc.t("BUD_INFLATION"), "Num"))
	top.add_child(h)
	var inc := Sheet.card(b)
	Sheet.header(inc, Loc.t("BUD_INCOME"))
	for k in ["tax", "production", "trade", "export", "tribute", "loot"]:
		if float(bud.get(k, 0.0)) > 0.04 or k in ["tax", "trade"]:
			Sheet.kv(inc, Loc.t("BUD_" + k.to_upper()), "%.1f" % float(bud.get(k, 0.0)))
	Sheet.kv(inc, Loc.t("BUD_TOTAL_INCOME"), "%.1f" % float(bud.get("income", 0.0)), "", UI.GOOD)
	var exp := Sheet.card(b)
	Sheet.header(exp, Loc.t("BUD_EXPENSES"))
	for k in ["army", "navy", "buildings", "admin", "interest", "subsidy", "food_import"]:
		if float(bud.get(k, 0.0)) > 0.04 or k in ["army", "buildings", "admin"]:
			Sheet.kv(exp, Loc.t("BUD_" + k.to_upper()), "%.1f" % float(bud.get(k, 0.0)))
	Sheet.kv(exp, Loc.t("BUD_TOTAL_EXPENSES"), "%.1f" % float(bud.get("expenses", 0.0)), "", UI.BAD)
	var net := float(bud.get("net", 0.0))
	var nc := Sheet.card(b)
	Sheet.kv(nc, Loc.t("BUD_NET"), UI.signed(net, 1), "", UI.color_for(net))
	Sheet.kv(nc, Loc.t("BUD_CREDIT"), UI.fmt(EconomySystem.credit_limit(s, cid) - float(c["debt"])), Loc.t("TIP_CREDIT"))
	# policies
	var pol := Sheet.card(b)
	Sheet.header(pol, Loc.t("BUD_POLICIES"))
	var tl := UI.label("%s: %d%%" % [Loc.t("BUD_TAX_RATE"), int(float(c["tax_rate"]) * 100.0)], "Value")
	pol.add_child(tl)
	var ts := HSlider.new()
	ts.min_value = 5
	ts.max_value = 60
	ts.step = 1
	ts.value = float(c["tax_rate"]) * 100.0
	ts.custom_minimum_size = Vector2(0, 38)
	ts.tooltip_text = Loc.t("TIP_TAX_RATE")
	ts.value_changed.connect(func(v: float) -> void: tl.text = "%s: %d%%" % [Loc.t("BUD_TAX_RATE"), int(v)])
	ts.drag_ended.connect(func(changed: bool) -> void:
		if changed:
			Game.cmd_set_tax(ts.value / 100.0))
	pol.add_child(ts)
	pol.add_child(UI.label(Loc.t("BUD_TAX_HINT"), "Tiny", -1, true))
	var fl := UI.label("%s: %d%%" % [Loc.t("BUD_FUNDING"), int(float(c["army_funding"]) * 100.0)], "Value")
	pol.add_child(fl)
	var fs := HSlider.new()
	fs.min_value = 40
	fs.max_value = 100
	fs.step = 5
	fs.value = float(c["army_funding"]) * 100.0
	fs.custom_minimum_size = Vector2(0, 38)
	fs.value_changed.connect(func(v: float) -> void: fl.text = "%s: %d%%" % [Loc.t("BUD_FUNDING"), int(v)])
	fs.drag_ended.connect(func(changed: bool) -> void:
		if changed:
			Game.cmd_set_funding(fs.value / 100.0))
	pol.add_child(fs)
	pol.add_child(UI.label(Loc.t("BUD_FUNDING_HINT"), "Tiny", -1, true))
	var imp := CheckButton.new()
	imp.text = Loc.t("BUD_IMPORT_FOOD")
	imp.button_pressed = bool(c["import_food"])
	imp.toggled.connect(func(on: bool) -> void: Game.cmd_set_import_food(on))
	pol.add_child(imp)
	# investments (gold sinks with real effects)
	var inv := Sheet.card(b)
	Sheet.header(inv, Loc.t("BUD_INVEST"))
	var rb := UI.button(Loc.tf("BUD_INVEST_RESEARCH", {"cost": "%.1f" % TechSystem.invest_cost_per_point(s, cid)}), func() -> void:
		Dialogs.amount(screen.overlay_layer, Loc.t("BUD_INVEST_RESEARCH_T"), Loc.t("BUD_INVEST_RESEARCH_D"), 25.0, maxf(50.0, float(c["gold"])), 25.0, minf(100.0, float(c["gold"])), func(v: float) -> void:
			var r := TechSystem.invest(Game.state, cid, v)
			if r.get("ok", false):
				Audio.sfx("coin")
				Game.state_changed.emit()
			else:
				screen.toast(NoteFmt.error_text(str(r.get("reason", "")), r.get("params", {})), "warning"), " " + Loc.t("RES_GOLD")), "", "research")
	inv.add_child(rb)
	var ab := UI.button(Loc.t("BUD_BUY_ADMIN"), func() -> void:
		var r := EconomySystem.buy_admin(Game.state, cid, 10.0)
		if r.get("ok", false):
			Audio.sfx("coin")
			Game.state_changed.emit()
		else:
			screen.toast(NoteFmt.error_text(str(r.get("reason", "")), r.get("params", {})), "warning"), "", "admin")
	inv.add_child(ab)

static func _resources(b: VBoxContainer, screen: CampaignScreen) -> void:
	var s: Dictionary = Game.state
	var c: Dictionary = Game.pc()
	var bud: Dictionary = c.get("budget", {})
	var fc := Sheet.card(b)
	Sheet.header(fc, Loc.t("RES_FOOD"))
	Sheet.kv(fc, Loc.t("RES_PRODUCTION"), UI.fmt(float(bud.get("food_prod", 0.0))))
	Sheet.kv(fc, Loc.t("RES_CONSUMPTION"), UI.fmt(float(bud.get("food_cons", 0.0))))
	Sheet.kv(fc, Loc.t("RES_ARMY_SUPPLY"), UI.fmt(float(bud.get("food_army", 0.0))))
	Sheet.kv(fc, Loc.t("RES_STOCK"), UI.fmt(float(c["stock"]["food"])))
	var fb := float(bud.get("food_balance", 0.0))
	Sheet.kv(fc, Loc.t("RES_BALANCE"), UI.signed(fb), "", UI.color_for(fb))
	if float(c.get("food_ratio", 1.0)) < 1.0:
		fc.add_child(UI.label(Loc.tf("NOTE_FAMINE", {"pct": int((1.0 - float(c["food_ratio"])) * 100.0)}), "Bad"))
	var mc := Sheet.card(b)
	Sheet.header(mc, Loc.t("RES_MATERIALS"))
	for r in ["iron", "wood", "stone", "coal", "lux"]:
		var h := HBoxContainer.new()
		h.add_child(UI.icon_rect(Fmt.RES_ICON[r], 28, Fmt.RES_COLOR[r]))
		var l := UI.label(Loc.t("RES_" + r.to_upper()), "Value")
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
		var prod := float(bud.get("mats", {}).get(r, 0.0))
		h.add_child(UI.label("%s   (+%.1f)   %s %.1f" % [UI.fmt(float(c["stock"][r])), prod, Loc.t("RES_PRICE"), float(s["market"][r]["price"])], "Small"))
		mc.add_child(h)
	mc.add_child(UI.label(Loc.t("RES_EXPORT_HINT"), "Tiny", -1, true))
	var mk := Sheet.card(b)
	Sheet.header(mk, Loc.t("RES_MARKET"))
	for r in ["food", "iron", "wood", "stone", "coal", "lux"]:
		var m: Dictionary = s["market"][r]
		var ratio := float(m["demand"]) / maxf(float(m["supply"]), 1.0)
		var h2 := HBoxContainer.new()
		var nm := UI.label(Loc.t("RES_" + r.to_upper()), "Small")
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h2.add_child(nm)
		h2.add_child(UI.label("%.2f" % float(m["price"]), "Value"))
		var ar := UI.label("▲" if ratio > 1.05 else ("▼" if ratio < 0.95 else "■"), "Value")
		ar.add_theme_color_override("font_color", UI.BAD if ratio > 1.05 else (UI.GOOD if ratio < 0.95 else Color("d8d0b8")))
		h2.add_child(ar)
		mk.add_child(h2)

static func _trade(b: VBoxContainer, screen: CampaignScreen) -> void:
	var s: Dictionary = Game.state
	var cid: String = Game.active_player
	var t := TradeSystem.ensure(s)
	var top := Sheet.card(b)
	Sheet.kv(top, Loc.t("TRADE_INCOME"), "%.1f" % float(t["income"].get(cid, 0.0)), "", UI.GOOD)
	var own := 0.0
	var foreign := 0.0
	var hubs := {}
	for pid in GS.owned(s, cid):
		var d: Dictionary = t["by_province"].get(pid, {})
		if d.is_empty():
			continue
		if d["hub"] == "" or s["provinces"][d["hub"]]["owner"] == cid:
			own += float(d["value"])
		else:
			foreign += float(d["value"])
		hubs[d["hub"]] = float(hubs.get(d["hub"], 0.0)) + float(d["value"])
	Sheet.kv(top, Loc.t("TRADE_DOMESTIC"), "%.1f" % own)
	Sheet.kv(top, Loc.t("TRADE_FOREIGN"), "%.1f" % foreign)
	top.add_child(UI.label(Loc.t("TRADE_HINT"), "Tiny", -1, true))
	var hc := Sheet.card(b)
	Sheet.header(hc, Loc.t("TRADE_HUBS"))
	var arr: Array = []
	for hpid in hubs:
		arr.append([float(hubs[hpid]), hpid])
	arr.sort_custom(func(x, y): return x[0] > y[0])
	for i in range(mini(8, arr.size())):
		var hpid: String = arr[i][1]
		var bt := UI.button("%s  –  %.1f   (%s)" % [Defs.province_name(hpid) if hpid != "" else Loc.t("TRADE_NO_HUB"), float(arr[i][0]), GS.country_name(s, s["provinces"][hpid]["owner"]) if hpid != "" else ""], func() -> void:
			if hpid != "":
				screen.mapview.focus_province(hpid, 3.5), "Flat", "trade")
		hc.add_child(bt)
	var ac := Sheet.card(b)
	Sheet.header(ac, Loc.t("TRADE_AGREEMENTS"))
	var any := false
	for oid in GS.alive_countries(s):
		if oid != cid:
			var r := GS.rel(s, cid, oid)
			if r["trade"]:
				ac.add_child(UI.stat("trade_agreement", GS.country_name(s, oid), Color("f4ecd6"), "", "Small"))
				any = true
			if r["embargo"].get(cid, false) or r["embargo"].get(oid, false):
				ac.add_child(UI.stat("embargo", GS.country_name(s, oid) + " – " + Loc.t("ACT_EMBARGO"), UI.BAD, "", "Small"))
				any = true
	if not any:
		ac.add_child(UI.label(Loc.t("UI_NONE"), "Small"))


static func _history(b: VBoxContainer, screen: CampaignScreen) -> void:
	var c: Dictionary = Game.pc()
	var series: Array = c.get("history_income", [])
	var card := Sheet.card(b)
	Sheet.header(card, Loc.t("HIST_INCOME_TITLE"))
	card.add_child(LineChart.make(series, Fmt.RES_COLOR["gold"], 150))
	var ser: Dictionary = Game.state["stats"].get("series", {}).get(Game.active_player, {})
	if not ser.is_empty():
		for pair in [["provinces", "C_PROVINCES"], ["pop", "C_POPULATION"], ["army", "C_MILITARY"], ["tech", "C_TECH"]]:
			var c2 := Sheet.card(b)
			Sheet.header(c2, Loc.t(pair[1]))
			c2.add_child(LineChart.make(ser[pair[0]], UI.GOLD_LIGHT, 110))
