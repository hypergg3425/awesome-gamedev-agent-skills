class_name BattleReportView
extends RefCounted
## Battle report pages: animated unit blocks, casualties and an explanation of why the winner won.

class BattleAnim:
	extends Control
	var rep: Dictionary
	var col_a := Color.RED
	var col_d := Color.BLUE
	var t := 0.0

	func _draw() -> void:
		var half := size.x / 2.0 - 30.0
		var na := int(round(float(rep["start_a"])))
		var nd := int(round(float(rep["start_d"])))
		var la := float(rep["loss_a"]) * t
		var ld := float(rep["loss_d"]) * t
		_block(Vector2(0, 10), half, na, int(round(la)), col_a, true)
		_block(Vector2(size.x - half, 10), half, nd, int(round(ld)), col_d, false)
		# clash marks in the middle
		var mid := size.x / 2.0
		for i in 5:
			var y := 20.0 + i * (size.y - 40.0) / 4.0
			var jitter := sin(t * 40.0 + i * 1.7) * 8.0 * (1.0 - absf(t * 2.0 - 1.0) * 0.5)
			draw_line(Vector2(mid - 12 + jitter, y), Vector2(mid + 12 - jitter, y + 4), Color(1, 0.85, 0.4, 0.8), 2.0)

	func _block(origin: Vector2, w: float, n: int, lost: int, col: Color, left: bool) -> void:
		var cols := 12
		var cell := minf(w / float(cols), 17.0)
		var shown := mini(n, 96)
		var scale_f := float(shown) / maxf(float(n), 1.0)
		var dead := int(round(float(lost) * scale_f))
		for i in shown:
			var cx := i % cols
			var cy := i / cols
			var x := origin.x + (cx * cell if left else w - (cx + 1) * cell)
			var y := origin.y + cy * cell
			var alive := i < shown - dead
			draw_rect(Rect2(x + 1, y + 1, cell - 3, cell - 3), col if alive else Color(0.2, 0.2, 0.2, 0.55), true)
			if alive:
				draw_rect(Rect2(x + 1, y + 1, cell - 3, cell - 3), Color(0, 0, 0, 0.55), false, 1.0)

static func show_reports(host: Control, s: Dictionary, reports: Array, on_done: Callable) -> void:
	var idx := [0]
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	host.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var pc := PanelContainer.new()
	pc.theme_type_variation = "Sheet"
	pc.custom_minimum_size = Vector2(900, 0)
	center.add_child(pc)
	var v := VBoxContainer.new()
	pc.add_child(v)
	var render: Callable
	render = func() -> void:
		UI.clear(v)
		var r: Dictionary = reports[idx[0]]
		_page(v, s, r)
		var h := HBoxContainer.new()
		if reports.size() > 1:
			h.add_child(UI.label("%d / %d" % [idx[0] + 1, reports.size()], "Small"))
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(sp)
		var last: bool = idx[0] >= reports.size() - 1
		h.add_child(UI.button(Loc.t("UI_NEXT") if not last else Loc.t("UI_CLOSE"), func() -> void:
			if last:
				dim.queue_free()
				on_done.call()
			else:
				idx[0] += 1
				render.call(), "Primary"))
		v.add_child(h)
	render.call()

static func _page(v: VBoxContainer, s: Dictionary, r: Dictionary) -> void:
	var me: String = Game.active_player
	var owners_a: Array = r["attackers"]["owners"]
	var owners_d: Array = r["defenders"]["owners"]
	var att_wins: bool = r["winner"] == "attacker"
	var i_won: bool = (me in owners_a and att_wins) or (me in owners_d and not att_wins)
	var title := UI.label(Loc.tf("BR_TITLE", {"province": Defs.province_name(r["pid"])}), "Heading")
	v.add_child(title)
	var verdict := UI.label(Loc.t("UI_VICTORY") if i_won else Loc.t("UI_DEFEAT"), "Good" if i_won else "Bad")
	v.add_child(verdict)
	var sub := "%s · %s · %s" % [Fmt.terrain_name(str(r["terrain"])), Loc.t("SEASON_" + str(["spring", "summer", "autumn", "winter"][int(r.get("weather", 0))]).to_upper()), Loc.tf("BR_WIDTH", {"n": int(r["width"])})]
	if float(r["fort"]) > 0.0:
		sub += " · " + Loc.tf("BR_FORT", {"n": "%.1f" % float(r["fort"])})
	if bool(r.get("naval", false)):
		sub = "%s · %s" % [Loc.t("BR_NAVAL"), Loc.t("SEASON_" + str(["spring", "summer", "autumn", "winter"][int(r.get("weather", 0))]).to_upper())]
		var sea: Dictionary = r.get("sea", {})
		if not sea.is_empty():
			sub += " · " + SeaZones.zone_name(str(sea.get("zone", ""))) + " · " + Loc.tf("BR_SEA_STATE", {"n": int(float(sea.get("state", 0.0)) * 100.0)})
	var rv: Dictionary = r.get("river", {})
	if float(rv.get("share", 0.0)) > 0.0:
		sub += " · " + Loc.tf("BR_RIVER", {"name": str(rv.get("name", "")) if str(rv.get("name", "")) != "" else Loc.t("BR_RIVER_UNNAMED"), "w": int(rv.get("width", 1))})
	var ps: Dictionary = r.get("pass", {})
	if float(ps.get("share", 0.0)) > 0.0:
		sub += " · " + Loc.tf("BR_PASS", {"name": str(ps.get("name", "")) if str(ps.get("name", "")) != "" else Loc.t("BR_PASS_UNNAMED")})
	v.add_child(UI.label(sub, "Small", -1, true))
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 16)
	for side in ["a", "d"]:
		var owners: Array = owners_a if side == "a" else owners_d
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for o in owners:
			var hh := HBoxContainer.new()
			hh.add_child(FlagView.make(s["countries"][o]["flag"], Util.color_from(s["countries"][o]["color"]), Vector2(44, 29)))
			hh.add_child(UI.label(GS.country_name(s, o), "Value"))
			col.add_child(hh)
		var start := float(r["start_" + side])
		var loss := float(r["loss_" + side])
		col.add_child(UI.label(Loc.tf("BR_STRENGTH", {"start": int(round(start)), "loss": int(round(loss * 10.0)) / 10.0, "end": int(round(float(r["end_" + side])))}), "Small"))
		col.add_child(UI.label(Loc.tf("BR_MEN", {"n": UI.fmt(loss * 1000.0)}), "Small"))
		var ci: Dictionary = r.get("commanders", {}).get(side, {})
		if not ci.is_empty():
			var tn: Array = []
			for tr_id in ci.get("traits", []):
				tn.append(Loc.t("TRAIT_" + str(tr_id).to_upper()))
			col.add_child(UI.label("%s: %s (%d)%s" % [Loc.t("BR_COMMANDER"), str(ci.get("name", "")), int(ci.get("tac", 0)), ("  " + ", ".join(tn)) if not tn.is_empty() else ""], "Tiny", -1, true))
		cols.add_child(col)
	v.add_child(cols)
	var anim := BattleAnim.new()
	anim.rep = r
	anim.col_a = Util.color_from(s["countries"][owners_a[0]]["color"])
	anim.col_d = Util.color_from(s["countries"][owners_d[0]]["color"])
	anim.custom_minimum_size = Vector2(0, 150)
	v.add_child(anim)
	if bool(Settings.get_value("animations")):
		var tw := anim.create_tween()
		tw.tween_method(func(x: float) -> void:
			anim.t = x
			anim.queue_redraw(), 0.0, 1.0, 1.8)
	else:
		anim.t = 1.0
	v.add_child(UI.hsep())
	v.add_child(UI.label(Loc.tf("BR_WHY", {"winner": GS.country_name(s, (owners_a if att_wins else owners_d)[0])}), "Sub"))
	for rs in r["reasons"]:
		v.add_child(UI.label("• " + Loc.t(str(rs)), "Small", -1, true))
	# every factor with its numeric contribution (percent change of the side's effectiveness)
	for ev in r.get("events", []):
		v.add_child(UI.label("• " + Loc.tf("BR_EVENT_" + str(ev["kind"]).to_upper(), {"name": str(ev["name"]), "country": GS.country_name(s, str(ev["owner"]))}), "Small", -1, true))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_child(UI.label(Loc.t("BR_FACTORS"), "Tiny"))
	grid.add_child(UI.label(Loc.t("BR_ATTACKER"), "Tiny", HORIZONTAL_ALIGNMENT_RIGHT))
	grid.add_child(UI.label(Loc.t("BR_DEFENDER"), "Tiny", HORIZONTAL_ALIGNMENT_RIGHT))
	for f in r.get("modifiers", []):
		var name_l := UI.label(Loc.t(str(f["key"])), "Small")
		if str(f["kind"]) == "inc":
			name_l.tooltip_text = Loc.t("BR_INCLUDED_TIP")
		grid.add_child(name_l)
		var la: Label
		var ld: Label
		if str(f["kind"]) == "info":
			la = UI.label(UI.fmt(float(f["va"])), "Value", HORIZONTAL_ALIGNMENT_RIGHT)
			ld = UI.label(UI.fmt(float(f["vd"])), "Value", HORIZONTAL_ALIGNMENT_RIGHT)
		else:
			var pa := BattleFactors.contribution_pct(f, "a")
			var pd := BattleFactors.contribution_pct(f, "d")
			la = UI.label("%+.0f%%" % pa, "Value", HORIZONTAL_ALIGNMENT_RIGHT)
			ld = UI.label("%+.0f%%" % pd, "Value", HORIZONTAL_ALIGNMENT_RIGHT)
			la.add_theme_color_override("font_color", UI.GOOD if pa > 0.5 else (UI.BAD if pa < -0.5 else Color("f4ecd6")))
			ld.add_theme_color_override("font_color", UI.GOOD if pd > 0.5 else (UI.BAD if pd < -0.5 else Color("f4ecd6")))
		grid.add_child(la)
		grid.add_child(ld)
	v.add_child(UI.scroll(grid, 190))
