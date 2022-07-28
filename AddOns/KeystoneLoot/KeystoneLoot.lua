KeystoneLoot = LibStub("AceAddon-3.0"):NewAddon("KeystoneLoot",
                                                "AceConsole-3.0",
                                                "AceEvent-3.0");
local L = LibStub("AceLocale-3.0"):GetLocale("KeystoneLoot", true)

local lineAdded = false

local numScreen = ""

local frame = CreateFrame("Frame");
frame:RegisterEvent("ADDON_LOADED");

frame:SetScript("OnEvent", function(self, event, ...)
    if (event == "ADDON_LOADED") then
        local addon = ...

        -- if (addon == "Blizzard_ChallengesUI") then		

        -- local iLvlFrm = CreateFrame("Frame","LootLevel",ChallengesModeWeeklyBest);
        -- iLvlFrm:SetWidth(100);
        -- iLvlFrm:SetHeight(50);
        -- iLvlFrm:SetPoint("CENTER",-128,-37); 

        -- sdm_SetTooltip(iLvlFrm, L["This shows the level of the item you'll find in this week's chest."]);

        -- iLvlFrm.text = iLvlFrm:CreateFontString(nil, "MEDIUM", "GameFontHighlightLarge");
        -- iLvlFrm.text:SetAllPoints(iLvlFrm);
        -- iLvlFrm.text:SetFont("Fonts\\FRIZQT__.TTF",30);
        -- iLvlFrm.text:SetPoint("CENTER",0,0);
        -- iLvlFrm.text:SetTextColor(1,0,1,1);
        -- iLvlFrm:SetScript("OnUpdate",function(self,elaps)		
        -- self.time = (self.time or 1)-elaps

        -- if (self.time > 0) then
        -- return
        -- end

        -- while (self.time <= 0) do				
        -- if (ChallengesModeWeeklyBest) then                    
        -- numScreen = ChallengesModeWeeklyBest.Child.Level:GetText();				

        -- self.time = self.time+1;

        -- self.text:SetText(MythicWeeklyLootItemLevel(numScreen));	
        ----self.text:SetText(numScreen);
        -- self:SetScript("OnUpdate",nil);
        -- end					
        -- end
        -- end)		
        -- end
    end
end)

-- Tooltip functions
function sdm_OnEnterTippedButton(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    -- GameTooltip:SetText(self.tooltipText, nil, nil, nil, nil, true)

    GameTooltip:AddLine("|cffff00ff" .. L["Weekly Chest Reward"] .. "|r")
    GameTooltip:AddLine("|cff00ff00" .. self.tooltipText .. "|r")
    GameTooltip:Show()
end

function sdm_OnLeaveTippedButton() GameTooltip_Hide() end

-- if text is provided, sets up the button to show a tooltip when moused over. Otherwise, removes the tooltip.
function sdm_SetTooltip(self, text)
    if text then
        self.tooltipText = text
        self:SetScript("OnEnter", sdm_OnEnterTippedButton)
        self:SetScript("OnLeave", sdm_OnLeaveTippedButton)
    else
        self:SetScript("OnEnter", nil)
        self:SetScript("OnLeave", nil)
    end
end

local function OnTooltipSetItem(tooltip, ...)
    name, link = GameTooltip:GetItem()

    -- The player is using the Auction House, return!
    if (link == nil) then return end

    for itemLink in link:gmatch("|%x+|Hkeystone:.-|h.-|h|r") do
        local itemString = string.match(itemLink, "keystone[%-?%d:]+")
        -- local itemName = string.match(itemLink, "\124h.-\124h"):gsub("%[","%%[)("):gsub("%]",")(%%]")
        -- local _,itemid,_,_,_,_,_,_,_,_,_,flags,_,_,mapid,mlvl,modifier1,modifier2,modifier3 = strsplit(":", itemString)
        -- keystone:234:12:1:6:3:9
        local mlvl = select(4, strsplit(":", itemString))

        local ilvl = MythicLootItemLevel(mlvl)
        local wlvl = MythicWeeklyLootItemLevel(mlvl)

        -- if (itemid == "138019") then -- Mythic Keystone
        if not lineAdded then
            tooltip:AddLine("|cffff00ff" .. L["Loot Item Level: "] .. ilvl ..
                                "|r") -- 551A8B   --ff00ff 
            tooltip:AddLine("|cffff00ff" .. L["Weekly Chest Item Level: "] ..
                                wlvl .. "|r") -- 551A8B   --ff00ff
            lineAdded = true
        end
        -- end
    end
end

local function OnTooltipCleared(tooltip, ...) lineAdded = false end

-- ITEM REF Tooltip
local function SetHyperlink_Hook(self, hyperlink, text, button)
    -- local _,itemid,_,_,_,_,_,_,_,_,_,flags,_,_,mapid,mlvl,modifier1,modifier2,modifier3 = strsplit(":", hyperlink)
    local itemString = string.match(hyperlink, "keystone[%-?%d:]+")
    if itemString == nil or itemString == "" then return end
    if strsplit(":", itemString) == "keystone" then
        local mlvl = select(4, strsplit(":", hyperlink))

        local ilvl = MythicLootItemLevel(mlvl)
        local wlvl = MythicWeeklyLootItemLevel(mlvl)
        -- local FULLINFO = itemString

        -- if (itemid == "138019") then -- Mythic Keystone			
        ItemRefTooltip:AddLine(
            "|cffff00ff" .. L["Loot Item Level: "] .. ilvl .. "+" .. "|r", 1, 1,
            1, true) -- 551A8B   --ff00ff 
        ItemRefTooltip:AddLine(
            "|cffff00ff" .. L["Weekly Chest Item Level: "] .. wlvl .. "|r", 1,
            1, 1, true) -- 551A8B   --ff00ff 
        ItemRefTooltip:Show()
        -- if not lineAdded then				
        --	ItemRefTooltip:AddLine("|cffff00ff" .. L["Loot Item Level: "] .. ilvl .. "+" .. "|r", 1,1,1,true) --551A8B   --ff00ff 
        --	ItemRefTooltip:AddLine("|cffff00ff" .. L["Weekly Chest Item Level: "] .. wlvl .."|r", 1,1,1,true) --551A8B   --ff00ff 
        --	ItemRefTooltip:Show()
        -- lineAdded = true
        -- end		
        -- end
    end
end

GameTooltip:HookScript("OnTooltipSetItem", OnTooltipSetItem)
GameTooltip:HookScript("OnTooltipCleared", OnTooltipCleared)
hooksecurefunc("ChatFrame_OnHyperlinkShow", SetHyperlink_Hook)

function MythicLootItemLevel(mlvl)
    if (mlvl == "2") then
        return "187"
    elseif (mlvl == "3") then
        return "190"
    elseif (mlvl == "4" or mlvl == "5") then
        return "194"
    elseif (mlvl == "6") then
        return "197"
    elseif (mlvl == "7" or mlvl == "8" or mlvl == "9") then
        return "200"
    elseif (mlvl == "10" or mlvl == "11") then
        return "203"
    elseif (mlvl == "12" or mlvl == "13" or mlvl == "14") then
        return "207"
    elseif (mlvl >= "15") then
        return "210"
    else
        return ""
    end
end

function MythicWeeklyLootItemLevel(mlvl)
    if (mlvl == "2") then
        return "200"
    elseif (mlvl == "3") then
        return "203"
    elseif (mlvl == "4") then
        return "207"
    elseif (mlvl == "5" or mlvl == "6") then
        return "210"
    elseif (mlvl == "7") then
        return "213"
    elseif (mlvl == "8" or mlvl == "9") then
        return "216"
    elseif (mlvl == "10" or mlvl == "11") then
        return "220"
    elseif (mlvl == "12" or mlvl == "13") then
        return "223"
    elseif (mlvl >= "14") then
        return "226"
    else
        return ""
    end
end
--[[
function KeystoneLoot:OnInitialize()
    -- Called when the addon is loaded

    -- Print a message to the chat frame
    self:Print(L["KeystoneLoot: Loaded"])
end

function KeystoneLoot:OnEnable()
    -- Called when the addon is enabled

    -- Print a message to the chat frame		
    self:Print(L["KeystoneLoot: Enabled"])
end

function KeystoneLoot:OnDisable()
    -- Called when the addon is disabled
    self:Print(L["KeystoneLoot: Disabled"])
end
--]]