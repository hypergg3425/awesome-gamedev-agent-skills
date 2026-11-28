class_name GestureLayer
extends Control
## Touch/mouse input for the world map: one-finger pan with inertia, two-finger pinch + drag, tap to select, long-press
## for a contextual popup, mouse wheel / trackpad zoom. It sits directly above the MapView (below all UI chrome) so
## controls consume their own touches first and the map never reacts to a press that started on a button or panel.
## MapView's own handler is switched off (`interaction_enabled = false`); this layer drives the camera through its public
## API and publishes its own signals.

signal province_tapped(pid: String)
signal empty_tapped()
signal long_pressed(kind: String, pid: String, screen_pos: Vector2)
signal gesture_started()

const LONG_PRESS_SEC := 0.5
const FEEDBACK_DELAY := 0.14
const TAP_SLOP := 12.0
const MARKER_RADIUS := 26.0

var mapview: MapView
var enabled := true
var touches: Dictionary = {}        # finger index -> screen position
var press_pos := Vector2.ZERO
var press_t := 0.0
var moved := false
var long_fired := false
var pinching := false
var pinch_dist := 0.0
var _vel := Vector2.ZERO
var _ring_alpha := 0.0

static func attach(view: MapView, parent: Control) -> GestureLayer:
	var g := GestureLayer.new()
	g.mapview = view
	view.interaction_enabled = false
	parent.add_child(g)
	return g

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE

func _gui_input(event: InputEvent) -> void:
	if not enabled or mapview == null:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			mapview.zoom_at(_to_map(mb.position), 1.18)
			accept_event()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			mapview.zoom_at(_to_map(mb.position), 1.0 / 1.18)
			accept_event()
	elif event is InputEventMagnifyGesture:
		mapview.zoom_at(_to_map((event as InputEventMagnifyGesture).position), (event as InputEventMagnifyGesture).factor)
		accept_event()
	elif event is InputEventPanGesture:
		mapview.center += (event as InputEventPanGesture).delta * 8.0 / mapview.zoom
		mapview._apply_camera()
		accept_event()
	elif event is InputEventScreenTouch:
		_touch(event as InputEventScreenTouch)
		accept_event()
	elif event is InputEventScreenDrag:
		_drag(event as InputEventScreenDrag)
		accept_event()

## Position inside the MapView (identical to this layer's local space unless the view is offset).
func _to_map(p: Vector2) -> Vector2:
	return p - (mapview.global_position - global_position)

func _touch(st: InputEventScreenTouch) -> void:
	if st.pressed:
		touches[st.index] = st.position
		if touches.size() == 1:
			press_pos = st.position
			press_t = Time.get_ticks_msec() / 1000.0
			moved = false
			long_fired = false
			pinching = false
			_vel = Vector2.ZERO
			mapview.velocity = Vector2.ZERO
			if mapview.focus_tween:
				mapview.focus_tween.kill()
			gesture_started.emit()
		elif touches.size() == 2:
			pinching = true
			moved = true
			var ks := touches.keys()
			pinch_dist = (touches[ks[0]] as Vector2).distance_to(touches[ks[1]])
		set_process(true)
	else:
		var was_single := touches.size() == 1 and not pinching
		touches.erase(st.index)
		if was_single and not moved and not long_fired:
			var pid := mapview.province_id_at_screen(_to_map(st.position))
			if pid == "":
				empty_tapped.emit()
			else:
				province_tapped.emit(pid)
		elif was_single and moved:
			mapview.velocity = _vel
		if touches.size() == 1:
			press_pos = touches.values()[0]
			pinching = false
		if touches.is_empty():
			pinching = false
			_ring_alpha = 0.0
			queue_redraw()

func _drag(sd: InputEventScreenDrag) -> void:
	if not touches.has(sd.index):
		return
	touches[sd.index] = sd.position
	if touches.size() >= 2:
		var ks := touches.keys()
		var a: Vector2 = touches[ks[0]]
		var b: Vector2 = touches[ks[1]]
		var d := a.distance_to(b)
		if pinch_dist > 1.0 and d > 1.0:
			mapview.zoom_at(_to_map((a + b) * 0.5), d / pinch_dist)
		pinch_dist = d
		mapview.center -= sd.relative * 0.5 / mapview.zoom
		mapview._apply_camera()
		return
	if not moved and sd.position.distance_to(press_pos) > TAP_SLOP:
		moved = true
		_ring_alpha = 0.0
		queue_redraw()
	if moved:
		mapview.center -= sd.relative / mapview.zoom
		_vel = _vel.lerp(sd.relative / mapview.zoom, 0.5)
		mapview._apply_camera()

func _process(_delta: float) -> void:
	if touches.size() != 1 or moved or long_fired or pinching:
		if _ring_alpha != 0.0:
			_ring_alpha = 0.0
			queue_redraw()
		if touches.is_empty():
			set_process(false)
		return
	var held := Time.get_ticks_msec() / 1000.0 - press_t
	if held >= LONG_PRESS_SEC:
		long_fired = true
		_ring_alpha = 0.0
		queue_redraw()
		var mp := _to_map(press_pos)
		var kind := "province"
		var pid := _marker_province_at(mp)
		if pid != "":
			kind = "army"
		else:
			pid = mapview.province_id_at_screen(mp)
		if pid != "":
			long_pressed.emit(kind, pid, press_pos)
		else:
			empty_tapped.emit()
	elif held >= FEEDBACK_DELAY and Anim.enabled():
		_ring_alpha = 1.0
		queue_redraw()

## Army marker (screen-space shield from the map overlay) under a map position -> its province id.
func _marker_province_at(mp: Vector2) -> String:
	if mapview.overlay == null:
		return ""
	var best := MARKER_RADIUS
	var found := ""
	for m in mapview.overlay.data.get("markers", []):
		var sp := mapview.world_to_screen(m["pos"])
		var d := sp.distance_to(mp)
		if d < best:
			var i := mapview.province_at_world(m["pos"])
			if i >= 0:
				best = d
				found = String(Defs.province_ids[i])
	return found

## Press-and-hold progress ring (feedback that a long press is being recognised).
func _draw() -> void:
	if _ring_alpha <= 0.0 or touches.size() != 1:
		return
	var held := Time.get_ticks_msec() / 1000.0 - press_t
	var t := clampf((held - FEEDBACK_DELAY) / (LONG_PRESS_SEC - FEEDBACK_DELAY), 0.0, 1.0)
	draw_arc(press_pos, 30.0, -PI * 0.5, -PI * 0.5 + TAU * t, 32, Color(UI.GOLD_LIGHT, 0.95), 4.0, true)
	draw_arc(press_pos, 30.0, 0.0, TAU, 32, Color(0, 0, 0, 0.25), 2.0, true)
