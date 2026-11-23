#!/usr/bin/env python3
"""IMPERIUM map generator, step 2: topology, terrain, sea links, binary export.

Reads provinces_step1.pkl and writes:
  data/map/provinces.json  - static province definitions + adjacency + sea links
  data/map/geometry.bin    - triangulated meshes, borders, coasts, land underlay, lakes
  data/map/seas.json       - sea labels
Everything derived here is an approximation for gameplay (see docs/ASSET_LICENSES.md).
"""
import math, pickle, struct, json, hashlib, collections, sys, os
import numpy as np
import shapefile
import shapely
from shapely.geometry import shape, Point, MultiPolygon, Polygon, LineString, MultiLineString, GeometryCollection
from shapely.ops import unary_union, nearest_points, polylabel
from shapely.strtree import STRtree
import mapbox_earcut as earcut

NE = '/tmp/claude-0/ne/'
IN = '/tmp/claude-0/provinces_step1.pkl'
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUTDIR = ROOT + '/data/map/'
os.makedirs(OUTDIR, exist_ok=True)

SCALE = 10.0          # map units per degree of longitude
SIMPLIFY = 0.035      # degrees (coverage simplify keeps shared borders identical)


def proj(lon, lat):
    """Miller cylindrical projection scaled to map units. y grows downwards."""
    phi = math.radians(max(min(lat, 83.0), -58.0))
    y = 1.25 * math.log(math.tan(math.pi / 4 + 0.4 * phi))
    return lon * SCALE, -math.degrees(y) * SCALE


def hav_km(lon1, lat1, lon2, lat2):
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dl = math.radians(lon2 - lon1)
    a = math.sin((p2 - p1) / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 6371.0 * 2 * math.asin(math.sqrt(a))


def polys(g):
    if g.is_empty:
        return []
    if isinstance(g, Polygon):
        return [g]
    if isinstance(g, (MultiPolygon, GeometryCollection)):
        out = []
        for x in g.geoms:
            out += polys(x)
        return out
    return []


def lines(g):
    if g.is_empty:
        return []
    if isinstance(g, LineString):
        return [g]
    if isinstance(g, (MultiLineString, GeometryCollection)):
        out = []
        for x in g.geoms:
            out += lines(x)
        return out
    return []


def hash01(s, salt=''):
    h = hashlib.md5((salt + s).encode()).digest()
    return int.from_bytes(h[:4], 'little') / 0xFFFFFFFF


def project_coords(coords):
    return [proj(x, y) for x, y in coords]


def tri_poly(poly):
    """Return (verts Nx2 float32 projected, indices uint32) for exterior ring of poly."""
    ring = list(poly.exterior.coords)[:-1]
    if len(ring) < 3:
        return None
    pts = np.array(project_coords(ring), dtype=np.float32)
    idx = earcut.triangulate_float32(pts, np.array([len(pts)], dtype=np.uint32))
    if len(idx) == 0:
        return None
    return pts, np.array(idx, dtype=np.uint32)


# culture groups by modern country (static province identity; approximate)
CULTURE = {}
def setc(c, codes):
    for a in codes.split():
        CULTURE[a] = c
setc('latin', 'FRA ITA ESP PRT BEL LUX MCO AND SMR VAT ROU MDA')
setc('germanic', 'DEU AUT CHE NLD GBR IRL ISL NOR SWE DNK LIE')
setc('slavic', 'POL CZE SVK UKR BLR RUS HRV SRB BIH SVN MNE MKD BGR LTU LVA EST KOS')
setc('hellenic', 'GRC CYP ALB')
setc('magyar_finnic', 'HUN FIN')
setc('turkic', 'TUR AZE UZB TKM KAZ KGZ')
setc('arabic', 'SYR IRQ ISR JOR LBN SAU YEM ARE KWT QAT OMN BHR EGY LBY TUN DZA MAR SAH ESH SDN MRT')
setc('iranian', 'IRN AFG TJK')
setc('caucasian', 'GEO ARM')
setc('indic', 'IND PAK BGD NPL LKA BTN')
setc('sinic', 'CHN TWN MNG PRK KOR')
setc('japonic', 'JPN')
setc('southeast_asian', 'THA VNM KHM LAO MMR MYS IDN PHL BRN TLS SGP')
setc('african', 'NGA ETH COD KEN TZA AGO MOZ ZAF ZMB ZWE NAM BWA GHA CIV CMR TCD NER MLI BFA SEN GIN SOM UGA RWA BDI MWI MDG LSO SWZ CAF COG GAB GNQ GMB GNB LBR SLE TGO BEN ERI DJI SDS')
setc('native_american', 'USA CAN MEX GTM BLZ HND SLV NIC CRI PAN CUB HTI DOM JAM BHS TTO PRI GRL')
setc('latin_american', 'BRA ARG CHL PER COL VEN ECU BOL PRY URY GUY SUR FLK')
setc('oceanian', 'AUS NZL PNG FJI SLB VUT NCL')


def terrain_for(p, cover, lat, lon):
    d = cover
    desert = d.get('Desert', 0)
    mtn = d.get('Range/mtn', 0) + 0.5 * d.get('Foothills', 0)
    wet = d.get('Wetlands', 0) + d.get('Delta', 0)
    plat = d.get('Plateau', 0)
    tundra = d.get('Tundra', 0)
    plain = d.get('Plain', 0) + d.get('Lowland', 0) + d.get('Basin', 0) + d.get('Valley', 0)
    if desert > 0.35:
        return 'desert'
    if mtn > 0.5:
        return 'mountains'
    if tundra > 0.3 or lat > 66:
        return 'arctic'
    if wet > 0.2:
        return 'marsh'
    if plat > 0.35 or mtn > 0.24:
        return 'hills'
    if abs(lat) < 9 and lon not in ():
        return 'jungle'
    if 40 <= lat <= 52 and 28 <= lon <= 120 and plain < 0.4:
        return 'steppe'
    if lat >= 48 and plain < 0.5:
        return 'forest'
    if 8 <= abs(lat) < 25 and desert > 0.1:
        return 'steppe'
    return 'plains'


def main():
    data = pickle.load(open(IN, 'rb'))
    provs = data['provinces']
    # deterministic order: continent then id
    provs.sort(key=lambda p: p['id'])
    n = len(provs)
    print('provinces', n)

    # -------- snapping + coverage simplify (shared borders stay identical)
    geoms = []
    for p in provs:
        g = p['geom']
        if not g.is_valid:
            g = g.buffer(0)
        # drop holes (lakes/enclaves) and tiny slivers
        parts = [Polygon(pg.exterior) for pg in polys(g) if pg.area > 1e-5]
        g = unary_union(parts) if parts else g
        g = shapely.set_precision(g, 0.0005)
        geoms.append(g)
    simp = shapely.coverage_simplify(np.array(geoms, dtype=object), SIMPLIFY)
    # drop holes again + slivers after simplify
    sgeoms = []
    for g in simp:
        parts = [Polygon(pg.exterior) for pg in polys(g) if pg.area > 2e-4]
        if not parts:
            parts = [Polygon(pg.exterior) for pg in polys(g)]
        sgeoms.append(MultiPolygon(parts) if len(parts) > 1 else parts[0])
    geoms = sgeoms
    tree = STRtree(geoms)

    # -------- adjacency + shared borders
    adj = collections.defaultdict(dict)
    borders = {}
    for i, g in enumerate(geoms):
        for j in tree.query(g.buffer(0.03)):
            j = int(j)
            if j <= i:
                continue
            if g.distance(geoms[j]) > 0.03:
                continue
            gb = g.boundary
            shared = gb.intersection(geoms[j].buffer(0.02))
            ls = lines(shared)
            L = sum(l.length for l in ls)
            if L < 0.12:      # ~12 km of contact needed
                continue
            adj[i][j] = L
            adj[j][i] = L
            borders[(i, j)] = ls
    print('land adjacencies', sum(len(v) for v in adj.values()) // 2)

    # -------- landmasses
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
    print('landmasses', c)

    # -------- coast lines (boundary parts that lie on the sea: near the exterior of the land underlay)
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
        b = g.boundary
        near = b.intersection(landb)
        sh = [geoms[j].buffer(0.02) for j in adj[i]]
        if sh:
            near = near.difference(unary_union(sh))
        coast.append(lines(near))
    coastal = [sum(l.length for l in coast[i]) > 0.35 for i in range(n)]

    # -------- terrain
    rr = shapefile.Reader(NE + 'ne_10m_geography_regions_polys/ne_10m_geography_regions_polys')
    reg = []
    for sr in rr.shapeRecords():
        cla = sr.record['FEATURECLA']
        if cla in ('Range/mtn', 'Desert', 'Plain', 'Plateau', 'Delta', 'Wetlands', 'Tundra', 'Basin',
                   'Lowland', 'Valley', 'Foothills'):
            g = shape(sr.shape.__geo_interface__)
            if not g.is_valid:
                g = g.buffer(0)
            reg.append((cla, g))
    rtree = STRtree([g for _, g in reg])
    terrain = []
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
        cen = g.centroid
        t = terrain_for(provs[i], cover, cen.y, cen.x)
        terrain.append(t)
        covers.append(dict(cover))
    print(collections.Counter(terrain))

    # -------- sea links
    cen_pts = [g.centroid for g in geoms]
    sea = {}  # (i,j)-> (type, km)
    cidx = [i for i in range(n) if coastal[i]]
    ctree = STRtree([geoms[i] for i in cidx])

    def add_link(i, j, typ):
        k = (min(i, j), max(i, j))
        a, b = nearest_points(geoms[i], geoms[j])
        km = hav_km(a.x, a.y, b.x, b.y)
        if k not in sea or km < sea[k][1]:
            sea[k] = (typ, km)

    for i in cidx:
        gi = geoms[i]
        cand = []
        for jj in ctree.query(gi.buffer(25.0)):
            j = cidx[int(jj)]
            if j == i or comp[j] == comp[i] or j in adj[i]:
                continue
            a, b = nearest_points(gi, geoms[j])
            cand.append((hav_km(a.x, a.y, b.x, b.y), j))
        cand.sort()
        taken = 0
        for km, j in cand:
            if km <= 150:
                add_link(i, j, 'strait')
            elif km <= 2600 and taken < 2:
                add_link(i, j, 'lane')
                taken += 1
    # make the world graph connected through sea lanes
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
        for other in cs[1:]:
            oc = [i for i in other if coastal[i]] or other
            best = None
            for i in oc:
                for j in big:
                    a, b = nearest_points(geoms[i], geoms[j])
                    km = hav_km(a.x, a.y, b.x, b.y)
                    if best is None or km < best[0]:
                        best = (km, i, j)
            add_link(best[1], best[2], 'lane')
            break
    print('sea links', len(sea), collections.Counter(v[0] for v in sea.values()))

    # -------- json records
    out = []
    for i, p in enumerate(provs):
        g = geoms[i]
        bb = g.bounds
        # label point: pole of inaccessibility of biggest polygon
        big = max(polys(g), key=lambda q: q.area)
        lp = polylabel(big, 0.05)
        x, y = proj(lp.x, lp.y)
        x0, y0 = proj(bb[0], bb[3])
        x1, y1 = proj(bb[2], bb[1])
        cen = g.centroid
        cx, cy = proj(cen.x, cen.y)
        pid = p['id']
        cover = covers[i]
        mtn = cover.get('Range/mtn', 0)
        t = terrain[i]
        lat = cen.y
        arable = {'plains': 0.85, 'steppe': 0.55, 'forest': 0.5, 'hills': 0.55, 'marsh': 0.55, 'jungle': 0.6,
                  'mountains': 0.25, 'desert': 0.08, 'arctic': 0.1}[t]
        fert = max(0.03, min(1.0, arable * (0.8 + 0.4 * hash01(pid, 'fert'))))
        iron = min(1.0, (0.6 if t in ('mountains', 'hills') else 0.2) * (0.3 + 1.4 * hash01(pid, 'iron')))
        stone = min(1.0, (0.7 if t in ('mountains', 'hills') else 0.25) * (0.4 + 1.2 * hash01(pid, 'stone')))
        coal = min(1.0, (0.45 if t in ('hills', 'mountains', 'plains', 'forest') else 0.1) * (0.2 + 1.6 * hash01(pid, 'coal')))
        wood = {'forest': 0.9, 'jungle': 0.85, 'hills': 0.5, 'mountains': 0.4, 'plains': 0.3, 'steppe': 0.15, 'marsh': 0.3,
                'desert': 0.03, 'arctic': 0.25}[t] * (0.7 + 0.6 * hash01(pid, 'wood'))
        lux = min(1.0, (0.7 if (abs(lat) < 25 or (30 < lat < 45 and -10 < cen.x < 45)) else 0.15) * (0.3 + 1.4 * hash01(pid, 'lux')))
        a3 = p['adm0']
        cont = p['continent']
        if cont == 'Europe':
            if cen.x < -30:
                cont = 'South America' if cen.y < 12 else 'North America'
            elif cen.x > 60:
                cont = 'Asia'
        culture = CULTURE.get(a3, 'african' if p['continent'] == 'Africa' else 'oceanian')
        out.append(dict(
            id=pid, name=p['name'], name_tr=p['name_tr'], adm0=a3, continent=cont, subregion=p['subregion'],
            area_km2=int(p['area']), pop_modern_m=round(p['pop_modern'] / 1e6, 3), centroid=[round(cx, 2), round(cy, 2)],
            label=[round(x, 2), round(y, 2)], bbox=[round(x0, 2), round(y0, 2), round(x1, 2), round(y1, 2)],
            lat=round(cen.y, 2), lon=round(cen.x, 2), terrain=t, coastal=bool(coastal[i]), landmass=comp[i],
            archipelago=bool(p.get('archipelago')), culture=culture,
            fert=round(fert, 2), iron=round(iron, 2), stone=round(stone, 2), coal=round(coal, 2),
            wood=round(wood, 2), lux=round(lux, 2), mountain_cover=round(mtn, 2),
            adj=sorted([provs[j]['id'] for j in adj[i]]),
            sea=[], ))
    ids = [p['id'] for p in provs]
    idx = {pid: k for k, pid in enumerate(ids)}
    for (i, j), (typ, km) in sorted(sea.items()):
        out[i]['sea'].append([ids[j], typ, int(km)])
        out[j]['sea'].append([ids[i], typ, int(km)])
    json.dump(out, open(OUTDIR + 'provinces.json', 'w'), ensure_ascii=False, separators=(',', ':'))

    # -------- binary geometry
    buf = bytearray()
    buf += struct.pack('<4sII', b'IMPG', 1, n)

    def put_f32(arr):
        buf.extend(np.asarray(arr, dtype='<f4').tobytes())

    def put_u32(arr):
        buf.extend(np.asarray(arr, dtype='<u4').tobytes())

    total_v = 0
    for i, g in enumerate(geoms):
        pl = []
        for pg in polys(g):
            t = tri_poly(pg)
            if t:
                pl.append(t)
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
            pts = np.array(project_coords(list(l.coords)), dtype=np.float32)
            buf.extend(struct.pack('<I', len(pts)))
            put_f32(pts.flatten())

    # shared borders
    keys = sorted(borders)
    buf += struct.pack('<I', len(keys))
    for (i, j) in keys:
        buf += struct.pack('<II', i, j)
        put_lines(borders[(i, j)])
    # coasts
    for i in range(n):
        put_lines(coast[i])

    # land underlay + lakes
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
            t = tri_poly(pg)
            if t:
                trs.append(t)
        buf += struct.pack('<I', len(trs))
        for pts, ix in trs:
            buf += struct.pack('<II', len(pts), len(ix))
            put_f32(pts.flatten())
            put_u32(ix)
        print('layer polys', len(trs))
    open(OUTDIR + 'geometry.bin', 'wb').write(bytes(buf))
    print('geometry.bin KB', len(buf) // 1024)

    # -------- sea labels
    TRS = {'Mediterranean Sea': 'Akdeniz', 'Black Sea': 'Karadeniz', 'North Sea': 'Kuzey Denizi',
           'Baltic Sea': 'Baltık Denizi', 'Atlantic Ocean': 'Atlas Okyanusu', 'North Atlantic Ocean': 'Kuzey Atlas Okyanusu',
           'South Atlantic Ocean': 'Güney Atlas Okyanusu', 'Pacific Ocean': 'Büyük Okyanus',
           'North Pacific Ocean': 'Kuzey Büyük Okyanus', 'South Pacific Ocean': 'Güney Büyük Okyanus',
           'Indian Ocean': 'Hint Okyanusu', 'Arctic Ocean': 'Kuzey Buz Denizi', 'Red Sea': 'Kızıldeniz',
           'Arabian Sea': 'Umman Denizi', 'Caspian Sea': 'Hazar Denizi', 'Persian Gulf': 'Basra Körfezi',
           'Gulf of Mexico': 'Meksika Körfezi', 'Caribbean Sea': 'Karayip Denizi', 'South China Sea': 'Güney Çin Denizi',
           'Sea of Japan': 'Japon Denizi', 'Bay of Bengal': 'Bengal Körfezi', 'Tasman Sea': 'Tasman Denizi',
           'Norwegian Sea': 'Norveç Denizi', 'Adriatic Sea': 'Adriyatik Denizi', 'Aegean Sea': 'Ege Denizi',
           'Bay of Biscay': 'Biskay Körfezi', 'English Channel': 'Manş Denizi', 'Labrador Sea': 'Labrador Denizi',
           'Yellow Sea': 'Sarı Deniz', 'East China Sea': 'Doğu Çin Denizi', 'Philippine Sea': 'Filipin Denizi',
           'Coral Sea': 'Mercan Denizi', 'Mozambique Channel': 'Mozambik Kanalı', 'Gulf of Guinea': 'Gine Körfezi',
           'Sargasso Sea': 'Sargasso Denizi', 'Barents Sea': 'Barents Denizi', 'Southern Ocean': 'Güney Okyanusu'}
    rm = shapefile.Reader(NE + 'ne_10m_geography_marine_polys/ne_10m_geography_marine_polys')
    seas = []
    for sr in rm.shapeRecords():
        d = sr.record.as_dict()
        nm = d.get('name_en') or d['name']
        if nm in TRS and nm != 'Southern Ocean':
            g = shape(sr.shape.__geo_interface__)
            if not g.is_valid:
                g = g.buffer(0)
            big = max(polys(g), key=lambda q: q.area)
            lp = polylabel(big, 0.2)
            x, y = proj(lp.x, lp.y)
            seas.append(dict(name=nm, name_tr=TRS[nm], pos=[round(x, 1), round(y, 1)], rank=d.get('scalerank', 3),
                             size=round(math.sqrt(big.area), 2)))
    json.dump(seas, open(OUTDIR + 'seas.json', 'w'), ensure_ascii=False, indent=0)
    print('seas', len(seas))
    wx0, wy0 = proj(-180, 83)
    wx1, wy1 = proj(180, -58)
    json.dump(dict(bounds=[wx0, wy0, wx1, wy1], scale=SCALE, provinces=n, projection='Miller',
                   source='Natural Earth (public domain) admin-0 50m, admin-1 10m, geography regions 10m, marine polys 10m, land 50m, lakes 50m'),
              open(OUTDIR + 'map_meta.json', 'w'), indent=1)


if __name__ == '__main__':
    main()
