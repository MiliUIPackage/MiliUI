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
--   ns.Masque.Generation()           Masque 那邊的設定每變一次 +1（從自己的框上讀回皮的形狀時，拿它判斷要不要重讀）
--   ns.Masque.GetNormal(button)      這一格現在畫皮外框的那張貼圖（光環格的探針用，見 Modules/Custom.lua）
--   ns.Masque.ShapeOf(frame)         交給 Masque 的框（我們交出去的那個）現在的皮是什麼形狀："Circle"／"Square"…／nil
--   ns.Masque.SpellAlertLoop(shape)  公開 API GetSpellAlertFlipBook("Modern", shape) 的循環圖 → { tex, w, h[, rows, cols, frames] }／nil
--   ns.Masque.SpellAlertOverlay(shape) 公開 API GetSpellAlert(shape) → glow, ants（快捷鍵閃光的兩張貼圖）／nil
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
-- 光環格（AuraContainer 的按鈕建好就 forbidden，Masque 碰不到）：Modules/Custom.lua 另建一顆看不見的普通框
-- （探針）交給同一個群組，再從它身上讀回 Icon 的遮罩／尺寸／texcoord 與皮外框（Normal）的外觀，烘進按鈕
-- （見那邊的「光環格的 Masque」）。
--
-- ⚠ 「不讀 Masque 內部表」的**唯一例外**：ShapeOf 從交出去的框上唯讀 `_MSQ_CFG.Shape`（rawget＋pcall＋Plain、字串才收）。
--   理由：發光要跟著皮的形狀（圓形皮配方形發光很突兀，Core/Glow.lua），而 Masque 沒有「這顆按鈕是什麼形狀」的公開 API——
--   它自己的觸發／閃光也是讀這個欄位決定用哪一組貼圖（Core/Regions/SpellAlert.lua）。只讀這一個字串、不讀其他欄位、
--   不呼叫 _MSQ_CFG 的任何方法；拿到形狀之後用的貼圖一律走公開 API（GetSpellAlertFlipBook／GetSpellAlert）。
--   讀不到／不是字串 ⇒ nil（呼叫端當方形＝現狀）。依「框＋Generation」快取（弱鍵表，不在框上寫欄位）。
--
-- 圓環條（layout.style ＝ "rings"，Core/Decorate.lua 的「圓環顯示」）**不進群組**：Decorate.Resolve 把 masque 壓成 false，
-- 已經交出去的格子在套圓環前 Release（皮的方形外框、遮罩套在同心圓上沒意義，轉圈材質也要換成環形）。
-- 登入時是 Masque、執行中才切成圓環的條：卸皮留下的外框圖收不乾淨的話跟下面「群組被停用」同一個情況，重載就乾淨。
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
local gen = 0

function M.Generation() return gen end

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
    gen = gen + 1
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
    holder.msqTouched = true       -- RemoveButton 會把圖示凍在預設皮的尺寸：Decorate.RefillIcon 貼回整格
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
            holder.msqTouched = true   -- 套過皮：之後切回米利（或群組被停用）時 Decorate.RefillIcon 要貼回整格
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
-- 光環格的探針（Modules/Custom.lua）：皮外框畫在哪一張貼圖上。Masque 多半不用我們給的 Normal，
-- 而是在按鈕上另建一張（皮沒有分狀態時把我們那張藏起來）⇒ 只能問它的公開 API GetNormal（拿到的是**我們自己框上**的貼圖）。
-- 沒有這支 API、或出錯 ⇒ nil（呼叫端當「讀不到」，退回米利邊）
------------------------------------------------------------
function M.GetNormal(button)
    if not (api and button) then return nil end
    local get = api.GetNormal
    if type(get) ~= "function" then return nil end
    local ok, t = pcall(get, api, button)
    if ok and type(t) == "table" then return t end
    return nil
end

------------------------------------------------------------
-- 皮的形狀（Core/Glow.lua 的發光、Modules/Custom.lua 光環格的生效發光用）
--
-- ShapeOf：見檔頭的例外說明。只在 Masque 有載入時讀；找到字串才快取（套皮可能晚到：還沒套上時讀不到，下次再讀）。
-- Masque 那邊設定一變 Generation 就加一 ⇒ 快取作廢、重讀。
------------------------------------------------------------
local function Plain(v)
    if v == nil or (ns.IsSecret and ns.IsSecret(v)) then return nil end
    local can = _G.canaccessvalue
    if can and not can(v) then return nil end
    return v
end

local shapeOf = setmetatable({}, { __mode = "k" })     -- 框 → 形狀字串
local shapeGen = setmetatable({}, { __mode = "k" })    -- 框 → 讀到形狀時的 Generation

local function ReadShape(frame)
    local cfg = Plain(rawget(frame, "_MSQ_CFG"))
    if type(cfg) ~= "table" then return nil end
    local s = Plain(rawget(cfg, "Shape"))
    if type(s) == "string" and s ~= "" then return s end
    return nil
end

function M.ShapeOf(frame)
    if type(frame) ~= "table" or not M.Available() then return nil end
    if shapeGen[frame] == gen then return shapeOf[frame] end
    local ok, s = pcall(ReadShape, frame)
    if ok and s then
        shapeOf[frame], shapeGen[frame] = s, gen
        return s
    end
    shapeOf[frame], shapeGen[frame] = nil, nil
    return nil
end

-- 循環圖的風格固定 "Modern"：跟以前寫死的方形循環圖（Textures/Square/SpellAlert-Loop-Modern）同一組。
-- Masque 自己用的是玩家在它設定裡選的風格（存在它的 db 裡，不讀）
local LOOP_STYLE = "Modern"

-- 回傳的表是我們自己的（每次新建，呼叫端自己快取）：tex、格子寬高；格子排法不是 6×5／30 格時才帶 rows／cols／frames
function M.SpellAlertLoop(shape)
    if type(shape) ~= "string" or not M.Available() then return nil end
    local fn = api.GetSpellAlertFlipBook
    if type(fn) ~= "function" then return nil end
    local ok, d = pcall(fn, api, LOOP_STYLE, shape)
    if not (ok and type(d) == "table") then return nil end
    local tex = rawget(d, "LoopTexture")
    if type(tex) ~= "string" or tex == "" then return nil end
    local out = { tex = tex, w = tonumber(rawget(d, "FrameWidth")) or 0, h = tonumber(rawget(d, "FrameHeight")) or 0 }
    local rows = tonumber(rawget(d, "Rows")) or 6
    local cols = tonumber(rawget(d, "Columns")) or 5
    local frames = tonumber(rawget(d, "Frames")) or 30
    if rows ~= 6 or cols ~= 5 or frames ~= 30 then out.rows, out.cols, out.frames = rows, cols, frames end
    return out
end

-- Masque 只附了圓形與方形兩組（六角形沒有 ⇒ nil）；皮可以用 AddSpellAlert 加
function M.SpellAlertOverlay(shape)
    if type(shape) ~= "string" or not M.Available() then return nil end
    local fn = api.GetSpellAlert
    if type(fn) ~= "function" then return nil end
    local ok, glow, ants = pcall(fn, api, shape)
    if ok and type(glow) == "string" and glow ~= "" and type(ants) == "string" and ants ~= "" then
        return glow, ants
    end
    return nil
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
