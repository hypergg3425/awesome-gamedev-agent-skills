class_name EndScreen
extends RefCounted
## Campaign conclusion: result, final score breakdown, statistics.

static func show_end(screen: CampaignScreen) -> void:
	var s: Dictionary = Game.state
	var me: String = s["player"]
	var win: bool = s["winner"] == me
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.05, 0.1, 0.96)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	screen.overlay_layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(760, 0)
	v.add_theme_constant_override("separation", 10)
	center.add_child(v)
	v.add_child(UI.label(Loc.t("END_VICTORY") if win else Loc.t("END_DEFEAT"), "Title", HORIZONTAL_ALIGNMENT_CENTER))
	var vt := str(s.get("victory_type", ""))
	var reason := Loc.t("END_REASON_" + vt.to_upper()) if Loc.has_key("END_REASON_" + vt.to_upper()) else vt
	v.add_child(UI.label(reason, "Heading", HORIZONTAL_ALIGNMENT_CENTER, true))
	if s["winner"] != "" and s["winner"] != me:
		v.add_child(UI.label(Loc.tf("END_WINNER", {"country": GS.country_name(s, s["winner"])}), "Value", HORIZONTAL_ALIGNMENT_CENTER))
	var sc := VictorySystem.score(s, me) if s["countries"][me]["alive"] else {"total": 0.0, "parts": {}}
	var card := PanelContainer.new()
	card.theme_type_variation = "Card"
	var cv := VBoxContainer.new()
	card.add_child(cv)
	Sheet.kv(cv, Loc.t("STAT_SCORE"), UI.fmt(float(sc["total"])), "", UI.GOLD_LIGHT)
	for k in sc["parts"]:
		Sheet.kv(cv, Loc.t(k), UI.fmt(float(sc["parts"][k])))
	var st: Dictionary = s["countries"][me]["stats"]
	Sheet.kv(cv, Loc.t("STAT_CONQUERED"), UI.fmt(float(st.get("provinces_conquered", 0.0))))
	Sheet.kv(cv, Loc.t("STAT_BATTLES"), "%d / %d" % [int(st.get("battles_won", 0.0)), int(st.get("battles", 0.0))])
	Sheet.kv(cv, Loc.t("STAT_DURATION"), Loc.tf("STAT_YEARS", {"n": "%.1f" % (float(s["turn"]) * 3.0 / 12.0)}))
	v.add_child(UI.scroll(card, 260))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	h.add_child(UI.button(Loc.t("END_STATS"), func() -> void:
		dim.queue_free()
		screen.open_sheet("objectives")
		(screen.sheets["objectives"] as Sheet).select_tab("stats")))
	var menu := UI.button(Loc.t("END_MENU"), func() -> void:
		Game.quit_to_menu()
		screen.get_tree().change_scene_to_file("res://scenes/menus/main_menu.tscn"), "Primary")
	menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(menu)
	v.add_child(h)
	Audio.sfx("victory" if win else "defeat")
	Achievements.record_campaign_end(s)
