"""Geographic features (rivers, passes, straits, lakes) for a province set.

Used by tools/gen_map600_step2.py (extended map) and tools/gen_map_features_classic.py (classic map).
Output format (features.json):
  {"rivers":  [[idA, idB, {"name": "Rhine", "name_tr": "Ren", "width": 2}], ...],   # adjacent pair separated by a major river
   "passes":  [[idA, idB, {"name": "Brenner", "name_tr": "...", "approximate": true}], ...],  # adjacent pair linked by a mountain pass
   "straits": [[idA, idB, {"name": "Bosporus", "name_tr": "...", "adjacent": bool, "km": 1}], ...],
   "lakes":   [{"name":..., "name_tr":..., "pos":[x,y], "area_km2":..., "provinces":[...]}], "meta": {...}}
Public-domain inputs: Natural Earth rivers/lakes. Passes and strait coordinates are hand-entered (approximate).
"""
import math, collections
import shapefile
from shapely.geometry import shape, Point, LineString, MultiLineString
from shapely.ops import unary_union
from shapely.strtree import STRtree
from map600_common import *
from map600_data import PASSES, STRAITS

RIVER_BUF = 0.07      # deg, tolerance between a simplified border and the river centre line


def load_rivers():
    out = []
    for fn, maxrank in (('ne_10m_rivers_lake_centerlines', 8), ('ne_10m_rivers_europe', 9)):
        r = shapefile.Reader(f'{NE2}{fn}/{fn}')
        for sr in r.shapeRecords():
            d = sr.record.as_dict()
            nm = (d.get('name_en') or d.get('name') or '').strip()
            if not nm or int(d.get('scalerank') or 99) > maxrank:
                continue
            g = shape(sr.shape.__geo_interface__)
            if g.is_empty:
                continue
            out.append(dict(name=nm, name_tr=(d.get('name_tr') or '').strip(), rank=int(d['scalerank']), geom=g))
    by = collections.defaultdict(list)
    for x in out:
        by[x['name']].append(x)
    merged = []
    for nm, xs in by.items():
        g = unary_union([x['geom'] for x in xs])
        merged.append(dict(name=nm, name_tr=next((x['name_tr'] for x in xs if x['name_tr']), ''), rank=min(x['rank'] for x in xs), geom=g))
    return merged


def river_width(rank):
    return 3 if rank <= 4 else (2 if rank <= 6 else 1)


def river_pairs(ids, geoms, pairs, rivers):
    """pairs: iterable of (i, j). Returns list [idA, idB, dict]."""
    rtree = STRtree([r['geom'] for r in rivers])
    out = []
    for i, j in sorted(pairs):
        sh = shared_border(geoms[i], geoms[j])
        L = sum(l.length for l in sh)
        if L <= 0:
            continue
        su = unary_union(sh)
        best = None
        for k in rtree.query(su.buffer(RIVER_BUF)):
            rv = rivers[int(k)]
            cov = su.intersection(rv['geom'].buffer(RIVER_BUF)).length
            if best is None or cov > best[0]:
                best = (cov, rv)
        if best and best[0] >= 0.2 and best[0] >= 0.25 * L:
            rv = best[1]
            d = {'name': rv['name'], 'width': river_width(rv['rank'])}
            if rv['name_tr']:
                d['name_tr'] = rv['name_tr']
            out.append([ids[i], ids[j], d])
    return out


def pass_pairs(ids, geoms, pairs):
    """For every curated pass find the adjacent pair whose shared border is nearest to the pass point."""
    border = {}
    for i, j in pairs:
        sh = shared_border(geoms[i], geoms[j])
        if sh:
            border[(i, j)] = unary_union(sh)
    out, miss = [], []
    used = set()
    for nm, nm_tr, lon, lat in PASSES:
        p = Point(lon, lat)
        best = None
        for (i, j), b in border.items():
            d = b.distance(p)
            if best is None or d < best[0]:
                best = (d, i, j)
        if best and best[0] <= 0.45 and (best[1], best[2]) not in used:
            used.add((best[1], best[2]))
            out.append([ids[best[1]], ids[best[2]], {'name': nm, 'name_tr': nm_tr, 'approximate': True}])
        else:
            miss.append(nm)
    return out, miss


def nearest_province(geoms, tree, lon, lat, maxd=0.8):
    p = Point(lon, lat)
    best = None
    for k in tree.query(p.buffer(maxd)):
        d = geoms[int(k)].distance(p)
        if best is None or d < best[0]:
            best = (d, int(k))
    return best[1] if best and best[0] <= maxd else None


def strait_pairs(ids, geoms, adj):
    """Resolve curated straits to province pairs. adj: dict index -> set(index). Returns list of
    (i, j, name, name_tr, adjacent, km) (i != j)."""
    tree = STRtree(geoms)
    out = []
    for nm, nm_tr, (lo1, la1), (lo2, la2) in STRAITS:
        a = nearest_province(geoms, tree, lo1, la1)
        b = nearest_province(geoms, tree, lo2, la2)
        if a is None or b is None or a == b:
            continue
        km = int(hav_km(lo1, la1, lo2, la2))
        out.append((a, b, nm, nm_tr, b in adj.get(a, ()), km))
    return out


def lakes_list(ids, geoms, min_area=1500, max_rank=7):
    r = shapefile.Reader(NE2 + 'ne_10m_lakes/ne_10m_lakes')
    tree = STRtree(geoms)
    res = []
    for sr in r.shapeRecords():
        d = sr.record.as_dict()
        nm = (d.get('name_en') or d.get('name') or '').strip()
        if not nm or int(d.get('scalerank') or 99) > max_rank:
            continue
        g = shape(sr.shape.__geo_interface__)
        a = km2(g)
        if a < min_area:
            continue
        c = g.centroid
        near = []
        for k in tree.query(g.buffer(0.15)):
            dd = geoms[int(k)].distance(g)
            if dd <= 0.12:
                near.append((dd, ids[int(k)]))
        near.sort()
        res.append({'name': nm, 'name_tr': (d.get('name_tr') or '').strip() or nm, 'lon': round(c.x, 2), 'lat': round(c.y, 2),
                    'area_km2': int(a), 'provinces': [p for _, p in near[:6]]})
    res.sort(key=lambda x: -x['area_km2'])
    return res
