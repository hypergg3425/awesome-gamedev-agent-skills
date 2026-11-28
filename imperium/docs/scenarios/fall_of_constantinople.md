# Scenario: Fall of Constantinople (`fall_of_constantinople`)

Status: v2.0 reconstruction by workstream B1. Everything marked `approximate` in `data/scenarios/fall_of_constantinople.json` is a best-effort reconstruction. Population, treasury and army sizes are **gameplay estimates** produced by `ScenarioLoader` (they are not documented statistics).

## Start date
* 1453-04 (siege begins 6 April; city falls 29 May). Turns are three months long; ages are computed for the start date (see `tests/t_scenarios_v2.gd`, which checks 29 ruler ages against birth years).

## What changed in v2.0
* Countries: 37 -> 136 (all 410 provinces now have a named owner; 259 provinces were previously generic `<Region> Peoples` filler).
* 99 new political entities, of which 45 are `native: true` named cultural groups where no state can be drawn.
* Scenario-specific province names layer (`province_names`): 87 provinces; geo layer notes: 2.
* Claims: 36 entries for 29 countries; alliances/vassals/wars were reviewed against the sources below.

## Sources
### Main historical sources
* Byzantium, the Ottomans and the Balkans: Steven Runciman, The Fall of Constantinople 1453 (1965); Doukas and Sphrantzes (primary chronicles); Wikipedia regnal lists (CC BY-SA 4.0).
* Timurids, Kara Koyunlu, Aq Qoyunlu, Uzbeks, Moghulistan, Great Horde, Kazan: Bosworth, The New Islamic Dynasties (1996); Cambridge History of Iran vol. 6 (1986).
* Ming, Oirats, Joseon, Muromachi, Ryukyu: Cambridge History of China vol. 7 (1988); Totman (2005); Wikipedia lists of rulers.
* India and Southeast Asia: Thapar (2002); Coedès (1968); Wikipedia lists of Bahmani, Vijayanagara, Bengal, Ayutthaya, Ava, Hanthawaddy, Malacca rulers.
* Africa and the Americas: UNESCO General History of Africa vols. 4-5; Zara Yaqob of Ethiopia (Taddesse Tamrat, Church and State in Ethiopia, 1972); Cambridge History of the Native Peoples of the Americas (1996).

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
| OTT | Ottoman Sultanate | empire | Mehmed II (21) | Bayezid | tur_eastern_thrace | 9 | yes |
| BYZ | Byzantine Empire | empire | Constantine XI Palaiologos (48) | - | tur_constantinople | 2 | no |
| KAR | Beylik of Karaman | feudal_kingdom | İbrahim Bey of Karaman (45) | - | tur_central_anatolia | 2 | yes |
| AQQ | Aq Qoyunlu Confederation | tribal_confederation | Uzun Hasan (30) | - | tur_upper_mesopotamia | 2 | yes |
| KQY | Kara Koyunlu Sultanate | military_government | Jahan Shah (56) | - | irn_azerbaijan_persia | 9 | yes |
| MAM | Mamluk Sultanate | military_government | al-Ashraf Inal (72) | - | egy_cairo | 14 | yes |
| GEO | Kingdom of Georgia | feudal_kingdom | George VIII of Georgia (36) | - | geo_georgia | 1 | yes |
| TRE | Empire of Trebizond | empire | John IV Megas Komnenos (50) | - | tur_pontus | 1 | yes |
| SRB | Serbian Despotate | feudal_kingdom | Đurađ Branković (76) | - | srb_serbia | 2 | yes |
| ALB | League of Lezhë (Skanderbeg's Albania) | tribal_confederation | Skanderbeg (Gjergj Kastrioti) (48) | - | alb_albania | 1 | yes |
| WAL | Principality of Wallachia | feudal_kingdom | Vladislav II of Wallachia (38) | - | rou_wallachia | 1 | yes |
| MOL | Principality of Moldavia | feudal_kingdom | Alexăndrel of Moldavia (25) | - | rou_moldavia | 2 | yes |
| HUN | Kingdom of Hungary | feudal_kingdom | John Hunyadi (Governor for Ladislaus V) (46) | Ladislaus the Posthumous | hun_transdanubia | 5 | yes |
| VEN | Republic of Venice | merchant_republic | Doge Francesco Foscari (80) | - | ita_veneto | 3 | yes |
| GEN | Republic of Genoa | merchant_republic | Doge Pietro di Campofregoso (60) | - | ita_liguria | 2 | yes |
| PAP | Papal States | theocracy | Nicholas V (56) | - | ita_lazio | 2 | yes |
| NAP | Kingdom of Naples and Sicily | feudal_kingdom | Alfonso V the Magnanimous (57) | Ferrante of Naples | ita_campania | 5 | yes |
| ARA | Crown of Aragon (Queen-Lieutenant Maria) | feudal_kingdom | Maria of Castile (lieutenant for Alfonso V) (52) | - | esp_catalonia | 5 | yes |
| MIL | Duchy of Milan (Sforza) | feudal_kingdom | Francesco Sforza (52) | - | ita_lombardy | 1 | yes |
| FLO | Republic of Florence (Medici) | republic | Cosimo de' Medici (64) | - | ita_tuscany | 1 | yes |
| POL | Kingdom of Poland | feudal_kingdom | Casimir IV Jagiellon (26) | - | pol_lesser_poland | 6 | yes |
| LIT | Grand Duchy of Lithuania | feudal_kingdom | Casimir IV (as Grand Duke) (26) | - | ltu_lithuania | 4 | yes |
| TEU | Teutonic Order | theocracy | Ludwig von Erlichshausen (43) | - | pol_pomerania | 4 | yes |
| MOS | Grand Principality of Moscow | feudal_kingdom | Vasily II the Blind (38) | - | rus_moscow | 2 | yes |
| CRI | Crimean Khanate | tribal_confederation | Hacı I Giray (56) | - | ukr_pontic_steppe | 2 | yes |
| FRA | Kingdom of France | feudal_kingdom | Charles VII the Victorious (50) | Louis the Dauphin | fra_ile_de_france | 8 | no |
| ANJ | House of Anjou (Provence and Lorraine) | feudal_kingdom | René of Anjou (44) | - | fra_provence | 2 | yes |
| BUR | Duchy of Burgundy | feudal_kingdom | Philip the Good (57) | - | fra_burgundy | 7 | yes |
| ENG | Kingdom of England | feudal_kingdom | Henry VI (31) | - | gbr_home_counties | 8 | no |
| SCO | Kingdom of Scotland | feudal_kingdom | James II Stewart (23) | - | gbr_lowland_scotland | 2 | yes |
| HRE | Holy Roman Empire | empire | Frederick III of Habsburg (38) | - | aut_austria | 16 | yes |
| BOH | Kingdom of Bohemia (Regency of George of Poděbrady) | feudal_kingdom | George of Poděbrady (33) | - | cze_bohemia | 3 | yes |
| CAS | Crown of Castile | feudal_kingdom | John II of Castile (48) | - | esp_old_castile | 5 | yes |
| GRA | Emirate of Granada | absolute_monarchy | Nasrid Emir of Granada (40) | - | esp_andalusia | 1 | yes |
| POR | Kingdom of Portugal | feudal_kingdom | Afonso V (21) | - | prt_south_portugal | 2 | yes |
| DEN | Kingdom of Denmark and Norway | feudal_kingdom | Christian I of Oldenburg (27) | - | dnk_zealand | 6 | yes |
| SWE | Kingdom of Sweden | feudal_kingdom | Charles VIII Knutsson (45) | - | swe_svealand | 4 | yes |
| NOV | Novgorod Republic | merchant_republic | Posadnik and the veche (council) (50) | - | rus_novgorod | 3 | yes |
| GAE | Gaelic Irish Lordships | tribal_confederation | Gaelic kings and lords (unnamed) (45) | - | irl_munster | 3 | yes |
| BRI | Duchy of Brittany | feudal_kingdom | Peter II of Brittany (35) | - | fra_brittany | 1 | no |
| SAV | Duchy of Savoy | feudal_kingdom | Louis I of Savoy (51) | - | ita_piedmont | 1 | yes |
| BOS | Kingdom of Bosnia | feudal_kingdom | Stephen Thomas of Bosnia (41) | - | bih_bosnia_and_herz | 1 | yes |
| ZET | Lordship of Zeta (Crnojević) | feudal_kingdom | Stefan Crnojević (40) | - | mne_montenegro | 1 | yes |
| CYP | Kingdom of Cyprus (Lusignan) | feudal_kingdom | John II of Cyprus (35) | Charlotte of Lusignan | cyp_cyprus | 1 | yes |
| TIM | Timurid Sultanate of Herat | feudal_kingdom | Abu'l-Qasim Babur Mirza (31) | - | irn_khorasan | 7 | yes |
| TSM | Timurid Realm of Samarkand | feudal_kingdom | Abu Sa'id Mirza (29) | - | uzb_bukhoro | 2 | yes |
| UZB | Uzbek Ulus of Abu'l-Khayr | tribal_confederation | Abu'l-Khayr Khan (41) | - | kaz_qaraghandy | 3 | yes |
| MGH | Moghulistan | tribal_confederation | Esen Buqa II (45) | - | chn_xinjiang | 3 | yes |
| GHD | Great Horde | tribal_confederation | Küchük Muhammad (45) | - | rus_don | 2 | yes |
| KZN | Khanate of Kazan | tribal_confederation | Mahmud Khan of Kazan (48) | - | rus_volga | 1 | yes |
| RAS | Rasulid Sultanate (late) | absolute_monarchy | Rasulid sultan (name uncertain) (35) | - | yem_yemen | 1 | yes |
| OMA | Nabhani Imamate of Oman | theocracy | Nabhani ruler (name uncertain) (45) | - | omn_oman | 2 | yes |
| HAF | Hafsid Sultanate | absolute_monarchy | Abu Amr Uthman (34) | - | tun_tunisia | 3 | yes |
| ZAY | Zayyanid Kingdom of Tlemcen | absolute_monarchy | Abu Abd Allah Muhammad IV al-Mutawakkil (40) | - | dza_oran | 2 | yes |
| MRN | Marinid-Wattasid Morocco | absolute_monarchy | Abd al-Haqq II (34) | - | mar_fez | 2 | yes |
| MLI | Mali Empire (declining) | empire | Mansa of Mali (name uncertain) (45) | - | gin_guinea | 4 | yes |
| SON | Songhai Kingdom of Gao | feudal_kingdom | Sonni ruler of Gao (name uncertain) (40) | - | mli_timbuktu | 1 | yes |
| JOL | Jolof Empire | empire | Burba Jolof (name uncertain) (45) | - | sen_senegal | 1 | yes |
| BNI | Kingdom of Benin | absolute_monarchy | Oba Ewuare the Great (45) | - | nga_niger | 1 | yes |
| KNB | Kanem-Bornu | feudal_kingdom | Mai of Bornu (Sayfawa, name uncertain) (40) | - | nga_borno | 3 | yes |
| ETH | Ethiopian Empire (Solomonic) | empire | Zara Yaqob (54) | - | eth_oromiya | 2 | yes |
| ADL | Sultanate of Adal | absolute_monarchy | Sultan of Adal (Walasma, name uncertain) (40) | - | eth_somali | 3 | yes |
| KLW | Sultanate of Kilwa | absolute_monarchy | Sultan of Kilwa (Mahdali dynasty, name uncertain) (40) | - | tza_morogoro | 1 | yes |
| MTP | Kingdom of Mutapa | tribal_confederation | Mwene Mutapa Matope (40) | - | zwe_zimbabwe | 2 | yes |
| KNG | Kingdom of Kongo | absolute_monarchy | Manikongo (Lukeni dynasty, name uncertain) (45) | - | ago_malanje | 3 | yes |
| MNG | Ming China (Jingtai Emperor) | empire | Jingtai Emperor (Zhu Qiyu) (25) | - | chn_jilin | 5 | yes |
| OIR | Oirat Khanate of Esen Taishi | tribal_confederation | Esen Taishi (46) | - | mng_govi_altay | 4 | yes |
| JUR | Jurchen Tribes (Jianzhou and Haixi) | tribal_confederation | Jurchen chiefs under Ming titles (unnamed) (40) | - | chn_heilongjiang | 2 | yes |
| PHG | Phagmodrupa Rule of Tibet | theocracy | Phagmodrupa ruler (name uncertain) (40) | - | chn_xizang | 1 | yes |
| KOR | Joseon Korea | absolute_monarchy | Danjong of Joseon (11) | - | kor_gangwon | 3 | yes |
| ASH | Ashikaga Shogunate (Muromachi) | feudal_kingdom | Ashikaga Yoshimasa (17) | - | jpn_nagano | 1 | yes |
| KNT | Kanto Kubo and Tohoku Lords | feudal_kingdom | Ashikaga Shigeuji (Koga Kubo) (19) | - | jpn_iwate | 1 | yes |
| RYK | Kingdom of Ryukyu | absolute_monarchy | Shō Kinpuku (55) | - | jpn_okinawa | 1 | yes |
| VIE | Đại Việt (Later Lê dynasty) | empire | Lê Nhân Tông (12) | - | vnm_nghe_an | 1 | yes |
| CHM | Kingdom of Champa | feudal_kingdom | King of Champa (name uncertain) (35) | - | vnm_gia_lai | 1 | yes |
| AYU | Ayutthaya Kingdom | absolute_monarchy | Borommatrailokanat (Trailok) (22) | - | tha_chiang_mai | 2 | yes |
| KHM | Khmer Kingdom (Longvek period) | absolute_monarchy | Ponhea Yat (40) | - | khm_cambodia | 1 | yes |
| LNX | Kingdom of Lan Xang | absolute_monarchy | Chakkaphat Phaen Phaeo (40) | - | lao_laos | 1 | yes |
| AVA | Kingdom of Ava | absolute_monarchy | Narapati I of Ava (35) | - | mmr_shan | 1 | yes |
| HNT | Hanthawaddy Kingdom (Shin Sawbu) | absolute_monarchy | Queen Shin Sawbu (59) | - | mmr_tanintharyi | 1 | yes |
| MLK | Sultanate of Malacca | absolute_monarchy | Muzaffar Shah of Malacca (40) | - | mys_pahang | 1 | yes |
| BRU | Sultanate of Brunei | absolute_monarchy | Sultan Sulaiman of Brunei (45) | - | brn_brunei | 3 | yes |
| MJP | Majapahit (late) | empire | Rajasawardhana (Sang Sinagara) (40) | - | idn_jawa_timur | 1 | yes |
| SPS | Samudera Pasai (declining) | absolute_monarchy | Sultan of Pasai (name uncertain) (40) | - | idn_sumatera_utara | 1 | yes |
| LOD | Delhi Sultanate (Lodi dynasty) | feudal_kingdom | Bahlul Khan Lodi (33) | - | ind_madhya_pradesh | 2 | yes |
| MWR | Kingdom of Mewar | feudal_kingdom | Rana Kumbha (36) | - | ind_rajasthan | 1 | yes |
| BHM | Bahmani Sultanate | feudal_kingdom | Ala ud-Din Ahmad Shah II (40) | - | ind_maharashtra | 1 | yes |
| VIJ | Vijayanagara Empire | empire | Mallikarjuna Raya (30) | - | ind_karnataka | 2 | yes |
| GJP | Gajapati Kingdom of Odisha | feudal_kingdom | Kapilendra Deva (40) | - | ind_odisha | 1 | yes |
| BNG | Bengal Sultanate (Ilyas Shahi) | feudal_kingdom | Nasir ud-Din Mahmud Shah I (40) | - | ind_bihar | 2 | yes |
| KSH | Sultanate of Kashmir | absolute_monarchy | Zain-ul-Abidin (Budshah) (58) | - | ind_ladakh | 1 | yes |
| KTT | Kingdom of Kotte | feudal_kingdom | Parakramabahu VI (69) | - | lka_sri_lanka | 1 | yes |
| AHM | Ahom Kingdom | feudal_kingdom | Susenphaa (40) | - | ind_arunachal_pradesh | 1 | yes |
| AZT | Aztec Triple Alliance | empire | Moctezuma I (Huehuemoteuhzoma) (55) | - | mex_jalisco | 1 | yes |
| INC | Inca State (Cusco) | empire | Pachacuti Inca Yupanqui (35) | - | per_madre_de_dios | 1 | yes |
| CHI | Chimú Kingdom (Chimor) | absolute_monarchy | Chimú king (name not securely attested) (40) | - | per_loreto | 1 | yes |
| SMA | Samma Sultanate of Sindh | feudal_kingdom | Jam of the Samma dynasty (name uncertain) (40) | - | pak_baluchistan | 1 | yes |
| SAM | Sami and Northern Finnic Peoples | tribal_confederation | Sami elders (unnamed) (40) | - | fin_north_finland | 1 | yes |
| MXT | Mixtec and Zapotec Kingdoms | tribal_confederation | Chiefs and elders (unnamed) (40) | - | mex_oaxaca | 1 | yes |
| MYA | Maya Cities (post-Mayapan Yucatan) | tribal_confederation | Chiefs and elders (unnamed) (40) | - | mex_campeche | 3 | yes |
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
| BOR | Bornean and Moluccan Coastal Chiefdoms | tribal_confederation | Chiefs and elders (unnamed) (40) | - | idn_kalimantan_timur | 6 | yes |
| PHI | Philippine Barangay Polities | tribal_confederation | Chiefs and elders (unnamed) (40) | - | phl_isabela | 2 | yes |
| FMS | Austronesian Peoples of Taiwan | tribal_confederation | Chiefs and elders (unnamed) (40) | - | twn_taiwan | 1 | yes |
| AIN | Ainu and Emishi Peoples of Ezo | tribal_confederation | Chiefs and elders (unnamed) (40) | - | jpn_hokkaido | 1 | yes |
| MDV | Sultanate of the Maldives | tribal_confederation | Chiefs and elders (unnamed) (40) | - | isl_indian_ocean | 1 | yes |
| UNS | Uninhabited islands (placeholder) | tribal_confederation | Chiefs and elders (unnamed) (40) | - | isl_atlantic | 2 | yes |
| SHL | Hausa, Nupe and Savanna Peoples | tribal_confederation | Chiefs and elders (unnamed) (40) | - | nga_taraba | 3 | yes |
| GUL | Guinea Coast and Forest Peoples | tribal_confederation | Chiefs and elders (unnamed) (40) | - | gha_ghana | 9 | yes |
| CAF | Central African Forest and Savanna Peoples | tribal_confederation | Chiefs and elders (unnamed) (40) | - | cod_orientale | 7 | yes |
| SSD | Nilotic and Great Lakes Peoples | tribal_confederation | Chiefs and elders (unnamed) (40) | - | sds_s_sudan | 4 | yes |
| SWH | Swahili Coast Towns and Eastern Bantu Peoples | tribal_confederation | Chiefs and elders (unnamed) (40) | - | ken_kenya | 4 | yes |
| SAF | Southern African Peoples (Bantu, Khoikhoi and San) | tribal_confederation | Chiefs and elders (unnamed) (40) | - | zaf_limpopo | 8 | yes |
| MAO | Early Maori Settlers of Aotearoa | tribal_confederation | Chiefs and elders (unnamed) (40) | - | nzl_waikato | 2 | yes |
| GRN | Norse Greenland Settlements | tribal_confederation | Chiefs and elders (unnamed) (40) | - | grl_greenland | 1 | yes |
| MDG | Peoples of Madagascar | tribal_confederation | Chiefs and elders (unnamed) (40) | - | mdg_madagascar | 1 | yes |
| SIB | Peoples of Siberia and the Far East | tribal_confederation | Chiefs and elders (unnamed) (40) | - | rus_sakha_yakutia | 5 | yes |
| HIM | Himalayan Valleys (Nepal and Bhutan) | tribal_confederation | Chiefs and elders (unnamed) (40) | - | npl_nepal | 2 | yes |
| SAH | Tuareg and Saharan Oasis Chiefdoms | tribal_confederation | Chiefs and elders (unnamed) (40) | - | dza_algerian_sahara | 3 | yes |
| NJD | Bedouin Tribes of Arabia | tribal_confederation | Chiefs and elders (unnamed) (40) | - | sau_najd | 4 | yes |
| NIL | Nubian and Nilotic Peoples | tribal_confederation | Chiefs and elders (unnamed) (40) | - | sdn_northern | 2 | yes |
| PNN | Malay Peninsula and Sumatran Coastal Polities | tribal_confederation | Chiefs and elders (unnamed) (40) | - | idn_riau | 1 | yes |

## Notes per new or changed country

* **NOV - Novgorod Republic**: Governed by the posadnik, the veche and the archbishop; Moscow forces it into submission by the Treaty of Yazhelbitsy in 1456. The ruler shown is an office, not a person.
* **GAE - Gaelic Irish Lordships**: Gaelic lordships outside the Pale, merged into one state; the Anglo-Irish earldoms of Ormond, Desmond and Kildare are part of English Ireland.
* **BRI - Duchy of Brittany**: Peter II (r. 1450-1457) kept Brittany neutral between France and England; age from b. 1418.
* **SAV - Duchy of Savoy**: Louis (r. 1440-1465) ruled Savoy, Piedmont and Aosta; age from b. 1402.
* **BOS - Kingdom of Bosnia**: Stephen Thomas (r. 1443-1461) ruled Bosnia; Herzegovina under Stjepan Vukčić Kosača is merged. Age is approximate.
* **ZET - Lordship of Zeta (Crnojević)**: Stefan Crnojević rose in Upper Zeta in the early 1450s, between Venice, Skanderbeg and Bosnia; age is approximate.
* **CYP - Kingdom of Cyprus (Lusignan)**: John II (r. 1432-1458) paid tribute to the Mamluks since 1426; his heir Charlotte was born in 1444.
* **TIM - Timurid Sultanate of Herat**: Babur Mirza (b. 1422, r. 1449-1457) ruled Khorasan and Herat; Fars and Kerman are held loosely and contested with Kara Koyunlu.
* **TSM - Timurid Realm of Samarkand**: Abu Sa'id (b. 1424) seized Samarkand in 1451 after the murders that followed Ulugh Beg's death; Babur Mirza of Herat is his rival.
* **UZB - Uzbek Ulus of Abu'l-Khayr**: Abu'l-Khayr (r. 1428-1468) led the steppe Uzbeks from Siberia to the Syr Darya; age from b. 1412.
* **MGH - Moghulistan**: Esen Buqa II (r. 1429-1462) held the Tarim Basin and the Ili valley; age is approximate.
* **GHD - Great Horde**: Küchük Muhammad (r. 1435-1459) led the Great Horde on the lower Volga and Don; age is approximate.
* **KZN - Khanate of Kazan**: Founded in 1438-1445 by Ulugh Muhammad; his son Mahmud reigned 1445-1466. Age is approximate.
* **RAS - Rasulid Sultanate (late)**: The Rasulids were declining before the Tahirids took Zabid in the 1450s-1460s; their sultans of this decade are not securely named here.
* **OMA - Nabhani Imamate of Oman**: Ibadi Oman under the Nabhani dynasty; shown as Sunni because the game has no Ibadi option.
* **HAF - Hafsid Sultanate**: Uthman (r. 1435-1488) presided over a long, prosperous Hafsid period; age is approximate.
* **ZAY - Zayyanid Kingdom of Tlemcen**: Ruled 1430-1462; age is approximate.
* **MRN - Marinid-Wattasid Morocco**: Abd al-Haqq II (r. 1421-1465) was a Marinid figurehead under Wattasid viziers; the last Marinid, he is murdered in 1465.
* **MLI - Mali Empire (declining)**: Mali lost Gao and Timbuktu in the 15th century but held the Mande heartland and Gambia; the mansa of 1453 is not securely named.
* **SON - Songhai Kingdom of Gao**: Songhai under the Sonni dynasty was independent of Mali; Tuareg held Timbuktu from 1433 until Sonni Ali takes it in 1468. The ruler of 1453 is not securely named.
* **JOL - Jolof Empire**: The Jolof Empire dominated Senegambia in the 15th century; its rulers are not securely dated.
* **BNI - Kingdom of Benin**: Ewuare (r. c. 1440-1473) rebuilt Benin City and expanded the kingdom; the Yoruba states of Ife and Oyo share the modern region. Age is a guess.
* **KNB - Kanem-Bornu**: The Sayfawa moved to Bornu after the Bulala drove them from Kanem in the 1380s; the mai of 1453 is not securely named.
* **ETH - Ethiopian Empire (Solomonic)**: Zara Yaqob (b. 1399, r. 1434-1468) centralised the church and the state at Debre Berhan.
* **ADL - Sultanate of Adal**: Adal replaced Ifat as the Muslim lowland state; the sultan of 1453 is not securely named.
* **KLW - Sultanate of Kilwa**: Kilwa controlled the gold trade through Sofala; its sultans of this decade are not securely named.
* **MTP - Kingdom of Mutapa**: Founded c. 1430 by Nyatsimba Mutota, who left Great Zimbabwe; Matope (r. c. 1450-1480) expanded it to the sea. Age is a guess.
* **KNG - Kingdom of Kongo**: Founded c. 1390 around Mbanza Kongo; the manikongo of 1453 is not securely named (Nzinga a Nkuwu succeeded c. 1470).
* **MNG - Ming China (Jingtai Emperor)**: Jingtai (b. 1428, r. 1449-1457) held the throne after his half-brother Zhengtong was captured at Tumu; the east coast is not drawn by the modern-geometry regions.
* **OIR - Oirat Khanate of Esen Taishi**: Esen Taishi defeated the Ming at Tumu in 1449 and proclaimed himself khan in 1453; he was killed in 1455. Birth year is approximate.
* **JUR - Jurchen Tribes (Jianzhou and Haixi)**: Jurchen tribes were nominally Ming-appointed commanders; no unified state existed until Nurhaci.
* **PHG - Phagmodrupa Rule of Tibet**: The Phagmodrupa dynasty (1354-1435 supremacy) was weakening against the Rinpungpa; the ruler of 1453 is not securely named.
* **KOR - Joseon Korea**: Danjong (b. 1441) succeeded Munjong in 1452 as a boy; his uncle Grand Prince Suyang (the later Sejo) overthrows his regents in October 1453.
* **ASH - Ashikaga Shogunate (Muromachi)**: Yoshimasa (b. 1436) became shogun in 1449; real power lay with the Hosokawa and Yamana kanrei.
* **KNT - Kanto Kubo and Tohoku Lords**: Shigeuji (b. 1434, Kanto Kubo from 1449) was about to rebel against the Uesugi and the shogunate (Kyotoku disturbance, 1454).
* **RYK - Kingdom of Ryukyu**: Shō Kinpuku (r. 1450-1453) died in 1453; his brother Shō Taikyū succeeded. The kingdom was unified in 1429.
* **VIE - Đại Việt (Later Lê dynasty)**: Nhân Tông (b. 1441, r. 1443-1459) reigned under his mother's regency; he was killed in a coup in 1459.
* **CHM - Kingdom of Champa**: Champa was under mounting pressure from Đại Việt before the fall of Vijaya in 1471; the king of 1453 is not securely named.
* **AYU - Ayutthaya Kingdom**: Trailok (b. 1431, r. 1448-1488) reformed the administration; Lan Na to the north is not drawn.
* **KHM - Khmer Kingdom (Longvek period)**: Ponhea Yat (r. 1432-1463) abandoned Angkor after the Siamese sack of 1431 and moved to the Phnom Penh area. Age is approximate.
* **LNX - Kingdom of Lan Xang**: Chakkaphat (r. 1442-1479) ruled the Lao kingdom of the million elephants; age is approximate.
* **AVA - Kingdom of Ava**: Narapati (r. 1443-1469) ruled Upper Burma; birth year is approximate.
* **HNT - Hanthawaddy Kingdom (Shin Sawbu)**: Shin Sawbu (b. c. 1394, r. 1453-1472) became queen of the Mon kingdom in 1453; the exact month of accession is not fixed.
* **MLK - Sultanate of Malacca**: Muzaffar Shah (r. 1445-1459) held the Strait of Malacca with Ming support; age is approximate.
* **BRU - Sultanate of Brunei**: Sultan Sulaiman (r. c. 1432-1485); the sultanate's authority over north Borneo is exaggerated by the large modern provinces. Age is approximate.
* **MJP - Majapahit (late)**: Rajasawardhana (r. 1451-1453) died in 1453, followed by an interregnum; Majapahit was declining. Age is approximate.
* **SPS - Samudera Pasai (declining)**: Pasai was overshadowed by Malacca; its sultans are not securely named here.
* **LOD - Delhi Sultanate (Lodi dynasty)**: Bahlul (r. 1451-1489) took Delhi from the last Sayyid in 1451; the sultanate is a small shadow of its earlier extent. Birth year is uncertain.
* **MWR - Kingdom of Mewar**: Kumbhakarna (r. 1433-1468) fought Malwa and Gujarat; Gujarat Sultanate under Qutb-ud-Din Ahmad Shah II is merged into the same modern region.
* **BHM - Bahmani Sultanate**: Ahmad II (r. 1436-1458) ruled the Deccan from Bidar; Bidar itself lies in the Karnataka-Andhra region. Age is approximate.
* **VIJ - Vijayanagara Empire**: Mallikarjuna (r. 1446-1465) ruled South India; age is approximate and the Bahmani frontier cuts through the same modern region.
* **GJP - Gajapati Kingdom of Odisha**: Kapilendra (r. 1435-1467) founded the Gajapati dynasty and expanded into Andhra; age is approximate.
* **BNG - Bengal Sultanate (Ilyas Shahi)**: Mahmud Shah (r. 1442-1459) restored the Ilyas Shahi line; Bihar shown here was contested with Jaunpur. Age is approximate.
* **KSH - Sultanate of Kashmir**: Zain-ul-Abidin (r. 1420-1470) is remembered for tolerance and crafts; the Himalayan foothills of the Punjab are merged into the region.
* **KTT - Kingdom of Kotte**: Parakramabahu VI (r. 1412-1467) reunified Sri Lanka (except the Jaffna kingdom); age from b. c. 1384.
* **AHM - Ahom Kingdom**: Susenphaa (r. 1439-1488); age is a guess.
* **AZT - Aztec Triple Alliance**: The Triple Alliance of Tenochtitlan, Texcoco and Tlacopan formed in 1428; Moctezuma I reigned 1440-1469. The Tarascan state shares the same modern region.
* **INC - Inca State (Cusco)**: Pachacuti (r. 1438-1471) began the Inca expansion after repelling the Chanka; dates come from later Spanish chronicles and are uncertain.
* **CHI - Chimú Kingdom (Chimor)**: Chimor lasted until the Inca conquest c. 1470; the modern region also covers Amazonian land.
* **SMA - Samma Sultanate of Sindh**: The Samma dynasty ruled Sindh from Thatta c. 1351-1520; Balochistan tribes are merged in. The ruler of 1453 is not securely named.
* **SAM - Sami and Northern Finnic Peoples**: Reindeer-herding peoples of Lapland; no state.
* **MXT - Mixtec and Zapotec Kingdoms**: A cultural group, not one state: the political map of this region and date is not securely documented, so no ruler is named.
* **MYA - Maya Cities (post-Mayapan Yucatan)**: Mayapan collapsed c. 1440-1450 into rival provinces; no state is drawn.
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
* **MDV - Sultanate of the Maldives**: Muslim sultanate since 1153.
* **UNS - Uninhabited islands (placeholder)**: A cultural group, not one state: the political map of this region and date is not securely documented, so no ruler is named.
* **SHL - Hausa, Nupe and Savanna Peoples**: A cultural group, not one state: the political map of this region and date is not securely documented, so no ruler is named.
* **GUL - Guinea Coast and Forest Peoples**: Akan (Bono, Begho), Yoruba and Atlantic-coast peoples; Benin is drawn separately.
* **CAF - Central African Forest and Savanna Peoples**: A cultural group, not one state: the political map of this region and date is not securely documented, so no ruler is named.
* **SSD - Nilotic and Great Lakes Peoples**: A cultural group, not one state: the political map of this region and date is not securely documented, so no ruler is named.
* **SWH - Swahili Coast Towns and Eastern Bantu Peoples**: Swahili city-states (Mombasa, Malindi) are not drawn separately; Kilwa is.
* **SAF - Southern African Peoples (Bantu, Khoikhoi and San)**: A cultural group, not one state: the political map of this region and date is not securely documented, so no ruler is named.
* **MAO - Early Maori Settlers of Aotearoa**: Maori iwi (tribes) without a central state.
* **GRN - Norse Greenland Settlements**: The Eastern Settlement is dying out in the mid-15th century.
* **MDG - Peoples of Madagascar**: A cultural group, not one state: the political map of this region and date is not securely documented, so no ruler is named.
* **SIB - Peoples of Siberia and the Far East**: A cultural group, not one state: the political map of this region and date is not securely documented, so no ruler is named.
* **HIM - Himalayan Valleys (Nepal and Bhutan)**: A cultural group, not one state: the political map of this region and date is not securely documented, so no ruler is named.
* **SAH - Tuareg and Saharan Oasis Chiefdoms**: A cultural group, not one state: the political map of this region and date is not securely documented, so no ruler is named.
* **NJD - Bedouin Tribes of Arabia**: A cultural group, not one state: the political map of this region and date is not securely documented, so no ruler is named.
* **NIL - Nubian and Nilotic Peoples**: Dotawo remnants and Arab Juhayna tribes; Alodia falls to the Funj only in 1504.
* **PNN - Malay Peninsula and Sumatran Coastal Polities**: A cultural group, not one state: the political map of this region and date is not securely documented, so no ruler is named.
