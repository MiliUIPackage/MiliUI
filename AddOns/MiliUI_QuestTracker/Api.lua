------------------------------------------------------------
-- 對外入口：/mquest 指令、插件選單按鈕、米利UI選單那一筆
------------------------------------------------------------
local _, ns = ...

local L = ns.L

function ns.OpenOptions(tabId)
    ns.Options.Open(tabId)
end

-- 插件選單（小地圖旁的收納選單）
function _G.MiliUIQuestTracker_OnAddonCompartmentClick()
    ns.OpenOptions()
end

-- 米利UI選單（ESC 選單「米利UI設定」滑過展開）的項目。
-- 直接往全域表塞而不是呼叫 MiliUI 的函式：兩邊沒有相依宣告，載入順序不保證，
-- 而且玩家可能只裝這支、根本沒有 MiliUI 套組。接口說明見 MiliUI/Menu.lua。
MiliUI_MenuEntries = MiliUI_MenuEntries or {}
MiliUI_MenuEntries[#MiliUI_MenuEntries + 1] = {
    key     = "questtracker",
    text    = L["MiliUI Quest Tracker"],
    icon    = "Interface\\Icons\\INV_Misc_Book_09",
    order   = 85,
    OnClick = function() ns.OpenOptions() end,
}

SLASH_MILIUIQUEST1 = "/mquest"
SLASH_MILIUIQUEST2 = "/miliuiquest"
SlashCmdList.MILIUIQUEST = function(msg)
    msg = strtrim(strlower(msg or ""))

    if msg == "fold" or msg == "toggle" then
        ns.Visibility.ToggleManualFold()

    elseif msg == "reset" then
        ns.DB.ResetAll()
        ns.Print(L["Restored the default settings."])

    elseif msg == "trace" then
        ns.AutoQuest.trace = not ns.AutoQuest.trace
        ns.Print(ns.AutoQuest.trace
            and "|cff88ccff" .. L["Quest automation trace ON — reproduce the problem, then paste the lines here."] .. "|r"
            or L["Quest automation trace off."])

    elseif msg == "debug" then
        ns.Print("v" .. ns.VERSION
            .. "  folded=" .. tostring(ns.Visibility.IsFolded())
            .. "  protected=" .. tostring(ns.Tracker.OTF() and ns.Tracker.OTF():IsProtected()))
        for _, line in ipairs(ns.Chrome.Diagnose()) do print("  " .. line) end
        local conflict = ns.AutoQuest.LeatrixConflict()
        if conflict then
            print("  Leatrix Plus: accept=" .. tostring(conflict.accept)
                .. " turnIn=" .. tostring(conflict.turnIn))
        end
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
