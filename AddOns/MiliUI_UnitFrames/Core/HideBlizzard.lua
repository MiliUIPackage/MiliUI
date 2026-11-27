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

-- 替身施法條 OverlayPlayerCastingBarFrame：暴雪拿它在別的框上「代班」玩家施法條
-- （StartReplacingPlayerBarAt），OnLoad 就自己以 "player" 註冊了全套施法事件。宿主有兩種：
--   * 覆蓋快捷列（載具、變身、寵物控制）：OverrideActionBar 停用本體、讓替身畫在自己上方 ——
--     代的就是玩家施法條 ⇒ 跟本體一起解
--   * 專精頁（切換專精）、天賦頁（套用天賦）、專業視窗（製作）：視窗自己的內容觸發的施法，
--     進度條畫在視窗裡，我們的施法條被視窗蓋住 ⇒ 不能解（2026-10-08 兩種一起解掉，
--     2026-10-21 玩家回報轉專精的施法條不見了）
-- 所以只在宿主是 OverrideActionBar 的那段解，換走就照原樣裝回 —— 這條**不是單向的**。
-- 宿主換手走 Start／EndReplacingPlayerBar 的後置勾：⚠ 跑在 OverrideActionBar 的 OnShow／OnHide
-- 裡，只排程；下一幀照替身現在的父框（GetParent，只讀）對帳
local OVERLAY_EVENTS = {
    "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_START",
    "UNIT_SPELLCAST_CHANNEL_UPDATE", "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_EMPOWER_START",
    "UNIT_SPELLCAST_EMPOWER_UPDATE", "UNIT_SPELLCAST_EMPOWER_STOP", "UNIT_SPELLCAST_INTERRUPTIBLE",
    "UNIT_SPELLCAST_NOT_INTERRUPTIBLE", "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP",
    "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_SENT", "PLAYER_ENTERING_WORLD",
}
local overlaySaved      -- 解之前它註冊著的事件：{ { event, unit1, unit2 }, … }；nil ＝ 現在沒解
local overlayHooked = false

local function ReconcileOverlayCastBar()
    local bar = OverlayPlayerCastingBarFrame
    if not bar then return end
    local host = OverrideActionBar
    local ok, parent = pcall(bar.GetParent, bar)
    local hide = ns.playerCastBarHidden == true and host ~= nil and ok and parent == host
    if hide and not overlaySaved then
        local saved = {}
        for _, e in ipairs(OVERLAY_EVENTS) do
            local okReg, reg, u1, u2 = pcall(bar.IsEventRegistered, bar, e)
            if okReg and reg == true then saved[#saved + 1] = { e, u1, u2 } end
        end
        Unreg(bar)
        overlaySaved = saved
    elseif not hide and overlaySaved then
        for _, e in ipairs(overlaySaved) do
            if type(e[3]) == "string" then
                pcall(bar.RegisterUnitEvent, bar, e[1], e[2], e[3])
            elseif type(e[2]) == "string" then
                pcall(bar.RegisterUnitEvent, bar, e[1], e[2])
            else
                pcall(bar.RegisterEvent, bar, e[1])
            end
        end
        overlaySaved = nil
    end
end

local function HookOverlayCastBar()
    local bar = OverlayPlayerCastingBarFrame
    if overlayHooked or not bar then return end
    overlayHooked = true
    local later = function() C_Timer.After(0, ReconcileOverlayCastBar) end
    for _, method in ipairs({ "StartReplacingPlayerBarAt", "EndReplacingPlayerBar" }) do
        if type(bar[method]) == "function" then hooksecurefunc(bar, method, later) end
    end
end

-- 戰鬥中 /reload 時 PLAYER_LOGIN 就在戰鬥鎖定裡 —— 以前這裡直接 return、之後再也沒人叫，
-- 結果整場登入暴雪原生框全都還在、跟我們的框疊在一起，直到下一次脫戰 /reload。
local loginRetry = CreateFrame("Frame")
loginRetry:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    ns.HideBlizzardFrames()
end)

-- 冪等：登入跑一次，設定裡「啟用這個單位框架」中途生出新框時（UnitFrame.lua 的
-- ApplySettings）再跑一次。重跑只會多 reparent／解事件一次，SetParent 掛勾有 hookedFrames 擋
function ns.HideBlizzardFrames()
    if InCombatLockdown() then
        loginRetry:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end

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

    -- 隊伍框：做法照首領框那一套（容器 reparent、容器排出來的成員只解事件）。
    --   PartyFrame     Edit Mode 的系統框，也是整組的容器 ⇒ HandleFrame reparent ＋ SetParent 掛勾補掛
    --   成員框         PartyFrame 的 PartyMemberFramePool 排出來的（同 BossNTargetFrame）⇒ 只解事件。
    --                  它們的條不在 HandleFrame 認得的欄位上（HealthBarContainer.HealthBar），另外解
    --   CompactPartyFrame  「團隊風格隊伍框」那一份，建出來時就是 PartyFrame 的子物件（暴雪
    --                  CompactPartyFrame_Generate），PartyFrame 藏了它就跟著藏 ⇒ 只解它自己的事件，
    --                  不另外 reparent（它的位置由 PartyFrame 的版面算，搬走沒有好處）。
    --                  這個設定沒開過的話根本不會建出來，所以要判 nil。
    -- ⚠ 對暴雪框只做 reparent／解事件，不寫任何欄位、不 SetScript（.claude/notes 的
    --   wow-121-addon-code-in-secure-stack 入口 5）
    -- ⚠ 成員框是池化的：PartyFrame 的 OnShow 會 ReleaseAll 再 Acquire、Setup 重新註冊事件。
    --   PartyFrame 已經掛在隱藏的父層底下，正常不會再觸發 OnShow；真的被叫回來也只是
    --   多收事件（框照樣看不見），不是功能問題。
    local partyDB = ns.GetUnitDB("party")
    if partyDB and partyDB.enabled and Spawned("party1") and PartyFrame then
        HandleFrame(PartyFrame)
        local pool = PartyFrame.PartyMemberFramePool
        if pool and pool.EnumerateActive then
            for member in pool:EnumerateActive() do
                Unreg(member)
                local hbc = member.HealthBarContainer
                Unreg(hbc and hbc.HealthBar)
                Unreg(hbc and hbc.TempMaxHealthLoss)
                Unreg(member.ManaBar)
                Unreg(member.PowerBarAlt)
                local pet = member.PetFrame
                Unreg(pet)
                Unreg(pet and pet.HealthBar)
            end
        end
        -- Ping 標記（Core/PingMark.lua）是鏡射暴雪精簡框上的那顆圖示，精簡框要繼續更新成員才對得到人
        -- ⇒ 那個功能開著時不解 CompactPartyFrame 的事件（它掛在已經藏起來的 PartyFrame 底下，
        -- 照樣看不到，只是在背景跑）。關掉就照舊解掉。登入時決定一次，所以那個開關要重載才生效。
        if ns.db.global.pingFlash == false then
            Unreg(CompactPartyFrame)
        end
    end

    -- 施法條：閘看**元件實際建出來沒有**（uf.elements.castbar），不是只看設定值 ——
    -- 元件 build 失敗同樣會被 BuildElements 的 xpcall 吃掉
    local playerUF = ns.frames.player
    if playerUF and playerUF.elements.castbar then
        Unreg(PlayerCastingBarFrame or CastingBarFrame)
        -- 只記帳，給公開 API HidesPlayerCastBar 回答（Api.lua）：別的插件要把暴雪施法條的
        -- 事件裝回去之前先問，不然會把我們藏起來的條又叫回來。單向，跟這支模組一樣
        ns.playerCastBarHidden = true
        -- 替身只在掛在覆蓋快捷列上時解（見 ReconcileOverlayCastBar 上面那段）
        HookOverlayCastBar()
        ReconcileOverlayCastBar()
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
