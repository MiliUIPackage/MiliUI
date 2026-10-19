------------------------------------------------------------
-- MiliUI_QoL: 烏拉特克滅團後自動釋放靈魂
--
-- 只認一隻首領：烏拉特克（ENCOUNTER_START 的 encounterID 3492），英雄／傳奇難度。
-- ENCOUNTER_END 回報滅團（第 5 個回傳值 success == 0）之後 0.5 秒呼叫 RepopMe()。
-- 預設開啟。讀寫於 MiliUI_QoL_DB.ulatekAutoRelease。
--
-- 為什麼要秒放：滅團後馬上釋放會直接留在首領平台上，不用從墓地重新跑回來。
--
-- 只在滅團時觸發：首領打死時自己倒在地上的人要留著等復活，不能被送去墓地。
-- 不釋放的情況：
--   * 已經是鬼魂、或根本沒死（假死／隱形活下來的人）
--   * 有自我復活可用（靈魂石、復生）：滅團後用它站起來再群體復活全團，是省跑屍的打法
------------------------------------------------------------
local _, ns = ...
if ns.legacyCore then return end

local ENCOUNTER_ID = 3492
local RELEASE_DELAY = 0.5

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

local function HasSelfResurrect()
    if not (C_DeathInfo and C_DeathInfo.GetSelfResurrectOptions) then return false end
    local opts = C_DeathInfo.GetSelfResurrectOptions()
    return type(opts) == "table" and #opts > 0
end

local function Release()
    if not GetDB().enabled then return end
    if not UnitIsDead("player") or UnitIsGhost("player") then return end
    if HasSelfResurrect() then return end
    RepopMe()
end

local ev = CreateFrame("Frame")
ev:SetScript("OnEvent", function(_, _, encounterID, _, difficultyID, _, success)
    if encounterID ~= ENCOUNTER_ID or success ~= 0 then return end
    if not GetDB().enabled then return end
    if not IsHeroicOrMythic(difficultyID) then
        local _, _, instDifficulty = GetInstanceInfo()
        if not IsHeroicOrMythic(instDifficulty) then return end
    end
    C_Timer.After(RELEASE_DELAY, Release)
end)
ev:RegisterEvent("ENCOUNTER_END")

------------------------------------------------------------
-- 對內 API（給 Options/Controls.lua 用；走 ns，不開全域）
------------------------------------------------------------
ns.UlatekAutoRelease = {
    IsEnabled  = function() return GetDB().enabled and true or false end,
    SetEnabled = function(v) GetDB().enabled = v and true or false end,
}
