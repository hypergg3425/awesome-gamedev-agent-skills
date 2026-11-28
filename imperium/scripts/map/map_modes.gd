class_name MapModes
extends RefCounted
## Map modes: per-province colour functions and legends. Pure functions of (state, province) so they can be tested
## headlessly on every province of both map sets. CampaignMap feeds the colours to the MapView data texture.

const MODES := ["political", "terrain", "economic", "diplomatic", "military", "population", "supply", "trade",
	"religion", "culture", "infrastructure", "unrest", "admin", "development", "naval"]

const TERRAIN_COL := {"plains": Color("b4c96e"), "steppe": Color("cdc07f"), "forest": Color("4a8a4e"), "hills": Color("a98a58"), "mountains": Color("8e8e9c"),
	"desert": Color("e8b968"), "jungle": Color("2c7a58"), "marsh": Color("68a09c"), "arctic": Color("e8f0f4")}
const TERRAIN_ORDER := ["plains", "steppe", "forest", "hills", "mountains", "desert", "jungle", "marsh", "arctic"]

const RELIGION_COL := {"catholic": Color("d8b24a"), "orthodox": Color("4f78b5"), "protestant": Color("7fb069"), "sunni": Color("2f9e8f"),
	"shia": Color("8a5fb5"), "jewish": Color("e8e4f0"), "buddhist": Color("e08a3a"), "hindu": Color("d9534f"), "eastern_faiths": Color("c06c84"),
	"pagan": Color("8c6b4a"), "animist": Color("a9b36a"), "tengri": Color("5aa0d0"), "shinto": Color("e6a0b4"), "secular": Color("9aa0a6")}
const CULTURE_COL := {"latin": Color("c9744a"), "germanic": Color("5f7fb5"), "slavic": Color("6aa66a"), "hellenic": Color("5ab0c8"), "magyar_finnic": Color("b09a52"),
	"caucasian": Color("a05a8a"), "turkic": Color("d9b84a"), "arabic": Color("3f9a82"), "iranian": Color("8a6fc0"), "indic": Color("d9772e"),
	"sinic": Color("c9453f"), "japonic": Color("e08aa0"), "southeast_asian": Color("4f9e5c"), "african": Color("9a6b3a"), "native_american": Color("7a8f4a"),
	"latin_american": Color("d08a6a"), "oceanian": Color("4aa0b8")}
const NEUTRAL := Color("7d8087")
const NO_OWNER := Color("5f6368")

static func country_color(s: Dictionary, cid: String, fallback: Color = Color(0.4, 0.4, 0.4)) -> Color:
	if cid == "" or not s["countries"].has(cid):
		return fallback
	return Util.color_from(s["countries"][cid]["color"], fallback)

## Sequential ramp: cool blue -> gold -> red, or a colour-blind-safe viridis.
static func ramp(t: float, cb: bool) -> Color:
	t = clampf(t, 0.0, 1.0)
	if cb:
		return Color("440154").lerp(Color("21908d"), clampf(t * 2.0, 0.0, 1.0)).lerp(Color("fde725"), clampf(t * 2.0 - 1.0, 0.0, 1.0))
	return Color("2c4a6b").lerp(Color("c9a24a"), clampf(t * 2.0, 0.0, 1.0)).lerp(Color("b5322b"), clampf(t * 2.0 - 1.0, 0.0, 1.0))

## Warning ramp (calm -> danger) for unrest.
static func ramp_warn(t: float, cb: bool) -> Color:
	t = clampf(t, 0.0, 1.0)
	if cb:
		return Color("fde725").lerp(Color("21908d"), clampf(t * 2.0, 0.0, 1.0)).lerp(Color("440154"), clampf(t * 2.0 - 1.0, 0.0, 1.0))
	return Color("3f7a52").lerp(Color("d6b64a"), clampf(t * 2.0, 0.0, 1.0)).lerp(Color("b5322b"), clampf(t * 2.0 - 1.0, 0.0, 1.0))

## Green ramp (weak -> strong) for administration.
static func ramp_admin(t: float, cb: bool) -> Color:
	t = clampf(t, 0.0, 1.0)
	if cb:
		return Color("e66101").lerp(Color("5e3c99"), t)
	return Color("8a4a3a").lerp(Color("c9b25a"), clampf(t * 2.0, 0.0, 1.0)).lerp(Color("3f8a5a"), clampf(t * 2.0 - 1.0, 0.0, 1.0))

## Per-evaluation context: maxima for the ramps and the sea-control table, computed only for the modes that need them.
## Build once per refresh.
static func context(s: Dictionary, me: String, mode: String = "") -> Dictionary:
	var ctx := {"me": me, "cb": bool(Settings.get_value("colorblind")), "inc": 1.0, "pop": 1.0, "sup": 14.0, "trade": 1.0, "infra": 8.0, "sea": {}}
	if mode == "economic" or mode == "population" or mode == "trade":
		var tr := TradeSystem.ensure(s) if mode == "trade" else {}
		for pid in Defs.province_ids:
			var p: Dictionary = s["provinces"][pid]
			if mode == "economic":
				var pc := EconomySystem.province_calc(s, pid)
				ctx["inc"] = maxf(ctx["inc"], float(pc["tax"]) + float(pc["production"]) + float(pc["commerce"]))
			elif mode == "population":
				ctx["pop"] = maxf(ctx["pop"], float(p["pop"]))
			else:
				ctx["trade"] = maxf(ctx["trade"], float(tr["by_province"].get(pid, {}).get("value", 0.0)))
	if mode == "naval":
		ctx["sea"] = NavalSystem.compute_control(s)
	return ctx

static func infra_score(s: Dictionary, pid: String) -> float:
	var b: Dictionary = s["provinces"][pid]["buildings"]
	var own := float(b.get("road", 0)) + float(b.get("bridge", 0)) + 2.0 * float(b.get("railway", 0)) + 0.6 * float(b.get("canal", 0)) \
			+ 0.6 * float(b.get("port", 0)) + 0.4 * float(b.get("post_office", 0))
	return own + 0.15 * float(s["provinces"][pid].get("dev", 1.0))

## 0..1: how firmly the owner administers the province (core status, offices, unrest, occupation).
static func admin_control(s: Dictionary, pid: String) -> float:
	var p: Dictionary = s["provinces"][pid]
	var owner: String = p["owner"]
	if owner == "":
		return 0.0
	if p["controller"] != owner:
		return 0.08
	var b: Dictionary = p["buildings"]
	var offices := float(b.get("government_office", 0)) + float(b.get("tax_office", 0)) + 1.5 * float(b.get("admin_center", 0)) + float(b.get("court", 0))
	var v := (0.7 if owner in (p.get("cores", []) as Array) else 0.35) + 0.2 * clampf(offices / 5.0, 0.0, 1.0)
	v -= 0.4 * clampf(float(p.get("unrest", 0.0)) / 100.0, 0.0, 1.0)
	return clampf(v, 0.02, 1.0)

static func dominant_naval(ctx: Dictionary, zone: String) -> Dictionary:
	var best := ""
	var bv := 0.0
	var total := 0.0
	var sea: Dictionary = ctx.get("sea", {})
	for cid in sea.get(zone, {}):
		var v := float(sea[zone][cid])
		total += v
		if v > bv:
			bv = v
			best = str(cid)
	return {"cid": best, "score": bv, "share": bv / maxf(total, 0.001)}

static func color(mode: String, s: Dictionary, pid: String, ctx: Dictionary) -> Color:
	var p: Dictionary = s["provinces"][pid]
	var me: String = ctx["me"]
	var cb: bool = ctx["cb"]
	var owner: String = p["owner"]
	match mode:
		"terrain":
			return TERRAIN_COL.get(Defs.provinces[pid]["terrain"], Color.GRAY)
		"economic":
			var pc := EconomySystem.province_calc(s, pid)
			return ramp((float(pc["tax"]) + float(pc["production"]) + float(pc["commerce"])) / float(ctx["inc"]), cb)
		"population":
			return ramp(sqrt(float(p["pop"]) / float(ctx["pop"])), cb)
		"supply":
			return ramp(MilitarySystem.supply_cap(s, me, pid) / float(ctx["sup"]), cb)
		"trade":
			var d: Dictionary = TradeSystem.ensure(s)["by_province"].get(pid, {})
			var c := ramp(sqrt(float(d.get("value", 0.0)) / float(ctx["trade"])), cb)
			if float(TradeSystem.ensure(s)["power"].get(Defs.province_index[pid], 0.0)) >= 1.0:
				c = c.lightened(0.25)
			return c
		"diplomatic":
			return _diplomatic(s, owner, me, cb)
		"military":
			return _military(s, pid, p, me)
		"religion":
			return RELIGION_COL.get(str(p["religion"]), NEUTRAL)
		"culture":
			return CULTURE_COL.get(str(p["culture"]), NEUTRAL)
		"infrastructure":
			return ramp(sqrt(infra_score(s, pid) / float(ctx["infra"])), cb)
		"unrest":
			if owner == "":
				return NO_OWNER
			return ramp_warn(float(p.get("unrest", 0.0)) / 60.0, cb)
		"admin":
			return NO_OWNER if owner == "" else ramp_admin(admin_control(s, pid), cb)
		"development":
			return ramp(float(p.get("dev", 0.0)) / 10.0, cb)
		"naval":
			return _naval(s, pid, p, ctx)
		_:
			var col := country_color(s, owner)
			if p["controller"] != owner and s["countries"].has(p["controller"]):
				col = col.lerp(country_color(s, p["controller"]), 0.55)
			return col

static func _diplomatic(s: Dictionary, owner: String, me: String, cb: bool) -> Color:
	if owner == me:
		return Color("e6c876")
	if owner == "" or not s["countries"].has(owner):
		return Color.GRAY
	if GS.at_war(s, me, owner):
		return Color("b5322b") if not cb else Color("d95f02")
	var r := GS.rel(s, me, owner)
	if GS.overlord_of(s, owner) == me or GS.overlord_of(s, me) == owner:
		return Color("3f9a8e")
	if r["alliance"]:
		return Color("4f9e5c") if not cb else Color("1b9e77")
	if int(r["truce_until"]) > int(s["turn"]):
		return Color("c28a3a")
	if r["trade"]:
		return Color("4f78b5")
	var op := GS.opinion(s, owner, me)
	return Color("8a8f98").lerp(Color("4f9e5c") if op > 0 else Color("b5322b"), clampf(absf(op) / 120.0, 0.0, 0.55))

static func _military(s: Dictionary, pid: String, p: Dictionary, me: String) -> Color:
	var owner: String = p["owner"]
	var c2 := country_color(s, owner).darkened(0.35)
	var n := 0.0
	var foe := false
	for aid in GS.armies_at(s, pid):
		var a: Dictionary = s["armies"][aid]
		if not a.get("naval", false):
			n += UnitUtil.army_size(a)
			if GS.at_war(s, me, a["owner"]):
				foe = true
	if p["controller"] != owner:
		c2 = c2.lerp(country_color(s, p["controller"], Color.GRAY), 0.6)
	c2 = c2.lightened(clampf(Mods.fort_level(s, pid) * 0.04, 0.0, 0.3))
	if n > 0.0:
		c2 = c2.lerp(Color("d9534f") if foe else Color("f0d98a"), clampf(n / 20.0, 0.12, 0.75))
	return c2

## Naval influence: land is muted, coastal provinces take the colour of the navy that dominates their sea zone
## (NavalSystem.sea_control); the sea zones themselves are tinted by SeaTintLayer.
static func _naval(s: Dictionary, pid: String, p: Dictionary, ctx: Dictionary) -> Color:
	var base := country_color(s, p["owner"], NO_OWNER)
	var muted := Color(base.get_luminance(), base.get_luminance(), base.get_luminance()).lerp(base, 0.28).darkened(0.18)
	if not bool(Defs.provinces[pid]["coastal"]):
		return muted
	var dom := dominant_naval(ctx, SeaZones.zone_of(pid))
	if str(dom["cid"]) == "":
		return muted
	return muted.lerp(country_color(s, str(dom["cid"])), clampf(0.45 + 0.4 * float(dom["share"]), 0.0, 0.9))

## --- legends --------------------------------------------------------------------------------------------------------
## {"title": String, "kind": "ramp"|"list", "stops": Array[Color], "lo": String, "hi": String, "items": [{"color", "text"}], "note": String}
static func legend(mode: String, s: Dictionary, me: String) -> Dictionary:
	var cb := bool(Settings.get_value("colorblind"))
	var out := {"title": Loc.t("MODE_" + mode.to_upper()), "kind": "list", "stops": [], "lo": "", "hi": "", "items": [], "note": ""}
	match mode:
		"political":
			var counts := {}
			for pid in Defs.province_ids:
				var o: String = s["provinces"][pid]["owner"]
				if o != "" and s["countries"].has(o):
					counts[o] = int(counts.get(o, 0)) + 1
			var top := _top_keys(counts, 5)
			if me != "" and me not in top and s["countries"].has(me):
				top.append(me)
			for cid in top:
				out["items"].append({"color": country_color(s, cid), "text": Loc.tx(s["countries"][cid]["short"])})
			out["note"] = Loc.t("LEG_POLITICAL_NOTE")
		"terrain":
			for t in TERRAIN_ORDER:
				out["items"].append({"color": TERRAIN_COL[t], "text": Loc.t("TERRAIN_" + t.to_upper())})
		"diplomatic":
			out["items"] = [{"color": Color("e6c876"), "text": Loc.t("LEG_DIP_SELF")}, {"color": Color("4f9e5c") if not cb else Color("1b9e77"), "text": Loc.t("LEG_DIP_ALLY")},
				{"color": Color("3f9a8e"), "text": Loc.t("LEG_DIP_VASSAL")}, {"color": Color("4f78b5"), "text": Loc.t("LEG_DIP_TRADE")},
				{"color": Color("c28a3a"), "text": Loc.t("LEG_DIP_TRUCE")}, {"color": Color("8a8f98"), "text": Loc.t("LEG_DIP_NEUTRAL")},
				{"color": Color("b5322b") if not cb else Color("d95f02"), "text": Loc.t("LEG_DIP_WAR")}]
		"military":
			out["items"] = [{"color": Color("f0d98a"), "text": Loc.t("LEG_MIL_FRIEND")}, {"color": Color("d9534f"), "text": Loc.t("LEG_MIL_FOE")},
				{"color": Color("8f8f8f"), "text": Loc.t("LEG_MIL_FORT")}]
			out["note"] = Loc.t("LEG_MIL_NOTE")
		"religion":
			out["items"] = _present_items(s, "religion", RELIGION_COL)
		"culture":
			out["items"] = _present_items(s, "culture", CULTURE_COL)
		"naval":
			var best := {}
			for z in NavalSystem.compute_control(s):
				var d := dominant_naval({"sea": NavalSystem.compute_control(s)}, str(z))
				if str(d["cid"]) != "":
					best[d["cid"]] = int(best.get(d["cid"], 0)) + 1
			for cid in _top_keys(best, 6):
				out["items"].append({"color": country_color(s, cid), "text": Loc.tx(s["countries"][cid]["short"])})
			out["items"].append({"color": Color("2a4560"), "text": Loc.t("LEG_NAVAL_NONE")})
			out["note"] = Loc.t("LEG_NAVAL_NOTE")
		_:
			out["kind"] = "ramp"
			var f := func(t: float) -> Color: return ramp(t, cb)
			var keys := {"economic": ["LEG_LOW", "LEG_HIGH", "LEG_ECONOMIC_NOTE"], "population": ["LEG_LOW", "LEG_HIGH", "LEG_POPULATION_NOTE"],
				"supply": ["LEG_SUPPLY_LO", "LEG_SUPPLY_HI", "LEG_SUPPLY_NOTE"], "trade": ["LEG_LOW", "LEG_HIGH", "LEG_TRADE_NOTE"],
				"infrastructure": ["LEG_LOW", "LEG_HIGH", "LEG_INFRA_NOTE"], "development": ["LEG_LOW", "LEG_HIGH", "LEG_DEV_NOTE"],
				"unrest": ["LEG_UNREST_LO", "LEG_UNREST_HI", "LEG_UNREST_NOTE"], "admin": ["LEG_ADMIN_LO", "LEG_ADMIN_HI", "LEG_ADMIN_NOTE"]}
			var k: Array = keys.get(mode, ["LEG_LOW", "LEG_HIGH", "LEG_ECONOMIC_NOTE"])
			if mode == "unrest":
				f = func(t: float) -> Color: return ramp_warn(t, cb)
			elif mode == "admin":
				f = func(t: float) -> Color: return ramp_admin(t, cb)
			for i in 5:
				out["stops"].append(f.call(float(i) / 4.0))
			out["lo"] = Loc.t(k[0])
			out["hi"] = Loc.t(k[1])
			out["note"] = Loc.t(k[2])
	return out

static func _top_keys(counts: Dictionary, n: int) -> Array:
	var keys := counts.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool: return int(counts[a]) > int(counts[b]) or (int(counts[a]) == int(counts[b]) and str(a) < str(b)))
	return keys.slice(0, n)

static func _present_items(s: Dictionary, field: String, pal: Dictionary) -> Array:
	var counts := {}
	for pid in Defs.province_ids:
		var v := str(s["provinces"][pid][field])
		counts[v] = int(counts.get(v, 0)) + 1
	var items: Array = []
	for v in _top_keys(counts, 8):
		var key := ("REL_" if field == "religion" else "CULT_") + str(v).to_upper()
		items.append({"color": pal.get(v, NEUTRAL), "text": Loc.t(key) if Loc.has_key(key) else str(v)})
	return items
