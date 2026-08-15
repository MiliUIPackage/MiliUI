------------------------------------------------------------
-- 隱藏暴雪原生單位框（做法照 Stuf/core.lua 的 DisableDefault，12.1 實戰驗證）
-- 只在登入時做一次；中途停用某單位要 /reload 才會還原暴雪框
------------------------------------------------------------
local _, ns = ...

local function Disable(f)
    if not f then return end
    f:UnregisterAllEvents()
    f:SetScript("OnUpdate", nil)
    f:Hide()
    f:SetAlpha(0)
end

local function DisableDefault(f)
    if not f then return end
    f:SetAlpha(0)
    f:EnableMouse(false)
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", -400, -400)
    local name = f:GetName() or "blah"
    Disable(f)
    Disable(_G[name .. "HealthBar"])
    Disable(_G[name .. "ManaBar"])
    Disable(_G[name .. "SpellBar"])
end

-- 暴雪施法條：解註冊事件 + Hide（照 Stuf:DefaultCastBar 的隱藏半邊）
local function DisableCastBar(bar)
    if not bar then return end
    bar:UnregisterAllEvents()
    bar:Hide()
end

-- unitKey → 對應的暴雪框
local BLIZZARD_FRAMES = {
    player       = function() return PlayerFrame end,
    target       = function() return TargetFrame end,
    targettarget = function() return TargetofTargetFrame or (TargetFrame and TargetFrame.totFrame) end,
    focus        = function() return FocusFrame end,
    focustarget  = function() return TargetofFocusFrame or (FocusFrame and FocusFrame.totFrame) end,
    pet          = function() return PetFrame end,
}

function ns.HideBlizzardFrames()
    if InCombatLockdown() then return end   -- 登入時不會在戰鬥，保險

    for unitKey, getter in pairs(BLIZZARD_FRAMES) do
        local udb = ns.GetUnitDB(unitKey)
        if udb and udb.enabled then
            DisableDefault(getter())
        end
    end

    -- 首領框
    local bossDB = ns.GetUnitDB("boss")
    if bossDB and bossDB.enabled then
        for i = 1, 5 do
            DisableDefault(_G["Boss" .. i .. "TargetFrame"])
        end
        if BossTargetFrameContainer then
            BossTargetFrameContainer:SetAlpha(0)
            BossTargetFrameContainer:EnableMouse(false)
        end
    end

    -- 玩家/寵物施法條（我們的 castbar 有開才藏）
    local playerDB = ns.GetUnitDB("player")
    if playerDB and playerDB.enabled and playerDB.elements.castbar
       and playerDB.elements.castbar.enabled then
        DisableCastBar(PlayerCastingBarFrame or CastingBarFrame)
    end
    local petDB = ns.GetUnitDB("pet")
    if petDB and petDB.enabled and petDB.elements.castbar
       and petDB.elements.castbar.enabled then
        DisableCastBar(PetCastingBarFrame)
    end

    -- 暴雪圖騰列（我們的圖騰框有開才藏）
    local totemDB = ns.db.units.totem
    if totemDB and totemDB.enabled and TotemFrame then
        DisableDefault(TotemFrame)
    end
end
