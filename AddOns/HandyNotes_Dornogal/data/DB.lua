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

----------------------------------------------------------------------------------------------------
----------------------------------------------DATABASE----------------------------------------------
----------------------------------------------------------------------------------------------------

local DB = {}
ns.DB = DB

DB.nodes = {
    [2339] = { -- Dornogal

        [44724642] = { icon = "innkeeper", npc = 212370 }, -- Ronesh

        [45105221] = { icon = "transmogrifier", npc = 221848 }, -- Warpweaver Voxin

        [55497721] = { icon = "vendor", npc = 219215 }, -- Hotharn
        [55237685] = { icon = "vendor", npc = 219213 }, -- Gilderann
        [54997647] = { icon = "vendor", npc = 219217 }, -- Velerd
        [55077619] = { icon = "vendor", npc = 219222 }, -- Lalandi

        [55655008] = { icon = "mail", label = L["Mailbox"] },
        [51724595] = { icon = "mail", label = L["Mailbox"] },
        [37644088] = { icon = "mail", label = L["Mailbox"] },
        [45364822] = { icon = "mail", label = L["Mailbox"] },

        [56724666] = { icon = "auctioneer", npc = 219040, sublabel = '' }, -- Auctioneer Prana
        [56924692] = { icon = "auctioneer", npc = 219037, sublabel = '' }, -- Auctioneer Durzin
        [57074719] = { icon = "auctioneer", npc = 219039, sublabel = '' }, -- Auctioneer Zyrgas

        [51174334] = { icon = "portal", label = L["Portal to The Timeways"], level = 80 }, -- RE(MOVED) / Needs S1?

        [54023820] = { icon = "vendor", npc=222561 }, -- Agmera

        -- Delver's Headqarters
        [47464362] = { icon = "vendor", npc = 208070 }, -- Sir Finley Mrrgglton

        -- Contender's Gate
        [59826931] = { icon = "vendor", npc = 219216 }, -- Rogurn
        [59986972] = { icon = "reforge", npc = 219073 }, -- Ledonir
        [60257001] = { icon = "vendor", npc = 219212 }, -- Maara

        -- The Forgegrounds
        [55376711] = { icon = "stablemaster", npc = 219376 }, -- Kargand

        [58506485] = { icon = "vendor", npc = 219230 }, -- Erani
        -- [58396470] = { icon = "vendor", npc = 226756 }, -- Giada Goldleash

        [57256084] = { icon = "vendor", npc = 224294 }, -- Osidion
        [57266056] = { icon = "vendor", npc = 219318 }, -- Jorid

        [56165766] = { icon = "vendor", npc = 219076 }, -- Kornd
        [57445814] = { icon = "vendor", npc = 219317 }, -- Kornak
        [57846048] = { icon = "vendor", npc = 219379 }, -- Morek
        [58806056] = { icon = "vendor", npc = 219324 }, -- Gerred
        [58756176] = { icon = "vendor", npc = 219325 }, -- Killm
        [58306270] = { icon = "vendor", npc = 219327 }, -- Nagar

        [58055645] = { icon = "craftingorders", npc = 215258 }, -- Clerk Gretal

        [58095520] = { icon = "bubble", npc = 219223 }, -- Mahra Treebender
        [58155559] = { icon = "mail", label = L["Mailbox"] },

        [58275374] = { icon = "anvil", npc = 219321 }, -- Grotir
        [58265327] = { icon = "vendor", npc = 219319 }, -- Yorda

        [45756871] = { icon = "mail", label = L["Mailbox"] },

        [47986785] = { icon = "rostrum", label = L["Rostrum of Transformation"] },

        [54066406] = { icon = "vendor", npc = 219285 }, -- Ramdah
        [54046520] = { icon = "vendor", npc = 219280 }, -- Durakh
        [51736769] = { icon = "vendor", npc = 219274 }, -- Brakha
        [50226764] = { icon = "anvil", npc = 219273 }, -- Breek
        [47276483] = { icon = "vendor", npc = 219255 }, -- Karbath
        [46156429] = { icon = "vendor", npc = 219247 }, -- Unak

        [50015431] = { icon = "catalyst", label = L["The Catalyst"] }, -- The Catalyst

        [51576861] = { icon = "vendor", npc = 219385 }, -- Nerada
        [50486853] = { icon = "vendor", npc = 219387 }, -- Belga

        [56216596] = { icon = "vendor", npc = 219380 }, -- Dokhan

        [53257066] = { icon = "vendor", npc = 219383 }, -- Malukh

        -- Lapidarium
        [58595264] = { icon = "barber", npc = 219052 }, -- Wireweaver Grelka

        -- The Ether House
        [58064879] = { icon = "transmogrifier", npc = 219053 }, -- Warpweaver Dezeeran
        [57704746] = { icon = "void", npc = 219054 }, -- Vaultkeeper Xir

        -- Shadestone Elixirs
        [61695186] = { icon = "vendor", npc = 219312 }, -- Gorenda

        -- The Fissure
        [62565094] = { icon = "vendor", npc = 219197 }, -- Griftah
        [62825137] = { icon = "vendor", npc = 219065 }, -- Grundaz
        [63624968] = { icon = "mail", label = L["Mailbox"] },

        -- The Knifeblock
        [64674956] = { icon = "vendor", npc = 219311 }, -- Kordan

        -- Madam Goya's Curiosities
        [64805264] = { icon = "auctioneer", npc = 219055 }, -- Madam Goya

        -- Council's Treasury
        [52974355] = { icon = "banker", npc = 219029 }, -- Counter Bardra
        [53734474] = { icon = "banker", npc = 219023 }, -- Counter Targrin
        [54794250] = { icon = "vendor", npc = 219036 }, -- Ardgaz
        [53954186] = { icon = "guildvault", label = L["config_guildvault"] },
        [54894326] = { icon = "guildvault", label = L["config_guildvault"] },

        -- Crafter's Enclave
        [59825640] = { icon = "vendor", npc = 219051 }, -- Lyrendal
        [59715561] = { icon = "craftingorders", npc = 219043 }, -- Clerk Ardran
        [59745588] = { icon = "craftingorders", npc = 219048 }, -- Clerk Pordaz

        -- Mythic Aspirations
        [52084224] = { icon = "vendor", npc = 219226 }, -- Vaskarn
        [52064196] = { icon = "reforge", npc = 219225 }, -- Cuzolth
        -- [53014236] = { icon = "vendor", npc = 219067 }, -- Nathden -- (RE)MOVED

        -- Stoneward's Rise
        [64971742] = { icon = "mail", label = L["Mailbox"] },

        -- Stoneshaper's Atrium
        [58153246] = { icon = "mail", label = L["Mailbox"] },

        -- Keepers Terrace
        [48482513] = { icon = "mail", label = L["Mailbox"] },

        -- Founding Hall
        [38162724] = { icon = "portal", label = L["Portal to Orgrimmar"], note = Durotar, faction = "Horde" },
        [41192269] = { icon = "portal", label = L["Portal to Stormwind"], note = ElwynnForest, faction = "Alliance" },
        -- [38872442] = { icon = "vendor", npc = 223725 }, -- Randulls Scredpyr / BUGGED -- (RE)MOVED
        -- [38972424] = { icon = "vendor", npc = 223727 }, -- Emissary of the Depths / BUGGED -- (RE)MOVED
        [39092417] = { icon = "vendor", npc = 223728 }, -- Auditor Balwurz
        -- [39252379] = { icon = "vendor", npc = 223726 }, -- Foreman Azap -- (RE)MOVED
        [40602894] = { icon = "portaltrainer", npc = 222631, class = "MAGE" }, -- Archmage Celindra

        -- Alchemy
        [47077052] = { icon = "trainer", npc = 219092, profession = 171, picon = "alchemy" }, -- Tarig
        [47327082] = { icon = "vendor", npc = 219091, profession = 171, picon = "alchemy" }, -- Grink

        -- Enchanting
        [52917131] = { icon = "trainer", npc = 219085, profession = 333, picon = "enchanting" }, -- Nagad
        [52367168] = { icon = "vendor", npc = 219086, profession = 333, picon = "enchanting" }, -- Llande

        -- Fishing, profession=356
        [50612680] = { icon = "vendor", npc = 219105, picon = "fishing" }, -- Hinodin
        [50482686] = { icon = "trainer", npc = 219106, picon = "fishing" }, -- Drokar

        -- Herbalism
        [44766931] = { icon = "trainer", npc = 219101, profession = 182, picon = "herbalism" }, -- Akdan
        [44696974] = { icon = "vendor", npc = 219093, profession = 182, picon = "herbalism" }, -- Vorig

        -- Inscription
        [48707117] = { icon = "trainer", npc = 219090, profession = 773, picon = "inscription" }, -- Brrigan
        [48767087] = { icon = "vendor", npc = 219089, profession = 773, picon = "inscription" }, -- Kardu
        [48817154] = { icon = "vendor", npc = 219249, profession = 773, picon = "inscription" }, -- Dogan

        -- Juwe
        [49477081] = { icon = "trainer", npc = 219087, profession = 755, picon = "jewelcrafting" }, -- Makir
        [49547153] = { icon = "vendor", npc = 219088, profession = 755, picon = "jewelcrafting" }, -- Uthaga

        -- Leatherworking
        [54315844] = { icon = "trainer", npc = 219080, profession = 165, picon = "leatherworking" }, -- Marbb
        [54455923] = { icon = "vendor", npc = 219081, profession = 165, picon = "leatherworking" }, -- Krinn

        -- Skinning
        [54275739] = { icon = "trainer", npc = 219083, profession = 393, picon = "skinning" }, -- Ginnad
        [54165696] = { icon = "vendor", npc = 219082, profession = 393, picon = "skinning" }, -- Kradan
        -- [54285664] = { icon = "trainer", npc = 226785, profession = 393, picon = "skinning" }, -- Kondal Huntsworn / BUGGED

        -- Tailor
        [54696370] = { icon = "trainer", npc = 219094, profession = 197, picon = "tailoring" }, -- Kotag
        [54776392] = { icon = "vendor", npc = 219100, profession = 197, picon = "tailoring" }, -- Berred

        -- Blacksmith
        [49186360] = { icon = "trainer", npc = 223644, profession = 164, picon = "blacksmithing" }, -- Darean
        [48676253] = { icon = "vendor", npc = 223643, profession = 164, picon = "blacksmithing" }, -- Borgos

        -- Engineer
        [49215593] = { icon = "trainer", npc = 219099, profession = 202, picon = "engineering" }, -- Thermalseer Arhdas
        [49305561] = { icon = "vendor", npc = 219098, profession = 202, picon = "engineering" }, -- Supply Foreman Drezmol

        -- Mining
        [52625254] = { icon = "trainer", npc = 219097, profession = 186, picon = "mining" }, -- Tarib
        [53145235] = { icon = "anvil", npc = 219096, profession = 186, picon = "mining" }, -- Gareb

        -- Cooking, profession=185
        [44184583] = { icon = "trainer", npc = 219104, picon = "cooking" }, -- Athodas
        [43584567] = { icon = "vendor", npc = 219103, picon = "cooking" } -- Kronzon
    }

} -- DB ENDE
