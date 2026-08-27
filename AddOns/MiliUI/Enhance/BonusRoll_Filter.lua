------------------------------------------------------------
-- MiliUI: 星雲之核骰裝提示過濾
--
-- 12.x 的星雲之核（Nebulous Voidcore）骰裝提示（BonusRollFrame）在探究、
-- 儀式地點、低層 M+、低難度團本這些骰不到高品質裝備的內容結束時也會跳。
-- 這裡依內容類型決定要不要把提示藏起來，讓提示只在值得花核心的場合出現。
--
-- 做法：hooksecurefunc BonusRollFrame_StartBonusRoll，條件命中就走暴雪
-- 自己的取消路徑 BonusRollFrame_CloseBonusRoll()。掛勾在原函式返回後
-- 同步執行，同一幀內就從 GroupLootContainer 移除，畫面上不會閃一下。
-- 只是不顯示提示，不代替玩家做決定；提示的倒數在伺服器端照跑，
-- 玩家反悔可以先把總開關關掉再打一場。
--
-- 內容分類吃 SPELL_CONFIRMATION_PROMPT 事件一路傳進來的 difficultyID：
--   8              M+（層數另查，見 GetKeystoneLevel）
--   15 / 16 / 233  英雄／傳奇／傳奇彈性團本 → 永遠顯示
--   14 / 17 / 220  普通／隨機／故事團本     → hideRaidNormal
--   其他（208 探究、0 開放世界、250 世界團本…）→ hideWorld
-- 未知的 difficultyID 一律落入 hideWorld 桶：會跳這個提示的低價值內容
-- 型態每季在變，落錯桶頂多多藏一種雜項內容，反向（漏藏）更煩人。
--
-- M+ 層數三層備援：完賽資訊 → 進行中鑰石 → 事件的 treasureContextLevel。
-- 全部拿不到就顯示 —— 寧可多跳一次，不要吃掉傳奇品質的機會。
--
-- 讀寫於 MiliUI_DB.bonusRollFilter。
------------------------------------------------------------

-- +8 以上完賽的寶庫已是傳奇軌道，骰裝才有機會出傳奇品質
local MPLUS_SHOW_MIN = 8

local RAID_ALWAYS_SHOW = {
    [15]  = true,   -- 英雄團本
    [16]  = true,   -- 傳奇團本
    [233] = true,   -- 傳奇彈性團本
}

local RAID_NORMAL_BELOW = {
    [14]  = true,   -- 普通團本
    [17]  = true,   -- 隨機團本
    [220] = true,   -- 故事團本
}

local DEFAULTS = {
    enabled        = true,    -- 總開關
    hideWorld      = true,    -- 探究、儀式地點與其他開放世界內容
    mplusMode      = "low",   -- "show" 全部顯示 / "low" 隱藏 +7 以下 / "all" 全部隱藏
    hideRaidNormal = true,    -- 團本普通難度（含）以下
}

local function GetDB()
    if not MiliUI_DB then MiliUI_DB = {} end
    local db = MiliUI_DB.bonusRollFilter
    if not db then
        db = {}
        MiliUI_DB.bonusRollFilter = db
    end
    for k, v in pairs(DEFAULTS) do
        if db[k] == nil then db[k] = v end
    end
    return db
end

local function GetKeystoneLevel(treasureContextLevel)
    -- 提示跳出來時這一場剛完賽，完賽資訊最貼近事實
    if C_ChallengeMode.GetChallengeCompletionInfo then
        local info = C_ChallengeMode.GetChallengeCompletionInfo()
        if info and info.level and info.level > 0 then
            return info.level
        end
    end
    local activeLevel = C_ChallengeMode.GetActiveKeystoneInfo()
    if activeLevel and activeLevel > 0 then
        return activeLevel
    end
    if treasureContextLevel and treasureContextLevel > 0 then
        return treasureContextLevel
    end
    return nil
end

local function ShouldHide(difficultyID, treasureContextLevel)
    local db = GetDB()
    if not db.enabled then return false end

    if difficultyID == 8 then
        if db.mplusMode == "all" then return true end
        if db.mplusMode == "show" then return false end
        local level = GetKeystoneLevel(treasureContextLevel)
        return level ~= nil and level < MPLUS_SHOW_MIN
    end
    if RAID_ALWAYS_SHOW[difficultyID] then return false end
    if RAID_NORMAL_BELOW[difficultyID] then
        return db.hideRaidNormal and true or false
    end
    return db.hideWorld and true or false
end

if type(BonusRollFrame_StartBonusRoll) == "function" then
    hooksecurefunc("BonusRollFrame_StartBonusRoll",
        function(spellID, text, duration, currencyID, currencyCost, difficultyID,
                 displayItemID, itemContext, treasureContextLevel)
            if not ShouldHide(difficultyID or 0, treasureContextLevel) then return end
            -- StartBonusRoll 可能因為核心數量 0 或重複提示而早退沒顯示；
            -- CloseBonusRoll 自帶 state == "prompt" 檢查，多叫無害
            BonusRollFrame_CloseBonusRoll()
        end)
end

------------------------------------------------------------
-- 對外 API（給 Options/Tab_Enhance.lua 用）
------------------------------------------------------------
MiliUI_BonusRollFilter = {
    IsEnabled  = function() return GetDB().enabled and true or false end,
    SetEnabled = function(v) GetDB().enabled = v and true or false end,
    GetOption  = function(key) return GetDB()[key] end,
    SetOption  = function(key, v) GetDB()[key] = v end,
}
