------------------------------------------------------------
-- 對外入口：/mmap 指令、插件選單按鈕、米利UI選單項目
------------------------------------------------------------
local _, ns = ...

local L = ns.L

function ns.OpenOptions(tabId)
    ns.Options.Open(tabId)
end

-- 插件收納選單（小地圖上方那顆）
function _G.MiliUIMinimap_OnAddonCompartmentClick()
    ns.OpenOptions()
end

-- 米利UI選單（ESC 選單「米利UI設定」滑過展開）的項目。
-- 直接往全域表塞而不是呼叫 MiliUI 的函式：兩邊沒有相依宣告，載入順序不保證，
-- 而且玩家可能只裝這支、根本沒有 MiliUI 套組。接口說明見 MiliUI/Menu.lua。
MiliUI_MenuEntries = MiliUI_MenuEntries or {}
MiliUI_MenuEntries[#MiliUI_MenuEntries + 1] = {
    key     = "minimap",
    text    = L["MiliUI Minimap"],
    icon    = "Interface\\Icons\\INV_Misc_Map_01",
    order   = 90,
    OnClick = function() ns.OpenOptions() end,
}

SLASH_MILIUIMINIMAP1 = "/mmap"
SLASH_MILIUIMINIMAP2 = "/miliuiminimap"

SlashCmdList.MILIUIMINIMAP = function(msg)
    local cmd = strtrim(strlower(msg or ""))

    if cmd == "lock" then
        ns.Skin.SetLocked(true)
        ns.Print(L["Minimap locked."])

    elseif cmd == "unlock" then
        ns.Skin.SetLocked(false)
        ns.Print(L["Minimap unlocked — drag it, right-click to send it back to the corner."])

    elseif cmd == "bag" then
        -- 資訊列沒放收納袋那一格時，這是袋子唯一的入口
        ns.Buttons.Toggle(ns.infoBar)

    elseif cmd == "reset" then
        ns.DB.ResetAll()
        ns.Print(L["Settings restored to defaults."])

    elseif cmd == "prof" then
        ns.ProfileToggle()

    elseif cmd == "debug" then
        -- ns.errors 由共用層 Libs/MiliUIWidgets/Errors.lua 收集
        local list = ns.errors
        if not list or #list == 0 then
            ns.Print(L["No errors recorded."])
        else
            for _, line in ipairs(list) do ns.Print(line) end
        end

    else
        ns.OpenOptions()
    end
end
