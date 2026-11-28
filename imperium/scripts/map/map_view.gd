class_name MapView
extends Control
## Interactive 2D world map: pan, pinch/wheel zoom, province hit-testing, colour layers.
## Rendering: one static ArrayMesh for all provinces; colours are fed through a data texture.

signal province_tapped(pid: String)
signal province_long_pressed(pid: String)
signal empty_tapped()
signal view_changed()

const TAP_MOVE_PX := 14.0
const LONG_PRESS_MS := 550
const GRID := 40.0
const COAST_CHUNK := 600.0

var geometry: MapGeometry
var world: Node2D
var overlay: Control
var province_mesh: MeshInstance2D
var land_mesh: MeshInstance2D
var lake_mesh: MeshInstance2D
var border_layer: Node2D
var water_layer: Node2D
var feature_layer: Node2D
var relief_layer: Node2D
var ocean_mat: ShaderMaterial
var relief: PackedFloat32Array = PackedFloat32Array()
var color_img: Image
var color_tex: ImageTexture
var n_prov := 0
var bounds := Rect2(0, 0, 3600, 1400)
var zoom := 1.0
var center := Vector2(1800, 600)
var min_zoom := 0.3
var max_zoom := 14.0
var grid: Dictionary = {}         # Vector2i -> Array[int]
var prov_bbox: Array = []          # Rect2 per province
var prov_center: Array = []        # Vector2 per province (label point)
var prov_polys: Array = []
var interaction_enabled := true

# colour layers
var base_colors: PackedColorArray
var hi_colors: PackedColorArray

# touch state
var touches: Dictionary = {}
var press_start := Vector2.ZERO
var press_time := 0
var press_moved := false
var pinch_dist := 0.0
var velocity := Vector2.ZERO
var _lp_fired := false
var focus_tween: Tween

# border data prepared by set_border_segments()
var seg_province: PackedVector2Array = PackedVector2Array()
var seg_country: PackedVector2Array = PackedVector2Array()
var seg_coast: PackedVector2Array = PackedVector2Array()
var seg_front: PackedVector2Array = PackedVector2Array()
var border_colors := {"province": Color(0.12, 0.1, 0.08, 0.35), "country": Color(0.08, 0.06, 0.05, 0.95),
	"coast": Color(0.05, 0.1, 0.16, 0.9), "front": Color(0.85, 0.15, 0.1, 0.95)}
var _last_border_zoom_tier := -99
var _shader_zoom := -1.0

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE

## Build meshes from geometry. Call once.
func setup(geom: MapGeometry, meta: Dictionary) -> void:
	geometry = geom
	n_prov = geom.polys.size()
	var b: Array = meta.get("bounds", [0, 0, 3600, 1400])
	bounds = Rect2(b[0], b[1], b[2] - b[0], b[3] - b[1])
	world = Node2D.new()
	add_child(world)
	_build_ocean()
	water_layer = Node2D.new()
	water_layer.set_script(preload("res://scripts/map/water_layer.gd"))
	water_layer.view = self
	world.add_child(water_layer)
	land_mesh = _mesh_from_polys(geom.land, Color(0.30, 0.28, 0.24), -1)
	world.add_child(land_mesh)
	_build_province_mesh()
	lake_mesh = _mesh_from_polys(geom.lakes, Color(0.10, 0.22, 0.33), -1)
	world.add_child(lake_mesh)
	relief_layer = Node2D.new()
	relief_layer.set_script(preload("res://scripts/map/relief_layer.gd"))
	relief_layer.view = self
	relief_layer.visible = false
	world.add_child(relief_layer)
	border_layer = Node2D.new()
	border_layer.set_script(preload("res://scripts/map/border_layer.gd"))
	border_layer.view = self
	world.add_child(border_layer)
	_build_coasts(geom)
	feature_layer = Node2D.new()
	feature_layer.set_script(preload("res://scripts/map/feature_layer.gd"))
	feature_layer.view = self
	world.add_child(feature_layer)
	overlay = Control.new()
	overlay.set_script(preload("res://scripts/map/map_overlay.gd"))
	overlay.view = self
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	_build_grid()
	feature_layer.build(geom)
	_compute_relief()
	Settings.changed.connect(_on_setting_changed)
	_apply_animation_setting()
	base_colors.resize(n_prov)
	hi_colors.resize(n_prov)
	for i in n_prov:
		base_colors[i] = Color(0.5, 0.5, 0.5)
		hi_colors[i] = Color(0, 0, 0, 0)
	_push_colors()
	fit_world()

func _grain_texture() -> NoiseTexture2D:
	var nt := NoiseTexture2D.new()
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.04
	noise.fractal_octaves = 3
	nt.noise = noise
	nt.width = 256
	nt.height = 256
	nt.seamless = true
	return nt

func _build_ocean() -> void:
	var rect := Polygon2D.new()
	var pad := 600.0
	rect.polygon = PackedVector2Array([bounds.position - Vector2(pad, pad), Vector2(bounds.end.x + pad, bounds.position.y - pad),
		bounds.end + Vector2(pad, pad), Vector2(bounds.position.x - pad, bounds.end.y + pad)])
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/ocean.gdshader")
	mat.set_shader_parameter("grain", _grain_texture())
	rect.material = mat
	ocean_mat = mat
	world.add_child(rect)

func _on_setting_changed(key: String) -> void:
	if key == "animations":
		_apply_animation_setting()

func _apply_animation_setting() -> void:
	if ocean_mat:
		ocean_mat.set_shader_parameter("animate", 1.0 if bool(Settings.get_value("animations")) else 0.0)

## Coast polylines of every province grouped in chunks (culling): full detail for zoom >= 1, a decimated and smoothed
## (Chaikin) copy for the world view. Water bands go under the land, the shoreline over the provinces.
func _build_coasts(geom: MapGeometry) -> void:
	var chunks := {}
	for lines in geom.coasts:
		for l in lines:
			var v: PackedVector2Array = l
			if v.size() < 2:
				continue
			var key := Vector2i(int(floor(v[0].x / COAST_CHUNK)), int(floor(v[0].y / COAST_CHUNK)))
			if not chunks.has(key):
				chunks[key] = {"hi": [], "lo": []}
			(chunks[key]["hi"] as Array).append(v)
			(chunks[key]["lo"] as Array).append(MapLines.chaikin(MapLines.decimate(v, 3)))
	water_layer.add_chunks(chunks)
	border_layer.add_coast_outline(chunks)

## Relief amplitude per province for the hillshade (0 flat .. 1 alpine), from terrain and mountain cover.
func _compute_relief() -> void:
	relief.resize(n_prov)
	var by_terrain := {"mountains": 0.9, "hills": 0.55, "arctic": 0.3, "forest": 0.2, "jungle": 0.2, "desert": 0.18, "marsh": 0.06}
	for i in n_prov:
		var pd: Dictionary = Defs.provinces[Defs.province_ids[i]]
		relief[i] = clampf(float(by_terrain.get(pd["terrain"], 0.1)) + 0.5 * float(pd.get("mountain_cover", 0.0)), 0.05, 1.0)

func _mesh_from_polys(polys: Array, col: Color, uv_index: int) -> MeshInstance2D:
	var verts := PackedVector2Array()
	var idx := PackedInt32Array()
	for p in polys:
		var base := verts.size()
		verts.append_array(p["v"])
		for t in (p["i"] as PackedInt32Array):
			idx.append(base + t)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_INDEX] = idx
	var cols := PackedColorArray()
	cols.resize(verts.size())
	cols.fill(col)
	arr[Mesh.ARRAY_COLOR] = cols
	var mesh := ArrayMesh.new()
	if verts.size() > 0:
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance2D.new()
	mi.mesh = mesh
	return mi

func _build_province_mesh() -> void:
	var verts := PackedVector2Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	for pi in n_prov:
		var u := Vector2((pi + 0.5) / float(n_prov), 0.5)
		for p in geometry.polys[pi]:
			var base := verts.size()
			var v: PackedVector2Array = p["v"]
			verts.append_array(v)
			for k in v.size():
				uvs.append(u)
			for t in (p["i"] as PackedInt32Array):
				idx.append(base + t)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	province_mesh = MeshInstance2D.new()
	province_mesh.mesh = mesh
	color_img = Image.create(n_prov, 3, false, Image.FORMAT_RGBA8)
	color_tex = ImageTexture.create_from_image(color_img)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/province_fill.gdshader")
	mat.set_shader_parameter("colors", color_tex)
	mat.set_shader_parameter("grain", _grain_texture())
	province_mesh.material = mat
	world.add_child(province_mesh)

func _build_grid() -> void:
	prov_bbox.resize(n_prov)
	prov_center.resize(n_prov)
	prov_polys.resize(n_prov)
	for pi in n_prov:
		var r := Rect2()
		var first := true
		var plist: Array = []
		for p in geometry.polys[pi]:
			var v: PackedVector2Array = p["v"]
			var pr := Rect2(v[0], Vector2.ZERO)
			for q in v:
				pr = pr.expand(q)
			r = pr if first else r.merge(pr)
			first = false
			plist.append({"v": v, "r": pr})
		prov_bbox[pi] = r
		prov_polys[pi] = plist
		prov_center[pi] = r.get_center()
		for pp in plist:
			var rr: Rect2 = pp["r"]
			var x0 := int(floor(rr.position.x / GRID))
			var x1 := int(floor(rr.end.x / GRID))
			var y0 := int(floor(rr.position.y / GRID))
			var y1 := int(floor(rr.end.y / GRID))
			for gx in range(x0, x1 + 1):
				for gy in range(y0, y1 + 1):
					var key := Vector2i(gx, gy)
					if not grid.has(key):
						grid[key] = []
					if not (grid[key] as Array).has(pi):
						(grid[key] as Array).append(pi)

func set_label_points(points: Array) -> void:
	for i in mini(points.size(), n_prov):
		prov_center[i] = points[i]

## --- colours ---------------------------------------------------------------------------------
func set_base_color(i: int, c: Color) -> void:
	base_colors[i] = c

func set_hi_color(i: int, c: Color) -> void:
	hi_colors[i] = c

func clear_highlights() -> void:
	hi_colors.fill(Color(0, 0, 0, 0))

func _push_colors() -> void:
	for i in n_prov:
		var b := base_colors[i]
		color_img.set_pixel(i, 0, Color(b.r, b.g, b.b, 1.0))
		color_img.set_pixel(i, 1, hi_colors[i])
		color_img.set_pixel(i, 2, Color(relief[i], 0.0, 0.0, 1.0))
	color_tex.update(color_img)

func push_colors() -> void:
	_push_colors()

## --- borders ---------------------------------------------------------------------------------
func set_border_segments(province: PackedVector2Array, country: PackedVector2Array, coast: PackedVector2Array,
		front: PackedVector2Array = PackedVector2Array()) -> void:
	seg_province = province
	seg_country = country
	seg_coast = coast
	seg_front = front
	border_layer.queue_redraw()

## --- camera ----------------------------------------------------------------------------------
func fit_world() -> void:
	var s := size
	if s.x < 10:
		s = Vector2(1280, 720)
	min_zoom = maxf(s.x / (bounds.size.x * 1.05), s.y / (bounds.size.y * 1.05)) * 0.9
	zoom = min_zoom * 1.0
	center = bounds.get_center()
	_apply_camera()

func _apply_camera() -> void:
	zoom = clampf(zoom, min_zoom, max_zoom)
	var half := size / (2.0 * zoom)
	var lo := bounds.position + half * 0.6
	var hi := bounds.end - half * 0.6
	if lo.x > hi.x:
		center.x = bounds.get_center().x
	else:
		center.x = clampf(center.x, lo.x, hi.x)
	if lo.y > hi.y:
		center.y = bounds.get_center().y
	else:
		center.y = clampf(center.y, lo.y, hi.y)
	if world:
		world.scale = Vector2(zoom, zoom)
		world.position = size * 0.5 - center * zoom
	if overlay:
		overlay.queue_redraw()
	var tier := int(floor(log(zoom) / log(1.35)))
	if tier != _last_border_zoom_tier:
		_last_border_zoom_tier = tier
		_update_zoom_layers()
	if province_mesh and not is_equal_approx(_shader_zoom, zoom):
		_shader_zoom = zoom
		(province_mesh.material as ShaderMaterial).set_shader_parameter("zoom", zoom)
		ocean_mat.set_shader_parameter("zoom", zoom)
	view_changed.emit()

## Layers whose line widths / visibility depend on the zoom tier (redrawn rarely, never per frame).
func _update_zoom_layers() -> void:
	if border_layer == null:
		return
	border_layer.queue_redraw_all()
	water_layer.redraw_chunks()
	feature_layer.queue_redraw()
	var show_relief := MapZoom.show_relief(zoom)
	if show_relief:
		relief_layer.ensure_built()
	relief_layer.visible = show_relief

func world_to_screen(p: Vector2) -> Vector2:
	return (p - center) * zoom + size * 0.5

func screen_to_world(p: Vector2) -> Vector2:
	return (p - size * 0.5) / zoom + center

func zoom_at(screen_pos: Vector2, factor: float) -> void:
	var before := screen_to_world(screen_pos)
	zoom = clampf(zoom * factor, min_zoom, max_zoom)
	center += before - screen_to_world(screen_pos)
	_apply_camera()

func focus_on(world_pos: Vector2, target_zoom: float = -1.0, animate: bool = true) -> void:
	if focus_tween:
		focus_tween.kill()
	var tz := zoom if target_zoom < 0.0 else clampf(target_zoom, min_zoom, max_zoom)
	if not animate or not bool(Settings.get_value("animations")):
		center = world_pos
		zoom = tz
		_apply_camera()
		return
	focus_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	focus_tween.tween_method(func(v: Vector2) -> void:
		center = v
		_apply_camera(), center, world_pos, 0.45)
	focus_tween.tween_method(func(z: float) -> void:
		zoom = z
		_apply_camera(), zoom, tz, 0.45)

func focus_province(pid: String, target_zoom: float = -1.0) -> void:
	var i: int = Defs.province_index.get(pid, -1)
	if i < 0:
		return
	var r: Rect2 = prov_bbox[i]
	var tz := target_zoom
	if tz < 0.0:
		tz = clampf(minf(size.x / maxf(r.size.x * 4.0, 1.0), size.y / maxf(r.size.y * 4.0, 1.0)), min_zoom * 1.5, 5.0)
	focus_on(prov_center[i], tz)

## --- hit testing -----------------------------------------------------------------------------
func province_at_world(p: Vector2) -> int:
	var key := Vector2i(int(floor(p.x / GRID)), int(floor(p.y / GRID)))
	var cands: Array = grid.get(key, [])
	for pi in cands:
		for pp in prov_polys[pi]:
			if (pp["r"] as Rect2).has_point(p) and Geometry2D.is_point_in_polygon(p, pp["v"]):
				return pi
	# tolerance: nearest province within ~8 screen px (covers simplification gaps, tiny islands)
	var tol := 8.0 / zoom
	var best := -1
	var bd := tol
	for gx in range(key.x - 1, key.x + 2):
		for gy in range(key.y - 1, key.y + 2):
			for pi in grid.get(Vector2i(gx, gy), []):
				for pp in prov_polys[pi]:
					var r: Rect2 = (pp["r"] as Rect2).grow(tol)
					if not r.has_point(p):
						continue
					var d := _dist_to_poly(p, pp["v"], bd)
					if d < bd:
						bd = d
						best = pi
	return best

func _dist_to_poly(p: Vector2, v: PackedVector2Array, limit: float) -> float:
	var best := limit
	var n := v.size()
	for k in n:
		var a := v[k]
		var b := v[(k + 1) % n]
		var cp := Geometry2D.get_closest_point_to_segment(p, a, b)
		var d := p.distance_to(cp)
		if d < best:
			best = d
	return best

func province_id_at_screen(sp: Vector2) -> String:
	var i := province_at_world(screen_to_world(sp))
	return "" if i < 0 else String(Defs.province_ids[i])

## --- input -----------------------------------------------------------------------------------
func _gui_input(event: InputEvent) -> void:
	if not interaction_enabled:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			zoom_at(mb.position, 1.18)
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			zoom_at(mb.position, 1.0 / 1.18)
			accept_event()
		return
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			touches[st.index] = st.position
			if touches.size() == 1:
				press_start = st.position
				press_time = Time.get_ticks_msec()
				press_moved = false
				_lp_fired = false
				velocity = Vector2.ZERO
				if focus_tween:
					focus_tween.kill()
			elif touches.size() == 2:
				press_moved = true
				var ks := touches.keys()
				pinch_dist = (touches[ks[0]] as Vector2).distance_to(touches[ks[1]])
		else:
			var was_single := touches.size() == 1
			touches.erase(st.index)
			if was_single and not press_moved and not _lp_fired:
				var pid := province_id_at_screen(st.position)
				if pid == "":
					empty_tapped.emit()
				else:
					province_tapped.emit(pid)
			if touches.size() == 1:
				# continue panning with remaining finger
				var k: int = touches.keys()[0]
				press_start = touches[k]
		accept_event()
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		touches[sd.index] = sd.position
		if touches.size() == 1:
			if not press_moved and sd.position.distance_to(press_start) > TAP_MOVE_PX:
				press_moved = true
			if press_moved:
				center -= sd.relative / zoom
				velocity = sd.relative / zoom
				_apply_camera()
		elif touches.size() >= 2:
			var ks := touches.keys()
			var a: Vector2 = touches[ks[0]]
			var b: Vector2 = touches[ks[1]]
			var d := a.distance_to(b)
			var mid := (a + b) * 0.5
			if pinch_dist > 1.0 and d > 1.0:
				zoom_at(mid, d / pinch_dist)
			pinch_dist = d
			center -= sd.relative * 0.5 / zoom
			_apply_camera()
		accept_event()

func _process(delta: float) -> void:
	if touches.size() == 1 and not press_moved and not _lp_fired:
		if Time.get_ticks_msec() - press_time > LONG_PRESS_MS:
			_lp_fired = true
			var pid := province_id_at_screen(press_start)
			if pid != "":
				province_long_pressed.emit(pid)
	elif touches.is_empty() and velocity.length() > 0.05 / maxf(zoom, 0.01):
		center -= velocity * 1.0
		velocity *= pow(0.0008, delta)
		_apply_camera()
	else:
		velocity = Vector2.ZERO

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and world:
		_apply_camera()
