class_name PanelsObjectives
extends RefCounted
## Objectives, victory progress, score and campaign statistics / timeline.

static func build(sheet: Sheet, screen: CampaignScreen) -> void:
	sheet.add_tab("objectives", "TAB_OBJECTIVES", func(b: VBoxContainer) -> void: _objectives(b, screen))
	sheet.add_tab("victory", "TAB_VICTORY", func(b: VBoxContainer) -> void: _victory(b, screen))
	sheet.add_tab("stats", "TAB_STATS", func(b: VBoxContainer) -> void: _stats(b, screen))
	sheet.add_tab("timeline", "TAB_TIMELINE", func(b: VBoxContainer) -> void: _timeline(b, screen))

static func _objectives(b: VBoxContainer, screen: CampaignScreen) -> void:
	var s: Dictionary = Game.state
	var cid: String = Game.active_player
	b.add_child(UI.label(Loc.t("OBJ_INTRO"), "Small", -1, true))
	if s["objectives"].is_empty():
		b.add_child(UI.label(Loc.t("UI_NONE"), "Small"))
	for ob in s["objectives"]:
		var box := Sheet.card(b)
		var h := HBoxContainer.new()
		var done: bool = ob.get("done", false)
		var failed: bool = ob.get("failed", false)
		h.add_child(UI.icon_rect("check" if done else ("cross" if failed else "objectives"), 28, UI.GOOD if done else (UI.BAD if failed else UI.GOLD_LIGHT)))
		var nm := UI.label(Loc.tx(ob.get("name", ob.get("id", ""))), "Value")
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		h.add_child(nm)
		box.add_child(h)
		box.add_child(UI.label(Loc.tx(ob.get("desc", {})), "Tiny", -1, true))
		var meta: Array = []
		if ob.has("by_turn"):
			meta.append(Loc.tf("OBJ_BY_TURN", {"n": int(ob["by_turn"]) + 1}))
		meta.append(Loc.tf("OBJ_SCORE", {"n": int(ob.get("score", 100))}))
		if ob.get("victory", false):
			meta.append(Loc.t("OBJ_VICTORY"))
		box.add_child(UI.label(" · ".join(meta), "Tiny"))

static func _victory(b: VBoxContainer, screen: CampaignScreen) -> void:
	var s: Dictionary = Game.state
	var cid: String = Game.active_player
	b.add_child(UI.label(Loc.t("VIC_INTRO"), "Small", -1, true))
	var pr := VictorySystem.progress(s, cid)
	for t in ["territory", "economic", "diplomatic", "technological"]:
		var d: Dictionary = pr[t]
		var box := Sheet.card(b)
		box.add_child(UI.label(Loc.t("VIC_" + t.to_upper()), "Sub"))
		box.add_child(UI.label(Loc.t("VICD_" + t.to_upper()), "Tiny", -1, true))
		var v := float(d["value"])
		var tg := float(d["target"])
		var txt := "%s / %s" % ["%.2f" % v if t in ["technological"] else Fmt.pct(v), "%.1f" % tg if t == "technological" else Fmt.pct(tg)]
		box.add_child(UI.progress(minf(v, tg), tg, UI.GOOD if d["done"] else UI.GOLD, txt))
		if int(d.get("hold", 0)) > 0:
			box.add_child(UI.label(Loc.tf("VIC_HOLD", {"n": int(d["hold"]), "need": VictorySystem.HOLD_TURNS}), "Tiny"))
	var sv := Sheet.card(b)
	sv.add_child(UI.label(Loc.t("VIC_SURVIVAL"), "Sub"))
	sv.add_child(UI.label(Loc.tf("VIC_SURVIVAL_D", {"turn": int(s["turn_limit"])}), "Tiny", -1, true))

static func _stats(b: VBoxContainer, screen: CampaignScreen) -> void:
	var s: Dictionary = Game.state
	var cid: String = Game.active_player
	var c: Dictionary = Game.pc()
	var st: Dictionary = c["stats"]
	var sc := VictorySystem.score(s, cid)
	var top := Sheet.card(b)
	Sheet.kv(top, Loc.t("STAT_SCORE"), UI.fmt(float(sc["total"])), "", UI.GOLD_LIGHT)
	for k in sc["parts"]:
		Sheet.kv(top, Loc.t(k), UI.fmt(float(sc["parts"][k])))
	var box := Sheet.card(b)
	Sheet.header(box, Loc.t("STAT_CAMPAIGN"))
	var rows := [["STAT_CONQUERED", "provinces_conquered"], ["STAT_BATTLES", "battles"], ["STAT_VICTORIES", "battles_won"], ["STAT_CASUALTIES", "casualties_taken"],
		["STAT_INFLICTED", "casualties_inflicted"], ["STAT_WARS_WON", "wars_won"], ["STAT_ANNEXED", "countries_annexed"], ["STAT_ALLIANCES", "alliances"],
		["STAT_TOTAL_INCOME", "total_income"], ["STAT_BUILDINGS", "buildings_built"], ["STAT_TECHS", "techs"]]
	for r in rows:
		Sheet.kv(box, Loc.t(r[0]), UI.fmt(float(st.get(r[1], 0.0))))
	Sheet.kv(box, Loc.t("STAT_DURATION"), Loc.tf("STAT_YEARS", {"n": "%.1f" % (float(s["turn"]) * float(Const.MONTHS_PER_TURN) / 12.0)}))

static func _timeline(b: VBoxContainer, screen: CampaignScreen) -> void:
	var s: Dictionary = Game.state
	var cid: String = Game.active_player
	var hist: Array = s["history"]
	var n := 0
	for i in range(hist.size() - 1, -1, -1):
		var h: Dictionary = hist[i]
		if h["cid"] != cid:
			continue
		var d := GS.date_of(s, int(h["turn"]))
		var row := HBoxContainer.new()
		var dl := UI.label("%d" % int(d["year"]), "Small")
		dl.custom_minimum_size = Vector2(60, 0)
		dl.add_theme_color_override("font_color", UI.GOLD)
		row.add_child(dl)
		var tl := UI.label(NoteFmt.history_text(s, h), "Small", -1, true)
		tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(tl)
		b.add_child(row)
		n += 1
		if n >= 80:
			break
	if n == 0:
		b.add_child(UI.label(Loc.t("TIMELINE_EMPTY"), "Small", -1, true))
