extends Node
## Map render cost probe. Usage: godot --headless --path . res://tests/map_perf.tscn -- [classic|extended]
## Prints geometry sizes and the CPU time of the map update paths (colour refresh, borders, features, markers).

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	Defs.use_map_set(args[0] if args.size() > 0 else "classic")
	var g := Defs.load_geometry()
	var verts := 0
	for pl in g.polys:
		for p in pl:
			verts += (p["v"] as PackedVector2Array).size()
	var coast_pts := 0
	var coast_lines := 0
	for c in g.coasts:
		for l in c:
			coast_pts += (l as PackedVector2Array).size()
			coast_lines += 1
	var border_pts := 0
	for b in g.borders:
		for l in b["lines"]:
			border_pts += (l as PackedVector2Array).size()
	print("set=%s provinces=%d mesh_verts=%d coast_lines=%d coast_pts=%d borders=%d border_pts=%d" % [Defs.map_set, Defs.province_ids.size(), verts, coast_lines, coast_pts, g.borders.size(), border_pts])
	get_tree().quit(0)
