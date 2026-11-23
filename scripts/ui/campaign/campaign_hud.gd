class_name CampaignHud
extends PanelContainer
## Top bar of the campaign screen. Visual hierarchy: country + date on the left, the three primary economy chips
## (treasury, manpower, food) in the middle at full prominence, then compact stability/legitimacy chips (wide screens only),
## a "more" button that drops down every secondary statistic, the notification bell and the menu. Elements hide in
## priority order when the bar would overflow (see fit()).

signal sheet_requested(id: String)
signal menu_requested()

var box: HBoxContainer
var refs := {}
var detail: PanelContainer
var detail_grid: GridContainer
var _chips := {}          # id -> Button
var _more: Button
var _inline_secondary: Array = []
var _hide_order: Array = []
var _wide := true

func _init() -> void:
	theme_type_variation = "Hud"
	clip_contents = true
	box = HBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	detail = PanelContainer.new()
	detail.theme_type_variation = "HudDrop"
	detail.visible = false
	detail_grid = GridContainer.new()
	detail_grid.columns = 2
	detail_grid.add_theme_constant_override("h_separation", 18)
	detail_grid.add_theme_constant_override("v_separation", 4)
	detail.add_child(detail_grid)
	build()

func build() -> void:
	UI.clear(box)
	UI.clear(detail_grid)
	refs.clear()
	_chips.clear()
	_inline_secondary.clear()
	_hide_order.clear()
	var tb := touch_size()
	custom_minimum_size = Vector2(0, tb + 10.0)
	box.add_child(_country_button(tb))
	box.add_child(_date_block())
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(sp)
	box.add_child(_chip("gold", "gold", "TIP_GOLD", "economy", Color("f0cf6a"), tb))
	box.add_child(_chip("manpower", "manpower", "TIP_MANPOWER", "military", Color("f4ecd6"), tb))
	var food := _chip("food", "food", "TIP_FOOD", "economy", Color("b7d98a"), tb)
	box.add_child(food)
	_hide_order.append(food)
	for spec in [["stability", "stability", "TIP_STABILITY", "politics", Color("f4ecd6")], ["legitimacy", "legitimacy", "TIP_LEGITIMACY", "politics", Color("f4ecd6")]]:
		var c := _chip(spec[0], spec[1], spec[2], spec[3], spec[4], tb)
		box.add_child(c)
		_inline_secondary.append(c)
	_more = UI.icon_button("chevron_down", func() -> void: toggle_detail(), Loc.t("HUD_MORE"), tb)
	_more.theme_type_variation = "Chip"
	box.add_child(_more)
	var ev := UI.icon_button("events", func() -> void: sheet_requested.emit("events"), Loc.t("PANEL_EVENTS"), tb)
	refs["events_btn"] = ev
	var badge := UI.label("", "Tiny", HORIZONTAL_ALIGNMENT_CENTER)
	badge.add_theme_color_override("font_color", Color.WHITE)
	badge.add_theme_stylebox_override("normal", UI._fb(UI.BURGUNDY_LIGHT, UI.BURGUNDY, UI.GOLD_LIGHT, 1.0, 9.0, 4.0))
	badge.visible = false
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	badge.offset_left = -20
	badge.offset_top = -3
	badge.custom_minimum_size = Vector2(20, 18)
	ev.add_child(badge)
	refs["events_badge"] = badge
	box.add_child(ev)
	var menu := UI.icon_button("menu", func() -> void: menu_requested.emit(), Loc.t("UI_MENU"), tb)
	refs["menu_btn"] = menu
	box.add_child(menu)
	# detail panel rows (every statistic, with its label)
	for d in [["admin", "admin", "TIP_ADMIN", "HUD_ADMIN"], ["stability", "stability", "TIP_STABILITY", "HUD_STABILITY"], ["legitimacy", "legitimacy", "TIP_LEGITIMACY", "HUD_LEGITIMACY"],
			["prestige", "prestige", "TIP_PRESTIGE", "HUD_PRESTIGE"], ["manpower", "manpower", "TIP_MANPOWER", "HUD_MANPOWER"], ["food", "food", "TIP_FOOD", "HUD_FOOD"]]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.tooltip_text = Loc.t(d[2])
		row.add_child(UI.icon_rect(d[1], 26, Color("f4ecd6")))
		var nm := UI.label(Loc.t(d[3]), "Small")
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(nm)
		detail_grid.add_child(row)
		var val := UI.label("0", "Value", HORIZONTAL_ALIGNMENT_RIGHT)
		val.custom_minimum_size = Vector2(88, 0)
		refs["d_" + str(d[0])] = val
		detail_grid.add_child(val)

func touch_size() -> float:
	return maxf(Layout.touch_min(get_window()), 46.0) if is_inside_tree() else 48.0

func _country_button(tb: float) -> Button:
	var b := Button.new()
	b.theme_type_variation = "Flat"
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(170, tb)
	b.clip_contents = true
	b.tooltip_text = Loc.t("PANEL_COUNTRY")
	var hb := HBoxContainer.new()
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.set_anchors_preset(Control.PRESET_FULL_RECT)
	hb.offset_left = 6
	hb.offset_right = -6
	var flag := FlagView.make({}, Color.GRAY, Vector2(tb * 0.95, tb * 0.62))
	flag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	refs["flag"] = flag
	hb.add_child(flag)
	var nm := UI.label("", "Sub")
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nm.clip_text = true
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	refs["name"] = nm
	hb.add_child(nm)
	b.add_child(hb)
	b.pressed.connect(func() -> void:
		Audio.sfx("ui_click")
		sheet_requested.emit("country"))
	refs["country_btn"] = b
	return b

func _date_block() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -2)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var d := UI.label("", "Value")
	var t := UI.label("", "Tiny")
	v.add_child(d)
	v.add_child(t)
	refs["date"] = d
	refs["turn"] = t
	refs["date_block"] = v
	return v

func _chip(id: String, icon_id: String, tip_key: String, sheet_id: String, tint: Color, tb: float) -> Button:
	var b := Button.new()
	b.theme_type_variation = "Chip"
	b.focus_mode = Control.FOCUS_NONE
	b.icon = UI.icon(icon_id)
	b.add_theme_constant_override("icon_max_width", int(tb * 0.5))
	b.add_theme_constant_override("h_separation", 6)
	b.add_theme_color_override("icon_normal_color", tint)
	b.add_theme_color_override("icon_hover_color", tint.lightened(0.3))
	b.add_theme_color_override("icon_pressed_color", tint.lightened(0.3))
	b.add_theme_font_size_override("font_size", UI.fs(19))
	b.custom_minimum_size = Vector2(0, tb)
	b.tooltip_text = Loc.t(tip_key)
	b.text = "0"
	b.pressed.connect(func() -> void:
		Audio.sfx("ui_click")
		sheet_requested.emit(sheet_id))
	refs[id] = b
	_chips[id] = b
	return b

func toggle_detail() -> void:
	detail.visible = not detail.visible
	_more.icon = UI.icon("chevron_up" if detail.visible else "chevron_down")
	if detail.visible:
		Anim.pop_in(detail)

func close_detail() -> void:
	if detail.visible:
		toggle_detail()

## --- data -------------------------------------------------------------------------------------------
func update_from(s: Dictionary, c: Dictionary, pending_events: int) -> void:
	var b: Dictionary = c.get("budget", {})
	(refs["flag"] as FlagView).setup(c.get("flag", {}), Util.color_from(c.get("color", "#888888")))
	refs["name"].text = Loc.tx(c.get("short", c.get("name", "")))
	refs["date"].text = GS.date_string(s)
	refs["turn"].text = Loc.tf("UI_TURN_N", {"n": int(s["turn"]) + 1})
	var net := float(b.get("net", 0.0))
	var g := float(c["gold"])
	_set_chip("gold", "%s %s" % [UI.fmt(g), UI.signed(net)], Color("f0cf6a") if g >= 0.0 and net >= 0.0 else UI.BAD)
	_set_chip("manpower", "%s/%s" % [UI.fmt(float(c["manpower"])), UI.fmt(float(c["manpower_max"]))])
	var fb := float(b.get("food_balance", 0.0))
	_set_chip("food", "%s %s" % [UI.fmt(float(c["stock"]["food"])), UI.signed(fb)], UI.GOOD if fb >= 0.0 else UI.BAD)
	var stab := float(c["stability"])
	_set_chip("stability", "%d" % int(round(stab)), UI.color_for(stab - 40.0))
	_set_chip("legitimacy", "%d" % int(round(float(c["legitimacy"]))))
	refs["d_admin"].text = UI.fmt(float(c["admin"]))
	refs["d_stability"].text = "%d" % int(round(stab))
	UI.tint_label(refs["d_stability"], stab - 40.0)
	refs["d_legitimacy"].text = "%d" % int(round(float(c["legitimacy"])))
	refs["d_prestige"].text = UI.fmt(float(c["prestige"]))
	refs["d_manpower"].text = "%s / %s" % [UI.fmt(float(c["manpower"])), UI.fmt(float(c["manpower_max"]))]
	refs["d_food"].text = "%s (%s)" % [UI.fmt(float(c["stock"]["food"])), UI.signed(fb)]
	var evb: Button = refs["events_btn"]
	evb.modulate = Color(1, 0.8, 0.3) if pending_events > 0 else Color.WHITE
	var badge: Label = refs["events_badge"]
	badge.visible = pending_events > 0
	badge.text = str(pending_events)

func _set_chip(id: String, text: String, tint: Color = Color("f4ecd6")) -> void:
	var b: Button = _chips[id]
	b.text = text
	b.add_theme_color_override("font_color", tint)
	b.add_theme_color_override("font_hover_color", tint.lightened(0.25))
	b.add_theme_color_override("font_pressed_color", tint.lightened(0.25))

## Hide low-priority elements until the content fits `width`.
func fit(width: float, wide_inline: bool) -> void:
	_wide = wide_inline
	var all_hideable: Array = _inline_secondary + _hide_order
	for c in all_hideable:
		(c as Control).visible = true
	(refs["date_block"] as Control).visible = true
	for c in _inline_secondary:
		(c as Control).visible = wide_inline
	var order: Array = []
	order.append_array(_inline_secondary)
	order.append_array(_hide_order)
	order.append(refs["date_block"])
	var avail := width - 24.0
	for c in order:
		if box.get_combined_minimum_size().x <= avail:
			break
		(c as Control).visible = false
