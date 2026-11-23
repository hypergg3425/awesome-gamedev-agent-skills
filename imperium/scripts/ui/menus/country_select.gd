extends Control
## Nation selection on a live map preview, with difficulty and hot-seat options.

var state: Dictionary
var mapview: MapView
var cmap: CampaignMap
var info: VBoxContainer
var list: VBoxContainer
var chosen := ""
var difficulty := "normal"
var hotseat: Array = []
var def: Dictionary
var start_btn: Button
var hot_label: Label

func _ready() -> void:
	theme = UI.theme()
	def = Defs.all_scenarios().get(Nav.scenario_id, {})
	if def.is_empty():
		Nav.go(get_tree(), "scenarios")
		return
	Ads.show_banner()
	var def_player := str(def.get("default_player", def["countries"].keys()[0]))
	state = ScenarioLoader.build(def, def_player, "normal", 1)
	Game.state = state
	Game.active_player = def_player
	mapview = MapView.new()
	mapview.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(mapview)
	mapview.setup(Defs.load_geometry(), Defs.map_meta)
	cmap = CampaignMap.new()
	cmap.attach(mapview, Defs.load_geometry())
	mapview.province_tapped.connect(func(pid: String) -> void:
		var o: String = state["provinces"][pid]["owner"]
		if state["countries"].has(o) and state["countries"][o]["playable"]:
			choose(o))
	_build_ui()
	cmap.refresh()
	choose(def_player)
	await get_tree().process_frame
	mapview.fit_world()

func _build_ui() -> void:
	var ui := Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)
	var root := Nav.safe_root(ui)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(v)
	var bar := PanelContainer.new()
	bar.theme_type_variation = "Hud"
	var bh := HBoxContainer.new()
	bar.add_child(bh)
	bh.add_child(UI.icon_button("back", func() -> void: Nav.go(get_tree(), "scenarios"), Loc.t("UI_BACK"), 52.0))
	bh.add_child(UI.label("%s – %s" % [Loc.tx(def["name"]), Loc.t("CS_TITLE")], "Heading"))
	v.add_child(bar)
	var h := HBoxContainer.new()
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(h)
	var left := PanelContainer.new()
	left.theme_type_variation = "Sheet"
	left.custom_minimum_size = Vector2(320, 0)
	list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	left.add_child(UI.scroll(list))
	h.add_child(left)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(sp)
	var right := PanelContainer.new()
	right.theme_type_variation = "Sheet"
	right.custom_minimum_size = Vector2(400, 0)
	var rv := VBoxContainer.new()
	right.add_child(rv)
	info = VBoxContainer.new()
	rv.add_child(UI.scroll(info))
	# difficulty
	rv.add_child(UI.label(Loc.t("CS_DIFFICULTY"), "Sub"))
	var dh := HBoxContainer.new()
	dh.add_theme_constant_override("separation", 4)
	var diff_desc := UI.label(Loc.t("DIFFD_NORMAL"), "Tiny", -1, true)
	for dname in Const.DIFFICULTIES:
		var dn: String = dname
		var db := UI.button(Loc.t("DIFF_" + dn.to_upper()), func() -> void:
			difficulty = dn
			diff_desc.text = Loc.t("DIFFD_" + dn.to_upper())
			_refresh_diff(dh), "Primary" if dn == difficulty else "Tab")
		db.custom_minimum_size = Vector2(0, 44)
		db.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		db.set_meta("d", dn)
		dh.add_child(db)
	rv.add_child(dh)
	rv.add_child(diff_desc)
	hot_label = UI.label("", "Tiny", -1, true)
	rv.add_child(hot_label)
	var hot := UI.button(Loc.t("CS_ADD_HOTSEAT"), func() -> void: _add_hotseat(), "", "country")
	rv.add_child(hot)
	start_btn = UI.button(Loc.t("CS_START"), func() -> void: _start(), "Primary", "next")
	start_btn.custom_minimum_size = Vector2(0, 62)
	rv.add_child(start_btn)
	h.add_child(right)
	# list of playable countries sorted by size
	var arr: Array = []
	for cid in state["countries"]:
		var c: Dictionary = state["countries"][cid]
		if c.get("playable", false) and c["alive"]:
			arr.append([-DiplomacySystem.power_score(state, cid), cid])
	arr.sort()
	for it in arr:
		var cid: String = it[1]
		var c: Dictionary = state["countries"][cid]
		var b := Button.new()
		b.theme_type_variation = "Tab"
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 52)
		var hb := HBoxContainer.new()
		hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.set_anchors_preset(Control.PRESET_FULL_RECT)
		hb.offset_left = 8
		hb.add_child(FlagView.make(c["flag"], Util.color_from(c["color"]), Vector2(44, 29)))
		var nl := UI.label(GS.country_name(state, cid), "Value")
		nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		nl.clip_text = true
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(nl)
		b.add_child(hb)
		b.pressed.connect(func() -> void:
			Audio.sfx("ui_click")
			choose(cid)
			mapview.focus_province(c["capital"], 2.2))
		list.add_child(b)

func _refresh_diff(dh: HBoxContainer) -> void:
	for b in dh.get_children():
		(b as Button).theme_type_variation = "Primary" if b.get_meta("d") == difficulty else "Tab"

func choose(cid: String) -> void:
	chosen = cid
	Game.active_player = cid
	state["player"] = cid
	var c: Dictionary = state["countries"][cid]
	UI.clear(info)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	h.add_child(FlagView.make(c["flag"], Util.color_from(c["color"]), Vector2(90, 60)))
	var vb := VBoxContainer.new()
	vb.add_child(UI.label(GS.country_name(state, cid), "Heading"))
	vb.add_child(UI.label(Defs.gov_name(c["gov"]), "Small"))
	h.add_child(vb)
	info.add_child(h)
	info.add_child(UI.hsep())
	var bud := EconomySystem.budget(state, cid)
	Sheet.kv(info, Loc.t("C_RULER"), "%s (%d)" % [str(c["ruler"]["name"]), int(float(c["ruler"]["age"]))])
	Sheet.kv(info, Loc.t("C_PROVINCES"), str(GS.owned(state, cid).size()))
	Sheet.kv(info, Loc.t("C_POPULATION"), UI.fmt(DiplomacySystem.total_pop(state, cid) * 1000.0))
	Sheet.kv(info, Loc.t("C_INCOME"), "%.0f" % float(bud["income"]))
	Sheet.kv(info, Loc.t("C_MILITARY"), "%s %s" % [UI.fmt(UnitUtil.country_regiments(state, cid)), Loc.t("UI_REGIMENTS")])
	Sheet.kv(info, Loc.t("C_RELIGION"), Fmt.religion_name(c["religion"]))
	Sheet.kv(info, Loc.t("C_TECH"), "%.1f / 4" % TechSystem.avg_level(c))
	# difficulty hint from relative power
	var rank := 0
	var me := DiplomacySystem.power_score(state, cid)
	var total := 0
	for oid in GS.alive_countries(state):
		if not str(oid).begins_with("NAT_"):
			total += 1
			if DiplomacySystem.power_score(state, oid) > me:
				rank += 1
	var rating := "easy" if rank <= total * 0.2 else ("medium" if rank <= total * 0.55 else "hard")
	Sheet.kv(info, Loc.t("CS_RATING"), Loc.t("CS_RATING_" + rating.to_upper()), "", UI.GOOD if rating == "easy" else (UI.WARN if rating == "medium" else UI.BAD))
	if not c.get("traditions", []).is_empty():
		for t in c["traditions"]:
			info.add_child(UI.label("• " + Loc.tx(t), "Tiny", -1, true))
	var nb := Sheet.card(info)
	nb.add_child(UI.label(Loc.t("CS_NEIGHBOURS"), "Sub"))
	var names: Array = []
	for pid in GS.owned(state, cid):
		for nbp in Defs.neighbors(pid):
			var o: String = state["provinces"][nbp]["owner"]
			if o != cid and o != "" and GS.country_name(state, o) not in names and not str(o).begins_with("NAT_"):
				names.append(GS.country_name(state, o))
	nb.add_child(UI.label(", ".join(names.slice(0, 10)), "Tiny", -1, true))
	cmap.select(c["capital"])
	cmap.refresh()
	mapview.focus_province(c["capital"], 2.0)

func _add_hotseat() -> void:
	if hotseat.size() >= 3:
		return
	if chosen in hotseat:
		return
	hotseat.append(chosen)
	var names: Array = []
	for h in hotseat:
		names.append(GS.country_name(state, h))
	hot_label.text = Loc.t("CS_HOTSEAT") + ": " + ", ".join(names)

func _start() -> void:
	var players: Array = []
	if not hotseat.is_empty():
		players = hotseat.duplicate()
		if chosen not in players:
			players.append(chosen)
		if players.size() < 2:
			players = []
	var r: Dictionary = Game.new_game(Nav.scenario_id, chosen, difficulty, 0, players)
	if not r["ok"]:
		Dialogs.info(self, Loc.t("ERR_GENERIC"), NoteFmt.error_text(str(r["reason"])))
		return
	Nav.go(get_tree(), "campaign")
