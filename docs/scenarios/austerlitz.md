# The Eve of Austerlitz (`austerlitz`, start September 1805)

Files: `data/scenarios/austerlitz.json`, `data/events/hist_austerlitz.json` (15 historical events), `data/events/random_austerlitz.json` (4 random events). 43 named polities; `province_names` carries 106 scenario-specific EN/TR names. Era 3, default player France, turn limit 160, territory victory at 10 %.

## Setting
September 1805: Napoleon has broken camp at Boulogne; Austria has invaded Bavaria; the Third Coalition (Britain, Austria, Russia, Sweden) is at war with France and its allies (Spain, Italy, Bavaria, Württemberg). Prussia is neutral and Naples has just signed a neutrality treaty with France. Elsewhere: the Serbian Uprising, Haiti's independence, the Wahhabi Emirate in the Hejaz, Muhammad Ali's rise in Egypt, the Russo-Persian war and the Second Maratha War.

## Documented vs estimated
Documented: rulers and birth years behind the ages (Napoleon 1769, Francis II 1768, Alexander I 1777, Frederick William III 1770, George III 1738, Selim III 1761, Fath-Ali Shah 1772, Gia Long 1762, Jefferson 1743, Ranjit Singh 1780, Dessalines c. 1758 ...), dynastic and alliance structure (e.g. Bavaria's treaty with France in Aug 1805), the Kingdom of Italy (May 1805), the annexation of Liguria (June 1805), the Batavian Republic under Schimmelpenninck (April 1805), the British protectorate over Shah Alam II, and the named commanders (Mack, Archduke Charles and John, Kutuzov, Buxhoeveden, Tsitsianov, Masséna, Mortier, Nelson, Gravina, Villeneuve, Lake, Moore, Abbas Mirza, Blücher, Brunswick).
Estimates: ability scores, treasuries, regiment counts, generals' tac/log/siege, stability, civ/military levels, opinion values, claims and objective thresholds; population and development are generated from modern geometry.

## Representation choices and limits
* Left-bank Rhineland and the Belgian regions are French; Hanover is French-occupied (they held it until Oct 1805; Prussia receives it in 1806 through diplomacy, not as a start holding).
* Austria includes Venetia and Dalmatia (lost at Pressburg) and Tyrol (lost to Bavaria); Pressburg's changes are not pre-applied (events cannot transfer provinces) but appear as `au_pressburg` decision and claims.
* Prussia holds Warsaw, Posen and West Prussia (Polish partitions); the Swedish Pomerania region is `deu_mecklenburg`.
* The East India Company is folded into the British state; Mysore is shown as British (it was a Company-protected princely state); Hyderabad, Nepal, Nassau, Baden, Hesse-Darmstadt, Ragusa, the Hanseatic cities and the Ionian Islands are not modelled.
* The Cape Colony is Batavian; `au_cape` models the January 1806 expedition.
* `chn_*` regions stand in for Qing China; Tibet and Xinjiang are Qing-held.
* Weakest data: the Algiers dey and the Ottoman Rumelian commander are unnamed or uncertain; the Prince Regent of Portugal's heir, the Mughal heir and some ages are approximate; native-state fallback covers sub-Saharan Africa and most of the Americas.
* Wars at start: the whole coalition is at war with the French camp from turn 0 (Russia and Sweden had not yet engaged; Britain and Spain were already at war), plus Russia-Persia, Serbia-Ottomans, Britain-Marathas, Ottomans-Wahhabis.

## Events
| id | window | scope | sources |
|---|---|---|---|
| au_boulogne | 1805-08 .. 12 | FRA | Chandler; Esdaile |
| au_ulm_fra / au_ulm_aut | 1805-08 .. 12 | FRA / AUT | Chandler; Rothenberg |
| au_trafalgar | 1805-08 .. 12 | GBR FRA SPA | Lavery; Adkin |
| au_vienna | 1805-08 .. 1806-01 | AUT | Chandler; Duffy |
| au_austerlitz | 1805-08 .. 1806-01 | FRA RUS AUT | Chandler; Duffy; Goetz |
| au_potsdam | 1805-09 .. 1806-06 | PRU | Clark; Sked |
| au_pressburg | 1805-10 .. 1806-06 | AUT FRA BAV WUR | Martens; Rothenberg |
| au_naples | 1805-09 .. 1806-06 | NAP | Davis; Esdaile |
| au_serbia | 1805-07 .. 1806-12 | SRB OTT | Ranke; Stavrianos |
| au_lewis_clark | 1805-09 .. 1806-09 | USA | Moulton; Ambrose |
| au_cape | 1805-09 .. 1806-03 | GBR NLD | Theal; Ross |
| au_pitt_dies | 1805-11 .. 1806-06 | GBR | Ehrman; Mori |
| au_confed_rhine | 1806-04 .. 12 | BAV WUR HES | Martens; Wilson |
| au_hre_end | 1806-04 .. 12 | AUT | Wilson; Rothenberg |
| au_rnd_subsidy, au_rnd_conscription, au_rnd_requisitions, au_rnd_privateers | random | various | n/a |

Dates used: Ulm capitulation 20 Oct, Trafalgar 21 Oct, Vienna occupied 13 Nov, Austerlitz 2 Dec, Pressburg 26 Dec 1805, Pitt's death 23 Jan 1806, Blaauwberg 8 Jan 1806, Confederation of the Rhine 12 Jul 1806, end of the Holy Roman Empire 6 Aug 1806.

## Sources
Access date 2026-11-23; no network page could be fetched during authoring, so dates and figures are from the author's knowledge of the works below and are best-effort, not re-verified.
* David G. Chandler, *The Campaigns of Napoleon* (Macmillan, 1966); Charles Esdaile, *Napoleon's Wars: An International History* (Allen Lane, 2007); Christopher Duffy, *Austerlitz 1805* (Cassell, 1977); Robert Goetz, *1805: Austerlitz* (Greenhill, 2005); Gunther Rothenberg, *The Art of Warfare in the Age of Napoleon* (Batsford, 1977) and *Napoleon's Great Adversaries* (Batsford, 1982). Published books.
* Christopher Clark, *Iron Kingdom* (2006); Peter H. Wilson, *The Holy Roman Empire: A Thousand Years of Europe's History* (Allen Lane, 2016); Alan Sked, *The Survival of the Habsburg Empire* (Longman, 1989). Published books.
* John Ehrman, *The Younger Pitt* (Constable, 1969-96); Roger Knight/Peter Lavery on Trafalgar (*Nelson's Navy*, Lavery, 1989; *The Trafalgar Companion*, Adkin, 2005).
* John A. Davis, *Naples and Napoleon* (Oxford, 2006); George McCall Theal, *History of South Africa* (public domain).
* Leopold von Ranke, *A History of Servia* (public domain); Leften Stavrianos, *The Balkans since 1453* (1958).
* *The Journals of the Lewis and Clark Expedition*, ed. Gary Moulton (Nebraska, 1983-2001); Stephen Ambrose, *Undaunted Courage* (1996).
* G. F. de Martens, *Recueil des traités* (public domain treaty texts).
* Province geometry: Natural Earth (public domain). Scenario text, Turkish translations and all numbers: original work for this project.
