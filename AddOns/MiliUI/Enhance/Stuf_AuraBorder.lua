------------------------------------------------------------
-- MiliUI: Stuf 光環邊框統一
-- 將頭像上所有 Buff/Debuff 圖示的邊框改為統一 1px 細框
--
-- hook icon texture inset + 替換背景為純色
------------------------------------------------------------
local AddonName, _ = ...
if AddonName ~= "MiliUI" then return end

local BORDER_SIZE = 1
local SOLID_BG = "Interface\\BUTTONS\\WHITE8X8"

local processedIcons = {}
local overriding = false

------------------------------------------------------------
-- 覆寫單一 aura icon 的邊框（首次 hook 時呼叫一次）
------------------------------------------------------------
local function OverrideIconBorder(icon)
    if not icon or not icon.texture then return end
    overriding = true

    icon.texture:ClearAllPoints()
    icon.texture:SetPoint("TOPLEFT", icon, "TOPLEFT", BORDER_SIZE, -BORDER_SIZE)
    icon.texture:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -BORDER_SIZE, BORDER_SIZE)

    local bd = icon.GetBackdrop and icon:GetBackdrop()
    if bd and bd.bgFile ~= SOLID_BG then
        local r, g, b, a = icon:GetBackdropColor()
        bd.bgFile = SOLID_BG
        icon:SetBackdrop(bd)
        if r then
            icon:SetBackdropColor(r, g, b, a)
        end
    end

    overriding = false
end

------------------------------------------------------------
-- Hook 單一 aura icon
------------------------------------------------------------
local function HookIcon(icon)
    if not icon or not icon.texture or processedIcons[icon] then return end

    hooksecurefunc(icon.texture, "SetPoint", function(self, point)
        if overriding then return end
        if point == "TOPRIGHT" or point == "BOTTOMLEFT" then
            overriding = true
            self:ClearAllPoints()
            self:SetPoint("TOPLEFT", icon, "TOPLEFT", BORDER_SIZE, -BORDER_SIZE)
            self:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -BORDER_SIZE, BORDER_SIZE)
            overriding = false
        end
    end)

    hooksecurefunc(icon, "SetBackdrop", function(self, bd)
        if overriding then return end
        if bd and bd.bgFile and bd.bgFile ~= SOLID_BG then
            overriding = true
            bd.bgFile = SOLID_BG
            self:SetBackdrop(bd)
            overriding = false
        end
    end)

    processedIcons[icon] = true
end

------------------------------------------------------------
-- 掃描並 hook 所有尚未處理的 aura icon
------------------------------------------------------------
local function ScanAndHookNew()
    local Stuf = _G["Stuf"]
    if not Stuf or not Stuf.units then return end

    for _, uf in pairs(Stuf.units) do
        for _, groupName in ipairs({ "buffgroup", "debuffgroup", "tempenchant" }) do
            local group = uf[groupName]
            if group then
                for i = 1, 80 do
                    local icon = group[i]
                    if not icon then break end
                    if not processedIcons[icon] then
                        HookIcon(icon)
                        OverrideIconBorder(icon)
                    end
                end
            end
        end
        local dispell = uf.dispellicon
        if dispell and dispell.texture and not processedIcons[dispell] then
            HookIcon(dispell)
            OverrideIconBorder(dispell)
        end
    end
end

local scanPending = false
local function ThrottledScanNew()
    if scanPending then return end
    scanPending = true
    C_Timer.After(0.05, function()
        scanPending = false
        ScanAndHookNew()
    end)
end

------------------------------------------------------------
-- INITIALIZATION
------------------------------------------------------------
local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")

    local attempts = 0
    local maxAttempts = 50  -- 50 * 0.1s = 最多等 5 秒
    local function TryInit()
        attempts = attempts + 1
        local Stuf = _G["Stuf"]
        if Stuf and Stuf.units and next(Stuf.units) then
            ScanAndHookNew()

            local eventFrame = CreateFrame("Frame")
            eventFrame:RegisterEvent("UNIT_AURA")
            eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
            eventFrame:SetScript("OnEvent", function()
                ThrottledScanNew()
            end)
            return
        end
        if attempts < maxAttempts then
            C_Timer.After(0.1, TryInit)
        end
    end
    C_Timer.After(0.1, TryInit)
end)
