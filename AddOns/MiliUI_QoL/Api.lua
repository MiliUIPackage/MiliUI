------------------------------------------------------------
-- 對外入口：/mqol 指令、米利UI選單項目、插件收納選單
-- 開設定一律走 ns.Host.Open（有本體就開本體的「便利功能」分頁，否則開自己的視窗）
------------------------------------------------------------
local _, ns = ...

function ns.OpenOptions()
    ns.Host.Open()
end

-- 插件選單（小地圖旁的收納選單）
function _G.MiliUIQoL_OnAddonCompartmentClick()
    ns.OpenOptions()
end

-- 米利UI選單（ESC 選單「米利UI設定」滑過展開）的項目。直接往全域表塞：
-- 玩家可能只裝這支、沒有本體。接口說明見 MiliUI/Menu.lua。
-- 本體的插件總覽也靠同一個 key（Roster.lua 的 menuKey = "qol"）開設定。
MiliUI_MenuEntries = MiliUI_MenuEntries or {}
MiliUI_MenuEntries[#MiliUI_MenuEntries + 1] = {
    key     = "qol",
    text    = ns.TITLE,
    icon    = "Interface\\Icons\\INV_Misc_Gear_01",
    order   = 55,
    OnClick = function() ns.OpenOptions() end,
}

SLASH_MILIUIQOL1 = "/mqol"
SLASH_MILIUIQOL2 = "/miliuiqol"
SlashCmdList.MILIUIQOL = function(msg)
    msg = strtrim(strlower(msg or ""))
    if msg == "reset" then
        ns.DB.ResetAll()
    elseif msg == "migrate" then
        -- 補搬：第一次啟動時剛好沒開 MiliUI，或印記蓋了之後才加進遷移清單的設定。
        -- 會覆蓋現有設定，所以只在明確下指令時跑。
        local ok, moved = ns.DB.RunMigration()
        if ok then
            ns.Print(("已從米利UI套組搬入 %d 項設定，重新載入介面。"):format(moved))
            C_Timer.After(1, ReloadUI)
        else
            ns.Print("沒有可以搬的設定（米利UI套組沒有存過便利功能的設定）。")
        end
    elseif msg == "debug loot" then
        ns.LootToast.Debug()
    elseif msg == "debug" then
        ns.Print("v" .. ns.VERSION .. "  migration=" .. tostring(ns.db and ns.db.miliuiMigration)
            .. "  host=" .. tostring(ns.Host.Mode()) .. "  legacyCore=" .. tostring(ns.legacyCore))
        if #ns.errors == 0 then
            print("  沒有記錄到錯誤")
        else
            for i, err in ipairs(ns.errors) do
                print(("  %d. %s"):format(i, err))
            end
        end
        print("  |cff808080/mqol debug loot：戰利品通知過濾的狀態與最近 10 筆紀錄|r")
    else
        ns.OpenOptions()
    end
end
