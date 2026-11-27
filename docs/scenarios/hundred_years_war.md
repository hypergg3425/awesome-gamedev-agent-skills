# Scenario: Hundred Years' War (`hundred_years_war`)

Status: v2.0 reconstruction by workstream B1. Everything marked `approximate` in `data/scenarios/hundred_years_war.json` is a best-effort reconstruction. Population, treasury and army sizes are **gameplay estimates** produced by `ScenarioLoader` (they are not documented statistics).

## Start date
* 1337-05 (Philip VI declares Aquitaine forfeit on 24 May 1337). Turns are three months long; ages are computed for the start date (see `tests/t_scenarios_v2.gd`, which checks 29 ruler ages against birth years).

## What changed in v2.0
* Countries: 37 -> 127 (all 410 provinces now have a named owner; 265 provinces were previously generic `<Region> Peoples` filler).
* 90 new political entities, of which 44 are `native: true` named cultural groups where no state can be drawn.
* Scenario-specific province names layer (`province_names`): 110 provinces; geo layer notes: 1.
* Claims: 46 entries for 31 countries; alliances/vassals/wars were reviewed against the sources below.

## Sources
### Main historical sources
* Rulers of England, France, the Empire, Iberia, Italy and Eastern Europe: standard regnal lists (Wikipedia list articles, CC BY-SA 4.0); Jonathan Sumption, The Hundred Years War vol. 1 (1990) for 1337.
* Ilkhanate successors (Jalayirids, Chobanids, Injuids, Muzaffarids, Kartids, Sarbadars): C. E. Bosworth, The New Islamic Dynasties (1996); Cambridge History of Iran vol. 6 (1986).
* Yuan China and Chagatai: Cambridge History of China vol. 6 (1994); Wikipedia lists of Yuan and Chagatai rulers.
* Delhi, Vijayanagara, Madurai, Southeast Asia, Japan, Korea: Thapar, Early India (2002); Coedès (1968); Conrad Totman, A History of Japan (2005); Wikipedia lists of rulers.
* Mali, Ethiopia, Ifat, Kilwa: Levtzion and Hopkins (1981; Ibn Battuta and al-Umari on Mansa Musa); UNESCO General History of Africa vols. 4-5.

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
| ENG | Kingdom of England | feudal_kingdom | Edward III (24) | Edward of Woodstock | gbr_home_counties | 8 | no |
| SCO | Kingdom of Scotland | feudal_kingdom | David II (under regency) (13) | - | gbr_lowland_scotland | 2 | yes |
| FRA | Kingdom of France | feudal_kingdom | Philip VI of Valois (44) | John of Normandy | fra_ile_de_france | 9 | no |
| BUR | Duchy of Burgundy | feudal_kingdom | Eudes IV of Burgundy (42) | - | fra_burgundy | 1 | yes |
| FLA | County of Flanders | feudal_kingdom | Louis I of Nevers (33) | - | bel_flanders | 1 | yes |
| BRI | Duchy of Brittany | feudal_kingdom | John III of Brittany (51) | - | fra_brittany | 1 | yes |
| HRE | Holy Roman Empire | empire | Louis IV the Bavarian (55) | Louis V of Brandenburg | deu_bavaria | 15 | yes |
| AUS | Duchy of Austria (Habsburg) | feudal_kingdom | Albert II the Lame (39) | - | aut_austria | 3 | yes |
| BOH | Kingdom of Bohemia | feudal_kingdom | John of Luxembourg (the Blind) (41) | Charles of Moravia | cze_bohemia | 4 | yes |
| HAN | Hanseatic League | merchant_republic | Council of Lübeck (50) | - | deu_mecklenburg | 2 | yes |
| TEU | Teutonic Order | theocracy | Dietrich von Altenburg (55) | - | pol_pomerania | 3 | yes |
| POL | Kingdom of Poland | feudal_kingdom | Casimir III the Great (27) | - | pol_lesser_poland | 3 | yes |
| LIT | Grand Duchy of Lithuania | feudal_kingdom | Gediminas (62) | Algirdas | ltu_lithuania | 4 | yes |
| HUN | Kingdom of Hungary | feudal_kingdom | Charles I Robert of Anjou (49) | Louis of Hungary | hun_transdanubia | 5 | yes |
| DEN | Kingdom of Denmark | feudal_kingdom | Gerhard III of Holstein (regent) (45) | Valdemar Atterdag | dnk_zealand | 4 | yes |
| SWN | Sweden and Norway (Union of Magnus Eriksson) | feudal_kingdom | Magnus IV Eriksson (21) | - | swe_svealand | 8 | yes |
| NAV | Kingdom of Navarre | feudal_kingdom | Philip III of Évreux and Joan II (31) | - | esp_navarre | 1 | yes |
| CAS | Crown of Castile | feudal_kingdom | Alfonso XI (26) | Peter of Castile | esp_old_castile | 5 | yes |
| GRA | Emirate of Granada | absolute_monarchy | Yusuf I of Granada (19) | - | esp_andalusia | 1 | yes |
| ARA | Crown of Aragon | feudal_kingdom | Peter IV the Ceremonious (18) | - | esp_catalonia | 5 | yes |
| POR | Kingdom of Portugal | feudal_kingdom | Afonso IV (46) | Peter of Portugal | prt_south_portugal | 2 | yes |
| MAR | Marinid Sultanate | absolute_monarchy | Abu al-Hasan Ali (40) | Abu Inan Faris | mar_fez | 4 | yes |
| PAP | Avignon Papacy and Papal States | theocracy | Benedict XII (52) | - | fra_provence | 3 | yes |
| NAP | Kingdom of Naples | feudal_kingdom | Robert the Wise (60) | - | ita_campania | 3 | yes |
| SIC | Kingdom of Trinacria (Sicily) | feudal_kingdom | Peter II of Sicily (33) | - | ita_sicily | 1 | yes |
| VEN | Republic of Venice | merchant_republic | Doge Francesco Dandolo (75) | - | ita_veneto | 4 | yes |
| GEN | Republic of Genoa | merchant_republic | Captains of the People of Genoa (45) | - | ita_liguria | 1 | yes |
| MIL | Lordship of Milan (Visconti) | feudal_kingdom | Azzone Visconti (35) | - | ita_lombardy | 1 | yes |
| FLO | Republic of Florence | republic | Signoria of Florence (50) | - | ita_tuscany | 1 | yes |
| BYZ | Byzantine Empire | empire | Andronikos III Palaiologos (40) | John Palaiologos | tur_constantinople | 6 | yes |
| OTT | Ottoman Beylik | military_government | Orhan (56) | Suleiman Pasha | tur_bithynia | 1 | yes |
| MAM | Mamluk Sultanate | military_government | an-Nasir Muhammad (52) | - | egy_cairo | 14 | yes |
| GOH | Golden Horde | tribal_confederation | Özbeg Khan (55) | - | rus_north_caucasus | 13 | yes |
| MOS | Grand Principality of Moscow | feudal_kingdom | Ivan I Kalita (49) | Simeon of Moscow | rus_moscow | 1 | yes |
| SRB | Kingdom of Serbia | feudal_kingdom | Stefan Dušan (29) | Stefan Uroš | srb_serbia | 4 | yes |
| BUL | Bulgarian Empire (Second) | feudal_kingdom | Ivan Alexander (36) | - | bgr_moesia | 2 | yes |
| WAL | Principality of Wallachia | feudal_kingdom | Basarab I (67) | - | rou_wallachia | 1 | yes |
| NOV | Novgorod Republic | merchant_republic | Posadnik and the veche (council) (50) | - | rus_novgorod | 3 | yes |
| GAE | Gaelic Irish Lordships | tribal_confederation | Gaelic kings (O'Brien, Ó Conchobair, Ó Néill; unnamed) (45) | - | irl_munster | 3 | yes |
| GEO | Kingdom of Georgia | feudal_kingdom | George V the Brilliant (51) | - | geo_georgia | 2 | yes |
| CYP | Kingdom of Cyprus (Lusignan) | feudal_kingdom | Hugh IV of Lusignan (42) | - | cyp_cyprus | 1 | yes |
| ARM | Armenian Kingdom of Cilicia | feudal_kingdom | Leo IV of Armenia (28) | - | tur_cilicia | 1 | yes |
| TRE | Empire of Trebizond | empire | Basil Megas Komnenos (30) | - | tur_pontus | 1 | yes |
| KRM | Beylik of Karaman | feudal_kingdom | Karamanid bey (Halil Mirza?, name uncertain) (35) | - | tur_central_anatolia | 1 | yes |
| ERT | Eretna Sultanate | feudal_kingdom | Eretna (50) | - | tur_armenia_highlands | 1 | yes |
| AYD | Beyliks of Aydın and Saruhan | feudal_kingdom | Umur Bey of Aydın (27) | - | tur_aegean_anatolia | 1 | yes |
| ART | Artuqid Beylik of Mardin | feudal_kingdom | al-Salih Shams al-Din Salih (40) | - | tur_upper_mesopotamia | 1 | yes |
| BOS | Banate of Bosnia | feudal_kingdom | Stephen II Kotromanić (45) | - | bih_bosnia_and_herz | 1 | yes |
| GAV | Kingdom of Galicia-Volhynia | feudal_kingdom | Yuri II Boleslav (27) | - | ukr_galicia_volhynia | 1 | yes |
| HAF | Hafsid Sultanate of Ifriqiya | absolute_monarchy | Abu Yahya Abu Bakr II (43) | - | tun_tunisia | 4 | yes |
| MLI | Mali Empire | empire | Mansa Musa I (Kankan Musa) (57) | Maghan Keita | gin_guinea | 7 | yes |
| KNM | Kingdom of Kanem | feudal_kingdom | Mai of Kanem (Sayfawa dynasty, name uncertain) (40) | - | tcd_batha | 3 | yes |
| ETH | Ethiopian Empire (Solomonic) | empire | Amda Seyon I (45) | - | eth_oromiya | 2 | yes |
| IFT | Sultanate of Ifat (Walasma) | absolute_monarchy | Sabr ad-Din I of Ifat (35) | - | eth_somali | 3 | yes |
| KLW | Sultanate of Kilwa | feudal_kingdom | Sulayman ibn al-Hasan of Kilwa (30) | - | tza_morogoro | 1 | yes |
| ZIM | Kingdom of Great Zimbabwe | tribal_confederation | King of Great Zimbabwe (name not attested) (40) | - | zwe_zimbabwe | 2 | yes |
| YUA | Yuan Empire (Great Khan) | empire | Toghon Temür (Emperor Huizong) (17) | - | chn_hunan | 11 | yes |
| CHG | Chagatai Khanate | tribal_confederation | Changshi Khan (30) | - | uzb_bukhoro | 6 | yes |
| KRT | Kartid Maliks of Herat | feudal_kingdom | Mu'izz ad-Din Husayn Kart (37) | - | afg_hilmand | 2 | yes |
| JAL | Jalayirid Sultanate | absolute_monarchy | Hasan Buzurg (Shaykh Hasan) (40) | - | irq_baghdad | 5 | yes |
| CHO | Chobanid Emirate of Tabriz | military_government | Hasan Kuchak (32) | - | irn_azerbaijan_persia | 2 | yes |
| INJ | Injuid Emirate of Shiraz | feudal_kingdom | Mahmud Shah Inju (30) | - | irn_fars | 2 | yes |
| MUZ | Muzaffarid Emirate of Yazd and Kerman | military_government | Mubariz al-Din Muhammad (37) | - | irn_kerman | 1 | yes |
| SBD | Sarbadars of Sabzevar | republic | Abd al-Razzaq (Sarbadar leader) (35) | - | irn_khorasan | 1 | yes |
| DEL | Delhi Sultanate (Tughluq) | empire | Muhammad bin Tughluq (47) | - | ind_madhya_pradesh | 9 | yes |
| VIJ | Vijayanagara (Sangama dynasty, founded 1336) | empire | Harihara I (37) | - | ind_karnataka | 1 | yes |
| MDU | Madurai Sultanate | military_government | Jalal ud-Din Ahsan Shah (40) | - | ind_tamil_nadu | 1 | yes |
| GNG | Eastern Ganga Kingdom (Odisha) | feudal_kingdom | Narasimhadeva III (40) | - | ind_odisha | 1 | yes |
| LKA | Sinhalese Kingdoms and Jaffna | feudal_kingdom | Vijayabahu V (40) | - | lka_sri_lanka | 1 | yes |
| AHM | Ahom Kingdom | feudal_kingdom | Sukhrangpha (40) | - | ind_arunachal_pradesh | 1 | yes |
| SKT | Sukhothai Kingdom | feudal_kingdom | Loethai of Sukhothai (40) | - | tha_chiang_mai | 1 | yes |
| KHM | Khmer Kingdom (Angkor) | empire | Khmer king (Jayavarman Paramesvara?, name uncertain) (40) | - | khm_cambodia | 2 | yes |
| SPS | Sultanate of Samudera Pasai | absolute_monarchy | Ahmad Malik az-Zahir (45) | - | idn_sumatera_utara | 1 | yes |
| MJP | Majapahit Empire | empire | Queen Tribhuwana Wijayatunggadewi (with Gajah Mada) (30) | - | idn_jawa_timur | 1 | yes |
| VIE | Đại Việt (Trần dynasty) | empire | Trần Hiến Tông (18) | - | vnm_nghe_an | 1 | yes |
| CHM | Kingdom of Champa | feudal_kingdom | Chế A Nan (45) | - | vnm_gia_lai | 1 | yes |
| PIN | Pinya Kingdom (Upper Burma) | feudal_kingdom | Uzana I of Pinya (40) | - | mmr_shan | 1 | yes |
| HNT | Mon Kingdom of Hanthawaddy | feudal_kingdom | Binnya E Law (40) | - | mmr_tanintharyi | 1 | yes |
| ASK | Ashikaga Shogunate (Northern Court) | feudal_kingdom | Ashikaga Takauji (32) | - | jpn_nagano | 1 | yes |
| SCT | Southern Court (Go-Daigo) | feudal_kingdom | Emperor Go-Daigo (49) | - | jpn_iwate | 1 | yes |
| GRY | Goryeo Kingdom (under Yuan) | feudal_kingdom | Chungsuk of Goryeo (43) | - | prk_north_korea | 3 | yes |
| CHZ | Kingdom of Chūzan (Ryukyu) | feudal_kingdom | Tamagusuku of Chūzan (40) | - | jpn_okinawa | 1 | yes |
| RAS | Rasulid Sultanate of Yemen | absolute_monarchy | al-Mujahid Ali (37) | - | yem_yemen | 1 | yes |
| OMA | Nabhani Imamate of Oman | theocracy | Nabhani Imam (name uncertain) (45) | - | omn_oman | 2 | yes |
| TNH | Mexica and Tepanec City-States (Valley of Mexico) | tribal_confederation | Tlatoani of Tenochtitlan and Azcapotzalco (names legendary) (40) | - | mex_jalisco | 1 | yes |
| INC | Kingdom of Cusco (early Inca) | tribal_confederation | Sapa Inca of Cusco (legendary list) (40) | - | per_madre_de_dios | 1 | yes |
| CHI | Chimú Kingdom (Chimor) | absolute_monarchy | Chimú king (name not securely attested) (40) | - | per_loreto | 1 | yes |
| MXT | Mixtec and Zapotec Kingdoms | tribal_confederation | Chiefs and elders (unnamed) (40) | - | mex_oaxaca | 1 | yes |
| MYA | League of Mayapan and Maya Cities | tribal_confederation | Chiefs and elders (unnamed) (40) | - | mex_campeche | 3 | yes |
| MSO | Mississippian and Southeastern Chiefdoms | tribal_confederation | Chiefs and elders (unnamed) (40) | - | usa_michigan | 4 | yes |
| PUE | Ancestral Puebloan and Desert Farming Peoples | tribal_confederation | Chiefs and elders (unnamed) (40) | - | usa_colorado | 3 | yes |
| PLN | Plains and Great Basin Peoples | tribal_confederation | Chiefs and elders (unnamed) (40) | - | usa_south_dakota | 4 | yes |
| PAC | Pacific Coast Peoples | tribal_confederation | Chiefs and elders (unnamed) (40) | - | usa_california | 3 | yes |
| WDL | Eastern Woodland Peoples (Algonquian and Iroquoian) | tribal_confederation | Chiefs and elders (unnamed) (40) | - | usa_new_york | 3 | yes |
| ARC | Arctic and Subarctic Peoples | tribal_confederation | Chiefs and elders (unnamed) (40) | - | usa_alaska | 5 | yes |
| ISM | Isthmian and Central American Chiefdoms | tribal_confederation | Chiefs and elders (unnamed) (40) | - | hnd_honduras | 5 | yes |
| TAI | Taino Chiefdoms (cacicazgos) | tribal_confederation | Chiefs and elders (unnamed) (40) | - | hti_haiti | 8 | yes |
| AND | Andean Kingdoms and Chiefdoms | tribal_confederation | Chiefs and elders (unnamed) (40) | - | ecu_ecuador | 3 | yes |
| AMZ | Amazonian and Orinoco Chiefdoms | tribal_confederation | Chiefs and elders (unnamed) (40) | - | bra_amazonas | 10 | yes |
| TUP | Tupi-Guarani and Southern Cone Peoples | tribal_confederation | Chiefs and elders (unnamed) (40) | - | bra_minas_gerais | 9 | yes |
| PTG | Mapuche and Patagonian Peoples | tribal_confederation | Chiefs and elders (unnamed) (40) | - | arg_santa_cruz | 3 | yes |
| ABO | Aboriginal Australian Nations | tribal_confederation | Chiefs and elders (unnamed) (40) | - | aus_new_south_wales | 6 | yes |
| PNG | Papuan and Melanesian Peoples | tribal_confederation | Chiefs and elders (unnamed) (40) | - | idn_papua | 8 | yes |
| MCR | Micronesian and Polynesian Chiefdoms | tribal_confederation | Chiefs and elders (unnamed) (40) | - | isl_polynesia | 2 | yes |
| BOR | Bornean and Moluccan Coastal Chiefdoms | tribal_confederation | Chiefs and elders (unnamed) (40) | - | idn_kalimantan_timur | 9 | yes |
| PHI | Philippine Barangay Polities | tribal_confederation | Chiefs and elders (unnamed) (40) | - | phl_isabela | 2 | yes |
| FMS | Austronesian Peoples of Taiwan | tribal_confederation | Chiefs and elders (unnamed) (40) | - | twn_taiwan | 1 | yes |
| AIN | Ainu and Emishi Peoples of Ezo | tribal_confederation | Chiefs and elders (unnamed) (40) | - | jpn_hokkaido | 1 | yes |
| MDV | Kingdom of the Maldives | tribal_confederation | Chiefs and elders (unnamed) (40) | - | isl_indian_ocean | 1 | yes |
| UNS | Uninhabited islands (placeholder) | tribal_confederation | Chiefs and elders (unnamed) (40) | - | isl_atlantic | 2 | yes |
| SHL | Hausa, Nupe and Savanna Peoples | tribal_confederation | Chiefs and elders (unnamed) (40) | - | nga_niger | 4 | yes |
| GUL | Guinea Coast and Forest Peoples | tribal_confederation | Chiefs and elders (unnamed) (40) | - | gha_ghana | 7 | yes |
| CAF | Central African Forest and Savanna Peoples | tribal_confederation | Chiefs and elders (unnamed) (40) | - | cod_orientale | 10 | yes |
| SSD | Nilotic and Great Lakes Peoples | tribal_confederation | Chiefs and elders (unnamed) (40) | - | sds_s_sudan | 4 | yes |
| SWH | Swahili Coast Towns and Eastern Bantu Peoples | tribal_confederation | Chiefs and elders (unnamed) (40) | - | ken_kenya | 4 | yes |
| SAF | Southern African Peoples (Bantu, Khoikhoi and San) | tribal_confederation | Chiefs and elders (unnamed) (40) | - | zaf_limpopo | 8 | yes |
| MAO | Early Maori Settlers of Aotearoa | tribal_confederation | Chiefs and elders (unnamed) (40) | - | nzl_waikato | 2 | yes |
| GRN | Norse Greenland Settlements | tribal_confederation | Chiefs and elders (unnamed) (40) | - | grl_greenland | 1 | yes |
| MDG | Peoples of Madagascar | tribal_confederation | Chiefs and elders (unnamed) (40) | - | mdg_madagascar | 1 | yes |
| SIB | Peoples of Siberia and the Far East | tribal_confederation | Chiefs and elders (unnamed) (40) | - | rus_sakha_yakutia | 6 | yes |
| HIM | Himalayan Valleys (Nepal and Bhutan) | tribal_confederation | Chiefs and elders (unnamed) (40) | - | npl_nepal | 2 | yes |
| SAH | Tuareg and Saharan Oasis Chiefdoms | tribal_confederation | Chiefs and elders (unnamed) (40) | - | dza_algerian_sahara | 3 | yes |
| NJD | Bedouin Tribes of Arabia | tribal_confederation | Chiefs and elders (unnamed) (40) | - | sau_najd | 4 | yes |
| NIL | Nubian and Nilotic Peoples | tribal_confederation | Chiefs and elders (unnamed) (40) | - | sdn_northern | 2 | yes |
| PNN | Malay Peninsula and Sumatran Coastal Polities | tribal_confederation | Chiefs and elders (unnamed) (40) | - | idn_riau | 3 | yes |
| SAM | Sami and Northern Finnic Peoples | tribal_confederation | Sami elders (unnamed) (40) | - | fin_north_finland | 1 | yes |
| ALBL | Albanian Lords (Angevin Durrës and the highland clans) | tribal_confederation | Albanian princes (Thopia, Muzaka; unnamed) (40) | - | alb_albania | 1 | yes |

## Notes per new or changed country

* **NOV - Novgorod Republic**: A republic governed by the posadnik, the veche and the archbishop; princes of Moscow were invited as military leaders. The ruler shown is an office, not a person.
* **GAE - Gaelic Irish Lordships**: The Gaelic resurgence after the Bruce invasion (1315-1318); the Anglo-Irish earldoms of Desmond and Ormond are folded into English Ireland and the lordships are merged into one state.
* **GEO - Kingdom of Georgia**: George V (r. 1314-1346) shook off Ilkhanid suzerainty after 1335; the Armenian Zakarid lands are part of the Georgian sphere. Age derived from b. 1286.
* **CYP - Kingdom of Cyprus (Lusignan)**: Hugh IV (r. 1324-1359) ruled a Latin kingdom over a mostly Greek Orthodox population.
* **ARM - Armenian Kingdom of Cilicia**: Leo IV (r. 1320-1342) was under heavy Mamluk pressure; Ayas fell to the Mamluks in 1337. Age is approximate.
* **TRE - Empire of Trebizond**: Basil (r. 1332-1340) succeeded the murdered Manuel II; age is approximate.
* **KRM - Beylik of Karaman**: The Karamanids held Konya after the Ilkhanid collapse; the ruler of 1337 is uncertain.
* **ERT - Eretna Sultanate**: Eretna, a former Ilkhanid governor, founded his sultanate around Sivas in 1335; the region of the scenario is the Erzincan-Erzurum side. Age is approximate.
* **AYD - Beyliks of Aydın and Saruhan**: Umur Bey (bey from 1334) led naval raids across the Aegean; Saruhan and Germiyan are merged into this region.
* **ART - Artuqid Beylik of Mardin**: The Artuqids of Mardin were tributary to the Mamluks; reign c. 1312-1364.
* **BOS - Banate of Bosnia**: Stephen II (r. 1322-1353) expanded into Hum (Herzegovina) in 1326. Religion is shown as Catholic; the Bosnian Church is not modelled.
* **GAV - Kingdom of Galicia-Volhynia**: Yuri II (r. 1323-1340) was the last ruler of the Romanovich line; he was poisoned in 1340 and the kingdom was contested by Poland and Lithuania. Age is approximate.
* **HAF - Hafsid Sultanate of Ifriqiya**: Abu Bakr II al-Mutawakkil (r. 1318-1346) held Tunis; the Zayyanids of Tlemcen fell to the Marinids in 1337. Age is approximate.
* **MLI - Mali Empire**: Mansa Musa (r. c. 1312-1337) made the pilgrimage of 1324; he died around 1337 and Maghan I succeeded him. Mali held Timbuktu from 1324 and Gao as a tributary. Birth year is not recorded; age is a guess.
* **KNM - Kingdom of Kanem**: Kanem was being pressed by the Bulala from the east; the Mai of 1337 is not securely named.
* **ETH - Ethiopian Empire (Solomonic)**: Amda Seyon I (r. 1314-1344) subjugated Ifat in 1332; his birth year is unknown and the age is estimated.
* **IFT - Sultanate of Ifat (Walasma)**: After Haqq ad-Din II was defeated by Amda Seyon in 1332, Sabr ad-Din led the Muslim lowlands; age approximate. Mogadishu is merged into this region.
* **KLW - Sultanate of Kilwa**: The Mahdali sultans of Kilwa controlled the gold trade from Sofala; ruler and age are approximate.
* **ZIM - Kingdom of Great Zimbabwe**: Great Zimbabwe flourished c. 1250-1450 as a centre of the gold trade; written sources do not name its kings.
* **YUA - Yuan Empire (Great Khan)**: Toghon Temür (b. 1320, r. 1333-1368) was dominated by the chancellor Bayan in 1337, who banned Chinese from bearing arms. Mongolia, Tibet and Yunnan are provinces here. The imperial capital Dadu (Beijing) lies in the Hebei-Liaodong region, so the capital marker is approximate.
* **CHG - Chagatai Khanate**: Changshi (r. 1335-1338) ruled a khanate that was splitting into Transoxiana and Moghulistan; age is a guess.
* **KRT - Kartid Maliks of Herat**: Husayn (r. 1332-1370) ruled Herat as an Ilkhanid successor; age is approximate.
* **JAL - Jalayirid Sultanate**: Hasan Buzurg took Baghdad after the death of the last Ilkhan in 1335-1336; age is approximate.
* **CHO - Chobanid Emirate of Tabriz**: Hasan Kuchak seized Tabriz in the 1337-1338 struggle for the Ilkhanid inheritance; the exact date of his rise and his age are approximate.
* **INJ - Injuid Emirate of Shiraz**: Mahmud Shah ruled Fars and Isfahan from c. 1336; ruler age is approximate.
* **MUZ - Muzaffarid Emirate of Yazd and Kerman**: Mubariz ad-Din held Yazd and conquered Kerman around 1340-1341, so Kerman is shown owned slightly early; age is approximate.
* **SBD - Sarbadars of Sabzevar**: The Sarbadar revolt began in Khorasan around 1337 (Baihaq/Sabzevar); the leader of that very year is approximate.
* **DEL - Delhi Sultanate (Tughluq)**: The Delhi Sultanate at its greatest extent (r. 1325-1351); Bengal revolted in 1338 and the Deccan in the 1340s. The capital marker stands for Delhi-Agra; Daulatabad lies in the Deccan region.
* **VIJ - Vijayanagara (Sangama dynasty, founded 1336)**: Harihara I and his brother Bukka founded the city in 1336; the Hoysalas and Kakatiyan Nayakas still hold parts of the region. Age is approximate.
* **MDU - Madurai Sultanate**: Ahsan Khan declared independence from Delhi in 1335; Kerala and the Pandya remnants share the modern region. Age is approximate.
* **GNG - Eastern Ganga Kingdom (Odisha)**: Narasimhadeva III (r. 1328-1352) of the Eastern Ganga dynasty; age is approximate.
* **LKA - Sinhalese Kingdoms and Jaffna**: Vijayabahu V (r. 1335-1341) ruled from Dedigama; the Jaffna kingdom under the Aryacakravarti kings in the north is merged. Age is approximate.
* **AHM - Ahom Kingdom**: The Tai-Ahom kingdom in the Brahmaputra valley (founded 1228); Sukhrangpha ruled c. 1332-1364. Age is a guess.
* **SKT - Sukhothai Kingdom**: Loethai (r. c. 1323-1347) ruled a kingdom that was losing its vassals; Ayutthaya is founded in 1351. Age is approximate.
* **KHM - Khmer Kingdom (Angkor)**: After Jayavarman VIII (d. 1295) Theravada Buddhism spread and Angkor declined; the kings of the 1330s are poorly attested.
* **SPS - Sultanate of Samudera Pasai**: One of the first Muslim states in Southeast Asia; Sultan Ahmad ruled c. 1326-1348 and was visited by Ibn Battuta in 1345. Age is approximate.
* **MJP - Majapahit Empire**: Tribhuwana (r. 1328-1350) ruled with the mahapatih Gajah Mada, who swore the Palapa oath in 1336 or 1343 (sources disagree). Age is approximate.
* **VIE - Đại Việt (Trần dynasty)**: Hiến Tông (b. 1319, r. 1329-1341) reigned under the guidance of the retired emperor Trần Minh Tông, who was the real power.
* **CHM - Kingdom of Champa**: Che A Nan (r. 1318-1342); Champa was weakened by Đại Việt. Age is approximate.
* **PIN - Pinya Kingdom (Upper Burma)**: After the fall of Pagan (1287), Upper Burma was split between Pinya and Sagaing; they are merged here. The ruler and age are approximate.
* **HNT - Mon Kingdom of Hanthawaddy**: Founded as Martaban in 1287; Binnya E Law is dated to c. 1330-1348. Age is approximate.
* **ASK - Ashikaga Shogunate (Northern Court)**: Takauji installed the Northern Court emperor Kōmyō (b. 1322) in 1336 and was appointed shogun in 1338; the sources of his birth year differ (1305 is commonly given).
* **SCT - Southern Court (Go-Daigo)**: Go-Daigo fled to Yoshino in 1336 (in the Kinai region, which is shown as Ashikaga land); his Tohoku general Kitabatake Akiie is the strength of the Southern Court on this map. Go-Daigo died in 1339.
* **GRY - Goryeo Kingdom (under Yuan)**: Chungsuk (b. 1294) reigned a second time 1332-1339 as a Yuan son-in-law and vassal.
* **CHZ - Kingdom of Chūzan (Ryukyu)**: Okinawa was split into three kingdoms (Hokuzan, Chuzan, Nanzan) from c. 1322; Tamagusuku is dated 1337-1349. Only Chuzan is drawn.
* **RAS - Rasulid Sultanate of Yemen**: al-Mujahid Ali (r. 1321-1363); birth year is approximate.
* **OMA - Nabhani Imamate of Oman**: The Banu Nabhan dynasty ruled Ibadi Oman from 1154; shown as Sunni because the game has no Ibadi option. The Gulf coast was under Hormuz influence.
* **TNH - Mexica and Tepanec City-States (Valley of Mexico)**: Tenochtitlan was founded in 1325 (traditional date); the Mexica were subjects of Azcapotzalco and Tarasca; no secure royal list exists.
* **INC - Kingdom of Cusco (early Inca)**: The early Inca rulers (Mayta Capac, Capac Yupanqui) are known only from later oral tradition.
* **CHI - Chimú Kingdom (Chimor)**: The Chimú state of the north coast (capital Chan Chan) lasted until the Inca conquest c. 1470; the modern region also covers Amazonian land.
* **MXT - Mixtec and Zapotec Kingdoms**: A cultural group, not one state: the political map of this region and date is not securely documented, so no ruler is named.
* **MYA - League of Mayapan and Maya Cities**: Mayapan led the Yucatan Maya c. 1220-1440; its rulers are not securely named.
* **MSO - Mississippian and Southeastern Chiefdoms**: A cultural group, not one state: the political map of this region and date is not securely documented, so no ruler is named.
* **PUE - Ancestral Puebloan and Desert Farming Peoples**: A cultural group, not one state: the political map of this region and date is not securely documented, so no ruler is named.
* **PLN - Plains and Great Basin Peoples**: A cultural group, not one state: the political map of this region and date is not securely documented, so no ruler is named.
* **PAC - Pacific Coast Peoples**: A cultural group, not one state: the political map of this region and date is not securely documented, so no ruler is named.
* **WDL - Eastern Woodland Peoples (Algonquian and Iroquoian)**: A cultural group, not one state: the political map of this region and date is not securely documented, so no ruler is named.
* **ARC - Arctic and Subarctic Peoples**: A cultural group, not one state: the political map of this region and date is not securely documented, so no ruler is named.
* **ISM - Isthmian and Central American Chiefdoms**: A cultural group, not one state: the political map of this region and date is not securely documented, so no ruler is named.
* **TAI - Taino Chiefdoms (cacicazgos)**: A cultural group, not one state: the political map of this region and date is not securely documented, so no ruler is named.
* **AND - Andean Kingdoms and Chiefdoms**: A cultural group, not one state: the political map of this region and date is not securely documented, so no ruler is named.
* **AMZ - Amazonian and Orinoco Chiefdoms**: A cultural group, not one state: the political map of this region and date is not securely documented, so no ruler is named.
* **TUP - Tupi-Guarani and Southern Cone Peoples**: A cultural group, not one state: the political map of this region and date is not securely documented, so no ruler is named.
* **PTG - Mapuche and Patagonian Peoples**: A cultural group, not one state: the political map of this region and date is not securely documented, so no ruler is named.
* **ABO - Aboriginal Australian Nations**: A cultural group, not one state: the political map of this region and date is not securely documented, so no ruler is named.
* **PNG - Papuan and Melanesian Peoples**: A cultural group, not one state: the political map of this region and date is not securely documented, so no ruler is named.
* **MCR - Micronesian and Polynesian Chiefdoms**: A cultural group, not one state: the political map of this region and date is not securely documented, so no ruler is named.
* **BOR - Bornean and Moluccan Coastal Chiefdoms**: A cultural group, not one state: the political map of this region and date is not securely documented, so no ruler is named.
* **PHI - Philippine Barangay Polities**: A cultural group, not one state: the political map of this region and date is not securely documented, so no ruler is named.
* **FMS - Austronesian Peoples of Taiwan**: A cultural group, not one state: the political map of this region and date is not securely documented, so no ruler is named.
* **AIN - Ainu and Emishi Peoples of Ezo**: A cultural group, not one state: the political map of this region and date is not securely documented, so no ruler is named.
* **MDV - Kingdom of the Maldives**: Buddhist until the conversion of 1153; Maldivian rulers of 1337 are not named here.
* **UNS - Uninhabited islands (placeholder)**: A cultural group, not one state: the political map of this region and date is not securely documented, so no ruler is named.
* **SHL - Hausa, Nupe and Savanna Peoples**: A cultural group, not one state: the political map of this region and date is not securely documented, so no ruler is named.
* **GUL - Guinea Coast and Forest Peoples**: Akan, Yoruba and Edo states (Ife, Benin) and Atlantic-coast peoples; not modelled individually.
* **CAF - Central African Forest and Savanna Peoples**: A cultural group, not one state: the political map of this region and date is not securely documented, so no ruler is named.
* **SSD - Nilotic and Great Lakes Peoples**: A cultural group, not one state: the political map of this region and date is not securely documented, so no ruler is named.
* **SWH - Swahili Coast Towns and Eastern Bantu Peoples**: Swahili city-states (Mombasa, Lamu, Pate) are not drawn separately; Kilwa is.
* **SAF - Southern African Peoples (Bantu, Khoikhoi and San)**: Great Zimbabwe is drawn separately; Mapungubwe ended c. 1300; the rest is Bantu, Khoikhoi and San peoples.
* **MAO - Early Maori Settlers of Aotearoa**: Polynesian settlement of New Zealand began c. 1250-1300; no chiefs are named.
* **GRN - Norse Greenland Settlements**: The Western Settlement is abandoned c. 1350; the Eastern Settlement survives to c. 1450.
* **MDG - Peoples of Madagascar**: A cultural group, not one state: the political map of this region and date is not securely documented, so no ruler is named.
* **SIB - Peoples of Siberia and the Far East**: A cultural group, not one state: the political map of this region and date is not securely documented, so no ruler is named.
* **HIM - Himalayan Valleys (Nepal and Bhutan)**: A cultural group, not one state: the political map of this region and date is not securely documented, so no ruler is named.
* **SAH - Tuareg and Saharan Oasis Chiefdoms**: A cultural group, not one state: the political map of this region and date is not securely documented, so no ruler is named.
* **NJD - Bedouin Tribes of Arabia**: A cultural group, not one state: the political map of this region and date is not securely documented, so no ruler is named.
* **NIL - Nubian and Nilotic Peoples**: Remnants of Christian Nubia (Dotawo) and Arab tribes under Mamluk influence; no single state.
* **PNN - Malay Peninsula and Sumatran Coastal Polities**: A cultural group, not one state: the political map of this region and date is not securely documented, so no ruler is named.
* **SAM - Sami and Northern Finnic Peoples**: Reindeer-herding peoples of Lapland; no state.
* **ALBL - Albanian Lords (Angevin Durrës and the highland clans)**: Angevin claims over Durrës (Kingdom of Albania) were fading; Serbia conquers the region in 1343-1346.
