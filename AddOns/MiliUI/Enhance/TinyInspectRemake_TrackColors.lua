
---------------------------------------------------------------
-- MiliUI Enhance: TinyInspect-Remake Upgrade Track Colors
-- 依裝備升級軌道 (精兵/勇士/英雄/神話) 套用品質色
-- 製作裝備加上製作規格前綴 (e.g. [烈光製作])，使用神話金色
-- Author: Mili
---------------------------------------------------------------

local DEBUG_CRAFTED = false

local TRACK_COLORS = {
    -- zh-TW / zh-CN
    ["探險者"]   = "ffffffff",
    ["冒險者"]   = "ffffffff",
    ["精兵"]     = "ff1eff00",
    ["勇士"]     = "ff0070dd",
    ["勇者"]     = "ff0070dd",
    ["英雄"]     = "ffa335ee",
    ["神話"]     = "ffff8000",
    -- enUS fallback
    ["Explorer"]   = "ffffffff",
    ["Adventurer"] = "ffffffff",
    ["Veteran"]    = "ff1eff00",
    ["Champion"]   = "ff0070dd",
    ["Hero"]       = "ffa335ee",
    ["Myth"]       = "ffff8000",
}

local CRAFTED_COLOR = "ffffd200"

local CRAFTED_QUALITY_COLORS = {
    [1] = "ffffffff",  -- Common (white)
    [2] = "ff1eff00",  -- Uncommon (green)
    [3] = "ff0070dd",  -- Rare (blue)
    [4] = "ffa335ee",  -- Epic (purple)
    [5] = "ffff8000",  -- Legendary (orange)
}

local GetItemUpgradeInfoAPI      = C_Item and C_Item.GetItemUpgradeInfo
local GetHyperlinkAPI            = C_TooltipInfo and C_TooltipInfo.GetHyperlink
local GetItemCraftedQualityAPI   = C_TradeSkillUI and C_TradeSkillUI.GetItemCraftedQualityByItemInfo

local ITEM_NAME_TYPE  = (Enum and Enum.TooltipDataLineType and Enum.TooltipDataLineType.ItemName)  or 22
local ITEM_LEVEL_TYPE = (Enum and Enum.TooltipDataLineType and Enum.TooltipDataLineType.ItemLevel) or 31

local function DebugPrintTooltip(link, data)
    if (not DEBUG_CRAFTED) then return end
    print(string.format("|cffffd200[MiliUI]|r Tooltip for %s", link or "?"))
    if (not data or not data.lines) then
        print("  (no tooltip data)")
        return
    end
    for i, line in ipairs(data.lines) do
        print(string.format("  [%d] type=%s text=%q",
            i, tostring(line.type), tostring(line.leftText or "")))
    end
end

local function StripColorCodes(text)
    if (not text) then return text end
    text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
    text = text:gsub("|r", "")
    return text
end

local function IsCraftedItem(link)
    if (not GetItemCraftedQualityAPI) then return false end
    local q = GetItemCraftedQualityAPI(link)
    return q ~= nil and q > 0
end

local function GetCraftedText(link)
    if (not GetHyperlinkAPI) then return end

    local crafted = IsCraftedItem(link)
    if (GetItemCraftedQualityAPI and not crafted) then return end

    local data = GetHyperlinkAPI(link)
    if (not data or not data.lines) then return end
    if (TooltipUtil and TooltipUtil.SurfaceArgs) then
        TooltipUtil.SurfaceArgs(data)
        for _, line in ipairs(data.lines) do
            TooltipUtil.SurfaceArgs(line)
        end
    end
    DebugPrintTooltip(link, data)

    if (crafted) then
        local afterName = false
        for _, line in ipairs(data.lines) do
            local t = line.type
            if (t == ITEM_LEVEL_TYPE) then break end
            if (afterName) then
                local text = StripColorCodes(line.leftText)
                if (text and text ~= "" and not text:find("<")) then
                    return text
                end
            end
            if (t == ITEM_NAME_TYPE) then afterName = true end
        end
    end

    for i = 2, math.min(#data.lines, 8) do
        local line = data.lines[i]
        local text = StripColorCodes(line and line.leftText)
        if (text and text ~= "" and not text:find("<") and not text:find("由")) then
            if (text:find("製作$") or text:find("crafted$") or text:find("Crafted$")) then
                return text
            end
        end
    end
end

local function HasActiveTrack(info)
    return info and info.trackString and info.maxLevel and info.maxLevel > 0
end

local function BuildTrackText(link)
    if (not link) then return end
    if (not TinyInspectRemakeDB or not TinyInspectRemakeDB.ShowUpgradeInfo) then return end
    if (GetItemUpgradeInfoAPI) then
        local info = GetItemUpgradeInfoAPI(link)
        if (HasActiveTrack(info)) then
            local color = TRACK_COLORS[info.trackString] or "ffffd200"
            if (info.currentLevel ~= nil) then
                return string.format("|c%s[%s %d/%d]|r %s",
                    color, info.trackString, info.currentLevel, info.maxLevel, link)
            else
                return string.format("|c%s[%s]|r %s", color, info.trackString, link)
            end
        elseif (info and info.trackString) then
            return link
        end
    end
    local craftText = GetCraftedText(link)
    if (craftText) then
        local quality = GetItemCraftedQualityAPI and GetItemCraftedQualityAPI(link)
        local color = CRAFTED_QUALITY_COLORS[quality or 0] or CRAFTED_COLOR
        return string.format("|c%s[%s]|r %s", color, craftText, link)
    end
end

local function RecolorFrame(self, frame, parent, ilevel)
    if (not frame) then return end

    local slots = {}
    local idx = 1
    while (frame["item" .. idx]) do
        slots[#slots + 1] = frame["item" .. idx]
        idx = idx + 1
    end

    local maxLvlW = 0
    for _, itemframe in ipairs(slots) do
        if (itemframe.levelString) then
            itemframe.levelString:SetWidth(0)
            local w = itemframe.levelString:GetStringWidth()
            if (w > maxLvlW) then maxLvlW = w end
        end
    end
    if (maxLvlW > 0) then
        for _, itemframe in ipairs(slots) do
            if (itemframe.levelString) then
                itemframe.levelString:SetWidth(maxLvlW)
                itemframe.levelString:SetJustifyH("LEFT")
            end
        end
    end

    local maxW = 160
    for _, itemframe in ipairs(slots) do
        if (itemframe.link and itemframe.itemString) then
            local newText = BuildTrackText(itemframe.link)
            if (newText) then
                itemframe.itemString:SetWidth(0)
                itemframe.itemString:SetText(newText)
            end
        end
        if (itemframe.itemString) then
            local w = itemframe.itemString:GetWidth()
            if (w > 260) then
                w = 260
                itemframe.itemString:SetWidth(w)
            end
            local frameWidth = w + math.max(64,
                math.floor(itemframe.label:GetWidth() + itemframe.levelString:GetWidth()) + 4)
            itemframe.width = frameWidth
            itemframe:SetWidth(frameWidth)
            if (maxW < frameWidth) then maxW = frameWidth end
        end
    end
    frame:SetWidth(maxW + 36)
end

-----------------------------------------------------------------
-- ItemLevel 數字顏色覆寫：
-- 若 ShowColoredItemLevelString 勾選，原本按物品品質上色；
-- 這裡改成：有升級軌道 -> 軌道色；製作裝備 -> 製作品質色；
-- 其他 -> 維持 TinyInspect 原本的品質色。
-----------------------------------------------------------------

local function GetItemLevelColor(link)
    if (not link) then return end
    if (GetItemUpgradeInfoAPI) then
        local info = GetItemUpgradeInfoAPI(link)
        if (HasActiveTrack(info) and TRACK_COLORS[info.trackString]) then
            return TRACK_COLORS[info.trackString]
        end
    end
    if (GetItemCraftedQualityAPI) then
        local q = GetItemCraftedQualityAPI(link)
        if (q and q > 0 and CRAFTED_QUALITY_COLORS[q]) then
            return CRAFTED_QUALITY_COLORS[q]
        end
    end
end

local function GetLinkForButton(button)
    if (not button) then return end
    if (button.OrigItemLink) then return button.OrigItemLink end
    local name = button.GetName and button:GetName()
    if (not name) then return end
    local id = button.GetID and button:GetID()
    if (not id) then return end
    if (name:match("^Character%w+Slot$")) then
        return GetInventoryItemLink("player", id)
    elseif (name:match("^Inspect%w+Slot$") and InspectFrame and InspectFrame.unit) then
        return GetInventoryItemLink(InspectFrame.unit, id)
    end
end

local function HookLevelStringSetText(frame, button)
    if (not frame or not frame.levelString or frame.MiliUILevelTextHooked) then return end
    frame.MiliUILevelTextHooked = true
    frame.MiliUIButton = button
    hooksecurefunc(frame.levelString, "SetText", function(self, text)
        if (self.__miliuiUpdating) then return end
        if (not TinyInspectRemakeDB or not TinyInspectRemakeDB.ShowColoredItemLevelString) then return end
        local link = GetLinkForButton(frame.MiliUIButton)
        if (not link) then return end
        local color = GetItemLevelColor(link)
        if (not color) then return end
        local plain = StripColorCodes(text or "") or ""
        if (plain == "") then return end
        self.__miliuiUpdating = true
        self:SetText("|c" .. color .. plain .. "|r")
        self.__miliuiUpdating = false
    end)
end

local function Setup()
    if (not C_AddOns or not C_AddOns.IsAddOnLoaded or not C_AddOns.IsAddOnLoaded("TinyInspect-Remake")) then
        return
    end
    local LibEvent = _G.LibStub and _G.LibStub:GetLibrary("LibEvent.7000", true)
    if (not LibEvent) then return end
    LibEvent:attachTrigger("INSPECT_FRAME_SHOWN", RecolorFrame)
    LibEvent:attachTrigger("ITEMLEVEL_FRAME_SHOWN", function(self, frame, parent, category)
        HookLevelStringSetText(frame, parent)
    end)
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", Setup)

SLASH_MILIUICRAFTDBG1 = "/miliuicraftdbg"
SlashCmdList.MILIUICRAFTDBG = function()
    DEBUG_CRAFTED = not DEBUG_CRAFTED
    print(string.format("|cffffd200[MiliUI]|r Crafted tooltip debug: %s",
        DEBUG_CRAFTED and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
end
