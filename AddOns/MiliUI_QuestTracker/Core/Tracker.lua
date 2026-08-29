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
