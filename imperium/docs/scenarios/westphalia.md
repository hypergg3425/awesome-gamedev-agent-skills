# The Peace of Westphalia (`westphalia`, start July 1648)

Files: `data/scenarios/westphalia.json`, `data/events/hist_westphalia.json` (14 historical events), `data/events/random_westphalia.json` (4 random events). 62 named polities; `province_names` carries 129 scenario-specific EN/TR names. Era 2, default player Sweden, turn limit 160, territory victory at 10 %.

## Setting
July 1648: the envoys at Münster and Osnabrück are about to sign; the Swedes have just taken Prague's Little Side (26 Jul), France and Spain are at war (Spanish-Dutch peace ratified in May 1648, so a long truce is set), the Catalan and Portuguese revolts continue, Khmelnytsky's uprising has begun and Władysław IV is dead (interregnum), Charles I is a prisoner and the Scots invade England (8 Jul), Sultan Ibrahim is about to be deposed (8 Aug), Ming-Qing war continues in the south.

## Documented vs estimated
Documented: rulers, regnal periods and birth years behind the ages (Ferdinand III 1608, Maximilian I 1573, Frederick William 1620, Christina 1626, Louis XIV 1638, Philip IV 1605, John IV 1604, Frederick III of Denmark 1609, William II of Orange 1626, Mehmed IV 1642, Abbas II 1632, Shah Jahan 1592, Alexis 1629, Bohdan Khmelnytsky c. 1595, Injo 1595, Güshi Khan 1582, Sulinya Vongsa, Fasilides ...), the war alignments, Savoy and Lorraine's situations, the 1648 treaty terms used in event texts, and the commanders named in armies (Wrangel, Königsmarck, Condé, Turenne, Gronsfeld, Melander, Archduke Leopold Wilhelm, Owen Roe O'Neill, Cromwell, Fairfax, Lambert, Hamilton).
Estimates: all ability scores, treasuries, regiment compositions, generals' tac/log/siege, stability, civ/military levels, opinions, claims and objective thresholds. Population and development are generated from modern geometry, not historical.

## Representation choices and limits
* The Empire is represented by the Habsburg monarchy plus Bavaria, Saxony, Brandenburg, Hesse-Kassel, Württemberg, Brunswick-Lüneburg, Mecklenburg and the Rhenish ecclesiastical states (one region, with the Palatinate folded in). Münster, Cleves, Baden, the Saxon duchies, the Free Cities and the Palatinate are not separate.
* Territorial changes of the Peace (Swedish Pomerania/Bremen, French Alsace, Brandenburg's Farther Pomerania, Swiss exemption) are not pre-applied. They appear as claims and wars, with `wp_peace`, `wp_brandenburg`, `wp_swiss` as decision events; events cannot transfer provinces.
* `fra_alsace` starts Habsburg with a French claim; `fra_lorraine` is the exiled Charles IV's Lorraine under a French war.
* England is Parliament and the Army: ruler Charles I (captive), heir Cromwell, so `kill_ruler` in `wp_charles_trial` models the regicide and the Army's government (the game cannot change the government form). The Second Civil War is not modelled; the Scots (Engager regime) and Confederate Ireland are.
* Poland-Lithuania starts in interregnum: the ruler is the Interrex (Łubieński), the heir John Casimir; `wp_poland_election` (Nov 1648) uses `kill_ruler` to install him.
* France: Louis XIV (9) with the regency of Anne of Austria and Mazarin; the Fronde starts as `wp_fronde`.
* Region stand-ins: `chn_jilin` for the Qing heartland, `chn_hunan`/`chn_sichuan` for Qing-held centre (Sichuan was in chaos), `chn_guangxi`/`chn_yunnan` for Southern Ming; Golconda has no region; `idn_jawa_timur` is Mataram (Dutch Batavia is unmodelled); `lka_sri_lanka` is Dutch with Kandy not separate.
* Weakest data: Maghrebi regimes (Algiers dey and Tunis bey are not reliably named), Morocco's fragmentation, Tüsheet Khan, Erdeni Batur's age, Jahangir Khan, Abd al-Aziz of Bukhara, Pindale's age, Ramathipadi's age, the Nguyễn succession in 1648, Cambodia, Aceh, Omani Imam, Yemen's Imam.

## Events
| id | window | scope | sources |
|---|---|---|---|
| wp_prague | 1648-07 .. 12 | SWE HAB | Theatrum Europaeum; Wilson; Parker |
| wp_ibrahim | 1648-07 .. 12 | OTT | Naima; Finkel; Faroqhi |
| wp_candia | 1648-07 .. 1649-06 | OTT VEN | Setton; Finkel |
| wp_lens | 1648-07 .. 12 | FRA SPA | Lynn; Wilson |
| wp_fronde | 1648-07 .. 1649-03 | FRA | Retz; Moote |
| wp_peace | 1648-07 .. 1649-06 | 12 powers | Instrumenta Pacis; Croxton; Wilson |
| wp_brandenburg | 1648-08 .. 1649-03 | BRA | IPO art. X-XI; Clark |
| wp_swiss | 1648-08 .. 1649-06 | SWI | HLS; IPO art. VI |
| wp_pilyavtsi | 1648-07 .. 1649-03 | HET POL CRI | Frost; Plokhy; Subtelny |
| wp_poland_election | 1648-08 .. 1649-03 | POL | Frost; Davies |
| wp_ulozhenie | 1648-07 .. 1649-06 | RUS | Hellie; Kollmann |
| wp_charles_trial | 1648-10 .. 1649-03 | ENG | Gardiner; Kishlansky |
| wp_luanda | 1648-07 .. 1649-03 | POR | Boxer; Israel |
| wp_kandahar | 1648-10 .. 1649-06 | SAF MUG | Cambridge History of Iran VI; Richards |
| wp_rnd_mutiny, wp_rnd_typhus, wp_rnd_refugees, wp_rnd_mercenary_offer | random | various | n/a |

## Sources
Access date 2026-11-23; the network was restricted during authoring (no page could be fetched) so all dates come from the author's knowledge of these works and were not re-verified. Event `source` strings are best-effort citations.
* Peter H. Wilson, *Europe's Tragedy: A History of the Thirty Years War* (Allen Lane, 2009). Published book.
* Geoffrey Parker (ed.), *The Thirty Years' War* (Routledge, 1984). Published book.
* Derek Croxton, *Westphalia: The Last Christian Peace* (Palgrave, 2013). Published book.
* Instrumentum Pacis Osnabrugense / Monasteriense (1648), public-domain treaty texts.
* Christopher Clark, *Iron Kingdom* (Allen Lane, 2006); John Lynn, *The Wars of Louis XIV* (Longman, 1999); Jonathan Israel, *The Dutch Republic* (Oxford, 1995). Published books.
* Robert Frost, *The Oxford History of Poland-Lithuania*, vol. 1 (Oxford, 2015); Serhii Plokhy, *The Gates of Europe* (Basic Books, 2015); Orest Subtelny, *Ukraine: A History* (Toronto, 1988). Published books.
* S. R. Gardiner, *History of the Great Civil War* (public domain); Mark Kishlansky, *A Monarchy Transformed* (Penguin, 1996).
* Caroline Finkel, *Osman's Dream* (John Murray, 2005); Suraiya Faroqhi, *The Ottoman Empire and the World Around It* (I. B. Tauris, 2004); Kenneth Setton, *Venice, Austria and the Turks in the Seventeenth Century* (American Philosophical Society, 1991).
* Richard Hellie, *Enserfment and Military Change in Muscovy* (Chicago, 1971); Nancy Kollmann, *The Russian Empire 1450-1801* (Oxford, 2017).
* C. R. Boxer, *Salvador de Sá and the Struggle for Brazil and Angola* (Athlone, 1952); John F. Richards, *The Mughal Empire* (Cambridge, 1993); *The Cambridge History of Iran* vol. 6.
* Province geometry: Natural Earth (public domain). Scenario text, Turkish translations and all numbers: original work for this project.
