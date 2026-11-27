"""Curated, approximate reference tables for the map generators (all marked approximate in docs).

Coordinates are (lon, lat). Everything here is hand-entered from general geographic/historical knowledge;
nothing is copied from a proprietary map.
"""

# Historic trade hubs / great cities: (name, lon, lat, score 1..3)  -> province `hub` hint = max score inside
HUBS = [
    ('Constantinople', 28.97, 41.01, 3), ('Alexandria', 29.9, 31.2, 3), ('Venice', 12.33, 45.44, 3),
    ('Genoa', 8.93, 44.41, 2), ('Bruges', 3.22, 51.21, 3), ('Novgorod', 31.27, 58.52, 2), ('Baghdad', 44.4, 33.31, 3),
    ('Aleppo', 37.16, 36.2, 2), ('Damascus', 36.3, 33.51, 2), ('Cairo', 31.24, 30.04, 3), ('Samarkand', 66.96, 39.65, 3),
    ('Bukhara', 64.42, 39.77, 2), ('Kashgar', 75.99, 39.47, 2), ('Malacca', 102.25, 2.19, 3), ('Canton', 113.26, 23.13, 3),
    ('Hangzhou', 120.15, 30.27, 2), ('Kaifeng', 114.35, 34.8, 2), ('Chang\'an', 108.94, 34.34, 2), ('Beijing', 116.4, 39.9, 2),
    ('Delhi', 77.2, 28.6, 2), ('Surat', 72.83, 21.17, 2), ('Calicut', 75.78, 11.25, 2), ('Hormuz', 56.46, 27.1, 2),
    ('Aden', 45.03, 12.78, 2), ('Mecca', 39.83, 21.42, 2), ('Tabriz', 46.29, 38.08, 2), ('Isfahan', 51.66, 32.65, 2),
    ('Paris', 2.35, 48.86, 2), ('London', -0.12, 51.5, 3), ('Lisbon', -9.14, 38.72, 2), ('Seville', -5.99, 37.39, 2),
    ('Barcelona', 2.17, 41.39, 2), ('Naples', 14.27, 40.85, 2), ('Palermo', 13.36, 38.12, 2), ('Lubeck', 10.69, 53.87, 2),
    ('Hamburg', 9.99, 53.55, 2), ('Antwerp', 4.4, 51.22, 2), ('Cologne', 6.96, 50.94, 2), ('Vienna', 16.37, 48.21, 2),
    ('Krakow', 19.94, 50.06, 1), ('Kiev', 30.52, 50.45, 2), ('Moscow', 37.62, 55.75, 2), ('Kazan', 49.1, 55.8, 1),
    ('Caffa', 35.38, 45.03, 2), ('Trebizond', 39.72, 41.0, 2), ('Thessalonica', 22.94, 40.64, 2), ('Ragusa', 18.09, 42.64, 1),
    ('Tunis', 10.18, 36.8, 2), ('Fez', -5.0, 34.03, 1), ('Timbuktu', -3.0, 16.77, 1), ('Kyoto', 135.77, 35.01, 2),
    ('Osaka', 135.5, 34.69, 2), ('Hanoi', 105.85, 21.03, 1), ('Ayutthaya', 100.56, 14.35, 1), ('Pegu', 96.48, 17.33, 1),
    ('Mumbai', 72.88, 19.08, 1), ('Gujarat Cambay', 72.62, 22.31, 2), ('Kolkata', 88.36, 22.57, 1), ('Zanzibar', 39.2, -6.17, 1),
    ('Jeddah', 39.2, 21.5, 1), ('Basra', 47.78, 30.5, 2), ('Tyre', 35.2, 33.27, 1), ('Acre', 35.07, 32.93, 1),
]

# Coal districts (name, lon, lat, radius_deg) approximate
COAL = [
    ('Ruhr', 7.2, 51.5, 0.9), ('Upper Silesia', 18.9, 50.2, 1.0), ('South Wales', -3.4, 51.7, 0.6), ('Tyneside', -1.6, 55.0, 0.8),
    ('Lancashire', -2.5, 53.5, 0.7), ('Midlands', -1.7, 52.7, 0.6), ('Saar', 7.0, 49.3, 0.5), ('Hainaut-Liege', 4.5, 50.4, 0.9),
    ('Donbas', 38.0, 48.0, 1.8), ('Zwickau-Saxony', 12.6, 50.7, 0.6), ('Ostrava', 18.3, 49.8, 0.5), ('Asturias', -5.8, 43.2, 0.5),
    ('Zonguldak', 31.8, 41.4, 0.5), ('Kuzbass', 87.0, 54.5, 2.0), ('Shanxi', 112.5, 37.5, 1.8), ('Jharia-Raniganj', 86.4, 23.7, 1.2),
    ('Manchuria Fushun', 124.0, 41.9, 1.0), ('Henan-Shandong', 114.5, 35.5, 1.5), ('Moscow basin', 37.5, 54.0, 1.2),
    ('Ukraine Lviv-Volyn', 24.0, 50.0, 0.8), ('Transylvania Jiu', 23.3, 45.2, 0.6), ('Bohemia Kladno', 14.0, 50.1, 0.6),
    ('Maharashtra Nagpur', 79.0, 21.0, 1.0), ('Kazakh Karaganda', 73.0, 49.8, 1.5), ('Indonesia Kutai', 117.0, 0.5, 1.5),
    ('Sumatra Ombilin', 100.8, -0.7, 0.8), ('Hunan Pingxiang', 113.8, 27.6, 1.0), ('Tonkin Hon Gai', 107.1, 21.1, 0.6),
]

# Iron / metal ore districts approximate
IRON = [
    ('Bergslagen', 15.0, 60.0, 0.9), ('Erzberg Styria', 14.9, 47.5, 0.6), ('Biscay', -3.0, 43.2, 0.6), ('Ore Mountains', 13.0, 50.4, 0.6),
    ('Lorraine', 6.0, 49.3, 0.6), ('Siegerland', 8.0, 50.9, 0.5), ('Forest of Dean', -2.6, 51.8, 0.5), ('Kiruna', 20.2, 67.9, 0.8),
    ('Kryvyi Rih', 33.3, 47.9, 0.8), ('Southern Urals', 59.0, 53.4, 1.5), ('Elba-Tuscany', 10.8, 43.0, 0.6), ('Daye-Hubei', 114.9, 30.1, 0.9),
    ('Handan-Hebei', 114.5, 36.6, 0.8), ('Singhbhum', 85.8, 22.8, 1.0), ('Divrigi', 38.1, 39.4, 0.6), ('Carinthia-Hüttenberg', 14.5, 46.9, 0.5),
    ('Bohemia Brdy', 13.8, 49.8, 0.5), ('Dalarna', 15.0, 61.0, 0.7), ('Weald', 0.3, 51.0, 0.5), ('Cleveland', -1.2, 54.5, 0.5),
    ('Toledo-Damascus steel', 36.3, 33.5, 0.5), ('Hallstatt', 13.6, 47.5, 0.4), ('Anshan', 123.0, 41.1, 0.8), ('Wutai-Shanxi', 113.0, 38.5, 0.8),
    ('Rajasthan Khetri', 75.8, 28.0, 0.8), ('Siberian Altai', 85.0, 51.0, 1.5), ('Kachin', 97.0, 25.5, 0.8), ('Sakhalin-Primorye', 134.0, 45.0, 0.8),
]

# Luxury production zones (spices, silk, incense, porcelain, pearls, wine, furs)
LUX = [
    ('Malabar spices', 76.3, 10.5, 1.2), ('Silk Yangtze delta', 120.0, 30.5, 1.2), ('Porcelain Jiangxi', 117.2, 29.3, 0.8),
    ('Incense Dhofar', 54.5, 18.5, 1.2), ('Incense Hadramawt', 49.3, 16.2, 1.0), ('Pearls Gulf', 51.0, 26.0, 1.5),
    ('Sicilian silk-sugar', 14.0, 37.8, 0.8), ('Flemish cloth', 3.5, 51.0, 0.8), ('Rhine wine', 8.0, 50.0, 0.8),
    ('Bordeaux wine', -0.6, 44.8, 0.6), ('Burgundy wine', 4.8, 47.1, 0.5), ('Fur Novgorod', 32.0, 58.5, 2.0), ('Fur Siberia', 70.0, 61.0, 3.0),
    ('Spice Islands', 127.8, 0.8, 1.5), ('Java spices', 110.5, -7.5, 1.5), ('Cotton Gujarat', 72.6, 22.5, 1.0), ('Cotton Egypt', 31.0, 30.0, 0.8),
    ('Silk Persia Gilan', 49.5, 37.3, 0.7), ('Sugar Cyprus-Crete', 33.0, 35.0, 1.0), ('Tea Assam-Yunnan', 95.0, 26.5, 1.5),
    ('Silk Bursa', 29.0, 40.2, 0.5), ('Samarkand paper-silk', 66.9, 39.7, 0.8), ('Brazil-less Ceylon cinnamon', 80.5, 7.0, 0.8),
    ('Ottoman Mocha coffee', 43.5, 13.5, 0.8), ('Pepper Sumatra', 99.0, 2.5, 1.5), ('Sandalwood Timor', 124.5, -9.5, 1.0),
]

# Named straits: (name, name_tr, (lonA, latA), (lonB, latB))
STRAITS = [
    ('Bosporus', 'İstanbul Boğazı', (28.98, 41.08), (29.08, 41.06)),
    ('Dardanelles', 'Çanakkale Boğazı', (26.3, 40.35), (26.4, 39.98)),
    ('Gibraltar', 'Cebelitarık Boğazı', (-5.5, 36.15), (-5.5, 35.78)),
    ('Oresund', 'Öresund', (12.6, 55.72), (12.95, 55.6)),
    ('Dover', 'Calais Boğazı', (1.3, 51.15), (1.85, 50.95)),
    ('Hormuz', 'Hürmüz Boğazı', (56.3, 26.2), (56.3, 27.1)),
    ('Malacca', 'Malaka Boğazı', (101.6, 1.7), (101.9, 2.4)),
    ('Bab-el-Mandeb', 'Bab-ül Mendeb', (43.3, 12.7), (43.1, 12.7)),
    ('Messina', 'Messina Boğazı', (15.65, 38.15), (15.55, 38.25)),
    ('Bonifacio', 'Bonifacio Boğazı', (9.2, 41.4), (9.2, 41.15)),
    ('Kerch', 'Kerç Boğazı', (36.4, 45.2), (36.8, 45.35)),
    ('Otranto', 'Otranto Boğazı', (18.4, 40.1), (19.4, 40.3)),
    ('Great Belt', 'Büyük Belt', (10.8, 55.35), (11.1, 55.4)),
    ('Tsugaru', 'Tsugaru Boğazı', (140.2, 41.4), (140.6, 41.1)),
    ('Kanmon', 'Kanmon Boğazı', (130.95, 33.9), (130.9, 34.0)),
    ('Korea Strait', 'Kore Boğazı', (129.2, 35.0), (129.4, 34.6)),
    ('Taiwan Strait', 'Tayvan Boğazı', (119.6, 25.3), (120.5, 24.6)),
    ('Palk Strait', 'Palk Boğazı', (79.3, 9.2), (79.95, 9.5)),
    ('Sicily Channel', 'Sicilya Kanalı', (11.0, 37.0), (12.5, 37.6)),
    ('North Channel', 'Kuzey Kanalı', (-5.7, 54.85), (-4.95, 54.85)),
    ('Torres Strait', 'Torres Boğazı', (142.3, -10.7), (142.6, -9.4)),
    ('Sunda Strait', 'Sunda Boğazı', (105.8, -5.8), (106.6, -6.2)),
    ('Strait of Mozambique narrows', 'Mozambik Kanalı', (44.0, -12.5), (45.3, -12.8)),
    ('Bering Strait', 'Bering Boğazı', (-166.0, 65.8), (-170.0, 66.0)),
    ('Skagerrak', 'Skagerrak', (8.5, 57.2), (8.0, 58.0)),
    ('Bornholm Sound', 'Bornholm Boğazı', (14.0, 55.2), (14.2, 55.4)),
]

# Mountain passes: (name, name_tr, lon, lat)  approximate historical crossing points
PASSES = [
    ('Brenner', 'Brenner Geçidi', 11.51, 47.0), ('Simplon', 'Simplon Geçidi', 8.03, 46.25), ('Great St Bernard', 'Büyük Saint Bernard Geçidi', 7.17, 45.87),
    ('Mont Cenis', 'Mont Cenis Geçidi', 6.9, 45.25), ('Little St Bernard', 'Küçük Saint Bernard Geçidi', 6.88, 45.68),
    ('St Gotthard', 'Saint Gotthard Geçidi', 8.57, 46.55), ('Splugen', 'Splügen Geçidi', 9.33, 46.5), ('Col de Tende', 'Tende Geçidi', 7.56, 44.15),
    ('Roncevaux', 'Roncevaux Geçidi', -1.32, 43.02), ('Somport', 'Somport Geçidi', -0.53, 42.79), ('Le Perthus', 'Perthus Geçidi', 2.87, 42.47),
    ('Despenaperros', 'Despeñaperros Geçidi', -3.5, 38.35), ('Guadarrama', 'Guadarrama Geçidi', -4.15, 40.78),
    ('Thermopylae', 'Thermopylae Geçidi', 22.54, 38.8), ('Kaçanik Gorge', 'Kaçanik Boğazı', 21.25, 42.23), ('Shipka', 'Şipka Geçidi', 25.32, 42.76),
    ('Iron Gates', 'Demirkapı', 22.5, 44.67), ('Trajan Gate', 'Trayan Kapısı', 23.9, 42.6), ('Vitosha Struma Gap', 'Struma Geçidi', 22.9, 42.2),
    ('Jablunkov', 'Jablunkov Geçidi', 18.77, 49.55), ('Dukla', 'Dukla Geçidi', 21.68, 49.42), ('Tihuta (Borgo)', 'Tihuța Geçidi', 25.0, 47.3),
    ('Predeal', 'Predeal Geçidi', 25.57, 45.5), ('Oituz', 'Oituz Geçidi', 26.35, 46.1), ('Verecke', 'Verecke Geçidi', 23.0, 48.8),
    ('Red Tower', 'Kızıl Kule Geçidi', 24.28, 45.63), ('Semmering', 'Semmering Geçidi', 15.83, 47.63), ('Pyhrn', 'Pyhrn Geçidi', 14.3, 47.65),
    ('Futa Pass', 'Futa Geçidi', 11.3, 44.0), ('Cisa Pass', 'Cisa Geçidi', 9.93, 44.4), ('Tarvisio', 'Tarvisio Geçidi', 13.58, 46.5),
    ('Karst Gate (Ocra)', 'Karst Kapısı', 14.1, 45.7), ('Vrata', 'Vratnik Geçidi', 14.9, 44.9),
    ('Cilician Gates', 'Gülek Boğazı (Kilikya Kapıları)', 34.77, 37.27), ('Syrian Gates (Belen)', 'Belen Geçidi (Suriye Kapıları)', 36.3, 36.5),
    ('Amanus Gates', 'Bahçe Geçidi (Amanos)', 36.6, 37.2), ('Zigana', 'Zigana Geçidi', 39.4, 40.6), ('Kop', 'Kop Geçidi', 40.5, 40.0),
    ('Dariel', 'Daryal Geçidi', 44.62, 42.75), ('Caspian Gates of Derbent', 'Derbent Geçidi', 48.3, 42.05), ('Rokisy Roki', 'Roki Geçidi', 44.0, 42.65),
    ('Caspian Gates (Sirdara)', 'Hazar Kapıları', 52.5, 35.5), ('Paitak (Zagros Gate)', 'Paytak Geçidi', 46.0, 34.5), ('Persian Gates', 'Pers Kapıları', 52.0, 30.5),
    ('Khyber', 'Hayber Geçidi', 71.1, 34.1), ('Bolan', 'Bolan Geçidi', 67.4, 29.8), ('Gomal', 'Gomal Geçidi', 69.9, 32.0), ('Salang', 'Salang Geçidi', 69.05, 35.3),
    ('Khawak', 'Havak Geçidi', 69.6, 35.6), ('Shibar', 'Şibar Geçidi', 68.1, 34.9), ('Baroghil', 'Baroğil Geçidi', 73.5, 36.9), ('Karakoram', 'Karakurum Geçidi', 77.8, 35.5),
    ('Terek (Fergana-Kashgar)', 'Terek Geçidi', 74.0, 39.8), ('Torugart', 'Torugart Geçidi', 75.4, 40.5), ('Dzungarian Gate', 'Cungar Kapısı', 82.3, 45.2),
    ('Iron Gate (Derbent Uzbek)', 'Demir Kapı (Buzgala)', 67.2, 38.2),
    ('Hexi (Jade Gate)', 'Hexi Koridoru (Yeşim Kapı)', 97.0, 40.3), ('Shanhai Pass', 'Şanhay Geçidi', 119.77, 40.0), ('Tong Pass', 'Tong Geçidi', 110.3, 34.55),
    ('Hangu Pass', 'Hangu Geçidi', 111.0, 34.6), ('Jiayu Pass', 'Cia Yu Geçidi', 98.2, 39.8), ('Meiling Pass', 'Meiling Geçidi', 114.3, 25.4),
    ('Zhuge Qinling (Baoxie)', 'Baoxie Yolu (Çinling)', 107.5, 33.8), ('Shu Plank Roads', 'Şu Yolları', 105.8, 32.4), ('Juyong Pass', 'Cuyong Geçidi', 116.1, 40.3),
    ('Gubeikou', 'Gubeikou Geçidi', 117.15, 40.7), ('Yanmen', 'Yanmen Geçidi', 112.8, 39.2),
    ('Hakone', 'Hakone Geçidi', 139.0, 35.2), ('Usui', 'Usui Geçidi', 138.7, 36.35), ('Sekigahara', 'Sekigahara Geçidi', 136.4, 35.35),
    ('Three Pagodas', 'Üç Pagoda Geçidi', 98.4, 15.3), ('Mu Gia', 'Mu Gia Geçidi', 105.8, 17.7), ('Hai Van', 'Hay Van Geçidi', 108.1, 16.2),
    ('Tizi n\'Tichka', 'Tichka Geçidi', -7.35, 31.3), ('Tazzeka', 'Tazzeka Geçidi', -4.0, 34.1), ('Gorges of Zahrez', 'Zahrez Geçidi', 3.3, 35.0),
    ('Kasserine', 'Kasserine Geçidi', 8.7, 35.2), ('Halfaya', 'Halfaya Geçidi', 25.2, 31.2), ('Mitla', 'Mitla Geçidi', 32.9, 30.0),
    ('Megiddo (Jezreel)', 'Megiddo Geçidi', 35.2, 32.6), ('Bekaa-Homs Gap', 'Humus Geçidi', 36.6, 34.4),
    ('Mt Cenis east', 'Montgenèvre Geçidi', 6.72, 44.93), ('Larche', 'Larche Geçidi', 6.9, 44.43), ('Sempione-Ossola', 'Ossola Geçidi', 8.3, 46.1),
    ('Sandomierz Gap', 'Sandomierz Geçidi', 21.7, 50.7), ('Moravian Gate', 'Moravya Kapısı', 17.5, 49.6), ('Ore Mountains Nollendorf', 'Nollendorf Geçidi', 13.9, 50.75),
    ('Bohemian Forest Gate', 'Bohemya Orman Geçidi', 12.85, 49.35), ('Bavarian Forest Cham', 'Cham Geçidi', 12.7, 49.2),
]

# Extra sea labels: (marine-poly name, Turkish) -- looked up in ne_10m_geography_marine_polys
SEA_TR_EXTRA = {
    'Ionian Sea': 'İyon Denizi', 'Tyrrhenian Sea': 'Tiren Denizi', 'Ligurian Sea': 'Ligurya Denizi', 'Alboran Sea': 'Alboran Denizi',
    'Sea of Marmara': 'Marmara Denizi', 'Sea of Azov': 'Azak Denizi', 'Gulf of Bothnia': 'Botna Körfezi', 'Irish Sea': 'İrlanda Denizi',
    'Celtic Sea': 'Kelt Denizi', 'Gulf of Aden': 'Aden Körfezi', 'Gulf of Oman': 'Umman Körfezi', 'Andaman Sea': 'Andaman Denizi',
    'Java Sea': 'Cava Denizi', 'Celebes Sea': 'Selebes Denizi', 'Sea of Okhotsk': 'Okhotsk Denizi', 'Gulf of Thailand': 'Tayland Körfezi',
    'Taiwan Strait': 'Tayvan Boğazı', 'Bohai Sea': 'Bohai Denizi', 'Arabian Sea': 'Umman Denizi', 'Aegean Sea': 'Ege Denizi',
    'Sea of Crete': 'Girit Denizi', 'Gulf of Finland': 'Finlandiya Körfezi', 'Gulf of Riga': 'Riga Körfezi', 'Kattegat': 'Kattegat',
    'Skagerrak': 'Skagerrak', 'Bay of Biscay': 'Biskay Körfezi', 'Levantine Sea': 'Levant Denizi', 'Gulf of Suez': 'Süveyş Körfezi',
    'Gulf of Aqaba': 'Akabe Körfezi', 'Strait of Hormuz': 'Hürmüz Boğazı', 'Persian Gulf': 'Basra Körfezi', 'Sulu Sea': 'Sulu Denizi',
    'Banda Sea': 'Banda Denizi', 'Timor Sea': 'Timor Denizi', 'Arafura Sea': 'Arafura Denizi', 'Gulf of Tonkin': 'Tonkin Körfezi',
    'Sea of Japan': 'Japon Denizi', 'Seto Inland Sea': 'Seto İç Denizi', 'Yellow Sea': 'Sarı Deniz', 'East China Sea': 'Doğu Çin Denizi',
    'Bay of Bengal': 'Bengal Körfezi', 'Adriatic Sea': 'Adriyatik Denizi',
}

# Great deserts as lon/lat boxes (lon0, lat0, lon1, lat1), approximate; they top up the Natural Earth "Desert"
# region cover, which misses much of Arabia and the Sahara at province scale.
DESERT_BOXES = [
    ('Sahara', -16.0, 15.5, 34.0, 31.0), ('Libyan-Egyptian desert', 24.0, 22.0, 33.5, 31.0), ('Nubian/Eastern desert', 31.5, 18.0, 36.0, 28.0),
    ('Arabian interior', 38.0, 16.0, 56.0, 30.0), ('Syrian desert', 37.0, 31.0, 43.0, 35.0), ('Iranian Dasht', 54.0, 29.0, 62.0, 36.0),
    ('Karakum', 54.0, 36.5, 63.0, 42.5), ('Kyzylkum', 61.0, 40.0, 67.5, 44.5), ('Taklamakan', 76.0, 36.5, 90.0, 41.5),
    ('Gobi', 95.0, 38.0, 112.0, 46.0), ('Thar', 69.0, 24.5, 74.5, 29.5), ('Kalahari-Namib', 12.0, -28.0, 24.0, -17.0),
    ('Australian interior', 120.0, -30.0, 140.0, -20.0), ('Atacama', -71.0, -28.0, -68.5, -18.0), ('Somali-Ogaden', 41.0, 3.0, 51.0, 10.0),
    ('Ustyurt-Aral', 55.0, 42.0, 61.0, 46.0), ('Lut-Kerman', 56.0, 28.0, 60.5, 33.0), ('Rub al Khali', 47.0, 17.0, 56.0, 23.0),
]
