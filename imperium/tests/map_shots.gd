extends Node
## Map screenshot review: one PNG per map mode and zoom. Run under Xvfb:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 res://tests/map_shots.tscn -- out=/tmp/claude-0/ms set=classic lang=en modes=all zooms=world,mid,high [scenario=early_modern country=FRA]
## Also prints the CPU cost of a colour refresh and of overlay redraws on this map set.

var out := "/tmp/claude-0/ms"
var args := {}

func _snap(name: String) -> void:
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s_%s.png" % [out, name])
	print("saved ", name, " ", img.get_size())

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	out = args.get("out", out)
	var set_id: String = args.get("set", "classic")
	Settings.set_value("language", args.get("lang", "en"), false)
	Loc.set_language(args.get("lang", "en"))
	Layout.install(get_window())
	get_tree().root.theme = UI.theme()
	Settings.set_value("animations", false, false)
	Defs.default_map_set = set_id
	var r: Dictionary = Game.new_game(args.get("scenario", "early_modern"), args.get("country", "FRA"), "normal", 5)
	print("new_game ", r, " map_set=", Defs.map_set, " provinces=", Defs.province_ids.size())
	for i in 6:
		TurnManager.end_turn(Game.state)   # some wars, armies, battles
	var camp: Control = load("res://scenes/campaign/campaign.tscn").instantiate()
	add_child(camp)
	await get_tree().create_timer(0.8).timeout
	var cs := camp as CampaignScreen
	for c in cs.overlay_layer.get_children():
		c.queue_free()
	cs.close_sheets()
	cs.province_panel.dismiss()
	cs.cmap.select("")
	cs.toast_box.visible = false
	var modes: Array = Array(MapModes.MODES) if args.get("modes", "all") == "all" else Array(String(args["modes"]).split(","))
	var zooms: Array = String(args.get("zooms", "world,mid")).split(",")
	var views := {"world": [Vector2(1800, 600), 0.0], "mid": [Vector2(100, -520), 1.8], "high": [Vector2(100, -520), 4.2], "close": [Vector2(100, -520), 8.0]}
	for m in modes:
		cs.set_map_mode(m)
		for z in zooms:
			var v: Array = views[z]
			if z == "world":
				cs.mapview.fit_world()
			else:
				cs.mapview.focus_on(v[0], v[1], false)
			await _snap("%s_%s_%s" % [set_id, m, z])
	cs.mapview.fit_world()
	cs.set_map_mode("political")
	cs._toggle_modes()
	await _snap("%s_strip" % set_id)
	await _timing(cs)
	get_tree().quit(0)

func _timing(cs: CampaignScreen) -> void:
	var t := Time.get_ticks_usec()
	for i in 5:
		cs.cmap.refresh()
	print("refresh avg ms: %.1f" % (float(Time.get_ticks_usec() - t) / 5000.0))
	for z in [0.6, 1.8, 4.2]:
		cs.mapview.zoom = z
		cs.mapview._apply_camera()
		var sum := 0
		for i in 10:
			cs.mapview.overlay.queue_redraw()
			await get_tree().process_frame
			sum += cs.mapview.overlay.last_draw_usec
		print("overlay _draw zoom %.1f avg ms: %.2f (city glyphs %d)" % [z, float(sum) / 10000.0, cs.mapview.overlay.last_city_glyphs])
