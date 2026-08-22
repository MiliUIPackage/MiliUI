------------------------------------------------------------
-- 對外入口：/mbh 指令、米利UI選單項目
------------------------------------------------------------
local _, ns = ...

local L = ns.L

function ns.OpenSettings(tabId)
    ns.Options.Open(tabId)
end

-- 米利UI選單（ESC 選單「米利UI設定」滑過展開）的項目。
-- 直接往全域表塞而不是呼叫 MiliUI 的函式：兩邊沒有相依宣告，載入順序不保證，
-- 而且玩家可能只裝這支、根本沒有 MiliUI 套組。接口說明見 MiliUI/Menu.lua。
MiliUI_MenuEntries = MiliUI_MenuEntries or {}
MiliUI_MenuEntries[#MiliUI_MenuEntries + 1] = {
    key     = "burstpotion",
    text    = L["ADDON_NAME"],
    icon    = "Interface\\Icons\\inv_12_profession_alchemy_lightpotion_yellow",
    order   = 30,
    OnClick = function() ns.OpenSettings() end,
}

SLASH_MILIUIBURST1 = "/mbh"
SLASH_MILIUIBURST2 = "/bursthelper"
SlashCmdList["MILIUIBURST"] = function(msg)
    msg = strtrim((msg or ""):lower())
    if msg == "macro" or msg == "copy" then
        ns.OpenSettings("macro")
    elseif msg == "show" then
        ns.Bar_SetShown(true)
    elseif msg == "hide" then
        ns.Bar_SetShown(false)
    elseif msg == "reset" then
        ns.Bar_ResetPosition()
    else
        ns.OpenSettings()
    end
end
