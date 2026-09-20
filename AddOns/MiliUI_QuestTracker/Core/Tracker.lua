------------------------------------------------------------
-- 碰暴雪任務追蹤器的唯一出口
--
-- 這支不做任何外觀決定，只提供「怎麼碰才不會出事」的原語。其他模組一律走這裡，
-- 不要自己去摸 ObjectiveTrackerFrame —— 下面每一條規矩背後都是一種**不會當場報錯、
-- 但會在別的地方炸掉**的失敗，散在各模組裡遲早會被繞過去。
--
-- ── 六條規矩 ────────────────────────────────────────────────
--
-- 1. 不要呼叫 ObjectiveTrackerFrame:Update()。
--    那會讓暴雪整套任務排版在我們的執行環境裡跑一遍，它沿路建出來的表之後會被
--    安全程式讀到，taint 就一路跟著走。C_Timer 延後沒有用 —— taint 記的是
--    「誰的執行環境」，不是「誰呼叫的」。代價是改字級之後暴雪快取的區塊高度會
--    暫時對不上（文字疊在一起），等下一個任務事件自然重排就好，不要去修它。
--
-- 2. 自己的旗標不准寫在暴雪的 frame 或 table 上。
--    追蹤器會自己 pairs() 走 usedBlocks 之類的表來決定哪些區塊還在用，多一個鍵
--    就是多一筆假資料。全部走本檔的 T.Flags() 弱表。
--
-- 3. ScenarioObjectiveTracker / UIWidgetObjectiveTracker 的子區塊一根手指都不能碰。
--    連 GetBottom() 都算碰。它們的內容是從暴雪的共用 widget pool 借出來畫的，
--    而那個池子同時服務工具提示與地圖圖釘 —— 沾過的元件被回收去畫提示時就會在
--    版面計算裡炸秘密值。它們的 Header 是安全的（不從池子來），可以照樣美化。
--    例外只有兩個，理由與界線各自寫在原語上：場景 ObjectivesBlock 的目標行
--    （T.EachScenarioLine）、StageBlock 自己的底圖與階段文字＋ObjectivesBlock 的
--    HeaderText 錨點（T.StageArt／T.ScenarioObjectivesAnchor）。
--
-- 4. 藏貼圖只准 SetTexture("")。SetTexture(nil) 與 SetAlpha(0) 都會沾到暴雪的貼圖。
--
-- 5. 任務地圖箭頭（block.poiButton）不准 Hide()，也不准掛它的 Show()。
--    那顆按鈕的 OnShow/OnHide 會去動 EventRegistry 上 "Supertracking.OnChanged"
--    的共用訂閱表，從我們的環境跑一次，整張表的訂閱者（世界地圖那一票資料來源）
--    就全部跟著髒。要藏走 alpha ＋ EnableMouse(false)。
--
-- 6. 不要做「覆蓋層轉發點擊」。想讓標題可以整條點的話，撐原生按鈕的 SetHitRectInsets，
--    讓點擊直接落在暴雪自己的 OnClick 上、我們的程式完全不在那條路上。
--    自己接手再 :Click() 過去等於把整串收合跑在我們的環境裡。
------------------------------------------------------------
local _, ns = ...

ns.Tracker = {}
local T = ns.Tracker

function T.OTF() return _G.ObjectiveTrackerFrame end

------------------------------------------------------------
-- 弱表工廠（規矩 2）
--
-- 追蹤器的區塊是池化的：同一個 frame 會被回收、換一個任務再拿出來用。弱鍵表讓
-- 我們的旗標跟著 frame 一起被垃圾回收，不會累積成一張永遠長大的表。
------------------------------------------------------------
local WEAK_KEY = { __mode = "k" }
function T.Flags() return setmetatable({}, WEAK_KEY) end

------------------------------------------------------------
-- 子追蹤器
--
-- 以 ObjectiveTrackerFrame.modules 為準（那是暴雪自己排版時走的清單），
-- 再補一輪具名全域 —— 有些子追蹤器是延後載入的，晚一步才會進 modules。
------------------------------------------------------------
local NAMED_TRACKERS = {
    "QuestObjectiveTracker",
    "CampaignQuestObjectiveTracker",
    "AchievementObjectiveTracker",
    "AdventureObjectiveTracker",
    "BonusObjectiveTracker",
    "WorldQuestObjectiveTracker",
    "MonthlyActivitiesObjectiveTracker",
    "ProfessionsRecipeTracker",
    "InitiativeTasksObjectiveTracker",
    "ScenarioObjectiveTracker",
    "UIWidgetObjectiveTracker",
}

-- 規矩 3 的黑名單
function T.SharesWidgetPool(tracker)
    return tracker == _G.ScenarioObjectiveTracker
        or tracker == _G.UIWidgetObjectiveTracker
end

function T.EachTracker(fn)
    local seen = {}
    local otf = T.OTF()
    local modules = otf and (otf.modules or otf.MODULES)
    if modules then
        for _, tracker in ipairs(modules) do
            if tracker and not seen[tracker] then
                seen[tracker] = true
                fn(tracker)
            end
        end
    end
    for _, name in ipairs(NAMED_TRACKERS) do
        local tracker = _G[name]
        if tracker and not seen[tracker] then
            seen[tracker] = true
            fn(tracker)
        end
    end
end

------------------------------------------------------------
-- 走一個子追蹤器的所有區塊
--
-- usedBlocks 是兩層的：範本字串 → blockID → block。共用池的追蹤器直接跳過
-- （規矩 3）—— 呼叫端不必自己記得擋，擋在這裡才不會有人漏掉。
------------------------------------------------------------
function T.EachBlock(tracker, fn)
    if not tracker or T.SharesWidgetPool(tracker) then return end
    local used = tracker.usedBlocks
    if type(used) ~= "table" then return end
    for _, byTemplate in pairs(used) do
        if type(byTemplate) == "table" then
            for _, block in pairs(byTemplate) do
                if type(block) == "table" then fn(block) end
            end
        end
    end
end

-- 這個區塊的 `id` 是不是 questID。
--
-- ⚠ `block.id` 的意思**隨區塊來自哪個子追蹤器而不同**：任務區塊是 questID，
--   成就區塊是 achievementID，專業配方是 recipeID。不分辨就拿去問
--   `C_QuestLog.IsComplete()` 或跟 super-track 的 questID 比對，等於在比兩個
--   不同號碼系統的數字 —— 成就 ID 與任務 ID 的值域是重疊的，所以偶爾會有一筆
--   成就無緣無故被上成「導航中」的顏色。
--
--   用排除法而不是白名單：任務類的子追蹤器有好幾支（一般、戰役、World Quest、
--   額外目標…），漏掉一支的後果是那一段整個不上色；而「不是任務」的那幾支是
--   數得完的。
local NON_QUEST_TRACKERS = {
    "AchievementObjectiveTracker",
    "ProfessionsRecipeTracker",
    "MonthlyActivitiesObjectiveTracker",
    "ScenarioObjectiveTracker",
    "UIWidgetObjectiveTracker",
}

function T.IsQuestBlock(block)
    if type(block) ~= "table" or type(block.id) ~= "number" then return false end
    local module = block.parentModule
    if not module then return true end
    for _, name in ipairs(NON_QUEST_TRACKERS) do
        if module == _G[name] then return false end
    end
    return true
end

-- 清單裡現在有幾筆。標題列的讀數用這個，不要用 C_QuestLog.GetNumQuestWatches()
-- —— 那支只數任務，而標題列講的是**整份清單**（戰役、成就、專業都在裡面）。
--
-- ⚠ 共用 widget pool 的兩支（場景／UI widget）數不到：它們的區塊碰不得（規矩 3）。
--   代價是在副本場景／M+ 裡會少算那一段。可以接受 —— 那時候清單裡本來就多半是
--   場景進度，而不是玩家在追蹤的東西。
function T.CountBlocks()
    local n = 0
    T.EachTracker(function(tracker)
        if not (tracker.IsShown and tracker:IsShown()) then return end
        T.EachBlock(tracker, function() n = n + 1 end)
    end)
    return n
end

-- 走一個區塊的所有目標行。
--
-- ⚠ 欄位是 `usedLines`，**不是 `lines`** —— 對照過 Blizzard_ObjectiveTrackerBlock.lua
--   的 ObjectiveTrackerBlockMixin:GetLine()，它寫的是 `self.usedLines[objectiveKey] = line`。
--   寫成 `lines` 的話這圈永遠是空的，而且**不會報錯**：症狀是「目標文字大小拉了沒反應」。
--   （2026-08-29 踩過一次。當時另一支同類插件也寫 `lines`，但它另外有一段盲掃
--   FontString 的程式碼把行文字順手蓋到了，所以看起來像是有效的 —— 別人怎麼寫
--   不能當根據，要去對原始碼。）
function T.EachLine(block, fn)
    local lines = block and (block.usedLines or block.lines)
    if type(lines) ~= "table" then return end
    for _, line in pairs(lines) do
        if type(line) == "table" then fn(line) end
    end
end

-- 走場景（探究、事件、副本場景）的目標行 —— 規矩 3 的唯一例外。
--
-- 那些行**不是**從共用 widget pool 借的，是 ObjectiveTrackerManager 的行池。池子的鍵
-- 只看模板名稱（Blizzard_SharedXMLBase/Pools.lua 的 GetPoolKey，父層不算），而場景用的
-- ObjectiveTrackerAnimLineTemplate 跟戰役、額外目標、成就、每月活動是**同一池**：同一個框
-- 這一輪在戰役底下、下一輪就被場景拿去用（GetLine 會 SetParent 過去）。
-- 所以「不美化場景的行」從來不成立 —— 結果是看運氣：從戰役回收過來的行帶著我們的字型，
-- 新建的沒有。2026-09-14 玩家回報的就是這個：同一個場景底下一行小一行大，/reload 之後
-- 池子是新的，變成全部沒套到。
--
-- 界線（其餘照舊不碰）：
--   * 只讀 ObjectivesBlock.usedLines 這張表、只把行交出去；不呼叫區塊的任何方法
--     （場景的區塊裡還掛著 widget、法術框、進度條，那些才是規矩 3 真正在擋的）
--   * 行上的文字是秘密值就跳過 —— 對秘密字串 SetFont 會把引擎回填弄掉（□% 那次）
function T.EachScenarioLine(fn)
    local tracker = _G.ScenarioObjectiveTracker
    local block = tracker and tracker.ObjectivesBlock
    local lines = block and block.usedLines
    if type(lines) ~= "table" then return end
    local IsSecret = ns.Secret.IsSecret
    for _, line in pairs(lines) do
        local text = type(line) == "table" and line.Text
        if text and text.GetText and not IsSecret(text:GetText()) then
            fn(line)
        end
    end
end

------------------------------------------------------------
-- 場景的階段框（StageBlock）—— 規矩 3 的第二個例外
--
-- StageBlock 是寫死在 XML 裡的固定子框（parentArray="FixedBlocks"），不是池子來的；
-- 底圖與階段文字都是它自己的 region，暴雪對它們只寫不讀。池子的東西在它的
-- WidgetContainer 底下，那邊照舊不碰 —— 有 widget set 的場景（探究、詛咒浪潮）
-- NormalBG 會被暴雪藏起來，T.StageArt 直接回 nil。
--
-- 界線：只挪 region 的錨點位移。不寫 block 的任何欄位（height／offsetX 是排版在讀的），
-- 不動 block 自己的錨點（後面的區塊錨在它身上）。
------------------------------------------------------------
-- 看 IsShown 不看 IsVisible：要分得出「widget 接手了」（回 nil）與「只是現在沒顯示」
-- （照樣回傳，呼叫端量不到 rect 自己會放棄）—— 前者要把挪過的東西歸位，後者不用
function T.StageArt()
    local tracker = _G.ScenarioObjectiveTracker
    local block = tracker and tracker.StageBlock
    local bg = block and block.NormalBG
    -- block 沒 shown ＝這一輪沒排到它（鑰石／試煉場用的是別的固定區塊）
    if not bg or not tracker.Header or not block:IsShown() or not bg:IsShown() then return end
    return block, bg, tracker.Header
end

-- 場景目標行的水平位置要挪這一個：目標行是一條接一條錨下去的（AddObjective／AddProgressBar
-- 都錨在上一個 region 的 BOTTOMLEFT），第一條錨在 ObjectivesBlock.HeaderText 上。
-- 行本身每次排版都會被重新錨定，挪它就是每一輪跳一下；HeaderText 的 TOPLEFT 暴雪只在
-- 滑入動畫（AdjustSlideAnchor）才重設，平常挪一次就留著。ObjectivesBlock 同樣是固定子框。
function T.ScenarioObjectivesAnchor()
    local tracker = _G.ScenarioObjectiveTracker
    local block = tracker and tracker.ObjectivesBlock
    local fs = block and block.HeaderText
    if fs and fs.GetPoint then return fs end
end

-- 跟著底圖一起走的 region。ThemeOverlay 錨在 NormalBG 上、Name 錨在 Stage 上，會自己跟
local STAGE_FOLLOWERS = { "FinalBG", "GlowTexture", "Stage", "CompleteLabel", "findGroupButton" }

function T.EachStageFollower(block, fn)
    for _, key in ipairs(STAGE_FOLLOWERS) do
        local region = block[key]
        if type(region) == "table" and region.GetPoint then fn(region) end
    end
end

-- 暴雪只在換階段時重設這些錨點（UpdateStageBlock），而且跟我們一樣是「同一個 point 直接
-- SetPoint、不 ClearAllPoints」。所以分辨方式是：讀到的位移不是我們上次設的 ⇒ 暴雪剛重設過，
-- 那組就是新的基準。位移一律從基準算，重跑幾次結果都一樣。
local nudged = T.Flags()   -- region → { x, y = 我們上次設的, baseX, baseY = 暴雪的 }

local function Near(a, b) return math.abs(a - b) < 0.01 end

-- wantPoint：region 有不只一個錨點時指名要哪一個（HeaderText 是 TOPLEFT ＋ RIGHT）
local function ReadPoint(region, wantPoint)
    local IsSecret = ns.Secret.IsSecret
    for i = 1, (wantPoint and region:GetNumPoints() or 1) do
        local point, rel, relPoint, x, y = region:GetPoint(i)
        if not point or IsSecret(point) or IsSecret(x) or IsSecret(y) then return end
        if not wantPoint or point == wantPoint then
            return point, rel, relPoint, x, y
        end
    end
end

function T.RegionBase(region, wantPoint)
    local point, rel, relPoint, x, y = ReadPoint(region, wantPoint)
    if not point then return end
    local st = nudged[region]
    if not (st and st.x and Near(x, st.x) and Near(y, st.y)) then
        st = st or {}
        nudged[region] = st
        st.baseX, st.baseY = x, y
    end
    return st.baseX, st.baseY, point, rel, relPoint
end

function T.NudgeRegion(region, dx, dy, wantPoint)
    local baseX, baseY, point, rel, relPoint = T.RegionBase(region, wantPoint)
    if not baseX then return end
    region:SetPoint(point, rel, relPoint, baseX + dx, baseY + dy)
    local _, _, _, x, y = ReadPoint(region, point)
    local st = nudged[region]
    st.x, st.y = x, y
end

-- 這個子追蹤器現在有沒有東西可顯示。三個訊號取聯集：收合中的區段仍然算「有內容」，
-- 所以不能只看有沒有區塊
function T.TrackerHasContent(tracker)
    if not tracker then return false end
    if tracker.hasContents then return true end
    local found = false
    T.EachBlock(tracker, function() found = true end)
    return found
end

------------------------------------------------------------
-- 剝裝飾貼圖（規矩 4）
--
-- 只掃這一層的 region，不遞迴 —— 子框各自會走到自己的美化流程。
-- keep 是一張「這些貼圖留著」的集合（通常是收合鈕的那幾張）。
------------------------------------------------------------
function T.StripTextures(frame, keep)
    if not frame or not frame.GetRegions then return end
    for _, region in ipairs({ frame:GetRegions() }) do
        if region and region.GetObjectType and region:GetObjectType() == "Texture"
           and region.SetTexture and not (keep and keep[region]) then
            region:SetTexture("")
        end
    end
end

------------------------------------------------------------
-- 延後合併：把一串連續事件收成一次工作
--
-- 掛在暴雪 Update 上的 hook 每次收合都會連開十幾次，而且每一次都是一輪完整排版。
-- 在 hook 裡直接做事等於把暴雪的排版成本記到我們頭上（插件效能表會看到），
-- 所以 hook 只設旗標，真正的工作丟到下一幀。
------------------------------------------------------------
local pending = {}
function T.Defer(key, fn, delay)
    if pending[key] then return end
    pending[key] = true
    C_Timer.After(delay or 0, function()
        pending[key] = nil
        xpcall(fn, ns.ReportError)
    end)
end

------------------------------------------------------------
-- 顯示與隱藏
--
-- ObjectiveTrackerFrame 在編輯模式裡被錨到快捷列時會變成**受保護框**，那時候
-- 戰鬥中的 Show / Hide / SetParent 全部會被封鎖（而且是靜默的，不是 Lua 錯誤）。
-- 沒被錨的時候它不受保護，戰鬥中照樣動得了。
--
-- 所以走哪條路是問出來的、不是猜的：IsProtected() 直接回答這個問題。
--   * 動得了 parent → 掛到隱藏容器底下。子框連滑鼠都收不到，最乾淨。
--   * 動不了     → 只能 alpha 0，而 alpha 0 的框**滑鼠還在**：滑過去照樣跳工具
--                  提示、照樣點得到。所以同時放一塊擋滑鼠的板子上去。
--
-- 兩條路都走過之後，PLAYER_REGEN_ENABLED 再收斂一次到 parent 路線。
------------------------------------------------------------
-- 隱藏容器跟 UIParent 等大：追蹤器的錨點如果是相對「父層」而不是具名 UIParent，
-- 換父層就會連位置一起跑掉（我們的標題列與背景是錨在追蹤器上的，跟著一起飛）。
-- 兩種寫法在這裡解出來的矩形一樣。
local hiddenParent = CreateFrame("Frame", "MiliUIQuestTrackerHidden", UIParent)
hiddenParent:SetAllPoints(UIParent)
hiddenParent:Hide()

-- 擋滑鼠的板子。只在「戰鬥中而且動不了 parent」那條路上出現
local mouseBlocker = CreateFrame("Frame", nil, UIParent)
mouseBlocker:EnableMouse(true)
mouseBlocker:Hide()

local wantHidden = false

-- 現在能不能動追蹤器的父層／錨點。
--
-- 編輯模式把它錨到快捷列時它會變成受保護框，那時候戰鬥中的 SetParent／SetPoint
-- 都會被**靜默**封鎖（不是 Lua 錯誤，你只會看到「沒反應」）。沒被錨的時候不受保護，
-- 戰鬥中照樣動得了 —— 所以這是問出來的，不是「戰鬥中一律不准」。
function T.CanReposition()
    local otf = T.OTF()
    if not otf then return false end
    if not InCombatLockdown() then return true end
    return not otf:IsProtected()
end

local function CanTouchParent(otf)
    if not InCombatLockdown() then return true end
    return not otf:IsProtected()
end

local function Reconcile()
    local otf = T.OTF()
    if not otf then return end

    -- 問實際狀態，不要另外記一個旗標：戰鬥中那條路根本沒動到 parent，
    -- 記旗標就會出現「以為換過了、其實沒有」的組合
    local parentedAway = (otf:GetParent() == hiddenParent)

    if CanTouchParent(otf) then
        if parentedAway ~= wantHidden then
            otf:SetParent(wantHidden and hiddenParent or UIParent)
        end
        -- alpha 只是戰鬥中的備援，換完 parent 一律歸位，
        -- 否則上一輪留下的 0 會讓展開之後整個追蹤器還是看不見
        otf:SetAlpha(1)
        mouseBlocker:Hide()
        return
    end

    -- 動不了 parent。已經掛在隱藏容器底下的話，alpha 救不回來（父層是隱藏的），
    -- 戰鬥中就是展不開 —— 這是客觀限制，不假裝有做到，也不要在這裡疊補救措施
    if parentedAway then
        mouseBlocker:Hide()
        return
    end

    otf:SetAlpha(wantHidden and 0 or 1)
    if wantHidden then
        -- alpha 0 的框滑鼠還在：滑過去照樣跳工具提示、照樣點得到。
        -- 蓋一塊自己的板子把滑鼠吃掉（不是暴雪的框，零風險）
        mouseBlocker:ClearAllPoints()
        mouseBlocker:SetAllPoints(otf)
        mouseBlocker:SetFrameStrata(otf:GetFrameStrata() or "MEDIUM")
        mouseBlocker:SetFrameLevel((otf:GetFrameLevel() or 0) + 50)
        mouseBlocker:Show()
    else
        mouseBlocker:Hide()
    end
end
T.Reconcile = Reconcile

function T.SetHidden(hide)
    hide = hide and true or false
    if hide == wantHidden then return end
    wantHidden = hide
    Reconcile()
    ns.Fire("TrackerHiddenChanged", hide)
end

function T.IsHidden() return wantHidden end

------------------------------------------------------------
-- 追蹤器的 parent 不是我們一個人的
--
-- 暴雪有三個地方會直接寫它，而且都不看現在掛在誰底下：
--   * ManagedFrameContainerMixin:UpdateFrame  —— SetParent(RightManagedFrameContainer)
--   * EditModeSystemMixin:ApplySystemAnchor   —— 預設位置走上面那支（AddManagedFrame 的閘
--     是 IsShown 不是 IsVisible，掛在隱藏容器底下照樣通過）
--   * EditModeSystemMixin:BreakFromFrameManager —— 拖過位置的走 SetParent(UIParent)
-- 也就是**每一次編輯模式套用版面**（過圖、換專精、改版面）都會把摺起來的清單拉回畫面上，
-- 而我們還以為它摺著：標題列的箭頭是「已摺疊」、清單卻開著；等下一次脫離戰鬥
-- Reconcile 才又把它收走。2026-09-18 玩家回報的「進探究整個消失」就是這一段 ——
-- 過圖時清單彈出來、打完第一波怪又不見。
--
-- Reconcile 本來就是「問實際狀態再收斂」，缺的只是暴雪動手的那一刻沒有人叫它。
-- 這裡補上那個觸發點，不另外記狀態、也不在 hook 裡直接 SetParent（那會在暴雪的
-- AddManagedFrame 跑到一半時重入它的 OnHide → RemoveManagedFrame）。
-- hook 裡只排一次下一幀的工作；我們自己的 SetParent 也會進來，但那時實際狀態
-- 跟 wantHidden 一致，Reconcile 什麼都不會做，不會成迴圈。
------------------------------------------------------------
local reclaimCount, reclaimLast = 0, nil

do
    local otf = T.OTF()
    if otf then
        hooksecurefunc(otf, "SetParent", function(_, parent)
            if not wantHidden or parent == hiddenParent then return end
            reclaimCount = reclaimCount + 1
            reclaimLast = GetTime()
            T.Defer("reconcileParent", Reconcile)
        end)
    end
end

-- /mquest debug 用：把隱藏機制走到哪一步攤開來。前三個值分別對應上面三條路；
-- reclaim 是暴雪在我們摺著的時候把 parent 拿回去的次數
function T.DiagState()
    local otf = T.OTF()
    return {
        wantHidden   = wantHidden,
        parentedAway = (otf and otf:GetParent() == hiddenParent) or false,
        blockerShown = mouseBlocker:IsShown(),
        reclaimCount = reclaimCount,
        reclaimLast  = reclaimLast,
    }
end

-- 追蹤器現在是不是真的看得見。畫背景／標題列的模組要問這個，不要各自
-- 用 IsShown() 再拼一套 —— 那樣戰鬥中走 alpha 那條路時就會判斷錯
function T.IsVisible()
    local otf = T.OTF()
    if not otf then return false end
    if wantHidden then return false end
    if not otf:IsShown() then return false end
    if otf:GetAlpha() <= 0 then return false end
    return true
end

do
    local regen = CreateFrame("Frame")
    regen:RegisterEvent("PLAYER_REGEN_ENABLED")
    regen:SetScript("OnEvent", function()
        -- 戰鬥中沒能落地的那半套在這裡收斂
        Reconcile()
        ns.Fire("CombatEnded")
    end)
end
