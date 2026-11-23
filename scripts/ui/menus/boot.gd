extends Control
## Splash: loads data, shows the emblem, then opens the main menu.

func _ready() -> void:
	theme = UI.theme()
	var bg := ColorRect.new()
	bg.color = UI.NAVY_DEEP
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(c)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	c.add_child(v)
	var logo_path := "res://assets/ui/logo_mark.png"
	if ResourceLoader.exists(logo_path):
		var tr := TextureRect.new()
		tr.texture = load(logo_path)
		tr.custom_minimum_size = Vector2(220, 220)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		v.add_child(tr)
	v.add_child(UI.label("IMPERIUM", "Title", HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UI.label(Loc.t("APP_SUBTITLE"), "Sub", HORIZONTAL_ALIGNMENT_CENTER))
	var l := UI.label(Loc.t("UI_LOADING"), "Tiny", HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(l)
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.5)
	await get_tree().process_frame
	Defs.load_all()
	Defs.load_geometry()
	await get_tree().create_timer(0.9).timeout
	Audio.play_music("music_menu")
	Nav.go(get_tree(), "menu")
