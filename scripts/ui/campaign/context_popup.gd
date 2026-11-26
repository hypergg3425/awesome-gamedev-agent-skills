class_name ContextPopup
extends PanelContainer
## Long-press popup for a province or an army stack: quick facts, armies present and shortcut actions. It lives in the
## HUD layer (not in the modal overlay layer) so it never blocks Android back handling; any tap elsewhere or the back
## button dismisses it.

var screen: CampaignScreen
var pid := ""
var _scroll: ScrollContainer
var _body: VBoxContainer

static func show_for(host: CampaignScreen, kind: String, p_pid: String, at: Vector2) -> ContextPopup:
	close_all(host)
	var p := ContextPopup.new()
	p.screen = host
	p.pid = p_pid
	p.name = "ContextPopup"
	host.ui_root.add_child(p)
	p.build(kind)
	p.place(at)
	p.place.call_deferred(at)
	Anim.pop_in(p, 0.14)
	Audio.sfx("ui_open", -8.0)
	return p

static func close_all(host: CampaignScreen) -> bool:
	var had := false
	for c in host.ui_root.get_children():
		if c is ContextPopup:
			c.queue_free()
			host.ui_root.remove_child(c)
			had = true
	return had

func _init() -> void:
	theme_type_variation = "Sheet"
	mouse_filter = Control.MOUSE_FILTER_STOP

func build(kind: String) -> void:
	var s: Dictionary = Game.state
	var p: Dictionary = s["provinces"][pid]
	var owner: String = p["owner"]
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.add_child(v)
	add_child(_scroll)
	_body = v
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	var c: Dictionary = s["countries"].get(owner, {})
	head.add_child(FlagView.make(c.get("flag", {}), Util.color_from(c.get("color", "#888")), Vector2(40, 27)))
	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_theme_constant_override("separation", -2)
	var nm := UI.label(Defs.province_name(pid), "Sub")
	nm.clip_text = true
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tv.add_child(nm)
	tv.add_child(UI.label(GS.country_name(s, owner), "Tiny"))
	head.add_child(tv)
	head.add_child(UI.icon_button("close", func() -> void: dismiss(), Loc.t("UI_CLOSE"), 40.0))
	v.add_child(head)
	v.add_child(UI.hsep())
	var pd: Dictionary = Defs.provinces[pid]
	v.add_child(UI.stat("terrain_" + str(pd["terrain"]), Fmt.terrain_name(str(pd["terrain"])), Color("d8d0b8"), "", "Small"))
	Sheet.kv(v, Loc.t("P_POP"), UI.fmt(float(p["pop"]) * 1000.0))
	Sheet.kv(v, Loc.t("P_DEV"), "%.1f" % float(p["dev"]))
	if p["controller"] != owner:
		Sheet.kv(v, Loc.t("P_OCCUPIED_BY"), GS.country_name(s, p["controller"]), "", UI.BAD)
	v.add_child(UI.progress(float(p["unrest"]), 100.0, UI.BAD if float(p["unrest"]) > 50.0 else UI.GOLD, "%s %d" % [Loc.t("P_UNREST"), int(p["unrest"])]))
	if p.get("siege") != null:
		v.add_child(UI.progress(float(p["siege"]["progress"]), 1.0, UI.BAD, Loc.t("P_SIEGE")))
	var present := GS.armies_at(s, pid)
	if not present.is_empty():
		v.add_child(UI.label(Loc.t("CTX_ARMIES"), "Eyebrow"))
		for aid in present:
			_army_row(v, s, aid, kind == "army")
	var acts := HBoxContainer.new()
	acts.add_theme_constant_override("separation", 6)
	var open := UI.button(Loc.t("CTX_OPEN"), func() -> void:
		dismiss()
		screen.select_province(pid), "Primary")
	open.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	acts.add_child(open)
	acts.add_child(UI.icon_button("zoom_in", func() -> void:
		dismiss()
		screen.mapview.focus_province(pid, 4.5), Loc.t("UI_FOCUS"), 52.0))
	v.add_child(acts)

func _army_row(v: VBoxContainer, s: Dictionary, aid: String, emphasise: bool) -> void:
	var a: Dictionary = s["armies"][aid]
	var own: bool = a["owner"] == Game.active_player
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	var oc: Dictionary = s["countries"][a["owner"]]
	h.add_child(FlagView.make(oc.get("flag", {}), Util.color_from(oc.get("color", "#888")), Vector2(30, 20)))
	var l := UI.label("%s  %s" % [UI.fmt(UnitUtil.army_size(a)), Loc.tf("CTX_MORALE", {"n": int(a["morale"])})], "Small")
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.clip_text = true
	h.add_child(l)
	if own:
		var b := UI.button(Loc.t("MIL_SELECT"), func() -> void:
			dismiss()
			screen.select_province(pid)
			screen.select_army(aid), "Primary" if emphasise else "", "move")
		b.custom_minimum_size = Vector2(110, 44)
		b.clip_text = true
		h.add_child(b)
	v.add_child(h)

func dismiss() -> void:
	if is_inside_tree():
		get_parent().remove_child(self)
	queue_free()

## Place near the finger, preferring up-right of it, always fully inside the free area (below the HUD); the body
## scrolls when it is taller than that area.
func place(at: Vector2) -> void:
	if not is_inside_tree():
		return
	var lay: Dictionary = screen.layout
	var area: Rect2 = lay["avail"] if lay.has("avail") else Rect2(Vector2.ZERO, screen.size)
	var top: float = (lay["hud"] as Rect2).end.y + 4.0 if lay.has("hud") else 60.0
	var w := minf(330.0, area.size.x - 16.0)
	var max_h := area.end.y - top - 8.0
	custom_minimum_size = Vector2(w, 0)
	_scroll.custom_minimum_size = Vector2(0, 0)
	var chrome_h := 2.0 * 14.0
	var body_h := _body.get_combined_minimum_size().y
	_scroll.custom_minimum_size.y = minf(body_h, maxf(80.0, max_h - chrome_h))
	size = Vector2(w, 0)
	var sz := Vector2(w, minf(get_combined_minimum_size().y, max_h))
	size = sz
	var pos := at + Vector2(24.0, -sz.y * 0.5)
	if pos.x + sz.x > area.end.x - 8.0:
		pos.x = at.x - sz.x - 24.0
	pos.x = clampf(pos.x, area.position.x + 8.0, maxf(area.position.x + 8.0, area.end.x - sz.x - 8.0))
	pos.y = clampf(pos.y, top, maxf(top, area.end.y - sz.y - 8.0))
	position = pos
