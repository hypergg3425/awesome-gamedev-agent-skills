#!/usr/bin/env python3
"""Writes docs/province_list_extended.txt from data/map600/provinces.json."""
import json, os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
recs = json.load(open(ROOT + '/data/map600/provinces.json'))
lines = ['# id|name|name_tr|lon|lat|culture|terrain|climate|C=coastal P=port H=hub|parent|reason  (extended map, data/map600/provinces.json)']
for r in recs:
    fl = ('C' if r['coastal'] else '') + ('P' if r.get('port') else '') + ('H' * int(r.get('hub', 0)) if r.get('hub') else '')
    lines.append('|'.join([r['id'], r['name'], r['name_tr'], str(r['lon']), str(r['lat']), r['culture'], r['terrain'], r['climate'], fl, r['parent'], r['reason']]))
open(ROOT + '/docs/province_list_extended.txt', 'w').write('\n'.join(lines) + '\n')
print(len(recs), 'provinces listed')
