------------------------------------------------------------
-- 對外入口：/mtip 指令、插件選單按鈕
------------------------------------------------------------
local _, ns = ...

local L = ns.L

function ns.OpenOptions(tabId)
    ns.Options.Open(tabId)
end

-- 插件選單（小地圖旁的收納選單）
function _G.MiliUITip_OnAddonCompartmentClick()
    ns.OpenOptions()
end

-- 米利UI選單（ESC 選單「米利UI設定」滑過展開）的項目。
-- 直接往全域表塞而不是呼叫 MiliUI 的函式：兩邊沒有相依宣告，載入順序不保證，
-- 而且玩家可能只裝這支、根本沒有 MiliUI 套組。接口說明見 MiliUI/Menu.lua。
-- 圖示不用 TOC 那顆水獺：單位框架跟這支共用同一顆，選單裡並排會分不出來。
MiliUI_MenuEntries = MiliUI_MenuEntries or {}
MiliUI_MenuEntries[#MiliUI_MenuEntries + 1] = {
    key     = "tooltip",
    text    = L["MiliUI Tooltip"],
    icon    = "Interface\\Icons\\INV_Misc_Note_01",
    order   = 20,
    OnClick = function() ns.OpenOptions() end,
}

SLASH_MILIUITIP1 = "/mtip"
SLASH_MILIUITIP2 = "/miliuitooltip"
SlashCmdList.MILIUITIP = function(msg)
    msg = strtrim(strlower(msg or ""))
    if msg == "reset" then
        ns.DB.ResetAll()
    elseif msg == "log" then
        ns.logEnabled = not ns.logEnabled
        if ns.logEnabled then wipe(ns.logBuf) end
        print("|cff4DD2FF[米利的滑鼠提示]|r 診斷記錄：" .. (ns.logEnabled and "開（重現問題後 /mtip logdump 印出）" or "關"))
    elseif msg == "logdump" then
        print("|cff4DD2FF[米利的滑鼠提示]|r 診斷記錄 " .. #ns.logBuf .. " 條：")
        for _, line in ipairs(ns.logBuf) do print(line) end
        wipe(ns.logBuf)
    elseif msg == "debug" then
        print("|cff4DD2FF[MiliUI Tooltip]|r v" .. ns.VERSION)
        if #ns.errors == 0 then
            print("  無錯誤紀錄")
        else
            for i, err in ipairs(ns.errors) do
                print(("  %d. %s"):format(i, err))
            end
        end
    else
        ns.OpenOptions()
    end
end
