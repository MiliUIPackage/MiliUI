------------------------------------------------------------
-- 對外入口：/maura 指令、插件選單按鈕、米利UI選單那一筆
------------------------------------------------------------
local _, ns = ...

local L = ns.L

function ns.OpenOptions(tabId)
    ns.Options.Open(tabId)
end

-- 插件選單（小地圖旁的收納選單）
function _G.MiliUIAuraEnhance_OnAddonCompartmentClick()
    ns.OpenOptions()
end

-- 米利UI選單（ESC 選單「米利UI設定」滑過展開）的項目。
-- 直接往全域表塞而不是呼叫 MiliUI 的函式：兩邊沒有相依宣告，載入順序不保證，
-- 而且玩家可能只裝這支、根本沒有 MiliUI 套組。接口說明見 MiliUI/Menu.lua。
MiliUI_MenuEntries = MiliUI_MenuEntries or {}
MiliUI_MenuEntries[#MiliUI_MenuEntries + 1] = {
    key     = "auraenhance",
    text    = L["MiliUI Aura Enhance"],
    icon    = "Interface\\Icons\\Spell_Holy_WordFortitude",
    order   = 80,
    OnClick = function() ns.OpenOptions() end,
}

SLASH_MILIUIAURA1 = "/maura"
SLASH_MILIUIAURA2 = "/miliuiaura"
SlashCmdList.MILIUIAURA = function(msg)
    msg = strtrim(strlower(msg or ""))

    if msg == "reset" then
        ns.DB.ResetAll()
        ns.Print(L["Restored the default settings."])

    elseif msg == "debug" then
        ns.Print("v" .. ns.VERSION .. "  migration=" .. tostring(ns.db and ns.db.migration))
        if #ns.errors == 0 then
            print("  " .. L["No errors recorded"])
        else
            for i, err in ipairs(ns.errors) do
                print(("  %d. %s"):format(i, err))
            end
        end

    else
        ns.OpenOptions()
    end
end
