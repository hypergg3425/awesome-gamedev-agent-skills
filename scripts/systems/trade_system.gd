class_name TradeSystem
extends RefCounted
## Trade flows over real map connectivity. Each province's commerce flows to the cheapest reachable
## trade hub (market / port / trading centre / capital) along land borders and sea lanes. Wars,
## embargoes, sanctions and blockades cut edges. Transit countries collect tariffs, hub owners
## collect handling fees, trade agreements halve tariffs and add a bonus.

const LOSS_PER_HOP := 0.03
const BASE_TARIFF := 0.02

class MinHeap:
	var keys: Array = []
	var vals: Array = []
	func push(k: float, v: int) -> void:
		keys.append(k)
		vals.append(v)
		var i := keys.size() - 1
		while i > 0:
			var par := (i - 1) / 2
			if keys[par] <= keys[i]:
				break
			var tk = keys[par]; keys[par] = keys[i]; keys[i] = tk
			var tv = vals[par]; vals[par] = vals[i]; vals[i] = tv
			i = par
	func pop() -> Array:
		var rk = keys[0]
		var rv = vals[0]
		var lk = keys.pop_back()
		var lv = vals.pop_back()
		if keys.size() > 0:
			keys[0] = lk
			vals[0] = lv
			var i := 0
			var n := keys.size()
			while true:
				var l := 2 * i + 1
				var r := l + 1
				var m := i
				if l < n and keys[l] < keys[m]:
					m = l
				if r < n and keys[r] < keys[m]:
					m = r
				if m == i:
					break
				var tk = keys[m]; keys[m] = keys[i]; keys[i] = tk
				var tv = vals[m]; vals[m] = vals[i]; vals[i] = tv
				i = m
		return [rk, rv]
	func is_empty() -> bool:
		return keys.is_empty()

static func edge_ok(s: Dictionary, pa: String, pb: String, link: String) -> bool:
	var a: Dictionary = s["provinces"][pa]
	var b: Dictionary = s["provinces"][pb]
	var ca: String = a["controller"]
	var cb: String = b["controller"]
	if ca == "" or cb == "":
		return ca == cb or ca == "" or cb == ""
	if GS.at_war(s, ca, cb) or GS.at_war(s, a["owner"], b["owner"]):
		return false
	if ca != cb:
		var r := GS.rel(s, ca, cb)
		if r["embargo"].get(ca, false) or r["embargo"].get(cb, false) or r["sanction"].get(ca, false) or r["sanction"].get(cb, false):
			return false
	if link != "land":
		if link == "lane":
			if int(a["buildings"].get("port", 0)) < 1 or int(b["buildings"].get("port", 0)) < 1:
				return false
		if _blockaded_province(s, pa) or _blockaded_province(s, pb):
			return false
	return true

static func _blockaded_province(s: Dictionary, pid: String) -> bool:
	var owner: String = s["provinces"][pid]["controller"]
	for aid in GS.armies_at(s, pid):
		var a: Dictionary = s["armies"][aid]
		if a.get("naval", false) and a["owner"] != owner and GS.at_war(s, a["owner"], owner):
			return true
	return false

static func compute(s: Dictionary) -> Dictionary:
	var ids: Array = Defs.province_ids
	var n := ids.size()
	var idx: Dictionary = Defs.province_index
	var dist := PackedFloat64Array()
	dist.resize(n)
	dist.fill(1e18)
	var pred := PackedInt32Array()
	pred.resize(n)
	pred.fill(-1)
	var hub_of := PackedInt32Array()
	hub_of.resize(n)
	hub_of.fill(-1)
	var heap := MinHeap.new()
	var power := {}
	for i in n:
		var pid: String = ids[i]
		var p: Dictionary = s["provinces"][pid]
		if p["owner"] == "":
			continue
		var pm := Mods.province(s, pid)
		var pw := float(pm.get("trade_power", 0.0))
		var cc: Dictionary = s["countries"].get(p["owner"], {})
		if cc.get("capital", "") == pid:
			pw += 1.0
		power[i] = pw
		if pw >= 1.0 and p["controller"] != "":
			var d0 := 2.0 - 0.5 * minf(pw, 3.0)
			dist[i] = d0
			hub_of[i] = i
			heap.push(d0, i)
	while not heap.is_empty():
		var top := heap.pop()
		var du: float = top[0]
		var u: int = top[1]
		if du > dist[u]:
			continue
		var upid: String = ids[u]
		var edges: Array = []
		for nb in Defs.neighbors(upid):
			edges.append([nb, "land", 1.0])
		for sl in Defs.sea_links(upid):
			var cost := 1.0 + float(sl[2]) / 900.0 if sl[1] == "lane" else 1.6
			edges.append([sl[0], str(sl[1]), cost])
		var infra := float(Mods.province(s, upid).get("infra", 0.0))
		for e in edges:
			var v: int = idx[e[0]]
			if s["provinces"][e[0]]["owner"] == "":
				continue
			if not edge_ok(s, upid, e[0], e[1]):
				continue
			var nd := du + float(e[2]) * (1.0 - clampf(infra * 0.05, 0.0, 0.3))
			if nd < dist[v]:
				dist[v] = nd
				pred[v] = u
				hub_of[v] = hub_of[u]
				heap.push(nd, v)
	# payouts
	var income := {}
	var by_province := {}
	var flows: Array = []
	var foreign_goods := {}
	var commerce_total := 0.0
	for i in n:
		var pid: String = ids[i]
		var p: Dictionary = s["provinces"][pid]
		var owner: String = p["owner"]
		if owner == "" or owner == "REB":
			continue
		var cv := float(EconomySystem.province_calc(s, pid)["commerce"])
		commerce_total += cv
		var payee: String = p["controller"]
		if payee != owner:
			# occupation: the occupier takes a share, the owner loses it
			if payee != "" and payee != "REB":
				income[payee] = float(income.get(payee, 0.0)) + cv * 0.35
			continue
		if hub_of[i] < 0:
			income[owner] = float(income.get(owner, 0.0)) + cv * 0.4
			by_province[pid] = {"hub": "", "value": cv * 0.4, "hops": 0}
			continue
		var h: int = hub_of[i]
		var hpid: String = ids[h]
		var hops := 0
		var cur := i
		var tariffs := 0.0
		var tariff_payees: Array = []
		var hub_owner: String = s["provinces"][hpid]["controller"]
		while cur != h and cur != -1:
			var cpid: String = ids[cur]
			var cown: String = s["provinces"][cpid]["controller"]
			if cur != i and cown != owner and cown != "" and cown != hub_owner:
				var rr := GS.rel(s, owner, cown)
				var tf := (BASE_TARIFF + Mods.get_mod(s, cown, "tariff")) * (0.5 if rr["trade"] else 1.0)
				tf = clampf(tf, 0.0, 0.1)
				tariffs += tf
				tariff_payees.append([cown, tf])
			hops += 1
			cur = pred[cur]
		var gross := cv * maxf(0.0, 1.0 - LOSS_PER_HOP * float(hops))
		var fee := 0.0
		if hub_owner != owner and hub_owner != "":
			fee = 0.06 + 0.02 * minf(float(power.get(h, 1.0)), 4.0)
			var rr2 := GS.rel(s, owner, hub_owner)
			if rr2["trade"]:
				fee *= 0.75   # a trade agreement lowers the hub's fee; it never creates money
			income[hub_owner] = float(income.get(hub_owner, 0.0)) + gross * fee
			foreign_goods[hub_owner] = float(foreign_goods.get(hub_owner, 0.0)) + gross
		for tp in tariff_payees:
			income[tp[0]] = float(income.get(tp[0], 0.0)) + gross * float(tp[1])
		income[owner] = float(income.get(owner, 0.0)) + gross * maxf(0.0, 1.0 - fee - tariffs)
		by_province[pid] = {"hub": hpid, "value": gross, "hops": hops}
		if hops >= 1 and hops <= 12:
			flows.append([pid, hpid, gross])
	var paid := 0.0
	for k in income:
		paid += float(income[k])
	var res := {"turn": s["turn"], "paid": paid, "commerce": commerce_total, "income": income, "by_province": by_province, "flows": flows, "power": power}
	s["_c"]["trade"] = res
	return res

static func ensure(s: Dictionary) -> Dictionary:
	var t: Variant = s["_c"].get("trade")
	if t == null or int((t as Dictionary).get("turn", -1)) != int(s["turn"]):
		return compute(s)
	return t

static func country_trade(s: Dictionary, cid: String) -> Dictionary:
	var t := ensure(s)
	return {"income": float(t["income"].get(cid, 0.0))}

static func has_market_access(s: Dictionary, cid: String) -> bool:
	var ports := 0
	var blocked := 0
	for pid in GS.owned(s, cid):
		if int(s["provinces"][pid]["buildings"].get("port", 0)) > 0:
			ports += 1
			if _blockaded_province(s, pid):
				blocked += 1
	if ports > 0 and blocked * 2 >= ports and blocked > 0:
		# a land route might remain: check an unblockaded neighbouring market
		for pid in GS.owned(s, cid):
			for nb in Defs.neighbors(pid):
				var o: String = s["provinces"][nb]["owner"]
				if o != cid and o != "" and not GS.at_war(s, cid, o) and int(s["provinces"][nb]["buildings"].get("market", 0)) > 0:
					return true
		return false
	return true

static func invalidate(s: Dictionary) -> void:
	s["_c"].erase("trade")

## Record material consumption (construction, recruitment) for market pricing.
static func record_use(s: Dictionary, res: String, amount: float) -> void:
	var d: Dictionary = s["_c"].get("demand", {})
	d[res] = float(d.get(res, 0.0)) + amount
	s["_c"]["demand"] = d

## Update global market prices from this turn's production and demand.
static func update_market(s: Dictionary, production: Dictionary, demand: Dictionary) -> void:
	var extra := EconomyDepth.demand_extra(s)
	for k in ["iron", "wood", "stone", "coal", "lux", "food"]:
		var sup := float(production.get(k, 0.0)) + 60.0
		var dem := float(demand.get(k, 0.0)) + float(extra.get(k, 0.0)) + 60.0
		var base := float(EconomySystem.BASE_PRICE[k])
		var target := base * pow(clampf(dem / sup, 0.55, 1.9), 0.55)
		var m: Dictionary = s["market"][k]
		m["price"] = snappedf(lerpf(float(m["price"]), target, 0.3), 0.001)
		m["supply"] = sup
		m["demand"] = dem
	EconomyDepth.record_history(s)
