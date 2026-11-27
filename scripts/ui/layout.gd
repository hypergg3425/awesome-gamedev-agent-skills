class_name Layout
extends RefCounted
## Responsive layout metrics. The project stretches a 1280x720 base viewport with `canvas_items`/`expand`, which on
## small physical windows (phones) shrinks everything. `apply()` compensates through Window.content_scale_factor so
## that one virtual pixel is never smaller than ~0.9 physical pixels on desktop and ~1 dp on touch devices. The UI is
## then laid out from the resulting virtual size using three size classes (COMPACT / MEDIUM / REGULAR).

enum SizeClass { COMPACT, MEDIUM, REGULAR }

const BASE := Vector2(1280.0, 720.0)
const MIN_DESKTOP_SCALE := 0.9
const MIN_TOUCH_DP := 48.0

## Test hooks: force touch metrics (dpi > 0) so desktop runs can exercise the phone code path.
static var override_dpi := 0.0
static var override_mobile := false
static var _installed := false

## Connects the window resize handler once. Call from every entry scene (idempotent).
static func install(window: Window) -> void:
	if _installed:
		return
	_installed = true
	window.size_changed.connect(func() -> void: apply(window))
	apply(window)

static func is_touch_device() -> bool:
	return override_mobile or OS.get_name() in ["Android", "iOS"] or OS.has_feature("mobile")

static func dpi() -> float:
	if override_dpi > 0.0:
		return override_dpi
	var d := float(DisplayServer.screen_get_dpi())
	return d if d > 0.0 else 160.0

## Physical pixels per virtual pixel that the stretch mode alone would produce.
static func base_scale(win: Vector2) -> float:
	return maxf(0.01, minf(win.x / BASE.x, win.y / BASE.y))

## Desired physical pixels per virtual pixel.
static func target_scale(win: Vector2) -> float:
	var sb := base_scale(win)
	if is_touch_device():
		var s := clampf(dpi() / 160.0, MIN_DESKTOP_SCALE, 3.5)
		s = minf(s, win.y / 360.0)      # never fewer than 360 virtual px of height
		s = maxf(s, win.y / 960.0)      # never more than 960
		return s
	return maxf(sb, MIN_DESKTOP_SCALE)

## Applies the content scale factor; returns the virtual size.
static func apply(window: Window) -> Vector2:
	var win := Vector2(window.size)
	if win.x < 2.0 or win.y < 2.0:
		return BASE
	var f := target_scale(win) / base_scale(win)
	f = clampf(f, 0.5, 4.0)
	if absf(window.content_scale_factor - f) > 0.001:
		window.content_scale_factor = f
	return virtual_size(window)

static func virtual_size(window: Window) -> Vector2:
	return window.get_visible_rect().size if window.get_viewport() != null else BASE

static func size_class(vs: Vector2) -> SizeClass:
	if vs.y < 560.0 or vs.x < 980.0:
		return SizeClass.COMPACT
	if vs.y < 700.0 or vs.x < 1200.0:
		return SizeClass.MEDIUM
	return SizeClass.REGULAR

static func compact(vs: Vector2) -> bool:
	return size_class(vs) == SizeClass.COMPACT

## Minimum edge of an interactive control in virtual pixels (>= 48 dp on touch devices, >= 44 px on desktop).
static func touch_min(window: Window = null) -> float:
	if not is_touch_device() or window == null:
		return 44.0
	var win := Vector2(window.size)
	return clampf(MIN_TOUCH_DP * (dpi() / 160.0) / target_scale(win), 44.0, 72.0)

## Usable width of a side panel (province panel, sheets) for a given available width.
static func panel_width(avail_w: float, want: float, min_w: float = 320.0) -> float:
	return clampf(minf(want, avail_w * 0.92), minf(min_w, avail_w), avail_w)
