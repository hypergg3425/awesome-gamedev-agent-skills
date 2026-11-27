extends Control
## Main menu: atmospheric background, title treatment and a three-level hierarchy (primary campaign actions, secondary
## destinations, utility row). Adapts to compact (phone) windows by moving the secondary grid into a second column.

func _ready() -> void:
	Layout.install(get_window())
	theme = UI.theme()
	MenuBackground.attach(self)
	Audio.play_music("music_menu")
	Ads.show_banner()
	var root := Nav.safe_root(self)
	var vs := get_viewport_rect().size
	var compact := Layout.compact(vs)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 28 if not compact else 18)
	root.add_child(h)
	var col_w := clampf(vs.x * 0.34, 330.0, 470.0) if not compact else clampf(vs.x * 0.36, 300.0, 380.0)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	var lscroll := UI.scroll(left)
	lscroll.custom_minimum_size = Vector2(col_w, 0)
	lscroll.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	h.add_child(lscroll)
	var animated: Array = []
	_title(left, compact)
	var primary := _primary_buttons(compact)
	for b in primary:
		left.add_child(b)
		animated.append(b)
	var secondary := _secondary_items()
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for it in secondary:
		var b := _small_button(it)
		grid.add_child(b)
		animated.append(b)
	if compact:
		var right := VBoxContainer.new()
		right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		right.add_theme_constant_override("separation", 8)
		right.alignment = BoxContainer.ALIGNMENT_CENTER
		right.add_child(grid)
		right.add_child(_utility_row())
		h.add_child(right)
	else:
		left.add_child(UI.spacer(4))
		left.add_child(grid)
		left.add_child(UI.spacer(4))
		left.add_child(_utility_row())
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(sp)
	Anim.fade_in(self, 0.35)
	Anim.stagger_in(animated, 0.045)

func _title(parent: VBoxContainer, compact: bool) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	if not compact and ResourceLoader.exists("res://assets/ui/logo_mark.png"):
		var tr := TextureRect.new()
		tr.texture = load("res://assets/ui/logo_mark.png")
		tr.custom_minimum_size = Vector2(84, 84)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(tr)
	var name := UI.label("IMPERIUM", "Title" if compact else "Hero")
	name.clip_text = true
	box.add_child(name)
	if ResourceLoader.exists("res://assets/ui/divider.png") and not compact:
		var dv := TextureRect.new()
		dv.texture = load("res://assets/ui/divider.png")
		dv.custom_minimum_size = Vector2(0, 14)
		dv.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		dv.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		dv.modulate = Color(1, 1, 1, 0.9)
		dv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(dv)
	var sub := UI.label(Loc.t("APP_SUBTITLE"), "Sub")
	sub.clip_text = true
	box.add_child(sub)
	parent.add_child(box)
	parent.add_child(UI.spacer(6 if compact else 14))

func _primary_buttons(compact: bool) -> Array:
	var out: Array = []
	var new_btn := UI.button(Loc.t("MENU_NEW"), func() -> void:
		Nav.mode = "new"
		Nav.go(get_tree(), "scenarios"), "Primary", "crown")
	new_btn.custom_minimum_size = Vector2(0, 60 if not compact else 52)
	new_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	new_btn.add_theme_font_size_override("font_size", UI.fs(24))
	new_btn.name = "NewCampaign"
	out.append(new_btn)
	var cont := UI.button(Loc.t("MENU_CONTINUE"), func() -> void: _continue(), "", "next")
	cont.custom_minimum_size = Vector2(0, 54 if not compact else 48)
	cont.alignment = HORIZONTAL_ALIGNMENT_LEFT
	cont.disabled = not Saves.has_save("last")
	cont.name = "Continue"
	out.append(cont)
	return out

func _secondary_items() -> Array:
	return [
		["MENU_LOAD", "load", func() -> void: SaveLoadDialog.show_load(self, func() -> void: Nav.go(get_tree(), "campaign"))],
		["MENU_SCENARIOS", "history", func() -> void:
			Nav.mode = "browse"
			Nav.go(get_tree(), "scenarios")],
		["MENU_CUSTOM", "editor", func() -> void:
			Nav.mode = "custom"
			Nav.go(get_tree(), "scenarios")],
		["MENU_EDITOR", "construction", func() -> void:
			EditorState.new_scenario = true
			Nav.go(get_tree(), "editor")],
		["MENU_ACHIEVEMENTS", "achievements", func() -> void: Nav.go(get_tree(), "achievements")],
		["MENU_STATISTICS", "statistics", func() -> void: Nav.go(get_tree(), "statistics")],
	]

func _small_button(it: Array) -> Button:
	var b := UI.button(Loc.t(it[0]), it[2], "", it[1])
	b.custom_minimum_size = Vector2(0, 48)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.clip_text = true
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", UI.fs(16))
	b.add_theme_constant_override("icon_max_width", 24)
	b.name = str(it[0])
	return b

func _utility_row() -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.add_child(UI.icon_button("settings", func() -> void: SettingsPanel.show_dialog(self), Loc.t("MENU_SETTINGS"), 52.0, "Chip"))
	h.add_child(UI.icon_button("credits", func() -> void: Nav.go(get_tree(), "credits"), Loc.t("MENU_CREDITS"), 52.0, "Chip"))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(sp)
	for l in [["EN", "en"], ["TR", "tr"]]:
		var code: String = l[1]
		var lb := UI.button(l[0], func() -> void:
			Settings.set_value("language", code)
			get_tree().reload_current_scene(), "Primary" if Loc.lang == code else "Tab")
		lb.custom_minimum_size = Vector2(56, 52)
		h.add_child(lb)
	var ver := UI.label("v%s" % Const.VERSION, "Tiny", HORIZONTAL_ALIGNMENT_RIGHT)
	ver.size_flags_vertical = Control.SIZE_SHRINK_END
	h.add_child(ver)
	return h

func _continue() -> void:
	var r: Dictionary = Game.load_game("last")
	if r.get("ok", false):
		Nav.go(get_tree(), "campaign")
	else:
		Dialogs.info(self, Loc.t("SAVE_LOAD_FAILED"), NoteFmt.error_text(str(r.get("reason", ""))))
