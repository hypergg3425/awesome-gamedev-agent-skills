class_name PanelsEspionage
extends RefCounted
## Espionage sheet: spy networks, covert operations (with live success chances), intelligence reports and the results log.

static var _target := ""

static func build(sheet: Sheet, _screen: CampaignScreen) -> void:
	sheet.add_tab("networks", "ESP_TAB_NETWORKS", func(b: VBoxContainer) -> void: _networks(b, sheet))
	sheet.add_tab("ops", "ESP_TAB_OPS", func(b: VBoxContainer) -> void: _ops(b, sheet))
	sheet.add_tab("intel", "ESP_TAB_INTEL", func(b: VBoxContainer) -> void: _intel(b))
	sheet.add_tab("log", "ESP_TAB_LOG", func(b: VBoxContainer) -> void: _log(b))

static func _candidates(s: Dictionary, me: String) -> Array:
	var out: Array = []
	for oid in GS.alive_countries(s):
		if oid != me and EspionageSystem.can_target(s, me, oid)["ok"]:
			out.append([-DiplomacySystem.power_score(s, oid), oid])
	out.sort()
	return out

static func _networks(b: VBoxContainer, sheet: Sheet) -> void:
	var s: Dictionary = Game.state
	var me: String = Game.active_player
	var e := EspionageSystem.st(s, me)
	var top := Sheet.card(b)
	top.add_child(UI.label(Loc.t("ESP_INTRO"), "Small", -1, true))
	Sheet.kv(top, Loc.t("ESP_UPKEEP"), "%.1f %s" % [EspionageSystem.upkeep(s, me), Loc.t("UI_PER_TURN")])
	Sheet.kv(top, Loc.t("ESP_CAPACITY"), "%d / %d" % [(e["net"] as Dictionary).size(), EspionageSystem.max_networks(s, me)])
	var ci := Sheet.card(b)
	Sheet.header(ci, Loc.t("ESP_CI"))
	ci.add_child(UI.progress(EspionageSystem.ci_strength(s, me), 8.0, UI.VERDIGRIS, "%s %.1f" % [Loc.t("ESP_CI_LEVEL"), EspionageSystem.ci_strength(s, me)]))
	var cb := UI.button(Loc.tf("ESP_RAISE_CI", {"cost": int(EspionageSystem.ci_cost(s, me))}), func() -> void:
		Game.cmd_counter_intel(), "Primary")
	cb.disabled = int(e["ci"]) >= EspionageSystem.MAX_LEVEL
	ci.add_child(cb)
	var nets := Sheet.card(b)
	Sheet.header(nets, Loc.t("ESP_NETWORKS"))
	var shown := {}
	for tid in Util.sorted_keys(e["net"]):
		shown[tid] = true
		_network_row(nets, s, me, tid)
	var add := Sheet.card(b)
	Sheet.header(add, Loc.t("ESP_NEW_NETWORK"))
	var n := 0
	for it in _candidates(s, me):
		if shown.has(it[1]) or n >= 10:
			continue
		n += 1
		_network_row(add, s, me, str(it[1]))

static func _network_row(parent: Control, s: Dictionary, me: String, tid: String) -> void:
	var lvl := EspionageSystem.level(s, me, tid)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var l := UI.label("%s   %s" % [GS.country_name(s, tid), "★".repeat(lvl) + "☆".repeat(EspionageSystem.MAX_LEVEL - lvl)], "Small", -1, true)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	var chk := EspionageSystem.can_build(s, me, tid)
	var bt := UI.button("%s (%d)" % [Loc.t("ESP_BUILD") if lvl == 0 else Loc.t("ESP_GROW"), int(EspionageSystem.build_cost(s, me, tid))], func() -> void:
		Game.cmd_spy_build(tid), "Primary" if chk["ok"] else "")
	bt.disabled = not chk["ok"]
	bt.custom_minimum_size = Vector2(150, 44)
	if not chk["ok"]:
		bt.tooltip_text = NoteFmt.error_text(str(chk["reason"]), chk.get("params", {}))
	h.add_child(bt)
	parent.add_child(h)

static func _ops(b: VBoxContainer, sheet: Sheet) -> void:
	var s: Dictionary = Game.state
	var me: String = Game.active_player
	var e := EspionageSystem.st(s, me)
	var targets: Array = Util.sorted_keys(e["net"])
	if targets.is_empty():
		b.add_child(UI.label(Loc.t("ESP_NO_NETWORKS"), "Small", -1, true))
		return
	if _target not in targets:
		_target = str(targets[0])
	var pick := Sheet.card(b)
	Sheet.header(pick, Loc.t("ESP_TARGET"))
	var row := HFlowContainer.new()
	for tid in targets:
		var t: String = tid
		row.add_child(UI.button(GS.country_name(s, t), func() -> void:
			_target = t
			sheet.refresh(), "Primary" if t == _target else "Tab"))
	pick.add_child(row)
	Sheet.kv(pick, Loc.t("ESP_NET_LEVEL"), "%d / %d" % [EspionageSystem.level(s, me, _target), EspionageSystem.MAX_LEVEL])
	Sheet.kv(pick, Loc.t("ESP_TARGET_CI"), "%.1f" % EspionageSystem.ci_strength(s, _target), Loc.t("ESP_TARGET_CI_TIP"))
	for op in EspionageSystem.OP_ORDER:
		var o: String = op
		var chk := EspionageSystem.can_op(s, me, _target, o)
		var card := Sheet.card(b)
		var h := HBoxContainer.new()
		var nm := UI.label(Loc.t("ESP_OP_" + o.to_upper()), "Value")
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(nm)
		var chance := EspionageSystem.op_chance(s, me, _target, o)
		h.add_child(UI.label("%d%%  ·  %d" % [int(round(chance * 100.0)), int(EspionageSystem.op_cost(s, me, _target, o))], "Small"))
		card.add_child(h)
		card.add_child(UI.label(Loc.t("ESP_OPD_" + o.to_upper()), "Tiny", -1, true))
		var go := UI.button(Loc.t("ESP_RUN"), func() -> void:
			var r := Game.cmd_spy_op(_target, o)
			if r.get("ok", false):
				Dialogs.info(Game.get_tree().current_scene, Loc.t("ESP_OP_" + o.to_upper()), Loc.t("ESP_RESULT_OK") if r.get("success", false) else (Loc.t("ESP_RESULT_CAUGHT") if r.get("caught", false) else Loc.t("ESP_RESULT_QUIET"))), "Primary" if chk["ok"] else "")
		go.disabled = not chk["ok"]
		if not chk["ok"]:
			card.add_child(UI.label(NoteFmt.error_text(str(chk["reason"]), chk.get("params", {})), "Tiny"))
		card.add_child(go)

static func _intel(b: VBoxContainer) -> void:
	var s: Dictionary = Game.state
	var me: String = Game.active_player
	var e := EspionageSystem.st(s, me)
	b.add_child(UI.label(Loc.t("ESP_INTEL_INTRO"), "Small", -1, true))
	var any := false
	for tid in Util.sorted_keys(e["net"]):
		any = true
		var card := Sheet.card(b)
		Sheet.header(card, GS.country_name(s, tid))
		var acc := EspionageSystem.accuracy(s, me, tid)
		Sheet.kv(card, Loc.t("ESP_ACCURACY"), Fmt.pct(acc))
		var mil := EspionageSystem.military_intel(s, me, tid)
		Sheet.kv(card, Loc.t("ESP_MIL_INTEL"), _range_text(mil, 1))
		var eco := EspionageSystem.economic_intel(s, me, tid)
		for k in ["gold", "income", "debt"]:
			Sheet.kv(card, Loc.t("ESP_ECO_" + str(k).to_upper()), _range_text(eco[k], 0))
	if not any:
		b.add_child(UI.label(Loc.t("ESP_NO_NETWORKS"), "Small", -1, true))

static func _range_text(r: Dictionary, dec: int) -> String:
	if not bool(r["known"]):
		return Loc.t("ESP_UNKNOWN")
	if bool(r["exact"]):
		return Util.fmt_num(float(r["est"]), dec)
	return "~%s  (%s – %s)" % [Util.fmt_num(float(r["est"]), dec), Util.fmt_num(float(r["lo"]), dec), Util.fmt_num(float(r["hi"]), dec)]

static func _log(b: VBoxContainer) -> void:
	var s: Dictionary = Game.state
	var e := EspionageSystem.st(s, Game.active_player)
	var lg: Array = e["log"]
	var card := Sheet.card(b)
	Sheet.kv(card, Loc.t("ESP_OPS_DONE"), str(int(e["ops_done"])))
	Sheet.kv(card, Loc.t("ESP_AGENTS_CAUGHT"), str(int(e["caught"])), "", UI.BAD if int(e["caught"]) > 0 else Color("f4ecd6"))
	if lg.is_empty():
		b.add_child(UI.label(Loc.t("UI_NONE"), "Small"))
	for i in range(lg.size() - 1, -1, -1):
		var it: Dictionary = lg[i]
		var kind := str(it["kind"])
		var nm := Loc.t("ESP_OP_" + kind.to_upper()) if Loc.has_key("ESP_OP_" + kind.to_upper()) else kind
		var txt := "%s  ·  %s  ·  %s" % [Loc.tf("UI_TURN_N", {"n": int(it["turn"]) + 1}), nm, GS.country_name(s, str(it["other"]))]
		var l := UI.label(txt, "Small", -1, true)
		l.add_theme_color_override("font_color", UI.GOOD if bool(it["ok"]) else UI.BAD)
		b.add_child(l)
