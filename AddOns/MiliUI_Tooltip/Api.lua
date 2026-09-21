------------------------------------------------------------
-- 對外入口：/mtip 指令、插件選單按鈕、`MiliUITip_API`
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

------------------------------------------------------------
-- `MiliUITip_API` —— 給套組裡其他插件用的**最小**公開介面
--
-- 目前只有一支：`Adopt(tip)` ＝「把這顆 tooltip 交給我接管」。
--
-- **為什麼要有它。** 有些插件不用 `GameTooltip`，而是自己
-- `CreateFrame("GameTooltip", …, "GameTooltipTemplate")` 一顆專用的。那種 tooltip
-- 不在 `Core/Hooks.lua` 的 `TRACKED` 清單裡，所以一直是暴雪原樣（圓角邊框、
-- 深藍半透明底），跟套組其他提示框擺在一起很突兀。
--
-- 以前這件事寫在這支插件自己的 `Modules/ThirdParty.lua` 裡 —— 那等於「提示插件
-- 要自己知道套組裡有哪些第三方插件」。現在改成：**誰負責換皮誰去找**
-- （`MiliUI_Skin` 的 `ThirdParty/`），找到了叫這一支把外觀交出來。
-- 好處是玩家只裝其中一支也各自說得通：
--   * 只有提示插件 ⇒ 沒有人叫 `Adopt`，那兩顆維持暴雪原樣（跟以前沒裝時一樣）；
--   * 只有外觀插件 ⇒ `MiliUITip_API` 不存在，它退回自己畫一層提示皮。
--
-- ## 回傳值
--
--   true   已經接管（這次接的，或之前就接過了）
--   false  現在還不行 —— **呼叫端晚點再試**。唯一的原因是這支插件還沒初始化完
--          （`ns.db` 要等自己的 `ADDON_LOADED`），或傳進來的不是一顆框。
--
-- ⚠ 接管之後**只有外觀變，內容一個字都不動**：這條路線就是內建 tooltip 走的
--   那一條（`ns.TrackTip` → `Skin.Attach`：自己的 skin 子框、NineSlice alpha 0、
--   暴雪物件零欄位寫入），而那些 tooltip 只有純文字行，不會經過
--   `TooltipDataProcessor` 的單位／物品後處理。
-- ⚠ `Skin.ApplyBase` 要再補一次：`ns.ApplyAll` 只在載入當下跑過一次，
--   晚到的 tooltip 沒吃到那一輪的設定。
-- ⚠ 冪等：已經接管過的直接回 true，不會長出第二層 skin。
------------------------------------------------------------
MiliUITip_API = MiliUITip_API or {}

function MiliUITip_API.Adopt(tip)
    if type(tip) ~= "table" then return false end
    -- 還沒初始化好（設定值還沒讀進來）⇒ 現在接管會畫出一顆沒有設定的框
    if not ns.db then return false end
    if ns.Skin.Get(tip) then return true end
    ns.TrackTip(tip)
    ns.Skin.ApplyBase(tip)
    return ns.Skin.Get(tip) ~= nil
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
