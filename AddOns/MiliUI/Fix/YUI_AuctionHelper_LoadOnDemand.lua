---------------------------------------------------------------
-- MiliUI Fix: YUI_AuctionHelper 改成隨拍賣場載入
-- Author: Mili
--
-- 為什麼：這支插件登入就要解析約 4.9 MB Lua，但真正的功能程式只有 512 KB，
--   其餘是它內嵌的整套 YUI 框架（GUI、監看器、語系、函式庫），而它唯一的功能
--   是拍賣場視窗旁的購物面板。所以 TOC 改成
--     ## LoadOnDemand: 1
--     ## LoadWith: Blizzard_AuctionHouseUI
--   第一次開拍賣場才載入。（TOC 那兩行是直接改插件檔，上游更新會洗掉，
--   見 .claude/notes/project-local-addon-forks.md）
--
-- 這支補的洞：YUI 的模組初始化掛在 PLAYER_LOGIN 上
--   （CoreEmbed/Core/Module.lua 的 Runtime:InitializeAll ← YUI_LOGIN_READY
--     ← Lifecycle:OnPlayerLogin ← PLAYER_LOGIN），而且不查 IsLoggedIn()。
--   登入之後才載入的話它永遠等不到這個事件，整支靜靜地不動。
--
-- 修法：它自己的存檔初始化（ADDON_LOADED → YUI_DB_READY）照常跑完之後，
--   在它的事件匯流排上把 PLAYER_LOGIN／PLAYER_ENTERING_WORLD 同步重播一次。
--   同步很重要：MiliUI 插件總覽的「開啟設定」是 LoadAddOn 完馬上找 /yah，
--   拍賣場那邊也是載入完緊接著就 Show。
---------------------------------------------------------------

local ADDON = "YUI_AuctionHelper"

local function Replay()
    local core = _G.YUI
    local bus, life = core and core.Event, core and core.Lifecycle
    if not (bus and life and life.IsReady) then return end
    -- 已經走過登入流程（例如別的插件在登入前就把它拉起來了）就不要再來一次
    if life:IsReady("YUI_LOGIN_READY") then return end

    -- "normal" 來源 = 跟真的遊戲事件走同一條派送（Event.lua 的 YUI.f OnEvent）
    local dispatch = bus._Dispatch
    if dispatch then
        dispatch(bus, "PLAYER_LOGIN", "normal", nil)
        dispatch(bus, "PLAYER_ENTERING_WORLD", "normal", nil, false, false)
    else
        bus:Emit("PLAYER_LOGIN")
        bus:Emit("PLAYER_ENTERING_WORLD", false, false)
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(self, _, name)
    if name ~= ADDON then return end
    self:UnregisterEvent("ADDON_LOADED")
    self:SetScript("OnEvent", nil)

    -- 登入當下載入（有人把 TOC 改回去、或別的插件在登入前拉它）：真的事件還沒來，交給它自己
    if not IsLoggedIn() then return end

    local core = _G.YUI
    local life = core and core.Lifecycle
    if life and life.IsReady and life:IsReady("YUI_DB_READY") then
        -- 它的 ADDON_LOADED 處理器比我們先跑完了
        Replay()
    elseif core and core.Event and core.Event.Once then
        -- 一般情況：我們的框先註冊，比它先收到 ADDON_LOADED ⇒ 等它的存檔就緒
        core.Event:Once("YUI_DB_READY", Replay, nil, { priority = -10000 })
    end
end)
