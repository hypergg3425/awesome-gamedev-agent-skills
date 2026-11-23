class_name ProvincePanel
extends PanelContainer
## Right-hand province inspector: info, construction, military. Shown when a province is selected.

var screen: CampaignScreen
var pid := ""
var tab := "info"
var head: HBoxContainer
var tabs_row: HBoxContainer
var body: VBoxContainer
var title: Label
var flag: FlagView

func _init(p_screen: CampaignScreen) -> void:
	screen = p_screen
	theme_type_variation = "Sheet"
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	add_child(root)
	head = HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	root.add_child(head)
	flag = FlagView.make({}, Color.GRAY, Vector2(46, 31))
	head.add_child(flag)
	title = UI.label("", "Sub")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.clip_text = true
	head.add_child(title)
	head.add_child(UI.icon_button("zoom_in", func() -> void: screen.mapview.focus_province(pid, 4.5), Loc.t("UI_FOCUS"), 42.0))
	head.add_child(UI.icon_button("close", func() -> void:
		visible = false
		screen.cmap.select(""), Loc.t("UI_CLOSE"), 42.0))
	tabs_row = HBoxContainer.new()
	tabs_row.add_theme_constant_override("separation", 4)
	root.add_child(tabs_row)
	for t in [["info", "PTAB_INFO"], ["build", "PTAB_BUILD"], ["army", "PTAB_ARMY"]]:
		var id: String = t[0]
		var b := UI.button(Loc.t(t[1]), func() -> void:
			tab = id
			refresh(), "Tab")
		b.custom_minimum_size = Vector2(0, 42)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.set_meta("tab", id)
		b.set_meta("key", t[1])
		tabs_row.add_child(b)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	root.add_child(UI.scroll(body))
	Loc.language_changed.connect(func(_l: String) -> void:
		for b in tabs_row.get_children():
			(b as Button).text = Loc.t(str(b.get_meta("key")))
		refresh())

func place(avail: Vector2) -> void:
	var w := minf(390.0, avail.x * 0.34)
	position = Vector2(avail.x - w - 8.0, 72.0)
	size = Vector2(w, maxf(200.0, avail.y - 72.0 - 96.0))
	custom_minimum_size = Vector2(w, 0)
	clip_contents = true

func show_province(p_pid: String) -> void:
	pid = p_pid
	visible = true
	refresh()

func refresh() -> void:
	if not visible or pid == "" or not Game.has_state():
		return
	var s: Dictionary = Game.state
	var p: Dictionary = s["provinces"][pid]
	var owner: String = p["owner"]
	title.text = Defs.province_name(pid)
	flag.setup(s["countries"][owner].get("flag", {}), Util.color_from(s["countries"][owner].get("color", "#888")))
	for b in tabs_row.get_children():
		(b as Button).theme_type_variation = "Primary" if b.get_meta("tab") == tab else "Tab"
	UI.clear(body)
	match tab:
		"info":
			_info(s, p)
		"build":
			_build(s, p)
		"army":
			_army(s, p)
	_shrinkable(body)

# Make every button/progress label shrinkable so long (e.g. Turkish) text can never
# widen the panel beyond the viewport.
func _shrinkable(n: Node) -> void:
	for ch in n.get_children():
		if ch is Button:
			(ch as Button).clip_text = true
		_shrinkable(ch)

func _info(s: Dictionary, p: Dictionary) -> void:
	var pd: Dictionary = Defs.provinces[pid]
	var owner: String = p["owner"]
	var me: String = Game.active_player
	var c: Dictionary = s["countries"][owner]
	var calc := EconomySystem.province_calc(s, pid)
	var box := Sheet.card(body)
	Sheet.kv(box, Loc.t("P_OWNER"), GS.country_name(s, owner))
	if p["controller"] != owner:
		Sheet.kv(box, Loc.t("P_OCCUPIED_BY"), GS.country_name(s, p["controller"]), "", UI.BAD)
	var terr := UI.stat("terrain_" + str(pd["terrain"]), Fmt.terrain_name(str(pd["terrain"])), Color("d8d0b8"), "", "Small")
	box.add_child(terr)
	Sheet.kv(box, Loc.t("P_POP"), UI.fmt(float(p["pop"]) * 1000.0), Loc.t("TIP_POP"))
	Sheet.kv(box, Loc.t("P_DEV"), "%.1f" % float(p["dev"]), Loc.t("TIP_DEV"))
	Sheet.kv(box, Loc.t("P_CULTURE"), Fmt.culture_name(str(p["culture"])) if Loc.has_key("CULT_" + str(p["culture"]).to_upper()) else str(p["culture"]))
	Sheet.kv(box, Loc.t("P_RELIGION"), Fmt.religion_name(str(p["religion"])) if Loc.has_key("REL_" + str(p["religion"]).to_upper()) else str(p["religion"]))
	var ut := PopulationSystem.unrest_target(s, pid)
	var tip: Array = []
	for k in ut["parts"]:
		tip.append("%s: %s" % [Loc.t(k), UI.signed(float(ut["parts"][k]), 1)])
	var ub := UI.progress(float(p["unrest"]), 100.0, UI.BAD if float(p["unrest"]) > 50.0 else UI.GOLD, "%s %d" % [Loc.t("P_UNREST"), int(p["unrest"])])
	ub.tooltip_text = "\n".join(tip)
	box.add_child(ub)
	var eco := Sheet.card(body)
	Sheet.header(eco, Loc.t("P_ECONOMY"))
	Sheet.kv(eco, Loc.t("P_TAX"), "%.1f" % float(calc["tax"]))
	Sheet.kv(eco, Loc.t("P_PRODUCTION"), "%.1f" % float(calc["production"]))
	Sheet.kv(eco, Loc.t("P_COMMERCE"), "%.1f" % float(calc["commerce"]))
	Sheet.kv(eco, Loc.t("P_MANPOWER"), "%.1f" % float(calc["manpower"]))
	Sheet.kv(eco, Loc.t("P_FOOD"), UI.signed(float(calc["food_prod"]) - float(calc["food_cons"]), 0), "", UI.color_for(float(calc["food_prod"]) - float(calc["food_cons"])))
	for r in ["iron", "wood", "stone", "coal", "lux"]:
		var amt := float(calc["mats"][r])
		if amt >= 0.05:
			eco.add_child(UI.stat(Fmt.RES_ICON[r], "%.1f / %s" % [amt, Loc.t("UI_TURN_SHORT")], Fmt.RES_COLOR[r], Loc.t("RES_" + r.to_upper()), "Small"))
	var mil := Sheet.card(body)
	Sheet.header(mil, Loc.t("P_DEFENCE"))
	Sheet.kv(mil, Loc.t("P_FORT"), "%.1f" % Mods.fort_level(s, pid))
	if me_can_see_supply():
		Sheet.kv(mil, Loc.t("P_SUPPLY"), "%.1f" % MilitarySystem.supply_cap(s, Game.active_player, pid))
	if p.get("siege") != null:
		mil.add_child(UI.progress(float(p["siege"]["progress"]), 1.0, UI.BAD, Loc.t("P_SIEGE")))
	var claims: Array = p["claims"]
	if not claims.is_empty():
		var names: Array = []
		for cl in claims:
			names.append(GS.country_name(s, cl))
		Sheet.kv(mil, Loc.t("P_CLAIMS"), ", ".join(names))
	# actions
	if owner == Game.active_player and p["controller"] == owner:
		var cost := ConstructionSystem.develop_cost(s, owner, pid)
		var b := UI.button(Loc.tf("P_DEVELOP", {"gold": int(cost["gold"]), "admin": int(cost["admin"])}), func() -> void:
			var r := Game.cmd_develop(pid)
			if r.get("ok", false):
				Audio.sfx("coin"), "", "plus")
		body.add_child(b)
	elif owner != Game.active_player and s["countries"][owner].get("alive", false) and owner != "REB":
		body.add_child(UI.button(Loc.tf("P_OPEN_DIPLO", {"country": GS.country_name(s, owner)}), func() -> void:
			screen.open_sheet("diplomacy")
			PanelsDiplomacy.focus_country(owner), "", "diplomacy"))

func me_can_see_supply() -> bool:
	return true

func _build(s: Dictionary, p: Dictionary) -> void:
	var owner: String = p["owner"]
	var me: String = Game.active_player
	if owner != me:
		body.add_child(UI.label(Loc.t("P_NOT_YOURS"), "Small", -1, true))
		return
	var slots := Mods.building_slots(p)
	var used := Mods.used_slots(p)
	var info := Sheet.card(body)
	Sheet.kv(info, Loc.t("P_SLOTS"), "%d / %d" % [used, slots])
	for i in (p["queue"] as Array).size():
		var q: Dictionary = p["queue"][i]
		var h := HBoxContainer.new()
		h.add_child(UI.icon_rect("b_" + str(q["bid"]), 26, UI.GOLD_LIGHT))
		var l := UI.label("%s %s  (%d/%d)" % [Defs.building_name(q["bid"]), Fmt.roman(int(q["level"])), int(q["total"]) - int(q["left"]), int(q["total"])], "Small")
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
		var idx := i
		h.add_child(UI.icon_button("cross", func() -> void:
			Dialogs.confirm(screen.overlay_layer, Loc.t("UI_CANCEL_BUILD"), Loc.t("CONFIRM_CANCEL_BUILD"), func() -> void: Game.cmd_cancel_build(pid, idx), "", false), Loc.t("UI_CANCEL"), 38.0))
		info.add_child(h)
	var cats := {}
	for bid in Defs.buildings:
		var cat: String = Defs.buildings[bid]["category"]
		if not cats.has(cat):
			cats[cat] = []
		cats[cat].append(bid)
	for cat in ["economic", "military", "administrative", "infrastructure", "social"]:
		var box := Sheet.card(body)
		Sheet.header(box, Loc.t("BCAT_" + cat.to_upper()))
		for bid in cats.get(cat, []):
			_building_row(box, s, p, bid)

func _building_row(box: VBoxContainer, s: Dictionary, p: Dictionary, bid: String) -> void:
	var b: Dictionary = Defs.buildings[bid]
	var lv := int(p["buildings"].get(bid, 0))
	var chk := ConstructionSystem.can_build(s, Game.active_player, pid, bid)
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	var h := HBoxContainer.new()
	h.add_child(UI.icon_rect("b_" + bid, 30, UI.GOLD_LIGHT if lv > 0 else Color(0.6, 0.6, 0.6)))
	var nm := UI.label("%s  %s/%d" % [Defs.building_name(bid), str(lv), int(b["max_level"])], "Value")
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.clip_text = true
	nm.tooltip_text = Fmt.effects_text(b["effects"])
	h.add_child(nm)
	var btn: Button
	if chk["ok"]:
		btn = UI.button(Loc.t("UI_BUILD") if lv == 0 else Loc.t("UI_UPGRADE"), func() -> void: _try_build(bid, chk), "Primary")
	else:
		btn = UI.button(Loc.t("UI_BUILD") if lv == 0 else Loc.t("UI_UPGRADE"), func() -> void:
			screen.toast(NoteFmt.error_text(chk["reason"], chk.get("params", {})), "warning"))
		btn.disabled = lv >= int(b["max_level"]) or (chk["reason"] in ["BUILD_ERR_MAX"])
		btn.modulate = Color(1, 1, 1, 0.6)
	btn.custom_minimum_size = Vector2(140, 44)
	btn.clip_text = true
	h.add_child(btn)
	row.add_child(h)
	var sub := UI.label(Fmt.effects_text(b["effects"]), "Tiny", -1, true)
	row.add_child(sub)
	if chk.has("cost"):
		row.add_child(Fmt.cost_row(chk["cost"], _have()))
		row.add_child(UI.label(Loc.tf("UI_BUILD_TIME", {"n": int(chk["time"])}), "Tiny"))
	elif not chk["ok"] and chk["reason"] != "BUILD_ERR_MAX":
		var rl := UI.label(NoteFmt.error_text(chk["reason"], chk.get("params", {})), "Tiny")
		rl.add_theme_color_override("font_color", UI.BAD)
		row.add_child(rl)
	box.add_child(row)
	box.add_child(UI.hsep())

func _have() -> Dictionary:
	var c := Game.pc()
	var d := {"gold": c["gold"]}
	for k in c["stock"]:
		d[k] = c["stock"][k]
	return d

func _try_build(bid: String, chk: Dictionary) -> void:
	if not (chk["shortage"] as Dictionary).is_empty():
		var gold := ConstructionSystem.buy_cost(Game.state, chk["shortage"])
		Dialogs.confirm(screen.overlay_layer, Loc.t("BUILD_BUY_TITLE"), Loc.tf("BUILD_BUY_TEXT", {"gold": int(gold)}), func() -> void:
			if Game.cmd_build(pid, bid, true).get("ok", false):
				Audio.sfx("coin"), Loc.t("UI_BUY_AND_BUILD"))
		return
	var r := Game.cmd_build(pid, bid, false)
	if r.get("ok", false):
		Audio.sfx("coin")

func _army(s: Dictionary, p: Dictionary) -> void:
	var me: String = Game.active_player
	var present := GS.armies_at(s, pid)
	if present.is_empty():
		body.add_child(UI.label(Loc.t("P_NO_ARMIES"), "Small", -1, true))
	for aid in present:
		var a: Dictionary = s["armies"][aid]
		var box := Sheet.card(body)
		var h := HBoxContainer.new()
		var own: bool = a["owner"] == me
		h.add_child(FlagView.make(s["countries"][a["owner"]].get("flag", {}), Util.color_from(s["countries"][a["owner"]].get("color", "#888")), Vector2(38, 25)))
		var tl := UI.label("%s  %s" % [GS.country_name(s, a["owner"]), ("⚓" if a.get("naval", false) else "")], "Value")
		tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(tl)
		h.add_child(UI.label("%s" % UI.fmt(UnitUtil.army_size(a)), "Num"))
		box.add_child(h)
		box.add_child(UI.label(Fmt.unit_comp(a), "Tiny", -1, true))
		Sheet.kv(box, Loc.t("MIL_MORALE"), "%d%%" % int(a["morale"]))
		Sheet.kv(box, Loc.t("MIL_GENERAL"), Fmt.general_text(a["general"]))
		if own:
			var bh := HBoxContainer.new()
			var sel := UI.button(Loc.t("MIL_SELECT") if Game.selected_army != aid else Loc.t("MIL_SELECTED"), func() -> void: screen.select_army(aid), "Primary" if Game.selected_army == aid else "", "move")
			sel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			bh.add_child(sel)
			if not (a["path"] as Array).is_empty():
				bh.add_child(UI.button(Loc.t("MIL_STOP"), func() -> void: Game.cmd_cancel_move(aid)))
			box.add_child(bh)
	if p["owner"] == me and p["controller"] == me:
		var rec := Sheet.card(body)
		Sheet.header(rec, Loc.t("MIL_RECRUIT_HERE"))
		var shown := 0
		for uid in UnitUtil.available_units(s, me):
			var u: Dictionary = Defs.units[uid]
			var chk := MilitarySystem.can_recruit(s, me, pid, uid)
			if not chk["ok"] and chk["reason"] in ["RECRUIT_ERR_PORT", "RECRUIT_ERR_TECH"]:
				continue
			# show only the best unit per class plus specials, to keep the list short
			if uid != UnitUtil.best_of(s, me, u["cls"]) and not (uid in s["countries"][me]["special_units"]):
				continue
			var rh := HBoxContainer.new()
			rh.add_child(UI.icon_rect("unit_" + str(u["cls"]), 28, UI.GOLD_LIGHT))
			var ul := UI.label(Defs.unit_name(uid), "Value")
			ul.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			rh.add_child(ul)
			var rb := UI.button(Loc.t("UI_RECRUIT"), func() -> void:
				var r := Game.cmd_recruit(pid, uid)
				if r.get("ok", false):
					Audio.sfx("recruit"), "Primary" if chk["ok"] else "")
			rb.disabled = not chk["ok"]
			rb.custom_minimum_size = Vector2(110, 44)
			rh.add_child(rb)
			rec.add_child(rh)
			var cost := MilitarySystem.recruit_cost(s, me, uid)
			rec.add_child(Fmt.cost_row(cost, _have()))
			if not chk["ok"]:
				rec.add_child(UI.label(NoteFmt.error_text(chk["reason"], chk.get("params", {})), "Tiny"))
			shown += 1
