#!/usr/bin/env python3
"""IMPERIUM extended map (map600), step 1: split the 410 classic provinces into >=600 regions.

Input : classic step-1 pickle (tools/gen_map_step1.py) + Natural Earth admin-1 units (public domain).
Output: pickle of the new province list + data/map600/parents.json (parent id -> child ids).

Every child is a union of admin-1 units (real borders), of single polygons of multi-part units
(e.g. European / Asian Istanbul, islands) or, where a modern unit is far too large to be one region,
of a Voronoi cut of that unit between authored historical-region seeds (tools/map600_splits.py).
Children always partition their parent exactly. The first child keeps the parent's id when the id
still names the region (stable references); otherwise all children get new ids.
"""
import collections, json, math, pickle, sys, os
import numpy as np
from shapely.geometry import Point, MultiPoint, Polygon, MultiPolygon
from shapely.ops import unary_union, voronoi_diagram
from shapely.strtree import STRtree
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from map600_common import *
from map600_splits import SPLITS

OUT = ROOT + '/data/map600/'


def cos_lat(y):
    return math.cos(math.radians(y))


def dist2(ax, ay, bx, by):
    dx = (ax - bx) * cos_lat((ay + by) / 2)
    return dx * dx + (ay - by) ** 2


def rep(g):
    return g.representative_point() if g.area > 0 else g.centroid


def make_pieces(units):
    """Units -> pieces. A multi-part unit yields one piece per polygon part >= 700 km2 (a strait or sea
    separates the parts, e.g. European / Asian Istanbul); smaller parts stay with the largest part."""
    pieces = []
    for u in units:
        parts = sorted(polys(u['geom']), key=lambda q: -q.area)
        main = [parts[0]]
        extra = []
        for q in parts[1:]:
            (extra if km2(q) >= 700 else main).append(q)
        for k, grp in enumerate([main] + [[q] for q in extra]):
            g = unary_union(grp)
            c, r = g.centroid, rep(g)
            pieces.append(dict(unit=u, geom=g, name=u['name'], name_tr=u['name_tr'], cx=c.x, cy=c.y, rx=r.x, ry=r.y,
                               area=km2(g), part=k))
    return pieces


def voronoi_cut(geom, seeds):
    """Split a polygon between seed points (lon/lat) with the Voronoi cells of the seeds."""
    k = cos_lat(geom.centroid.y)
    pts = MultiPoint([(x * k, y) for x, y in seeds])
    env = Polygon([(-400, -100), (400, -100), (400, 100), (-400, 100)])
    cells = list(voronoi_diagram(pts, envelope=env).geoms)
    out = {}
    for i, (x, y) in enumerate(seeds):
        p = Point(x * k, y)
        cell = min(cells, key=lambda c: 0 if c.contains(p) else c.distance(p))
        cell_ll = Polygon([(cx / k, cy) for cx, cy in cell.exterior.coords])
        part = geom.intersection(cell_ll)
        if not part.is_empty:
            out[i] = part
    return out


def assign_children(kids, pieces):
    """Distribute the pieces of one parent over its child specs; returns child index -> list of geoms."""
    unit_child = {}
    for ci, k in enumerate(kids):
        for un in k.get('units', []):
            unit_child[un] = ci
    seeds = [(ci, k['seed']) for ci, k in enumerate(kids) if 'seed' in k]
    got = collections.defaultdict(list)
    loose = []
    for pc in pieces:
        if pc['name'] in unit_child:
            got[unit_child[pc['name']]].append(pc['geom'])
        elif not seeds:
            loose.append(pc)
        else:
            inside = [(ci, s) for ci, s in seeds if pc['geom'].contains(Point(*s))]
            if len(inside) >= 2 and pc['area'] > 3000:
                cut = voronoi_cut(pc['geom'], [s for _, s in seeds])
                for j, g in cut.items():
                    got[seeds[j][0]].append(g)
            else:
                best = inside[0] if inside else min(seeds, key=lambda cs: dist2(pc['rx'], pc['ry'], cs[1][0], cs[1][1]))
                got[best[0]].append(pc['geom'])
    if loose:
        cen = {}
        for ci, gs in got.items():
            c = unary_union(gs).centroid
            cen[ci] = (c.x, c.y)
        for pc in loose:
            ci = min(cen, key=lambda c: dist2(pc['rx'], pc['ry'], cen[c][0], cen[c][1]))
            got[ci].append(pc['geom'])
    return got


def main():
    classic = pickle.load(open(CLASSIC_PKL, 'rb'))
    units = pickle.load(open(UNITS_PKL, 'rb'))
    parents = sorted(classic['provinces'], key=lambda p: p['id'])
    ptree = STRtree([p['geom'] for p in parents])
    by_parent = collections.defaultdict(list)
    for u in units:
        r = rep(u['geom'])
        cand = [int(i) for i in ptree.query(r) if parents[int(i)]['geom'].contains(r)]
        if not cand:
            cand = [int(i) for i in ptree.query(u['geom'])]
            if not cand:
                continue
            cand = [max(cand, key=lambda i: parents[i]['geom'].intersection(u['geom']).area)]
        by_parent[parents[cand[0]]['id']].append(u)
    used = set(p['id'] for p in parents)
    children = []
    parent_map = {}
    for p in parents:
        spec = SPLITS.get(p['id'])
        us = by_parent.get(p['id'], [])
        if spec is None or not us:
            children.append(dict(p, parent=p['id'], reason_hint=''))
            parent_map[p['id']] = [p['id']]
            continue
        pcs = make_pieces(us)
        kids = spec(p, us, pcs) if callable(spec) else spec
        got = assign_children(kids, pcs)
        ids = []
        a3 = p['adm0'].lower()
        for ci, k in enumerate(kids):
            if ci not in got:
                print('WARN empty child', p['id'], k.get('en'))
                continue
            g = unary_union(got[ci])
            if k.get('id') in (None, 'keep'):
                cid = p['id']
            else:
                cid = f"{a3}_{k['id']}"
                if cid in used and cid != p['id']:
                    raise SystemExit('duplicate id ' + cid)
            used.add(cid)
            c = dict(p)
            c.update(id=cid, name=k['en'], name_tr=k.get('tr') or k['en'], geom=g, area=km2(g), parent=p['id'],
                     unit_names=sorted(set(pc['name'] for pc in pcs if any(g.contains(rep(pc['geom'])) or g.intersects(pc['geom'].buffer(-1e-6)) for _ in [0]))) if False else [],
                     reason_hint=k.get('tag', ''), seeded=True)
            children.append(c)
            ids.append(cid)
        # partition check
        tot = sum(c['area'] for c in children if c['parent'] == p['id'])
        if abs(tot - p['area']) > 0.01 * p['area'] + 50:
            print('WARN partition area mismatch', p['id'], int(p['area']), int(tot))
        parent_map[p['id']] = ids
    # pop share by area within parent
    sib = collections.defaultdict(float)
    for c in children:
        sib[c['parent']] += max(c['area'], 1)
    for c in children:
        pp = next(q for q in parents if q['id'] == c['parent'])
        c['pop_modern'] = pp['pop_modern'] * max(c['area'], 1) / sib[c['parent']]
    print('children', len(children))
    cnt = collections.Counter(c['continent'] for c in children)
    print(cnt)
    os.makedirs(OUT, exist_ok=True)
    json.dump(parent_map, open(OUT + 'parents.json', 'w'), indent=0, sort_keys=True)
    pickle.dump(dict(provinces=children, countries=classic['countries']), open(MAP600_PKL, 'wb'))


if __name__ == '__main__':
    main()
