------------------------------------------------------------
-- 對外入口：設定視窗的開啟函式、米利UI選單項目
-- （/blm 指令在 Music.lua 的 PLAYER_LOGIN 裡註冊，會呼叫下面這個全域）
------------------------------------------------------------
local _, ns = ...

local L = ns.L

function ns.OpenSettings(tabId)
    ns.Options.Open(tabId)
end

-- Music.lua 的 /blm 走這個全域（兩支檔案之間不互相 require）
_G.MiliUI_OpenBloodlustMusicSettings = function() ns.OpenSettings() end

-- 米利UI選單（ESC 選單「米利UI設定」滑過展開）的項目。
-- 直接往全域表塞而不是呼叫 MiliUI 的函式：兩邊沒有相依宣告，載入順序不保證，
-- 而且玩家可能只裝這支、根本沒有 MiliUI 套組。接口說明見 MiliUI/Menu.lua。
MiliUI_MenuEntries = MiliUI_MenuEntries or {}
MiliUI_MenuEntries[#MiliUI_MenuEntries + 1] = {
    key     = "bloodlustmusic",
    text    = L["ADDON_NAME"],
    icon    = "Interface\\Icons\\Spell_Nature_Bloodlust",
    order   = 40,
    OnClick = function() ns.OpenSettings() end,
}
