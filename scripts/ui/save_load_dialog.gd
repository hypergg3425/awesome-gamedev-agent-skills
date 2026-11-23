class_name SaveLoadDialog
extends RefCounted
## Slot picker for saving and loading (manual slots 1-5, plus autosaves).

static func _slots() -> Array:
	var out: Array = []
	for i in range(1, 6):
		out.append("slot_%d" % i)
	return out

static func _meta_text(m: Dictionary) -> String:
	if m.is_empty():
		return Loc.t("SAVE_EMPTY")
	if m.get("corrupt", false):
		return Loc.t("SAVE_CORRUPT")
	var nm := Loc.tx(m.get("player_name", {}))
	var scn := Loc.tx(m.get("scenario_name", {}))
	return "%s – %s\n%s · %s %d" % [nm, scn, str(m.get("date", "")), Loc.t("UI_TURN"), int(m.get("turn", 0)) + 1]

static func show_save(host: Control) -> void:
	var dlg := Dialogs.custom(host, Loc.t("UI_SAVE_GAME"), 700.0)
	var box: VBoxContainer = dlg["box"]
	for slot in _slots():
		var sl: String = slot
		var m: Dictionary = Saves.read_meta(sl)
		var b := UI.button(_meta_text(m), func() -> void:
			var doit := func() -> void:
				var r: Dictionary = Game.save_game(sl)
				if r.get("ok", false):
					dlg["close"].call()
					Audio.sfx("ui_confirm")
				else:
					Dialogs.info(host, Loc.t("ERR_GENERIC"), NoteFmt.error_text(str(r.get("reason", ""))))
			if m.is_empty():
				doit.call()
			else:
				Dialogs.confirm(host, Loc.t("SAVE_OVERWRITE"), Loc.t("SAVE_OVERWRITE_Q"), doit, "", true), "")
		b.custom_minimum_size = Vector2(0, 70)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		box.add_child(b)

static func show_load(host: Control, on_loaded: Callable) -> void:
	var dlg := Dialogs.custom(host, Loc.t("UI_LOAD_GAME"), 760.0)
	var box: VBoxContainer = dlg["box"]
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	box.add_child(list)
	var saves: Array = Saves.list_saves()
	if saves.is_empty():
		list.add_child(UI.label(Loc.t("SAVE_NONE"), "Small"))
	for m in saves:
		var sl: String = m["slot"]
		if str(sl).begins_with("t_"):
			continue
		var row := HBoxContainer.new()
		var label_prefix := ""
		if sl.begins_with("auto_"):
			label_prefix = Loc.t("SAVE_AUTO") + "\n"
		elif sl == "last":
			label_prefix = Loc.t("SAVE_LAST") + "\n"
		var b := UI.button(label_prefix + _meta_text(m), func() -> void:
			var r: Dictionary = Game.load_game(sl)
			if r.get("ok", false):
				dlg["close"].call()
				if r.get("recovered", false):
					Dialogs.info(host, Loc.t("SAVE_RECOVERED"), Loc.t("SAVE_RECOVERED_D"))
				on_loaded.call()
			else:
				Dialogs.info(host, Loc.t("SAVE_LOAD_FAILED"), NoteFmt.error_text(str(r.get("reason", "")))), "Primary" if sl == "last" else "")
		b.custom_minimum_size = Vector2(0, 72)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = bool(m.get("corrupt", false))
		row.add_child(b)
		if not sl.begins_with("auto_") and sl != "last":
			row.add_child(UI.icon_button("cross", func() -> void:
				Dialogs.confirm(host, Loc.t("SAVE_DELETE"), Loc.t("SAVE_DELETE_Q"), func() -> void:
					Saves.delete_slot(sl)
					dlg["close"].call()
					show_load(host, on_loaded), Loc.t("SAVE_DELETE"), true), Loc.t("SAVE_DELETE"), 56.0))
		list.add_child(row)
