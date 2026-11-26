#!/usr/bin/env python3
"""IMPERIUM extended map (map600), step 2: topology, data-derived attributes, sea links, features, binary export.

Reads /tmp/claude-0/provinces600_step1.pkl (tools/gen_map600_step1.py) and writes data/map600/
  provinces.json  geometry.bin  seas.json  map_meta.json  features.json
Same file formats as data/map (see tools/gen_map_step2.py); extra per-province fields are documented in
docs/MAP_DATA_SOURCES.md. All derived numbers are deterministic functions of Natural Earth data plus the small
curated tables in tools/map600_data.py (no random numbers).
"""
import math, pickle, struct, json, collections, sys, os, time
import numpy as np
import shapefile
import shapely
from shapely.geometry import shape, Point, MultiPolygon, Polygon, LineString
from shapely.ops import unary_union, nearest_points, polylabel
from shapely.strtree import STRtree
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from map600_common import *
from map600_data import HUBS, COAL, IRON, LUX, SEA_TR_EXTRA
import map600_features as feat
import gen_map_step2 as S2          # reuse proj, tri_poly, terrain_for, CULTURE, read helpers

OUTDIR = ROOT + '/data/map600/'
SIMPLIFY = 0.035
proj = S2.proj


def climate_of(lat, lon, desert, mtn, coastal):
    a = abs(lat)
    if a >= 66:
        return 'arctic'
    if desert > 0.35:
        return 'arid'
    if mtn > 0.5 and a < 40:
        return 'highland'
    if a < 12:
        return 'tropical_monsoon' if (70 < lon < 130 and a > 8) else 'tropical_wet'
    if a < 25:
        if desert > 0.1 or (lon > -20 and lon < 60 and 15 < a):
            return 'semi_arid'
        return 'tropical_monsoon' if 70 < lon < 130 else 'tropical_savanna'
    if a < 40:
        if -12 < lon < 45 and 30 < lat < 45:
            return 'mediterranean' if (coastal or lon < 20) else 'semi_arid'
        if lon > 100 and 25 <= a < 36:
            return 'humid_subtropical'
        if 45 <= lon < 85:
            return 'semi_arid'
        return 'humid_subtropical' if lon > 85 else 'semi_arid'
    if a < 55:
        if (lon < 12 and lat > 43) or (coastal and lon < 25 and lat > 48):
            return 'temperate_oceanic'
        if 40 <= lat < 46 and -12 < lon < 40:
            return 'mediterranean' if coastal else 'continental'
        return 'continental'
    if lon > 25 or lat >= 61:
        return 'subarctic'
    return 'temperate_oceanic'


FERT_BASE = {'plains': 0.80, 'steppe': 0.50, 'forest': 0.50, 'hills': 0.50, 'marsh': 0.55, 'jungle': 0.55,
             'mountains': 0.22, 'desert': 0.07, 'arctic': 0.08}
FERT_CLIMATE = {'mediterranean': 1.0, 'temperate_oceanic': 1.05, 'continental': 0.95, 'humid_subtropical': 1.1,
                'tropical_monsoon': 1.1, 'tropical_wet': 0.9, 'tropical_savanna': 0.95, 'semi_arid': 0.8, 'arid': 0.7,
                'subarctic': 0.7, 'arctic': 0.6, 'highland': 0.85}
WOOD_BASE = {'forest': 0.85, 'jungle': 0.80, 'hills': 0.50, 'mountains': 0.40, 'plains': 0.30, 'steppe': 0.12,
             'marsh': 0.30, 'desert': 0.03, 'arctic': 0.20}
WOOD_CLIMATE = {'arid': 0.5, 'semi_arid': 0.7, 'tropical_wet': 1.1, 'tropical_monsoon': 1.05, 'highland': 0.9}


def near_score(pt, table):
    """0..1 proximity score to the nearest curated district (1 inside half radius, fading to 0 at 1.6 radius)."""
    best = 0.0
    for _, lo, la, r in table:
        d = math.hypot((pt[0] - lo) * math.cos(math.radians(la)), pt[1] - la)
        best = max(best, max(0.0, min(1.0, (1.6 * r - d) / (1.1 * r))))
    return best


def district_score(g, table):
    """Max proximity of any curated district to the province polygon."""
    best = 0.0
    for _, lo, la, r in table:
        p = Point(lo, la)
        d = g.distance(p) * 1.0
        best = max(best, max(0.0, min(1.0, (1.0 * r - d) / (1.0 * r) + (0.2 if d < r else 0.0))) if d < r else 0.0)
    return min(1.0, best)


def main():
    t0 = time.time()
    data = pickle.load(open(MAP600_PKL, 'rb'))
    provs = sorted(data['provinces'], key=lambda p: p['id'])
    n = len(provs)
    ids = [p['id'] for p in provs]
    idx = {pid: k for k, pid in enumerate(ids)}
    print('provinces', n)
    geoms = snap_simplify([p['geom'] for p in provs], SIMPLIFY)
    tree = STRtree(geoms)

    # ---- adjacency + shared borders (same thresholds as classic)
    adj = collections.defaultdict(dict)
    borders = {}
    for i, g in enumerate(geoms):
        for j in tree.query(g.buffer(0.03)):
            j = int(j)
            if j <= i or g.distance(geoms[j]) > 0.03:
                continue
            ls = shared_border(g, geoms[j])
            L = sum(l.length for l in ls)
            if L < 0.12:
                continue
            adj[i][j] = L
            adj[j][i] = L
            borders[(i, j)] = ls
    print('land adjacencies', sum(len(v) for v in adj.values()) // 2)

    # ---- landmasses
    comp = [-1] * n
    c = 0
    for i in range(n):
        if comp[i] >= 0:
            continue
        stack = [i]
        comp[i] = c
        while stack:
            a = stack.pop()
            for b in adj[a]:
                if comp[b] < 0:
                    comp[b] = c
                    stack.append(b)
        c += 1
    comp_size = collections.Counter(comp)
    print('landmasses', c)

    # ---- coast
    land_rd = shapefile.Reader(NE + 'ne_50m_land/ne_50m_land')
    land_rings = []
    for sr in land_rd.shapeRecords():
        g = shape(sr.shape.__geo_interface__)
        if not g.is_valid:
            g = g.buffer(0)
        for pg in polys(g):
            land_rings.append(pg.exterior)
    landb = unary_union(land_rings).buffer(0.09)
    coast = []
    for i, g in enumerate(geoms):
        near = g.boundary.intersection(landb)
        sh = [geoms[j].buffer(0.02) for j in adj[i]]
        if sh:
            near = near.difference(unary_union(sh))
        coast.append(lines(near))
    coast_len = [sum(l.length for l in coast[i]) for i in range(n)]
    coastal = [coast_len[i] > 0.35 for i in range(n)]

    # ---- terrain cover from Natural Earth geography regions
    rr = shapefile.Reader(NE + 'ne_10m_geography_regions_polys/ne_10m_geography_regions_polys')
    reg = []
    for sr in rr.shapeRecords():
        cla = sr.record['FEATURECLA']
        if cla in ('Range/mtn', 'Desert', 'Plain', 'Plateau', 'Delta', 'Wetlands', 'Tundra', 'Basin', 'Lowland', 'Valley', 'Foothills'):
            g = shape(sr.shape.__geo_interface__)
            if not g.is_valid:
                g = g.buffer(0)
            reg.append((cla, g))
    rtree = STRtree([g for _, g in reg])
    covers = []
    for i, g in enumerate(geoms):
        cover = collections.defaultdict(float)
        a = g.area
        for k in rtree.query(g):
            cla, rg = reg[int(k)]
            try:
                cover[cla] += g.intersection(rg).area / a
            except Exception:
                pass
        covers.append(dict(cover))

    # ---- rivers inside each province (length in degrees) + names
    rivers = feat.load_rivers()
    rvtree = STRtree([r['geom'] for r in rivers])
    river_in = [collections.defaultdict(float) for _ in range(n)]
    for i, g in enumerate(geoms):
        for k in rvtree.query(g):
            rv = rivers[int(k)]
            try:
                L = g.intersection(rv['geom']).length
            except Exception:
                continue
            if L > 0.05:
                river_in[i][rv['name']] += L

    # ---- populated places -> cities / urban population
    pp = shapefile.Reader(NE2 + 'ne_10m_populated_places/ne_10m_populated_places')
    cities = [[] for _ in range(n)]
    for sr in pp.shapeRecords():
        d = sr.record.as_dict()
        pt = Point(d['LONGITUDE'], d['LATITUDE'])
        best = None
        for k in tree.query(pt.buffer(0.2)):
            dd = geoms[int(k)].distance(pt)
            if best is None or dd < best[0]:
                best = (dd, int(k))
        if best and best[0] <= 0.2:
            cities[best[1]].append((int(d['POP_MAX'] or 0), d['NAME'], d['NAMEASCII']))
    for cl in cities:
        cl.sort(reverse=True)

    # ---- terrain etc
    out = []
    comp_of = {}
    for i, p in enumerate(provs):
        g = geoms[i]
        cov = covers[i]
        cen = g.centroid
        lat, lon = cen.y, cen.x
        t = S2.terrain_for(p, cov, lat, lon)
        desert = cov.get('Desert', 0)
        mtn = cov.get('Range/mtn', 0)
        foot = cov.get('Foothills', 0)
        cl = climate_of(lat, lon, desert, mtn, coastal[i])
        area_deg = g.area
        rv_total = sum(river_in[i].values())
        rv_density = min(1.0, rv_total / max(math.sqrt(area_deg), 0.1) / 2.0)
        fert = FERT_BASE[t] * FERT_CLIMATE[cl]
        fert += 0.12 * rv_density + 0.15 * (cov.get('Delta', 0) + 0.5 * cov.get('Wetlands', 0)) + 0.10 * (cov.get('Valley', 0) + cov.get('Lowland', 0))
        if t == 'desert' and rv_total > 0.5:
            fert += 0.20          # river oasis (Nile, Euphrates, Indus, Amu Darya ...)
        fert = max(0.03, min(1.0, fert))
        iron = min(1.0, 0.10 + 0.50 * mtn + 0.25 * foot + (0.10 if t == 'hills' else 0) + 0.55 * district_score(g, IRON))
        stone = min(1.0, 0.15 + 0.55 * mtn + 0.30 * foot + (0.20 if t in ('hills', 'mountains') else 0) + 0.10 * cov.get('Plateau', 0))
        coal = min(1.0, 0.04 + (0.10 if t in ('hills', 'mountains', 'plains', 'forest') else 0) + 0.85 * district_score(g, COAL))
        wood = WOOD_BASE[t] * WOOD_CLIMATE.get(cl, 1.0)
        lux = min(1.0, 0.08 + {'tropical_monsoon': 0.25, 'tropical_wet': 0.2, 'mediterranean': 0.22, 'humid_subtropical': 0.2,
                              'tropical_savanna': 0.1, 'temperate_oceanic': 0.08}.get(cl, 0.0)
                  + (0.08 if coastal[i] else 0) + 0.65 * district_score(g, LUX))
        urban_k = sum(c0[0] for c0 in cities[i]) / 1000.0
        # strategic reasons (machine tags) -------------------------------------------------
        tags = []
        if p.get('reason_hint'):
            tags.append(p['reason_hint'])
        small_land = comp_size[comp[i]] <= 2
        if p.get('archipelago') or (small_land and coastal[i]):
            tags.append('island')
        if t == 'mountains' or mtn > 0.45:
            tags.append('mountain')
        if t == 'desert':
            tags.append('desert')
        if t == 'steppe':
            tags.append('steppe')
        if river_in[i]:
            top = max(river_in[i].items(), key=lambda kv: kv[1])
            if top[1] > 0.8:
                tags.append(f'river valley ({top[0]})')
        if cov.get('Delta', 0) > 0.1:
            tags.append('delta')
        if cities[i] and cities[i][0][0] >= 1_000_000:
            tags.append(f'city hinterland ({cities[i][0][2]})')
        if coastal[i] and not small_land:
            tags.append('coast')
        if not tags:
            tags.append(f'{t} region')
        hub = 0
        for nm, lo, la, sc in HUBS:
            if g.contains(Point(lo, la)) or g.distance(Point(lo, la)) < 0.12:
                hub = max(hub, sc)
        out.append(dict(i=i, terrain=t, climate=cl, fert=fert, iron=iron, stone=stone, coal=coal, wood=wood, lux=lux,
                        lat=lat, lon=lon, cen=cen, urban_k=urban_k, tags=tags, hub=hub))

    # ---- sea links
    def land_hops(a, limit=8):
        seen = {a: 0}
        q = collections.deque([a])
        while q:
            u = q.popleft()
            if seen[u] >= limit:
                continue
            for v in adj[u]:
                if v not in seen:
                    seen[v] = seen[u] + 1
                    q.append(v)
        return seen

    sea = {}

    def add_link(i, j, typ, km=None):
        k = (min(i, j), max(i, j))
        if km is None:
            a, b = nearest_points(geoms[i], geoms[j])
            km = hav_km(a.x, a.y, b.x, b.y)
        if k not in sea or typ == 'strait' and sea[k][0] != 'strait' or km < sea[k][1]:
            sea[k] = (typ, km)

    cidx = [i for i in range(n) if coastal[i]]
    ctree = STRtree([geoms[i] for i in cidx])
    for i in cidx:
        gi = geoms[i]
        hops = land_hops(i, 8)
        cand = []
        for jj in ctree.query(gi.buffer(25.0)):
            j = cidx[int(jj)]
            if j == i or j in adj[i]:
                continue
            a, b = nearest_points(gi, geoms[j])
            km = hav_km(a.x, a.y, b.x, b.y)
            cand.append((km, j, a, b))
        cand.sort(key=lambda x: x[0])
        straits_taken = 0
        lanes_taken = 0
        for km, j, a, b in cand:
            if comp[j] != comp[i]:
                # different landmass: classic rule
                if km <= 150 and straits_taken < 4:
                    add_link(i, j, 'strait', km)
                    straits_taken += 1
                elif km <= 2600 and lanes_taken < 2 and straits_taken == 0:
                    add_link(i, j, 'lane', km)
                    lanes_taken += 1
            else:
                # same landmass: only if the sea route saves a long detour and the line is open sea
                if hops.get(j, 99) < 5:
                    continue
                if km <= 90 and straits_taken < 3:
                    add_link(i, j, 'strait', km)
                    straits_taken += 1
                elif km <= 900 and lanes_taken < 3 and hops.get(j, 99) >= 7:
                    seg = LineString([a, b])
                    blocked = 0.0
                    for k in tree.query(seg):
                        k = int(k)
                        if k in (i, j):
                            continue
                        blocked += seg.intersection(geoms[k]).length
                    if blocked < 0.05 * max(seg.length, 1e-6):
                        add_link(i, j, 'lane', km)
                        lanes_taken += 1

    # curated named straits
    strait_res = feat.strait_pairs(ids, geoms, adj)
    for a, b, nm, nm_tr, is_adj, km in strait_res:
        if not is_adj:
            add_link(a, b, 'strait', km)

    def comps_graph():
        par = list(range(n))

        def f(a):
            while par[a] != a:
                par[a] = par[par[a]]
                a = par[a]
            return a
        for i in range(n):
            for j in adj[i]:
                par[f(i)] = f(j)
        for (i, j) in sea:
            par[f(i)] = f(j)
        gr = collections.defaultdict(list)
        for i in range(n):
            gr[f(i)].append(i)
        return list(gr.values())
    while True:
        cs = comps_graph()
        if len(cs) == 1:
            break
        cs.sort(key=len, reverse=True)
        big = [i for i in cs[0] if coastal[i]]
        other = cs[1]
        oc = [i for i in other if coastal[i]] or other
        best = None
        for i in oc:
            for j in big:
                a, b = nearest_points(geoms[i], geoms[j])
                km = hav_km(a.x, a.y, b.x, b.y)
                if best is None or km < best[0]:
                    best = (km, i, j)
        add_link(best[1], best[2], 'lane', best[0])
    print('sea links', len(sea), collections.Counter(v[0] for v in sea.values()))

    # ---- population hints within parent
    sib_area = collections.defaultdict(float)
    sib_urban = collections.defaultdict(float)
    for i, p in enumerate(provs):
        sib_area[p['parent']] += max(p['area'], 1.0)
        sib_urban[p['parent']] += out[i]['urban_k']

    # ---- records
    recs = []
    for i, p in enumerate(provs):
        o = out[i]
        g = geoms[i]
        bb = g.bounds
        big = max(polys(g), key=lambda q: q.area)
        lp = polylabel(big, 0.05)
        x, y = proj(lp.x, lp.y)
        x0, y0 = proj(bb[0], bb[3])
        x1, y1 = proj(bb[2], bb[1])
        cx, cy = proj(o['cen'].x, o['cen'].y)
        par = p['parent']
        a_share = max(p['area'], 1.0) / sib_area[par]
        u_share = (o['urban_k'] / sib_urban[par]) if sib_urban[par] > 0 else a_share
        parent_pop = next(q for q in data['provinces'] if q['id'] == par) if False else None
        cont = p['continent']
        if cont == 'Europe':
            if o['lon'] < -30:
                cont = 'South America' if o['lat'] < 12 else 'North America'
            elif o['lon'] > 60:
                cont = 'Asia'
        culture = S2.CULTURE.get(p['adm0'], 'african' if p['continent'] == 'Africa' else 'oceanian')
        top_cities = [c0[2] for c0 in cities[i][:3]]
        urb = o['urban_k']
        recs.append(dict(
            id=p['id'], name=p['name'], name_tr=p['name_tr'], adm0=p['adm0'], continent=cont, subregion=p['subregion'],
            area_km2=int(p['area']), pop_modern_m=0.0, centroid=[round(cx, 2), round(cy, 2)],
            label=[round(x, 2), round(y, 2)], bbox=[round(x0, 2), round(y0, 2), round(x1, 2), round(y1, 2)],
            lat=round(o['lat'], 2), lon=round(o['lon'], 2), terrain=o['terrain'], coastal=bool(coastal[i]), landmass=comp[i],
            archipelago=bool(p.get('archipelago')), culture=culture,
            fert=round(o['fert'], 2), iron=round(o['iron'], 2), stone=round(o['stone'], 2), coal=round(o['coal'], 2),
            wood=round(o['wood'], 2), lux=round(o['lux'], 2), mountain_cover=round(covers[i].get('Range/mtn', 0), 2),
            adj=sorted(ids[j] for j in adj[i]), sea=[],
            parent=par, climate=o['climate'], port=bool(coastal[i] and (coast_len[i] >= 0.6 or comp_size[comp[i]] <= 2)),
            coast_km=int(coast_len[i] * 100.0), hub=o['hub'], urban_k=int(urb), cities=top_cities,
            dev_hint=round(max(0.0, min(1.0, 0.22 * math.log2(1 + urb / 150.0))), 2),
            pop_share=round(0.5 * a_share + 0.5 * u_share, 4),
            tags=o['tags'][:4], reason='; '.join(o['tags'][:4])))
    for (i, j), (typ, km) in sorted(sea.items()):
        recs[i]['sea'].append([ids[j], typ, int(km)])
        recs[j]['sea'].append([ids[i], typ, int(km)])
    # modern population hint from parent country share (parent's classic pop_modern is area-weighted)
    parents_pop = {q['id']: q['pop_modern'] for q in data['provinces']}
    ppar = collections.defaultdict(float)
    for q in data['provinces']:
        ppar[q['parent']] += q['pop_modern']
    for r in recs:
        r['pop_modern_m'] = round(ppar[r['parent']] * r['pop_share'] / 1e6, 3)
    json.dump(recs, open(OUTDIR + 'provinces.json', 'w'), ensure_ascii=False, separators=(',', ':'))

    # ---- features
    pairs = set(borders.keys())
    fe = {'rivers': feat.river_pairs(ids, geoms, pairs, rivers)}
    fe['passes'], miss = feat.pass_pairs(ids, geoms, pairs)
    fe['straits'] = [[ids[a], ids[b], {'name': nm, 'name_tr': nm_tr, 'adjacent': bool(ia), 'km': km}] for a, b, nm, nm_tr, ia, km in strait_res]
    lk = feat.lakes_list(ids, geoms)
    for l in lk:
        x, y = proj(l['lon'], l['lat'])
        l['pos'] = [round(x, 1), round(y, 1)]
    fe['lakes'] = lk
    fe['meta'] = {'passes_unmatched': miss, 'note': 'rivers: Natural Earth river centre lines that follow a shared border; passes and strait points are hand-entered and approximate'}
    json.dump(fe, open(OUTDIR + 'features.json', 'w'), ensure_ascii=False, indent=0)
    print('features', {k: len(v) for k, v in fe.items() if isinstance(v, list)}, 'passes unmatched', len(miss))

    # ---- binary geometry (identical layout to classic)
    buf = bytearray()
    buf += struct.pack('<4sII', b'IMPG', 1, n)

    def put_f32(arr):
        buf.extend(np.asarray(arr, dtype='<f4').tobytes())

    def put_u32(arr):
        buf.extend(np.asarray(arr, dtype='<u4').tobytes())
    total_v = 0
    for i, g in enumerate(geoms):
        pl = [t for t in (S2.tri_poly(pg) for pg in polys(g)) if t]
        buf += struct.pack('<I', len(pl))
        for pts, ix in pl:
            buf += struct.pack('<II', len(pts), len(ix))
            put_f32(pts.flatten())
            put_u32(ix)
            total_v += len(pts)
    print('mesh vertices', total_v)

    def put_lines(ls):
        buf.extend(struct.pack('<I', len(ls)))
        for l in ls:
            pts = np.array(S2.project_coords(list(l.coords)), dtype=np.float32)
            buf.extend(struct.pack('<I', len(pts)))
            put_f32(pts.flatten())
    keys = sorted(borders)
    buf += struct.pack('<I', len(keys))
    for (i, j) in keys:
        buf += struct.pack('<II', i, j)
        put_lines(borders[(i, j)])
    for i in range(n):
        put_lines(coast[i])

    def read_poly_layer(path, tol, minarea):
        r = shapefile.Reader(path)
        res = []
        for sr in r.shapeRecords():
            g = shape(sr.shape.__geo_interface__)
            if not g.is_valid:
                g = g.buffer(0)
            for pg in polys(g):
                if pg.area < minarea:
                    continue
                pg = Polygon(pg.exterior).simplify(tol)
                if pg.is_empty or not isinstance(pg, Polygon):
                    continue
                res.append(pg)
        return res
    land = read_poly_layer(NE + 'ne_50m_land/ne_50m_land', 0.04, 0.003)
    lakes = read_poly_layer(NE + 'ne_50m_lakes/ne_50m_lakes', 0.04, 0.05)
    for layer in (land, lakes):
        trs = []
        for pg in layer:
            if pg.bounds[1] < -58:
                continue
            t = S2.tri_poly(pg)
            if t:
                trs.append(t)
        buf += struct.pack('<I', len(trs))
        for pts, ix in trs:
            buf += struct.pack('<II', len(pts), len(ix))
            put_f32(pts.flatten())
            put_u32(ix)
    open(OUTDIR + 'geometry.bin', 'wb').write(bytes(buf))
    print('geometry.bin KB', len(buf) // 1024)

    # ---- sea labels: classic list + extra marine polygons
    rm = shapefile.Reader(NE + 'ne_10m_geography_marine_polys/ne_10m_geography_marine_polys')
    seas = []
    TRS = dict(S2_TRS) if False else None
    classic_seas = json.load(open(ROOT + '/data/map/seas.json'))
    have = {s['name'] for s in classic_seas}
    seas = list(classic_seas)
    for sr in rm.shapeRecords():
        d = sr.record.as_dict()
        nm = d.get('name_en') or d['name']
        if nm in SEA_TR_EXTRA and nm not in have:
            g = shape(sr.shape.__geo_interface__)
            if not g.is_valid:
                g = g.buffer(0)
            bigp = max(polys(g), key=lambda q: q.area)
            lp = polylabel(bigp, 0.2)
            x, y = proj(lp.x, lp.y)
            seas.append(dict(name=nm, name_tr=SEA_TR_EXTRA[nm], pos=[round(x, 1), round(y, 1)], rank=max(4, int(d.get('scalerank', 4))),
                             size=round(math.sqrt(bigp.area), 2)))
            have.add(nm)
    json.dump(seas, open(OUTDIR + 'seas.json', 'w'), ensure_ascii=False, indent=0)
    wx0, wy0 = proj(-180, 83)
    wx1, wy1 = proj(180, -58)
    json.dump(dict(bounds=[wx0, wy0, wx1, wy1], scale=S2.SCALE, provinces=n, projection='Miller', map_set='extended',
                   source='Natural Earth (public domain): admin-0 50m, admin-1 10m, geography regions 10m, marine polys 10m, land 50m, lakes 50m/10m, rivers 10m, populated places 10m'),
              open(OUTDIR + 'map_meta.json', 'w'), indent=1)
    print('done in %.0fs' % (time.time() - t0))


if __name__ == '__main__':
    main()
