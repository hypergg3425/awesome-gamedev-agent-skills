#!/usr/bin/env python3
"""Validates a map set directory: python3 tools/validate_map.py [data/map600|data/map] [--parents]
Checks: unique ids, adjacency symmetric, every landmass connected (by construction) and the whole world connected
through land + sea links, sea links valid/symmetric, no tiny/degenerate provinces, names (en + tr), geometry.bin
header/size, features reference valid pairs, and (for map600) that parents.json partitions the 410 classic ids."""
import json, os, struct, sys, collections
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MIN_AREA = 1000          # km2; smaller provinces must carry an island/city reason
errors, warnings = [], []


def err(m):
    errors.append(m)


def main():
    d = sys.argv[1] if len(sys.argv) > 1 and not sys.argv[1].startswith('--') else 'data/map600'
    d = os.path.join(ROOT, d)
    recs = json.load(open(d + '/provinces.json'))
    ids = [r['id'] for r in recs]
    idset = set(ids)
    if len(idset) != len(ids):
        err('duplicate ids')
    by = {r['id']: r for r in recs}
    for r in recs:
        pid = r['id']
        if not pid.replace('_', '').isalnum() or pid != pid.lower() or not pid.isascii():
            err(f'bad id {pid}')
        if not r.get('name') or not r.get('name_tr'):
            err(f'{pid}: missing name/name_tr')
        for a in r['adj']:
            if a not in idset:
                err(f'{pid}: adj {a} unknown')
            elif pid not in by[a]['adj']:
                err(f'{pid}<->{a}: adjacency not symmetric')
        for s in r['sea']:
            if s[0] not in idset:
                err(f'{pid}: sea link {s[0]} unknown')
            elif not any(x[0] == pid and x[1] == s[1] for x in by[s[0]]['sea']):
                err(f'{pid}<->{s[0]}: sea link not symmetric')
            if s[1] not in ('strait', 'lane') or s[0] == pid:
                err(f'{pid}: bad sea link {s}')
            if not (r['coastal'] and by.get(s[0], {}).get('coastal', True)):
                err(f'{pid}->{s[0]}: sea link on non-coastal province')
        if r['area_km2'] <= 0:
            err(f'{pid}: non-positive area')
        elif r['area_km2'] < MIN_AREA and 'island' not in r.get('tags', []) and r['adm0'] != 'ISL_POOL' and r['adm0'] not in ('LUX', 'MCO', 'SMR', 'VAT', 'AND', 'LIE'):
            warnings.append(f'{pid}: small ({r["area_km2"]} km2)')
        bb = r['bbox']
        if bb[2] - bb[0] <= 0.5 or bb[3] - bb[1] <= 0.5:
            err(f'{pid}: degenerate bbox {bb}')
        if 'reason' in r and not r['reason']:
            err(f'{pid}: empty strategic reason')
    # landmass connectivity by land
    comp = collections.defaultdict(set)
    for r in recs:
        comp[r['landmass']].add(r['id'])
    for lm, members in comp.items():
        start = next(iter(members))
        seen = {start}
        st = [start]
        while st:
            u = st.pop()
            for v in by[u]['adj']:
                if v not in seen:
                    seen.add(v)
                    st.append(v)
        if seen != members:
            err(f'landmass {lm} not connected by land ({len(seen)}/{len(members)})')
    # whole world connected through land + sea
    seen = {ids[0]}
    st = [ids[0]]
    while st:
        u = st.pop()
        for v in by[u]['adj'] + [s[0] for s in by[u]['sea']]:
            if v not in seen:
                seen.add(v)
                st.append(v)
    if len(seen) != len(ids):
        err(f'world graph not connected ({len(seen)}/{len(ids)})')
    # geometry header
    gb = open(d + '/geometry.bin', 'rb').read(12)
    magic, ver, n = struct.unpack('<4sII', gb)
    if magic != b'IMPG' or ver != 1 or n != len(ids):
        err(f'geometry.bin header mismatch ({magic},{ver},{n} vs {len(ids)})')
    # features
    fp = d + '/features.json'
    if os.path.exists(fp):
        f = json.load(open(fp))
        for key in ('rivers', 'passes'):
            for a, b, meta in f.get(key, []):
                if a not in idset or b not in idset:
                    err(f'features.{key}: unknown id {a}/{b}')
                elif b not in by[a]['adj']:
                    err(f'features.{key}: {a},{b} not adjacent')
                if not meta.get('name'):
                    err(f'features.{key}: unnamed {a},{b}')
        for a, b, meta in f.get('straits', []):
            if a not in idset or b not in idset:
                err(f'features.straits: unknown id {a}/{b}')
            elif b not in by[a]['adj'] and not any(s[0] == b for s in by[a]['sea']):
                err(f'features.straits: {a},{b} neither adjacent nor sea-linked')
    else:
        err('features.json missing')
    # parents partition
    pp = d + '/parents.json'
    if os.path.exists(pp):
        parents = json.load(open(pp))
        classic = json.load(open(ROOT + '/data/map/provinces.json'))
        cids = {r['id'] for r in classic}
        if set(parents) != cids:
            err(f'parents.json keys differ from classic ids ({len(set(parents) ^ cids)} diff)')
        allkids = [k for v in parents.values() for k in v]
        if len(allkids) != len(set(allkids)):
            err('a child appears under two parents')
        if set(allkids) != idset:
            err(f'children do not cover the extended ids ({len(set(allkids) ^ idset)} diff)')
        for p, kids in parents.items():
            for k in kids:
                if by.get(k, {}).get('parent') != p:
                    err(f'{k}: parent field mismatch')
        # area partition: children sum ~ classic parent area
        carea = {r['id']: r['area_km2'] for r in classic}
        for p, kids in parents.items():
            tot = sum(by[k]['area_km2'] for k in kids if k in by)
            if abs(tot - carea[p]) > 0.06 * carea[p] + 400:
                err(f'{p}: children area {tot} vs parent {carea[p]}')
    print(f'{d}: {len(ids)} provinces, {sum(len(r["adj"]) for r in recs)//2} land edges, {sum(len(r["sea"]) for r in recs)//2} sea links, '
          f'{len(errors)} errors, {len(warnings)} warnings')
    for w in warnings[:20]:
        print('  warn', w)
    for e in errors[:60]:
        print('  ERROR', e)
    sys.exit(1 if errors else 0)


if __name__ == '__main__':
    main()
