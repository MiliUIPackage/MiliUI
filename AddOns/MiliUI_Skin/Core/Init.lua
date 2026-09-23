------------------------------------------------------------
-- MiliUI_Skin 命名空間與啟動流程
--
-- 這支插件做的事只有一件：把暴雪原生視窗**重畫**成米利UI的設定視窗皮。
-- 契約（完整版在 STYLE.md ③）：
--   * 只重畫，不重排 —— 不 Hide／不 SetPoint／不 SetParent 任何暴雪物件
--   * 暴雪物件上零欄位寫入 —— 狀態一律放 Engine 的弱鍵 side table
--   * 零秘密值接觸 —— 不讀暴雪物件的文字／尺寸／錨點
--
-- 啟動一律等到 PLAYER_LOGIN：
--   * 自己的 SavedVariables 那時已經載入；
--   * 常駐視窗（對話／角色面板）那時也都建好了，不必猜載入順序。
-- 戰鬥中一律不套（`InCombatLockdown()`），延到 PLAYER_REGEN_ENABLED —— 我們碰的
-- 幾個視窗都帶著保護子物件，戰鬥中動它們最好的下場是被擋、最壞的下場是染髒。
------------------------------------------------------------
local ADDON, ns = ...

ns.ADDON_NAME = ADDON
ns.VERSION    = C_AddOns.GetAddOnMetadata(ADDON, "Version") or "dev"

-- 聊天前綴與設定視窗標題共用這一個色，跟 TOC 的 [外觀] 標籤同色
ns.PREFIX_COLOR = "|cff33F5FF"

function ns.Print(...)
    print(ns.PREFIX_COLOR .. "[" .. ns.L["MiliUI Skin"] .. "]|r", ...)
end

------------------------------------------------------------
-- 錯誤收集與封鎖動作攔截 —— 共用層 Libs/MiliUIWidgets/Errors.lua
--
--   ns.ReportError  xpcall 的訊息處理器（三道守衛：防遞迴、err 本身可能是秘密
--                   字串、下游 handler 包 pcall）。記進 ns.errors 供 /mskin debug
--                   印出，同時照常轉給全域 errorhandler。
--   封鎖動作攔截    ADDON_ACTION_FORBIDDEN 不是 Lua error、pcall 攔不住，
--                   但事件會點名是哪個插件的哪個函式。對這支插件來說那是**最重要
--                   的一條驗收線**：只要出現一次，就代表某份配方碰到了不該碰的東西。
------------------------------------------------------------
ns.Errors.Install(function(line)
    ns.Print("|cffff5555" .. line .. "|r")
end)

------------------------------------------------------------
-- 啟動
------------------------------------------------------------
-- ⚠ `PLAYER_LOGOUT` 把 `/mskin debug` 的內容原封不動存進 SavedVariables
--   （`MiliUI_Skin_DB.lastReport`，只留最後一份）。那是給維護者讀的：
--   「哪些區域找不到了」「哪些框被跳過」在改版之後就是現成的待辦清單，
--   不必再請玩家進遊戲打一次指令、把輸出貼出來。
--   整支走 `Engine.SaveReport` 的 pcall —— 登出路徑上報錯只會留下一個關不掉的視窗。
local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:RegisterEvent("PLAYER_LOGOUT")
boot:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGOUT" then
        pcall(ns.Engine.SaveReport)
        return
    end
    self:UnregisterEvent("PLAYER_LOGIN")
    ns.DB.Init()
    ns.Engine.Boot()
    -- 對外 handle（`Core/External.lua`）：Boot 前登記的插件在這一刻拿到 handle
    ns.External.OnBoot()
end)

-- 對外命名空間（除錯用；沒有任何對外 API 承諾）
MiliUISkin = ns
