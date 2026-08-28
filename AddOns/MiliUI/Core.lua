------------------------------------------------------------
-- 登入時的歡迎／更新訊息
--
-- 舊版是「每次登入都印一次，只有 zhTW 看得到，而且沒有開關」。三個問題各自修掉：
--
-- ⚠⚠ **網址不要寫成 Markdown 連結。** 舊版寫 `[奇樂-...](https://addons.miliui.com)`，
--   而聊天視窗不解析 Markdown —— 玩家看到的就是原樣的中括號加括號，而且點不了。
--   WoW 的聊天也不會自動把裸網址變成連結，所以想給「點得到」的東西只有兩條路：
--   ① 印純文字網址讓玩家自己複製，② 做成 hyperlink 開一個可以 Ctrl+C 的視窗。
--   這裡走 ①：一行純文字最不會出錯，而設定視窗的「關於」本來就放得下更完整的資訊。
--
-- **只在版本號變動時印一次**（版本存在 SV）。套組的 `## Version` 是 YYYYMMDD，
--   每次發佈都會變，所以這等於「更新之後第一次登入才講一次話」——那正是這則訊息
--   唯一有意義的時機。想再看一次就 `/miliui`。
--
-- **給一個開關**（`MiliUI_DB.welcomeMessage`，設定視窗的「插件強化」分頁）。
------------------------------------------------------------
local _, ns = ...

local DELAY = 1        -- 讓聊天視窗先把自己的東西印完，訊息才不會被推上去

local function Welcome()
    if not MiliUI_DB then MiliUI_DB = {} end
    if MiliUI_DB.welcomeMessage == false then return end

    local seen = MiliUI_DB.lastSeenVersion
    if seen == ns.VERSION then return end
    local isUpdate = seen ~= nil        -- 沒有印記＝第一次裝，不是「更新」
    MiliUI_DB.lastSeenVersion = ns.VERSION

    if GetLocale() == "zhTW" or GetLocale() == "zhCN" then
        if isUpdate then
            print(("|cfffeff00米利UI套組|r 已更新到 |cffffd200%s|r。"):format(ns.VERSION))
        else
            print("|cfffeff00歡迎使用|r|cffffd200米利UI套組|r。")
        end
        print("|cff808080最新版本與問題討論：|r|cffffd200addons.miliui.com|r  |cff808080（輸入 /miliui 開啟設定）|r")
    else
        if isUpdate then
            print(("|cfffeff00MiliUI Package|r updated to |cffffd200%s|r."):format(ns.VERSION))
        else
            print("|cfffeff00Welcome to the|r |cffffd200MiliUI Package|r.")
        end
        print("|cff808080Updates and discussion: |r|cffffd200addons.miliui.com|r  |cff808080(type /miliui for settings)|r")
    end
end

-- SV 要等 ADDON_LOADED 才存在，所以不能像舊版那樣在檔案載入時就排 C_Timer
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    C_Timer.After(DELAY, function() xpcall(Welcome, ns.ReportError) end)
end)
