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

## --- placement / highlight -----------------------------------------------------------------------------------
func _focus_rect(focus: String) -> Rect2:
	match focus:
		"hud":
			return screen.hud.get_global_rect()
		"province":
			return screen.province_panel.get_global_rect() if screen.province_panel.visible else Rect2()
		"end":
			return screen.end_btn.get_global_rect()
		"menu":
			return screen.hud_box.get_child(screen.hud_box.get_child_count() - 1).get_global_rect()
	if focus.begins_with("tool:"):
		var i := int(focus.substr(5))
		if i < screen.toolbar.get_child_count():
			return (screen.toolbar.get_child(i) as Control).get_global_rect()
	return Rect2()

func _place() -> void:
	if not is_inside_tree():
		return
	var vp := get_viewport().get_visible_rect().size
	var ins := UI.safe_insets(get_viewport())
	var w := minf(520.0, vp.x * 0.46)
	custom_minimum_size = Vector2(w, 0)
	size = Vector2(w, 10)
	var h := size.y
	# bottom-centre-left: clear of the toolbar (left), province panel (right) and the End-turn button
	var bottom := vp.y - float(ins["bottom"]) - Ads.reserved_height() - 12.0
	position = Vector2(clampf(86.0 + float(ins["left"]), 0.0, maxf(0.0, vp.x - w)), maxf(8.0, bottom - h))
	var r := _focus_rect(str(STEPS[step]["focus"]))
	_ring.visible = r.size.x > 4.0
	if _ring.visible:
		_ring.position = r.position - Vector2(4, 4)
		_ring.size = r.size + Vector2(8, 8)
		var pulse := 0.65 + 0.35 * sin(float(Time.get_ticks_msec()) / 260.0)
		_ring.modulate = Color(1, 1, 1, pulse if bool(Settings.get_value("animations")) else 1.0)
