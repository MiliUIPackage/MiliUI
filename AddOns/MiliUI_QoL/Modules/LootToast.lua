------------------------------------------------------------
-- 戰利品通知過濾（全域 MiliUI_LootToast）
--
-- 拾取時跳出的「你獲得了」通知，依種類（團隊擲骰／拾取物品／貨幣／金錢／裝備升級）
-- 與品質決定要不要顯示。
--
-- 暴雪原始碼（12.1.5，Blizzard_FrameXML/Mainline/AlertFrames.lua 的 AlertFrameMixin:OnEvent）：
--   LOOT_ITEM_ROLL_WON       → LootAlertSystem（團隊擲骰贏得）
--   SHOW_LOOT_TOAST          → typeIdentifier 分流："item" → LootAlertSystem、"money" →
--                              MoneyWonAlertSystem、"currency"（只在 isPersonal）→ LootAlertSystem、
--                              "honor" → HonorAwardedAlertSystem
--   SHOW_LOOT_TOAST_UPGRADE  → LootUpgradeAlertSystem
-- 佇列 API 沒有「否決單一通知」的掛點（SetCanShowMoreConditionFunc 不帶參數、回 false 只會
-- 排隊；setUpFunction 是建子系統時存起來的值，勾全域攔不到），所以做法是：
--
--   攔截 → 過濾 → 轉交暴雪自己的分派（不自己重建通知的參數）
--
-- 1. 只拿下「用得到的」事件（那個事件底下至少有一類設成隱藏），而且只拿
--    AlertFrame:IsEventRegistered(ev) 當下為 true 的 —— 已經被別的插件拿走的不搶
--    （Plumber 的戰利品介面會解掉 SHOW_LOOT_TOAST）。拿下的記在 taken[ev]。
-- 2. 要顯示就轉交 AlertFrame:OnEvent(ev, ...)。AlertFrames.xml 的 OnEvent 是
--    `<OnEvent method="OnEvent"/>`，也就是 AlertFrameMixin.OnEvent 本人，直接叫方法。
-- 3. 功能關掉或全部類別都顯示：taken 裡的事件還給 AlertFrame。**預設不碰 AlertFrame 任何東西。**
--
-- ⚠ 不寫暴雪框的任何欄位（[[wow-121-addon-code-in-secure-stack]] 入口 5）：對 AlertFrame
--   只有 Unregister／RegisterEvent、IsEventRegistered 與呼叫它的 OnEvent。
-- ⚠ 失效方向一律「顯示」：品質拿不到（物品還沒快取）、參數是秘密值、型別不對，都直接轉交。
--   藏錯是功能壞掉，多顯示一張只是回到暴雪預設。
-- ⚠ 轉交出去的通知走的是暴雪自己的流程，MiliUI_Skin 掛在 AlertFrame_ShowNewAlert 的配方照樣套得到。
------------------------------------------------------------
local _, ns = ...

local LT = {}
ns.LootToast = LT
MiliUI_LootToast = LT

local issecret = ns.Secret.IsSecret

local EVENTS = { "LOOT_ITEM_ROLL_WON", "SHOW_LOOT_TOAST", "SHOW_LOOT_TOAST_UPGRADE" }

-- 每個事件管到哪幾類（決定「用不用得到」這個事件）
local EVENT_CATS = {
    LOOT_ITEM_ROLL_WON      = { "rollWon" },
    SHOW_LOOT_TOAST         = { "item", "currency", "money" },
    SHOW_LOOT_TOAST_UPGRADE = { "upgrade" },
}
LT.EVENTS = EVENTS
LT.EVENT_CATS = EVENT_CATS

LT.CATEGORY_NAMES = {
    rollWon  = "團隊擲骰獲得",
    item     = "拾取物品",
    currency = "貨幣",
    money    = "金錢",
    upgrade  = "裝備升級",
}

local taken = {}
local listener = CreateFrame("Frame")
local started = false

------------------------------------------------------------
-- 除錯紀錄：最近 10 筆，只存字串（不存秘密值；戰鬥中掛勾裡 print 也可能被吞，
-- 所以事件當下只記、/mqol debug loot 時再印）
------------------------------------------------------------
local LOG_MAX = 10
local log = {}
local function Log(cat, quality, verdict)
    log[#log + 1] = ("%s  %s  品質=%s  %s"):format(date("%H:%M:%S"), cat, quality, verdict)
    if #log > LOG_MAX then tremove(log, 1) end
end

local function Cfg()
    return ns.db and ns.db.lootToast
end

local function EventWanted(c, ev)
    if not (c and c.enabled) then return false end
    for _, cat in ipairs(EVENT_CATS[ev]) do
        if c.hide[cat] then return true end
    end
    return false
end

local function AlertRegistered(ev)
    return AlertFrame and AlertFrame.IsEventRegistered and AlertFrame:IsEventRegistered(ev) and true or false
end

local function Release(ev)
    listener:UnregisterEvent(ev)
    taken[ev] = nil
    if AlertFrame and not AlertRegistered(ev) then
        AlertFrame:RegisterEvent(ev)
    end
end

-- 設定一改就呼叫；叫幾次都沒有副作用
function LT.Apply()
    if not started then return end
    local c = Cfg()
    for _, ev in ipairs(EVENTS) do
        local want = EventWanted(c, ev)
        if want and not taken[ev] then
            if AlertRegistered(ev) then
                AlertFrame:UnregisterEvent(ev)
                listener:RegisterEvent(ev)
                taken[ev] = true
            end
        elseif not want and taken[ev] then
            Release(ev)
        end
    end
end

function LT.IsTaken(ev)
    return taken[ev] == true
end

-- 這個事件是不是被別的插件拿走了（AlertFrame 沒註冊、也不在我們手上）
function LT.IsForeign(ev)
    if not AlertFrame then return false end
    return not taken[ev] and not AlertRegistered(ev)
end

------------------------------------------------------------
-- 品質：事件 payload 沒有品質，要從連結推。拿不到一律回 nil（＝顯示）
------------------------------------------------------------
local function ItemQuality(link)
    if link == nil or issecret(link) or type(link) ~= "string" then return nil end
    if not (C_Item and C_Item.GetItemQualityByID) then return nil end
    local ok, q = pcall(C_Item.GetItemQualityByID, link)
    if not ok or issecret(q) or type(q) ~= "number" then return nil end
    return q
end

local function CurrencyQuality(link)
    if link == nil or issecret(link) or type(link) ~= "string" then return nil end
    if not (C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfoFromLink) then return nil end
    local ok, info = pcall(C_CurrencyInfo.GetCurrencyInfoFromLink, link)
    if not ok or type(info) ~= "table" then return nil end
    local q = info.quality
    if issecret(q) or type(q) ~= "number" then return nil end
    return q
end

-- 回傳 show, 品質字串, 判定字串
local function Decide(cat, link)
    local c = Cfg()
    if not (c and c.enabled and c.hide[cat]) then return true, "-", "顯示（沒有隱藏這類）" end
    if cat == "money" then return false, "-", "隱藏" end

    local kq = tonumber(c.keepQuality) or 0
    if kq <= 0 then return false, "-", "隱藏" end

    local q
    if cat == "currency" then q = CurrencyQuality(link) else q = ItemQuality(link) end
    if q == nil then return true, "?", "顯示（品質拿不到）" end
    if q >= kq then return true, tostring(q), "顯示（品質例外）" end
    return false, tostring(q), "隱藏"
end

-- 把事件交回暴雪自己的分派。AlertFrames.xml：<OnEvent method="OnEvent"/>
local function Forward(ev, ...)
    local fn = AlertFrame and AlertFrame.OnEvent
    if type(fn) == "function" then
        fn(AlertFrame, ev, ...)
        return
    end
    local script = AlertFrame and AlertFrame:GetScript("OnEvent")
    if script then script(AlertFrame, ev, ...) end
end

listener:SetScript("OnEvent", function(self, ev, ...)
    if not taken[ev] then return end
    -- 別的插件把事件還給了 AlertFrame（例如 Plumber 關掉戰利品介面時會 RegisterEvent 回去）：
    -- 暴雪這次已經自己收到了，再轉交就是兩張。放手，下次 Apply 再判斷要不要拿。
    if AlertRegistered(ev) then
        self:UnregisterEvent(ev)
        taken[ev] = nil
        return
    end

    local cat, link
    if ev == "LOOT_ITEM_ROLL_WON" then
        cat, link = "rollWon", (...)
    elseif ev == "SHOW_LOOT_TOAST_UPGRADE" then
        -- baseQuality（第 5 個）是升級前的品質，所以一樣從連結推
        cat, link = "upgrade", (...)
    elseif ev == "SHOW_LOOT_TOAST" then
        local typeIdentifier, itemLink, _, _, _, isPersonal = ...
        if issecret(typeIdentifier) or type(typeIdentifier) ~= "string" then
            cat = nil
        elseif typeIdentifier == "item" then
            cat = "item"
        elseif typeIdentifier == "money" then
            cat = "money"
        elseif typeIdentifier == "currency" and not issecret(isPersonal) and isPersonal then
            cat = "currency"
        end
        -- "honor"、非個人的貨幣、不認得的 typeIdentifier：一律原樣轉交
        link = itemLink
    end

    if not cat then
        Log("其他", "-", "轉交（不分類）")
        Forward(ev, ...)
        return
    end

    local show, qText, verdict = Decide(cat, link)
    Log(cat, qText, verdict)
    if show then Forward(ev, ...) end
end)

------------------------------------------------------------
-- /mqol debug loot
------------------------------------------------------------
function LT.Debug()
    local c = Cfg() or {}
    ns.Print("戰利品通知過濾：enabled=" .. tostring(c.enabled)
        .. "  keepQuality=" .. tostring(c.keepQuality) .. "  started=" .. tostring(started))
    for _, ev in ipairs(EVENTS) do
        local state = taken[ev] and "|cff33ff66由本插件接手|r"
            or (LT.IsForeign(ev) and "|cffff9900被其他插件拿走|r" or "暴雪自己處理")
        print("  " .. ev .. "：" .. state)
    end
    local parts = {}
    for _, cat in ipairs({ "rollWon", "item", "currency", "money", "upgrade" }) do
        parts[#parts + 1] = cat .. "=" .. ((c.hide and c.hide[cat]) and "隱藏" or "顯示")
    end
    print("  " .. table.concat(parts, "  "))
    if #log == 0 then
        print("  （還沒有紀錄）")
    else
        for _, line in ipairs(log) do print("  " .. line) end
    end
end

------------------------------------------------------------
-- 啟動時機：第一次 PLAYER_ENTERING_WORLD 之後再等一秒。
-- Plumber 的戰利品介面在它自己的第一次 PLAYER_ENTERING_WORLD 才解掉 AlertFrame 的
-- SHOW_LOOT_TOAST；比它早拿的話，它的 UnregisterEvent 落空、自己又註冊一份，
-- 我們再轉交一次就變成兩邊都跳。晚一點拿，「已經被別人拿走就不搶」才判斷得準。
------------------------------------------------------------
ns.RegisterCallback("Init", "LootToast", function()
    local waiter = CreateFrame("Frame")
    waiter:RegisterEvent("PLAYER_ENTERING_WORLD")
    waiter:SetScript("OnEvent", function(self)
        self:UnregisterAllEvents()
        C_Timer.After(1, function()
            started = true
            LT.Apply()
        end)
    end)
end)
