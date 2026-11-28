# Scenario: Medieval Europe (`medieval_europe`)

Status: v2.0 reconstruction by workstream B1. Everything marked `approximate` in `data/scenarios/medieval_europe.json` is a best-effort reconstruction. Population, treasury and army sizes are **gameplay estimates** produced by `ScenarioLoader` (they are not documented statistics).

## Start date
* 1066-09-01 (Autumn 1066; Stamford Bridge 25 Sept., Hastings 14 Oct.). Turns are three months long; ages are computed for the start date (see `tests/t_scenarios_v2.gd`, which checks 29 ruler ages against birth years).

## What changed in v2.0
* Countries: 38 -> 136 (all 410 provinces now have a named owner; 260 provinces were previously generic `<Region> Peoples` filler).
* 98 new political entities, of which 48 are `native: true` named cultural groups where no state can be drawn.
* Scenario-specific province names layer (`province_names`): 148 provinces; geo layer notes: 2.
* Claims: 31 entries for 22 countries; alliances/vassals/wars were reviewed against the sources below.

## Sources
### Main historical sources
* Ruler names and reign dates of Western Europe, Byzantium, the Seljuks, Fatimids and Rus princes: standard regnal lists (Wikipedia list articles, CC BY-SA 4.0; Cambridge Medieval History vols. 3-4; Oxford History of Byzantium).
* Islamic dynasties (Zirids, Hammadids, Almoravids, Ghaznavids, Karakhanids, Sulayhids, Qarmatians): C. E. Bosworth, The New Islamic Dynasties (Edinburgh UP, 1996); Encyclopaedia of Islam, 2nd ed.
* China, Liao, Western Xia, Dali, Tibet: Denis Twitchett and Herbert Franke (eds.), Cambridge History of China vol. 6 (1994); Wikipedia articles on the Song, Liao, Western Xia and Dali.
* India and Southeast Asia: Romila Thapar, Early India (2002); George Coedès, The Indianized States of Southeast Asia (1968); Wikipedia lists of Chola, Chalukya, Pala, Khmer, Pagan and Lý rulers.
* Africa: Nehemia Levtzion and J. F. P. Hopkins, Corpus of Early Arabic Sources for West African History (1981; al-Bakri 1068 on Tunka Manin); UNESCO General History of Africa vols. 3-4.

### Geographic sources
* Natural Earth admin-0/admin-1 and geography regions (public domain, https://www.naturalearthdata.com), grouped into 410 modern-geometry provinces by `tools/gen_map_step*.py`. The geometry is modern: historical borders are approximated by assigning each modern region to the realm that held most of it. Access date of the original download was not recorded; this document was written 2026-11-23 to 2026-11-27.
* Province names for the date come from the scenario `province_names` layer; they are hand-written historical or regional names (not an external gazetteer).

### Verification status
* Checked through web search result snippets on 2026-11-23 to 2026-11-27 (Wikipedia, CC BY-SA 4.0): Dali kingdom rulers around 1081-1108 (Duan Zhengming, Duan Zhengchun); Western Xia emperor Yizong (b. 1047, r. 1048-1067/68); Khmer king Harshavarman III (succeeded 1066); Kara-Khanid Ibrahim Tamghach-Khan (r. 1038-1068). Dates that sources disagree on are explained in the country notes.
* Direct page fetches of Wikipedia, Britannica and Wikidata were **blocked** in the authoring environment (DNS not allowed), so every other fact was written from established general knowledge of the standard references listed above and was **not** re-opened or verified line by line. Those countries are flagged `approximate: true` and their notes say what is uncertain (unknown rulers are named as an office, e.g. "King of Alania (name not attested)").

## Approximation notes and known limitations
* The 410 provinces are modern administrative regions: one region often stands for several historical realms (see the per-country notes). Capitals are the province that contains the real capital city when that is possible; otherwise the note says so.
* Where several historical states share one modern region only one is drawn; the others are named in the note of the drawn state.
* Placeholder states: `native: true` groups are cultural groupings, not states. Their rulers are unnamed on purpose. They are marked `approximate` and cannot be played.
* Treasury is not set for most countries (computed by the loader from income: gameplay estimate). Starting armies are auto-composed from population and tech except for countries with explicit `armies`.

## Countries

| Tag | Name | Government | Ruler (age) | Heir | Capital | Provinces | Approximate |
|---|---|---|---|---|---|---|---|
| ENG | Kingdom of England | feudal_kingdom | Harold Godwinson (44) | Edgar Ætheling | gbr_home_counties | 5 | no |
| NRM | Duchy of Normandy | feudal_kingdom | William the Bastard (38) | Robert Curthose | fra_normandy | 1 | no |
| SCO | Kingdom of Scotland | feudal_kingdom | Malcolm III (35) | - | gbr_lowland_scotland | 2 | yes |
| MUN | Kingdom of Munster | tribal_confederation | Toirdelbach Ua Briain (57) | - | irl_munster | 1 | yes |
| LEI | Kingdom of Leinster | tribal_confederation | Diarmait mac Máel na mBó (56) | - | irl_leinster | 1 | yes |
| FRA | Kingdom of France | feudal_kingdom | Philip I (under regency) (14) | - | fra_ile_de_france | 5 | yes |
| FLA | County of Flanders | feudal_kingdom | Baldwin V (54) | Baldwin of Mons (future Baldwin VI) | bel_flanders | 1 | yes |
| AQU | Duchy of Aquitaine | feudal_kingdom | William VIII of Aquitaine (41) | - | fra_aquitaine | 3 | yes |
| TOU | County of Toulouse | feudal_kingdom | William IV of Toulouse (33) | - | fra_languedoc | 1 | yes |
| HRE | Holy Roman Empire | empire | Henry IV (under the influence of Archbishop Adalbert of Bremen) (15) | - | deu_rhineland | 18 | yes |
| BAV | Duchy of Bavaria | feudal_kingdom | Otto of Nordheim (46) | - | deu_bavaria | 2 | yes |
| SAX | Duchy of Saxony | feudal_kingdom | Ordulf Billung (46) | - | deu_lower_saxony | 3 | yes |
| TUS | Margraviate of Tuscany | feudal_kingdom | Beatrice of Lorraine (46) | Matilda of Canossa | ita_tuscany | 2 | yes |
| PAP | Papal States | theocracy | Alexander II (56) | - | ita_lazio | 1 | yes |
| VEN | Republic of Venice | merchant_republic | Domenico Contarini (60) | - | ita_veneto | 1 | yes |
| GEN | Commune of Genoa | merchant_republic | Consular Council of Genoa (45) | - | ita_liguria | 1 | yes |
| NIT | Norman Duchy of Apulia and Calabria | feudal_kingdom | Robert Guiscard (49) | Bohemond of Taranto | ita_apulia | 3 | yes |
| SIC | Emirates of Muslim Sicily | absolute_monarchy | Qa'id of Sicily (45) | - | ita_sicily | 1 | yes |
| CAS | Kingdom of Castile and León | feudal_kingdom | Alfonso VI (26) | - | esp_old_castile | 4 | yes |
| NAV | Kingdom of Navarre | feudal_kingdom | Sancho IV of Navarre (27) | - | esp_navarre | 1 | yes |
| ARA | Kingdom of Aragon and County of Barcelona | feudal_kingdom | Sancho Ramírez (23) | - | esp_aragon | 2 | yes |
| SEV | Taifa of Seville | absolute_monarchy | al-Mu'tadid ibn Abbad (58) | - | esp_andalusia | 3 | yes |
| TOL | Taifa of Toledo and Valencia | absolute_monarchy | al-Ma'mun of Toledo (50) | - | esp_new_castile | 2 | yes |
| ALM | Almoravid Emirate | military_government | Abu Bakr ibn Umar (46) | - | mar_marrakesh | 4 | yes |
| ZIR | Zirid Emirate of Ifriqiya | absolute_monarchy | Tamim ibn al-Mu'izz (35) | Yahya ibn Tamim | tun_tunisia | 2 | yes |
| FAT | Fatimid Caliphate | theocracy | al-Mustansir Billah (37) | Nizar ibn al-Mustansir | egy_cairo | 12 | yes |
| BYZ | Byzantine Empire | empire | Constantine X Doukas (60) | Michael VII Doukas | tur_constantinople | 22 | yes |
| SEL | Great Seljuk Sultanate | empire | Alp Arslan (37) | Malik-Shah | irn_isfahan | 16 | yes |
| GEO | Kingdom of Georgia | feudal_kingdom | Bagrat IV (48) | George II of Georgia | geo_georgia | 1 | yes |
| POL | Duchy of Poland | feudal_kingdom | Bolesław II the Bold (24) | - | pol_lesser_poland | 4 | yes |
| BOH | Duchy of Bohemia | feudal_kingdom | Vratislaus II (31) | - | cze_bohemia | 2 | yes |
| HUN | Kingdom of Hungary | feudal_kingdom | Solomon (with Dukes Géza and Ladislaus) (13) | - | hun_transdanubia | 4 | yes |
| KIE | Grand Principality of Kyiv | feudal_kingdom | Iziaslav I Yaroslavich (41) | Sviatopolk Iziaslavich | ukr_kyiv | 5 | yes |
| CHE | Principality of Chernigov and Pereyaslavl | feudal_kingdom | Sviatoslav II Yaroslavich (39) | - | rus_black_earth | 3 | yes |
| NOV | Principality of Novgorod | merchant_republic | Prince of Novgorod (35) | - | rus_novgorod | 3 | yes |
| NOR | Kingdom of Norway | feudal_kingdom | Harald Hardrada (51) | Magnus Haraldsson | nor_south_norway | 3 | no |
| DEN | Kingdom of Denmark | feudal_kingdom | Sweyn II Estridsson (47) | Harald Hen | dnk_zealand | 2 | yes |
| SWE | Kingdom of Sweden | feudal_kingdom | Stenkil (40) | - | swe_svealand | 3 | yes |
| BRI | Duchy of Brittany | feudal_kingdom | Conan II (33) | - | fra_brittany | 1 | yes |
| WAL | Welsh Kingdoms (Gwynedd and Powys) | tribal_confederation | Bleddyn ap Cynfyn (40) | - | gbr_wales | 1 | yes |
| CON | Kingdom of Connacht | tribal_confederation | Áed in Gai Bernaig Ua Conchobair (45) | - | irl_connacht | 1 | yes |
| ULA | Kingdom of Ailech and Ulaid (Ulster) | tribal_confederation | King of Ailech (Cenél nEógain), name uncertain (45) | - | gbr_ulster | 1 | yes |
| ICE | Icelandic Commonwealth (Althing) | tribal_confederation | Lawspeaker and chieftains (goðar) (50) | - | isl_iceland | 1 | yes |
| GRN | Norse Greenland Settlements | tribal_confederation | Chieftains of the Eastern and Western Settlements (40) | - | grl_greenland | 1 | yes |
| CRO | Kingdom of Croatia | feudal_kingdom | Petar Krešimir IV (46) | - | hrv_croatia | 2 | yes |
| DUK | Principality of Duklja | feudal_kingdom | Mihailo I Vojislavljević (50) | - | mne_montenegro | 2 | yes |
| OBO | Obotrite Realm (pagan reaction) | tribal_confederation | Kruto of Rügen (45) | - | deu_mecklenburg | 1 | yes |
| LUT | Lutician Confederation | tribal_confederation | Council of the Lutician tribes (Redarii, Tollensians) (50) | - | deu_brandenburg | 1 | yes |
| PMR | Pomeranian Tribes | tribal_confederation | Pomeranian chieftains (unnamed) (45) | - | pol_pomerania | 1 | yes |
| PRS | Old Prussian and Yotvingian Tribes | tribal_confederation | Tribal chiefs (unnamed) (45) | - | rus_koenigsberg | 2 | yes |
| LTT | Lithuanian Tribes | tribal_confederation | Tribal chiefs (unnamed) (45) | - | ltu_lithuania | 1 | yes |
| LIV | Latgalian, Curonian and Estonian Tribes | tribal_confederation | Tribal elders (unnamed) (45) | - | lva_latvia | 2 | yes |
| FNN | Finnish and Karelian Tribes | tribal_confederation | Tribal elders (unnamed) (45) | - | fin_south_finland | 2 | yes |
| VLK | Vlach Knezates and Pecheneg Remnants | tribal_confederation | Local knezes and voivodes (unnamed) (45) | - | rou_wallachia | 3 | yes |
| CUM | Cuman-Kipchak Confederation | tribal_confederation | Cuman khans (unnamed) (45) | - | ukr_pontic_steppe | 5 | yes |
| ALA | Kingdom of Alania | feudal_kingdom | King of Alania (name not attested) (45) | - | rus_north_caucasus | 1 | yes |
| VBG | Volga Bulgaria | feudal_kingdom | Emir of Volga Bulgaria (name not securely attested) (45) | - | rus_volga | 1 | yes |
| URL | Ugrian and Samoyed Tribes | tribal_confederation | Tribal chiefs (unnamed) (40) | - | rus_urals | 1 | yes |
| SIB | Peoples of Siberia and the Far East | tribal_confederation | Clan elders (unnamed) (40) | - | rus_sakha_yakutia | 5 | yes |
| SDA | Judicates of Sardinia | republic | Judge of Arborea and Cagliari (name uncertain) (40) | - | ita_sardinia | 1 | yes |
| DEN2 | Taifa of Denia and the Balearics | absolute_monarchy | Iqbal al-Dawla Ali (50) | - | isl_mediterranean | 1 | yes |
| SUL | Sulayhid Emirate of Yemen | absolute_monarchy | Ali al-Sulayhi (54) | - | yem_yemen | 1 | yes |
| QAR | Qarmatian Emirate of al-Ahsa | theocracy | Qarmatian council of elders (name uncertain) (50) | - | sau_al_hasa | 3 | yes |
| OMA | Ibadi Imamate of Oman | theocracy | Ibadi Imam (name uncertain) (50) | - | omn_oman | 2 | yes |
| NJD | Bedouin Tribes of Najd | tribal_confederation | Tribal shaykhs (unnamed) (45) | - | sau_najd | 1 | yes |
| HAM | Hammadid Emirate | absolute_monarchy | Buluggin ibn Muhammad (36) | - | dza_constantine | 2 | yes |
| MAG | Zenata Emirates (Maghrawa of Fez and Tlemcen) | absolute_monarchy | Maghrawa emir (name uncertain) (45) | - | mar_fez | 2 | yes |
| KHT | Khattabid Emirate of Fezzan | absolute_monarchy | Khattabid emir (name uncertain) (45) | - | lby_fezzan | 1 | yes |
| TUA | Tuareg and Zenata Oasis Chiefdoms | tribal_confederation | Tribal chiefs (unnamed) (45) | - | dza_algerian_sahara | 2 | yes |
| TAK | Kingdom of Takrur | feudal_kingdom | King of Takrur (War Jabi dynasty, name uncertain) (40) | - | sen_senegal | 1 | yes |
| GHN | Ghana Empire (Wagadou) | empire | Tunka Manin (45) | - | mli_kayes | 1 | yes |
| GAO | Kingdom of Gao (Kawkaw) | feudal_kingdom | King of Gao (Za dynasty, name uncertain) (40) | - | mli_timbuktu | 1 | yes |
| KNM | Kingdom of Kanem | feudal_kingdom | Mai of Kanem (Sayfawa dynasty, name uncertain) (40) | - | tcd_batha | 2 | yes |
| MAK | Kingdom of Makuria | feudal_kingdom | Georgios III of Makuria (45) | - | sdn_northern | 1 | yes |
| ALW | Kingdom of Alodia | feudal_kingdom | King of Alodia (name not attested) (45) | - | sdn_north_kordufan | 1 | yes |
| AXM | Highland Christian Kingdom (late Aksum) | feudal_kingdom | King of the Ethiopian highlands (name not attested) (45) | - | eri_eritrea | 2 | yes |
| SNG | Northern Song Empire | empire | Emperor Yingzong (Zhao Shu) (34) | Zhao Xu (future Shenzong) | chn_hunan | 3 | yes |
| LIA | Liao (Khitan) Empire | empire | Emperor Daozong (Yelü Hongji) (34) | - | chn_jilin | 2 | yes |
| JUR | Jurchen Tribes (Wanyan) | tribal_confederation | Wanyan Wugunai (45) | - | chn_heilongjiang | 1 | yes |
| MGT | Mongol, Kereit and Tatar Tribes (Liao tributaries) | tribal_confederation | Tribal khans (unnamed) (45) | - | mng_govi_altay | 2 | yes |
| XIA | Western Xia (Tangut) Empire | empire | Emperor Yizong (Li Liangzuo) (19) | - | chn_qinghai | 1 | yes |
| TIB | Tibetan Principalities | theocracy | Regional lords and monasteries (unnamed) (45) | - | chn_xizang | 1 | yes |
| DAL | Kingdom of Dali | feudal_kingdom | King of Dali (Duan clan, name uncertain) (45) | - | chn_yunnan | 1 | yes |
| KKH | Kara-Khanid Khanate | tribal_confederation | Ibrahim Tamghach-Khan (Böritigin) (55) | - | uzb_bukhoro | 4 | yes |
| GHZ | Ghaznavid Sultanate | empire | Ibrahim of Ghazna (33) | - | afg_hilmand | 4 | yes |
| SMR | Soomra Emirate of Sindh | absolute_monarchy | Soomra chief (name uncertain) (45) | - | pak_baluchistan | 1 | yes |
| KSH | Kingdom of Kashmir (Lohara dynasty) | feudal_kingdom | Kalasha of Kashmir (40) | - | ind_ladakh | 1 | yes |
| CND | Chandela Kingdom | feudal_kingdom | Kirtivarman Chandela (35) | - | ind_madhya_pradesh | 1 | yes |
| CHK | Chaulukya (Solanki) Kingdom of Gujarat | feudal_kingdom | Karna Chaulukya (Karnadeva I) (30) | - | ind_rajasthan | 1 | yes |
| PAL | Pala Empire (Bengal and Bihar) | feudal_kingdom | Vigrahapala III (45) | - | ind_bihar | 2 | yes |
| GNG | Eastern Gangas and Somavamsis (Kalinga and Kosala) | feudal_kingdom | Anantavarman Vajrahasta V (45) | - | ind_odisha | 1 | yes |
| WCH | Western Chalukya Empire | empire | Someshvara I (Ahavamalla) (50) | - | ind_karnataka | 2 | yes |
| CHL | Chola Empire | empire | Virarajendra Chola (45) | - | ind_tamil_nadu | 2 | yes |
| ASM | Kingdoms of the Brahmaputra Valley | tribal_confederation | Local kings and tribal chiefs (unnamed) (45) | - | ind_arunachal_pradesh | 1 | yes |
| NPL | Himalayan Valleys (Nepal and Bhutan) | tribal_confederation | Local rajas and lamas (unnamed) (45) | - | npl_nepal | 2 | yes |
| PGN | Pagan Kingdom | feudal_kingdom | Anawrahta (52) | - | mmr_shan | 2 | yes |
| KHM | Khmer Empire (Angkor) | empire | Harshavarman III (30) | - | khm_cambodia | 3 | yes |
| VIE | Đại Việt (Lý dynasty) | empire | Lý Thánh Tông (43) | - | vnm_nghe_an | 1 | yes |
| CHM | Kingdom of Champa | feudal_kingdom | Rudravarman III (Chế Củ) (35) | - | vnm_gia_lai | 1 | yes |
| SRV | Srivijaya (Malay thalassocracy) | feudal_kingdom | Maharaja of Srivijaya (name not securely attested) (45) | - | idn_riau | 4 | yes |
| KDR | Kingdom of Kediri and Janggala (East Java) | feudal_kingdom | Kings of Janggala and Panjalu (names uncertain) (40) | - | idn_jawa_timur | 1 | yes |
| HEI | Heian Japan (Fujiwara regency) | empire | Emperor Go-Reizei (41) | - | jpn_nagano | 2 | yes |
| GRY | Goryeo Kingdom | feudal_kingdom | Munjong of Goryeo (47) | - | prk_north_korea | 3 | yes |
| TLT | Toltec Realm (Tollan) | tribal_confederation | Toltec rulers of Tula (legendary names only) (40) | - | mex_jalisco | 1 | yes |
| MXT | Mixtec and Zapotec Kingdoms | tribal_confederation | Chiefs and elders (unnamed) (40) | - | mex_oaxaca | 1 | yes |
| MYA | Maya City-States (Chichen Itza and the highlands) | tribal_confederation | Chiefs and elders (unnamed) (40) | - | mex_campeche | 3 | yes |
| MSO | Mississippian Chiefdoms (Cahokia and neighbours) | tribal_confederation | Chiefs and elders (unnamed) (40) | - | usa_michigan | 4 | yes |
| PUE | Ancestral Puebloan and Desert Farming Peoples | tribal_confederation | Chiefs and elders (unnamed) (40) | - | usa_colorado | 3 | yes |
| PLN | Plains and Great Basin Peoples | tribal_confederation | Chiefs and elders (unnamed) (40) | - | usa_south_dakota | 4 | yes |
| PAC | Pacific Coast Peoples | tribal_confederation | Chiefs and elders (unnamed) (40) | - | usa_california | 3 | yes |
| WDL | Eastern Woodland Peoples (Algonquian and Iroquoian) | tribal_confederation | Chiefs and elders (unnamed) (40) | - | usa_new_york | 3 | yes |
| ARC | Arctic and Subarctic Peoples (Thule Inuit and others) | tribal_confederation | Chiefs and elders (unnamed) (40) | - | usa_alaska | 5 | yes |
| ISM | Isthmian and Central American Chiefdoms | tribal_confederation | Chiefs and elders (unnamed) (40) | - | hnd_honduras | 5 | yes |
| TAI | Taino Chiefdoms (cacicazgos) | tribal_confederation | Chiefs and elders (unnamed) (40) | - | hti_haiti | 8 | yes |
| AND | Andean Kingdoms and Chiefdoms (Chimú and the post-Tiwanaku lands) | tribal_confederation | Chiefs and elders (unnamed) (40) | - | per_loreto | 5 | yes |
| AMZ | Amazonian and Orinoco Chiefdoms | tribal_confederation | Chiefs and elders (unnamed) (40) | - | bra_amazonas | 10 | yes |
| TUP | Tupi-Guarani and Southern Cone Peoples | tribal_confederation | Chiefs and elders (unnamed) (40) | - | bra_minas_gerais | 9 | yes |
| PTG | Mapuche and Patagonian Peoples | tribal_confederation | Chiefs and elders (unnamed) (40) | - | arg_santa_cruz | 3 | yes |
| ABO | Aboriginal Australian Nations | tribal_confederation | Chiefs and elders (unnamed) (40) | - | aus_new_south_wales | 6 | yes |
| PNG | Papuan and Melanesian Peoples | tribal_confederation | Chiefs and elders (unnamed) (40) | - | idn_papua | 8 | yes |
| MCR | Micronesian and Polynesian Chiefdoms | tribal_confederation | Chiefs and elders (unnamed) (40) | - | isl_polynesia | 2 | yes |
| BOR | Bornean and Moluccan Coastal Chiefdoms | tribal_confederation | Chiefs and elders (unnamed) (40) | - | idn_kalimantan_timur | 9 | yes |
| PHI | Philippine Barangay Polities (Tondo, Butuan, Cebu) | tribal_confederation | Chiefs and elders (unnamed) (40) | - | phl_isabela | 2 | yes |
| FMS | Austronesian Peoples of Taiwan | tribal_confederation | Chiefs and elders (unnamed) (40) | - | twn_taiwan | 1 | yes |
| RYU | Okinawan Gusuku Chiefs | tribal_confederation | Chiefs and elders (unnamed) (40) | - | jpn_okinawa | 1 | yes |
| AIN | Ainu and Emishi Peoples of Ezo | tribal_confederation | Chiefs and elders (unnamed) (40) | - | jpn_hokkaido | 1 | yes |
| MDV | Buddhist Kingdom of the Maldives | tribal_confederation | Chiefs and elders (unnamed) (40) | - | isl_indian_ocean | 1 | yes |
| UNS | Uninhabited islands (placeholder) | tribal_confederation | Chiefs and elders (unnamed) (40) | - | isl_atlantic | 4 | yes |
| SHL | Hausa, Nupe and Savanna Peoples | tribal_confederation | Chiefs and elders (unnamed) (40) | - | nga_borno | 5 | yes |
| GUL | Guinea Coast and Forest Peoples | tribal_confederation | Chiefs and elders (unnamed) (40) | - | gha_ghana | 9 | yes |
| CAF | Central African Forest and Savanna Peoples | tribal_confederation | Chiefs and elders (unnamed) (40) | - | cod_orientale | 10 | yes |
| SSD | Nilotic Peoples of the Upper Nile | tribal_confederation | Chiefs and elders (unnamed) (40) | - | sds_s_sudan | 4 | yes |
| SWH | Swahili Coast Towns and Eastern Bantu Peoples | tribal_confederation | Chiefs and elders (unnamed) (40) | - | ken_kenya | 5 | yes |
| SOMA | Somali and Afar Peoples (Horn of Africa) | tribal_confederation | Chiefs and elders (unnamed) (40) | - | som_somalia | 3 | yes |
| SAF | Southern African Peoples (Bantu, Khoikhoi and San) | tribal_confederation | Chiefs and elders (unnamed) (40) | - | zaf_limpopo | 10 | yes |
| MDG | Peoples of Madagascar | tribal_confederation | Chiefs and elders (unnamed) (40) | - | mdg_madagascar | 1 | yes |

## Notes per new or changed country

* **BRI - Duchy of Brittany**: Conan II of Brittany (r. 1040-1066) died in December 1066; the duchy is a small independent power.
* **WAL - Welsh Kingdoms (Gwynedd and Powys)**: After Gruffydd ap Llywelyn died in 1063 Wales split into several kingdoms; Bleddyn and Rhiwallon held Gwynedd and Powys. Deheubarth and Morgannwg cannot be drawn separately. Ruler age is approximate.
* **CON - Kingdom of Connacht**: King of Connacht c. 1046-1067; age estimated.
* **ULA - Kingdom of Ailech and Ulaid (Ulster)**: The northern Uí Néill kings and the Ulaid are merged; the ruler is unnamed because the succession in 1066 is uncertain.
* **ICE - Icelandic Commonwealth (Althing)**: No king: power is shared among chieftains meeting at the Althing; the lawspeaker is not named.
* **GRN - Norse Greenland Settlements**: Norse farms existed from c. 985; the whole big province is a placeholder for two small settlements.
* **CRO - Kingdom of Croatia**: Krešimir IV (r. 1058-1074) styled himself king of Croatia and Dalmatia; Venice and Byzantium held coastal towns. Ruler age is approximate.
* **DUK - Principality of Duklja**: Mihailo (r. c. 1046-1081) became king in 1077; Bosnia was only loosely under Duklja's influence. Age is approximate.
* **OBO - Obotrite Realm (pagan reaction)**: Prince Gottschalk was murdered in June 1066 and the pagan Kruto seized power; Mecklenburg and Pomerania are merged in one region here.
* **LUT - Lutician Confederation**: A pagan Slavic confederation without a king, resisting Saxon and Polish expansion.
* **PMR - Pomeranian Tribes**: Poland's northern neighbours; no secure ruler list for 1066.
* **PRS - Old Prussian and Yotvingian Tribes**: Baltic-speaking tribes without a central state.
* **LTT - Lithuanian Tribes**: The Lithuanian state forms only in the 13th century.
* **LIV - Latgalian, Curonian and Estonian Tribes**: Finnic and Baltic tribes in the eastern Baltic; some paid tribute to Rus princes.
* **FNN - Finnish and Karelian Tribes**: Tavastians, Finns, Karelians and Sami; the Swedish crown only reaches here in the 12th-13th centuries.
* **VLK - Vlach Knezates and Pecheneg Remnants**: Romanian principalities form only in the 14th century; in 1066 the steppe edge was ruled by Pechenegs, Uzes and local knezes.
* **CUM - Cuman-Kipchak Confederation**: The Cumans reached the Rus frontier in 1055; the Kimek-Kipchak lands east of them are merged into one confederation.
* **ALA - Kingdom of Alania**: Christian Alania in the North Caucasus foothills survived until the Mongol invasions.
* **VBG - Volga Bulgaria**: Muslim since 922 with Bolghar as its main trading city.
* **URL - Ugrian and Samoyed Tribes**: Hunting and herding peoples of the Urals and western Siberia; no state.
* **SIB - Peoples of Siberia and the Far East**: Evenk, Yukaghir, Nivkh and other peoples; the area is a placeholder for many small groups and no state.
* **SDA - Judicates of Sardinia**: Four independent judicates (Cagliari, Arborea, Torres, Gallura) are merged into one.
* **DEN2 - Taifa of Denia and the Balearics**: Denia's coast on the mainland is part of the Valencia region here; only the islands are drawn separately. Ruler age is approximate.
* **SUL - Sulayhid Emirate of Yemen**: Ali al-Sulayhi (r. 1047-1067) ruled Yemen as a Fatimid Ismaili vassal and was killed in 1067; age is approximate.
* **QAR - Qarmatian Emirate of al-Ahsa**: The Qarmatian state of Bahrayn was overthrown c. 1067-1077 by the Uyunids; its last rulers are not securely named.
* **OMA - Ibadi Imamate of Oman**: Ibadi imams ruled the interior; the faith is shown as Sunni because the game has no separate Ibadi option.
* **NJD - Bedouin Tribes of Najd**: Nomadic tribal confederations of central Arabia; no state.
* **HAM - Hammadid Emirate**: The Hammadids broke away from the Zirids in 1015 and ruled central Algeria from the Qal'a; age is approximate.
* **MAG - Zenata Emirates (Maghrawa of Fez and Tlemcen)**: Zenata Berber dynasties held Fez and Tlemcen until the Almoravid conquests of the 1060s-1070s; rulers are not securely named.
* **KHT - Khattabid Emirate of Fezzan**: Banu Khattab of Zawila controlled the Saharan oases from the 11th century to 1172; included with low confidence.
* **TUA - Tuareg and Zenata Oasis Chiefdoms**: Saharan nomads and oasis towns; no central state.
* **TAK - Kingdom of Takrur**: Takrur on the Senegal River was among the earliest African Muslim states.
* **GHN - Ghana Empire (Wagadou)**: Tunka Manin is described by al-Bakri in 1068. The imperial court at Koumbi Saleh was sacked by the Almoravids around 1076. Age is a guess.
* **GAO - Kingdom of Gao (Kawkaw)**: Gao on the Niger bend already had Muslim rulers by c. 1000; later named Songhai.
* **KNM - Kingdom of Kanem**: Kanem around Lake Chad adopted Islam under Mai Hummay in the late 11th century; the Mai of 1066 is not securely named.
* **MAK - Kingdom of Makuria**: Christian Nubia with its capital at Dongola; Georgios III is traditionally dated to c. 1030-1070. Orthodox is the closest available faith (Nubian Miaphysite church).
* **ALW - Kingdom of Alodia**: Christian Alodia with its capital Soba; the region is merged with Kordofan.
* **AXM - Highland Christian Kingdom (late Aksum)**: Aksum declined in the 7th-10th centuries; the Zagwe dynasty takes over only around 1137. The sultanate of Shewa and the Muslim lowlands cannot be drawn separately.
* **SNG - Northern Song Empire**: Yingzong (b. 1032, r. 1063-1067) ruled from Kaifeng. The modern-geometry regions cover only the central plain, Sichuan and the south; the east coast is not drawn.
* **LIA - Liao (Khitan) Empire**: Daozong (b. 1032, r. 1055-1101). The Liao Southern Capital (Beijing) and Liaodong share one modern region; Khitan and Chinese culture are not separated.
* **JUR - Jurchen Tribes (Wanyan)**: The Wanyan clan led the Jurchens under Liao suzerainty; Wugunai (1021-1074) is the later-ennobled ancestor of the Jin dynasty. Age is approximate.
* **MGT - Mongol, Kereit and Tatar Tribes (Liao tributaries)**: Steppe tribes of Mongolia; no unified state before Genghis Khan.
* **XIA - Western Xia (Tangut) Empire**: Yizong (b. 1047) ruled under the influence of his regents; the Qinghai-Gansu region also contains Tibetan Tsongkha, not drawn separately.
* **TIB - Tibetan Principalities**: After the collapse of the Tibetan Empire (9th century) the plateau was divided among lords and monastic orders; the western Guge-Purang kingdom is not separated.
* **DAL - Kingdom of Dali**: The Duan clan ruled Dali from 937 until the Mongol conquest of 1253-1254; the 1066 king is not securely named here (the dynastic list of this period is disputed).
* **KKH - Kara-Khanid Khanate**: Ibrahim (r. 1038-1068) ruled the western khanate from Samarkand; the eastern khanate at Kashgar is merged here and the Buddhist Uyghur kingdom of Qocho is not drawn. Age is approximate.
* **GHZ - Ghaznavid Sultanate**: Ibrahim (r. 1059-1099) made peace with the Seljuks and raided India; age is approximate.
* **SMR - Soomra Emirate of Sindh**: The Soomra dynasty took power in Sindh in the mid-11th century (Ismaili leaning); Balochistan's tribes are merged in.
* **KSH - Kingdom of Kashmir (Lohara dynasty)**: Kalasha (r. 1063-1089) ruled Kashmir; the Punjab hill states are merged into this region. Age is approximate.
* **CND - Chandela Kingdom**: Kirtivarman (r. c. 1060-1100) ruled Bundelkhand; the Kalachuri, Paramara and Gahadavala states of the same region are not drawn. Age is approximate.
* **CHK - Chaulukya (Solanki) Kingdom of Gujarat**: Karna (r. c. 1064-1092) ruled from Anahilavada; the Chahamana and Paramara kingdoms of Rajasthan are merged into the region. Age is approximate.
* **PAL - Pala Empire (Bengal and Bihar)**: Vigrahapala III (r. c. 1043-1070) ruled a weakened Pala realm; the Varman and Chandra lines of East Bengal are not separated. Age is approximate.
* **GNG - Eastern Gangas and Somavamsis (Kalinga and Kosala)**: Anantavarman Vajrahasta V (r. 1038-1070) of the Eastern Gangas; Somavamsi Kosala shares the region. Age is approximate.
* **WCH - Western Chalukya Empire**: Someshvara I (r. 1042-1068) ruled from Kalyani; he died in 1068. The age is approximate.
* **CHL - Chola Empire**: Virarajendra (r. 1063-1070) ruled from Gangaikondacholapuram; the Sinhalese Rohana under Vijayabahu I, who expelled the Cholas c. 1070, is not drawn. Age is approximate.
* **ASM - Kingdoms of the Brahmaputra Valley**: The Kamarupa successors and hill tribes of the north-east; not individually modelled.
* **NPL - Himalayan Valleys (Nepal and Bhutan)**: Small Himalayan states; Nepal's dynastic sequence before the Karnatas (1097) is uncertain.
* **PGN - Pagan Kingdom**: Anawrahta (r. 1044-1077) unified Upper and Lower Burma after conquering Thaton in 1057; age is approximate.
* **KHM - Khmer Empire (Angkor)**: Harshavarman III succeeded his brother Udayadityavarman II in 1066; age is approximate. Central Thailand (Lavo) and the Mekong valley were Khmer territory.
* **VIE - Đại Việt (Lý dynasty)**: Lý Thánh Tông (b. 1023, r. 1054-1072) ruled from Thăng Long and campaigned against Champa in 1069.
* **CHM - Kingdom of Champa**: Rudravarman III (r. c. 1061-1074) was captured by Đại Việt in 1069; age is approximate.
* **SRV - Srivijaya (Malay thalassocracy)**: Srivijaya never recovered fully from the Chola raid of 1025; the capital moved to Jambi. The exact extent in 1066 is uncertain.
* **KDR - Kingdom of Kediri and Janggala (East Java)**: Airlangga split his kingdom into Janggala and Panjalu in 1045; they appear here as one state.
* **HEI - Heian Japan (Fujiwara regency)**: Go-Reizei (b. 1025, r. 1045-1068) reigned while the Fujiwara held the regency; Tohoku (Mutsu and Dewa) was only loosely under court control after the Former Nine Years' War (1051-1062).
* **GRY - Goryeo Kingdom**: Munjong (b. 1019, r. 1046-1083) is the king of the prosperous mid-Goryeo period.
* **TLT - Toltec Realm (Tollan)**: Tula was the dominant city of central Mexico c. 950-1150; rulers known from later Aztec tradition are legendary.
* **MXT - Mixtec and Zapotec Kingdoms**: A cultural group, not one state; no sources name its rulers for this date.
* **MYA - Maya City-States (Chichen Itza and the highlands)**: A cultural group, not one state; no sources name its rulers for this date.
* **MSO - Mississippian Chiefdoms (Cahokia and neighbours)**: A cultural group, not one state; no sources name its rulers for this date.
* **PUE - Ancestral Puebloan and Desert Farming Peoples**: A cultural group, not one state; no sources name its rulers for this date.
* **PLN - Plains and Great Basin Peoples**: A cultural group, not one state; no sources name its rulers for this date.
* **PAC - Pacific Coast Peoples**: A cultural group, not one state; no sources name its rulers for this date.
* **WDL - Eastern Woodland Peoples (Algonquian and Iroquoian)**: A cultural group, not one state; no sources name its rulers for this date.
* **ARC - Arctic and Subarctic Peoples (Thule Inuit and others)**: A cultural group, not one state; no sources name its rulers for this date.
* **ISM - Isthmian and Central American Chiefdoms**: A cultural group, not one state; no sources name its rulers for this date.
* **TAI - Taino Chiefdoms (cacicazgos)**: A cultural group, not one state; no sources name its rulers for this date.
* **AND - Andean Kingdoms and Chiefdoms (Chimú and the post-Tiwanaku lands)**: A cultural group, not one state; no sources name its rulers for this date.
* **AMZ - Amazonian and Orinoco Chiefdoms**: A cultural group, not one state; no sources name its rulers for this date.
* **TUP - Tupi-Guarani and Southern Cone Peoples**: A cultural group, not one state; no sources name its rulers for this date.
* **PTG - Mapuche and Patagonian Peoples**: A cultural group, not one state; no sources name its rulers for this date.
* **ABO - Aboriginal Australian Nations**: Hundreds of independent nations; shown as one placeholder state because the game has no way to draw them separately.
* **PNG - Papuan and Melanesian Peoples**: A cultural group, not one state; no sources name its rulers for this date.
* **MCR - Micronesian and Polynesian Chiefdoms**: A cultural group, not one state; no sources name its rulers for this date.
* **BOR - Bornean and Moluccan Coastal Chiefdoms**: A cultural group, not one state; no sources name its rulers for this date.
* **PHI - Philippine Barangay Polities (Tondo, Butuan, Cebu)**: A cultural group, not one state; no sources name its rulers for this date.
* **FMS - Austronesian Peoples of Taiwan**: A cultural group, not one state; no sources name its rulers for this date.
* **RYU - Okinawan Gusuku Chiefs**: A cultural group, not one state; no sources name its rulers for this date.
* **AIN - Ainu and Emishi Peoples of Ezo**: A cultural group, not one state; no sources name its rulers for this date.
* **MDV - Buddhist Kingdom of the Maldives**: Buddhist until the conversion of 1153; ruler names for 1066 are not attested here.
* **UNS - Uninhabited islands (placeholder)**: Madeira, the Aland region and New Zealand (Polynesian settlement c. 1250-1300) were not settled; the game requires every province to have an owner, so a placeholder state holds them.
* **SHL - Hausa, Nupe and Savanna Peoples**: Hausa city-states, Nupe, Jukun and Gur-speaking peoples; the political map is poorly known for 1066.
* **GUL - Guinea Coast and Forest Peoples**: Akan, Yoruba, Edo, Mande and Atlantic-speaking groups; Ife and Benin are not modelled separately.
* **CAF - Central African Forest and Savanna Peoples**: Bantu, Ubangian and Kisalian (Upemba) chiefdoms; the Kongo kingdom is only founded in the 14th century.
* **SSD - Nilotic Peoples of the Upper Nile**: A cultural group, not one state; no sources name its rulers for this date.
* **SWH - Swahili Coast Towns and Eastern Bantu Peoples**: Shirazi Swahili city-states (Kilwa, Mombasa, Lamu) are not drawn separately.
* **SOMA - Somali and Afar Peoples (Horn of Africa)**: A cultural group, not one state; no sources name its rulers for this date.
* **SAF - Southern African Peoples (Bantu, Khoikhoi and San)**: Mapungubwe and Great Zimbabwe emerge only after c. 1075; no state is attested here for 1066.
* **MDG - Peoples of Madagascar**: A cultural group, not one state; no sources name its rulers for this date.
