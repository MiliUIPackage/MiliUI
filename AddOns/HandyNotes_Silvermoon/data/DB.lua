----------------------------------------------------------------------------------------------------
------------------------------------------AddOn NAMESPACE-------------------------------------------
----------------------------------------------------------------------------------------------------

local _, ns = ...
local L = ns.locale

----------------------------------------------------------------------------------------------------
-----------------------------------------------LOCALS-----------------------------------------------
----------------------------------------------------------------------------------------------------

local function GetMapNames(id1, id2)
    if (id1 and id2) then
        return format("%s, %s", C_Map.GetMapInfo(id1).name, C_Map.GetMapInfo(id2).name)
    else
        return C_Map.GetMapInfo(id1).name
    end
end

local Durotar = GetMapNames(12, 1)
local ElwynnForest = GetMapNames(13, 37)
local QuelThalas = GetMapNames(13, 2537)

----------------------------------------------------------------------------------------------------
----------------------------------------------DATABASE----------------------------------------------
----------------------------------------------------------------------------------------------------

local DB = {}
ns.DB = DB

DB.nodes = {
    [2393] = { -- Silvermoon City (Midnight)
        [52176522] = { icon = "portal", label = L["Portal to Orgrimmar"], note = Durotar, faction = "Horde" },
        [52626452] = { icon = "portal", label = L["Portal to Stormwind"], note = ElwynnForest, faction = "Alliance" },
        [52626520] = { icon = "trainer", npc = 239673, class = "MAGE" }, -- Magistrix Narinth
        [36946798] = { icon = "portal", label = L["Rootway to Harandar"], note = QuelThalas, requirements = { quest = 86898 } }, -- check quest

        -- Court of Blood
        [70478387] = { icon = "catalyst", label = L["The Catalyst"], faction = "Horde" }, -- The Catalyst
        [69838445] = { icon = "trainer", npc = 247618, profession = 164, picon = "blacksmithing", faction = "Horde" }, -- Arathel Sunforge
        [69348423] = { icon = "trainer", npc = 247791, profession = 202, picon = "engineering", faction = "Horde" }, -- Gloresse
        [69508434] = { icon = "vendor", npc = 247792, faction = "Horde" }, -- Renfreid
        [70708255] = { icon = "trainer", npc = 247803, profession = 186, picon = "mining", faction = "Horde" }, -- Saren
        [69728131] = { icon = "trainer", npc = 247623, profession = 165, picon = "leatherworking", faction = "Horde" }, -- Sathein
        [69898098] = { icon = "trainer", npc = 247626, profession = 393, picon = "skinning", faction = "Horde" }, -- Mathreyn
        [69268166] = { icon = "mail", label = L["Mailbox"], faction = "Horde" },

        [72677383] = { icon = "trainer", npc = 247564, profession = 182, picon = "herbalism", faction = "Horde" }, -- Botanist Tyniarrel
        [73297353] = { icon = "trainer", npc = 247556, profession = 171, picon = "alchemy", faction = "Horde" }, -- Arcanist Sheynathren
        [73337287] = { icon = "trainer", npc = 247560, profession = 197, picon = "tailoring", faction = "Horde" }, -- Sempstress Ambershine
        [72917162] = { icon = "trainer", npc = 247554, profession = 333, picon = "enchanting", faction = "Horde" }, -- Magistrix Eredania
        [73757123] = { icon = "trainer", npc = 243346, profession = 755, picon = "jewelcrafting", faction = "Horde" }, -- Aleinia
        [72337422] = { icon = "mail", label = L["Mailbox"], faction = "Horde" },

        -- Walk of Elders
        [56398538] = { icon = "vendor", npc = 251196, faction = "Horde" }, -- Dalon Sunsugar

        -- The Royal Exchange
        [65157640] = { icon = "anvil", npc = 251456, faction = "Horde" }, -- Zathanna
        [65847702] = { icon = "vendor", npc = 251454, faction = "Horde" }, -- Miss Jadepaw
        [64447962] = { icon = "vendor", npc = 251398, faction = "Horde" }, -- Lady Gianna

        [67086609] = { icon = "stablemaster", npc = 254366, faction = "Horde" }, -- Winaestra
        [66727041] = { icon = "mail", label = L["Mailbox"], faction = "Horde" },

        [63937137] = { icon = "vendor", npc = 254414, faction = "Horde" }, -- Conjurer Tyren

        [69116755] = { icon = "vendor", npc = 240940, faction = "Horde" }, -- Magistrix Nizara

        -- Royal Exchange Bank
        [72586403] = { icon = "banker", npc = 243128, faction = "Horde" }, -- Novia
        [72726435] = { icon = "banker", npc = 243130, faction = "Horde" }, -- Daenice
        [72866478] = { icon = "banker", npc = 243129, faction = "Horde" }, -- Periel
        [72516543] = { icon = "guildvault", label = L["config_guildvault"], faction = "Horde" },
        [71766572] = { icon = "mail", label = L["Mailbox"], faction = "Horde" },

        -- Silvermoon City Inn
        [66906203] = { icon = "innkeeper", npc = 247804, faction = "Horde" }, -- Innkeeper Delaniel
        [68086328] = { icon = "mail", label = L["Mailbox"], faction = "Horde" },

        -- Royal Exchange Auction House
        [67897271] = { icon = "auctioneer", npc = 243111, sublabel = "", faction = "Horde" }, -- Auctioneer Caidori
        [67607266] = { icon = "auctioneer", npc = 243113, sublabel = "", faction = "Horde" }, -- Auctioneer Ithillan
        [67247266] = { icon = "auctioneer", npc = 243114, sublabel = "", faction = "Horde" }, -- Auctioneer Tandron
        [68367156] = { icon = "craftingorders", npc = 260100, faction = "Horde" }, -- Kinamisa

        -- Silvermoon Harbor
        [51542871] = { icon = "vendor", npc = 257540, picon = "fishing" }, -- Daelyn

        -- The Bazaar
        [46915161] = { icon = "trainer", npc = 243553, profession = 755, picon = "jewelcrafting" }, -- Zantasia
        [46665119] = { icon = "vendor", npc = 243555, profession = 773, picon = "inscription" }, -- Lelorian
        [47035196] = { icon = "trainer", npc = 243357, profession = 171, picon = "alchemy" }, -- Camberon
        [47035166] = { icon = "vendor", npc = 243359, profession = 171, picon = "alchemy" }, -- Melaris
        [48295143] = { icon = "trainer", npc = 243355, profession = 182, picon = "herbalism" }, -- Botanist Nathera
        [48305130] = { icon = "vendor", npc = 256026, profession = 182, picon = "herbalism" }, -- Irodalmin
        [48005384] = { icon = "trainer", npc = 243349, profession = 333, picon = "enchanting" }, -- Dolothos
        [47905308] = { icon = "mail", label = L["Mailbox"] },
        [47925343] = { icon = "vendor", npc = 243350, profession = 333, picon = "enchanting" }, -- Lyna
        [48185400] = { icon = "trainer", npc = 243352, profession = 197, picon = "tailoring" }, -- Galana
        [48225431] = { icon = "vendor", npc = 243353, profession = 197, picon = "tailoring" }, -- Deynna
        [48875418] = { icon = "trainer", npc = 243347, profession = 755, picon = "jewelcrafting" }, -- Kalinda
        [48175509] = { icon = "trainer", npc = 243345, profession = 755, picon = "jewelcrafting" }, -- Kalinda
        [48015502] = { icon = "vendor", npc = 243346, profession = 755, picon = "jewelcrafting"  }, -- Gelanthis

        [48566202] = { icon = "vendor", npc = 239676 }, -- Vaskarn
        [48666201] = { icon = "reforge", npc = 239675 }, -- Cuzolth

        [49486592] = { icon = "mail", label = L["Mailbox"] },
        [50406493] = { icon = "vendor", npc = 239670 }, -- Vaultkeeper Elysa
        [50716472] = { icon = "banker", npc = 239666 }, -- Elana
        [50926515] = { icon = "banker", npc = 239664 }, -- Ceera
        [51106542] = { icon = "banker", npc = 239665 }, -- Hatheon
        [50956607] = { icon = "guildvault", label = L["config_guildvault"] },

        [46355556] = { icon = "stablemaster", npc = 243161 }, -- Seraphina Bloodheart

        [45005659] = { icon = "mail", label = L["Mailbox"] },
        [44935607] = { icon = "vendor", npc = 243280 }, -- Theremis
        [44925588] = { icon = "vendor", npc = 243160 }, -- Zalle
        [45025561] = { icon = "craftingorders", npc = 243279 }, -- Mar'nah
        [44965540] = { icon = "vendor", npc = 243286 }, -- Lyrendal

        [44836036] = { icon = "trainer", npc = 253468, picon = "fishing" }, -- Drathen
        [45015978] = { icon = "vendor", npc = 257539, picon = "fishing" }, -- Olirea

        [43655179] = { icon = "trainer", npc = 241450, profession = 164, picon = "blacksmithing" }, -- Bemarrin
        [43625147] = { icon = "anvil", npc = 241451, profession = 164, picon = "blacksmithing" }, -- Eriden
        [42595285] = { icon = "trainer", npc = 241455, profession = 186, picon = "mining" }, -- Belil
        [42615298] = { icon = "vendor", npc = 241454, profession = 186, picon = "mining" }, -- Zelan
        [43545409] = { icon = "trainer", npc = 241452, profession = 202, picon = "engineering" }, -- Danwe
        [43475373] = { icon = "vendor", npc = 241453, profession = 202, picon = "engineering" }, -- Yatheon

        [43215557] = { icon = "trainer", npc = 243527, profession = 393, picon = "skinning" }, -- Tyn
        [43145538] = { icon = "vendor", npc = 256009, profession = 393, picon = "skinning" }, -- Rendron
        [43135575] = { icon = "trainer", npc = 243500, profession = 165, picon = "leatherworking" }, -- Talmar
        [43055600] = { icon = "vendor", npc = 243531, profession = 165, picon = "leatherworking" }, -- Zaralda

        [42005831] = { icon = "portal", label = L["Portal to The Timeways"], requirements = { level = 90 } },
        [42105879] = { icon = "bubble", npc = 197711 }, -- Lindormi

        [44096277] = { icon = "decor", npc = 252915 }, -- Corlen Hordralin
        [44046275] = { icon = "decor", npc = 252916 }, -- Hesta Forlath

        [39986551] = { icon = "catalyst", label = L["The Catalyst"] }, -- The Catalyst
        [41726637] = { icon = "anvil", npc = 259722 }, -- Andra
        [41846694] = { icon = "vendor", npc = 257939 }, -- Enchanter Erodin

        [48624925] = { icon = "vendor", npc = 255474 }, -- Faeth Strongbow

        [47537895] = { icon = "vendor", npc = 258610 }, -- Velothir
        [48397455] = { icon = "anvil", npc = 243134 }, -- Rahein
        [49077606] = { icon = "vendor", npc = 243147 }, -- Aerith Primrose
        [49497553] = { icon = "mail", label = L["Mailbox"] },

        [51447592] = { icon = "auctioneer", npc = 239625, sublabel = "" }, -- Auctioneer Jenath
        [51177613] = { icon = "auctioneer", npc = 239621, sublabel = "" }, -- Auctioneer Vynna
        [50907651] = { icon = "auctioneer", npc = 239628, sublabel = "" }, -- Auctioneer Feynna
        [51187465] = { icon = "craftingorders", npc = 260098 }, -- Larissia

        [52187367] = { icon = "rostrum", label = L["Rostrum of Transformation"] },

        [49237745] = { icon = "transmogrifier", npc = 249050 }, -- Warpweaver Zirka

        [52767789] = { icon = "vendor", npc = 242398 }, -- Naleidea Rivergleam
        [52537888] = { icon = "vendor", npc = 242399 }, -- Telemancer Astrandis

        -- Murder Row
        [51165645] = { icon = "decor", npc = 256828 }, -- Dennia Silvertongue
        [50725608] = { icon = "vendor", npc = 251091 }, -- Nael Silvertongue
        [52066062] = { icon = "vendor", npc = 251022 }, -- Alendis
        [52666115] = { icon = "mail", label = L["Mailbox"] },

        [56555521] = { icon = "vendor", npc = 245175 }, -- Darlia
        [54955556] = { icon = "vendor", npc = 245174 }, -- Feranin

        [55125003] = { icon = "vendor", npc = 245180 }, -- Sleyin
        [55274774] = { icon = "vendor", npc = 245181 }, -- Vanaris
        [52735025] = { icon = "vendor", npc = 245179 }, -- Vinemaster Suntouched
        [52494723] = { icon = "decor", npc = 250982 }, -- Dethelin
        [51904741] = { icon = "vendor", npc = 245183 }, -- Cravitz Lorent

        [52025578] = { icon = "vendor", npc = 258639 }, -- Valeriel

        -- Sanctum of Light
        [44997035] = { icon = "trainer", npc = 237941, class = "PRIEST" }, -- Aldrae
        [44447229] = { icon = "trainer", npc = 237940, class = "PRIEST" }, -- Lotheolan
        [46277033] = { icon = "trainer", npc = 237939, class = "PRIEST" }, -- Belestra

        -- Students of Shadow
        [50566074] = { icon = "trainer", npc = 251137, class = "WARLOCK" }, -- Torian
        [50866108] = { icon = "trainer", npc = 241482, class = "WARLOCK" }, -- Zanien
        [50916050] = { icon = "trainer", npc = 251114, class = "DEMONHUNTER" }, -- Tylos Darksight
        [50716124] = { icon = "trainer", npc = 251122, class = "ROGUE" }, -- Elara

        -- Second Identity
        [52865742] = { icon = "transmogrifier", npc = 243242 }, -- Warpweaver Diveera

        -- The Silver Chalice
        [52806350] = { icon = "vendor", npc = 250981 }, -- Faeldin

        -- Astalor's Sanctum
        [55666589] = { icon = "vendor", npc = 252956 }, -- Construct V'anore
        [55796603] = { icon = "decor", npc = 252956 }, -- Construct Ali'a

        -- Wayfarer's Rest
        [56467035] = { icon = "innkeeper", npc = 239630 }, -- Innkeeper Jovia
        [56356983] = { icon = "trainer", npc = 257913, picon = "cooking" }, -- Sylann
        [56446992] = { icon = "vendor", npc = 257914, picon = "cooking" }, -- Quelis
        [54867093] = { icon = "mail", label = L["Mailbox"] },

        -- Thalassian University
        [36156180] = { icon = "vendor", npc = 241459 }, -- Parnis
        [35916199] = { icon = "vendor", npc = 241458 }, -- Lothene

        -- Duskglow Gloriette
        [35286619] = { icon = "portal", label = L["Portal to Voidstorm"], note = QuelThalas, requirements = { quest = 86549 } }, -- check quest

        -- Dawning Lane
        [29236712] = { icon = "vendor", npc = 251129 }, -- Shara Sunwing
        [28656692] = { icon = "mail", label = L["Mailbox"] },

        -- Falconwing Square
        [27257737] = { icon = "stablemaster", npc = 251302 }, -- Shalenn

        [26498070] = { icon = "anvil", npc = 251449 }, -- Vara
        [25758038] = { icon = "anvil", npc = 251447 }, -- Farsil

        [29357695] = { icon = "trainer", npc = 251372, class = "MONK" }, -- Cyn'drel the Patient
        [29517697] = { icon = "trainer", npc = 251350, class = "MONK" }, -- Sho the Wise
        [28977773] = { icon = "trainer", npc = 251443, class = "ROGUE" }, -- Tannaria
        [29137783] = { icon = "trainer", npc = 251472, class = "WARRIOR" }, -- Lothan Silverblade
        [29257796] = { icon = "trainer", npc = 251441, class = "PALADIN" }, -- Noellene

        [29907946] = { icon = "trainer", npc = 251438, class = "PRIEST" }, -- Ponaris
        [30137946] = { icon = "trainer", npc = 251432, class = "MAGE" }, -- Garidel
        [30237926] = { icon = "trainer", npc = 251433, class = "WARLOCK" }, -- Celoenus
        [30707869] = { icon = "trainer", npc = 251296, class = "HUNTER" }, -- Zandine
        [30777856] = { icon = "trainer", npc = 251294, class = "HUNTER" }, -- Tana
        [30757839] = { icon = "trainer", npc = 251295, class = "HUNTER" }, -- Oninath

        [30447700] = { icon = "trainer", npc = 251431, profession = 197, picon = "tailoring" }, -- Kanaria

        [30107876] = { icon = "anvil", npc = 251301 }, -- Mathaleron
        [30197873] = { icon = "anvil", npc = 251289 }, -- Celana

        [30588002] = { icon = "trainer", npc = 251472, class = "WARRIOR" }, -- Sarithra
        [30648016] = { icon = "trainer", npc = 251472, class = "WARRIOR" }, -- Beldis
        [30748027] = { icon = "trainer", npc = 251472, class = "WARRIOR" }, -- Alsudar the Bastion

        [29898030] = { icon = "vendor", npc = 251427 }, -- Jarson Everlong (Pet Battle)
        [30968292] = { icon = "anvil", npc = 251446 }, -- Feylen

        [34098171] = { icon = "vendor", npc = 243224 }, -- Knight-Lord Bloodvalor
        [34018125] = { icon = "vendor", npc = 243225 }, -- Mirvedon
        [34048096] = { icon = "vendor", npc = 243221 }, -- Captain Dawnrunner
        [34028070] = { icon = "vendor", npc = 255844 }, -- Soryn
        [34048041] = { icon = "vendor", npc = 243220 }, -- Irissa Bloodstar
        [34328023] = { icon = "mail", label = L["Mailbox"] },

        [38868339] = { icon = "anvil", npc = 251416 }, -- Geron

        -- Silvermoon City
        [57356973] = { icon = "mail", label = L["Mailbox"] },
        [42187841] = { icon = "barber", label = L["Mirror"] },

        -- MISC
        -- [34605180] = { icon = "vendor", npc = 255782 }, -- Fosura Clearsun -- NOT FOUND
        -- [24566955] = { icon = "vendor", npc = 258550 }, -- Farstrider Aerieminder -- NO VENDOR
    }
} -- DB ENDE
