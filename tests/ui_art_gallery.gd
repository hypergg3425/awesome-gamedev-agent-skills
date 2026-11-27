extends Node
## Renders a contact sheet of the procedural flags (every charge on several fields) for visual review.
## Usage: xvfb-run -a godot --path . --rendering-driver opengl3 res://tests/ui_art_gallery.tscn -- /tmp/flags.png

func _ready() -> void:
	var out := "/tmp/ui_flags.png"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	get_window().size = Vector2i(1280, 720)
	var bg := ColorRect.new()
	bg.color = UI.NAVY_DEEP
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var grid := GridContainer.new()
	grid.columns = 10
	grid.position = Vector2(12, 12)
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	add_child(grid)
	var pats := ["plain", "hstripes", "cross", "quartered", "disc", "canton", "chequy", "diagonal"]
	var cols := [["#8a2b38", "#e6c876"], ["#14203a", "#e9dfc4", "#c9a24a"], ["#2c6e49", "#f4ecd6"], ["#c9a24a", "#5b1a24"]]
	var i := 0
	for k in FlagCharges.KINDS:
		for v in 2:
			var spec := {"p": pats[(i + v * 3) % pats.size()], "c": cols[(i + v) % cols.size()], "charge": k}
			grid.add_child(FlagView.make(spec, Color.GRAY, Vector2(112, 74)))
		i += 1
	for p in pats:
		grid.add_child(FlagView.make({"p": p, "c": ["#5b1a24", "#e6c876", "#14203a"], "charge": "none"}, Color.GRAY, Vector2(112, 74)))
	for f in 6:
		grid.add_child(FlagView.make({"p": "hstripes", "c": ["#8a2b38", "#e6c876"], "charge": FlagCharges.KINDS[f]}, Color.GRAY, Vector2(36, 24)))
	for n in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out)
	print("saved ", out)
	get_tree().quit()
