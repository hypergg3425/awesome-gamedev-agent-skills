class_name CampaignLayout
extends RefCounted
## Pure geometry for the campaign screen (no nodes): given the virtual viewport, safe-area insets and the banner
## height it returns the rectangle of every chrome element so the HUD, toolbar, province panel, sheets, End-turn button
## and the move bar never overlap. Used by CampaignScreen and by tests/ui_layout_check.gd.

const MARGIN := 8.0
const GAP := 6.0
const MODE_COLUMNS := 5
const MODE_BTN_W := 146.0
const LEGEND_W := 190.0

## Returns {hud, toolbar, toolbar_vertical, end, province, sheet, sheet_hides_province, modes, legend, toast, move, avail, tb}.
static func compute(vs: Vector2, ins: Dictionary, banner: float, tool_count: int, tb: float = 52.0, province_open: bool = false, mode_count: int = 15) -> Dictionary:
	var a := Rect2(float(ins["left"]), float(ins["top"]), vs.x - float(ins["left"]) - float(ins["right"]),
			vs.y - float(ins["top"]) - float(ins["bottom"]) - banner)
	var compact := Layout.compact(vs)
	var hud_h := tb + 10.0
	var hud := Rect2(a.position, Vector2(a.size.x, hud_h))
	var btn := tb + (0.0 if compact else 4.0)
	var tool_need := float(tool_count) * (btn + GAP)
	var end_size := Vector2(clampf(a.size.x * 0.2, 150.0, 230.0), btn + 6.0)
	var end := Rect2(a.end - end_size - Vector2(MARGIN, MARGIN), end_size)
	var free_h := end.position.y - hud.end.y - 2.0 * MARGIN
	var vertical := (tool_need <= free_h) and not compact
	var tool_size := Vector2(btn, tool_need - GAP) if vertical else Vector2(tool_need - GAP, btn)
	var tool_pos := Vector2(a.position.x + MARGIN, hud.end.y + MARGIN) if vertical else Vector2(a.position.x + MARGIN, a.end.y - MARGIN - btn)
	var toolbar := Rect2(tool_pos, tool_size)
	# right-hand province panel
	var pw := Layout.panel_width(a.size.x * 0.34, 400.0, 300.0)
	var pbottom := end.position.y - MARGIN
	var province := Rect2(a.end.x - pw - MARGIN, hud.end.y + MARGIN, pw, maxf(120.0, pbottom - hud.end.y - MARGIN))
	# sheets
	var sx := toolbar.end.x + MARGIN if vertical else a.position.x + MARGIN
	var sheet_bottom := toolbar.position.y - MARGIN if not vertical else a.end.y - MARGIN
	var sheet_w := minf(800.0, a.end.x - MARGIN - sx)
	var hides := false
	if compact:
		# phone: the sheet takes the whole area below the HUD; toolbar and End-turn hide while it is open
		sheet_bottom = a.end.y - MARGIN
		sx = a.position.x + MARGIN
		sheet_w = a.size.x - 2.0 * MARGIN
		hides = true
	elif sx + sheet_w + MARGIN > province.position.x:
		var fit := province.position.x - MARGIN - sx
		if fit >= 560.0:
			sheet_w = fit
		else:
			hides = true
			sheet_w = minf(800.0, a.end.x - MARGIN - sx)
	var sheet := Rect2(sx, hud.end.y + MARGIN, maxf(300.0, sheet_w), maxf(160.0, sheet_bottom - hud.end.y - MARGIN))
	# map-mode strip (horizontal pill next to / above the toolbar)
	var mode_cols := mini(mode_count, MODE_COLUMNS)
	var mode_rows := int(ceil(float(mode_count) / float(MODE_COLUMNS)))
	var mode_w := float(mode_cols) * (MODE_BTN_W + 4.0) + 20.0
	var mode_h := float(mode_rows) * (btn + 4.0) + 12.0
	var modes := Rect2(Vector2(toolbar.end.x + MARGIN, toolbar.end.y - mode_h), Vector2(mode_w, mode_h)) if vertical \
			else Rect2(Vector2(toolbar.position.x, toolbar.position.y - mode_h - GAP), Vector2(mode_w, mode_h))
	modes.position.x = minf(modes.position.x, a.end.x - mode_w - MARGIN)
	# map legend: top-left under the HUD, right of the vertical toolbar
	var legend_x := (toolbar.end.x + MARGIN) if vertical else a.position.x + MARGIN
	var legend := Rect2(Vector2(legend_x, hud.end.y + MARGIN), Vector2(LEGEND_W, 40.0))
	var toast_w := minf(600.0, a.size.x - 2.0 * MARGIN)
	var toast := Rect2(Vector2(a.position.x + (a.size.x - toast_w) * 0.5, hud.end.y + 10.0), Vector2(toast_w, 10.0))
	# move bar: between the toolbar and the End-turn button, above them when there is no room
	var left_edge := (toolbar.end.x + MARGIN) if vertical else a.position.x + MARGIN
	var move_w := minf(720.0, a.end.x - MARGIN - left_edge - (end.size.x + 2.0 * MARGIN if end.position.y > a.end.y - 160.0 else 0.0))
	var move := Rect2(Vector2(left_edge, a.end.y - MARGIN - (btn + 14.0)), Vector2(maxf(280.0, move_w), btn + 14.0))
	if not vertical:
		move.position.y = toolbar.position.y - GAP - move.size.y
		if end.intersects(move):
			move.size.x = maxf(280.0, end.position.x - MARGIN - move.position.x)
	if move.end.x > end.position.x - MARGIN and move.end.y > end.position.y:
		move.size.x = maxf(240.0, end.position.x - MARGIN - move.position.x)
	return {"avail": a, "hud": hud, "toolbar": toolbar, "toolbar_vertical": vertical, "end": end, "province": province, "sheet": sheet,
		"sheet_hides_province": hides, "modes": modes, "legend": legend, "toast": toast, "move": move, "tb": btn, "compact": compact, "province_open": province_open}
