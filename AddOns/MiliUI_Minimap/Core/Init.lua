------------------------------------------------------------
-- MiliUI_Minimap 命名空間與啟動流程
--
-- 兩件事：
--   1. 把暴雪的小地圖換成 MiliUI 的 HUD 皮（方形、黑透明底、1px 職業色邊）
--   2. 在地圖下方掛一條資訊列 —— 左邊公會在線、右邊好友在線
--
-- 設計語言的定義在 Core/Style.lua；踩過的坑在
-- .claude/notes/project-miliui-minimap.md。
--
-- 啟動一律等到 PLAYER_LOGIN：SavedVariables 那時才保證載入，也不必猜插件順序。
------------------------------------------------------------
local ADDON, ns = ...

ns.ADDON_NAME = ADDON
ns.VERSION    = C_AddOns.GetAddOnMetadata(ADDON, "Version") or "dev"
ns.DB_VERSION = 1

-- player token 不受 12.1 身分限制，讀職業是安全的
ns.playerClass = select(2, UnitClass("player"))
ns.playerName  = UnitName("player")

-- 聊天前綴色跟 TOC 的 [地圖] 標籤同色
ns.PREFIX_COLOR = "|cff5CC9F5"

function ns.Print(...)
    print(ns.PREFIX_COLOR .. "[" .. ns.L["MiliUI Minimap"] .. "]|r", ...)
end

------------------------------------------------------------
-- 錯誤收集與封鎖動作攔截 —— 共用層 Libs/MiliUIWidgets/Errors.lua
--
-- 小地圖插件特別需要那個攔截器：MinimapCluster 是**編輯模式管的系統框**，
-- 碰錯地方的症狀是「嘗試進行 Blizzard UI 專屬動作，遭到封鎖」彈窗，
-- 那不是 Lua error、pcall 攔不住，但事件會點名是哪個函式
-- （見 .claude/notes/project-miliui-hide-blizzard-taint.md）。
------------------------------------------------------------
ns.Errors.Install(function(line)
    ns.Print("|cffff5555" .. line .. "|r")
end)

------------------------------------------------------------
-- 安全更新：任何會碰到 UI 的更新都從這裡進，錯誤才不會連坐
------------------------------------------------------------
function ns.Safe(fn, ...)
    if not fn then return end
    return xpcall(fn, ns.ReportError, ...)
end

------------------------------------------------------------
-- 啟動
------------------------------------------------------------
local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")

    ns.DB.Init()
    -- 自訂職業色插件（Cell 那類）多半比我們晚載入，這時再解一次強調色
    ns.Style.RefreshAccent()

    if not ns.DB.Get().enabled then
        -- 停用狀態下**什麼都不做** —— 對別的小地圖插件零干擾。
        -- 重新啟用需要 /reload，設定頁的開關會講。
        return
    end

    ns.Fire("Init")
end)

_G.MiliUIMinimap = ns
