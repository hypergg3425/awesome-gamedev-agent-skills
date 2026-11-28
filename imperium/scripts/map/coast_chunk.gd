extends Node2D
## A culled chunk of coast polylines. `outline` = false draws the shallow-water bands (placed under the land),
## true draws the shoreline itself (placed over the provinces). Zoom below 1 uses the decimated + smoothed lines.

const BANDS := [[22.0, 0.045], [11.0, 0.06]]
const BAND_COL := Color(0.38, 0.62, 0.72)

var view: MapView
var outline := false
var hi: Array = []
var lo: Array = []

func _draw() -> void:
	if view == null:
		return
	var z := maxf(view.zoom, 0.05)
	var lines := hi if z >= 1.0 else lo
	if outline:
		for l in lines:
			draw_polyline(l, view.border_colors["coast"], 1.3 / z, false)
	else:
		for b in BANDS:
			for l in lines:
				draw_polyline(l, Color(BAND_COL, b[1]), b[0] / z, false)
