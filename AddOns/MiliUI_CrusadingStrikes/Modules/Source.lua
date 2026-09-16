------------------------------------------------------------
-- 來源：暴雪冷卻管理器「追蹤的量條」長條
--
-- 為什麼是這條路（其他四條都查證過走不通，別再試）：
--   * 戰鬥記錄 SWING_DAMAGE —— 12.x 插件不能註冊 COMBAT_LOG_EVENT_UNFILTERED。
--   * UNIT_SPELLCAST_SUCCEEDED —— 近戰普攻不派送。
--   * GetPlayerAuraBySpellID → GetAuraDuration → SetTimerDuration —— GetAuraDuration 是
--     AllowedWhenUntainted，光環受限時（戰鬥／首領戰／M+／PvP）污染端呼叫直接拋錯，
--     而這個 buff 每揮一刀就刷新一次，等於每刀都要在戰鬥中重 arm。
--   * 自建 duration 物件／自己算 expirationTime - GetTime() —— 前者餵不進秘密值，
--     後者是對秘密值做算術。
--
-- 走得通的是：暴雪自己的 `BuffBarCooldownViewer` item frame 是 **untainted 程式**
-- 在每幀往 `item.Bar` 餵 SetMinMaxValues / SetValue。那些值戰鬥中是秘密，但
-- **原生 StatusBar 之間互傳是允許的**，我們只當傳遞者（見 Modules/Bar.lua）。
--
-- 這支的職責只有一件：找出「哪一個 item frame 是征戰聖擊」，並把它交出去。
-- 前置條件在玩家端：冷卻管理器要啟用，且征戰聖擊要在「追蹤的量條」列裡
-- （設定頁會把這個狀態亮出來，見 Options/Tab_General.lua）。
------------------------------------------------------------
local _, ns = ...

local S = ns.Secret

ns.Source = {}
local Source = ns.Source

-- 征戰聖擊在不同天賦／覆寫下用過的法術編號，全部視為同一件事。
-- CDM 的 cooldownInfo 可能填其中任一個，所以是一張集合不是單一值。
local CRUSADING_STRIKES_IDS = {
    [404542]  = true,
    [406833]  = true,
    [408385]  = true,
    [1226662] = true,
    [1307499] = true,
}
Source.SPELL_IDS = CRUSADING_STRIKES_IDS

local trackedItem, trackedID
local lastScanFailed = false

------------------------------------------------------------
-- 比對
--
-- ⚠ 秘密值不能當 table 的 key —— 每個編號查表之前都要先過秘密閘，
--   否則在戰鬥中就是一句 "cannot be indexed with secret keys"。
------------------------------------------------------------
local function IsKnownSpellID(value)
    if value == nil or S.IsSecret(value) then return false end
    return CRUSADING_STRIKES_IDS[value] == true
end

local function InfoMatches(info)
    if type(info) ~= "table" then return false end
    if S.IsSecret(info) then return false end
    if IsKnownSpellID(info.spellID)
        or IsKnownSpellID(info.overrideSpellID)
        or IsKnownSpellID(info.overrideTooltipSpellID) then
        return true
    end
    local linked = info.linkedSpellIDs
    if type(linked) == "table" and not S.IsSecret(linked) then
        for _, spellID in ipairs(linked) do
            if IsKnownSpellID(spellID) then return true end
        end
    end
    return false
end

local function ItemMatches(item)
    if not item then return false end
    local cooldownID = item.cooldownID
    if cooldownID == nil or S.IsSecret(cooldownID) then return false end

    local getInfo = C_CooldownViewer and C_CooldownViewer.GetCooldownViewerCooldownInfo
    if getInfo then
        local info = S.SafeCall(getInfo, cooldownID)
        if InfoMatches(info) then return true end
    end

    -- 備援：有些版本的 item frame 自己給得出光環的法術編號
    if item.GetAuraSpellID then
        local spellID = S.SafeCall(item.GetAuraSpellID, item)
        if IsKnownSpellID(spellID) then return true end
    end
    return false
end

-- ⚠ 不要問 item:IsActive()：它是暴雪從光環的到期時間算出來的，**戰鬥中是秘密布林**
--   （2026-09-17 實機：一進戰鬥條出現 0.幾秒就消失 —— 秘密布林被當成 false，0.5 秒輪詢
--   一驗就把追蹤丟掉）。暴雪對非 active 的 item 會 SetShown(false)，所以「看得見」是等價
--   而且永遠明文的訊號。用 IsVisible 而不是 IsShown：整個 viewer 被藏起來時 item 的
--   OnUpdate 不跑、值會凍住，那時一樣不該鏡射。我們自己壓的 alpha 0 不影響 IsVisible。
function Source.IsItemActive(item)
    if not item or not item.IsVisible then return false end
    return item:IsVisible() and true or false
end

------------------------------------------------------------
-- 掃描
------------------------------------------------------------
local function Clear()
    trackedItem, trackedID = nil, nil
end

local function Scan()
    Clear()
    local viewer = _G.BuffBarCooldownViewer
    local pool = viewer and viewer.itemFramePool
    if not pool or not pool.EnumerateActive then
        lastScanFailed = true
        return
    end
    lastScanFailed = false

    -- 正在跑的那個優先；只是「在清單裡但沒亮」的留成備援，這樣玩家看設定頁時
    -- 也能得到「有找到，只是現在沒上 buff」這個答案
    local fallback
    for item in pool:EnumerateActive() do
        if ItemMatches(item) then
            if Source.IsItemActive(item) then
                trackedItem, trackedID = item, item.cooldownID
                return
            end
            fallback = fallback or item
        end
    end
    if fallback then
        trackedItem, trackedID = fallback, fallback.cooldownID
    end
end

-- 手上這個還算不算數：框架會被回收再發給別的法術，cooldownID 變了就是換人了。
-- ⚠ 戰鬥中 cooldownID 可能讀不到（秘密）：那時**當作沒換**，不能當作換了 ——
--   當作換了會去重掃，而重掃在戰鬥中什麼都比對不到，追蹤就這樣掉了。
--   框被重發只發生在追蹤清單改變（換天賦／專精），不會在戰鬥中發生；能讀時輪詢會再驗。
local function StillCurrent()
    if not trackedItem then return false end
    local id = trackedItem.cooldownID
    if id == nil then return false end
    if S.IsSecret(id) or S.IsSecret(trackedID) then return true end
    return id == trackedID
end

function Source.GetTrackedItem()
    if not StillCurrent() then return nil end
    return trackedItem
end

------------------------------------------------------------
-- 隱藏暴雪那一條（使用者要的：其他量條有用，只有這條是重複的）
--
-- ⚠ 只壓 alpha，**不能 Hide**：暴雪是在那條的 OnUpdate 裡更新值，藏起來的框
--   收不到 OnUpdate，我們鏡射的就凍住了。alpha 0 的框照樣在跑。
-- ⚠ 每次都重設而不是「設過就好」：這個框是從池子借來的，會被回收再發給別的法術
--   （所以 cooldownID 變了要把 alpha 還回去），別的插件的淡出功能也可能整批改 alpha。
--   0.5 秒的輪詢跟著重設一次就夠，這只是一個 setter。
-- 編輯模式時還原：玩家在排版時要看得到那條在哪。
------------------------------------------------------------
local dimmedItem

local function EditModeActive()
    local f = EditModeManagerFrame
    return f and f.IsEditModeActive and f:IsEditModeActive() and true or false
end

function Source.ApplyDim()
    local want
    if ns.db and ns.db.enabled and ns.db.hideBlizzardBar and ns.isPaladin
        and not EditModeActive() and StillCurrent() then
        want = trackedItem
    end
    if dimmedItem and dimmedItem ~= want then
        dimmedItem:SetAlpha(1)
        dimmedItem = nil
    end
    if want then
        want:SetAlpha(0)
        dimmedItem = want
    end
end

function Source.IsDimmed()
    return dimmedItem ~= nil
end

------------------------------------------------------------
-- 事件與輪詢
--
-- 事件負責「清單可能變了」的時刻；輪詢只做便宜的驗證（框還在嗎、還亮著嗎），
-- 不在乎那 0.5 秒的延遲 —— 條要不要顯示是 Bar 每幀自己問 IsItemActive()（IsVisible），
-- 這裡只管「指到的是不是還是同一個框」。**不要用每幀 OnUpdate 掃池子。**
------------------------------------------------------------
local driver = CreateFrame("Frame")
local EVENTS = {
    "PLAYER_ENTERING_WORLD",
    "SPELLS_CHANGED",
    "PLAYER_SPECIALIZATION_CHANGED",
    "TRAIT_CONFIG_UPDATED",
    "COOLDOWN_VIEWER_TABLE_HOTFIXED",
}

-- ⚠ 只在「沒有追蹤對象」或「對象換人了」時重掃，**item 沒亮不重掃**：戰鬥中目標死掉、
--   buff 掉了那一刻 item 會藏起來，這時重掃比對不到秘密 ID，等於自己把追蹤丟掉，
--   下一個目標要等脫戰才有條。條亮不亮是 Bar 每幀自己看 IsItemActive，跟這裡無關。
local function Validate()
    if not StillCurrent() then
        Scan()
    end
    Source.ApplyDim()
end

function Source.Start()
    for _, e in ipairs(EVENTS) do
        pcall(driver.RegisterEvent, driver, e)
    end
    driver:SetScript("OnEvent", function()
        Clear()
        Scan()
        Source.ApplyDim()
    end)
    ns.poll.Add("source", 0.5, Validate)
    Scan()
    Source.ApplyDim()
end

function Source.Stop()
    driver:UnregisterAllEvents()
    driver:SetScript("OnEvent", nil)
    ns.poll.Remove("source")
    Clear()
    Source.ApplyDim()   -- 沒有追蹤對象了 → 把暴雪那條的 alpha 還回去
end

function Source.Rescan()
    Clear()
    Scan()
    Source.ApplyDim()
end

------------------------------------------------------------
-- 設定頁的狀態列用的診斷（全部明文，任何可能是秘密的值都只回「有／沒有」）
------------------------------------------------------------
-- 征戰聖擊有沒有被加進「追蹤的量條」。戰鬥中 cooldownInfo 的欄位可能是秘密值，
-- 比對不了，所以那時候直接回 "combat" 讓設定頁說「戰鬥中無法檢查」。
local function TrackedBarListed()
    if InCombatLockdown() then return "combat" end
    local cv = C_CooldownViewer
    local cat = Enum and Enum.CooldownViewerCategory and Enum.CooldownViewerCategory.TrackedBar
    if not cv or not cv.GetCooldownViewerCategorySet or cat == nil then return "unknown" end
    local ids = S.SafeCall(cv.GetCooldownViewerCategorySet, cat, true)
    if type(ids) ~= "table" then return "unknown" end
    for _, cooldownID in ipairs(ids) do
        if not S.IsSecret(cooldownID) then
            local info = S.SafeCall(cv.GetCooldownViewerCooldownInfo, cooldownID)
            if InfoMatches(info) then return "yes" end
        end
    end
    return "no"
end

function Source.Status()
    local item = Source.GetTrackedItem()
    return {
        isPaladin  = ns.isPaladin,
        platynator = C_AddOns.IsAddOnLoaded("Platynator") and true or false,
        cdmEnabled = GetCVar("cooldownViewerEnabled") == "1",
        viewer     = _G.BuffBarCooldownViewer ~= nil and not lastScanFailed,
        listed     = TrackedBarListed(),
        item       = item ~= nil,
        active     = Source.IsItemActive(item),
        dimmed     = Source.IsDimmed(),
        secretID   = trackedItem ~= nil and S.IsSecret(trackedItem.cooldownID),
    }
end
