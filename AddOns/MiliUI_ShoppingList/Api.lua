------------------------------------------------------------
-- 對外入口：/mlist 指令、插件選單按鈕、米利UI選單那一筆
------------------------------------------------------------
local _, ns = ...

local L = ns.L

function ns.OpenOptions(tabId)
    ns.Options.Open(tabId)
end

-- 插件選單（小地圖旁的收納選單）
function _G.MiliUIShoppingList_OnAddonCompartmentClick()
    ns.Window.Toggle()
end

-- 米利UI選單（ESC 選單「米利UI設定」滑過展開）的項目。
-- 直接往全域表塞而不是呼叫 MiliUI 的函式：兩邊沒有相依宣告，載入順序不保證，
-- 而且玩家可能只裝這支、根本沒有 MiliUI 套組。接口說明見 MiliUI/Menu.lua。
MiliUI_MenuEntries = MiliUI_MenuEntries or {}
MiliUI_MenuEntries[#MiliUI_MenuEntries + 1] = {
    key     = "shoppinglist",
    text    = L["MiliUI Shopping List"],
    icon    = "Interface\\Icons\\INV_Misc_Bag_10_Green",
    order   = 86,
    OnClick = function() ns.Window.Toggle() end,
}

SLASH_MILIUISHOP1 = "/mlist"
SLASH_MILIUISHOP2 = "/miliuishop"
SlashCmdList.MILIUISHOP = function(msg)
    msg = strtrim(strlower(msg or ""))

    if msg == "config" or msg == "options" or msg == "設定" then
        ns.OpenOptions()

    elseif msg == "search" or msg == "搜尋" then
        ns.Auction.SearchAll()

    elseif msg == "reset" then
        ns.DB.ResetSettings()
        ns.Print(L["Restored the default settings."])

    elseif msg == "debug" then
        ns.Print("v" .. ns.VERSION)
        print(("  recipes=%d extras=%d missing=%d"):format(
            #ns.cdb.recipes, #ns.cdb.extras, ns.List.MissingTotal()))
        print(("  auctionHouse=%s status=%s"):format(
            tostring(ns.Auction.IsOpen()), (ns.Auction.Status())))
        for _, row in ipairs(ns.List.Shopping({ includeReady = true, allRecipes = true })) do
            if (row.buy or 0) > 0 and row.itemID then
                local d = ns.Auction.DebugInfo(row.itemID)
                print(("  %s(%d) buy=%d detailed=%s searched=%s quote=%s commodity=%s results=%s price=%s"):format(
                    ns.List.ItemInfo(row.itemID).name, row.itemID, row.buy,
                    tostring(d.detailed), tostring(d.searched), tostring(d.hasQuote),
                    tostring(d.commodity), tostring(d.results), tostring(d.unitPrice)))
            end
        end
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
