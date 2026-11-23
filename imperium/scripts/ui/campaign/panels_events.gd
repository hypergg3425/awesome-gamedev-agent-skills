class_name PanelsEvents
extends RefCounted
## Notification log sheet.

static func build(sheet: Sheet, screen: CampaignScreen) -> void:
	sheet.add_tab("log", "TAB_LOG", func(b: VBoxContainer) -> void: _log(b, screen))

static func _log(b: VBoxContainer, screen: CampaignScreen) -> void:
	var s: Dictionary = Game.state
	var me: String = Game.active_player
	var pend := Game.pending_events()
	if not pend.is_empty():
		var box := Sheet.card(b)
		box.add_child(UI.label(Loc.tf("EVT_PENDING", {"n": pend.size()}), "Warn"))
		box.add_child(UI.button(Loc.t("EVT_OPEN"), func() -> void:
			screen.close_sheets()
			screen._show_pending_events(), "Primary", "events"))
	var n := 0
	var notes: Array = s["notes"]
	for i in range(notes.size() - 1, -1, -1):
		var note: Dictionary = notes[i]
		if note["cid"] != me:
			continue
		var d := GS.date_of(s, int(note["turn"]))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.add_child(UI.icon_rect(NoteFmt.category_icon(note["cat"]), 24, UI.GOLD))
		var dl := UI.label("%d" % int(d["year"]), "Tiny")
		dl.custom_minimum_size = Vector2(48, 0)
		row.add_child(dl)
		var tl := UI.label(NoteFmt.text(s, note), "Small", -1, true)
		tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(tl)
		if note.get("pid", "") != "":
			var pid: String = note["pid"]
			row.add_child(UI.icon_button("map", func() -> void:
				screen.mapview.focus_province(pid, 4.0)
				screen.select_province(pid), Loc.t("UI_FOCUS"), 38.0))
		b.add_child(row)
		n += 1
		if n >= 60:
			break
	if n == 0 and pend.is_empty():
		b.add_child(UI.label(Loc.t("LOG_EMPTY"), "Small", -1, true))
