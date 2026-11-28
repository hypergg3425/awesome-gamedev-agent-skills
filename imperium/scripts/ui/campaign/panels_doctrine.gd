class_name PanelsDoctrine
extends RefCounted
## Doctrines tab of the military sheet: the current land and naval doctrine, what each unlocked doctrine does,
## what locked ones need, and the cost of switching.

static func build(b: VBoxContainer, _screen: CampaignScreen) -> void:
	var s: Dictionary = Game.state
	var me: String = Game.active_player
	DoctrineSystem.ensure(s, me)
	var c: Dictionary = s["countries"][me]
	for slot in DoctrineSystem.SLOTS:
		var cur := DoctrineSystem.current(c, slot)
		var card := Sheet.card(b)
		Sheet.header(card, Loc.t("DOC_SLOT_" + slot.to_upper()))
		if cur != "":
			card.add_child(UI.label(DoctrineSystem.doctrine_name(cur), "Value"))
			card.add_child(UI.label(Loc.tx(DoctrineSystem.get_def(cur)["desc"]), "Tiny", -1, true))
			card.add_child(UI.label(Fmt.effects_text(DoctrineSystem.get_def(cur)["mods"]), "Small", -1, true))
			if DoctrineSystem.strength(s, c, slot) < 1.0:
				card.add_child(UI.label(Loc.t("DOC_RETRAINING"), "Tiny", -1, true))
		for did in DoctrineSystem.ids_for_slot(slot):
			if did == cur:
				continue
			var d: Dictionary = DoctrineSystem.get_def(did)
			var box := Sheet.card(b)
			var h := HBoxContainer.new()
			var nm := UI.label(DoctrineSystem.doctrine_name(did), "Value")
			nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			h.add_child(nm)
			var chk := DoctrineSystem.can_switch(s, me, did)
			var unlocked := DoctrineSystem.is_unlocked(s, me, did)
			var did2: String = did
			var cost := DoctrineSystem.switch_cost(s, me, slot, did)
			var btn := UI.button(Loc.tf("DOC_ADOPT", {"cost": int(cost["gold"])}), func() -> void: Game.cmd_set_doctrine(did2), "Primary" if chk["ok"] else "")
			btn.disabled = not chk["ok"]
			btn.custom_minimum_size = Vector2(150, 44)
			h.add_child(btn)
			box.add_child(h)
			box.add_child(UI.label(Loc.tx(d["desc"]), "Tiny", -1, true))
			box.add_child(UI.label(Fmt.effects_text(d["mods"]), "Small", -1, true))
			if not unlocked:
				box.add_child(UI.label(Loc.tf("DOC_REQUIRES", {"req": _requirements(d)}), "Tiny", -1, true))
			elif not chk["ok"]:
				box.add_child(UI.label(Loc.tf(str(chk["reason"]), chk.get("params", {})) if Loc.has_key(str(chk["reason"])) else str(chk["reason"]), "Tiny", -1, true))

static func _requirements(d: Dictionary) -> String:
	var parts: Array = []
	for req in d["unlock"]:
		parts.append("%s %s" % [Loc.tx(Defs.tech_lines.get(str(req[0]), {}).get("name")), Fmt.roman(int(req[1]))])
	if d.get("year_min") != null:
		parts.append(str(int(d["year_min"])))
	return ", ".join(parts)
