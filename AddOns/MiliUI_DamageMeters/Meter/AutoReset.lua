------------------------------------------------------------
-- 進新副本時自動重置
--
-- ════════════════════════════════════════════════════════════
-- 為什麼是一個下拉而不是兩個勾選
-- ════════════════════════════════════════════════════════════
-- 「要不要自動重置」＋「要不要先確認」兩個布林 = 四種狀態，但其中
-- 「不自動重置 ＋ 需要確認」是**無意義的組合** —— 第二個勾選必須跟著第一個
-- 變灰，玩家還得自己推理哪些組合有效。改成三選一的下拉：狀態剛好三個、
-- 沒有相依、沒有變灰的控件，而且標籤讀起來就是一句話（「進入新副本時 → 跳出確認」）。
-- 規則見 miliui-menu-design 技能。
--
-- ════════════════════════════════════════════════════════════
-- 什麼算「新副本」
-- ════════════════════════════════════════════════════════════
--   1. 進到一個**跟上次記錄不同**的副本（instanceID ＋ 難度）
--   2. 鑰石開始 —— 同一個副本連跑第二趟，1 認不出來，但那確實是新的一趟
--
-- 三個「不要吵人」的閘，每一個都對應一種實際會惹人厭的情況：
--   * **戰鬥中不跳** → 押到離開戰鬥再說（zone in 直接開打是常態）
--   * **沒有資料可重置就不問** → 問一個答案不影響任何事的問題是純噪音
--   * **登入／重載不跳** → 只記錄目前副本。在團隊裡重載一次就被問一次很煩
------------------------------------------------------------
local _, ns = ...

ns.AutoReset = {}
local A = ns.AutoReset
local D = ns.Data

local _pending          -- 戰鬥中先押著的副本名，離開戰鬥再處理

------------------------------------------------------------
-- 目前副本的識別字串。難度要算進去：同一個副本的英雄與傳奇是兩趟。
-- 不在副本裡回 nil。
------------------------------------------------------------
local function InstanceKey()
    local name, instType, difficultyID, _, _, _, _, instanceID = GetInstanceInfo()
    if not instType or instType == "none" then return nil end
    return tostring(instanceID) .. ":" .. tostring(difficultyID), name
end

------------------------------------------------------------
-- 有東西可以重置嗎
--
-- 拿「總計」的傷害輸出當代表：它是唯一一定會有資料的類型，而且我們只要知道
-- 「有沒有」，不必讀值 —— 所以連秘密值都不必碰。
------------------------------------------------------------
local function HasData()
    local session = D.GetSession(D.S.Overall, nil, D.T.DamageDone)
    local sources = session and session.combatSources
    return sources ~= nil and #sources > 0
end

------------------------------------------------------------
-- 確認視窗
--
-- ⚠ 自建，**不走暴雪的 StaticPopup**（2026-10-20 玩家回報、2026-10-29 再報一次）：
-- 12.1.5 的 `StaticPopup_Hide(which)` 沒包 securecall，直接讀每個顯示中彈窗的
-- `dialog.which`。我們用 StaticPopup_Show 開的彈窗，那些欄位是在插件 taint 下寫的
-- ⇒ 彈窗掛在畫面上的期間，暴雪任何呼叫 StaticPopup_Hide 的路徑都被染成我們
-- （實例：非會長收到 GUILD_RANKS_UPDATE_ACTIVE_PLAYER → GuildControlUI_Setup →
-- StaticPopup_Hide("CONFIRM_RANK_AUTHENTICATOR_REMOVE") → 查 Discord 狀態 →
-- FORBIDDEN: IsUserOAuthed() / GetGuildLinkStatus() 點名「米利的伤害统计」）。
-- 這個提示 timeout 0、會一直掛到玩家回答，進副本那一刻又剛好撞上公會事件，中獎率很高。
-- 通則在 .claude/notes/wow-staticpopup-addon-show-taint.md：憑空跳出來、等人回答的提示
-- 一律自建框。
--
-- 也不用共用層的 W.CreateConfirmPopup：那顆有整片滑鼠遮罩（設計給設定視窗內用），
-- 遊戲中途跳出來會把整個畫面鎖住。
--
-- 外觀走套組的「提示皮」（彈出來給人讀內容的表面：不透明 0.133 底 ＋ 1px 職業色邊 ＋ 直角），
-- 按鈕照全套組規則：確認＝primary、否＝normal。位置照原本 StaticPopup 的習慣放畫面上緣。
-- ESC 關得掉（W.CloseOnEscape）。
------------------------------------------------------------
local PROMPT_W = 320
local PROMPT_Y = -135         -- 跟暴雪 StaticPopup 第一格同一個高度，玩家看慣的位置

local _prompt                 -- 建一次重用（frame 刪不掉）

local function GetPrompt()
    if _prompt then return _prompt end
    local W = ns.W
    local f = W.CreateFrame("MiliUI_DamageMeters_AutoResetPrompt", UIParent, PROMPT_W, 80)
    W.Stylize(f, { 0.133, 0.133, 0.133, 1 }, { W.Accent(1) })
    f:SetFrameStrata("DIALOG")
    f:SetPoint("TOP", UIParent, "TOP", 0, PROMPT_Y)
    f:SetClampedToScreen(true)
    W.CloseOnEscape(f)

    local fs = f:CreateFontString(nil, "OVERLAY")
    fs:SetFontObject(W.fontNormal)
    fs:SetPoint("TOP", 0, -14)
    fs:SetWidth(PROMPT_W - 28)
    fs:SetJustifyH("CENTER")
    f.text = fs

    local yes = W.CreateButton(f, YES or "Yes", "primary", 90, 22)
    yes:SetPoint("BOTTOMRIGHT", f, "BOTTOM", -4, 12)
    yes:SetScript("OnClick", function()
        f:Hide()
        ns.Combat.ResetData()
    end)
    local no = W.CreateButton(f, NO or "No", "normal", 90, 22)
    no:SetPoint("BOTTOMLEFT", f, "BOTTOM", 4, 12)
    no:SetScript("OnClick", function() f:Hide() end)

    -- 高度貼著字長：上緣 14 ＋ 字高 ＋ 字與按鈕間距 14 ＋ 按鈕 22 ＋ 下緣 12。
    -- 顯示時才量：建立當下字型可能還沒就緒、字高量成 0
    f:SetScript("OnShow", function(self)
        local h = fs:GetStringHeight() or 0
        if h > 0 then ns.P.Height(self, 14 + h + 14 + 22 + 12) end
    end)

    -- 建完先關掉：CreateFrame 出來預設是顯示的，而且對已顯示的框 Show() 不會觸發 OnShow
    f:Hide()
    _prompt = f
    return f
end

local function Ask(instanceName)
    local f = GetPrompt()
    local text = ns.L["Entering %s. Reset the damage meter?"]
    f.text:SetText(text:format(instanceName or "?"))
    f:Hide()          -- 已經開著（連進兩個副本）就重開，讓 OnShow 重新量高
    f:Show()
end

local function HidePrompt()
    if _prompt then _prompt:Hide() end
end

------------------------------------------------------------
-- 處理一趟「新的一趟開始了」
------------------------------------------------------------
local function Handle(instanceName)
    local s = ns.DB.Style()
    local mode = s and s.autoReset or "ask"
    if mode == "off" then return end

    -- 戰鬥中先押著：zone in 直接開打是常態，這時候跳確認只會擋事
    if InCombatLockdown() then
        _pending = instanceName or true
        return
    end
    _pending = nil

    -- 沒有資料可重置就不要問 —— 答案不影響任何事
    if not HasData() then return end

    if mode == "auto" then
        ns.Combat.ResetData()
    else
        Ask(instanceName)
    end
end

------------------------------------------------------------
-- 事件
------------------------------------------------------------
local f = CreateFrame("Frame")

local function OnEvent(_, event, isInitialLogin, isReloadingUi)
    if event == "PLAYER_REGEN_ENABLED" then
        -- 戰鬥中押下來的，現在補做
        if _pending then
            local name = (_pending ~= true) and _pending or nil
            _pending = nil
            Handle(name)
        end
        -- 沒答的提示到這時候已經過期了，收掉
        return
    end

    if event == "PLAYER_REGEN_DISABLED" then
        -- 開打了，還掛著的確認已經沒有意義 —— 留著只會變成一個過期的彈窗
        HidePrompt()
        return
    end

    local acc = ns.DB.Account()
    if not acc then return end

    if event == "CHALLENGE_MODE_START" then
        -- 鑰石開始就是新的一趟，即使副本跟上一趟相同
        local key, name = InstanceKey()
        acc.lastInstanceKey = key or acc.lastInstanceKey
        Handle(name)
        return
    end

    -- PLAYER_ENTERING_WORLD
    local key, name = InstanceKey()
    if not key then
        -- 出了副本：清掉記錄，下次進副本（即使是同一個）就算新的一趟
        acc.lastInstanceKey = nil
        return
    end
    -- 登入／重載只記錄不打擾：在團隊裡重載一次就被問一次很煩
    if isInitialLogin or isReloadingUi then
        acc.lastInstanceKey = key
        return
    end
    if acc.lastInstanceKey == key then return end
    acc.lastInstanceKey = key
    Handle(name)
end

ns.RegisterCallback("Init", "autoreset", function()
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:RegisterEvent("CHALLENGE_MODE_START")
    f:RegisterEvent("PLAYER_REGEN_DISABLED")
    f:RegisterEvent("PLAYER_REGEN_ENABLED")
    f:SetScript("OnEvent", function(...)
        xpcall(OnEvent, ns.ReportError, ...)
    end)
end)
