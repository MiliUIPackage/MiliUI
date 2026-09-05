------------------------------------------------------------
-- 對外入口：/mchatbar 指令、米利UI選單項目
-- （聊天列自己的右鍵選單也是走 ns.OpenSettings）
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
    key     = "chatbar",
    text    = L["ADDON_NAME"],
    icon    = "Interface\\Icons\\Achievement_Boss_HighMaul_King",
    order   = 50,
    OnClick = function() ns.OpenSettings() end,
}

SLASH_MILIUICHATBAR1 = "/mchatbar"
SLASH_MILIUICHATBAR2 = "/mcb"
SlashCmdList["MILIUICHATBAR"] = function(msg)
    msg = strtrim((msg or ""):lower())
    if msg == "reset" then
        ns.ResetPosition()
    elseif msg == "debug" then
        if ns.Anchor then ns.Anchor.Debug() end
    else
        ns.OpenSettings()
    end
end
