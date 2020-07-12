local Addon = LibStub("AceAddon-3.0"):GetAddon("CorruptionTooltips")
local Module = Addon:NewModule("Summary", "AceHook-3.0", "AceEvent-3.0")

local Config, Scanner

local P, I, slotNames

function Module:OnInitialize()
    Config = Addon:GetModule("Config")
    Scanner = Addon:GetModule("Scanner")
    slotNames = Scanner:GetSlots()
    self:RegisterEvent('ADDON_LOADED', 'OnLoad')
    self:RegisterEvent('PLAYER_LOGIN', 'OnLogin')
end

function Module:OnEnable()
    self:SecureHookScript(CharacterStatsPane.ItemLevelFrame.Corruption, 'OnEnter', 'SummaryEnter')
    self:SecureHookScript(CharacterStatsPane.ItemLevelFrame.Corruption, 'OnLeave', 'SummaryLeave')
end

function Module:OnLoad(event, ...)
    if (...) == "Blizzard_InspectUI" then
        self:UnregisterEvent(event)
        I = CreateFrame("Frame", nil, _G.InspectPaperDollFrame)
        self:SetupCharacterFrame(I)
    end
end

function Module:OnLogin(event, ...)
    self:UnregisterEvent(event)
    P = CreateFrame("Frame", nil, _G.PaperDollFrame)
    self:SetupCharacterFrame(P)
end

function Module:SummaryEnter(frame)
    self:CharacterFrameShow(P)
    self:SummaryHook(frame)
end

function Module:SummaryLeave(frame)
    self:CharacterFrameShow(P)
end

function Module:SummaryHook(frame)
    if Config:GetOption("summary") ~= false then
        local corruptions = Scanner:GetCharacterCorruptions()
        if #corruptions > 0 then
            GameTooltip:AddLine(" ")

            local buckets = {}
            for i=1, #corruptions do
                local name = corruptions[i][1]
                local icon = corruptions[i][2]
                local line = '|T'..icon..':0|t |cff956dd1'..name..'|r'
                if Config:GetOption("icon") ~= true then
                    line = '|cff956dd1'..name..'|r'
                end

                if buckets[name] == nil then
                    buckets[name] = {
                        1,
                        line,
                    }
                else
                    buckets[name][1]= buckets[name][1] + 1
                end
            end
            table.sort(buckets)
            for name, _ in pairs(buckets) do
                GameTooltip:AddLine("|cff956dd1"..buckets[name][1]..' x '..buckets[name][2].."|r")
            end

            GameTooltip:Show()
        end
    end
end

function Module:returnPoints(slotId)
    if slotId <= 5 or slotId == 15 or slotId == 9 then -- Left side
        return "LEFT", "RIGHT", 8, 0, "LEFT", "MIDDLE"
    elseif slotId <= 14 then -- Right side
        return "RIGHT", "LEFT", -8, 0, "RIGHT", "MIDDLE"
    else -- Weapon slots
        return "BOTTOM", "TOP", 2, 3, "CENTER", "MIDDLE"
    end
end

function Module:SetupCharacterFrame(frame)
    if #frame > 0 then return end

    if frame == P then
        frame:SetFrameLevel(_G.CharacterHeadSlot:GetFrameLevel())
        self:SecureHook("PaperDollItemSlotButton_Update", 'CharacterFrameUpdate')
        self:SecureHookScript(frame, "OnShow", 'CharacterFrameShow')
    else
        frame:SetFrameLevel(_G.InspectHeadSlot:GetFrameLevel())
        self:SecureHook("InspectPaperDollItemSlotButton_Update", 'CharacterFrameUpdate')
    end

    for i = 1, #slotNames do
        frame[i] = CreateFrame("Frame", nil, frame)
        local s = frame[i]:CreateFontString(nil, "OVERLAY", "GameFontNormalOutline") -- Revert the previous fix, the smaller text size made it bit too hard to read the icons
        frame[i]:SetAllPoints(s) -- Fontstring anchoring hack by SDPhantom https://www.wowinterface.com/forums/showpost.php?p=280136&postcount=6
        frame[i].string = s;
    end

    local point
    if frame == P then
        point = "Character"
    else
        point = "Inspect"
    end

    for i = 1, #slotNames do -- Set Point and Justify
        local parent = _G[ point..slotNames[i] ]
        local myPoint, parentPoint, x, y, justifyH, justifyV = self:returnPoints(i)
        frame[i].string:ClearAllPoints()
        frame[i].string:SetPoint(myPoint, parent, parentPoint, x, y)
        frame[i].string:SetJustifyH(justifyH)
        frame[i].string:SetJustifyV(justifyV)
        frame[i].string:SetFormattedText("")
    end
end

function Module:CharacterFrameShow(frame)
    C_Timer.After(0, function()
        for slotId = 1, #slotNames do
            self:UpdateCharacterFrame(frame, "player", slotId)
        end
    end)
end

function Module:CharacterFrameUpdate(button)
    local slotId = button:GetID()
    local frame, unit

    if (button:GetParent():GetName() == "PaperDollItemsFrame") then
        frame, unit = P, "player"
    elseif (button:GetParent():GetName()) == "InspectPaperDollItemsFrame" then
        frame, unit = I, _G.InspectFrame.unit or "target"
    end
    self:UpdateCharacterFrame(frame, unit, slotId)
end

function Module:UpdateCharacterFrame(frame, unit, slotId)
    if unit and slotId <= #slotNames then
        local itemLink = GetInventoryItemLink(unit, slotId)
        if Config:GetOption("showlevel") == true and itemLink then
            if IsCorruptedItem(itemLink) and CharacterStatsPane.ItemLevelFrame.Corruption.tooltipShowing then
                local item = Item:CreateFromItemLink(itemLink)
                item:ContinueOnItemLoad(function()
                    local corruption = GetItemStats(item:GetItemLink())
                    if corruption["ITEM_MOD_CORRUPTION"] > 0 then
                        local line = '|cff956dd1'..corruption["ITEM_MOD_CORRUPTION"]..'|r'
                        frame[slotId].string:SetFormattedText(line)
                    end
                end)
                return
            end
        end
        frame[slotId].string:SetFormattedText("")
    end
end
