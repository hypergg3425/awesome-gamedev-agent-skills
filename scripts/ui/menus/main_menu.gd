extends Control
## Main menu.

func _ready() -> void:
	theme = UI.theme()
	Nav.background(self)
	Audio.play_music("music_menu")
	Ads.show_banner()
	var root := Nav.safe_root(self)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 40)
	root.add_child(h)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(430, 0)
	left.add_theme_constant_override("separation", 8)
	h.add_child(left)
	left.add_child(UI.label("IMPERIUM", "Title"))
	left.add_child(UI.label(Loc.t("APP_SUBTITLE"), "Sub"))
	left.add_child(UI.spacer(6))
	var items := [
		["MENU_NEW", "crown", func() -> void:
			Nav.mode = "new"
			Nav.go(get_tree(), "scenarios"), true],
		["MENU_CONTINUE", "next", func() -> void: _continue(), Saves.has_save("last")],
		["MENU_LOAD", "load", func() -> void: SaveLoadDialog.show_load(self, func() -> void: Nav.go(get_tree(), "campaign")), true],
		["MENU_SCENARIOS", "history", func() -> void:
			Nav.mode = "browse"
			Nav.go(get_tree(), "scenarios"), true],
		["MENU_CUSTOM", "editor", func() -> void:
			Nav.mode = "custom"
			Nav.go(get_tree(), "scenarios"), true],
		["MENU_EDITOR", "construction", func() -> void:
			EditorState.new_scenario = true
			Nav.go(get_tree(), "editor"), true],
		["MENU_ACHIEVEMENTS", "achievements", func() -> void: Nav.go(get_tree(), "achievements"), true],
		["MENU_STATISTICS", "statistics", func() -> void: Nav.go(get_tree(), "statistics"), true],
		["MENU_SETTINGS", "settings", func() -> void: SettingsPanel.show_dialog(self), true],
		["MENU_CREDITS", "credits", func() -> void: Nav.go(get_tree(), "credits"), true],
	]
	var grid := VBoxContainer.new()
	grid.add_theme_constant_override("separation", 6)
	left.add_child(UI.scroll(grid))
	for it in items:
		var b := UI.button(Loc.t(it[0]), it[2], "Primary" if it[0] == "MENU_NEW" else "", it[1])
		b.custom_minimum_size = Vector2(0, 54)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = not it[3]
		grid.add_child(b)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(sp)
	# language quick switch + version (bottom right)
	var br := VBoxContainer.new()
	br.size_flags_vertical = Control.SIZE_SHRINK_END
	br.alignment = BoxContainer.ALIGNMENT_END
	var lang := HBoxContainer.new()
	for l in [["EN", "en"], ["TR", "tr"]]:
		var code: String = l[1]
		var lb := UI.button(l[0], func() -> void:
			Settings.set_value("language", code)
			get_tree().reload_current_scene(), "Primary" if Loc.lang == code else "Tab")
		lb.custom_minimum_size = Vector2(70, 46)
		lang.add_child(lb)
	br.add_child(lang)
	br.add_child(UI.label("v%s" % Const.VERSION, "Tiny", HORIZONTAL_ALIGNMENT_RIGHT))
	h.add_child(br)

func _continue() -> void:
	var r: Dictionary = Game.load_game("last")
	if r.get("ok", false):
		Nav.go(get_tree(), "campaign")
	else:
		Dialogs.info(self, Loc.t("SAVE_LOAD_FAILED"), NoteFmt.error_text(str(r.get("reason", ""))))
