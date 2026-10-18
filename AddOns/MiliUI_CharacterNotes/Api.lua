------------------------------------------------------------
-- 對外入口：/mnote 指令、插件選單按鈕、米利UI選單那一筆
------------------------------------------------------------
local _, ns = ...

local L = ns.L

function ns.OpenOptions(tabId)
    ns.Options.Open(tabId)
end

-- 插件選單（小地圖旁的收納選單）
function _G.MiliUICharacterNotes_OnAddonCompartmentClick()
    ns.Window.Toggle()
end

-- 米利UI選單（ESC 選單「米利UI設定」滑過展開）的項目。
-- 直接往全域表塞而不是呼叫 MiliUI 的函式：兩邊沒有相依宣告，載入順序不保證，
-- 而且玩家可能只裝這支、根本沒有 MiliUI 套組。接口說明見 MiliUI/Menu.lua。
MiliUI_MenuEntries = MiliUI_MenuEntries or {}
MiliUI_MenuEntries[#MiliUI_MenuEntries + 1] = {
    key     = "characternotes",
    text    = L["MiliUI Character Notes"],
    icon    = "Interface\\Icons\\INV_Misc_Note_01",
    order   = 85,
    OnClick = function() ns.Window.Toggle() end,
}

SLASH_MILIUINOTE1 = "/mnote"
SLASH_MILIUINOTE2 = "/miliuinote"
SlashCmdList.MILIUINOTE = function(msg)
    msg = strtrim(strlower(msg or ""))

    if msg == "config" or msg == "options" or msg == "設定" then
        ns.OpenOptions()

    elseif msg == "dungeon" or msg == "instance" or msg == "副本" then
        ns.Overlay.Toggle()

    elseif msg == "migrate" then
        local moved = ns.DB.ForceMigration()
        if moved == nil then
            ns.Print(L["The MiliUI package is not loaded, so there is nothing to import."])
        elseif moved == 0 then
            ns.Print(L["Nothing new to import — everything is already here."])
        else
            ns.Print(L["Imported %d notes from the MiliUI package."]:format(moved))
        end

    elseif msg == "reset" then
        ns.DB.ResetSettings()
        ns.Print(L["Restored the default settings."])

    elseif msg == "debug" then
        ns.Print("v" .. ns.VERSION .. "  migration=" .. tostring(ns.db and ns.db.migration))
        local jInst, name = ns.Journal.CurrentInstance()
        print(("  instance=%s (%s)"):format(tostring(jInst), tostring(name)))
        for _, line in ipairs(ns.Journal.DebugLines()) do print(line) end
        if #ns.errors == 0 then
            print("  " .. L["No errors recorded"])
        else
            for i, err in ipairs(ns.errors) do
                print(("  %d. %s"):format(i, err))
            end
        end

    else
        ns.Window.Toggle()
    end
end
