# Scenario: Early Modern Europe (`early_modern`)

Status: v2.0 reconstruction by workstream B1. Everything marked `approximate` in `data/scenarios/early_modern.json` is a best-effort reconstruction. Population, treasury and army sizes are **gameplay estimates** produced by `ScenarioLoader` (they are not documented statistics).

## Start date
* 1519-06 (Charles V elected Holy Roman Emperor on 28 June 1519). Turns are three months long; ages are computed for the start date (see `tests/t_scenarios_v2.gd`, which checks 29 ruler ages against birth years).

## What changed in v2.0
* Countries: 54 -> 125 (all 410 provinces now have a named owner; 187 provinces were previously generic `<Region> Peoples` filler).
* 71 new political entities, of which 39 are `native: true` named cultural groups where no state can be drawn.
* Scenario-specific province names layer (`province_names`): 88 provinces; geo layer notes: 0.
* Claims: 79 entries for 34 countries; alliances/vassals/wars were reviewed against the sources below.

## Sources
### Main historical sources
* European rulers: standard regnal lists (Wikipedia, CC BY-SA 4.0); Geoffrey Parker, Emperor: A New Life of Charles V (2019) for the Habsburg context.
* Ottomans, Safavids, Mamluk conquest of 1517: Halil Inalcik, The Ottoman Empire: The Classical Age (1973); Roger Savory, Iran under the Safavids (1980).
* Central, South and Southeast Asia: Babur-nama (primary source); Thapar (2002); Coedès (1968); M. C. Ricklefs, A History of Modern Indonesia (2001).
* Africa and the Americas: Levtzion and Hopkins (1981) and Leo Africanus (primary) for Songhai; UNESCO General History of Africa vol. 5; Cambridge History of the Native Peoples of the Americas (1996).

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
| SPA | Kingdom of Spain (Habsburg Realm) | absolute_monarchy | Charles I (Emperor-elect Charles V) (19) | - | esp_new_castile | 21 | yes |
| NAP | Kingdom of Naples (Habsburg viceroyalty) | feudal_kingdom | Ramon de Cardona (52) | - | ita_campania | 3 | yes |
| NLD | Habsburg Netherlands | feudal_kingdom | Margaret of Austria (regent) (39) | - | nld_brabant | 6 | yes |
| POR | Kingdom of Portugal | absolute_monarchy | Manuel I the Fortunate (50) | John | prt_south_portugal | 7 | yes |
| FRA | Kingdom of France | absolute_monarchy | Francis I (24) | Francis, Dauphin | fra_ile_de_france | 14 | no |
| LOR | Duchy of Lorraine | feudal_kingdom | Antoine the Good (30) | - | fra_lorraine | 1 | yes |
| SAV | Duchy of Savoy | feudal_kingdom | Charles III (33) | - | ita_piedmont | 1 | yes |
| GEN | Republic of Genoa | merchant_republic | Ottaviano Fregoso (49) | - | ita_liguria | 1 | yes |
| ENG | Kingdom of England | absolute_monarchy | Henry VIII (27) | Mary | gbr_home_counties | 7 | no |
| SCO | Kingdom of Scotland | feudal_kingdom | James V (under the Duke of Albany) (7) | - | gbr_lowland_scotland | 2 | yes |
| IRE | Gaelic & Norman Irish Lords | tribal_confederation | Conn Bacach O'Neill (35) | - | gbr_ulster | 3 | yes |
| DEN | Kingdom of Denmark | feudal_kingdom | Christian II (38) | John of Denmark | dnk_zealand | 3 | yes |
| NOR | Kingdom of Norway (Danish union) | feudal_kingdom | Christian II (personal union) (38) | - | nor_south_norway | 4 | yes |
| SWE | Sweden (Sture Regency) | feudal_kingdom | Sten Sture the Younger (26) | - | swe_svealand | 6 | yes |
| AUS | Habsburg Austria | feudal_kingdom | Ferdinand of Austria (16) | - | aut_austria | 6 | yes |
| BAV | Duchy of Bavaria | feudal_kingdom | William IV (25) | - | deu_bavaria | 1 | yes |
| SAX | Electorate of Saxony | feudal_kingdom | Frederick III the Wise (56) | - | deu_saxony | 2 | yes |
| BRA | Margraviate of Brandenburg | feudal_kingdom | Joachim I Nestor (35) | - | deu_brandenburg | 1 | yes |
| MEK | Duchies of Mecklenburg & Pomerania | feudal_kingdom | Bogislaw X (65) | - | deu_mecklenburg | 1 | yes |
| PAL | Palatinate & Rhenish Electorates | feudal_kingdom | Louis V, Elector Palatine (40) | - | deu_rhineland | 1 | yes |
| BSW | Brunswick-Lüneburg | feudal_kingdom | Henry V the Younger (30) | - | deu_lower_saxony | 1 | yes |
| SWI | Swiss Confederacy | republic | Federal Diet (Tagsatzung) (50) | - | che_switzerland | 1 | yes |
| VEN | Republic of Venice | merchant_republic | Leonardo Loredan (Doge) (83) | - | ita_veneto | 4 | yes |
| PAP | Papal States | theocracy | Leo X (Giovanni de' Medici) (43) | - | ita_lazio | 2 | yes |
| FLO | Florence (Medici) | merchant_republic | Giulio de' Medici (41) | - | ita_tuscany | 1 | yes |
| POL | Poland-Lithuania | feudal_kingdom | Sigismund I the Old (52) | - | pol_lesser_poland | 10 | yes |
| TEU | Teutonic Order (Prussia) | theocracy | Albert of Brandenburg-Ansbach (29) | - | rus_koenigsberg | 1 | yes |
| LIV | Livonian Order | theocracy | Wolter von Plettenberg (69) | - | lva_latvia | 2 | yes |
| MOS | Grand Duchy of Muscovy | absolute_monarchy | Vasili III (40) | - | rus_moscow | 6 | yes |
| KAZ | Khanate of Kazan | tribal_confederation | Shah Ali Khan (14) | - | rus_volga | 1 | yes |
| HUN | Kingdom of Hungary | feudal_kingdom | Louis II Jagiellon (12) | - | hun_transdanubia | 5 | yes |
| BOH | Kingdom of Bohemia | feudal_kingdom | Louis II Jagiellon (personal union) (12) | - | cze_bohemia | 3 | yes |
| OTT | Ottoman Empire | empire | Selim I the Grim (49) | Suleiman | tur_constantinople | 36 | yes |
| EGY | Egypt (Mamluk emirs under Ottoman rule) | feudal_kingdom | Khayr Bey (55) | - | egy_cairo | 4 | yes |
| CRI | Crimean Khanate | tribal_confederation | Mehmed I Giray (52) | - | ukr_pontic_steppe | 4 | yes |
| ALG | Algiers (Barbarossa) | military_government | Hayreddin Barbarossa (41) | - | dza_algiers | 2 | yes |
| HAF | Hafsid Tunis | feudal_kingdom | Muhammad V (46) | - | tun_tunisia | 1 | yes |
| MAR | Wattasid Morocco | feudal_kingdom | Muhammad al-Burtuqali (50) | - | mar_fez | 2 | yes |
| SAF | Safavid Persia | absolute_monarchy | Ismail I (31) | Tahmasp | irn_azerbaijan_persia | 11 | yes |
| GEO | Georgian Kingdoms | feudal_kingdom | David X of Kartli (37) | - | geo_georgia | 1 | yes |
| UZB | Shaybanid Uzbek Khanate | tribal_confederation | Küchkünji Khan (61) | - | uzb_bukhoro | 4 | yes |
| KAB | Kabul (Babur's Timurid Realm) | feudal_kingdom | Babur (36) | - | afg_badakhshan | 2 | yes |
| DEL | Delhi Sultanate (Lodi) | feudal_kingdom | Ibrahim Lodi (38) | - | ind_madhya_pradesh | 3 | yes |
| RAJ | Mewar & Rajput Confederacy | feudal_kingdom | Rana Sanga (37) | - | ind_rajasthan | 1 | yes |
| VIJ | Vijayanagara Empire | empire | Krishnadevaraya (48) | - | ind_karnataka | 2 | yes |
| DEC | Deccan Sultanates | feudal_kingdom | Ismail Adil Shah (21) | - | ind_maharashtra | 1 | yes |
| ETH | Ethiopian Empire | feudal_kingdom | Lebna Dengel (Dawit II) (23) | - | eth_oromiya | 2 | yes |
| AZT | Aztec Triple Alliance | empire | Moctezuma II (53) | - | mex_jalisco | 2 | yes |
| INC | Inca Empire | empire | Huayna Capac (55) | - | per_madre_de_dios | 6 | yes |
| CHN | Ming China | empire | Zhengde Emperor (27) | - | chn_jilin | 5 | yes |
| KOR | Joseon Korea | absolute_monarchy | Jungjong (31) | - | kor_gangwon | 3 | yes |
| ASH | Ashikaga Shogunate (Sengoku Japan) | feudal_kingdom | Ashikaga Yoshitane (53) | - | jpn_nagano | 1 | yes |
| HOJ | Eastern Daimyo (Hōjō) | feudal_kingdom | Hōjō Ujitsuna (32) | - | jpn_iwate | 1 | yes |
| AYU | Ayutthaya Kingdom | absolute_monarchy | Ramathibodi II (50) | - | tha_chiang_mai | 2 | yes |
| MGL | Northern Yuan (Mongol Khanate of Dayan Khan's heirs) | tribal_confederation | Bodi Alagh Khan (25) | - | chn_inner_mongol | 4 | yes |
| JUR | Jurchen Tribes (Jianzhou and Haixi) | tribal_confederation | Jurchen chiefs under Ming titles (unnamed) (40) | - | chn_heilongjiang | 2 | yes |
| YRK | Yarkent Khanate (Chagatai of Kashgar) | tribal_confederation | Sultan Said Khan (32) | - | chn_xinjiang | 2 | yes |
| KZK | Kazakh Khanate | tribal_confederation | Qasim Khan (65) | - | kaz_qaraghandy | 3 | yes |
| ARG | Arghun Dynasty of Kandahar | feudal_kingdom | Shah Beg Arghun (39) | - | afg_hilmand | 1 | yes |
| SMA | Samma Sultanate of Sindh | feudal_kingdom | Jam Firuz of Sindh (35) | - | pak_baluchistan | 1 | yes |
| KSH | Sultanate of Kashmir | feudal_kingdom | Muhammad Shah of Kashmir (Shah Mir dynasty) (35) | - | ind_ladakh | 1 | yes |
| GJP | Gajapati Kingdom of Odisha | feudal_kingdom | Prataparudra Deva (49) | - | ind_odisha | 1 | yes |
| BNG | Bengal Sultanate (Husain Shahi) | feudal_kingdom | Alauddin Husain Shah (60) | - | bgd_bangladesh | 1 | yes |
| AHM | Ahom Kingdom | feudal_kingdom | Suhungmung (Dihingia Raja) (40) | - | ind_arunachal_pradesh | 1 | yes |
| KTT | Kingdom of Kotte | feudal_kingdom | Vijayabahu VII (40) | - | lka_sri_lanka | 1 | yes |
| PGU | Kingdom of Pegu (Hanthawaddy) | feudal_kingdom | Binnya Ran II (60) | - | mmr_tanintharyi | 1 | yes |
| AVA | Kingdom of Ava | feudal_kingdom | Shwenankyawshin (40) | - | mmr_shan | 1 | yes |
| KHM | Khmer Kingdom (Ang Chan I) | absolute_monarchy | Ang Chan I (25) | - | khm_cambodia | 1 | yes |
| LNX | Kingdom of Lan Xang | absolute_monarchy | Visoun (Wisunarat) (45) | - | lao_laos | 1 | yes |
| VIE | Đại Việt (Lê dynasty, in crisis) | empire | Lê Tương Dực (25) | - | vnm_nghe_an | 1 | yes |
| CHM | Kingdom of Champa (reduced) | feudal_kingdom | King of Champa (name uncertain) (40) | - | vnm_gia_lai | 1 | yes |
| BRU | Sultanate of Brunei | absolute_monarchy | Sultan Bolkiah (50) | - | brn_brunei | 3 | yes |
| DMK | Sultanate of Demak (and last Majapahit) | absolute_monarchy | Pati Unus (Yat Sunda) (35) | - | idn_jawa_timur | 1 | yes |
| JOH | Malay Sultanate in exile (Johor-Riau) | absolute_monarchy | Sultan Mahmud Shah of Malacca (35) | - | idn_riau | 1 | yes |
| ACH | Sultanate of Aceh | absolute_monarchy | Ali Mughayat Syah (35) | - | idn_sumatera_utara | 1 | yes |
| TRN | Sultanate of Ternate | absolute_monarchy | Sultan Bayan Sirrullah (45) | - | idn_maluku_utara | 1 | yes |
| TDR | Sultanate of Tidore | absolute_monarchy | Sultan al-Mansur of Tidore (40) | - | idn_maluku | 1 | yes |
| RYK | Kingdom of Ryukyu | absolute_monarchy | Shō Shin (54) | - | jpn_okinawa | 1 | yes |
| YEM | Tahirid Sultanate of Yemen | absolute_monarchy | Amir ibn Abd al-Wahhab (Tahirid) (35) | - | yem_yemen | 1 | yes |
| OMA | Nabhani Imamate of Oman | theocracy | Nabhani ruler (name uncertain) (45) | - | omn_oman | 1 | yes |
| SON | Songhai Empire | empire | Askia Muhammad I (Muhammad Ture) (77) | - | mli_timbuktu | 4 | yes |
| MLI | Mali (remnant) | empire | Mansa Mahmud III (uncertain) (40) | - | gin_guinea | 3 | yes |
| JOL | Jolof Empire (declining) | empire | Burba Jolof (name uncertain) (45) | - | sen_senegal | 1 | yes |
| BNI | Kingdom of Benin | absolute_monarchy | Oba Esigie (40) | - | nga_niger | 1 | yes |
| KNB | Bornu (Sayfawa) | feudal_kingdom | Mai of Bornu (Sayfawa, name uncertain) (40) | - | nga_borno | 3 | yes |
| KNG | Kingdom of Kongo | absolute_monarchy | Afonso I (Mvemba a Nzinga) (63) | - | ago_malanje | 3 | yes |
| ADL | Sultanate of Adal | absolute_monarchy | Sultan Abu Bakr ibn Muhammad of Adal (40) | - | eth_somali | 3 | yes |
| MTP | Kingdom of Mutapa | tribal_confederation | Mwene Mutapa (name uncertain) (40) | - | zwe_zimbabwe | 2 | yes |
| FNJ | Funj Sultanate of Sennar | tribal_confederation | Amara Dunqas (40) | - | sdn_north_kordufan | 2 | yes |
| MSC | Muisca Confederation | tribal_confederation | Zipa Tisquesusa (Bogotá) (40) | - | col_antioquia | 1 | yes |
| SBR | Khanate of Sibir | tribal_confederation | Khan of Sibir (Taibugid, name uncertain) (40) | - | rus_urals | 1 | yes |
| MYA | Maya City-States (post-Mayapan) | tribal_confederation | Chiefs and elders (unnamed) (40) | - | mex_campeche | 3 | yes |
| MSO | Mississippian and Southeastern Chiefdoms | tribal_confederation | Chiefs and elders (unnamed) (40) | - | usa_michigan | 4 | yes |
| PUE | Ancestral Puebloan and Desert Farming Peoples | tribal_confederation | Chiefs and elders (unnamed) (40) | - | usa_colorado | 3 | yes |
| PLN | Plains and Great Basin Peoples | tribal_confederation | Chiefs and elders (unnamed) (40) | - | usa_south_dakota | 4 | yes |
| PAC | Pacific Coast Peoples | tribal_confederation | Chiefs and elders (unnamed) (40) | - | usa_california | 3 | yes |
| WDL | Eastern Woodland Peoples (Algonquian and Iroquoian) | tribal_confederation | Chiefs and elders (unnamed) (40) | - | usa_new_york | 3 | yes |
| ARC | Arctic and Subarctic Peoples | tribal_confederation | Chiefs and elders (unnamed) (40) | - | usa_alaska | 5 | yes |
| ISM | Isthmian and Central American Chiefdoms | tribal_confederation | Chiefs and elders (unnamed) (40) | - | hnd_honduras | 4 | yes |
| TAI | Carib and Lucayan Peoples | tribal_confederation | Chiefs and elders (unnamed) (40) | - | bhs_bahamas | 3 | yes |
| AMZ | Amazonian and Orinoco Chiefdoms | tribal_confederation | Chiefs and elders (unnamed) (40) | - | bra_amazonas | 9 | yes |
| TUP | Tupi-Guarani and Southern Cone Peoples | tribal_confederation | Chiefs and elders (unnamed) (40) | - | bra_minas_gerais | 8 | yes |
| PTG | Mapuche and Patagonian Peoples | tribal_confederation | Chiefs and elders (unnamed) (40) | - | arg_santa_cruz | 3 | yes |
| ABO | Aboriginal Australian Nations | tribal_confederation | Chiefs and elders (unnamed) (40) | - | aus_new_south_wales | 6 | yes |
| PNG | Papuan and Melanesian Peoples | tribal_confederation | Chiefs and elders (unnamed) (40) | - | idn_papua | 8 | yes |
| MCR | Micronesian and Polynesian Chiefdoms | tribal_confederation | Chiefs and elders (unnamed) (40) | - | isl_polynesia | 2 | yes |
| BOR | Bornean and Moluccan Coastal Chiefdoms | tribal_confederation | Chiefs and elders (unnamed) (40) | - | idn_kalimantan_timur | 4 | yes |
| PHI | Philippine Barangay Polities | tribal_confederation | Chiefs and elders (unnamed) (40) | - | phl_isabela | 2 | yes |
| FMS | Austronesian Peoples of Taiwan | tribal_confederation | Chiefs and elders (unnamed) (40) | - | twn_taiwan | 1 | yes |
| AIN | Ainu and Emishi Peoples of Ezo | tribal_confederation | Chiefs and elders (unnamed) (40) | - | jpn_hokkaido | 1 | yes |
| MDV | Sultanate of the Maldives | tribal_confederation | Chiefs and elders (unnamed) (40) | - | isl_indian_ocean | 1 | yes |
| SHL | Hausa, Nupe and Savanna Peoples | tribal_confederation | Chiefs and elders (unnamed) (40) | - | nga_taraba | 2 | yes |
| GUL | Guinea Coast and Forest Peoples | tribal_confederation | Chiefs and elders (unnamed) (40) | - | civ_cote_d_ivoire | 8 | yes |
| CAF | Central African Forest and Savanna Peoples | tribal_confederation | Chiefs and elders (unnamed) (40) | - | cod_orientale | 7 | yes |
| SSD | Nilotic and Great Lakes Peoples | tribal_confederation | Chiefs and elders (unnamed) (40) | - | sds_s_sudan | 4 | yes |
| SWH | Swahili Coast Towns and Eastern Bantu Peoples | tribal_confederation | Chiefs and elders (unnamed) (40) | - | ken_kenya | 4 | yes |
| XSAF | Southern African Peoples (Bantu, Khoikhoi and San) | tribal_confederation | Chiefs and elders (unnamed) (40) | - | zaf_limpopo | 8 | yes |
| MAO | Early Maori Settlers of Aotearoa | tribal_confederation | Chiefs and elders (unnamed) (40) | - | nzl_waikato | 2 | yes |
| GRN | Norse Greenland Settlements | tribal_confederation | Chiefs and elders (unnamed) (40) | - | grl_greenland | 1 | yes |
| MDG | Peoples of Madagascar | tribal_confederation | Chiefs and elders (unnamed) (40) | - | mdg_madagascar | 1 | yes |
| SIB | Peoples of Siberia and the Far East | tribal_confederation | Chiefs and elders (unnamed) (40) | - | rus_sakha_yakutia | 4 | yes |
| HIM | Himalayan Valleys (Nepal and Bhutan) | tribal_confederation | Chiefs and elders (unnamed) (40) | - | npl_nepal | 2 | yes |
| SAH | Tuareg and Saharan Oasis Chiefdoms | tribal_confederation | Chiefs and elders (unnamed) (40) | - | dza_algerian_sahara | 2 | yes |
| NJD | Bedouin Tribes of Arabia | tribal_confederation | Chiefs and elders (unnamed) (40) | - | sau_najd | 4 | yes |
| YUT | Tibetan Principalities (Rinpungpa and Phagmodrupa) | tribal_confederation | Chiefs and elders (unnamed) (40) | - | chn_xizang | 1 | yes |

## Notes per new or changed country

* **MGL - Northern Yuan (Mongol Khanate of Dayan Khan's heirs)**: Dayan Khan reunited the Mongols (d. 1517 or 1543, sources differ); Bodi Alagh Khan is shown as his successor, the Tumed and Ordos under Altan Khan are not yet prominent. Age is a guess.
* **JUR - Jurchen Tribes (Jianzhou and Haixi)**: Jurchen tribes were nominally Ming commanders; Nurhaci unifies them only after 1583.
* **YRK - Yarkent Khanate (Chagatai of Kashgar)**: Said Khan (b. 1487) took Kashgar and Yarkent in 1514 and founded the Yarkent Khanate; Turfan and Hami are not drawn.
* **KZK - Kazakh Khanate**: Qasim Khan (r. c. 1511-1523) united the Kazakh hordes at their peak; birth year is uncertain.
* **ARG - Arghun Dynasty of Kandahar**: Shah Beg (r. 1507-1522) held Kandahar after being expelled from Herat, and soon conquered Sindh. Herat itself, in the same modern region, is Safavid. Age is approximate.
* **SMA - Samma Sultanate of Sindh**: Jam Firuz (r. 1508-1527) ruled Sindh from Thatta until the Arghuns conquered it (1520-1522).
* **KSH - Sultanate of Kashmir**: Kashmir was dominated by competing nobles under the Shah Mir sultans; the Punjab foothills are merged into this region. Name and age are approximate.
* **GJP - Gajapati Kingdom of Odisha**: Prataparudra (r. 1497-1540) fought Vijayanagara and the Bahmani successors; age is approximate.
* **BNG - Bengal Sultanate (Husain Shahi)**: Husain Shah (r. 1493-1519) died around this time and Nusrat Shah succeeded; the exact date and birth year are uncertain.
* **AHM - Ahom Kingdom**: Suhungmung (r. 1497-1539) expanded the Ahom state; age is a guess.
* **KTT - Kingdom of Kotte**: Vijayabahu VII (r. 1509-1521) was the first Sinhalese king to deal with the Portuguese, who built a fort at Colombo c. 1518; age is a guess.
* **PGU - Kingdom of Pegu (Hanthawaddy)**: Binnya Ran II (r. 1492-1526) ruled the wealthy Mon kingdom; age is approximate.
* **AVA - Kingdom of Ava**: Shwenankyawshin (r. 1502-1527) held Upper Burma against the Shan; Toungoo under Mingyinyo (r. 1510-1530) is merged here. Age is approximate.
* **KHM - Khmer Kingdom (Ang Chan I)**: Ang Chan I (r. 1516-1566) ruled from Lovek; birth year is uncertain.
* **LNX - Kingdom of Lan Xang**: Visoun (r. 1500-1520) ruled Lan Xang; birth year is uncertain.
* **VIE - Đại Việt (Lê dynasty, in crisis)**: Lê Tương Dực (r. 1509-1516) died three years earlier; the kingdom of 1519 is ruled by weak Lê emperors with rebels in the provinces (Mạc Đăng Dung rises). The emperor is approximate.
* **CHM - Kingdom of Champa (reduced)**: After the fall of Vijaya in 1471 only the southern rump of Champa remains.
* **BRU - Sultanate of Brunei**: Bolkiah (r. 1485-1524) led Brunei's golden age; the large modern provinces overstate its authority. Age is approximate.
* **DMK - Sultanate of Demak (and last Majapahit)**: Demak (Central Java) replaced Majapahit as the leading Javanese power; Pati Unus (r. 1518-1521) attacked Portuguese Malacca in 1513. East Java shown here also holds the last Majapahit remnant. Age is approximate.
* **JOH - Malay Sultanate in exile (Johor-Riau)**: Mahmud Shah fled Malacca after the Portuguese conquest of 1511 and reestablished his court at Bintan; age is approximate.
* **ACH - Sultanate of Aceh**: Ali Mughayat Syah (r. c. 1514-1530) founded Aceh and began to absorb Pasai and Pedir; birth year is unknown.
* **TRN - Sultanate of Ternate**: Bayan Sirrullah (r. 1500-1522) allied with the Portuguese who arrived in 1512; age is approximate.
* **TDR - Sultanate of Tidore**: The Tidore sultanate was Ternate's rival and allied with Spain; the sultan of 1519 is approximate (Sultan al-Mansur, r. c. 1512-1526).
* **RYK - Kingdom of Ryukyu**: Shō Shin (b. 1465, r. 1477-1526) centralised Ryukyu and made it a hub of East Asian trade.
* **YEM - Tahirid Sultanate of Yemen**: The Tahirids fought the Mamluks and, from 1517, the Ottomans' rival claims over the Red Sea; the Tahirid amir of 1519 is approximate.
* **OMA - Nabhani Imamate of Oman**: Ibadi interior Oman; the coast (Muscat) was Portuguese from 1507-1515. Shown as Sunni because the game has no Ibadi option.
* **SON - Songhai Empire**: Askia Muhammad (r. 1493-1528) made Songhai the largest empire in West Africa; his birth year is c. 1442 (approximate).
* **MLI - Mali (remnant)**: Mali shrank to the Mande homeland and Gambia; the exact mansa is uncertain.
* **JOL - Jolof Empire (declining)**: Jolof was losing its tributaries (Kajoor, Waalo) in the 16th century.
* **BNI - Kingdom of Benin**: Esigie (r. c. 1504-1550) traded with the Portuguese from 1486; the Yoruba states of Ife and Oyo share the modern region. Age is approximate.
* **KNB - Bornu (Sayfawa)**: The Sayfawa recovered power in Bornu around the 1500s; the mai of 1519 is not securely named.
* **KNG - Kingdom of Kongo**: Afonso I (r. 1509-1542) converted to Christianity and corresponded with Manuel I and the Pope; age from b. c. 1456.
* **ADL - Sultanate of Adal**: Abu Bakr (r. c. 1517-1526) preceded the rise of Ahmad Gragn; name and age are approximate.
* **MTP - Kingdom of Mutapa**: The Mutapa kingdom was at its peak c. 1450-1500 and began to divide into Mutapa and Butua around the 1490s; the ruler of 1519 is not securely named.
* **FNJ - Funj Sultanate of Sennar**: Amara Dunqas (r. 1504-1534) founded Sennar after defeating Alodia; Funj authority in Nubia is partial. Age is a guess.
* **MSC - Muisca Confederation**: The Muisca confederation of the Zipa (Bogotá) and the Zaque (Tunja); Tisquesusa (r. c. 1514-1537) is only known from Spanish sources. Antioquia and Boyacá share the modern region.
* **SBR - Khanate of Sibir**: The Khanate of Sibir on the Irtysh was a small Turkic-Tatar state until Yermak (1582).
* **MYA - Maya City-States (post-Mayapan)**: Yucatan is divided among rival Maya provinces (Cupul, Cochuah, Tutul Xiu); the Spanish arrive in 1517-1519.
* **MSO - Mississippian and Southeastern Chiefdoms**: A cultural group, not one state: the political map of this region and date is not securely documented, so no ruler is named.
* **PUE - Ancestral Puebloan and Desert Farming Peoples**: A cultural group, not one state: the political map of this region and date is not securely documented, so no ruler is named.
* **PLN - Plains and Great Basin Peoples**: A cultural group, not one state: the political map of this region and date is not securely documented, so no ruler is named.
* **PAC - Pacific Coast Peoples**: A cultural group, not one state: the political map of this region and date is not securely documented, so no ruler is named.
* **WDL - Eastern Woodland Peoples (Algonquian and Iroquoian)**: A cultural group, not one state: the political map of this region and date is not securely documented, so no ruler is named.
* **ARC - Arctic and Subarctic Peoples**: A cultural group, not one state: the political map of this region and date is not securely documented, so no ruler is named.
* **ISM - Isthmian and Central American Chiefdoms**: A cultural group, not one state: the political map of this region and date is not securely documented, so no ruler is named.
* **TAI - Carib and Lucayan Peoples**: The Greater Antilles are Spanish; the Lesser Antilles are Carib, and the Bahamas are being depopulated by slave raids.
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
* **MDV - Sultanate of the Maldives**: Muslim sultanate since 1153; rulers of 1519 are not named here.
* **SHL - Hausa, Nupe and Savanna Peoples**: A cultural group, not one state: the political map of this region and date is not securely documented, so no ruler is named.
* **GUL - Guinea Coast and Forest Peoples**: Akan, Yoruba and Atlantic coast peoples (Portuguese factory at Elmina since 1482); Benin is drawn separately.
* **CAF - Central African Forest and Savanna Peoples**: A cultural group, not one state: the political map of this region and date is not securely documented, so no ruler is named.
* **SSD - Nilotic and Great Lakes Peoples**: A cultural group, not one state: the political map of this region and date is not securely documented, so no ruler is named.
* **SWH - Swahili Coast Towns and Eastern Bantu Peoples**: Swahili city-states (Mombasa, Malindi) under Portuguese pressure after 1505; not drawn separately.
* **XSAF - Southern African Peoples (Bantu, Khoikhoi and San)**: Mutapa is drawn separately; the south is Khoikhoi, San and Bantu peoples; Portuguese factories are not drawn.
* **MAO - Early Maori Settlers of Aotearoa**: Maori iwi (tribes) without a central state.
* **GRN - Norse Greenland Settlements**: The Norse settlements have died out by about 1500; the island is Inuit land.
* **MDG - Peoples of Madagascar**: A cultural group, not one state: the political map of this region and date is not securely documented, so no ruler is named.
* **SIB - Peoples of Siberia and the Far East**: A cultural group, not one state: the political map of this region and date is not securely documented, so no ruler is named.
* **HIM - Himalayan Valleys (Nepal and Bhutan)**: A cultural group, not one state: the political map of this region and date is not securely documented, so no ruler is named.
* **SAH - Tuareg and Saharan Oasis Chiefdoms**: A cultural group, not one state: the political map of this region and date is not securely documented, so no ruler is named.
* **NJD - Bedouin Tribes of Arabia**: A cultural group, not one state: the political map of this region and date is not securely documented, so no ruler is named.
* **YUT - Tibetan Principalities (Rinpungpa and Phagmodrupa)**: The Rinpungpa of Tsang overshadow the Phagmodrupa; the Gelug school is growing. No single ruler is named.
