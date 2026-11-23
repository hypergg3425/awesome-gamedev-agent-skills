class_name InfoScreens
extends RefCounted
## Credits, Achievements and Statistics screens (all built from the same page frame).

static func _frame(host: Control, title_key: String) -> VBoxContainer:
	host.theme = UI.theme()
	Nav.background(host, "res://assets/backgrounds/menu_bg.png", 0.7)
	Ads.show_banner()
	var root := Nav.safe_root(host)
	var v := VBoxContainer.new()
	root.add_child(v)
	Nav.header(v, Loc.t(title_key), func() -> void: Nav.go(host.get_tree(), "menu"))
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	var sc := UI.scroll(body)
	v.add_child(sc)
	return body

static func build_credits(host: Control) -> void:
	var b := _frame(host, "MENU_CREDITS")
	var card := Sheet.card(b)
	card.add_child(UI.label("IMPERIUM: " + Loc.t("APP_SUBTITLE"), "Heading"))
	card.add_child(UI.label(Loc.t("CREDITS_INTRO"), "", -1, true))
	var rows := [
		["CREDITS_ENGINE", "Godot Engine 4.7 (MIT License) — godotengine.org"],
		["CREDITS_MAPDATA", "Natural Earth (public domain) — naturalearthdata.com"],
		["CREDITS_FONTS", "Cinzel, EB Garamond, Noto Sans (SIL Open Font License 1.1)"],
		["CREDITS_ADS", "Godot AdMob plugin by Poing Studios (MIT License) — Google Mobile Ads SDK / UMP"],
		["CREDITS_ART", "Original, procedurally generated icons, illustrations, flags and ornaments (project licence)"],
		["CREDITS_AUDIO", "Original, procedurally synthesised music and sound effects (project licence)"],
		["CREDITS_HISTORY", "Historical scenarios are approximations on modern-geometry regions; see each scenario's note"],
	]
	for r in rows:
		var c := Sheet.card(b)
		c.add_child(UI.label(Loc.t(r[0]), "Sub"))
		c.add_child(UI.label(r[1], "Small", -1, true))
	b.add_child(UI.label("v%s · %s" % [Const.VERSION, Engine.get_version_info()["string"]], "Tiny"))

static func build_achievements(host: Control) -> void:
	var b := _frame(host, "MENU_ACHIEVEMENTS")
	var prof := Achievements.load_profile()
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	b.add_child(grid)
	for d in Achievements.DEFS:
		var id: String = d["id"]
		var done: bool = prof["unlocked"].has(id)
		var card := PanelContainer.new()
		card.theme_type_variation = "Card"
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 14)
		var path := "res://assets/illustrations/ach_%s.png" % id
		if ResourceLoader.exists(path):
			var tr := TextureRect.new()
			tr.texture = load(path)
			tr.custom_minimum_size = Vector2(84, 84)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.modulate = Color.WHITE if done else Color(0.35, 0.35, 0.4, 0.8)
			h.add_child(tr)
		else:
			h.add_child(UI.icon_rect(d["icon"], 64, UI.GOLD if done else Color(0.4, 0.4, 0.45)))
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(UI.label(Loc.t("ACH_" + id.to_upper()), "Sub"))
		v.add_child(UI.label(Loc.t("ACHD_" + id.to_upper()), "Tiny", -1, true))
		v.add_child(UI.label(Loc.t("ACH_UNLOCKED") if done else Loc.t("ACH_LOCKED"), "Good" if done else "Tiny"))
		h.add_child(v)
		card.add_child(h)
		grid.add_child(card)

static func build_statistics(host: Control) -> void:
	var b := _frame(host, "MENU_STATISTICS")
	var prof := Achievements.load_profile()
	var lt: Dictionary = prof["lifetime"]
	var c := Sheet.card(b)
	Sheet.header(c, Loc.t("STATS_LIFETIME"))
	for r in [["STATS_CAMPAIGNS", "campaigns"], ["STATS_VICTORIES", "victories"], ["STAT_BATTLES", "battles"], ["STAT_VICTORIES", "battles_won"], ["STAT_CONQUERED", "provinces_conquered"],
			["STAT_WARS_WON", "wars_won"], ["STAT_ALLIANCES", "alliances"], ["STATS_TURNS", "turns"], ["STATS_BEST_SCORE", "best_score"]]:
		Sheet.kv(c, Loc.t(r[0]), UI.fmt(float(lt.get(r[1], 0))))
	var u := Sheet.card(b)
	Sheet.header(u, Loc.t("MENU_ACHIEVEMENTS"))
	Sheet.kv(u, Loc.t("STATS_UNLOCKED"), "%d / %d" % [(prof["unlocked"] as Dictionary).size(), Achievements.DEFS.size()])
