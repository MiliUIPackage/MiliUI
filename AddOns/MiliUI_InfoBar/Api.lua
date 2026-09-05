------------------------------------------------------------
-- 對外入口：斜線指令、設定視窗開啟函式、米利UI選單項目
------------------------------------------------------------
local _, ns = ...

local L = ns.L

function ns.OpenSettings(tabId)
    ns.Options.Open(tabId)
end

SLASH_MILIUI_INFOBAR1 = "/mib"
SLASH_MILIUI_INFOBAR2 = "/miliinfobar"
SlashCmdList.MILIUI_INFOBAR = function(msg)
    local cmd = type(msg) == "string" and msg:lower():match("^%s*(%S+)") or nil
    if cmd == "debug" then
        ns.PrintDebug()
    elseif cmd == "keydebug" then
        -- 戰隊資訊資料層的追蹤輸出（鑰石／寶庫快照什麼時候存、為什麼存）
        local on = ns.Warband.ToggleDebug()
        print(ns.PREFIX_COLOR .. L["ADDON_NAME"] .. "|r warband debug: " .. (on and "ON" or "OFF"))
    elseif cmd == "stash" then
        -- 探測鍍金儲物箱的 widget（改版後 ID 換了要靠這個找）
        ns.Warband.ProbeStash()
    else
        ns.OpenSettings()
    end
end

-- 米利UI選單（ESC 選單「米利UI設定」滑過展開）的項目。
-- 直接往全域表塞而不是呼叫 MiliUI 的函式：兩邊沒有相依宣告，載入順序不保證，
-- 而且玩家可能只裝這支、根本沒有 MiliUI 套組。接口說明見 MiliUI/Menu.lua。
MiliUI_MenuEntries = MiliUI_MenuEntries or {}
MiliUI_MenuEntries[#MiliUI_MenuEntries + 1] = {
    key     = "infobar",
    text    = L["ADDON_NAME"],
    icon    = "Interface\\Icons\\INV_Misc_Note_06",
    order   = 45,
    OnClick = function() ns.OpenSettings() end,
}
