#!/usr/bin/env python3
"""Validate scenario and event JSON without Godot.  Usage: validate_content.py [files...]"""
import json, sys, glob, fnmatch, os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
P = json.load(open(ROOT + '/data/map/provinces.json'))
PIDS = [p['id'] for p in P]
UNITS = json.load(open(ROOT + '/data/units.json'))
GOVS = json.load(open(ROOT + '/data/governments.json'))
TECHS = json.load(open(ROOT + '/data/technologies.json'))
BLD = json.load(open(ROOT + '/data/buildings.json'))
CULT = {'latin','germanic','slavic','hellenic','magyar_finnic','turkic','arabic','iranian','caucasian','indic','sinic','japonic','southeast_asian','african','native_american','latin_american','oceanian'}
REL = {'catholic','orthodox','protestant','sunni','shia','jewish','buddhist','hindu','eastern_faiths','pagan','animist','tengri','shinto','secular'}
PERS = {'aggressive','defensive','expansionist','diplomatic','economic','opportunistic','isolationist'}
CONDS = set('stability_below stability_above legitimacy_below legitimacy_above treasury_below treasury_above debt_above income_below income_above at_war not_at_war at_war_with gov_is gov_in has_tech tech_avg_above provinces_above provinces_below food_ratio_below food_stock_below religion_is culture_is flag_set flag_not_set year_at_least year_before is_player is_ai ruler_age_above ruler_skill_below ruler_skill_above prestige_above prestige_below manpower_below has_reform war_exhaustion_above season_is class_sat_below is_vassal has_vassals alliances_at_least owns_province neighbors_tag armies_at_least inflation_above bankrupt_recently heir_missing capital_coastal'.split())
PCONDS = set('unrest_above unrest_below pop_above pop_below terrain_is coastal culture_is religion_is religion_differs has_building dev_below dev_above devastation_above occupied'.split())
EFFECTS = set('gold manpower stability legitimacy prestige admin inflation debt stock set_flag clear_flag temp_mod class_sat pop_pct province_unrest province_pop_pct province_devastation province_dev add_building destroy_building ruler_skill kill_ruler spawn_rebels relation research_points add_claim trigger_event disband_pct add_regiments change_religion_province war_exhaustion reform_cost_free'.split())
CATS = {'political','succession','economic','food','diplomatic','religious','military','uprising','disaster','tech','historical'}
OBJ = {'own_provinces','own_all','provinces_count','tech_avg','treasury','survive_until','alliance_with','vassalize','destroy','capital_of','wars_won','income'}
errs = []
def E(f, m): errs.append(f'{os.path.basename(f)}: {m}')
def loc(f, v, ctx):
    if not isinstance(v, dict) or not v.get('en') or not v.get('tr'): E(f, f'{ctx}: needs en+tr')

def scen(f):
    d = json.load(open(f))
    for k in ('id','name','desc','start','countries'):
        if k not in d: E(f, f'missing {k}')
    loc(f, d.get('name'), 'name'); loc(f, d.get('desc'), 'desc'); loc(f, d.get('note'), 'note')
    owner = {}
    cs = d.get('countries', {})
    for cid, c in cs.items():
        loc(f, c.get('name'), cid + '.name')
        if c.get('gov', 'feudal_kingdom') not in GOVS: E(f, f'{cid}: bad gov {c.get("gov")}')
        if c.get('culture') and c['culture'] not in CULT: E(f, f'{cid}: bad culture')
        if c.get('religion') and c['religion'] not in REL: E(f, f'{cid}: bad religion')
        if c.get('ai') and c['ai'] not in PERS: E(f, f'{cid}: bad ai')
        if not c.get('color', '').startswith('#'): E(f, f'{cid}: color')
        if 'flag' not in c: E(f, f'{cid}: flag')
        if 'ruler' not in c: E(f, f'{cid}: ruler')
        for pat in c.get('provinces', []):
            neg = pat.startswith('-'); pat = pat.lstrip('-')
            hits = [p for p in PIDS if fnmatch.fnmatchcase(p, pat)]
            if not hits: E(f, f'{cid}: pattern matches nothing: {pat}')
            for h in hits:
                if neg:
                    if owner.get(h) == cid: owner.pop(h)
                else: owner[h] = cid
        for a in c.get('armies', []):
            if a.get('loc') not in PIDS: E(f, f'{cid}: army loc {a.get("loc")}')
            for u in a.get('units', {}):
                if u not in UNITS: E(f, f'{cid}: unit {u}')
        for u in c.get('special_units', []):
            if u not in UNITS: E(f, f'{cid}: special unit {u}')
    cnt = {}
    for p, c in owner.items(): cnt[c] = cnt.get(c, 0) + 1
    for cid, c in cs.items():
        if cnt.get(cid, 0) == 0: E(f, f'{cid}: owns no provinces')
        cap = c.get('capital')
        if cap and owner.get(cap) != cid: E(f, f'{cid}: capital {cap} not owned (owner={owner.get(cap)})')
        if not cap: E(f, f'{cid}: no capital')
    st = d.get('start', {})
    if not (isinstance(st.get('year'), int) and isinstance(st.get('month'), int) and 1 <= st['month'] <= 12): E(f, 'start needs integer year and month 1-12')
    for cid, c in cs.items():
        ru = c.get('ruler', {})
        if not ru.get('name') or not all(isinstance(ru.get(k), int) and 0 <= ru[k] <= 10 for k in ('adm', 'dip', 'mil')): E(f, f'{cid}: ruler needs name and adm/dip/mil 0-10')
        if not isinstance(ru.get('age', 35), int) or not 0 <= ru.get('age', 35) <= 110: E(f, f'{cid}: ruler age')
        h = c.get('heir')
        if h is not None and (not h.get('name') or not isinstance(h.get('age'), int)): E(f, f'{cid}: heir needs name and integer age')
        if 'approximate' in c and not isinstance(c['approximate'], bool): E(f, f'{cid}: approximate must be a boolean')
        if 'note' in c: loc(f, c['note'], cid + '.note')
    for pid, nd in d.get('province_names', {}).items():
        if pid not in PIDS: E(f, f'province_names: unknown province {pid}')
        loc(f, nd, 'province_names.' + pid)
    for cid, lst in d.get('claims', {}).items():
        if cid not in cs: E(f, f'claims: unknown country {cid}')
        for pat in lst:
            if not any(fnmatch.fnmatchcase(p, pat.lstrip('-')) for p in PIDS): E(f, f'claims.{cid}: pattern matches nothing: {pat}')
    for gl in d.get('geo_layer', []):
        if not gl.get('id') or gl.get('kind') not in ('strait', 'river', 'pass', 'fortification', 'region', 'route'): E(f, f'geo_layer {gl.get("id")}: id/kind')
        loc(f, gl.get('name'), 'geo_layer.' + str(gl.get('id'))); loc(f, gl.get('note'), 'geo_layer.note.' + str(gl.get('id')))
        for pid in gl.get('provinces', []):
            if pid not in PIDS: E(f, f'geo_layer {gl.get("id")}: unknown province {pid}')
    for k in ('religion_overrides', 'culture_overrides'):
        for val, pats in d.get(k, {}).items():
            for pat in pats:
                if not any(fnmatch.fnmatchcase(p, pat) for p in PIDS): E(f, f'{k}.{val}: pattern matches nothing: {pat}')
    r = d.get('relations', {})
    for k in ('alliances','defensive','nap','access','trade','guarantees','vassals','opinions','truces'):
        for pair in r.get(k, []):
            for x in pair[:2]:
                if x not in cs: E(f, f'relations.{k}: unknown {x}')
    for w in r.get('wars', []):
        for x in w.get('attackers', []) + w.get('defenders', []):
            if x not in cs: E(f, f'war: unknown {x}')
    for o in d.get('objectives', []):
        if o.get('type') not in OBJ: E(f, f'objective type {o.get("type")}')
        loc(f, o.get('name'), 'objective name')
    if d.get('default_player') not in cs: E(f, 'default_player not a country')
    print(f'{os.path.basename(f)}: countries={len(cs)} owned={len(owner)}/{len(PIDS)}')

def conds(f, lst, valid, ctx):
    for c in lst:
        if c.get('type') not in valid: E(f, f'{ctx}: unknown cond {c.get("type")}')

def events(f):
    arr = json.load(open(f))
    ids = set()
    for e in arr:
        i = e.get('id', '?')
        if i in ids: E(f, f'dup id {i}')
        ids.add(i)
        if e.get('category') not in CATS: E(f, f'{i}: category')
        loc(f, e.get('title'), i + '.title'); loc(f, e.get('text'), i + '.text')
        if e.get('historical') and not e.get('source'): E(f, f'{i}: historical needs source')
        t = e.get('trigger', {})
        conds(f, t.get('conds', []), CONDS, i)
        conds(f, e.get('pconds', []), PCONDS, i + '.pconds')
        ops = e.get('options', [])
        if not (2 <= len(ops) <= 4): E(f, f'{i}: needs 2-4 options')
        for o in ops:
            loc(f, o.get('name'), i + '.option')
            conds(f, o.get('requires', []), CONDS, i + '.requires')
            if not o.get('effects'): E(f, f'{i}: option {o.get("id")} has no effects')
            for ef in o.get('effects', []):
                if ef.get('type') not in EFFECTS: E(f, f'{i}: effect {ef.get("type")}')
    print(f'{os.path.basename(f)}: {len(arr)} events')

files = sys.argv[1:] or glob.glob(ROOT + '/data/scenarios/*.json') + glob.glob(ROOT + '/data/events/*.json')
for f in files:
    (scen if '/scenarios/' in f else events)(f)
for e in errs: print('ERROR', e)
print('OK' if not errs else f'{len(errs)} errors')
sys.exit(1 if errs else 0)
