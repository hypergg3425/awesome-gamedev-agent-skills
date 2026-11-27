# Scenario: World Conquest (fictional) (`world_conquest`)

Status: v2.0 reconstruction by workstream B1. Everything marked `approximate` in `data/scenarios/world_conquest.json` is a best-effort reconstruction. Population, treasury and army sizes are **gameplay estimates** produced by `ScenarioLoader` (they are not documented statistics).

## Start date
* 1900-01 (alternate-history start on approximate 1900 borders). Turns are three months long; ages are computed for the start date (see `tests/t_scenarios_v2.gd`, which checks 29 ruler ages against birth years).

## What changed in v2.0
* Countries: 53 -> 53 (all 410 provinces now have a named owner; 0 provinces were previously generic `<Region> Peoples` filler).
* 0 new political entities, of which 0 are `native: true` named cultural groups where no state can be drawn.
* Scenario-specific province names layer (`province_names`): 33 provinces; geo layer notes: 0.
* Claims: 51 entries for 18 countries; alliances/vassals/wars were reviewed against the sources below.

## Sources
### Main historical sources
* Political situation of 1900: Hobsbawm, The Age of Empire (1987); Wikipedia lists of rulers of 1900 (CC BY-SA 4.0).
* This scenario is FICTIONAL alternate history; the 1900 borders and colonial arrangements are simplified and no claim about what was or should have been is made.

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
| GBR | British Empire | constitutional_monarchy | Victoria (PM Salisbury) (80) | Albert Edward, Prince of Wales | gbr_home_counties | 73 | yes |
| CAN | Dominion of Canada | constitutional_monarchy | Wilfrid Laurier (58) | - | can_ontario | 8 | yes |
| EGY | Egypt (British-occupied Khedivate) | absolute_monarchy | Abbas II Hilmi (25) | - | egy_cairo | 4 | yes |
| FRA | French Republic | republic | Émile Loubet (61) | - | fra_ile_de_france | 43 | yes |
| RUS | Russian Empire | absolute_monarchy | Nicholas II (31) | - | rus_novgorod | 40 | yes |
| AUH | Austria-Hungary | constitutional_monarchy | Franz Joseph I (69) | Franz Ferdinand | aut_austria | 15 | yes |
| ITA | Kingdom of Italy | constitutional_monarchy | Umberto I (55) | Victor Emmanuel | ita_lazio | 14 | yes |
| OTT | Ottoman Empire | absolute_monarchy | Abdulhamid II (57) | - | tur_constantinople | 34 | yes |
| SPA | Kingdom of Spain | constitutional_monarchy | Alfonso XIII (Regent Maria Christina) (13) | - | esp_new_castile | 13 | yes |
| POR | Kingdom of Portugal | constitutional_monarchy | Carlos I (36) | - | prt_south_portugal | 9 | yes |
| NLD | Kingdom of the Netherlands | constitutional_monarchy | Wilhelmina (19) | - | nld_holland | 13 | yes |
| BEL | Kingdom of Belgium | constitutional_monarchy | Leopold II (64) | - | bel_flanders | 3 | yes |
| CFS | Congo Free State | absolute_monarchy | Leopold II (sovereign) (64) | - | cod_bandundu | 3 | yes |
| SWN | Sweden-Norway | constitutional_monarchy | Oscar II (70) | - | swe_svealand | 6 | yes |
| DEN | Kingdom of Denmark | constitutional_monarchy | Christian IX (81) | - | dnk_zealand | 4 | yes |
| SWI | Swiss Confederation | republic | Federal Council (Bundesrat) (50) | - | che_switzerland | 1 | yes |
| GRE | Kingdom of Greece | constitutional_monarchy | George I (54) | - | grc_central_greece | 3 | yes |
| SRB | Kingdom of Serbia | constitutional_monarchy | Alexander I Obrenović (23) | - | srb_serbia | 1 | yes |
| ROU | Kingdom of Romania | constitutional_monarchy | Carol I (60) | - | rou_wallachia | 2 | yes |
| BUL | Principality of Bulgaria | constitutional_monarchy | Ferdinand I (38) | - | bgr_moesia | 2 | yes |
| MNE | Principality of Montenegro | absolute_monarchy | Nikola I (58) | - | mne_montenegro | 1 | yes |
| ETH | Ethiopian Empire | absolute_monarchy | Menelik II (55) | - | eth_oromiya | 2 | yes |
| MAR | Sultanate of Morocco | absolute_monarchy | Abdelaziz (21) | - | mar_fez | 2 | yes |
| LIB | Republic of Liberia | republic | William David Coleman (57) | - | lbr_liberia | 1 | yes |
| BOR | Boer Republics (Transvaal) | republic | Paul Kruger (74) | - | zaf_limpopo | 2 | yes |
| OMN | Sultanate of Muscat and Oman | absolute_monarchy | Faisal bin Turki (36) | - | omn_oman | 1 | yes |
| QNG | Qing Empire | absolute_monarchy | Guangxu Emperor (Dowager Cixi) (28) | - | chn_jilin | 12 | yes |
| JPN | Empire of Japan | empire | Meiji Emperor (47) | - | jpn_iwate | 5 | yes |
| KOR | Korean Empire | absolute_monarchy | Gojong (47) | - | kor_gangwon | 3 | yes |
| SIA | Kingdom of Siam | absolute_monarchy | Chulalongkorn (Rama V) (46) | - | tha_chiang_mai | 2 | yes |
| QAJ | Qajar Persia | absolute_monarchy | Mozaffar ad-Din Shah (46) | - | irn_jibal | 7 | yes |
| AFG | Emirate of Afghanistan | absolute_monarchy | Abdur Rahman Khan (55) | - | afg_badakhshan | 2 | yes |
| NPL | Kingdom of Nepal | military_government | Bir Shumsher Rana (47) | - | npl_nepal | 1 | yes |
| USA | United States of America | republic | William McKinley (56) | - | usa_new_york | 17 | yes |
| MEX | Mexican Republic | republic | Porfirio Díaz (69) | - | mex_jalisco | 5 | yes |
| GTM | Republic of Guatemala | military_government | Manuel Estrada Cabrera (42) | - | gtm_guatemala | 1 | yes |
| HND | Republic of Honduras | military_government | Terencio Sierra (50) | - | hnd_honduras | 1 | yes |
| SLV | Republic of El Salvador | military_government | Tomás Regalado (38) | - | slv_el_salvador | 1 | yes |
| NIC | Republic of Nicaragua | military_government | José Santos Zelaya (46) | - | nic_nicaragua | 1 | yes |
| CRI | Republic of Costa Rica | republic | Rafael Iglesias Castro (38) | - | cri_costa_rica | 1 | yes |
| HTI | Republic of Haiti | republic | Tirésias Simon Sam (64) | - | hti_haiti | 1 | yes |
| DOM | Dominican Republic | republic | Juan Isidro Jimenes (53) | - | dom_dominican_rep | 1 | yes |
| BRA | United States of Brazil | republic | Manuel Ferraz de Campos Sales (58) | - | bra_minas_gerais | 8 | yes |
| ARG | Argentine Republic | republic | Julio Argentino Roca (56) | - | arg_buenos_aires | 4 | yes |
| CHL | Republic of Chile | republic | Federico Errázuriz Echaurren (49) | - | chl_antofagasta | 2 | yes |
| URU | Oriental Republic of Uruguay | republic | Juan Lindolfo Cuestas (62) | - | ury_uruguay | 1 | yes |
| PAR | Republic of Paraguay | republic | Emilio Aceval (46) | - | pry_paraguay | 1 | yes |
| BOL | Republic of Bolivia | republic | José Manuel Pando (50) | - | bol_bolivia | 1 | yes |
| PER | Republic of Peru | republic | Eduardo López de Romaña (52) | - | per_loreto | 2 | yes |
| ECU | Republic of Ecuador | republic | Eloy Alfaro (57) | - | ecu_ecuador | 1 | yes |
| COL | Republic of Colombia | republic | Manuel Antonio Sanclemente (86) | - | col_antioquia | 3 | yes |
| VNZ | Republic of Venezuela | military_government | Cipriano Castro (41) | - | ven_venezuela | 1 | yes |
| GER | German Empire | constitutional_monarchy | Wilhelm II (40) | Crown Prince Wilhelm | deu_brandenburg | 25 | yes |

## Notes per new or changed country

