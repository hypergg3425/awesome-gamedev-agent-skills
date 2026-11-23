# Historical sources

Status: **v2.0 audit snapshot.** This file lists only sources that are actually recorded in the project data, plus the limitations of that data. A full scholarly source bibliography per scenario (rulers, borders, political structure) has **not** been compiled yet — see VERSION_2_AUDIT.md §Historical inaccuracies.

## Geography

* Province geometry and sea zones: Natural Earth (admin-0 50m, admin-1 10m, geography regions 10m, marine polys 10m, land 50m, lakes 50m) — public domain (https://www.naturalearthdata.com). Processed by `tools/gen_map_step1.py` / `gen_map_step2.py`.
* **Limitation:** these are *modern* administrative regions grouped into 410 gameplay provinces. They are not reconstructions of historical borders for any of the dates. Province display names are modern/regional, not scenario-specific historical names. Access dates were not recorded when the data was fetched.

## Scenarios (data/scenarios/*.json)

### Age of Revolutions (age_of_revolutions.json) — start 1789-07, `approximate: True`

Author's own note in the data: Borders are approximated on modern-geometry regions: each region stands in for the realm that held most of it in 1789 (e.g. 'Madhya Pradesh' for the Delhi-Agra heartland, 'Nagano' for the Kansai core of Tokugawa Japan). Rulers, ages and abilities are best-effort. Small states (Hesse, Württemberg, the Rhenish electors, Hyderabad, Nepal, the Gulf sheikhdoms and most of Africa) are merged into neighbours or shown as native states. Spanish and Portuguese American colonies are ordinary provinces of their mother countries; Saint-Domingue is a French vassal.

### Early Modern Europe (early_modern.json) — start 1519-06, `approximate: True`

Author's own note in the data: Borders are approximated on modern-geometry regions: one region stands for a historical realm that never matched it exactly (e.g. 'Hesse & Thuringia' for Electoral Saxony, or four regions for the whole of Sengoku Japan). Rulers, ages and abilities are best-effort estimates. Naples is shown as a Habsburg vassal, Milan as French, and minor realms such as Gujarat, Bengal, Songhai, Burma or the Maya cities are not modelled: their lands appear as native states. The Americas are shown at the moment of first contact.

### Fall of Constantinople (fall_of_constantinople.json) — start 1453-04, `approximate: True`

Author's own note in the data: Borders are approximated on modern-geometry regions: Byzantium is reduced to the Constantinople region and the Morea, Granada is represented by the Andalusia region, Navarre is folded into Aragon, and the Timurids, Hafsids, Marinids, Novgorod, Bosnia, Cyprus and Savoy are not modelled and appear as native states. Poland and Lithuania are in personal union under Casimir IV, and Aragon and Naples under Alfonso V. Rulers, ages and abilities are best-effort estimates.

### Hundred Years' War (hundred_years_war.json) — start 1337-05, `approximate: True`

Author's own note in the data: Borders are approximated on modern-geometry regions: Gascony is shown as 'Aquitaine & Gascony', Avignon stands for the papal court (Provence is shown as papal), Granada is represented by the Andalusia region, and the Ottoman beylik by a single region. Rulers, ages and abilities are best-effort estimates. Galicia-Volhynia, Ireland outside Leinster, Wales' princes, the Anatolian beyliks, Persia, Ifriqiya, Savoy and Sicily's neighbours beyond those listed appear as native states.

### Industrial Era (industrial_era.json) — start 1871-01, `approximate: True`

Author's own note in the data: Borders are approximated on modern-geometry regions, so a region may only roughly match the realm that held it in 1871 (e.g. 'Madhya Pradesh' stands for British-ruled northern India, 'Nagano' for the Japanese core). The 1871 colonial picture is approximate: the scramble for Africa has not begun, so most of the continent is shown as native states, and princely India is folded into the British Raj. Rulers, ages and abilities are best-effort estimates, and a few minor states (Hawaii, the Zulu, Ashanti, Sokoto, the Boer Orange Free State) are not modelled. Alsace and Lorraine begin French while the war is still being fought.

### Medieval Europe (medieval_europe.json) — start 1066-09, `approximate: True`

Author's own note in the data: Borders are approximated on modern-geometry regions: Zaragoza and Valencia, the Italian marches, Hammadid Algeria and Armenian Cilicia cannot be drawn exactly, Castile-León-Galicia is shown united although Ferdinand I's sons had just partitioned it, and the Almoravids are shown holding Marrakesh before its 1070 founding. Rulers, ages and abilities are best-effort estimates. Wales, Brittany, Connacht, Ulster, Sardinia, the Baltic and Wendish tribes, Croatia, Duklja and the Cumans are not modelled and appear as native states.

### World Conquest (world_conquest.json) — start 1900-01, `approximate: True`

Author's own note in the data: This is an explicitly FICTIONAL, alternate-history world-conquest sandbox, not a historical scenario. It is built on approximate 1900 borders, cut into modern-geometry regions, so every region is assigned to the nearest plausible power (e.g. Luxembourg to Belgium, Arabia's interior to the Ottomans, Cuba to the United States as occupier, the Congo Free State shown separately). Rulers, ages and abilities are best-effort; colonial and protectorate arrangements are simplified, and princely states, small kingdoms and chiefdoms are merged into their overlords. Nothing here should be read as a claim about what was or should have been.

## Historical events and their recorded sources

Every event flagged `historical: true` carries a `source` string (dated reference). Random events carry none and are labelled random in the UI. The `source` strings are citations of events/documents as the data author recorded them; they were **not independently re-verified** in the v2.0 audit.

### hist_constantinople.json (10 historical events)

* `cp_gutenberg` — Gutenberg Bible, Mainz, c. 1454-1455 (Helmasperger notarial instrument, 1455)
* `cp_siege` — Siege of Constantinople, 6 April - 29 May 1453 (Doukas; Sphrantzes; Nicolò Barbaro; Tursun Beg)
* `cp_fall` — Fall of Constantinople, 29 May 1453 (Doukas; Sphrantzes; Kritovoulos; Leonard of Chios)
* `cp_castillon` — Battle of Castillon, 17 July 1453 (Mathieu d'Escouchy; Jean Chartier)
* `cp_stalbans` — First Battle of St Albans, 22 May 1455 (Paston Letters; Whethamstede Register)
* `cp_lodi` — Peace of Lodi, 9 April 1454; Italic League, 30 August 1454 (treaty texts; Guicciardini, Storia d'Italia)
* `cp_belgrade` — Siege of Belgrade, 4-22 July 1456 (letters of John of Capistrano; Kritovoulos)
* `cp_albulena` — Battle of Albulena, 2 September 1457 (Marin Barleti, Historia de vita et gestis Scanderbegi)
* `cp_morea` — Ottoman conquest of the Morea, 1458-1460; surrender of Mistra, 29 May 1460 (Kritovoulos; Chalkokondyles)
* `cp_trebizond` — Fall of Trebizond, August 1461 (Kritovoulos; Chalkokondyles)

### hist_early_modern.json (13 historical events)

* `em_imperial_election` — Imperial election of 1519, Frankfurt, 28 June 1519
* `em_tenochtitlan_azt` — Fall of Tenochtitlan, 13 August 1521
* `em_tenochtitlan_spa` — Fall of Tenochtitlan, 13 August 1521
* `em_worms` — Diet of Worms, 17-18 April 1521; Edict of Worms, 25 May 1521
* `em_prussia_secular` — Treaty of Kraków, 8 April 1525 (Prussian Homage)
* `em_panipat` — First Battle of Panipat, 21 April 1526
* `em_mohacs` — Battle of Mohács, 29 August 1526
* `em_sack_rome` — Sack of Rome, 6 May 1527
* `em_vienna` — First Siege of Vienna, 27 September - 15 October 1529
* `em_henry_rome` — Act of Supremacy, November 1534
* `em_augsburg` — Peace of Augsburg, 25 September 1555
* `em_lepanto` — Battle of Lepanto, 7 October 1571
* `em_armada` — Spanish Armada, July-August 1588

### hist_hyw.json (11 historical events)

* `hyw_guyenne` — Confiscation of Guyenne, 24 May 1337 (Rymer, Foedera; Froissart)
* `hyw_french_title` — Edward III assumes the arms and title of King of France, Ghent, 26 January 1340 (Rymer, Foedera)
* `hyw_crecy` — Battle of Crécy, 26 August 1346 (Froissart; Jean le Bel)
* `hyw_black_death` — Black Death in Europe, 1347-1351 (Boccaccio, Decameron; Gabriele de' Mussi)
* `hyw_poitiers` — Battle of Poitiers, 19 September 1356 (Froissart; Chandos Herald)
* `hyw_bretigny` — Treaty of Brétigny, 8 May 1360, ratified at Calais 24 October 1360 (Rymer, Foedera)
* `hyw_peasants` — Peasants' Revolt, May-June 1381 (Anonimalle Chronicle; Froissart)
* `hyw_kosovo` — Battle of Kosovo, 15 June 1389 (Mehmed Neşri; Serbian chronicle tradition)
* `hyw_nicopolis` — Battle of Nicopolis, 25 September 1396 (Froissart; Johann Schiltberger)
* `hyw_grunwald` — Battle of Grunwald (Tannenberg), 15 July 1410 (Jan Długosz; Johann von Posilge)
* `hyw_agincourt` — Battle of Agincourt, 25 October 1415 (Gesta Henrici Quinti; Monstrelet)

### hist_industrial.json (12 historical events)

* `ind_frankfurt` — Treaty of Frankfurt, 10 May 1871
* `ind_commune` — Paris Commune, 18 March - 28 May 1871
* `ind_haihan` — Abolition of the han and creation of prefectures, 29 August 1871
* `ind_suez_shares` — Purchase of the Khedive's Suez Canal shares, November 1875
* `ind_berlin_congress` — Congress of Berlin, 13 June - 13 July 1878
* `ind_berlin_conference` — Berlin Conference, 15 November 1884 - 26 February 1885
* `ind_shimonoseki` — Treaty of Shimonoseki, 17 April 1895
* `ind_fashoda` — Fashoda Incident, 18 September - 3 November 1898
* `ind_spanish_american` — Spanish-American War, 21 April - 13 August 1898
* `ind_russojapanese` — Battle of Tsushima, 27-28 May 1905; Treaty of Portsmouth, 5 September 1905
* `ind_young_turks` — Young Turk Revolution, 24 July 1908
* `ind_sarajevo` — Assassination of Archduke Franz Ferdinand, Sarajevo, 28 June 1914

### hist_medieval.json (10 historical events)

* `medieval_stamford_bridge` — Battle of Stamford Bridge, 25 September 1066 (Anglo-Saxon Chronicle)
* `medieval_hastings_eng` — Battle of Hastings, 14 October 1066 (Bayeux Tapestry; Anglo-Saxon Chronicle)
* `medieval_hastings_nrm` — Battle of Hastings, 14 October 1066 (Bayeux Tapestry; William of Poitiers)
* `medieval_harrying` — Harrying of the North, winter 1069-1070 (Domesday Book; Orderic Vitalis)
* `medieval_domesday` — Domesday Book, 1085-1086 (Anglo-Saxon Chronicle)
* `medieval_manzikert` — Battle of Manzikert, 26 August 1071 (Attaleiates; Skylitzes Continuatus)
* `medieval_canossa` — Walk to Canossa, January 1077 (Lampert of Hersfeld; Gregory VII, Registrum)
* `medieval_toledo` — Capture of Toledo, 25 May 1085 (Historia Roderici; Crónica Najerense)
* `medieval_palermo` — Siege and capture of Palermo, 1071-1072 (Geoffrey Malaterra)
* `medieval_clermont` — Council of Clermont, 27 November 1095 (Fulcher of Chartres; Robert the Monk)

### hist_revolutions.json (12 historical events)

* `rev_bastille` — Storming of the Bastille, 14 July 1789
* `rev_us_funding` — Report on Public Credit, January 1790
* `rev_haiti` — Slave uprising in Saint-Domingue, 22 August 1791 (Bois Caïman)
* `rev_louis_xvi` — Execution of Louis XVI, 21 January 1793
* `rev_partition_1793` — Second Partition of Poland, 23 January 1793
* `rev_napoleon` — Coronation of Napoleon I, 2 December 1804
* `rev_trafalgar` — Battle of Trafalgar, 21 October 1805
* `rev_continental_system` — Berlin Decree (Continental System), 21 November 1806
* `rev_waterloo` — Battle of Waterloo, 18 June 1815
* `rev_vienna` — Congress of Vienna, September 1814 - June 1815
* `rev_ayacucho` — Battle of Ayacucho, 9 December 1824
* `rev_1848` — Revolutions of 1848, February-March 1848


Total historical events with source: 68

## Not yet done (required by the v2.0 brief)
* Per-scenario bibliography of rulers, dynasties, capitals, political structure and starting dates.
* Scenario-specific historical province names and geometry.
* Documentation of access dates and licences for historical (non-geometry) sources.
