------------------------------------------------------------
-- 對外入口：/mskin 指令、插件選單按鈕、米利UI選單那一筆
--
-- 這裡寫出去的全域都登記在 .claude/scripts/check_lua.py 的 ALLOWED_GLOBAL_WRITES。
------------------------------------------------------------
local _, ns = ...

local L = ns.L

function ns.OpenOptions(tabId)
    ns.Options.Open(tabId)
end

-- 插件選單（小地圖旁的收納選單）
function MiliUISkin_OnAddonCompartmentClick()
    ns.OpenOptions()
end

-- 米利UI選單（ESC 選單「米利UI設定」滑過展開）的項目。
-- 直接往全域表塞而不是呼叫 MiliUI 的函式：兩邊沒有相依宣告，載入順序不保證，
-- 而且玩家可能只裝這支、根本沒有 MiliUI 套組。
MiliUI_MenuEntries = MiliUI_MenuEntries or {}
MiliUI_MenuEntries[#MiliUI_MenuEntries + 1] = {
    key     = "skin",
    text    = L["MiliUI Skin"],
    icon    = "Interface\\Icons\\INV_Misc_Gem_Variety_01",
    order   = 90,
    OnClick = function() ns.OpenOptions() end,
}

SLASH_MILIUISKIN1 = "/mskin"
SLASH_MILIUISKIN2 = "/miliuiskin"
SlashCmdList.MILIUISKIN = function(msg)
    msg = strtrim(strlower(msg or ""))

    if msg == "debug" then
        ns.Engine.Report()
    else
        ns.OpenOptions()
    end
end
