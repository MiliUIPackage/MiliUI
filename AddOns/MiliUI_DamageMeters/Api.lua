------------------------------------------------------------
-- 對外入口：/mdm 指令、插件選單按鈕
------------------------------------------------------------
local _, ns = ...

local L = ns.L

function ns.OpenOptions(tabId)
    ns.Options.Open(tabId)
end

-- 插件選單（小地圖旁的收納選單）
function _G.MiliUIDamageMeters_OnAddonCompartmentClick()
    ns.OpenOptions()
end

-- 米利UI選單（ESC 選單「米利UI設定」滑過展開）的項目。
-- 直接往全域表塞而不是呼叫 MiliUI 的函式：兩邊沒有相依宣告，載入順序不保證，
-- 而且玩家可能只裝這支、根本沒有 MiliUI 套組。接口說明見 MiliUI/Menu.lua。
MiliUI_MenuEntries = MiliUI_MenuEntries or {}
MiliUI_MenuEntries[#MiliUI_MenuEntries + 1] = {
    key     = "damagemeters",
    text    = L["MiliUI Damage Meters"],
    icon    = "Interface\\Icons\\Ability_DualWield",
    order   = 70,
    OnClick = function() ns.OpenOptions() end,
}

SLASH_MILIUIDAMAGEMETERS1 = "/mdm"
SLASH_MILIUIDAMAGEMETERS2 = "/miliuidm"
SlashCmdList.MILIUIDAMAGEMETERS = function(msg)
    msg = strtrim(strlower(msg or ""))

    if msg == "reset" then
        ns.Combat.ResetData()
        ns.Print(L["Cleared the recorded segments."])

    elseif msg == "resetall" then
        ns.DB.ResetAll()

    elseif msg == "debug" then
        ns.Print("v" .. ns.VERSION
            .. "  api=" .. tostring(ns.HAS_API)
            .. "  windows=" .. tostring(ns.Windows and ns.Windows.Count() or 0)
            .. "  combat=" .. tostring(ns.Combat and ns.Combat.IsInCombat()))
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
