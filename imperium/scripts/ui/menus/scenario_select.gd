extends Control
## Scenario browser (new campaign / browse / custom scenarios).

var list_box: VBoxContainer
var detail: VBoxContainer
var selected := ""

func _ready() -> void:
	theme = UI.theme()
	Nav.background(self, "res://assets/backgrounds/menu_bg.png", 0.6)
	Ads.show_banner()
	var root := Nav.safe_root(self)
	var v := VBoxContainer.new()
	root.add_child(v)
	var title := Loc.t("MENU_NEW") if Nav.mode == "new" else (Loc.t("MENU_SCENARIOS") if Nav.mode == "browse" else Loc.t("MENU_CUSTOM"))
	Nav.header(v, title, func() -> void: Nav.go(get_tree(), "menu"))
	var h := HBoxContainer.new()
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	h.add_theme_constant_override("separation", 18)
	v.add_child(h)
	list_box = VBoxContainer.new()
	list_box.add_theme_constant_override("separation", 8)
	var sc := UI.scroll(list_box)
	sc.custom_minimum_size = Vector2(430, 0)
	sc.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	h.add_child(sc)
	var dp := PanelContainer.new()
	dp.theme_type_variation = "Sheet"
	dp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail = VBoxContainer.new()
	dp.add_child(UI.scroll(detail))
	h.add_child(dp)
	_fill_list()

func _fill_list() -> void:
	var defs: Dictionary = Defs.all_scenarios()
	var ids: Array = []
	for id in defs:
		var custom: bool = bool(defs[id].get("custom", false))
		if (Nav.mode == "custom") == custom:
			ids.append(id)
	ids.sort_custom(func(a, b): return int(defs[a]["start"]["year"]) < int(defs[b]["start"]["year"]))
	if ids.is_empty():
		list_box.add_child(UI.label(Loc.t("SC_NO_CUSTOM"), "Small", -1, true))
		detail.add_child(UI.label(Loc.t("SC_NO_CUSTOM_HINT"), "", -1, true))
		detail.add_child(UI.button(Loc.t("MENU_EDITOR"), func() -> void:
			EditorState.new_scenario = true
			Nav.go(get_tree(), "editor"), "Primary", "construction"))
		return
	for id in ids:
		var d: Dictionary = defs[id]
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.theme_type_variation = "Tab"
		b.custom_minimum_size = Vector2(0, 86)
		b.text = ""
		var vb := VBoxContainer.new()
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.set_anchors_preset(Control.PRESET_FULL_RECT)
		vb.offset_left = 12
		vb.offset_top = 8
		var n := UI.label(Loc.tx(d["name"]), "Sub")
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(n)
		var yl := UI.label("%d  ·  %d %s" % [int(d["start"]["year"]), (d["countries"] as Dictionary).size(), Loc.t("SC_COUNTRIES")], "Small")
		yl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(yl)
		b.add_child(vb)
		var sid: String = id
		b.pressed.connect(func() -> void:
			Audio.sfx("ui_click")
			selected = sid
			_show(sid))
		list_box.add_child(b)
	_show(ids[0])
	selected = ids[0]

func _show(id: String) -> void:
	var d: Dictionary = Defs.all_scenarios()[id]
	UI.clear(detail)
	detail.add_child(UI.label(Loc.tx(d["name"]), "Heading"))
	var date := UI.label("%s %d  ·  %s" % [_month(int(d["start"].get("month", 1))), int(d["start"]["year"]), Loc.tf("SC_TURNS", {"n": int(d.get("turn_limit", 200))})], "Small")
	detail.add_child(date)
	detail.add_child(UI.hsep())
	detail.add_child(UI.label(Loc.tx(d.get("desc", {})), "", -1, true))
	var note := PanelContainer.new()
	note.theme_type_variation = "Card"
	var nv := VBoxContainer.new()
	note.add_child(nv)
	nv.add_child(UI.label(Loc.t("SC_APPROX_TITLE") if d.get("approximate", true) else Loc.t("SC_HISTORICAL"), "Warn"))
	nv.add_child(UI.label(Loc.tx(d.get("note", {})) if d.has("note") else Loc.t("SC_APPROX_DEFAULT"), "Small", -1, true))
	detail.add_child(note)
	var errs := ScenarioLoader.validate(d)
	if not errs.is_empty():
		detail.add_child(UI.label(Loc.t("SC_INVALID") + ": " + str(errs.slice(0, 3)), "Bad", -1, true))
	var objs: Array = d.get("objectives", [])
	if not objs.is_empty():
		detail.add_child(UI.label(Loc.t("TAB_OBJECTIVES"), "Sub"))
		for o in objs.slice(0, 4):
			detail.add_child(UI.label("• " + Loc.tx(o.get("name", "")), "Small", -1, true))
	var bh := HBoxContainer.new()
	if bool(d.get("custom", false)):
		bh.add_child(UI.button(Loc.t("SC_EDIT"), func() -> void:
			EditorState.edit_id = id
			EditorState.new_scenario = false
			Nav.go(get_tree(), "editor"), "", "editor"))
		bh.add_child(UI.button(Loc.t("SAVE_DELETE"), func() -> void:
			Dialogs.confirm(self, Loc.t("SAVE_DELETE"), Loc.t("SC_DELETE_Q"), func() -> void:
				DirAccess.remove_absolute("user://custom_scenarios/%s.json" % id)
				get_tree().reload_current_scene(), "", true), "", "cross"))
	var go := UI.button(Loc.t("SC_CHOOSE_NATION") if Nav.mode != "browse" else Loc.t("SC_PLAY"), func() -> void:
		Nav.scenario_id = id
		Nav.go(get_tree(), "country"), "Primary", "next")
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bh.add_child(go)
	detail.add_child(bh)

func _month(m: int) -> String:
	var months: Array = Loc.t("MONTHS").split(",")
	return months[clampi(m - 1, 0, 11)] if months.size() == 12 else str(m)
