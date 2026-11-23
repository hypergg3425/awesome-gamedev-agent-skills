#!/usr/bin/env python3
"""List every localization key the game can ask for (literals in scripts + data-derived families)."""
import re, json, glob, os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
keys = set()
pat = re.compile(r'"([A-Z][A-Z0-9]*(?:_[A-Z0-9]+)+)"')
skip_prefix = ('res://',)
for f in glob.glob(ROOT + '/scripts/**/*.gd', recursive=True):
    src = open(f, encoding='utf-8').read()
    for m in pat.finditer(src):
        keys.add(m.group(1))
# concatenated families: "PREFIX_" + something
fam = set(re.findall(r'"([A-Z]+_)"\s*\+', open(ROOT + '/scripts/ui/campaign/panels_economy.gd').read()))
D = ROOT + '/data/'
def load(n): return json.load(open(D + n, encoding='utf-8'))
res = ['gold','food','manpower','iron','wood','stone','coal','lux','admin','prestige','production','consumption','army_supply','stock','balance','price','materials','market']
fams = {
 'RES_': [r.upper() for r in res],
 'TERRAIN_': [t.upper() for t in ['plains','hills','mountains','forest','desert','jungle','marsh','steppe','arctic']],
 'REL_': [r.upper() for r in ['catholic','orthodox','protestant','sunni','shia','jewish','buddhist','hindu','eastern_faiths','pagan','animist','tengri','shinto','secular']],
 'CULT_': [c.upper() for c in ['latin','germanic','slavic','hellenic','magyar_finnic','turkic','arabic','iranian','caucasian','indic','sinic','japonic','southeast_asian','african','native_american','latin_american','oceanian','native']],
 'CLASS_': [c.upper() for c in ['nobility','merchants','peasants','clergy','artisans','military']],
 'CLASS_WANTS_': [c.upper() for c in ['nobility','merchants','peasants','clergy','artisans','military']],
 'UCLASS_': [c.upper() for c in ['infantry','heavy_infantry','archers','cavalry','heavy_cavalry','artillery','engineer','naval']],
 'BCAT_': ['ECONOMIC','MILITARY','ADMINISTRATIVE','INFRASTRUCTURE','SOCIAL'],
 'BRANCH_': ['MILITARY','ECONOMIC','ADMINISTRATION','SOCIETY'],
 'MODE_': [m.upper() for m in ['political','terrain','economic','diplomatic','military','population','supply','trade']],
 'ACT_': [a.upper() for a in ['alliance','break_alliance','nap','defensive','access','trade','vassalize','release_vassal','guarantee','gift','improve','sanction','transfer','assist','coalition','embargo','declare_war','peace','annex_vassal']],
 'ACTD_': [a.upper() for a in ['alliance','break_alliance','nap','defensive','access','trade','vassalize','release_vassal','guarantee','gift','improve','sanction','transfer','assist','coalition','embargo','annex_vassal']],
 'CB_': ['CONQUEST','CLAIM','HOLY_WAR','CONTAINMENT','LIBERATION','RECONQUEST','COALITION'],
 'CBD_': ['CONQUEST','CLAIM','HOLY_WAR','CONTAINMENT'],
 'FEAT_': [f.upper() for g in load('governments.json').values() for f in g['features']],
 'AI_': [p.upper() for p in ['aggressive','defensive','expansionist','diplomatic','economic','opportunistic','isolationist']],
 'DIFF_': ['EASY','NORMAL','HARD','EXPERT'], 'DIFFD_': ['EASY','NORMAL','HARD','EXPERT'],
 'SEASON_': ['SPRING','SUMMER','AUTUMN','WINTER'],
 'ACH_': [a.upper() for a in ['first_conquest','great_diplomat','economic_powerhouse','military_supremacy','world_conqueror','peaceful_expansion','technological_pioneer','survived_against_all_odds']],
 'ACHD_': [a.upper() for a in ['first_conquest','great_diplomat','economic_powerhouse','military_supremacy','world_conqueror','peaceful_expansion','technological_pioneer','survived_against_all_odds']],
 'CONSENT_': ['UNKNOWN','NOT_REQUIRED','REQUIRED','OBTAINED'],
 'ADS_STATE_': ['IDLE','UNAVAILABLE','CONSENT','INITIALIZING','LOADING','LOADED','FAILED','HIDDEN'],
 'VIC_': ['TERRITORY','ECONOMIC','DIPLOMATIC','TECHNOLOGICAL'], 'VICD_': ['TERRITORY','ECONOMIC','DIPLOMATIC','TECHNOLOGICAL'],
 'END_REASON_': ['TERRITORY','ECONOMIC','DIPLOMATIC','TECHNOLOGICAL','SURVIVAL','SCORE','SCENARIO','DEFEAT'],
 'ED_MIL_': ['LOW','MEDIUM','HIGH'], 'SET_QUALITY_': ['0','1','2'], 'CS_RATING_': ['EASY','MEDIUM','HARD'],
 'FACTOR_': ['NUMBERS','GENERAL','TERRAIN','FORT','MORALE','SUPPLY','WEATHER','TECH','COMPOSITION','LUCK'],
 'UNREST_': ['TAX','STABILITY','OVEREXT','CULTURE','RELIGION','CONQUEST','HUNGER','WAR','CLASSES','BUILDINGS','GARRISON','GOV','OCCUPIED'],
 'SKILL_': ['ADM','DIP','MIL'],
 'DR_': ['OPINION','COMMON_ENEMY','RELIGION_SAME','RELIGION_DIFF','CULTURE','STRENGTH','TRUST','CLAIMS','INFAMY','PERSONALITY','TRADE_PARTNER','BORDER_FRICTION','RECENT_WAR','ALLIES','THREAT','MUTUAL_GAIN','PROTECTION','THREATENED','PAYMENT','OFFER_VALUE','INFAMY_TARGET','DISLIKE_TARGET','WARSCORE','EXHAUSTION','TERMS_COST','WAR_LENGTH'],
}
mods = set()
for g in load('governments.json').values(): mods |= set(g['mods'])
for t in load('technologies.json')['techs'].values(): mods |= set(t['effects'])
for r in load('reforms.json').values(): mods |= set(r['advantages']) | set(r['disadvantages'])
for b in load('buildings.json').values(): mods |= set(b['effects'])
fams['MOD_'] = sorted(m.upper() for m in mods) 
out = set(keys)
for p, vs in fams.items():
    for v in vs: out.add(p + v)
json.dump(sorted(out), open(__import__('os').environ.get('KEYS_JSON','/tmp/claude-0/keys.json'),'w'), indent=0)
mods_l = sorted(mods)
json.dump(mods_l, open('/tmp/claude-0/mods.json','w'))
print(len(keys), 'literal keys;', len(out), 'total')
