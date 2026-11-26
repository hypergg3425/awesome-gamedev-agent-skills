class_name Tutorial
extends PanelContainer
## Interactive first-campaign tutorial. A coach card with a pulsing highlight guides the player through twelve
## steps. Steps with a `done` condition advance automatically when the player really does the thing (the condition
## is read from the live game state), otherwise by the Next button. Skippable at any time; replayable from
## Settings or the pause menu. Completion/skip is stored in Settings.tutorial_done.

var screen: CampaignScreen
var step := 0
var _title: Label
var _body: Label
var _step_lbl: Label
var _hint: Label
var _next: Button
var _ring: Panel
var _timer: Timer
var _base_queue := 0
var _base_turn := 0

## Each step: id (string key part), focus (what to highlight) and an optional condition id.
const STEPS: Array = [
	{"id": "S1", "focus": "map", "cond": ""},
	{"id": "S2", "focus": "hud", "cond": ""},
	{"id": "S3", "focus": "map", "cond": "province_selected"},
	{"id": "S4", "focus": "province", "cond": "queue_grew"},
	{"id": "S5", "focus": "tool:0", "cond": "sheet:economy"},
	{"id": "S6", "focus": "tool:1", "cond": "sheet:military"},
	{"id": "S7", "focus": "map", "cond": "army_moving"},
	{"id": "S8", "focus": "", "cond": ""},
	{"id": "S9", "focus": "tool:2", "cond": "sheet:diplomacy"},
	{"id": "S10", "focus": "tool:3", "cond": "sheet:technology"},
	{"id": "S11", "focus": "end", "cond": "turn_passed"},
	{"id": "S12", "focus": "menu", "cond": ""},
]

static func should_start() -> bool:
	return not bool(Settings.get_value("tutorial_done")) and Game.has_state() and int(Game.state["turn"]) <= 2 and Game.state["players"].size() == 1

static func start(host: CampaignScreen, force: bool = false) -> void:
	if not force and not should_start():
		return
	var t := Tutorial.new(host)
	host.overlay_layer.get_parent().add_child(t)   # above sheets, below dialogs in overlay_layer

func _init(p_screen: CampaignScreen = null) -> void:
	screen = p_screen
	theme_type_variation = "Sheet"
	mouse_filter = Control.MOUSE_FILTER_STOP
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	add_child(v)
	var top := HBoxContainer.new()
	_step_lbl = UI.label("", "Tiny")
	_step_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_step_lbl)
	top.add_child(UI.button(Loc.t("TUT_SKIP"), func() -> void: finish(true), "Tab"))
	v.add_child(top)
	_title = UI.label("", "Sub")
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_title)
	_body = UI.label("", "Small", -1, true)
	v.add_child(_body)
	_hint = UI.label("", "Tiny", -1, true)
	v.add_child(_hint)
	_next = UI.button(Loc.t("TUT_NEXT"), func() -> void: advance(), "Primary", "next")
	_next.custom_minimum_size = Vector2(0, 44)
	v.add_child(_next)

func _ready() -> void:
	_ring = Panel.new()
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = Color("e6c46a")
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(8)
	_ring.add_theme_stylebox_override("panel", sb)
	get_parent().add_child(_ring)
	_timer = Timer.new()
	_timer.wait_time = 0.35
	_timer.timeout.connect(_poll)
	add_child(_timer)
	_timer.start()
	_base_turn = int(Game.state["turn"])
	_base_queue = _queue_total()
	Loc.language_changed.connect(func(_l: String) -> void: _show_step())
	get_viewport().size_changed.connect(_place)
	_show_step()

func _exit_tree() -> void:
	if _ring != null and is_instance_valid(_ring):
		_ring.queue_free()

## --- flow --------------------------------------------------------------------------------------------------
func _show_step() -> void:
	var st: Dictionary = STEPS[step]
	_step_lbl.text = Loc.tf("TUT_STEP", {"n": step + 1, "total": STEPS.size()})
	_title.text = Loc.t("TUT_%s_T" % st["id"])
	_body.text = Loc.t("TUT_%s_B" % st["id"])
	var waiting: bool = str(st["cond"]) != ""
	_hint.text = Loc.t("TUT_HINT_WAIT") if waiting else ""
	_next.text = Loc.t("TUT_DONE_BTN") if step == STEPS.size() - 1 else Loc.t("TUT_NEXT")
	_base_queue = _queue_total()
	_base_turn = int(Game.state["turn"])
	# a sheet left open by the previous step would hide the map / buttons this step talks about
	if screen.open_sheet_name != "" and not str(st["cond"]).begins_with("sheet:"):
		screen.close_sheets()
	call_deferred("_place")

func advance() -> void:
	if step >= STEPS.size() - 1:
		finish(false)
		return
	step += 1
	_show_step()

func finish(_skipped: bool) -> void:
	Settings.set_value("tutorial_done", true)
	queue_free()

func _poll() -> void:
	if not Game.has_state():
		return
	if _condition_met(str(STEPS[step]["cond"])):
		advance()
	else:
		_place()

func _queue_total() -> int:
	var n := 0
	var me: String = Game.active_player
	for pid in GS.owned(Game.state, me):
		n += (Game.state["provinces"][pid]["queue"] as Array).size()
	return n

func _condition_met(cond: String) -> bool:
	if cond == "":
		return false
	if cond == "province_selected":
		return Game.selected_province != ""
	if cond == "queue_grew":
		return _queue_total() > _base_queue
	if cond.begins_with("sheet:"):
		return screen.open_sheet_name == cond.substr(6)
	if cond == "army_moving":
		for aid in GS.armies_of(Game.state, Game.active_player):
			if not (Game.state["armies"][aid]["path"] as Array).is_empty():
				return true
		return false
	if cond == "turn_passed":
		return int(Game.state["turn"]) > _base_turn
	return false

## Compact (phone) variant: smaller type, Skip inline with the step counter, shorter buttons.
func _apply_density(compact: bool) -> void:
	_body.theme_type_variation = "Tiny" if compact else "Small"
	_title.theme_type_variation = "Small" if compact else "Sub"
	_next.custom_minimum_size = Vector2(0, 44 if compact else 48)
	_hint.visible = not compact and _hint.text != ""

## --- placement / highlight -----------------------------------------------------------------------------------
func _vis_rect(c: Control) -> Rect2:
	return c.get_global_rect() if c != null and c.is_visible_in_tree() else Rect2()

func _focus_rect(focus: String) -> Rect2:
	match focus:
		"hud":
			return _vis_rect(screen.hud)
		"province":
			return _vis_rect(screen.province_panel)
		"end":
			return _vis_rect(screen.end_btn)
		"menu":
			return _vis_rect(screen.hud.refs["menu_btn"])
	if focus.begins_with("tool:"):
		var i := int(focus.substr(5))
		if i < screen.toolbar.get_child_count():
			return _vis_rect(screen.toolbar.get_child(i) as Control)
	return Rect2()

## Rectangles the coach card should avoid covering (besides the highlighted target, which it must never cover).
func _avoid_rects() -> Array:
	var out: Array = []
	for c in [screen.hud, screen.toolbar, screen.end_btn, screen.province_panel, screen.mode_strip, screen.move_bar]:
		var r := _vis_rect(c)
		if r.size.x > 0.0:
			out.append(r)
	if screen.open_sheet_name != "":
		out.append(_vis_rect(screen.sheets[screen.open_sheet_name]))
	return out

static func _overlap(a: Rect2, b: Rect2) -> float:
	var i := a.intersection(b)
	return maxf(i.size.x, 0.0) * maxf(i.size.y, 0.0)

## Picks the position of a card of `card` size inside `area` that never overlaps `focus` and covers the least of
## `avoid` (scanned on a coarse grid, ties broken toward the bottom-left where the thumb rests).
static func choose_rect(card: Vector2, area: Rect2, focus: Rect2, avoid: Array) -> Rect2:
	var best := Rect2(area.position, card)
	var best_cost := INF
	var step := 16.0
	var y := area.end.y - card.y
	while y >= area.position.y - 0.01:
		var x := area.position.x
		while x + card.x <= area.end.x + 0.01:
			var r := Rect2(Vector2(x, y), card)
			var cost := 0.0
			if focus.size.x > 0.0:
				cost += _overlap(r, focus.grow(10.0)) * 1000.0
			for a in avoid:
				cost += _overlap(r, a)
			cost += (area.end.y - r.end.y) * 0.5 + (r.position.x - area.position.x) * 0.1
			if cost < best_cost:
				best_cost = cost
				best = r
			x += step
		y -= step
	return best

var _sig := ""
var _target := Rect2()

func _place() -> void:
	if not is_inside_tree():
		return
	var vp := get_viewport().get_visible_rect().size
	var ins := UI.safe_insets(get_viewport())
	var area := Rect2(float(ins["left"]) + 8.0, float(ins["top"]) + 8.0, vp.x - float(ins["left"]) - float(ins["right"]) - 16.0,
			vp.y - float(ins["top"]) - float(ins["bottom"]) - Ads.reserved_height() - 16.0)
	_apply_density(Layout.compact(vp))
	var w := minf(500.0, area.size.x * 0.5 if area.size.x > 700.0 else area.size.x - 8.0)
	custom_minimum_size = Vector2(w, 0)
	size = Vector2(w, 10)
	var h := minf(size.y, area.size.y)
	var focus := _focus_rect(str(STEPS[step]["focus"]))
	var avoid := _avoid_rects()
	var sig := "%s|%s|%s|%s|%s" % [step, str(focus), str(area), str(Vector2(w, h)), str(avoid)]
	if sig != _sig:
		_sig = sig
		var r := choose_rect(Vector2(w, h), area, focus, avoid)
		position = r.position
		size = r.size
	_target = focus
	_ring.visible = focus.size.x > 4.0
	if _ring.visible:
		_ring.position = focus.position - Vector2(4, 4)
		_ring.size = focus.size + Vector2(8, 8)

func _process(_delta: float) -> void:
	if _ring != null and _ring.visible:
		var pulse := 0.65 + 0.35 * sin(float(Time.get_ticks_msec()) / 260.0)
		_ring.modulate = Color(1, 1, 1, pulse if bool(Settings.get_value("animations")) else 1.0)
