class_name MapMarkers
extends RefCounted
## Builds the marker data of the campaign map from the game state: cities / ports / forts, battles, supply lines,
## trade routes and sea-control tint. Output is plain data (world positions); MapMarkerPainter draws it in screen space
## with zoom-dependent detail and collision culling. No nodes involved, so it is testable headlessly.

const BATTLE_TURNS := 3
const MAX_TRADE_ROUTES := 140
const SUPPLY_BFS_DEPTH := 7

static func city_rank(s: Dictionary, pid: String) -> int:
	var cs: Dictionary = s["countries"].get(s["provinces"][pid]["owner"], {})
	if str(cs.get("capital", "")) == pid:
		return 3
	var p: Dictionary = s["provinces"][pid]
	var pd: Dictionary = Defs.provinces[pid]
	var dev := float(p.get("dev", 0.0))
	if dev >= 5.0 or int(pd.get("hub", 0)) >= 2:
		return 2
	if dev >= 3.0 or int(p["buildings"].get("port", 0)) > 0 or int(p["buildings"].get("fort", 0)) >= 2 or int(pd.get("hub", 0)) >= 1:
		return 1
	return 0

## Settlement / infrastructure markers, sorted by priority (capitals first). pos = province label point (approximate).
static func cities(s: Dictionary, prov_center: Array) -> Array:
	var out: Array = []
	for i in Defs.province_ids.size():
		var pid: String = Defs.province_ids[i]
		var p: Dictionary = s["provinces"][pid]
		var pd: Dictionary = Defs.provinces[pid]
		var names: Array = pd.get("cities", [])
		var rank := city_rank(s, pid)
		var fort := int(p["buildings"].get("fort", 0))
		var port := bool(pd.get("coastal", false)) and int(p["buildings"].get("port", 0)) > 0
		var road := int(p["buildings"].get("road", 0)) + 2 * int(p["buildings"].get("railway", 0))
		out.append({"pos": prov_center[i], "rank": rank, "pid": pid, "name": str(names[0]) if names.size() > 0 else Defs.province_name(pid).split(" (")[0], "generic": names.is_empty(),
			"more": names.slice(1, 3), "port": port, "fort": fort, "road": road, "dev": float(p.get("dev", 0.0)), "owner": str(p["owner"])})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["rank"] != b["rank"]:
			return int(a["rank"]) > int(b["rank"])
		return float(a["dev"]) > float(b["dev"]))
	return out

## Recent battles (last BATTLE_TURNS turns) from the state's battle log.
static func battles(s: Dictionary, prov_center: Array) -> Array:
	var out: Array = []
	for b in s.get("battle_log", []):
		if int(s["turn"]) - int(b["turn"]) > BATTLE_TURNS or not Defs.province_index.has(b["pid"]):
			continue
		out.append({"pos": prov_center[Defs.province_index[b["pid"]]], "naval": bool(b.get("naval", false)), "age": int(s["turn"]) - int(b["turn"])})
	return out

## Supply lines of the player's armies standing outside friendly ground: a polyline back to the nearest own province.
## Colour: green within 1 hop, amber up to 3, red beyond.
static func supply_lines(s: Dictionary, me: String, prov_center: Array) -> Array:
	var out: Array = []
	var seen_loc := {}
	for aid in GS.armies_of(s, me):
		var a: Dictionary = s["armies"][aid]
		var loc: String = a["loc"]
		if loc == "" or bool(a.get("naval", false)) or seen_loc.has(loc) or MilitarySystem.is_friendly_ground(s, me, loc):
			continue
		seen_loc[loc] = true
		var path := _path_home(s, me, loc)
		if path.size() < 2:
			continue
		var pts := PackedVector2Array()
		for pid in path:
			pts.append(prov_center[Defs.province_index[pid]])
		var hops := path.size() - 1
		out.append({"points": pts, "hops": hops, "color": Color("5fbf6a") if hops <= 1 else (Color("e0b040") if hops <= 3 else Color("d9534f"))})
	return out

static func _path_home(s: Dictionary, me: String, from: String) -> Array:
	var prev := {from: ""}
	var queue: Array = [from]
	var depth := {from: 0}
	var qi := 0
	while qi < queue.size():
		var u: String = queue[qi]
		qi += 1
		if u != from and s["provinces"][u]["controller"] == me:
			var path: Array = []
			var cur := u
			while cur != "":
				path.push_front(cur)
				cur = prev[cur]
			return path
		if int(depth[u]) >= SUPPLY_BFS_DEPTH:
			continue
		for nb in Defs.neighbors(u):
			if not prev.has(nb):
				prev[nb] = u
				depth[nb] = int(depth[u]) + 1
				queue.append(nb)
	return []

## Trade flows (province -> hub), strongest first, capped.
static func trade_routes(s: Dictionary, prov_center: Array) -> Array:
	var flows: Array = TradeSystem.ensure(s)["flows"]
	var sorted := flows.duplicate()
	sorted.sort_custom(func(a: Array, b: Array) -> bool: return float(a[2]) > float(b[2]))
	var mx := 0.001
	for f in sorted:
		mx = maxf(mx, float(f[2]))
	var out: Array = []
	for f in sorted.slice(0, MAX_TRADE_ROUTES):
		out.append({"a": prov_center[Defs.province_index[f[0]]], "b": prov_center[Defs.province_index[f[1]]], "w": float(f[2]) / mx})
	return out

## Sea zones tinted by their dominant navy: [{pos, radius, color, strength}] in world units.
static func sea_tint(s: Dictionary, ctx: Dictionary) -> Array:
	var out: Array = []
	for z in ctx.get("sea", {}):
		var zid := str(z)
		if not zid.begins_with("sea_"):
			continue
		var idx := int(zid.substr(4))
		if idx < 0 or idx >= Defs.seas.size():
			continue
		var d := MapModes.dominant_naval(ctx, zid)
		if str(d["cid"]) == "":
			continue
		var sea: Dictionary = Defs.seas[idx]
		out.append({"pos": Vector2(sea["pos"][0], sea["pos"][1]), "radius": clampf(float(sea.get("size", 8.0)) * 7.0, 60.0, 280.0),
			"color": MapModes.country_color(s, str(d["cid"])), "strength": clampf(0.25 + 0.5 * float(d["share"]), 0.0, 0.75)})
	return out
