------------------------------------------------------------
-- MiliUI: Stuf 光環邊框統一
-- 把頭像上的光環圖示邊框改為統一 1px 細框（icon texture 內縮 + 背景換純色）
--
-- 範圍只剩 tempenchant（武器附魔）和 dispellicon 兩個元素。
--
-- buffgroup / debuffgroup 已經不需要了：Fix\Stuf_AuraContainer.lua 用
-- AuraContainer 接管了那兩組的顯示（ALWAYS_ON = true，所以 Stuf 原本的群組
-- 是永久 SetAlpha(0)），改在看不見的圖示上是白費工。而真正在顯示的
-- AuraButton 是 AuraContainerCore 建的，本來就照 Core.BORDER_SIZE = 1 內縮
-- 並鋪一張純色底框，外觀跟這裡一致。
--
-- 這兩個元素沒被接管的原因：
--   tempenchant  武器附魔沒有對應的 aura filter，要走 AddItemEnchantment
--   dispellicon  不在 Stuf_AuraContainer 的 DISPLAYS 裡
--
-- 若哪天把 Stuf_AuraContainer 的 ALWAYS_ON 改回只在戰鬥中接管，非戰鬥時
-- Stuf 原生的 buffgroup/debuffgroup 圖示會重新現身，那時要把它們加回 GROUPS。
------------------------------------------------------------
local AddonName, _ = ...
if AddonName ~= "MiliUI" then return end

-- Stuf 的光環群組元素名稱（見 Stuf/aura.lua 的 AddBuilder）
local GROUPS = { "tempenchant" }

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
--
-- 圖示是 Stuf 的 builder 建的，改設定會整組重建，所以不能只掃一次；
-- processedIcons 擋掉重複 hook，重掃只有新圖示要付代價。
------------------------------------------------------------
local function ScanAndHookNew()
    local Stuf = _G["Stuf"]
    if not Stuf or not Stuf.units then return end

    for _, uf in pairs(Stuf.units) do
        for _, groupName in ipairs(GROUPS) do
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
