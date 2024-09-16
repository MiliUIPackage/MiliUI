local addonName, addon = ...

-- this module adds +20 portal buttons to the M+ UI if the player has learned them

-- DB structure:
-- mapID = { -- number, the mapID of the M+ dungeon, eg 251 for The Underrot. from C_ChallengeMode.GetMapUIInfo(mapID) 
--   primarySpell = number, the spellID of the primary teleport to this dungeon
--   alternateSpells = {
--     number, [number, number...] spell IDs of next closest teleports, in order from closest to furthest
--   }
-- }

local db = {
    -- Dragonflight Season 2 (when this module was added)
    [406] = { -- Halls of Infusion
        primarySpell = 393283,
        alternateSpells = {
            393273, -- Algethar Academy
        },
    },
    [251] = { -- The Underrot
        primarySpell = 410074,
        alternateSpells = {
            281404, -- Dazar'alor (horde mage)
        },
    },
    [438] = { -- Vortex Pinnacle
        primarySpell = 410080,
        alternateSpells = {},
    },
    [206] = { -- Neltharion's Lair
        primarySpell = 410078,
        alternateSpells = {
            393766, -- Court of Stars
            224869, -- Dalaran Broken Isles (mage)
        },
    },
    [403] = { -- Uldaman 2.0
        primarySpell = 393222,
        alternateSpells = {},
    },
    [245] = { -- Freehold
        primarySpell = 410071,
        alternateSpells = {
            281403, -- Boralus (alliance mage)
        },
    },
    [405] = { -- Brackenhide Hollow
        primarySpell = 393267,
        alternateSpells = {
            393279, -- Azure Vault
        },
    },
    [404] = { -- Neltharus
        primarySpell = 393276,
        alternateSpells = {
            393256, -- Ruby Life Pools
        },
    },
    
    -- Dragonflight Season 3
    [168] = { -- Everbloom
        primarySpell = 159901,
        alternateSpells = {
            426410, -- Alternate teleport to Everbloom added in 10.2, unsure if this one is actually needed
            159900, -- Grimrail Depot
            159896, -- Iron Docks
        },
    },
    [248] = { -- Waycrest Manor
        primarySpell = 424167,
        alternateSpells = {},
    },
    [456] = { -- Throne of the Tides
        primarySpell = 424142,
        alternateSpells = {},
    },
    [464] = { -- Dawn of the Infinite: Murozond
        primarySpell = 424197,
        alternateSpells = {},
    },
    [463] = { -- Dawn of the Infinite: Galakrond
        primarySpell = 424197,
        alternateSpells = {},
    },
    [198] = { -- Darkheart Thicket
        primarySpell = 424163,
        alternateSpells = {
            424153, -- Black Rook Hold
        },
    },
    [199] = { -- Black Rook Hold
        primarySpell = 424153,
        alternateSpells = {
            424163, -- Darkheart Thicket
        },
    },
    [244] = { -- Atal'Dazar
        primarySpell = 424187,
        alternateSpells = {
            281404, -- Dazar'alor
        },
    },
    
    -- Dragonflight Season 4 (just adding the dungeons from Season 1, from before this module existed)
    [400] = { -- Nokhud Offensive
        primarySpell = 393262,
        alternateSpells = {},
    },
    [401] = { -- Azure Vault
        primarySpell = 393279,
        alternateSpells = {},
    },
    [399] = { -- Ruby Life Pools
        primarySpell = 393256,
        alternateSpells = {},
    },
    [402] = { -- Algethar Academy
        primarySpell = 393273,
        alternateSpells = {
            393283, -- Halls of Infusion
        },
    },
    
    -- TWW season 1
    [376] = { -- Necrotic Wake
        primarySpell = 354462,
        alternateSpells = {
            354466, -- Spires of Ascension
        },
    },
    [501] = { -- Stonevault
        primarySpell = 445269,
        alternateSpells = {},
    },
    [505] = { -- Dawnbreaker
        primarySpell = 445414,
        alternateSpells = {},
    },
    [353] = { -- Siege of Boralus
        primarySpell = 445418,
        alternateSpells = {
            464256, -- Also SOB - the other faction's one
            272270, -- Tol Dagor
        },
    },
    [375] = { -- Mists of Tirna Scythe
        primarySpell = 354464,
        alternateSpells = {
            354468, -- De Other Side
        },
    },
    [507] = { -- Grim Batol
        primarySpell = 445424,
        alternateSpells = {},
    },
    [502] = { -- City of Threads
        primarySpell = 445416,
        alternateSpells = {
            445417, -- Ara-Kara
        },
    },
    [502] = { -- Ara-Kara, City of Echoes
        primarySpell = 445417,
        alternateSpells = {
            445416, -- City of Threads
        },
    },
}

local loaded = false
function addon:initPortalButtons()
    if not addon.db.profile.portalButtons then return end
    
    hooksecurefunc(ChallengesFrame, "Update", function()
        if InCombatLockdown() then return end
        
        if loaded then return end
        loaded = true
        
        for i, icon in ipairs(ChallengesFrame.DungeonIcons) do
            local button = CreateFrame("Button", nil, icon, "SecureActionButtonTemplate")
            icon.MPAGPortalButton = button
            button:SetPoint("BOTTOM", icon, "TOP")
            button:RegisterForClicks("LeftButtonDown", "LeftButtonUp")
            button:SetSize(40, 40)
            button:SetHighlightTexture("Interface\\Buttons\\CheckButtonHilight", "ADD")
            
            local cdFrame = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
            cdFrame:SetAllPoints(button)
            cdFrame:SetDrawEdge(false)

            button:HookScript("OnEnter", function()
                GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
                GameTooltip:ClearLines()
                GameTooltip:SetSpellByID(button:GetAttribute("spell"))
                GameTooltip:Show()
            end)
            button:HookScript("OnLeave", function()
                GameTooltip:Hide()
                if icon:IsMouseOver() then return end
                button:Hide()
            end)
            button:Hide()
            
            icon:HookScript("OnEnter", function()
                if InCombatLockdown() then return end
                local data = db[icon.mapID]
                if data then
                    local spellID = data.primarySpell
                    
                    if not IsSpellKnown(spellID) then
                        spellID = nil
                        for _, sid in ipairs(data.alternateSpells) do
                            if IsSpellKnown(sid) then
                                spellID = sid
                                break
                            end
                        end
                        if not spellID then return end
                    end
                    
                    local button = icon.MPAGPortalButton
                    button:SetAttribute("type", "spell")
                    button:SetAttribute("spell", spellID)
                    local icon = C_Spell.GetSpellInfo(spellID).iconID
                    button:SetNormalTexture(icon)
                    local spellCooldownInfo = C_Spell.GetSpellCooldown(spellID)
                    local startTime, duration = spellCooldownInfo.startTime, spellCooldownInfo.duration
                    cdFrame:SetCooldown(startTime, duration)
                    button:Show()
                end
            end)
            
            icon:HookScript("OnLeave", function()
                if InCombatLockdown() then return end
                if button:IsMouseOver() then return end
                button:Hide()
            end)
        end
    end)
end
