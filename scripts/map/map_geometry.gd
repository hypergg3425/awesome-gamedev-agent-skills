class_name MapGeometry
extends RefCounted
## Loads geometry.bin produced by tools/gen_map_step2.py.
## Layout: header IMPG,u32 ver,u32 n; per province polys (verts f32 xy, tri indices u32);
## then shared borders, coasts, land underlay and lakes.

var polys: Array = []        # per province: Array of {v: PackedVector2Array, i: PackedInt32Array}
var borders: Array = []      # {a:int,b:int,lines:Array[PackedVector2Array]}
var coasts: Array = []       # per province Array[PackedVector2Array]
var land: Array = []         # decorative land polygons {v,i}
var lakes: Array = []
var ok := false

func load_file(path: String, expected: int) -> bool:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("MapGeometry: cannot open " + path)
		return false
	var magic := f.get_buffer(4).get_string_from_ascii()
	var ver := f.get_32()
	var n := f.get_32()
	if magic != "IMPG" or ver != 1 or n != expected:
		push_error("MapGeometry: bad header %s v%d n=%d (expected %d)" % [magic, ver, n, expected])
		return false
	for pi in n:
		polys.append(_read_poly_list(f))
	var bc := f.get_32()
	for k in bc:
		var a := f.get_32()
		var b := f.get_32()
		borders.append({"a": a, "b": b, "lines": _read_lines(f)})
	for pi in n:
		coasts.append(_read_lines(f))
	land = _read_poly_list(f)
	lakes = _read_poly_list(f)
	ok = true
	return true

func _read_poly_list(f: FileAccess) -> Array:
	var cnt := f.get_32()
	var out: Array = []
	for k in cnt:
		var nv := f.get_32()
		var ni := f.get_32()
		var vb := f.get_buffer(nv * 8).to_float32_array()
		var ib := f.get_buffer(ni * 4).to_int32_array()
		var v := PackedVector2Array()
		v.resize(nv)
		for j in nv:
			v[j] = Vector2(vb[j * 2], vb[j * 2 + 1])
		out.append({"v": v, "i": ib})
	return out

func _read_lines(f: FileAccess) -> Array:
	var cnt := f.get_32()
	var out: Array = []
	for k in cnt:
		var nv := f.get_32()
		var vb := f.get_buffer(nv * 8).to_float32_array()
		var v := PackedVector2Array()
		v.resize(nv)
		for j in nv:
			v[j] = Vector2(vb[j * 2], vb[j * 2 + 1])
		out.append(v)
	return out
