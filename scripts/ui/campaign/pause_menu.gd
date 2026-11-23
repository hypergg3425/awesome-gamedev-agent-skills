class_name PauseMenu
extends RefCounted
## In-campaign menu: resume, save, load, settings, back to main menu.

static func show_menu(host: Control, screen: CampaignScreen) -> void:
	var dlg := Dialogs.custom(host, Loc.t("UI_MENU"), 460.0)
	var box: VBoxContainer = dlg["box"]
	var close: Callable = dlg["close"]
	box.add_child(UI.button(Loc.t("UI_RESUME"), func() -> void: close.call(), "Primary", "next"))
	box.add_child(UI.button(Loc.t("UI_SAVE_GAME"), func() -> void:
		close.call()
		SaveLoadDialog.show_save(host), "", "save"))
	box.add_child(UI.button(Loc.t("UI_LOAD_GAME"), func() -> void:
		close.call()
		SaveLoadDialog.show_load(host, func() -> void: screen.get_tree().change_scene_to_file("res://scenes/campaign/campaign.tscn")), "", "load"))
	box.add_child(UI.button(Loc.t("MENU_SETTINGS"), func() -> void:
		close.call()
		SettingsPanel.show_dialog(host), "", "settings"))
	box.add_child(UI.button(Loc.t("UI_QUIT_TO_MENU"), func() -> void:
		close.call()
		Dialogs.confirm(host, Loc.t("UI_QUIT_TO_MENU"), Loc.t("CONFIRM_QUIT_MENU"), func() -> void:
			Saves.autosave(Game.state)
			Game.quit_to_menu()
			screen.get_tree().change_scene_to_file("res://scenes/menus/main_menu.tscn"), Loc.t("UI_QUIT_TO_MENU"), true), "", "back"))
