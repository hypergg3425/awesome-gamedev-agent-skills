class_name MapFx
extends Control
## Screen-space map effects drawn above the MapView: selection ring, army march tokens, battle clashes, siege sparks,
## map-mode flash and the turn banner. All effects are optional (Settings "animations"); the node only processes while
## at least one effect is alive, so an idle map costs nothing. Positions are stored in world coordinates so effects
## follow the camera.

var mapview: MapView
var _fx: Array = []                     # {kind, t, dur, a, b, color, text}
var _selected_world := Vector2.ZERO
var _has_selection := false
var _army_locs := {}                    # army id -> last known province id
var _flash := 0.0
var _flash_color := Color(1, 1, 1, 0.0)
var _clock := 0.0

static func attach(view: MapView, parent: Control) -> MapFx:
	var f := MapFx.new()
	f.mapview = view
	parent.add_child(f)
	return f

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)

func _prov_pos(pid: String) -> Vector2:
	var i: int = Defs.province_index.get(pid, -1)
	return Vector2.ZERO if i < 0 else mapview.prov_center[i]

func _add(kind: String, dur: float, a: Vector2, b: Vector2 = Vector2.ZERO, color: Color = Color.WHITE, text: String = "") -> void:
	if not Anim.enabled():
		return
	_fx.append({"kind": kind, "t": 0.0, "dur": dur, "a": a, "b": b, "color": color, "text": text})
	set_process(true)

## --- triggers ---------------------------------------------------------------------------------------
func select_burst(pid: String) -> void:
	if pid == "":
		_has_selection = false
		queue_redraw()
		return
	_selected_world = _prov_pos(pid)
	_has_selection = true
	_add("ring", 0.55, _selected_world, Vector2.ZERO, UI.GOLD_LIGHT)
	if Anim.enabled():
		set_process(true)

func mode_flash(c: Color = Color(1, 0.95, 0.8)) -> void:
	if not Anim.enabled():
		return
	_flash = 1.0
	_flash_color = c
	set_process(true)

func battle(pid: String, player_won: bool) -> void:
	var col := Color(0.95, 0.8, 0.35) if player_won else Color(0.9, 0.3, 0.25)
	_add("clash", 1.1, _prov_pos(pid), Vector2.ZERO, col)

func turn_banner(text: String) -> void:
	_add("banner", 1.4, Vector2.ZERO, Vector2.ZERO, UI.GOLD_LIGHT, text)

## Compare army locations with the previous snapshot and animate tokens that moved.
func track_armies(s: Dictionary) -> void:
	var seen := {}
	for aid in s["armies"]:
		var a: Dictionary = s["armies"][aid]
		var loc: String = a["loc"]
		seen[aid] = true
		if _army_locs.has(aid) and _army_locs[aid] != loc and loc != "" and _army_locs[aid] != "":
			var col := Util.color_from(s["countries"][a["owner"]].get("color", "#888"))
			_add("march", 0.7, _prov_pos(_army_locs[aid]), _prov_pos(loc), col)
		_army_locs[aid] = loc
	for aid in _army_locs.keys():
		if not seen.has(aid):
			_army_locs.erase(aid)

func has_active() -> bool:
	return not _fx.is_empty() or _flash > 0.0

## --- drawing ----------------------------------------------------------------------------------------
func _process(delta: float) -> void:
	_clock += delta
	for e in _fx:
		e["t"] += delta
	_fx = _fx.filter(func(e: Dictionary) -> bool: return e["t"] < e["dur"])
	_flash = maxf(0.0, _flash - delta * 3.5)
	if _fx.is_empty() and _flash <= 0.0 and not (_has_selection and Anim.enabled()):
		set_process(false)
	queue_redraw()

func _draw() -> void:
	if mapview == null:
		return
	if _flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(_flash_color, 0.22 * _flash), true)
	if _has_selection and Anim.enabled():
		var c := mapview.world_to_screen(_selected_world)
		var pulse := 0.5 + 0.5 * sin(_clock * 3.0)
		draw_arc(c, 17.0 + pulse * 3.0, 0.0, TAU, 28, Color(UI.GOLD_LIGHT, 0.35 + 0.25 * pulse), 2.0, true)
	for e in _fx:
		var k := float(e["t"]) / float(e["dur"])
		match str(e["kind"]):
			"ring":
				var c := mapview.world_to_screen(e["a"])
				draw_arc(c, 10.0 + 46.0 * k, 0.0, TAU, 32, Color(e["color"], 1.0 - k), 3.0 * (1.0 - k) + 1.0, true)
			"march":
				var p: Vector2 = mapview.world_to_screen((e["a"] as Vector2).lerp(e["b"], ease(k, -2.0)))
				draw_rect(Rect2(p - Vector2(11, 7), Vector2(22, 14)), Color(0.05, 0.04, 0.03, 0.95), true)
				draw_rect(Rect2(p - Vector2(9, 5), Vector2(18, 10)), e["color"], true)
				var tail: Vector2 = mapview.world_to_screen(e["a"])
				draw_line(tail, p, Color(e["color"], 0.45 * (1.0 - k)), 2.0, true)
			"clash":
				_draw_clash(mapview.world_to_screen(e["a"]), k, e["color"])
			"banner":
				_draw_banner(k, str(e["text"]), e["color"])

func _draw_clash(c: Vector2, k: float, col: Color) -> void:
	var a := 1.0 - k
	for i in 8:
		var ang := float(i) * TAU / 8.0 + k * 0.6
		var r0 := 8.0 + 30.0 * k
		draw_line(c + Vector2(cos(ang), sin(ang)) * r0, c + Vector2(cos(ang), sin(ang)) * (r0 + 12.0 * a), Color(col, a), 3.0, true)
	var s := 16.0 * (1.0 - absf(k * 2.0 - 1.0) * 0.4)
	draw_line(c + Vector2(-s, -s), c + Vector2(s, s), Color(1, 1, 1, a), 4.0, true)
	draw_line(c + Vector2(s, -s), c + Vector2(-s, s), Color(1, 1, 1, a), 4.0, true)

func _draw_banner(k: float, text: String, col: Color) -> void:
	var a := sin(clampf(k, 0.0, 1.0) * PI)
	a = clampf(a * 2.0, 0.0, 1.0)
	var h := 76.0
	var y := size.y * 0.36
	var x_off := (k - 0.5) * 60.0
	draw_rect(Rect2(0, y, size.x, h), Color(0.04, 0.07, 0.15, 0.82 * a), true)
	draw_rect(Rect2(0, y, size.x, 2), Color(col, a), true)
	draw_rect(Rect2(0, y + h - 2, size.x, 2), Color(col, a), true)
	var f := UI.font("title")
	var fs := UI.fs(40)
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(f, Vector2((size.x - w) * 0.5 + x_off, y + h * 0.5 + fs * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(col, a))
