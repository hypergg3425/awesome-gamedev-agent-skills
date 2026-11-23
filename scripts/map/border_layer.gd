extends Node2D
## Draws province / country / coast / front lines. Width is quantised to zoom tiers so redraws are rare.

var view: MapView

func _draw() -> void:
	if view == null:
		return
	var z := maxf(view.zoom, 0.05)
	var tier := clampf(z, 0.25, 12.0)
	var hair := 0.9 / z                 # about one screen pixel
	if view.seg_coast.size() > 0:
		draw_multiline(view.seg_coast, view.border_colors["coast"], 1.4 / z)
	if view.seg_province.size() > 0:
		draw_multiline(view.seg_province, view.border_colors["province"], hair)
	if view.seg_country.size() > 0:
		draw_multiline(view.seg_country, view.border_colors["country"], 2.3 / z)
	if view.seg_front.size() > 0:
		draw_multiline(view.seg_front, view.border_colors["front"], 3.2 / z)
