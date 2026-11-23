class_name Util
extends RefCounted
## Small static helpers (no state).

static func clampf_(v: float, lo: float, hi: float) -> float:
	return maxf(lo, minf(hi, v))

static func pair_key(a: String, b: String) -> String:
	return a + "|" + b if a < b else b + "|" + a

static func glob_match(pattern: String, s: String) -> bool:
	if pattern.find("*") == -1:
		return pattern == s
	return s.matchn(pattern)

static func color_from(v: Variant, fallback: Color = Color.GRAY) -> Color:
	if v is Color:
		return v
	if v is String and (v as String).begins_with("#"):
		return Color.html(v)
	return fallback

static func fmt_num(v: float, decimals: int = 0) -> String:
	var neg := v < 0.0
	var a := absf(v)
	var s := ""
	if a >= 1_000_000.0:
		s = "%.2fM" % (a / 1_000_000.0)
	elif a >= 10_000.0:
		s = "%.1fk" % (a / 1000.0)
	elif decimals > 0:
		s = ("%." + str(decimals) + "f") % a
	else:
		s = str(int(round(a)))
	return ("-" + s) if neg else s

static func fmt_signed(v: float, decimals: int = 1) -> String:
	var s := ("%." + str(decimals) + "f") % v
	return ("+" + s) if v > 0.0 else s

static func dict_add(d: Dictionary, key: String, v: float) -> void:
	d[key] = float(d.get(key, 0.0)) + v

static func deep_copy(v: Variant) -> Variant:
	if v is Dictionary:
		return (v as Dictionary).duplicate(true)
	if v is Array:
		return (v as Array).duplicate(true)
	return v

static func sorted_keys(d: Dictionary) -> Array:
	var k := d.keys()
	k.sort()
	return k

static func weighted_pick(rng: GameRng, items: Array, weights: Array) -> Variant:
	var total := 0.0
	for w in weights:
		total += maxf(0.0, float(w))
	if total <= 0.0 or items.is_empty():
		return null
	var r := rng.randf() * total
	for i in items.size():
		r -= maxf(0.0, float(weights[i]))
		if r <= 0.0:
			return items[i]
	return items[items.size() - 1]
