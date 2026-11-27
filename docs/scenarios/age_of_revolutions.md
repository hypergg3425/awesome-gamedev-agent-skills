# Scenario: Age of Revolutions (`age_of_revolutions`)

Status: v2.0 reconstruction by workstream B1. Everything marked `approximate` in `data/scenarios/age_of_revolutions.json` is a best-effort reconstruction. Population, treasury and army sizes are **gameplay estimates** produced by `ScenarioLoader` (they are not documented statistics).

## Start date
* 1789-07 (the Bastille falls on 14 July 1789). Turns are three months long; ages are computed for the start date (see `tests/t_scenarios_v2.gd`, which checks 29 ruler ages against birth years).

## What changed in v2.0
* Countries: 44 -> 91 (all 410 provinces now have a named owner; 108 provinces were previously generic `<Region> Peoples` filler).
* 47 new political entities, of which 34 are `native: true` named cultural groups where no state can be drawn.
* Scenario-specific province names layer (`province_names`): 61 provinces; geo layer notes: 0.
* Claims: 55 entries for 20 countries; alliances/vassals/wars were reviewed against the sources below.

## Sources
### Main historical sources
* European rulers: standard regnal lists (Wikipedia, CC BY-SA 4.0); Eric Hobsbawm, The Age of Revolution (1962).
* Ottoman, Persian, Indian and East Asian states: Inalcik and Quataert (eds.), An Economic and Social History of the Ottoman Empire (1994); Cambridge History of Iran vol. 7; Cambridge History of China vol. 9; Totman (2005).
* Africa: UNESCO General History of Africa vol. 5 (1992); Basil Davidson, A History of West Africa; Wikipedia lists of rulers (Asante, Dahomey, Oyo, Segou, Darfur, Imerina).

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
| FRA | Kingdom of France (Ancien Régime) | absolute_monarchy | Louis XVI (34) | Louis-Charles, Dauphin | fra_ile_de_france | 17 | no |
| SDG | Saint-Domingue (French colony) | absolute_monarchy | Comte de Peynier (governor) (50) | - | hti_haiti | 1 | yes |
| GBR | Kingdom of Great Britain | constitutional_monarchy | George III (51) | George, Prince of Wales | gbr_home_counties | 15 | no |
| IRL | Kingdom of Ireland | constitutional_monarchy | Marquess of Buckingham (Lord Lieutenant) (36) | - | irl_leinster | 4 | yes |
| HAN | Electorate of Hanover | feudal_kingdom | George III (Elector, personal union) (51) | - | deu_lower_saxony | 1 | yes |
| EIC | East India Company (British India) | military_government | Lord Cornwallis (50) | - | bgd_bangladesh | 3 | yes |
| AUT | Habsburg Monarchy | absolute_monarchy | Joseph II (48) | Leopold | aut_austria | 18 | yes |
| RUS | Russian Empire | absolute_monarchy | Catherine II the Great (60) | Paul | rus_novgorod | 20 | yes |
| OTT | Ottoman Empire | empire | Selim III (27) | - | tur_constantinople | 42 | yes |
| EGY | Egypt (Mamluk beys) | feudal_kingdom | Ibrahim Bey (54) | - | egy_cairo | 4 | yes |
| ALG | Regency of Algiers | military_government | Dey Muhammad ibn Uthman (70) | - | dza_algiers | 2 | yes |
| TUN | Beylik of Tunis | feudal_kingdom | Hammuda Pasha (30) | - | tun_tunisia | 1 | yes |
| MOR | Sultanate of Morocco | absolute_monarchy | Muhammad III ibn Abdallah (79) | - | mar_fez | 2 | yes |
| SPA | Kingdom of Spain | absolute_monarchy | Charles IV (41) | Ferdinand | esp_new_castile | 51 | yes |
| POR | Kingdom of Portugal | absolute_monarchy | Maria I (54) | John, Prince of Brazil | prt_south_portugal | 15 | yes |
| NLD | Dutch Republic | merchant_republic | William V of Orange (Stadtholder) (41) | William | nld_holland | 10 | yes |
| SWE | Kingdom of Sweden | absolute_monarchy | Gustav III (43) | Gustav Adolf | swe_svealand | 6 | yes |
| DEN | Denmark-Norway | absolute_monarchy | Crown Prince Frederick (regent for Christian VII) (21) | - | dnk_zealand | 8 | yes |
| POL | Polish-Lithuanian Commonwealth | feudal_kingdom | Stanisław August Poniatowski (57) | - | pol_masovia | 7 | yes |
| VEN | Republic of Venice | merchant_republic | Ludovico Manin (Doge) (64) | - | ita_veneto | 2 | yes |
| PAP | Papal States | theocracy | Pius VI (71) | - | ita_lazio | 2 | yes |
| NAP | Kingdom of the Two Sicilies | absolute_monarchy | Ferdinand IV (38) | Francis | ita_campania | 4 | yes |
| SAV | Kingdom of Sardinia (Savoy-Piedmont) | absolute_monarchy | Victor Amadeus III (63) | - | ita_piedmont | 2 | yes |
| GEN | Republic of Genoa | merchant_republic | Doge of Genoa (Senate) (60) | - | ita_liguria | 1 | yes |
| SWI | Swiss Confederacy | republic | Federal Diet (Tagsatzung) (50) | - | che_switzerland | 1 | yes |
| BAV | Palatinate-Bavaria | absolute_monarchy | Charles Theodore (64) | - | deu_bavaria | 2 | yes |
| SAX | Electorate of Saxony | absolute_monarchy | Frederick Augustus III (38) | - | deu_saxony | 2 | yes |
| USA | United States of America | republic | George Washington (57) | - | usa_new_york | 4 | no |
| MRT | Maratha Confederacy | feudal_kingdom | Madhavrao II (under Nana Phadnavis) (15) | - | ind_maharashtra | 3 | yes |
| MUG | Mughal Empire (Delhi) | feudal_kingdom | Shah Alam II (61) | - | ind_madhya_pradesh | 1 | yes |
| MYS | Sultanate of Mysore | military_government | Tipu Sultan (38) | - | ind_karnataka | 1 | yes |
| SKH | Sikh Misls | tribal_confederation | Maha Singh Sukerchakia (29) | - | pak_punjab | 1 | yes |
| DUR | Durrani Empire | feudal_kingdom | Timur Shah Durrani (41) | - | afg_hilmand | 6 | yes |
| QNG | Qing China | empire | Qianlong Emperor (77) | - | chn_jilin | 14 | yes |
| KOR | Joseon Korea | absolute_monarchy | Jeongjo (36) | - | kor_gangwon | 3 | yes |
| JPN | Tokugawa Japan | feudal_kingdom | Tokugawa Ienari (16) | - | jpn_iwate | 3 | yes |
| SIA | Kingdom of Siam (Rattanakosin) | absolute_monarchy | Rama I (Phutthayotfa Chulalok) (52) | - | tha_chiang_mai | 4 | yes |
| BUR | Konbaung Burma | absolute_monarchy | Bodawpaya (44) | - | mmr_shan | 2 | yes |
| DAI | Tây Sơn Vietnam | military_government | Quang Trung (Nguyễn Huệ) (36) | - | vnm_nghe_an | 2 | yes |
| ZND | Zand Persia | absolute_monarchy | Lotf Ali Khan (20) | - | irn_fars | 4 | yes |
| QAJ | Qajar Persia (rising) | absolute_monarchy | Agha Mohammad Khan (47) | - | irn_jibal | 4 | yes |
| GEO | Kingdom of Kartli-Kakheti | feudal_kingdom | Erekle II (69) | - | geo_georgia | 1 | yes |
| SAU | Emirate of Diriyah (First Saudi State) | theocracy | Abd al-Aziz ibn Muhammad (69) | - | sau_najd | 2 | yes |
| PRU | Kingdom of Prussia | absolute_monarchy | Frederick William II (44) | Frederick William | deu_brandenburg | 5 | yes |
| ASN | Asante Empire | absolute_monarchy | Asantehene Osei Kwame Panyin (25) | - | gha_ghana | 1 | yes |
| DAH | Kingdom of Dahomey | absolute_monarchy | King Agonglo (succeeding Kpengla) (30) | - | ben_benin | 2 | yes |
| OYO | Oyo Empire (Yoruba) | absolute_monarchy | Alaafin Abiodun (died 1789) (60) | - | nga_niger | 1 | yes |
| KNB | Bornu (Sayfawa Mais) | absolute_monarchy | Mai of Bornu (Sayfawa, name uncertain) (40) | - | nga_borno | 3 | yes |
| FTR | Imamate of Futa Toro | theocracy | Almamy Abdul Qadir Kan (50) | - | sen_senegal | 1 | yes |
| FTJ | Imamate of Futa Jallon | theocracy | Almami of Futa Jallon (name uncertain) (45) | - | gin_guinea | 2 | yes |
| SEG | Bamana Empire of Segou | absolute_monarchy | Monson Diarra (40) | - | mli_kayes | 1 | yes |
| ETH | Ethiopia (Gondar, Era of the Princes) | empire | Emperor Tekle Giyorgis I (puppet of the warlords) (40) | - | eth_oromiya | 2 | yes |
| DRF | Sultanate of Darfur | absolute_monarchy | Sultan Abd al-Rahman al-Rashid (40) | - | sdn_north_kordufan | 1 | yes |
| FNJ | Funj Sultanate of Sennar | absolute_monarchy | Sultan of Sennar (name uncertain) (40) | - | sdn_northern | 1 | yes |
| LND | Lunda Empire (Mwata Yamvo) | absolute_monarchy | Mwata Yamvo (name uncertain) (45) | - | cod_katanga | 2 | yes |
| MER | Kingdom of Imerina (Merina) | absolute_monarchy | Andrianampoinimerina (44) | - | mdg_madagascar | 1 | yes |
| RZV | Rozvi Empire (Changamire) | absolute_monarchy | Changamire (name uncertain) (45) | - | zwe_zimbabwe | 1 | yes |
| OMA | Sultanate of Muscat and Oman | absolute_monarchy | Hamad bin Said Al Bu Said (30) | - | omn_oman | 2 | yes |
| KWT | Sheikhdom of Kuwait | absolute_monarchy | Sheikh Abdullah I Al Sabah (50) | - | kwt_kuwait | 2 | yes |
| YEM | Zaydi Imamate of Yemen | theocracy | Imam al-Mahdi Abbas (50) | - | yem_yemen | 1 | yes |
| BKH | Emirate of Bukhara (Manghit) | absolute_monarchy | Shah Murad (39) | - | uzb_bukhoro | 2 | yes |
| KHV | Khanate of Khiva | absolute_monarchy | Avaz Inaq (Qungrat) (45) | - | uzb_karakalpakstan | 1 | yes |
| KOK | Khanate of Kokand | absolute_monarchy | Narbuta Bi (45) | - | kgz_kyrgyzstan | 1 | yes |
| NPL | Gorkha Kingdom of Nepal | absolute_monarchy | Rana Bahadur Shah (under regent Bahadur Shah) (14) | - | npl_nepal | 1 | yes |
| AHM | Ahom Kingdom | absolute_monarchy | Gaurinath Singha (20) | - | ind_arunachal_pradesh | 1 | yes |
| BRU | Sultanate of Brunei (declining) | absolute_monarchy | Sultan Muhammad Tajuddin (50) | - | brn_brunei | 3 | yes |
| BJM | Sultanate of Banjar | absolute_monarchy | Tahmidullah II (50) | - | idn_kalimantan_tengah | 1 | yes |
| ACH | Sultanate of Aceh | absolute_monarchy | Sultan Alauddin Muhammad Syah (40) | - | idn_sumatera_utara | 1 | yes |
| JOH | Sultanate of Riau-Lingga | absolute_monarchy | Sultan Mahmud Riayat Shah III (50) | - | idn_riau | 1 | yes |
| KZH | Kazakh Zhuzes (Hordes) | tribal_confederation | Khans of the three zhuzes (Ablai's successors; unnamed) (45) | - | kaz_qaraghandy | 3 | yes |
| TKM | Turkmen Tribes (Tekke, Yomut, Ersari) | tribal_confederation | Tribal elders (unnamed) (45) | - | tkm_turkmenistan | 1 | yes |
| TMB | Pashalik of Timbuktu (Arma) and Tuareg | military_government | Arma pasha of Timbuktu (name uncertain) (45) | - | mli_timbuktu | 1 | yes |
| MYA | Maya City-States | tribal_confederation | Chiefs and elders (unnamed) (40) | - | blz_belize | 1 | yes |
| PLN | Plains and Great Basin Peoples | tribal_confederation | Chiefs and elders (unnamed) (40) | - | usa_montana | 3 | yes |
| PAC | Pacific Coast Peoples | tribal_confederation | Chiefs and elders (unnamed) (40) | - | usa_oregon | 2 | yes |
| ARC | Arctic and Subarctic Peoples | tribal_confederation | Chiefs and elders (unnamed) (40) | - | can_yukon | 3 | yes |
| ABO | Aboriginal Australian Nations | tribal_confederation | Chiefs and elders (unnamed) (40) | - | aus_northern_territory | 5 | yes |
| PNG | Papuan and Melanesian Peoples | tribal_confederation | Chiefs and elders (unnamed) (40) | - | idn_papua | 8 | yes |
| MCR | Micronesian and Polynesian Chiefdoms | tribal_confederation | Chiefs and elders (unnamed) (40) | - | isl_polynesia | 1 | yes |
| BOR | Bornean and Moluccan Coastal Chiefdoms | tribal_confederation | Chiefs and elders (unnamed) (40) | - | idn_kalimantan_timur | 3 | yes |
| AIN | Ainu and Emishi Peoples of Ezo | tribal_confederation | Chiefs and elders (unnamed) (40) | - | jpn_hokkaido | 1 | yes |
| SHL | Hausa, Nupe and Savanna Peoples | tribal_confederation | Chiefs and elders (unnamed) (40) | - | nga_taraba | 3 | yes |
| GUL | Guinea Coast and Forest Peoples | tribal_confederation | Chiefs and elders (unnamed) (40) | - | civ_cote_d_ivoire | 6 | yes |
| CAF | Central African Forest and Savanna Peoples | tribal_confederation | Chiefs and elders (unnamed) (40) | - | cod_orientale | 6 | yes |
| SSD | Nilotic and Great Lakes Peoples | tribal_confederation | Chiefs and elders (unnamed) (40) | - | sds_s_sudan | 4 | yes |
| SWH | Swahili Coast Towns and Eastern Bantu Peoples | tribal_confederation | Chiefs and elders (unnamed) (40) | - | ken_kenya | 4 | yes |
| SOMA | Somali and Afar Peoples (Horn of Africa) | tribal_confederation | Chiefs and elders (unnamed) (40) | - | som_somalia | 3 | yes |
| SAF | Southern African Peoples (Bantu, Khoikhoi and San) | tribal_confederation | Chiefs and elders (unnamed) (40) | - | zaf_limpopo | 8 | yes |
| MAO | Early Maori Settlers of Aotearoa | tribal_confederation | Chiefs and elders (unnamed) (40) | - | nzl_waikato | 2 | yes |
| HIM | Himalayan Valleys (Nepal and Bhutan) | tribal_confederation | Chiefs and elders (unnamed) (40) | - | btn_bhutan | 1 | yes |
| SAH | Tuareg and Saharan Oasis Chiefdoms | tribal_confederation | Chiefs and elders (unnamed) (40) | - | dza_algerian_sahara | 2 | yes |

## Notes per new or changed country

* **ASN - Asante Empire**: Osei Kwame (r. 1777-1803) ruled the Gold Coast hinterland from Kumasi; his age is uncertain (he came to the Golden Stool as a young man).
* **DAH - Kingdom of Dahomey**: Kpengla died in 1789 and his son Agonglo succeeded him; the month is uncertain, age is a guess. Dahomey was a tributary of Oyo until c. 1818 and profited from the slave trade.
* **OYO - Oyo Empire (Yoruba)**: Abiodun (r. 1770-1789) died in 1789; the empire is already weakening. The Benin kingdom shares the modern region and is not drawn separately.
* **KNB - Bornu (Sayfawa Mais)**: Bornu was weakening under the Sayfawa mais before the Fulani jihad of 1804; Wadai and Baguirmi in the same region are not drawn separately.
* **FTR - Imamate of Futa Toro**: Abdul Qadir (r. 1776-1806) led the Torodbe theocratic state on the Senegal River; age is a guess.
* **FTJ - Imamate of Futa Jallon**: A Fulani theocratic state founded c. 1725; the almami of 1789 is not securely named.
* **SEG - Bamana Empire of Segou**: Monson Diarra (r. 1787-1808) ruled the Bamana state of Segou on the Niger; age is a guess.
* **ETH - Ethiopia (Gondar, Era of the Princes)**: The Zemene Mesafint (1769-1855): emperors in Gondar are controlled by regional rases; reigns of Tekle Giyorgis were interrupted several times. Age is a guess.
* **DRF - Sultanate of Darfur**: Abd al-Rahman al-Rashid (r. 1787-1801) ruled Darfur, whose lands overlap the modern Kordofan region. Age is a guess.
* **FNJ - Funj Sultanate of Sennar**: Sennar was dominated by the Hamaj regents; the sultan of 1789 is not securely named.
* **LND - Lunda Empire (Mwata Yamvo)**: The Lunda empire was at its height; its rulers of the 1780s are not securely named.
* **MER - Kingdom of Imerina (Merina)**: Andrianampoinimerina (r. 1787-1810) began the unification of the Madagascar highlands; the modern region is the whole island, most of which is other peoples.
* **RZV - Rozvi Empire (Changamire)**: The Rozvi state replaced Mutapa as the main power south of the Zambezi; its rulers are not securely named.
* **OMA - Sultanate of Muscat and Oman**: Hamad bin Said (de facto ruler of Muscat 1784-1792) sidelined the imam; age is a guess. The Trucial sheikhdoms of the coast are merged.
* **KWT - Sheikhdom of Kuwait**: Abdullah I (r. 1762-1814) ruled the trading port of Kuwait; Qatar and the Al Khalifa conquest of Bahrain (1783) are merged. Age is a guess.
* **YEM - Zaydi Imamate of Yemen**: Al-Mahdi Abbas (r. 1775-1809) ruled the declining Qasimid imamate; age is a guess.
* **BKH - Emirate of Bukhara (Manghit)**: Shah Murad (r. 1785-1800) formalised Manghit rule in Bukhara; age is approximate.
* **KHV - Khanate of Khiva**: The Qungrat inaqs ruled Khiva as vizier-regents behind figurehead khans; the exact inaq of 1789 is approximate.
* **KOK - Khanate of Kokand**: Narbuta Bi (r. 1770-1798) ruled the Ferghana khanate; age is a guess.
* **NPL - Gorkha Kingdom of Nepal**: Rana Bahadur (b. 1775, r. 1777-1799) was a child under the regency of his uncle Bahadur Shah. Nepal invades Tibet in 1788-1789.
* **AHM - Ahom Kingdom**: Gaurinath Singha (r. 1780-1795) faced the Moamoria rebellion; birth year is approximate.
* **BRU - Sultanate of Brunei (declining)**: Muhammad Tajuddin (r. 1778-1807); the large modern provinces overstate Brunei's authority. Age is a guess.
* **BJM - Sultanate of Banjar**: Tahmidullah II (r. 1761-1801) was a VOC client; age is a guess.
* **ACH - Sultanate of Aceh**: Alauddin Muhammad Syah (r. 1781-1795) ruled a weakened Aceh; age is a guess.
* **JOH - Sultanate of Riau-Lingga**: Mahmud III (r. 1761-1812) ruled Johor-Riau, fighting the Dutch (1784) and the Bugis; age is a guess.
* **KZH - Kazakh Zhuzes (Hordes)**: The Younger and Middle Zhuz accepted Russian protection from 1731-1740, but remained effectively independent.
* **TKM - Turkmen Tribes (Tekke, Yomut, Ersari)**: Nomadic Turkmen tribes under Persian, Khivan and Bukharan pressure; no state.
* **TMB - Pashalik of Timbuktu (Arma) and Tuareg**: The Arma descendants of the Moroccan conquerors of 1591 held Timbuktu under Tuareg pressure; no ruler is securely named.
* **MYA - Maya City-States**: A cultural group, not one state: the political map of this region and date is not securely documented, so no ruler is named.
* **PLN - Plains and Great Basin Peoples**: Plains and Rocky Mountain peoples (Lakota, Crow, Blackfoot, Shoshone); no state.
* **PAC - Pacific Coast Peoples**: Pacific Northwest peoples (Nootka Crisis between Spain and Britain, 1789) and Californian peoples; Spanish missions are shown as part of Spain elsewhere.
* **ARC - Arctic and Subarctic Peoples**: Inuit, Dene, Cree and Hudson's Bay Company trading posts (Rupert's Land); no state is drawn.
* **ABO - Aboriginal Australian Nations**: Hundreds of Aboriginal nations; the First Fleet arrived at Botany Bay in 1788 (New South Wales is a British colony in this scenario).
* **PNG - Papuan and Melanesian Peoples**: A cultural group, not one state: the political map of this region and date is not securely documented, so no ruler is named.
* **MCR - Micronesian and Polynesian Chiefdoms**: A cultural group, not one state: the political map of this region and date is not securely documented, so no ruler is named.
* **BOR - Bornean and Moluccan Coastal Chiefdoms**: A cultural group, not one state: the political map of this region and date is not securely documented, so no ruler is named.
* **AIN - Ainu and Emishi Peoples of Ezo**: Ainu lands north of the Matsumae domain; Japanese traders hold coastal posts.
* **SHL - Hausa, Nupe and Savanna Peoples**: Hausa city-states, Nupe, Jukun and Mossi peoples; the Sokoto Caliphate is founded only in 1804.
* **GUL - Guinea Coast and Forest Peoples**: Coastal peoples of Upper Guinea and Liberia; not modelled.
* **CAF - Central African Forest and Savanna Peoples**: A cultural group, not one state: the political map of this region and date is not securely documented, so no ruler is named.
* **SSD - Nilotic and Great Lakes Peoples**: Buganda, Bunyoro, Rwanda, Burundi and Nilotic peoples; no single state is drawn.
* **SWH - Swahili Coast Towns and Eastern Bantu Peoples**: East African interior and the Omani-influenced coast; Zanzibar is not yet a separate state.
* **SOMA - Somali and Afar Peoples (Horn of Africa)**: A cultural group, not one state: the political map of this region and date is not securely documented, so no ruler is named.
* **SAF - Southern African Peoples (Bantu, Khoikhoi and San)**: Zulu, Xhosa, Sotho, Tswana, Khoikhoi, San and Boer frontier peoples (the Cape Colony is part of the Dutch sphere in this scenario); the Zulu kingdom under Shaka is not yet formed.
* **MAO - Early Maori Settlers of Aotearoa**: Maori iwi (tribes); Cook visited in 1769-1777.
* **HIM - Himalayan Valleys (Nepal and Bhutan)**: A cultural group, not one state: the political map of this region and date is not securely documented, so no ruler is named.
* **SAH - Tuareg and Saharan Oasis Chiefdoms**: A cultural group, not one state: the political map of this region and date is not securely documented, so no ruler is named.
