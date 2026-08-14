
---------------------------------------------------------------
-- MiliUI Enhance: TinyInspect-Remake Upgrade Track Colors
-- 依裝備升級軌道 (精兵/勇士/英雄/神話) 套用品質色
-- 製作裝備加上製作規格前綴 (e.g. [烈光製作])，使用神話金色
-- Author: Mili
---------------------------------------------------------------

local DEBUG_CRAFTED = false
local DEBUG_TRACK = false
local DEBUG_ILVL = false

local function DebugILvl(fmt, ...)
    if (not DEBUG_ILVL) then return end
    print("|cffffd200[MiliUI-ILVL]|r " .. string.format(fmt, ...))
end

-- 把 | 跳脫掉才看得到 link 裡的 bonusID，否則聊天視窗會渲染成可點的物品連結
local function EscapeLink(link)
    if (not link) then return "nil" end
    return (tostring(link):gsub("|", "||"))
end

local TRACK_COLORS = {
    -- zh-TW / zh-CN
    ["探險者"]   = "ffffffff",
    ["冒險者"]   = "ffffffff",
    ["精兵"]     = "ff1eff00",
    ["勇士"]     = "ff0070dd",
    ["勇者"]     = "ff0070dd",
    ["英雄"]     = "ffa335ee",
    ["神話"]     = "ffff8000",
    ["傳奇"]     = "ffff8000",
    -- enUS fallback
    ["Explorer"]   = "ffffffff",
    ["Adventurer"] = "ffffffff",
    ["Veteran"]    = "ff1eff00",
    ["Champion"]   = "ff0070dd",
    ["Hero"]       = "ffa335ee",
    ["Myth"]       = "ffff8000",
    ["Legendary"]  = "ffff8000",
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
local GetLootInfoByIndex         = (C_EncounterJournal and C_EncounterJournal.GetLootInfoByIndex)
                                   or EJ_GetLootInfoByIndex

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

local function GetTooltipLines(link)
    if (not GetHyperlinkAPI or not link) then return end
    local data = GetHyperlinkAPI(link)
    if (not data or not data.lines) then return end
    if (TooltipUtil and TooltipUtil.SurfaceArgs) then
        TooltipUtil.SurfaceArgs(data)
        for _, line in ipairs(data.lines) do
            TooltipUtil.SurfaceArgs(line)
        end
    end
    return data
end

local function IsCraftedItem(link)
    if (not GetItemCraftedQualityAPI) then return false end
    local q = GetItemCraftedQualityAPI(link)
    return q ~= nil and q > 0
end

local function GetCraftedText(link, data)
    local crafted = IsCraftedItem(link)
    if (GetItemCraftedQualityAPI and not crafted) then return end

    data = data or GetTooltipLines(link)
    if (not data) then return end
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

local FORGE_COLOR = "ffff8000"

-- 特殊裝備關鍵字 (出現在物品名稱與物品等級之間的提示行)，一律套傳奇橘色。
-- match 為字串時做子字串比對；為表格時需「全部」子字串都出現才算命中。
-- text 省略時顯示整行原文。
local SPECIAL_KEYWORDS = {
    { match = "虛無鍛造",  text = "虛無鍛造" },  -- Null Forge (zh-TW)
    { match = "Null Forge", text = "Null Forge" },
    { match = { "含孢", "傳奇" }, text = "含孢：傳奇" },  -- 只有「含孢：傳奇」套橘色，其餘含孢軌跡維持原色
}

local function GetForgeInfo(link, data)
    data = data or GetTooltipLines(link)
    if (not data) then return end
    local afterName = false
    for _, line in ipairs(data.lines) do
        local t = line.type
        if (t == ITEM_LEVEL_TYPE) then break end
        if (afterName) then
            local text = StripColorCodes(line.leftText)
            if (text) then
                for _, kw in ipairs(SPECIAL_KEYWORDS) do
                    local hit
                    if (type(kw.match) == "table") then
                        hit = true
                        for _, m in ipairs(kw.match) do
                            if (not text:find(m, 1, true)) then
                                hit = false
                                break
                            end
                        end
                    else
                        hit = text:find(kw.match, 1, true) ~= nil
                    end
                    if (hit) then
                        return kw.text or text, FORGE_COLOR
                    end
                end
            end
        end
        if (t == ITEM_NAME_TYPE) then afterName = true end
    end
end

-- C_Item.GetItemUpgradeInfo 對 Journal 的預覽連結常常回一組沒有 trackString 的空表，
-- 但遊戲自己在工具提示上印的「提升等級：神話 1/6」是可靠的，拿那行當第二來源。
-- 樣板直接從 ITEM_UPGRADE_TOOLTIP_FORMAT_STRING 組，不必自己維護各語系字串。
local UpgradePattern
local function GetUpgradePattern()
    if (UpgradePattern ~= nil) then
        return UpgradePattern or nil
    end
    local fmt = _G.ITEM_UPGRADE_TOOLTIP_FORMAT_STRING
    if (type(fmt) ~= "string") then
        UpgradePattern = false
        return
    end
    -- 先跳脫在地化字串裡的樣板魔術字元，再把 %s / %d 換成擷取群組
    local p = fmt:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
    p = p:gsub("%%%%s", "(.+)")
    p = p:gsub("%%%%d", "(%%d+)")
    UpgradePattern = p
    return p
end

local function GetTrackFromTooltip(link, data)
    local pattern = GetUpgradePattern()
    if (not pattern) then return end
    data = data or GetTooltipLines(link)
    if (not data) then return end
    for _, line in ipairs(data.lines) do
        local text = StripColorCodes(line.leftText)
        if (text) then
            local track, current, max = text:match(pattern)
            if (track) then
                return track, tonumber(current), tonumber(max)
            end
        end
    end
    if (DEBUG_ILVL) then
        DebugILvl("    工具提示裡也找不到升級軌道，原文如下：")
        for i, line in ipairs(data.lines) do
            DebugILvl("      [%d] %s", i, tostring(StripColorCodes(line.leftText)))
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
        if (DEBUG_TRACK) then
            if (info) then
                local parts = {}
                for k, v in pairs(info) do
                    parts[#parts + 1] = tostring(k) .. "=" .. tostring(v)
                end
                print("|cffffd200[MiliUI-DBG]|r UpgradeInfo: " .. table.concat(parts, ", "))
            else
                print("|cffffd200[MiliUI-DBG]|r UpgradeInfo: nil")
            end
            local crafted = IsCraftedItem(link)
            local craftQ = GetItemCraftedQualityAPI and GetItemCraftedQualityAPI(link)
            print("|cffffd200[MiliUI-DBG]|r IsCrafted=" .. tostring(crafted) .. " CraftedQuality=" .. tostring(craftQ))
        end
        if (HasActiveTrack(info)) then
            local color = TRACK_COLORS[info.trackString] or "ffffd200"
            if (info.currentLevel ~= nil) then
                return string.format("|c%s[%s %d/%d]|r %s",
                    color, info.trackString, info.currentLevel, info.maxLevel, link)
            else
                return string.format("|c%s[%s]|r %s", color, info.trackString, link)
            end
        elseif (info and info.trackString) then
            local color = TRACK_COLORS[info.trackString]
            if (color) then
                return string.format("|c%s[%s]|r %s", color, info.trackString, link)
            end
            return link
        end
    end
    local data = GetTooltipLines(link)
    local forgeText, forgeColor = GetForgeInfo(link, data)
    if (forgeText) then
        return string.format("|c%s[%s]|r %s", forgeColor, forgeText, link)
    end
    local craftText = GetCraftedText(link, data)
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
        if (DEBUG_ILVL) then
            if (info) then
                local parts = {}
                for k, v in pairs(info) do
                    parts[#parts + 1] = tostring(k) .. "=" .. tostring(v)
                end
                table.sort(parts)
                DebugILvl("    UpgradeInfo: %s", table.concat(parts, ", "))
            else
                DebugILvl("    UpgradeInfo: nil")
            end
        end
        if (info and info.trackString and TRACK_COLORS[info.trackString]) then
            DebugILvl("    -> 軌道色 %s (%s)", TRACK_COLORS[info.trackString], tostring(info.trackString))
            return TRACK_COLORS[info.trackString]
        end
    end
    -- 以下三個判斷共用同一份工具提示，不要各抓一次
    local data = GetTooltipLines(link)
    local tooltipTrack = GetTrackFromTooltip(link, data)
    if (tooltipTrack and TRACK_COLORS[tooltipTrack]) then
        DebugILvl("    -> 軌道色 %s (%s，來自工具提示)", TRACK_COLORS[tooltipTrack], tooltipTrack)
        return TRACK_COLORS[tooltipTrack]
    end
    local forgeText, forgeColor = GetForgeInfo(link, data)
    if (forgeColor) then
        DebugILvl("    -> 特殊關鍵字色 %s (%s)", forgeColor, tostring(forgeText))
        return forgeColor
    end
    if (GetItemCraftedQualityAPI) then
        local q = GetItemCraftedQualityAPI(link)
        DebugILvl("    CraftedQuality: %s", tostring(q))
        if (q and q > 0 and CRAFTED_QUALITY_COLORS[q]) then
            DebugILvl("    -> 製作品質色 %s", CRAFTED_QUALITY_COLORS[q])
            return CRAFTED_QUALITY_COLORS[q]
        end
    end
    DebugILvl("    -> 不覆寫，沿用 TinyInspect 的品質色")
end

-- 一律優先讀「這個按鈕當下顯示的物品」，button.OrigItemLink 只能當最後的退路。
-- TinyInspect 是在 SetItemLevelString() 之後才寫入 OrigItemLink，而我們的掛勾正是掛在
-- SetItemLevelString 上，跑在那之前；直接讀它拿到的是這個按鈕上一次顯示的物品，按鈕
-- 第一次用到時更是 nil。Journal 換首領時第一格永遠不上色就是這樣來的。
local function GetLinkForButton(button)
    if (not button) then return end
    -- Journal 戰利品按鈕
    if (button.encounterID) then
        if (button.index and GetLootInfoByIndex) then
            local info = GetLootInfoByIndex(button.index)
            if (info and info.link) then return info.link end
        end
        if (button.link) then return button.link end
    end
    -- 角色／觀察視窗的裝備欄
    local name = button.GetName and button:GetName()
    local id = name and button.GetID and button:GetID()
    if (name and id) then
        if (name:match("^Character%w+Slot$")) then
            return GetInventoryItemLink("player", id)
        elseif (name:match("^Inspect%w+Slot$") and InspectFrame and InspectFrame.unit) then
            return GetInventoryItemLink(InspectFrame.unit, id)
        end
    end
    return button.OrigItemLink
end

local function HookLevelStringSetText(frame, button)
    if (not frame or not frame.levelString or frame.MiliUILevelTextHooked) then return end
    frame.MiliUILevelTextHooked = true
    frame.MiliUIButton = button
    hooksecurefunc(frame.levelString, "SetText", function(self, text)
        if (self.__miliuiUpdating) then return end
        if (not TinyInspectRemakeDB or not TinyInspectRemakeDB.ShowColoredItemLevelString) then return end
        local link = GetLinkForButton(frame.MiliUIButton)
        if (DEBUG_ILVL) then
            local b = frame.MiliUIButton
            DebugILvl("SetText(%q) button=%s", StripColorCodes(text or "") or "",
                (b and b.GetName and b:GetName()) or tostring(b))
            if (b and b.encounterID) then
                DebugILvl("    EJ index=%s encounterID=%s", tostring(b.index), tostring(b.encounterID))
            end
            -- OrigItemLink 落後一輪，兩者不一致就代表退路救回了一筆
            DebugILvl("    實際採用    = %s", EscapeLink(link))
            DebugILvl("    OrigItemLink = %s", EscapeLink(b and b.OrigItemLink))
        end
        if (not link) then
            DebugILvl("    (無 link，直接跳過)")
            return
        end
        local plain = StripColorCodes(text or "") or ""
        if (plain == "") then return end
        local color = GetItemLevelColor(link)
        if (not color) then return end
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

SLASH_MILIUIILVLDBG1 = "/miliuiilvldbg"
SlashCmdList.MILIUIILVLDBG = function()
    DEBUG_ILVL = not DEBUG_ILVL
    print(string.format("|cffffd200[MiliUI]|r 裝等顏色 debug: %s",
        DEBUG_ILVL and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
end
