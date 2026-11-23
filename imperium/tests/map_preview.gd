extends Control
## Developer preview: political colours by modern country; saves a screenshot when --shot is passed.

func _ready() -> void:
	var geom := Defs.load_geometry()
	var mv := MapView.new()
	mv.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(mv)
	mv.setup(geom, Defs.map_meta)
	var cols := {}
	var owners: Array = []
	for i in Defs.province_ids.size():
		var p: Dictionary = Defs.provinces[Defs.province_ids[i]]
		var a3: String = p["adm0"]
		var h := float(hash(a3) % 1000) / 1000.0
		var c := Color.from_hsv(h, 0.45, 0.78)
		var shade := 0.92 + 0.08 * float(hash(Defs.province_ids[i]) % 100) / 100.0
		mv.set_base_color(i, Color(c.r * shade, c.g * shade, c.b * shade))
		owners.append(a3)
	mv.push_colors()
	var mb := MapBorders.new(geom)
	var s := mb.build(owners)
	mv.set_border_segments(s["province"], s["country"], s["coast"])
	var lbl := {}
	var clist := []
	var groups := {}
	for i in Defs.province_ids.size():
		var p: Dictionary = Defs.provinces[Defs.province_ids[i]]
		var a3: String = p["adm0"]
		if not groups.has(a3):
			groups[a3] = []
		groups[a3].append(i)
	for a3 in groups.keys():
		var r := Rect2()
		var first := true
		for i in groups[a3]:
			r = (mv.prov_bbox[i] as Rect2) if first else r.merge(mv.prov_bbox[i])
			first = false
		clist.append({"text": a3, "pos": r.get_center(), "extent": r.size.x})
	mv.overlay.data["country_labels"] = clist
	var args := OS.get_cmdline_user_args()
	if "--shot" in args:
		await get_tree().process_frame
		await get_tree().process_frame
		var zshots := [[0, "world"], [1, "europe"]]
		await _snap(mv, "world")
		mv.focus_on(Vector2(100, -550), 4.2, false)
		await _snap(mv, "europe")
		get_tree().quit()

func _snap(mv: MapView, name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("/tmp/claude-0/shot_%s.png" % name)
	print("saved ", name, " ", img.get_size())
