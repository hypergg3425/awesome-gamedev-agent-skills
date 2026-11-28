class_name PanelsPolitics
extends RefCounted
## "Population & politics" sheet: demographic overview, religions/cultures, class power, stability factors.

static func build(sheet: Sheet, screen: CampaignScreen) -> void:
	sheet.add_tab("population", "TAB_POPULATION", func(b: VBoxContainer) -> void: _population(b, screen))
	sheet.add_tab("stability", "TAB_STABILITY", func(b: VBoxContainer) -> void: _stability(b, screen))
	PanelsFactions.add_tabs(sheet, screen)

static func _population(b: VBoxContainer, screen: CampaignScreen) -> void:
	var s: Dictionary = Game.state
	var cid: String = Game.active_player
	var total := 0.0
	var by_rel := {}
	var by_cul := {}
	var urban := 0.0
	var lit := 0.0
	var disease := 0
	var growth_cap := 0.0
	for pid in GS.owned(s, cid):
		var p: Dictionary = s["provinces"][pid]
		var pop := float(p["pop"])
		total += pop
		by_rel[p["religion"]] = float(by_rel.get(p["religion"], 0.0)) + pop
		by_cul[p["culture"]] = float(by_cul.get(p["culture"], 0.0)) + pop
		urban += float(p["urban"]) * pop
		lit += float(p["literacy"]) * pop
		growth_cap += PopulationSystem.pop_cap(s, pid)
		if float(p["disease"]) > 1.0:
			disease += 1
	var top := Sheet.card(b)
	Sheet.kv(top, Loc.t("C_POPULATION"), UI.fmt(total * 1000.0))
	Sheet.kv(top, Loc.t("POP_URBAN"), Fmt.pct(urban / maxf(total, 1.0)))
	Sheet.kv(top, Loc.t("POP_LITERACY"), Fmt.pct(lit / maxf(total, 1.0)))
	Sheet.kv(top, Loc.t("POP_CAPACITY"), Fmt.pct(total / maxf(growth_cap, 1.0)), Loc.t("TIP_POP_CAP"))
	Sheet.kv(top, Loc.t("POP_OUTBREAKS"), str(disease), "", UI.BAD if disease > 0 else Color("f4ecd6"))
	Sheet.kv(top, Loc.t("C_MANPOWER"), "%s / %s" % [UI.fmt(float(Game.pc()["manpower"])), UI.fmt(float(Game.pc()["manpower_max"]))])
	for pair in [["POP_RELIGIONS", by_rel, "REL_"], ["POP_CULTURES", by_cul, "CULT_"]]:
		var box := Sheet.card(b)
		Sheet.header(box, Loc.t(pair[0]))
		var arr: Array = []
		for k in pair[1]:
			arr.append([float(pair[1][k]), k])
		arr.sort_custom(func(x, y): return x[0] > y[0])
		for it in arr:
			var nm: String = Loc.t(pair[2] + str(it[1]).to_upper()) if Loc.has_key(pair[2] + str(it[1]).to_upper()) else str(it[1])
			box.add_child(UI.progress(float(it[0]), total, UI.GOLD, "%s  %s" % [nm, Fmt.pct(float(it[0]) / maxf(total, 1.0))]))
	var pl := Sheet.card(b)
	Sheet.header(pl, Loc.t("POP_PROVINCES"))
	var arr2: Array = []
	for pid in GS.owned(s, cid):
		arr2.append([float(s["provinces"][pid]["pop"]), pid])
	arr2.sort_custom(func(x, y): return x[0] > y[0])
	for it in arr2.slice(0, 12):
		var pid2: String = it[1]
		pl.add_child(UI.button("%s  –  %s" % [Defs.province_name(pid2), UI.fmt(float(it[0]) * 1000.0)], func() -> void:
			screen.mapview.focus_province(pid2, 4.0)
			screen.select_province(pid2), "Flat", "population"))

static func _stability(b: VBoxContainer, screen: CampaignScreen) -> void:
	var s: Dictionary = Game.state
	var cid: String = Game.active_player
	var c: Dictionary = Game.pc()
	var top := Sheet.card(b)
	top.add_child(UI.progress(float(c["stability"]), 100.0, UI.GOOD if float(c["stability"]) > 55.0 else (UI.WARN if float(c["stability"]) > 35.0 else UI.BAD), "%s %d" % [Loc.t("C_STABILITY"), int(c["stability"])]))
	top.add_child(UI.progress(float(c["legitimacy"]), 100.0, UI.GOLD, "%s %d" % [Loc.t("C_LEGITIMACY"), int(c["legitimacy"])]))
	top.add_child(UI.progress(float(c["war_exhaustion"]), 100.0, UI.BAD, "%s %d" % [Loc.t("WAR_EXHAUSTION"), int(c["war_exhaustion"])]))
	var fac := Sheet.card(b)
	Sheet.header(fac, Loc.t("STAB_FACTORS"))
	var m := Mods.country(s, cid)
	Sheet.kv(fac, Loc.t("STAB_FACTION"), "%.0f" % float(c.get("faction_sat", 50.0)))
	Sheet.kv(fac, Loc.t("STAB_GOV"), UI.signed(float(m.get("stability", 0.0)) * 3.0, 0))
	Sheet.kv(fac, Loc.t("STAB_WAR"), UI.signed(-float(c["war_exhaustion"]) * 0.2, 1))
	var ac := EconomySystem.admin_capacity(s, cid)
	Sheet.kv(fac, Loc.t("STAB_OVEREXT"), UI.signed(-float(ac["overextension"]) * 18.0, 1))
	Sheet.kv(fac, Loc.t("STAB_PRESTIGE"), UI.signed(clampf(float(c["prestige"]) / 60.0, -5.0, 8.0), 1))
	if not c.get("lux_ok", true):
		Sheet.kv(fac, Loc.t("STAB_LUXURY"), "-2", "", UI.BAD)
	if float(c.get("food_ratio", 1.0)) < 1.0:
		Sheet.kv(fac, Loc.t("STAB_HUNGER"), UI.signed(-(1.0 - float(c["food_ratio"])) * 25.0, 0), "", UI.BAD)
	var advice := Sheet.card(b)
	Sheet.header(advice, Loc.t("STAB_ADVICE"))
	var tips := 0
	if float(c["tax_rate"]) > 0.32:
		advice.add_child(UI.label("• " + Loc.t("ADV_TAXES"), "Small", -1, true))
		tips += 1
	if float(ac["ratio"]) > 1.0:
		advice.add_child(UI.label("• " + Loc.t("ADV_OVEREXT"), "Small", -1, true))
		tips += 1
	if float(c["war_exhaustion"]) > 40.0:
		advice.add_child(UI.label("• " + Loc.t("ADV_WAR"), "Small", -1, true))
		tips += 1
	if float(c.get("food_ratio", 1.0)) < 1.0:
		advice.add_child(UI.label("• " + Loc.t("ADV_FOOD"), "Small", -1, true))
		tips += 1
	if tips == 0:
		advice.add_child(UI.label(Loc.t("ADV_NONE"), "Small", -1, true))
