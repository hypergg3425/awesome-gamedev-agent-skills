class_name MapLegend
extends PanelContainer
## Legend of the active map mode: colour ramp with low/high labels, or a list of colour swatches, plus a short note.
## Content comes from MapModes.legend (already localised). Tapping the title collapses / expands the widget, which
## keeps the map visible on phones. Mouse events on the body pass through to the map.

var _mode := ""
var collapsed := false
var _body: VBoxContainer
var _title: Button

func _init() -> void:
	theme_type_variation = "HudDrop"
	mouse_filter = Control.MOUSE_FILTER_PASS
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 3)
	add_child(_body)

## Rebuild for `mode` from the current state.
func show_mode(mode: String, s: Dictionary, me: String) -> void:
	_mode = mode
	UI.clear(_body)
	var leg := MapModes.legend(mode, s, me)
	_title = Button.new()
	_title.text = ("%s  %s" % ["+" if collapsed else "-", leg["title"]])
	_title.flat = true
	_title.focus_mode = Control.FOCUS_NONE
	_title.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_title.custom_minimum_size = Vector2(0, maxf(Layout.touch_min(get_window()), 40.0) * 0.8)
	_title.add_theme_font_size_override("font_size", UI.fs(16))
	_title.pressed.connect(_toggle)
	_body.add_child(_title)
	if collapsed:
		return
	if leg["kind"] == "ramp":
		_body.add_child(_ramp_bar(leg["stops"]))
		var row := HBoxContainer.new()
		row.add_child(UI.label(leg["lo"], "Small"))
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(sp)
		row.add_child(UI.label(leg["hi"], "Small"))
		_body.add_child(row)
	else:
		for it in leg["items"]:
			var row2 := HBoxContainer.new()
			row2.add_theme_constant_override("separation", 6)
			var sw := ColorRect.new()
			sw.color = it["color"]
			sw.custom_minimum_size = Vector2(16, 16)
			row2.add_child(sw)
			row2.add_child(UI.label(it["text"], "Small"))
			_body.add_child(row2)
	if str(leg["note"]) != "":
		var note := UI.label(leg["note"], "Small", -1, true)
		note.modulate = Color(1, 1, 1, 0.7)
		note.custom_minimum_size = Vector2(170, 0)
		_body.add_child(note)

func _ramp_bar(stops: Array) -> Control:
	var bar := TextureRect.new()
	var g := Gradient.new()
	var offs := PackedFloat32Array()
	var cols := PackedColorArray()
	for i in stops.size():
		offs.append(float(i) / float(stops.size() - 1))
		cols.append(stops[i])
	g.offsets = offs
	g.colors = cols
	var gt := GradientTexture1D.new()
	gt.gradient = g
	gt.width = 128
	bar.texture = gt
	bar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bar.stretch_mode = TextureRect.STRETCH_SCALE
	bar.custom_minimum_size = Vector2(170, 14)
	return bar

func _toggle() -> void:
	collapsed = not collapsed
	if Game.has_state():
		show_mode(_mode, Game.state, Game.active_player)
	reset_size()
