------------------------------------------------------------
-- 對外入口：/mmerchant 指令、插件選單按鈕、米利UI選單那一筆
------------------------------------------------------------
local _, ns = ...

local L = ns.L

function ns.OpenOptions(tabId)
    ns.Options.Open(tabId)
end

-- 插件選單（小地圖旁的收納選單）
function _G.MiliUIMerchant_OnAddonCompartmentClick()
    ns.OpenOptions()
end

-- 米利UI選單（ESC 選單「米利UI設定」滑過展開）的項目。
-- 直接往全域表塞而不是呼叫 MiliUI 的函式：兩邊沒有相依宣告，載入順序不保證，
-- 而且玩家可能只裝這支、根本沒有 MiliUI 套組。接口說明見 MiliUI/Menu.lua。
MiliUI_MenuEntries = MiliUI_MenuEntries or {}
MiliUI_MenuEntries[#MiliUI_MenuEntries + 1] = {
    key     = "merchant",
    text    = L["MiliUI Merchant"],
    icon    = "Interface\\Icons\\INV_Misc_Coin_02",
    order   = 87,
    OnClick = function() ns.OpenOptions() end,
}

SLASH_MILIUIMERCHANT1 = "/mmerchant"
SLASH_MILIUIMERCHANT2 = "/miliuimerchant"
SlashCmdList.MILIUIMERCHANT = function(msg)
    msg = strtrim(strlower(msg or ""))

    if msg == "reset" then
        ns.DB.ResetAll()
        ns.Print(L["Restored the default settings."])

    elseif msg:match("^debug") then
        -- 一次把「插件現在到底在幹嘛」全部印出來。最重要的是最後兩個數字：
        -- 掛勾在商人框隱藏時被閘掉的次數應該遠大於 0（暴雪本來就會在關著的時候
        -- 跑 Update），而且商人沒開過的話 hookRuns 扣掉 hookGated 應該是 0
        local db = ns.db
        ns.Print("v" .. ns.VERSION)
        print(("  dormant=%s  rows=%d cols=%d perPage=%d cells=%d"):format(
            tostring(ns.dormant),
            db and db.rows or -1,
            db and db.cols or -1,
            ns.Grid.PerPage(),
            ns.Grid.CreatedCells()))
        print(("  MERCHANT_ITEMS_PER_PAGE=%s  merchantShown=%s"):format(
            tostring(_G.MERCHANT_ITEMS_PER_PAGE),
            tostring(MerchantFrame and MerchantFrame:IsShown() or false)))
        print(("  hookRuns=%d  gatedWhileHidden=%d  collectedCache=%d"):format(
            ns.Grid.stats.hookRuns, ns.Grid.stats.hookGated, ns.Collected.Count()))
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
