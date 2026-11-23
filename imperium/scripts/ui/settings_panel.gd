class_name SettingsPanel
extends VBoxContainer
## Settings: language, audio, display, accessibility, performance and privacy / ads status.

static func show_dialog(host: Control) -> void:
	var dlg := Dialogs.custom(host, Loc.t("MENU_SETTINGS"), 760.0)
	var box: VBoxContainer = dlg["box"]
	var sp := SettingsPanel.new()
	box.add_child(UI.scroll(sp, 460))
	box.add_child(UI.button(Loc.t("UI_CLOSE"), func() -> void: dlg["close"].call(), "Primary"))

func _init() -> void:
	add_theme_constant_override("separation", 10)
	_build()
	Loc.language_changed.connect(func(_l: String) -> void: _rebuild())

func _rebuild() -> void:
	UI.clear(self)
	_build()

func _section(key: String) -> VBoxContainer:
	var c := Sheet.card(self)
	Sheet.header(c, Loc.t(key))
	return c

func _slider(parent: Control, key: String, label_key: String, mn: float, mx: float, step: float, fmt_pct: bool = true) -> void:
	var v := float(Settings.get_value(key))
	var l := UI.label("", "Small")
	var update := func(x: float) -> void:
		l.text = "%s: %s" % [Loc.t(label_key), ("%d%%" % int(round(x * 100.0))) if fmt_pct else str(x)]
	update.call(v)
	parent.add_child(l)
	var s := HSlider.new()
	s.min_value = mn
	s.max_value = mx
	s.step = step
	s.value = v
	s.custom_minimum_size = Vector2(0, 38)
	s.value_changed.connect(func(x: float) -> void:
		update.call(x)
		Settings.set_value(key, x))
	parent.add_child(s)

func _toggle(parent: Control, key: String, label_key: String) -> void:
	var c := CheckButton.new()
	c.text = Loc.t(label_key)
	c.button_pressed = bool(Settings.get_value(key))
	c.toggled.connect(func(on: bool) -> void:
		Settings.set_value(key, on)
		Audio.sfx("ui_click"))
	parent.add_child(c)

func _build() -> void:
	var lang := _section("SET_LANGUAGE")
	var ob := OptionButton.new()
	ob.add_item("English", 0)
	ob.add_item("Türkçe", 1)
	ob.selected = 0 if Loc.lang == "en" else 1
	ob.custom_minimum_size = Vector2(0, 52)
	ob.item_selected.connect(func(i: int) -> void: Settings.set_value("language", "en" if i == 0 else "tr"))
	lang.add_child(ob)
	var snd := _section("SET_AUDIO")
	_toggle(snd, "muted", "SET_MUTE")
	_slider(snd, "music_volume", "SET_MUSIC", 0.0, 1.0, 0.05)
	_slider(snd, "sfx_volume", "SET_SFX", 0.0, 1.0, 0.05)
	var disp := _section("SET_DISPLAY")
	_toggle(disp, "map_labels", "SET_MAP_LABELS")
	_toggle(disp, "army_markers", "SET_ARMY_MARKERS")
	_toggle(disp, "animations", "SET_ANIMATIONS")
	_toggle(disp, "colorblind", "SET_COLORBLIND")
	var ts: float = float(Settings.get_value("text_scale"))
	var tl := UI.label("%s: %d%%" % [Loc.t("SET_TEXT_SCALE"), int(float(ts) * 100.0)], "Small")
	disp.add_child(tl)
	var tsl := HSlider.new()
	tsl.min_value = 0.85
	tsl.max_value = 1.3
	tsl.step = 0.05
	tsl.value = float(ts)
	tsl.custom_minimum_size = Vector2(0, 38)
	tsl.value_changed.connect(func(x: float) -> void: tl.text = "%s: %d%%" % [Loc.t("SET_TEXT_SCALE"), int(x * 100.0)])
	tsl.drag_ended.connect(func(ch: bool) -> void:
		if ch:
			Settings.set_value("text_scale", tsl.value))
	disp.add_child(tsl)
	var game := _section("SET_GAMEPLAY")
	_toggle(game, "confirm_actions", "SET_CONFIRM")
	_toggle(game, "autosave", "SET_AUTOSAVE")
	var perf := _section("SET_PERFORMANCE")
	var gq := OptionButton.new()
	for i in 3:
		gq.add_item(Loc.t("SET_QUALITY_%d" % i), i)
	gq.selected = int(Settings.get_value("graphics_quality"))
	gq.custom_minimum_size = Vector2(0, 52)
	gq.item_selected.connect(func(i: int) -> void:
		Settings.set_value("graphics_quality", i)
		Settings.set_value("fps_cap", 30 if i == 0 else 60))
	perf.add_child(UI.label(Loc.t("SET_GRAPHICS"), "Small"))
	perf.add_child(gq)
	perf.add_child(UI.label(Loc.t("SET_GRAPHICS_HINT"), "Tiny", -1, true))
	var ads := _section("SET_PRIVACY")
	ads.add_child(UI.label(Loc.t("SET_ADS_INFO"), "Small", -1, true))
	ads.add_child(UI.label("%s: %s" % [Loc.t("SET_ADS_STATUS"), Loc.t(Ads.status_text_key())], "Tiny"))
	if AdConfig.using_test_ads():
		ads.add_child(UI.label(Loc.t("SET_ADS_TEST"), "Tiny"))
	ads.add_child(UI.label("%s: %s" % [Loc.t("SET_CONSENT"), Loc.t("CONSENT_" + Ads.consent_status.to_upper())], "Tiny"))
	if Ads.privacy_options_required:
		ads.add_child(UI.button(Loc.t("SET_PRIVACY_OPTIONS"), func() -> void: Ads.show_privacy_options(), "", "info"))
	var about := _section("SET_ABOUT")
	about.add_child(UI.label("IMPERIUM: " + Loc.t("APP_SUBTITLE") + "  v" + Const.VERSION + "  (Godot " + Engine.get_version_info()["string"] + ")", "Tiny", -1, true))
