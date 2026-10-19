------------------------------------------------------------
-- 資源條：專精 → 該專精要看的資源清單，一種資源一列（獨立 HUD，容器 MiliUICDM_Bar_resources）
--
-- 引擎從套組自己的單位框架（MiliUI_UnitFrames 的資源條與能量條）改來，差別：
--   * **有法力**：單位框自己有能量條，所以那邊刻意不做法力；這裡是獨立 HUD，
--     有法力的專精在最下面多一列法力條（做法照能量條：上限／目前值直接餵 StatusBar）。
--   * **主資源也列**：那邊把「單位框能量條已經在畫的主資源」剔掉，這裡不剔。
--   * **血量**：每個專精的候選都多一列血量條（Health，預設關），見下面「血量」一節。
--
-- 列的順序：預設照專精的清單（法力、血量排最下面），玩家可以在設定頁上下移（resources.order，
-- 整份設定檔共用、不分專精；見 R.ApplyOrder）。
-- 哪幾列要顯示是**分專精**存的（resources.rows[specID][key]，見 R.RowOn／R.SetRow）。
-- 高度（resources.heights[key]）與外觀（resources.style[key]，見 R.StyleFor）是逐列的、所有專精共用。
--
-- 獨立擺放（resources.detached[key].on，所有專精共用；2026-10-13）：這一列離開資源條，照自己的錨定／位置擺在
-- 面板 "res:<key>"（容器 MiliUICDM_Bar_res:<key>，第一次用到才登記；Core/Bars.lua 的「第一次用到才登記的面板」）。
--   * 列的 parent **不換**（留在 root 底下），只把 SetPoint 改錨到那個面板的容器：顯示條件、整條關掉、淡出
--     全部由資源條的容器帶，「顯示條件跟資源條」不用另外寫；代價是 strata 跟資源條一樣。
--   * 拆出的列不累計 y、不算進資源條的寬高（R.MainRows）；那個面板的大小＝這一列的寬高。
--   * 閒置（開關關著、這個專精／型態沒有這一列、資源條整條關掉）：面板當它不存在（Bars 的 idle／Dormant），
--     判斷讀 R.det.live（上一次排版的結果 ⇒ 跟畫面一致；戰鬥中排版延後時也一起延後）。
--   * 引擎畫的列（無視苦痛、鐵鬃…）是保護框：錨在它身上的容器跟著變成隱式保護，容器的寫入照舊全走 ns.Write，
--     資源條本身照舊 MustDefer／DeferRelayout。
--
-- 每一列自己決定長相：
--   pip        分段（點數型：聖能／連擊點數／真氣／碎片／充能／精華／符文，以及光環堆疊型：冰刺…）
--   bar        連續長條（怒氣／能量／集中值／符文能量／星能／元能／狂亂值／魔怒／法力；
--              def.get 型：醉仙緩勁 UnitStagger／UnitHealthMax、噬靈魂碎片、血量 UnitHealth／UnitHealthMax）
--   auraPct    **引擎寫百分比**（無視苦痛）：增益 190456 的「層數」欄位是盾量佔上限的百分比（0～100）。
--              單格 AuraContainer ＋ SetApplicationBar(bar, { maxApplications = 100 })，畫成連續條（列上的
--              裝飾不畫分格）；showText 時層數走 SetApplicationCount、後面接一個自己的「%」。
--              只算這個增益自己的盾（別人套的盾、其他吸收不算）。條件規則不適用。
--              容器沒好（戰鬥中、建失敗）時退回下面的 absorbBar（所有吸收盾的總量）。
--   absorbBar  吸收盾（auraPct 的退路）：值 UnitGetTotalAbsorbs("player")、上限「最大生命的三成」。
--              ⚠ 不對秘密的最大生命乘 0.3：用幾何做 —— 裁切框寬 W（SetClipsChildren），裡面的 StatusBar
--              寬 W / 0.3、貼在填充起點那一側，SetMinMaxValues(0, UnitHealthMax)，於是只看得到前三成。
--              這條 StatusBar 的填充貼圖上不錨任何東西、不讀它的尺寸。
--   auraBar    **引擎寫層數**（Modules/AuraBar.lua）：GetPlayerAuraBySpellID 讀不到的增益（旋風斬、橫掃攻擊）
--              用一顆單格 AuraContainer ＋ SetApplicationBar；每施放一次多一顆獨立光環的（鐵鬃）用
--              AddAuraGroup ＋ 每顆 SetDurationBar（一格一層、各自倒數；目前沒有使用者，鐵鬃實測是疊層數）。
--              條件規則不適用；showText 時文字也交給引擎，內容照 R.AuraText（層數／秒數／兩者）。
--              容器是受保護的 intrinsic ⇒ 有這種列時面板在戰鬥中不重排（記旗標、脫戰補）。
--   auraTimer  **光環剩餘時間條**（黯黑力量、秘法靈魂）：同一支 AuraBar 的 kind = "duration"，單格 AuraContainer
--              ＋ SetDurationBar（RemainingTime）：光環在身上時引擎往下縮、不在時是空條（列上畫的暗底）。
--              上限秒數不經 Lua（引擎用光環自己的持續時間，含延長）；showText 時秒數走 SetDurationText。
--              秘法靈魂可以改印「剩幾個 GCD」（arcaneSoulText = "gcd"）：數字格式器一個 GCD 一段，
--              GCD 長度在建容器前用明文算好、進簽章（R.GcdLength）。
--              條件規則不適用；容器沒好（戰鬥中、建失敗）時先畫空條（timerIdle）。
--
-- 12.1 秘密值（見 .claude/notes/wow-121-secret-values.md）：
--   * 連續條：UnitPowerMax／UnitPower **直接**餵 SetMinMaxValues／SetValue（引擎收秘密值），
--     明文且上限 <= 0 才顯示空條。
--   * 點數型：「第 i 格亮不亮」**不在 Lua 比**。每一格是一顆 StatusBar，
--     SetMinMaxValues(i-1, i)＋SetValue(目前值) —— 秘密值照樣畫得對。
--     毀滅術（267）的靈魂裂片改讀原始單位（UnitPower(…, true)，一顆 ＝ per 單位）：
--     第 i 格 SetMinMaxValues((i-1)·per, i·per)＋SetValue(原始值)，碎片的零頭也由引擎畫。
--     明文時正在累積的那一格用暗一階的顏色、文字印一位小數（R.ShardSplit）。
--   * 喚能師精華：下一格畫回充進度（UnitPartialPower，讀不到改用回充速度推算；明文才算，R.EssenceFrac），
--     跟符文共用「有格子在回充才跑」的 0.1 秒 ticker。
--   * 氣漩武器摺疊（maelstromFold）：10 層摺成 5 格，每格疊兩顆 StatusBar，
--     底層 (i-1, i)、上層 (i+4, i+5) 都 SetValue(層數)；上層用溢出色（R.FoldRange）。
--   * 條件規則、數值文字、充能格判斷只吃**明文**（canaccessvalue）；讀不到就不求值
--     （照原本的顏色）、不印字。玩家自己的資源在目前的客戶端是明文，這是保底。
--   * 格子一律錨在列本身（不串在前一格上）：SetValue(秘密值) 會讓那顆 StatusBar 的幾何
--     變成秘密，錨在它身上的東西會被傳染。
--
-- 事件處理器只標髒、下一幀做（ns.Defer）。能量走 UNIT_POWER_FREQUENT（UNIT_POWER_UPDATE
-- 在回能／衰減時兩秒才一次，留著當回滿的保底）。
--
-- 自訂格子（cfg.customRows[specID]）是另一個面板（Modules/Pips.lua，容器 MiliUICDM_Bar_pips）：
-- 清單存在這張設定表、樣式（列高、格距、材質、填充方向、寬度）沿用這裡，位置與錨定是它自己的。
-- 這支只出借共用的小工具（Plain、AuraStacks、Edges、Width、RowHeight、DIM）。
------------------------------------------------------------
local _, ns = ...

-- 關掉貼圖的像素貼齊（Core/Media.lua 的 ns.NoSnap；離線測試沒載 Media 時是空操作）
local function NoSnap(t) if ns.NoSnap then ns.NoSnap(t) end return t end

local L = ns.L

ns.Resources = {}
local R = ns.Resources

local RC = ns.ResCond
local CLASS = ns.playerClass
local PT = (Enum and Enum.PowerType) or {}
local MAX_SEGMENTS = RC.MAX_SEGMENTS
local SOLID = "Interface\\BUTTONS\\WHITE8X8"
local DIM = { r = 0.15, g = 0.15, b = 0.15, a = 0.6 }
R.DIM = DIM
local WHITE = { r = 1, g = 1, b = 1 }

local function Plain(v)
    if type(v) ~= "number" then return nil end
    if ns.IsSecret(v) then return nil end
    return v
end
R.Plain = Plain

-- 死騎符文列的數字：「長條上顯示數值」（showText）是總開關，開著時這裡二選一
-- （使用者 2026-10-01 試過兩者並列後定案：一排數字裡再夾一個顆數會分不出哪個是顆數、
-- 哪個是秒數，不要再拆成兩個獨立開關）。
--   countdown 在轉的格子印剩餘秒數（預設）／count 中間印轉好的顆數
-- 排序與回充進度不受影響，兩種都有
function R.RuneText(cfg)
    local v = type(cfg) == "table" and cfg.runeText
    if v == "count" then return v end
    return "countdown"
end

-- 取值：**原始值**（可能是秘密值）。要比較、要當文字之前一律過 Plain
------------------------------------------------------------
local function AuraStacks(spellID)
    local get = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID
    if not get then return 0 end
    local ok, a = pcall(get, spellID)
    if not ok or not a then return 0 end
    local ok2, n = pcall(function() return a.applications end)
    if not ok2 or n == nil then return 0 end
    return n
end
R.AuraStacks = AuraStacks

-- 回傳 cur, max（原始值）
local function GetValue(key)
    local def = R.RESOURCES[key]
    if not def then return 0, 0 end
    if def.mode == "auraTimer" or def.mode == "mirror" then return 0, 0 end     -- 剩餘時間只在引擎／暴雪的條那邊，Lua 不讀
    if def.get then return def.get() end
    if def.aura then return AuraStacks(def.aura), def.max end
    if def.auras then return AuraStacks(def.auras[1]), R.SegmentsFor(key) end
    if def.cast then
        local fn = C_Spell and C_Spell.GetSpellCastCount
        if not fn then return 0, def.max end
        local ok, n = pcall(fn, def.cast)
        if not ok or n == nil then n = 0 end
        return n, def.max
    end
    if def.power == nil then return 0, 0 end
    local cur = UnitPower("player", def.power)
    local max = UnitPowerMax("player", def.power)
    return cur or 0, max or 0
end
R.GetValue = GetValue

------------------------------------------------------------
-- 設定
------------------------------------------------------------
local function Cfg() return ns.DB and ns.DB.ConfigTable("resources") end
R.Cfg = Cfg

-- 虛空化身門檻規則的清理（設定頁寫入前；純函式本體在 Modules/DevourerMeta.lua）
function R.CleanMetaRules(rules) return ns.DevourerMeta.CleanRules(rules) end

-- 顏色：玩家調的 cfg.colors[key][field] → Core/DB.lua 的預設。回傳既有的表，一次都不配新的
local function DefaultColor(key, field)
    local t = ns.DB and ns.DB.RESOURCE_COLORS and ns.DB.RESOURCE_COLORS[key]
    local c = t and t[field]
    if RC.ValidColor(c) then return c end
    -- 充能色缺了退回主色（不要退成白色：白色比主色還亮，充能格的判讀會反過來）
    if field ~= "color" then return DefaultColor(key, "color") end
    return WHITE
end
R.DefaultColor = DefaultColor

local function ResolveColor(cfg, key, field)
    local own = type(cfg) == "table" and type(cfg.colors) == "table" and cfg.colors[key]
    local c = type(own) == "table" and own[field]
    if RC.ValidColor(c) then return c end
    return DefaultColor(key, field)
end
R.ResolveColor = ResolveColor

------------------------------------------------------------
-- 天賦判斷
--
--   標準資源看 UnitPowerMax > 0（沒點到那個天賦時上限就是 0；秘密值當有）。
--   光環堆疊型查被動是否已學；被動 ID 萬一寫錯會誤判，所以**目前有層數就一律顯示**。
--   ⚠ 那條保險只保得住「脫戰且當下有層數」：12.1 戰鬥中層數／施放次數是秘密值、脫戰沒層數是 0，
--   被動 ID 寫成法術書查不到的東西（buff 光環的 ID）整列就會時有時無。def.passive 一律填
--   法術書查得到的技能或被動（靈魂碎片 2026-10-19 踩過：203981 是 buff，改看碎魂斬 228477）。
------------------------------------------------------------
local function SpellKnown(id)
    if not id then return true end
    local fn = C_SpellBook and C_SpellBook.IsSpellKnown
    if not fn then return true end
    local ok, known = pcall(fn, id)
    if not ok then return true end
    if ns.IsSecret(known) then return true end
    return known and true or false
end

-- 目前的英雄天賦樹（明文才算；讀不到回 nil）
local function ActiveHeroTree()
    local fn = C_ClassTalents and C_ClassTalents.GetActiveHeroTalentSpec
    if not fn then return nil end
    local ok, v = pcall(fn)
    if not ok then return nil end
    return Plain(v)
end

local gateLog = {}
R.gateLog = gateLog

local function Available(key)
    local def = R.RESOURCES[key]
    if not def then return false, "沒有定義" end
    if def.mode == "mirror" then
        if SpellKnown(def.passive) then return true, "被動已學" end
        return false, "被動未學（天賦沒點）"
    end
    if def.aura or def.cast or def.auras or def.get then
        if SpellKnown(def.passive) then return true, def.passive and "被動已學" or "不需要天賦" end
        if def.heroTree and ActiveHeroTree() == def.heroTree then return true, "英雄天賦樹 " .. tostring(def.heroTree) end
        -- 剩餘時間條沒有 Lua 讀得到的值，沒有「目前有層數」這條保險
        if def.mode == "auraTimer" then return false, "被動未學（天賦沒點）" end
        local cur = Plain((GetValue(key)))
        if (cur or 0) > 0 then return true, "被動查不到但目前有層數" end
        return false, "被動未學（天賦沒點）"
    end
    local _, max = GetValue(key)
    local pm = Plain(max)
    if pm == nil then return true, "上限讀不到（秘密值），照列" end
    if pm <= 0 then return false, "上限 0（天賦沒點／此型態沒有）" end
    return true, "上限 " .. tostring(pm)
end
R.Available = Available     -- 離線測試直接問閘（Candidates 綁定載入時的職業）

local function CurrentSpecID()
    return ns.specID
end
R.CurrentSpecID = CurrentSpecID

local function DruidForm()
    if CLASS ~= "DRUID" then return nil end
    local fn = GetShapeshiftFormID
    local form = fn and fn()
    return Plain(form)
end

------------------------------------------------------------
-- 列的順序（resources.order：資源 key 的陣列，整份設定檔共用、不分專精）
--
-- 在 order 裡的照它的位置；不在的維持原本（專精清單）的相對順序、排在所有排過的後面。
-- 寫回時別的專精才有的 key 錨在原本的鄰居後面（R.MergeOrder），兩個專精各排各的、共有列不互相洗掉。
-- 不分專精 ⇒ 兩個專精共有的 key（法力、血量…）在一邊調了另一邊也跟著；只差在各自有哪幾列。
------------------------------------------------------------
-- 純函式：回傳排好的新表（list 不動）。穩定：同樣沒排過的照原順序；order 裡重複的 key 只認第一次
function R.ApplyOrder(list, order)
    local out = {}
    if type(list) ~= "table" then return out end
    if type(order) ~= "table" or #order == 0 then
        for i, key in ipairs(list) do out[i] = key end
        return out
    end
    local present, placed = {}, {}
    for _, key in ipairs(list) do present[key] = true end
    for _, key in ipairs(order) do
        if present[key] and not placed[key] then
            out[#out + 1] = key
            placed[key] = true
        end
    end
    for _, key in ipairs(list) do
        if not placed[key] then
            out[#out + 1] = key
            placed[key] = true
        end
    end
    return out
end

-- 純函式：設定頁上下移之後要存的 order。cand ＝ 這個專精排好的完整清單（照它排），
-- 舊 order 裡不在 cand 的 key（別的專精才有的）**錨在它在舊 order 裡的前一個 key 後面**（沒有前一個就排最前）。
-- 不能一律接到最後：懲戒排「聖能、征戰、血量」、神聖排「聖能、法力、血量」，接到最後會變成
-- 「聖能、法力、血量、征戰」，切回懲戒就成了「聖能、血量、征戰」（血量是兩邊共有的才會露餡）
function R.MergeOrder(old, cand)
    local out, seen = {}, {}
    for _, key in ipairs(type(cand) == "table" and cand or {}) do
        if not seen[key] then
            out[#out + 1] = key
            seen[key] = true
        end
    end
    local prev
    for _, key in ipairs(type(old) == "table" and old or {}) do
        if type(key) == "string" then
            if not seen[key] then
                local at = 1
                if prev then
                    for i = 1, #out do
                        if out[i] == prev then at = i + 1; break end
                    end
                end
                table.insert(out, at, key)
                seen[key] = true
            end
            prev = key
        end
    end
    return out
end

-- 這個專精「可以顯示」哪些資源（已套天賦／型態與玩家排的順序，不看玩家的開關）。有快取，
-- 專精／型態／天賦／上限變動時 Reevaluate 清掉（設定頁改順序走 R.Apply，同樣清）
local cachedList, cachedSpec

function R.Candidates()
    if cachedList then return cachedList, cachedSpec end
    local specID = CurrentSpecID()
    local raw = R.RawList(CLASS, specID, DruidForm())
    -- 血量每個專精都有（預設關，見 R.DefaultOn）：RawList 不動，在這裡接到最後
    if specID then raw[#raw + 1] = "Health" end
    for k in pairs(gateLog) do gateLog[k] = nil end
    local list = {}
    for _, key in ipairs(raw) do
        local ok, why = Available(key)
        gateLog[key] = (ok and "顯示：" or "隱藏：") .. why
        if ok then list[#list + 1] = key end
    end
    local cfg = Cfg()
    list = R.ApplyOrder(list, cfg and cfg.order)
    cachedList, cachedSpec = list, specID
    return list, specID
end

function R.Invalidate() cachedList = nil end

function R.Info(key) return R.RESOURCES[key] end

-- 實際要畫的清單（套上玩家的開關 rows[key] 與每個專精的預設，見 R.RowOn）。scratch 表，呼叫端不可留著
local activeRows = {}
local function ActiveRows(cfg)
    local cand, specID = R.Candidates()
    for i = #activeRows, 1, -1 do activeRows[i] = nil end
    for _, key in ipairs(cand) do
        if R.RESOURCES[key] and R.RowOn(cfg, specID, key) then activeRows[#activeRows + 1] = key end
    end
    return activeRows
end

------------------------------------------------------------
-- 氣漩武器摺疊（maelstromFold，預設關）：10 層摺成 5 格，每格兩顆疊起來的 StatusBar
--   底層 (i-1, i)、上層 (i-1+5, i+5)，同樣 SetValue(層數) ⇒ 6 層時第 1 格的上層亮、2～5 格只有底層
-- 上層用溢出色（colors.MaelstromWeapon.overflowColor）。條件規則：整條的覆寫照舊，
-- 逐格的顏色只套在底層（格子序號是 1～5）
------------------------------------------------------------
local FOLD_SEGMENTS = 5
R.FOLD_SEGMENTS = FOLD_SEGMENTS

function R.Folded(cfg, key)
    local def = R.RESOURCES[key]
    return def ~= nil and def.foldable == true and type(cfg) == "table" and cfg.maelstromFold == true
end

-- 純函式：摺疊時第 i 格第 layer 層（1 底、2 上）的 min／max
function R.FoldRange(i, layer, n)
    n = n or FOLD_SEGMENTS
    if layer == 2 then return i - 1 + n, i + n end
    return i - 1, i
end

------------------------------------------------------------
-- 毀滅術的碎片零頭（專精 267）
--   UnitPower(…, true)／UnitPowerMax(…, true) 是原始單位（一顆 ＝ 10）；per ＝ 原始上限 ／ 整顆上限，
--   讀不到（秘密值、0）就 10。第 i 格 (i-1)·per ～ i·per，SetValue 原始值（秘密值也畫得對）
------------------------------------------------------------
local SHARD_UNITS = 10
function R.ShardPer(rawMax, max)
    local rm, m = Plain(rawMax), Plain(max)
    if rm and m and m > 0 and rm > 0 then return rm / m end
    return SHARD_UNITS
end

-- 純函式（明文才叫）：原始值 → 整顆數、正在累積的那一格（沒有 ＝ nil）、顆數（帶小數）
function R.ShardSplit(raw, per, n)
    if type(raw) ~= "number" or type(per) ~= "number" or per <= 0 then return nil end
    local value = raw / per
    local whole = math.floor(value + 1e-6)
    local partial
    if raw - whole * per > 1e-6 and whole < (n or math.huge) then partial = whole + 1 end
    return whole, partial, value
end

------------------------------------------------------------
-- 精華回充（喚能師）
--   來源優先 UnitPartialPower（0～1000，明文且 > 0 才用）；拿不到 → 回充速度（每秒幾顆，
--   GetPowerRegenForPowerType，明文才收、記住上次的）× 距離上次精華變動的秒數。兩者都沒有 ＝ 不畫
------------------------------------------------------------
function R.EssenceFrac(partial, rate, elapsed)
    local f
    if type(partial) == "number" and partial > 0 then
        f = partial / 1000
    elseif type(rate) == "number" and rate > 0 and type(elapsed) == "number" and elapsed >= 0 then
        f = elapsed * rate
    else
        return nil
    end
    if f < 0 then f = 0 elseif f > 0.999 then f = 0.999 end
    return f
end

------------------------------------------------------------
-- 秘法靈魂的「剩幾個 GCD」：GCD 長度（明文才算）
--   C_Spell.GetSpellCooldown(61304) 正在 GCD 時的 duration；不在 GCD（0）或讀不到 ⇒ 1.5 ／（1 ＋ 加速 ／ 100）；
--   加速也讀不到 ⇒ 上次的、再沒有就 1.5。夾在 0.75～1.5，四捨五入到 0.05 秒（進容器簽章，別讓小數抖動換容器）
------------------------------------------------------------
local GCD_BASE, GCD_MIN = 1.5, 0.75
function R.GcdLength(cdDuration, haste, last)
    local g
    if type(cdDuration) == "number" and cdDuration > 0 then
        g = cdDuration
    elseif type(haste) == "number" and haste > -100 then
        g = GCD_BASE / (1 + haste / 100)
    else
        g = tonumber(last) or GCD_BASE
    end
    if g < GCD_MIN then g = GCD_MIN elseif g > GCD_BASE then g = GCD_BASE end
    return math.floor(g / 0.05 + 0.5) * 0.05
end

local GCD_SPELL = 61304
local gcdLast
function R.ReadGcd()
    local dur
    local fn = C_Spell and C_Spell.GetSpellCooldown
    if fn then
        local ok, info = pcall(fn, GCD_SPELL)
        if ok and type(info) == "table" then
            local ok2, d = pcall(function() return info.duration end)
            if ok2 then dur = Plain(d) end
        end
    end
    local haste
    if UnitSpellHaste then
        local ok, h = pcall(UnitSpellHaste, "player")
        if ok then haste = Plain(h) end
    end
    gcdLast = R.GcdLength(dur, haste, gcdLast)
    return gcdLast
end

-- 引擎寫層數的列（auraBar：鐵鬃、旋風斬、橫掃攻擊）的文字，showText 開著才有；逐資源存在 auraText[key]：
--   stacks 疊層數字（預設）／time 剩餘秒數／stacksTime 疊層數字 (剩餘秒數)／timeStacks 剩餘秒數 (疊層數字)
-- 自訂格子的層數列用同一組值（entry.text.mode，Pips.TextMode）
R.AURA_TEXT_MODES = { stacks = true, time = true, stacksTime = true, timeStacks = true }
function R.AuraText(cfg, key)
    local t = type(cfg) == "table" and cfg.auraText
    local v = type(t) == "table" and t[key]
    if R.AURA_TEXT_MODES[v] then return v end
    return "stacks"
end

-- 秘法靈魂的文字：seconds（剩餘秒數，預設）／gcd（剩幾個 GCD）
function R.ArcaneSoulText(cfg)
    local v = type(cfg) == "table" and cfg.arcaneSoulText
    if v == "gcd" then return v end
    return "seconds"
end

-- 一列現在要幾格（bar 回 0）。上限讀不到（秘密值）時沿用上次的明文值，沒有就 5
local lastMax = {}
local function SegmentsFor(key)
    local def = R.RESOURCES[key]
    if not def then return 0 end
    if def.mode == "auraBar" then
        -- 引擎畫的連續填色：格數不受點數型的 30 格上限限制（橫掃攻擊 18 層）
        local m = def.maxFn and def.maxFn() or def.max
        return math.max(1, math.min(30, math.floor(tonumber(m) or 1)))
    end
    if def.mode ~= "pip" then return 0 end
    if def.foldable and R.Folded(Cfg(), key) then return FOLD_SEGMENTS end
    if def.max then return def.max end
    local _, max = GetValue(key)
    local pm = Plain(max)
    if pm == nil then pm = lastMax[key] or 5 else lastMax[key] = pm end
    if pm <= 0 then return 0 end
    return math.min(MAX_SEGMENTS, pm)
end
R.SegmentsFor = SegmentsFor

------------------------------------------------------------
-- 充能的連擊點
--
--   盜賊  GetUnitChargedPowerPoints("player") → 被充能的**索引**陣列；事件 UNIT_POWER_POINT_CHARGE
--   野德  光環 405189 的層數 n ⇒ 第 1..n 格算充能
-- 查表用檔案層級的表重用（Update 掛在能量事件上）。索引一律驗過明文才當 key。
------------------------------------------------------------
local FERAL_OVERFLOW_AURA = 405189
local chargedLookup = {}
local chargedDirty = true

local function Wipe(t) for k in pairs(t) do t[k] = nil end end

local function RefreshChargedLookup()
    chargedDirty = false
    Wipe(chargedLookup)
    local fn = GetUnitChargedPowerPoints
    if type(fn) ~= "function" then return end
    local ok, list = pcall(fn, "player")
    if not ok or type(list) ~= "table" then return end
    for i = 1, #list do
        local idx = Plain(list[i])
        if idx and idx > 0 then chargedLookup[idx] = true end
    end
end

local function ChargedPoints(key)
    if key ~= "ComboPoints" then return nil end
    if CLASS == "ROGUE" then
        if chargedDirty then RefreshChargedLookup() end
        return next(chargedLookup) and chargedLookup or nil
    end
    if CLASS == "DRUID" then
        local n = Plain(AuraStacks(FERAL_OVERFLOW_AURA))
        if not n or n <= 0 then return nil end
        Wipe(chargedLookup)
        for i = 1, math.min(n, MAX_SEGMENTS) do chargedLookup[i] = true end
        return chargedLookup
    end
    return nil
end
R.ChargedPoints = ChargedPoints

------------------------------------------------------------
-- 數值文字
------------------------------------------------------------
-- 法力縮寫：none（完整數字）／k（K、M）／wan（萬、億；中日韓讀法）
function R.FormatMana(v, max, cfg)
    if type(v) ~= "number" then return "" end
    if cfg and cfg.manaPercent then
        if not max or max <= 0 then return "" end
        return ("%d%%"):format(math.floor(v / max * 100 + 0.5))
    end
    local mode = cfg and cfg.manaAbbrev or "k"
    if mode == "wan" then
        if v >= 1e8 then return ("%.2f"):format(v / 1e8) .. L["yi"] end
        if v >= 1e4 then return ("%.1f"):format(v / 1e4) .. L["wan"] end
        return ("%d"):format(v)
    elseif mode == "k" then
        if v >= 1e6 then return ("%.1fM"):format(v / 1e6) end
        if v >= 1e4 then return ("%.0fK"):format(v / 1e3) end
        if v >= 1e3 then return ("%.1fK"):format(v / 1e3) end
        return ("%d"):format(v)
    end
    return ("%d"):format(v)
end

-- 秘密值（12.1 起法力、戰鬥中的其他資源）Lua 讀不到：縮寫與百分比全交給 C 端，Lua 只當傳遞者。
-- 分段照 R.FormatMana：significand ＝ floor(v ／ significandDivisor)，印 significand ／ fractionDivisor
local abbrevCfg = {}
local function AbbrevConfig(mode)
    if abbrevCfg[mode] ~= nil then return abbrevCfg[mode] end
    local opts
    if mode == "wan" then
        opts = {
            { breakpoint = 1e8, abbreviation = L["yi"],  significandDivisor = 1e6, fractionDivisor = 100, abbreviationIsGlobal = false },
            { breakpoint = 1e4, abbreviation = L["wan"], significandDivisor = 1e3, fractionDivisor = 10,  abbreviationIsGlobal = false },
            { breakpoint = 1,   abbreviation = "",       significandDivisor = 1,   fractionDivisor = 1,   abbreviationIsGlobal = false },
        }
    elseif mode == "k" then
        opts = {
            { breakpoint = 1e6, abbreviation = "M", significandDivisor = 1e5, fractionDivisor = 10, abbreviationIsGlobal = false },
            { breakpoint = 1e4, abbreviation = "K", significandDivisor = 1e3, fractionDivisor = 1,  abbreviationIsGlobal = false },
            { breakpoint = 1e3, abbreviation = "K", significandDivisor = 100, fractionDivisor = 10, abbreviationIsGlobal = false },
            { breakpoint = 1,   abbreviation = "",  significandDivisor = 1,   fractionDivisor = 1,  abbreviationIsGlobal = false },
        }
    end
    local cfg = false
    if opts and CreateAbbreviateConfig then
        local ok, c = pcall(CreateAbbreviateConfig, opts)
        if ok and c then cfg = { config = c } end
    end
    abbrevCfg[mode] = cfg
    return cfg
end

-- 數值寫進 FontString：明文走 R.FormatMana，秘密值原樣交給 AbbreviateNumbers／SetFormattedText
-- percentOf ＝ 要印百分比時的 power type（秘密值的百分比只能問 UnitPowerPercent）
function R.SetNumberText(fs, v, max, cfg, percentOf)
    if not ns.IsSecret(v) and (max == nil or not ns.IsSecret(max)) then
        fs:SetText(R.FormatMana(v, max, cfg))      -- 不是數字時 FormatMana 回空字串
        return
    end
    if cfg and cfg.manaPercent and percentOf then
        local scale = CurveConstants and CurveConstants.ScaleTo100
        if UnitPowerPercent and scale then
            fs:SetFormattedText("%d%%", UnitPowerPercent("player", percentOf, false, scale))
        else
            fs:SetText("")
        end
        return
    end
    local ac = AbbrevConfig(cfg and cfg.manaAbbrev or "k")
    if ac and AbbreviateNumbers then
        fs:SetText(AbbreviateNumbers(v, ac))
    else
        fs:SetFormattedText("%d", v)
    end
end

------------------------------------------------------------
-- 框
------------------------------------------------------------
local container, root
local rows = {}                 -- 池化的列（frame 刪不掉，換專精只換內容）
local condState = RC.NewState()
R.condState = condState

-- 邊框：疊在填充之上（不是內縮），線寬換成整數實體像素。
-- 粗細與顏色是資源條的外觀設定（borderSize 0～4 實體像素、borderColor；每種資源可在自己的外觀裡蓋，
-- R.StyleFor 的代理表）。預設 1px 不透明黑 ＝ 加設定以前的樣子。0 ＝ 不畫邊框
R.BORDER_MIN, R.BORDER_MAX, R.BORDER_DEFAULT = 0, 4, 1
local BORDER_BLACK = { r = 0, g = 0, b = 0, a = 1 }

function R.BorderSize(cfg)
    local v = tonumber(type(cfg) == "table" and cfg.borderSize or nil)
    if not v then return R.BORDER_DEFAULT end
    v = math.floor(v + 0.5)
    if v < R.BORDER_MIN then v = R.BORDER_MIN elseif v > R.BORDER_MAX then v = R.BORDER_MAX end
    return v
end

-- 回傳色表 { r, g, b, a }（壞資料／沒存 ＝ 不透明黑）
function R.BorderColor(cfg)
    local c = type(cfg) == "table" and RC.ValidColor(cfg.borderColor) or nil
    return c or BORDER_BLACK
end

local function MakeEdge(parent, p1, p2)
    local e = NoSnap(parent:CreateTexture(nil, "OVERLAY"))
    e:SetTexture(SOLID)
    e:SetVertexColor(0, 0, 0, 1)
    e:SetPoint(p1)
    e:SetPoint(p2)
    return e
end

-- 一組四條邊（上、下、左、右）的粗細與顏色。t ＝ 實體像素整數（0 ＝ 藏起來）、c ＝ 色表。
-- 值沒變就不碰貼圖（重排時每列都會叫，設定沒改就零寫入）。
-- ⚠ 線寬是 ns.P.Pixel(t)：UI 縮放改了要重算 ⇒ 握柄也記下當時的 1px 換算值
local function PaintEdges(edges, t, c)
    if type(edges) ~= "table" then return end
    t = tonumber(t) or R.BORDER_DEFAULT
    c = c or BORDER_BLACK
    local r, g, b, a = c.r or 0, c.g or 0, c.b or 0, c.a or 1
    local px = ns.P.Pixel(1)
    if edges.t == t and edges.px == px and edges.r == r and edges.g == g and edges.b == b and edges.a == a then return end
    edges.t, edges.px, edges.r, edges.g, edges.b, edges.a = t, px, r, g, b, a
    if t <= 0 then
        for i = 1, 4 do edges[i]:Hide() end
        return
    end
    local w = ns.P.Pixel(t)
    edges[1]:SetHeight(w)
    edges[2]:SetHeight(w)
    edges[3]:SetWidth(w)
    edges[4]:SetWidth(w)
    for i = 1, 4 do
        edges[i]:SetVertexColor(r, g, b, a)
        edges[i]:Show()
    end
end
R.PaintEdges = PaintEdges

-- 給 AuraBar 裝飾（geom.px／geom.edge）：邊框粗細換成 UI 單位（0 ＝ 不畫）、顏色換成 { r, g, b, a } 陣列
function R.DecorPx(cfg)
    local t = R.BorderSize(cfg)
    if t <= 0 then return 0 end
    return ns.P.Pixel(t)
end

function R.EdgeArray(cfg)
    local c = R.BorderColor(cfg)
    return { c.r or 0, c.g or 0, c.b or 0, c.a or 1 }
end

-- 邊緣陰影（Core/Shape.lua 的 SH.EdgeShadow）：資源條外觀的三鍵 shadow／shadowSize／shadowAlpha
-- （每種資源可在自己的外觀裡蓋，R.StyleFor 的代理表）→ 粗細（實體像素）, 透明度 | nil（關／壞資料）。
-- 自訂格子、自訂列、觸發牌堆列、天空騎術都照資源條的全域這三個
function R.ShadowOf(cfg)
    if type(cfg) ~= "table" or not ns.Shape then return nil end
    return ns.Shape.ShadowOf(cfg.shadow, cfg.shadowSize, cfg.shadowAlpha)
end

-- 給 AuraBar 裝飾（geom.shadow）：{ px, alpha } | nil
function R.ShadowArray(cfg)
    local px, a = R.ShadowOf(cfg)
    if not px then return nil end
    return { px = px, alpha = a }
end

-- 一格一個框的分段（點數型、自訂格子）：第 i 格的 x 與寬（從填充起點量）。
-- 整列先換成整數實體像素再切：每格的左右邊界各自四捨五入，零頭平均分到各格，最後一格的右緣一定落在 W 上。
-- ⚠ 不能「格寬先對齊像素、再乘 n」：每格的捨入誤差會累積，6 格的符文列比同寬的符能條多出 2px
-- （玩家回報「自動同寬下兩列對不齊」）。
-- border ＝ 邊框粗細（實體像素；沒給 ＝ 1，天空騎術這種不吃資源條設定的呼叫端照舊）。
-- 每格自帶邊框，格距 0 時相鄰兩條邊並排成 2t ⇒ 改成重疊 t 實體像素，兩格共用同一條邊；
-- 邊框 0 時格距 0 ＝ 剛好相貼（不重疊）。格距 > 0 跟邊框無關：兩格之間空 spacing 實體像素
function R.SegCell(W, n, spacing, i, border)
    local px = ns.P.Pixel(1)
    if not px or px <= 0 then px = 1 end
    local t = math.floor((tonumber(border) or 1) + 0.5)
    if t < 0 then t = 0 end
    local gp = math.floor((tonumber(spacing) or 1) + 0.5)
    if gp <= 0 then gp = -t end
    local Wp = math.floor(W / px + 0.5)
    local span = Wp + gp
    local x0 = math.floor((i - 1) * span / n + 0.5)
    local x1 = math.floor(i * span / n + 0.5) - gp
    return x0 * px, (x1 - x0) * px
end

-- 在 frame 上建四條邊，回傳握柄（給 PaintEdges 改粗細／顏色）。沒給 t／c ＝ 1px 黑
-- （天空騎術照這個預設，不吃資源條的設定）
local function Edges(frame, t, c)
    local edges = {
        MakeEdge(frame, "TOPLEFT", "TOPRIGHT"),
        MakeEdge(frame, "BOTTOMLEFT", "BOTTOMRIGHT"),
        MakeEdge(frame, "TOPLEFT", "BOTTOMLEFT"),
        MakeEdge(frame, "TOPRIGHT", "BOTTOMRIGHT"),
    }
    PaintEdges(edges, t or R.BORDER_DEFAULT, c or BORDER_BLACK)
    return edges
end
R.Edges = Edges

-- 一格＝一顆 StatusBar（min i-1、max i，SetValue 目前值 ⇒ 秘密值也畫得對）
local function MakeSegment(row)
    local seg = CreateFrame("StatusBar", nil, row)
    seg:SetStatusBarTexture(SOLID)
    NoSnap(seg)
    local bg = NoSnap(seg:CreateTexture(nil, "BACKGROUND"))
    bg:SetTexture(SOLID)
    bg:SetAllPoints(seg)
    seg.bg = bg
    seg.edges = Edges(seg)
    seg:Hide()
    return seg
end

-- 符文格的秒數（懶建；只有符文列、倒數開著才顯示）。
-- 顯示／隱藏只在排版時做，更新只換字（SetText("")），熱路徑上不碰 Show／Hide
-- 數字的描邊：資源條自己的 textOutline（全域；每種資源可在自己的外觀裡蓋，R.StyleFor 的代理表）；
-- 沒存／"INHERIT" ＝ 跟主題的描邊（玩家回報「法力條不支援改描邊」，2026-10-03）
local function TextOutline(cfg)
    local v = type(cfg) == "table" and cfg.textOutline
    if type(v) == "string" and v ~= "" and v ~= ns.Media.INHERIT then return ns.Media.Outline(v) end
    return ns.Media.ThemeOutline()
end
R.TextOutline = TextOutline          -- 虛空化身那兩段字「跟隨這一列的數字」用（Modules/DevourerMeta.lua）

-- 條上數字的位移（textOffset，所有列共用）換成 FontString 自己的單位：字型忽略父層縮放（SetPixelFont），
-- 位移要乘上 UIParent 的縮放才是版面上的 N 點（同 DevourerMeta.Layout）
function R.TextOffset(cfg)
    local o = type(cfg) == "table" and cfg.textOffset
    if type(o) ~= "table" then return 0, 0 end
    local scale = UIParent:GetEffectiveScale()
    if not scale or scale <= 0 then scale = 1 end
    return (tonumber(o.x) or 0) * scale, (tonumber(o.y) or 0) * scale
end

local function LayoutRuneTimer(seg, on, cfg)
    if not on then
        if seg.timer then seg.timer:Hide() end
        return
    end
    if not seg.timer then
        local fs = seg:CreateFontString(nil, "OVERLAY")
        -- ⚠ 先給字型才能 SetText
        ns.Media.SetPixelFont(fs, 10, "OUTLINE")
        fs:SetDrawLayer("OVERLAY", 7)
        fs:SetJustifyH("CENTER")
        fs:SetPoint("CENTER", seg, "CENTER", 0, 0)
        fs:SetTextColor(1, 1, 1, 1)
        seg.timer = fs
    end
    ns.Media.SetPixelFont(seg.timer, tonumber(cfg.textSize) or 10, TextOutline(cfg), ns.Media.ElementFont(cfg.textFont, ns.Setting(nil, "font")))
    seg.timer:ClearAllPoints()
    seg.timer:SetPoint("CENTER", seg, "CENTER", R.TextOffset(cfg))
    seg.timer:SetText("")
    seg.timerSec = nil
    seg.timer:Show()
end

local function MakeRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row.segs = {}
    for i = 1, MAX_SEGMENTS do row.segs[i] = MakeSegment(row) end
    row.barBG = NoSnap(row:CreateTexture(nil, "BACKGROUND"))
    row.barBG:SetAllPoints(row)
    row.barBG:SetTexture(SOLID)
    row.bar = CreateFrame("StatusBar", nil, row)
    row.bar:SetAllPoints(row)
    row.bar:SetStatusBarTexture(SOLID)
    NoSnap(row.bar)
    -- 邊框建在 bar 上：bar 是層級更高的子框，建在 row 上會被填充蓋掉
    row.barEdges = Edges(row.bar)
    -- 數值掛在獨立的高層框上，父層是 row（點數型會把 bar 整個藏起來）
    -- 懶建的零件先放 false（有就是框、沒有就是 false；沒寫過的欄位別指望是 nil 以外的東西）
    row.ab, row.abDecor, row.absorbClip, row.absorbBar = false, false, false, false
    row.overs, row.folded = false, false      -- 氣漩武器摺疊的上層（懶建）
    row.metaTime, row.metaStars = false, false   -- 噬滅的虛空化身計時／崩陷之星計數（懶建，Modules/DevourerMeta.lua）
    row.textFrame = CreateFrame("Frame", nil, row)
    row.textFrame:SetAllPoints(row)
    row.text = row.textFrame:CreateFontString(nil, "OVERLAY")
    -- ⚠ 先給字型才能 SetText（沒字型的 FontString SetText 是硬錯）
    ns.Media.SetPixelFont(row.text, 10, "OUTLINE")
    row.text:SetDrawLayer("OVERLAY", 7)
    row.text:SetJustifyH("CENTER")
    row.text:SetPoint("CENTER", row.textFrame, "CENTER", 0, 0)
    row.text:SetTextColor(1, 1, 1, 1)
    row:Hide()
    return row
end

------------------------------------------------------------
-- 條件規則的整條層級覆寫（透明度與數值文字色）。列是池化重用的：
-- 規則不成立要還原、換列也要還原（row 是我們自己的框，欄位可以寫）
------------------------------------------------------------
local function ClearRowOverrides(row)
    if not row.condApplied then return end
    row:SetAlpha(1)
    row.text:SetTextColor(1, 1, 1, 1)
    row.condApplied = nil
    row.condAlpha = nil
end
R.ClearRowOverrides = ClearRowOverrides

local function ApplyRowOverrides(row, ov)
    if not ov then
        ClearRowOverrides(row)
        return
    end
    local a = (type(ov.alpha) == "number") and ov.alpha or 1
    if row.condAlpha ~= a then
        row:SetAlpha(a)
        row.condAlpha = a
    end
    local tc = RC.ValidColor(ov.tagColor)
    if tc then row.text:SetTextColor(tc.r, tc.g, tc.b, tc.a or 1) else row.text:SetTextColor(1, 1, 1, 1) end
    row.condApplied = true
end
R.ApplyRowOverrides = ApplyRowOverrides

-- 背景（空的那截）的玩家設定（玩家回報 2026-10-03：以前只能換成空材質才透明）：
--   bgAlpha   背景的不透明度，**絕對值**（1 ＝ 不透明、0 ＝ 全透明、預設 0.6；使用者 2026-10-15 指定，v9 前是倍率）。
--             所有底色（自動推的、自訂的、條件規則的 bgColor、征戰聖擊的 backColor）一律用這個 alpha，顏色各走各的
--   bgCustom＋bgColor  換掉「自動推的」底色（點數型的暗灰、連續條的主色 × 0.25）；條件規則命中時規則優先
local function BgAlpha(cfg)
    local a = tonumber(type(cfg) == "table" and cfg.bgAlpha) or 0.6
    if a < 0 then a = 0 elseif a > 1 then a = 1 end
    return a
end
R.BgAlpha = BgAlpha

local function BgCustom(cfg)
    if type(cfg) ~= "table" or not cfg.bgCustom then return nil end
    return RC.ValidColor(cfg.bgColor)
end
R.BgCustom = BgCustom

-- 「未填滿」的顏色（點數型）：整條層級規則的 bgColor 命中時取代暗色 → 色表, alpha
local function DimColor(barOv, cfg)
    local m = BgAlpha(cfg)
    if barOv then
        local bc = RC.ValidColor(barOv.bgColor)
        if bc then return bc, m end
    end
    local cc = BgCustom(cfg)
    if cc then return cc, m end
    return DIM, m
end
R.DimColor = DimColor

-- 同上，給 AuraBar 的 geom.dim（{ r, g, b, a } 陣列）
function R.DimArray(cfg)
    local c, a = DimColor(nil, cfg)
    return { c.r, c.g, c.b, a }
end

-- 連續條的背景：規則 bgColor ＞ 自訂背景色 ＞ 主色 × 0.25；alpha ＝ bgAlpha
local function PaintBarBG(row, cfg, barOv, fc)
    local m = BgAlpha(cfg)
    local bgc = barOv and RC.ValidColor(barOv.bgColor)
    if bgc then
        row.barBG:SetVertexColor(bgc.r, bgc.g, bgc.b, m)
        return
    end
    local cc = BgCustom(cfg)
    if cc then
        row.barBG:SetVertexColor(cc.r, cc.g, cc.b, m)
    else
        row.barBG:SetVertexColor(fc.r * 0.25, fc.g * 0.25, fc.b * 0.25, m)
    end
end
R.PaintBarBG = PaintBarBG

------------------------------------------------------------
-- 版面
------------------------------------------------------------
-- panelKey：寬 0 跟著哪個面板的錨定目標（nil ＝ 資源條；分段資源條傳自己的 key；false ＝ 一律核心技能）
function R.Width(cfg, panelKey)
    cfg = cfg or Cfg() or {}
    local w = tonumber(cfg.width) or 0
    if w <= 0 then
        w = ns.Bars and ns.Bars.AutoWidth and ns.Bars.AutoWidth(panelKey == nil and "resources" or panelKey or nil) or 0
        if w <= 0 then w = 200 end
    end
    return w
end

local function RowHeight(cfg) return tonumber(type(cfg) == "table" and cfg.rowHeight) or 8 end

-- 背景（空的那截）的材質路徑：沒挑或「跟填充相同」就用填充那張（自訂格子也走這支）
function R.BgTexture(cfg)
    local v = type(cfg) == "table" and cfg.bgTexture
    if type(v) ~= "string" or v == "" or v == ns.Media.INHERIT then
        return ns.Media.Texture(type(cfg) == "table" and cfg.texture or nil)
    end
    return ns.Media.Texture(v)
end
R.RowHeight = RowHeight

------------------------------------------------------------
-- 每種資源自己的外觀（resources.style[key]；設定頁每一列「設定…」視窗裡那一節，Options/ResourceSettings.lua）
--
--   style[key] = { follow = true|false, texture, bgTexture, barAlpha, bgAlpha, bgCustom, bgColor, smooth, showText,
--                  textFont, textSize, textOutline, borderSize, borderColor, shadow, shadowSize, shadowAlpha }
--   follow 沒存 ＝ 跟（舊存檔沒有這張表 ⇒ 畫面一模一樣，不遷移）；跟著時其餘欄位不讀。
--
-- 不跟時，那一列的排版與更新（LayoutRow／UpdateRow 那一整串）讀 R.StyleFor 回的**代理表**：
-- 外觀欄位（STYLE_FIELDS）先查 style[key]、沒存的退回資源條的全域值；其他欄位（manaAbbrev、colors、conditions、
-- fillDirection、segmentSpacing…）一律照讀 cfg。
-- ⚠ 代理表只給引擎讀值：不存進 SV、不 pairs（Lua 5.1 沒有 __pairs，遍歷是空的）、不寫（寫就報錯）。
--   設定頁與匯出一律讀原表。每個 key 快取一張（cfg／style[key] 換了表就重建），R.Apply 時作廢
------------------------------------------------------------
local STYLE_FIELDS = { texture = true, bgTexture = true, barAlpha = true, smooth = true,
                       showText = true, textFont = true, textSize = true, textOutline = true,
                       bgAlpha = true, bgCustom = true, bgColor = true,
                       borderSize = true, borderColor = true,
                       shadow = true, shadowSize = true, shadowAlpha = true }
R.STYLE_FIELDS = STYLE_FIELDS

local function OwnStyle(cfg, key)
    local st = type(cfg) == "table" and cfg.style
    local s = type(st) == "table" and st[key]
    return type(s) == "table" and s or nil
end

-- 這一列的外觀跟不跟資源條（判準是 follow ~= false）
function R.StyleFollows(cfg, key)
    local own = OwnStyle(cfg, key)
    return not (own and own.follow == false)
end

local styleProxies = {}          -- [key] = { cfg, own, proxy }

local function ProxyWrite() error("MiliUI_CooldownManager: resource style proxy is read-only", 2) end

-- 不看 follow 的欄位：「長條上顯示數值」每一列各自存、沒存＝照全域（使用者 2026-10-03 指定）
local INDEPENDENT = { showText = true }
R.INDEPENDENT_FIELDS = INDEPENDENT

-- 版面（設定視窗「版面」節，使用者 2026-10-12 指定「跟外觀同一套：跟隨資源條的版面」）：style[key].followLayout 沒存＝跟
-- ⇒ 這幾欄一律讀全域、自己存的值留著不讀；followLayout == false 才讀自己的，沒存的退回全域。
--   segmentSpacing、fillDirection 是純量；textOffset 是 { x, y }——**逐欄位**退回全域（只存了 x 時 y 照全域），
--   代理表回一張合併過的表（每個 key 一張快取、每次讀都重填）。寬與列距不經代理表（Relayout 在列層讀：R.KeyWidth／R.KeyRowSpacing）
local LAYOUT_FIELDS = { segmentSpacing = true, fillDirection = true, textOffset = true, width = true, rowSpacing = true }
R.LAYOUT_FIELDS = LAYOUT_FIELDS

-- 這一列的版面跟不跟資源條（判準是 followLayout ~= false）
function R.LayoutFollows(cfg, key)
    local own = OwnStyle(cfg, key)
    return not (own and own.followLayout == false)
end

do  -- 主 chunk 貼著 200 個 local 的上限：這一段的幫手收在區塊裡
-- 要不要代理表：顯示數值存了、外觀不跟、版面不跟（跟著時自己存的版面值一律不讀 ⇒ 原表就對）
local function NeedsProxy(own)
    return own.showText ~= nil or own.follow == false or own.followLayout == false
end

local mergedOffsets = {}         -- [key] = { x, y }（代理表 textOffset 的合併結果，重用）

local function MergedOffset(key, own, cfg)
    local o, g = own.textOffset, cfg.textOffset
    if type(o) ~= "table" then return g end
    if type(g) ~= "table" then g = nil end
    local m = mergedOffsets[key]
    if not m then m = {}; mergedOffsets[key] = m end
    local x, y = o.x, o.y
    if x == nil and g then x = g.x end
    if y == nil and g then y = g.y end
    m.x, m.y = x, y
    return m
end

function R.StyleFor(cfg, key)
    local own = OwnStyle(cfg, key)
    if not own then return cfg end
    if not NeedsProxy(own) then return cfg end
    local hit = styleProxies[key]
    if hit and hit.cfg == cfg and hit.own == own then return hit.proxy end
    local proxy = setmetatable({}, {
        __index = function(_, k)
            local layoutOwn = own.followLayout == false
            if k == "textOffset" then
                if layoutOwn then return MergedOffset(key, own, cfg) end
                return cfg.textOffset
            end
            if INDEPENDENT[k] or (STYLE_FIELDS[k] and own.follow == false) or (LAYOUT_FIELDS[k] and layoutOwn) then
                local v = own[k]
                if v ~= nil then return v end
            end
            return cfg[k]
        end,
        __newindex = ProxyWrite,
    })
    styleProxies[key] = { cfg = cfg, own = own, proxy = proxy }
    return proxy
end
end

-- 這一列自己的寬（實體像素；版面不跟、而且 style[key].width > 0 才算；0／沒存／跟著 ＝ 跟資源條 ⇒ nil）
function R.KeyWidth(cfg, key)
    local own = OwnStyle(cfg, key)
    if not (own and own.followLayout == false) then return nil end
    local w = tonumber(own.width)
    if w and w > 0 then return w end
    return nil
end

-- 這一列與上一列的間距（版面不跟時讀 style[key].rowSpacing，沒存／跟著 ＝ 資源條的列距）
function R.KeyRowSpacing(cfg, key)
    local own = OwnStyle(cfg, key)
    if own and own.followLayout == false then
        local v = tonumber(own.rowSpacing)
        if v ~= nil then return v end
    end
    return tonumber(type(cfg) == "table" and cfg.rowSpacing) or 1
end

function R.InvalidateStyles()
    for k in pairs(styleProxies) do styleProxies[k] = nil end
end

-- 一列的高度：resources.heights[key]（每種資源設定視窗的「高」，所有專精共用，跟 order 一樣）。
-- 沒設過的退回舊的共用值：征戰聖擊 crusadingHeight（預設 4）、其他 rowHeight（預設 14）——
-- 這兩個欄位不再有控件，留著當起始值，舊存檔不用遷移
R.HEIGHT_MIN, R.HEIGHT_MAX = 1, 30
function R.KeyRowHeight(cfg, key)
    local t = type(cfg) == "table" and cfg.heights
    local h = type(t) == "table" and tonumber(t[key])
    if h then return h end
    local def = R.RESOURCES[key]
    if def and def.crusading then
        return tonumber(type(cfg) == "table" and cfg.crusadingHeight) or 4
    end
    return RowHeight(cfg)
end

function R.SetKeyHeight(cfg, key, v)
    if type(cfg) ~= "table" or type(key) ~= "string" then return end
    v = math.floor((tonumber(v) or R.KeyRowHeight(cfg, key)) + 0.5)
    v = math.max(R.HEIGHT_MIN, math.min(R.HEIGHT_MAX, v))
    if type(cfg.heights) ~= "table" then cfg.heights = {} end
    cfg.heights[key] = v
end

-- 征戰聖擊的填充：elapsed 已揮的時間長出來（預設）／remaining 剩餘時間縮短
function R.CrusadingFill(cfg)
    local v = type(cfg) == "table" and cfg.crusadingFill
    if v == "remaining" then return v end
    return "elapsed"
end

-- 吸收盾列的零件（懶建）：裁切框（跟列一樣大）＋裡面一條寬 W / cap 的 StatusBar
local function EnsureAbsorb(row)
    if row.absorbClip then return end
    local clip = CreateFrame("Frame", nil, row)
    clip:SetAllPoints(row)
    clip:SetClipsChildren(true)
    local bar = CreateFrame("StatusBar", nil, clip)
    bar:SetStatusBarTexture(SOLID)
    NoSnap(bar)
    row.absorbClip, row.absorbBar = clip, bar
end

local function HideAbsorb(row)
    if row.absorbClip then row.absorbClip:Hide() end
end

local function OnAuraRegen() R.Mark(true) end

-- 引擎寫層數的列。回傳 true ＝ 容器就緒（這一列交給引擎）；false ＝ 退回明文畫法
------------------------------------------------------------
-- 每層刻度線（def.castTimers，目前只有鐵鬃；推算在 Modules/CastStacks.lua）
--
-- 鐵鬃畫成一條剩餘時間條（auraTimer：引擎用光環自己的到期時間＝最晚那層，刷新、延長都對）＋中間的層數
--（引擎寫，永遠對）＋**每一層一根刻度線**（比照 YHUD／EllesmereUI）：位置＝那一層剩餘時間 ／ 那一層總時間，
-- 隨時間往條的起點移動，到期消失。刻度線依施放推算（Lua 讀不到每層的時間），天賦多疊的層沒有線。
-- 刻度線畫在列上自己的一層框（引擎填色之上、裝飾與文字之下），有層時才跑 OnUpdate，沒有就停。
-- cfg.castTimers == false 時不畫線
------------------------------------------------------------
local castSorted = {}

local function TickUpdate(frame)
    local row = frame.row
    local CS = ns.CastStacks
    local now = GetTime()
    local list = CS and CS.Sorted(now, castSorted) or castSorted
    local W, tw = row.tkW or 0, row.tkTW or 1
    local ticks = row.tk
    for i, e in ipairs(list) do
        local t = ticks[i]
        if not t then
            t = NoSnap(frame:CreateTexture(nil, "OVERLAY", nil, 7))
            t:SetTexture(SOLID)
            ticks[i] = t
        end
        local frac = e.dur > 0 and (e.expire - now) / e.dur or 0
        if frac < 0 then frac = 0 elseif frac > 1 then frac = 1 end
        local x = frac * W
        if x > W - tw then x = W - tw end
        if x < 0 then x = 0 end
        t:SetVertexColor(1, 1, 1, 0.9)
        t:SetSize(tw, row.tkH or 1)
        t:ClearAllPoints()
        if row.tkRev then
            t:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -x, 0)
        else
            t:SetPoint("TOPLEFT", frame, "TOPLEFT", x, 0)
        end
        t:Show()
    end
    for i = #list + 1, #ticks do ticks[i]:Hide() end
    if #list == 0 then frame:SetScript("OnUpdate", nil) end
end

local function StartTicks(row)
    if row and row.tkOn and row.tkFrame then
        row.tkFrame:SetScript("OnUpdate", TickUpdate)
        TickUpdate(row.tkFrame)
    end
end

local function HideTicks(row)
    row.tkOn = false
    if row.tkFrame then
        row.tkFrame:SetScript("OnUpdate", nil)
        row.tkFrame:Hide()
    end
end

local function LayoutTicks(row, W, H, reversed)
    if not row.tkFrame then
        local f = CreateFrame("Frame", nil, row)
        f:SetAllPoints(row)
        f.row = row
        row.tkFrame, row.tk = f, {}
    end
    row.tkFrame:SetFrameLevel((row:GetFrameLevel() or 1) + 6)
    row.tkFrame:Show()
    row.tkW, row.tkH, row.tkRev = W, H, reversed and true or false
    row.tkTW = ns.P.Pixel(2)
    row.tkOn = true
    StartTicks(row)
end

-- 剩餘時間條（與層數列選了秒數時）的秒數：低於這個秒數印一位小數（秘法靈魂 4 秒整段都有小數；黯黑力量剩 5 秒起）
local TIMER_DECIMALS_BELOW = 5

local function LayoutAuraBar(row, key, def, cfg, numSeg, W, H, reversed, tex)
    if not ns.AuraBar then return false end
    row.ab = row.ab or ns.AuraBar.New(row, OnAuraRegen)
    local gap = ns.P.Pixel(tonumber(cfg.segmentSpacing) or 1)
    local geom = {
        W = W, H = H, n = numSeg, gap = gap, segW = (W - gap * (numSeg - 1)) / numSeg, reversed = reversed,
        segments = true, dim = R.DimArray(cfg), px = R.DecorPx(cfg), edge = R.EdgeArray(cfg), bgTex = R.BgTexture(cfg),
        shadow = R.ShadowArray(cfg),
        instances = def.instances and true or nil,     -- 一顆光環一格：裝飾跟引擎的等分排版對齊、不貼像素（AuraBar.LayoutDecor）
    }
    -- 透明格距：格距 > 0 時填色貼圖掛遮罩把格距挖掉（AuraBar.MaskPlan），裝飾就不畫分隔
    local mask = (not def.instances and gap > 0) and { period = geom.segW + gap, gap = gap, pixel = ns.P.Pixel(1) } or nil
    geom.mask = mask ~= nil
    local cc = ResolveColor(cfg, key, "color")
    local count
    if cfg.showText and not def.instances then
        -- 文字交給引擎（層數 SetApplicationCount／秒數 SetDurationText）：字級換成實體像素，樣式進簽章
        local scale = UIParent:GetEffectiveScale()
        if not scale or scale <= 0 then scale = 1 end
        count = {
            font = ns.Media.Font(ns.Media.ElementFont(cfg.textFont, ns.Setting(nil, "font"))),
            size = (tonumber(cfg.textSize) or 10) * scale,
            outline = TextOutline(cfg), off = { R.TextOffset(cfg) },
            mode = R.AuraText(cfg, key),
            decimals = TIMER_DECIMALS_BELOW,
        }
    end
    local status = ns.AuraBar.Apply(row.ab, {
        kind = def.instances and "instances" or "applications",
        spellIDs = def.auras, max = numSeg, texture = tex, color = cc, alpha = tonumber(cfg.barAlpha) or 1,
        reversed = reversed, cell = def.instances and geom or nil, count = count,
        unit = def.unit, filter = def.filter, mask = mask,
    })
    row.engineStatus = status
    if status ~= "ready" then
        ns.AuraBar.HideContainer(row.ab)
        ns.AuraBar.HideRowDecor(row)
        return false
    end
    ns.AuraBar.RowDecor(row, geom, (row:GetFrameLevel() or 1) + 8)
    return true
end


-- 空條的底色：跟連續條同一套（主色 × 0.25、alpha 0.8）。out 給了就填進去（熱路徑上不配表）
function R.TimerDim(c, out)
    out = out or {}
    out[1], out[2], out[3], out[4] = c.r * 0.25, c.g * 0.25, c.b * 0.25, 0.8
    return out
end
local timerDimScratch = {}
R.timerDimScratch = timerDimScratch

-- 剩餘時間條的底色：有自己底色的列（征戰聖擊的 backColor，含 alpha）照它，其他照主色推
function R.TimerBack(cfg, key, cc, out)
    local colors = type(cfg) == "table" and type(cfg.colors) == "table" and cfg.colors
    local t = colors and type(colors[key]) == "table" and colors[key].backColor
    if type(t) == "table" and t.r then
        out = out or {}
        out[1], out[2], out[3], out[4] = t.r, t.g, t.b, tonumber(t.a) or 1
        return out
    end
    return R.TimerDim(cc, out)
end

-- 剩餘時間條「當背景畫」的底色：TimerBack 再套玩家的背景設定（自己有 backColor 的列顏色照它、alpha 照 bgAlpha）。
-- ⚠ 征戰聖擊「經過時間」模式拿 TimerBack 當**填充**色（PaintMirror），那裡照用 TimerBack
function R.TimerBg(cfg, key, cc, out)
    out = R.TimerBack(cfg, key, cc, out)
    local colors = type(cfg) == "table" and type(cfg.colors) == "table" and cfg.colors
    local own = colors and type(colors[key]) == "table" and type(colors[key].backColor) == "table"
    local custom = not own and BgCustom(cfg)
    if custom then out[1], out[2], out[3] = custom.r, custom.g, custom.b end
    out[4] = BgAlpha(cfg)
    return out
end

-- 光環剩餘時間條。回傳 true ＝ 容器就緒（這一列交給引擎）；false ＝ 先畫空條
local function LayoutAuraTimer(row, key, def, cfg, W, H, reversed, tex)
    if not ns.AuraBar then return false end
    row.ab = row.ab or ns.AuraBar.New(row, OnAuraRegen)
    local cc = ResolveColor(cfg, key, "color")
    local text
    if cfg.showText then
        -- 字級換成實體像素（同 row.text 的 SetPixelFont）：按鈕子樹裡的 FontString 忽略父層縮放
        local scale = UIParent:GetEffectiveScale()
        if not scale or scale <= 0 then scale = 1 end
        text = {
            font = ns.Media.Font(ns.Media.ElementFont(cfg.textFont, ns.Setting(nil, "font"))),
            size = (tonumber(cfg.textSize) or 10) * scale,
            outline = TextOutline(cfg), off = { R.TextOffset(cfg) },
            decimals = TIMER_DECIMALS_BELOW,
        }
    end
    local count
    if def.castTimers then
        -- 鐵鬃：不印秒數；中間的層數是自己的勾選（castCount），引擎寫
        text = nil
        if cfg.castCount ~= false then
            local scale = UIParent:GetEffectiveScale()
            if not scale or scale <= 0 then scale = 1 end
            count = {
                font = ns.Media.Font(ns.Media.ElementFont(cfg.textFont, ns.Setting(nil, "font"))),
                size = (tonumber(cfg.textSize) or 10) * scale,
                outline = TextOutline(cfg), mode = "stacks", off = { R.TextOffset(cfg) },
            }
        end
    end
    if text and def.gcdText and R.ArcaneSoulText(cfg) == "gcd" then
        -- 剩幾個 GCD：格式器只能在 initializeFrame 給 ⇒ GCD 長度（明文、0.05 秒一格）進簽章，變了換容器
        text.gcd = R.ReadGcd()
        text.last = L["Last"]
    end
    local status = ns.AuraBar.Apply(row.ab, {
        kind = "duration", spellIDs = def.auras, max = 1, texture = tex, color = cc,
        alpha = tonumber(cfg.barAlpha) or 1, reversed = reversed, text = text, count = count,
        unit = def.unit, filter = def.filter,
    })
    row.gcdUsed = text and text.gcd or nil
    row.engineStatus = status
    if status ~= "ready" then
        ns.AuraBar.HideContainer(row.ab)
        ns.AuraBar.HideRowDecor(row)
        if row.tkFrame then HideTicks(row) end
        return false
    end
    -- 空條（暗底＋1px 黑邊）畫在列上：光環不在時按鈕藏著，看到的就是這個
    ns.AuraBar.RowDecor(row, {
        W = W, H = H, n = 1, gap = 0, segW = W, reversed = reversed, segments = false,
        dim = R.TimerBg(cfg, key, cc), px = R.DecorPx(cfg), edge = R.EdgeArray(cfg), bgTex = R.BgTexture(cfg),
        shadow = R.ShadowArray(cfg),
    }, (row:GetFrameLevel() or 1) + 8)
    if def.castTimers and cfg.castTimers ~= false then
        LayoutTicks(row, W, H, reversed)
    elseif row.tkFrame then
        HideTicks(row)
    end
    return true
end

-- 百分比條（無視苦痛）：單格容器、層數欄位當 0～appMax 的條值，連續條（裝飾不分格）。
-- 回傳 true ＝ 容器就緒；false ＝ 退回吸收盾總量（absorbBar）
local function LayoutAuraPct(row, key, def, cfg, W, H, reversed, tex)
    if not ns.AuraBar then return false end
    row.ab = row.ab or ns.AuraBar.New(row, OnAuraRegen)
    local cc = ResolveColor(cfg, key, "color")
    local count
    if cfg.showText then
        -- 層數走 SetApplicationCount（不給格式器：引擎拿格式器處理秘密層數會整顆容器壞掉），後面接自己的「%」
        local scale = UIParent:GetEffectiveScale()
        if not scale or scale <= 0 then scale = 1 end
        count = {
            font = ns.Media.Font(ns.Media.ElementFont(cfg.textFont, ns.Setting(nil, "font"))),
            size = (tonumber(cfg.textSize) or 10) * scale,
            outline = TextOutline(cfg), off = { R.TextOffset(cfg) },
            suffix = "%",
        }
    end
    local status = ns.AuraBar.Apply(row.ab, {
        kind = "applications", spellIDs = def.auras, max = tonumber(def.appMax) or 100, texture = tex, color = cc,
        alpha = tonumber(cfg.barAlpha) or 1, reversed = reversed, count = count,
        -- 盾的剩餘時間：條底部一條細線（引擎畫，含暴力爆發之類的刷新）；高度約列高的 1/5、至少 1 實體像素
        strip = cfg.ipDuration ~= false and {
            h = math.max(ns.P.Pixel(1), math.floor(H / 5 + 0.5)), r = 1, g = 1, b = 1, a = 0.85 } or nil,
    })
    row.engineStatus = status
    if status ~= "ready" then
        ns.AuraBar.HideContainer(row.ab)
        ns.AuraBar.HideRowDecor(row)
        return false
    end
    -- 空條（暗底＋1px 黑邊、不分格）畫在列上：增益不在時按鈕藏著，看到的就是這個
    ns.AuraBar.RowDecor(row, {
        W = W, H = H, n = 1, gap = 0, segW = W, reversed = reversed, segments = false,
        dim = R.TimerBg(cfg, key, cc), px = R.DecorPx(cfg), edge = R.EdgeArray(cfg), bgTex = R.BgTexture(cfg),
        shadow = R.ShadowArray(cfg),
    }, (row:GetFrameLevel() or 1) + 8)
    return true
end

-- 摺疊的上層（一格一顆，錨在列上、位置跟底層同一格；層級比底層高、自帶黑邊）
local function LayoutFold(row, on, numSeg, W, H, cfg, tex, reversed)
    local bt, bc = R.BorderSize(cfg), R.BorderColor(cfg)
    if not on then
        if row.overs then for _, o in ipairs(row.overs) do o:Hide() end end
        row.folded = false
        return
    end
    row.overs = row.overs or {}
    local lv = row:GetFrameLevel() or 1
    for i = 1, numSeg do
        local o = row.overs[i]
        if not o then
            o = CreateFrame("StatusBar", nil, row)
            o:SetStatusBarTexture(SOLID)
            NoSnap(o)                -- 填充跟自己的 1px 邊相接：不貼齊
            o.edges = Edges(o)
            row.overs[i] = o
        end
        local x, segW = R.SegCell(W, numSeg, cfg.segmentSpacing, i, bt)
        PaintEdges(o.edges, bt, bc)
        o:SetSize(segW, H)
        o:ClearAllPoints()
        if reversed then
            o:SetPoint("TOPRIGHT", row, "TOPRIGHT", -x, 0)
        else
            o:SetPoint("TOPLEFT", row, "TOPLEFT", x, 0)
        end
        o:SetFrameLevel(lv + 2)
        o:SetStatusBarTexture(tex)
        o:SetMinMaxValues(R.FoldRange(i, 2, numSeg))
        o:SetValue(0)
        o:Show()
    end
    for i = numSeg + 1, #row.overs do row.overs[i]:Hide() end
    row.folded = true
end

-- 數值文字的層級：要高過**隔壁列**所有東西 —— 引擎畫的列（無視苦痛／鐵鬃）裝飾在 +8、引擎層數字約 +15，
-- 列高比字矮時字會凸出到隔壁列上，層級不夠就被隔壁的邊框壓住（2026-10-13 玩家回報：怒氣數字被無視苦痛的邊蓋掉）
local TEXT_LEVEL = 20

local function LayoutRow(row, key, cfg, numSeg, W, H)
    local def = R.RESOURCES[key]
    row:SetSize(W, H)
    row.textFrame:SetFrameLevel((row:GetFrameLevel() or 1) + TEXT_LEVEL)
    -- 換列：上一個資源的條件殘留一律先還原
    row:SetAlpha(1)
    row.condAlpha, row.condApplied = nil, nil
    row.text:SetTextColor(1, 1, 1, 1)
    row.gcdUsed = nil

    local reversed = ns.FillReversed(cfg)
    local tex = ns.Media.Texture(cfg.texture)
    local showText = cfg.showText and true or false
    if def.fill == "rune" then showText = showText and R.RuneText(cfg) == "count" end
    ns.Media.SetPixelFont(row.text, tonumber(cfg.textSize) or 10, TextOutline(cfg), ns.Media.ElementFont(cfg.textFont, ns.Setting(nil, "font")))
    row.text:ClearAllPoints()
    row.text:SetPoint("CENTER", row.textFrame, "CENTER", R.TextOffset(cfg))
    row.text:SetText("")

    -- 這一列實際的畫法：容器沒好時 auraBar 退回 pip（明文層數）、auraTimer 退回空條
    local mode = def.mode
    if mode == "auraBar" then
        mode = R.DrawMode(mode, LayoutAuraBar(row, key, def, cfg, numSeg, W, H, reversed, tex))
    elseif mode == "auraTimer" then
        mode = R.DrawMode(mode, LayoutAuraTimer(row, key, def, cfg, W, H, reversed, tex))
    elseif mode == "auraPct" then
        mode = R.DrawMode(mode, LayoutAuraPct(row, key, def, cfg, W, H, reversed, tex))
    else
        if row.ab and ns.AuraBar then ns.AuraBar.HideContainer(row.ab) end
        if ns.AuraBar then ns.AuraBar.HideRowDecor(row) end
    end
    -- 退回點數型時照點數型的格數上限
    if mode == "pip" and numSeg and numSeg > MAX_SEGMENTS then
        numSeg = MAX_SEGMENTS
        row.numSeg = numSeg
    end
    row.mode = mode
    -- 引擎寫的列沒有 Lua 讀得到的數字：不印數值文字（剩餘時間條的秒數在按鈕子樹裡，引擎印）
    row.text:SetShown(showText and mode ~= "engine" and mode ~= "timerIdle" and not def.noText)

    local isPip = mode == "pip" and numSeg and numSeg > 0
    local isBar = mode == "bar" or mode == "absorbBar" or mode == "timerIdle" or mode == "mirror"
    row.barBG:SetShown(isBar)
    row.bar:SetShown(isBar)
    if isBar then PaintEdges(row.barEdges, R.BorderSize(cfg), R.BorderColor(cfg)) end
    -- 邊緣陰影（Core/Shape.lua）：條型整列一圈、點數型每格一圈；陰影框都是列的子框（層級＝列 − 1，壓在鄰列底下）。
    -- 用不到的那幾圈這裡收掉（格子藏了，掛在列上的陰影不會跟著藏）；引擎列的陰影在 AuraBar 的裝飾裡
    do
        local SH = ns.Shape
        if SH then
            local spx, sa = R.ShadowOf(cfg)
            SH.EdgeShadow(row, row, isBar and spx or nil, sa)
            for i = 1, MAX_SEGMENTS do
                SH.EdgeShadow(row, row.segs[i], (isPip and i <= numSeg) and spx or nil, sa)
            end
        end
    end
    if mode ~= "absorbBar" then HideAbsorb(row) end

    LayoutFold(row, isPip and R.Folded(cfg, key) or false, numSeg, W, H, cfg, tex, reversed)

    if not isPip then
        for i = 1, MAX_SEGMENTS do row.segs[i]:Hide() end
        if not isBar then return end
        row.bar:SetStatusBarTexture(tex)
        row.bar:SetReverseFill(reversed)
        row.barBG:SetTexture(R.BgTexture(cfg))
        if mode == "mirror" then
            R.PaintMirror(row, key, cfg, reversed)
            return
        end
        if mode == "absorbBar" then
            -- 列本身的 bar 只剩邊框（值 0），真正的填色在裁切框裡那條寬的
            EnsureAbsorb(row)
            local lv = row:GetFrameLevel() or 1
            row.absorbClip:SetFrameLevel(lv + 1)
            row.bar:SetFrameLevel(lv + 2)
            row.bar:SetMinMaxValues(0, 1)
            row.bar:SetValue(0)
            local ab = row.absorbBar
            ab:SetStatusBarTexture(tex)
            ab:SetReverseFill(reversed)
            ab:ClearAllPoints()
            -- 寬度是自己的設定算出來的明文：W / cap（上限＝最大生命的 cap 倍 ⇒ 只看得到前 cap）
            local cap = tonumber(def.cap) or 1
            ab:SetSize(W / cap, H)
            if reversed then
                ab:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
            else
                ab:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
            end
            row.absorbClip:Show()
        end
        return
    end

    -- 格寬是除出來的小數 → 對齊實體像素；每格直接錨在列上（不串在前一格）
    local isRune = def.fill == "rune" and cfg.showText and R.RuneText(cfg) == "countdown"
    local bt, bc = R.BorderSize(cfg), R.BorderColor(cfg)
    local bgTex = R.BgTexture(cfg)
    for i = 1, numSeg do
        local seg = row.segs[i]
        local x, segW = R.SegCell(W, numSeg, cfg.segmentSpacing, i, bt)
        PaintEdges(seg.edges, bt, bc)
        seg:SetSize(segW, H)
        seg:ClearAllPoints()
        -- 從右到左：第 1 格在最右邊
        if reversed then
            seg:SetPoint("TOPRIGHT", row, "TOPRIGHT", -x, 0)
        else
            seg:SetPoint("TOPLEFT", row, "TOPLEFT", x, 0)
        end
        seg:SetStatusBarTexture(tex)
        seg.bg:SetTexture(bgTex)
        seg:SetMinMaxValues(i - 1, i)
        LayoutRuneTimer(seg, isRune, cfg)
        seg:Show()
    end
    for i = numSeg + 1, MAX_SEGMENTS do row.segs[i]:Hide() end
end

------------------------------------------------------------
-- 重排與重畫
------------------------------------------------------------
local shownCount = 0
local SyncUnitEvents             -- 定義在事件那一段（前置宣告；Relayout 結尾與整條關掉時叫）
local healthShown = false        -- 畫面上有沒有血量列（沒有的職業不必為 UNIT_HEALTH 重畫）
local laidOut = false            -- 排過版了沒（false ＝ 下一次 Update 一定重排）
local pendingRelayout = false    -- 戰鬥中面板是保護框（有 auraBar 的容器）、該重排的時候記在這裡

-- auraBar 的 AuraContainer 讓列與面板變成保護框：戰鬥中不能 SetSize／SetPoint／Show／Hide ⇒ 記旗標、脫戰補
local function MustDefer()
    return InCombatLockdown() and root ~= nil and ns.IsProtectedFrame and ns.IsProtectedFrame(root)
end

local function OnRegenRelayout()
    ns.Events.Unregister("PLAYER_REGEN_ENABLED", "resources_relayout")
    if pendingRelayout then
        pendingRelayout = false
        R.Mark(true)
    end
end

local function DeferRelayout()
    pendingRelayout = true
    ns.Events.Register("PLAYER_REGEN_ENABLED", "resources_relayout", OnRegenRelayout)
end

------------------------------------------------------------
-- 獨立擺放
------------------------------------------------------------
-- 這一列有沒有拆出去（只看開關；這個專精有沒有這一列是排版的事）
function R.IsDetached(cfg, key)
    local d = type(cfg) == "table" and cfg.detached
    local t = type(d) == "table" and d[key]
    return type(t) == "table" and t.on == true
end

-- 建表（只有那一列的「錨定」鈕會叫；讀取路徑不建）：預設見 DB.NewDetached，開關維持關
function R.EnsureDetached(key)
    local cfg = Cfg()
    if not (cfg and type(key) == "string") then return nil end
    if type(cfg.detached) ~= "table" then cfg.detached = {} end
    local t = cfg.detached[key]
    if type(t) ~= "table" then
        t = ns.DB.NewDetached(cfg.rowSpacing)
        cfg.detached[key] = t
    end
    return t
end

-- 純函式：哪幾列留在主面板、各自的 y、主面板總高。
--   list 實際要畫的列；isDetached(key) 拆出去的不算；heightOf(key)／spacingOf(key) 列高、跟上一列的間距
-- 間距只加在「主面板裡的上一列」與這一列之間：拆走中間一列，下面的往上補、間距不多一份。
-- 回 main（陣列）, yOf（key → y）, total。out／yOf 可傳 scratch 表（就地清空重填）
function R.MainRows(list, isDetached, heightOf, spacingOf, out, yOf)
    out, yOf = out or {}, yOf or {}
    for i = #out, 1, -1 do out[i] = nil end
    for k in pairs(yOf) do yOf[k] = nil end
    local y = 0
    for _, key in ipairs(list) do
        if not isDetached(key) then
            if #out > 0 then y = y + (tonumber(spacingOf(key)) or 0) end
            out[#out + 1] = key
            yOf[key] = y
            y = y + (tonumber(heightOf(key)) or 0)
        end
    end
    return out, yOf, y
end

-- 狀態集中一張表（這個檔的主 chunk 貼著 200 個 local 的上限）：
--   live    key → true：上一次排版拆出去、畫在自己面板上的列（面板的閒置判斷讀這張）
--   panels  key → 容器（登記過的 "res:<key>"；框刪不掉，登記一次就一直在）
--   want／main／ys  Relayout 的 scratch
-- （表掛在 R.det 上、不另開 local；R.detachedLive 給 /mcdm debug、測試用）
R.det = { live = {}, panels = {}, want = {}, main = {}, ys = {}, none = {} }
R.detachedLive = R.det.live

do
    local DET = R.det
    -- 第一次拆出來才登記（RegisterPanel 當場套結構：live 要先寫好，才不會被當成閒置）
    local function Panel(key)
        local c = DET.panels[key]
        if c then return c, false end
        c = ns.Bars.RegisterPanel(ns.DB.DETACHED_PREFIX .. key, {
            anchorPoint = "CENTER",
            rank        = 1.1,                -- 排開：緊貼資源條（1），在自訂列（1.2）裡面
            minSize     = function()
                local cfg = Cfg() or {}
                return R.KeyWidth(cfg, key) or R.Width(cfg), R.KeyRowHeight(cfg, key)
            end,
            idle        = function() return not DET.live[key] end,
        })
        DET.panels[key] = c
        return c, true
    end

    -- 這一輪拆出去的集合（want：key → true）跟上一輪比：變了的那幾個面板請 Bars 重套結構（出現／收起來、排開重算）。
    -- 回傳有沒有變
    function R.SyncDetached(want)
        local live, changed = DET.live, false
        for key in pairs(live) do
            if not want[key] then
                live[key] = nil
                changed = true
                if DET.panels[key] then ns.Bars.ApplyPanelStructure(ns.DB.DETACHED_PREFIX .. key) end
            end
        end
        for key in pairs(want) do
            if not live[key] then
                live[key] = true
                changed = true
                local _, fresh = Panel(key)
                if not fresh then ns.Bars.ApplyPanelStructure(ns.DB.DETACHED_PREFIX .. key) end
            end
        end
        if changed and ns.Fire then ns.Fire("DetachedChanged") end
        return changed
    end
end

-- W ＝ 資源條的寬（實體像素）。每一列可以有自己的寬（R.KeyWidth）與跟上一列的間距（R.KeyRowSpacing）：
-- 面板寬＝最寬的那一列，窄的列置中（位移貼整數像素）；列從面板頂端用累計的 y 擺，不互相鏈結
local function Relayout(cfg, list, W)
    -- 拆出去的列先定案（面板的閒置判斷讀 R.det.live，登記／重套結構要在擺列之前）
    local DET = R.det
    local want, live = DET.want, DET.live
    for k in pairs(want) do want[k] = nil end
    for _, key in ipairs(list) do
        if R.IsDetached(cfg, key) then want[key] = true end
    end
    R.SyncDetached(want)
    local P = ns.P
    local main, yOf, total = R.MainRows(list, function(k) return live[k] end,
        function(k) return P.Scale(R.KeyRowHeight(cfg, k)) end,
        function(k) return P.Scale(R.KeyRowSpacing(cfg, k)) end, DET.main, DET.ys)
    local panelPx = W
    for _, key in ipairs(main) do
        local w = R.KeyWidth(cfg, key)
        if w and w > panelPx then panelPx = w end
    end
    healthShown = false
    local metaShown = false
    local DM = ns.DevourerMeta
    for i, key in ipairs(list) do
        local row = rows[i]
        if not row then
            row = MakeRow(root)
            rows[i] = row
        end
        row.key = key
        row.numSeg = SegmentsFor(key)
        if R.RESOURCES[key] and R.RESOURCES[key].health then
            healthShown = true
            R.PrepareHealthCurve(cfg)
        end
        local rowPx = R.KeyWidth(cfg, key) or W
        local H = ns.P.Scale(R.KeyRowHeight(cfg, key))
        row:ClearAllPoints()
        if live[key] then
            -- 獨立擺放：parent 照舊是 root，只錨到自己的面板；面板大小＝這一列
            row:SetPoint("TOPLEFT", DET.panels[key], "TOPLEFT", 0, 0)
            ns.Bars.SetPanelSize(ns.DB.DETACHED_PREFIX .. key, ns.P.Scale(rowPx), H)
        else
            local xPx = math.floor((panelPx - rowPx) / 2 + 0.5)
            row:SetPoint("TOPLEFT", root, "TOPLEFT", ns.P.Scale(xPx), -(yOf[key] or 0))
        end
        row:Show()
        -- 外觀與版面：這一列自己的（代理表，見 R.StyleFor）；錨定照全域
        LayoutRow(row, key, R.StyleFor(cfg, key), row.numSeg, ns.P.Scale(rowPx), H)
        if row.ab and ns.AuraBar then ns.AuraBar.KickPending(row.ab) end
        -- 噬靈魂碎片列上的虛空化身計時／崩陷之星計數（池化的列換成別的資源就收起來）
        if DM and R.RESOURCES[key] and R.RESOURCES[key].meta then
            DM.Layout(row, R.StyleFor(cfg, key), cfg)
            metaShown = true
        elseif DM and row.metaTime then
            DM.Hide(row)
        end
    end
    -- 沒有靈魂碎片列了（換專精、列被關）：狀態整個重設
    if DM and not metaShown then DM.Reset() end
    for i = #list + 1, #rows do
        local row = rows[i]
        row:Hide()
        row.key, row.mode = nil, nil
        if row.ab and ns.AuraBar then ns.AuraBar.HideContainer(row.ab) end
    end
    shownCount = #list
    R.SetMirrorDriver(rows, shownCount, cfg)
    SyncUnitEvents()
    -- 一列都不剩（沒有列、或全部拆走）：高度 1（不能是 0，見 Core/Bars.lua 收合那段）
    ns.Bars.SetPanelSize("resources", ns.P.Scale(panelPx), #main > 0 and total or 1)
end

-- 戰鬥中該重排卻重排不了（MustDefer：有 auraBar 容器的面板是保護框）時，引擎寫的列只把裝飾的顏色就地重上：
-- 背景不透明度／自訂底色／背景材質／邊框色這幾樣改了當場看得到，不必等脫戰（點數型的列在 UpdateRow 每次都重上色，
-- 引擎列的暗底只在 Layout 時上，戰鬥中改設定會一直停在舊的灰底 —— 玩家回報 2026-10-15 惡魔之核）。
-- 尺寸、格數、填色（在容器簽章裡）照舊等脫戰的重排
function R.RecolorDeferred(cfg)
    if not ns.AuraBar then return end
    for i = 1, shownCount do
        local row = rows[i]
        local key = row and row.key
        local def = key and R.RESOURCES[key]
        if def and row.abDecor and row.mode == "engine" then
            local sc = R.StyleFor(cfg, key)
            local dim
            if def.mode == "auraBar" then
                dim = R.DimArray(sc)
            else
                dim = R.TimerBg(sc, key, ResolveColor(sc, key, "color"))
            end
            ns.AuraBar.RecolorRowDecor(row, dim, R.EdgeArray(sc), R.BgTexture(sc))
        end
    end
end

-- force：重排（清單、格數、尺寸設定、寬度都可能變了）。不給 ＝ 只重畫值（能量事件走這條，
-- 熱路徑上不重算清單、不配任何表或字串）
function R.Update(force)
    if not root then return end
    local cfg = Cfg()
    if not cfg or cfg.enabled == false then
        if MustDefer() then DeferRelayout() return end
        for i = 1, #rows do
            rows[i]:Hide()
            if rows[i].ab and ns.AuraBar then ns.AuraBar.HideContainer(rows[i].ab) end
        end
        shownCount = 0
        healthShown = false
        laidOut = false
        R.SyncDetached(R.det.none)       -- 拆出去的面板跟著收（閒置）
        if ns.DevourerMeta then ns.DevourerMeta.Reset() end
        R.SetMirrorDriver(rows, 0, cfg)
        SyncUnitEvents()
        return
    end
    if force or not laidOut then
        if MustDefer() then
            DeferRelayout()
            R.RecolorDeferred(cfg)
        else
            Relayout(cfg, ActiveRows(cfg), R.Width(cfg))
            laidOut = true
        end
    end
    for i = 1, shownCount do
        local ok, err = xpcall(R.UpdateRow, ns.ReportError, rows[i], cfg)
        if not ok then R.lastError = err end
    end
end

-- 符文回充的進度與秒數、精華的回充進度都沒有事件可等（RUNE_POWER_UPDATE 只在轉好／用掉時來，
-- 精華的回充中間沒有能量事件）：有格子在回充時開一個 0.1 秒的 ticker 只重畫這兩種列，
-- 全部回充好（或列不見了）就停
local TICKED_FILL = { rune = true, essence = true }
local rechargeTicker
local rechargeRearmed = false    -- 這一趟有沒有人說「還有格子在回充」

-- 虛空化身計時（噬滅）也搭這班：化身中、或還有「結束後保留」沒清時，每趟只重畫那兩段字（DM.Paint，
-- 整數秒變了才換字），不重畫整列。停止條件 ＝ 回充與化身計時都沒人要
local function RechargeTick()
    rechargeRearmed = false
    local cfg = Cfg()
    local busy = false
    if cfg and cfg.enabled ~= false then
        local DM = ns.DevourerMeta
        for i = 1, shownCount do
            local row = rows[i]
            local def = row.key and R.RESOURCES[row.key]
            if def and TICKED_FILL[def.fill] and row.mode == "pip" and row:IsShown() then
                busy = true
                local ok, err = xpcall(R.UpdateRow, ns.ReportError, row, cfg)
                if not ok then R.lastError = err end
            elseif def and def.meta and DM and row.metaTime and DM.NeedsTick(DM.state) then
                busy = true
                rechargeRearmed = true          -- 化身計時自己續班（DM.Paint 清掉過期的保留後下一趟就不續了）
                local ok, err = xpcall(DM.Paint, ns.ReportError, row)
                if not ok then R.lastError = err end
            end
        end
    end
    -- UpdatePipRow 在還有格子回充時會再呼叫 ArmTicker；這一趟沒人呼叫 ⇒ 全部好了
    if not busy or not rechargeRearmed then
        if rechargeTicker then rechargeTicker:Cancel() end
        rechargeTicker = nil
    end
end

function R.ArmTicker()
    rechargeRearmed = true
    if rechargeTicker or not (C_Timer and C_Timer.NewTicker) then return end
    rechargeTicker = C_Timer.NewTicker(0.1, RechargeTick)
end

-- 專精／型態／天賦／上限變動：清單與格數都可能變
function R.Reevaluate()
    R.Invalidate()
    chargedDirty = true
    R.Update(true)
end

------------------------------------------------------------
-- 事件：只標髒，下一幀做
------------------------------------------------------------
local dirtyReeval, dirtyValues, armed = false, false, false

local function Flush()
    armed = false
    local re, va = dirtyReeval, dirtyValues
    dirtyReeval, dirtyValues = false, false
    if re then
        R.Reevaluate()
    elseif va then
        R.valueFlushes = R.valueFlushes + 1
        R.Update(false)
    end
end

-- what：true ＝ 重算清單與重排；其他 ＝ 只重畫值
local function Mark(what)
    if what then
        dirtyReeval = true
    else
        dirtyValues = true
    end
    if not armed then
        armed = true
        ns.Defer(Flush)
    end
end
R.Mark = Mark

-- MAGE：冰刺；MONK：醉仙緩勁（減益每跳都會發 UNIT_AURA）
local AURA_DRIVEN_CLASSES = { SHAMAN = true, HUNTER = true, DEMONHUNTER = true, DRUID = true, MAGE = true, MONK = true }
-- 只重畫值的生命／吸收事件（醉仙緩勁的上限是最大生命、每跳扣血；無視苦痛看吸收量與最大生命）。
-- UNIT_HEALTH／UNIT_MAXHEALTH 每個職業都註冊（血量列）；這張表列的是「沒有血量列也要重畫」的
local HEALTH_EVENTS = {
    MONK    = { UNIT_HEALTH = true, UNIT_MAXHEALTH = true },
    WARRIOR = { UNIT_ABSORB_AMOUNT_CHANGED = true, UNIT_MAXHEALTH = true },
}
local CLASS_HEALTH = HEALTH_EVENTS[CLASS] or {}

local REEVAL_EVENTS = {
    UNIT_MAXPOWER = true, UNIT_DISPLAYPOWER = true, UPDATE_SHAPESHIFT_FORM = true,
    PLAYER_SPECIALIZATION_CHANGED = true, PLAYER_TALENT_UPDATE = true, TRAIT_CONFIG_UPDATED = true,
    PLAYER_ENTERING_WORLD = true, UNIT_ENTERED_VEHICLE = true, UNIT_EXITED_VEHICLE = true,
    SPELLS_CHANGED = true,
}

local evFrame

------------------------------------------------------------
-- 光環／生命事件依列動態註冊（效能修整 E3 #16a）
--
--   R.WantedEvents(keys, class [, out])   純函式：畫面上的列（資源 key 陣列）＋職業 → 要註冊的事件集合
--     UNIT_AURA                     職業在 AURA_DRIVEN_CLASSES（以前就只有這六個職業註冊）而且有列要吃它：
--                                   層數型（def.aura／def.auras）、施放次數型（def.cast：靈魂碎片）、醉仙緩勁
--                                   （def.stagger：減益每跳都發）、讀光環層數的取值（def.auraRead：噬靈魂碎片）、
--                                   野德的連擊點（滿溢之力畫在連擊點上，ChargedPoints）
--     UNIT_HEALTH                   血量列（def.health）、醉仙緩勁
--     UNIT_MAXHEALTH                血量列、醉仙緩勁、無視苦痛（def.absorb：上限是最大生命）
--     UNIT_ABSORB_AMOUNT_CHANGED    無視苦痛（以前只有戰士註冊，這一列只有戰士有）
--     UNIT_SPELLCAST_SUCCEEDED      噬靈魂碎片列（def.meta：崩陷之星計數，只有專精 1480 有這一列）
--   能量、符文、點數充能、急速照舊一次註冊。作廢點＝Relayout 結尾（Reevaluate、R.Apply、Bars 的 relayout 都經過它）
--   與整條關掉的那一支；戰鬥中重排延後時畫面上的列沒變，事件集合跟著不變
------------------------------------------------------------
local UNIT_EVENTS = { "UNIT_AURA", "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_ABSORB_AMOUNT_CHANGED", "UNIT_SPELLCAST_SUCCEEDED" }

function R.WantedEvents(keys, class, out)
    out = out or {}
    for k in pairs(out) do out[k] = nil end
    local auraClass = AURA_DRIVEN_CLASSES[class] == true
    for _, key in ipairs(keys or {}) do
        local def = R.RESOURCES[key]
        if def then
            if auraClass and (def.aura or def.auras or def.cast or def.stagger or def.auraRead
                or (key == "ComboPoints" and class == "DRUID")) then
                out.UNIT_AURA = true
            end
            if def.health or def.stagger then
                out.UNIT_HEALTH, out.UNIT_MAXHEALTH = true, true
            end
            if def.absorb then
                out.UNIT_MAXHEALTH, out.UNIT_ABSORB_AMOUNT_CHANGED = true, true
            end
            if def.meta or def.castTimers then out.UNIT_SPELLCAST_SUCCEEDED = true end
        end
    end
    return out
end

local unitEvOn = {}                  -- 事件 → true（現在註冊著）
local shownKeys, wantScratch = {}, {}
R.unitEvOn = unitEvOn                 -- /mcdm debug、測試用

SyncUnitEvents = function()
    if not evFrame then return end
    for i = #shownKeys, 1, -1 do shownKeys[i] = nil end
    for i = 1, shownCount do
        local row = rows[i]
        if row and row.key then shownKeys[#shownKeys + 1] = row.key end
    end
    local want = R.WantedEvents(shownKeys, CLASS, wantScratch)
    for _, ev in ipairs(UNIT_EVENTS) do
        if want[ev] and not unitEvOn[ev] then
            unitEvOn[ev] = true
            evFrame:RegisterUnitEvent(ev, "player")
        elseif not want[ev] and unitEvOn[ev] then
            unitEvOn[ev] = nil
            evFrame:UnregisterEvent(ev)
        end
    end
end

-- 每層刻度線：施放／重置後把畫面上這種列的 OnUpdate 叫起來（沒有層時自己停）
function R.RenderAllCastTimers()
    for i = 1, shownCount do
        local row = rows[i]
        if row and row.tkOn then StartTicks(row) end
    end
end

local function OnEvent(_, event, ...)
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        -- 崩陷之星計數：計數變了才重畫（施法很頻繁，別的法術不標髒）
        if ns.DevourerMeta and ns.DevourerMeta.OnSpellcast(...) then Mark(false) end
        -- 每層倒數（鐵鬃）：清單變了就重畫遮罩、排下一次到期
        local _, _, spellID = ...
        if ns.CastStacks and ns.CastStacks.OnSpellcast(spellID) then R.RenderAllCastTimers() end
        return
    end
    if event == "PLAYER_DEAD" then
        if ns.CastStacks then ns.CastStacks.Reset() R.RenderAllCastTimers() end
        return
    end
    if event == "UPDATE_SHAPESHIFT_FORM" and ns.CastStacks then
        ns.CastStacks.Reset()
        R.RenderAllCastTimers()
    end
    if event == "PLAYER_TARGET_CHANGED" then
        -- 看目標身上減益的列（Frozen）：容器不會自己因為換目標重掃
        for i = 1, shownCount do
            local row = rows[i]
            local def = row and row.key and R.RESOURCES[row.key]
            if def and def.unit == "target" and row.ab then ns.AuraBar.Refresh(row.ab) end
        end
        return
    end
    if event == "SPELL_UPDATE_CHARGES" then
        -- 充能列（火焰衝擊）：只重畫值
        for i = 1, shownCount do
            local def = rows[i] and rows[i].key and R.RESOURCES[rows[i].key]
            if def and def.charges then Mark(false) return end
        end
        return
    end
    if event == "UNIT_POWER_POINT_CHARGE" then chargedDirty = true end
    if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
        -- 沒有血量列、這個職業的資源也不看生命 ⇒ 不重畫（每次受傷都來，別白做）
        if healthShown or CLASS_HEALTH[event] then Mark(false) end
        return
    end
    if event == "UNIT_SPELL_HASTE" then
        -- 秘法靈魂印「剩幾個 GCD」時：GCD 長度（0.05 秒一格）變了才重排（戰鬥中照樣記旗標、脫戰補）
        for i = 1, shownCount do
            local used = rows[i].gcdUsed
            if used then
                if R.ReadGcd() ~= used then Mark(true) end
                return
            end
        end
        return
    end
    if event == "UNIT_AURA" or event == "UNIT_ABSORB_AMOUNT_CHANGED" then
        Mark(false)
        return
    end
    Mark(REEVAL_EVENTS[event] == true)
end

local function RegisterEvents()
    if evFrame then return end
    evFrame = CreateFrame("Frame")
    -- 綁 "player" 走 RegisterUnitEvent：團隊裡其他人的能量事件在 C 端就被擋掉
    for _, e in ipairs({ "UNIT_POWER_FREQUENT", "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER",
                         "UNIT_ENTERED_VEHICLE", "UNIT_EXITED_VEHICLE", "PLAYER_SPECIALIZATION_CHANGED" }) do
        evFrame:RegisterUnitEvent(e, "player")
    end
    for _, e in ipairs({ "UPDATE_SHAPESHIFT_FORM", "PLAYER_TALENT_UPDATE", "TRAIT_CONFIG_UPDATED",
                         "PLAYER_ENTERING_WORLD", "SPELLS_CHANGED" }) do
        evFrame:RegisterEvent(e)
    end
    if CLASS == "DEATHKNIGHT" then evFrame:RegisterEvent("RUNE_POWER_UPDATE") end
    if CLASS == "DRUID" then evFrame:RegisterEvent("PLAYER_DEAD") end       -- 鐵鬃的每層倒數清空
    if CLASS == "ROGUE" then evFrame:RegisterUnitEvent("UNIT_POWER_POINT_CHARGE", "player") end
    -- 秘法靈魂的「剩幾個 GCD」：格式器的分段跟著 GCD 長度
    if CLASS == "MAGE" then
        evFrame:RegisterUnitEvent("UNIT_SPELL_HASTE", "player")
        -- 火焰衝擊的充能、Frozen（目標身上的減益）換目標
        evFrame:RegisterEvent("SPELL_UPDATE_CHARGES")
        evFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    end
    -- UNIT_AURA／UNIT_HEALTH／UNIT_MAXHEALTH／UNIT_ABSORB_AMOUNT_CHANGED／UNIT_SPELLCAST_SUCCEEDED：
    -- 依畫面上的列動態註冊（SyncUnitEvents）
    evFrame:SetScript("OnEvent", OnEvent)
    SyncUnitEvents()
end

------------------------------------------------------------
-- 初始化（ns.StartEngine：Bars 之後）
------------------------------------------------------------
local function MinSize()
    local cfg = Cfg() or {}
    return R.Width(cfg), RowHeight(cfg)
end

function R.Init()
    if container then return end
    container = ns.Bars.RegisterPanel("resources", {
        anchorPoint = "BOTTOM",               -- 貼在核心技能上方、列數增減時下緣不動
        minSize     = MinSize,
        relayout    = function() R.Update(true) end,
    })
    root = CreateFrame("Frame", nil, container)
    root:SetAllPoints(container)
    RegisterEvents()
    ns.RegisterCallback("FirstRowWidthChanged", "resources", function()
        local cfg = Cfg()
        if cfg and (tonumber(cfg.width) or 0) <= 0 then Mark(true) end
    end)
    ns.RegisterCallback("ProfileChanged", "resources", function() Mark(true) end)
    ns.RegisterCallback("SpecChanged", "resources", function() Mark(true) end)
    -- 玩家在暴雪面板把征戰聖擊放進／拿出追蹤的量條
    ns.RegisterCallback("CatalogChanged", "resources_cstrack", function() R.ScheduleTrackedCheck() end)
    -- 職業色晚到（自訂職業色表）：血量列的底色與門檻曲線的最後一個點要重組
    ns.RegisterCallback("AccentChanged", "resources", function() Mark(true) end)
    -- 虛空化身那兩段字的預覽（設定視窗開著／暴雪編輯模式中）：進出時重畫值
    ns.RegisterCallback("OptionsShown", "resources_meta", function() Mark(false) end)
    ns.RegisterCallback("OptionsHidden", "resources_meta", function() Mark(false) end)
    ns.RegisterCallback("EditModeChanged", "resources_meta", function() Mark(false) end)
    R.Reevaluate()
end

-- 設定頁改了值：重排＋結構（錨點、strata、開關）＋ alpha
function R.Apply()
    R.InvalidateStyles()
    R.condCurveGen = R.condCurveGen + 1          -- 條件規則改了：秘密值時的換色曲線重建（CondCurve）
    if not container then return end
    R.Invalidate()
    R.Update(true)
    -- 結構（錨點、strata、開關）：戰鬥外當場套；戰鬥中交給排程記帳到脫戰
    if InCombatLockdown() then ns.Bars.Request("resources", "structure") else ns.Bars.ApplyStructure("resources") end
    if ns.Visibility then ns.Visibility.Apply("resources") end
end

------------------------------------------------------------
-- 公開 API 與除錯
------------------------------------------------------------
-- powerType（Enum.PowerType）或資源 key（字串，沒有 PowerType 的資源：Stagger、IgnorePain…）→ 那一列的框；
-- 沒有這一列、藏著、整條關著都回 nil
function R.GetRowFrame(powerType)
    if powerType == nil or not container then return nil end
    local cfg = Cfg()
    if not cfg or cfg.enabled == false or not container:IsShown() then return nil end
    local byKey = type(powerType) == "string"
    for i = 1, shownCount do
        local row = rows[i]
        local def = row and row.key and R.RESOURCES[row.key]
        if def and row:IsShown() then
            if byKey then
                if row.key == powerType then return row end
            elseif def.power == powerType then
                return row
            end
        end
    end
    return nil
end

function R.DebugLines()
    local out = {}
    local cfg = Cfg()
    if not container then
        out[1] = "  資源條：沒有初始化"
        return out
    end
    local cand, specID = R.Candidates()
    out[#out + 1] = ("  資源條：%s  專精 %s  候選 %d  顯示 %d 列  寬 %s  alpha %s%s")
        :format((cfg and cfg.enabled ~= false) and "開" or "關", tostring(specID), #cand, shownCount,
                tostring(R.Width(cfg)), tostring(ns.Visibility and ns.Visibility.Current("resources")),
                pendingRelayout and "  （戰鬥中，重排延到脫戰）" or "")
    for i = 1, shownCount do
        local row = rows[i]
        local key = row.key
        local def = R.RESOURCES[key]
        local cur, max = GetValue(key)
        local secret = ns.IsSecret(cur) or ns.IsSecret(max)
        local n = RC.Resolve(cfg, key)
        local extra = R.det.live[key] and "  獨立擺放" or ""
        if R.EngineDriven(key) and row.ab and ns.AuraBar then
            local bound = ns.AuraBar.Bound(row.ab)
            extra = extra .. ("  容器 %s／交條 %s"):format(tostring(row.engineStatus),
                bound == true and "是" or bound == false and "失敗" or "未知")
        end
        out[#out + 1] = ("    %d. %-15s %s%s  畫法 %s  秘密 %s  條件 %d  %s%s")
            :format(i, key, def.mode, (def.mode == "pip" or def.mode == "auraBar") and ("×" .. tostring(row.numSeg)) or "",
                    tostring(row.mode), secret and "是" or "否", n and #n or 0, tostring(gateLog[key] or ""), extra)
        -- 引擎寫的列：容器、按鈕、身上光環的細節（「整列空白」分得出卡在哪一段）＋列本身的尺寸／可見
        if R.EngineDriven(key) and row.ab and ns.AuraBar and ns.AuraBar.DebugLines then
            local okS, rw, rh = pcall(row.GetSize, row)
            local okV, vis = pcall(row.IsVisible, row)
            out[#out + 1] = ("       列：尺寸 %sx%s  可見 %s  格數 %s"):format(
                okS and tostring(Plain(rw)) or "?", okS and tostring(Plain(rh)) or "?",
                okV and tostring(Plain(vis)) or "?", tostring(row.numSeg))
            for _, line in ipairs(ns.AuraBar.DebugLines(row.ab, def.auras)) do out[#out + 1] = line end
        end
    end
    if CLASS == "DEMONHUNTER" and ns.DevourerMeta then out[#out + 1] = "  " .. ns.DevourerMeta.DebugLine() end
    for key, why in pairs(gateLog) do
        local listed = false
        for i = 1, shownCount do if rows[i].key == key then listed = true end end
        if not listed then out[#out + 1] = ("    （%s）%s"):format(key, why) end
    end
    return out
end
