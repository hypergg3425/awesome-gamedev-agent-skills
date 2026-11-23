class_name CampaignScreen
extends Control
## The main campaign scene: world map + HUD + side panels. Pure UI: all rules live in the systems.

const MODES := ["political", "terrain", "economic", "diplomatic", "military", "population", "supply", "trade"]

var mapview: MapView
var cmap: CampaignMap
var ui_root: Control
var hud: PanelContainer
var hud_box: HBoxContainer
var toolbar: VBoxContainer
var sheet_layer: Control
var overlay_layer: Control
var toast_box: VBoxContainer
var end_btn: Button
var mode_strip: VBoxContainer
var province_panel: ProvincePanel
var move_bar: PanelContainer
var move_label: Label
var sheets := {}
var open_sheet_name := ""
var _refresh_queued := false
var _busy := false
var _pending_move: Dictionary = {}
var hud_refs := {}

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	theme = UI.theme()
	_build()
	Game.state_changed.connect(_queue_refresh)
	Game.command_failed.connect(_on_command_failed)
	Game.achievement_unlocked.connect(func(aid: String) -> void:
		toast("%s: %s" % [Loc.t("MENU_ACHIEVEMENTS"), Loc.t("ACH_" + aid.to_upper())], "prestige", 4.5))
	Loc.language_changed.connect(func(_l: String) -> void: _rebuild_static())
	Settings.changed.connect(func(k: String) -> void:
		if k in ["map_labels", "army_markers", "colorblind"]:
			_queue_refresh()
		elif k == "text_scale":
			theme = UI.rebuild_theme()
			_rebuild_static())
	Ads.state_changed.connect(func(_s: String) -> void: _apply_layout())
	get_viewport().size_changed.connect(_apply_layout)
	Audio.play_music("music_campaign")
	Ads.show_banner()
	await get_tree().process_frame
	_apply_layout()
	mapview.fit_world()
	_focus_player()
	_refresh_all()
	_show_pending_events()

func _exit_tree() -> void:
	Ads.hide_banner()

## --- construction ---------------------------------------------------------------------------------
func _build() -> void:
	mapview = MapView.new()
	mapview.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(mapview)
	mapview.setup(Defs.load_geometry(), Defs.map_meta)
	cmap = CampaignMap.new()
	cmap.attach(mapview, Defs.load_geometry())
	mapview.province_tapped.connect(_on_province_tapped)
	mapview.province_long_pressed.connect(_on_province_long)
	mapview.empty_tapped.connect(_on_empty_tapped)
	ui_root = Control.new()
	ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui_root)
	_build_hud()
	_build_toolbar()
	_build_mode_strip()
	sheet_layer = Control.new()
	sheet_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	sheet_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(sheet_layer)
	province_panel = ProvincePanel.new(self)
	province_panel.visible = false
	ui_root.add_child(province_panel)
	_build_end_turn()
	_build_move_bar()
	toast_box = VBoxContainer.new()
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast_box.position = Vector2(-300, 86)
	toast_box.custom_minimum_size = Vector2(600, 0)
	ui_root.add_child(toast_box)
	overlay_layer = Control.new()
	overlay_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay_layer)
	_create_sheets()

func _rebuild_static() -> void:
	# language / text scale changed: rebuild HUD & toolbar texts
	UI.clear(hud_box)
	UI.clear(toolbar)
	UI.clear(mode_strip)
	hud_refs.clear()
	_fill_hud()
	_fill_toolbar()
	_fill_mode_strip()
	end_btn.text = Loc.t("UI_END_TURN")
	for s in sheets.values():
		(s as Sheet).relocalize()
	_queue_refresh()

func _build_hud() -> void:
	hud = PanelContainer.new()
	hud.theme_type_variation = "Hud"
	hud.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hud.custom_minimum_size = Vector2(0, 64)
	ui_root.add_child(hud)
	hud_box = HBoxContainer.new()
	hud_box.add_theme_constant_override("separation", 14)
	hud.add_child(hud_box)
	_fill_hud()

func _stat_node(id: String, icon: String, tip_key: String, tint: Color = Color("f4ecd6")) -> HBoxContainer:
	var h := UI.stat(icon, "0", tint, Loc.t(tip_key))
	hud_refs[id] = h.get_child(1)
	return h

func _fill_hud() -> void:
	var b := Button.new()
	b.theme_type_variation = "Flat"
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(190, 52)
	var hb := HBoxContainer.new()
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.set_anchors_preset(Control.PRESET_FULL_RECT)
	var flag := FlagView.make({}, Color.GRAY, Vector2(50, 33))
	flag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_refs["flag"] = flag
	hb.add_child(flag)
	var nm := UI.label("", "Sub")
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nm.clip_text = true
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud_refs["name"] = nm
	hb.add_child(nm)
	b.add_child(hb)
	b.pressed.connect(func() -> void:
		Audio.sfx("ui_click")
		open_sheet("country"))
	hud_box.add_child(b)
	var date := UI.label("", "Value")
	hud_refs["date"] = date
	hud_box.add_child(date)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud_box.add_child(sp)
	hud_box.add_child(_stat_node("gold", "gold", "TIP_GOLD", Color("f0cf6a")))
	hud_box.add_child(_stat_node("manpower", "manpower", "TIP_MANPOWER"))
	hud_box.add_child(_stat_node("food", "food", "TIP_FOOD", Color("b7d98a")))
	hud_box.add_child(_stat_node("admin", "admin", "TIP_ADMIN", Color("9ec5ee")))
	hud_box.add_child(_stat_node("stability", "stability", "TIP_STABILITY"))
	hud_box.add_child(_stat_node("legitimacy", "legitimacy", "TIP_LEGITIMACY"))
	hud_box.add_child(_stat_node("prestige", "prestige", "TIP_PRESTIGE", Color("e0b0e8")))
	var ev := UI.icon_button("events", func() -> void: open_sheet("events"), Loc.t("PANEL_EVENTS"), 50.0)
	hud_refs["events_btn"] = ev
	hud_box.add_child(ev)
	hud_box.add_child(UI.icon_button("menu", func() -> void: _open_menu(), Loc.t("UI_MENU"), 50.0))

func _build_toolbar() -> void:
	toolbar = VBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 6)
	toolbar.position = Vector2(8, 78)
	ui_root.add_child(toolbar)
	_fill_toolbar()

func _fill_toolbar() -> void:
	for t in [["economy", "economy", "PANEL_ECONOMY"], ["military", "military", "PANEL_MILITARY"], ["diplomacy", "diplomacy", "PANEL_DIPLOMACY"],
			["technology", "technology", "PANEL_TECH"], ["politics", "politics", "PANEL_POLITICS"], ["objectives", "objectives", "PANEL_OBJECTIVES"]]:
		var key: String = t[0]
		var b := UI.icon_button(t[1], func() -> void: open_sheet(key), Loc.t(t[2]), 58.0)
		toolbar.add_child(b)
	toolbar.add_child(UI.spacer(6))
	toolbar.add_child(UI.icon_button("map", func() -> void:
		mode_strip.visible = not mode_strip.visible, Loc.t("UI_MAP_MODES"), 58.0))

func _build_mode_strip() -> void:
	mode_strip = VBoxContainer.new()
	mode_strip.add_theme_constant_override("separation", 4)
	mode_strip.position = Vector2(76, 392)
	mode_strip.visible = false
	ui_root.add_child(mode_strip)
	_fill_mode_strip()

func _fill_mode_strip() -> void:
	for m in MODES:
		var mm: String = m
		var b := UI.icon_button("mode_" + mm, func() -> void: set_map_mode(mm), Loc.t("MODE_" + mm.to_upper()), 50.0, "Primary" if cmap and cmap.mode == mm else "")
		mode_strip.add_child(b)

func set_map_mode(m: String) -> void:
	cmap.mode = m
	mode_strip.visible = false
	UI.clear(mode_strip)
	_fill_mode_strip()
	cmap.refresh()
	toast(Loc.t("MODE_" + m.to_upper()), "map")

func _build_end_turn() -> void:
	end_btn = UI.button(Loc.t("UI_END_TURN"), func() -> void: _on_end_turn(), "Primary", "end_turn")
	end_btn.custom_minimum_size = Vector2(210, 64)
	end_btn.add_theme_font_size_override("font_size", UI.fs(24))
	ui_root.add_child(end_btn)

func _build_move_bar() -> void:
	move_bar = PanelContainer.new()
	move_bar.theme_type_variation = "Toast"
	move_bar.visible = false
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	move_bar.add_child(h)
	move_label = UI.label("", "Value")
	move_label.custom_minimum_size = Vector2(380, 0)
	move_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	h.add_child(move_label)
	h.add_child(UI.button(Loc.t("UI_CANCEL"), func() -> void: _cancel_move_preview()))
	h.add_child(UI.button(Loc.t("UI_CONFIRM"), func() -> void: _confirm_move(), "Primary", "check"))
	ui_root.add_child(move_bar)

## --- layout (safe area + banner) ------------------------------------------------------------------------------
func _apply_layout() -> void:
	if ui_root == null:
		return
	var ins := UI.safe_insets(get_viewport())
	var bottom := float(ins["bottom"]) + Ads.reserved_height()
	ui_root.offset_left = float(ins["left"])
	ui_root.offset_top = float(ins["top"])
	ui_root.offset_right = -float(ins["right"])
	ui_root.offset_bottom = -bottom
	mapview.offset_bottom = -bottom
	var sz := get_viewport_rect().size
	var avail := Vector2(sz.x - float(ins["left"]) - float(ins["right"]), sz.y - float(ins["top"]) - bottom)
	end_btn.position = Vector2(avail.x - 226.0, avail.y - 80.0)
	move_bar.position = Vector2(maxf(90.0, avail.x * 0.5 - 330.0), avail.y - 92.0)
	for s in sheets.values():
		_place_sheet(s)
	province_panel.place(avail)

func _place_sheet(s: Sheet) -> void:
	var sz := ui_root.size
	var w := minf(780.0, sz.x * 0.62)
	s.position = Vector2(82, 72)
	s.custom_minimum_size = Vector2(w, 0)
	s.size = Vector2(w, maxf(200.0, sz.y - 150.0))

## --- sheets --------------------------------------------------------------------------------------------------------------
func _create_sheets() -> void:
	var defs := {
		"country": ["PANEL_COUNTRY", "country", PanelsCountry],
		"economy": ["PANEL_ECONOMY", "economy", PanelsEconomy],
		"military": ["PANEL_MILITARY", "military", PanelsMilitary],
		"diplomacy": ["PANEL_DIPLOMACY", "diplomacy", PanelsDiplomacy],
		"technology": ["PANEL_TECH", "technology", PanelsTech],
		"politics": ["PANEL_POLITICS", "politics", PanelsPolitics],
		"objectives": ["PANEL_OBJECTIVES", "objectives", PanelsObjectives],
		"events": ["PANEL_EVENTS", "events", PanelsEvents],
	}
	for id in defs:
		var d: Array = defs[id]
		var sh := Sheet.new(d[0], d[1])
		sh.visible = false
		sheet_layer.add_child(sh)
		d[2].build(sh, self)
		sh.closed.connect(func() -> void: open_sheet_name = "")
		sheets[id] = sh
		_place_sheet(sh)

func open_sheet(id: String) -> void:
	if not sheets.has(id):
		return
	var was_open: bool = open_sheet_name == id and sheets[id].visible
	for k in sheets:
		sheets[k].visible = false
	if was_open:
		open_sheet_name = ""
		return
	open_sheet_name = id
	(sheets[id] as Sheet).open()
	_place_sheet(sheets[id])

func close_sheets() -> void:
	for k in sheets:
		sheets[k].visible = false
	open_sheet_name = ""

func refresh_open_sheet() -> void:
	if open_sheet_name != "" and sheets[open_sheet_name].visible:
		(sheets[open_sheet_name] as Sheet).refresh()

## --- refresh ---------------------------------------------------------------------------------------------------------------
func _queue_refresh() -> void:
	if _refresh_queued:
		return
	_refresh_queued = true
	call_deferred("_refresh_all")

func _refresh_all() -> void:
	_refresh_queued = false
	if not Game.has_state():
		return
	cmap.refresh()
	update_hud()
	refresh_open_sheet()
	province_panel.refresh()

func update_hud() -> void:
	var s: Dictionary = Game.state
	var c: Dictionary = Game.pc()
	var b: Dictionary = c.get("budget", {})
	(hud_refs["flag"] as FlagView).setup(c.get("flag", {}), Util.color_from(c.get("color", "#888888")))
	hud_refs["name"].text = Loc.tx(c.get("short", c.get("name", "")))
	hud_refs["date"].text = GS.date_string(s) + "   " + Loc.tf("UI_TURN_N", {"n": int(s["turn"]) + 1})
	var net := float(b.get("net", 0.0))
	hud_refs["gold"].text = "%s (%s)" % [UI.fmt(float(c["gold"])), UI.signed(net)]
	UI.tint_label(hud_refs["gold"], 1.0 if float(c["gold"]) >= 0.0 else -1.0)
	hud_refs["manpower"].text = "%s/%s" % [UI.fmt(float(c["manpower"])), UI.fmt(float(c["manpower_max"]))]
	var fb := float(b.get("food_balance", 0.0))
	hud_refs["food"].text = "%s (%s)" % [UI.fmt(float(c["stock"]["food"])), UI.signed(fb)]
	hud_refs["admin"].text = UI.fmt(float(c["admin"]))
	hud_refs["stability"].text = "%d" % int(round(float(c["stability"])))
	UI.tint_label(hud_refs["stability"], float(c["stability"]) - 40.0)
	hud_refs["legitimacy"].text = "%d" % int(round(float(c["legitimacy"])))
	hud_refs["prestige"].text = UI.fmt(float(c["prestige"]))
	var pend := Game.pending_events().size()
	var evb: Button = hud_refs["events_btn"]
	evb.modulate = Color(1, 0.8, 0.3) if pend > 0 else Color.WHITE
	end_btn.disabled = bool(s.get("game_over", false)) or _busy

func _focus_player() -> void:
	var cap: String = Game.pc().get("capital", "")
	if cap != "":
		mapview.focus_province(cap, 2.4)
		select_province(cap)

## --- selection / interaction ------------------------------------------------------------------------------------------------
func select_province(pid: String) -> void:
	Game.select_province(pid)
	cmap.select(pid)
	province_panel.show_province(pid)

func _on_province_tapped(pid: String) -> void:
	Audio.sfx("ui_click", -6.0)
	var a: Dictionary = Game.state["armies"].get(Game.selected_army, {})
	if not a.is_empty() and a["owner"] == Game.active_player and a["loc"] != pid and a["loc"] != "" and not move_bar.visible and Game.selected_army != "":
		_preview_move(Game.selected_army, pid)
		return
	if move_bar.visible:
		_cancel_move_preview()
	select_province(pid)

func _on_province_long(pid: String) -> void:
	mapview.focus_province(pid, 4.0)

func _on_empty_tapped() -> void:
	if move_bar.visible:
		_cancel_move_preview()
		return
	Game.selected_army = ""
	province_panel.visible = false
	cmap.select("")
	close_sheets()
	_queue_refresh()

func select_army(aid: String) -> void:
	Game.select_army(aid)
	var a: Dictionary = Game.state["armies"].get(aid, {})
	if not a.is_empty() and a["loc"] != "":
		toast(Loc.t("MOVE_TAP_TARGET"), "move")

func _preview_move(aid: String, target: String) -> void:
	var r := MilitarySystem.find_path(Game.state, aid, target)
	if not r["ok"]:
		toast(NoteFmt.error_text(str(r.get("reason", "ERR_INVALID")), r.get("params", {})), "warning")
		return
	var a: Dictionary = Game.state["armies"][aid]
	var turns := _eta(a, r["path"])
	_pending_move = {"aid": aid, "target": target}
	cmap.set_preview(aid, r["path"])
	move_label.text = Loc.tf("MOVE_PREVIEW", {"to": Defs.province_name(target), "n": turns})
	move_bar.visible = true

func _eta(a: Dictionary, path: Array) -> int:
	var mp := MilitarySystem.move_points(Game.state, a)
	var cost := 0.0
	var prev: String = a["loc"]
	var turns := 1
	var left := mp
	for pid in path:
		var lk: Array = MilitarySystem.link_between(prev, pid)
		var c: float
		if lk[0] == "lane":
			turns += maxi(1, int(ceil(float(lk[1]) / MilitarySystem.SEA_KM_PER_TURN)))
			left = 0.0
			prev = pid
			continue
		c = MilitarySystem.move_cost(Game.state, a, pid, lk[0])
		if left < c * 0.75:
			turns += 1
			left = mp
		left -= c
		prev = pid
	return turns

func _cancel_move_preview() -> void:
	move_bar.visible = false
	_pending_move = {}
	cmap.set_preview("", [])

func _confirm_move() -> void:
	if _pending_move.is_empty():
		return
	var r := Game.cmd_move(_pending_move["aid"], _pending_move["target"])
	_cancel_move_preview()
	if r.get("ok", false):
		Audio.sfx("march")

func _on_command_failed(reason: String, params: Dictionary) -> void:
	Audio.sfx("ui_error")
	toast(NoteFmt.error_text(reason, params), "warning")

## --- toasts -------------------------------------------------------------------------------------------------------------------------
func toast(text: String, icon: String = "info", seconds: float = 3.2) -> void:
	var pc := PanelContainer.new()
	pc.theme_type_variation = "Toast"
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	h.add_child(UI.icon_rect(icon, 28, UI.GOLD_LIGHT))
	var l := UI.label(text, "Value")
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(520, 0)
	h.add_child(l)
	pc.add_child(h)
	toast_box.add_child(pc)
	while toast_box.get_child_count() > 4:
		toast_box.get_child(0).queue_free()
		toast_box.remove_child(toast_box.get_child(0))
	if bool(Settings.get_value("animations")):
		pc.modulate.a = 0.0
		create_tween().tween_property(pc, "modulate:a", 1.0, 0.25)
	get_tree().create_timer(seconds).timeout.connect(func() -> void:
		if is_instance_valid(pc):
			var tw := create_tween()
			tw.tween_property(pc, "modulate:a", 0.0, 0.3)
			tw.tween_callback(pc.queue_free))

## --- end turn flow -----------------------------------------------------------------------------------------------------------------------
func _on_end_turn() -> void:
	if _busy:
		return
	var chk := Game.can_end_turn()
	if not chk["ok"]:
		if chk["reason"] == "TURN_ERR_EVENTS":
			_show_pending_events()
		else:
			toast(NoteFmt.error_text(chk["reason"]), "warning")
		return
	# friendly warnings (never blocking)
	var c := Game.pc()
	var warns: Array = []
	if float(c["gold"]) < 0.0:
		warns.append(Loc.t("WARN_NEGATIVE_GOLD"))
	var idle_branches := 0
	for b in Const.BRANCHES:
		if str(c["research"]["current"].get(b, "")) == "":
			idle_branches += 1
	if idle_branches >= 3 and int(Game.state["turn"]) > 0:
		warns.append(Loc.t("WARN_IDLE_RESEARCH"))
	if not warns.is_empty() and bool(Settings.get_value("confirm_actions")):
		Dialogs.confirm(overlay_layer, Loc.t("WARN_TITLE"), "\n".join(warns), func() -> void: _run_end_turn(), Loc.t("UI_END_TURN"))
		return
	_run_end_turn()

func _run_end_turn() -> void:
	_busy = true
	end_btn.disabled = true
	var spin := _spinner()
	Audio.sfx("turn_end")
	await get_tree().process_frame
	await get_tree().process_frame
	var res: Dictionary = Game.end_turn()
	spin.queue_free()
	_busy = false
	if res.get("passed", false):
		_hotseat_handoff()
		return
	_after_turn(res)

func _spinner() -> Control:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.35)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	var l := UI.label(Loc.t("UI_RESOLVING_TURN"), "Heading", HORIZONTAL_ALIGNMENT_CENTER)
	l.set_anchors_preset(Control.PRESET_CENTER)
	l.position = Vector2(size.x / 2.0 - 200, size.y / 2.0 - 20)
	l.custom_minimum_size = Vector2(400, 40)
	dim.add_child(l)
	overlay_layer.add_child(dim)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	return dim

func _hotseat_handoff() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.05, 0.1, 1.0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER)
	v.position = Vector2(size.x / 2.0 - 260, size.y / 2.0 - 120)
	v.custom_minimum_size = Vector2(520, 0)
	v.add_child(UI.label(Loc.t("HOTSEAT_PASS"), "Heading", HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UI.label(GS.country_name(Game.state, Game.active_player), "Title", HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UI.button(Loc.t("HOTSEAT_READY"), func() -> void:
		dim.queue_free()
		_focus_player()
		_queue_refresh()
		_show_pending_events(), "Primary"))
	dim.add_child(v)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay_layer.add_child(dim)
	cmap.refresh()

func _after_turn(res: Dictionary) -> void:
	_queue_refresh()
	var me := Game.active_player
	var notes := Game.notes_this_turn(me)
	var shown := 0
	for n in notes:
		if shown >= 4:
			break
		if n["cat"] in ["battle", "diplomacy", "war", "economy", "tech", "construction", "politics", "uprising", "disaster", "objective", "military", "world"]:
			toast(NoteFmt.text(Game.state, n), NoteFmt.category_icon(n["cat"]), 4.0)
			shown += 1
	# battle reports for the player
	var mine: Array = []
	for r in res.get("battles", []):
		if me in r["attackers"]["owners"] or me in r["defenders"]["owners"]:
			mine.append(r)
	if not mine.is_empty():
		Audio.sfx("clash")
		BattleReportView.show_reports(overlay_layer, Game.state, mine, func() -> void: _after_battles())
	else:
		_after_battles()

func _after_battles() -> void:
	if bool(Game.state.get("game_over", false)):
		_show_end_screen()
		return
	_show_pending_requests()
	_show_pending_events()

func _show_pending_requests() -> void:
	var pend: Array = Game.state["pending_requests"]
	for r in pend:
		if r["to"] == Game.active_player and not r.get("shown", false):
			r["shown"] = true
			DiplomacyPrompts.show_request(overlay_layer, r)
			return

func _show_pending_events() -> void:
	var evs := Game.pending_events()
	if evs.is_empty():
		return
	EventDialog.show_event(overlay_layer, Game.state, evs[0], func() -> void:
		_queue_refresh()
		_show_pending_events())

func _show_end_screen() -> void:
	EndScreen.show_end(self)

## Android back button: dismiss panels first, otherwise open the pause menu (never quits mid-campaign).
func on_back_requested() -> void:
	if overlay_layer.get_child_count() > 0:
		return   # a modal dialog is up; it must be answered explicitly
	if open_sheet_name != "":
		close_sheets()
	elif province_panel != null and province_panel.visible:
		province_panel.visible = false
		cmap.select("")
	else:
		_open_menu()

func _open_menu() -> void:
	PauseMenu.show_menu(overlay_layer, self)
