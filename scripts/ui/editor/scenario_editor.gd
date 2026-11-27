extends Control
## Scenario editor over the built-in world map: countries, province ownership, starting resources,
## armies, relations, dates and victory settings, with validation and save/load of custom scenarios.
## Architecture note: the scenario format (docs/SCENARIO_SCHEMA.md) is geometry-agnostic, so custom map
## imports can later plug in a different province table without changing the editor model.

const CUSTOM_DIR := "user://custom_scenarios"

var def: Dictionary = {}
var owners: Dictionary = {}          # province id -> country tag (explicit, editor model)
var brush := ""
var selected_province := ""
var mapview: MapView
var cmap: CampaignMap
var preview_state: Dictionary = {}
var side: VBoxContainer
var sheet: Sheet
var tab := "info"
var status: Label

func _ready() -> void:
	theme = UI.theme()
	Ads.show_banner()
	_load_model()
	mapview = MapView.new()
	mapview.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(mapview)
	mapview.setup(Defs.load_geometry(), Defs.map_meta)
	cmap = CampaignMap.new()
	cmap.attach(mapview, Defs.load_geometry())
	mapview.province_tapped.connect(_on_province)
	_build_ui()
	_refresh_map()
	await get_tree().process_frame
	mapview.fit_world()

func _load_model() -> void:
	if not EditorState.new_scenario and EditorState.edit_id != "":
		def = (Defs.all_scenarios().get(EditorState.edit_id, {}) as Dictionary).duplicate(true)
	if def.is_empty():
		def = {"id": "custom_%d" % (int(Time.get_unix_time_from_system()) % 100000), "name": {"en": "My Scenario", "tr": "Senaryom"}, "desc": {"en": "A custom scenario.", "tr": "Özel bir senaryo."},
			"note": {"en": "Custom scenario created in the editor.", "tr": "Düzenleyicide oluşturulmuş özel senaryo."}, "start": {"year": 1500, "month": 1}, "turn_limit": 200,
			"era": 2, "approximate": true, "native_fallback": true, "countries": {}, "relations": {}, "objectives": [], "default_player": "", "custom": true}
		var tpl: Dictionary = Defs.all_scenarios().get("early_modern", {})
		# start from two example countries so that a fresh scenario is immediately valid
		_add_country("Kingdom A", "A Krallığı", Color("b8242b"), ["fra_ile_de_france", "fra_normandy", "fra_picardy", "fra_champagne"], "fra_ile_de_france")
		_add_country("Kingdom B", "B Krallığı", Color("2b5fb8"), ["deu_rhineland", "deu_lower_saxony", "deu_hesse_thuringia"], "deu_hesse_thuringia")
		def["default_player"] = def["countries"].keys()[0]
	else:
		def["custom"] = true
		# expand glob patterns into the explicit ownership model
		for cid in def["countries"]:
			for pat in def["countries"][cid].get("provinces", []):
				var ps := str(pat)
				var neg := ps.begins_with("-")
				if neg:
					ps = ps.substr(1)
				for pid in Defs.province_ids:
					if Util.glob_match(ps, pid):
						if neg:
							if owners.get(pid, "") == cid:
								owners.erase(pid)
						else:
							owners[pid] = cid
	for cid in def["countries"]:
		for pid in def["countries"][cid].get("provinces", []):
			if Defs.provinces.has(pid) and not owners.has(pid):
				owners[pid] = cid
	brush = str(def.get("default_player", ""))
	if brush == "" and not def["countries"].is_empty():
		brush = def["countries"].keys()[0]

func _add_country(en: String, tr: String, col: Color, provs: Array, capital: String) -> String:
	var n := (def["countries"] as Dictionary).size() + 1
	var tag := "C%02d" % n
	while def["countries"].has(tag):
		n += 1
		tag = "C%02d" % n
	def["countries"][tag] = {"name": {"en": en, "tr": tr}, "short": {"en": en, "tr": tr}, "color": "#" + col.to_html(false), "flag": {"p": "hstripes", "c": ["#" + col.to_html(false), "#f2f2f2"], "charge": "star"},
		"culture": "latin", "religion": "catholic", "gov": "feudal_kingdom", "ruler": {"name": "Ruler", "adm": 5, "dip": 5, "mil": 5, "age": 35, "dynasty": ""},
		"capital": capital, "provinces": provs, "civ": "average", "military": "medium", "ai": "opportunistic", "playable": true}
	for p in provs:
		owners[p] = tag
	return tag

## --- UI ----------------------------------------------------------------------------------------------------
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
	bh.add_child(UI.icon_button("back", func() -> void: on_back_requested(), Loc.t("UI_BACK"), 52.0))
	bh.add_child(UI.label(Loc.t("MENU_EDITOR"), "Heading"))
	status = UI.label("", "Small")
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bh.add_child(status)
	var small := Layout.compact(get_viewport_rect().size)
	for act in [["ED_VALIDATE", "check", "", _validate_dialog], ["UI_SAVE_GAME", "save", "Primary", _save], ["ED_TEST", "next", "", _test_play]]:
		var cb: Callable = act[3]
		if small:
			bh.add_child(UI.icon_button(act[1], cb, Loc.t(act[0]), 52.0, act[2]))
		else:
			bh.add_child(UI.button(Loc.t(act[0]), cb, act[2], act[1]))
	v.add_child(bar)
	var h := HBoxContainer.new()
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(h)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(sp)
	sheet = Sheet.new("MENU_EDITOR", "editor")
	sheet.custom_minimum_size = Vector2(clampf(get_viewport_rect().size.x * 0.42, 340.0, 560.0), 0)
	sheet.find_child("CloseButton", true, false).visible = false
	for t in [["info", "ED_TAB_INFO", _tab_info], ["countries", "ED_TAB_COUNTRIES", _tab_countries], ["map", "ED_TAB_MAP", _tab_map], ["relations", "ED_TAB_RELATIONS", _tab_relations]]:
		sheet.add_tab(t[0], t[1], t[2])
	h.add_child(sheet)
	sheet.refresh()

func _set_status(txt: String, good: bool = true) -> void:
	status.text = txt
	status.add_theme_color_override("font_color", UI.GOOD if good else UI.BAD)

func _line(parent: Control, label_key: String, value: String, on_change: Callable) -> LineEdit:
	var l := UI.label(Loc.t(label_key), "Tiny")
	parent.add_child(l)
	var e := LineEdit.new()
	e.text = value
	e.custom_minimum_size = Vector2(0, 46)
	e.text_changed.connect(on_change)
	parent.add_child(e)
	return e

func _spin(parent: Control, label_key: String, v: float, mn: float, mx: float, step: float, on_change: Callable) -> void:
	var h := HBoxContainer.new()
	var l := UI.label(Loc.t(label_key), "Small")
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	var s := SpinBox.new()
	s.min_value = mn
	s.max_value = mx
	s.step = step
	s.value = v
	s.custom_minimum_size = Vector2(120, 46)
	s.value_changed.connect(on_change)
	h.add_child(s)
	parent.add_child(h)

func _option(parent: Control, label_key: String, items: Array, current: String, on_pick: Callable, display: Callable = Callable()) -> void:
	var h := HBoxContainer.new()
	var l := UI.label(Loc.t(label_key), "Small")
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	var o := OptionButton.new()
	o.custom_minimum_size = Vector2(150, 46)
	o.clip_text = true
	o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in items.size():
		o.add_item(str(display.call(items[i])) if display.is_valid() else str(items[i]), i)
		if str(items[i]) == current:
			o.selected = i
	o.item_selected.connect(func(i: int) -> void: on_pick.call(items[i]))
	h.add_child(o)
	parent.add_child(h)

func _tab_info(b: VBoxContainer) -> void:
	_line(b, "ED_NAME_EN", str(def["name"]["en"]), func(t: String) -> void: def["name"]["en"] = t)
	_line(b, "ED_NAME_TR", str(def["name"]["tr"]), func(t: String) -> void: def["name"]["tr"] = t)
	_line(b, "ED_DESC_EN", str(def["desc"]["en"]), func(t: String) -> void: def["desc"]["en"] = t)
	_line(b, "ED_DESC_TR", str(def["desc"]["tr"]), func(t: String) -> void: def["desc"]["tr"] = t)
	_spin(b, "ED_START_YEAR", float(def["start"]["year"]), 500, 2100, 1, func(v: float) -> void: def["start"]["year"] = int(v))
	_spin(b, "ED_START_MONTH", float(def["start"]["month"]), 1, 12, 1, func(v: float) -> void: def["start"]["month"] = int(v))
	_spin(b, "ED_TURN_LIMIT", float(def["turn_limit"]), 20, 600, 10, func(v: float) -> void: def["turn_limit"] = int(v))
	_spin(b, "ED_ERA", float(def.get("era", 2)), 0, 4, 1, func(v: float) -> void: def["era"] = int(v))
	var vc: Dictionary = def.get("victory", {})
	_spin(b, "ED_TERRITORY_PCT", float(vc.get("territory_pct", 0.22)) * 100.0, 5, 90, 1, func(v: float) -> void:
		if not def.has("victory"):
			def["victory"] = {}
		def["victory"]["territory_pct"] = v / 100.0)
	_option(b, "ED_DEFAULT_PLAYER", def["countries"].keys(), str(def.get("default_player", "")), func(x: Variant) -> void: def["default_player"] = str(x),
		func(x: Variant) -> String: return "%s (%s)" % [x, Loc.tx(def["countries"][x]["name"])])

func _tab_map(b: VBoxContainer) -> void:
	b.add_child(UI.label(Loc.t("ED_MAP_HINT"), "Small", -1, true))
	_option(b, "ED_BRUSH", def["countries"].keys(), brush, func(x: Variant) -> void: brush = str(x),
		func(x: Variant) -> String: return "%s (%s)" % [x, Loc.tx(def["countries"][x]["name"])])
	if selected_province != "":
		var c := Sheet.card(b)
		c.add_child(UI.label(Defs.province_name(selected_province), "Sub"))
		var o: String = owners.get(selected_province, "")
		Sheet.kv(c, Loc.t("P_OWNER"), (Loc.tx(def["countries"][o]["name"]) if o != "" else Loc.t("ED_UNCLAIMED")))
		c.add_child(UI.button(Loc.t("ED_ASSIGN"), func() -> void: _assign(selected_province, brush), "Primary", "check"))
		c.add_child(UI.button(Loc.t("ED_UNASSIGN"), func() -> void: _assign(selected_province, ""), "", "cross"))
		c.add_child(UI.button(Loc.t("ED_ASSIGN_REGION"), func() -> void:
			var adm0: String = Defs.provinces[selected_province]["adm0"]
			for pid in Defs.province_ids:
				if Defs.provinces[pid]["adm0"] == adm0:
					_assign(pid, brush, false)
			_refresh_map()
			sheet.refresh(), "", "map"))
	b.add_child(UI.label(Loc.tf("ED_OWNED_COUNT", {"n": owners.size(), "total": Defs.province_ids.size()}), "Tiny"))

func _tab_countries(b: VBoxContainer) -> void:
	b.add_child(UI.button(Loc.t("ED_NEW_COUNTRY"), func() -> void:
		var tag := _add_country("New Country", "Yeni Ülke", Color.from_hsv(randf(), 0.6, 0.7), [], "")
		brush = tag
		sheet.refresh(), "Primary", "plus"))
	for tag in def["countries"]:
		var t: String = tag
		var c: Dictionary = def["countries"][t]
		var box := Sheet.card(b)
		var hh := HBoxContainer.new()
		hh.add_child(FlagView.make(c.get("flag", {}), Util.color_from(c["color"]), Vector2(44, 29)))
		var l := UI.label("%s – %s" % [t, Loc.tx(c["name"])], "Value")
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hh.add_child(l)
		hh.add_child(UI.button(Loc.t("ED_BRUSH_THIS") if brush != t else Loc.t("ED_BRUSH_ACTIVE"), func() -> void:
			brush = t
			sheet.refresh(), "Primary" if brush == t else "Tab"))
		box.add_child(hh)
		if brush != t:
			continue
		_line(box, "ED_NAME_EN", str(c["name"]["en"]), func(x: String) -> void:
			c["name"]["en"] = x
			c["short"]["en"] = x)
		_line(box, "ED_NAME_TR", str(c["name"]["tr"]), func(x: String) -> void:
			c["name"]["tr"] = x
			c["short"]["tr"] = x)
		var ch := HBoxContainer.new()
		ch.add_child(UI.label(Loc.t("ED_COLOR"), "Small"))
		var cp := ColorPickerButton.new()
		cp.color = Util.color_from(c["color"])
		cp.custom_minimum_size = Vector2(110, 46)
		cp.edit_alpha = false
		cp.color_changed.connect(func(col: Color) -> void:
			c["color"] = "#" + col.to_html(false)
			if c["flag"].get("c") is Array and (c["flag"]["c"] as Array).size() > 0:
				c["flag"]["c"][0] = c["color"]
			_refresh_map())
		ch.add_child(cp)
		box.add_child(ch)
		_option(box, "ED_GOV", Const.GOV_IDS, str(c["gov"]), func(x: Variant) -> void: c["gov"] = str(x), func(x: Variant) -> String: return Defs.gov_name(str(x)))
		_option(box, "C_RELIGION", Const.RELIGIONS, str(c["religion"]), func(x: Variant) -> void: c["religion"] = str(x), func(x: Variant) -> String: return Fmt.religion_name(str(x)))
		_option(box, "ED_AI", Const.PERSONALITIES, str(c.get("ai", "opportunistic")), func(x: Variant) -> void: c["ai"] = str(x), func(x: Variant) -> String: return Loc.t("AI_" + str(x).to_upper()))
		_option(box, "ED_MILITARY", ["low", "medium", "high"], str(c.get("military", "medium")), func(x: Variant) -> void: c["military"] = str(x), func(x: Variant) -> String: return Loc.t("ED_MIL_" + str(x).to_upper()))
		var owned_list: Array = []
		for pid in owners:
			if owners[pid] == t:
				owned_list.append(pid)
		owned_list.sort()
		if not owned_list.is_empty():
			_option(box, "ED_CAPITAL", owned_list, str(c.get("capital", "")), func(x: Variant) -> void: c["capital"] = str(x), func(x: Variant) -> String: return Defs.province_name(str(x)))
			if c.get("capital", "") == "" or c["capital"] not in owned_list:
				c["capital"] = owned_list[0]
		_spin(box, "ED_TREASURY", float(c.get("treasury", 100.0)), 0, 100000, 50, func(x: float) -> void: c["treasury"] = x)
		_line(box, "C_RULER", str(c["ruler"]["name"]), func(x: String) -> void: c["ruler"]["name"] = x)
		for sk in ["adm", "dip", "mil"]:
			var s2: String = sk
			_spin(box, "SKILL_" + s2.to_upper(), float(c["ruler"][s2]), 1, 9, 1, func(x: float) -> void: c["ruler"][s2] = int(x))
		_spin(box, "ED_START_REGIMENTS", float(_sum_regiments(c)), 0, 60, 1, func(x: float) -> void: _set_regiments(c, int(x)))
		box.add_child(UI.button(Loc.t("ED_DELETE_COUNTRY"), func() -> void:
			Dialogs.confirm(self, Loc.t("ED_DELETE_COUNTRY"), Loc.t("ED_DELETE_Q"), func() -> void:
				for pid in owners.keys():
					if owners[pid] == t:
						owners.erase(pid)
				def["countries"].erase(t)
				_drop_relations(t)
				if brush == t:
					brush = def["countries"].keys()[0] if not def["countries"].is_empty() else ""
				if def.get("default_player", "") == t:
					def["default_player"] = brush
				_refresh_map()
				sheet.refresh(), "", true), "", "cross"))

func _sum_regiments(c: Dictionary) -> int:
	var n := 0
	for a in c.get("armies", []):
		for u in a["units"]:
			n += int(a["units"][u])
	return n if c.has("armies") else {"low": 6, "medium": 10, "high": 18}.get(str(c.get("military", "medium")), 10)

func _set_regiments(c: Dictionary, n: int) -> void:
	if n <= 0:
		c["armies"] = []
		return
	var loc: String = str(c.get("capital", ""))
	if loc == "":
		return
	c["armies"] = [{"loc": loc, "units": {"spearmen": float(n)}}]

func _tab_relations(b: VBoxContainer) -> void:
	var tags: Array = def["countries"].keys()
	if tags.size() < 2:
		b.add_child(UI.label(Loc.t("ED_NEED_TWO"), "Small"))
		return
	var a_sel := [tags[0]]
	var b_sel := [tags[1]]
	var rd: Dictionary = def["relations"]
	_option(b, "ED_COUNTRY_A", tags, a_sel[0], func(x: Variant) -> void: a_sel[0] = str(x))
	_option(b, "ED_COUNTRY_B", tags, b_sel[0], func(x: Variant) -> void: b_sel[0] = str(x))
	var grid := GridContainer.new()
	grid.columns = 2
	b.add_child(grid)
	for k in [["alliances", "ACT_ALLIANCE"], ["nap", "ACT_NAP"], ["trade", "ACT_TRADE"], ["vassals", "ED_VASSAL"], ["wars", "ED_WAR"]]:
		var key: String = k[0]
		var bt := UI.button(Loc.t(k[1]), func() -> void:
			if a_sel[0] == b_sel[0]:
				_set_status(Loc.t("ED_SAME_COUNTRY"), false)
				return
			if key == "wars":
				if not rd.has("wars"):
					rd["wars"] = []
				rd["wars"].append({"attackers": [a_sel[0]], "defenders": [b_sel[0]], "cb": "conquest"})
			else:
				if not rd.has(key):
					rd[key] = []
				rd[key].append([a_sel[0], b_sel[0]])
			sheet.refresh())
		bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(bt)
	var lst := Sheet.card(b)
	Sheet.header(lst, Loc.t("ED_EXISTING"))
	for key in ["alliances", "nap", "trade", "vassals"]:
		var arr: Array = rd.get(key, [])
		for i in arr.size():
			var idx := i
			var kk: String = key
			var h := HBoxContainer.new()
			var l := UI.label("%s: %s ↔ %s" % [kk, arr[i][0], arr[i][1]], "Small")
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			h.add_child(l)
			h.add_child(UI.icon_button("cross", func() -> void:
				rd[kk].remove_at(idx)
				sheet.refresh(), "", 40.0))
			lst.add_child(h)
	var wars: Array = rd.get("wars", [])
	for i in wars.size():
		var wi := i
		var h2 := HBoxContainer.new()
		var l2 := UI.label("war: %s → %s" % [", ".join(wars[i]["attackers"]), ", ".join(wars[i]["defenders"])], "Small")
		l2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h2.add_child(l2)
		h2.add_child(UI.icon_button("cross", func() -> void:
			rd["wars"].remove_at(wi)
			sheet.refresh(), "", 40.0))
		lst.add_child(h2)

func _drop_relations(tag: String) -> void:
	var rd: Dictionary = def["relations"]
	for key in ["alliances", "defensive", "nap", "access", "trade", "guarantees", "vassals"]:
		if rd.has(key):
			var keep: Array = []
			for p in rd[key]:
				if p[0] != tag and p[1] != tag:
					keep.append(p)
			rd[key] = keep
	if rd.has("wars"):
		var kw: Array = []
		for w in rd["wars"]:
			if tag not in w["attackers"] and tag not in w["defenders"]:
				kw.append(w)
		rd["wars"] = kw

## --- map interaction -----------------------------------------------------------------------------------------
func _on_province(pid: String) -> void:
	selected_province = pid
	if tab == "map" or sheet.current == "map":
		pass
	if sheet.current == "map" and Input.is_key_pressed(KEY_SHIFT) == false and brush != "":
		# quick paint: tapping assigns immediately while the Map tab is open
		_assign(pid, brush)
	cmap.select(pid)
	sheet.refresh()

func _assign(pid: String, tag: String, refresh: bool = true) -> void:
	var prev: String = owners.get(pid, "")
	if prev != "" and prev == tag:
		return
	# the previous owner loses the province; invalid capitals are repaired
	if tag == "":
		owners.erase(pid)
	else:
		owners[pid] = tag
	if prev != "" and def["countries"].has(prev) and def["countries"][prev].get("capital", "") == pid:
		def["countries"][prev]["capital"] = ""
		for p2 in owners:
			if owners[p2] == prev:
				def["countries"][prev]["capital"] = p2
				break
	if tag != "" and def["countries"][tag].get("capital", "") == "":
		def["countries"][tag]["capital"] = pid
	if refresh:
		_refresh_map()

func _sync_def() -> void:
	for tag in def["countries"]:
		var lst: Array = []
		for pid in owners:
			if owners[pid] == tag:
				lst.append(pid)
		lst.sort()
		def["countries"][tag]["provinces"] = lst
		if (def["countries"][tag].get("armies", []) as Array).size() > 0:
			for a in def["countries"][tag]["armies"]:
				a["loc"] = def["countries"][tag].get("capital", a["loc"])

func _refresh_map() -> void:
	_sync_def()
	# build a lightweight state just for colours
	var errs := ScenarioLoader.validate(def)
	if def["countries"].is_empty():
		return
	var tmp: Dictionary = def.duplicate(true)
	for t in tmp["countries"]:
		if (tmp["countries"][t]["provinces"] as Array).is_empty():
			tmp["countries"][t]["provinces"] = []
	var good := {}
	for t in tmp["countries"]:
		if not (tmp["countries"][t]["provinces"] as Array).is_empty():
			good[t] = tmp["countries"][t]
	tmp["countries"] = good
	tmp["relations"] = {}
	if good.is_empty():
		return
	tmp["default_player"] = good.keys()[0]
	preview_state = ScenarioLoader.build(tmp, good.keys()[0], "normal", 1)
	Game.state = preview_state
	Game.active_player = good.keys()[0]
	cmap.refresh()
	_set_status(Loc.tf("ED_STATUS", {"n": errs.size()}), errs.is_empty())

func _validate_dialog() -> void:
	_sync_def()
	var errs := _full_validate()
	var dlg := Dialogs.custom(self, Loc.t("ED_VALIDATE"), 640.0)
	var box: VBoxContainer = dlg["box"]
	if errs.is_empty():
		box.add_child(UI.label(Loc.t("ED_VALID_OK"), "Good", -1, true))
	for e in errs:
		var parts := str(e).split(":")
		var key := parts[0]
		var txt := Loc.tf(key, {"a": parts[1] if parts.size() > 1 else "", "b": parts[2] if parts.size() > 2 else ""}) if Loc.has_key(key) else str(e)
		var l := UI.label("• " + txt, "Small", -1, true)
		l.add_theme_color_override("font_color", UI.BAD)
		box.add_child(l)

func _full_validate() -> Array:
	var errs: Array = ScenarioLoader.validate(def)
	if def["countries"].size() < 2:
		errs.append("ED_ERR_TWO_COUNTRIES")
	if str(def.get("default_player", "")) not in def["countries"]:
		errs.append("ED_ERR_NO_PLAYER")
	var seen_names := {}
	for t in def["countries"]:
		var nm := str(def["countries"][t]["name"]["en"])
		if nm.strip_edges() == "":
			errs.append("ED_ERR_EMPTY_NAME:" + t)
		if seen_names.has(nm):
			errs.append("ED_ERR_DUP_NAME:" + nm)
		seen_names[nm] = true
	return errs

func _save() -> void:
	_sync_def()
	var errs := _full_validate()
	if not errs.is_empty():
		_validate_dialog()
		return
	DirAccess.make_dir_recursive_absolute(CUSTOM_DIR)
	def["id"] = str(def["id"]).replace(" ", "_")
	var out := def.duplicate(true)
	out.erase("custom")
	var f := FileAccess.open("%s/%s.json" % [CUSTOM_DIR, def["id"]], FileAccess.WRITE)
	if f == null:
		Dialogs.info(self, Loc.t("ERR_GENERIC"), Loc.t("SAVE_ERR_WRITE"))
		return
	f.store_string(JSON.stringify(out, "  "))
	f.close()
	_set_status(Loc.t("ED_SAVED"))
	Audio.sfx("ui_confirm")

func _test_play() -> void:
	_sync_def()
	if not _full_validate().is_empty():
		_validate_dialog()
		return
	_save()
	var out := def.duplicate(true)
	out["custom"] = true
	Defs.scenarios[str(def["id"])] = out
	var r: Dictionary = Game.new_game(str(def["id"]), str(def["default_player"]), "normal", 0)
	if r.get("ok", false):
		Nav.go(get_tree(), "campaign")
	else:
		Dialogs.info(self, Loc.t("ERR_GENERIC"), NoteFmt.error_text(str(r.get("reason", ""))))

func on_back_requested() -> void:
	Dialogs.confirm(self, Loc.t("ED_LEAVE"), Loc.t("ED_LEAVE_Q"), func() -> void: Nav.go(get_tree(), "menu"), "", true)
