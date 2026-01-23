local addonName, addon = ...

local INFINITE_POWER_SPELL_ID = 1232454
local THROTTLE = 2

-- /dump AuraUtil.FindAura(function(_, _, _, ...) local _, _, _, _, _, _, _, _, _, spellId = ... return spellId == 1232454 end, "player", "HELPFUL")

function addon:initRemixInfinitePower()
    if not addon.db.profile.remixIP then return end
    if not (PlayerIsTimerunning() and (C_TimerunningUI.GetActiveTimerunningSeasonID() == 2)) then
        return
    end
    
    local function predicate(_, _, _, ...)
        local _, _, _, _, _, _, _, _, _, spellId = ...
        return spellId == INFINITE_POWER_SPELL_ID
    end
    
    local function getPlayerIP(unitID)
        local _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, point = AuraUtil.FindAura(predicate, unitID, "HELPFUL")
        return point
    end
    
    local lastScan = GetTime()
    local function scanParty()
        for partyIndex = 1, 4 do
            local ip = getPlayerIP("party"..partyIndex)
            if ip then
                local memberFrame = PartyFrame["MemberFrame"..partyIndex]
                if memberFrame then
                    local frame = memberFrame.MPAGInfinitePower or CreateFrame("Frame", nil, memberFrame)
                    memberFrame.MPAGInfinitePower = frame
                    frame:SetPoint("RIGHT", memberFrame, "LEFT")
                    frame:SetSize(40, 20)
                    
                    local text = frame.text or frame:CreateFontString(nil, "OVERLAY", "GameTooltipText")
                    frame.text = text
                    text:SetPoint("CENTER")
                    text:SetText(ip)
                end
            end
        end
    end
    
    local function scanRaid()
        for raidGroupIndex = 1, 8 do
            for raidMemberIndex = 1, 5 do
                local raidIndex = (raidGroupIndex * 5) - 5 + raidMemberIndex
                local ip = getPlayerIP("raid"..(raidIndex))
                if ip then
                    local memberFrame = _G["CompactRaidGroup"..raidGroupIndex.."Member"..raidMemberIndex]
                    if memberFrame then
                        local frame = memberFrame.MPAGInfinitePower or CreateFrame("Frame", nil, memberFrame)
                        memberFrame.MPAGInfinitePower = frame
                        frame:SetPoint("BOTTOM", memberFrame, "BOTTOM")
                        frame:SetSize(40, 20)
                        
                        local text = frame.text or frame:CreateFontString(nil, "OVERLAY", "GameTooltipText")
                        frame.text = text
                        text:SetPoint("CENTER")
                        text:SetText(ip)
                    end
                end
            end
        end
    end
    
    local eventHandler = CreateFrame("Frame")
    eventHandler:RegisterEvent("UNIT_AURA")
    eventHandler:SetScript("OnEvent", function()
        if (lastScan + THROTTLE) > GetTime() then return end
        if IsInGroup() then
            if IsInRaid() then
                scanRaid()
            else
                scanParty()
            end
            lastScan = GetTime()
        end
    end)
end