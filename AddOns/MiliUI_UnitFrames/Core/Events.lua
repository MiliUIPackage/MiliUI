------------------------------------------------------------
-- 事件引擎：事件 → 刷新桶 對照集中在這裡，單一 frame 分派
-- Metro：共用 ticker（tot/focustarget 換人偵測、施法條秘密模式等）
------------------------------------------------------------
local _, ns = ...

ns.Events = {}
ns.Metro = {}

local eventFrame = CreateFrame("Frame")

------------------------------------------------------------
-- 單位事件 → 刷新桶
--
-- ⚠ 這裡的分桶就是效能本身。以前 UNIT_FACTION / UNIT_FLAGS / UNIT_MODEL_CHANGED
-- 這些通通對到 identity，而 identity 會跑**所有**元件——包含彈光環容器（強制整組
-- 重掃）和重載 3D 模型。等於進出一次戰鬥、改一次 PvP 旗標就付一次全量重畫。
--
--   unitchanged  這個框現在看的是**另一個單位**了 → 全量（只有這個桶跑所有元件）
--   info         名字／等級／分類 → 只有文字
--   reaction     陣營／旗標 → 只有顏色與狀態文字
--   portrait     模型換了 → 只有頭像
--   health / power / powertype / death   數值類，照舊
--   metro        輪詢（超出距離）
------------------------------------------------------------
local UNIT_EVENT_BUCKET = {
    UNIT_HEALTH = "health",
    UNIT_MAXHEALTH = "health",
    UNIT_HEAL_PREDICTION = "health",
    UNIT_ABSORB_AMOUNT_CHANGED = "health",
    UNIT_HEAL_ABSORB_AMOUNT_CHANGED = "health",
    UNIT_POWER_UPDATE = "power",
    UNIT_MAXPOWER = "power",
    UNIT_DISPLAYPOWER = "powertype",
    UNIT_CONNECTION = "death",
    UNIT_NAME_UPDATE = "info",
    UNIT_LEVEL = "info",
    UNIT_CLASSIFICATION_CHANGED = "info",
    UNIT_FACTION = "reaction",
    UNIT_FLAGS = "reaction",
    -- ⚠ 這兩個語意不同，不可以合併：
    --   model    模型真的換了（變身／幻化／變形術）→ 3D 要重載
    --   portrait 頭像貼圖該更新（主要是 2D 那條路）→ 3D **不可以**重載，
    --            這個事件在戰鬥中會反覆來，每次重載就是肉眼可見的閃爍
    UNIT_MODEL_CHANGED = "model",
    UNIT_PORTRAIT_UPDATE = "portrait",
}

-- ⚠⚠ 這幾個事件**不吃同幀去重**（戳記照寫，只是不吃它跳過）。
--
-- 它們帶的是「值」本身，而且對應的狀態可能是**終點**：死亡之後血量不再變動，
-- 同幀第二波派送被戳記擋掉就永遠等不到下一次補救，血條會停在死前那一格。
-- 完整理由寫在 Core/UnitFrame.lua 的「同幀去重」那段。
--
-- 只列帶值的：absorb 家族（UNIT_ABSORB_AMOUNT_CHANGED 等）**刻意不列** ——
-- 護盾會持續產生事件，過期一幀下一幀就自我修復，而它們正是同幀重複派送的大宗，
-- 去重省下來的就是它們。
local FORCE_EVENT = {
    UNIT_HEALTH = true,
    UNIT_MAXHEALTH = true,
}

local function RefreshUnit(unitToken, bucket, force)
    local uf = ns.frames[unitToken]
    if uf and uf:IsVisible() then
        ns.Refresh(uf, bucket, force)
    end
end

------------------------------------------------------------
-- 每個 unit token 一顆 tracker frame
--
-- 全域 RegisterEvent 的語意是「**每一個**單位的事件都送進 Lua，我們才判斷關不關
-- 自己的事」。20 人團隊戰裡 raid1-20、寵物、名條、首領的 UNIT_HEALTH 全部都會來，
-- 而我們只在乎 11 個 token —— 九成以上是白工。RegisterUnitEvent 讓客戶端在 C 端
-- 就過濾掉。
--
-- 副 token 在**註冊期**就一起收：玩家框同時收 player 與 vehicle、
-- 寵物框同時收 pet 與 player。這樣進出載具時 uf.unit 換掉就好，事件完全不用重註冊。
------------------------------------------------------------
local SECONDARY_TOKEN = { player = "vehicle", pet = "player" }
local trackers = {}

-- ⚠ 副 token 的事件要**擋掉**。上面那段讓一顆 tracker 同時收兩個 token，好處是
-- 載具切換不必重註冊；代價是**沒在載具裡的時候**，寵物框照樣收得到 player 的事件
-- （寵物框註冊的是 pet + player）。少了這道閘就是「玩家每次掉血都讓寵物框跑一次
-- 完整 health 重畫」——cache 消毒＋血條計算器＋所有訂閱 health 桶的文字 tag，
-- 而那次重畫讀的是 pet，跟事件毫無關係。獵人／術士／邪騎／法師整場戰鬥都在付。
--
-- ⚠⚠ 閘只在 `uf.unit == uf.baseUnit`（框正在畫它原本的單位）時生效，不是無條件
-- 比對 uf.unit。這個保守版本當初是為了避開「不確定引擎用哪個 token 派送」而寫的，
-- 日常情況（99% 的時間）該擋的全擋掉，一旦框被重新對應到別的 token 就整個放行。
--
-- ⚠⚠ **不要收緊成單純的 `unit ~= uf.unit`。** 註解原本留著「哪天實測確認過就可以
-- 收緊」的問號，2026-08-20 在有載具 UI 的載具上量到答案了 ——
-- 下面那張 census 印出來是 `player=player×2,vehicle×4`、`pet=pet×4,player×2`：
-- **兩個 token 都會派送**，而且技能可能掛在 "player" 上報，即使框已經被對應成
-- "vehicle"。收緊等於把 player 那半全部擋掉，玩家框整趟車不更新。
--
-- 這不是假想的故障：Elements/Castbar.lua 的施法條閘當初就是寫成嚴格比對，症狀是
-- 「在載具上施法，施法條長在寵物框（那格這時畫的是你自己）」，玩家框永遠空的。
-- 那邊的修法是把「框在畫誰」跟「這條在畫誰的施法」拆成兩個欄位，見那支的
-- AcceptCastEvent；這裡則是維持全放行——刷新讀的是 uf.unit，多跑幾次不會讀錯單位。
local function TrackerOnEvent(self, event, unit)
    local uf = self.uf
    if not (uf and uf:IsVisible()) then return end
    if uf.unit == uf.baseUnit then
        -- 一般情況（99% 的時間）：只理會這個框正在畫的那個 token
        if unit ~= uf.unit then return end
    else
        -- 框被重新對應（載具）：兩個 token 都放行，並記下**實際**收到的是哪一個。
        -- 這張表就是「上面那道閘能不能收緊」的唯一證據，`/muf debug` 印得出來：
        --   只出現 vehicle ⇒ 引擎按實際 token 派送，閘可以收緊成單純的 unit ~= uf.unit
        --   出現 player    ⇒ 收緊會把載具中的事件擋掉，保守版本是必要的
        -- 只在被重新對應時才配置，日常路徑一個位元組都不花。
        local census = uf.tokenCensus
        if not census then census = {}; uf.tokenCensus = census end
        census[unit] = (census[unit] or 0) + 1
    end
    local bucket = UNIT_EVENT_BUCKET[event]
    if bucket then ns.Refresh(uf, bucket, FORCE_EVENT[event]) end
end

-- 單位框生出來時呼叫（SpawnUnitFrame）
function ns.Events.AttachUnit(uf)
    local token = uf.baseUnit
    local t = trackers[token]
    if t then t.uf = uf; return end
    t = CreateFrame("Frame")
    t.uf = uf
    t:SetScript("OnEvent", TrackerOnEvent)
    trackers[token] = t
    local secondary = SECONDARY_TOKEN[token]
    for event in pairs(UNIT_EVENT_BUCKET) do
        -- 麵包屑同 Reg()：ADDON_ACTION_FORBIDDEN 不會說是哪個事件
        ns.trace = "RegisterUnitEvent(" .. event .. ")"
        if secondary then
            pcall(t.RegisterUnitEvent, t, event, token, secondary)
        else
            pcall(t.RegisterUnitEvent, t, event, token)
        end
        ns.trace = nil
    end
end

------------------------------------------------------------
-- 註冊簿
--
-- ⚠ 這一段必須排在 SPECIAL／SCOPED／Start 之前：Lua 的 local 只對「宣告之後」的
-- 程式碼可見，宣告在下面的話上面那些函式體會抓到同名的**全域 nil** 而靜默失效
-- （這個 repo 已經踩過兩次：Tags 的 _CSU、Totems 的 previewOn）。
------------------------------------------------------------
-- callback key 查表算一次就好。原本每次派發都現串 "EVENT_" .. event，
-- 而 UNIT_AURA 這種在團隊戰是每秒數百次的量。
local FIRE_KEY = setmetatable({}, { __index = function(t, event)
    local k = "EVENT_" .. event
    t[event] = k
    return k
end })

local externalEvents = {}      -- [event] 註冊在全域 eventFrame 上的
local unitScoped = {}          -- [event] 有任何 token 走過 unit 範圍註冊（不可再上全域，會雙送）
local unitRegistered = {}      -- [event.."/"..token] 這個組合註冊過了
local unitFrames = {}          -- unit token → frame

-- 麵包屑：ADDON_ACTION_FORBIDDEN 只會告訴我們「Frame:RegisterEvent()」，
-- 不會說是哪個事件。註冊前先記下來，攔截器就能指名（見 Core/Init.lua）
local function Reg(event)
    ns.trace = "RegisterEvent(" .. tostring(event) .. ")"
    pcall(eventFrame.RegisterEvent, eventFrame, event)
    ns.trace = nil
end

local SCOPED        -- 前置宣告：UnitReg 的處理器要查它，實體定義在 SPECIAL 後面

-- 只關心特定單位的事件走這裡：RegisterUnitEvent 讓客戶端在 C 端就過濾掉，
-- 不相干的單位根本不會進 Lua。全域 RegisterEvent 是「每個單位都送進來、
-- 我們才判斷關不關自己的事」，團隊戰差距很大。
--
-- 同一個 token 的所有事件共用一顆 frame。處理器同時服務兩種來源：
-- SCOPED 的內部邏輯（有定義才跑）與外部訂閱者的 callback。
local function DispatchScoped(ev, unit, ...)
    local def = SCOPED[ev]
    if def then def.fn(unit) end
    ns.Fire(FIRE_KEY[ev], unit, ...)
end

local function UnitReg(event, token, token2)
    local f = unitFrames[token]
    if not f then
        f = CreateFrame("Frame")
        -- 只記帳，工作延到下一幀（UNIT_TARGET 會在 TargetUnit 的 secure 流程裡
        -- 同步派送）—— 見下面 ns.Defer 的說明
        f:SetScript("OnEvent", function(_, ...) ns.Defer(DispatchScoped, ...) end)
        unitFrames[token] = f
    end
    ns.trace = "RegisterUnitEvent(" .. tostring(event) .. ")"
    pcall(f.RegisterUnitEvent, f, event, token, token2)
    ns.trace = nil
    return f
end

-- 非單位事件（沒有 unit 參數，或參數不是「這個框在看的單位」）走全域 frame。
-- 這些都是低頻事件，留在全域沒有成本問題。
local SPECIAL = {
    PLAYER_TARGET_CHANGED = function()
        RefreshUnit("target", "unitchanged")
        RefreshUnit("targettarget", "unitchanged")
    end,
    PLAYER_FOCUS_CHANGED = function()
        RefreshUnit("focus", "unitchanged")
        RefreshUnit("focustarget", "unitchanged")
    end,
    INSTANCE_ENCOUNTER_ENGAGE_UNIT = function()
        for i = 1, 5 do RefreshUnit("boss" .. i, "unitchanged") end
    end,
    -- 隊伍組成變了：影響的是隊長圖示與陣營色，不是「換人」。
    -- ⚠ 要刷**所有**框不是只刷玩家：隊長圖示畫在每個框上（目標、目標的目標、寵物都可能
    -- 是隊友），只刷玩家的話別人的隊長圖示會停在舊狀態，直到那個框因為別的原因重畫。
    GROUP_ROSTER_UPDATE = function()
        ns.RefreshAll("reaction")
    end,
    -- 隊長換人。GROUP_ROSTER_UPDATE **不涵蓋這個**——組成沒變、只是權杖換人時
    -- 只會發這一個事件。同樣走 reaction 桶（隊長圖示在裡面）
    PARTY_LEADER_CHANGED = function()
        ns.RefreshAll("reaction")
    end,
    PLAYER_ENTERING_WORLD = function()
        ns.RefreshAll("unitchanged")
    end,
    -- 生死狀態。
    -- ⚠ 這三個是**全域**事件，不是 UNIT_ 事件，所以不會經過上面那張 unit 事件表。
    -- 少了它們的症狀是：跑屍復活之後「靈魂」字樣不會消失 —— cache.ghost 其實已經
    -- 被 UNIT_HEALTH 那條路更新了，但顯示「靈魂」的文字訂閱的是 **death 桶**，
    -- 而 death 桶只有 UNIT_CONNECTION 會推，所以那顆文字根本沒有重畫的機會。
    -- 三個都收：PLAYER_DEAD（倒地）、PLAYER_UNGHOST（從靈魂變回活人）、
    -- PLAYER_ALIVE（放棄屍體變靈魂，以及登入時）。都是罕見事件，成本可以忽略。
    -- 一律 force：生死是終點狀態，被同幀稍早的重畫吃掉就等不到下一次了（同 FORCE_EVENT）。
    PLAYER_DEAD = function()
        RefreshUnit("player", "death", true)
    end,
    PLAYER_ALIVE = function()
        RefreshUnit("player", "death", true)
    end,
    PLAYER_UNGHOST = function()
        RefreshUnit("player", "death", true)
    end,
    -- AFK／DND。不是 UNIT_ 事件，不確定 RegisterUnitEvent 吃不吃，留在全域比較保險
    PLAYER_FLAGS_CHANGED = function(unit)
        RefreshUnit(unit, "reaction")
    end,
    -- UNIT_PET：寵物換了（arg 是主人）
    UNIT_PET = function(unit)
        if unit == "player" then RefreshUnit("pet", "unitchanged") end
    end,
}

------------------------------------------------------------
-- 有 unit 參數、但我們只在乎少數 token 的事件
--
-- UNIT_TARGET 以前掛在全域 eventFrame 上，也就是 20 人團隊裡**每一個人**換目標都會
-- 進 Lua，我們才判斷是不是 target／focus —— 九成以上是白工，正好是這個檔案在別處
-- 用 RegisterUnitEvent 避掉的那件事。
--
-- 這顆 frame 同時做兩件事：跑我們自己的邏輯，以及 ns.Fire 給外部訂閱者（光環模組要用）。
-- 所以 ns.Events.Register("UNIT_TARGET", …) 不可以再把它掛上全域 —— 由下面
-- unitScoped 的守衛擋掉。
------------------------------------------------------------
SCOPED = {
    UNIT_TARGET = {
        tokens = { "target", "focus" },
        fn = function(unit)
            if unit == "target" then
                RefreshUnit("targettarget", "unitchanged")
            elseif unit == "focus" then
                RefreshUnit("focustarget", "unitchanged")
            end
        end,
    },
}

-- ⚠⚠ 旗標要在**檔案載入期**就立起來，不能等 Events.Start()。
-- 各元件模組是在自己被載入時（也就是 PLAYER_LOGIN 之前）就呼叫 ns.Events.Register 的，
-- 那一刻 unitScoped 若還是空的，UNIT_TARGET 會先被掛上全域 frame，等 Start 再掛一次
-- unit 範圍 ⇒ 同一個事件送兩次，callback 全部跑兩遍。
-- 實際註冊仍然留在 Start（跟 SPECIAL 一致），這裡只先立旗標。
for event in pairs(SCOPED) do unitScoped[event] = true end

------------------------------------------------------------
-- 全域 frame 的派送要延到下一幀（taint 隔離）
--
-- ⚠⚠ 這裡的事件有一部分是**在暴雪的 secure 執行流程裡同步派送**的：
--
--   TARGETNEARESTENEMY:2     → TargetNearestEnemy()  ─┐
--   TURNORACTION:4           → TurnOrActionStop()    ─┼→ PLAYER_TARGET_CHANGED
--   MULTIACTIONBAR4BUTTON9:2 → UseAction()           ─┘
--
-- 也就是「按 Tab 選目標」「右鍵轉向點怪」「按技能」這三個最常按的動作。在這個
-- handler 裡同步跑 RefreshUnit／ns.Fire，等於把 MiliUI_UnitFrames 的 taint 灌進
-- 那條按鍵的 secure 執行流程 —— 2026-08-30 的 taint.log：一分鐘內 119 次，
-- 期間暴雪的 SetTexture 被封鎖 62 次。
--
-- 跟 Core/UnitFrame.lua 的 OnShow 是同一類問題（我們的 Lua 跑在暴雪的 secure
-- 堆疊裡面），同一招處理：丟到下一幀就完全脫離那條堆疊。那邊實測有效
-- （SecureStateDriverManager 那條從 60 筆歸零、SetAttribute 封鎖從 40 次歸零）。
--
-- 幾個刻意的決定：
--   * **不去重**。UNIT_PET / PLAYER_FLAGS_CHANGED / UNIT_PORTRAIT_UPDATE 的參數是
--     unit token，同一幀來兩次很可能是**不同單位**，去重會吃掉一筆。這張表上的
--     事件本來就低頻（檔案上方那句「留在全域沒有成本問題」），照單全收最安全。
--   * 參數整包留著（`n` ＋ unpack）而不是只存第一個。目前只有兩個 handler 吃參數、
--     而且都只吃第一個，但 externalEvents 是開放註冊的，寫死 arg1 會在未來某支
--     元件註冊「要第二個參數」的事件時**靜默**壞掉。
--   * 雙緩衝：flush 途中若有 handler 又觸發事件，新的進另一個桶，不會蓋掉正在跑的。
------------------------------------------------------------
local qA, qB = {}, {}
local queue, queueN, queueQueued = qA, 0, false

local function FlushGlobalEvents()
    queueQueued = false
    local run, n = queue, queueN
    queue = (run == qA) and qB or qA
    queueN = 0
    for i = 1, n do
        local a = run[i]
        run[i] = nil
        local event = a.event
        local special = SPECIAL[event]
        if special then special(unpack(a, 1, a.n)) end
        if externalEvents[event] then
            ns.Fire(FIRE_KEY[event], unpack(a, 1, a.n))
        end
    end
end

-- 全域 frame：SPECIAL 的內部邏輯 ＋ 有人訂閱的外掛事件
eventFrame:SetScript("OnEvent", function(_, event, ...)
    -- 這裡**只做記帳**，真正的工作在下一幀 —— 見上面那段的說明
    local a = { n = select("#", ...), ... }
    a.event = event
    queueN = queueN + 1
    queue[queueN] = a
    if not queueQueued then
        queueQueued = true
        C_Timer.After(0, FlushGlobalEvents)
    end
end)

------------------------------------------------------------
-- 通用「丟到下一幀」
--
-- 給那些**不走全域 eventFrame**、但一樣可能在暴雪的 secure 流程裡被同步呼叫的入口用：
--   * unit 範圍的事件 frame（UnitReg）：UNIT_TARGET 在 TargetUnit 流程裡同步派送
--   * 施法條的事件 frame（Elements/Castbar.lua）：UNIT_SPELLCAST_FAILED 在 UseAction
--     裡同步派送（技能按不出去的那一下）、UNIT_TARGET 在按 Tab 選目標時同步派送
--   * OnAttributeChanged／OnShow／OnHide 掛在 secure 單位框上的 HookScript：
--     RegisterUnitWatch 的 Show()／SetAttribute("statehidden") 從安全端呼叫
-- 2026-09-05：8/30 只把全域 frame 延了，這幾個入口漏掉，戰鬥中快捷列按鈕的
-- SetAttribute 照樣被封鎖、記在我們頭上。
--
-- 規矩同上面那段：不去重、參數整包留著、雙緩衝。每筆各自 xpcall 隔離，
-- 一筆炸掉不能拖垮同一幀後面的。
------------------------------------------------------------
local dA, dB = {}, {}
local dq, dqN, dqQueued = dA, 0, false

local function FlushDeferred()
    dqQueued = false
    local run, n = dq, dqN
    dq = (run == dA) and dB or dA
    dqN = 0
    for i = 1, n do
        local a = run[i]
        run[i] = nil
        xpcall(a.fn, ns.ReportError, unpack(a, 1, a.n))
    end
end

function ns.Defer(fn, ...)
    local a = { n = select("#", ...), ... }
    a.fn = fn
    dqN = dqN + 1
    dq[dqN] = a
    if not dqQueued then
        dqQueued = true
        C_Timer.After(0, FlushDeferred)
    end
end

function ns.Events.Start()
    -- UNIT_EVENT_BUCKET 的事件**不在這裡註冊**：它們走 ns.Events.AttachUnit 的
    -- per-token tracker。同時上全域會被送兩次。
    for event in pairs(SPECIAL) do Reg(event) end

    -- unit 範圍的內部事件：C 端就把不相干的單位過濾掉
    for event, def in pairs(SCOPED) do
        UnitReg(event, def.tokens[1], def.tokens[2])
        unitScoped[event] = true
        for _, token in ipairs(def.tokens) do
            unitRegistered[event .. "/" .. token] = true
        end
    end
end

------------------------------------------------------------
-- 外掛事件（元件模組用：ClassPower / Visibility / Portrait 等）
------------------------------------------------------------
-- unitToken 給了就走 C 端過濾。
--
-- ⚠ 兩個容易踩的點：
--   1. 去重的鍵要含 token。以前只用 event 當鍵，同一個事件想再綁**第二個 token**
--      就會整個被略過 —— 註冊靜默失敗、那個 token 的事件永遠不會進來。
--   2. 已經有 unit 範圍註冊的事件**不可以再上全域**：全域那顆會把每個單位的事件都
--      送進來，對已經被 scope 過的 token 就是雙送。所以走全域那條要先看 unitScoped。
--      （UNIT_TARGET 就是這種：Events.Start 已經綁好 target+focus 並且會 ns.Fire，
--        光環模組那邊照樣 ns.Events.Register 不傳 token，callback 一樣收得到。）
function ns.Events.Register(event, key, fn, unitToken)
    ns.RegisterCallback(FIRE_KEY[event], key, fn)
    if unitToken then
        local id = event .. "/" .. unitToken
        if not unitRegistered[id] then
            unitRegistered[id] = true
            unitScoped[event] = true
            UnitReg(event, unitToken)
        end
    elseif not externalEvents[event] then
        if unitScoped[event] then
            -- 這個事件已經被 unit 範圍註冊過，不可以再上全域（會雙送）。
            --
            -- ⚠⚠ **SCOPED 裡的事件是正常情況，不要警告。** 那張表綁好 token 之後，
            -- 它的 OnEvent 會照樣 ns.Fire 給所有訂閱者 ⇒ 不傳 token 的訂閱者一樣
            -- 收得到（上面那段註解本來就寫明了，UNIT_TARGET 就是這樣設計的）。
            -- 我一度在這裡無條件記一筆「收不到其他單位的事件」，結果 /muf debug 上
            -- 冒出兩條指著光環模組的假警報 —— 會誤導的診斷比靜默更糟。
            --
            -- 真正值得記的只有另一種：**別的模組臨時用 token 註冊**，把這個事件變成
            -- unit 範圍，於是後來不傳 token 的訂閱者只收得到那個 token。那才是意外。
            if not SCOPED[event] then
                -- 走 ns.errors 不走 ns.ReportError：這是給開發者的線索、不是玩家的
                -- 問題，不該在登入時彈錯誤視窗。`/muf debug` 讀得到。
                tinsert(ns.errors, ("Events.Register: %s 已被 %s 之外的 token 註冊，key=%s 的全域訂閱只收得到那個 token")
                    :format(tostring(event), "SCOPED", tostring(key)))
            end
            return
        end
        externalEvents[event] = true
        Reg(event)
    end
end

------------------------------------------------------------
-- Metro：共用 0.1s ticker，依 key 節流
------------------------------------------------------------
local metroEntries = {}
local metroTicker

-- ⚠ 逐項隔離：這是裸迴圈 dispatch，一支拋錯會讓該次 tick 剩下的項目全部不跑。
-- 症狀是「某個框的文字壞掉之後，所有框的超出距離淡出跟著凍結」，而且每 0.1 秒
-- 重演一次。UnitFrame 的三處 dispatch 已經是這樣防的，這裡是同一類的最後一個缺口。
local function MetroTick()
    for _, entry in pairs(metroEntries) do
        entry.elapsed = entry.elapsed + 0.1
        if entry.elapsed >= entry.interval then
            entry.elapsed = 0
            xpcall(entry.fn, ns.ReportError)
        end
    end
end

-- ⚠ 既有項目只更新欄位、不重置 elapsed：Add 會被重複呼叫（Bind 每次 OnShow
-- 都會叫一次），每次都歸零的話間隔長的項目永遠等不到觸發
function ns.Metro.Add(key, interval, fn)
    local e = metroEntries[key]
    if e then
        e.interval, e.fn = interval, fn
    else
        metroEntries[key] = { interval = interval, elapsed = 0, fn = fn }
    end
    if not metroTicker then
        metroTicker = C_Timer.NewTicker(0.1, MetroTick)
    end
end

function ns.Metro.Remove(key)
    metroEntries[key] = nil
    if metroTicker and not next(metroEntries) then
        metroTicker:Cancel()
        metroTicker = nil
    end
end

-- 把一個輪詢項目綁在框架的可見度上：框藏起來就卸下，整張表空了 ticker 才停得掉。
-- 沒有這層的話一個永久項目就會讓 0.1 秒的 ticker 從登入轉到登出。
-- OnShow/OnHide 只掛一次（Build 是冪等的，會被重跑）。
function ns.Metro.Bind(uf, key, interval, fn)
    local bound = uf.metroBound
    if not bound then bound = {}; uf.metroBound = bound end
    local function sync()
        if uf:IsShown() then
            ns.Metro.Add(key, interval, fn)
        else
            ns.Metro.Remove(key)
        end
    end
    bound[key] = sync
    if not uf.metroHooked then
        uf.metroHooked = true
        local function syncAll()
            for _, s in pairs(uf.metroBound) do s() end
        end
        -- Show()/Hide() 是 RegisterUnitWatch 從安全端呼叫的，掛勾裡不做事，丟到下一幀
        uf:HookScript("OnShow", function() ns.Defer(syncAll) end)
        uf:HookScript("OnHide", function() ns.Defer(syncAll) end)
    end
    sync()
end

-- 給 /muf debug：輪詢項目有沒有真的掛上去
function ns.Metro.Debug()
    local out = {}
    for key, e in pairs(metroEntries) do
        out[#out + 1] = ("%s(%.1fs)"):format(key, e.interval or 0)
    end
    table.sort(out)
    return out, metroTicker ~= nil
end

function ns.Metro.Unbind(uf, key)
    if uf.metroBound then uf.metroBound[key] = nil end
    ns.Metro.Remove(key)
end
