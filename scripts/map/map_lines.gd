class_name MapLines
extends RefCounted
## Small polyline helpers for the map layers (coast smoothing, river/pass anchors).

## One pass of Chaikin corner cutting; keeps the end points. Closed rings are detected by equal end points.
static func chaikin(v: PackedVector2Array) -> PackedVector2Array:
	var n := v.size()
	if n < 3:
		return v
	var closed := v[0].is_equal_approx(v[n - 1])
	var out := PackedVector2Array()
	out.resize(2 * (n - 1) + (1 if closed else 2))
	var k := 0
	if not closed:
		out[k] = v[0]
		k += 1
	for i in n - 1:
		var a := v[i]
		var b := v[i + 1]
		var first := not closed and i == 0
		var last := not closed and i == n - 2
		out[k] = a.lerp(b, 0.5 if first else 0.25)
		out[k + 1] = a.lerp(b, 0.5 if last else 0.75)
		k += 2
	if not closed:
		out[k] = v[n - 1]
		k += 1
	else:
		out[k] = out[0]
		k += 1
	out.resize(k)
	return out

static func length(v: PackedVector2Array) -> float:
	var l := 0.0
	for i in range(1, v.size()):
		l += v[i - 1].distance_to(v[i])
	return l

static func longest(lines: Array) -> PackedVector2Array:
	var best := PackedVector2Array()
	var bl := -1.0
	for l in lines:
		var ll := length(l)
		if ll > bl:
			bl = ll
			best = l
	return best

## Point at half the length of the polyline.
static func midpoint(v: PackedVector2Array) -> Vector2:
	if v.is_empty():
		return Vector2.ZERO
	var half := length(v) * 0.5
	var acc := 0.0
	for i in range(1, v.size()):
		var seg := v[i - 1].distance_to(v[i])
		if acc + seg >= half and seg > 0.0:
			return v[i - 1].lerp(v[i], (half - acc) / seg)
		acc += seg
	return v[v.size() - 1]

## Keeps every n-th vertex (and always the last one).
static func decimate(v: PackedVector2Array, n: int) -> PackedVector2Array:
	if v.size() <= n + 1:
		return v
	var out := PackedVector2Array()
	for i in range(0, v.size(), n):
		out.append(v[i])
	if not out[out.size() - 1].is_equal_approx(v[v.size() - 1]):
		out.append(v[v.size() - 1])
	return out
