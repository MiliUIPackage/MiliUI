local _, Cell = ...
local F = Cell.funcs

-- stolen from elvui
local hiddenParent = CreateFrame("Frame", nil, _G.UIParent)
hiddenParent:SetAllPoints()
hiddenParent:Hide()

local function HideFrame(frame)
    if not frame then return end

    frame:UnregisterAllEvents()
    frame:Hide()
    frame:SetParent(hiddenParent)

    local health = frame.healthBar or frame.healthbar
    if health then
        health:UnregisterAllEvents()
    end

    local power = frame.manabar
    if power then
        power:UnregisterAllEvents()
    end

    local spell = frame.castBar or frame.spellbar
    if spell then
        spell:UnregisterAllEvents()
    end

    local altpowerbar = frame.powerBarAlt
    if altpowerbar then
        altpowerbar:UnregisterAllEvents()
    end

    local buffFrame = frame.BuffFrame
    if buffFrame then
        buffFrame:UnregisterAllEvents()
    end

    local petFrame = frame.PetFrame
    if petFrame then
        petFrame:UnregisterAllEvents()
    end
end

-- Stock Cell called _G.UIParent:UnregisterEvent("GROUP_ROSTER_UPDATE") here (and in
-- HideBlizzardRaid), inherited from the ElvUI recipe this file is stolen from. Removed: it is
-- DEAD CODE. UIParent does not register that event -- in current retail the whole
-- Blizzard_UIParent addon is an 11-line stub with no OnEvent handler at all, and nothing in
-- Blizzard's UI source calls UIParent:RegisterEvent (verified by grep over wow-ui-source live:
-- 0 hits across 2551 files, against 2519 :RegisterEvent calls overall). The monolithic
-- UIParent_OnEvent that used to drive UIParent_ManageFramePositions is long gone.
--
-- So this is a no-op either way; it is deleted for being misleading, not for an effect.
-- NeeRgY's fork also drops it and credits it with fixing scenario/delve objective tracking --
-- that cannot be the mechanism, so if their fix is real it came from something else in their
-- HideBlizzard rewrite. Do not re-add this line expecting it to hide anything.
function F.HideBlizzardParty()
    -- Midnight 12.0.0+ may have different party frame structure
    if _G.CompactPartyFrame then
        _G.CompactPartyFrame:UnregisterAllEvents()
        _G.CompactPartyFrame:SetParent(hiddenParent)
    end

    if _G.PartyFrame then
        _G.PartyFrame:UnregisterAllEvents()
        _G.PartyFrame:SetScript("OnShow", nil)
        if _G.PartyFrame.PartyMemberFramePool then
            for frame in _G.PartyFrame.PartyMemberFramePool:EnumerateActive() do
                HideFrame(frame)
            end
        end
        HideFrame(_G.PartyFrame)
    else
        -- Legacy party frame fallback
        for i = 1, 4 do
            HideFrame(_G["PartyMemberFrame"..i])
            HideFrame(_G["CompactPartyMemberFrame"..i])
        end
        if _G.PartyMemberBackground then
            HideFrame(_G.PartyMemberBackground)
        end
    end
end

-- Same dead UIParent:UnregisterEvent call removed here too. See the note above.
function F.HideBlizzardRaid()
    if _G.CompactRaidFrameContainer then
        _G.CompactRaidFrameContainer:UnregisterAllEvents()
        _G.CompactRaidFrameContainer:SetParent(hiddenParent)
    end
end

function F.HideBlizzardRaidManager()
    if CompactRaidFrameManager_SetSetting then
        CompactRaidFrameManager_SetSetting("IsShown", "0")
    end

    if _G.CompactRaidFrameManager then
        _G.CompactRaidFrameManager:UnregisterAllEvents()
        _G.CompactRaidFrameManager:SetParent(hiddenParent)
    end
end
