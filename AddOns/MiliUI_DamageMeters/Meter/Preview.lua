------------------------------------------------------------
-- 預覽：設定視窗或編輯模式開著時，統計視窗改畫一份範例資料
--
-- 玩家調樣式的當下通常沒有資料（剛登入、剛重置、單刷只有自己一列），調了什麼看不出來。
-- 跟暴雪內建統計在編輯模式的預覽同一招：**只換資料來源**，其餘整條繪製路徑原封不動 ——
-- 畫出來的就是真正的長條、字型、圖示、顏色、排名、百分比、計時器、釘住自己那列。
--
-- 範圍刻意只在 W.Refresh 這一個入口：首頁、展開頁、滑過預覽、發佈照舊讀 API。
-- 範例列帶 isPreview 標記，展開頁與滑過預覽看到就不開（沒有法術資料可以給）。
--
-- 什麼時候是預覽（三個條件同時成立）：
--   * 編輯模式或設定視窗開著 —— 跟「一律顯示／一律展開／一律可點」同一個狀態
--   * 玩家沒在設定視窗的「預覽」鈕把它關掉。**每次打開都重新開著，不存檔**：
--     存檔的話關過一次就永遠關著，下次調樣式又看不到，而且想不起來是哪裡關的
--   * 不在戰鬥中。預覽中碰上戰鬥就關掉**並維持關閉**（按鈕跟著變 OFF）：打完回頭看的
--     是剛剛那場，不該在脫戰後被範例資料蓋回去。要再看預覽按一下按鈕。
--     戰鬥中才打開設定的不算，脫戰後的第一次刷新就開起來（Check）
--
-- ⚠ 戰鬥中一定要是真資料。進出的入口有好幾個（設定視窗 OnShow/OnHide、編輯模式、
--   戰鬥開始），漏一個就會在戰鬥中畫假資料 —— 所以 W.Refresh 每次都再算一次（Check），
--   跟記住的不一樣就當場補做切換。成本是幾個布林判斷。
------------------------------------------------------------
local _, ns = ...

ns.Preview = {}
local Preview = ns.Preview
local D = ns.Data

-- 範例戰鬥的時長：計時器顯示這個，每秒值也照它換算總量
local DURATION = 150
Preview.DURATION = DURATION

-- 跟暴雪內建編輯模式預覽同一批人：GlobalStrings 的 DAMAGE_METER_EDIT_MODE_SOURCE_1～7，
-- 各語系都有官方譯名，不必自己翻。英文名只是那條字串不存在時的退路。
-- 第三格是暴雪的專精順序（GetSpecializationInfoForClassID 的第幾個），圖示照它找
local CAST = {
    { "Arthas",   "DEATHKNIGHT", 2 },   -- 冰霜
    { "Jaina",    "MAGE",        3 },   -- 冰霜
    { "Gul'dan",  "WARLOCK",     2 },   -- 惡魔學識
    { "Thrall",   "SHAMAN",      1 },   -- 元素
    { "Uther",    "PALADIN",     1 },   -- 神聖
    { "Illidan",  "DEMONHUNTER", 1 },   -- 浩劫
    { "Sylvanas", "HUNTER",      2 },   -- 射擊
}
local ME = 0   -- 排行表裡代表玩家自己的那一格

-- 各類型的排行：{ 誰, 值 }，照名次排好（API 給的也是排好的）。
-- 值：量的類型是每秒值；次數型是次數；死亡是開場後第幾秒，**最近的在前**（跟 API 一樣，
-- Rows.FilterDeaths 會再翻成時間順序）。
-- 自己排在第三名附近：看得到自己那列的樣子，又不會佔掉第一名。
-- 敵方承受傷害的來源是怪，沒有職業（enemy）：跟真資料一樣不畫圖示、不上職業色。
local RANKS = {
    DamageDone = {
        { 6, 512000 }, { 2, 486000 }, { ME, 455000 }, { 7, 431000 },
        { 1, 402000 }, { 3, 377000 }, { 4, 341000 }, { 5, 96000 },
    },
    HealingDone = {
        { 5, 402000 }, { 4, 118000 }, { ME, 61000 }, { 1, 47000 },
        { 6, 23000 }, { 2, 15000 }, { 3, 12000 }, { 7, 6000 },
    },
    DamageTaken = {
        { 1, 214000 }, { 6, 158000 }, { ME, 97000 }, { 5, 88000 },
        { 4, 71000 }, { 7, 52000 }, { 3, 49000 }, { 2, 33000 },
    },
    AvoidableDamageTaken = {
        { 3, 18400 }, { ME, 12100 }, { 2, 7600 }, { 6, 5200 }, { 4, 2300 },
    },
    EnemyDamageTaken = { enemy = true,
        { 1, 1950000 }, { 6, 860000 }, { 3, 412000 }, { 7, 205000 },
    },
    Interrupts = {
        { 6, 9 }, { 1, 7 }, { ME, 6 }, { 4, 5 }, { 2, 4 }, { 7, 3 }, { 3, 2 },
    },
    Dispels = {
        { 5, 14 }, { 4, 9 }, { ME, 5 }, { 2, 4 }, { 3, 2 },
    },
    Deaths = {
        { 3, 131 }, { 2, 98 }, { 7, 46 },
    },
}

-- 暴雪的類型值 → 上面那張表的名字。逐筆塞：舊客戶端少一種類型時不會變成 nil key
local RANK_OF = {}
for name, list in pairs(RANKS) do
    local v = D.T[name]
    if v ~= nil then RANK_OF[v] = list end
end

------------------------------------------------------------
-- 範例資料
------------------------------------------------------------
local function PlayerSpecIcon()
    local idx = GetSpecialization and GetSpecialization()
    if not idx or not GetSpecializationInfo then return nil end
    local _, _, _, icon = GetSpecializationInfo(idx)
    return icon
end

-- 欄位照 C_DamageMeter 的 source 抄，繪製端分不出差別。
-- **不給 sourceGUID**：範例列不該被拿去問 API、查觀察快取。
local function MakeSource(who, value, dmType, enemy)
    local src = { isPreview = true, isLocalPlayer = (who == ME) }
    if who == ME then
        -- 預覽只在脫戰時出現，名字與職業都是明碼
        src.name = UnitName("player")
        src.classFilename = ns.playerClass
        src.specIconID = PlayerSpecIcon()
    else
        local c = CAST[who]
        src.name = _G["DAMAGE_METER_EDIT_MODE_SOURCE_" .. who] or c[1]
        if not enemy then
            src.classFilename = c[2]
            src.specIconID = D.SpecIconFor(c[2], c[3])
        end
    end
    if D.IsDeathType(dmType) then
        src.totalAmount = 0
        src.deathRecapID = 1          -- > 0 才過得了 FilterDeaths
        src.deathTimeSeconds = value
    elseif D.IsCountType(dmType) then
        src.totalAmount = value
        src.amountPerSecond = value / DURATION
    else
        src.totalAmount = value * DURATION
        src.amountPerSecond = value
    end
    return src
end

-- 每種類型一份，進入預覽時清掉重建（名字、專精可能跟上次不一樣）。
-- 表要穩定：Rows 把 source 存在 bar._src 上，每次刷新換一張新表只是製造垃圾。
local _sessions = {}

function Preview.Session(dmType)
    local s = dmType ~= nil and _sessions[dmType]
    if s then return s end
    -- 暴雪哪天加了新類型：先借傷害輸出那張，至少畫得出東西
    local list = (dmType ~= nil and RANK_OF[dmType]) or RANKS.DamageDone
    local sources = {}
    for i, e in ipairs(list) do
        sources[i] = MakeSource(e[1], e[2], dmType, list.enemy)
    end
    s = { combatSources = sources, isPreview = true }
    if dmType ~= nil then _sessions[dmType] = s end
    return s
end

------------------------------------------------------------
-- 狀態
------------------------------------------------------------
local _forced = false   -- 上一次看到的「編輯模式或設定視窗開著」
local _wanted = false   -- 玩家要不要預覽：打開時重置成要、戰鬥一來就不要
local _active = false   -- 畫面上現在是不是預覽

local function InCombat()
    return InCombatLockdown() or ns.Combat.IsInCombat()
end

local function Compute()
    local forced = (ns.Move.IsEditing() or ns._optionsOpen) and true or false
    if forced ~= _forced then
        _forced = forced
        _wanted = forced   -- 打開＝重新預覽；關掉＝一起收
    end
    if not (_forced and _wanted) then return false end
    if InCombat() then
        -- 預覽中碰上戰鬥：收掉並維持關閉。還沒預覽起來就在戰鬥中（戰鬥中、或剛打完
        -- 狀態機還沒收尾就打開設定）不算 —— 那是來調設定的，脫戰後照樣開起來
        if _active then _wanted = false end
        return false
    end
    return true
end

function Preview.IsActive() return _active end

-- 進出預覽：資料整批換掉，標題的狀態標籤也跟著換字
local function Apply(W, entering)
    W._barCacheKey = nil
    W._timerSec = nil
    -- 展開頁／滑過預覽開著的是真資料的某一列，底下的清單一換就對不上了
    ns.Breakdown.Close(W)
    ns.Tooltip.HideFor(W)
    ns.Window.UpdateTitle(W)
    W.Refresh()
    -- 狀態標籤亮一下：畫面上的人與數字整批換掉，要有個交代
    if entering then ns.Window.PulseStatus(W) end
end

function Preview.Sync()
    local active = Compute()
    if active == _active then return end
    _active = active
    if active then wipe(_sessions) end
    if ns.Windows then
        ns.Windows.ForEach(function(W) Apply(W, active) end)
    end
    ns.Fire("PreviewChanged", active)
end

-- W.Refresh 每次都問這支：狀態跟記住的不一樣（某個入口漏了 Sync）就當場補做
function Preview.Check()
    if Compute() ~= _active then Preview.Sync() end
    return _active
end

-- 設定視窗的「預覽」鈕。戰鬥中按了也不會開（Compute 會再關掉）
function Preview.Set(on)
    _wanted = on and true or false
    Preview.Sync()
end

-- 自己進戰鬥的那一刻就收。隊友先開怪那種（沒有 PLAYER_REGEN_DISABLED）由
-- Combat.lua 的 BeginSegment 叫，再漏的由 W.Refresh 的 Check 補
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_REGEN_DISABLED")
ev:SetScript("OnEvent", function() Preview.Sync() end)
