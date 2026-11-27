# Scenario: Industrial Era (`industrial_era`)

Status: v2.0 reconstruction by workstream B1. Everything marked `approximate` in `data/scenarios/industrial_era.json` is a best-effort reconstruction. Population, treasury and army sizes are **gameplay estimates** produced by `ScenarioLoader` (they are not documented statistics).

## Start date
* 1871-01 (the German Empire is proclaimed on 18 January 1871; Paris capitulates on 28 January). Turns are three months long; ages are computed for the start date (see `tests/t_scenarios_v2.gd`, which checks 29 ruler ages against birth years).

## What changed in v2.0
* Countries: 60 -> 88 (all 410 provinces now have a named owner; 51 provinces were previously generic `<Region> Peoples` filler).
* 28 new political entities, of which 24 are `native: true` named cultural groups where no state can be drawn.
* Scenario-specific province names layer (`province_names`): 51 provinces; geo layer notes: 0.
* Claims: 43 entries for 22 countries; alliances/vassals/wars were reviewed against the sources below.

## Sources
### Main historical sources
* European rulers and the Franco-Prussian War: Michael Howard, The Franco-Prussian War (1961); standard regnal lists (Wikipedia, CC BY-SA 4.0).
* Ottoman, Qing, Meiji and South/Southeast Asian states: Cambridge History of China vol. 10-11; Totman (2005); Thapar (2002).
* Africa: UNESCO General History of Africa vol. 6 (1989); Roland Oliver, The African Experience (1991); Wikipedia lists of rulers (Asante, Dahomey, Sokoto, Bornu, Wadai, Buganda, Yeke, Ndebele).

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
| GBR | United Kingdom of Great Britain and Ireland | constitutional_monarchy | Victoria (PM Gladstone) (51) | Albert Edward, Prince of Wales | gbr_home_counties | 49 | yes |
| FRA | French Republic (National Defence) | republic | Louis-Jules Trochu (Government of National Defence) (55) | - | fra_ile_de_france | 26 | yes |
| AUH | Austria-Hungary | constitutional_monarchy | Franz Joseph I (40) | Rudolf | aut_austria | 14 | yes |
| RUS | Russian Empire | absolute_monarchy | Alexander II (52) | Alexander | rus_novgorod | 35 | yes |
| OTT | Ottoman Empire | absolute_monarchy | Abdulaziz (40) | - | tur_constantinople | 36 | yes |
| ITA | Kingdom of Italy | constitutional_monarchy | Victor Emmanuel II (50) | Umberto | ita_lazio | 12 | yes |
| SPA | Kingdom of Spain | constitutional_monarchy | Amadeo I (25) | - | esp_new_castile | 17 | yes |
| POR | Kingdom of Portugal | constitutional_monarchy | Luís I (32) | - | prt_south_portugal | 8 | yes |
| NLD | Kingdom of the Netherlands | constitutional_monarchy | William III (53) | - | nld_holland | 14 | yes |
| BEL | Kingdom of Belgium | constitutional_monarchy | Leopold II (35) | - | bel_flanders | 2 | yes |
| SWN | United Kingdoms of Sweden and Norway | constitutional_monarchy | Charles XV (44) | Oscar | swe_svealand | 6 | yes |
| DEN | Kingdom of Denmark | constitutional_monarchy | Christian IX (52) | - | dnk_zealand | 4 | yes |
| SWI | Swiss Confederation | republic | Federal Council (Bundesrat) (50) | - | che_switzerland | 1 | yes |
| GRE | Kingdom of Greece | constitutional_monarchy | George I (25) | - | grc_central_greece | 3 | yes |
| SRB | Principality of Serbia | constitutional_monarchy | Prince Milan Obrenović IV (16) | - | srb_serbia | 1 | yes |
| ROU | Principality of Romania | constitutional_monarchy | Carol I (31) | - | rou_wallachia | 2 | yes |
| MNE | Principality of Montenegro | absolute_monarchy | Nikola I (29) | - | mne_montenegro | 1 | yes |
| EGY | Khedivate of Egypt | absolute_monarchy | Isma'il Pasha (40) | - | egy_cairo | 8 | yes |
| TUN | Beylik of Tunis | absolute_monarchy | Muhammad as-Sadiq Bey (57) | - | tun_tunisia | 1 | yes |
| MAR | Sultanate of Morocco | absolute_monarchy | Muhammad IV (65) | - | mar_fez | 2 | yes |
| ETH | Ethiopian Empire | absolute_monarchy | Kassa Mercha (Yohannes IV) (33) | - | eth_oromiya | 1 | yes |
| ZAN | Sultanate of Zanzibar | absolute_monarchy | Barghash bin Said (34) | - | tza_morogoro | 2 | yes |
| MAD | Kingdom of Madagascar (Merina) | absolute_monarchy | Ranavalona II (41) | - | mdg_madagascar | 1 | yes |
| BOR | South African Republic (Transvaal) | republic | Marthinus Wessel Pretorius (51) | - | zaf_limpopo | 1 | yes |
| LIB | Republic of Liberia | republic | Edward James Roye (55) | - | lbr_liberia | 1 | yes |
| QAJ | Qajar Persia | absolute_monarchy | Naser al-Din Shah (39) | - | irn_jibal | 7 | yes |
| OMN | Sultanate of Muscat and Oman | absolute_monarchy | Turki bin Said (38) | - | omn_oman | 2 | yes |
| QNG | Qing Empire | absolute_monarchy | Tongzhi Emperor (Dowager Cixi) (14) | - | chn_jilin | 12 | yes |
| KOR | Joseon Korea | absolute_monarchy | Gojong (Daewongun regent) (18) | - | kor_gangwon | 3 | yes |
| JPN | Empire of Japan (Meiji) | empire | Meiji Emperor (18) | - | jpn_iwate | 4 | yes |
| SIA | Kingdom of Siam | absolute_monarchy | Chulalongkorn (Rama V) (17) | - | tha_chiang_mai | 3 | yes |
| BUR | Konbaung Burma | absolute_monarchy | Mindon Min (62) | - | mmr_shan | 1 | yes |
| DAI | Đại Nam (Nguyễn Vietnam) | absolute_monarchy | Tự Đức (41) | - | vnm_nghe_an | 1 | yes |
| AFG | Emirate of Afghanistan | absolute_monarchy | Sher Ali Khan (45) | - | afg_badakhshan | 3 | yes |
| KSH | Kashgaria (Yaqub Beg) | absolute_monarchy | Yaqub Beg (51) | - | chn_xinjiang | 1 | yes |
| KOK | Khanate of Kokand | absolute_monarchy | Khudayar Khan (41) | - | kgz_kyrgyzstan | 1 | yes |
| BUK | Emirate of Bukhara (Russian protectorate) | absolute_monarchy | Muzaffar ad-Din (40) | - | uzb_bukhoro | 2 | yes |
| KHV | Khanate of Khiva | absolute_monarchy | Muhammad Rahim II (25) | - | uzb_karakalpakstan | 2 | yes |
| NPL | Kingdom of Nepal (Rana regime) | military_government | Jung Bahadur Rana (54) | - | npl_nepal | 1 | yes |
| USA | United States of America | republic | Ulysses S. Grant (48) | - | usa_new_york | 12 | yes |
| CAN | Dominion of Canada | constitutional_monarchy | John A. Macdonald (55) | - | can_ontario | 6 | yes |
| MEX | Mexican Republic | republic | Benito Juárez (64) | - | mex_jalisco | 5 | yes |
| BRA | Empire of Brazil | constitutional_monarchy | Pedro II (45) | - | bra_minas_gerais | 8 | yes |
| ARG | Argentine Republic | republic | Domingo F. Sarmiento (59) | - | arg_buenos_aires | 4 | yes |
| URU | Oriental Republic of Uruguay | republic | Lorenzo Batlle (60) | - | ury_uruguay | 1 | yes |
| PAR | Republic of Paraguay | republic | Cirilo Antonio Rivarola (34) | - | pry_paraguay | 1 | yes |
| CHL | Republic of Chile | republic | José Joaquín Pérez (69) | - | chl_antofagasta | 2 | yes |
| BOL | Republic of Bolivia | republic | Agustín Morales (62) | - | bol_bolivia | 1 | yes |
| PER | Republic of Peru | republic | José Balta (56) | - | per_loreto | 2 | yes |
| ECU | Republic of Ecuador | republic | Gabriel García Moreno (49) | - | ecu_ecuador | 1 | yes |
| COL | United States of Colombia | republic | Eustorgio Salgar (39) | - | col_antioquia | 3 | yes |
| VNZ | Republic of Venezuela | republic | Antonio Guzmán Blanco (41) | - | ven_venezuela | 1 | yes |
| HTI | Republic of Haiti | republic | Nissage Saget (61) | - | hti_haiti | 1 | yes |
| DOM | Dominican Republic | republic | Buenaventura Báez (59) | - | dom_dominican_rep | 1 | yes |
| GTM | Republic of Guatemala | military_government | Vicente Cerna (56) | - | gtm_guatemala | 1 | yes |
| HND | Republic of Honduras | military_government | José María Medina (50) | - | hnd_honduras | 1 | yes |
| SLV | Republic of El Salvador | military_government | Francisco Dueñas (59) | - | slv_el_salvador | 1 | yes |
| NIC | Republic of Nicaragua | military_government | Fernando Guzmán (58) | - | nic_nicaragua | 1 | yes |
| CRI | Republic of Costa Rica | military_government | Tomás Guardia Gutiérrez (40) | - | cri_costa_rica | 1 | yes |
| GER | German Empire | constitutional_monarchy | Wilhelm I (Chancellor Bismarck) (73) | Frederick William | deu_brandenburg | 13 | no |
| ASN | Asante Empire | absolute_monarchy | Asantehene Kofi Karikari (35) | - | gha_ghana | 1 | yes |
| DAH | Kingdom of Dahomey | absolute_monarchy | King Glele (57) | - | ben_benin | 2 | yes |
| SOK | Sokoto Caliphate | theocracy | Sultan Ahmadu Rufai (60) | - | nga_niger | 2 | yes |
| KNB | Bornu (Shehu Umar) | absolute_monarchy | Shehu Umar of Bornu (50) | - | nga_borno | 1 | yes |
| WAD | Sultanate of Wadai | absolute_monarchy | Sultan Ali of Wadai (40) | - | tcd_batha | 2 | yes |
| BUG | Kingdom of Buganda | absolute_monarchy | Kabaka Mutesa I (34) | - | uga_uganda | 1 | yes |
| RWD | Kingdoms of Rwanda and Burundi | absolute_monarchy | Mwami Kigeli IV Rwabugiri (31) | - | rwa_rwanda | 2 | yes |
| NYM | Nyamwezi Kingdoms (Mirambo) | tribal_confederation | Mirambo (31) | - | tza_tabora | 1 | yes |
| MSR | Yeke Kingdom of Msiri (Garanganze) | absolute_monarchy | Msiri (40) | - | cod_katanga | 1 | yes |
| TTP | Swahili-Arab Trading Domain (Tippu Tip) | military_government | Hamed bin Muhammad (Tippu Tip) (38) | - | cod_orientale | 1 | yes |
| KNG | Kingdom of Kongo (São Salvador) | absolute_monarchy | Pedro V of Kongo (45) | - | cog_congo | 2 | yes |
| NDB | Ndebele Kingdom | absolute_monarchy | Lobengula (26) | - | zwe_zimbabwe | 1 | yes |
| LOZ | Lozi Kingdom (Barotseland) | absolute_monarchy | Litunga Sipopa (45) | - | zmb_zambia | 1 | yes |
| TCL | Toucouleur Empire | theocracy | Ahmadu Seku (35) | - | mli_kayes | 2 | yes |
| KWT | Sheikhdom of Kuwait | absolute_monarchy | Sheikh Abdullah II Al Sabah (56) | - | kwt_kuwait | 2 | yes |
| NJD | Emirate of Najd (Second Saudi State) | theocracy | Abdallah bin Faisal (43) | - | sau_najd | 1 | yes |
| BRU | Sultanate of Brunei (reduced) | absolute_monarchy | Sultan Abdul Mumin (70) | - | brn_brunei | 2 | yes |
| SRW | Raj of Sarawak (Brooke) | absolute_monarchy | Rajah Charles Brooke (41) | - | mys_sarawak | 1 | yes |
| FJI | Fijian Chiefdoms (Cakobau) | tribal_confederation | Ratu Seru Cakobau (55) | - | fji_fiji | 1 | yes |
| PNG | Papuan and Melanesian Peoples | tribal_confederation | Chiefs and elders (unnamed) (40) | - | png_west_new_britain | 5 | yes |
| SHL | Hausa, Nupe and Savanna Peoples | tribal_confederation | Chiefs and elders (unnamed) (40) | - | nga_taraba | 2 | yes |
| GUL | Guinea Coast and Forest Peoples | tribal_confederation | Chiefs and elders (unnamed) (40) | - | civ_cote_d_ivoire | 5 | yes |
| CAF | Central African Forest and Savanna Peoples | tribal_confederation | Chiefs and elders (unnamed) (40) | - | cmr_cameroon | 3 | yes |
| SWH | Swahili Coast Towns and Eastern Bantu Peoples | tribal_confederation | Chiefs and elders (unnamed) (40) | - | mwi_malawi | 1 | yes |
| SOMA | Somali and Afar Peoples (Horn of Africa) | tribal_confederation | Chiefs and elders (unnamed) (40) | - | som_somalia | 3 | yes |
| SAF | Southern African Peoples (Bantu, Khoikhoi and San) | tribal_confederation | Chiefs and elders (unnamed) (40) | - | bwa_botswana | 3 | yes |
| HIM | Himalayan Valleys (Nepal and Bhutan) | tribal_confederation | Chiefs and elders (unnamed) (40) | - | btn_bhutan | 1 | yes |
| SAH | Tuareg and Saharan Oasis Chiefdoms | tribal_confederation | Chiefs and elders (unnamed) (40) | - | dza_algerian_sahara | 2 | yes |

## Notes per new or changed country

* **ASN - Asante Empire**: Kofi Karikari (r. 1867-1874) was about to invade the Gold Coast protectorate (1873); the British Gold Coast Colony is formed only in 1874, so the whole region is Asante here. Age is approximate.
* **DAH - Kingdom of Dahomey**: Glele (r. 1858-1889) ruled Dahomey with its Amazon regiments; birth year is approximate.
* **SOK - Sokoto Caliphate**: Ahmadu Rufai (r. 1867-1873) headed the caliphate founded by Usman dan Fodio in 1804; the emirates (Gwandu, Kano, Yola) are merged and the Yoruba states in the same modern region are not drawn separately. Age is a guess.
* **KNB - Bornu (Shehu Umar)**: Umar (r. 1853-1881) ruled Bornu as shehu of the Kanemi dynasty after the Sayfawa mais; age is approximate.
* **WAD - Sultanate of Wadai**: Ali ibn Muhammad Sharif (r. 1858-1874) was the strong ruler of Wadai in the central Sudan; age is approximate.
* **BUG - Kingdom of Buganda**: Mutesa I (r. 1856-1884) received Speke (1862) and Stanley (1875); birth year c. 1837.
* **RWD - Kingdoms of Rwanda and Burundi**: Rwabugiri (r. 1853-1895) expanded Rwanda; Burundi under Mwezi IV Gisabo (r. 1852-1908) is merged. Ages are approximate.
* **NYM - Nyamwezi Kingdoms (Mirambo)**: Mirambo (c. 1840-1884) was building his Ruga-Ruga state in the early 1870s; the date of his rise is approximate.
* **MSR - Yeke Kingdom of Msiri (Garanganze)**: Msiri (r. c. 1856-1891) built a copper-and-ivory trading state in Katanga; birth year is approximate.
* **TTP - Swahili-Arab Trading Domain (Tippu Tip)**: From the 1870s Tippu Tip built a trading domain in the eastern Congo; in 1871 it is still emerging.
* **KNG - Kingdom of Kongo (São Salvador)**: Pedro V (r. 1859-1891) ruled a Portuguese-influenced rump kingdom; its capital São Salvador lies in Angola, so the modern regions shown are only its sphere.
* **NDB - Ndebele Kingdom**: Lobengula was crowned in 1870 after Mzilikazi's death in 1868 (b. c. 1845, approximate).
* **LOZ - Lozi Kingdom (Barotseland)**: Sipopa (r. 1864-1876) restored the Lozi kingdom after the Kololo interlude; age is approximate.
* **TCL - Toucouleur Empire**: Ahmadu Seku (r. 1864-1893) inherited El Hadj Umar's empire from Segou; Masina and Timbuktu are only loosely held. Birth year c. 1836.
* **KWT - Sheikhdom of Kuwait**: Abdullah II (r. 1866-1892); Qatar under the Al Thani is merged. Age is approximate.
* **NJD - Emirate of Najd (Second Saudi State)**: Abdallah and Saud (sons of Faisal bin Turki) fought over Najd in 1865-1871; the Rashidis of Hail are rising. Age is approximate.
* **BRU - Sultanate of Brunei (reduced)**: Abdul Mumin (r. 1852-1885) lost territory to Sarawak; Sabah is shown with Brunei before the British North Borneo Company (1881). Age is approximate.
* **SRW - Raj of Sarawak (Brooke)**: Charles Brooke (b. 1829) succeeded James Brooke in 1868 as White Rajah.
* **FJI - Fijian Chiefdoms (Cakobau)**: Cakobau (b. c. 1815) led the Tovata confederacy; he proclaims the Kingdom of Fiji in June 1871, so it is shown slightly early.
* **PNG - Papuan and Melanesian Peoples**: New Guinea and Melanesian peoples; German and British claims on the coast come after 1884.
* **SHL - Hausa, Nupe and Savanna Peoples**: Mossi and Gur peoples and non-caliphate Hausa areas.
* **GUL - Guinea Coast and Forest Peoples**: Mande (Samori's Wassoulou emerges in the 1870s), Akan, Yoruba and Atlantic-coast peoples; not modelled.
* **CAF - Central African Forest and Savanna Peoples**: Peoples of the Congo basin, Cameroon, Gabon and the Ubangi; the Adamawa emirate and the Fang are not drawn separately.
* **SWH - Swahili Coast Towns and Eastern Bantu Peoples**: Interior peoples of Malawi and the lakes region; Zanzibar and the coast are shown separately.
* **SOMA - Somali and Afar Peoples (Horn of Africa)**: Somali clan sultanates (Majeerteen, Geledi) and Afar sultans; Ottoman and Egyptian garrisons hold some coastal towns.
* **SAF - Southern African Peoples (Bantu, Khoikhoi and San)**: Zulu (Mpande, d. 1872), Swazi, Tswana and Sotho kingdoms and Khoikhoi groups beyond the colonial frontier; not drawn individually.
* **HIM - Himalayan Valleys (Nepal and Bhutan)**: A cultural group, not one state: the political map of this region and date is not securely documented, so no ruler is named.
* **SAH - Tuareg and Saharan Oasis Chiefdoms**: Tuareg confederations and the Moorish emirates of Mauritania (Trarza, Adrar); no single state.
