class_name Anim
extends RefCounted
## Small animation helpers. Every helper honours Settings "animations": when off, the end state is applied at once and
## no tween is created (so there is no per-frame cost and nothing to wait for). Durations are short (<= 0.4 s) so the
## UI never feels slow even on low-end phones; looping effects return their Tween so the owner can kill it.

static func enabled() -> bool:
	return bool(Settings.get_value("animations"))

static func _center_pivot(c: Control) -> void:
	c.pivot_offset = c.size * 0.5

## Fade + slight scale-up. Used for panels, dialogs, toasts.
static func pop_in(c: Control, dur: float = 0.18) -> void:
	if not enabled() or not c.is_inside_tree():
		c.modulate.a = 1.0
		c.scale = Vector2.ONE
		return
	_center_pivot(c)
	c.modulate.a = 0.0
	c.scale = Vector2(0.94, 0.94)
	var tw := c.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "modulate:a", 1.0, dur)
	tw.tween_property(c, "scale", Vector2.ONE, dur)

static func fade_in(c: CanvasItem, dur: float = 0.25) -> void:
	if not enabled() or not c.is_inside_tree():
		c.modulate.a = 1.0
		return
	c.modulate.a = 0.0
	c.create_tween().tween_property(c, "modulate:a", 1.0, dur)

## Fade out then free (or just free when animations are off).
static func fade_free(c: CanvasItem, dur: float = 0.18) -> void:
	if not enabled() or not c.is_inside_tree():
		c.queue_free()
		return
	var tw := c.create_tween()
	tw.tween_property(c, "modulate:a", 0.0, dur)
	tw.tween_callback(c.queue_free)

## Slides a control in from an offset to its current position (call after placing it).
static func slide_in(c: Control, from_offset: Vector2, dur: float = 0.22) -> void:
	if not enabled() or not c.is_inside_tree():
		return
	var target := c.position
	c.position = target + from_offset
	c.modulate.a = 0.0
	var tw := c.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "position", target, dur)
	tw.tween_property(c, "modulate:a", 1.0, dur * 0.8)

## Looping soft pulse of a control's modulate (e.g. End-turn when nothing else is left to do). Returns the Tween or null.
static func pulse(c: CanvasItem, strength: float = 0.18, period: float = 1.2) -> Tween:
	if not enabled() or not c.is_inside_tree():
		return null
	var tw := c.create_tween().set_loops()
	var hi := Color(1.0 + strength, 1.0 + strength * 0.8, 1.0 + strength * 0.4, 1.0)
	tw.tween_property(c, "modulate", hi, period * 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(c, "modulate", Color.WHITE, period * 0.5).set_trans(Tween.TRANS_SINE)
	return tw

static func shake(c: Control, amount: float = 5.0) -> void:
	if not enabled() or not c.is_inside_tree():
		return
	var base := c.position
	var tw := c.create_tween()
	for i in 4:
		tw.tween_property(c, "position", base + Vector2(amount * (1.0 if i % 2 == 0 else -1.0), 0), 0.04)
	tw.tween_property(c, "position", base, 0.04)

## Counts a number label from `from` to `to`.
static func count_to(l: Label, from: float, to: float, formatter: Callable, dur: float = 0.4) -> void:
	if not enabled() or not l.is_inside_tree() or absf(to - from) < 0.5:
		l.text = formatter.call(to)
		return
	var tw := l.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(v: float) -> void: l.text = formatter.call(v), from, to, dur)

## Scale "punch" on a control (selection feedback, button press).
static func punch(c: Control, amount: float = 1.12, dur: float = 0.18) -> void:
	if not enabled() or not c.is_inside_tree():
		return
	_center_pivot(c)
	var tw := c.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "scale", Vector2(amount, amount), dur * 0.4)
	tw.tween_property(c, "scale", Vector2.ONE, dur * 0.6)

## Staggered fade-in for a list of controls (menu entries). Safe inside containers: only modulate is animated.
static func stagger_in(items: Array, step: float = 0.05, dur: float = 0.28) -> void:
	if not enabled():
		return
	var i := 0
	for c in items:
		var ctl := c as Control
		if ctl == null or not ctl.is_inside_tree():
			continue
		ctl.modulate.a = 0.0
		var tw := ctl.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_interval(float(i) * step)
		tw.tween_property(ctl, "modulate:a", 1.0, dur)
		i += 1
