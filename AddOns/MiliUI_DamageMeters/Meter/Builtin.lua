------------------------------------------------------------
-- 暴雪內建傷害統計（12.0 起）
--
-- 這支檔案是「跟內建統計互動」的唯一出口，兩件事：
--   1. 讀它的位置 —— 我們第一次擺放時直接接手（玩家早就擺在習慣的地方了）
--   2. **主動關掉它**（`style.disableBuiltinMeter`，預設開）
--
-- 視窗叫 DamageMeterSessionWindow1 ~ 3。名字是從本機的 DamageMeterTools 挖出來的
-- （那支專門增強內建統計）—— 要找內建統計相關的框架名稱先翻它。
--
-- ════════════════════════════════════════════════════════════
-- 為什麼是「關掉」而不是「藏起來」
-- ════════════════════════════════════════════════════════════
--
-- 開關是 CVar **`damageMeterEnabled`**（來源：Blizzard_DamageMeter/DamageMeter.lua 的
-- `DAMAGE_METER_ENABLED_CVAR`，對應「選項 → 遊戲體驗強化 → 傷害量表 → 啟用傷害量表」）。
--
-- 曾經考慮過只用 `SetAlpha(0)` 化妝性地藏起來、不碰玩家的設定。**否決了**：
-- 那樣框還在、還在跑、還在吃資源，等於兩份統計同時算 —— 而效能與版面乾淨是這個
-- 套組的第一原則。同時出現兩個統計視窗對玩家來說也只是困惑。
--
-- 這是**普通 CVar**，不是 Edit Mode 版面資料，所以：改得動、還原得回去、不牽扯 taint。
-- 為了讓它真的可逆，我們記下「關之前它是開著的」（`db.builtinRestore`），
-- 玩家把這個選項關掉時就原樣還回去。**借了要還**，這是這個功能唯一的約束。
------------------------------------------------------------
local _, ns = ...

ns.Builtin = {}
local B = ns.Builtin
local D = ns.Data

local NAME = "DamageMeterSessionWindow"
local MAX  = 3
local CVAR = "damageMeterEnabled"

B.WINDOW_NAME = NAME
B.MAX_WINDOWS = MAX
B.CVAR = CVAR

------------------------------------------------------------
-- 讀位置
--
-- 回傳 (x, y, matchedIndex)：相對 UIParent 左上角的 TOPLEFT 位移。
-- 同編號優先，沒有就退回第一個（玩家通常只開一個）。
--
-- ⚠ 這件事跟「關掉內建統計」有先後：關掉之後那些視窗就不存在了，位置也就讀不到。
--   所以 Enforce 一定要排在接手位置之後（見 Meter/Manager.lua 的呼叫點）。
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
-- 開關
------------------------------------------------------------
-- 讀不到就回 nil（分不出「關著」與「這個客戶端沒有這個 CVar」）
function B.IsEnabled()
    if not GetCVarBool then return nil end
    local ok, v = pcall(GetCVarBool, CVAR)
    if not ok then return nil end
    return v and true or false
end

local function SetEnabled(on)
    if not SetCVar then return false end
    -- 戰鬥中不動 CVar：部分 CVar 在戰鬥鎖定時是受保護的，而這件事一點都不急
    if InCombatLockdown() then return false end
    return (pcall(SetCVar, CVAR, on and "1" or "0"))
end

------------------------------------------------------------
-- 主動關掉
--
-- 每次登入都跑（不是只跑一次）：只要插件開著，內建統計就該是關的。
-- 玩家想要它回來，就把這個選項關掉，或停用這支插件。
------------------------------------------------------------
function B.Enforce()
    local db, s = ns.db, ns.DB.Style()
    if not (db and s) then return end
    if s.disableBuiltinMeter == false then return end

    local enabled = B.IsEnabled()
    if enabled ~= true then return end          -- 已經關了，或這個客戶端沒有這個 CVar

    if not SetEnabled(false) then return end

    -- 記下「我們動過，而且動之前它是開著的」→ 選項關掉時要還回去。
    -- ⚠ 存帳號層（DB.Account）而不是設定檔裡：這是「這台機器欠著一個 CVar 還原」
    -- 的狀態，不是玩家調的設定。放進設定檔的話換一份設定檔就忘了要還，
    -- 而且會跟著匯出字串跑到別人那裡去。
    local acc = ns.DB.Account()
    local first = not acc.builtinRestore
    acc.builtinRestore = true

    -- 只在**第一次**真的關掉時講一句，免得玩家莫名其妙發現內建統計不見了。
    -- 之後每次登入都會靜靜地關，不再囉唆。
    if first then
        ns.Print(ns.L["Turned off Blizzard's built-in damage meter so the two don't overlap and double up the cost. You can get it back from this addon's settings."])
    end
end

------------------------------------------------------------
-- 還回去
--
-- 玩家把「自動關閉內建統計」關掉時呼叫。只有我們動過才還 ——
-- 沒動過就還原等於替玩家開了一個他本來就沒開的東西。
------------------------------------------------------------
function B.Release()
    local acc = ns.DB.Account()
    if not (acc and acc.builtinRestore) then return end
    acc.builtinRestore = false
    SetEnabled(true)
end

-- 選項變動時的統一入口
function B.ApplySetting()
    local s = ns.DB.Style()
    if not s then return end
    if s.disableBuiltinMeter == false then
        B.Release()
    else
        B.Enforce()
    end
end
