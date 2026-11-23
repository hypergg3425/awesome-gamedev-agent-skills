class_name PanelsMilitary
extends RefCounted
## Military sheet: armies (orders, merge/split/disband), recruitment queue, wars overview.

static func build(sheet: Sheet, screen: CampaignScreen) -> void:
	sheet.add_tab("armies", "TAB_ARMIES", func(b: VBoxContainer) -> void: _armies(b, screen))
	sheet.add_tab("recruit", "TAB_RECRUIT", func(b: VBoxContainer) -> void: _recruit(b, screen))
	sheet.add_tab("wars", "TAB_WARS", func(b: VBoxContainer) -> void: _wars(b, screen))

static func _armies(b: VBoxContainer, screen: CampaignScreen) -> void:
	var s: Dictionary = Game.state
	var me: String = Game.active_player
	var c: Dictionary = Game.pc()
	var top := Sheet.card(b)
	var bud: Dictionary = c.get("budget", {})
	Sheet.kv(top, Loc.t("MIL_REGIMENTS"), UI.fmt(UnitUtil.country_regiments(s, me)))
	Sheet.kv(top, Loc.t("MIL_SHIPS"), UI.fmt(UnitUtil.country_regiments(s, me, true)))
	Sheet.kv(top, Loc.t("MIL_MANPOWER"), "%s / %s" % [UI.fmt(float(c["manpower"])), UI.fmt(float(c["manpower_max"]))])
	Sheet.kv(top, Loc.t("MIL_UPKEEP"), UI.fmt(float(bud.get("army", 0.0)) + float(bud.get("navy", 0.0))))
	var armies := GS.armies_of(s, me)
	if armies.is_empty():
		b.add_child(UI.label(Loc.t("MIL_NO_ARMIES"), "Small", -1, true))
	for aid in armies:
		var a: Dictionary = s["armies"][aid]
		var box := Sheet.card(b)
		var h := HBoxContainer.new()
		h.add_child(UI.icon_rect("unit_naval" if a.get("naval", false) else "unit_infantry", 30, UI.GOLD_LIGHT))
		var loc := Defs.province_name(a["loc"]) if a["loc"] != "" else Loc.t("MIL_AT_SEA")
		var l := UI.label("%s  –  %s" % [loc, UI.fmt(UnitUtil.army_size(a))], "Value")
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
		box.add_child(h)
		box.add_child(UI.label(Fmt.unit_comp(a), "Tiny", -1, true))
		box.add_child(UI.progress(float(a["morale"]), 100.0, UI.GOOD if float(a["morale"]) > 55.0 else UI.WARN, "%s %d%%" % [Loc.t("MIL_MORALE"), int(a["morale"])]))
		Sheet.kv(box, Loc.t("MIL_GENERAL"), Fmt.general_text(a["general"]))
		if not (a["path"] as Array).is_empty():
			Sheet.kv(box, Loc.t("MIL_ORDERS"), Loc.tf("MIL_MOVING_TO", {"to": Defs.province_name(a["path"][a["path"].size() - 1])}))
		if a["transit"] != null:
			Sheet.kv(box, Loc.t("MIL_ORDERS"), Loc.tf("MIL_IN_TRANSIT", {"to": Defs.province_name(a["transit"]["to"]), "n": int(a["transit"]["left"])}))
		var bh := HBoxContainer.new()
		var focus := UI.button(Loc.t("UI_FOCUS"), func() -> void:
			if a["loc"] != "":
				screen.mapview.focus_province(a["loc"], 4.0)
				screen.select_province(a["loc"])
				screen.select_army(aid), "", "map")
		focus.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bh.add_child(focus)
		var dis := UI.button(Loc.t("MIL_DISBAND"), func() -> void:
			Dialogs.confirm(screen.overlay_layer, Loc.t("MIL_DISBAND"), Loc.t("MIL_DISBAND_CONFIRM"), func() -> void: Game.cmd_disband(aid), Loc.t("MIL_DISBAND"), true), "", "disband")
		dis.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bh.add_child(dis)
		box.add_child(bh)
		var bh2 := HBoxContainer.new()
		# merge with another own army in the same province
		for other in GS.armies_at(s, a["loc"]):
			if other != aid and s["armies"][other]["owner"] == me and bool(s["armies"][other].get("naval", false)) == bool(a.get("naval", false)):
				var o: String = other
				var mb := UI.button(Loc.t("MIL_MERGE"), func() -> void: Game.cmd_merge(aid, o), "", "merge")
				mb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				bh2.add_child(mb)
				break
		if UnitUtil.army_size(a) >= 2.0 and a["loc"] != "":
			var sb := UI.button(Loc.t("MIL_SPLIT"), func() -> void: _split_dialog(screen, aid), "", "split")
			sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			bh2.add_child(sb)
		if bh2.get_child_count() > 0:
			box.add_child(bh2)

static func _split_dialog(screen: CampaignScreen, aid: String) -> void:
	var a: Dictionary = Game.state["armies"].get(aid, {})
	if a.is_empty():
		return
	Dialogs.amount(screen.overlay_layer, Loc.t("MIL_SPLIT"), Loc.t("MIL_SPLIT_HINT"), 1.0, floorf(UnitUtil.army_size(a)) - 1.0, 1.0, 1.0, func(v: float) -> void:
		# move the requested number of regiments, taking proportionally from each unit type
		var total := UnitUtil.army_size(a)
		var take := {}
		var left := v
		for uid in a["units"]:
			var n := minf(floorf(float(a["units"][uid]) * v / total + 0.5), left)
			if n >= 1.0:
				take[uid] = n
				left -= n
		if take.is_empty():
			var first: String = a["units"].keys()[0]
			take[first] = 1.0
		Game.cmd_split(aid, take), "")

static func _recruit(b: VBoxContainer, screen: CampaignScreen) -> void:
	var s: Dictionary = Game.state
	var me: String = Game.active_player
	var c: Dictionary = Game.pc()
	var pid: String = Game.selected_province if Game.selected_province != "" and s["provinces"][Game.selected_province]["owner"] == me else c["capital"]
	var info := Sheet.card(b)
	Sheet.kv(info, Loc.t("MIL_RECRUIT_AT"), Defs.province_name(pid))
	Sheet.kv(info, Loc.t("MIL_MANPOWER"), "%s / %s" % [UI.fmt(float(c["manpower"])), UI.fmt(float(c["manpower_max"]))])
	info.add_child(UI.label(Loc.t("MIL_RECRUIT_HINT"), "Tiny", -1, true))
	if not (c["recruit_queue"] as Array).is_empty():
		var q := Sheet.card(b)
		Sheet.header(q, Loc.t("MIL_QUEUE"))
		for it in c["recruit_queue"]:
			q.add_child(UI.label("%s – %s (%d)" % [Defs.unit_name(it["uid"]), Defs.province_name(it["pid"]), int(it["left"])], "Small"))
	var have := {"gold": c["gold"], "manpower": c["manpower"]}
	for k in c["stock"]:
		have[k] = c["stock"][k]
	var order := ["infantry", "heavy_infantry", "archers", "cavalry", "heavy_cavalry", "artillery", "engineer", "naval"]
	for cls in order:
		var box := Sheet.card(b)
		var hdr := HBoxContainer.new()
		hdr.add_child(UI.icon_rect("unit_" + cls, 28, UI.GOLD_LIGHT))
		hdr.add_child(UI.label(Loc.t("UCLASS_" + cls.to_upper()), "Sub"))
		box.add_child(hdr)
		var any := false
		for uid in UnitUtil.available_units(s, me):
			var u: Dictionary = Defs.units[uid]
			if u["cls"] != cls:
				continue
			any = true
			var chk := MilitarySystem.can_recruit(s, me, pid, uid)
			var h := HBoxContainer.new()
			var nm := UI.label(Defs.unit_name(uid), "Value")
			nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			nm.tooltip_text = Loc.tf("UNIT_STATS", {"f": u["fire"], "s": u["shock"], "d": u["defense"], "m": u["morale"], "mv": u["move"], "up": u["upkeep"]})
			h.add_child(nm)
			h.add_child(UI.label("🔥%d ⚔%d 🛡%d" % [int(u["fire"]), int(u["shock"]), int(u["defense"])] if false else "%d/%d/%d" % [int(u["fire"]), int(u["shock"]), int(u["defense"])], "Small"))
			var rb := UI.button(Loc.t("UI_RECRUIT"), func() -> void:
				if Game.cmd_recruit(pid, uid).get("ok", false):
					Audio.sfx("recruit"), "Primary" if chk["ok"] else "")
			rb.disabled = not chk["ok"]
			rb.custom_minimum_size = Vector2(110, 44)
			h.add_child(rb)
			box.add_child(h)
			box.add_child(Fmt.cost_row(MilitarySystem.recruit_cost(s, me, uid), have))
			box.add_child(UI.label(Loc.tf("UNIT_LINE", {"up": "%.1f" % float(u["upkeep"]), "mv": int(u["move"]), "mo": int(u["morale"])}), "Tiny"))
		if not any:
			box.add_child(UI.label(Loc.t("MIL_LOCKED_CLASS"), "Tiny"))

static func _wars(b: VBoxContainer, screen: CampaignScreen) -> void:
	var s: Dictionary = Game.state
	var me: String = Game.active_player
	var wars := GS.wars_of(s, me)
	if wars.is_empty():
		b.add_child(UI.label(Loc.t("WAR_NONE"), "Small", -1, true))
	for wid in wars:
		var w: Dictionary = s["wars"][wid]
		var box := Sheet.card(b)
		box.add_child(UI.label(Fmt.war_name(s, w), "Value"))
		var sc := DiplomacySystem.score_for(s, wid, me)
		box.add_child(UI.progress(sc + 100.0, 200.0, UI.GOOD if sc > 0.0 else UI.BAD, "%s %+d" % [Loc.t("WAR_SCORE"), int(sc)]))
		Sheet.kv(box, Loc.t("WAR_LENGTH"), Loc.tf("GOV_TURNS", {"n": int(s["turn"]) - int(w["start_turn"])}))
		Sheet.kv(box, Loc.t("WAR_EXHAUSTION"), "%d" % int(float(Game.pc().get("war_exhaustion", 0.0))))
		var us: Array = []
		var them: Array = []
		var my_side := DiplomacySystem.side_of(w, me)
		for x in w["attackers"]:
			(us if my_side == "attackers" else them).append(GS.country_name(s, x))
		for x in w["defenders"]:
			(them if my_side == "attackers" else us).append(GS.country_name(s, x))
		Sheet.kv(box, Loc.t("WAR_OUR_SIDE"), ", ".join(us))
		Sheet.kv(box, Loc.t("WAR_THEIR_SIDE"), ", ".join(them))
		var foe_leader: String = w["leader_d"] if my_side == "attackers" else w["leader_a"]
		box.add_child(UI.button(Loc.t("WAR_NEGOTIATE"), func() -> void: PeaceDialog.show_peace(screen, wid, foe_leader), "Primary", "peace"))
