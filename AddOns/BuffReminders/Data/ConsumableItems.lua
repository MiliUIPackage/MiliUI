local _, BR = ...

-- Lookup tables of known consumable item IDs, keyed by consumable type.
-- Values: `true` for simple membership, or a number for priority sorting (lower = higher priority).
-- Food items may use a table with `label` (stat abbreviation) and `hearty` (boolean) fields.
BR.CONSUMABLE_ITEMS = {
    food = {
        [222702] = { label = "低次屬性" }, -- Skewered Fillet
        [222703] = { label = "低次屬性" }, -- Simple Stew
        [222704] = { label = "低次屬性" }, -- Unseasoned Field Steak
        [222705] = { label = "低次屬性" }, -- Roasted Mycobloom
        [222706] = { label = "低次屬性" }, -- Pan-Seared Mycobloom
        [222707] = { label = "低次屬性" }, -- Hallowfall Chili
        [222708] = { label = "低次屬性" }, -- Coreway Kabob
        [222709] = { label = "低次屬性" }, -- Flashfire Fillet
        [222710] = { label = "耐/力" }, -- Meat and Potatoes
        [222711] = { label = "耐/敏" }, -- Rib Stickers
        [222712] = { label = "耐/智" }, -- Sweet and Sour Meatballs
        [222713] = { label = "耐力" }, -- Tender Twilight Jerky
        [222714] = { label = "加速" }, -- Zesty Nibblers
        [222715] = { label = "致命" }, -- Fiery Fish Sticks
        [222716] = { label = "臨機" }, -- Ginger-Glazed Fillet
        [222717] = { label = "精通" }, -- Salty Dog
        [222718] = { label = "加速/致命" }, -- Deepfin Patty
        [222719] = { label = "加速/臨機" }, -- Sweet and Spicy Soup
        [222720] = { label = "高次屬性" }, -- The Sushi Special
        [222721] = { label = "致命/臨機" }, -- Fish and Chips
        [222722] = { label = "精通/致命" }, -- Salt Baked Seafood
        [222723] = { label = "精通/臨機" }, -- Marinated Tenderloins
        [222724] = { label = "耐/力" }, -- Sizzling Honey Roast
        [222725] = { label = "耐/敏" }, -- Mycobloom Risotto
        [222726] = { label = "耐/智" }, -- Stuffed Cave Peppers
        [222727] = { label = "耐力" }, -- Angler's Delight
        [222728] = { label = "高次屬性" }, -- Beledar's Bounty
        [222729] = { label = "高次屬性" }, -- Empress' Farewell
        [222730] = { label = "高次屬性" }, -- Jester's Board
        [222731] = { label = "高次屬性" }, -- Outsider's Provisions
        [222732] = { label = "大餐" }, -- 大餐 of the Divine Day
        [222733] = { label = "大餐" }, -- 大餐 of the Midnight Masquerade
        [222735] = { label = "低次屬性" }, -- Everything Stew
        [222736] = { label = "精通/加速" }, -- Chippy Tea
        [222750] = { label = "低次屬性", hearty = true }, -- Hearty Skewered Fillet
        [222751] = { label = "低次屬性", hearty = true }, -- Hearty Simple Stew
        [222752] = { label = "低次屬性", hearty = true }, -- Hearty Unseasoned Field Steak
        [222753] = { label = "低次屬性", hearty = true }, -- Hearty Roasted Mycobloom
        [222754] = { label = "低次屬性", hearty = true }, -- Hearty Pan-Seared Mycobloom
        [222755] = { label = "低次屬性", hearty = true }, -- Hearty Hallowfall Chili
        [222756] = { label = "低次屬性", hearty = true }, -- Hearty Coreway Kabob
        [222757] = { label = "低次屬性", hearty = true }, -- Hearty Flashfire Fillet
        [222758] = { label = "耐/力", hearty = true }, -- Hearty Meat and Potatoes
        [222759] = { label = "耐/敏", hearty = true }, -- Hearty Rib Stickers
        [222760] = { label = "耐/智", hearty = true }, -- Hearty Sweet and Sour Meatballs
        [222761] = { label = "耐力", hearty = true }, -- Hearty Tender Twilight Jerky
        [222762] = { label = "加速", hearty = true }, -- Hearty Zesty Nibblers
        [222763] = { label = "致命", hearty = true }, -- Hearty Fiery Fish Sticks
        [222764] = { label = "臨機", hearty = true }, -- Hearty Ginger-Glazed Fillet
        [222765] = { label = "精通", hearty = true }, -- Hearty Salty Dog
        [222766] = { label = "加速/致命", hearty = true }, -- Hearty Deepfin Patty
        [222767] = { label = "加速/臨機", hearty = true }, -- Hearty Sweet and Spicy Soup
        [222768] = { label = "高次屬性", hearty = true }, -- Hearty Sushi Special
        [222769] = { label = "致命/臨機", hearty = true }, -- Hearty Fish and Chips
        [222770] = { label = "精通/致命", hearty = true }, -- Hearty Salt Baked Seafood
        [222771] = { label = "精通/臨機", hearty = true }, -- Hearty Marinated Tenderloins
        [222772] = { label = "耐/力", hearty = true }, -- Hearty Sizzling Honey Roast
        [222773] = { label = "耐/敏", hearty = true }, -- Hearty Mycobloom Risotto
        [222774] = { label = "耐/智", hearty = true }, -- Hearty Stuffed Cave Peppers
        [222775] = { label = "耐力", hearty = true }, -- Hearty Angler's Delight
        [222776] = { label = "高次屬性", hearty = true }, -- Hearty Beledar's Bounty
        [222777] = { label = "高次屬性", hearty = true }, -- Hearty Empress' Farewell
        [222778] = { label = "高次屬性", hearty = true }, -- Hearty Jester's Board
        [222779] = { label = "高次屬性", hearty = true }, -- Hearty Outsider's Provisions
        [222780] = { label = "大餐", hearty = true }, -- Hearty 大餐 of the Divine Day
        [222781] = { label = "大餐", hearty = true }, -- Hearty 大餐 of the Midnight Masquerade
        [222783] = { label = "低次屬性", hearty = true }, -- Hearty Everything Stew
        [222784] = { label = "精通/加速", hearty = true }, -- Hearty Chippy Tea
        [223966] = { label = "隨機" }, -- Everything-on-a-Stick (random Khaz Algar meal)
        [223967] = { label = "低次屬性" }, -- Protein Slurp
        [223968] = { label = "低次屬性" }, -- Spongey Scramble
        [225592] = { label = "速度" }, -- Exquisitely Eviscerated Muscle
        [235805] = { label = "高次屬性" }, -- Authentic Undermine Clam Chowder
        [235853] = { label = "高次屬性", hearty = true }, -- Hearty Authentic Undermine Clam Chowder
        [242272] = { label = "高次屬性" }, -- Quel'dorei Medley
        [242273] = { label = "高次屬性" }, -- Blooming 大餐
        [242274] = { label = "高次屬性" }, -- Champion's Bento
        [242275] = { label = "大餐" }, -- Royal Roast
        [242276] = { label = "臨機" }, -- Braised Blood Hunter
        [242277] = { label = "加速" }, -- Crimson Calamari
        [242278] = { label = "致命" }, -- Tasty Smoked Tetra
        [242279] = { label = "大餐" }, -- Baked Lucky Loa
        [242280] = { label = "臨機" }, -- Buttered Root Crab
        [242281] = { label = "精通" }, -- Glitter Skewers
        [242282] = { label = "加速" }, -- Null and Void Plate
        [242283] = { label = "致命" }, -- Sun-Seared Lumifin
        [242284] = { label = "臨機" }, -- Void-Kissed Fish Rolls
        [242285] = { label = "精通" }, -- Warped Wise Wings
        [242286] = { label = "加速" }, -- Fel-Kissed Filet
        [242287] = { label = "致命" }, -- Arcano Cutlets
        [242288] = { label = "大餐" }, -- Twilight Angler's Medley
        [242289] = { label = "大餐" }, -- Spellfire Filet
        [242290] = { label = "致命/臨機" }, -- Wise Tails
        [242291] = { label = "精通/臨機" }, -- Fried Bloomtail
        [242292] = { label = "精通/致命" }, -- Eversong Pudding
        [242293] = { label = "加速/臨機" }, -- Sunwell Delight
        [242294] = { label = "臨機" }, -- Felberry Figs
        [242295] = { label = "加速/致命" }, -- Hearthflame Supper
        [242296] = { label = "精通/加速" }, -- Bloodthistle-wrapped Cutlets
        [242302] = { label = "大餐" }, -- Bloom Skewers
        [242303] = { label = "大餐" }, -- Mana-Infused Stew
        [242304] = { label = "致命/臨機" }, -- Spiced Biscuits
        [242305] = { label = "精通/臨機" }, -- Silvermoon Standard
        [242306] = { label = "精通/致命" }, -- Forager's Medley
        [242307] = { label = "加速/臨機" }, -- Quick Sandwich
        [242308] = { label = "加速/致命" }, -- Portable Snack
        [242309] = { label = "精通/加速" }, -- Farstrider Rations
        [242744] = { label = "高次屬性", hearty = true }, -- Hearty Quel'dorei Medley
        [242745] = { label = "高次屬性", hearty = true }, -- Hearty Blooming 大餐
        [242746] = { label = "高次屬性", hearty = true }, -- Hearty Champion's Bento
        [242747] = { label = "大餐", hearty = true }, -- Hearty Royal Roast
        [242748] = { label = "臨機", hearty = true }, -- Hearty Braised Blood Hunter
        [242749] = { label = "加速", hearty = true }, -- Hearty Crimson Calamari
        [242750] = { label = "致命", hearty = true }, -- Hearty Tasty Smoked Tetra
        [242751] = { label = "大餐", hearty = true }, -- Hearty Rootland Surprise
        [242752] = { label = "臨機", hearty = true }, -- Hearty Buttered Root Crab
        [242753] = { label = "精通", hearty = true }, -- Hearty Glitter Skewers
        [242754] = { label = "加速", hearty = true }, -- Hearty Null and Void Plate
        [242755] = { label = "致命", hearty = true }, -- Hearty Sun-Seared Lumifin
        [242756] = { label = "臨機", hearty = true }, -- Hearty Void-Kissed Fish Rolls
        [242757] = { label = "精通", hearty = true }, -- Hearty Warped Wise Wings
        [242758] = { label = "加速", hearty = true }, -- Hearty Fel-Kissed Filet
        [242759] = { label = "致命", hearty = true }, -- Hearty Arcano Cutlets
        [242760] = { label = "大餐", hearty = true }, -- Hearty Twilight Angler's Medley
        [242761] = { label = "大餐", hearty = true }, -- Hearty Spellfire Filet
        [242762] = { label = "致命/臨機", hearty = true }, -- Hearty Wise Tails
        [242763] = { label = "精通/臨機", hearty = true }, -- Hearty Fried Bloomtail
        [242764] = { label = "精通/致命", hearty = true }, -- Hearty Eversong Pudding
        [242765] = { label = "加速/臨機", hearty = true }, -- Hearty Sunwell Delight
        [242766] = { label = "臨機", hearty = true }, -- Hearty Felberry Figs
        [242767] = { label = "加速/致命", hearty = true }, -- Hearty Hearthflame Supper
        [242768] = { label = "精通/加速", hearty = true }, -- Hearty Bloodthistle-Wrapped Cutlets
        [242769] = { label = "大餐", hearty = true }, -- Hearty Bloom Skewers
        [242770] = { label = "大餐", hearty = true }, -- Hearty Mana-Infused Stew
        [242771] = { label = "致命/臨機", hearty = true }, -- Hearty Spiced Biscuits
        [242772] = { label = "精通/臨機", hearty = true }, -- Hearty Silvermoon Standard
        [242773] = { label = "精通/致命", hearty = true }, -- Hearty Forager's Medley
        [242774] = { label = "加速/臨機", hearty = true }, -- Hearty Quick Sandwich
        [242775] = { label = "加速/致命", hearty = true }, -- Hearty Portable Snack
        [242776] = { label = "精通/加速", hearty = true }, -- Hearty Farstrider Rations
        [255845] = { label = "大餐" }, -- Silvermoon Parade
        [255846] = { label = "大餐" }, -- Harandar Celebration
        [255847] = { label = "大餐" }, -- Impossibly Royal Roast
        [255848] = { label = "高次屬性" }, -- Flora Frenzy
        [266985] = { label = "大餐", hearty = true }, -- Hearty Silvermoon Parade
        [266986] = { label = "高次屬性", hearty = true }, -- Hearty Quel'dorei Medley
        [266996] = { label = "大餐", hearty = true }, -- Hearty Harandar Celebration
        [267000] = { label = "高次屬性", hearty = true }, -- Hearty Flora Frenzy
        [268679] = { label = "大餐", hearty = true }, -- Hearty Impossibly Royal Roast
        [268680] = { label = "高次屬性", hearty = true }, -- Hearty Flora Frenzy
        [242532] = { label = "大餐" }, -- [PH] Vegetarian Recipe
        [260264] = true, -- Quel'Danas Rations
        [260275] = true, -- Mukleech Curry
        [260276] = true, -- Akil'stew
        [260277] = true, -- Sedge Crawler Gumbo
        [260286] = true, -- Shrooms and Nectar
        [260299] = true, -- Roasted Abyssal Eel
    },
    -- Flask priority: cauldron flasks (1) are prioritized over regular flasks (true)
    flask = {
        -- Regular TWW flasks
        [212269] = true,
        [212270] = true,
        [212271] = true,
        [212272] = true,
        [212273] = true,
        [212274] = true,
        [212275] = true,
        [212276] = true,
        [212277] = true,
        [212278] = true,
        [212279] = true,
        [212280] = true,
        [212281] = true,
        [212282] = true,
        [212283] = true,
        [212299] = true,
        [212300] = true,
        [212301] = true,
        -- Cauldron TWW flasks
        [212725] = 1,
        [212727] = 1,
        [212728] = 1,
        [212729] = 1,
        [212730] = 1,
        [212731] = 1,
        [212732] = 1,
        [212733] = 1,
        [212734] = 1,
        [212735] = 1,
        [212736] = 1,
        [212738] = 1,
        [212739] = 1,
        [212740] = 1,
        [212741] = 1,
        [212745] = 1,
        [212746] = 1,
        [212747] = 1,
        [241320] = true,
        [241321] = true,
        [241322] = true,
        [241323] = true,
        [241324] = true,
        [241325] = true,
        [241326] = true,
        [241327] = true,
        [245926] = true,
        [245927] = true,
        [245928] = true,
        [245929] = true,
        [245930] = true,
        [245931] = true,
        [245932] = true,
        [245933] = true,
        -- Midnight flasks
        [236774] = true,
        [236776] = true,
        [236780] = true,
        [236950] = true,
        [240991] = true,
        [241310] = true,
        [241311] = true,
        [241312] = true,
        [241313] = true,
        [241314] = true,
        [241315] = true,
        [241316] = true,
        [241317] = true,
        [241334] = true,
        [241335] = true,
    },
    -- Rune priority: lower number = use first (Ethereal > Soulgorged > Crystallized > legacy)
    rune = {
        [243191] = 1, -- Ethereal Augment Rune (TWW permanent)
        [246492] = 2, -- Soulgorged Augment Rune (TWW, persists through death)
        [259085] = 3, -- Void-Touched Augment Rune (Midnight)
        [224572] = 4, -- Crystallized Augment Rune (TWW single use)
        -- Legacy runes
        [211495] = 5, -- Dreambound Augment Rune (Dragonflight)
        [201325] = 6, -- Draconic Augment Rune (Dragonflight)
        [181468] = 7, -- Veiled Augment Rune (Shadowlands)
    },
    weapon = {
        [220156] = true,
        [222502] = true,
        [222503] = true,
        [222504] = true,
        [222508] = true,
        [222509] = true,
        [222510] = true,
        [224105] = true,
        [224106] = true,
        [224107] = true,
        [224108] = true,
        [224109] = true,
        [224110] = true,
        [224111] = true,
        [224112] = true,
        [224113] = true,
        [237367] = true,
        [237369] = true,
        [237370] = true,
        [237371] = true,
        [243733] = true,
        [243734] = true,
        [243735] = true,
        [243736] = true,
        [243737] = true,
        [243738] = true,
        [257749] = true,
        [257750] = true,
        [257751] = true,
        [257752] = true,
        -- Midnight weapon enhancements
        [237372] = true,
        [237373] = true,
        [268032] = true,
        [268033] = true,
        [268034] = true,
    },
}
