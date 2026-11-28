extends Node2D
## Water between the ocean and the land: shallow-water bands along the coast (depth gradient, chunked so off-screen
## shores are culled) and the sea-control tint of the naval map mode. Widths are screen pixels: redrawn on zoom-tier changes only.

var view: MapView
var tint: Array = []        # [{pos, radius, color, strength}] from MapMarkers.sea_tint

func add_chunks(chunks: Dictionary) -> void:
	for k in chunks:
		var c := Node2D.new()
		c.set_script(preload("res://scripts/map/coast_chunk.gd"))
		c.view = view
		c.hi = chunks[k]["hi"]
		c.lo = chunks[k]["lo"]
		add_child(c)

func redraw_chunks() -> void:
	for c in get_children():
		c.queue_redraw()

func _draw() -> void:
	for t in tint:
		var c: Color = t["color"]
		for k in 9:
			var f := 1.0 - 0.1 * float(k)
			draw_circle(t["pos"], float(t["radius"]) * f, Color(c.r, c.g, c.b, float(t["strength"]) * 0.085))

func set_tint(t: Array) -> void:
	tint = t
	queue_redraw()
