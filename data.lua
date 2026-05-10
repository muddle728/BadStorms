local BadStorms = _G.BadStorms

BadStorms.BossIDs = {
	-- Blackfathom Deeps
	[4829]=true,[4830]=true,[4831]=true,[4832]=true,[4887]=true,[6243]=true,[12876]=true,[12902]=true,
	-- Deadmines
	[642]=true,[647]=true,[639]=true,[1763]=true,[646]=true,[645]=true,[644]=true,[643]=true,[641]=true,[640]=true,
	-- Gnomeregan
	[7800]=true,[7079]=true,[7361]=true,[6235]=true,[6229]=true,[6228]=true,[6231]=true,
	-- Maraudon
	[13742]=true,[13741]=true,[13740]=true,[13739]=true,[12236]=true,[13738]=true,[13282]=true,[12258]=true,[12237]=true,[12225]=true,[12203]=true,[13601]=true,[13596]=true,[12201]=true,
	-- Ragefire Chasm
	[11517]=true,[11518]=true,[11519]=true,[11520]=true,[17830]=true,
	-- Razorfen Downs
	[7355]=true,[14686]=true,[7356]=true,[7357]=true,[8567]=true,[7354]=true,[7358]=true,
	-- Razorfen Kraul
	[4421]=true,[4420]=true,[4422]=true,[4428]=true,[4424]=true,[6168]=true,[4425]=true,[4842]=true,
	-- Scarlet Monastery
	[3975]=true,[4542]=true,[3976]=true,[3977]=true,[3983]=true,[6488]=true,[6490]=true,[6489]=true,[14693]=true,[4543]=true,[3974]=true,[6487]=true,
	-- Scholomance
	[14861]=true,[10506]=true,[14695]=true,[10503]=true,[11622]=true,[14516]=true,[10433]=true,[10432]=true,[16118]=true,[10508]=true,[10505]=true,[11261]=true,[10901]=true,[10507]=true,[10504]=true,[10502]=true,[1853]=true,
	-- Shadowfang Keep
	[3914]=true,[3886]=true,[4279]=true,[3887]=true,[4278]=true,[4274]=true,[3927]=true,[14682]=true,[4275]=true,[3872]=true,
	-- Stormwind Stockade
	[1716]=true,[1663]=true,[1717]=true,[1666]=true,[1696]=true,[1720]=true,
	-- Stratholme
	[10393]=true,[14684]=true,[11058]=true,[10558]=true,[10516]=true,[16387]=true,[11143]=true,[10808]=true,[11032]=true,[11120]=true,[10997]=true,[10811]=true,[10813]=true,[16101]=true,[16102]=true,[17913]=true,[17911]=true,[17910]=true,[17914]=true,[17912]=true,[10809]=true,[10437]=true,[10436]=true,[11121]=true,[10438]=true,[10435]=true,[10439]=true,[10440]=true,
	-- The Temple of Atal'Hakkar (Sunken Temple)
	[8443]=true,[5709]=true,[5710]=true,[5720]=true,[5711]=true,[5712]=true,[5713]=true,[5714]=true,[5715]=true,[5716]=true,[5717]=true,[5718]=true,[5719]=true,
	-- Uldaman
	[2729]=true,[2748]=true,[2751]=true,[2752]=true,[2753]=true,[2754]=true,[2760]=true,[2761]=true,[2762]=true,[2763]=true,[2764]=true,[2779]=true,[2857]=true,[2858]=true,[2892]=true,
	-- Wailing Caverns
	[3653]=true,[3654]=true,[3671]=true,[3670]=true,[3669]=true,[3655]=true,[5775]=true,
	-- Zul'Farrak
	[7271]=true,[7272]=true,[7267]=true,[7275]=true,[7268]=true,[7273]=true,[7274]=true,[7795]=true,[7796]=true,[7797]=true,
	-- Blackrock Depths
	[9018]=true,[9543]=true,[9537]=true,[9502]=true,[9499]=true,[23872]=true,[9025]=true,[9319]=true,[9156]=true,[8923]=true,[17808]=true,[9039]=true,[9040]=true,[9037]=true,[9034]=true,[9038]=true,[9036]=true,[9938]=true,[10076]=true,[8929]=true,[9019]=true,[9024]=true,[9041]=true,[9042]=true,[9476]=true,[9056]=true,[9017]=true,[9016]=true,[9033]=true,[8983]=true,[9031]=true,[9029]=true,[9027]=true,[9028]=true,[9032]=true,[9030]=true,[16059]=true,
	-- Blackrock Spire (Lower)
	[10263]=true,[9218]=true,[9219]=true,[9217]=true,[9196]=true,[9236]=true,[9237]=true,[16080]=true,[9596]=true,[10596]=true,[10376]=true,[10584]=true,[9736]=true,[10220]=true,[10268]=true,[9718]=true,[9568]=true,
	-- Blackrock Spire (Upper)
	[9816]=true,[10258]=true,[9817]=true,[9818]=true,[9819]=true,[9820]=true,[10339]=true,[10429]=true,[10430]=true,[10509]=true,
	-- Dire Maul
	[11447]=true,[11498]=true,[11497]=true,[14354]=true,[14327]=true,[14349]=true,[13280]=true,[11490]=true,[11492]=true,[16097]=true,[14326]=true,[14322]=true,[14321]=true,[14323]=true,[14325]=true,[14324]=true,[11501]=true,[11489]=true,[11487]=true,[11467]=true,[11488]=true,[14690]=true,[11496]=true,[14506]=true,[11486]=true,
	-- Molten Core
	[12118]=true,[11982]=true,[12259]=true,[12057]=true,[12056]=true,[12264]=true,[12098]=true,[11988]=true,[12018]=true,[11502]=true,
	-- Blackwing Lair
	[12435]=true,[13020]=true,[12017]=true,[11983]=true,[14601]=true,[11981]=true,[14020]=true,[11583]=true,[12557]=true,[10162]=true,
	-- Ruins of Ahn'Qiraj
	[15348]=true,[15341]=true,[15340]=true,[15370]=true,[15369]=true,[15339]=true,
	-- Temple of Ahn'Qiraj
	[15516]=true,[15510]=true,[15509]=true,[15263]=true,[15517]=true,[15511]=true,[15543]=true,[15299]=true,[15275]=true,[15544]=true,[15727]=true,
	-- Naxxramas (60)
	[15956]=true,[15953]=true,[15952]=true,[15954]=true,[15936]=true,[16011]=true,[16028]=true,[15931]=true,[15932]=true,[15928]=true,[16061]=true,[16060]=true,[15989]=true,[15990]=true,[16065]=true,[16064]=true,[16062]=true,[16063]=true,[15930]=true,[15929]=true,
	-- World Bosses
	[6109]=true,[12397]=true,[14464]=true,[15203]=true,[15204]=true,[15205]=true,[15305]=true,[14454]=true,
	-- Hellfire Ramparts
	[17306]=true,[17308]=true,[17537]=true,[17307]=true,[17536]=true,
	-- The Blood Furnace
	[17381]=true,[17380]=true,[17377]=true,
	-- The Shattered Halls
	[16807]=true,[20923]=true,[16809]=true,[16808]=true,
	-- Slave Pens
	[17941]=true,[17991]=true,[17942]=true,
	-- The Underbog
	[17770]=true,[18105]=true,[17826]=true,[17827]=true,[17882]=true,
	-- The Steamvault
	[17797]=true,[17796]=true,[17798]=true,
	-- Auchenai Crypts
	[18371]=true,[18373]=true,
	-- Mana-Tombs
	[18341]=true,[18343]=true,[22930]=true,[18344]=true,
	-- Sethekk Halls
	[18472]=true,[23035]=true,[18473]=true,
	-- Shadow Labyrinth
	[18731]=true,[18667]=true,[18732]=true,[18708]=true,
	-- Magisters' Terrace
	[24723]=true,[24744]=true,[24560]=true,[24664]=true,
	-- Arcatraz
	[20870]=true,[20886]=true,[20885]=true,[20912]=true,[20904]=true,
	-- Botanica
	[17976]=true,[17975]=true,[17978]=true,[17980]=true,
	-- Mechanar
	[19218]=true,[19219]=true,[19220]=true,[19221]=true,
	-- Karazhan
	[15550]=true,[16151]=true,[28194]=true,[15687]=true,[16457]=true,[15691]=true,[15688]=true,[16524]=true,[15689]=true,[15690]=true,[17225]=true,[17229]=true,[16179]=true,[16181]=true,[16180]=true,[17535]=true,[17546]=true,[17543]=true,[17547]=true,[17548]=true,[18168]=true,[17521]=true,[17533]=true,[17534]=true,
	-- Zul'Aman
	[23574]=true,[23576]=true,[23577]=true,[23578]=true,[24239]=true,[23863]=true,[23542]=true,[23864]=true,
	-- Gruul's Lair
	[18831]=true,[19044]=true,[18835]=true,[18836]=true,[18834]=true,[18832]=true,
	-- Magtheridon's Lair
	[17257]=true,
	-- Serpentshrine Cavern
	[21216]=true,[21217]=true,[21215]=true,[21214]=true,[21213]=true,[21212]=true,[21875]=true,
	-- Tempest Keep
	[19514]=true,[19516]=true,[18805]=true,[19622]=true,
	-- Hyjal Summit
	[17767]=true,[17808]=true,[17888]=true,[17842]=true,[17968]=true,
	-- Black Temple
	[22887]=true,[22898]=true,[22841]=true,[22871]=true,[22948]=true,[23420]=true,[23419]=true,[23418]=true,[22947]=true,[23426]=true,[22917]=true,[22949]=true,[22950]=true,[22951]=true,[22952]=true,
	-- Sunwell Plateau
	[24891]=true,[25319]=true,[24850]=true,[24882]=true,[25038]=true,[25165]=true,[25166]=true,[25741]=true,[25315]=true,[25840]=true,[24892]=true,
	-- Zul'Gurub
	[14507]=true,[14510]=true,[11380]=true,[11382]=true,[15085]=true,[14517]=true,[14509]=true,[15082]=true,[14499]=true,
	-- Utgarde Keep
	[23953]=true,[24200]=true,[23795]=true,[23872]=true,
	-- Utgarde Pinnacle
	[26668]=true,[26687]=true,[26693]=true,[26694]=true,[26731]=true,[26763]=true,[26794]=true,[26796]=true,
	-- The Nexus
	[26763]=true,[26731]=true,[26794]=true,[26796]=true,[26832]=true,
	-- Azjol-Nerub
	[28684]=true,[28921]=true,[29120]=true,
	-- Ahn'kahet
	[29309]=true,[29308]=true,[29310]=true,[29311]=true,[30258]=true,
	-- Drak'Tharon Keep
	[26630]=true,[26631]=true,[27483]=true,[26632]=true,[27696]=true,
	-- Violet Hold
	[29315]=true,[29313]=true,[29314]=true,[29316]=true,[31134]=true,[29312]=true,[30658]=true,[30660]=true,[30659]=true,[30661]=true,[30662]=true,[30663]=true,[30666]=true,[30664]=true,[30665]=true,[30667]=true,
	-- Gundrak
	[29304]=true,[29305]=true,[29307]=true,[29306]=true,[29932]=true,
	-- Halls of Stone
	[27977]=true,[27975]=true,[28234]=true,[27978]=true,
	-- Halls of Lightning
	[28586]=true,[28587]=true,[28546]=true,[28923]=true,
	-- Oculus
	[27753]=true,[27755]=true,[27756]=true,[27654]=true,[27655]=true,[27656]=true,
	-- Culling of Stratholme
	[26529]=true,[26530]=true,[26532]=true,[32273]=true,[26533]=true,[29620]=true,
	-- Trial of the Champion
	[35351]=true,[35451]=true,[35572]=true,[34497]=true,[34496]=true,[34498]=true,[34564]=true,
	-- Trial of the Crusader
	[34796]=true,[34780]=true,[34797]=true,[34497]=true,[34496]=true,[34498]=true,[34564]=true,[35119]=true,
	-- Halls of Reflection
	[38112]=true,[38113]=true,[37226]=true,
	-- Pit of Saron
	[36494]=true,[36477]=true,[36476]=true,[36658]=true,
	-- Forge of Souls
	[36497]=true,[36502]=true,
	-- Naxxramas (80)
	[30549]=true,[16803]=true,[15930]=true,[15929]=true,[16028]=true,[15931]=true,[15932]=true,[15928]=true,[16061]=true,[16060]=true,[15989]=true,[15990]=true,[15954]=true,[15936]=true,[16011]=true,[15956]=true,[15953]=true,[15952]=true,[16065]=true,[16064]=true,[16062]=true,[16063]=true,
	-- Obsidian Sanctum
	[30451]=true,[30452]=true,[30449]=true,[28860]=true,
	-- Eye of Eternity
	[28859]=true,[28860]=true,
	-- Ulduar
	[33288]=true,[33293]=true,[33452]=true,[33515]=true,[33651]=true,[32867]=true,[32927]=true,[32857]=true,[32906]=true,[32930]=true,[33113]=true,[32915]=true,[33449]=true,[33453]=true,[33572]=true,[33670]=true,[34085]=true,[33271]=true,[33236]=true,[33237]=true,[33238]=true,[33239]=true,[33240]=true,[33241]=true,[33242]=true,[33243]=true,[33244]=true,[33245]=true,[33246]=true,[33248]=true,[33249]=true,[33250]=true,[33251]=true,[33252]=true,[33253]=true,[33254]=true,[33349]=true,[33350]=true,[33351]=true,[33352]=true,[33353]=true,[33354]=true,[33355]=true,[33186]=true,[33768]=true,[33769]=true,[33770]=true,[33771]=true,[33772]=true,[33773]=true,[33774]=true,
	-- Crusaders' Coliseum (ToC Raid)
	[34796]=true,[34780]=true,[34797]=true,[35119]=true,
	-- Icecrown Citadel
	[36612]=true,[36855]=true,[37813]=true,[36626]=true,[36627]=true,[36678]=true,[37972]=true,[37970]=true,[37973]=true,[37955]=true,[36789]=true,[37950]=true,[37868]=true,[36791]=true,[37934]=true,[37886]=true,[37985]=true,[36853]=true,[36597]=true,[37217]=true,[37025]=true,[36661]=true,
	-- Ruby Sanctum
	[39746]=true,[39747]=true,[39751]=true,[39863]=true,[39899]=true,[40142]=true,
	-- Onyxia's Lair
	[10184]=true,
	-- World Bosses (WotLK)
	[18728]=true,[17711]=true,
}
