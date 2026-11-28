class_name MenuBackground
extends Control
## Atmospheric full-screen background for the menus: key illustration with a slow "breathing" zoom, two drifting cloud
## bands, rising embers and a legibility gradient on the text side. All motion stops when Settings "animations" is off
## (the node then renders a static frame and does not process).

const ART := "res://assets/backgrounds/menu_twilight.png"
const CLOUDS := "res://assets/backgrounds/menu_clouds.png"
const EMBERS := 46

var _art: TextureRect
var _clouds: Array = []
var _embers: Array = []             # {p: Vector2 (0..1), v: float, s: float, ph: float, a: float}
var _t := 0.0
var _dim := 0.0

static func attach(host: Control, art_path: String = ART, dim: float = 0.0, with_embers: bool = true) -> MenuBackground:
	var b := MenuBackground.new()
	b._dim = dim
	b._build(art_path, with_embers)
	host.add_child(b)
	host.move_child(b, 0)
	return b

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true

func _build(art_path: String, with_embers: bool) -> void:
	_art = TextureRect.new()
	if ResourceLoader.exists(art_path):
		_art.texture = load(art_path)
	_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_art)
	if with_embers and ResourceLoader.exists(CLOUDS):
		var tex: Texture2D = load(CLOUDS)
		for i in 2:
			var c := TextureRect.new()
			c.texture = tex
			c.stretch_mode = TextureRect.STRETCH_TILE
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE
			c.modulate = Color(1, 1, 1, 0.26 - 0.1 * i)
			c.set_anchors_preset(Control.PRESET_TOP_WIDE)
			add_child(c)
			_clouds.append(c)
	# legibility gradient: dark navy on the left (menu column) fading to transparent
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(0.03, 0.05, 0.11, 0.86), Color(0.03, 0.05, 0.11, 0.55), Color(0.03, 0.05, 0.11, 0.0)])
	g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0.5)
	gt.fill_to = Vector2(1, 0.5)
	gt.width = 256
	gt.height = 8
	var shade := TextureRect.new()
	shade.texture = gt
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	if _dim > 0.0:
		var d := ColorRect.new()
		d.color = Color(0.03, 0.05, 0.1, _dim)
		d.set_anchors_preset(Control.PRESET_FULL_RECT)
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(d)
	if with_embers:
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for i in EMBERS:
			_embers.append({"p": Vector2(rng.randf(), rng.randf()), "v": rng.randf_range(0.015, 0.05), "s": rng.randf_range(1.0, 2.6), "ph": rng.randf() * TAU, "a": rng.randf_range(0.35, 0.9)})
	set_process(Anim.enabled() and with_embers)
	if Anim.enabled():
		_art.pivot_offset = Vector2(960, 540)
		var tw := _art.create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(_art, "scale", Vector2(1.05, 1.05), 24.0)
		tw.tween_property(_art, "scale", Vector2.ONE, 24.0)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _art != null:
		_art.pivot_offset = size * 0.5
		var band := minf(size.y * 0.3, 256.0)
		for i in _clouds.size():
			var c: TextureRect = _clouds[i]
			c.offset_top = size.y * (0.12 + 0.17 * i)
			c.offset_bottom = c.offset_top + band
			c.offset_left = 0
			c.offset_right = 0
		queue_redraw()

func _process(delta: float) -> void:
	_t += delta
	for i in _clouds.size():
		var c: TextureRect = _clouds[i]
		c.pivot_offset = Vector2.ZERO
		# scroll by shifting the tiled region: move the node left and wrap by the texture width
		var w := float(c.texture.get_width()) * (c.size.y / float(c.texture.get_height()))
		c.position.x = -fmod(_t * (9.0 + 7.0 * i), maxf(w, 1.0))
		c.size.x = size.x + w
	for e in _embers:
		var p: Vector2 = e["p"]
		p.y -= float(e["v"]) * delta
		if p.y < -0.02:
			p = Vector2(randf(), 1.02)
		e["p"] = p
	queue_redraw()

func _draw() -> void:
	if _embers.is_empty():
		return
	for e in _embers:
		var p: Vector2 = e["p"]
		var sway := sin(_t * 0.7 + float(e["ph"])) * 12.0
		var pos := Vector2(p.x * size.x + sway, p.y * size.y)
		var fade := clampf(p.y * 1.6, 0.0, 1.0) * float(e["a"]) * (0.6 + 0.4 * sin(_t * 2.0 + float(e["ph"])))
		draw_circle(pos, float(e["s"]), Color(0.98, 0.72, 0.32, fade))
		draw_circle(pos, float(e["s"]) * 2.4, Color(0.95, 0.5, 0.2, fade * 0.18))
