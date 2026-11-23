class_name PanelsTech
extends RefCounted
## Technology sheet: one tab per branch, lines as rows of four level cards.

static func build(sheet: Sheet, screen: CampaignScreen) -> void:
	for br in Const.BRANCHES:
		var branch: String = br
		sheet.add_tab(branch, "BRANCH_" + branch.to_upper(), func(b: VBoxContainer) -> void: _branch(b, screen, branch), "t_" + branch)

static func _branch(b: VBoxContainer, screen: CampaignScreen, branch: String) -> void:
	var s: Dictionary = Game.state
	var cid: String = Game.active_player
	var c: Dictionary = Game.pc()
	var top := Sheet.card(b)
	var rp := TechSystem.points(s, cid)
	Sheet.kv(top, Loc.t("TECH_POINTS"), "%.1f / %s" % [rp, Loc.t("UI_TURN_SHORT")], Loc.t("TIP_RESEARCH"))
	var alloc := float(c["research"]["alloc"].get(branch, 1.0))
	var al := UI.label("%s: ×%.1f" % [Loc.t("TECH_FOCUS"), alloc], "Small")
	top.add_child(al)
	var sl := HSlider.new()
	sl.min_value = 0.0
	sl.max_value = 3.0
	sl.step = 0.5
	sl.value = alloc
	sl.custom_minimum_size = Vector2(0, 34)
	sl.value_changed.connect(func(v: float) -> void: al.text = "%s: ×%.1f" % [Loc.t("TECH_FOCUS"), v])
	sl.drag_ended.connect(func(ch: bool) -> void:
		if ch:
			Game.cmd_set_research_alloc(branch, sl.value))
	top.add_child(sl)
	var cur := str(c["research"]["current"].get(branch, ""))
	if cur != "":
		var need := TechSystem.cost_rp(s, cid, cur)
		var prog := float(c["research"]["progress"].get(cur, 0.0))
		var cc := Sheet.card(b)
		cc.add_child(UI.label(Loc.tf("TECH_RESEARCHING", {"tech": Defs.tech_name(cur)}), "Value"))
		cc.add_child(UI.progress(prog, need, UI.GOLD, "%d / %d" % [int(prog), int(need)]))
		cc.add_child(UI.button(Loc.t("TECH_CANCEL"), func() -> void:
			Dialogs.confirm(screen.overlay_layer, Loc.t("TECH_CANCEL"), Loc.t("TECH_CANCEL_CONFIRM"), func() -> void: Game.cmd_cancel_research(branch), "", true)))
	var lines: Array = []
	for lid in Defs.tech_lines:
		if Defs.tech_lines[lid]["branch"] == branch:
			lines.append(lid)
	lines.sort()
	for lid in lines:
		var box := Sheet.card(b)
		box.add_child(UI.label(Loc.tx(Defs.tech_lines[lid]["name"]), "Sub"))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		for lv in range(1, 5):
			var tid := "%s_%d" % [lid, lv]
			var t: Dictionary = Defs.techs[tid]
			var done: bool = c["researched"].has(tid)
			var chk := TechSystem.can_research(s, cid, tid)
			var btn := Button.new()
			btn.focus_mode = Control.FOCUS_NONE
			btn.custom_minimum_size = Vector2(0, 74)
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.theme_type_variation = "Primary" if done else ("" if chk["ok"] or tid == cur else "Tab")
			btn.text = "%s\n%s" % [Fmt.roman(lv), "✓" if done else (str(int(TechSystem.cost_rp(s, cid, tid))) if true else "")]
			btn.add_theme_font_size_override("font_size", UI.fs(17))
			btn.tooltip_text = Defs.tech_name(tid) + "\n" + Fmt.effects_text(t["effects"])
			btn.disabled = false
			btn.pressed.connect(func() -> void:
				Audio.sfx("ui_click")
				_tech_dialog(screen, tid))
			if not done and not chk["ok"] and tid != cur:
				btn.modulate = Color(1, 1, 1, 0.55)
			row.add_child(btn)
		box.add_child(row)

static func _tech_dialog(screen: CampaignScreen, tid: String) -> void:
	var s: Dictionary = Game.state
	var cid: String = Game.active_player
	var c: Dictionary = Game.pc()
	var t: Dictionary = Defs.techs[tid]
	var dlg := Dialogs.custom(screen.overlay_layer, Defs.tech_name(tid), 640.0)
	var box: VBoxContainer = dlg["box"]
	box.add_child(UI.label(Loc.tx(t["line_name"]) + "  " + Fmt.roman(int(t["level"])), "Sub"))
	for e in Fmt.effects_list(t["effects"]):
		var l := UI.label("+ " + e, "Good")
		box.add_child(l)
	var unlocks: Array = []
	for uid in Defs.units:
		var req: Variant = Defs.units[uid]["tech"]
		if req is Array and req[0] == t["line"] and int(req[1]) == int(t["level"]):
			unlocks.append(Defs.unit_name(uid))
	for bid in Defs.buildings:
		var rq: Dictionary = Defs.buildings[bid]["requires"]
		if rq.has("tech") and rq["tech"][0] == t["line"] and int(rq["tech"][1]) == int(t["level"]):
			unlocks.append(Defs.building_name(bid))
	if not unlocks.is_empty():
		box.add_child(UI.label(Loc.t("TECH_UNLOCKS") + ": " + ", ".join(unlocks), "Small", -1, true))
	var pre: Array = []
	for p in t["prereq"]:
		var ok: bool = c["researched"].has(p)
		pre.append(("✓ " if ok else "✗ ") + Defs.tech_name(p))
	if not pre.is_empty():
		box.add_child(UI.label(Loc.t("TECH_PREREQ") + ": " + ", ".join(pre), "Small", -1, true))
	var need := TechSystem.cost_rp(s, cid, tid)
	box.add_child(Fmt.cost_row({"gold": float(t["cost_gold"])}, {"gold": c["gold"]}))
	box.add_child(UI.label(Loc.tf("TECH_COST_RP", {"rp": int(need), "turns": int(ceil(need / maxf(1.0, float(c["research"].get("last_points", 1.0)) * 0.25)))}), "Small"))
	var chk := TechSystem.can_research(s, cid, tid)
	if c["researched"].has(tid):
		box.add_child(UI.label(Loc.t("TECH_DONE"), "Good"))
	else:
		var bt := UI.button(Loc.t("TECH_START"), func() -> void:
			dlg["close"].call()
			var r := Game.cmd_research(tid)
			if r.get("ok", false):
				Audio.sfx("ui_confirm"), "Primary", "research")
		bt.disabled = not chk["ok"]
		box.add_child(bt)
		if not chk["ok"]:
			var rl := UI.label(NoteFmt.error_text(chk["reason"], chk.get("params", {})), "Small")
			rl.add_theme_color_override("font_color", UI.BAD)
			box.add_child(rl)
