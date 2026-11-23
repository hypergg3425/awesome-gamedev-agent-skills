# -*- coding: utf-8 -*-
from s1_ui import S, E

# --- military ---------------------------------------------------------------------------------------------------
E("MIL_REGIMENTS", "Land regiments", "Kara alayları"); E("MIL_SHIPS", "Ship squadrons", "Gemi filoları"); E("MIL_MANPOWER", "Manpower", "İnsan gücü")
E("MIL_UPKEEP", "Upkeep per turn", "Tur başına masraf"); E("MIL_NO_ARMIES", "You have no armies.", "Hiç ordunuz yok."); E("MIL_AT_SEA", "At sea", "Denizde")
E("MIL_MORALE", "Morale", "Moral"); E("MIL_GENERAL", "General", "Komutan"); E("MIL_NO_GENERAL", "No general", "Komutan yok")
E("MIL_ORDERS", "Orders", "Emirler"); E("MIL_MOVING_TO", "Moving to {to}", "{to} eyaletine ilerliyor"); E("MIL_IN_TRANSIT", "Sailing to {to} ({n} turns)", "{to} eyaletine yelken açtı ({n} tur)")
E("MIL_DISBAND", "Disband", "Dağıt"); E("MIL_DISBAND_CONFIRM", "Disband this army? Part of the manpower returns to your pool.", "Bu ordu dağıtılsın mı? İnsan gücünün bir kısmı havuza döner.")
E("MIL_MERGE", "Merge", "Birleştir"); E("MIL_SPLIT", "Split", "Böl"); E("MIL_SPLIT_HINT", "How many regiments should form a new army?", "Kaç alay yeni bir ordu oluştursun?")
E("MIL_SELECT", "Select / give orders", "Seç / emir ver"); E("MIL_SELECTED", "Selected", "Seçili"); E("MIL_STOP", "Stop", "Durdur")
E("MIL_RECRUIT_HERE", "Recruit here", "Burada asker topla"); E("MIL_RECRUIT_AT", "Recruiting in", "Asker toplanan eyalet"); E("MIL_QUEUE", "In training", "Eğitimde")
E("MIL_RECRUIT_HINT", "Select one of your provinces on the map to recruit there. Ships need a port.", "Orada asker almak için haritada eyaletlerinizden birini seçin. Gemiler için liman gerekir.")
E("MIL_LOCKED_CLASS", "Not yet available: research the matching technology.", "Henüz mevcut değil: ilgili teknolojiyi araştırın.")
E("UCLASS_INFANTRY", "Infantry", "Piyade"); E("UCLASS_HEAVY_INFANTRY", "Heavy infantry", "Ağır piyade"); E("UCLASS_ARCHERS", "Ranged", "Menzilli birlikler")
E("UCLASS_CAVALRY", "Cavalry", "Süvari"); E("UCLASS_HEAVY_CAVALRY", "Heavy cavalry", "Ağır süvari"); E("UCLASS_ARTILLERY", "Artillery", "Topçu")
E("UCLASS_ENGINEER", "Engineers", "Istihkâm"); E("UCLASS_NAVAL", "Naval", "Deniz")
E("UNIT_STATS", "Fire {f} · Shock {s} · Defence {d} · Morale {m} · Move {mv} · Upkeep {up}", "Ateş {f} · Şok {s} · Savunma {d} · Moral {m} · Hareket {mv} · Masraf {up}")
E("UNIT_LINE", "Upkeep {up} · Move {mv} · Morale {mo}", "Masraf {up} · Hareket {mv} · Moral {mo}")
E("MOVE_TAP_TARGET", "Tap a destination province.", "Bir hedef eyalete dokunun.")
E("MOVE_PREVIEW", "March to {to}: about {n} turns", "{to} eyaletine yürüyüş: yaklaşık {n} tur")
E("MOVE_ERR_NO_ACCESS", "You may not enter that territory (declare war or get military access).", "Bu topraklara giremezsiniz (savaş ilan edin veya askerî geçiş izni alın).")
E("MOVE_ERR_NO_PATH", "No route exists (islands need a fleet and a port).", "Güzergâh yok (adalar için donanma ve liman gerekir).")
E("MOVE_ERR_TRANSIT", "The army is at sea.", "Ordu denizde.")
E("RECRUIT_ERR_LIMIT", "This province cannot train more units this turn.", "Bu eyalet bu tur daha fazla birlik eğitemez.")
E("RECRUIT_ERR_MANPOWER", "Not enough manpower.", "İnsan gücü yetersiz."); E("RECRUIT_ERR_MATERIAL", "Not enough {what}.", "{what} yetersiz.")
E("RECRUIT_ERR_PORT", "Ships need a province with a port.", "Gemiler için limanı olan bir eyalet gerekir."); E("RECRUIT_ERR_TECH", "Technology required.", "Teknoloji gerekir.")
E("WAR_NONE", "You are at peace.", "Barış içindesiniz."); E("WAR_SCORE", "War score", "Savaş skoru"); E("WAR_LENGTH", "Duration", "Süre")
E("WAR_EXHAUSTION", "War exhaustion", "Savaş yorgunluğu"); E("WAR_OUR_SIDE", "Our side", "Bizim taraf"); E("WAR_THEIR_SIDE", "Enemy side", "Düşman taraf"); E("WAR_NEGOTIATE", "Negotiate peace", "Barış görüşmesi")
E("WAR_DECLARE_TITLE", "War on {country}", "{country} devletine savaş"); E("WAR_CB_HINT", "Choose a reason for war. Unjustified conquest builds infamy and invites coalitions.", "Savaş gerekçesi seçin. Haksız fetih kötü şöhret yaratır ve koalisyonları davet eder.")
E("WAR_CONFIRM", "Declare war on {country} ({cb})? This cannot be undone.", "{country} devletine savaş ilan edilsin mi ({cb})? Bu geri alınamaz.")
E("WAR_ERR_ALLIED", "You must end the alliance first.", "Önce ittifakı sona erdirmelisiniz."); E("WAR_ERR_ALREADY", "Already at war.", "Zaten savaştasınız.")
E("WAR_ERR_NO_REACH", "That nation cannot be reached by land, strait or from your ports.", "O devlete kara, boğaz veya limanlarınızdan ulaşılamıyor.")
E("WAR_ERR_TRUCE", "A truce is in force for {turns} more turns.", "Ateşkes {turns} tur daha geçerli."); E("WAR_ERR_VASSAL", "You cannot attack your overlord.", "Hükümdarınıza saldıramazsınız.")
E("CB_CONQUEST", "Conquest (no justification)", "Fetih (gerekçesiz)"); E("CB_CLAIM", "Territorial claim", "Toprak iddiası"); E("CB_HOLY_WAR", "Holy war", "Kutsal savaş")
E("CB_CONTAINMENT", "Containment of an aggressor", "Saldırganı sınırlama"); E("CB_LIBERATION", "Liberation", "Kurtuluş"); E("CB_RECONQUEST", "Reconquest", "Geri alım"); E("CB_COALITION", "Coalition war", "Koalisyon savaşı")
E("CBD_CONQUEST", "Heavy infamy; other nations grow hostile.", "Ağır kötü şöhret; diğer devletler düşmanlaşır."); E("CBD_CLAIM", "You hold a claim on their land: little infamy.", "Topraklarında iddianız var: az kötü şöhret.")
E("CBD_HOLY_WAR", "Against another faith, as a theocracy.", "Teokrasi olarak başka inanca karşı."); E("CBD_CONTAINMENT", "They are infamous; the world tolerates your war.", "Kötü şöhretli; dünya savaşınızı hoş görür.")
E("PEACE_TITLE", "Peace with {country}", "{country} ile barış"); E("PEACE_HINT_WIN", "You are winning: demand provinces, gold or vassalage up to the value of your war score.", "Kazanıyorsunuz: savaş skorunuz kadar eyalet, altın veya tâbiilik isteyebilirsiniz.")
E("PEACE_HINT_LOSE", "You are losing: offer concessions, or ask for a white peace.", "Kaybediyorsunuz: taviz önerin ya da beraberlik barışı isteyin.")
E("PEACE_PROVINCES_WIN", "Demand provinces", "Eyalet talep et"); E("PEACE_PROVINCES_LOSE", "Cede provinces", "Eyalet bırak"); E("PEACE_OCCUPIED", "occupied", "işgal altında")
E("PEACE_GOLD", "Demand {gold} gold", "{gold} altın talep et"); E("PEACE_VASSALIZE", "Make them your vassal", "Tâbiiniz yap"); E("PEACE_COST", "cost", "bedel")
E("PEACE_SEND", "Send proposal", "Teklifi gönder"); E("PEACE_MADE", "Peace with {country}.", "{country} ile barış yapıldı."); E("PEACE_REFUSED", "They refused.", "Reddettiler.")
E("PEACE_OFFER_WHITE", "a white peace", "beraberlik barışı"); E("PEACE_OFFER_TERMS", "peace on their terms", "kendi şartlarıyla barış")
E("PROPOSAL_TITLE", "Diplomatic proposal", "Diplomatik teklif"); E("PROPOSAL_PEACE", "{country} offers {what}.", "{country} {what} öneriyor.")
E("PROPOSAL_GENERIC", "{country} proposes: {action}.", "{country} öneriyor: {action}.")

# --- diplomacy -----------------------------------------------------------------------------------------------------------
E("DIPLO_INTRO", "Choose a nation. At war and allied nations are listed first.", "Bir devlet seçin. Savaştaki ve müttefik devletler önce listelenir.")
E("DIPLO_ACTIONS", "Actions", "Eylemler"); E("DIPLO_OPINION", "Their opinion of you", "Sizin hakkınızdaki görüşü"); E("DIPLO_THEIR_OPINION", "Your standing in their eyes", "Gözlerindeki konumunuz")
E("DIPLO_TRUST", "Trust", "Güven"); E("DIPLO_OVERLORD", "Overlord", "Hükümdar"); E("DIPLO_TRUCE", "Truce", "Ateşkes")
E("DIPLO_AT_WAR_WITH", "At war. Your war score: {score}", "Savaştasınız. Savaş skorunuz: {score}")
E("DIPLO_LIKELY_ACCEPT", "Likely accepted", "Kabul edilmesi olası"); E("DIPLO_LIKELY_REFUSE", "Likely refused", "Reddedilmesi olası"); E("DIPLO_PROPOSE", "Propose", "Teklif et")
E("DIPLO_DONE", "{action}: agreed with {country}.", "{action}: {country} ile anlaşıldı."); E("DIPLO_REFUSED", "{country} declined.", "{country} reddetti.")
E("DIPLO_NO_PROPOSALS", "No pending proposals.", "Bekleyen teklif yok."); E("DIPLO_OFFER_BALANCE", "Offer balance", "Teklif dengesi")
E("DIPLO_ERR_AT_WAR", "Not possible while at war.", "Savaş sırasında mümkün değil."); E("DIPLO_ERR_HAVE", "Already in force.", "Zaten yürürlükte.")
E("DIPLO_ERR_CANNOT_JOIN", "Your ally cannot join.", "Müttefikiniz katılamıyor."); E("DIPLO_ERR_EMBARGO", "An embargo is in place.", "Ambargo var.")
E("DIPLO_ERR_NOT_VASSAL", "That nation is not your vassal.", "Bu devlet tâbiiniz değil."); E("DIPLO_ERR_NO_ALLIANCE", "No alliance exists.", "İttifak yok.")
E("DIPLO_ERR_NO_COALITION", "Not enough nations resent that target.", "Yeterli sayıda devlet bu hedeften rahatsız değil.")
E("DIPLO_ERR_NO_ROUTE", "No trade route connects you.", "Sizi bağlayan bir ticaret yolu yok."); E("DIPLO_ERR_TOO_EARLY", "Too early to annex this vassal.", "Bu tâbiyi ilhak etmek için erken.")
E("DIPLO_ERR_VASSAL", "Vassals cannot conduct independent diplomacy.", "Tâbi devletler bağımsız diplomasi yürütemez.")
E("ACT_ALLIANCE", "Propose alliance", "İttifak öner"); E("ACT_BREAK_ALLIANCE", "Break alliance", "İttifakı boz"); E("ACT_NAP", "Non-aggression pact", "Saldırmazlık paktı")
E("ACT_DEFENSIVE", "Defensive agreement", "Savunma anlaşması"); E("ACT_ACCESS", "Request military access", "Askerî geçiş izni iste"); E("ACT_TRADE", "Trade agreement", "Ticaret anlaşması")
E("ACT_VASSALIZE", "Offer vassalage", "Tâbiiyet öner"); E("ACT_RELEASE_VASSAL", "Release vassal", "Tâbiyi serbest bırak"); E("ACT_GUARANTEE", "Guarantee independence", "Bağımsızlığı garanti et")
E("ACT_GIFT", "Send gift", "Hediye gönder"); E("ACT_IMPROVE", "Improve relations", "İlişkileri geliştir"); E("ACT_SANCTION", "Impose sanctions", "Yaptırım uygula")
E("ACT_TRANSFER", "Negotiate territory", "Toprak pazarlığı"); E("ACT_ASSIST", "Call ally to arms", "Müttefiki yardıma çağır"); E("ACT_COALITION", "Form coalition", "Koalisyon kur")
E("ACT_EMBARGO", "Embargo", "Ambargo"); E("ACT_DECLARE_WAR", "Declare war", "Savaş ilan et"); E("ACT_PEACE", "Negotiate peace", "Barış görüş"); E("ACT_ANNEX_VASSAL", "Annex vassal", "Tâbiyi ilhak et")
E("ACTD_ALLIANCE", "A mutual defence pact. Allies join your wars when asked and defend you when attacked.", "Karşılıklı savunma paktı. Müttefikler istendiğinde savaşlarınıza katılır, saldırıya uğradığınızda sizi savunur.")
E("ACTD_BREAK_ALLIANCE", "Ends the alliance. Costs prestige and angers your former partner.", "İttifakı sona erdirir. Prestij kaybettirir ve eski ortağınızı kızdırır.")
E("ACTD_NAP", "Neither side may declare war for a long time. Breaking it costs prestige.", "Uzun süre iki taraf da savaş ilan edemez. Bozmak prestij kaybettirir.")
E("ACTD_DEFENSIVE", "They will defend you if attacked, without joining your offensive wars.", "Saldırıya uğrarsanız sizi savunur, ama saldırı savaşlarınıza katılmaz.")
E("ACTD_ACCESS", "Allows your armies to cross their land.", "Ordularınızın topraklarından geçmesine izin verir.")
E("ACTD_TRADE", "Lower tariffs and a trade bonus for both sides.", "İki taraf için düşük gümrük ve ticaret bonusu.")
E("ACTD_VASSALIZE", "They become your vassal: they follow you to war and pay tribute.", "Tâbiiniz olur: sizi savaşa izler ve haraç öder.")
E("ACTD_RELEASE_VASSAL", "Grants independence. Greatly improves their opinion.", "Bağımsızlık verir. Görüşlerini büyük ölçüde düzeltir.")
E("ACTD_GUARANTEE", "You promise to defend their independence.", "Bağımsızlıklarını savunacağınıza söz verirsiniz.")
E("ACTD_GIFT", "Gold given as a gift improves their opinion.", "Hediye edilen altın görüşlerini düzeltir.")
E("ACTD_IMPROVE", "Spend 10 administrative points to improve relations over the next turns.", "Önümüzdeki turlarda ilişkileri düzeltmek için 10 idari puan harcarsınız.")
E("ACTD_SANCTION", "Economic pressure that angers them.", "Onları kızdıran ekonomik baskı.")
E("ACTD_TRANSFER", "Swap provinces and gold.", "Eyalet ve altın takası.")
E("ACTD_ASSIST", "Ask your ally to join your current wars.", "Müttefikinizden mevcut savaşlarınıza katılmasını isteyin.")
E("ACTD_COALITION", "Rally nations that fear an infamous aggressor.", "Kötü şöhretli bir saldırgandan çekinen devletleri toplayın.")
E("ACTD_EMBARGO", "Cuts all trade between you. They will resent it.", "Aranızdaki tüm ticareti keser. Bundan nefret ederler.")
E("ACTD_ANNEX_VASSAL", "Integrate the vassal completely (costs administrative points).", "Tâbiyi tamamen bünyenize katın (idari puan harcar).")
E("GIFT_HINT", "How much gold do you send?", "Ne kadar altın gönderiyorsunuz?")
E("TRANSFER_HINT", "Tick the provinces each side hands over.", "Her tarafın devrettiği eyaletleri işaretleyin."); E("TRANSFER_GIVE", "You give", "Siz verirsiniz"); E("TRANSFER_WANT", "You receive", "Siz alırsınız")
E("COALITION_HINT", "Choose the nation the coalition is aimed at.", "Koalisyonun hedefleneceği devleti seçin."); E("COALITION_NONE", "No nation is infamous enough.", "Yeterince kötü şöhretli bir devlet yok.")
E("COALITION_FORMED", "A coalition forms against {country}.", "{country} aleyhine bir koalisyon kuruluyor."); E("COALITION_AGAINST_YOU", "A coalition against you has formed: {members}.", "Aleyhinize bir koalisyon kuruldu: {members}.")
# diplomacy reason lines
for k, en, tr in [("DR_OPINION", "Opinion of you", "Sizin hakkınızdaki görüş"), ("DR_COMMON_ENEMY", "Common enemies", "Ortak düşmanlar"), ("DR_RELIGION_SAME", "Same religion", "Aynı din"),
    ("DR_RELIGION_DIFF", "Different religion", "Farklı din"), ("DR_CULTURE", "Shared culture", "Ortak kültür"), ("DR_STRENGTH", "Relative strength", "Göreli güç"), ("DR_TRUST", "Trust", "Güven"),
    ("DR_CLAIMS", "Territorial claims", "Toprak iddiaları"), ("DR_INFAMY", "Your infamy", "Kötü şöhretiniz"), ("DR_PERSONALITY", "National character", "Ulusal karakter"),
    ("DR_TRADE_PARTNER", "Trade partners", "Ticaret ortakları"), ("DR_BORDER_FRICTION", "Border friction", "Sınır sürtüşmesi"), ("DR_RECENT_WAR", "Recent war", "Yakın zamanda savaş"),
    ("DR_ALLIES", "Allies", "Müttefikler"), ("DR_THREAT", "Threat from your power", "Gücünüzden duyulan tehdit"), ("DR_MUTUAL_GAIN", "Mutual gain", "Karşılıklı kazanç"),
    ("DR_PROTECTION", "Protection", "Koruma"), ("DR_THREATENED", "They feel threatened", "Kendilerini tehdit altında hissediyorlar"), ("DR_PAYMENT", "Payment", "Ödeme"),
    ("DR_OFFER_VALUE", "Value of the offer", "Teklifin değeri"), ("DR_INFAMY_TARGET", "Target's infamy", "Hedefin kötü şöhreti"), ("DR_DISLIKE_TARGET", "Dislike of the target", "Hedeften hoşlanmama"),
    ("DR_WARSCORE", "War score", "Savaş skoru"), ("DR_EXHAUSTION", "War exhaustion", "Savaş yorgunluğu"), ("DR_TERMS_COST", "Cost of the terms", "Şartların bedeli"), ("DR_WAR_LENGTH", "Length of the war", "Savaşın uzunluğu")]:
    E(k, en, tr)

# --- technology ------------------------------------------------------------------------------------------------------------------
E("TECH_POINTS", "Research points", "Araştırma puanı"); E("TECH_FOCUS", "Focus", "Odak"); E("TECH_RESEARCHING", "Researching: {tech}", "Araştırılıyor: {tech}")
E("TECH_CANCEL", "Abandon research", "Araştırmayı bırak"); E("TECH_CANCEL_CONFIRM", "Abandon this research? Progress is kept but the fee is not refunded.", "Bu araştırma bırakılsın mı? İlerleme saklanır ama ücret iade edilmez.")
E("TECH_START", "Start research", "Araştırmayı başlat"); E("TECH_DONE", "Researched", "Araştırıldı"); E("TECH_UNLOCKS", "Unlocks", "Açar"); E("TECH_PREREQ", "Requires", "Gerektirir")
E("TECH_COST_RP", "{rp} research points (roughly {turns} turns)", "{rp} araştırma puanı (yaklaşık {turns} tur)")
E("TECH_ERR_BUSY", "This branch is already researching something.", "Bu kol zaten bir şey araştırıyor."); E("TECH_ERR_DONE", "Already researched.", "Zaten araştırıldı.")
E("TECH_ERR_PREREQ", "Requires {tech} first.", "Önce {tech} gerekir."); E("TECH_ERR_UNKNOWN", "Unknown technology.", "Bilinmeyen teknoloji.")

# --- politics / population ------------------------------------------------------------------------------------------------------
E("POP_URBAN", "Urbanisation", "Şehirleşme"); E("POP_LITERACY", "Literacy", "Okuryazarlık"); E("POP_CAPACITY", "Use of land capacity", "Toprak kapasitesi kullanımı")
E("POP_OUTBREAKS", "Disease outbreaks", "Salgın vakaları"); E("POP_RELIGIONS", "Religions", "Dinler"); E("POP_CULTURES", "Cultures", "Kültürler"); E("POP_PROVINCES", "Most populous provinces", "En kalabalık eyaletler")
E("STAB_FACTORS", "What shapes stability", "İstikrarı belirleyenler"); E("STAB_FACTION", "Class satisfaction", "Sınıf memnuniyeti"); E("STAB_GOV", "Government type", "Hükûmet türü")
E("STAB_WAR", "War exhaustion", "Savaş yorgunluğu"); E("STAB_OVEREXT", "Overextension", "Aşırı genişleme"); E("STAB_PRESTIGE", "Prestige", "Prestij"); E("STAB_LUXURY", "Luxuries lacking", "Lüks eksikliği"); E("STAB_HUNGER", "Hunger", "Açlık")
E("STAB_ADVICE", "Advisers say", "Danışmanlar diyor ki")
E("ADV_TAXES", "Taxes are high: expect discontent among peasants and merchants.", "Vergiler yüksek: köylüler ve tüccarlar arasında hoşnutsuzluk bekleyin.")
E("ADV_OVEREXT", "Your administration is overstretched: build government offices or administrative centres.", "İdareniz fazla gerilmiş: hükûmet konağı veya idari merkez kurun.")
E("ADV_WAR", "War weariness is spreading: seek peace soon.", "Savaş bıkkınlığı yayılıyor: yakında barış arayın.")
E("ADV_FOOD", "Famine looms: build farms, import food or reduce the army.", "Kıtlık yaklaşıyor: çiftlik kurun, gıda ithal edin veya orduyu küçültün.")
E("ADV_NONE", "The realm is calm.", "Devlet sakin.")

# --- objectives / victory -----------------------------------------------------------------------------------------------------------
E("OBJ_INTRO", "Scenario objectives grant score and prestige. Some lead to victory.", "Senaryo hedefleri puan ve prestij kazandırır. Bazıları zafere götürür.")
E("OBJ_BY_TURN", "By turn {n}", "{n}. tura kadar"); E("OBJ_SCORE", "{n} points", "{n} puan"); E("OBJ_VICTORY", "Victory objective", "Zafer hedefi")
E("VIC_INTRO", "Several roads lead to victory. Hold the condition for several turns to win.", "Zafere giden birkaç yol var. Kazanmak için koşulu birkaç tur boyunca koruyun.")
E("VIC_TERRITORY", "Territorial domination", "Toprak üstünlüğü"); E("VICD_TERRITORY", "Own the required share of the map.", "Haritanın gereken payına sahip olun.")
E("VIC_ECONOMIC", "Economic supremacy", "Ekonomik üstünlük"); E("VICD_ECONOMIC", "Command a large share of world income, far ahead of any rival.", "Dünya gelirinin büyük bir payını, her rakibin çok önünde elinizde tutun.")
E("VIC_DIPLOMATIC", "Diplomatic supremacy", "Diplomatik üstünlük"); E("VICD_DIPLOMATIC", "Lead a bloc of allies and vassals that dominates the world.", "Dünyaya hâkim bir müttefik ve tâbi bloğuna önderlik edin.")
E("VIC_TECHNOLOGICAL", "Technological supremacy", "Teknolojik üstünlük"); E("VICD_TECHNOLOGICAL", "Reach near-complete mastery of all technologies.", "Tüm teknolojilerde neredeyse tam hâkimiyete ulaşın.")
E("VIC_SURVIVAL", "Survival & independence", "Hayatta kalma ve bağımsızlık"); E("VIC_SURVIVAL_D", "If you start small and are still independent at turn {turn}, you win.", "Küçük başlayıp {turn}. turda hâlâ bağımsızsanız kazanırsınız.")
E("VIC_HOLD", "Held for {n} of {need} turns", "{n} / {need} tur boyunca korundu")
E("STAT_CAMPAIGN", "Campaign", "Kampanya"); E("STAT_CONQUERED", "Provinces conquered", "Fethedilen eyalet"); E("STAT_BATTLES", "Battles", "Savaşlar"); E("STAT_VICTORIES", "Battle victories", "Muharebe zaferleri")
E("STAT_CASUALTIES", "Own casualties", "Kendi kayıplarımız"); E("STAT_INFLICTED", "Enemy casualties", "Düşman kayıpları"); E("STAT_WARS_WON", "Wars won", "Kazanılan savaşlar")
E("STAT_ANNEXED", "Countries annexed", "İlhak edilen devletler"); E("STAT_ALLIANCES", "Alliances formed", "Kurulan ittifaklar"); E("STAT_TOTAL_INCOME", "Total income earned", "Toplam kazanılan gelir")
E("STAT_BUILDINGS", "Buildings constructed", "İnşa edilen binalar"); E("STAT_TECHS", "Technologies researched", "Araştırılan teknolojiler"); E("STAT_DURATION", "Campaign duration", "Kampanya süresi"); E("STAT_YEARS", "{n} years", "{n} yıl")
E("TIMELINE_EMPTY", "Nothing noteworthy has happened yet.", "Henüz kayda değer bir şey olmadı."); E("LOG_EMPTY", "No notifications yet.", "Henüz bildirim yok.")
E("EVT_PENDING", "{n} event(s) await your decision.", "{n} olay kararınızı bekliyor."); E("EVT_OPEN", "Decide now", "Şimdi karar ver")
E("EVT_HISTORICAL", "HISTORICAL EVENT", "TARİHÎ OLAY"); E("EVT_RANDOM", "RANDOM EVENT", "RASTGELE OLAY"); E("EVT_SOURCE", "Source: {src}", "Kaynak: {src}")
for k, en, tr in [("SCORE_TERRITORY", "Territory", "Toprak"), ("SCORE_DEVELOPMENT", "Development", "Gelişmişlik"), ("SCORE_POPULATION", "Population", "Nüfus"), ("SCORE_ECONOMY", "Economy", "Ekonomi"),
    ("SCORE_TECH", "Technology", "Teknoloji"), ("SCORE_PRESTIGE", "Prestige", "Prestij"), ("SCORE_MILITARY", "Military achievements", "Askerî başarılar"), ("SCORE_DIPLOMACY", "Diplomacy", "Diplomasi"), ("SCORE_OBJECTIVES", "Objectives", "Hedefler")]:
    E(k, en, tr)
E("END_VICTORY", "VICTORY", "ZAFER"); E("END_DEFEAT", "DEFEAT", "YENİLGİ"); E("END_STATS", "Statistics", "İstatistikler"); E("END_MENU", "Main menu", "Ana menü"); E("END_WINNER", "{country} prevailed.", "{country} galip geldi.")
for k, en, tr in [("END_REASON_TERRITORY", "You dominate the known world.", "Bilinen dünyaya hükmediyorsunuz."), ("END_REASON_ECONOMIC", "Your wealth outshines every rival.", "Servetiniz tüm rakiplerinizin üzerinde."),
    ("END_REASON_DIPLOMATIC", "Your bloc of allies and vassals rules the world.", "Müttefik ve tâbi bloğunuz dünyayı yönetiyor."), ("END_REASON_TECHNOLOGICAL", "Your realm leads the age in science and craft.", "Devletiniz çağa bilim ve sanatta önderlik ediyor."),
    ("END_REASON_SURVIVAL", "Against all odds, your realm endured and stayed independent.", "Tüm olumsuzluklara rağmen devletiniz ayakta kaldı ve bağımsızlığını korudu."),
    ("END_REASON_SCORE", "The campaign ended; the highest score decides.", "Kampanya sona erdi; en yüksek puan belirler."), ("END_REASON_SCENARIO", "You achieved the scenario's great goals.", "Senaryonun büyük hedeflerine ulaştınız."),
    ("END_REASON_DEFEAT", "Your realm has fallen.", "Devletiniz yıkıldı.")]:
    E(k, en, tr)
for k, en, tr in [("BR_TITLE", "Battle of {province}", "{province} Muharebesi"), ("BR_WIDTH", "front width {n}", "cephe genişliği {n}"), ("BR_FORT", "fortification {n}", "tahkimat {n}"),
    ("BR_STRENGTH", "{start} regiments, losses {loss}, survivors {end}", "{start} alay, kayıp {loss}, hayatta kalan {end}"), ("BR_MEN", "about {n} men lost", "yaklaşık {n} kişi kaybedildi"),
    ("BR_WHY", "Why {winner} won", "{winner} neden kazandı"), ("BR_ATTACKER", "Attacker", "Saldıran"), ("BR_DEFENDER", "Defender", "Savunan")]:
    E(k, en, tr)
for k, en, tr in [("FACTOR_NUMBERS", "Numbers", "Sayısal üstünlük"), ("FACTOR_GENERAL", "General's skill", "Komutan yeteneği"), ("FACTOR_TERRAIN", "Terrain", "Arazi"), ("FACTOR_FORT", "Fortifications", "Tahkimat"),
    ("FACTOR_MORALE", "Morale", "Moral"), ("FACTOR_SUPPLY", "Supply", "İkmal"), ("FACTOR_WEATHER", "Weather", "Hava"), ("FACTOR_TECH", "Technology", "Teknoloji"),
    ("FACTOR_COMPOSITION", "Army composition", "Ordu bileşimi"), ("FACTOR_LUCK", "The fortunes of war", "Savaşın kaderi")]:
    E(k, en, tr)
for k, en, tr in [("SEASON_SPRING", "Spring", "İlkbahar"), ("SEASON_SUMMER", "Summer", "Yaz"), ("SEASON_AUTUMN", "Autumn", "Sonbahar"), ("SEASON_WINTER", "Winter", "Kış")]:
    E(k, en, tr)
for k, en, tr in [("UNREST_TAX", "Taxation", "Vergilendirme"), ("UNREST_STABILITY", "National stability", "Ulusal istikrar"), ("UNREST_OVEREXT", "Overextension", "Aşırı genişleme"),
    ("UNREST_CULTURE", "Foreign culture", "Yabancı kültür"), ("UNREST_RELIGION", "Foreign religion", "Yabancı din"), ("UNREST_CONQUEST", "Recent conquest", "Yeni fetih"),
    ("UNREST_HUNGER", "Hunger", "Açlık"), ("UNREST_WAR", "War exhaustion", "Savaş yorgunluğu"), ("UNREST_CLASSES", "Unhappy classes", "Mutsuz sınıflar"),
    ("UNREST_BUILDINGS", "Courts, offices, temples", "Mahkemeler, konaklar, ibadethaneler"), ("UNREST_GARRISON", "Garrison", "Garnizon"), ("UNREST_GOV", "Government", "Hükûmet"), ("UNREST_OCCUPIED", "Under occupation", "İşgal altında")]:
    E(k, en, tr)
