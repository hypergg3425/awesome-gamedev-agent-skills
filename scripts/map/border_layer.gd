extends Node2D
## Draws province / country / front lines (the shoreline lives in chunked CoastChunk children). Widths are in screen
## pixels (divided by zoom), so the layer is redrawn only when the zoom tier changes. Styles: province = thin, fading in with
## zoom; country = dark line over a soft light halo; front = red line over a red glow; coast = dark smoothed shoreline.

var view: MapView

func add_coast_outline(chunks: Dictionary) -> void:
	for k in chunks:
		var c := Node2D.new()
		c.set_script(preload("res://scripts/map/coast_chunk.gd"))
		c.view = view
		c.outline = true
		c.hi = chunks[k]["hi"]
		c.lo = chunks[k]["lo"]
		add_child(c)

func queue_redraw_all() -> void:
	queue_redraw()
	for c in get_children():
		c.queue_redraw()

func _draw() -> void:
	if view == null:
		return
	var z := maxf(view.zoom, 0.05)
	var prov_alpha := clampf(0.18 + 0.12 * log(z / 0.45) / log(2.0), 0.18, 0.7)
	var pc: Color = view.border_colors["province"]
	if view.seg_province.size() > 0:
		draw_multiline(view.seg_province, Color(pc.r, pc.g, pc.b, prov_alpha), 0.9 / z)
	if view.seg_country.size() > 0:
		draw_multiline(view.seg_country, Color(1, 0.97, 0.88, 0.22), 4.6 / z)
		draw_multiline(view.seg_country, view.border_colors["country"], 2.0 / z)
	if view.seg_front.size() > 0:
		draw_multiline(view.seg_front, Color(0.9, 0.12, 0.08, 0.3), 7.0 / z)
		draw_multiline(view.seg_front, view.border_colors["front"], 3.0 / z)
