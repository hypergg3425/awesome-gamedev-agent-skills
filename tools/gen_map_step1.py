#!/usr/bin/env python3
"""IMPERIUM map generator, step 1: build provinces from Natural Earth (public domain).

Input : Natural Earth 10m admin-1 + 50m admin-0 shapefiles (see docs/ASSET_LICENSES.md)
Output: pickle of province definitions (unprojected lon/lat shapely geometry).

Algorithm
  1. Group admin-1 units per country (neutral merges in map_seeds.MERGE).
  2. Remote small components and micro-countries are pooled into archipelago provinces.
  3. Countries with authored seeds: units -> nearest seed (Voronoi on unit centroids).
     Other countries: deterministic, area-weighted k-means.
"""
import math, pickle, sys, unicodedata, re, collections
import numpy as np
import shapefile
from shapely.geometry import shape, Point, MultiPolygon, Polygon
from shapely.ops import unary_union
from shapely.strtree import STRtree
sys.path.insert(0, __file__.rsplit('/', 1)[0])
from map_seeds import SEEDS, MERGE

NE = '/tmp/claude-0/ne/'
OUT = '/tmp/claude-0/provinces_step1.pkl'
SKIP_ADM0 = {'ATA', 'ATF', 'HMD', 'SGS', 'BVT', 'ATC'}

# count overrides for auto-clustered countries (others derived from area / population)
COUNT_OVERRIDE = {
    'USA': 11, 'CAN': 8, 'MEX': 5, 'BRA': 8, 'ARG': 4, 'CHL': 2, 'PER': 2, 'COL': 2, 'VEN': 1,
    'CHN': 10, 'IND': 9, 'JPN': 4, 'KAZ': 3, 'MNG': 2, 'IDN': 5, 'PAK': 3, 'MYS': 2, 'COD': 3, 'NGA': 3,
    'ETH': 2, 'ZAF': 3, 'SDN': 2, 'TCD': 2, 'NER': 2, 'MLI': 2, 'AGO': 2, 'MOZ': 2, 'TZA': 2,
    'KOR': 2, 'THA': 2, 'MMR': 2, 'VNM': 2, 'AFG': 2, 'AUS': 6, 'NZL': 2, 'GRL': 1,
    'BLR': 1, 'LTU': 1, 'LVA': 1, 'EST': 1, 'SRB': 1, 'BIH': 1, 'ALB': 1, 'SVK': 1, 'CHE': 1,
    'JOR': 1, 'LBN': 1, 'TUN': 1, 'ISL': 1, 'CYP': 1, 'AZE': 1, 'ARM': 1, 'GEO': 1,
    'UZB': 2, 'TKM': 1, 'SOM': 1, 'KEN': 1, 'UGA': 1, 'MRT': 2, 'ESH': 1, 'GHA': 1, 'CIV': 1,
    'CMR': 1, 'GAB': 1, 'COG': 1, 'CAF': 1, 'ZMB': 1, 'ZWE': 1, 'BWA': 1, 'NAM': 1, 'MDG': 1,
    'SEN': 1, 'GIN': 1, 'BFA': 1, 'OMN': 1, 'YEM': 1, 'ARE': 1, 'PHL': 2, 'MYS': 2, 'BGD': 1,
    'NPL': 1, 'LKA': 1, 'KHM': 1, 'LAO': 1, 'PRK': 1, 'TWN': 1, 'PNG': 2, 'CUB': 1, 'BOL': 1,
    'PRY': 1, 'URY': 1, 'ECU': 1, 'GTM': 1, 'SSD': 1, 'ERI': 1, 'DJI': 1, 'LUX': 1, 'SVN': 1,
    'MKD': 1, 'MNE': 1, 'MDA': 1, 'KOS': 1, 'KGZ': 1, 'TJK': 1, 'HTI': 1, 'DOM': 1, 'HND': 1,
    'NIC': 1, 'PAN': 1, 'CRI': 1, 'SLV': 1, 'GUY': 1, 'SUR': 1, 'BLZ': 1, 'JAM': 1,
}
MICRO_KM2 = 4500          # non-European countries below this go to island pools
REMOTE_SMALL_KM2 = 25000  # overseas components below this (and far) go to island pools
REMOTE_DEG = 4.5


def slug(s):
    s = unicodedata.normalize('NFKD', s).encode('ascii', 'ignore').decode()
    s = re.sub(r'[^a-zA-Z0-9]+', '_', s).strip('_').lower()
    return s or 'x'


def km2(geom):
    c = geom.centroid
    return geom.area * 111.32 * 111.32 * math.cos(math.radians(c.y))


def ctr(u):
    return u['cx'], u['cy']


def kmeans(units, k, iters=40):
    """Deterministic area-weighted k-means on unit centroids (equirectangular)."""
    n = len(units)
    if k >= n:
        return [[u] for u in units]
    P = np.array([[u['cx'] * math.cos(math.radians(u['cy'])), u['cy']] for u in units])
    W = np.array([max(u['area'], 1.0) for u in units])
    # farthest-point init starting at the heaviest unit
    idx = [int(np.argmax(W))]
    while len(idx) < k:
        d = np.min(((P[:, None, :] - P[idx][None, :, :]) ** 2).sum(-1), axis=1)
        d = d * np.sqrt(W)
        idx.append(int(np.argmax(d)))
    C = P[idx].copy()
    for _ in range(iters):
        D = ((P[:, None, :] - C[None, :, :]) ** 2).sum(-1)
        lab = D.argmin(1)
        newC = C.copy()
        for j in range(k):
            m = lab == j
            if m.any():
                newC[j] = (P[m] * W[m, None]).sum(0) / W[m].sum()
        if np.allclose(newC, C):
            break
        C = newC
    D = ((P[:, None, :] - C[None, :, :]) ** 2).sum(-1)
    lab = D.argmin(1)
    groups = [[units[i] for i in range(n) if lab[i] == j] for j in range(k)]
    return [g for g in groups if g]


def components(units):
    geoms = [u['geom'] for u in units]
    tree = STRtree(geoms)
    parent = list(range(len(units)))

    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a
    for i, g in enumerate(geoms):
        for j in tree.query(g.buffer(0.02)):
            j = int(j)
            if j > i and g.distance(geoms[j]) < 0.02:
                parent[find(i)] = find(j)
    comp = collections.defaultdict(list)
    for i in range(len(units)):
        comp[find(i)].append(units[i])
    return list(comp.values())


def make_province(pid, name, name_tr, units, adm0, c0, extra=None):
    g = unary_union([u['geom'] for u in units])
    d = dict(id=pid, name=name, name_tr=name_tr, adm0=adm0, continent=c0['continent'],
             subregion=c0['subregion'], geom=g, area=km2(g), unit_names=[u['name'] for u in units],
             pop_modern=0.0, archipelago=False)
    if extra:
        d.update(extra)
    return d


def main():
    r0 = shapefile.Reader(NE + 'ne_50m_admin_0_countries/ne_50m_admin_0_countries')
    countries = {}
    for sr in r0.shapeRecords():
        d = sr.record.as_dict()
        a3 = d['ADM0_A3']
        if a3 in SKIP_ADM0:
            continue
        countries[a3] = dict(a3=a3, name=d['NAME'], name_tr=d.get('NAME_TR') or d['NAME'],
                             continent=d['CONTINENT'], subregion=d['SUBREGION'],
                             pop=d['POP_EST'], geom=shape(sr.shape.__geo_interface__))
    r1 = shapefile.Reader(NE + 'ne_10m_admin_1_states_provinces/ne_10m_admin_1_states_provinces')
    units = collections.defaultdict(list)
    for sr in r1.shapeRecords():
        d = sr.record.as_dict()
        a3 = MERGE.get(d['adm0_a3'], d['adm0_a3'])
        if d['adm0_a3'] in SKIP_ADM0:
            continue
        g = shape(sr.shape.__geo_interface__)
        if g.is_empty:
            continue
        if not g.is_valid:
            g = g.buffer(0)
        c = g.representative_point() if g.area > 0 else g.centroid
        cen = g.centroid
        units[a3].append(dict(name=d['name'] or d['name_alt'] or d['gn_name'] or 'Unit',
                              name_tr=d.get('name_tr') or '', geom=g, area=km2(g),
                              cx=cen.x, cy=cen.y, adm0=a3))
    for a3, c in countries.items():
        if a3 not in units and a3 not in MERGE:
            g = c['geom'] if c['geom'].is_valid else c['geom'].buffer(0)
            cen = g.centroid
            units[a3] = [dict(name=c['name'], name_tr=c['name_tr'], geom=g, area=km2(g),
                              cx=cen.x, cy=cen.y, adm0=a3)]
    for a3 in list(units):
        if a3 not in countries:
            # unit belongs to a country missing in admin-0 (should not happen), keep generic info
            cen = units[a3][0]
            countries[a3] = dict(a3=a3, name=a3, name_tr=a3, continent='Seven seas (open ocean)',
                                 subregion='Pool', pop=0, geom=units[a3][0]['geom'])

    provinces = []
    pool = []  # units to be grouped into archipelago provinces
    used_ids = set()

    def uid(base):
        b = base
        i = 2
        while b in used_ids:
            b = f'{base}_{i}'
            i += 1
        used_ids.add(b)
        return b

    for a3 in sorted(units):
        c0 = countries[a3]
        us = units[a3]
        total_area = sum(u['area'] for u in us)
        europe = c0['continent'] == 'Europe'
        if total_area < MICRO_KM2 and not (europe and total_area > 1500):
            pool += us
            continue
        # land components
        comps = components(us)
        comps.sort(key=lambda cc: -sum(u['area'] for u in cc))
        main = comps[0]
        main_geom = unary_union([u['geom'] for u in main])
        keep = list(main)
        remote_big = []
        for cc in comps[1:]:
            ca = sum(u['area'] for u in cc)
            cg = unary_union([u['geom'] for u in cc])
            dist = cg.distance(main_geom)
            if dist <= REMOTE_DEG and ca < 0.5 * total_area:
                keep += cc
            elif ca < REMOTE_SMALL_KM2 and not (a3 in SEEDS and ca >= 5000 and
                                                  min(math.hypot((cg.centroid.x - sd[3]) * math.cos(math.radians(cg.centroid.y)), cg.centroid.y - sd[4]) for sd in SEEDS[a3]) < 8.0):
                pool += cc
            elif ca < REMOTE_SMALL_KM2:
                keep += cc
            else:
                remote_big.append(cc)
        seeds = SEEDS.get(a3)
        pops = c0['pop'] or 0
        if seeds:
            groups = collections.defaultdict(list)
            far = []
            for u in keep:
                best, bd = None, 1e9
                for s in seeds:
                    dx = (u['cx'] - s[3]) * math.cos(math.radians(u['cy']))
                    dy = u['cy'] - s[4]
                    d = dx * dx + dy * dy
                    if d < bd:
                        best, bd = s, d
                if math.sqrt(bd) > 14.0:
                    far.append(u)
                else:
                    groups[best[0]].append(u)
            for s in seeds:
                if s[0] in groups:
                    provinces.append(make_province(uid(f'{a3.lower()}_{s[0]}'), s[1], s[2], groups[s[0]], a3, c0,
                                                   extra=dict(seeded=True)))
            if far:
                k = SEEDS.get(a3 + '_REMAINDER_K', 2)
                for gi, grp in enumerate(kmeans(far, k)):
                    big = max(grp, key=lambda u: u['area'])
                    provinces.append(make_province(uid(f'{a3.lower()}_{slug(big["name"])}'), big['name'],
                                                   big['name_tr'] or big['name'], grp, a3, c0))
        else:
            k = COUNT_OVERRIDE.get(a3)
            if k is None:
                a0 = 90000 if europe else 450000
                k = max(round(total_area / a0), round(pops / 70e6))
                k = max(1, min(k, 4))
            k = min(k, len(keep))
            grps = kmeans(keep, k) if k > 1 else [keep]
            for grp in grps:
                big = max(grp, key=lambda u: u['area'])
                nm = big['name'] if len(grps) > 1 else c0['name']
                nt = (big['name_tr'] or big['name']) if len(grps) > 1 else c0['name_tr']
                provinces.append(make_province(uid(f'{a3.lower()}_{slug(nm)}'), nm, nt, grp, a3, c0))
        for cc in remote_big:
            ca = sum(u['area'] for u in cc)
            k = max(1, min(round(ca / 450000), 3, len(cc)))
            for grp in (kmeans(cc, k) if k > 1 else [cc]):
                big = max(grp, key=lambda u: u['area'])
                provinces.append(make_province(uid(f'{a3.lower()}_{slug(big["name"])}'), big['name'],
                                               big['name_tr'] or big['name'], grp, a3, c0))

    # archipelago pools: grouped into macro ocean regions by position
    def pool_group(u):
        lon, lat = u['cx'], u['cy']
        if -92 < lon < -55 and 5 < lat < 28: return 'Caribbean'
        if -50 < lon < -5 and lat > 10: return 'Atlantic'
        if -5 <= lon <= 37 and 30 < lat < 46: return 'Mediterranean'
        if 37 < lon < 110 and -50 < lat < 14: return 'Indian Ocean'
        if lat > 60: return 'Arctic'
        if 120 <= lon <= 180 and 0 <= lat <= 25: return 'Micronesia'
        if 130 <= lon <= 180 and -25 <= lat < 0: return 'Melanesia'
        if (lon <= -100 and lat < 25) or (lon >= 170 and lat < 0) or (-180 <= lon <= -140): return 'Polynesia'
        return None
    TR = {'Caribbean': 'Karayip', 'Atlantic': 'Atlantik', 'Mediterranean': 'Akdeniz', 'Indian Ocean': 'Hint Okyanusu',
          'Arctic': 'Arktik', 'Micronesia': 'Mikronezya', 'Melanesia': 'Melanezya', 'Polynesia': 'Polinezya'}
    by_g = collections.defaultdict(list)
    for u in pool:
        g = pool_group(u)
        if g:
            by_g[g].append(u)
    for g, us in sorted(by_g.items()):
        if sum(u['area'] for u in us) < 300:
            continue
        c0 = dict(continent='Oceania' if g in ('Micronesia', 'Melanesia', 'Polynesia') else countries[us[0]['adm0']]['continent'],
                  subregion=g)
        provinces.append(make_province(uid(f'isl_{slug(g)}'), g + ' Islands', TR[g] + ' Adaları', us, 'ISL_POOL', c0,
                                       extra=dict(archipelago=True)))
    by_c = collections.defaultdict(list)
    for p in provinces:
        by_c[p['adm0']].append(p)
    for a3, ps in by_c.items():
        pop = countries.get(a3, {}).get('pop', 0) or 0
        tot = sum(max(p['area'], 1) for p in ps)
        for p in ps:
            p['pop_modern'] = pop * max(p['area'], 1) / tot
    print('provinces:', len(provinces))
    cnt = collections.Counter(p['continent'] for p in provinces)
    print(cnt)
    pickle.dump(dict(provinces=provinces, countries=countries), open(OUT, 'wb'))


if __name__ == '__main__':
    main()
