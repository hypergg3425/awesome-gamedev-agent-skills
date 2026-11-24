class_name PanelsCountry
extends RefCounted
## Country sheet: overview, society (classes / factions), government (reforms and transitions).

static func build(sheet: Sheet, screen: CampaignScreen) -> void:
	sheet.add_tab("overview", "TAB_OVERVIEW", func(b: VBoxContainer) -> void: _overview(b, screen))
	sheet.add_tab("society", "TAB_SOCIETY", func(b: VBoxContainer) -> void: _society(b, screen))
	sheet.add_tab("government", "TAB_GOVERNMENT", func(b: VBoxContainer) -> void: _government(b, screen))

static func _overview(b: VBoxContainer, screen: CampaignScreen) -> void:
	var s: Dictionary = Game.state
	var cid: String = Game.active_player
	var c: Dictionary = s["countries"][cid]
	var top := Sheet.card(b)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	h.add_child(FlagView.make(c["flag"], Util.color_from(c["color"]), Vector2(96, 64)))
	var v := VBoxContainer.new()
	v.add_child(UI.label(GS.country_name(s, cid), "Heading"))
	v.add_child(UI.stat("g_" + str(c["gov"]), Defs.gov_name(c["gov"]), Color("f4ecd6"), "", "Value"))
	h.add_child(v)
	top.add_child(h)
	if bool(c.get("approximate", false)):
		top.add_child(UI.label(Loc.t("C_APPROX") + (": " + Loc.tx(c.get("note", {})) if c.get("note", {}) is Dictionary and not (c["note"] as Dictionary).is_empty() else ""), "Small", -1, true))
	var ru: Dictionary = c["ruler"]
	var rc := Sheet.card(b)
	Sheet.header(rc, Loc.t("C_RULER"))
	Sheet.kv(rc, Loc.t("C_NAME"), "%s %s" % [str(ru["name"]), ("(" + str(c["dynasty"]) + ")") if str(c["dynasty"]) != "" else ""])
	Sheet.kv(rc, Loc.t("C_AGE"), str(int(float(ru["age"]))))
	Sheet.kv(rc, Loc.t("SKILL_ADM"), "%d" % int(ru["adm"]), Loc.t("TIP_SKILL_ADM"))
	Sheet.kv(rc, Loc.t("SKILL_DIP"), "%d" % int(ru["dip"]), Loc.t("TIP_SKILL_DIP"))
	Sheet.kv(rc, Loc.t("SKILL_MIL"), "%d" % int(ru["mil"]), Loc.t("TIP_SKILL_MIL"))
	if c["heir"] != null:
		Sheet.kv(rc, Loc.t("C_HEIR"), "%s (%d)" % [str(c["heir"]["name"]), int(float(c["heir"]["age"]))])
	elif "succession_crisis" in Defs.governments[c["gov"]].get("features", []):
		var w := UI.label(Loc.t("C_NO_HEIR"), "Warn")
		rc.add_child(w)
	if int(c.get("regency", 0)) > 0:
		rc.add_child(UI.label(Loc.tf("C_REGENCY", {"n": int(c["regency"])}), "Warn"))
	var st := Sheet.card(b)
	Sheet.header(st, Loc.t("C_STATE"))
	var bud: Dictionary = c.get("budget", {})
	Sheet.kv(st, Loc.t("C_PROVINCES"), str(GS.owned(s, cid).size()))
	Sheet.kv(st, Loc.t("C_POPULATION"), UI.fmt(DiplomacySystem.total_pop(s, cid) * 1000.0))
	Sheet.kv(st, Loc.t("C_RELIGION"), Fmt.religion_name(c["religion"]))
	Sheet.kv(st, Loc.t("C_INCOME"), UI.signed(float(bud.get("net", 0.0)), 1), "", UI.color_for(float(bud.get("net", 0.0))))
	Sheet.kv(st, Loc.t("C_MILITARY"), "%s %s" % [UI.fmt(UnitUtil.country_regiments(s, cid)), Loc.t("UI_REGIMENTS")])
	Sheet.kv(st, Loc.t("C_TECH"), "%.1f / 4" % TechSystem.avg_level(c))
	Sheet.kv(st, Loc.t("C_STABILITY"), "%d" % int(c["stability"]))
	Sheet.kv(st, Loc.t("C_LEGITIMACY"), "%d" % int(c["legitimacy"]))
	Sheet.kv(st, Loc.t("C_PRESTIGE"), UI.fmt(float(c["prestige"])))
	Sheet.kv(st, Loc.t("C_INFAMY"), "%d" % int(float(c.get("infamy", 0.0))), Loc.t("TIP_INFAMY"), UI.BAD if float(c.get("infamy", 0.0)) > 30.0 else Color("f4ecd6"))
	var ac := EconomySystem.admin_capacity(s, cid)
	Sheet.kv(st, Loc.t("C_ADMIN_CAP"), "%.0f / %.0f" % [float(ac["used"]), float(ac["cap"])], Loc.t("TIP_ADMIN_CAP"), UI.BAD if float(ac["ratio"]) > 1.0 else Color("f4ecd6"))
	var mods := Mods.country(s, cid)
	var mc := Sheet.card(b)
	Sheet.header(mc, Loc.t("C_MODIFIERS"))
	var shown := 0
	var keys := mods.keys()
	keys.sort()
	for k in keys:
		if str(k) in ["cost_inflation"] or absf(float(mods[k])) < 0.004:
			continue
		var line := Fmt.mod_line(str(k), float(mods[k]))
		var l := UI.label(line, "Small")
		l.add_theme_color_override("font_color", UI.GOOD if (float(mods[k]) > 0.0) != (str(k) in ["army_upkeep", "corruption", "unrest", "war_exhaustion", "recruit_cost", "build_cost", "interest", "attrition", "reform_cost"]) else UI.BAD)
		mc.add_child(l)
		shown += 1
	if shown == 0:
		mc.add_child(UI.label(Loc.t("UI_NONE"), "Small"))
	for t in c.get("traditions", []):
		mc.add_child(UI.label("• " + Loc.tx(t), "Tiny", -1, true))

static func _society(b: VBoxContainer, screen: CampaignScreen) -> void:
	var s: Dictionary = Game.state
	var c: Dictionary = Game.pc()
	var intro := UI.label(Loc.t("SOC_INTRO"), "Small", -1, true)
	b.add_child(intro)
	var gov: Dictionary = Defs.governments[c["gov"]]
	var targets := PoliticsSystem.class_targets(s, Game.active_player)
	for cls in Const.CLASSES:
		var cd: Dictionary = c["classes"][cls]
		var box := Sheet.card(b)
		var h := HBoxContainer.new()
		h.add_child(UI.icon_rect("c_" + cls, 30, UI.GOLD_LIGHT))
		var nm := UI.label(Loc.t("CLASS_" + cls.to_upper()), "Value")
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(nm)
		h.add_child(UI.label(Loc.tf("SOC_SHARE_POWER", {"share": Fmt.pct(float(cd.get("share", 0.0))), "power": Fmt.pct(float(cd.get("power", 0.0)))}), "Small"))
		box.add_child(h)
		var sat := float(cd["sat"])
		box.add_child(UI.progress(sat, 100.0, UI.GOOD if sat >= 55.0 else (UI.WARN if sat >= 40.0 else UI.BAD), "%s %d" % [Loc.t("SOC_SATISFACTION"), int(sat)]))
		var favor := float(gov.get("class_favor", {}).get(cls, 0))
		box.add_child(UI.label(Loc.t("CLASS_WANTS_" + cls.to_upper()), "Tiny", -1, true))
		if favor != 0.0:
			var fl := UI.label(Loc.t("SOC_FAVOURED") if favor > 0.0 else Loc.t("SOC_DISFAVOURED"), "Tiny")
			fl.add_theme_color_override("font_color", UI.GOOD if favor > 0.0 else UI.BAD)
			box.add_child(fl)
	# unrest hot spots
	var hot := Sheet.card(b)
	Sheet.header(hot, Loc.t("SOC_UNREST_SPOTS"))
	var list: Array = []
	for pid in GS.owned(s, Game.active_player):
		list.append([float(s["provinces"][pid]["unrest"]), pid])
	list.sort_custom(func(x, y): return x[0] > y[0])
	for i in range(mini(5, list.size())):
		var pid: String = list[i][1]
		var bt := UI.button("%s  –  %d" % [Defs.province_name(pid), int(list[i][0])], func() -> void:
			screen.mapview.focus_province(pid, 4.0)
			screen.select_province(pid), "Flat", "warning")
		hot.add_child(bt)

static func _government(b: VBoxContainer, screen: CampaignScreen) -> void:
	var s: Dictionary = Game.state
	var cid: String = Game.active_player
	var c: Dictionary = Game.pc()
	var gov: Dictionary = Defs.governments[c["gov"]]
	var gc := Sheet.card(b)
	Sheet.header(gc, Defs.gov_name(c["gov"]))
	for f in gov.get("features", []):
		gc.add_child(UI.label("• " + Loc.t("FEAT_" + str(f).to_upper()), "Small", -1, true))
	gc.add_child(UI.label(Fmt.effects_text(gov["mods"]), "Tiny", -1, true))
	if int(gov.get("term_turns", 0)) > 0:
		var left := int(gov["term_turns"]) - (int(s["turn"]) - int(c.get("election_turn", 0)))
		Sheet.kv(gc, Loc.t("GOV_NEXT_CHANGE"), Loc.tf("GOV_TURNS", {"n": maxi(0, left)}))
	Sheet.kv(gc, Loc.t("C_ADMIN"), UI.fmt(float(c["admin"])), Loc.t("TIP_ADMIN"))
	# transitions
	var tr := Sheet.card(b)
	Sheet.header(tr, Loc.t("GOV_TRANSITIONS"))
	var opts := PoliticsSystem.government_options(s, cid)
	if opts.is_empty():
		tr.add_child(UI.label(Loc.t("UI_NONE"), "Small"))
	for o in opts:
		var to: String = o["to"]
		var h := HBoxContainer.new()
		h.add_child(UI.icon_rect("g_" + to, 28, UI.GOLD_LIGHT))
		var l := UI.label("%s  (-%d %s, -%d %s)" % [Defs.gov_name(to), int(o["cost_admin"]), Loc.t("RES_ADMIN"), int(o["stability_hit"]), Loc.t("C_STABILITY")], "Small", -1, true)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
		var btn := UI.button(Loc.t("GOV_CHANGE"), func() -> void:
			Dialogs.confirm(screen.overlay_layer, Loc.t("GOV_CHANGE"), Loc.tf("GOV_CHANGE_CONFIRM", {"gov": Defs.gov_name(to)}), func() -> void: Game.cmd_change_gov(to), "", true), "Primary")
		btn.disabled = not o["ok"]
		btn.custom_minimum_size = Vector2(110, 44)
		h.add_child(btn)
		tr.add_child(h)
		if not o["ok"] and o["reason"] != "":
			tr.add_child(UI.label(NoteFmt.error_text(str(o["reason"])), "Tiny"))
	# reforms
	var rf := Sheet.card(b)
	Sheet.header(rf, Loc.t("REFORMS"))
	var ids: Array = Defs.reforms.keys()
	ids.sort()
	for rid in ids:
		var r: Dictionary = Defs.reforms[rid]
		var have: bool = rid in c["reforms"]
		var chk := PoliticsSystem.can_adopt_reform(s, cid, rid)
		if not have and not chk["ok"] and chk["reason"] in ["REFORM_ERR_GOV", "REFORM_ERR_EXCLUDES"]:
			continue
		var box := VBoxContainer.new()
		var h2 := HBoxContainer.new()
		var nm := UI.label(Loc.tx(r["name"]), "Value")
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h2.add_child(nm)
		if have:
			h2.add_child(UI.label(Loc.t("REFORM_ADOPTED"), "Good"))
		else:
			var rb := UI.button(Loc.t("UI_ADOPT"), func() -> void:
				var cost := "%d %s, %d %s" % [int(chk.get("admin", r["cost_admin"])), Loc.t("RES_ADMIN"), int(r["cost_gold"]), Loc.t("RES_GOLD")]
				Dialogs.confirm(screen.overlay_layer, Loc.tx(r["name"]), Loc.tf("REFORM_CONFIRM", {"cost": cost}), func() -> void: Game.cmd_adopt_reform(rid)), "Primary" if chk["ok"] else "")
			rb.disabled = not chk["ok"]
			rb.custom_minimum_size = Vector2(110, 44)
			h2.add_child(rb)
		box.add_child(h2)
		var adv := UI.label("+ " + Fmt.effects_text(r["advantages"]), "Tiny", -1, true)
		adv.add_theme_color_override("font_color", UI.GOOD)
		box.add_child(adv)
		var dis := UI.label("− " + Fmt.effects_text(r["disadvantages"]), "Tiny", -1, true)
		dis.add_theme_color_override("font_color", UI.BAD)
		box.add_child(dis)
		if not have and not chk["ok"]:
			box.add_child(UI.label(NoteFmt.error_text(chk["reason"], chk.get("params", {})), "Tiny"))
		rf.add_child(box)
		rf.add_child(UI.hsep())
