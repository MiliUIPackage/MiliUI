
---------------------------------------------------------------
-- MiliUI Enhance: Stuf Inspect Button Tooltip Localization
-- Stuf/icons.lua 763-766 的 inspect button tooltip 硬寫英文，
-- 沒走 L[...]；StufLocale.lua 裡 zhTW/zhCN 翻譯未被讀取。
-- 這裡在 tooltip 顯示時以 owner backdrop 辨識 Stuf inspect button
-- 後，把 FontString 文字覆寫成對應本地化字串。
-- Author: Mili
---------------------------------------------------------------

local locale = GetLocale()
if (locale ~= "zhTW" and locale ~= "zhCN") then return end

local TRANS = (locale == "zhTW") and {
    header = "快速互動",
    left   = " <左鍵> 觀察\n",
    middle = " <右鍵> 試衣間\n",
} or {
    header = "快速互动",
    left   = " <左键> 观察\n",
    middle = " <右键> 试衣间\n",
}

local function IsStufInspectOwner(owner)
    if (not owner) then return false end
    if (owner.MiliUIStufInspect) then return true end
    local bd = owner.GetBackdrop and owner:GetBackdrop()
    if (bd and bd.bgFile and type(bd.bgFile) == "string" and bd.bgFile:find("inspectup")) then
        owner.MiliUIStufInspect = true
        return true
    end
    return false
end

local function Setup()
    if (not C_AddOns or not C_AddOns.IsAddOnLoaded or not C_AddOns.IsAddOnLoaded("Stuf")) then
        return
    end
    hooksecurefunc(GameTooltip, "Show", function(self)
        if (self.__miliuiStufInspectProcessing) then return end
        if (not IsStufInspectOwner(self:GetOwner())) then return end

        local changed = false
        local l1 = _G.GameTooltipTextLeft1
        if (l1 and l1:GetText() == "Inspect") then
            l1:SetText(TRANS.header)
            changed = true
        end
        local l2 = _G.GameTooltipTextLeft2
        if (l2) then
            local t = l2:GetText()
            if (t and t:find("Left%-click")) then
                l2:SetText((TRANS.left or "") .. (TRANS.middle or "") .. (TRANS.right or ""))
                changed = true
            end
        end

        if (changed) then
            self.__miliuiStufInspectProcessing = true
            self:Show()
            self.__miliuiStufInspectProcessing = nil
        end
    end)
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", Setup)
