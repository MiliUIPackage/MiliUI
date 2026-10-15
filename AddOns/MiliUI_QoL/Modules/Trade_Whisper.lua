------------------------------------------------------------
-- MiliUI_QoL: 交易完成後密語對方明細（2026-10 從本體 MiliUI/Enhance 搬來）
--
-- 交易成功的那一刻，把「給了什麼、收到什麼、金額」整理成一則（太長就拆成幾則）密語
-- 送給交易對象，雙方都留一份聊天記錄可以對帳。物品用連結，對方點得開。
-- 預設關閉（這是替玩家對外發訊息的功能，要玩家自己打開）。
-- 讀寫於 MiliUI_QoL_DB.tradeWhisper（boolean）。
--
-- ## 流程
--
--   TRADE_SHOW          記下交易對象（"NPC" 這個 unit token 在交易期間就是對方）
--   *_ITEM_CHANGED／TRADE_MONEY_CHANGED／TRADE_ACCEPT_UPDATE
--                       每次都重拍一張快照。成交訊息到的時候交易欄已經清空了，
--                       只能用成交前最後一張
--   UI_INFO_MESSAGE     訊息是 ERR_TRADE_COMPLETE 才送；一次交易只送一次
--   TRADE_CLOSED／TRADE_REQUEST_CANCEL
--                       取消就丟掉快照；成交訊息有時晚於 TRADE_CLOSED 到，
--                       所以 CLOSED 只標記時間、2 秒內的成交仍然算
--
-- ## 12.x 限制
--
-- 首領戰／M+／PvP 期間插件不能送聊天（C_ChatInfo.InChatMessagingLockdown()，
-- .claude/notes/wow-12x-addon-restrictions.md）。那時改成只在自己的聊天框印出明細，
-- 不硬送（硬送會彈封鎖對話框）。對方名字或物品資料讀到秘密值也一樣只印不送。
------------------------------------------------------------
local _, ns = ...
if ns.legacyCore then return end

local LOCALE = GetLocale()
local T = ({
    zhTW = { head = "交易完成：", give = "給予", get = "收到", sep = "、", group = "；",
             local_ = "聊天受限，交易明細只印在這裡：" },
    zhCN = { head = "交易完成：", give = "给予", get = "收到", sep = "、", group = "；",
             local_ = "聊天受限，交易明细只显示在这里：" },
})[LOCALE] or { head = "Trade complete: ", give = "gave", get = "received", sep = ", ", group = "; ",
                local_ = "Chat is restricted; trade summary shown locally only:" }

local SendChat = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
local function ChatLocked()
    return C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown() and true or false
end

local MAX_BYTES = 240       -- 一則聊天上限 255，留一點餘裕
local TRADE_SLOTS = 6       -- 第 7 格是「不交易」的附魔欄，不算轉手

-- ns.db（＝MiliUI_QoL_DB）在自己的 ADDON_LOADED 才有；那之前一律當關閉
local function IsEnabled()
    return ns.db and ns.db.tradeWhisper == true
end

local function Plain(v)
    return not (issecretvalue and issecretvalue(v))
end

local trade         -- { target, given, received, valid, closedAt }
local ev = CreateFrame("Frame")

-- 一邊的交易欄 → { "連結×數量", …, "金額" }；讀到不能用的值就回 nil（整筆不送）
local function Side(linkFn, infoFn, moneyFn)
    local out = {}
    for slot = 1, TRADE_SLOTS do
        local name, _, count = infoFn(slot)
        if not Plain(name) or not Plain(count) then return nil end
        if name then
            local link = linkFn(slot)
            if not Plain(link) then return nil end
            local text = (type(link) == "string" and link ~= "") and link or ("[" .. name .. "]")
            if type(count) == "number" and count > 1 then text = text .. "×" .. count end
            out[#out + 1] = text
        end
    end
    local money = moneyFn()
    if not Plain(money) then return nil end
    money = tonumber(money) or 0
    if money > 0 then out[#out + 1] = C_CurrencyInfo.GetCoinText(money, " ") end
    return out
end

local function Snapshot()
    if not trade then return end
    local given = Side(GetTradePlayerItemLink, GetTradePlayerItemInfo, GetPlayerTradeMoney)
    local received = Side(GetTradeTargetItemLink, GetTradeTargetItemInfo, GetTargetTradeMoney)
    trade.valid = given ~= nil and received ~= nil
    if trade.valid then trade.given, trade.received = given, received end
end

-- 把兩邊組成一到多則訊息，每則不超過 MAX_BYTES
local function Compose(t)
    local messages, line, current = {}, T.head, nil
    local function Add(label, entry)
        local piece
        if current == label then
            piece = T.sep .. entry
        else
            piece = (current and T.group or "") .. label .. " " .. entry
        end
        if #line + #piece > MAX_BYTES and line ~= T.head then
            messages[#messages + 1] = line
            line, piece = T.head, label .. " " .. entry
        end
        line, current = line .. piece, label
    end
    for _, e in ipairs(t.given) do Add(T.give, e) end
    for _, e in ipairs(t.received) do Add(T.get, e) end
    if current then messages[#messages + 1] = line end
    return messages
end

local function Deliver(t)
    if #t.given == 0 and #t.received == 0 then return end
    local messages = Compose(t)
    if ChatLocked() or not t.target then
        print("|cff33B8FF[MiliUI]|r " .. T.local_)
        for _, m in ipairs(messages) do print("  " .. m) end
        return
    end
    -- 多則訊息間隔 0.4 秒送，避免被伺服器的洪水保護吃掉
    for i, m in ipairs(messages) do
        C_Timer.After((i - 1) * 0.4, function()
            if ChatLocked() then
                print("|cff33B8FF[MiliUI]|r " .. m)
                return
            end
            SendChat(m, "WHISPER", nil, t.target)
        end)
    end
end

ev:SetScript("OnEvent", function(_, event, ...)
    if event == "TRADE_SHOW" then
        trade = nil
        if UnitIsPlayer("NPC") ~= true then return end
        local target = GetUnitName("NPC", true)
        if not Plain(target) or type(target) ~= "string" or target == "" then
            target = nil    -- 讀不到名字：照樣記帳，成交時只印在本地
        end
        trade = { target = target }
        Snapshot()
    elseif event == "TRADE_REQUEST_CANCEL" then
        trade = nil
    elseif event == "TRADE_CLOSED" then
        if trade and not trade.closedAt then
            local t = trade
            t.closedAt = GetTime()
            C_Timer.After(2, function() if trade == t then trade = nil end end)
        end
    elseif event == "UI_INFO_MESSAGE" then
        local _, message = ...
        if not Plain(message) or message ~= ERR_TRADE_COMPLETE then return end
        local t = trade
        trade = nil     -- 同一筆只送一次，就算客戶端重複發訊息
        if t and t.valid and IsEnabled() then Deliver(t) end
    elseif trade and not trade.closedAt then
        Snapshot()
    end
end)

local EVENTS = {
    "TRADE_SHOW", "TRADE_CLOSED", "TRADE_REQUEST_CANCEL", "TRADE_ACCEPT_UPDATE",
    "TRADE_PLAYER_ITEM_CHANGED", "TRADE_TARGET_ITEM_CHANGED", "TRADE_MONEY_CHANGED",
    "PLAYER_TRADE_MONEY", "UI_INFO_MESSAGE",
}

local function Sync()
    trade = nil
    ev:UnregisterAllEvents()
    if IsEnabled() then
        for _, e in ipairs(EVENTS) do ev:RegisterEvent(e) end
    end
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    Sync()
end)

------------------------------------------------------------
-- 對外（給 Options/Controls.lua 用）
------------------------------------------------------------
ns.TradeWhisper = {
    IsEnabled = IsEnabled,
    SetEnabled = function(v)
        if not ns.db then return end
        ns.db.tradeWhisper = v and true or false
        Sync()
    end,
}
