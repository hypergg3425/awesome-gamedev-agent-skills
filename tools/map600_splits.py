"""Authored split table for the extended map (map600).

SPLITS maps a classic province id -> list of children (or a callable returning one).
Child = C(id, en, tr, units=[admin-1 names] | seed=(lon, lat), tag=...).
  * id None  -> the child keeps the parent's id (only for the first child, and only if the id still names it)
  * units    -> those Natural Earth admin-1 units belong to the child
  * seed     -> remaining units go to the nearest seed; a unit that contains several seeds is cut between
                them with a Voronoi diagram (approximate frontier, used for modern units that are far too
                big to be one historical region)
Every child must be a real region (historical province, river valley, mountain block, island, plain, ...);
`tag` is an optional strategic hint used for the `reason` field. Names are neutral regional names.
"""
import math, collections


def C(id, en, tr=None, **kw):
    d = dict(id=id, en=en, tr=tr or en)
    d.update(kw)
    return d


def _dist(ax, ay, bx, by):
    dx = (ax - bx) * math.cos(math.radians((ay + by) / 2))
    return math.hypot(dx, ay - by)


def explode(min_km2=15000, keep=None, rename=None):
    """Every admin-1 unit becomes a child; units smaller than min_km2 join the nearest larger unit."""
    rename = rename or {}

    def f(p, units, pieces):
        by = collections.OrderedDict()
        for pc in pieces:
            e = by.setdefault(pc['name'], dict(name=pc['name'], tr=pc['name_tr'], area=0.0, cx=0.0, cy=0.0))
            e['cx'] = (e['cx'] * e['area'] + pc['cx'] * pc['area']) / max(e['area'] + pc['area'], 1)
            e['cy'] = (e['cy'] * e['area'] + pc['cy'] * pc['area']) / max(e['area'] + pc['area'], 1)
            e['area'] += pc['area']
        big = [e for e in by.values() if e['area'] >= min_km2]
        if not big:
            big = [max(by.values(), key=lambda e: e['area'])]
        grp = {e['name']: [e['name']] for e in big}
        for e in by.values():
            if e['area'] < min_km2 and e not in big:
                t = min(big, key=lambda b: _dist(e['cx'], e['cy'], b['cx'], b['cy']))
                grp[t['name']].append(e['name'])
        kids = []
        for e in big:
            en, tr = rename.get(e['name'], (e['name'], e['tr'] or e['name']))
            kids.append(C('keep' if keep == e['name'] else _slug(en), en, tr, units=grp[e['name']]))
        if keep is None:
            return kids
        kids.sort(key=lambda k: k['id'] != 'keep')
        return kids
    return f


def auto(n, keep=False):
    """k-means the units of the parent into n regions named after their largest admin-1 unit."""
    from map600_common import kmeans

    def f(p, units, pieces):
        by = collections.OrderedDict()
        for pc in pieces:
            e = by.setdefault(pc['name'], dict(name=pc['name'], tr=pc['name_tr'], area=0.0, cx=pc['cx'], cy=pc['cy']))
            if pc['area'] > e['area']:
                e.update(cx=pc['cx'], cy=pc['cy'])
            e['area'] += pc['area']
        ents = list(by.values())
        groups = kmeans(ents, min(n, len(ents)))
        kids = []
        for g in groups:
            members = [ents[i] for i in g]
            big = max(members, key=lambda e: e['area'])
            kids.append(C(_slug(big['name']), big['name'], big['tr'] or big['name'], units=[m['name'] for m in members]))
        if keep:
            kids.sort(key=lambda k: -sum(by[u]['area'] for u in k['units']))
            kids[0]['id'] = None
        return kids
    return f


def _slug(s):
    import unicodedata, re
    s = unicodedata.normalize('NFKD', s).encode('ascii', 'ignore').decode()
    s = re.sub(r'[^a-zA-Z0-9]+', '_', s).strip('_').lower()
    return s or 'x'


def K(id, en, tr, *units, **kw):
    """Child defined by admin-1 unit names."""
    return C(id, en, tr, units=list(units), **kw)


def S(id, en, tr, lon, lat, **kw):
    """Child defined by a seed point."""
    return C(id, en, tr, seed=(lon, lat), **kw)


SPLITS = {}

# ============================================================ NORTHERN EUROPE
SPLITS.update({
    'nor_south_norway': [
        K(None, 'Eastern Norway (Oslofjord)', 'Doğu Norveç (Oslofjord)', 'Oslo', 'Akershus', 'Østfold', 'Vestfold', 'Buskerud', tag='capital hinterland'),
        K('hedmark', 'Hedmark & Glomma Valley', 'Hedmark ve Glomma Vadisi', 'Hedmark', tag='river valley'),
        K('sorlandet', 'Sørlandet & Rogaland', 'Sørlandet ve Rogaland', 'Telemark', 'Aust-Agder', 'Vest-Agder', 'Rogaland', tag='coast'),
    ],
    'nor_west_norway': [
        K(None, 'Western Norway (Fjordland)', 'Batı Norveç (Fiyortlar)', 'Hordaland', 'Sogn og Fjordane', tag='fjords'),
        K('trondelag', 'Trøndelag (Nidaros)', 'Trøndelag (Nidaros)', 'Sør-Trøndelag', tag='historic centre'),
        K('more', 'Møre & Romsdal', 'Møre ve Romsdal', 'Møre og Romsdal'),
        K('oppland', 'Oppland (Gudbrandsdal)', 'Oppland (Gudbrandsdal)', 'Oppland', tag='mountain valley'),
    ],
    'nor_north_norway': [
        K(None, 'Nordland & Namdalen', 'Nordland ve Namdalen', 'Nordland', 'Nord-Trøndelag'),
        K('troms', 'Troms', 'Troms', 'Troms'),
        K('finnmark', 'Finnmark', 'Finnmark', 'Finnmark', tag='arctic'),
        K('svalbard', 'Svalbard', 'Svalbard', 'Svalbard', tag='island'),
    ],
    'swe_svealand': [
        K(None, 'Svealand (Mälaren Valley)', 'Svealand (Mälaren Vadisi)', 'Stockholm', 'Uppsala', 'Södermanland', 'Västmanland', tag='capital hinterland'),
        K('dalarna', 'Dalarna & Gästrikland', 'Dalarna ve Gästrikland', 'Dalarna', 'Gävleborg', tag='mining'),
        K('varmland', 'Värmland & Närke', 'Värmland ve Närke', 'Värmland', 'Orebro'),
        K('ostergotland', 'Östergötland', 'Östergötland', 'Östergötland'),
    ],
    'swe_gotaland': [
        K(None, 'Västergötland & Halland', 'Västergötland ve Halland', 'Västra Götaland', 'Halland'),
        K('skane', 'Scania (Skåne) & Blekinge', 'Skåne ve Blekinge', 'Skåne', 'Blekinge', tag='strait'),
        K('smaland', 'Småland', 'Småland', 'Kalmar', 'Jönköping', 'Kronoberg', tag='forest highland'),
        K('gotland', 'Gotland', 'Gotland', 'Gotland', tag='island'),
    ],
    'swe_norrland': [
        K(None, 'Coastal Norrland', 'Kıyı Norrland', 'Västerbotten', 'Västernorrland'),
        K('norrbotten', 'Norrbotten', 'Norrbotten', 'Norrbotten', tag='arctic'),
        K('jamtland', 'Jämtland', 'Jämtland', 'Jämtland', tag='mountain'),
    ],
    'fin_south_finland': [
        K(None, 'Uusimaa & Southwest Finland', 'Uusimaa ve Güneybatı Finlandiya', 'Uusimaa', 'Finland Proper', 'Kymenlaakso', tag='capital hinterland'),
        K('hame', 'Häme (Tavastia)', 'Häme', 'Tavastia Proper', 'Päijät-Häme', 'Pirkanmaa', 'Satakunta', 'Central Finland', tag='lake plateau'),
        K('savonia', 'Karelia & Savonia', 'Karelya ve Savonya', 'North Karelia', 'South Karelia', 'Northern Savonia', 'Southern Savonia', tag='lakeland'),
        K('ostrobothnia', 'Ostrobothnia', 'Pohjanmaa', 'Ostrobothnia', 'Central Ostrobothnia', 'Southern Ostrobothnia', tag='coastal plain'),
    ],
    'fin_north_finland': [
        K(None, 'Oulu & Kainuu', 'Oulu ve Kainuu', 'Northern Ostrobothnia', 'Kainuu'),
        K('lapland', 'Lapland', 'Laponya', 'Lapland', tag='arctic'),
    ],
    'dnk_jutland': [
        K(None, 'Central Jutland', 'Orta Jutland', 'Midtjylland'),
        K('north_jutland', 'North Jutland', 'Kuzey Jutland', 'Nordjylland'),
        K('funen', 'Funen & South Jutland', 'Fyn ve Güney Jutland', 'Syddanmark', tag='strait'),
    ],
    'dnk_zealand': [
        K(None, 'Zealand', 'Zealand', 'Sjaælland', tag='strait'),
        K('copenhagen', 'Copenhagen & Bornholm', 'Kopenhag ve Bornholm', 'Hovedstaden', tag='capital hinterland'),
    ],
    'nld_frisia': [
        K(None, 'Frisia & Groningen', 'Frizya ve Groningen', 'Groningen', 'Friesland'),
        K('overijssel', 'Overijssel & Drenthe', 'Overijssel ve Drenthe', 'Overijssel', 'Drenthe', tag='river valley'),
    ],
    'nld_brabant': [
        K(None, 'Gelderland', 'Gelderland', 'Gelderland', tag='river valley'),
        K('north_brabant', 'Brabant & Limburg', 'Brabant ve Limburg', 'Noord-Brabant', 'Limburg'),
    ],
    'nld_holland': [
        K(None, 'Holland', 'Hollanda', 'Noord-Holland', 'Zuid-Holland', 'Zeeland', tag='delta'),
        K('utrecht', 'Utrecht & Flevoland', 'Utrecht ve Flevoland', 'Utrecht', 'Flevoland'),
    ],
    'bel_flanders': [
        K(None, 'Flanders', 'Flandre', 'West Flanders', 'East Flanders', tag='cloth towns'),
        K('brabant', 'Brabant (Antwerp & Brussels)', 'Brabant (Anvers ve Brüksel)', 'Antwerp', 'Flemish Brabant', 'Brussels', tag='capital hinterland'),
        K('hainaut', 'Hainaut', 'Hainaut', 'Hainaut', tag='coal'),
    ],
    'bel_wallonia': [
        K(None, 'Meuse (Liège & Namur)', 'Meuse (Liège ve Namur)', 'Namur', 'Liege', 'Walloon Brabant', tag='river valley'),
        K('ardennes', 'Ardennes (Luxembourg)', 'Ardenler (Lüksemburg)', 'Luxembourg', tag='forest highland'),
        K('limburg', 'Limburg', 'Limburg', 'Limburg'),
    ],
})

# ============================================================ GERMANY
SPLITS.update({
    'deu_bavaria': [
        S(None, 'Bavaria (Munich)', 'Bavyera (Münih)', 11.6, 48.1, tag='alpine foreland'),
        S('franconia', 'Franconia', 'Franken', 10.5, 49.6, tag='river valley'),
        S('danube_bavaria', 'Eastern Bavaria (Regensburg)', 'Doğu Bavyera (Regensburg)', 12.6, 48.9, tag='river valley'),
    ],
    'deu_brandenburg': [
        K(None, 'Brandenburg & Berlin', 'Brandenburg ve Berlin', 'Brandenburg', 'Berlin'),
        K('saxony_anhalt', 'Saxony-Anhalt (Magdeburg)', 'Saksonya-Anhalt (Magdeburg)', 'Sachsen-Anhalt', tag='river valley'),
    ],
    'deu_hesse_thuringia': [
        K(None, 'Hesse', 'Hessen', 'Hessen'),
        K('thuringia', 'Thuringia', 'Thüringen', 'Thüringen', tag='forest highland'),
    ],
    'deu_holstein': [
        S(None, 'Holstein & Hamburg', 'Holstein ve Hamburg', 10.0, 53.8, tag='trade port'),
        S('schleswig', 'Schleswig', 'Schleswig', 9.5, 54.6, tag='peninsula'),
    ],
    'deu_lower_saxony': [
        S(None, 'Lower Saxony (Hanover)', 'Aşağı Saksonya (Hannover)', 9.7, 52.4),
        S('weser_ems', 'East Frisia & Oldenburg', 'Doğu Frizya ve Oldenburg', 7.9, 53.1, tag='coast'),
        S('brunswick', 'Brunswick & Harz', 'Braunschweig ve Harz', 10.8, 51.9, tag='mountain'),
    ],
    'deu_mecklenburg': [
        S(None, 'Mecklenburg', 'Mecklenburg', 11.8, 53.6),
        S('pomerania', 'Western Pomerania', 'Batı Pomeranya', 13.6, 53.9, tag='coast'),
    ],
    'deu_rhineland': [
        K(None, 'Palatinate & Saar', 'Pfalz ve Saar', 'Rheinland-Pfalz', 'Saarland', tag='river valley'),
        S('lower_rhine', 'Cologne & Lower Rhine', 'Köln ve Aşağı Ren', 6.9, 50.9, tag='river valley'),
        S('westphalia', 'Westphalia', 'Vestfalya', 8.2, 51.8),
    ],
    'deu_swabia': [
        S(None, 'Württemberg & Swabia', 'Württemberg ve Swabia', 9.3, 48.6),
        S('baden', 'Baden (Upper Rhine)', 'Baden (Yukarı Ren)', 8.3, 48.5, tag='river valley'),
    ],
})

# ============================================================ FRANCE
SPLITS.update({
    'fra_normandy': [
        K(None, 'Lower Normandy', 'Aşağı Normandiya', 'Manche', 'Calvados', 'Orne', 'Mayenne'),
        K('upper_normandy', 'Upper Normandy (Rouen)', 'Yukarı Normandiya (Rouen)', 'Eure', 'Seine-Maritime', tag='river valley'),
    ],
    'fra_picardy': [
        K(None, 'Picardy', 'Pikardiya', 'Aisne', 'Somme', 'Oise'),
        K('flanders_artois', 'French Flanders & Artois', 'Fransız Flandre ve Artois', 'Nord', 'Pas-de-Calais', tag='cloth towns'),
    ],
    'fra_burgundy': [
        K(None, 'Burgundy', 'Burgonya', 'Côte-d\'Or', 'Saône-et-Loire', 'Nièvre', 'Yonne'),
        K('franche_comte', 'Franche-Comté', 'Franche-Comté', 'Doubs', 'Jura', 'Haute-Saône', tag='mountain'),
    ],
    'fra_loire': [
        K(None, 'Touraine, Anjou & Maine', 'Touraine, Anjou ve Maine', 'Indre-et-Loire', 'Maine-et-Loire', 'Sarthe', tag='river valley'),
        K('orleanais_berry', 'Orléanais & Berry', 'Orléanais ve Berry', 'Loir-et-Cher', 'Indre', 'Cher'),
    ],
    'fra_aquitaine': [
        K(None, 'Guyenne (Bordeaux)', 'Guyenne (Bordo)', 'Gironde', 'Dordogne', 'Lot-et-Garonne', tag='river valley'),
        K('gascony', 'Gascony & Béarn', 'Gaskonya ve Béarn', 'Pyrénées-Atlantiques', 'Hautes-Pyrénées', 'Landes', 'Gers', tag='mountain foothills'),
    ],
    'fra_languedoc': [
        K(None, 'Languedoc', 'Langedok', 'Hérault', 'Gard', 'Aude', 'Pyrénées-Orientales', tag='coast'),
        K('toulouse', 'Toulouse & Quercy', 'Toulouse ve Quercy', 'Haute-Garonne', 'Ariège', 'Tarn-et-Garonne', 'Tarn', 'Aveyron', 'Lot', tag='river valley'),
    ],
    'fra_auvergne': [
        K(None, 'Auvergne', 'Overnya', 'Puy-de-Dôme', 'Cantal', 'Haute-Loire', 'Lozère', 'Allier', tag='volcanic highland'),
        K('limousin', 'Limousin & Marche', 'Limousin ve Marche', 'Corrèze', 'Creuse', 'Loire'),
    ],
    'fra_dauphine': [
        K(None, 'Dauphiné', 'Dofine', 'Isère', 'Drôme', 'Hautes-Alpes', 'Ardèche', tag='mountain'),
        K('savoy', 'Savoy', 'Savoy', 'Savoie', 'Haute-Savoie', tag='mountain pass'),
        K('lyonnais', 'Lyonnais & Bresse', 'Lyonnais ve Bresse', 'Rhône', 'Ain', tag='river junction'),
    ],
    'fra_provence': [
        K(None, 'Provence', 'Provence', 'Bouches-du-Rhône', 'Vaucluse', 'Var', 'Alpes-de-Haute-Provence', 'Alpes-Maritimes', tag='coast'),
        K('corsica', 'Corsica', 'Korsika', 'Haute-Corse', 'Corse-du-Sud', tag='island'),
    ],
})

# ============================================================ BRITAIN
SPLITS.update({
    'gbr_wessex': [
        S(None, 'Wessex', 'Wessex', -2.2, 51.1),
        S('cornwall_devon', 'Cornwall & Devon', 'Cornwall ve Devon', -4.0, 50.5, tag='peninsula'),
    ],
    'gbr_home_counties': [
        S(None, 'London & Home Counties', 'Londra ve Çevresi', -0.2, 51.5, tag='capital hinterland'),
        S('kent_sussex', 'Kent & Sussex', 'Kent ve Sussex', 0.4, 51.0, tag='strait'),
        S('hampshire', 'Hampshire & Wight', 'Hampshire ve Wight', -1.3, 51.1, tag='naval coast'),
        S('essex', 'Essex', 'Essex', 0.5, 51.8),
    ],
    'gbr_midlands': [
        S(None, 'West Midlands (Mercia)', 'Batı Midlands (Mercia)', -2.0, 52.5),
        S('east_midlands', 'East Midlands', 'Doğu Midlands', -1.1, 52.9),
        S('merseyside', 'Merseyside & Cheshire', 'Merseyside ve Cheshire', -2.7, 53.35, tag='trade port'),
    ],
    'gbr_northumbria': [
        S(None, 'Northumbria (Tyne & Tees)', 'Northumbria (Tyne ve Tees)', -1.7, 54.9, tag='coalfield'),
        S('cumbria', 'Cumbria & the Lakes', 'Cumbria', -2.9, 54.6, tag='mountain'),
        S('yorkshire', 'Yorkshire', 'Yorkshire', -1.4, 53.9),
        S('lancashire', 'Lancashire', 'Lancashire', -2.5, 53.7, tag='industrial'),
    ],
    'gbr_east_anglia': [
        S(None, 'East Anglia', 'Doğu Anglia', 0.9, 52.5),
        S('lincolnshire', 'Lincolnshire & the Fens', 'Lincolnshire', -0.2, 53.2, tag='fenland'),
    ],
    'gbr_wales': [
        S(None, 'Mid Wales & the Marches', 'Orta Galler ve Marches', -3.4, 52.3, tag='mountain'),
        S('gwynedd', 'Gwynedd (North Wales)', 'Gwynedd (Kuzey Galler)', -3.9, 53.0, tag='mountain'),
        S('deheubarth', 'Deheubarth (South-West Wales)', 'Deheubarth (Güneybatı Galler)', -4.3, 51.9),
    ],
    'gbr_lowland_scotland': [
        S(None, 'Lothian & the Borders', 'Lothian ve Borders', -3.0, 55.85, tag='capital hinterland'),
        S('strathclyde', 'Strathclyde (Glasgow & Ayrshire)', 'Strathclyde (Glasgow)', -4.4, 55.8),
        S('galloway', 'Galloway', 'Galloway', -4.0, 55.1),
        S('argyll', 'Argyll', 'Argyll', -5.5, 56.1, tag='western coast'),
        S('tayside', 'Tayside & Fife', 'Tayside ve Fife', -3.2, 56.4),
    ],
    'gbr_highland_scotland': [
        S(None, 'Highlands', 'Yaylalar', -4.7, 57.5, tag='mountain'),
        S('grampian', 'Grampian (Aberdeen)', 'Grampian (Aberdeen)', -2.5, 57.3, tag='coast'),
        S('western_isles', 'Western Isles', 'Batı Adaları', -6.8, 57.9, tag='island'),
        S('northern_isles', 'Orkney & Shetland', 'Orkney ve Shetland', -1.8, 59.7, tag='island'),
    ],
})

# ============================================================ IBERIA
SPLITS.update({
    'esp_asturias': [
        K(None, 'Asturias', 'Asturias', 'Asturias', tag='mountain'),
        K('cantabria', 'Cantabria', 'Kantabria', 'Cantabria', tag='coast'),
        K('leon', 'León', 'León', 'León', tag='pilgrim road'),
    ],
    'esp_old_castile': [
        K(None, 'Old Castile (Burgos & Valladolid)', 'Eski Kastilya (Burgos ve Valladolid)', 'Burgos', 'Palencia', 'Valladolid', 'Segovia'),
        K('salamanca', 'Salamanca & Zamora', 'Salamanca ve Zamora', 'Salamanca', 'Zamora', 'Ávila', tag='river valley'),
    ],
    'esp_new_castile': [
        K(None, 'New Castile (Madrid & Toledo)', 'Yeni Kastilya (Madrid ve Toledo)', 'Madrid', 'Toledo', tag='capital hinterland'),
        K('alcarria', 'Alcarria & Cuenca', 'Alcarria ve Cuenca', 'Cuenca', 'Guadalajara', tag='plateau'),
        K('la_mancha', 'La Mancha', 'La Mancha', 'Ciudad Real', tag='plateau'),
    ],
    'esp_extremadura': [
        K(None, 'Upper Extremadura (Cáceres)', 'Yukarı Extremadura (Cáceres)', 'Cáceres'),
        K('badajoz', 'Lower Extremadura (Badajoz)', 'Aşağı Extremadura (Badajoz)', 'Badajoz', tag='river valley'),
        K('huelva', 'Huelva & Río Tinto', 'Huelva ve Río Tinto', 'Huelva', tag='mining'),
    ],
    'esp_andalusia': [
        K(None, 'Seville & Cádiz (Lower Guadalquivir)', 'Sevilla ve Cádiz (Aşağı Guadalquivir)', 'Sevilla', 'Cádiz', 'Ceuta', tag='river valley'),
        K('cordoba_jaen', 'Córdoba & Jaén (Upper Guadalquivir)', 'Córdoba ve Jaén', 'Córdoba', 'Jaén', tag='river valley'),
        K('granada', 'Granada & Málaga', 'Granada ve Málaga', 'Granada', 'Málaga', tag='mountain'),
        K('almeria', 'Almería', 'Almería', 'Almería', 'Melilla', tag='arid coast'),
    ],
    'esp_valencia': [
        K(None, 'Valencia & Castellón', 'Valensiya ve Castellón', 'Valencia', 'Castellón', tag='irrigated coast'),
        K('murcia', 'Murcia & Alicante', 'Murcia ve Alicante', 'Murcia', 'Alicante', 'Albacete'),
    ],
    'esp_aragon': [
        K(None, 'Aragon (Ebro Valley)', 'Aragon (Ebro Vadisi)', 'Zaragoza', 'Teruel', 'Soria', tag='river valley'),
        K('huesca', 'Upper Aragon (Huesca)', 'Yukarı Aragon (Huesca)', 'Huesca', tag='mountain'),
    ],
    'esp_catalonia': [
        K(None, 'Catalonia (Barcelona)', 'Katalonya (Barselona)', 'Barcelona', 'Tarragona', 'Gerona', tag='trade port'),
        K('lleida', 'Lleida (Segre Valley)', 'Lleida (Segre Vadisi)', 'Lérida', tag='river valley'),
        K('balearics', 'Balearic Islands', 'Balear Adaları', 'Baleares', tag='island'),
    ],
    'esp_navarre': [
        K(None, 'Navarre & Rioja', 'Navarra ve Rioja', 'Navarra', 'La Rioja', tag='river valley'),
        K('basque', 'Basque Country', 'Bask Ülkesi', 'Gipuzkoa', 'Bizkaia', 'Álava', tag='coast'),
    ],
    'prt_north_portugal': [
        K(None, 'Minho & Douro Litoral (Porto)', 'Minho ve Douro (Porto)', 'Viana do Castelo', 'Braga', 'Porto', 'Aveiro', tag='river mouth'),
        K('tras_os_montes', 'Trás-os-Montes', 'Trás-os-Montes', 'Bragança', 'Vila Real', tag='mountain'),
        K('beira', 'Beira (Coimbra & Viseu)', 'Beira (Coimbra ve Viseu)', 'Guarda', 'Viseu', 'Castelo Branco', 'Coimbra'),
    ],
    'prt_south_portugal': [
        K(None, 'Lisbon & Estremadura', 'Lizbon ve Estremadura', 'Lisboa', 'Setúbal', 'Leiria', 'Santarém', tag='capital hinterland'),
        K('alentejo', 'Alentejo', 'Alentejo', 'Évora', 'Portalegre', 'Beja', tag='plain'),
        K('algarve', 'Algarve', 'Algarve', 'Faro', tag='coast'),
    ],
})

# ============================================================ ITALY, ALPS, CENTRAL EUROPE
SPLITS.update({
    'ita_piedmont': [
        K(None, 'Piedmont', 'Piyemonte', 'Turin', 'Cuneo', 'Asti', 'Vercelli', 'Biella'),
        K('aosta', 'Aosta Valley', 'Aosta Vadisi', 'Aoste', tag='alpine pass'),
    ],
    'ita_lombardy': [
        K(None, 'Lombardy (Milan)', 'Lombardiya (Milano)', 'Milano', 'Monza e Brianza', 'Lodi', 'Pavia', 'Cremona', 'Novara', 'Varese', 'Como', 'Lecco', 'Piacenza', tag='capital hinterland'),
        K('bergamo', 'Bergamo & Brescia', 'Bergamo ve Brescia', 'Bergamo', 'Brescia'),
        K('valtellina', 'Valtellina & Lake Maggiore', 'Valtellina ve Maggiore Gölü', 'Sondrio', 'Verbano-Cusio-Ossola', tag='alpine valley'),
    ],
    'ita_veneto': [
        K(None, 'Veneto (Venice)', 'Veneto (Venedik)', 'Venezia', 'Padova', 'Rovigo', 'Treviso', 'Vicenza', 'Verona', 'Belluno', tag='trade port'),
        K('trentino', 'Trentino & South Tyrol', 'Trentino ve Güney Tirol', 'Trento', 'Bozen', tag='alpine pass'),
        K('friuli', 'Friuli & Trieste', 'Friuli ve Trieste', 'Udine', 'Gorizia', 'Trieste', 'Pordenone', tag='gateway'),
    ],
    'ita_liguria': [
        K(None, 'Liguria (Genoa)', 'Liguria (Cenova)', 'Genova', 'Savona', 'Imperia', 'La Spezia', 'Massa-Carrara', tag='trade port'),
        K('montferrat', 'Alessandria (Montferrat)', 'Alessandria (Monferrato)', 'Alessandria'),
    ],
    'ita_emilia': [
        K(None, 'Emilia', 'Emilia', 'Bologna', 'Modena', 'Reggio Emilia', 'Parma', 'Lucca', 'Mantova', tag='plain'),
        K('romagna', 'Romagna & Ferrara', 'Romagna ve Ferrara', 'Ferrara', 'Ravenna', 'Forlì-Cesena', tag='delta'),
    ],
    'ita_tuscany': [
        K(None, 'Tuscany', 'Toskana', 'Firenze', 'Pisa', 'Siena', 'Arezzo', 'Livorno', 'Pistoia', 'Prato', 'Grosseto'),
        K('marche', 'Marche', 'Marche', 'Rimini', 'Pesaro e Urbino', 'Ancona', tag='coast'),
    ],
    'ita_lazio': [
        K(None, 'Lazio & Rome', 'Lazio ve Roma', 'Roma', 'Latina', 'Frosinone', 'Viterbo', 'Rieti', tag='capital hinterland'),
        K('umbria', 'Umbria', 'Umbria', 'Perugia', 'Terni'),
        K('abruzzo', 'Abruzzo', 'Abruzzo', "L'Aquila", 'Pescara', 'Teramo', 'Macerata', 'Fermo', 'Ascoli Piceno', tag='mountain'),
    ],
    'ita_campania': [
        K(None, 'Campania (Naples)', 'Kampanya (Napoli)', 'Napoli', 'Caserta', 'Salerno', 'Benevento', 'Avellino', tag='trade port'),
        K('molise', 'Molise', 'Molise', 'Chieti', 'Campobasso', 'Isernia'),
        K('capitanata', 'Capitanata (Foggia)', 'Capitanata (Foggia)', 'Foggia', tag='plain'),
    ],
    'ita_apulia': [
        K(None, 'Apulia', 'Apulya', 'Bari', 'Barletta-Andria Trani', 'Brindisi', 'Lecce', 'Taranto', tag='coast'),
        K('basilicata', 'Basilicata', 'Basilikata', 'Matera', 'Potenza', tag='mountain'),
    ],
    'ita_sicily': [
        K(None, 'Western Sicily (Palermo)', 'Batı Sicilya (Palermo)', 'Palermo', 'Trapani', 'Agrigento', tag='island'),
        K('eastern_sicily', 'Eastern Sicily (Catania)', 'Doğu Sicilya (Katanya)', 'Messina', 'Catania', 'Siracusa', 'Ragusa', 'Enna', 'Caltanissetta', tag='island'),
    ],
    'ita_sardinia': [
        K(None, 'Southern Sardinia (Cagliari)', 'Güney Sardinya (Cagliari)', 'Cagliari', 'Carbonia-Iglesias', 'Medio Campidano', 'Oristrano', 'Ogliastra', tag='island'),
        K('northern_sardinia', 'Northern Sardinia', 'Kuzey Sardinya', 'Sassari', 'Olbia-Tempio', 'Nuoro', tag='island'),
    ],
    'che_switzerland': [
        K(None, 'Swiss Plateau', 'İsviçre Platosu', 'Bern', 'Lucerne', 'Zürich', 'Aargau', 'Solothurn', 'Zug', 'Basel-Stadt', 'Basel-Landschaft', 'Schaffhausen', 'Thurgau', tag='plateau'),
        K('romandy', 'Romandy (Geneva & Vaud)', 'Romandiya (Cenevre ve Vaud)', 'Vaud', 'Genève', 'Fribourg', 'Neuchâtel', 'Jura', tag='lake'),
        K('alpine_switzerland', 'Alpine Switzerland (Gotthard & Grisons)', 'Alp İsviçresi (Gotthard ve Graubünden)', 'Valais', 'Ticino', 'Uri', 'Graubünden', 'Glarus', 'Schwyz', 'Nidwalden', 'Obwalden', 'Sankt Gallen', 'Appenzell Ausserrhoden', 'Appenzell Innerrhoden', tag='alpine pass'),
    ],
    'aut_austria': [
        K(None, 'Lower Austria (Vienna)', 'Aşağı Avusturya (Viyana)', 'Niederösterreich', 'Wien', 'Burgenland', tag='capital hinterland'),
        K('upper_austria', 'Upper Austria', 'Yukarı Avusturya', 'Oberösterreich', tag='river valley'),
    ],
    'aut_styria': [
        K(None, 'Styria', 'Steiermark', 'Steiermark', tag='iron'),
        K('salzburg', 'Salzburg', 'Salzburg', 'Salzburg', tag='salt'),
        K('carinthia', 'Carinthia', 'Kärnten', 'Kärnten', tag='mountain'),
    ],
    'aut_tyrol': [
        K(None, 'Tyrol', 'Tirol', 'Tirol', tag='alpine pass'),
        K('vorarlberg', 'Vorarlberg', 'Vorarlberg', 'Vorarlberg', tag='alpine pass'),
    ],
    'cze_bohemia': [
        K(None, 'Bohemia (Prague)', 'Bohemya (Prag)', 'Prague', 'Středočeský', 'Královéhradecký', 'Liberecký', tag='capital hinterland'),
        K('west_bohemia', 'Western Bohemia (Plzeň)', 'Batı Bohemya (Plzeň)', 'Plzeňský', 'Karlovarský'),
        K('south_bohemia', 'Southern Bohemia', 'Güney Bohemya', 'Jihočeský'),
        K('ustecky', 'Northern Bohemia (Ústí)', 'Kuzey Bohemya (Ústí)', 'Ústecký', tag='river valley'),
    ],
    'cze_moravia': [
        K(None, 'Moravia (Brno)', 'Moravya (Brno)', 'Jihomoravský', 'Zlínský', 'Vysočina'),
        K('olomouc', 'Olomouc & Pardubice', 'Olomouc ve Pardubice', 'Olomoucký', 'Pardubický'),
        K('ostrava', 'Moravian Silesia (Ostrava)', 'Moravya Silezyası (Ostrava)', 'Moravskoslezský', tag='coalfield'),
    ],
    'svk_slovakia': [
        K(None, 'Western Slovakia (Bratislava)', 'Batı Slovakya (Bratislava)', 'Bratislavský', 'Trnavský', 'Nitriansky', 'Trenciansky', tag='river valley'),
        K('central_slovakia', 'Central Slovakia (Mining Towns)', 'Orta Slovakya (Maden Kentleri)', 'Banskobystrický', 'Žilinský', tag='mining'),
        K('eastern_slovakia', 'Eastern Slovakia (Košice)', 'Doğu Slovakya (Košice)', 'Prešov', 'Košický'),
    ],
    'hun_transdanubia': [
        S(None, 'Central Transdanubia (Balaton)', 'Orta Transdanubya (Balaton)', 18.2, 47.3, tag='lake'),
        S('west_transdanubia', 'Western Transdanubia (Győr)', 'Batı Transdanubya (Győr)', 16.9, 47.3),
        S('south_transdanubia', 'Southern Transdanubia (Pécs)', 'Güney Transdanubya (Pécs)', 18.1, 46.2),
    ],
    'hun_great_plain': [
        S(None, 'Great Plain (Szolnok)', 'Büyük Ova (Szolnok)', 20.2, 47.2, tag='plain'),
        S('pest', 'Budapest & Pest', 'Budapeşte ve Pest', 19.3, 47.45, tag='capital hinterland'),
        S('north_hungary', 'Northern Hungary (Tokaj)', 'Kuzey Macaristan (Tokaj)', 20.6, 48.1, tag='foothills'),
        S('tiszantul', 'Tiszántúl (Debrecen)', 'Tiszántúl (Debrecen)', 21.5, 47.6),
        S('south_alfold', 'Southern Alföld (Szeged)', 'Güney Alföld (Szeged)', 20.1, 46.4),
    ],
    'pol_greater_poland': [
        K(None, 'Greater Poland (Poznań)', 'Büyük Polonya (Poznań)', 'Greater Poland'),
        K('west_pomerania', 'West Pomerania (Szczecin)', 'Batı Pomeranya (Szczecin)', 'West Pomeranian', tag='river mouth'),
        K('lubusz', 'Lubusz Land', 'Lubusz Toprağı', 'Lubusz'),
    ],
    'pol_lesser_poland': [
        K(None, 'Lesser Poland (Kraków)', 'Küçük Polonya (Krakov)', 'Lesser Poland', 'Świętokrzyskie'),
        K('upper_silesia', 'Upper Silesia (Katowice)', 'Yukarı Silezya (Katowice)', 'Silesian', tag='coalfield'),
        K('subcarpathia', 'Subcarpathia (Rzeszów)', 'Karpat Eteği (Rzeszów)', 'Subcarpathian', tag='foothills'),
    ],
    'pol_masovia': [
        K(None, 'Masovia (Warsaw)', 'Mazovya (Varşova)', 'Masovian', tag='capital hinterland'),
        K('lodz', 'Łódź Land', 'Łódź Bölgesi', 'Łódź'),
    ],
    'pol_podlasie': [
        K(None, 'Podlasie & Lublin', 'Podlasie ve Lublin', 'Lublin'),
        K('podlachia', 'Podlachia (Białystok)', 'Podlasie (Białystok)', 'Podlachian', tag='forest'),
    ],
    'pol_pomerania': [
        K(None, 'Pomerelia (Gdańsk)', 'Pomerelya (Gdańsk)', 'Pomeranian', tag='trade port'),
        K('warmia_masuria', 'Warmia & Masuria', 'Ermland ve Masurya', 'Warmian-Masurian', tag='lakeland'),
        K('kuyavia', 'Kuyavia & Chełmno', 'Kuyavya ve Chełmno', 'Kuyavian-Pomeranian', tag='river valley'),
    ],
    'pol_silesia': [
        K(None, 'Lower Silesia (Wrocław)', 'Aşağı Silezya (Wrocław)', 'Lower Silesian', tag='river valley'),
        K('opole', 'Opole Silesia', 'Opole Silezyası', 'Opole'),
    ],
})

# ============================================================ BALKANS
SPLITS.update({
    'grc_morea': [
        K(None, 'Morea (Peloponnese)', 'Mora (Peloponez)', 'Peloponnisos', tag='peninsula'),
        K('attica', 'Attica', 'Attika', 'Attiki', tag='city hinterland'),
        K('sterea', 'Central Greece (Boeotia & Phocis)', 'Orta Yunanistan (Beotya ve Fokis)', 'Stereá Elláda'),
        K('achaea', 'Western Greece (Achaea & Aetolia)', 'Batı Yunanistan (Ahaya ve Aitolya)', 'Dytiki Ellada', tag='coast'),
    ],
    'grc_central_greece': [
        K(None, 'Thessaly', 'Tesalya', 'Thessalia', tag='plain'),
        K('epirus', 'Epirus', 'Epir', 'Ipeiros', tag='mountain'),
        K('west_macedonia', 'Western Macedonia', 'Batı Makedonya', 'Dytiki Makedonia', tag='mountain'),
        K('ionian', 'Ionian Islands', 'İyonya Adaları', 'Ionioi Nisoi', tag='island'),
    ],
    'grc_aegean_isles': [
        K(None, 'Southern Aegean (Cyclades & Dodecanese)', 'Güney Ege (Kiklad ve On İki Ada)', 'Notio Aigaio', tag='island'),
        K('north_aegean', 'Northern Aegean (Lesbos, Chios, Samos)', 'Kuzey Ege (Midilli, Sakız, Sisam)', 'Voreio Aigaio', tag='island'),
    ],
    'alb_albania': [
        K(None, 'Central Albania (Durrës & Tirana)', 'Orta Arnavutluk (Dıraç ve Tiran)', 'Tiranë', 'Durrës', 'Elbasan', 'Fier', 'Berat', tag='Via Egnatia coast'),
        K('north_albania', 'Northern Albania (Shkodër)', 'Kuzey Arnavutluk (İşkodra)', 'Shkodër', 'Lezhë', 'Kukës', 'Dibër', tag='mountain'),
        K('south_albania', 'Southern Albania (Vlorë & Korçë)', 'Güney Arnavutluk (Avlonya ve Görice)', 'Vlorë', 'Gjirokastër', 'Korçë', tag='mountain'),
    ],
    'mkd_north_macedonia': [
        S(None, 'Skopje & Northern Vardar', 'Üsküp ve Kuzey Vardar', 21.4, 42.0, tag='river valley'),
        S('pelagonia', 'Pelagonia & Ohrid', 'Pelagonya ve Ohri', 21.1, 41.1, tag='lake basin'),
        S('lower_vardar', 'Lower Vardar & Strumica', 'Aşağı Vardar ve Ustrumca', 22.4, 41.3, tag='river valley'),
    ],
    'kos_kosovo': [
        S(None, 'Kosovo Field (Priština)', 'Kosova Ovası (Priştine)', 21.2, 42.6, tag='plain'),
        S('dukagjin', 'Dukagjin (Prizren & Peć)', 'Dukagjin (Prizren ve İpek)', 20.5, 42.4, tag='basin'),
    ],
    'mne_montenegro': [
        S(None, 'Zeta & the Coast', 'Zeta ve Kıyı', 18.9, 42.4, tag='coast'),
        S('montenegro_highlands', 'Montenegrin Highlands', 'Karadağ Yaylaları', 19.6, 42.9, tag='mountain'),
    ],
    'bih_bosnia_and_herz': [
        S(None, 'Bosnia (Sarajevo)', 'Bosna (Saraybosna)', 18.3, 43.9, tag='mountain valley'),
        S('herzegovina', 'Herzegovina', 'Hersek', 17.8, 43.2, tag='karst'),
        S('krajina', 'Bosanska Krajina', 'Bosna Krajinası', 16.9, 44.6, tag='frontier'),
        S('posavina', 'Posavina & Tuzla', 'Posavina ve Tuzla', 18.5, 44.7, tag='river plain'),
    ],
    'srb_serbia': [
        S(None, 'Šumadija & Belgrade', 'Şumadiya ve Belgrad', 20.7, 44.2, tag='river junction'),
        S('vojvodina', 'Vojvodina (Bačka & Banat)', 'Voyvodina (Bačka ve Banat)', 20.0, 45.7, tag='plain'),
        S('raska', 'Raška & Zlatibor', 'Raşka ve Zlatibor', 20.0, 43.4, tag='mountain'),
        S('nis', 'Niš & South Morava', 'Niş ve Güney Morava', 21.9, 43.2, tag='river valley'),
        S('timok', 'Timok & Iron Gates', 'Timok ve Demirkapı', 22.1, 44.0, tag='river gorge'),
    ],
    'hrv_croatia': [
        K(None, 'Zagreb & Zagorje', 'Zagreb ve Zagorje', 'Grad Zagreb', 'Zagrebacka', 'Krapinsko-Zagorska', 'Varaždinska', 'Medimurska', 'Koprivničko-Križevačka', tag='capital hinterland'),
        K('slavonia', 'Slavonia', 'Slavonya', 'Osjecko-Baranjska', 'Vukovarsko-Srijemska', 'Brodsko-Posavska', 'Viroviticko-Podravska', 'Bjelovarsko-bilogorska', tag='river plain'),
        K('istria', 'Istria & Kvarner', 'İstirya ve Kvarner', 'Istarska', 'Primorsko-Goranska', tag='peninsula'),
        K('lika', 'Lika, Karlovac & Banovina', 'Lika, Karlovac ve Banovina', 'Licko-Senjska', 'Karlovacka', 'Sisacko-Moslavacka', tag='frontier'),
    ],
    'svn_slovenia': [
        S(None, 'Carniola (Ljubljana)', 'Kranjska (Ljubljana)', 14.6, 46.0, tag='pass'),
        S('lower_styria', 'Lower Styria (Maribor)', 'Aşağı Steiermark (Maribor)', 15.7, 46.4),
        S('littoral', 'Littoral & Karst (Koper)', 'Kıyı ve Karst (Koper)', 13.8, 45.9, tag='coast'),
    ],
    'bgr_moesia': [
        S(None, 'Moesia (Central Danubian Plain)', 'Mezya (Orta Tuna Ovası)', 25.2, 43.3, tag='river plain'),
        S('sofia', 'Sofia Basin', 'Sofya Havzası', 23.4, 42.7, tag='basin'),
        S('north_west_bulgaria', 'Northwestern Bulgaria (Vidin)', 'Kuzeybatı Bulgaristan (Vidin)', 23.0, 43.6, tag='river'),
        S('dobruja_bg', 'Ludogorie & Black Sea (Varna)', 'Deliorman ve Karadeniz (Varna)', 27.3, 43.5, tag='coast'),
    ],
    'bgr_thrace_bg': [
        K(None, 'Upper Thrace (Plovdiv)', 'Yukarı Trakya (Filibe)', 'Plovdiv', 'Pazardzhik', 'Stara Zagora', 'Haskovo', tag='plain'),
        K('burgas', 'Burgas & Strandzha', 'Burgaz ve Istranca', 'Burgas', 'Yambol', 'Sliven', tag='coast'),
        K('rhodopes', 'Rhodopes', 'Rodoplar', 'Smolyan', 'Kardzhali', tag='mountain'),
        K('struma', 'Struma Valley (Pirin)', 'Struma Vadisi (Pirin)', 'Blagoevgrad', 'Kyustendil', 'Pernik', tag='river valley'),
    ],
    'rou_wallachia': [
        K(None, 'Muntenia (Bucharest)', 'Munteniya (Bükreş)', 'Ilfov', 'Bucharest', 'Dâmbovita', 'Giurgiu', 'Teleorman', 'Calarasi', 'Ialomita', 'Prahova', 'Buzau', 'Braila', 'Arges', tag='plain'),
        K('oltenia', 'Oltenia', 'Oltenya', 'Mehedinti', 'Dolj', 'Olt', 'Vâlcea', tag='river valley'),
        K('dobruja', 'Dobruja (Constanța)', 'Dobruca (Köstence)', 'Constanta', tag='coast'),
    ],
    'rou_moldavia': [
        K(None, 'Moldavia (Iași)', 'Boğdan (Yaş)', 'Botosani', 'Iasi', 'Vaslui', 'Neamt', 'Bacau'),
        K('bukovina', 'Bukovina (Suceava)', 'Bukovina (Suçava)', 'Suceava', tag='mountain'),
        K('lower_danube', 'Danube Delta & Galați', 'Tuna Deltası ve Kalas', 'Galati', 'Tulcea', tag='delta'),
        K('szeklerland', 'Szeklerland & Vrancea', 'Szekely Ülkesi ve Vrancea', 'Covasna', 'Harghita', 'Vrancea', tag='mountain pass'),
    ],
    'rou_transylvania': [
        K(None, 'Transylvania (Cluj & Mureș)', 'Transilvanya (Kaloşvar ve Mureş)', 'Cluj', 'Alba', 'Mures', 'Bistrita-Nasaud', 'Salaj', tag='plateau'),
        K('banat', 'Banat (Timișoara)', 'Banat (Temeşvar)', 'Timis', 'Caras-Severin', tag='plain'),
        K('crisana', 'Crișana (Oradea)', 'Krişana (Varat)', 'Arad', 'Bihor', tag='plain'),
        K('maramures', 'Maramureș & Satu Mare', 'Maramureş ve Satu Mare', 'Maramures', 'Satu Mare', tag='mountain'),
        K('saxon_lands', 'Southern Transylvania (Sibiu & Brașov)', 'Güney Transilvanya (Sibiu ve Brașov)', 'Sibiu', 'Brasov', tag='mountain pass'),
        K('hunedoara', 'Hunedoara & Gorj', 'Hunedoara ve Gorj', 'Hunedoara', 'Gorj', tag='mountain'),
    ],
    'mda_moldova': [
        S(None, 'Bessarabia (Chișinău)', 'Besarabya (Kişinev)', 28.5, 46.8),
        S('north_moldova', 'Northern Moldova (Bălți)', 'Kuzey Moldova (Beltsy)', 27.7, 47.9),
        S('transnistria', 'Transnistria', 'Transdinyester', 29.3, 47.2, tag='river'),
    ],
})

# ============================================================ EASTERN EUROPE AND RUSSIA
SPLITS.update({
    'ukr_kyiv': [
        K(None, 'Kyiv (Middle Dnieper)', 'Kiev (Orta Dinyeper)', 'Kiev', 'Kiev City', 'Cherkasy', tag='river city'),
        K('chernihiv_sumy', 'Chernihiv & Sumy (Severia)', 'Çernigov ve Sumı (Severya)', 'Chernihiv', 'Sumy'),
        K('poltava', 'Poltava', 'Poltava', 'Poltava', tag='plain'),
        K('polesia', 'Zhytomyr (Polesia)', 'Jitomir (Polesya)', 'Zhytomyr', tag='forest marsh'),
    ],
    'ukr_galicia_volhynia': [
        K(None, 'Galicia (Lviv)', 'Galiçya (Lviv)', "L'viv", "Ternopil'", "Ivano-Frankivs'k"),
        K('volhynia', 'Volhynia', 'Volhınya', 'Volyn', 'Rivne', tag='forest marsh'),
        K('transcarpathia', 'Transcarpathia', 'Zakarpatya', 'Transcarpathia', tag='mountain pass'),
    ],
    'ukr_podolia': [
        K(None, 'Podolia', 'Podolya', 'Vinnytsya', "Khmel'nyts'kyy", tag='plateau'),
        K('north_bukovina', 'Northern Bukovina', 'Kuzey Bukovina', 'Chernivtsi'),
    ],
    'ukr_pontic_steppe': [
        K(None, 'Odessa & Budjak', 'Odesa ve Budjak', 'Odessa', tag='trade port'),
        K('tavria', 'Kherson & Tavria', 'Herson ve Tavriya', 'Kherson', tag='steppe'),
        K('dnieper_bug', 'Dnieper-Bug Steppe', 'Dinyeper-Bug Bozkırı', 'Mykolayiv', 'Kirovohrad', tag='steppe'),
    ],
    'ukr_sloboda': [
        K(None, 'Sloboda (Kharkiv)', 'Sloboda (Harkov)', 'Kharkiv'),
        K('donbas', 'Donbas', 'Donbas', "Donets'k", "Luhans'k", tag='coalfield'),
        K('zaporizhia', 'Zaporizhia', 'Zaporijya', 'Zaporizhzhya', tag='cossack steppe'),
        K('dnipro', 'Dnipro Rapids', 'Dinyeper Akıntıları', "Dnipropetrovs'k", tag='river'),
    ],
    'blr_belarus': [
        K(None, 'Minsk (Central Belarus)', 'Minsk (Orta Belarus)', 'Minsk', 'City of Minsk'),
        K('brest', 'Brest (Polesia)', 'Brest (Polesya)', 'Brest', tag='marsh frontier'),
        K('grodno', 'Grodno (Neman)', 'Grodno (Neman)', 'Grodno', tag='river'),
        K('vitebsk', 'Vitebsk (Dvina)', 'Vitebsk (Dvina)', 'Vitebsk', tag='river'),
        K('gomel_mogilev', 'Gomel & Mogilev (Dnieper)', 'Gomel ve Mogilev (Dinyeper)', 'Gomel', 'Mogilev', tag='river'),
    ],
    'ltu_lithuania': [
        K(None, 'Aukštaitija (Vilnius)', 'Aukštaitija (Vilnüs)', 'Vilniaus', 'Utenos', 'Panevezio'),
        K('suvalkija', 'Kaunas & Suvalkija', 'Kaunas ve Suvalkija', 'Kauno', 'Marijampoles', 'Alytaus', tag='river junction'),
        K('samogitia', 'Samogitia & Klaipėda', 'Samogitya ve Klaipėda', 'Telšiai', 'Šiauliai', 'Taurages', 'Klaipedos', tag='coast'),
    ],
    'lva_latvia': [
        S(None, 'Livonia (Riga)', 'Livonya (Riga)', 24.4, 57.0, tag='trade port'),
        S('courland', 'Courland', 'Kurlandiya', 21.9, 56.9, tag='coast'),
        S('semigallia', 'Semigallia (Zemgale)', 'Zemgale', 23.8, 56.45, tag='plain'),
        S('latgale', 'Latgale', 'Latgale', 27.0, 56.5, tag='lakeland'),
        S('vidzeme', 'Vidzeme (Cēsis & Valmiera)', 'Vidzeme', 25.5, 57.6),
    ],
    'est_estonia': [
        S(None, 'Harju & Lääne (Tallinn)', 'Harju ve Lääne (Tallinn)', 24.9, 59.2, tag='trade port'),
        S('tartu', 'Dorpat (Tartu & Võru)', 'Dorpat (Tartu ve Võru)', 26.8, 58.0),
        S('virumaa', 'Virumaa (Narva)', 'Virumaa (Narva)', 27.0, 59.2, tag='frontier'),
        S('parnu', 'Pärnu & Viljandi', 'Pärnu ve Viljandi', 24.9, 58.4, tag='coast'),
        S('osel', 'Ösel & Dagö (Saaremaa)', 'Ösel ve Dagö (Saaremaa)', 22.6, 58.5, tag='island'),
    ],
    'rus_novgorod': [
        K(None, 'Novgorod', 'Novgorod', 'Novgorod', tag='trade centre'),
        K('pskov', 'Pskov', 'Pskov', 'Pskov', tag='frontier'),
        K('ingria', 'Ingria (Neva & St Petersburg)', 'İngria (Neva ve St. Petersburg)', 'Leningrad', 'City of St. Petersburg', tag='river mouth'),
    ],
    'rus_karelia': [
        K(None, 'Karelia', 'Karelya', 'Karelia', tag='lakeland'),
        K('kola', 'Kola (Murmansk)', 'Kola (Murmansk)', 'Murmansk', tag='arctic'),
    ],
    'rus_north_russia': [
        K(None, 'Northern Dvina (Arkhangelsk)', 'Kuzey Dvina (Arhangelsk)', "Arkhangel'sk", tag='white sea port'),
        K('komi', 'Komi (Vychegda)', 'Komi (Vıçegda)', 'Komi', tag='taiga'),
        K('pechora', 'Pechora & Nenets', 'Peçora ve Nenets', 'Nenets', 'Unit', tag='arctic'),
    ],
    'rus_moscow': [
        K(None, 'Muscovy (Moscow)', 'Moskova Knezliği', 'Moskovskaya', 'Moskva', 'Tula', "Ryazan'", tag='capital hinterland'),
        K('vladimir_suzdal', 'Vladimir-Suzdal (Zalesye)', 'Vladimir-Suzdal (Zalesye)', 'Vladimir', 'Ivanovo', "Yaroslavl'", tag='river valley'),
        K('tver', 'Tver', 'Tver', "Tver'", tag='Volga headwaters'),
        K('vologda', 'Vologda', 'Vologda', 'Vologda', tag='forest'),
    ],
    'rus_smolensk': [
        K(None, 'Smolensk', 'Smolensk', 'Smolensk', tag='Dnieper gateway'),
        K('bryansk_kaluga', 'Bryansk & Kaluga (Upper Oka)', 'Bryansk ve Kaluga (Yukarı Oka)', 'Bryansk', 'Kaluga', tag='forest'),
    ],
    'rus_volga': [
        K(None, 'Middle Volga (Samara & Saratov)', 'Orta Volga (Samara ve Saratov)', 'Saratov', 'Samara', "Ul'yanovsk", tag='river steppe'),
        K('kazan', 'Kazan (Tatarstan & Chuvashia)', 'Kazan (Tataristan ve Çuvaşistan)', 'Tatarstan', 'Chuvash', 'Mariy-El', tag='river junction'),
        K('nizhny_novgorod', 'Nizhny Novgorod & Kostroma', 'Nijni Novgorod ve Kostroma', 'Nizhegorod', 'Kostroma', tag='river junction'),
        K('mordovia_penza', 'Mordovia & Penza', 'Mordovya ve Penza', 'Mordovia', 'Penza', tag='forest steppe'),
        K('vyatka', 'Vyatka (Kirov)', 'Vyatka (Kirov)', 'Kirov', tag='taiga'),
    ],
    'rus_black_earth': [
        K(None, 'Severia (Kursk & Orel)', 'Severya (Kursk ve Oryol)', 'Kursk', 'Belgorod', 'Orel', tag='black earth'),
        K('voronezh', 'Voronezh (Upper Don)', 'Voronej (Yukarı Don)', 'Voronezh', tag='black earth'),
        K('tambov', 'Tambov & Lipetsk', 'Tambov ve Lipetsk', 'Tambov', 'Lipetsk', tag='black earth'),
    ],
    'rus_don': [
        K(None, 'Lower Don (Rostov)', 'Aşağı Don (Rostov)', 'Rostov', tag='river mouth'),
        K('kuban', 'Kuban (Krasnodar & Adygea)', 'Kuban (Krasnodar ve Adigey)', 'Krasnodar', 'Adygey', tag='steppe coast'),
        K('tsaritsyn', 'Volgograd (Tsaritsyn)', 'Volgograd (Çarisin)', 'Volgograd', tag='Volga-Don portage'),
        K('crimea_ru', 'Crimea (Tauric Peninsula)', 'Kırım Yarımadası', 'Crimea', 'Sevastopol', tag='peninsula'),
    ],
    'rus_north_caucasus': [
        K(None, 'Chechnya', 'Çeçenistan', 'Chechnya', tag='mountain'),
        K('dagestan', 'Dagestan', 'Dağıstan', 'Dagestan', tag='Caspian coast'),
        K('ossetia', 'Ossetia & Ingushetia', 'Osetya ve İnguşetya', 'North Ossetia', 'Ingush', tag='mountain pass'),
        K('kabardia', 'Kabardia & Karachay', 'Kabardey ve Karaçay', 'Karachay-Cherkess', 'Kabardin-Balkar', tag='mountain'),
        K('stavropol', 'Stavropol Plateau', 'Stavropol Platosu', "Stavropol'", tag='steppe'),
        K('kalmykia', 'Astrakhan & Kalmykia', 'Astrahan ve Kalmukya', "Astrakhan'", 'Kalmyk', tag='steppe delta'),
    ],
    'rus_urals': [
        K(None, 'Middle Urals (Sverdlovsk & Chelyabinsk)', 'Orta Urallar (Sverdlovsk ve Çelyabinsk)', 'Sverdlovsk', 'Chelyabinsk', 'Kurgan', tag='mining'),
        K('bashkiria', 'Bashkiria & Orenburg', 'Başkurdistan ve Orenburg', 'Bashkortostan', 'Orenburg', tag='steppe frontier'),
        K('perm', 'Perm & Udmurtia', 'Perm ve Udmurtya', "Perm'", 'Udmurt', tag='river valley'),
        K('tyumen', 'Tyumen & Khanty-Mansi', 'Tümen ve Hanti-Mansi', "Tyumen'", 'Khanty-Mansiy', tag='taiga'),
        K('yamal', 'Yamal', 'Yamal', 'Yamal-Nenets', tag='arctic'),
        K('west_siberia', 'Western Siberian Plain (Omsk & Tomsk)', 'Batı Sibirya Ovası (Omsk ve Tomsk)', 'Omsk', 'Novosibirsk', 'Tomsk', tag='plain'),
    ],
    'rus_sakha_yakutia': [
        K(None, 'Sakha (Yakutia)', 'Saha (Yakutya)', 'Sakha (Yakutia)', tag='arctic'),
        K('irkutsk', 'Irkutsk (Baikal)', 'İrkutsk (Baykal)', 'Irkutsk', tag='lake'),
        K('chukotka', 'Chukotka', 'Çukotka', 'Chukchi Autonomous Okrug', tag='arctic'),
        K('altai_kuzbass', 'Altai & Kuzbass', 'Altay ve Kuzbas', 'Gorno-Altay', 'Altay', 'Kemerovo', 'Khakass', tag='mountain'),
    ],
    'rus_primor_ye': [
        K(None, 'Primorye', 'Primorye', "Primor'ye", 'Yevrey', tag='pacific coast'),
        K('sakhalin', 'Sakhalin', 'Sahalin', 'Sakhalin', tag='island'),
    ],
    'rus_krasnoyarsk': [
        S(None, 'Krasnoyarsk (Yenisei)', 'Krasnoyarsk (Yenisey)', 93.0, 57.0, tag='river'),
        S('taymyr', 'Taymyr', 'Taymır', 96.0, 72.0, tag='arctic'),
        S('evenkia', 'Evenkia (Tunguska)', 'Evenkiya (Tunguska)', 96.0, 64.5, tag='taiga'),
    ],
    'rus_khabarovsk': explode(100000),
    'rus_maga_buryatdan': explode(100000),
})

# ============================================================ ANATOLIA
SPLITS.update({
    'tur_constantinople': [
        S(None, 'Constantinople (European Shore)', 'İstanbul (Konstantiniyye, Avrupa Yakası)', 28.8, 41.05, tag='strait city'),
        S('scutari', 'Scutari & Kocaeli (Asian Shore)', 'Üsküdar ve Kocaeli (Anadolu Yakası)', 29.4, 40.95, tag='strait'),
        S('bursa', 'Bursa (Mount Olympus)', 'Bursa (Uludağ)', 29.0, 40.1, tag='silk city'),
    ],
    'tur_eastern_thrace': [
        K(None, 'Eastern Thrace (Edirne)', 'Doğu Trakya (Edirne)', 'Kirklareli', 'Edirne', tag='Maritsa valley'),
        K('tekirdag', 'Tekirdağ & Propontis', 'Tekirdağ ve Marmara Kıyısı', 'Tekirdag', tag='coast'),
        S('gallipoli', 'Gallipoli (Thracian Chersonese)', 'Gelibolu Yarımadası', 26.5, 40.35, tag='strait'),
        S('troad', 'Troad (Çanakkale)', 'Truva Bölgesi (Çanakkale)', 26.5, 39.9, tag='strait'),
    ],
    'tur_bithynia': [
        K(None, 'Bithynia (Sakarya & Bolu)', 'Bitinya (Sakarya ve Bolu)', 'Sakarya', 'Kocaeli', 'Düzce', 'Bolu', 'Bilecik', tag='river valley'),
        K('black_sea_coal', 'Black Sea Coalfield (Zonguldak)', 'Zonguldak Kömür Havzası', 'Zinguldak', 'Bartın', 'Karabük', tag='coal coast'),
        K('phrygia', 'Phrygia (Eskişehir & Kütahya)', 'Frigya (Eskişehir ve Kütahya)', 'Eskisehir', 'Kütahya', 'Afyonkarahisar', tag='plateau'),
    ],
    'tur_aegean_anatolia': [
        K(None, 'Ionia (İzmir & Manisa)', 'İyonya (İzmir ve Manisa)', 'Izmir', 'Manisa', 'Usak', tag='trade port'),
        K('mysia', 'Mysia (Balıkesir)', 'Misya (Balıkesir)', 'Balikesir'),
        K('caria', 'Caria (Muğla & Aydın)', 'Karya (Muğla ve Aydın)', 'Mugla', 'Aydin', 'Denizli', tag='coast'),
        K('pamphylia', 'Lycia & Pamphylia (Antalya)', 'Likya ve Pamfilya (Antalya)', 'Antalya', tag='coast'),
        K('pisidia', 'Pisidia (Lake District)', 'Pisidya (Göller Bölgesi)', 'Isparta', 'Burdur', tag='lakes'),
    ],
    'tur_central_anatolia': [
        K(None, 'Galatia (Ankara)', 'Galatya (Ankara)', 'Ankara', 'Kinkkale', 'Çankiri', 'Kirsehir', tag='capital hinterland'),
        K('konya', 'Lycaonia (Konya)', 'Likaonya (Konya)', 'Konya', tag='plateau'),
        K('cappadocia', 'Cappadocia (Nevşehir & Aksaray)', 'Kapadokya (Nevşehir ve Aksaray)', 'Nevsehir', 'Aksaray', tag='tuff plateau'),
        K('paphlagonia', 'Paphlagonia (Kastamonu)', 'Paflagonya (Kastamonu)', 'Kastamonu', tag='forest mountain'),
        K('corum_yozgat', 'Çorum & Yozgat (Hittite Heartland)', 'Çorum ve Yozgat', 'Çorum', 'Yozgat', tag='plateau'),
    ],
    'tur_cilicia': [
        K(None, 'Cilicia (Adana & Mersin)', 'Kilikya (Adana ve Mersin)', 'Adana', 'Mersin', 'Osmaniye', tag='plain'),
        K('hatay', 'Antioch & Amanus (Hatay)', 'Antakya ve Amanos (Hatay)', 'Hatay', 'Kilis', tag='mountain pass'),
        K('kayseri', 'Caesarea (Kayseri & Niğde)', 'Kayseri ve Niğde', 'Kayseri', 'Nigde', tag='plateau'),
        K('marash', 'Marash (Kahramanmaraş)', 'Maraş (Kahramanmaraş)', 'K. Maras', tag='mountain pass'),
        K('isauria', 'Isauria (Karaman)', 'İsavrya (Karaman)', 'Karaman', tag='Taurus'),
    ],
    'tur_pontus': [
        K(None, 'Pontus (Trabzon)', 'Pontus (Trabzon)', 'Trabzon', 'Giresun', 'Gümüshane', tag='coast'),
        K('amasya_samsun', 'Samsun & Amasya (Pontic Plain)', 'Samsun ve Amasya', 'Samsun', 'Sinop', 'Amasya', 'Ordu', tag='river valley'),
        K('sivas', 'Sivas & Tokat (Armenia Minor)', 'Sivas ve Tokat', 'Sivas', 'Tokat', tag='plateau'),
    ],
    'tur_armenia_highlands': [
        K(None, 'Erzurum (Theodosiopolis)', 'Erzurum (Karin)', 'Erzurum', 'Bayburt', tag='highland plain'),
        K('tao', 'Tao-Klarjeti (Artvin & Ardahan)', 'Tao-Klarceti (Artvin ve Ardahan)', 'Artvin', 'Ardahan', 'Rize', tag='mountain'),
        K('kars_ararat', 'Kars & Ağrı (Ararat Highlands)', 'Kars ve Ağrı (Ağrı Dağı)', 'Kars', 'Agri', 'Iğdir', tag='mountain'),
        K('van', 'Van & Hakkari (Vaspurakan)', 'Van ve Hakkâri (Vaspurakan)', 'Van', 'Hakkari', tag='lake'),
        K('sasun', 'Muş & Bitlis (Sasun)', 'Muş ve Bitlis (Sason)', 'Mus', 'Bitlis', 'Bingöl', tag='mountain'),
        K('upper_euphrates', 'Erzincan & Tunceli (Upper Euphrates)', 'Erzincan ve Tunceli (Yukarı Fırat)', 'Erzincan', 'Tunceli', tag='river gorge'),
        K('botan', 'Siirt, Batman & Şırnak (Botan)', 'Siirt, Batman ve Şırnak (Botan)', 'Siirt', 'Batman', 'Sirnak', tag='mountain'),
    ],
    'tur_upper_mesopotamia': [
        K(None, 'Diyarbakır (Amida)', 'Diyarbakır (Amid)', 'Diyarbakir', tag='river plateau'),
        K('mardin', 'Mardin (Tur Abdin)', 'Mardin (Turabdin)', 'Mardin'),
        K('urfa', 'Edessa (Şanlıurfa & Adıyaman)', 'Urfa (Edessa) ve Adıyaman', 'Sanliurfa', 'Adiyaman', tag='plain'),
        K('gaziantep', 'Aintab (Gaziantep)', 'Antep (Gaziantep)', 'Gaziantep', tag='trade route'),
        K('malatya', 'Melitene (Malatya & Elazığ)', 'Malatya ve Elazığ', 'Malatya', 'Elazig', tag='river valley'),
    ],
})

# ============================================================ CAUCASUS AND LEVANT
SPLITS.update({
    'geo_georgia': [
        K(None, 'Kartli (Tbilisi)', 'Kartli (Tiflis)', 'Tbilisi', 'Kvemo Kartli', 'Shida Kartli', 'Mtskheta-Mtianeti', tag='river valley'),
        K('kakheti', 'Kakheti', 'Kaheti', 'Kakheti', tag='wine valley'),
        K('imereti', 'Imereti (Kutaisi)', 'İmereti (Kutaisi)', 'Imereti', 'Racha-Lechkhumi-Kvemo Svaneti', tag='river valley'),
        K('colchis', 'Colchis (Samegrelo & Abkhazia)', 'Kolhis (Megrelya ve Abhazya)', 'Samegrelo-Zemo Svaneti', 'Abkhazia', tag='coast'),
        K('adjara', 'Adjara & Guria', 'Acara ve Guria', 'Ajaria', 'Guria', tag='port coast'),
        K('javakheti', 'Samtskhe-Javakheti', 'Samtshe-Cavaheti', 'Samtskhe-Javakheti', tag='plateau'),
    ],
    'arm_armenia': [
        K(None, 'Ararat Plain (Yerevan)', 'Ararat Ovası (Erivan)', 'Erevan', 'Ararat', 'Armavir', 'Aragatsotn', 'Kotayk', tag='river plain'),
        K('lori', 'Lori, Tavush & Shirak', 'Lori, Tavuş ve Şirak', 'Lori', 'Tavush', 'Shirak', tag='highland'),
        K('sevan', 'Gegharkunik (Lake Sevan)', 'Gegarkunik (Sevan Gölü)', 'Gegharkunik', tag='lake'),
        K('syunik', 'Syunik (Zangezur)', 'Sünik (Zengezur)', 'Syunik', 'Vayots Dzor', tag='mountain'),
    ],
    'aze_azerbaijan': [
        S(None, 'Shirvan', 'Şirvan', 48.2, 40.6),
        S('absheron', 'Baku & Absheron', 'Bakü ve Abşeron', 49.7, 40.4, tag='oil port'),
        S('ganja_karabakh', 'Ganja & Karabakh', 'Gence ve Karabağ', 46.8, 40.4, tag='highland'),
        S('sheki', 'Sheki & Zaqatala', 'Şeki ve Zaqatala', 47.3, 41.3, tag='mountain foothills'),
        S('mugan', 'Mugan & Lankaran', 'Muğan ve Lenkeran', 48.5, 39.3, tag='steppe coast'),
        S('nakhchivan', 'Nakhchivan', 'Nahçıvan', 45.4, 39.3, tag='exclave valley'),
    ],
    'syr_aleppo': [
        K(None, 'Aleppo', 'Halep', 'Aleppo', tag='trade city'),
        K('hama_idlib', 'Hama & Idlib', 'Hama ve İdlib', 'Hamah', 'Idlib', tag='river valley'),
        K('latakia', 'Latakia Coast', 'Lazkiye Kıyısı', 'Lattakia', tag='coast'),
    ],
    'syr_damascus': [
        K(None, 'Damascus (Ghouta)', 'Şam (Guta)', 'Damascus', 'Rif Dimashq', 'Quneitra', 'UNDOF', tag='oasis city'),
        K('homs_palmyra', 'Homs & Palmyra (Syrian Steppe)', 'Humus ve Palmira (Suriye Bozkırı)', 'Homs (Hims)', tag='desert steppe'),
        K('tartus', 'Tartus Coast', 'Tartus Kıyısı', 'Tartus', tag='coast'),
        K('hauran', 'Hauran (Daraa & Suwayda)', 'Havran (Dera ve Süveyda)', 'Dar`a', "As Suwayda'", tag='basalt plain'),
    ],
    'syr_jazira': [
        K(None, 'Raqqa (Euphrates Jazira)', 'Rakka (Fırat Cezire)', 'Ar Raqqah', tag='river'),
        K('hasakah', 'Khabur (Hasakah)', 'Habur (Haseke)', 'Hasaka (Al Haksa)', tag='steppe'),
        K('deir_ez_zor', 'Deir ez-Zor (Middle Euphrates)', 'Deyrizor (Orta Fırat)', 'Dayr Az Zawr', tag='river'),
    ],
    'irq_baghdad': [
        K(None, 'Baghdad & Karbala', 'Bağdat ve Kerbela', 'Baghdad', 'Babil', "Karbala'", 'Al-Qādisiyyah', tag='river junction'),
        K('diyala_wasit', 'Diyala & Wasit (Tigris East)', 'Diyala ve Vasıt (Doğu Dicle)', 'Diyala', 'Wasit', tag='river plain'),
        K('salahaddin', 'Salah ad-Din (Tikrit & Samarra)', 'Selahaddin (Tikrit ve Samarra)', 'Sala ad-Din', tag='river valley'),
        K('anbar', 'Anbar (Euphrates & Western Desert)', 'Enbar (Fırat ve Batı Çölü)', 'Al-Anbar', tag='desert river'),
        K('najaf', 'Najaf (Kufa)', 'Necef (Kûfe)', 'An-Najaf', tag='desert edge'),
    ],
    'irq_basra': [
        K(None, 'Basra', 'Basra', 'Al-Basrah', tag='gulf port'),
        K('marshes', 'Southern Marshes (Maysan & Dhi Qar)', 'Güney Bataklıkları (Maysan ve Zikar)', 'Maysan', 'Dhi-Qar', tag='marsh'),
        K('muthanna', 'Muthanna (Southern Desert)', 'Müsenna (Güney Çölü)', 'Al-Muthannia', tag='desert'),
    ],
    'irq_mosul': [
        K(None, 'Mosul (Nineveh)', 'Musul (Ninova)', 'Ninawa', tag='river city'),
        K('erbil', 'Erbil (Arbela)', 'Erbil (Arbela)', 'Arbil', tag='plain'),
        K('kirkuk', 'Kirkuk (Tamim)', 'Kerkük', "At-Ta'mim", tag='oil'),
        K('sulaymaniyah', 'Sulaymaniyah (Shahrizor)', 'Süleymaniye (Şehrizor)', 'As-Sulaymaniyah', tag='mountain'),
        K('duhok', 'Duhok (Bohtan)', 'Dohuk (Botan)', 'Dihok', tag='mountain'),
    ],
    'isr_judea': [
        K(None, 'Judea (Jerusalem)', 'Yahuda (Kudüs)', 'West Bank', 'Jerusalem', tag='highland'),
        K('coastal_plain', 'Coastal Plain (Jaffa & Gaza)', 'Kıyı Ovası (Yafa ve Gazze)', 'Gaza Strip', 'HaMerkaz', 'Tel Aviv', tag='coast'),
    ],
    'jor_jordan': [
        K(None, 'Amman & Balqa', 'Amman ve Belka', 'Amman', 'Zarqa', 'Balqa', 'Madaba', tag='plateau'),
        K('gilead', 'Gilead & Hauran Fringe (Irbid)', 'Gilead (İrbid)', 'Irbid', 'Ajlun', 'Jarash', 'Mafraq', tag='highland'),
        K('moab_edom', 'Moab & Edom (Karak)', 'Moab ve Edom (Kerek)', 'Karak', 'Tafilah', tag='highland'),
        K('maan', "Ma'an & Aqaba (Hisma)", "Maan ve Akabe", 'Ma`an', 'Aqaba', tag='desert gulf'),
    ],
    'lbn_lebanon': [
        K(None, 'Mount Lebanon & the Coast', 'Lübnan Dağı ve Kıyı', 'Mount Lebanon', 'Beirut', 'North Lebanon', 'South Lebanon', 'An Nabatiyah', tag='mountain port'),
        K('bekaa', 'Bekaa Valley', 'Bekaa Vadisi', 'Beqaa', tag='valley'),
    ],
    'cyp_cyprus': [
        S(None, 'Cyprus (Nicosia & Paphos)', 'Kıbrıs (Lefkoşa ve Baf)', 33.0, 35.0, tag='island'),
        S('famagusta', 'Famagusta & Karpas', 'Mağusa ve Karpaz', 33.8, 35.1, tag='island'),
    ],
})

# ============================================================ EGYPT AND NORTH AFRICA
SPLITS.update({
    'egy_delta': [
        K(None, 'Alexandria & Beheira', 'İskenderiye ve Buhayra', 'Al Iskandariyah', 'Al Buhayrah', tag='trade port'),
        K('eastern_delta', 'Eastern Delta (Damietta & Dakahlia)', 'Doğu Delta (Dimyat ve Dakahliye)', 'Ad Daqahliyah', 'Dumyat', 'Kafr ash Shaykh', tag='delta'),
        K('central_delta', 'Central Delta (Gharbiyah & Minufiyah)', 'Orta Delta (Garbiye ve Minufiye)', 'Al Gharbiyah', 'Al Minufiyah', tag='delta'),
        K('marmarica', 'Marmarica (Matruh)', 'Marmarika (Matruh)', 'Matruh', tag='desert coast'),
    ],
    'egy_cairo': [
        K(None, 'Cairo (Fustat & Qalyubiyah)', 'Kahire (Fustat)', 'Al Qahirah', 'Al Qalyubiyah', tag='river city'),
        K('isthmus', 'Suez Isthmus (Ismailia & Port Said)', 'Süveyş Kıstağı (İsmailiye ve Port Said)', 'As Suways', 'Bur Sa`id', 'Al Isma`iliyah', 'Ash Sharqiyah', tag='canal route'),
        K('giza', 'Giza & Bahariya', 'Giza ve Baharriye', 'Al Jizah', tag='pyramids'),
        K('fayyum', 'Fayyum & Beni Suef', 'Feyyum ve Beni Süveyf', 'Al Fayyum', 'Bani Suwayf', tag='oasis'),
        K('minya', 'Minya (Middle Egypt)', 'Minya (Orta Mısır)', 'Al Minya', tag='river valley'),
    ],
    'egy_upper_egypt': [
        K(None, 'Asyut & Sohag', 'Asyut ve Sohag', 'Asyut', 'Suhaj', tag='river valley'),
        K('thebes', 'Thebes (Qena & Luxor)', 'Teb (Kına ve Luksor)', 'Qina', 'Luxor', tag='river valley'),
        K('aswan', 'Aswan & Nubia', 'Asvan ve Nübye', 'Aswan', tag='cataract'),
        K('eastern_desert', 'Eastern Desert & Red Sea Coast', 'Doğu Çölü ve Kızıldeniz Kıyısı', 'Al Bahr al Ahmar', tag='mining coast'),
        K('new_valley', 'Western Oases (New Valley)', 'Batı Vahaları (Yeni Vadi)', 'Al Wadi at Jadid', tag='oasis'),
    ],
    'egy_sinai': [
        K(None, 'North Sinai (Via Maris)', 'Kuzey Sina (Via Maris)', "Shamal Sina'", tag='land bridge'),
        K('south_sinai', 'South Sinai', 'Güney Sina', "Janub Sina'", tag='mountain'),
    ],
    'lby_tripolitania': [
        K(None, 'Tripolitania (Tripoli)', 'Trablusgarp (Trablus)', "Tajura' wa an Nawahi al Arba", 'Az Zawiyah', 'Al Jifarah', 'An Nuqat al Khams', 'Al Marqab', tag='trade port'),
        K('nafusa', 'Jebel Nafusa (Mizdah)', 'Nefüsa Dağı (Mizde)', 'Mizdah', tag='mountain'),
        K('misrata', 'Misrata & Gulf of Sidra', 'Misrata ve Sirte Körfezi', 'Misratah', tag='coast'),
        K('ghadames', 'Ghadames', 'Gadames', 'Ghadamis', tag='oasis'),
    ],
    'lby_cyrenaica': [
        K(None, 'Cyrenaica (Jebel Akhdar)', 'Bingazi (Yeşil Dağ)', 'Benghazi', 'Al Marj', 'Al Jabal al Akhdar', 'Al Qubbah', tag='fertile coast'),
        K('sirte', 'Ajdabiya & Sirte', 'Ecdabiye ve Sirte', 'Ajdabiya', 'Surt', tag='desert coast'),
        K('butnan', 'Butnan (Tobruk)', 'Butnan (Tobruk)', 'Al Butnan', tag='coast'),
        K('kufra', 'Kufra Oasis', 'Kufra Vahası', 'Al Kufrah', tag='oasis'),
    ],
    'lby_fezzan': [
        K(None, 'Fezzan (Sabha)', 'Fizan (Sebha)', 'Sabha', "Wadi al Hayaa", "Ash Shati'", tag='oasis'),
        K('murzuq', 'Murzuq', 'Murzuk', 'Murzuq', tag='oasis'),
        K('ghat', 'Ghat (Tuareg Sahara)', 'Gat (Tuareg Sahrası)', 'Ghat', tag='caravan route'),
        K('jufra', 'Jufra', 'Cufra', 'Al Jufrah', tag='oasis'),
    ],
    'tun_tunisia': [
        K(None, 'Tunis & Cap Bon (Carthage)', 'Tunus ve Bon Burnu (Kartaca)', 'Tunis', 'Ben Arous (Tunis Sud)', 'Manubah', 'Nabeul', tag='capital hinterland'),
        K('medjerda', 'Medjerda Valley (Béja & Bizerte)', 'Mecerde Vadisi (Beca ve Bizerte)', 'Béja', 'Jendouba', 'Bizerte', 'Le Kef', 'Siliana', tag='grain valley'),
        K('sahel', 'Sahel (Sousse & Sfax)', 'Sahel (Susa ve Sfaks)', 'Sousse', 'Monastir', 'Mahdia', 'Sfax', tag='olive coast'),
        K('kairouan', 'Kairouan & the Steppe', 'Kayrevan ve Bozkır', 'Kairouan', 'Kassérine', 'Sidi Bou Zid', tag='steppe'),
        K('jerid', 'Jerid (Gafsa, Tozeur & Kebili)', 'Cerid (Kafsa, Tozur ve Kebili)', 'Gafsa', 'Tozeur', 'Kebili', tag='oasis'),
        K('djerba_gabes', 'Gabès, Djerba & Tataouine', 'Kabis, Cerbe ve Tataouine', 'Gabès', 'Médenine', 'Tataouine', tag='coast desert'),
    ],
    'dza_algiers': [
        K(None, 'Algiers (Mitidja)', 'Cezayir (Mitidja)', 'Alger', 'Blida', 'Boumerdès', 'Tipaza', 'Médéa', tag='capital hinterland'),
        K('kabylia', 'Kabylia (Djurdjura)', 'Kabiliye (Cürcüra)', 'Tizi Ouzou', 'Bouira', 'Bordj Bou Arréridj', tag='mountain'),
        K('chelif', 'Chélif Valley (Dahra)', 'Şelif Vadisi (Dahra)', 'Chlef', 'Aïn Defla', 'Tissemsilt', tag='river valley'),
        K('high_plateaus', 'High Plateaus (Djelfa & Laghouat)', 'Yüksek Platolar (Celfa ve Lağvat)', 'Djelfa', 'Laghouat', "M'Sila", tag='steppe'),
    ],
    'dza_constantine': [
        K(None, 'Constantine', 'Konstantin', 'Constantine', 'Mila', 'Skikda', 'Oum el Bouaghi', tag='plateau city'),
        K('annaba', 'Annaba & El Kala (Bône)', 'Annaba (Bona) ve El Kala', 'Annaba', 'El Tarf', 'Guelma', 'Souk Ahras', tag='port coast'),
        K('aures', 'Aurès', 'Evras', 'Batna', 'Khenchela', 'Tébessa', tag='mountain'),
        K('setif', 'Sétif & Bejaia (Lesser Kabylia)', 'Setif ve Bicaye', 'Sétif', 'Béjaïa', 'Jijel', tag='highland coast'),
        K('zibans', 'Zibans (Biskra)', 'Zibanlar (Biskra)', 'Biskra', tag='oasis'),
        K('souf', 'Souf (El Oued)', 'Suf (El Vadi)', 'El Oued', tag='dune oasis'),
    ],
    'dza_oran': [
        K(None, 'Oran', 'Oran', 'Oran', 'Aïn Témouchent', 'Mostaganem', 'Relizane', tag='port'),
        K('tlemcen', 'Tlemcen (Zayyanid Heartland)', 'Tilimsan (Zeyyaniler)', 'Tlemcen', 'Sidi Bel Abbès', tag='highland'),
        K('tiaret', 'Tiaret & Saïda (High Plateaus)', 'Tihert ve Saida (Yüksek Platolar)', 'Tiaret', 'Saïda', 'Mascara', tag='steppe'),
        K('saharan_atlas', 'Saharan Atlas (Naâma & El Bayadh)', 'Sahra Atlası (Naama ve Bayad)', 'Naâma', 'El Bayadh', tag='mountain'),
        K('saoura', 'Saoura (Béchar & Tindouf)', 'Savra (Beşşar ve Tindouf)', 'Béchar', 'Tindouf', tag='desert'),
    ],
    'dza_algerian_sahara': [
        K(None, 'Ouargla & Ghardaïa (M\'zab)', "Varkla ve Gardaya (M'zab)", 'Ouargla', 'Ghardaïa', tag='oasis'),
        K('touat', 'Touat (Adrar)', 'Tuvat (Adrar)', 'Adrar', tag='oasis'),
        K('ahaggar', 'Ahaggar (Tamanrasset)', 'Ahaggar (Tamanrasset)', 'Tamanghasset', tag='mountain desert'),
        K('tassili', 'Tassili n\'Ajjer (Illizi)', "Tassili n'Ajjer (İlizi)", 'Illizi', tag='plateau desert'),
    ],
    'mar_fez': [
        K(None, 'Fez', 'Fes', 'Fès - Boulemane', tag='imperial city'),
        K('tangier', 'Tangier & Tetouan (Strait)', 'Tanca ve Tetuan (Boğaz)', 'Tanger - Tétouan', tag='strait'),
        K('rif', 'Rif & Taza', 'Rif ve Taza', 'Taza - Al Hoceima - Taounate', tag='mountain pass'),
        K('atlantic_plain', 'Gharb & Rabat (Atlantic Plain)', 'Garb ve Rabat (Atlantik Ovası)', 'Gharb - Chrarda - Béni Hssen', 'Rabat - Salé - Zemmour - Zaer', 'Grand Casablanca', tag='plain'),
        K('oriental', 'Oriental (Oujda)', 'Şarkî (Ucda)', 'Oriental', tag='steppe frontier'),
        K('tafilalet', 'Meknes & Tafilalet', 'Mekn ve Tafilalt', 'Meknès - Tafilalet', tag='oasis mountain'),
    ],
    'mar_marrakesh': [
        K(None, 'Marrakesh (Haouz)', 'Marakeş (Havz)', 'Marrakech - Tensift - Al Haouz', tag='imperial city'),
        K('doukkala', 'Doukkala & Chaouia', 'Dukkala ve Şavia', 'Chaouia - Ouardigha', 'Doukkala - Abda', tag='plain'),
        K('tadla', 'Tadla & Azilal (Middle Atlas)', 'Tadla ve Azilal (Orta Atlas)', 'Tadla - Azilal', tag='mountain'),
        K('souss', 'Souss, Massa & Draa', 'Sus, Massa ve Dra', 'Souss - Massa - Draâ', tag='river valley'),
        K('guelmim', 'Guelmim & Saharan Atlantic', 'Guelmim ve Atlantik Sahra', 'Guelmim - Es-Semara', tag='caravan route'),
        K('sahara_atlantic', 'Laâyoune & Dakhla (Saharan Coast)', 'Layun ve Dahla (Sahra Kıyısı)', 'Laâyoune - Boujdour - Sakia El Hamra', 'Oued el Dahab', tag='desert coast'),
    ],
})

# ============================================================ ARABIA
SPLITS.update({
    'sau_hejaz': [
        K(None, 'Hejaz (Mecca & Jeddah)', 'Hicaz (Mekke ve Cidde)', 'Makkah', 'Al Bahah', tag='holy city port'),
        K('medina', 'Medina (Yathrib)', 'Medine', 'Al Madinah', tag='holy city oasis'),
        K('tabuk', 'Tabuk (Midian)', 'Tebük (Medyen)', 'Tabuk', tag='desert frontier'),
        K('asir', 'Asir & Tihama', 'Asir ve Tihame', '`Asir', 'Jizan', tag='mountain'),
    ],
    'sau_najd': [
        S(None, 'Najd (Riyadh)', 'Necid (Riyad)', 46.7, 24.5, tag='oasis'),
        S('wadi_dawasir', 'Wadi ad-Dawasir (South Najd)', 'Vadi ed-Devasir (Güney Necid)', 44.5, 21.0, tag='oasis'),
        K('qassim', 'Qassim (Buraydah)', 'Kasım (Bureyde)', 'Al Quassim', tag='oasis'),
        K('hail', 'Ha\'il (Jabal Shammar)', 'Hayil (Cebel Şammar)', "Ha'il", tag='mountain oasis'),
        K('jawf', 'Northern Frontier (Al Jawf)', 'Kuzey Sınır Bölgesi (Cevf)', 'Al Jawf', 'Al Hudud ash Shamaliyah', tag='desert frontier'),
        K('najran', 'Najran', 'Necran', 'Najran', tag='oasis'),
    ],
    'sau_al_hasa': [
        S(None, 'Al-Hasa & Qatif (Eastern Coast)', 'Ahsa ve Katif (Doğu Kıyısı)', 49.8, 26.0, tag='gulf oasis'),
        S('hafar', 'Hafar al-Batin (Wadi al-Batin)', 'Hafr el-Batın', 46.5, 28.0, tag='desert frontier'),
        S('rub_al_khali', 'Rub al-Khali (Empty Quarter)', 'Rub el-Hali', 52.0, 21.0, tag='desert'),
    ],
    'yem_yemen': [
        S(None, "Sana'a (Yemeni Highlands)", 'Sana (Yemen Yaylaları)', 44.2, 15.3, tag='highland'),
        S('tihama', 'Tihama (Hodeidah)', 'Tihame (Hudeyde)', 43.2, 14.8, tag='red sea coast'),
        S('taizz_ibb', 'Taiz & Ibb (Southern Highlands)', 'Taiz ve İbb (Güney Yaylaları)', 44.0, 13.7, tag='fertile highland'),
        S('aden', 'Aden (Lahij & Abyan)', 'Aden (Lahic ve Ebyen)', 45.0, 13.1, tag='port'),
        S('hadramawt', 'Hadramawt', 'Hadramut', 49.3, 16.6, tag='wadi'),
        S('marib', "Ma'rib & Shabwah", 'Marib ve Şabva', 46.2, 15.3, tag='incense road'),
        S('mahra', 'Al Mahrah', 'Mehre', 51.6, 16.7, tag='desert coast'),
        S('sadah', "Sa'dah & Hajjah", 'Saada ve Hacce', 43.7, 16.7, tag='mountain'),
    ],
    'omn_oman': [
        K(None, 'Muscat & Batinah', 'Maskat ve Batine', 'Muscat', 'Al Batnah North', 'Al Batnah South', tag='gulf port'),
        K('musandam', 'Musandam (Strait of Hormuz)', 'Musandam (Hürmüz Boğazı)', 'Musandam', tag='strait'),
        K('interior', 'Interior (Dakhiliyah & Buraimi)', 'İç Umman (Dahiliye ve Buraymi)', 'Ad Dakhliyah', 'Al Dhahira', 'Al Buraymi', tag='oasis'),
        K('sharqiyah', 'Sharqiyah (Sur)', 'Şarkiye (Sur)', 'Ash Sharqiyah South', 'Ash Sharqiyah North', tag='coast'),
        K('dhofar', 'Dhofar (Salalah)', 'Dofar (Salale)', 'Dhofar', tag='incense coast'),
        K('wusta', 'Al Wusta', 'Vusta', 'Al Wusta', tag='desert'),
    ],
    'are_united_arab_emirates': [
        K(None, 'Abu Dhabi & Liwa', 'Abu Dabi ve Liva', 'Abu Dhabi', tag='desert coast'),
        K('trucial_coast', 'Trucial Coast (Dubai & Sharjah)', 'Trucial Kıyısı (Dubai ve Şarika)', 'Dubay', 'Sharjah', 'Ras Al Khaymah', 'Fujayrah', 'Ajman', 'Umm Al Qaywayn', 'Neutral Zone', tag='strait pearl coast'),
    ],
})

# ============================================================ PERSIA
SPLITS.update({
    'irn_azerbaijan_persia': [
        K(None, 'Tabriz (East Azerbaijan)', 'Tebriz (Doğu Azerbaycan)', 'East Azarbaijan', tag='trade city'),
        K('urmia', 'Urmia (West Azerbaijan)', 'Urmiye (Batı Azerbaycan)', 'West Azarbaijan', tag='lake'),
        K('ardabil', 'Ardabil (Mughan)', 'Erdebil (Muğan)', 'Ardebil', tag='highland'),
        K('zanjan', 'Zanjan', 'Zencan', 'Zanjan'),
        K('kurdistan_ir', 'Kurdistan (Sanandaj)', 'Kürdistan (Senendec)', 'Kordestan', tag='mountain'),
        K('kermanshah', 'Kermanshah', 'Kirmanşah', 'Kermanshah', tag='Zagros pass'),
    ],
    'irn_jibal': [
        K(None, 'Rayy (Tehran)', 'Rey (Tahran)', 'Tehran', 'Alborz', 'Qom', tag='capital hinterland'),
        K('gilan', 'Gilan', 'Gilan', 'Gilan', tag='caspian coast'),
        K('mazandaran', 'Mazandaran (Tabaristan)', 'Mazenderan (Taberistan)', 'Mazandaran', tag='caspian coast'),
        K('gorgan', 'Gorgan', 'Gürgan', 'Golestan', tag='steppe frontier'),
        K('semnan', 'Semnan (Qumis)', 'Semnan (Kumis)', 'Semnan', tag='desert edge'),
        K('qazvin', 'Qazvin', 'Kazvin', 'Qazvin', tag='pass'),
        K('hamadan', 'Hamadan & Arak (Ecbatana)', 'Hemedan ve Arak', 'Hamadan', 'Markazi', tag='plateau'),
    ],
    'irn_isfahan': [
        S(None, 'Isfahan', 'İsfahan', 51.7, 32.6, tag='oasis city'),
        S('kashan', 'Kashan & Natanz', 'Kâşân ve Natanz', 51.4, 33.9, tag='oasis'),
        K('bakhtiari', 'Bakhtiari Mountains', 'Bahtiyari Dağları', 'Chahar Mahall and Bakhtiari', tag='mountain'),
        K('yazd', 'Yazd', 'Yezd', 'Yazd', tag='desert oasis'),
    ],
    'irn_fars': [
        S(None, 'Fars (Shiraz & Persepolis)', 'Fars (Şiraz ve Persepolis)', 52.5, 29.8, tag='heartland'),
        S('larestan', 'Larestan (South Fars)', 'Laristan (Güney Fars)', 54.3, 27.7, tag='desert'),
        K('bushehr', 'Bushehr (Gulf Coast)', 'Buşehr (Körfez Kıyısı)', 'Bushehr', tag='gulf port'),
    ],
    'irn_khuzestan': [
        K(None, 'Khuzestan (Susa & Ahvaz)', 'Huzistan (Sus ve Ahvaz)', 'Khuzestan', tag='river plain'),
        K('luristan', 'Luristan', 'Lorestan', 'Lorestan', tag='Zagros'),
        K('ilam', 'Ilam (Pusht-i Kuh)', 'İlam (Puşt-ı Kuh)', 'Ilam', tag='border mountain'),
        K('kohgiluyeh', 'Kohgiluyeh & Boyer-Ahmad', 'Kohgilüye ve Boyer-Ahmed', 'Kohgiluyeh and Buyer Ahmad', tag='Zagros'),
    ],
    'irn_khorasan': [
        S(None, 'Khorasan (Mashhad)', 'Horasan (Meşhed)', 59.6, 36.3, tag='holy city'),
        S('nishapur', 'Nishapur & Sabzevar', 'Nişabur ve Sebzevar', 57.6, 36.2, tag='Silk Road'),
        S('torbat', 'Torbat & Tayyebat', 'Turbet ve Tayyebat', 60.5, 35.2, tag='frontier'),
        K('north_khorasan', 'North Khorasan (Bojnord)', 'Kuzey Horasan (Bucnurd)', 'North Khorasan', tag='mountain'),
        K('quhistan', 'Quhistan (Birjand)', 'Kuhistan (Birced)', 'South Khorasan', tag='desert'),
    ],
    'irn_kerman': [
        S(None, 'Kerman', 'Kirman', 57.1, 30.3, tag='desert oasis'),
        S('jiroft', 'Jiroft & Bam', 'Ciruft ve Bem', 57.8, 28.0, tag='oasis'),
        S('sistan', 'Sistan (Zabol)', 'Sistan (Zabol)', 61.3, 31.0, tag='lake delta'),
        S('makran', 'Makran (Baluchistan)', 'Mekran (Belucistan)', 61.0, 26.8, tag='arid coast'),
        K('hormozgan', 'Hormozgan (Strait of Hormuz)', 'Hürmüzgan (Hürmüz Boğazı)', 'Hormozgan', tag='strait port'),
    ],
})

# ============================================================ CENTRAL ASIA AND AFGHANISTAN
SPLITS.update({
    'afg_badakhshan': [
        S(None, 'Badakhshan & Wakhan (Pamir)', 'Bedehşan ve Vahan (Pamir)', 71.4, 37.0, tag='mountain'),
        S('kabul', 'Kabul & Kohistan', 'Kabil ve Kohistan', 69.3, 34.7, tag='capital valley'),
        S('jalalabad', 'Jalalabad (Nangarhar & Kunar)', 'Celalabad (Nengerhar ve Kunar)', 70.6, 34.4, tag='Khyber approach'),
        S('balkh', 'Balkh (Bactria)', 'Belh (Baktriya)', 67.1, 36.7, tag='oasis plain'),
        S('tokharistan', 'Kunduz & Takhar (Tokharistan)', 'Kunduz ve Tahar (Tohâristan)', 69.2, 36.8, tag='river plain'),
        S('faryab', 'Faryab & Jawzjan', 'Faryab ve Cuzcan', 65.0, 36.4, tag='steppe'),
        S('bamyan', 'Bamyan (Hazarajat)', 'Bamyan (Hazaracat)', 67.2, 34.8, tag='mountain'),
    ],
    'afg_hilmand': [
        S(None, 'Kandahar & Helmand (Arachosia)', 'Kandahar ve Helmend (Arakozya)', 65.0, 31.3, tag='river oasis'),
        S('herat', 'Herat (Aria)', 'Herat (Aria)', 62.2, 34.3, tag='oasis city'),
        S('farah', 'Farah & Nimroz (Sistan Border)', 'Ferah ve Nimruz', 62.3, 31.8, tag='desert'),
        S('ghazni', 'Ghazni & Zabul', 'Gazne ve Zabul', 67.6, 32.8, tag='plateau'),
        S('ghor', 'Ghor (Ghorid Mountains)', 'Gur (Guriler Dağları)', 64.9, 34.2, tag='mountain'),
    ],
    'kaz_qaraghandy': [
        K(None, 'Karaganda (Saryarka)', 'Karaganda (Sarıarka)', 'Qaraghandy', tag='steppe mining'),
        K('kyzylorda', 'Kyzylorda (Syr Darya)', 'Kızılorda (Seyhun)', 'Qyzylorda', tag='river steppe'),
        K('akmola', 'Akmola (Astana)', 'Akmola (Astana)', 'Aqmola', 'Astana', tag='steppe'),
        K('pavlodar', 'Pavlodar (Irtysh)', 'Pavlodar (İrtiş)', 'Pavlodar', tag='river steppe'),
    ],
    'kaz_aqtobe': [
        K(None, 'Aktobe (Turgay)', 'Aktöbe (Turgay)', 'Aqtöbe', tag='steppe'),
        K('mangystau', 'Mangystau (Caspian Peninsula)', 'Mangistau (Hazar Yarımadası)', 'Mangghystau', tag='desert coast'),
        K('atyrau', 'Atyrau (Ural Mouth)', 'Atırav (Ural Ağzı)', 'Atyrau', tag='river mouth'),
        K('west_kazakhstan', 'West Kazakhstan (Ural River)', 'Batı Kazakistan (Ural Nehri)', 'West Kazakhstan', tag='river steppe'),
        K('kostanay', 'Kostanay & North Kazakhstan', 'Kostanay ve Kuzey Kazakistan', 'Qostanay', 'North Kazakhstan', tag='grain steppe'),
    ],
    'kaz_east_kazakhstan': [
        K(None, 'East Kazakhstan (Irtysh & Altai)', 'Doğu Kazakistan (İrtiş ve Altay)', 'East Kazakhstan', tag='mountain river'),
        K('semirechye', 'Semirechye (Almaty)', 'Yedisu (Almatı)', 'Almaty', 'Almaty City', tag='Tian Shan foothills'),
        K('zhambyl', 'Zhambyl (Talas)', 'Cambıl (Talas)', 'Zhambyl', tag='Silk Road'),
        K('turkestan', 'Turkestan (Syr Darya Cities)', 'Türkistan (Seyhun Şehirleri)', 'South Kazakhstan', tag='Silk Road'),
    ],
    'uzb_karakalpakstan': [
        K(None, 'Karakalpakstan (Aral Delta)', 'Karakalpakistan (Aral Deltası)', 'Karakalpakstan', tag='delta'),
        K('khorezm', 'Khorezm (Khiva)', 'Harezm (Hive)', 'Khorezm', tag='oasis'),
        K('navoi', 'Navoi (Kyzylkum)', 'Navoi (Kızılkum)', 'Navoi', tag='desert'),
    ],
    'uzb_bukhoro': [
        K(None, 'Bukhara', 'Buhara', 'Bukhoro', tag='oasis city'),
        K('samarkand', 'Samarkand (Sogdiana)', 'Semerkant (Soğdiyana)', 'Samarkand', 'Jizzakh', tag='Zeravshan oasis'),
        K('kashkadarya', 'Kashkadarya & Surkhandarya (Termez)', 'Kaşkaderya ve Surhanderya (Tirmiz)', 'Kashkadarya', 'Surkhandarya', tag='river crossing'),
        K('tashkent', 'Tashkent (Chach)', 'Taşkent (Çaç)', 'Tashkent', 'Sirdaryo', tag='oasis city'),
        K('fergana', 'Fergana Valley', 'Fergana Vadisi', 'Ferghana', 'Namangan', 'Andijon', tag='fertile valley'),
    ],
    'tkm_turkmenistan': [
        K(None, 'Ahal (Kopet Dag)', 'Ahal (Kopet Dağ)', 'Ahal', tag='piedmont oasis'),
        K('merv', 'Merv (Mary)', 'Merv (Mary)', 'Mary', tag='oasis city'),
        K('chardzhou', 'Chardzhou (Amu Darya)', 'Çarcev (Ceyhun)', 'Chardzhou', tag='river crossing'),
        K('balkan', 'Balkan (Caspian Coast)', 'Balkan (Hazar Kıyısı)', 'Balkan', tag='desert coast'),
        K('dashoguz', 'Dashoguz (Khorezm Oasis)', 'Daşoğuz (Harezm Vahası)', 'Tashauz', tag='oasis'),
    ],
    'kgz_kyrgyzstan': [
        K(None, 'Chuy & Talas', 'Çuy ve Talas', 'Chuy', 'Bishkek', 'Talas', tag='valley'),
        K('issyk_kul', 'Issyk-Kul', 'Issık Göl', 'Ysyk-Köl', tag='lake'),
        K('naryn', 'Naryn (Inner Tian Shan)', 'Narın (İç Tanrı Dağları)', 'Naryn', tag='mountain'),
        K('fergana_kg', 'Osh & Jalal-Abad (Fergana East)', 'Oş ve Celalabad (Doğu Fergana)', 'Osh', 'Jalal-Abad', 'Batken', tag='fertile valley'),
    ],
    'tjk_tajikistan': [
        K(None, 'Dushanbe & Karategin', 'Duşanbe ve Karategin', 'Dushanbe', 'Tadzhikistan Territories', tag='mountain valley'),
        K('sughd', 'Sughd (Khujand)', 'Sogd (Hucand)', 'Leninabad', tag='Silk Road'),
        K('khatlon', 'Khatlon (Kulob)', 'Hatlon (Külab)', 'Khatlon', tag='river valley'),
        K('pamir', 'Pamir (Gorno-Badakhshan)', 'Pamir (Dağlık Bedehşan)', 'Gorno-Badakhshan', tag='mountain'),
    ],
    'mng_omnogovi': [
        K(None, 'Gobi (Ömnögovi & Dornogovi)', 'Gobi (Ömnögovi ve Dornogovi)', 'Ömnögovi', 'Dornogovi', 'Dundgovi', tag='desert'),
        K('khentii', 'Khentii & Dornod (Eastern Steppe)', 'Hentiy ve Dornod (Doğu Bozkırı)', 'Dornod', 'Sühbaatar', 'Hentiy', tag='steppe'),
        K('tuul', 'Tuul Valley (Ulaanbaatar)', 'Tola Vadisi (Ulan Batur)', 'Töv', 'Ulaanbaatar', 'Govĭ-Sümber', tag='river valley'),
        K('khangai_south', 'Khangai (Övörhangay & Bayankhongor)', 'Hangay (Övörhangay ve Bayanhongor)', 'Övörhangay', 'Bayanhongor', tag='mountain pasture'),
    ],
    'mng_govi_altay': [
        K(None, 'Govi-Altai & Zavkhan', 'Gobi-Altay ve Zavhan', 'Govi-Altay', 'Dzavhan', tag='mountain desert'),
        K('khovd', 'Khovd & Bayan-Ölgii (Altai)', 'Hovd ve Bayan-Ölgii (Altay)', 'Hovd', 'Bayan-Ölgiy', tag='mountain'),
        K('uvs', 'Uvs & Khövsgöl (Northwest)', 'Uvs ve Hövsgöl (Kuzeybatı)', 'Uvs', 'Hövsgöl', tag='lake'),
        K('orkhon', 'Orkhon-Selenge (Karakorum)', 'Orhun-Selenge (Karakurum)', 'Arhangay', 'Bulgan', 'Selenge', 'Darhan-Uul', 'Orhon', tag='river valley'),
    ],
})

# ============================================================ SOUTH ASIA
SPLITS.update({
    'ind_rajasthan': [
        S(None, 'Rajputana (Jaipur & Ajmer)', 'Racputana (Jaipur ve Acmer)', 75.6, 26.8, tag='plateau'),
        S('marwar', 'Marwar (Jodhpur)', 'Marvar (Codhpur)', 72.8, 26.3, tag='desert edge'),
        S('mewar', 'Mewar (Udaipur)', 'Mevar (Udaipur)', 73.8, 24.5, tag='hills'),
        S('thar', 'Thar Desert (Jaisalmer & Bikaner)', 'Thar Çölü (Caysalmer ve Bikaner)', 71.0, 27.8, tag='desert'),
        S('gujarat', 'Gujarat (Ahmedabad)', 'Gucerat (Ahmedabad)', 72.7, 23.0, tag='trade plain'),
        S('saurashtra', 'Saurashtra (Kathiawar)', 'Sourashtra (Kathiavar)', 70.7, 21.9, tag='peninsula coast'),
        S('kutch', 'Kutch', 'Kaç', 69.7, 23.6, tag='salt desert'),
    ],
    'ind_madhya_pradesh': [
        S(None, 'Malwa (Ujjain & Indore)', 'Malva (Ujjain ve İndor)', 75.8, 23.3, tag='plateau'),
        S('doab', 'Doab (Delhi–Agra Gangetic Plain)', 'Doab (Ganj-Yamuna Ovası)', 78.0, 27.8, tag='river plain'),
        S('awadh', 'Awadh (Lucknow)', 'Avadh (Lakhnau)', 81.0, 26.8, tag='river plain'),
        S('purvanchal', 'Purvanchal (Benares)', 'Purvançal (Benares)', 83.2, 26.0, tag='holy river city'),
        S('bundelkhand', 'Bundelkhand', 'Bundelhand', 79.3, 25.3, tag='plateau'),
        S('mahakoshal', 'Mahakoshal (Jabalpur)', 'Mahakoşal (Cabalpur)', 79.9, 23.0, tag='hills'),
        S('baghelkhand', 'Baghelkhand (Rewa)', 'Bagelhand (Reva)', 81.3, 24.3, tag='plateau'),
    ],
    'ind_maharashtra': [
        S(None, 'Deccan (Pune & Nashik)', 'Dekkan (Pune ve Nasik)', 74.2, 18.7, tag='plateau'),
        S('konkan', 'Konkan (Mumbai)', 'Konkan (Bombay)', 73.2, 18.8, tag='trade port'),
        S('khandesh', 'Khandesh', 'Kandeş', 75.5, 21.0, tag='river valley'),
        S('vidarbha', 'Vidarbha (Nagpur)', 'Vidarbha (Nagpur)', 79.0, 20.8, tag='cotton plain'),
        S('marathwada', 'Marathwada (Aurangabad)', 'Marathvada (Aurangabad)', 76.5, 19.3, tag='plateau'),
    ],
    'ind_odisha': [
        S(None, 'Odisha (Kalinga Coast)', 'Odişa (Kalinga Kıyısı)', 85.8, 20.4, tag='coast'),
        S('sambalpur', 'Western Odisha (Sambalpur)', 'Batı Odişa (Sambalpur)', 83.8, 21.0, tag='plateau'),
        K('chhattisgarh', 'Chhattisgarh (Dakshina Kosala)', 'Çhattisgarh (Dakşina Kosala)', 'Chhattisgarh', tag='plateau'),
    ],
    'ind_karnataka': [
        S(None, 'Mysore (Southern Karnataka)', 'Maysor (Güney Karnataka)', 76.6, 13.2, tag='plateau'),
        S('north_karnataka', 'Northern Karnataka (Bijapur & Dharwad)', 'Kuzey Karnataka (Bicapur ve Dharvad)', 75.6, 16.0, tag='plateau'),
        S('goa_konkan', 'Goa & Karwar', 'Goa ve Karvar', 74.0, 15.3, tag='port coast'),
        S('telangana', 'Telangana (Hyderabad)', 'Telengana (Haydarabad)', 79.0, 17.8, tag='plateau'),
        S('andhra_coast', 'Andhra Coast (Krishna-Godavari Delta)', 'Andra Kıyısı (Krişna-Godavari Deltası)', 80.5, 16.3, tag='delta'),
        S('rayalaseema', 'Rayalaseema', 'Rayalaseema', 78.5, 14.5, tag='dry plateau'),
        S('kalinga_north', 'Northern Circars (Visakhapatnam)', 'Kuzey Circarlar (Visakhapatnam)', 83.0, 18.0, tag='coast'),
    ],
    'ind_tamil_nadu': [
        S(None, 'Chola Nadu (Cauvery Delta)', 'Çola Ülkesi (Kaveri Deltası)', 79.2, 10.8, tag='river delta'),
        S('tondaimandalam', 'Tondaimandalam (Chennai)', 'Tondaimandalam (Madras)', 79.8, 12.8, tag='coast'),
        S('kongu', 'Kongu Nadu (Coimbatore)', 'Kongu Ülkesi (Koyambattur)', 77.0, 11.0, tag='mountain pass'),
        S('pandya', 'Pandya Nadu (Madurai)', 'Pandya Ülkesi (Madurai)', 78.2, 9.7, tag='plain'),
        K('kerala', 'Kerala (Malabar Coast)', 'Kerala (Malabar Kıyısı)', 'Kerala', 'Lakshadweep', tag='spice coast'),
    ],
    'ind_arunachal_pradesh': explode(15000, keep='Arunachal Pradesh', rename={'Assam': ('Assam (Brahmaputra Valley)', 'Assam (Brahmaputra Vadisi)')}),
    'ind_bihar': [
        K(None, 'Bihar (Magadha)', 'Bihar (Magadha)', 'Bihar', tag='river plain'),
        K('jharkhand', 'Jharkhand (Chota Nagpur)', 'Jharkhand (Chota Nagpur)', 'Jharkhand', tag='mining plateau'),
        S('bengal', 'Bengal (Gangetic Delta)', 'Bengal (Ganj Deltası)', 88.0, 23.0, tag='delta'),
        S('north_bengal', 'North Bengal & Sikkim', 'Kuzey Bengal ve Sikkim', 88.3, 26.6, tag='foothills'),
    ],
    'ind_ladakh': [
        K(None, 'Ladakh', 'Ladak', 'Ladakh', tag='high mountain'),
        K('uttarakhand', 'Uttarakhand (Garhwal & Kumaon)', 'Uttarakhand (Garhval ve Kumaon)', 'Uttarakhand', tag='mountain'),
        K('himachal', 'Himachal', 'Himaçal', 'Himachal Pradesh', tag='mountain'),
        K('kashmir', 'Kashmir & Jammu', 'Keşmir ve Cammu', 'Jammu and Kashmir', tag='valley'),
        K('punjab_in', 'Punjab (East)', 'Pencap (Doğu)', 'Punjab', 'Chandigarh', tag='river plain'),
        K('haryana', 'Haryana (Kurukshetra)', 'Haryana (Kurukşetra)', 'Haryana', tag='battleground plain'),
        K('delhi', 'Delhi', 'Delhi', 'Delhi', tag='capital city'),
    ],
    'pak_baluchistan': [
        S(None, 'Kalat (Central Baluchistan)', 'Kelat (Orta Belucistan)', 66.5, 28.3, tag='desert mountain'),
        S('quetta', 'Quetta & Bolan', 'Kuetta ve Bolan', 67.0, 30.2, tag='mountain pass'),
        S('makran_pk', 'Makran Coast', 'Mekran Kıyısı', 63.5, 25.8, tag='arid coast'),
        S('lower_sindh', 'Lower Sindh (Karachi & Indus Delta)', 'Aşağı Sind (Karaçi ve İndus Deltası)', 68.0, 25.0, tag='delta port'),
        S('upper_sindh', 'Upper Sindh (Sukkur)', 'Yukarı Sind (Sukkur)', 68.8, 27.3, tag='river valley'),
        S('tharparkar', 'Tharparkar', 'Tharparkar', 70.2, 25.0, tag='desert'),
    ],
    'pak_k_p': [
        K(None, 'Peshawar & Swat (Gandhara)', 'Peşaver ve Svat (Gandhara)', 'K.P.', tag='valley'),
        K('gilgit', 'Gilgit-Baltistan', 'Gilgit-Baltistan', 'Northern Areas', tag='high mountain'),
        K('khyber', 'Khyber & Tribal Areas', 'Hayber ve Kabile Bölgeleri', 'F.A.T.A.', tag='mountain pass'),
        K('potohar', 'Potohar & Azad Kashmir', 'Potohar ve Azad Keşmir', 'Azad Kashmir', 'F.C.T.', tag='plateau'),
    ],
    'pak_punjab': [
        S(None, 'Lahore (Upper Punjab)', 'Lahor (Yukarı Pencap)', 74.2, 31.5, tag='river plain'),
        S('multan', 'Multan (Lower Punjab)', 'Multan (Aşağı Pencap)', 71.5, 30.5, tag='river plain'),
        S('salt_range', 'Salt Range & Jhelum', 'Tuz Sıradağları ve Celum', 72.6, 32.8, tag='foothills'),
        S('bahawalpur', 'Bahawalpur & Cholistan', 'Bahavalpur ve Çolistan', 71.8, 28.9, tag='desert edge'),
    ],
    'npl_nepal': [
        S(None, 'Kathmandu Valley (Bagmati)', 'Katmandu Vadisi (Bagmati)', 85.3, 27.7, tag='valley'),
        S('western_nepal', 'Western Nepal (Karnali)', 'Batı Nepal (Karnali)', 82.0, 29.0, tag='mountain'),
        S('eastern_nepal', 'Eastern Nepal (Koshi)', 'Doğu Nepal (Koşi)', 87.0, 27.2, tag='mountain'),
    ],
    'bgd_bangladesh': [
        K(None, 'Dhaka (Bengal Heartland)', 'Dakka (Bengal)', 'Dhaka', tag='delta'),
        K('chittagong', 'Chittagong', 'Çittagong', 'Chittagong', tag='port hills'),
        K('sylhet', 'Sylhet', 'Silet', 'Sylhet', tag='tea hills'),
        K('varendra', 'Varendra (Rajshahi & Rangpur)', 'Varendra (Racşahi ve Rangpur)', 'Rajshahi', 'Rangpur', tag='river plain'),
        K('khulna_barisal', 'Khulna & Barisal (Sundarbans)', 'Kulna ve Barisal (Sundarban)', 'Khulna', 'Barisal', tag='mangrove delta'),
    ],
    'lka_sri_lanka': [
        S(None, 'Colombo & Western Province', 'Kolombo ve Batı Eyaleti', 80.0, 6.9, tag='trade port'),
        S('kandy', 'Kandy (Hill Country)', 'Kandi (Dağlık Bölge)', 80.7, 7.3, tag='mountain'),
        S('jaffna', 'Jaffna & Northern Province', 'Yafna ve Kuzey Eyaleti', 80.1, 9.6, tag='peninsula'),
        S('rajarata', 'Rajarata (Anuradhapura)', 'Racarata (Anuradhapura)', 80.4, 8.3, tag='dry zone'),
        S('ruhuna', 'Ruhuna (Galle & Hambantota)', 'Ruhuna (Galle ve Hambantota)', 80.7, 6.2, tag='south coast'),
        S('east_ceylon', 'East Coast (Trincomalee & Batticaloa)', 'Doğu Kıyısı (Trincomalee ve Batticaloa)', 81.4, 7.9, tag='harbour coast'),
    ],
})

# ============================================================ EAST ASIA
SPLITS.update({
    'chn_guangxi': [
        K(None, 'Guangxi (Lingnan West)', 'Guangksi (Batı Lingnan)', 'Guangxi', tag='karst highland'),
        K('guangdong', 'Guangdong (Pearl River Delta)', 'Guangdong (İnci Nehri Deltası)', 'Guangdong', tag='trade port'),
        K('fujian', 'Fujian', 'Fucien', 'Fujian', tag='mountain coast'),
        K('zhejiang', 'Zhejiang & Shanghai', 'Çekiang ve Şanghay', 'Zhejiang', 'Shanghai', tag='delta coast'),
        K('jiangxi', 'Jiangxi (Gan River)', 'Ciangsi (Gan Nehri)', 'Jiangxi', tag='river valley'),
        K('hainan', 'Hainan', 'Hainan', 'Hainan', 'Paracel Islands', tag='island'),
    ],
    'chn_inner_mongol': [
        S(None, 'Ordos & Hetao (Yellow River Bend)', 'Ordos ve Hetao (Sarı Nehir Dirseği)', 109.0, 40.2, tag='river steppe'),
        S('chahar', 'Chahar (Hohhot & Zhangjiakou Steppe)', 'Çahar (Hohhot ve Cangcyakou Bozkırı)', 113.5, 42.3, tag='steppe frontier'),
        S('hulunbuir', 'Hulunbuir (Barga)', 'Hulunbuir (Barga)', 119.5, 49.0, tag='steppe'),
        S('khingan', 'Hinggan & Tongliao (Khorchin)', 'Hingan ve Tongliao (Korçin)', 122.0, 44.5, tag='steppe'),
        S('alxa', 'Alxa (Western Desert)', 'Alaşan (Batı Çölü)', 103.0, 39.5, tag='desert'),
    ],
    'chn_xinjiang': [
        S(None, 'Dzungaria (Ürümqi)', 'Cungarya (Urumçi)', 87.5, 44.5, tag='steppe basin'),
        S('tarim_north', 'Northern Tarim (Aksu & Kashgar)', 'Kuzey Tarım (Aksu ve Kaşgar)', 79.0, 40.5, tag='oasis Silk Road'),
        S('tarim_south', 'Southern Tarim (Khotan)', 'Güney Tarım (Hotan)', 80.0, 37.2, tag='oasis Silk Road'),
        S('turpan_hami', 'Turpan & Hami', 'Turfan ve Hami', 91.5, 42.8, tag='oasis gateway'),
        S('ili', 'Ili Valley (Yining)', 'İli Vadisi (Gulca)', 82.0, 43.8, tag='river valley'),
        S('lop_nur', 'Lop Nur & Charklik', 'Lop Nur ve Çarklık', 88.5, 38.8, tag='desert'),
    ],
    'chn_xizang': [
        S(None, 'Central Tibet (Lhasa)', 'Orta Tibet (Lhasa)', 91.1, 29.7, tag='river valley plateau'),
        S('tsang', 'Tsang (Shigatse)', 'Tsang (Şigatse)', 88.8, 29.3, tag='river valley plateau'),
        S('ngari', 'Western Tibet (Ngari)', 'Batı Tibet (Ngari)', 82.0, 32.0, tag='plateau'),
        S('changtang', 'Changtang (Northern Plateau)', 'Çangtang (Kuzey Platosu)', 87.0, 34.0, tag='plateau'),
        S('kham_west', 'Chamdo (Western Kham)', 'Çamdo (Batı Kham)', 97.2, 31.2, tag='mountain'),
    ],
    'chn_sichuan': [
        S(None, 'Sichuan Basin (Chengdu)', 'Sıçuan Havzası (Çengdu)', 104.5, 30.6, tag='fertile basin'),
        S('western_sichuan', 'Western Sichuan (Garze & Aba)', 'Batı Sıçuan (Garze ve Aba)', 101.0, 31.0, tag='mountain'),
        S('guanzhong', 'Guanzhong (Xi\'an Plain)', 'Guanzhong (Şian Ovası)', 108.9, 34.3, tag='capital plain'),
        S('hanzhong', 'Hanzhong (Qinling South)', 'Hanzhong (Çinling Güneyi)', 107.0, 33.0, tag='mountain valley'),
        S('north_shaanxi', 'Northern Shaanxi (Yan\'an & Yulin)', 'Kuzey Şensi (Yanan ve Yulin)', 109.5, 37.0, tag='loess plateau'),
    ],
    'chn_jilin': [
        K(None, 'Jilin (Manchurian Plain)', 'Cilin (Mançurya Ovası)', 'Jilin', tag='plain'),
        K('liaoning', 'Liaoning (Liaodong)', 'Liaoning (Liaodong)', 'Liaoning', tag='peninsula coast'),
        K('shandong', 'Shandong', 'Şandong', 'Shandong', tag='peninsula'),
        K('hebei', 'Hebei (Yan & Zhao)', 'Hebei', 'Hebei', tag='north China plain'),
        K('beijing', 'Beijing & Tianjin', 'Pekin ve Tiencin', 'Beijing', 'Tianjin', tag='capital city'),
        K('shanxi', 'Shanxi', 'Şanşi', 'Shanxi', tag='mountain plateau'),
    ],
    'chn_hunan': [
        K(None, 'Hunan (Xiang River)', 'Hunan (Xiang Nehri)', 'Hunan', tag='river valley'),
        K('jiangsu', 'Jiangsu (Lower Yangtze)', 'Ciangsu (Aşağı Yangtze)', 'Jiangsu', tag='delta'),
        K('henan', 'Henan (Central Plain)', 'Henan (Orta Ova)', 'Henan', tag='Yellow River plain'),
        K('hubei', 'Hubei (Middle Yangtze)', 'Hubei (Orta Yangtze)', 'Hubei', tag='river lakes'),
        K('anhui', 'Anhui (Huai River)', 'Anhui (Huai Nehri)', 'Anhui', tag='river plain'),
    ],
    'chn_yunnan': [
        S(None, 'Yunnan (Kunming)', 'Yunnan (Kunming)', 102.7, 25.0, tag='plateau lake'),
        S('dali', 'Dali & Western Yunnan', 'Dali ve Batı Yunnan', 99.8, 25.5, tag='mountain'),
        S('xishuangbanna', 'Xishuangbanna (Southern Yunnan)', 'Sişuangbanna (Güney Yunnan)', 100.8, 22.0, tag='tropical frontier'),
        K('chongqing', 'Chongqing (Ba)', 'Çungçing (Ba)', 'Chongqing', tag='river junction'),
        K('guizhou', 'Guizhou', 'Guyçou', 'Guizhou', tag='karst mountain'),
    ],
    'chn_qinghai': [
        S(None, 'Qinghai (Xining & Koko Nor)', 'Çinghay (Sining ve Kokonor)', 100.5, 36.5, tag='plateau lake'),
        S('qaidam', 'Qaidam Basin', 'Qaidam Havzası', 95.0, 37.0, tag='desert basin'),
        S('yushu', 'Yushu (Upper Yangtze)', 'Yuşu (Yukarı Yangtze)', 96.5, 33.5, tag='plateau'),
        S('hexi', 'Hexi Corridor (Zhangye & Jiuquan)', 'Hexi Koridoru (Canye ve Ciuçuan)', 99.0, 39.0, tag='Silk Road corridor'),
        S('longyou', 'Longyou (Lanzhou & Tianshui)', 'Longyou (Lançov ve Tiyançuy)', 104.5, 35.5, tag='river valley'),
        K('ningxia', 'Ningxia (Yinchuan)', 'Ningşya (Yinçuan)', 'Ningxia', tag='river oasis'),
    ],
    'chn_heilongjiang': [
        S(None, 'Harbin (Songhua Valley)', 'Harbin (Songhua Vadisi)', 126.5, 45.8, tag='river plain'),
        S('qiqihar', 'Qiqihar (Nen River)', 'Çiçihar (Nen Nehri)', 123.9, 47.3, tag='river plain'),
        S('amur_north', 'Northern Heilongjiang (Amur)', 'Kuzey Hılongciang (Amur)', 127.5, 50.5, tag='taiga'),
        S('sanjiang', 'Sanjiang Plain', 'Sanciang Ovası', 133.0, 47.0, tag='wetland plain'),
    ],
    'jpn_hokkaido': [
        S(None, 'Hokkaido (Ishikari)', 'Hokkaido (İşikari)', 141.5, 43.2, tag='frontier island'),
        S('oshima', 'Oshima (Matsumae)', 'Oşima (Matsumae)', 140.3, 42.0, tag='strait'),
        S('east_hokkaido', 'Eastern Hokkaido (Kushiro)', 'Doğu Hokkaido (Kuşiro)', 144.0, 43.3, tag='frontier'),
        K('aomori', 'Tsugaru & Nanbu (Aomori)', 'Tsugaru ve Nanbu (Aomori)', 'Aomori', tag='strait'),
    ],
    'jpn_iwate': [
        K(None, 'Mutsu (Iwate & Miyagi)', 'Mutsu (İvate ve Miyagi)', 'Iwate', 'Miyagi', tag='frontier'),
        K('dewa', 'Dewa (Akita & Yamagata)', 'Dewa (Akita ve Yamagata)', 'Akita', 'Yamagata', tag='coast basin'),
        K('echigo', 'Echigo (Niigata)', 'Echigo (Niigata)', 'Niigata', tag='plain coast'),
        K('hokuriku', 'Hokuriku (Kaga & Etchu)', 'Hokuriku (Kaga ve Etçu)', 'Ishikawa', 'Toyama', tag='coast'),
        K('iwaki', 'Iwaki (Fukushima)', 'Ivaki (Fukuşima)', 'Fukushima', tag='basin'),
    ],
    'jpn_nagano': [
        K(None, 'Shinano & Kai (Nagano)', 'Şinano ve Kai (Nagano)', 'Nagano', 'Yamanashi', tag='mountain'),
        K('north_kyushu', 'Northern Kyushu (Chikuzen & Hizen)', 'Kuzey Kyuşu (Çikuzen ve Hizen)', 'Fukuoka', 'Saga', 'Nagasaki', tag='strait port'),
        K('south_kyushu', 'Southern Kyushu (Satsuma & Higo)', 'Güney Kyuşu (Satsuma ve Higo)', 'Kagoshima', 'Miyazaki', 'Kumamoto', 'Ōita', tag='volcanic'),
        K('shikoku', 'Shikoku', 'Şikoku', 'Tokushima', 'Kagawa', 'Ehime', 'Kōchi', tag='island'),
        K('sanyo', 'San\'yo (Inland Sea Coast)', 'San\'yo (İç Deniz Kıyısı)', 'Okayama', 'Hiroshima', 'Yamaguchi', tag='sea route'),
        K('sanin', 'San\'in (Izumo)', 'San\'in (İzumo)', 'Shimane', 'Tottori', tag='coast'),
        K('kinai', 'Kinai (Kyoto, Osaka & Nara)', 'Kinai (Kyoto, Osaka ve Nara)', 'Kyōto', 'Ōsaka', 'Nara', 'Shiga', 'Hyōgo', 'Wakayama', 'Fukui', tag='imperial core'),
        K('tokai', 'Tokai (Owari & Mikawa)', 'Tokay (Owari ve Mikava)', 'Aichi', 'Gifu', 'Mie', tag='highway plain'),
        K('suruga', 'Suruga & Tōtōmi (Shizuoka)', 'Suruga ve Tōtōmi (Şizuoka)', 'Shizuoka', tag='Tokaido coast'),
        K('kanto', 'Kanto (Edo)', 'Kanto (Edo)', 'Tokyo', 'Kanagawa', 'Chiba', 'Saitama', tag='plain'),
        K('north_kanto', 'North Kanto (Hitachi & Kozuke)', 'Kuzey Kanto (Hitaçi ve Kozuke)', 'Ibaraki', 'Tochigi', 'Gunma', tag='plain'),
    ],
    'kor_gangwon': [
        K(None, 'Gangwon (Taebaek Mountains)', 'Gangwon (Taebaek Dağları)', 'Gangwon', tag='mountain'),
        K('hanseong', 'Seoul & Gyeonggi (Hanseong)', 'Seul ve Gyeonggi (Hanseong)', 'Gyeonggi', 'Seoul', 'Incheon', tag='capital hinterland'),
        K('chungcheong', 'Chungcheong (Daejeon)', 'Chungcheong (Taejon)', 'South Chungcheong', 'North Chungcheong', 'Daejeon', 'Sejong', tag='basin'),
    ],
    'kor_north_gyeongsang': [
        K(None, 'North Gyeongsang (Daegu)', 'Kuzey Gyeongsang (Taegu)', 'North Gyeongsang', 'Daegu', tag='basin'),
        K('south_gyeongsang', 'South Gyeongsang (Busan)', 'Güney Gyeongsang (Busan)', 'South Gyeongsang', 'Busan', 'Ulsan', tag='port strait'),
        K('jeolla', 'Jeolla (Honam)', 'Jeolla (Honam)', 'North Jeolla', 'South Jeolla', 'Gwangju', tag='rice plain'),
        K('jeju', 'Jeju', 'Çeçu', 'Jeju', tag='island'),
    ],
    'prk_north_korea': [
        K(None, 'Pyongan (Pyongyang)', 'Pyongan (Pyongyang)', "P'yŏngyang", "P'yŏngan-namdo", "P'yŏngan-bukto", tag='river plain'),
        K('hwanghae', 'Hwanghae (Kaesong)', 'Hwanghae (Kaesong)', 'Hwanghae-namdo', 'Hwanghae-bukto', tag='plain'),
        K('kangwon_north', 'Kangwon (Wonsan)', 'Kangwon (Wonsan)', 'Kangwŏn-do', tag='coast'),
        K('hamgyong', 'Hamgyong (Northeast)', 'Hamgyong (Kuzeydoğu)', 'Hamgyŏng-namdo', 'Hamgyŏng-bukto', 'Rasŏn', tag='mountain coast'),
        K('ryanggang', 'Ryanggang & Chagang', 'Ryanggang ve Chagang', 'Ryanggang', 'Chagang-do', tag='mountain'),
    ],
    'twn_taiwan': [
        K(None, 'Northern Taiwan (Taipei & Hsinchu)', 'Kuzey Tayvan (Taypey ve Hsinçu)', 'Taoyuan', 'Hsinchu', 'Hsinchu City', 'Miaoli', 'New Taipei City', 'Keelung City', 'Taipei City', 'Yilan', tag='basin'),
        K('central_taiwan', 'Central Taiwan (Taichung)', 'Orta Tayvan (Taiçung)', 'Taichung City', 'Changhua', 'Yunlin', 'Nantou', tag='plain'),
        K('south_taiwan', 'Southern Taiwan (Tainan & Kaohsiung)', 'Güney Tayvan (Tainan ve Kaohsiung)', 'Chiayi', 'Chiayi City', 'Tainan City', 'Kaohsiung City', 'Pingtung', 'Penghu', tag='plain port'),
        K('east_taiwan', 'Eastern Taiwan (Hualien & Taitung)', 'Doğu Tayvan (Hualien ve Taitung)', 'Hualien', 'Taitung', tag='mountain coast'),
    ],
})

# ============================================================ SOUTHEAST ASIA
SPLITS.update({
    'tha_chiang_mai': [
        K(None, 'Lanna (Chiang Mai)', 'Lanna (Chiang Mai)', 'Chiang Mai', 'Chiang Rai', 'Phayao', 'Nan', 'Mae Hong Son', tag='mountain valley'),
        K('sukhothai', 'Sukhothai (Phitsanulok & Tak)', 'Sukhothai (Phitsanulok ve Tak)', 'Phitsanulok', 'Uttaradit', 'Tak', tag='river plain'),
        K('lower_isan', 'Lower Isan (Khorat Plateau South)', 'Aşağı Isan (Khorat Platosu Güneyi)', 'Surin', 'Si Sa Ket', 'Ubon Ratchathani', 'Buri Ram', 'Amnat Charoen', 'Sa Kaeo', tag='plateau'),
        K('upper_isan', 'Upper Isan (Mekong Bank)', 'Yukarı Isan (Mekong Kıyısı)', 'Nong Khai', 'Loei', 'Bueng Kan', 'Nakhon Phanom', 'Mukdahan', tag='river plateau'),
        K('chao_phraya', 'Chao Phraya Delta (Bangkok)', 'Chao Phraya Deltası (Bangkok)', 'Bangkok Metropolis', 'Samut Prakan', 'Samut Sakhon', 'Samut Songkhram', 'Ratchaburi', 'Phetchaburi', tag='delta capital'),
        K('kanchanaburi', 'Kanchanaburi (Three Pagodas Pass)', 'Kanchanaburi (Üç Pagoda Geçidi)', 'Kanchanaburi', tag='mountain pass'),
    ],
    'tha_surat_thani': [
        K(None, 'Isthmus of Kra (Surat Thani & Chumphon)', 'Kra Kıstağı (Surat Thani ve Chumphon)', 'Surat Thani', 'Chumphon', 'Prachuap Khiri Khan', tag='isthmus'),
        K('ligor', 'Nakhon Si Thammarat (Ligor)', 'Nakhon Si Thammarat (Ligor)', 'Nakhon Si Thammarat', 'Phatthalung', 'Trang', tag='coast'),
        K('pattani', 'Pattani (Songkhla & Malay South)', 'Pattani (Songkhla ve Malay Güneyi)', 'Songkhla', 'Yala', 'Narathiwat', 'Pattani', 'Satun', tag='strait'),
        K('andaman_coast', 'Andaman Coast (Phuket & Krabi)', 'Andaman Kıyısı (Phuket ve Krabi)', 'Phuket', 'Phangnga', 'Krabi', 'Ranong', tag='coast'),
        K('eastern_gulf', 'Eastern Gulf Coast (Rayong & Chanthaburi)', 'Doğu Körfez Kıyısı (Rayong ve Chanthaburi)', 'Rayong', 'Chanthaburi', 'Trat', tag='coast'),
    ],
    'vnm_nghe_an': [
        K(None, 'North Annam (Thanh Hoa & Nghe An)', 'Kuzey Annam (Thanh Hoa ve Nghe An)', 'Thanh Hóa', 'Nghệ An', 'Ha Tinh', tag='coast'),
        K('tonkin_delta', 'Tonkin Delta (Hanoi)', 'Tonkin Deltası (Hanoi)', 'Ha Noi', 'Hải Phòng', 'Nam Định', 'Thái Bình', 'Ninh Bình', 'Vĩnh Phúc', 'Bắc Ninh', 'Đồng Bằng Sông Hồng', tag='river delta'),
        K('viet_bac', 'Northeast Tonkin (Lang Son & Ha Long)', 'Kuzeydoğu Tonkin (Lang Son ve Ha Long)', 'Lạng Sơn', 'Cao Bằng', 'Quảng Ninh', 'Đông Bắc', 'Hà Giang', tag='frontier coast'),
        K('tay_bac', 'Northwest Tonkin (Son La & Dien Bien)', 'Kuzeybatı Tonkin (Son La ve Dien Bien)', 'Điện Biên', 'Son La', 'Hòa Bình', 'Lai Chau', 'Lào Cai', 'Yên Bái', 'Tuyên Quang', 'Phú Thọ', tag='mountain'),
        K('quang_binh', 'Quang Binh (Gate of Annam)', 'Quang Binh (Annam Kapısı)', 'Quảng Bình', tag='narrow coast'),
    ],
    'vnm_gia_lai': [
        K(None, 'Central Highlands (Gia Lai & Dak Lak)', 'Orta Yaylalar (Gia Lai ve Dak Lak)', 'Gia Lai', 'Kon Tum', 'Đắk Lắk', 'Đắk Nông', tag='plateau'),
        K('mekong_delta', 'Mekong Delta', 'Mekong Deltası', 'Long An', 'Ðong Tháp', 'An Giang', 'Kiên Giang', 'Cà Mau', 'Bạc Liêu', 'Sóc Trăng', 'Hau Giang', 'Vĩnh Long', 'Trà Vinh', 'Bến Tre', 'Tiền Giang', tag='river delta'),
        K('saigon', 'Saigon & Dong Nai', 'Saygon ve Dong Nai', 'Hồ Chí Minh city', 'Tây Ninh', 'Bình Phước', 'Bà Rịa - Vũng Tàu', 'Đông Nam Bộ', tag='river port'),
        K('hue_champa', 'Hue, Quang Nam & Champa Coast', 'Hue, Quang Nam ve Çampa Kıyısı', 'Quảng Trị', 'Thừa Thiên - Huế', 'Quàng Nam', 'Khánh Hòa', tag='coast'),
    ],
    'khm_cambodia': [
        S(None, 'Phnom Penh & Mekong (Kandal)', 'Phnom Penh ve Mekong', 104.9, 11.6, tag='river junction'),
        S('angkor', 'Angkor (Siem Reap & Battambang)', 'Angkor (Siem Reap ve Battambang)', 103.6, 13.5, tag='Tonle Sap'),
        S('tonle_sap', 'Tonle Sap East (Kampong Thom & Cham)', 'Tonle Sap Doğusu (Kampong Thom ve Cham)', 105.0, 12.5, tag='lake plain'),
        S('northeast_cambodia', 'Northeast Cambodia (Ratanakiri)', 'Kuzeydoğu Kamboçya (Ratanakiri)', 106.6, 13.3, tag='highland'),
        S('cambodia_coast', 'Southwest Coast (Kampot & Koh Kong)', 'Güneybatı Kıyısı (Kampot ve Koh Kong)', 103.7, 11.0, tag='coast'),
    ],
    'lao_laos': [
        K(None, 'Luang Prabang', 'Luang Prabang', 'Louangphrabang', 'Oudômxai', 'Bokeo', 'Louang Namtha', 'Phôngsali', tag='river mountain'),
        K('vientiane', 'Vientiane Plain', 'Vientiane Ovası', 'Vientiane', 'Vientiane [prefecture]', 'Xaignabouri', 'Bolikhamxai', tag='river plain'),
        K('xiang_khouang', 'Xieng Khouang (Plain of Jars)', 'Xieng Khouang (Testi Ovası)', 'Xiangkhoang', 'Houaphan', tag='plateau'),
        K('savannakhet', 'Savannakhet & Khammouan', 'Savannakhet ve Khammouan', 'Savannakhét', 'Khammouan', tag='river plain'),
        K('champasak', 'Champasak (Bolaven)', 'Champasak (Bolaven)', 'Champasak', 'Saravan', 'Xékong', 'Attapu', tag='plateau'),
    ],
    'mmr_shan': [
        K(None, 'Shan Plateau', 'Shan Platosu', 'Shan', tag='plateau'),
        K('kachin', 'Kachin (Myitkyina)', 'Kaçin (Myitkyina)', 'Kachin', tag='mountain river'),
        K('arakan', 'Arakan (Rakhine)', 'Arakan (Rakhine)', 'Rakhine', tag='coast'),
        K('chin', 'Chin Hills', 'Çin Tepeleri', 'Chin', tag='mountain'),
        K('sagaing', 'Sagaing (Upper Chindwin)', 'Sagaing (Yukarı Chindwin)', 'Sagaing', tag='river valley'),
        K('upper_burma', 'Upper Burma (Mandalay & Magway)', 'Yukarı Burma (Mandalay ve Magway)', 'Mandalay', 'Magway', tag='river dry zone'),
    ],
    'mmr_tanintharyi': [
        K(None, 'Tenasserim', 'Tenasserim', 'Tanintharyi', tag='coast'),
        K('martaban', 'Martaban (Mon & Kayin)', 'Martaban (Mon ve Kayin)', 'Mon', 'Kayin', 'Kayah', tag='river coast'),
        K('pegu', 'Pegu (Bago)', 'Pegu (Bago)', 'Bago', tag='river plain'),
        K('irrawaddy_delta', 'Irrawaddy Delta (Yangon)', 'İravadi Deltası (Yangon)', 'Ayeyarwady', 'Yangon', tag='delta port'),
    ],
    'mys_pahang': [
        K(None, 'Pahang (Interior)', 'Pahang (İç Bölge)', 'Pahang', tag='jungle river'),
        K('kedah', 'Kedah & Penang', 'Kedah ve Penang', 'Perlis', 'Kedah', 'Pulau Pinang', tag='strait'),
        K('perak', 'Perak (Tin Valley)', 'Perak (Kalay Vadisi)', 'Perak', tag='tin'),
        K('selangor', 'Selangor (Klang Valley)', 'Selangor (Klang Vadisi)', 'Selangor', 'Kuala Lumpur', 'Putrajaya', tag='tin river'),
        K('malacca', 'Malacca & Negeri Sembilan', 'Malaka ve Negeri Sembilan', 'Melaka', 'Negeri Sembilan', tag='strait port'),
        K('johor', 'Johor', 'Johor', 'Johor', tag='strait'),
        K('east_coast_my', 'Kelantan & Terengganu (East Coast)', 'Kelantan ve Terengganu (Doğu Kıyısı)', 'Kelantan', 'Terengganu', tag='coast'),
    ],
    'idn_jawa_timur': [
        K(None, 'East Java (Majapahit)', 'Doğu Cava (Majapahit)', 'Jawa Timur', tag='river plain'),
        K('central_java', 'Central Java (Mataram)', 'Orta Cava (Mataram)', 'Jawa Tengah', 'Yogyakarta', tag='volcanic plain'),
        K('west_java', 'West Java (Sunda & Batavia)', 'Batı Cava (Sunda ve Batavya)', 'Jawa Barat', 'Jakarta Raya', tag='highland port'),
        K('bali', 'Bali', 'Bali', 'Bali', tag='island'),
        K('lombok', 'Lombok & Sumbawa', 'Lombok ve Sumbava', 'Nusa Tenggara Barat', tag='island'),
    ],
    'idn_riau': [
        K(None, 'Riau & the Straits Islands', 'Riau ve Boğaz Adaları', 'Riau', 'Kepulauan Riau', tag='strait'),
        K('minangkabau', 'Minangkabau (West Sumatra)', 'Minangkabau (Batı Sumatra)', 'Sumatera Barat', tag='highland'),
        K('jambi', 'Jambi & Bengkulu', 'Jambi ve Bengkulu', 'Jambi', 'Bengkulu', tag='river jungle'),
        K('palembang', 'Palembang (Srivijaya)', 'Palembang (Srivijaya)', 'Sumatera Selatan', 'Bangka-Belitung', tag='river port'),
        K('lampung', 'Lampung & Banten (Sunda Strait)', 'Lampung ve Banten (Sunda Boğazı)', 'Lampung', 'Banten', tag='strait'),
    ],
    'idn_sumatera_utara': [
        K(None, 'North Sumatra (Batak Lands)', 'Kuzey Sumatra (Batak Ülkesi)', 'Sumatera Utara', tag='highland lake'),
        K('aceh', 'Aceh', 'Açe', 'Aceh', tag='strait'),
    ],
    'idn_kalimantan_tengah': explode(30000, keep='Kalimantan Tengah', rename={'Kalimantan Barat': ('West Kalimantan', 'Batı Kalimantan'), 'Kalimantan Selatan': ('South Kalimantan (Banjar)', 'Güney Kalimantan (Banjar)'), 'Kalimantan Tengah': ('Central Kalimantan', 'Orta Kalimantan')}),
    'idn_kalimantan_timur': [
        K(None, 'East Kalimantan (Kutai)', 'Doğu Kalimantan (Kutai)', 'Kalimantan Timur', tag='river jungle'),
        K('south_sulawesi', 'South Sulawesi (Makassar)', 'Güney Sulavesi (Makasar)', 'Sulawesi Selatan', 'Sulawesi Barat', tag='port'),
        K('central_sulawesi', 'Central Sulawesi', 'Orta Sulavesi', 'Sulawesi Tengah', tag='mountain'),
        K('southeast_sulawesi', 'Southeast Sulawesi', 'Güneydoğu Sulavesi', 'Sulawesi Tenggara', tag='peninsula'),
        K('minahasa', 'Minahasa & Gorontalo', 'Minahasa ve Gorontalo', 'Sulawesi Utara', 'Gorontalo', tag='peninsula'),
    ],
    'idn_papua': [
        K(None, 'Papua (Western New Guinea)', 'Papua (Batı Yeni Gine)', 'Papua', tag='mountain jungle'),
        K('bird_head', "Bird's Head (Vogelkop)", 'Kuş Başı (Vogelkop)', 'Papua Barat', tag='peninsula'),
    ],
    'phl_isabela': [
        S(None, 'Manila (Tagalog Heartland)', 'Manila (Tagalog Yurdu)', 121.0, 14.5, tag='bay port'),
        S('ilocos', 'Ilocos (Northwest Luzon)', 'Ilocos (Kuzeybatı Luzon)', 120.4, 17.3, tag='narrow coast'),
        S('cagayan_valley', 'Cagayan Valley', 'Cagayan Vadisi', 121.8, 17.6, tag='river valley'),
        S('central_luzon', 'Central Luzon (Pampanga & Pangasinan)', 'Orta Luzon (Pampanga ve Pangasinan)', 120.6, 15.5, tag='rice plain'),
        S('cordillera', 'Cordillera (Benguet & Ifugao)', 'Cordillera (Benguet ve Ifugao)', 120.9, 16.8, tag='mountain'),
        S('bicol', 'Bicol (Southeast Luzon)', 'Bicol (Güneydoğu Luzon)', 123.3, 13.4, tag='volcanic peninsula'),
        S('mindoro', 'Mindoro & Romblon', 'Mindoro ve Romblon', 121.1, 12.9, tag='island'),
    ],
    'phl_palawan': [
        S(None, 'Palawan', 'Palawan', 118.7, 9.9, tag='island'),
        S('western_visayas', 'Western Visayas (Panay & Negros)', 'Batı Visayas (Panay ve Negros)', 122.6, 10.7, tag='island'),
        S('central_visayas', 'Central Visayas (Cebu & Bohol)', 'Orta Visayas (Cebu ve Bohol)', 123.9, 10.3, tag='island port'),
        S('eastern_visayas', 'Eastern Visayas (Samar & Leyte)', 'Doğu Visayas (Samar ve Leyte)', 125.0, 11.3, tag='island'),
        S('zamboanga', 'Zamboanga', 'Zamboanga', 122.2, 7.8, tag='peninsula'),
        S('northern_mindanao', 'Northern Mindanao', 'Kuzey Mindanao', 124.9, 8.3, tag='coast'),
        S('davao', 'Davao & Southeast Mindanao', 'Davao ve Güneydoğu Mindanao', 125.7, 7.0, tag='gulf'),
        S('moroland', 'Cotabato & Lanao (Moro Heartland)', 'Cotabato ve Lanao (Moro Yurdu)', 124.4, 7.3, tag='river basin'),
    ],
})
