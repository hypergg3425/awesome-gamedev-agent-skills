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
         countries=None, naval=False, cap=0, nat=None):
    U[uid] = dict(id=uid, cls=cls, name=N(en, tr), fire=fire, shock=shock, defense=df, morale=mor, move=mv,
                  cost=dict(gold=gold, manpower=0 if naval else 1.0, **(mats or {})), upkeep=round(up * 2.5, 2), supply=sup,
                  siege=siege, tech=tech, cultures=cultures or [], countries=countries or [], naval=naval,
                  transport=cap)
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
dump('units.json', U)

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
dump('technologies.json', dict(lines={k: dict(branch=v[0], name=N(v[1], v[2])) for k, v in LINES.items()}, techs=T))

# ---------------------------------------------------------------- buildings
B = {}
def bld(bid, cat, en, tr, cost, time, up, maxlv, eff, req=None, slot=1):
    B[bid] = dict(id=bid, category=cat, name=N(en, tr), cost=cost, time=time, upkeep=up, max_level=maxlv,
                  effects=eff, requires=req or {}, slots=slot)
# effects are per level (province-local unless prefixed nat_)
bld('farm', 'economic', 'Farms', 'Çiftlikler', dict(gold=30, wood=4), 2, 0.2, 3, {'food_mult': 0.15, 'pop_cap': 0.05})
bld('market', 'economic', 'Market', 'Pazar', dict(gold=45, wood=5, stone=3), 3, 0.5, 3, {'tax_mult': 0.10, 'trade_power': 1.0, 'merchant_share': 0.01})
bld('workshop', 'economic', 'Workshop', 'Atölye', dict(gold=55, wood=6, stone=4), 3, 0.7, 3, {'prod_mult': 0.15, 'artisan_share': 0.01, 'tax_mult': 0.05})
bld('mine', 'economic', 'Mine', 'Maden', dict(gold=60, wood=8, stone=4), 4, 0.8, 3, {'mine_mult': 0.35}, {'terrain': ['hills', 'mountains', 'plains', 'desert', 'steppe', 'forest']})
bld('sawmill', 'economic', 'Lumber Camp', 'Kereste Ocağı', dict(gold=30, wood=2), 2, 0.3, 3, {'wood_mult': 0.30}, {'terrain': ['forest', 'jungle', 'hills', 'mountains', 'marsh']})
bld('port', 'economic', 'Port', 'Liman', dict(gold=70, wood=10, stone=5), 4, 0.8, 3, {'trade_power': 1.5, 'naval_slots': 1, 'tax_mult': 0.05}, {'coastal': True})
bld('trading_center', 'economic', 'Trading Center', 'Ticaret Merkezi', dict(gold=120, wood=8, stone=8), 5, 1.4, 2, {'trade_power': 3.0, 'merchant_share': 0.02}, {'building': ['market', 1], 'min_dev': 3})
bld('barracks', 'military', 'Barracks', 'Kışla', dict(gold=50, wood=6, stone=4), 3, 0.6, 3, {'manpower_mult': 0.20, 'recruit_speed': 0.1})
bld('fort', 'military', 'Fort', 'Kale', dict(gold=80, stone=14), 4, 1.0, 4, {'fort_level': 1})
bld('arsenal', 'military', 'Arsenal', 'Cephanelik', dict(gold=90, wood=8, iron=6), 4, 1.2, 2, {'recruit_cost': -0.10, 'naval_slots': 1}, {'min_dev': 2})
bld('military_academy', 'military', 'Military Academy', 'Harp Okulu', dict(gold=110, stone=8, wood=6), 5, 1.5, 2, {'general_skill': 0.5, 'xp_gain': 0.15}, {'min_dev': 3})
bld('government_office', 'administrative', 'Government Office', 'Hükümet Konağı', dict(gold=50, wood=5, stone=4), 3, 0.5, 3, {'admin_cap': 1.0, 'stability_local': 1})
bld('court', 'administrative', 'Court', 'Mahkeme', dict(gold=55, stone=6), 3, 0.5, 2, {'stability_local': 2, 'legit': 0.1})
bld('tax_office', 'administrative', 'Tax Office', 'Vergi Dairesi', dict(gold=60, wood=4, stone=4), 3, 0.6, 3, {'tax_mult': 0.15})
bld('admin_center', 'administrative', 'Administrative Center', 'İdari Merkez', dict(gold=140, wood=8, stone=12), 6, 1.5, 2, {'admin_cap': 3.0, 'overextension': -0.05}, {'min_dev': 4})
bld('road', 'infrastructure', 'Roads', 'Yollar', dict(gold=25, stone=4), 2, 0.2, 3, {'infra': 1, 'trade_power': 0.2})
bld('bridge', 'infrastructure', 'Bridges', 'Köprüler', dict(gold=45, stone=10, wood=4), 3, 0.3, 1, {'infra': 1, 'move_bonus': 0.25}, {'tech': ['infrastructure', 2], 'building': ['road', 1]})
bld('canal', 'infrastructure', 'Canals', 'Kanallar', dict(gold=90, stone=14, wood=6), 5, 0.6, 2, {'trade_power': 0.8, 'food_mult': 0.08}, {'tech': ['infrastructure', 2], 'terrain': ['plains', 'marsh', 'steppe']})
bld('railway', 'infrastructure', 'Railway', 'Demiryolu', dict(gold=160, iron=12, coal=6, stone=8), 5, 1.2, 2, {'infra': 2, 'trade_power': 1.0, 'move_bonus': 0.5}, {'tech': ['infrastructure', 4], 'building': ['road', 2]})
bld('university', 'social', 'University', 'Üniversite', dict(gold=110, stone=10, wood=6), 5, 1.4, 3, {'research_pts': 1.2, 'literacy': 0.02}, {'tech': ['education', 1], 'min_dev': 3})
bld('hospital', 'social', 'Hospital', 'Hastane', dict(gold=65, stone=6, wood=4), 3, 0.8, 3, {'disease_resist': 0.12, 'pop_growth': 0.01}, {'tech': ['medicine', 1]})
bld('cultural_institution', 'social', 'Cultural Institution', 'Kültür Kurumu', dict(gold=90, stone=8, lux=1), 4, 1.0, 2, {'prestige': 0.15, 'happiness_local': 3}, {'tech': ['culture', 1], 'min_dev': 2})
bld('religious_building', 'social', 'Religious Building', 'Dini Yapı', dict(gold=45, stone=8), 3, 0.4, 3, {'stability_local': 1, 'clergy_share': 0.005, 'religion_unity': 0.05})
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
