------------------------------------------------------------
-- 隱藏暴雪原生單位框（12.1 實戰調過）
--
-- ⚠⚠ 這個檔案改壞的代價是「戰鬥中跳封鎖視窗」，動之前先讀完：
--
-- 暴雪的單位框都是 protected frame，我們碰過的框就帶著我們的 taint。之後暴雪自己的
-- 程式碼再對同一個框做受保護動作，帳會算到我們頭上，跳
-- 「MiliUI_UnitFrames 嘗試進行 Blizzard UI 專屬動作」。實測抓到的就是
-- `Frame:RegisterEvent()`——我們自己所有 RegisterEvent 都打在自建的普通 frame 上，
-- 那一次是**暴雪自己**在被我們染過的框上註冊事件。
--
-- 12.1 之後歸納出來的三條規則：
--   1. 藏起來靠 **reparent 到一個隱藏的 frame**，不是靠 Hide()（Hide 會被 Edit Mode 復活）
--   2. Edit Mode 開著、或在戰鬥中，**延後**再 reparent；被搶走了也只在
--      `C_Timer.After(0)` 之後補掛——**絕不能在 hooksecurefunc 裡同步做**，
--      那等於跑在暴雪的安全執行流程裡，會污染到秘密值讀取（連累團隊框）
--   3. **Edit Mode 自己管的東西只解事件、不 reparent 也不 Hide**
--      （MonkStaggerBar 那類 alt power bar 就屬於這種；我們的 TotemFrame 同理）
------------------------------------------------------------
local _, ns = ...

local hiddenParent = CreateFrame("Frame", nil, UIParent)
hiddenParent:Hide()

local pendingParent, looseFrames, hookedFrames = {}, {}, {}

-- 戰鬥中不能對 protected frame reparent → 先寄放，脫戰再掃一次
local regenWatcher = CreateFrame("Frame")
regenWatcher:SetScript("OnEvent", function(self)
    if InCombatLockdown() then return end
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    for f in pairs(looseFrames) do pcall(f.SetParent, f, hiddenParent) end
    wipe(looseFrames)
end)

local function ApplyHiddenParent(frame)
    pendingParent[frame] = nil
    if frame:GetParent() == hiddenParent then return end
    if EditModeManagerFrame and EditModeManagerFrame:IsShown() then
        pendingParent[frame] = true
        C_Timer.After(0.25, function() ApplyHiddenParent(frame) end)
    elseif InCombatLockdown() and frame:IsProtected() then
        looseFrames[frame] = true
        regenWatcher:RegisterEvent("PLAYER_REGEN_ENABLED")
    else
        pcall(frame.SetParent, frame, hiddenParent)
    end
end

local function Unreg(child)
    if child then pcall(child.UnregisterAllEvents, child) end
end

-- doNotReparent：Edit Mode／容器自己管版面的框，只解事件就好
local function HandleFrame(frame, doNotReparent)
    if type(frame) == "string" then frame = _G[frame] end
    if not frame then return end
    Unreg(frame)

    if not doNotReparent then
        pcall(frame.Hide, frame)
        pcall(frame.SetParent, frame, hiddenParent)
        if not hookedFrames[frame] then
            hookedFrames[frame] = true
            hooksecurefunc(frame, "SetParent", function(self, parent)
                -- ⚠ 這裡跑在暴雪的執行流程裡，只能排程、不能當場動手
                if parent ~= hiddenParent and not pendingParent[self] then
                    pendingParent[self] = true
                    C_Timer.After(0, function() ApplyHiddenParent(self) end)
                end
            end)
        end
    end

    -- 子條各自有事件，父框解了不代表它們停了
    Unreg(frame.healthBar or frame.healthbar or frame.HealthBar
          or (frame.HealthBarsContainer and frame.HealthBarsContainer.healthBar))
    Unreg(frame.manabar or frame.ManaBar)
    Unreg(frame.castBar or frame.spellbar or frame.CastingBarFrame)
    Unreg(frame.powerBarAlt or frame.PowerBarAlt)
    Unreg(frame.BuffFrame or frame.AurasFrame)
    Unreg(frame.totFrame)
    Unreg(frame.DebuffFrame)
end

-- PlayerFrame 一被 reparent，掛在它底下的替代能量條就變成「不安全框的子物件」。
-- 那些條會自己註冊事件，一路驅動到 BuffFrame:Update() → 在 12.1 丟
-- 「Auras cannot be accessed when secret while tainted」。只解事件、不 reparent。
local ALT_POWER_BARS = {
    "AlternatePowerBar", "MonkStaggerBar",
    "EvokerEbonMightBar", "DemonHunterSoulFragmentsBar",
}

local BLIZZARD_FRAMES = {
    player       = function() return PlayerFrame end,
    target       = function() return TargetFrame end,
    targettarget = function() return TargetofTargetFrame or (TargetFrame and TargetFrame.totFrame) end,
    focus        = function() return FocusFrame end,
    focustarget  = function() return TargetofFocusFrame or (FocusFrame and FocusFrame.totFrame) end,
    pet          = function() return PetFrame end,
}

-- ⚠⚠ 「設定裡有啟用」不等於「我們的框真的生出來了」。
-- SpawnUnitFrame 在把 uf 寫進 ns.frames 之前還有幾十行，任何一步拋錯都會被
-- Units 的 xpcall 吃掉、然後這裡照樣把暴雪的框藏起來 ⇒ 那一格整個空白。
-- 而這支模組是**單向的**（reparent + 解事件，沒有還原路徑），玩家連 /reload
-- 都救不回來（錯誤是決定性的話會再失敗一次）。
-- 所以失敗方向必須朝「退回暴雪原生框」而不是「什麼都沒有」。
local function Spawned(unitKey)
    return ns.frames[unitKey] ~= nil
end

function ns.HideBlizzardFrames()
    if InCombatLockdown() then return end   -- 登入時不會在戰鬥，保險

    for unitKey, getter in pairs(BLIZZARD_FRAMES) do
        local udb = ns.GetUnitDB(unitKey)
        if udb and udb.enabled and Spawned(unitKey) then
            HandleFrame(getter())
            if unitKey == "player" then
                for i = 1, #ALT_POWER_BARS do Unreg(_G[ALT_POWER_BARS[i]]) end
            end
        end
    end

    -- 首領框：容器可以 reparent（Edit Mode 會想把它救回去，靠 hook 補掛），
    -- 但個別 BossNTargetFrame 是容器排版出來的，reparent 會把尺寸弄壞 → 只解事件
    local bossDB = ns.GetUnitDB("boss")
    if bossDB and bossDB.enabled and Spawned("boss1") then
        HandleFrame(BossTargetFrameContainer)
        for i = 1, (_G.MAX_BOSS_FRAMES or 5) do
            HandleFrame("Boss" .. i .. "TargetFrame", true)
        end
    end

    -- 施法條：閘看**元件實際建出來沒有**（uf.elements.castbar），不是只看設定值 ——
    -- 元件 build 失敗同樣會被 BuildElements 的 xpcall 吃掉
    local playerUF = ns.frames.player
    if playerUF and playerUF.elements.castbar then
        Unreg(PlayerCastingBarFrame or CastingBarFrame)
    end
    local petUF = ns.frames.pet
    if petUF and petUF.elements.castbar then
        Unreg(PetCastingBarFrame)
    end

    -- 暴雪圖騰列：**Edit Mode 自己管的系統框**，只解事件。
    -- 之前對它 Hide + ClearAllPoints + SetPoint，登入後 Edit Mode 跑版面時就會在
    -- 被染過的框上 RegisterEvent → 就是那個封鎖視窗的來源。
    -- ⚠ 圖騰框是 "Loaded" 事件才建的，所以這整支要排在 ns.Fire("Loaded") 之後跑，
    -- 否則 ns.totemFrame 永遠是 nil、這一段就變成永遠不執行。
    local totemDB = ns.db.units.totem
    if totemDB and totemDB.enabled and ns.totemFrame then
        HandleFrame(TotemFrame, true)
        for i = 1, 4 do Unreg(_G["TotemFrameTotem" .. i]) end
        if TotemFrame then pcall(TotemFrame.SetAlpha, TotemFrame, 0) end
    end
end
