# -*- coding: utf-8 -*-
"""Workstream E: military and naval overhaul strings."""
ENTRIES = []
def E(k, en, tr): ENTRIES.append((k, en, tr))

# tabs / sheet
E("TAB_FLEETS", "Fleets", "Filolar")
E("TAB_DOCTRINE", "Doctrine", "Doktrin")
E("MIL_DISCIPLINE", "Discipline", "Disiplin")
E("MIL_XP", "Exp.", "Tecr.")
E("MIL_SUPPLY", "Supply", "İkmal")
E("MIL_UPGRADE_BTN", "Upgrade {from} to {to} ({cost} gold)", "{from} birimini {to} birimine yükselt ({cost} altın)")
E("UPGRADE_ERR_NONE", "No better unit is available for this type.", "Bu tür için daha iyi bir birim yok.")
E("UPGRADE_ERR_PLACE", "Troops can only be improved on friendly ground (ships in a port).", "Birlikler yalnızca dost topraklarda (gemiler limanda) yükseltilebilir.")
E("NOTE_LANDING_REFUSED", "The landing at {province} was cancelled: the enemy controls the sea.", "{province} çıkarması iptal edildi: deniz düşmanın elinde.")
E("NOTE_CONVOY_INTERCEPTED", "A convoy was intercepted at sea and lost {pct}% of its ships and troops.", "Bir konvoy denizde durduruldu; gemilerinin ve askerlerinin %{pct} kadarını kaybetti.")
E("LANDING_ERR_NO_ESCORT", "A landing needs an escort fleet in port.", "Çıkarma için limanda bir eskort filosu gerekir.")
E("LANDING_ERR_SEA_CONTROL", "The enemy controls these waters; the landing would be hopeless.", "Bu sulara düşman hâkim; çıkarma umutsuz olurdu.")

# fleets tab
E("NAV_OVERVIEW", "Naval overview", "Deniz genel durumu")
E("NAV_TRANSPORT", "Transport capacity", "Nakliye kapasitesi")
E("NAV_TRANSPORT_TIP", "Regiments your ships can carry; also feeds your merchant marine.", "Gemilerinizin taşıyabileceği alay sayısı; ticaret filonuzu da besler.")
E("NAV_MERCHANT", "Merchant marine", "Ticaret filosu")
E("NAV_RAID_LOSS", "Trade lost to raiders", "Akıncılara kaybedilen ticaret")
E("NAV_RAID_TIP", "Share of your sea-borne trade income destroyed by enemy commerce raiders this turn.", "Düşman ticaret akıncıları tarafından bu tur yok edilen deniz ticareti gelirinizin payı.")
E("NAV_CONVOY", "Convoy escorts", "Konvoy eskortları")
E("NAV_CONVOY_TIP", "Escort strength in your ports' waters and the trade it saves.", "Limanlarınızın sularındaki eskort gücü ve kurtardığı ticaret.")
E("NAV_BLOCKADED", "Blockaded ports", "Abluka altındaki limanlar")
E("NAV_NONE", "none", "yok")
E("NAV_LOOTED", "Captured from raiding", "Baskınlarla ele geçirilen")
E("NAV_RAIDED", "Lost to raiding", "Baskınlarda kaybedilen")
E("NAV_SEA_CONTROL", "Sea control (yours / enemy)", "Deniz hâkimiyeti (sizin / düşman)")
E("NAV_SEA_CONTROL_TIP", "Influence of fleets and ports in this sea.", "Bu denizdeki filo ve liman etkisi.")
E("NAV_NO_FLEETS", "You have no fleets. Build ships in a port.", "Hiç filonuz yok. Bir limanda gemi inşa edin.")
E("NAV_FLAGSHIP", "Flagship", "Amiral gemisi")
E("NAV_SQUADRONS", "Squadrons", "Filotillalar")
E("NAV_NO_ADMIRAL", "No admiral", "Amiral yok")
E("NAV_AT_SEA", "Away from port", "Limandan uzakta")
E("NAV_AT_SEA_FMT", "{n} turns, supply {supply}%", "{n} tur, ikmal %{supply}")
E("NAV_SPLIT_ROLES", "Split by role", "Göreve göre ayır")
E("MISSION_PATROL", "Patrol", "Devriye")
E("MISSION_BLOCKADE", "Blockade", "Abluka")
E("MISSION_RAID", "Raid trade", "Ticaret baskını")
E("MISSION_CONVOY", "Convoy", "Konvoy")
E("MISSION_PATROL_TIP", "Balanced: some escort and raiding value, ready to fight.", "Dengeli: bir miktar eskort ve baskın değeri, savaşa hazır.")
E("MISSION_BLOCKADE_TIP", "Closes the port the fleet sits in if strong enough.", "Yeterince güçlüyse bulunduğu limanı kapatır.")
E("MISSION_RAID_TIP", "Hunts enemy merchants in the sea around its position.", "Bulunduğu denizde düşman tüccar gemilerini avlar.")
E("MISSION_CONVOY_TIP", "Escorts your merchants and transports against raiders.", "Tüccar ve nakliye gemilerinizi akıncılara karşı korur.")
for r, en, tr in [("LINE", "Battle line", "Hat gemileri"), ("CRUISER", "Cruisers", "Kruvazörler"), ("RAIDER", "Raiders", "Akıncılar"), ("GALLEY", "Galleys", "Kadırgalar"), ("TRANSPORT", "Transports", "Nakliye")]:
    E("ROLE_" + r, en, tr)

# doctrines
E("DOC_SLOT_LAND", "Land doctrine", "Kara doktrini")
E("DOC_SLOT_NAVAL", "Naval doctrine", "Deniz doktrini")
E("DOC_ADOPT", "Adopt ({cost} gold)", "Benimse ({cost} altın)")
E("DOC_REQUIRES", "Requires: {req}", "Gerekir: {req}")
E("DOC_RETRAINING", "The troops are retraining: half effect for a few turns.", "Birlikler yeniden eğitiliyor: birkaç tur yarı etki.")
E("DOC_ERR_SAME", "This doctrine is already in force.", "Bu doktrin zaten yürürlükte.")
E("DOC_ERR_LOCKED", "Research the required technologies first.", "Önce gerekli teknolojileri araştırın.")
E("DOC_ERR_COOLDOWN", "Doctrine changed recently; wait {n} more turns.", "Doktrin yakın zamanda değişti; {n} tur daha bekleyin.")
E("HIST_DOCTRINE", "Adopted a new military doctrine", "Yeni bir askerî doktrin benimsendi")

# battle report
E("BR_FACTORS", "Factor", "Etken")
E("BR_COMMANDER", "Commander", "Komutan")
E("BR_NAVAL", "Sea battle", "Deniz savaşı")
E("BR_SEA_STATE", "sea state {n}%", "deniz durumu %{n}")
E("BR_RIVER", "river crossing: {name} (width {w})", "nehir geçişi: {name} (genişlik {w})")
E("BR_RIVER_UNNAMED", "river", "nehir")
E("BR_PASS", "mountain pass: {name}", "dağ geçidi: {name}")
E("BR_PASS_UNNAMED", "pass", "geçit")
E("BR_INCLUDED_TIP", "Already counted inside the unit strength; shown to explain its weight.", "Birim gücünün içinde zaten sayılır; ağırlığını göstermek için listelenir.")
E("BR_EVENT_DIED", "{name} of {country} was killed.", "{country} komutanı {name} öldü.")
E("BR_EVENT_CAPTURED", "{name} of {country} was captured and ransomed.", "{country} komutanı {name} esir alındı ve fidyeyle bırakıldı.")
E("BR_EVENT_PROMOTED", "{name} of {country} gained a level.", "{country} komutanı {name} seviye atladı.")

# battle factors
for k, en, tr in [("FACTOR_RIVER", "River crossing", "Nehir geçişi"), ("FACTOR_PASS", "Mountain pass", "Dağ geçidi"),
                  ("FACTOR_DISCIPLINE", "Discipline", "Disiplin"), ("FACTOR_EXPERIENCE", "Experience", "Tecrübe"),
                  ("FACTOR_DOCTRINE", "Doctrine", "Doktrin"), ("FACTOR_AMPHIB", "Landing from the sea", "Denizden çıkarma"),
                  ("FACTOR_ADMIRAL", "Admiral's skill", "Amiralin yeteneği"), ("FACTOR_WIND", "Wind and sea", "Rüzgâr ve deniz"),
                  ("FACTOR_SHIPS", "Ship types", "Gemi türleri")]:
    E(k, en, tr)

# modifiers used by doctrines
for k, en, tr in [("PURSUIT", "Pursuit", "Takip"), ("DISCIPLINE", "Discipline", "Disiplin"), ("ANTI_CAV", "Anti-cavalry", "Süvariye karşı koyuş"),
                  ("RIVER_PEN", "River-crossing penalty", "Nehir geçişi cezası"), ("RAID", "Commerce raiding", "Ticaret baskını"),
                  ("CONVOY", "Convoy protection", "Konvoy koruması"), ("BLOCKADE", "Blockade strength", "Abluka gücü"),
                  ("NAVY_UPKEEP", "Navy upkeep", "Donanma masrafı"), ("NAVAL_MORALE", "Naval morale", "Deniz morali")]:
    E("MOD_" + k, en, tr)

# commander traits
for k, en, tr in [("AGGRESSIVE", "Aggressive", "Saldırgan"), ("STEADFAST", "Steadfast", "Sebatkâr"), ("CAUTIOUS", "Cautious", "Temkinli"),
                  ("SIEGE_MASTER", "Siege master", "Kuşatma ustası"), ("LOGISTICIAN", "Logistician", "İkmal ustası"), ("INSPIRING", "Inspiring", "İlham verici"),
                  ("CAVALRY_MASTER", "Cavalry master", "Süvari ustası"), ("ARTILLERIST", "Artillerist", "Topçu"), ("MOUNTAIN_FIGHTER", "Mountain fighter", "Dağ savaşçısı"),
                  ("BRIDGE_BUILDER", "Bridge builder", "Köprü ustası"), ("RECKLESS", "Reckless", "Pervasız"), ("VETERAN", "Veteran", "Gazi"),
                  ("BRILLIANT", "Brilliant", "Parlak"), ("INCOMPETENT", "Incompetent", "Beceriksiz"), ("SEA_DOG", "Sea dog", "Deniz kurdu"),
                  ("GUNNERY_EXPERT", "Gunnery expert", "Topçuluk uzmanı"), ("BOARDING_MASTER", "Boarding master", "Abordaj ustası"),
                  ("RAIDER", "Raider", "Akıncı"), ("BLOCKADER", "Blockader", "Ablukacı"), ("CONVOY_MASTER", "Convoy master", "Konvoy ustası")]:
    E("TRAIT_" + k, en, tr)
E("TERRAIN_SEA", "Open sea", "Açık deniz")
