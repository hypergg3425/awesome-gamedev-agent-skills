#!/usr/bin/env python3
"""Features (rivers, passes, straits, lakes) for the classic 410-province map -> data/map/features.json.
Rebuilds the simplified province geometry exactly like gen_map_step2.py (deterministic) and keeps only
pairs that are adjacent (or sea-linked) in data/map/provinces.json."""
import json, os, pickle, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from map600_common import *
import map600_features as feat
import gen_map_step2 as S2


def main():
    recs = json.load(open(ROOT + '/data/map/provinces.json'))
    ids = [r['id'] for r in recs]
    idx = {p: i for i, p in enumerate(ids)}
    data = pickle.load(open(CLASSIC_PKL, 'rb'))
    by = {p['id']: p for p in data['provinces']}
    geoms = snap_simplify([by[i]['geom'] for i in ids], 0.035)
    adj = {i: set(idx[a] for a in r['adj']) for i, r in enumerate(recs)}
    pairs = set((i, j) for i in adj for j in adj[i] if i < j)
    rivers = feat.load_rivers()
    fe = {'rivers': feat.river_pairs(ids, geoms, pairs, rivers)}
    fe['passes'], miss = feat.pass_pairs(ids, geoms, pairs)
    seas = set()
    for i, r in enumerate(recs):
        for s in r['sea']:
            seas.add((min(i, idx[s[0]]), max(i, idx[s[0]])))
    st = []
    for a, b, nm, nm_tr, ia, km in feat.strait_pairs(ids, geoms, adj):
        if ia or (min(a, b), max(a, b)) in seas:
            st.append([ids[a], ids[b], {'name': nm, 'name_tr': nm_tr, 'adjacent': bool(ia), 'km': km}])
    fe['straits'] = st
    lk = feat.lakes_list(ids, geoms)
    for l in lk:
        x, y = S2.proj(l['lon'], l['lat'])
        l['pos'] = [round(x, 1), round(y, 1)]
    fe['lakes'] = lk
    fe['meta'] = {'passes_unmatched': miss, 'note': 'classic 410-province map; see docs/MAP_DATA_SOURCES.md'}
    json.dump(fe, open(ROOT + '/data/map/features.json', 'w'), ensure_ascii=False, indent=0)
    print({k: len(v) for k, v in fe.items() if isinstance(v, list)})


if __name__ == '__main__':
    main()
