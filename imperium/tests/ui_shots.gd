extends Node
## Renders the main screens and saves PNGs (run under Xvfb). Usage: ui_shots.tscn -- <outprefix> [lang]

var out := "/tmp/claude-0/ui"

func _snap(name: String) -> void:
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s_%s.png" % [out, name])
	print("saved ", name, " ", img.get_size())

func _show(scene: Node) -> void:
	for c in get_children():
		c.queue_free()
	add_child(scene)

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	if args.size() > 1:
		Settings.set_value("language", args[1], false)
		Loc.set_language(args[1])
	Layout.install(get_window())
	get_tree().root.theme = UI.theme()
	Defs.load_geometry()
	Settings.set_value("animations", false, false)
	var menu: Control = load("res://scenes/menus/main_menu.tscn").instantiate()
	_show(menu)
	await _snap("menu")
	Nav.mode = "new"
	var sel: Control = load("res://scenes/menus/scenario_select.tscn").instantiate()
	_show(sel)
	await _snap("scenarios")
	Nav.scenario_id = "early_modern"
	var cs: Control = load("res://scenes/menus/country_select.tscn").instantiate()
	_show(cs)
	await get_tree().create_timer(0.3).timeout
	await _snap("country")
	var r: Dictionary = Game.new_game("early_modern", "FRA", "normal", 5)
	print("new_game ", r)
	var camp: Control = load("res://scenes/campaign/campaign.tscn").instantiate()
	_show(camp)
	await get_tree().create_timer(0.6).timeout
	await _snap("campaign")
	var cscr := camp as CampaignScreen
	for sh in ["country", "economy", "military", "diplomacy", "technology", "politics", "objectives", "events"]:
		cscr.open_sheet(sh)
		await _snap("sheet_" + sh)
	cscr.close_sheets()
	cscr.select_province("fra_normandy")
	cscr.province_panel.tab = "build"
	cscr.province_panel.refresh()
	await _snap("province_build")
	cscr.province_panel.tab = "army"
	cscr.province_panel.refresh()
	await _snap("province_army")
	cscr.set_map_mode("economic")
	cscr.mapview.focus_on(Vector2(100, -520), 3.6, false)
	await _snap("map_economic")
	cscr.set_map_mode("diplomatic")
	await _snap("map_diplomatic")
	cscr.set_map_mode("political")
	var sc2: Control = load("res://scenes/menus/credits.tscn").instantiate()
	_show(sc2)
	await _snap("credits")
	var ed: Control = load("res://scenes/editor/editor.tscn").instantiate()
	_show(ed)
	await get_tree().create_timer(0.5).timeout
	await _snap("editor")
	get_tree().quit(0)
