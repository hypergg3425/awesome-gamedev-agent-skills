class_name DiplomacyPrompts
extends RefCounted
## Pop-ups for AI proposals (alliance, trade, peace ...).

static func request_text(s: Dictionary, r: Dictionary) -> String:
	if r["action"] == "peace":
		var t: Dictionary = r["params"]["terms"]
		var what := Loc.t("PEACE_OFFER_WHITE") if t.get("white", false) else Loc.t("PEACE_OFFER_TERMS")
		return Loc.tf("PROPOSAL_PEACE", {"country": GS.country_name(s, r["from"]), "what": what})
	return Loc.tf("PROPOSAL_GENERIC", {"country": GS.country_name(s, r["from"]), "action": Loc.t("ACT_" + str(r["action"]).to_upper())})

static func show_request(host: Control, r: Dictionary) -> void:
	var s: Dictionary = Game.state
	var dlg := Dialogs.custom(host, Loc.t("PROPOSAL_TITLE"), 620.0)
	(dlg["dim"] as Control).remove_meta("back")   # a proposal must be answered explicitly
	var box: VBoxContainer = dlg["box"]
	var h := HBoxContainer.new()
	var oc: Dictionary = s["countries"][r["from"]]
	h.add_child(FlagView.make(oc["flag"], Util.color_from(oc["color"]), Vector2(70, 46)))
	h.add_child(UI.label(request_text(s, r), "Value", -1, true))
	box.add_child(h)
	if r["action"] == "peace":
		var terms: Dictionary = r["params"]["terms"]
		for pid in terms.get("provinces", []):
			box.add_child(UI.label("• " + Defs.province_name(pid), "Small"))
	var bh := HBoxContainer.new()
	var no := UI.button(Loc.t("UI_DECLINE"), func() -> void:
		dlg["close"].call()
		Game.cmd_respond_request(r["id"], false))
	no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var yes := UI.button(Loc.t("UI_ACCEPT"), func() -> void:
		dlg["close"].call()
		Game.cmd_respond_request(r["id"], true), "Primary")
	yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bh.add_child(no)
	bh.add_child(yes)
	box.add_child(bh)
	Audio.sfx("diplomacy_notify")
