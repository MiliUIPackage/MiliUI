-- Rare Share Uldum module v0.1.0 based on v0.6.1 core module

local AddonName, Addon = ... 

RareShare:LoadModule({
    ID = 1530,
    Title = Addon.Loc.Title,
    Colour = "|cffff9956",
    Events = {},
    Rares = {
        [159087] = { Addon.Loc.Rares[159087], 1, false, false, 57834 }, -- Corrupted Bonestripper
        [154087] = { Addon.Loc.Rares[154087], 1, false, false, 56084 }, -- Zror'um the Infinite
        [154495] = { Addon.Loc.Rares[154495], 1, false, false, 56303 }, -- Will of N'Zoth
        [154333] = { Addon.Loc.Rares[154333], 1, false, false, 56183 }, -- Voidtender Malketh
        [154447] = { Addon.Loc.Rares[154447], 1, false, false, 56237 }, -- Brother Meller
        [154559] = { Addon.Loc.Rares[154559], 1, false, false, 56323 }, -- Deeplord Zrihj
        [154467] = { Addon.Loc.Rares[154467], 1, false, false, 56255 }, -- Chief Mek-mek
        [154600] = { Addon.Loc.Rares[154600], 1, false, false, 56332 }, -- Teng the Awakened
        [154332] = { Addon.Loc.Rares[154332], 1, false, false, 56183 }, -- Voidtender Malketh
        [154106] = { Addon.Loc.Rares[154106], 1, false, false, 56094 }, -- Quid
        [156083] = { Addon.Loc.Rares[156083], 1, false, false, 56954 }, -- Sanguifang
        [155958] = { Addon.Loc.Rares[155958], 1, false, false, 58507 }, -- Tashara
        [157162] = { Addon.Loc.Rares[157162], 1, false, false, 57346 }, -- Rei Lun
        [157160] = { Addon.Loc.Rares[157160], 1, false, false, 57345 }, -- Houndlord Ren
        [154490] = { Addon.Loc.Rares[154490], 1, false, false, 56302 }, -- Rijz'x the Devourer
        [157153] = { Addon.Loc.Rares[157153], 1, false, false, 57344 }, -- Ha-Li
        [157171] = { Addon.Loc.Rares[157171], 1, false, false, 57347 }, -- Heixi the Stonelord
        [157287] = { Addon.Loc.Rares[157287], 1, false, false, 57349 }, -- Dokani Obliterator
        [157176] = { Addon.Loc.Rares[157176], 1, false, false, 57342 }, -- The Forgotten
        [157279] = { Addon.Loc.Rares[157279], 1, false, false, 57348 }, -- Stormhowl
        [157267] = { Addon.Loc.Rares[157267], 1, false, false, 57343 },  -- Escaped Mutation
        [157290] = { Addon.Loc.Rares[157290], 1, false, false, 57350 }, -- Jade Watcher
        [157291] = { Addon.Loc.Rares[157291], 1, false, false, 57351 }, -- Spymaster Hul'ach
        [157183] = { Addon.Loc.Rares[157183], 1, false, false, 58296 }, -- Coagulated Anima
        [157466] = { Addon.Loc.Rares[157466], 1, false, false, 57363 }, -- Anh-De the Loyal
        [157443] = { Addon.Loc.Rares[157443], 1, false, false, 57358 }, -- Xiln the Mountain
        [157468] = { Addon.Loc.Rares[157468], 1, false, false, 57364 }, -- Tisiphon
        [160810] = { Addon.Loc.Rares[160810], 1, false, false, 58299 }, -- Harbinger Il'koxik
        [160826] = { Addon.Loc.Rares[160826], 1, false, false, 58301 }, -- Hive-Guard Naz'ruzek
        [160825] = { Addon.Loc.Rares[160825], 1, false, false, 58300 }, -- Amber-Shaper Esh'ri
        [154394] = { Addon.Loc.Rares[154394], 1, false, false, 56213 }, -- Veskan the Fallen
        [160867] = { Addon.Loc.Rares[160867], 1, false, false, 58302 }, -- Kzit'kovok
        [160868] = { Addon.Loc.Rares[160868], 1, false, false, 58303 }, -- Harrier Nir'verash
        [160874] = { Addon.Loc.Rares[160874], 1, false, false, 58305 }, -- Drone Keeper Ak'thet
        [160872] = { Addon.Loc.Rares[160872], 1, false, false, 58304 }, -- Destroyer Krox'tazar
        [160876] = { Addon.Loc.Rares[160876], 1, false, false, 58306 }, -- Enraged Amber Elemental
        [160893] = { Addon.Loc.Rares[160893], 1, false, false, 58308 }, -- Captain Vor'lek
        [160878] = { Addon.Loc.Rares[160878], 1, false, false, 58307 }, -- Buh'gzaki the Blasphemous
        [160920] = { Addon.Loc.Rares[160920], 1, false, false, 58310 }, -- Kal'tik the Blight
        [160906] = { Addon.Loc.Rares[160906], 1, false, false, 58309 }, -- Skiver
        [160922] = { Addon.Loc.Rares[160922], 1, false, false, 58311 }, -- Needler Zhesalla
        [157266] = { Addon.Loc.Rares[157266], 1, false, false, 57341 }, -- Kilxl the Gaping Maw
        [160930] = { Addon.Loc.Rares[160930], 1, false, false, 58312 }, -- Infused Amber Ooze
        [160968] = { Addon.Loc.Rares[160968], 1, false, false, 58295 }  -- Jade Colossus
    },
})
