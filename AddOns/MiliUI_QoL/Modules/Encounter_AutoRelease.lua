------------------------------------------------------------
-- MiliUI_QoL: 烏拉特克戰鬥結束後自動釋放靈魂
--
-- 只認一隻首領：烏拉特克（ENCOUNTER_START 的 encounterID 3492），英雄／傳奇難度。
-- ENCOUNTER_END 當下就開始嘗試 RepopMe()，每 0.1 秒一次、最多 10 秒，變成鬼魂就停。
-- 滅團與擊殺都算（擊殺時倒地的人一樣能秒放）。預設開啟。讀寫於 MiliUI_QoL_DB.ulatekAutoRelease。
--
-- 為什麼要搶快：戰鬥一結束馬上釋放會直接留在首領平台上；慢了就落到墓地，要重新跑回來。
--
-- 為什麼是重試不是單發：RepopMe 在暴雪自己的「釋放靈魂」按鈕被停用的時候是空操作——
--   * 遭遇還在壓制釋放（C_InstanceEncounter.IsEncounterSuppressingRelease，彈窗顯示「戰鬥中無法釋放」）：
--     ENCOUNTER_END 送到客戶端跟伺服器解除壓制不一定同一刻，固定延遲一發常常打在縫裡。
--   * 身上有禁止釋放的光環（HasNoReleaseAura，按鈕變倒數）。
--   * 墜落中（IsFalling）。
--   這三個判斷照抄 Blizzard_StaticPopup_Game 的 DEATH 彈窗 OnUpdate；撞到就下一拍再試，
--   所以能在伺服器放行的第一刻釋放，而不是猜一個延遲。
--
-- 不釋放的情況：
--   * 已經是鬼魂、或整個時間窗內都沒死（假死／隱形活下來的人）
--   * 有「可以用」的自我復活（靈魂石、復生；canUse == true）：留給玩家自己用，滅團後站起來
--     再群體復活全團是省跑屍的打法。冷卻中的選項暴雪也會列出來但 canUse 是 false，那不算。
------------------------------------------------------------
local _, ns = ...
if ns.legacyCore then return end

local ENCOUNTER_ID = 3492
local TRY_INTERVAL = 0.1     -- 每拍間隔
local TRY_WINDOW = 10        -- 最多嘗試幾秒
local REPOP_COOLDOWN = 0.5   -- 送出 RepopMe 之後等伺服器回應的時間，期間不重送

local DEFAULTS = {
    enabled = true,     -- 預設開啟
}

local function GetDB()
    -- ns.db 在自己的 ADDON_LOADED 才有；那之前給一份預設值的拷貝，不碰存檔
    local root = ns.db
    if not root then return CopyTable(DEFAULTS) end
    local db = root.ulatekAutoRelease
    if type(db) ~= "table" then
        db = {}
        root.ulatekAutoRelease = db
    end
    for k, v in pairs(DEFAULTS) do
        if db[k] == nil then db[k] = v end
    end
    return db
end

-- 15 英雄、16 傳奇；233 是這一季傳奇在 GetInstanceInfo 的另一個代碼，當傳奇看
local function IsHeroicOrMythic(difficultyID)
    if difficultyID == 233 then difficultyID = 16 end
    return difficultyID == 15 or difficultyID == 16
end

-- 有「現在就能用」的自我復活才算；暴雪死亡彈窗也是這樣篩（canUse false 的按鈕灰掉）
local function HasUsableSelfResurrect()
    if not (C_DeathInfo and C_DeathInfo.GetSelfResurrectOptions) then return false end
    local opts = C_DeathInfo.GetSelfResurrectOptions()
    if type(opts) ~= "table" then return false end
    for _, opt in ipairs(opts) do
        if opt.canUse then return true end
    end
    return false
end

-- 暴雪「釋放靈魂」按鈕此刻會被停用的三個條件；任一成立 RepopMe 都是空操作
local function ReleaseBlocked()
    if C_InstanceEncounter and C_InstanceEncounter.IsEncounterSuppressingRelease
        and C_InstanceEncounter.IsEncounterSuppressingRelease() then
        return true
    end
    if HasNoReleaseAura and HasNoReleaseAura() then return true end
    if IsFalling and IsFalling() and not (IsOutOfBounds and IsOutOfBounds()) then return true end
    return false
end

local ticker
local lastRepop = 0

local function Stop()
    if ticker then
        ticker:Cancel()
        ticker = nil
    end
end

local function Try()
    if not GetDB().enabled then return Stop() end
    if UnitIsGhost("player") then return Stop() end          -- 已經放了
    if not UnitIsDead("player") then return end              -- 還活著；可能等一下才被餘波打死
    if HasUsableSelfResurrect() then return Stop() end       -- 留給玩家自己決定
    if ReleaseBlocked() then return end                      -- 這拍不行，下拍再試
    local now = GetTime()
    if now - lastRepop < REPOP_COOLDOWN then return end      -- 上一發還在等伺服器
    lastRepop = now
    RepopMe()
end

local function Start()
    Stop()
    lastRepop = 0
    local left = math.floor(TRY_WINDOW / TRY_INTERVAL)
    local self
    self = C_Timer.NewTicker(TRY_INTERVAL, function()
        left = left - 1
        Try()
        if left <= 0 and ticker == self then Stop() end
    end, left)
    ticker = self
    Try()   -- 第一拍不等
end

local ev = CreateFrame("Frame")
ev:SetScript("OnEvent", function(_, _, encounterID, _, difficultyID)
    if encounterID ~= ENCOUNTER_ID then return end
    if not GetDB().enabled then return end
    if not IsHeroicOrMythic(difficultyID) then
        local _, _, instDifficulty = GetInstanceInfo()
        if not IsHeroicOrMythic(instDifficulty) then return end
    end
    Start()
end)
ev:RegisterEvent("ENCOUNTER_END")

------------------------------------------------------------
-- 對內 API（給 Options/Controls.lua 用；走 ns，不開全域）
------------------------------------------------------------
ns.UlatekAutoRelease = {
    IsEnabled  = function() return GetDB().enabled and true or false end,
    SetEnabled = function(v) GetDB().enabled = v and true or false end,
}
