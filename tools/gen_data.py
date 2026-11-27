#!/usr/bin/env python3
"""Authoring source for balance tables. Emits data/*.json (committed).

Run:  python3 tools/gen_data.py
All names are {en, tr}. Modifier keys are documented in docs/TECHNICAL_ARCHITECTURE.md (MODS).
"""
import json, os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
D = ROOT + '/data/'
os.makedirs(D, exist_ok=True)


def N(en, tr):
    return {'en': en, 'tr': tr}


def dump(name, obj):
    with open(D + name, 'w', encoding='utf-8') as f:
        json.dump(obj, f, ensure_ascii=False, indent=1, sort_keys=False)


# ---------------------------------------------------------------- units
# fire = ranged-phase power, shock = melee-phase power, def = defence, mor = morale, mv = movement points
# cost: gold + manpower (thousand men == 1 regiment) + materials; up = gold upkeep per turn; sup = food per turn
U = {}
def unit(uid, cls, en, tr, fire, shock, df, mor, mv, gold, up, sup, siege=0, tech=None, mats=None, cultures=None,
         countries=None, naval=False, cap=0, nat=None, **extra):
    U[uid] = dict(id=uid, cls=cls, name=N(en, tr), fire=fire, shock=shock, defense=df, morale=mor, move=mv,
                  cost=dict(gold=gold, manpower=0 if naval else 1.0, **(mats or {})), upkeep=round(up * 2.5, 2), supply=sup,
                  siege=siege, tech=tech, cultures=cultures or [], countries=countries or [], naval=naval,
                  transport=cap)
    U[uid].update(extra)   # workstream E: tags, year_min/year_max, tech_also, naval role, upgrades_to, approximate
# infantry
unit('spearmen', 'infantry', 'Spearmen', 'Mızraklılar', 0, 4, 5, 4, 2, 6, 0.4, 0.8)
unit('pikemen', 'infantry', 'Pikemen', 'Pikeciler', 0, 5, 8, 5, 2, 8, 0.5, 0.8, tech=['infantry_tactics', 1])
unit('musketeers', 'infantry', 'Musketeers', 'Tüfekçiler', 6, 5, 6, 6, 2, 11, 0.7, 0.9, tech=['infantry_tactics', 2], mats=dict(iron=0.3))
unit('line_infantry', 'infantry', 'Line Infantry', 'Hat Piyadesi', 9, 5, 7, 7, 2, 13, 0.8, 1.0, tech=['infantry_tactics', 3], mats=dict(iron=0.4))
unit('riflemen', 'infantry', 'Riflemen', 'Tüfekli Piyade', 14, 5, 8, 8, 2, 16, 1.0, 1.0, tech=['infantry_tactics', 4], mats=dict(iron=0.5))
# heavy infantry
unit('men_at_arms', 'heavy_infantry', 'Men-at-Arms', 'Zırhlı Piyade', 0, 7, 8, 6, 2, 12, 0.8, 0.9, mats=dict(iron=0.3))
unit('halberdiers', 'heavy_infantry', 'Halberdiers', 'Teber Piyadesi', 0, 9, 9, 6, 2, 13, 0.8, 0.9, tech=['infantry_tactics', 1], mats=dict(iron=0.3))
unit('grenadiers', 'heavy_infantry', 'Grenadiers', 'Humbaracılar', 7, 9, 9, 8, 2, 17, 1.1, 1.0, tech=['infantry_tactics', 3], mats=dict(iron=0.5))
unit('guard_infantry', 'heavy_infantry', 'Guard Infantry', 'Muhafız Piyadesi', 12, 11, 11, 10, 2, 22, 1.4, 1.0, tech=['infantry_tactics', 4], mats=dict(iron=0.6))
# archers / ranged
unit('archers', 'archers', 'Archers', 'Okçular', 5, 2, 3, 4, 2, 7, 0.4, 0.7, mats=dict(wood=0.2))
unit('crossbowmen', 'archers', 'Crossbowmen', 'Tatar Yayı Okçuları', 7, 2, 3, 5, 2, 9, 0.5, 0.7, tech=['infantry_tactics', 1], mats=dict(wood=0.2, iron=0.1))
unit('skirmishers', 'archers', 'Skirmishers', 'Avcı Tüfekçileri', 9, 3, 3, 6, 3, 11, 0.6, 0.8, tech=['infantry_tactics', 2], mats=dict(iron=0.2))
unit('sharpshooters', 'archers', 'Sharpshooters', 'Keskin Nişancılar', 15, 3, 4, 8, 3, 15, 0.9, 0.9, tech=['infantry_tactics', 4], mats=dict(iron=0.4))
# cavalry
unit('light_cavalry', 'cavalry', 'Light Cavalry', 'Hafif Süvari', 0, 6, 3, 5, 4, 10, 0.7, 1.4)
unit('hussars', 'cavalry', 'Hussars', 'Hafif Atlı Birlikleri', 2, 8, 4, 7, 4, 13, 0.9, 1.4, tech=['cavalry_doctrine', 2])
unit('lancers', 'cavalry', 'Lancers', 'Mızraklı Süvari', 3, 10, 5, 8, 4, 16, 1.0, 1.4, tech=['cavalry_doctrine', 3])
unit('mounted_rifles', 'cavalry', 'Mounted Rifles', 'Atlı Tüfekçiler', 8, 9, 6, 9, 4, 19, 1.2, 1.4, tech=['cavalry_doctrine', 4], mats=dict(iron=0.3))
# heavy cavalry
unit('knights', 'heavy_cavalry', 'Knights', 'Şövalyeler', 0, 11, 7, 7, 3, 18, 1.2, 1.5, mats=dict(iron=0.4))
unit('gendarmes', 'heavy_cavalry', 'Gendarmes', 'Jandarmalar', 1, 13, 9, 8, 3, 20, 1.3, 1.5, tech=['cavalry_doctrine', 1], mats=dict(iron=0.5))
unit('cuirassiers', 'heavy_cavalry', 'Cuirassiers', 'Zırhlı Süvari', 5, 14, 10, 9, 3, 23, 1.5, 1.5, tech=['cavalry_doctrine', 3], mats=dict(iron=0.6))
# artillery
unit('bombards', 'artillery', 'Bombards', 'Balyemez Topları', 8, 1, 2, 4, 1, 22, 1.4, 1.0, siege=3, tech=['artillery', 1], mats=dict(iron=1.0))
unit('cannons', 'artillery', 'Cannons', 'Toplar', 12, 1, 3, 5, 1, 26, 1.6, 1.0, siege=5, tech=['artillery', 2], mats=dict(iron=1.2))
unit('field_guns', 'artillery', 'Field Guns', 'Sahra Topları', 17, 1, 3, 6, 2, 30, 1.8, 1.0, siege=6, tech=['artillery', 3], mats=dict(iron=1.4))
unit('rifled_artillery', 'artillery', 'Rifled Artillery', 'Yivli Toplar', 24, 1, 4, 7, 2, 36, 2.1, 1.0, siege=9, tech=['artillery', 4], mats=dict(iron=1.8, coal=0.3))
# engineers
unit('sappers', 'engineer', 'Sappers', 'Lağımcılar', 0, 2, 4, 5, 2, 14, 0.8, 0.8, siege=4, tech=['fortification', 1], mats=dict(wood=0.3))
unit('field_engineers', 'engineer', 'Field Engineers', 'Istihkam Birlikleri', 2, 2, 5, 6, 2, 18, 1.0, 0.8, siege=8, tech=['fortification', 3], mats=dict(wood=0.3, iron=0.2))
# naval (a "regiment" here is a squadron of ships; no manpower pool drain, uses gold + wood)
unit('cog', 'naval', 'Cogs', 'Kogalar', 1, 2, 3, 4, 3, 14, 0.8, 0.5, mats=dict(wood=1.0), naval=True, cap=3)
unit('galley', 'naval', 'Galleys', 'Kadırgalar', 3, 5, 3, 5, 3, 16, 0.9, 0.5, mats=dict(wood=1.0), naval=True, cap=1)
unit('carrack', 'naval', 'Carracks', 'Karaka Gemileri', 6, 5, 5, 6, 3, 22, 1.1, 0.6, tech=['naval_warfare', 1], mats=dict(wood=1.4), naval=True, cap=4)
unit('galleon', 'naval', 'Galleons', 'Kalyonlar', 10, 6, 6, 7, 3, 28, 1.4, 0.6, tech=['naval_warfare', 2], mats=dict(wood=1.6, iron=0.3), naval=True, cap=4)
unit('ship_of_the_line', 'naval', 'Ships of the Line', 'Hat Gemileri', 16, 7, 8, 8, 3, 38, 1.9, 0.7, tech=['naval_warfare', 3], mats=dict(wood=2.0, iron=0.6), naval=True, cap=3)
unit('ironclad', 'naval', 'Ironclads', 'Zırhlılar', 24, 8, 12, 9, 4, 52, 2.6, 0.8, tech=['naval_warfare', 4], mats=dict(iron=2.0, coal=1.0), naval=True, cap=6)
# regional specials (restricted by culture / country)
unit('janissaries', 'infantry', 'Janissaries', 'Yeniçeriler', 5, 8, 8, 9, 2, 18, 1.1, 0.9, tech=['infantry_tactics', 1], cultures=['turkic'], countries=['OTT'])
unit('mamluks', 'heavy_cavalry', 'Mamluks', 'Memlükler', 3, 13, 8, 9, 3, 21, 1.4, 1.5, tech=['cavalry_doctrine', 1], cultures=['arabic'], countries=['MAM', 'EGY'])
unit('samurai', 'heavy_infantry', 'Samurai', 'Samuraylar', 4, 11, 8, 10, 2, 20, 1.3, 0.9, tech=['infantry_tactics', 1], cultures=['japonic'])
unit('longbowmen', 'archers', 'Longbowmen', 'Uzun Yay Okçuları', 9, 2, 3, 6, 2, 11, 0.6, 0.7, tech=['infantry_tactics', 1], countries=['ENG', 'GBR'], mats=dict(wood=0.3))
unit('landsknechts', 'infantry', 'Landsknechts', 'Landsknechtler', 3, 9, 8, 7, 2, 14, 0.9, 0.9, tech=['infantry_tactics', 2], countries=['HRE', 'AUS', 'GER'])
unit('tercios', 'infantry', 'Tercios', 'Tercio Piyadeleri', 8, 8, 10, 9, 2, 18, 1.1, 0.9, tech=['infantry_tactics', 2], countries=['SPA', 'HAB'])
unit('swiss_pikemen', 'infantry', 'Swiss Pikemen', 'İsviçreli Pikeciler', 0, 8, 11, 8, 2, 14, 0.8, 0.8, tech=['infantry_tactics', 1], countries=['SWI'])
unit('cossacks', 'cavalry', 'Cossacks', 'Kazaklar', 3, 8, 5, 7, 4, 12, 0.7, 1.2, tech=['cavalry_doctrine', 1], countries=['RUS', 'MOS'])
unit('horse_archers', 'cavalry', 'Horse Archers', 'Atlı Okçular', 7, 4, 3, 6, 5, 11, 0.6, 1.3, cultures=['turkic', 'sinic'])
unit('war_elephants', 'heavy_cavalry', 'War Elephants', 'Savaş Filleri', 2, 13, 8, 6, 2, 22, 1.5, 2.0, cultures=['indic'])
unit('hoplites_phalanx', 'infantry', 'Phalanx Guard', 'Falanks Muhafızları', 0, 6, 10, 7, 2, 12, 0.7, 0.8, tech=['infantry_tactics', 1], countries=['BYZ'])

# ---- workstream E (military/naval overhaul): extra units, tags, naval roles, upgrade paths ----------------------
# tags drive combat counters (pike = anti-cavalry, firearm, bow, light, mountain, bridging); naval roles drive the
# naval system: role (line/cruiser/raider/transport/galley), raid = commerce-raiding power, escort = convoy escort
# value, endurance = turns a squadron may stay away from a friendly port before attrition. year_min/year_max gate
# units to the historical period where they existed; every stat is approximate.
TAGS = {
    'spearmen': ['pike'], 'pikemen': ['pike'], 'swiss_pikemen': ['pike'], 'hoplites_phalanx': ['pike'], 'halberdiers': ['pike'],
    'musketeers': ['firearm'], 'line_infantry': ['firearm'], 'riflemen': ['firearm'], 'grenadiers': ['firearm'],
    'guard_infantry': ['firearm'], 'tercios': ['pike', 'firearm'], 'janissaries': ['firearm'], 'skirmishers': ['firearm', 'light'],
    'sharpshooters': ['firearm', 'light'], 'archers': ['bow'], 'crossbowmen': ['bow'], 'longbowmen': ['bow'], 'horse_archers': ['bow', 'light'],
    'light_cavalry': ['light'], 'hussars': ['light'], 'cossacks': ['light'], 'lancers': ['light'], 'mounted_rifles': ['firearm', 'light'],
    'landsknechts': ['pike', 'firearm'],
}
for _u, _t in TAGS.items():
    U[_u]['tags'] = _t
U['janissaries'].update(year_min=1350, year_max=1826)
U['samurai'].update(year_max=1870)
U['longbowmen'].update(year_max=1560)
unit('housecarls', 'heavy_infantry', 'Housecarls', 'Huscarllar', 0, 10, 9, 9, 2, 17, 1.3, 0.9, mats=dict(iron=0.4), countries=['ENG'],
     year_max=1100, approximate=True, tags=['axe'])
unit('sipahis', 'heavy_cavalry', 'Sipahis', 'Sipahiler', 2, 12, 7, 8, 3, 17, 1.2, 1.4, countries=['OTT'], year_max=1830,
     approximate=True, tags=['bow'])
unit('streltsy', 'infantry', 'Streltsy', 'Streltsy Tüfekçileri', 7, 6, 6, 7, 2, 13, 0.9, 0.9, tech=['infantry_tactics', 2],
     countries=['RUS', 'MOS', 'NOV'], year_min=1540, year_max=1720, approximate=True, tags=['firearm'])
unit('ashigaru', 'infantry', 'Ashigaru Arquebusiers', 'Ashigaru Arkebüzcüleri', 6, 4, 5, 6, 2, 10, 0.7, 0.8, tech=['infantry_tactics', 2],
     cultures=['japonic'], year_min=1543, year_max=1868, approximate=True, tags=['firearm'])
unit('rocket_corps', 'artillery', 'Rocket Corps', 'Roket Birliği', 13, 1, 2, 5, 2, 24, 1.5, 0.9, siege=2, tech=['artillery', 3],
     countries=['MYS', 'EIC', 'GBR', 'FRA'], year_min=1780, year_max=1870, approximate=True, mats=dict(iron=0.8))
unit('dragoons', 'cavalry', 'Dragoons', 'Dragonlar', 6, 7, 5, 7, 4, 14, 1.0, 1.3, tech=['cavalry_doctrine', 2], mats=dict(iron=0.2),
     year_min=1600, tags=['firearm'])
unit('jaegers', 'archers', 'Jaegers', 'Av Birlikleri', 12, 3, 4, 7, 3, 13, 0.8, 0.8, tech=['infantry_tactics', 3], mats=dict(iron=0.3),
     year_min=1740, tags=['firearm', 'light', 'mountain'])
unit('mountain_troops', 'infantry', 'Mountain Troops', 'Dağ Birlikleri', 11, 6, 8, 8, 3, 15, 1.0, 0.9, tech=['infantry_tactics', 4],
     mats=dict(iron=0.4), year_min=1850, tags=['firearm', 'mountain'])
unit('horse_artillery', 'artillery', 'Horse Artillery', 'Atlı Topçu', 15, 1, 3, 6, 3, 32, 2.0, 1.1, siege=4, tech=['artillery', 3],
     tech_also=['cavalry_doctrine', 2], mats=dict(iron=1.2), year_min=1790)
unit('pontonniers', 'engineer', 'Pontonniers', 'Köprücüler', 0, 2, 5, 6, 2, 16, 0.9, 0.8, siege=3, tech=['engineering', 2],
     mats=dict(wood=0.4), tags=['bridging'], year_min=1500)
# naval: role / raid / escort / blockade / endurance / draft
NAVAL = {
    'galley': dict(role='galley', raid=0.8, escort=0.6, blockade=0.9, endurance=2, rough=1.6),
    'cog': dict(role='transport', raid=0.3, escort=0.4, blockade=0.5, endurance=3, rough=1.0),
    'carrack': dict(role='line', raid=1.0, escort=1.0, blockade=1.0, endurance=4, rough=1.0),
    'galleon': dict(role='line', raid=1.2, escort=1.2, blockade=1.2, endurance=5, rough=0.9),
    'ship_of_the_line': dict(role='line', raid=0.8, escort=1.3, blockade=1.6, endurance=5, rough=0.8),
    'ironclad': dict(role='line', raid=0.7, escort=1.2, blockade=1.5, endurance=4, rough=0.7),
}
for _u, _t in NAVAL.items():
    U[_u].update(_t)
U['galley'].update(upgrades_to='carrack')
unit('dromon', 'naval', 'Dromons', 'Dromonlar', 4, 5, 3, 6, 3, 15, 0.9, 0.5, mats=dict(wood=1.0), naval=True, cap=1,
     role='galley', raid=0.8, escort=0.6, blockade=0.9, endurance=2, rough=1.6, countries=['BYZ'], year_max=1204, approximate=True)
unit('longship', 'naval', 'Longships', 'Uzun Gemiler', 2, 5, 2, 5, 4, 10, 0.7, 0.4, mats=dict(wood=0.8), naval=True, cap=2,
     role='raider', raid=1.7, escort=0.3, blockade=0.6, endurance=3, rough=1.2, countries=['NOR', 'DEN', 'SWE'], year_max=1200,
     approximate=True)
unit('xebec', 'naval', 'Xebecs', 'Şebekler', 5, 4, 3, 6, 4, 18, 1.0, 0.5, mats=dict(wood=1.0), naval=True, cap=1,
     role='raider', raid=1.9, escort=0.5, blockade=0.8, endurance=3, rough=1.1, countries=['ALG', 'TUN', 'MOR', 'OTT', 'LIB'],
     tech=['naval_warfare', 1], year_min=1500, year_max=1830, approximate=True)
unit('war_junk', 'naval', 'War Junks', 'Savaş Yelkenlileri', 5, 5, 5, 6, 3, 18, 1.0, 0.5, mats=dict(wood=1.2), naval=True, cap=3,
     role='line', raid=0.8, escort=0.9, blockade=1.0, endurance=5, rough=0.9, cultures=['sinic'], approximate=True)
unit('fluyt', 'naval', 'Fluyts', 'Fluytlar', 2, 1, 3, 4, 3, 17, 1.0, 0.4, mats=dict(wood=1.2), naval=True, cap=7,
     role='transport', raid=0.3, escort=0.3, blockade=0.5, endurance=6, rough=0.9, tech=['naval_warfare', 2], tech_also=['trade', 2],
     year_min=1590, approximate=True)
unit('frigate', 'naval', 'Frigates', 'Fırkateynler', 11, 4, 5, 7, 4, 28, 1.3, 0.6, mats=dict(wood=1.4, iron=0.3), naval=True, cap=2,
     role='cruiser', raid=2.0, escort=1.5, blockade=1.2, endurance=6, rough=0.8, tech=['naval_warfare', 3], year_min=1700, approximate=True)
unit('steam_cruiser', 'naval', 'Steam Cruisers', 'Buharlı Kruvazörler', 20, 5, 7, 8, 5, 44, 2.2, 0.8, mats=dict(iron=1.6, coal=0.8),
     naval=True, cap=2, role='cruiser', raid=2.4, escort=1.8, blockade=1.5, endurance=7, rough=0.6, tech=['naval_warfare', 4],
     tech_also=['industry', 3], year_min=1860, approximate=True)
unit('steam_transport', 'naval', 'Steam Transports', 'Buharlı Nakliye Gemileri', 2, 1, 5, 5, 4, 30, 1.2, 0.6, mats=dict(iron=1.2, coal=0.6),
     naval=True, cap=10, role='transport', raid=0.2, escort=0.2, blockade=0.5, endurance=8, rough=0.6, tech=['naval_warfare', 4],
     tech_also=['industry', 3], year_min=1850, approximate=True)
UP = {'spearmen': 'pikemen', 'pikemen': 'musketeers', 'musketeers': 'line_infantry', 'line_infantry': 'riflemen',
      'men_at_arms': 'halberdiers', 'halberdiers': 'grenadiers', 'grenadiers': 'guard_infantry',
      'archers': 'crossbowmen', 'crossbowmen': 'skirmishers', 'skirmishers': 'sharpshooters',
      'light_cavalry': 'hussars', 'hussars': 'lancers', 'lancers': 'mounted_rifles',
      'knights': 'gendarmes', 'gendarmes': 'cuirassiers',
      'bombards': 'cannons', 'cannons': 'field_guns', 'field_guns': 'rifled_artillery', 'sappers': 'field_engineers',
      'cog': 'fluyt', 'carrack': 'galleon', 'galleon': 'ship_of_the_line', 'ship_of_the_line': 'ironclad', 'frigate': 'steam_cruiser',
      'fluyt': 'steam_transport'}
for _u, _t in UP.items():
    U[_u]['upgrades_to'] = _t
dump('units.json', U)

# ---------------------------------------------------------------- doctrines (workstream E)
# Two slots per country: "land" and "naval". unlock = every [tech line, level] listed (+ optional year_min).
# mods use the national modifier keys read by Combat / MilitarySystem / NavalSystem. Every figure is a game-balance
# abstraction of the historical style it is named after, not a measured value.
DOC = {}
def doctrine(did, slot, en, tr, den, dtr, unlock, mods, year_min=None, switch=1.0):
    DOC[did] = dict(id=did, slot=slot, name=N(en, tr), desc=N(den, dtr), unlock=unlock, year_min=year_min,
                    mods=mods, switch_cost=switch)
doctrine('feudal_levy', 'land', 'Feudal Host', 'Feodal Ordu',
         'Mounted nobles and levied retinues: strong charges and cheap upkeep, poor drill and supply.',
         'Atlı soylular ve derlenen birlikler: güçlü hücum ve ucuz bakım; talim ve ikmal zayıf.',
         [], {'cav_atk': 0.12, 'morale': 0.04, 'manpower': 0.08, 'army_upkeep': -0.10, 'discipline': -0.05, 'supply': -0.05}, switch=0.6)
doctrine('fortress_defence', 'land', 'Defence in Depth', 'Derinlemesine Savunma',
         'Fortified lines and patient defence: better forts and defence, slower manoeuvre.',
         'Tahkimli hatlar ve sabırlı savunma: daha iyi kaleler ve savunma, yavaş manevra.',
         [['fortification', 1]], {'fort_def': 0.25, 'inf_def': 0.08, 'attrition': -0.05, 'move': -0.05, 'siege_def': 0.10})
doctrine('mounted_manoeuvre', 'land', 'Mounted Manoeuvre', 'Atlı Manevra',
         'Fast columns and relentless pursuit: strong cavalry, speed, river fording; weaker supply.',
         'Hızlı kollar ve amansız takip: güçlü süvari, hız, nehir geçişi; zayıf ikmal.',
         [['cavalry_doctrine', 1]], {'cav_atk': 0.15, 'move': 0.12, 'pursuit': 0.5, 'supply': -0.05, 'river_pen': -0.15})
doctrine('pike_and_shot', 'land', 'Pike and Shot', 'Pike ve Ateşli Silah',
         'Pike blocks protecting musketeers: sturdy infantry that resists cavalry.',
         'Tüfekçileri koruyan pike kareleri: süvariye direnen sağlam piyade.',
         [['infantry_tactics', 2]], {'inf_atk': 0.10, 'inf_def': 0.10, 'morale': 0.03, 'discipline': 0.04, 'anti_cav': 0.15})
doctrine('grand_battery', 'land', 'Grand Battery', 'Büyük Batarya',
         'Massed guns decide battles and sieges; the army moves slowly and costs more.',
         'Yığılmış toplar muharebe ve kuşatmaları belirler; ordu yavaş ve pahalıdır.',
         [['artillery', 2]], {'art_atk': 0.20, 'siege': 0.20, 'move': -0.06, 'army_upkeep': 0.05})
doctrine('linear_firepower', 'land', 'Linear Firepower', 'Hat Ateşi',
         'Drilled volley fire in lines: devastating firepower from disciplined troops.',
         'Hatlar halinde talimli yaylım ateşi: disiplinli birliklerden yıkıcı ateş gücü.',
         [['infantry_tactics', 3]], {'inf_atk': 0.18, 'discipline': 0.08, 'morale': 0.04, 'cav_atk': -0.04})
doctrine('corps_system', 'land', 'Corps System', 'Kolordu Sistemi',
         'Self-contained corps living off the land: mobile, balanced and hard to starve.',
         'Araziden beslenen bağımsız kolordular: hareketli, dengeli, aç bırakılması zor.',
         [['infantry_tactics', 3], ['artillery', 3], ['cavalry_doctrine', 2]],
         {'move': 0.08, 'inf_atk': 0.08, 'art_atk': 0.10, 'cav_atk': 0.08, 'supply': 0.08, 'pursuit': 0.2}, year_min=1790)
doctrine('nation_in_arms', 'land', 'Nation in Arms', 'Silahlı Millet',
         'Mass conscription and patriotic fervour: huge reserves, but less drilled troops.',
         'Kitlesel askerlik ve vatansever coşku: devasa yedekler, ama daha az talimli birlikler.',
         [['infantry_tactics', 3], ['centralization', 2]], {'manpower': 0.25, 'manpower_recovery': 0.25, 'morale': 0.06, 'army_upkeep': -0.08, 'discipline': -0.04}, year_min=1790)
doctrine('logistical_warfare', 'land', 'Logistical Warfare', 'İkmal Harbi',
         'Magazines, depots and marching schedules: armies stay fed and arrive in shape.',
         'Ambarlar, depolar ve yürüyüş çizelgeleri: ordular beslenir ve formda varır.',
         [['logistics', 2]], {'supply': 0.25, 'attrition': -0.20, 'move': 0.05, 'discipline': 0.02})
doctrine('modern_firepower', 'land', 'Rifle and Rail', 'Tüfek ve Ray',
         'Rifled weapons moved and fed by rail: the late-century standard of firepower.',
         'Raylarla taşınan ve beslenen yivli silahlar: yüzyıl sonunun ateş gücü standardı.',
         [['infantry_tactics', 4], ['logistics', 3]], {'inf_atk': 0.22, 'inf_def': 0.10, 'discipline': 0.10, 'supply': 0.15, 'art_atk': 0.10}, year_min=1840)
doctrine('sea_power', 'naval', 'Blue-Water Battle Fleet', 'Açık Deniz Muharebe Filosu',
         'Fleets of heavy ships to win the sea: stronger battle line, blockade and transport.',
         'Denizi kazanmak için ağır gemi filoları: güçlü muharebe hattı, abluka ve nakliye.',
         [['naval_warfare', 2]], {'naval_atk': 0.15, 'naval_morale': 0.05, 'blockade': 0.20, 'naval_transport': 0.10})
doctrine('commerce_raiding', 'naval', 'Guerre de Course', 'Ticaret Baskını (Guerre de Course)',
         'Fast raiders hunt enemy merchantmen instead of seeking battle: strong raiding, cheap navy.',
         'Hızlı akıncılar savaşı değil düşman tüccar gemilerini arar: güçlü baskın, ucuz donanma.',
         [['naval_warfare', 1], ['trade', 1]], {'raid': 0.35, 'naval_atk': -0.05, 'blockade': -0.10, 'navy_upkeep': -0.10})
doctrine('convoy_system', 'naval', 'Convoy System', 'Konvoy Sistemi',
         'Escorted merchant convoys: trade and transports are protected, raiders are less effective.',
         'Eskortlu ticaret konvoyları: ticaret ve nakliye korunur, akıncılar daha az etkilidir.',
         [['naval_warfare', 2], ['trade', 2]], {'convoy': 0.35, 'naval_transport': 0.20, 'raid': -0.20, 'blockade': 0.05})
doctrine('steam_battle_line', 'naval', 'Steam and Armour', 'Buhar ve Zırh',
         'Steam propulsion, armour and rifled naval guns: the industrial battle fleet.',
         'Buhar makinesi, zırh ve yivli deniz topları: sanayi çağı muharebe filosu.',
         [['naval_warfare', 4], ['industry', 3]], {'naval_atk': 0.25, 'naval_morale': 0.05, 'blockade': 0.25, 'raid': 0.15}, year_min=1850)
dump('doctrines.json', DOC)

# ---------------------------------------------------------------- technologies
# lines: id -> (branch, [(en,tr) x4], modifiers per level (list of 4 dicts), cross prerequisite for L>=2 (line, level))
LINES = {
 'infantry_tactics': ('military', 'Infantry Tactics', 'Piyade Taktikleri',
   [N('Pike Drill', 'Pike Talimi'), N('Gunpowder Infantry', 'Barutlu Piyade'), N('Linear Tactics', 'Hat Taktikleri'), N('Rifle Doctrine', 'Tüfek Doktrini')],
   {'inf_atk': 0.08, 'inf_def': 0.06}, None),
 'cavalry_doctrine': ('military', 'Cavalry Doctrine', 'Süvari Doktrini',
   [N('Stirrup Warfare', 'Üzengi Savaşı'), N('Heavy Charge', 'Ağır Hücum'), N('Light Horse Reforms', 'Hafif Atlı Reformları'), N('Mounted Rifle Corps', 'Atlı Tüfek Birlikleri')],
   {'cav_atk': 0.10, 'move': 0.04}, ('infantry_tactics', 1)),
 'artillery': ('military', 'Artillery', 'Topçuluk',
   [N('Early Bombards', 'İlk Balyemezler'), N('Cast Cannon', 'Dökme Toplar'), N('Field Artillery', 'Sahra Topçuluğu'), N('Rifled Guns', 'Yivli Toplar')],
   {'art_atk': 0.10, 'siege': 0.10}, ('fortification', 1)),
 'logistics': ('military', 'Logistics', 'Lojistik',
   [N('Supply Wagons', 'İkmal Arabaları'), N('Magazines', 'Cephanelikler'), N('Commissariat', 'İaşe Teşkilatı'), N('Railway Supply', 'Demiryolu İkmali')],
   {'supply': 0.15, 'attrition': -0.10}, ('infrastructure', 1)),
 'fortification': ('military', 'Fortification', 'Tahkimat',
   [N('Stone Keeps', 'Taş Kaleler'), N('Bastion Forts', 'Bastiyon Kaleleri'), N('Star Fortresses', 'Yıldız Kaleler'), N('Fortress Belts', 'Kale Kuşakları')],
   {'fort_def': 0.15, 'siege_def': 0.10}, None),
 'naval_warfare': ('military', 'Naval Warfare', 'Deniz Harbi',
   [N('Carracks', 'Karakalar'), N('Broadside Galleons', 'Yan Ateşli Kalyonlar'), N('Ship Squadrons', 'Hat Filoları'), N('Steam and Iron', 'Buhar ve Demir')],
   {'naval_atk': 0.12, 'naval_transport': 0.10}, ('logistics', 1)),
 'agriculture': ('economic', 'Agriculture', 'Tarım',
   [N('Heavy Plough', 'Ağır Saban'), N('Three-Field Rotation', 'Üç Tarla Sistemi'), N('Crop Rotation', 'Münavebeli Ekim'), N('Mechanised Farming', 'Makineli Tarım')],
   {'food': 0.12, 'pop_growth': 0.03}, None),
 'trade': ('economic', 'Trade', 'Ticaret',
   [N('Merchant Law', 'Tüccar Hukuku'), N('Chartered Fairs', 'Ticaret Panayırları'), N('Joint-Stock Companies', 'Anonim Şirketler'), N('Global Commerce', 'Küresel Ticaret')],
   {'trade': 0.12, 'tariff': 0.02}, ('banking', 1)),
 'banking': ('economic', 'Banking', 'Bankacılık',
   [N('Moneylenders', 'Sarraflık'), N('Banking Houses', 'Banka Evleri'), N('Central Credit', 'Merkezi Kredi'), N('Modern Finance', 'Modern Maliye')],
   {'interest': -0.12, 'credit': 0.15}, ('trade', 1)),
 'industry': ('economic', 'Industrial Production', 'Sanayi Üretimi',
   [N('Guild Workshops', 'Lonca Atölyeleri'), N('Manufactories', 'Manifaktürler'), N('Steam Power', 'Buhar Gücü'), N('Factory System', 'Fabrika Sistemi')],
   {'prod': 0.10, 'build_cost': -0.04}, ('resource_extraction', 1)),
 'infrastructure': ('economic', 'Infrastructure', 'Altyapı',
   [N('Paved Roads', 'Döşeli Yollar'), N('Bridges and Canals', 'Köprüler ve Kanallar'), N('Turnpike Network', 'Paralı Yol Ağı'), N('Railway Age', 'Demiryolu Çağı')],
   {'infra': 0.15, 'build_speed': 0.05}, None),
 'resource_extraction': ('economic', 'Resource Extraction', 'Kaynak Çıkarımı',
   [N('Deep Mining', 'Derin Madencilik'), N('Blast Furnaces', 'Yüksek Fırınlar'), N('Coal Mining', 'Kömür Madenciliği'), N('Steam Pumps', 'Buharlı Pompalar')],
   {'mine': 0.15}, None),
 'bureaucracy': ('administration', 'Bureaucracy', 'Bürokrasi',
   [N('Royal Clerks', 'Saray Katipleri'), N('Chanceries', 'Kançılaryalar'), N('Civil Service', 'Memuriyet Sistemi'), N('Ministries', 'Bakanlıklar')],
   {'admin_cap': 0.15, 'corruption': -0.08}, None),
 'taxation': ('administration', 'Taxation', 'Vergilendirme',
   [N('Tax Rolls', 'Vergi Defterleri'), N('Tax Farming', 'İltizam'), N('Fiscal Codes', 'Mali Kanunlar'), N('Income Tax', 'Gelir Vergisi')],
   {'tax': 0.10}, ('bureaucracy', 1)),
 'public_admin': ('administration', 'Public Administration', 'Kamu İdaresi',
   [N('Town Councils', 'Şehir Meclisleri'), N('Provincial Governors', 'Eyalet Valileri'), N('Prefectures', 'Valilikler'), N('Public Works Office', 'Bayındırlık İdaresi')],
   {'stability': 1, 'unrest': -0.08}, ('bureaucracy', 1)),
 'centralization': ('administration', 'Centralization', 'Merkezileşme',
   [N('Royal Prerogative', 'Hükümdar Yetkileri'), N('Standing Councils', 'Daimi Divanlar'), N('Absolutist Court', 'Mutlakiyetçi Saray'), N('National State', 'Ulus Devlet')],
   {'legit': 0.4, 'reform_cost': -0.08}, ('bureaucracy', 1)),
 'legal_reform': ('administration', 'Legal Reform', 'Hukuk Reformu',
   [N('Written Customs', 'Yazılı Örf'), N('Roman Law Revival', 'Roma Hukukunun Dirilişi'), N('Civil Codes', 'Medeni Kanunlar'), N('Constitutional Law', 'Anayasa Hukuku')],
   {'stability': 1, 'diplo': 0.08}, ('public_admin', 1)),
 'education': ('society', 'Education', 'Eğitim',
   [N('Monastic Schools', 'Manastır Okulları'), N('Universities', 'Üniversiteler'), N('Public Schools', 'Halk Okulları'), N('Mass Education', 'Kitlesel Eğitim')],
   {'research': 0.12, 'literacy': 0.03}, None),
 'medicine': ('society', 'Medicine', 'Tıp',
   [N('Hospitals', 'Hastaneler'), N('Anatomy', 'Anatomi'), N('Quarantine and Vaccination', 'Karantina ve Aşı'), N('Germ Theory', 'Mikrop Kuramı')],
   {'disease': -0.15, 'pop_growth': 0.02}, ('education', 1)),
 'printing': ('society', 'Printing', 'Matbaa',
   [N('Block Printing', 'Kalıp Baskı'), N('Movable Type', 'Hareketli Harfler'), N('Newspapers', 'Gazeteler'), N('Rotary Press', 'Döner Baskı')],
   {'literacy': 0.04, 'prestige': 0.05}, ('education', 1)),
 'engineering': ('society', 'Engineering', 'Mühendislik',
   [N('Masonry Arts', 'Duvarcılık Sanatı'), N('Surveying', 'Haritacılık'), N('Mechanics', 'Mekanik'), N('Civil Engineering', 'İnşaat Mühendisliği')],
   {'build_cost': -0.06, 'build_speed': 0.06}, ('education', 1)),
 'science': ('society', 'Scientific Development', 'Bilimsel Gelişme',
   [N('Natural Philosophy', 'Doğa Felsefesi'), N('Experimental Method', 'Deneysel Yöntem'), N('Academies of Science', 'Bilim Akademileri'), N('Research Institutes', 'Araştırma Enstitüleri')],
   {'research': 0.15}, ('printing', 1)),
 'culture': ('society', 'Cultural Advancement', 'Kültürel Gelişim',
   [N('Court Patronage', 'Saray Himayesi'), N('Renaissance Arts', 'Rönesans Sanatları'), N('National Letters', 'Ulusal Edebiyat'), N('Mass Culture', 'Kitle Kültürü')],
   {'prestige': 0.08, 'happiness': 2}, ('education', 1)),
}
BASE_COST = [0, 260, 620, 1150, 1850]
T = {}
for lid, (branch, en, tr, names, mods, cross) in LINES.items():
    for lv in range(1, 5):
        tid = f'{lid}_{lv}'
        prereq = []
        if lv > 1:
            prereq.append(f'{lid}_{lv-1}')
            if cross and lv >= 2:
                prereq.append(f'{cross[0]}_{min(lv - 1, 4) if lv > 2 else cross[1]}')
        eff = {k: round(v * (1 if lv < 4 else 1.15), 3) for k, v in mods.items()}
        T[tid] = dict(id=tid, line=lid, branch=branch, level=lv, name=names[lv - 1],
                      line_name=N(en, tr), cost_rp=BASE_COST[lv], cost_gold=int(BASE_COST[lv] * 0.25),
                      prereq=prereq, effects=eff, era=lv)
# Approximate years of first widespread use of each level of each line (era gating; see HISTORICAL_SOURCES.md, "Technology eras").
ERA_YEARS = {
 'infantry_tactics': [1000, 1450, 1690, 1850], 'cavalry_doctrine': [1000, 1250, 1700, 1860], 'artillery': [1000, 1450, 1680, 1850],
 'logistics': [1000, 1550, 1750, 1850], 'fortification': [1000, 1500, 1600, 1860], 'naval_warfare': [1000, 1450, 1690, 1840],
 'agriculture': [1000, 1100, 1700, 1850], 'trade': [1000, 1150, 1600, 1860], 'banking': [1000, 1300, 1690, 1850],
 'industry': [1000, 1500, 1770, 1860], 'infrastructure': [1000, 1500, 1750, 1830], 'resource_extraction': [1000, 1400, 1760, 1860],
 'bureaucracy': [1000, 1300, 1700, 1850], 'taxation': [1000, 1300, 1700, 1860], 'public_admin': [1000, 1400, 1790, 1860],
 'centralization': [1000, 1450, 1650, 1850], 'legal_reform': [1000, 1450, 1790, 1850], 'education': [1000, 1200, 1700, 1870],
 'medicine': [1000, 1500, 1790, 1860], 'printing': [1000, 1450, 1700, 1860], 'engineering': [1000, 1450, 1700, 1850],
 'science': [1000, 1550, 1700, 1870], 'culture': [1000, 1400, 1790, 1880],
}
for tid, t in T.items():
    t['era_year'] = ERA_YEARS[t['line']][t['level'] - 1]

# Specialisation techs: two per line. They do not raise the line level (so unit unlocks and the technological victory are
# unchanged); they add focused effects, extra prerequisites (own line level + optional cross-line level) and era years.
# (line, key, level, name, desc, era_year, effects, cross prerequisite)
SPECS = [
 ('infantry_tactics', 'a', 1, N('Militia Levies', 'Milis Seferberliği'), N('Call up village levies to swell the host.', 'Köy milislerini orduya katarak seferberlik gücünü artırır.'), 1000, {'manpower': 0.06, 'army_upkeep': -0.03}, None),
 ('infantry_tactics', 'b', 3, N('Drill Regulations', 'Talim Nizamnamesi'), N('Standard drill manuals raise discipline across the line.', 'Standart talim kılavuzları tüm hatta disiplini artırır.'), 1700, {'morale': 0.04, 'inf_def': 0.04}, None),
 ('cavalry_doctrine', 'a', 1, N('Remount Depots', 'Binek Depoları'), N('State stables keep the cavalry mounted.', 'Devlet ahırları süvarinin atsız kalmasını önler.'), 1000, {'cav_atk': 0.05, 'supply': 0.04}, None),
 ('cavalry_doctrine', 'b', 3, N('Dragoon Companies', 'Dragon Bölükleri'), N('Mounted infantry give commanders flexible striking power.', 'Atlı piyade komutanlara esnek vuruş gücü verir.'), 1650, {'move': 0.05, 'inf_atk': 0.03}, ('infantry_tactics', 2)),
 ('artillery', 'a', 2, N("Gunfounders' Guild", 'Dökümcüler Loncası'), N('Master founders cut the cost of heavy ordnance.', 'Usta dökümcüler ağır top maliyetini düşürür.'), 1480, {'recruit_cost': -0.05, 'art_atk': 0.04}, ('resource_extraction', 1)),
 ('artillery', 'b', 4, N('Counter-Battery Fire', 'Karşı Batarya Ateşi'), N('Spotting and ranging make guns decisive in siege and field.', 'Gözetleme ve nişan alma topları kuşatmada ve sahada belirleyici kılar.'), 1860, {'siege': 0.10, 'art_atk': 0.05}, None),
 ('logistics', 'a', 2, N('Military Roads', 'Askeri Yollar'), N('Dedicated roads speed the march of armies.', 'Özel yollar orduların yürüyüşünü hızlandırır.'), 1500, {'move': 0.06, 'attrition': -0.04}, ('infrastructure', 1)),
 ('logistics', 'b', 3, N('Field Hospitals', 'Sahra Hastaneleri'), N('Surgeons follow the army and save the wounded.', 'Cerrahlar orduyu izler ve yaralıları kurtarır.'), 1750, {'attrition': -0.08, 'disease': -0.05}, None),
 ('fortification', 'a', 1, N('Moats and Palisades', 'Hendekler ve Sur Kazıkları'), N('Cheap earthworks protect towns and garrisons.', 'Ucuz toprak tahkimatlar kasabaları ve garnizonları korur.'), 1000, {'fort_def': 0.05, 'build_cost': -0.02}, None),
 ('fortification', 'b', 3, N('Garrison Engineers', 'Garnizon Mühendisleri'), N('Resident engineers keep fortresses in repair and shorten sieges.', 'Yerleşik mühendisler kaleleri onarır ve kuşatmaları kısaltır.'), 1650, {'siege': 0.05, 'fort_def': 0.06}, ('engineering', 2)),
 ('naval_warfare', 'a', 2, N('Naval Ordnance', 'Deniz Topçuluğu'), N('Broadside guns standardised across the fleet.', 'Borda topları tüm donanmada standartlaştırılır.'), 1520, {'naval_atk': 0.08}, None),
 ('naval_warfare', 'b', 3, N('Merchant Convoys', 'Ticaret Konvoyları'), N('Armed convoys protect trade at sea.', 'Silahlı konvoylar deniz ticaretini korur.'), 1650, {'trade': 0.05, 'naval_transport': 0.10}, ('trade', 2)),
 ('agriculture', 'a', 1, N('Irrigation Works', 'Sulama Tesisleri'), N('Channels and wells extend fertile land.', 'Kanallar ve kuyular verimli toprağı genişletir.'), 1000, {'food': 0.05}, None),
 ('agriculture', 'b', 3, N('Selective Breeding', 'Seçici Üretim'), N('Improved livestock and seed stock raise yields.', 'Gelişmiş hayvan ve tohum ırkları verimi artırır.'), 1700, {'food': 0.08, 'pop_growth': 0.02}, ('science', 1)),
 ('trade', 'a', 1, N('Caravan Routes', 'Kervan Yolları'), N('Organised caravans link distant markets.', 'Düzenli kervanlar uzak pazarları birbirine bağlar.'), 1000, {'trade': 0.05}, None),
 ('trade', 'b', 3, N('Trade Treaty Network', 'Ticaret Antlaşmaları Ağı'), N('A web of commercial treaties lowers tariffs and builds goodwill.', 'Ticaret antlaşmaları ağı gümrükleri düşürür ve dostluk yaratır.'), 1650, {'tariff': 0.02, 'diplo': 0.05}, ('legal_reform', 1)),
 ('banking', 'a', 2, N('Bills of Exchange', 'Poliçe Sistemi'), N('Paper credit moves money without moving coin.', 'Kâğıt kredi parayı taşımadan aktarır.'), 1350, {'credit': 0.10}, None),
 ('banking', 'b', 3, N('Public Debt Office', 'Kamu Borcu İdaresi'), N('A trusted debt office lowers the price of borrowing.', 'Güvenilir bir borç idaresi borçlanma maliyetini düşürür.'), 1690, {'interest': -0.10, 'credit': 0.10}, ('taxation', 2)),
 ('industry', 'a', 2, N('Mill Power', 'Değirmen Gücü'), N('Water and wind mills multiply artisan output.', 'Su ve yel değirmenleri zanaatkâr üretimini katlar.'), 1300, {'prod': 0.06}, None),
 ('industry', 'b', 4, N('Assembly Lines', 'Montaj Hatları'), N('Division of labour in great factories puts whole districts to work.', 'Büyük fabrikalarda iş bölümü bütün mahalleleri çalıştırır.'), 1870, {'prod': 0.06, 'employment': 0.06}, ('infrastructure', 3)),
 ('infrastructure', 'a', 1, N('Corvée Roads', 'Angarya Yolları'), N('Seasonal labour repairs the roads.', 'Mevsimlik emek yolları onarır.'), 1000, {'infra': 0.06, 'build_cost': -0.02}, None),
 ('infrastructure', 'b', 3, N('Signal Posts', 'İşaret Kuleleri'), N('Optical signals carry orders across the realm.', 'Görsel işaretler emirleri ülke genelinde taşır.'), 1790, {'admin_cap': 0.04, 'move': 0.03}, ('engineering', 2)),
 ('resource_extraction', 'a', 1, N('Prospecting Charters', 'Maden Arama Ruhsatları'), N('Licensed prospectors find new veins.', 'Ruhsatlı arayıcılar yeni damarlar bulur.'), 1000, {'mine': 0.06}, None),
 ('resource_extraction', 'b', 3, N('Mining Engineers', 'Maden Mühendisleri'), N('Trained engineers drain and shore deeper shafts.', 'Eğitimli mühendisler daha derin kuyuları kurutur ve destekler.'), 1720, {'mine': 0.10, 'build_cost': -0.02}, ('engineering', 1)),
 ('bureaucracy', 'a', 1, N('Archive Reform', 'Arşiv Reformu'), N('Orderly archives make officials accountable.', 'Düzenli arşivler memurları hesap verebilir kılar.'), 1000, {'corruption': -0.05}, None),
 ('bureaucracy', 'b', 3, N('Audit Courts', 'Denetim Mahkemeleri'), N('Independent auditors catch embezzlement.', 'Bağımsız denetçiler zimmeti yakalar.'), 1650, {'corruption': -0.08, 'tax': 0.03}, ('taxation', 1)),
 ('taxation', 'a', 1, N('Customs Houses', 'Gümrük Daireleri'), N('Collectors at borders and ports tax the flow of goods.', 'Sınır ve limanlardaki tahsildarlar mal akışını vergilendirir.'), 1000, {'tariff': 0.01, 'tax': 0.03}, None),
 ('taxation', 'b', 3, N('Cadastral Survey', 'Kadastro Taraması'), N('Land is measured and every holding assessed fairly.', 'Topraklar ölçülür ve her mülk adilce değerlendirilir.'), 1700, {'tax': 0.05, 'unrest': -0.02}, ('engineering', 2)),
 ('public_admin', 'a', 1, N('Watchmen and Wardens', 'Bekçiler ve Muhafızlar'), N('Local watchmen keep order and report plots.', 'Yerel bekçiler düzeni korur ve entrikaları bildirir.'), 1000, {'unrest': -0.03, 'counter_intel': 0.10}, None),
 ('public_admin', 'b', 3, N('Secret Chancery', 'Gizli Kançılarya'), N('A secret office reads foreign letters and recruits agents.', 'Gizli bir daire yabancı mektupları okur ve ajan devşirir.'), 1550, {'spy_net': 0.10, 'counter_intel': 0.10}, None),
 ('centralization', 'a', 1, N('Royal Household Offices', 'Hanedan Saray Daireleri'), N("A disciplined household strengthens the crown's authority and trains its heirs.", 'Disiplinli bir saray teşkilatı tacın otoritesini güçlendirir ve veliahtları yetiştirir.'), 1000, {'legit': 0.1, 'heir_quality': 0.1}, None),
 ('centralization', 'b', 3, N('Court Etiquette', 'Saray Protokolü'), N('Elaborate ritual binds the great families to the court.', 'Ayrıntılı törenler büyük aileleri saraya bağlar.'), 1650, {'faction_loyalty': 0.05, 'prestige': 0.05}, None),
 ('legal_reform', 'a', 1, N('Charters of Liberties', 'Hürriyet Fermanları'), N('Written guarantees calm the privileged orders.', 'Yazılı güvenceler imtiyazlı zümreleri yatıştırır.'), 1100, {'faction_loyalty': 0.05, 'unrest': -0.02}, None),
 ('legal_reform', 'b', 3, N('Diplomatic Law', 'Diplomasi Hukuku'), N('Settled rules for envoys and treaties build trust.', 'Elçiler ve antlaşmalar için yerleşik kurallar güven yaratır.'), 1650, {'diplo': 0.10, 'legit': 0.1}, None),
 ('education', 'a', 1, N('Cathedral Schools', 'Katedral Okulları'), N('Church schools train clerks and scholars.', 'Kilise okulları katip ve âlim yetiştirir.'), 1000, {'literacy': 0.01, 'research': 0.03}, None),
 ('education', 'b', 3, N('Technical Schools', 'Teknik Okullar'), N('Practical schooling trains engineers and managers.', 'Uygulamalı eğitim mühendis ve yönetici yetiştirir.'), 1780, {'research': 0.05, 'build_speed': 0.04}, None),
 ('medicine', 'a', 1, N('Herbals and Apothecaries', 'Bitkisel İlaçlar ve Eczacılar'), N('Apothecaries spread proven remedies and tend the royal household.', 'Eczacılar denenmiş ilaçları yayar ve hanedanın sağlığına bakar.'), 1000, {'disease': -0.05, 'royal_health': 0.05}, None),
 ('medicine', 'b', 3, N('Public Sanitation', 'Kamu Sağlığı'), N('Sewers and clean water cut the toll of epidemics.', 'Kanalizasyon ve temiz su salgınların kaybını azaltır.'), 1750, {'disease': -0.10, 'pop_growth': 0.02}, None),
 ('printing', 'a', 2, N('Broadsheets and Pamphlets', 'Bildiriler ve Risaleler'), N("Cheap print carries the ruler's word to every town.", 'Ucuz basım hükümdarın sözünü her kasabaya taşır.'), 1500, {'legit': 0.1, 'literacy': 0.01}, None),
 ('printing', 'b', 3, N('Postal Service', 'Posta Teşkilatı'), N('A regular post binds the realm and carries confidential reports.', 'Düzenli posta ülkeyi birbirine bağlar ve gizli raporları taşır.'), 1650, {'admin_cap': 0.05, 'spy_net': 0.05}, None),
 ('engineering', 'a', 1, N('Guild Masons', 'Duvarcı Loncaları'), N("Masons' lodges pass on building craft.", 'Duvarcı locaları yapı sanatını aktarır.'), 1000, {'build_cost': -0.03}, None),
 ('engineering', 'b', 3, N('Canal Engineering', 'Kanal Mühendisliği'), N('Locks and cuts open new trade routes.', 'Havuzlar ve kanallar yeni ticaret yolları açar.'), 1700, {'infra': 0.08, 'trade': 0.04}, ('infrastructure', 2)),
 ('science', 'a', 1, N('Scholarly Societies', 'İlim Cemiyetleri'), N('Learned circles exchange discoveries.', 'İlim halkaları keşifleri paylaşır.'), 1400, {'research': 0.04}, None),
 ('science', 'b', 4, N('Laboratories', 'Laboratuvarlar'), N('Systematic experiment becomes routine.', 'Sistemli deney olağanlaşır.'), 1860, {'research': 0.08, 'prod': 0.03}, None),
 ('culture', 'a', 1, N('Royal Patronage of Poets', 'Şairlere Saray Himayesi'), N('Poets and chroniclers glorify the dynasty.', 'Şairler ve vakanüvisler hanedanı yüceltir.'), 1000, {'prestige': 0.06, 'happiness': 1}, None),
 ('culture', 'b', 3, N('Public Festivals', 'Halk Şenlikleri'), N('Seasonal festivals channel discontent into celebration.', 'Mevsimlik şenlikler hoşnutsuzluğu kutlamaya dönüştürür.'), 1650, {'happiness': 1, 'unrest': -0.03}, None),
]
for (line, key, lv, nm, desc, yr, eff, cross) in SPECS:
    tid = f'{line}_{key}'
    prereq = [f'{line}_{lv}']
    if cross:
        prereq.append(f'{cross[0]}_{cross[1]}')
    T[tid] = dict(id=tid, line=line, branch=LINES[line][0], level=lv, name=nm, desc=desc, line_name=N(LINES[line][1], LINES[line][2]),
                  cost_rp=int(BASE_COST[lv] * 0.7), cost_gold=int(BASE_COST[lv] * 0.7 * 0.25), prereq=prereq, effects=eff, era=lv, era_year=yr, spec=True)
dump('technologies.json', dict(lines={k: dict(branch=v[0], name=N(v[1], v[2])) for k, v in LINES.items()}, techs=T))

# ---------------------------------------------------------------- buildings
B = {}
# jobs = thousand workers employed per level (employment model, economy_depth.gd); `requires.year` = earliest year it can be built.
JOBS = {'farm': 4, 'market': 2, 'workshop': 3, 'mine': 4, 'sawmill': 3, 'port': 3, 'trading_center': 3, 'barracks': 1.5, 'fort': 1,
        'arsenal': 2, 'military_academy': 1, 'government_office': 1.5, 'court': 1, 'tax_office': 1, 'admin_center': 2, 'road': 1,
        'bridge': 0.5, 'canal': 2, 'railway': 3, 'university': 2, 'hospital': 1.5, 'cultural_institution': 1, 'religious_building': 1,
        'granary': 1, 'bank': 1.5, 'stock_exchange': 2, 'factory': 8, 'post_office': 1.5, 'intelligence_office': 0.8, 'shipyard': 3,
        'gendarmerie': 1.5}
def bld(bid, cat, en, tr, cost, time, up, maxlv, eff, req=None, slot=1):
    B[bid] = dict(id=bid, category=cat, name=N(en, tr), cost=cost, time=time, upkeep=up, max_level=maxlv,
                  effects=eff, requires=req or {}, slots=slot, jobs=JOBS.get(bid, 1))
# effects are per level (province-local unless prefixed nat_)
bld('farm', 'economic', 'Farms', 'Çiftlikler', dict(gold=30, wood=4), 2, 0.2, 3, {'food_mult': 0.15, 'pop_cap': 0.05})
bld('market', 'economic', 'Market', 'Pazar', dict(gold=45, wood=5, stone=3), 3, 0.5, 3, {'tax_mult': 0.10, 'trade_power': 1.0, 'merchant_share': 0.01})
bld('workshop', 'economic', 'Workshop', 'Atölye', dict(gold=55, wood=6, stone=4), 3, 0.7, 3, {'prod_mult': 0.15, 'artisan_share': 0.01, 'tax_mult': 0.05})
bld('mine', 'economic', 'Mine', 'Maden', dict(gold=60, wood=8, stone=4), 4, 0.8, 3, {'mine_mult': 0.35}, {'terrain': ['hills', 'mountains', 'plains', 'desert', 'steppe', 'forest']})
bld('sawmill', 'economic', 'Lumber Camp', 'Kereste Ocağı', dict(gold=30, wood=2), 2, 0.3, 3, {'wood_mult': 0.30}, {'terrain': ['forest', 'jungle', 'hills', 'mountains', 'marsh']})
bld('port', 'economic', 'Port', 'Liman', dict(gold=70, wood=10, stone=5), 4, 0.8, 3, {'trade_power': 1.5, 'naval_transport': 0.03, 'tax_mult': 0.05}, {'coastal': True})
bld('trading_center', 'economic', 'Trading Center', 'Ticaret Merkezi', dict(gold=120, wood=8, stone=8), 5, 1.4, 2, {'trade_power': 3.0, 'merchant_share': 0.02}, {'building': ['market', 1], 'min_dev': 3})
bld('barracks', 'military', 'Barracks', 'Kışla', dict(gold=50, wood=6, stone=4), 3, 0.6, 3, {'manpower_mult': 0.20, 'recruit_speed': 0.1})
bld('fort', 'military', 'Fort', 'Kale', dict(gold=80, stone=14), 4, 1.0, 4, {'fort_level': 1})
bld('arsenal', 'military', 'Arsenal', 'Cephanelik', dict(gold=90, wood=8, iron=6), 4, 1.2, 2, {'recruit_cost': -0.04, 'recruit_speed': 0.1, 'naval_transport': 0.03}, {'min_dev': 2})
bld('military_academy', 'military', 'Military Academy', 'Harp Okulu', dict(gold=110, stone=8, wood=6), 5, 1.5, 2, {'general_skill': 0.5, 'morale': 0.02}, {'min_dev': 3})
bld('government_office', 'administrative', 'Government Office', 'Hükümet Konağı', dict(gold=50, wood=5, stone=4), 3, 0.5, 3, {'admin_cap': 1.0, 'stability_local': 1})
bld('court', 'administrative', 'Court', 'Mahkeme', dict(gold=55, stone=6), 3, 0.5, 2, {'stability_local': 2, 'legit': 0.1})
bld('tax_office', 'administrative', 'Tax Office', 'Vergi Dairesi', dict(gold=60, wood=4, stone=4), 3, 0.6, 3, {'tax_mult': 0.15})
bld('admin_center', 'administrative', 'Administrative Center', 'İdari Merkez', dict(gold=140, wood=8, stone=12), 6, 1.5, 2, {'admin_cap': 3.0, 'overextension': -0.05}, {'min_dev': 4})
bld('road', 'infrastructure', 'Roads', 'Yollar', dict(gold=25, stone=4), 2, 0.2, 3, {'infra': 1, 'trade_power': 0.2})
bld('bridge', 'infrastructure', 'Bridges', 'Köprüler', dict(gold=45, stone=10, wood=4), 3, 0.3, 1, {'infra': 1, 'move_bonus': 0.25}, {'tech': ['infrastructure', 2], 'building': ['road', 1]})
bld('canal', 'infrastructure', 'Canals', 'Kanallar', dict(gold=90, stone=14, wood=6), 5, 0.6, 2, {'trade_power': 0.8, 'food_mult': 0.08}, {'tech': ['infrastructure', 2], 'terrain': ['plains', 'marsh', 'steppe']})
bld('railway', 'infrastructure', 'Railway', 'Demiryolu', dict(gold=160, iron=12, coal=6, stone=8), 5, 1.2, 2, {'infra': 2, 'trade_power': 1.0, 'move_bonus': 0.5}, {'tech': ['infrastructure', 4], 'building': ['road', 2], 'year': 1825})
bld('university', 'social', 'University', 'Üniversite', dict(gold=110, stone=10, wood=6), 5, 1.4, 3, {'research_pts': 1.2, 'literacy': 0.02}, {'tech': ['education', 1], 'min_dev': 3})
bld('hospital', 'social', 'Hospital', 'Hastane', dict(gold=65, stone=6, wood=4), 3, 0.8, 3, {'disease_resist': 0.12, 'pop_growth': 0.01}, {'tech': ['medicine', 1]})
bld('cultural_institution', 'social', 'Cultural Institution', 'Kültür Kurumu', dict(gold=90, stone=8, lux=1), 4, 1.0, 2, {'prestige': 0.15, 'happiness_local': 3}, {'tech': ['culture', 1], 'min_dev': 2})
bld('religious_building', 'social', 'Religious Building', 'Dini Yapı', dict(gold=45, stone=8), 3, 0.4, 3, {'stability_local': 1, 'clergy_share': 0.005, 'religion_unity': 0.05})
# --- v2.1 era buildings (each effect is consumed by a system; see Mods.NATIONAL and EconomyDepth)
bld('granary', 'economic', 'Granary', 'Tahıl Ambarı', dict(gold=40, wood=6, stone=2), 3, 0.3, 3, {'granary': 20, 'pop_cap': 0.03}, {'tech': ['agriculture', 1], 'min_dev': 1.5})
bld('bank', 'economic', 'Bank', 'Banka', dict(gold=120, stone=8), 5, 1.2, 2, {'tax_mult': 0.08, 'credit': 0.12, 'interest': -0.04, 'merchant_share': 0.01}, {'tech': ['banking', 1], 'building': ['market', 1], 'min_dev': 3, 'year': 1250})
bld('stock_exchange', 'economic', 'Stock Exchange', 'Borsa', dict(gold=220, stone=10, lux=1), 6, 2.2, 1, {'trade_power': 1.5, 'credit': 0.15, 'interest': -0.05, 'merchant_share': 0.02}, {'tech': ['banking', 3], 'building': ['bank', 1], 'min_dev': 5, 'year': 1600})
bld('factory', 'economic', 'Factory', 'Fabrika', dict(gold=150, iron=6, stone=6, wood=6), 5, 2.0, 3, {'prod_mult': 0.35, 'artisan_share': 0.02, 'stability_local': -1}, {'tech': ['industry', 3], 'building': ['workshop', 2], 'min_dev': 4, 'year': 1760})
bld('post_office', 'administrative', 'Post Office', 'Posta İdaresi', dict(gold=70, wood=4, stone=4), 3, 0.6, 2, {'admin_cap': 0.6, 'trade_power': 0.3, 'spy_net': 0.03}, {'tech': ['printing', 2], 'min_dev': 2.5, 'year': 1450})
bld('intelligence_office', 'administrative', 'Intelligence Office', 'İstihbarat Dairesi', dict(gold=100, stone=6), 4, 1.5, 2, {'spy_net': 0.08, 'counter_intel': 0.08}, {'tech': ['bureaucracy', 2], 'min_dev': 3})
bld('shipyard', 'military', 'Shipyard', 'Tersane', dict(gold=90, wood=14, iron=2), 4, 1.0, 2, {'naval_transport': 0.06, 'recruit_speed': 0.1, 'recruit_cost': -0.03}, {'tech': ['naval_warfare', 1], 'coastal': True, 'building': ['port', 1], 'year': 1200})
bld('gendarmerie', 'administrative', 'Gendarmerie', 'Jandarma', dict(gold=90, stone=6, iron=2), 4, 1.3, 2, {'stability_local': 2, 'counter_intel': 0.06, 'coup_guard': 0.10}, {'tech': ['public_admin', 3], 'min_dev': 3, 'year': 1790})
dump('buildings.json', B)

# ---------------------------------------------------------------- governments
G = {}
def gov(gid, en, tr, succession, mods, feats, favor, term=0, start_legit=60):
    G[gid] = dict(id=gid, name=N(en, tr), succession=succession, term_turns=term, mods=mods, features=feats,
                  class_favor=favor, legit_start=start_legit)
gov('absolute_monarchy', 'Absolute Monarchy', 'Mutlak Monarşi', 'hereditary',
    dict(tax=0.10, admin_cap=0.15, stability=0, manpower=0.05, research=-0.05, army_upkeep=0.0, unrest=-0.05, war_exhaustion=-0.10),
    ['ruler_skill_matters', 'succession_crisis'], dict(nobility=1, clergy=1, military=0, merchants=-1, peasants=0, artisans=-0), 0)
gov('constitutional_monarchy', 'Constitutional Monarchy', 'Meşruti Monarşi', 'hereditary',
    dict(tax=-0.05, stability=1, research=0.08, trade=0.05, admin_cap=0.0, war_exhaustion=0.10, unrest=-0.08),
    ['parliament', 'succession_crisis'], dict(nobility=0, merchants=1, artisans=1, peasants=0, clergy=-0, military=0), 0)
gov('republic', 'Republic', 'Cumhuriyet', 'elective',
    dict(tax=0.0, trade=0.08, research=0.05, manpower=-0.05, war_exhaustion=0.20, stability=0, unrest=-0.03),
    ['elections', 'factions_strong'], dict(merchants=1, artisans=1, peasants=1, nobility=-1, clergy=-1, military=0), 20)
gov('merchant_republic', 'Merchant Republic', 'Tüccar Cumhuriyeti', 'elective',
    dict(trade=0.25, tax=0.05, manpower=-0.25, mercenary_cost=-0.30, army_upkeep=0.05, war_exhaustion=0.25, stability=0, research=0.03),
    ['elections', 'mercenaries', 'factions_strong'], dict(merchants=2, artisans=1, nobility=-1, peasants=-1, clergy=0, military=-1), 16)
gov('empire', 'Empire', 'İmparatorluk', 'hereditary',
    dict(admin_cap=0.25, manpower=0.10, tax=0.0, overextension=-0.30, stability=0, legit_conquest=0.4, unrest=0.0, war_exhaustion=-0.05),
    ['ruler_skill_matters', 'succession_crisis', 'prestige_legit'], dict(military=1, nobility=1, clergy=0, merchants=0, peasants=-1, artisans=0), 0)
gov('tribal_confederation', 'Tribal Confederation', 'Kabile Konfederasyonu', 'elective',
    dict(manpower=0.35, recruit_cost=-0.20, tax=-0.20, admin_cap=-0.25, research=-0.20, morale=0.10, stability=0, trade=-0.15, army_upkeep=-0.15),
    ['elections', 'raiding', 'no_advanced_buildings'], dict(military=2, nobility=1, peasants=0, merchants=-1, clergy=0, artisans=-1), 24)
gov('theocracy', 'Theocracy', 'Teokrasi', 'theocratic',
    dict(stability=1, tax=0.0, research=-0.10, unrest=-0.10, prestige=0.10, religion_unity=0.15, manpower=0.0, trade=-0.05),
    ['religious_unity_matters', 'holy_war'], dict(clergy=2, peasants=0, nobility=0, merchants=-1, artisans=-1, military=0), 12)
gov('feudal_kingdom', 'Feudal Kingdom', 'Feodal Krallık', 'hereditary',
    dict(manpower=0.20, tax=-0.15, admin_cap=-0.10, army_upkeep=-0.10, recruit_cost=-0.10, stability=0, trade=-0.05, unrest=0.0),
    ['vassals', 'ruler_skill_matters', 'succession_crisis'], dict(nobility=2, clergy=1, peasants=-1, merchants=-1, military=0, artisans=0), 0)
gov('military_government', 'Military Government', 'Askeri Yönetim', 'military',
    dict(army_upkeep=-0.15, morale=0.10, manpower=0.10, stability=-1, tax=0.0, research=-0.05, war_exhaustion=-0.15, unrest=-0.02),
    ['coup_risk'], dict(military=2, nobility=0, clergy=0, peasants=-1, merchants=-1, artisans=0), 0)
# Internal-politics rules per government (factions_system.gd / gov_mechanics.gd).
# bias: multiplier on faction influence; tax_cap: highest tax rate the ruling order tolerates; corr: corruption growth per turn
# (base, per province); coup / civil: multipliers on coup and civil-war risk; transition: turns of upheaval after adopting it;
# mech: the government's distinctive mechanic (implemented in gov_mechanics.gd); land_cap: provinces it can govern without strain.
POLITICS = {
 'absolute_monarchy': dict(bias=dict(court=1.5, nobility=1.1, merchants=0.8, clergy=1.0, military=1.0, popular=0.6), tax_cap=0.60, corr=[0.10, 0.012], coup=0.6, civil=1.0, transition=6, mech='court_favour', land_cap=18),
 'constitutional_monarchy': dict(bias=dict(court=0.8, nobility=1.0, merchants=1.3, clergy=0.8, military=0.8, popular=1.2), tax_cap=0.40, corr=[0.05, 0.008], coup=0.3, civil=0.6, transition=8, mech='parliament', land_cap=20),
 'republic': dict(bias=dict(court=0.5, nobility=0.7, merchants=1.3, clergy=0.8, military=0.9, popular=1.5), tax_cap=0.45, corr=[0.06, 0.010], coup=0.8, civil=0.9, transition=8, mech='elections', land_cap=16),
 'merchant_republic': dict(bias=dict(court=0.4, nobility=0.6, merchants=1.8, clergy=0.7, military=0.5, popular=1.0), tax_cap=0.40, corr=[0.08, 0.020], coup=0.4, civil=0.7, transition=6, mech='oligarchy', land_cap=8),
 'empire': dict(bias=dict(court=1.2, nobility=1.0, merchants=0.8, clergy=0.9, military=1.3, popular=0.6), tax_cap=0.60, corr=[0.12, 0.018], coup=1.2, civil=1.3, transition=8, mech='governors', land_cap=40),
 'tribal_confederation': dict(bias=dict(court=0.3, nobility=1.2, merchants=0.4, clergy=0.7, military=1.6, popular=1.0), tax_cap=0.30, corr=[0.0, 0.0], coup=1.0, civil=1.4, transition=4, mech='clan_unity', land_cap=10),
 'theocracy': dict(bias=dict(court=0.8, nobility=0.7, merchants=0.6, clergy=1.8, military=0.8, popular=1.0), tax_cap=0.50, corr=[0.03, 0.006], coup=0.5, civil=1.0, transition=8, mech='clerical_authority', land_cap=14),
 'feudal_kingdom': dict(bias=dict(court=0.8, nobility=1.7, merchants=0.6, clergy=1.1, military=1.0, popular=0.7), tax_cap=0.35, corr=[0.07, 0.008], coup=0.7, civil=1.5, transition=8, mech='vassal_lords', land_cap=16),
 'military_government': dict(bias=dict(court=0.5, nobility=0.7, merchants=0.6, clergy=0.6, military=2.0, popular=0.5), tax_cap=0.60, corr=[0.09, 0.012], coup=1.8, civil=1.0, transition=4, mech='junta', land_cap=20),
}
for gid, pol in POLITICS.items():
    G[gid]['politics'] = pol
dump('governments.json', G)

# ---------------------------------------------------------------- reforms
R = {}
def ref(rid, en, tr, cost_admin, cost_gold, adv, dis, req=None, gov_only=None, excl=None):
    R[rid] = dict(id=rid, name=N(en, tr), cost_admin=cost_admin, cost_gold=cost_gold, advantages=adv,
                  disadvantages=dis, requires=req or {}, governments=gov_only or [], excludes=excl or [])
ref('standing_army', 'Standing Army', 'Daimi Ordu', 40, 120, {'morale': 0.10, 'manpower_recovery': 0.25}, {'army_upkeep': 0.15}, {'tech': ['infantry_tactics', 2]})
ref('conscription', 'Conscription', 'Zorunlu Askerlik', 50, 150, {'manpower': 0.30}, {'unrest': 0.06, 'peasants_sat': -6}, {'tech': ['infantry_tactics', 3]}, [], ['mercenary_contracts'])
ref('mercenary_contracts', 'Mercenary Contracts', 'Paralı Asker Sözleşmeleri', 25, 80, {'recruit_cost': -0.15, 'recruit_speed': 0.3}, {'army_upkeep': 0.20, 'morale': -0.05}, {}, [], ['conscription'])
ref('professional_officers', 'Professional Officer Corps', 'Profesyonel Subay Kadrosu', 45, 140, {'general_skill': 0.5, 'xp_gain': 0.2}, {'nobility_sat': -5}, {'tech': ['infantry_tactics', 2]})
ref('naval_doctrine', 'Naval Doctrine', 'Deniz Doktrini', 35, 100, {'naval_atk': 0.15, 'naval_transport': 0.15}, {'tax': -0.03}, {'tech': ['naval_warfare', 1]})
ref('centralization_edict', 'Centralization Edict', 'Merkezileşme Fermanı', 40, 100, {'tax': 0.10, 'admin_cap': 0.15, 'legit': 0.3}, {'nobility_sat': -8, 'unrest': 0.03}, {'tech': ['centralization', 1]}, ['absolute_monarchy', 'empire', 'feudal_kingdom', 'military_government', 'constitutional_monarchy'])
ref('parliament_charter', 'Parliament Charter', 'Meclis Beyannamesi', 35, 80, {'stability': 1, 'legit': 0.4, 'research': 0.05}, {'tax': -0.05, 'army_upkeep': 0.05}, {'tech': ['legal_reform', 1]}, ['constitutional_monarchy', 'feudal_kingdom', 'absolute_monarchy'])
ref('guild_charters', 'Guild Charters', 'Lonca Fermanları', 30, 80, {'prod': 0.10, 'artisans_sat': 6}, {'trade': -0.05, 'peasants_sat': -2}, {'tech': ['industry', 1]})
ref('free_trade_act', 'Free Trade Act', 'Serbest Ticaret Yasası', 35, 90, {'trade': 0.20, 'merchants_sat': 8}, {'tax': -0.05, 'artisans_sat': -4}, {'tech': ['trade', 2]}, [], ['mercantilism'])
ref('mercantilism', 'Mercantilism', 'Merkantilizm', 35, 90, {'tariff': 0.05, 'prod': 0.08, 'merchants_sat': 3}, {'trade': -0.05}, {'tech': ['trade', 2]}, [], ['free_trade_act'])
ref('abolish_serfdom', 'Abolish Serfdom', 'Serfliğin Kaldırılması', 45, 120, {'pop_growth': 0.05, 'tax': 0.05, 'peasants_sat': 10}, {'nobility_sat': -12, 'manpower': -0.05}, {'tech': ['legal_reform', 2]})
ref('religious_tolerance', 'Religious Tolerance', 'Dini Hoşgörü', 30, 60, {'unrest': -0.10, 'trade': 0.03}, {'clergy_sat': -8}, {'tech': ['legal_reform', 1]})
ref('state_church', 'State Church', 'Devlet Kilisesi', 30, 70, {'stability': 1, 'religion_unity': 0.15, 'clergy_sat': 8}, {'research': -0.05, 'unrest_minority': 0.10})
ref('public_education', 'Public Education Act', 'Halk Eğitimi Yasası', 45, 130, {'research': 0.15, 'literacy': 0.04}, {'tax': -0.03}, {'tech': ['education', 2]})
ref('bureaucratic_reform', 'Bureaucratic Reform', 'Bürokratik Reform', 40, 100, {'admin_cap': 0.20, 'corruption': -0.10}, {'army_upkeep': 0.05}, {'tech': ['bureaucracy', 2]})
ref('land_reform', 'Land Reform', 'Toprak Reformu', 45, 110, {'food': 0.10, 'peasants_sat': 8}, {'nobility_sat': -10, 'tax': -0.03}, {'tech': ['agriculture', 2]})
ref('war_economy', 'War Economy Act', 'Savaş Ekonomisi Yasası', 30, 60, {'recruit_cost': -0.20, 'prod_military': 0.15}, {'trade': -0.10, 'merchants_sat': -6}, {'tech': ['industry', 2]})
# v2.1 government-specific reforms. `fx` = one-off faction loyalty changes {court, nobility, merchants, clergy, military, popular}.
def ref2(rid, en, tr, cost_admin, cost_gold, adv, dis, fx, req, govs):
    ref(rid, en, tr, cost_admin, cost_gold, adv, dis, req, govs)
    R[rid]['fx'] = fx
ref2('privy_council', 'Privy Council', 'Has Divan', 40, 100, {'admin_cap': 0.06, 'corruption': -0.05}, {'army_upkeep': 0.02}, {'court': 10, 'nobility': -6}, {'tech': ['centralization', 1]}, ['absolute_monarchy', 'empire', 'feudal_kingdom'])
ref2('estates_general', 'Estates General', 'Millet Meclisi', 35, 80, {'faction_loyalty': 0.08, 'legit': 0.2}, {'tax': -0.05}, {'nobility': 12, 'clergy': 6, 'court': -6}, {'tech': ['legal_reform', 1]}, ['feudal_kingdom', 'absolute_monarchy', 'constitutional_monarchy'])
ref2('senate_reform', 'Senate Reform', 'Senato Reformu', 35, 80, {'faction_loyalty': 0.05, 'legit': 0.3}, {'war_exhaustion': 0.05}, {'popular': 8, 'merchants': 6, 'military': -6}, {'tech': ['legal_reform', 1]}, ['republic', 'merchant_republic'])
ref2('merchant_navy_act', 'Merchant Navy Act', 'Ticaret Donanması Yasası', 35, 90, {'trade': 0.10, 'naval_transport': 0.10}, {'manpower': -0.05}, {'merchants': 12, 'nobility': -6}, {'tech': ['naval_warfare', 1]}, ['merchant_republic', 'republic', 'constitutional_monarchy'])
ref2('war_council', 'War Council', 'Savaş Meclisi', 30, 70, {'morale': 0.05, 'army_upkeep': -0.05}, {'unrest': 0.02}, {'military': 12, 'popular': -6}, {}, ['tribal_confederation', 'military_government', 'empire'])
ref2('clerical_courts', 'Clerical Courts', 'Dini Mahkemeler', 30, 60, {'stability': 1, 'corruption': -0.05}, {'trade': -0.05}, {'clergy': 12, 'merchants': -8}, {}, ['theocracy'])
ref2('anti_corruption_commission', 'Anti-Corruption Commission', 'Yolsuzlukla Mücadele Komisyonu', 45, 120, {'corruption': -0.15, 'tax': 0.03}, {'faction_loyalty': -0.03}, {'court': -10, 'popular': 6}, {'tech': ['bureaucracy', 2]}, [])
dump('reforms.json', R)

# government transitions: from -> to with requirements
dump('government_transitions.json', {
    'absolute_monarchy': {'constitutional_monarchy': {'cost_admin': 80, 'stability_hit': 15, 'requires': {'tech': ['legal_reform', 3]}},
                          'empire': {'cost_admin': 60, 'stability_hit': 8, 'requires': {'provinces': 12}}},
    'feudal_kingdom': {'absolute_monarchy': {'cost_admin': 70, 'stability_hit': 12, 'requires': {'tech': ['centralization', 2]}},
                       'empire': {'cost_admin': 60, 'stability_hit': 10, 'requires': {'provinces': 12}}},
    'constitutional_monarchy': {'republic': {'cost_admin': 90, 'stability_hit': 20, 'requires': {'tech': ['legal_reform', 3]}}},
    'republic': {'merchant_republic': {'cost_admin': 40, 'stability_hit': 6, 'requires': {'tech': ['trade', 2]}},
                 'military_government': {'cost_admin': 30, 'stability_hit': 15, 'requires': {}}},
    'merchant_republic': {'republic': {'cost_admin': 40, 'stability_hit': 6, 'requires': {}}},
    'tribal_confederation': {'feudal_kingdom': {'cost_admin': 60, 'stability_hit': 10, 'requires': {'tech': ['bureaucracy', 1]}}},
    'theocracy': {'absolute_monarchy': {'cost_admin': 70, 'stability_hit': 18, 'requires': {'tech': ['centralization', 1]}}},
    'military_government': {'republic': {'cost_admin': 50, 'stability_hit': 14, 'requires': {'tech': ['legal_reform', 2]}},
                             'absolute_monarchy': {'cost_admin': 50, 'stability_hit': 10, 'requires': {}}},
    'empire': {'constitutional_monarchy': {'cost_admin': 90, 'stability_hit': 20, 'requires': {'tech': ['legal_reform', 3]}}},
})
print('units', len(U), 'techs', len(T), 'buildings', len(B), 'governments', len(G), 'reforms', len(R))
