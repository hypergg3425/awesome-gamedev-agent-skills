class_name MapBorders
extends RefCounted
## Converts shared-border polylines to line segments and classifies them by ownership.

var geometry: MapGeometry
var pair_segs: Array = []    # per border entry: PackedVector2Array of segment endpoints (a,b,a,b...)
var coast_segs: Array = []   # per province

func _init(geom: MapGeometry) -> void:
	geometry = geom
	for b in geom.borders:
		pair_segs.append(_to_segments(b["lines"]))
	for c in geom.coasts:
		coast_segs.append(_to_segments(c))

static func _to_segments(lines: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for l in lines:
		var v: PackedVector2Array = l
		for k in range(v.size() - 1):
			out.append(v[k])
			out.append(v[k + 1])
	return out

## owners: Array of owner ids per province index ("" = none). front_fn(i,j)->bool marks war fronts.
func build(owners: Array, front_fn: Callable = Callable()) -> Dictionary:
	var prov := PackedVector2Array()
	var country := PackedVector2Array()
	var front := PackedVector2Array()
	for k in geometry.borders.size():
		var b: Dictionary = geometry.borders[k]
		var a := int(b["a"])
		var c := int(b["b"])
		if owners[a] == owners[c]:
			prov.append_array(pair_segs[k])
		else:
			country.append_array(pair_segs[k])
			if front_fn.is_valid() and front_fn.call(a, c):
				front.append_array(pair_segs[k])
	var coast := PackedVector2Array()
	for s in coast_segs:
		coast.append_array(s)
	return {"province": prov, "country": country, "coast": coast, "front": front}
