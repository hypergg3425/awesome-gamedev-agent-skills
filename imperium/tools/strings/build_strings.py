# -*- coding: utf-8 -*-
import json, os, sys, subprocess
sys.path.insert(0, os.path.dirname(__file__))
from s3_misc import S
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
keys = json.load(open('/tmp/claude-0/keys.json'))
missing = [k for k in keys if k not in S]
extra = [k for k in S if k not in keys]
print('keys needed', len(keys), 'defined', len(S), 'missing', len(missing), 'extra', len(extra))
print('MISSING:', ' '.join(missing))
bad = [k for k, (en, tr) in S.items() if (not en or not tr) and k not in ('RES_FOOD_HINT', 'BRANCH_X')]
print('EMPTY:', bad)
out = {k: {"en": en, "tr": tr} for k, (en, tr) in sorted(S.items()) if en or tr}
os.makedirs(ROOT + '/data/localization', exist_ok=True)
json.dump(out, open(ROOT + '/data/localization/strings.json', 'w', encoding='utf-8'), ensure_ascii=False, indent=0)
