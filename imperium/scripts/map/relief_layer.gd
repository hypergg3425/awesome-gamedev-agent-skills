extends Node2D
## Terrain relief marks (peaks, hills, trees, dunes, reeds) scattered deterministically inside the provinces, in world
## units, grouped in chunks so the renderer culls the off-screen ones. Built lazily the first time the zoom needs them.

const CHUNK := 480.0
const CELL := 13.0
const MAX_PER_PROVINCE := 90
## terrain -> [probability per cell, glyph]
const KIND := {"mountains": [0.95, "peak"], "hills": [0.55, "hill"], "forest": [0.5, "tree"], "jungle": [0.6, "palm"], "marsh": [0.4, "reed"],
	"desert": [0.22, "dune"], "steppe": [0.06, "tuft"], "arctic": [0.18, "peak"]}

var view: MapView
var built := false
var count := 0
var _chunks: Dictionary = {}    # Vector2i -> Node2D chunk

func ensure_built() -> void:
	if built or view == null:
		return
	built = true
	var marks: Dictionary = {}
	for i in view.n_prov:
		var pid: String = Defs.province_ids[i]
		var pd: Dictionary = Defs.provinces[pid]
		var kind: Array = KIND.get(pd["terrain"], [])
		if kind.is_empty():
			continue
		var prob: float = kind[0]
		var cover := float(pd.get("mountain_cover", 0.0))
		if pd["terrain"] != "mountains" and cover > 0.3:
			kind = KIND["mountains"]
			prob = 0.3 * cover
		var r: Rect2 = view.prov_bbox[i]
		var placed := 0
		var x0 := int(floor(r.position.x / CELL))
		var x1 := int(floor(r.end.x / CELL))
		var y0 := int(floor(r.position.y / CELL))
		var y1 := int(floor(r.end.y / CELL))
		for gx in range(x0, x1 + 1):
			for gy in range(y0, y1 + 1):
				var h := _hash(gx, gy)
				if float(h & 1023) / 1023.0 > prob or placed >= MAX_PER_PROVINCE:
					continue
				var p := Vector2((float(gx) + 0.15 + 0.7 * float((h >> 10) & 255) / 255.0) * CELL, (float(gy) + 0.15 + 0.7 * float((h >> 18) & 255) / 255.0) * CELL)
				if not r.has_point(p) or not _inside(i, p):
					continue
				placed += 1
				var ck := Vector2i(int(floor(p.x / CHUNK)), int(floor(p.y / CHUNK)))
				if not marks.has(ck):
					marks[ck] = []
				(marks[ck] as Array).append([p, kind[1], float((h >> 26) & 7) / 7.0])
	for ck in marks:
		var n := Node2D.new()
		n.set_script(preload("res://scripts/map/relief_chunk.gd"))
		n.marks = marks[ck]
		count += (marks[ck] as Array).size()
		add_child(n)
		_chunks[ck] = n

func _inside(i: int, p: Vector2) -> bool:
	for pp in view.prov_polys[i]:
		if (pp["r"] as Rect2).has_point(p) and Geometry2D.is_point_in_polygon(p, pp["v"]):
			return true
	return false

static func _hash(x: int, y: int) -> int:
	var h := (x * 73856093) ^ (y * 19349663)
	h = (h ^ (h >> 13)) * 1274126177
	return (h ^ (h >> 16)) & 0x7fffffff
