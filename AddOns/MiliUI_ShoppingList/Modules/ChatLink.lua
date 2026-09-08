------------------------------------------------------------
-- Shift 點物品連結 → 加進「額外物品」
--
-- 只在採購清單視窗的「加入物品」輸入框有焦點時才吃連結。沒有這道閘的話，
-- 玩家在背包裡 Shift 點任何東西都會被我們吞進清單 —— 那是所有「吃連結」的
-- 插件共同的災難。
--
-- 掛 HandleModifiedItemClick（不是 ChatEdit_InsertLink）：後者只在聊天輸入框
-- 開著時才會被呼叫，我們的輸入框不是聊天框。
------------------------------------------------------------
local _, ns = ...

local lastLink, lastTime = nil, 0

hooksecurefunc("HandleModifiedItemClick", function(link)
    if not ns.db or type(link) ~= "string" then return end
    if not (ns.Window and ns.Window.WantsLink and ns.Window.WantsLink()) then return end

    -- 同一次點擊可能經過兩條路（背包格與物品按鈕各自呼叫），去重一下
    local now = GetTime()
    if link == lastLink and (now - lastTime) < 0.2 then return end
    lastLink, lastTime = link, now

    local itemID = C_Item.GetItemInfoInstant(link)
    if not itemID then return end
    ns.Window.TakeLink(itemID)
end)
