------------------------------------------------------------
-- Masque：圖示外觀交給 Masque（主題／條的「圖示外觀」= Masque）
--
--   ns.Masque.Available()            Masque 有載入（LibStub 拿得到它的 API）
--   ns.Masque.Desired(barKey)        設定**現在**要的模式："miliui" | "masque"（沒裝 Masque 一律 miliui）
--   ns.Masque.Mode(barKey)           **登入時**的模式：第一次問的當下照設定快照，整個工作階段固定
--   ns.Masque.NeedsReload()          有哪一條 Desired ≠ Mode（設定頁問要不要重載）
--   ns.Masque.ModesSig()             每一條 Desired 串成的字串（設定頁記「這個組合問過了」）
--   ns.Masque.Active()               群組在 Masque 裡沒被停用（停用時外觀還給我們畫）
--   ns.Masque.TypeFor(barKey, src)   交給 Masque 的按鈕型別（增益 "Debuff"、其他 "Action"）
--   ns.Masque.Sync(holder, button, regions, btype, w, h, onLate) → 這一格現在是不是 Masque 在畫
--   ns.Masque.Release(holder)        從群組拿掉（格子換到米利樣式的條上）
--   ns.Masque.IsSkinned(holder)
--   ns.Masque.OpenOptions()
--
-- 分工（Core/Decorate.lua 依 Mode 分支）：
--   Masque  邊框（皮的外框圖）、圖示縮放（texcoord）、轉圈材質、圖示遮罩
--   我們    倒數／充能／層數文字、轉圈色、去飽和、隱藏 GCD、發光、按鍵文字、淡出、提示 overlay；
--           無損刷新期間把自己那圈彩色邊框亮出來（平常藏著，見 Decorate.RecolorBorder）
--
-- 規則
--   * **執行期不做米利 ↔ Masque 的雙向切換**：每條的模式登入時決定（Mode），設定頁改了只提示重載。
--     兩邊在同一批貼圖上輪流蓋（texcoord、錨點、轉圈材質），半路換手一定有殘留。
--   * Masque 裡只註冊**一個群組**（插件名固定英文、群組名在地化、StaticID 固定），皮膚、顏色、縮放都在
--     Masque 自己的設定裡選；我們不呼叫它任何 `__` 開頭的內部方法。
--     ⚠ Masque 的群組 ID ＝ 插件名＋StaticID：兩者都不能在地化，否則換客戶端語系就換一個群組、皮要重選。
--   * AddButton 一律傳**完整的 regions 表＋Strict = true**：它不去 item 上自己找欄位（Count、
--     HotKey、IconBorder…），我們也不為了讓它找到而在 item 上寫任何欄位。文字留在我們這邊，
--     所以 regions 不給 Count。
--   * 尺寸：Masque 套皮當下讀按鈕尺寸算比例，之後尺寸一變就要 ReSkin（holder.msqSize 記著）。
--   * 寫入走 ns.Write：戰鬥中按鈕在保護鏈上（可點擊群組的 secure 鈕、光環格的持有框會把保護
--     往上傳）就記帳、脫戰補做，補做完叫 onLate 讓 Decorate 重套一次（把我們暫代的邊框收掉）。
--   * 按鈕的幾何讀不到（秘密錨點）就不交：Masque 會拿 GetSize 做算術，那是它的錯誤、我們的堆疊。
--
-- ⚠ 這是引擎契約「暴雪框上一個欄位都不寫」的**第二個例外**（第一個在 Core/Compat.lua）：
--   交給 Masque 的暴雪 item，Masque 會在它身上寫自己的設定表（_MSQ_CFG）、掛勾旗標，在 Icon／
--   Cooldown 上寫 _MSQ_* 欄位，並在 item 上建外框圖與遮罩。**我們自己一個欄位都不寫**；
--   Masque 寫的那些 key 暴雪的程式不讀（污染只跟著那幾個 key），而且只有玩家選了 Masque 才發生。
--   跟 MasqueBlizzBars 套冷卻管理器時做的是同一件事；Compat.lua 照樣請它跳過我們的 item。
--
-- 群組在 Masque 裡被停用／啟用（Masque 自己的設定）：它會自己把按鈕還成預設皮或重新套皮。
-- 我們掛它的回呼，全部格子重套一次：停用時邊框、縮放、方角轉圈回到我們畫，但 Masque 預設皮留下的
-- 外框圖與圖示尺寸收不乾淨 ⇒ 聊天框提示重載（重載後群組停用＝AddButton 不套皮，畫面是乾淨的米利樣式）。
------------------------------------------------------------
local _, ns = ...

local L = ns.L

ns.Masque = {}
local M = ns.Masque

------------------------------------------------------------
-- 有沒有 Masque
------------------------------------------------------------
local api
function M.Available()
    if api then return true end
    local LS = LibStub
    if not LS then return false end
    local ok, lib = pcall(LS.GetLibrary, LS, "Masque", true)
    if ok and type(lib) == "table" and type(lib.Group) == "function" then
        api = lib
        return true
    end
    return false
end

------------------------------------------------------------
-- 模式：設定值（Desired）與登入時的快照（Mode）
------------------------------------------------------------
function M.Desired(barKey)
    local v = ns.Setting(barKey or "theme", "icon.skin")
    if v == "masque" and M.Available() then return "masque" end
    return "miliui"
end

-- 快照：第一次問的當下把主題與每一條都記下來（引擎第一次排版時，設定檔已經載好）。
-- 之後才建的條（新的自訂群組）沒有自己的快照 ⇒ 用主題的：新群組預設跟隨主題，
-- 而主題的「現在」可能已經改了但還沒重載，畫面要跟其他條一致。
local snap
local function Snapshot()
    if snap or not ns.profile then return snap end
    snap = { theme = M.Desired("theme") }
    for key in pairs(ns.profile.bars or {}) do snap[key] = M.Desired(key) end
    return snap
end

function M.Mode(barKey)
    local s = Snapshot()
    if not s then return "miliui" end
    return s[barKey or "theme"] or s.theme
end

-- 主題＋每一條；條不存在了就不算
local function EachKey(fn)
    fn("theme")
    local p = ns.profile
    for key in pairs(p and p.bars or {}) do fn(key) end
end

function M.NeedsReload()
    if not Snapshot() then return false end
    local need = false
    EachKey(function(key)
        if M.Desired(key) ~= M.Mode(key) then need = true end
    end)
    return need
end

function M.ModesSig()
    local keys = {}
    EachKey(function(key) keys[#keys + 1] = key end)
    table.sort(keys)
    for i, key in ipairs(keys) do keys[i] = key .. "=" .. M.Desired(key) end
    return table.concat(keys, ",")
end

-- 增益（暴雪的增益圖示／長條、增益型的佔位）照 Masque 的 Aura 系列套；其他照動作條按鈕
function M.TypeFor(barKey, sourceKey)
    local aura = ns.Viewers and ns.Viewers.AURA_KIND or {}
    if sourceKey ~= nil then return aura[sourceKey] and "Debuff" or "Action" end
    if aura[barKey] then return "Debuff" end
    local bar = ns.DB and ns.DB.BarTable and ns.DB.BarTable(barKey)
    if bar and bar.source == "buffs" then return "Debuff" end
    return "Action"
end

------------------------------------------------------------
-- 群組（懶建：第一格要交出去才建）
------------------------------------------------------------
local group
local warned = false

local function Disabled()
    -- db 是 Masque 群組自己的設定表（唯讀；它的 options 也是讀這個欄位）
    local db = group and group.db
    return type(db) == "table" and db.Disabled == true
end

function M.Active()
    return group ~= nil and not Disabled()
end

-- Masque 那邊的設定變了（換皮、縮放、背景、停用／啟用…）：全部格子重套一次，
-- 把轉圈色、我們暫代的邊框照新狀態寫回去
local function OnMasqueChanged(_, option, value)
    if ns.Decorate then ns.Decorate.InvalidateAll() end
    if ns.Bars and ns.Bars.RequestAll then ns.Bars.RequestAll("layout") end
    if ns.Preview and ns.Preview.RefreshAll then ns.Preview.RefreshAll() end
    if option == "Disabled" and value and not warned then
        warned = true
        ns.Print(L["Masque skinning is off for these icons. They are back to MiliUI's look; /reload if any of Masque's frame art is left over."])
    end
end

local function Group()
    if group then return group end
    if not M.Available() then return nil end
    local ok, g = pcall(api.Group, api, "MiliUI Cooldown Manager", L["Icons"], "Icons")
    if not ok or type(g) ~= "table" then return nil end
    group = g
    -- 不給選項名 ＝ 每一種設定變動都叫（Masque 的 RegisterCallback 公開介面）
    if g.RegisterCallback then pcall(g.RegisterCallback, g, ns.Guard(OnMasqueChanged)) end
    return group
end

------------------------------------------------------------
-- 交格子
--
-- holder：存狀態的表（真實 item 用它的 rec、佔位用 ph、預覽用格子自己）——都是我們的表。
--   holder.msqButton  交給 Masque 的那個框（圖示型＝item 本身；長條型＝item.Icon 那一層）
--   holder.msqSize    最後一次套皮時的尺寸（"寬x高"）
-- 回傳 true ＝ Masque 現在正在畫這一格（Decorate 據此不畫邊框、不設 texcoord、不換轉圈材質）。
------------------------------------------------------------
local function PlainWidth(frame)
    local ok, w = pcall(frame.GetWidth, frame)
    if not ok or ns.IsSecret(w) then return nil end
    return w
end

function M.IsSkinned(holder)
    return holder ~= nil and holder.msqButton ~= nil and holder.msqSize ~= nil and M.Active()
end

function M.Release(holder)
    local b = holder and holder.msqButton
    if not b then return end
    holder.msqButton, holder.msqSize = nil, nil
    local g = group
    if not g then return end
    ns.Write(b, function(f) g:RemoveButton(f) end, "masque")
end

function M.Sync(holder, button, regions, btype, w, h, onLate)
    if not (holder and button) then return false end
    local g = Group()
    if not g then return false end
    if holder.msqButton and holder.msqButton ~= button then M.Release(holder) end
    local size = tostring(w) .. "x" .. tostring(h)
    if holder.msqButton == button and holder.msqSize == size then return M.Active() end
    if not PlainWidth(button) then return M.IsSkinned(holder) end

    local queued = false
    local done = ns.Write(button, function(f)
        if holder.msqButton ~= f then
            g:AddButton(f, regions, btype, true)
            holder.msqButton = f
        else
            g:ReSkin(f)
        end
        holder.msqSize = size
        if queued and onLate then onLate() end
    end, "masque")
    queued = not done
    return (not queued) and M.IsSkinned(holder) or false
end

------------------------------------------------------------
-- 開 Masque 的設定
--
-- Masque 沒有公開的「開設定」函式，只有斜線指令 /msq（SlashCmdList.MASQUE，內部呼叫它的
-- ToggleOptions）。它戰鬥中什麼都不做。
-- 我們的設定視窗在 DIALOG 層，Masque 的設定（嵌在暴雪設定面板時是 HIGH）會被蓋住 ⇒ 先關自己的。
------------------------------------------------------------
function M.OpenOptions()
    if InCombatLockdown() or not M.Available() then return end
    local fn = SlashCmdList and SlashCmdList.MASQUE
    if type(fn) ~= "function" then return end
    if ns.Options and ns.Options.Close then ns.Options.Close() end
    fn("")
end
