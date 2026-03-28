local _, BR = ...

-- Lookup tables of known consumable item IDs, keyed by consumable type.
-- Values: `true` for simple membership, or a table with `label` (stat abbreviation) and optional fields.
-- Food tables: `{ label, badge }`. Flask tables: `{ label, badge, priority }`.
-- `badge`: bottom-left overlay text ("H" for hearty food, "R1"/"R2"/"R3" for flask quality).
BR.CONSUMABLE_ITEMS = {
    food = {
        -- TWW 11.0.0
        [222702] = { label = "低次屬" }, -- Skewered Fillet
        [222703] = { label = "低次屬" }, -- Simple Stew
        [222704] = { label = "低次屬" }, -- Unseasoned Field Steak
        [222705] = { label = "低次屬" }, -- Roasted Mycobloom
        [222706] = { label = "低次屬" }, -- Pan-Seared Mycobloom
        [222707] = { label = "低次屬" }, -- Hallowfall Chili
        [222708] = { label = "低次屬" }, -- Coreway Kabob
        [222709] = { label = "低次屬" }, -- Flashfire Fillet
        [222710] = { label = "耐/力" }, -- Meat and Potatoes
        [222711] = { label = "耐/敏" }, -- Rib Stickers
        [222712] = { label = "耐/智" }, -- Sweet and Sour Meatballs
        [222713] = { label = "耐力" }, -- Tender Twilight Jerky
        [222714] = { label = "加速" }, -- Zesty Nibblers
        [222715] = { label = "致命" }, -- Fiery Fish Sticks
        [222716] = { label = "臨機" }, -- Ginger-Glazed Fillet
        [222717] = { label = "精通" }, -- Salty Dog
        [222718] = { label = "速/致" }, -- Deepfin Patty
        [222719] = { label = "速/臨" }, -- Sweet and Spicy Soup
        [222720] = { label = "高次屬" }, -- The Sushi Special
        [222721] = { label = "致/臨" }, -- Fish and Chips
        [222722] = { label = "精/致" }, -- Salt Baked Seafood
        [222723] = { label = "精/臨" }, -- Marinated Tenderloins
        [222724] = { label = "耐/力" }, -- Sizzling Honey Roast
        [222725] = { label = "耐/敏" }, -- Mycobloom Risotto
        [222726] = { label = "耐/智" }, -- Stuffed Cave Peppers
        [222727] = { label = "耐力" }, -- Angler's Delight
        [222728] = { label = "高次屬" }, -- Beledar's Bounty
        [222729] = { label = "高次屬" }, -- Empress' Farewell
        [222730] = { label = "高次屬" }, -- Jester's Board
        [222731] = { label = "高次屬" }, -- Outsider's Provisions
        [222732] = { label = "大餐" }, -- Feast of the Divine Day
        [222733] = { label = "大餐" }, -- Feast of the Midnight Masquerade
        [222735] = { label = "低次屬" }, -- Everything Stew
        [222736] = { label = "精/速" }, -- Chippy Tea
        [222750] = { label = "低次屬", badge = "H" }, -- Hearty Skewered Fillet
        [222751] = { label = "低次屬", badge = "H" }, -- Hearty Simple Stew
        [222752] = { label = "低次屬", badge = "H" }, -- Hearty Unseasoned Field Steak
        [222753] = { label = "低次屬", badge = "H" }, -- Hearty Roasted Mycobloom
        [222754] = { label = "低次屬", badge = "H" }, -- Hearty Pan-Seared Mycobloom
        [222755] = { label = "低次屬", badge = "H" }, -- Hearty Hallowfall Chili
        [222756] = { label = "低次屬", badge = "H" }, -- Hearty Coreway Kabob
        [222757] = { label = "低次屬", badge = "H" }, -- Hearty Flashfire Fillet
        [222758] = { label = "耐/力", badge = "H" }, -- Hearty Meat and Potatoes
        [222759] = { label = "耐/敏", badge = "H" }, -- Hearty Rib Stickers
        [222760] = { label = "耐/智", badge = "H" }, -- Hearty Sweet and Sour Meatballs
        [222761] = { label = "耐力", badge = "H" }, -- Hearty Tender Twilight Jerky
        [222762] = { label = "加速", badge = "H" }, -- Hearty Zesty Nibblers
        [222763] = { label = "致命", badge = "H" }, -- Hearty Fiery Fish Sticks
        [222764] = { label = "臨機", badge = "H" }, -- Hearty Ginger-Glazed Fillet
        [222765] = { label = "精通", badge = "H" }, -- Hearty Salty Dog
        [222766] = { label = "速/致", badge = "H" }, -- Hearty Deepfin Patty
        [222767] = { label = "速/臨", badge = "H" }, -- Hearty Sweet and Spicy Soup
        [222768] = { label = "高次屬", badge = "H" }, -- Hearty Sushi Special
        [222769] = { label = "致/臨", badge = "H" }, -- Hearty Fish and Chips
        [222770] = { label = "精/致", badge = "H" }, -- Hearty Salt Baked Seafood
        [222771] = { label = "精/臨", badge = "H" }, -- Hearty Marinated Tenderloins
        [222772] = { label = "耐/力", badge = "H" }, -- Hearty Sizzling Honey Roast
        [222773] = { label = "耐/敏", badge = "H" }, -- Hearty Mycobloom Risotto
        [222774] = { label = "耐/智", badge = "H" }, -- Hearty Stuffed Cave Peppers
        [222775] = { label = "耐力", badge = "H" }, -- Hearty Angler's Delight
        [222776] = { label = "高次屬", badge = "H" }, -- Hearty Beledar's Bounty
        [222777] = { label = "高次屬", badge = "H" }, -- Hearty Empress' Farewell
        [222778] = { label = "高次屬", badge = "H" }, -- Hearty Jester's Board
        [222779] = { label = "高次屬", badge = "H" }, -- Hearty Outsider's Provisions
        [222780] = { label = "大餐", badge = "H" }, -- Hearty Feast of the Divine Day
        [222781] = { label = "大餐", badge = "H" }, -- Hearty Feast of the Midnight Masquerade
        [222783] = { label = "低次屬", badge = "H" }, -- Hearty Everything Stew
        [222784] = { label = "精/速", badge = "H" }, -- Hearty Chippy Tea
        [223966] = { label = "隨機" }, -- Everything-on-a-Stick (random Khaz Algar meal)
        [223967] = { label = "低次屬" }, -- Protein Slurp
        [223968] = { label = "低次屬" }, -- Spongey Scramble
        [225592] = { label = "速度" }, -- Exquisitely Eviscerated Muscle

        -- TWW 11.1.0
        [235805] = { label = "高次屬" }, -- Authentic Undermine Clam Chowder
        [235853] = { label = "高次屬", badge = "H" }, -- Hearty Authentic Undermine Clam Chowder

        -- Midnight 12.0.0
        [242272] = { label = "高次屬" }, -- Quel'dorei Medley
        [242273] = { label = "高次屬" }, -- Blooming Feast
        [242274] = { label = "高次屬" }, -- Champion's Bento
        [242275] = { label = "高主屬" }, -- Royal Roast
        [242276] = { label = "臨機" }, -- Braised Blood Hunter
        [242277] = { label = "加速" }, -- Crimson Calamari
        [242278] = { label = "致命" }, -- Tasty Smoked Tetra
        [242279] = { label = "中主屬" }, -- Baked Lucky Loa
        [242280] = { label = "臨機" }, -- Buttered Root Crab
        [242281] = { label = "精通" }, -- Glitter Skewers
        [242282] = { label = "加速" }, -- Null and Void Plate
        [242283] = { label = "致命" }, -- Sun-Seared Lumifin
        [242284] = { label = "臨機" }, -- Void-Kissed Fish Rolls
        [242285] = { label = "精通" }, -- Warped Wise Wings
        [242286] = { label = "加速" }, -- Fel-Kissed Filet
        [242287] = { label = "致命" }, -- Arcano Cutlets
        [242288] = { label = "中主屬" }, -- Twilight Angler's Medley
        [242289] = { label = "中主屬" }, -- Spellfire Filet
        [242290] = { label = "致/臨" }, -- Wise Tails
        [242291] = { label = "精/臨" }, -- Fried Bloomtail
        [242292] = { label = "精/致" }, -- Eversong Pudding
        [242293] = { label = "速/臨" }, -- Sunwell Delight
        [242294] = { label = "臨機" }, -- Felberry Figs
        [242295] = { label = "速/致" }, -- Hearthflame Supper
        [242296] = { label = "精/速" }, -- Bloodthistle-wrapped Cutlets
        [242302] = { label = "低主屬" }, -- Bloom Skewers
        [242303] = { label = "低主屬" }, -- Mana-Infused Stew
        [242304] = { label = "致/臨" }, -- Spiced Biscuits
        [242305] = { label = "精/臨" }, -- Silvermoon Standard
        [242306] = { label = "精/致" }, -- Forager's Medley
        [242307] = { label = "速/臨" }, -- Quick Sandwich
        [242308] = { label = "速/致" }, -- Portable Snack
        [242309] = { label = "精/速" }, -- Farstrider Rations
        [242532] = { label = "低主屬" }, -- [PH] Vegetarian Recipe
        [242744] = { label = "高次屬", badge = "H" }, -- Hearty Quel'dorei Medley
        [242745] = { label = "高次屬", badge = "H" }, -- Hearty Blooming Feast
        [242746] = { label = "高次屬", badge = "H" }, -- Hearty Champion's Bento
        [242747] = { label = "高主屬", badge = "H" }, -- Hearty Royal Roast
        [242748] = { label = "臨機", badge = "H" }, -- Hearty Braised Blood Hunter
        [242749] = { label = "加速", badge = "H" }, -- Hearty Crimson Calamari
        [242750] = { label = "致命", badge = "H" }, -- Hearty Tasty Smoked Tetra
        [242751] = { label = "中主屬", badge = "H" }, -- Hearty Rootland Surprise
        [242752] = { label = "臨機", badge = "H" }, -- Hearty Buttered Root Crab
        [242753] = { label = "精通", badge = "H" }, -- Hearty Glitter Skewers
        [242754] = { label = "加速", badge = "H" }, -- Hearty Null and Void Plate
        [242755] = { label = "致命", badge = "H" }, -- Hearty Sun-Seared Lumifin
        [242756] = { label = "臨機", badge = "H" }, -- Hearty Void-Kissed Fish Rolls
        [242757] = { label = "精通", badge = "H" }, -- Hearty Warped Wise Wings
        [242758] = { label = "加速", badge = "H" }, -- Hearty Fel-Kissed Filet
        [242759] = { label = "致命", badge = "H" }, -- Hearty Arcano Cutlets
        [242760] = { label = "中主屬", badge = "H" }, -- Hearty Twilight Angler's Medley
        [242761] = { label = "中主屬", badge = "H" }, -- Hearty Spellfire Filet
        [242762] = { label = "致/臨", badge = "H" }, -- Hearty Wise Tails
        [242763] = { label = "精/臨", badge = "H" }, -- Hearty Fried Bloomtail
        [242764] = { label = "精/致", badge = "H" }, -- Hearty Eversong Pudding
        [242765] = { label = "速/臨", badge = "H" }, -- Hearty Sunwell Delight
        [242766] = { label = "臨機", badge = "H" }, -- Hearty Felberry Figs
        [242767] = { label = "速/致", badge = "H" }, -- Hearty Hearthflame Supper
        [242768] = { label = "精/速", badge = "H" }, -- Hearty Bloodthistle-Wrapped Cutlets
        [242769] = { label = "低主屬", badge = "H" }, -- Hearty Bloom Skewers
        [242770] = { label = "低主屬", badge = "H" }, -- Hearty Mana-Infused Stew
        [242771] = { label = "致/臨", badge = "H" }, -- Hearty Spiced Biscuits
        [242772] = { label = "精/臨", badge = "H" }, -- Hearty Silvermoon Standard
        [242773] = { label = "精/致", badge = "H" }, -- Hearty Forager's Medley
        [242774] = { label = "速/臨", badge = "H" }, -- Hearty Quick Sandwich
        [242775] = { label = "速/致", badge = "H" }, -- Hearty Portable Snack
        [242776] = { label = "精/速", badge = "H" }, -- Hearty Farstrider Rations
        [255845] = { label = "大餐" }, -- Silvermoon Parade
        [255846] = { label = "大餐" }, -- Harandar Celebration
        [255847] = { label = "高主屬" }, -- Impossibly Royal Roast
        [255848] = { label = "高次屬" }, -- Flora Frenzy
        [266985] = { label = "大餐", badge = "H" }, -- Hearty Silvermoon Parade
        [266986] = { label = "高次屬", badge = "H" }, -- Hearty Quel'dorei Medley
        [266996] = { label = "大餐", badge = "H" }, -- Hearty Harandar Celebration
        [267000] = { label = "高次屬", badge = "H" }, -- Hearty Flora Frenzy
        [268679] = { label = "高主屬", badge = "H" }, -- Hearty Impossibly Royal Roast
        [268680] = { label = "高次屬", badge = "H" }, -- Hearty Flora Frenzy
        -- Recovery-only (no Well Fed buff, just health/mana restore). Not tracked, listed here for reference.
        -- [260264] = true, -- Quel'Danas Rations
        -- [260275] = true, -- Mukleech Curry
        -- [260276] = true, -- Akil'stew
        -- [260277] = true, -- Sedge Crawler Gumbo
        -- [260286] = true, -- Shrooms and Nectar
        -- [260299] = true, -- Roasted Abyssal Eel
    },
    -- Flask entries: { label, badge } for regular, { label, badge, priority } for fleeting/cauldron
    -- badge = quality rank (R1/R2/R3), priority = sort order (fleeting sort first)
    flask = {
        -- TWW 11.0.0 (3 tiers: R1 gold, R2 silver, R3 bronze)
        [212269] = { label = "致命", badge = "R1" }, -- Flask of Tempered Aggression
        [212270] = { label = "致命", badge = "R2" }, -- Flask of Tempered Aggression (quality 2)
        [212271] = { label = "致命", badge = "R3" }, -- Flask of Tempered Aggression (quality 3)
        [212272] = { label = "加速", badge = "R1" }, -- Flask of Tempered Swiftness
        [212273] = { label = "加速", badge = "R2" }, -- Flask of Tempered Swiftness (quality 2)
        [212274] = { label = "加速", badge = "R3" }, -- Flask of Tempered Swiftness (quality 3)
        [212275] = { label = "臨機", badge = "R1" }, -- Flask of Tempered Versatility
        [212276] = { label = "臨機", badge = "R2" }, -- Flask of Tempered Versatility (quality 2)
        [212277] = { label = "臨機", badge = "R3" }, -- Flask of Tempered Versatility (quality 3)
        [212278] = { label = "精通", badge = "R1" }, -- Flask of Tempered Mastery
        [212279] = { label = "精通", badge = "R2" }, -- Flask of Tempered Mastery (quality 2)
        [212280] = { label = "精通", badge = "R3" }, -- Flask of Tempered Mastery (quality 3)
        [212281] = { label = "隨機", badge = "R1" }, -- Flask of Alchemical Chaos
        [212282] = { label = "隨機", badge = "R2" }, -- Flask of Alchemical Chaos (quality 2)
        [212283] = { label = "隨機", badge = "R3" }, -- Flask of Alchemical Chaos (quality 3)
        [212299] = { label = "治療", badge = "R1" }, -- Flask of Saving Graces
        [212300] = { label = "治療", badge = "R2" }, -- Flask of Saving Graces (quality 2)
        [212301] = { label = "治療", badge = "R3" }, -- Flask of Saving Graces (quality 3)
        -- TWW 11.0.0 (fleeting/cauldron, 3 tiers)
        [212725] = { label = "致命", badge = "F1", priority = 1 }, -- Fleeting Flask of Tempered Aggression
        [212727] = { label = "致命", badge = "F2", priority = 1 }, -- Fleeting Flask of Tempered Aggression (quality 2)
        [212728] = { label = "致命", badge = "F3", priority = 1 }, -- Fleeting Flask of Tempered Aggression (quality 3)
        [212729] = { label = "加速", badge = "F1", priority = 1 }, -- Fleeting Flask of Tempered Swiftness
        [212730] = { label = "加速", badge = "F2", priority = 1 }, -- Fleeting Flask of Tempered Swiftness (quality 2)
        [212731] = { label = "加速", badge = "F3", priority = 1 }, -- Fleeting Flask of Tempered Swiftness (quality 3)
        [212732] = { label = "臨機", badge = "F1", priority = 1 }, -- Fleeting Flask of Tempered Versatility
        [212733] = { label = "臨機", badge = "F2", priority = 1 }, -- Fleeting Flask of Tempered Versatility (quality 2)
        [212734] = { label = "臨機", badge = "F3", priority = 1 }, -- Fleeting Flask of Tempered Versatility (quality 3)
        [212735] = { label = "精通", badge = "F1", priority = 1 }, -- Fleeting Flask of Tempered Mastery
        [212736] = { label = "精通", badge = "F2", priority = 1 }, -- Fleeting Flask of Tempered Mastery (quality 2)
        [212738] = { label = "精通", badge = "F3", priority = 1 }, -- Fleeting Flask of Tempered Mastery (quality 3)
        [212739] = { label = "隨機", badge = "F1", priority = 1 }, -- Fleeting Flask of Alchemical Chaos
        [212740] = { label = "隨機", badge = "F2", priority = 1 }, -- Fleeting Flask of Alchemical Chaos (quality 2)
        [212741] = { label = "隨機", badge = "F3", priority = 1 }, -- Fleeting Flask of Alchemical Chaos (quality 3)
        [212745] = { label = "治療", badge = "F1", priority = 1 }, -- Fleeting Flask of Saving Graces
        [212746] = { label = "治療", badge = "F2", priority = 1 }, -- Fleeting Flask of Saving Graces (quality 2)
        [212747] = { label = "治療", badge = "F3", priority = 1 }, -- Fleeting Flask of Saving Graces (quality 3)
        -- Midnight 12.0.0 (2 tiers: R1 gold, R2 silver)
        [241320] = { label = "臨機", badge = "R1" }, -- Flask of Thalassian Resistance
        [241321] = { label = "臨機", badge = "R2" }, -- Flask of Thalassian Resistance (quality 2)
        [241322] = { label = "精通", badge = "R1" }, -- Flask of the Magisters
        [241323] = { label = "精通", badge = "R2" }, -- Flask of the Magisters (quality 2)
        [241324] = { label = "加速", badge = "R1" }, -- Flask of the Blood Knights
        [241325] = { label = "加速", badge = "R2" }, -- Flask of the Blood Knights (quality 2)
        [241326] = { label = "致命", badge = "R1" }, -- Flask of the Shattered Sun
        [241327] = { label = "致命", badge = "R2" }, -- Flask of the Shattered Sun (quality 2)
        [241334] = { label = "PvP", badge = "R1" }, -- Vicious Thalassian Flask of Honor
        [241335] = { label = "PvP", badge = "R2" }, -- Vicious Thalassian Flask of Honor (quality 2)
        -- Midnight 12.0.0 (fleeting, 2 tiers)
        [245926] = { label = "臨機", badge = "F1", priority = 1 }, -- Fleeting Flask of Thalassian Resistance
        [245927] = { label = "臨機", badge = "F2", priority = 1 }, -- Fleeting Flask of Thalassian Resistance (quality 2)
        [245928] = { label = "致命", badge = "F1", priority = 1 }, -- Fleeting Flask of the Shattered Sun
        [245929] = { label = "致命", badge = "F2", priority = 1 }, -- Fleeting Flask of the Shattered Sun (quality 2)
        [245930] = { label = "加速", badge = "F1", priority = 1 }, -- Fleeting Flask of the Blood Knights
        [245931] = { label = "加速", badge = "F2", priority = 1 }, -- Fleeting Flask of the Blood Knights (quality 2)
        [245932] = { label = "精通", badge = "F1", priority = 1 }, -- Fleeting Flask of the Magisters
        [245933] = { label = "精通", badge = "F2", priority = 1 }, -- Fleeting Flask of the Magisters (quality 2)
    },
    -- Rune priority: lower number = use first (Ethereal > Soulgorged > Crystallized > legacy)
    rune = {
        [259085] = 1, -- Void-Touched Augment Rune (Midnight)
        [243191] = 2, -- Ethereal Augment Rune (TWW permanent)
        [246492] = 3, -- Soulgorged Augment Rune (TWW, persists through death)
        [224572] = 4, -- Crystallized Augment Rune (TWW single use)
        -- Legacy runes
        [211495] = 5, -- Dreambound Augment Rune (Dragonflight)
        [201325] = 6, -- Draconic Augment Rune (Dragonflight)
        [181468] = 7, -- Veiled Augment Rune (Shadowlands)
    },
    weapon = {
        -- Midnight 12.0.0
        [237367] = true, -- Refulgent Weightstone
        [237369] = true, -- Refulgent Weightstone (quality 2)
        [237370] = true, -- Refulgent Whetstone
        [237371] = true, -- Refulgent Whetstone (quality 2)
        [243733] = true, -- Thalassian Phoenix Oil
        [243734] = true, -- Thalassian Phoenix Oil (quality 2)
        [243735] = true, -- Oil of Dawn
        [243736] = true, -- Oil of Dawn (quality 2)
        [243737] = true, -- Smuggler's Enchanted Edge
        [243738] = true, -- Smuggler's Enchanted Edge (quality 2)
        [257749] = true, -- Laced Zoomshots
        [257750] = true, -- Laced Zoomshots (quality 2)
        [257751] = true, -- Weighted Boomshots
        [257752] = true, -- Weighted Boomshots (quality 2)
    },
}

-- Fleeting flask item IDs. These sort first by numeric priority but should NOT be
-- remembered — they would overwrite the user's regular flask preference.
BR.FLEETING_FLASK_ITEMS = {
    [245926] = true, -- Fleeting Flask of Thalassian Resistance
    [245927] = true, -- Fleeting Flask of Thalassian Resistance (quality 2)
    [245928] = true, -- Fleeting Flask of the Shattered Sun
    [245929] = true, -- Fleeting Flask of the Shattered Sun (quality 2)
    [245930] = true, -- Fleeting Flask of the Blood Knights
    [245931] = true, -- Fleeting Flask of the Blood Knights (quality 2)
    [245932] = true, -- Fleeting Flask of the Magisters
    [245933] = true, -- Fleeting Flask of the Magisters (quality 2)
}
