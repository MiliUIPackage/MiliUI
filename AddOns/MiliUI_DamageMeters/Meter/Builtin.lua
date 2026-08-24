------------------------------------------------------------
-- 暴雪內建傷害統計視窗（12.0 起）
--
-- 這支檔案是「跟內建統計互動」的唯一出口，兩件事：
--   1. 讀它的位置 —— 我們第一次擺放時直接接手（玩家早就擺在習慣的地方了）
--   2. 把它藏起來（預設**開**），並偵測官方開關、提醒玩家真的關掉它
--
-- 視窗叫 DamageMeterSessionWindow1 ~ 3。名字是從本機的 DamageMeterTools 挖出來的
-- （那支專門增強內建統計）—— 要找內建統計相關的框架名稱先翻它。
--
-- ════════════════════════════════════════════════════════════
-- 「藏起來」與「關掉」是兩件事，兩件都做但方式不同
-- ════════════════════════════════════════════════════════════
--
-- **藏起來（預設開）**：`style.hideBuiltinMeter`，只改 alpha 與滑鼠接收。
--   兩個框同時出現又醜又讓人搞不清楚哪個是哪個，所以預設就把官方那個弄不見。
--   ⚠ 只能用 alpha —— **不要 Hide()／SetParent／ClearAllPoints**。內建統計是
--   Edit Mode 管的框，那三個動作會讓暴雪自己的 RegisterEvent 在**非戰鬥**變成
--   禁止動作，跳出關不掉、pcall 不掉的「遭到封鎖」彈窗（見
--   project-miliui-hide-blizzard-taint）。DamageMeterTools 的戰鬥隱藏也是一路只用 alpha。
--
--   代價要講清楚：**框還在、還在跑、還在吃資源**，我們只是讓它看不見。
--
-- **關掉（要玩家自己按）**：真的省資源只有一條路 —— CVar `damageMeterEnabled`
--   （來源：Blizzard_DamageMeter/DamageMeter.lua 的 DAMAGE_METER_ENABLED_CVAR，
--   對應「選項 → 遊戲體驗強化 → 傷害量表 → 啟用傷害量表」）。
--
--   它是**普通 CVar**，不是 Edit Mode 版面資料，所以改得動也還原得回去。
--   即使如此我們還是**不自動關**：那是玩家的設定，靜默改掉的話他哪天移除插件會
--   一頭霧水。做法是「偵測 ＋ 提醒 ＋ 給一顆按鈕」，由他按下去。
------------------------------------------------------------
local _, ns = ...

ns.Builtin = {}
local B = ns.Builtin
local D = ns.Data

local NAME = "DamageMeterSessionWindow"
local MAX  = 3

B.WINDOW_NAME = NAME
B.MAX_WINDOWS = MAX

local function IsEditing()
    if C_EditMode and C_EditMode.IsEditModeActive then
        return C_EditMode.IsEditModeActive()
    end
    return EditModeManagerFrame and EditModeManagerFrame:IsShown() or false
end

------------------------------------------------------------
-- 讀位置
--
-- 回傳 (x, y, matchedIndex)：相對 UIParent 左上角的 TOPLEFT 位移。
-- 同編號優先，沒有就退回第一個（玩家通常只開一個）。
--
-- 注意 alpha 為 0 不影響幾何，所以「藏起來」跟「讀得到位置」不衝突 ——
-- 順序上仍然是先讀再藏（見 ns.Move 與 Manager 的呼叫點），因為那是比較好懂的因果。
------------------------------------------------------------
function B.WindowOffset(idx)
    local pl, pt = UIParent:GetLeft(), UIParent:GetTop()
    if not (pl and pt) then return nil end
    for _, i in ipairs({ idx, 1 }) do
        if i and i <= MAX then
            local f = _G[NAME .. i]
            if f then
                local l, t = f:GetLeft(), f:GetTop()
                -- ⚠ 內建視窗會把秘密值餵給自己的長條，幾何有被污染的可能。
                -- 讀到秘密就當作沒這個位置 —— 絕對不能拿去做算術。
                if l and t and not D.IsSecret(l) and not D.IsSecret(t) then
                    return math.floor(l - pl + 0.5), math.floor(t - pt + 0.5), i
                end
            end
        end
    end
    return nil
end

------------------------------------------------------------
-- 官方統計的開關（CVar）
------------------------------------------------------------
local CVAR = "damageMeterEnabled"
B.CVAR = CVAR

-- 讀不到就回 nil（分不出「關著」與「這個客戶端沒有這個 CVar」）
function B.IsEnabled()
    if not GetCVarBool then return nil end
    local ok, v = pcall(GetCVarBool, CVAR)
    if not ok then return nil end
    return v and true or false
end

-- **只由玩家的明確動作呼叫**（設定頁那顆按鈕）。不要自動跑。
function B.Disable()
    if not SetCVar then return false end
    local ok = pcall(SetCVar, CVAR, "0")
    if ok then
        B.Apply()
        if ns.db then ns.db.builtinReminderShown = false end
    end
    return ok
end

------------------------------------------------------------
-- 提醒
--
-- 官方統計還開著就講一次：我們只是把它弄不見，它還在吃資源。
-- 印記存在 SV，講過就不再囉唆；**玩家哪天把它關掉，印記會自己清掉**
-- （見 B.Disable 與下面的 CheckReminder），所以之後若又打開，還會再提醒一次。
------------------------------------------------------------
function B.CheckReminder()
    local db = ns.db
    if not db then return end
    local enabled = B.IsEnabled()

    if enabled == false then
        db.builtinReminderShown = false   -- 已經關了：印記歸零，之後再開才會再提醒
        return
    end
    if enabled ~= true then return end    -- 讀不到就別亂講
    if db.builtinReminderShown then return end
    db.builtinReminderShown = true

    ns.Print(ns.L["Blizzard's built-in damage meter is still on. This addon only makes it invisible — it keeps running and still costs resources."])
    ns.Print(ns.L["Turn it off at: Options → Gameplay Enhancements → Damage Meter → Enable Damage Meter (or use the button in /mdm)."])
end

------------------------------------------------------------
-- 化妝性質的隱藏
------------------------------------------------------------
-- 記下「我們對每一個視窗寫過什麼」。沒碰過的就完全不去動 ——
-- 別的插件（例如 DamageMeterTools 的戰鬥隱藏／滑過顯示）也在驅動同一個 alpha，
-- 無條件寫 alpha=1 會把它的效果洗掉。
local _state = {}

function B.Apply()
    local s = ns.DB.Style()
    if not s then return end

    -- 編輯模式期間一律放它出來：不然玩家沒辦法看到、也沒辦法搬或關掉內建統計。
    local want = (s.hideBuiltinMeter == true) and not IsEditing()

    for i = 1, MAX do
        local f = _G[NAME .. i]
        -- 只在「狀態要變」而且「這個視窗是我們動過的」時候才寫。
        -- want=false ＋ 從沒碰過 → 什麼都不做。
        if f and _state[i] ~= want and (want or _state[i] ~= nil) then
            -- ⚠ 只有這兩行是安全的。**不要 Hide()、不要 SetParent、不要 ClearAllPoints** ——
            -- 那三個都會讓 Edit Mode 的版面流程碰到被我們染過的框。
            f:SetAlpha(want and 0 or 1)
            if f.EnableMouse then f:EnableMouse(not want) end
            _state[i] = want
        end
    end
end
